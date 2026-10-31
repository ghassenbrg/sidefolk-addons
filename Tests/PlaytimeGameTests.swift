import Foundation
import Testing
import SidefolkExtensionKit
@testable import ext_playtime

/// Playtime's trivia as a game in Sidefolk's Play panel (Sidefolk D75): the round's rules, the companion's honest
/// picks and help, the boards and cues it sends, its words in ten languages, and the Kit's `Localized`.
@Suite(.serialized) struct PlaytimeGameTests {
    init() {
        // Scores go to a folder of the test's own, never the person's.
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("playtime-tests-\(UUID().uuidString)").path
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        setenv("SIDEFOLK_DATA_DIR", dir, 1)
    }

    /// The same numbers every run.
    struct Seeded: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
    }

    @Test func localizedPicksTheLanguageAndFallsBackToEnglish() {
        #expect(Localized.normalized("fr-CA") == "fr" && Localized.normalized("pt") == "pt-BR" && Localized.normalized("zh-Hans-CN") == "zh-Hans")
        #expect(Localized.normalized("zh_TW") == "zh-Hans" && Localized.normalized("sv") == "en" && Localized.normalized(nil) == "en")
        let w = Localized("fr", ["en": ["a": "A", "of": "%1$@ of %2$@", "only": "Only English"], "fr": ["a": "À", "of": "%1$@ sur %2$@"]])
        #expect(w["a"] == "À" && w["only"] == "Only English" && w["missing"] == "missing")
        #expect(w("of", w.number(3), w.number(10)) == "3 sur 10")
        // Numbers as the language writes them, the way Sidefolk writes its own.
        let arabic = 12.formatted(.number.grouping(.never).locale(Locale(identifier: "ar")))
        #expect(Localized("ar", [:]).number(12) == arabic && Localized("ar", [:]).rightToLeft && Localized("de", [:]).number(1234) == "1234")
    }

    @Test func everyLanguageSaysEveryWordWithItsPlaceholders() {
        let english = Words.tables["en"]!
        func slots(_ s: String) -> [String] {
            s.matches(of: /%(\d\$)?@/).map { String($0.output.0) }.sorted()
        }
        #expect(Set(Words.tables.keys) == Set(Localized.languages))
        for (language, table) in Words.tables {
            #expect(Set(table.keys) == Set(english.keys), "\(language): \(Set(english.keys).symmetricDifference(table.keys))")
            for (key, text) in table {
                let a = slots(text), b = slots(english[key] ?? "")
                #expect(a.count == b.count && (a == b || b.count < 2), "\(language) \(key)")
            }
        }
        // Topics shown on the set-up have words in every language.
        for language in Localized.languages {
            for topic in ["mix"] + TriviaLibrary.categories(language: "en") {
                #expect(TriviaScreen.topic(topic, Words.for(language)) != topic, "\(language) \(topic)")
            }
        }
    }

    @Test func aRoundAgainstTheCompanion() throws {
        var random = Seeded(state: 7)
        var s = TriviaEngine.start(level: .fair, options: GameOptions(), random: &random)
        #expect(s.phase == .setup && s.topic == "mix" && s.length == 10 && !s.quick)
        #expect(TriviaEngine.play(.topic("nowhere"), on: &s, random: &random) == nil, "only topics with questions")
        #expect(TriviaEngine.play(.answer(0), on: &s, random: &random) == nil, "no answer before a question")
        _ = TriviaEngine.play(.topic("space"), on: &s, random: &random)
        _ = TriviaEngine.play(.length(5), on: &s, random: &random)
        #expect(TriviaEngine.play(.start, on: &s, random: &random) == [.other("question")])
        #expect(s.phase == .question && s.round.count == 5 && Set(s.round).count == 5)
        #expect(s.round.allSatisfy { id in TriviaLibrary.questions(language: "en").first { $0.id == id }?.category == "space" })
        #expect(TriviaRecords.load().setup == TriviaRecords.Setup(topic: "space", length: 5, quick: false), "the set-up is remembered")

        // The lifeline, once: two tiles fade, and the person can't pick one.
        let hint = try #require(TriviaEngine.play(.hint, on: &s, random: &random))
        #expect(s.faded.count == 2 && s.lifelineUsed && hint.count == 1)
        #expect(TriviaEngine.play(.hint, on: &s, random: &random) == nil)
        #expect(TriviaEngine.play(.answer(s.faded[0]), on: &s, random: &random) == nil)

        var rights = 0
        for i in 0..<5 {
            let right = try #require(TriviaEngine.rightTile(s))
            let pick = i.isMultiple(of: 2) ? right : (right + 1) % 4
            let events = try #require(TriviaEngine.play(.answer(s.faded.contains(pick) ? right : pick), on: &s, random: &random))
            if events.contains(.personRight) { rights += 1 }
            #expect(events.contains(.companionRight) == (s.companionPick == right))
            #expect(s.phase == .answered)
            _ = TriviaEngine.play(.next, on: &s, random: &random)
        }
        #expect(s.phase == .done && s.you == rights && s.results.count == 5)
        let records = TriviaRecords.load()
        #expect(records.played == 1 && records.you == s.you && records.companion == s.companion && records.history.first?.topic == "space")
        #expect(records.best["5"] == s.you && s.record == (s.you > 0))
        #expect(TriviaEngine.play(.again, on: &s, random: &random) == [.other("question")] && s.you == 0 && s.phase == .question)
    }

    @Test func theTimeRunningOutIsAMissAndEndlessGoesOnUntilFinish() throws {
        var random = Seeded(state: 3)
        var s = TriviaEngine.start(level: .fair, options: GameOptions(), random: &random)
        _ = TriviaEngine.play(.length(0), on: &s, random: &random)
        _ = TriviaEngine.play(.pace(quick: true), on: &s, random: &random)
        _ = TriviaEngine.play(.start, on: &s, random: &random)
        let events = try #require(TriviaEngine.play(.timeout, on: &s, random: &random))
        #expect(events.contains(.personWrong) && s.picked == nil && s.streak == 0)
        for _ in 0..<60 {
            _ = TriviaEngine.play(.next, on: &s, random: &random)
            _ = TriviaEngine.play(.timeout, on: &s, random: &random)
        }
        #expect(s.phase == .answered, "endless laps the topic again")
        let end = try #require(TriviaEngine.play(.finish, on: &s, random: &random))
        #expect(s.phase == .done && end.contains(.ended(s.companion > 0 ? .lost : .draw)), "nothing answered right: the companion wins or it's a draw")
    }

    @Test func theCompanionKnowsWhatItKnows() {
        let easy = TriviaQuestion(id: "e", category: "nature", difficulty: 1, text: "", choices: [], answer: 0, fact: "")
        let hard = TriviaQuestion(id: "h", category: "sports", difficulty: 3, text: "", choices: [], answer: 0, fact: "")
        #expect(TriviaEngine.skill(easy, .fair) > 0.9 && TriviaEngine.skill(hard, .fair) < 0.45)
        #expect(TriviaEngine.skill(hard, .hard) > TriviaEngine.skill(hard, .easy))
        // Over many questions it is right about as often as it knows them, neither always nor never.
        var random = Seeded(state: 11)
        var s = TriviaEngine.start(level: .fair, options: GameOptions(), random: &random)
        _ = TriviaEngine.play(.length(0), on: &s, random: &random)
        _ = TriviaEngine.play(.start, on: &s, random: &random)
        var right = 0
        for _ in 0..<200 {
            if s.companionPick == TriviaEngine.rightTile(s) { right += 1 }
            _ = TriviaEngine.play(.timeout, on: &s, random: &random)
            _ = TriviaEngine.play(.next, on: &s, random: &random)
        }
        #expect((110...175).contains(right), "\(right) of 200")
    }

    @Test func boardsAndCuesAreSidefolks() throws {
        var random = Seeded(state: 5)
        let words = Words.for("de")
        var options = GameOptions()
        options.companion = "Nori"
        var s = TriviaEngine.start(level: .fair, options: options, random: &random)
        let setup = TriviaScreen.board(s, events: [.other("opened")], words: words, options: options).json
        let parts = setup["parts"] as! [[String: Any]]
        #expect(parts.map { $0["type"] as! String } == ["prompt", "choice", "choice", "choice", "button"])
        #expect(parts[0]["eyebrow"] as? String == "Ein Quiz mit Nori" && parts[4]["label"] as? String == "Starten")
        #expect((setup["companion"] as? [String: Any])?["line"] as? String == "hello")

        _ = TriviaEngine.play(.start, on: &s, random: &random)
        let question = TriviaScreen.board(s, events: [.other("question")], words: words, options: options).json
        let qparts = question["parts"] as! [[String: Any]]
        #expect(qparts.first?["companion_picked"] as? Bool == true, "its pick is sealed")
        #expect(qparts.contains { $0["type"] as? String == "answers" && ($0["items"] as? [[String: Any]])?.contains { $0["companion"] != nil } == false })
        #expect(qparts.contains { $0["move"] as? String == "hint" && $0["label"] as? String == "Nori fragen" && $0["key"] as? String == "h" })

        _ = TriviaEngine.play(.answer(0), on: &s, random: &random)
        let answered = TriviaScreen.board(s, events: [.personRight, .companionWrong], words: words, options: options).json
        let aparts = answered["parts"] as! [[String: Any]]
        #expect(aparts.contains { $0["type"] as? String == "note" && $0["title"] as? String == "Schon gewusst?" })
        #expect(aparts.contains { ($0["items"] as? [[String: Any]])?.filter { $0["companion"] as? Bool == true }.count == 1 }, "its pick shows once answered")
        #expect(TriviaScreen.cue([.personRight, .companionWrong])?.move == "sulk")
        #expect(TriviaScreen.cue([.personWrong, .companionRight])?.line == "tease")
        #expect(TriviaScreen.cue([.personRight, .companionRight, .streak(3)])?.effect == "sparkles")
        #expect(TriviaScreen.cue([.ended(.won)])?.line == "you_win" && TriviaScreen.cue([.ended(.lost)])?.sound == "trombone")
        #expect(TriviaScreen.cue([]) == nil)
        // Every cue value is one Sidefolk knows.
        let moves: Set<String> = ["think", "cheer", "celebrate", "sulk", "bow", "nod", "shrug", "giggle", "wince", "gasp", "tease", "sweat", "dizzy",
                                  "ready", "shuffle", "hop", "spin", "wave", "dance"]
        for events: [GameEvent] in [[.other("question")], [.hint(trusty: true)], [.hint(trusty: false)], [.ended(.draw)], [.personWrong, .companionWrong]] {
            let cue = try #require(TriviaScreen.cue(events))
            #expect(moves.contains(cue.move ?? ""), "\(events)")
        }
        #expect(TriviaScreen.action(for: .choice(name: "length", value: "0"), in: s) == .length(0))
        #expect(TriviaScreen.action(for: .button("erase"), in: s) == nil)
    }

    @Test func homeShowsTheScoreInTheLanguageAsked() {
        TriviaRecords.update { $0 = TriviaRecords() }
        let empty = PlaytimePage.render(language: "fr")
        #expect(empty.summary?.title == "Un quiz contre votre compagnon")
        TriviaRecords.update {
            $0.played = 3
            $0.you = 21
            $0.companion = 18
            $0.history = [TriviaRecords.Game(date: Date(), topic: "space", asked: 10, you: 7, companion: 6)]
        }
        let page = PlaytimePage.render(language: "ar")
        let w = Words.for("ar")
        #expect(page.summary?.title == "أنت \(w.number(21)) · رفيقك \(w.number(18))")
        #expect(page.sections.count == 2)
    }
}
