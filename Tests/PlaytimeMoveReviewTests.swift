import Foundation
import Testing
@testable import SidefolkExtensionKit
@testable import ext_playtime

/// What comparing the moved games with the old ones found in the pack (Sidefolk D101), each as the behaviour that must hold.
@Suite(.serialized) @MainActor
struct PlaytimeMoveReviewTests {
    private func clearSessions() { try? FileManager.default.removeItem(atPath: PlayTable.folder) }

    private func opening(_ game: String, session: String = "") -> SurfaceReply {
        PlayTable.open(SurfaceRequest(["session": session, "arguments": ["game": game]]))
    }

    /// ✕ only hides the panel, and Sidefolk's session goes on with no word to the program: the game is still the one to come back to.
    @Test func aGameHiddenInItsPanelIsStillTheOneToContinue() {
        clearSessions()
        defer { clearSessions() }
        #expect(PlayTable.keptGame == nil)
        _ = opening("sudoku")
        #expect(PlayTable.keptGame == "sudoku", "hidden, no close")
        let page = PlaytimePage.render().json
        let text = String(decoding: (try? JSONSerialization.data(withJSONObject: page)) ?? Data(), as: UTF8.self)
        #expect(text.contains("Continue") && text.contains("Sudoku") && text.contains("Ready when you are!"), "the hero says so")
        #expect(text.contains("Resume") && text.contains("\"style\":\"accent\""), "and its card")
    }

    @Test func aGameEndedByAnotherOpeningIsKeptAndAnOverGameIsNot() {
        clearSessions()
        defer { clearSessions() }
        let reply = opening("sudoku")
        PlayTable.close(SurfaceRequest(["session": reply.session, "reason": "closed"]))
        #expect(PlayTable.keptGame == "sudoku")
        // The kept file itself is what the next opening takes back.
        _ = PlayTable.open(SurfaceRequest(["session": "", "arguments": [:]]))
        #expect(PlayTable.keptGame == "sudoku", "the menu holds it now")
    }

    /// Leaving a game for the menu puts its props away, and the menu has no speaker of its own.
    @Test func theMenuClearsPropsAndHasNoSpeaker() {
        let scene = PlayMenu.scene(selected: 0, kept: nil).json
        #expect((scene["react"] as? [String: Any])?["prop"] as? String == "none")
        #expect(scene["speaker"] as? Bool == false)
    }

    /// One switch for every game: a game's speaker reads it until pressed, a change to it clears those, and nothing the program writes makes a row per game.
    @Test func eachGamesSoundFollowsTheOneSwitch() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("extensions/playtime/sidefolk-extension.json")
        let manifest = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let settings = try #require(manifest["settings"] as? [[String: Any]])
        for game in GameTable.drivers.keys {
            let key = GameSoundSetting.key(game), found = settings.first { $0["key"] as? String == key }
            #expect(found?["follows"] as? String == "sounds" && found?["listed"] as? Bool == false, "\(key)")
        }
        let tone = settings.first { $0["key"] as? String == "tone" }
        #expect(tone?["segmented"] as? Bool == true)
        let source = try String(contentsOf: url.deletingLastPathComponent().appendingPathComponent("Sources/Table/PlaytimeTools.swift"), encoding: .utf8)
        #expect(!source.contains("GameSoundSetting.key"), "the tool writes one setting")
    }

    /// A topic is the AI's to start only in a clean turn: the manifest says so, and Sidefolk holds it to that.
    @Test func aTopicIsTrustedOnly() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("extensions/playtime/sidefolk-extension.json")
        let manifest = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let open = try #require((manifest["tools"] as? [String: Any])?["open"] as? [String: Any])
        #expect(open["trusted_only"] as? [String] == ["topic"])
    }

    /// History's row says what was done and how it came out, once.
    @Test func aRowSaysWhatHappened() {
        Language.with("en", strings: PlaytimeGameTests.strings) {
            #expect(Toss.coins([true]).row == "Flip a coin — Heads!")
            #expect(Toss.dice(sides: 6, rolls: [4], modifier: 0).row.seen == "Roll a die — It's 4!")
            #expect(Toss.dice(sides: 6, rolls: [4, 2], modifier: 1).row.seen.hasPrefix("Roll 2d6+1 — "))
            #expect(Toss.hands(person: .paper, companion: .rock).row == "Rock, paper, scissors — Paper beats rock: you win!")
        }
    }

    /// The face scenes draw with, so a line that fits isn't counted as two, leaving an empty band in a bubble.
    @Test func wordsAreMeasuredInTheFaceTheyAreDrawnIn() {
        let line = "Guess the word, a letter at a time."
        let width = TextFit.width(line, size: 17, weight: "heavy")
        #expect(width <= 281, "\(width): the rounded face runs narrower than the system's, 283")
        #expect(TextFit.height(line, size: 17, weight: "heavy", width: 300) == 20 || TextFit.height(line, size: 17, weight: "heavy", width: 300) == 21)
        #expect(TextFit.height(line + " " + line, size: 17, weight: "heavy", width: 300) >= 40)
    }

    /// The page holds the Game Center's look as data of its own: nothing of it is the app's.
    @Test func theGameCentersLookIsInThePage() {
        let page = PlaytimePage.render().json
        let text = String(decoding: (try? JSONSerialization.data(withJSONObject: page)) ?? Data(), as: UTF8.self)
        for part in ["\"tile\":[", "\"wash\":[", "\"banner\":{", "\"shape\":\"round\"", "\"grid\":true", "\"ai_title\":", "\"wide\":true"] { #expect(text.contains(part), "\(part)") }
    }

    /// Words of the Game Center's and the menu's that mean wins and puzzles are their own, so a language can keep its word for them apart from Daily Word's.
    @Test func wordsInContextAreTheirOwn() {
        Language.with("en", strings: PlaytimeGameTests.strings) {
            #expect(L("Best streak", context: "games") == "Best streak" && L("Not played yet", context: "games") == "Not played yet")
        }
        Language.with("zh-Hans", strings: PlaytimeGameTests.strings) {
            #expect(L("Not played yet", context: "games") == "还没玩过" && L("Not played yet") == "今天还没玩")
            #expect(L("Best streak", context: "games") == "最佳连胜")
        }
        Language.with("ja", strings: PlaytimeGameTests.strings) { #expect(L("Solved", context: "games") == "クリア" && L("Solved") == "正解") }
        Language.with("ar", strings: PlaytimeGameTests.strings) { #expect(L("Next round") == "الجولة التالية") }
    }
}
