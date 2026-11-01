import Foundation
import Testing
@testable import SidefolkExtensionKit
@testable import ext_playtime

/// Playtime's trivia as a game in Sidefolk's Play panel (Sidefolk D75): the round's rules, the companion's honest
/// picks and help, the 400 questions in every language, the boards and cues it sends, its words through strings/.
@Suite(.serialized) struct PlaytimeGameTests {
    static let strings = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("extensions/playtime/strings").path

    init() {
        // Scores go to a folder of the test's own, never the person's.
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("playtime-tests-\(UUID().uuidString)").path
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        setenv("SIDEFOLK_DATA_DIR", dir, 1)
    }

    @Test func localizedPicksTheLanguageAndFallsBackToEnglish() {
        #expect(Localized.normalized("fr-CA") == "fr" && Localized.normalized("pt") == "pt-BR" && Localized.normalized("zh-Hans-CN") == "zh-Hans")
        #expect(Localized.normalized("zh_TW") == "zh-Hans" && Localized.normalized("sv") == "en" && Localized.normalized(nil) == "en")
    }

    /// Every text in every language, placeholders kept, plural forms as the language counts.
    @Test func everyLanguageSaysEveryText() throws {
        func load(_ l: String) throws -> [String: Any] {
            try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: Self.strings + "/\(l).json"))) as! [String: Any]
        }
        let english = try load("en")["text"] as! [String: Any]
        #expect(english.count > 200)
        func slots(_ s: String) -> Set<String> { Set(s.matches(of: /\{([a-z]+)\}/).map { String($0.1) }) }
        for language in Localized.languages where language != "en" {
            let file = try load(language)
            let text = file["text"] as! [String: Any]
            #expect(Set(text.keys) == Set(english.keys), "\(language): \(Set(english.keys).symmetricDifference(text.keys))")
            for (key, value) in text {
                if let s = value as? String {
                    #expect(slots(s) == slots(key), "\(language) \(key)")
                } else if let forms = value as? [String: String] {
                    #expect(forms["other"].map(slots) == slots(key), "\(language) \(key)")
                }
            }
            #expect((file["games"] as? [String: Any])?.count == 15, "\(language): every game's title")
        }
    }

    @Test func theQuestionsAreFourHundredInEveryLanguage() {
        for language in Localized.languages {
            let questions = TriviaLibrary.questions(language: language)
            #expect(questions.count >= 400, "\(language)")
            #expect(Set(questions.map(\.id)).count == questions.count)
            #expect(TriviaLibrary.categories(language: language).count == 10)
        }
        // The same question in each language: its id, category and right answer (the first, as written) are shared.
        let en = TriviaLibrary.questions(language: "en"), ja = TriviaLibrary.questions(language: "ja")
        #expect(zip(en, ja).allSatisfy { $0.id == $1.id && $0.category == $1.category && $0.answer == 0 && $0.text != $1.text })
    }

    @Test func aRoundAgainstTheCompanion() throws {
        var random = Games.Random(seed: 7)
        var s = TriviaEngine.start(level: .fair, options: GameOptions(), random: &random)
        #expect(s.phase == .setup && s.topic == "mix" && s.length == 10 && !s.quick)
        #expect(throws: Games.Refusal.self) { try TriviaEngine.play(.topic("nowhere"), on: &s, random: &random) }
        #expect(throws: Games.Refusal.self) { try TriviaEngine.play(.answer(0), on: &s, random: &random) }
        _ = try TriviaEngine.play(.topic("space"), on: &s, random: &random)
        _ = try TriviaEngine.play(.length(5), on: &s, random: &random)
        #expect(try TriviaEngine.play(.start, on: &s, random: &random) == [.sealed])
        #expect(s.phase == .question && s.round.count == 5 && Set(s.round).count == 5)
        #expect(s.round.allSatisfy { id in TriviaLibrary.questions(language: "en").first { $0.id == id }?.category == "space" })
        #expect(TriviaRecords.load().setup == TriviaRecords.Setup(topic: "space", length: 5, quick: false), "the set-up is remembered")

        // The lifeline, once: two tiles fade, and the person can't pick one.
        let hint = try TriviaEngine.play(.hint, on: &s, random: &random)
        #expect(s.faded.count == 2 && s.lifelineUsed && hint.count == 1)
        #expect(throws: Games.Refusal("hint_used")) { try TriviaEngine.play(.hint, on: &s, random: &random) }
        #expect(throws: Games.Refusal.self) { try TriviaEngine.play(.answer(s.faded[0]), on: &s, random: &random) }

        var rights = 0
        for i in 0..<5 {
            let right = try #require(TriviaEngine.rightTile(s))
            let pick = i.isMultiple(of: 2) ? right : (right + 1) % 4
            let events = try TriviaEngine.play(.answer(s.faded.contains(pick) ? right : pick), on: &s, random: &random)
            if events.contains(.point(.you)) { rights += 1 }
            #expect(events.contains(.point(.companion)) == (s.companionPick == right))
            _ = try? TriviaEngine.play(.next, on: &s, random: &random)
        }
        #expect(s.phase == .done && s.you == rights && s.results.count == 5)
        let records = TriviaRecords.load()
        #expect(records.played == 1 && records.you == s.you && records.history.first?.topic == "space")
        #expect(PlaytimeRecords.load().games["trivia"]?.played == 1, "Home's tally counts it too")
        #expect(try TriviaEngine.play(.again, on: &s, random: &random) == [.sealed] && s.you == 0 && s.phase == .question)
    }

    /// The companion's pick is sealed when the question is asked: whatever the person answers, it is the same pick.
    @Test func theCompanionsPickNeverReadsThePersons() throws {
        for seed in 1...20 as ClosedRange<UInt64> {
            var picks: Set<Int> = []
            for answer in 0..<4 {
                TriviaRecords.update { $0 = TriviaRecords() }
                var random = Games.Random(seed: seed)
                var s = TriviaEngine.start(level: .fair, options: GameOptions(), random: &random)
                _ = try TriviaEngine.play(.start, on: &s, random: &random)
                let sealed = s.companionPick
                _ = try TriviaEngine.play(.answer(answer), on: &s, random: &random)
                #expect(s.companionPick == sealed)
                picks.insert(sealed)
            }
            #expect(picks.count == 1)
        }
    }

    @Test func eachCompanionKnowsItsOwnTopics() {
        let mochi = Games.QuizBank.categories.map { TriviaEngine.strength($0, companion: "Mochi") }
        let nori = Games.QuizBank.categories.map { TriviaEngine.strength($0, companion: "Nori") }
        #expect(mochi.allSatisfy { (0.55...0.85).contains($0) } && Set(mochi).count > 3 && mochi != nori)
        #expect(mochi == Games.QuizBank.categories.map { TriviaEngine.strength($0, companion: "Mochi") }, "always the same for one companion")
        let easy = TriviaQuestion(id: "e", category: "nature", difficulty: 1, text: "", choices: [], answer: 0, fact: "")
        let hard = TriviaQuestion(id: "h", category: "nature", difficulty: 3, text: "", choices: [], answer: 0, fact: "")
        #expect(TriviaEngine.skill(easy, .fair) > TriviaEngine.skill(hard, .fair) && TriviaEngine.skill(hard, .hard) > TriviaEngine.skill(hard, .easy))
        // Over many questions it is right about as often as it knows them, neither always nor never.
        var random = Games.Random(seed: 11)
        var s = TriviaEngine.start(level: .fair, options: GameOptions(), random: &random)
        _ = try? TriviaEngine.play(.length(0), on: &s, random: &random)
        _ = try? TriviaEngine.play(.start, on: &s, random: &random)
        var right = 0
        for _ in 0..<200 {
            if s.companionPick == TriviaEngine.rightTile(s) { right += 1 }
            _ = try? TriviaEngine.play(.timeout, on: &s, random: &random)
            _ = try? TriviaEngine.play(.next, on: &s, random: &random)
        }
        #expect((100...180).contains(right), "\(right) of 200")
    }

    @Test func boardsAndCuesInGerman() throws {
        try Language.with("de", strings: Self.strings) {
            var random = Games.Random(seed: 5)
            var options = GameOptions()
            options.companion = "Nori"
            options.language = "de"
            var s = TriviaEngine.start(level: .fair, options: options, random: &random)
            let setup = TriviaScreen.board(s, events: [.opened], options: options).json
            let parts = setup["parts"] as! [[String: Any]]
            #expect(parts.map { $0["type"] as! String } == ["prompt", "choice", "choice", "choice", "button", "choice"])
            #expect((parts[0]["eyebrow"] as? String)?.seen == "Ein Quiz mit Nori" && parts[4]["label"] as? String == "Starten")
            #expect((setup["companion"] as? [String: Any])?["line"] as? String == "hello")

            _ = try TriviaEngine.play(.start, on: &s, random: &random)
            let question = TriviaScreen.board(s, events: [.sealed], options: options).json
            let qparts = question["parts"] as! [[String: Any]]
            #expect(qparts.first?["companion_picked"] as? Bool == true, "its pick is sealed")
            #expect(qparts.contains { $0["move"] as? String == "hint" && ($0["label"] as? String)?.seen == "Nori fragen" && $0["key"] as? String == "h" })
            let prompt = try #require(qparts.first { $0["type"] as? String == "prompt" })
            #expect(TriviaLibrary.questions(language: "de").contains { $0.text == prompt["text"] as? String }, "the question in German")

            _ = try TriviaEngine.play(.answer(0), on: &s, random: &random)
            let answered = TriviaScreen.board(s, events: [.reveal, .point(.you)], options: options).json
            let aparts = answered["parts"] as! [[String: Any]]
            #expect(aparts.contains { ($0["items"] as? [[String: Any]])?.filter { $0["companion"] as? Bool == true }.count == 1 }, "its pick shows once answered")
            #expect(aparts.contains { $0["label"] as? String == "Weiter" })
        }
        #expect(TriviaScreen.cue([.reveal, .point(.you)])?.move == "sulk")
        #expect(TriviaScreen.cue([.reveal, .point(.companion)])?.line == "tease")
        #expect(TriviaScreen.cue([.reveal, .point(.you), .point(.companion), .streak(3)])?.effect == "sparkles")
        #expect(TriviaScreen.cue([.matchOver(winner: .you)])?.line == "you_win" && TriviaScreen.cue([.matchOver(winner: .companion)])?.sound == "trombone")
        #expect(TriviaScreen.cue([]) == nil)
    }

    @Test func theGameCenterGetsEveryGameWithItsBest() {
        Language.with("fr", strings: Self.strings) {
            PlaytimeRecords.update { $0 = PlaytimeRecords() }
            let empty = PlaytimePage.render()
            #expect(empty.summary?.title.seen == "Le mot du jour : Pas encore joué")
            PlaytimeRecords.finish(QuickPawsScreen.id, .won, you: 3, companion: 1, best: 243, lower: true)
            PlaytimeRecords.finish(QuickPawsScreen.id, .lost, you: 1, companion: 3, best: 300, lower: true)
            let page = PlaytimePage.render()
            let json = String(decoding: try! JSONSerialization.data(withJSONObject: page.json), as: UTF8.self)
            #expect(json.seen.contains("Record : 243 ms"), "\(json.prefix(400))")
            let paws = page.games?.records[QuickPawsScreen.id]
            #expect(paws?.played == 2 && paws?.won == 1 && paws?.lost == 1 && paws?.best?.seen == "Record : 243 ms")
            #expect(page.sections.isEmpty, "Sidefolk draws the Game Center from the records")
            #expect(page.games?.recent.map(\.outcome) == [.lost, .won] && page.games?.recent.first?.game == QuickPawsScreen.id)
            #expect(page.games?.records[DailyWordScreen.id]?.today?.done == false)
        }
    }
}
