import Foundation
import Testing
@testable import SidefolkExtensionKit
@testable import ext_playtime

/// The ten new games as Sidefolk sees them (Sidefolk D75, phases 2 and 3): each adapter's moves and boards, the one
/// event → cue table, the records kept, fairness (the companion's hidden choices are fixed before the person moves),
/// the keyboards per script, Daily Word the same for everyone on a date, and a bot that plays each to its end.
@Suite(.serialized) struct PlaytimeScreensTests {
    init() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("playtime-screens-\(UUID().uuidString)").path
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        setenv("SIDEFOLK_DATA_DIR", dir, 1)
    }

    static func options(_ language: String = "en", sneaky: Bool = false) -> GameOptions {
        var o = GameOptions()
        o.language = language
        o.sneaky = sneaky
        o.companion = "Mochi"
        return o
    }

    static func parts(_ b: Board) -> [[String: Any]] { b.json["parts"] as! [[String: Any]] }
    static func part(_ b: Board, _ type: String) -> [String: Any]? { parts(b).first { $0["type"] as? String == type } }

    // MARK: A bot that plays each game through its screen

    /// Picks a move the board offers, as a person clicking might: enough to reach every game's end.
    static func botMove(_ board: Board, step: Int) -> Move? {
        let json = board.json
        if json["after_ms"] != nil { return .next }
        let ps = parts(board)
        func find(_ t: String) -> [String: Any]? { ps.first { $0["type"] as? String == t } }
        if let r = find("reflex"), r["after_ms"] != nil, r["shows"] == nil { return .press(milliseconds: step % 2 == 0 ? 180 : 600) }
        if let a = find("answers"), a["locked"] as? Bool != true {
            let items = a["items"] as! [[String: Any]]
            let open = items.indices.filter { items[$0]["state"] as? String != "faded" }
            return .answer(open[step % open.count])
        }
        if let g = find("board"), g["locked"] as? Bool != true {
            let cells = g["cells"] as! [[String: Any]], columns = g["columns"] as! Int
            if let i = cells.indices.first(where: { ["empty", "card_back"].contains(cells[$0]["mark"] as? String) && cells[$0]["state"] as? String != "disabled" }) {
                return .cell(row: i / columns, column: i % columns)
            }
        }
        if let c = find("cups"), c["locked"] as? Bool != true, c["gem"] == nil { return .cell(row: 0, column: step % (c["count"] as! Int)) }
        if let p = find("pads"), p["locked"] as? Bool != true { return .pad(step % 2) }
        if let s = find("sticks"), s["locked"] as? Bool != true { return .number(1) }
        if let n = find("number"), n["locked"] as? Bool != true {
            var low = 1, high = 100
            for g in n["history"] as? [[String: Any]] ?? [] {
                let v = g["value"] as! Int
                if g["mark"] as? String == "higher" { low = max(low, v + 1) } else if g["mark"] as? String == "lower" { high = min(high, v - 1) }
            }
            return .number((low + high) / 2)
        }
        if let k = find("keys"), k["locked"] as? Bool != true {
            let keys = (k["pages"] as! [[String: Any]]).flatMap { ($0["rows"] as! [[[String: Any]]]).flatMap { $0 } }
            if k["mode"] as? String == "spell" {
                let n = k["length"] as! Int
                return .word((0..<n).map { keys[(step * n + $0 * 3) % keys.count]["key"] as! String }.joined())
            }
            if let key = keys.first(where: { $0["mark"] as? String == "none" }) { return .letter(key["key"] as! String) }
        }
        if let e = find("entry"), e["locked"] as? Bool != true {
            if e["kind"] as? String == "word" { return .word(["一心一意", "七上八下", "人山人海", "三心二意", "十全十美", "五颜六色"][step % 6]) }
            return .text(name: e["name"] as! String, value: e["name"] as? String == "animal" ? "axolotl \(step)" : "Does it live in a lake?")
        }
        if let b = ps.first(where: { $0["type"] as? String == "button" && $0["style"] as? String == "primary" }) { return .button(b["move"] as! String) }
        if let c = find("choice"), c["name"] as? String != "level" {
            return .choice(name: c["name"] as! String, value: ((c["options"] as! [[String: Any]])[0]["value"] as! String))
        }
        return nil
    }

    /// Plays a game from its start to its end card; every board is JSON under 64 KB.
    @discardableResult
    static func play<S: GameScreen>(_ screen: S.Type, seed: UInt64, language: String = "en", options o: GameOptions? = nil,
                                    limit: Int = 600) throws -> (boards: [Board], state: S.Engine.State) {
        let options = o ?? Self.options(language)
        var random = Games.Random(seed: seed)
        var state = S.Engine.start(level: .fair, options: options, random: &random)
        var board = S.board(state, events: [.opened] + S.Engine.opening(state), options: options)
        var boards = [board]
        for step in 0..<limit where !board.over {
            let move = try #require(botMove(board, step: step), "\(S.id): stuck on \(board.json)")
            let events = GameTable.play(S.self, move, on: &state, random: &random)
            board = S.board(state, events: events, options: options)
            let data = try JSONSerialization.data(withJSONObject: board.json)
            #expect(data.count < 64 * 1024, "\(S.id)")
            boards.append(board)
        }
        #expect(board.over, "\(S.id) ended within \(limit) moves")
        #expect(part(board, "result") != nil, "\(S.id) ends on its card")
        return (boards, state)
    }

    @Test func everyGamePlaysToItsEnd() throws {
        try Language.with("en", strings: PlaytimeGameTests.strings) {
            for seed in [1, 2, 3] as [UInt64] {
                try Self.play(TriviaScreen.self, seed: seed)
                try Self.play(TicTacToeScreen.self, seed: seed)
                try Self.play(CopyMeScreen.self, seed: seed)
                try Self.play(QuickPawsScreen.self, seed: seed)
                try Self.play(WhichCupScreen.self, seed: seed)
                try Self.play(HigherLowerScreen.self, seed: seed)
                try Self.play(GuessAnimalScreen.self, seed: seed)
                try Self.play(BalloonWordsScreen.self, seed: seed)
                try Self.play(LastStickScreen.self, seed: seed)
                try Self.play(MemoryPairsScreen.self, seed: seed)
                PlaytimeRecords.update { $0.dailyGame = nil; $0.daily = Games.DailyWord.Record() }
                try Self.play(DailyWordScreen.self, seed: seed)
            }
            // The word games in every script.
            for language in ["de", "ja", "ko", "zh-Hans", "ar"] {
                try Self.play(BalloonWordsScreen.self, seed: 4, language: language)
                PlaytimeRecords.update { $0.dailyGame = nil; $0.daily = Games.DailyWord.Record() }
                try Self.play(DailyWordScreen.self, seed: 4, language: language)
                try Self.play(GuessAnimalScreen.self, seed: 4, language: language)
            }
        }
    }

    // MARK: Each game

    @Test func ticTacToeThinksThenPlays() throws {
        var random = Games.Random(seed: 9)
        var s = TicTacToeEngine.start(level: .fair, options: Self.options(), random: &random)
        let first = TicTacToeScreen.board(s, events: [.opened], options: Self.options())
        #expect(Self.part(first, "board")?["keys"] as? String == "numpad" && first.afterMs == nil)
        let events = GameTable.play(TicTacToeScreen.self, .cell(row: 1, column: 1), on: &s, random: &random)
        let thinking = TicTacToeScreen.board(s, events: events, options: Self.options())
        #expect(thinking.afterMs.map { (600...1400).contains($0) } == true, "the companion thinks for the engine's time")
        #expect(thinking.companion?.move == "think" && Self.part(thinking, "board")?["locked"] as? Bool == true)
        let replied = GameTable.play(TicTacToeScreen.self, .next, on: &s, random: &random)
        #expect(s.game.cells.compactMap { $0 }.count == 2 && replied.contains(.turn(.you)))
        // A taken cell is refused in words.
        let refused = GameTable.play(TicTacToeScreen.self, .cell(row: 1, column: 1), on: &s, random: &random)
        #expect(refused == [.refused("taken")])
        let note = Self.part(TicTacToeScreen.board(s, events: refused, options: Self.options()), "note")
        #expect(note?["text"] as? String == "That one's taken.")
    }

    @Test func copyMeShowsTheSequenceThenTakesPresses() throws {
        var random = Games.Random(seed: 3)
        var s = CopyMeEngine.start(level: .fair, options: Self.options(), random: &random)
        let first = Self.part(CopyMeScreen.board(s, events: [.opened], options: Self.options()), "pads")!
        let play = first["play"] as! [Int]
        #expect(play.count == 1 && (first["items"] as! [[String: Any]]).count == 4)
        _ = GameTable.play(CopyMeScreen.self, .pad(play[0]), on: &s, random: &random)
        let grown = Self.part(CopyMeScreen.board(s, events: [], options: Self.options()), "pads")!
        #expect((grown["play"] as! [Int]).count == 2, "a right copy grows the sequence, which plays again")
        let wrong = (s.game.pads.firstIndex(of: s.game.sequence[0])! + 1) % 4
        let events = GameTable.play(CopyMeScreen.self, .pad(wrong), on: &s, random: &random)
        #expect(events.contains(.mistake) && s.game.phase == .over)
        #expect(["dizzy", "cheer"].contains(CopyMeScreen.board(s, events: events, options: Self.options()).companion?.move))
        #expect(PlaytimeRecords.load().games[CopyMeScreen.id]?.best == 1)
    }

    @Test func quickPawsTimesAreSidefolksAndFair() throws {
        var random = Games.Random(seed: 1)
        var s = QuickPawsEngine.start(level: .fair, options: Self.options(), random: &random)
        let reflex = Self.part(QuickPawsScreen.board(s, events: [.opened], options: Self.options()), "reflex")!
        #expect((1500...5000).contains(reflex["after_ms"] as! Int) && reflex["shows"] == nil)
        // The companion's time is drawn with the round: the same whatever the person presses.
        let companion = try #require(s.round?.companionMs)
        var early = s
        _ = GameTable.play(QuickPawsScreen.self, .early, on: &early, random: &random)
        #expect(early.game.score.companion == 1 && early.early)
        let pressed = GameTable.play(QuickPawsScreen.self, .press(milliseconds: 100), on: &s, random: &random)
        #expect(s.game.lastCompanionMs == companion && pressed.contains(.point(.you)))
        let after = QuickPawsScreen.board(s, events: pressed, options: Self.options())
        #expect(after.afterMs == 1800 && (Self.part(after, "reflex")?["shows"] as? String)?.seen.contains("100 ms") == true)
    }

    @Test func whichCupsGemIsWhereTheSwapsLeaveIt() throws {
        for seed in 1...30 as ClosedRange<UInt64> {
            var gems: Set<Int?> = []
            for pick in 0..<4 {
                var random = Games.Random(seed: seed)
                var s = WhichCupEngine.start(level: .fair, options: Self.options(), random: &random)
                let shuffle = try #require(s.shuffle)
                var at = shuffle.hide
                for swap in shuffle.swaps { if at == swap[0] { at = swap[1] } else if at == swap[1] { at = swap[0] } }
                _ = GameTable.play(WhichCupScreen.self, .cell(row: 0, column: pick), on: &s, random: &random)
                #expect(s.gemAt == at, "without Sneaky the gem is always where the swaps put it")
                gems.insert(s.gemAt)
            }
            #expect(gems.count == 1, "the person's pick never moves the gem")
        }
        // Sneaky: the companion in the scene is the "Check its paw" button (C too), once a round.
        var random = Games.Random(seed: 2)
        let sneaky = Self.options(sneaky: true)
        var s = WhichCupEngine.start(level: .fair, options: sneaky, random: &random)
        let board = WhichCupScreen.board(s, events: [.opened], options: sneaky)
        let check = try #require(Self.parts(board).first { $0["move"] as? String == "accuse" })
        #expect(check["companion"] as? Bool == true && check["key"] as? String == "c" && check["disabled"] == nil)
        #expect(Self.part(board, "prompt")?["text"] as? String == L("Keep your eye on the gem… which cup? Think I'm hiding it? Click me."))
        var seen: Set<String> = []
        for _ in 0..<20 where !s.game.over {
            let events = GameTable.play(WhichCupScreen.self, .button("accuse"), on: &s, random: &random)
            let after = WhichCupScreen.board(s, events: events, options: sneaky)
            if events.contains(.innocent) {
                #expect((Self.parts(after).first { $0["move"] as? String == "accuse" })?["disabled"] as? Bool == true, "once a round")
                #expect(Self.part(after, "prompt")?["text"] as? String == L("Nothing in my paw! It's under a cup."))
                seen.insert("innocent")
                _ = GameTable.play(WhichCupScreen.self, .cell(row: 0, column: 0), on: &s, random: &random)
            } else {
                #expect(events.contains(.caught) && s.caught && !Self.parts(after).contains { $0["move"] as? String == "accuse" })
                seen.insert("caught")
            }
            if !s.game.over { _ = GameTable.play(WhichCupScreen.self, .next, on: &s, random: &random) }
        }
        #expect(seen == ["innocent", "caught"], "this seed has both: \(seen)")
    }

    @Test func higherOrLowerBothWays() throws {
        var random = Games.Random(seed: 4)
        var s = HigherLowerEngine.start(level: .fair, options: Self.options(), random: &random)
        _ = GameTable.play(HigherLowerScreen.self, .choice(name: "mode", value: "mine"), on: &s, random: &random)
        _ = GameTable.play(HigherLowerScreen.self, .button("start"), on: &s, random: &random)
        let secret = s.mine
        _ = GameTable.play(HigherLowerScreen.self, .number(50), on: &s, random: &random)
        let board = HigherLowerScreen.board(s, events: [.lower], options: Self.options())
        #expect(Self.part(board, "meter") != nil && (Self.part(board, "number")?["history"] as? [[String: Any]])?.count == 1)
        #expect(secret?.shown == nil, "sealed until found")
        var yours = HigherLowerEngine.start(level: .fair, options: Self.options(), random: &random)
        _ = GameTable.play(HigherLowerScreen.self, .choice(name: "mode", value: "yours"), on: &yours, random: &random)
        _ = GameTable.play(HigherLowerScreen.self, .button("start"), on: &yours, random: &random)
        #expect(HigherLowerScreen.board(yours, events: [.think(ms: 900)], options: Self.options()).afterMs == 900)
        _ = GameTable.play(HigherLowerScreen.self, .next, on: &yours, random: &random)
        let asking = HigherLowerScreen.board(yours, events: [], options: Self.options())
        #expect((Self.part(asking, "answers")?["items"] as? [[String: Any]])?.map { $0["key"] as? String } == ["h", "l", "y"])
        #expect((Self.part(asking, "prompt")?["text"] as? String)?.seen == "Is it… 50?")
    }

    /// The founder picked "I'll guess yours" once and could never change it: both ways are offered every time, the
    /// last one picked (Return plays it), and either swaps for the other during a game and on its end card.
    @Test func higherOrLowerAlwaysLetsYouSwitchWhoGuesses() throws {
        PlaytimeRecords.update { $0 = PlaytimeRecords() }
        try Language.with("en", strings: PlaytimeGameTests.strings) {
            var random = Games.Random(seed: 5)
            func buttons(_ b: Board) -> [String] {
                Self.parts(b).flatMap { p -> [String] in
                    p["type"] as? String == "button" ? [p["move"] as! String] : (p["actions"] as? [[String: Any]] ?? []).map { $0["move"] as! String }
                }
            }
            var s = HigherLowerEngine.start(level: .fair, options: Self.options(), random: &random)
            var board = HigherLowerScreen.board(s, events: [.opened], options: Self.options())
            #expect(Self.part(board, "choice")?["selected"] as? String == "mine" && buttons(board) == ["start"], "a first game: guess mine, Start")
            #expect(GameTable.play(HigherLowerScreen.self, .choice(name: "mode", value: "yours"), on: &s, random: &random).isEmpty && s.mode == nil,
                    "a card picks, Start plays")
            _ = GameTable.play(HigherLowerScreen.self, .button("start"), on: &s, random: &random)
            #expect(s.yours != nil && PlaytimeRecords.load().higherLowerMode == "yours")

            // Closed and opened again: both ways offered, the last one picked.
            var again = HigherLowerEngine.start(level: .fair, options: Self.options(), random: &random)
            board = HigherLowerScreen.board(again, events: [.opened], options: Self.options())
            #expect((Self.part(board, "choice")?["options"] as? [[String: Any]])?.map { $0["value"] as! String } == ["mine", "yours"])
            #expect(Self.part(board, "choice")?["selected"] as? String == "yours")
            _ = GameTable.play(HigherLowerScreen.self, .choice(name: "mode", value: "mine"), on: &again, random: &random)
            _ = GameTable.play(HigherLowerScreen.self, .button("start"), on: &again, random: &random)
            #expect(again.mine != nil && PlaytimeRecords.load().higherLowerMode == "mine")

            // During a game: the switch, never while the companion thinks.
            #expect(!buttons(HigherLowerScreen.board(s, events: [], options: Self.options())).contains("switch"), "thinking")
            _ = GameTable.play(HigherLowerScreen.self, .next, on: &s, random: &random)
            board = HigherLowerScreen.board(s, events: [], options: Self.options())
            #expect(buttons(board) == ["switch"])
            #expect(Self.parts(board).first { $0["move"] as? String == "switch" }?["label"] as? String == "Switch: you guess")
            _ = GameTable.play(HigherLowerScreen.self, .button("switch"), on: &s, random: &random)
            #expect(s.mode == .mine && s.mine != nil && s.yours == nil && PlaytimeRecords.load().higherLowerMode == "mine")
            #expect(PlaytimeRecords.load().games[HigherLowerScreen.id] == nil, "the game left isn't scored")

            // On the end card: Play again (the same way) first, then the switch.
            while !s.over {
                _ = GameTable.play(HigherLowerScreen.self, .number((s.mine!.low + s.mine!.high) / 2), on: &s, random: &random)
            }
            board = HigherLowerScreen.board(s, events: [.roundOver(winner: .you)], options: Self.options())
            #expect(buttons(board) == ["again", "switch"] && board.over)
            #expect(((Self.part(board, "result")?["actions"] as? [[String: Any]])?.last?["label"] as? String)?.seen == "Switch: Mochi guesses")
            _ = GameTable.play(HigherLowerScreen.self, .button("switch"), on: &s, random: &random)
            #expect(s.mode == .yours && !s.over && PlaytimeRecords.load().higherLowerMode == "yours")
            _ = GameTable.play(HigherLowerScreen.self, .next, on: &s, random: &random)
            while !s.over { _ = GameTable.play(HigherLowerScreen.self, .answer(2), on: &s, random: &random) }
            _ = GameTable.play(HigherLowerScreen.self, .button("again"), on: &s, random: &random)
            #expect(s.mode == .yours, "Play again keeps the way")
        }
    }

    @Test func guessMyAnimalLearnsAndRemembers() throws {
        var random = Games.Random(seed: 1)
        var s = GuessAnimalEngine.start(level: .fair, options: Self.options(), random: &random)
        while s.game.phase == .asking { _ = GameTable.play(GuessAnimalScreen.self, .answer(0), on: &s, random: &random) }
        let guessed = try #require(s.game.guess?.name)
        _ = GameTable.play(GuessAnimalScreen.self, .answer(1), on: &s, random: &random)
        if s.thinking { _ = GameTable.play(GuessAnimalScreen.self, .next, on: &s, random: &random) }
        while s.game.phase == .asking { _ = GameTable.play(GuessAnimalScreen.self, .answer(0), on: &s, random: &random) }
        if s.game.phase == .guessing { _ = GameTable.play(GuessAnimalScreen.self, .answer(1), on: &s, random: &random) }
        #expect(s.game.phase == .teaching)
        #expect(GameTable.play(GuessAnimalScreen.self, .text(name: "animal", value: s.game.guess!.name), on: &s, random: &random) == [.refused("same_animal")])
        _ = GameTable.play(GuessAnimalScreen.self, .text(name: "animal", value: "axolotl"), on: &s, random: &random)
        _ = GameTable.play(GuessAnimalScreen.self, .text(name: "question", value: "Does it live in a Mexican lake?"), on: &s, random: &random)
        let learned = GameTable.play(GuessAnimalScreen.self, .answer(0), on: &s, random: &random)
        #expect(learned.contains(.learned) && s.outcome == .won)
        #expect(PlaytimeRecords.animals().lessons["en"]?.last?.animal == "axolotl", "kept in Playtime's folder")
        let next = GuessAnimalEngine.start(level: .fair, options: Self.options(), random: &random)
        #expect(next.game != s.game && !guessed.isEmpty)
    }

    @Test func balloonWordsPopsAndHoldsBalloons() throws {
        var random = Games.Random(seed: 6)
        var s = BalloonWordsEngine.start(level: .easy, options: Self.options(), random: &random)
        let keys = s.game.keys.filter { k in !s.game.units.contains { $0.key == k } }
        let events = GameTable.play(BalloonWordsScreen.self, .letter(keys[0]), on: &s, random: &random)
        let board = BalloonWordsScreen.board(s, events: events, options: Self.options())
        #expect(board.companion?.prop == "balloons(6)" && (Self.part(board, "lives")?["left"] as? Int) == 6)
        let keyboard = Self.part(board, "keys")!
        let marks = (keyboard["pages"] as! [[String: Any]]).flatMap { ($0["rows"] as! [[[String: Any]]]).flatMap { $0 } }
        #expect(marks.first { $0["key"] as? String == keys[0] }?["mark"] as? String == "miss")
    }

    @Test func lastStickTeachesAfterThreeLosses() throws {
        var random = Games.Random(seed: 2)
        PlaytimeRecords.update { $0.stickLosses = 2; $0.stickSecretOffered = false }
        var s = LastStickEngine.start(level: .hard, options: Self.options(), random: &random)
        while !s.game.over {
            if s.game.turn == .you { _ = GameTable.play(LastStickScreen.self, .number(1), on: &s, random: &random) }
            else { _ = GameTable.play(LastStickScreen.self, .next, on: &s, random: &random) }
        }
        #expect(s.game.winner == .companion && s.game.secretOffered, "you started from 21: Hard wins, then offers its trick")
        _ = GameTable.play(LastStickScreen.self, .button("again"), on: &s, random: &random)
        _ = GameTable.play(LastStickScreen.self, .button("lesson"), on: &s, random: &random)
        let sticks = Self.part(LastStickScreen.board(s, events: [.hint], options: Self.options()), "sticks")!
        #expect(!(sticks["groups"] as! [[Int]]).isEmpty && PlaytimeRecords.load().stickSecretOffered)
    }

    @Test func memoryPairsLeavesTwoCardsUpThenPlaysItsTurn() throws {
        var random = Games.Random(seed: 8)
        var s = MemoryPairsEngine.start(level: .fair, options: Self.options(), random: &random)
        let a = 0, b = s.game.cards.indices.first { $0 != 0 && s.game.cards[$0] != s.game.cards[0] }!
        _ = GameTable.play(MemoryPairsScreen.self, .cell(row: 0, column: a), on: &s, random: &random)
        let e = GameTable.play(MemoryPairsScreen.self, .cell(row: b / 4, column: b % 4), on: &s, random: &random)
        let up = MemoryPairsScreen.board(s, events: e, options: Self.options())
        #expect(e.contains(.noPair(.you)) && up.afterMs == 1200, "two cards stay up a moment")
        #expect((Self.part(up, "board")?["cells"] as! [[String: Any]]).filter { $0["mark"] as? String == "symbol" }.count == 2)
        let turn = GameTable.play(MemoryPairsScreen.self, .next, on: &s, random: &random)
        #expect(s.game.turn == .companion && MemoryPairsScreen.board(s, events: turn, options: Self.options()).afterMs != nil)
    }

    // MARK: Daily Word

    @Test func dailyWordIsTheSameForEveryoneOnADate() throws {
        let date = ISO8601DateFormatter().date(from: "2026-11-02T12:00:00Z")!
        var tokyo = Calendar(identifier: .gregorian), paris = Calendar(identifier: .gregorian)
        tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        paris.timeZone = TimeZone(identifier: "Europe/Paris")!
        // Noon in London is 2 November in both Tokyo and Paris: the same day, the same word.
        #expect(DailyWordEngine.today(date, calendar: tokyo) == DailyWordEngine.today(date, calendar: paris))
        let day = DailyWordEngine.today(date, calendar: paris)
        for language in Games.Language.allCases {
            #expect(Games.DailyWord(language: language, day: day) == Games.DailyWord(language: language, day: day))
            #expect(Games.DailyWord.answer(day: day, language: language) != Games.DailyWord.answer(day: day + 1, language: language))
        }
        // The day on two Macs: one started fresh, one with yesterday's game kept, both today's word.
        DailyWordEngine.now = { date }
        defer { DailyWordEngine.now = { Date() } }
        var random = Games.Random(seed: 1)
        PlaytimeRecords.update { $0.dailyGame = Games.DailyWord(language: .en, day: day - 1) }
        let a = DailyWordEngine.start(level: .fair, options: Self.options(), random: &random)
        PlaytimeRecords.update { $0.dailyGame = nil }
        let b = DailyWordEngine.start(level: .fair, options: Self.options(), random: &random)
        #expect(a.game.day == day && a.game == b.game)
    }

    @Test func dailyWordKeepsTheDayTheStreakAndTheTile() throws {
        let date = ISO8601DateFormatter().date(from: "2026-11-02T12:00:00Z")!
        DailyWordEngine.now = { date }
        defer { DailyWordEngine.now = { Date() } }
        PlaytimeRecords.update { $0 = PlaytimeRecords() }
        try Language.with("en", strings: PlaytimeGameTests.strings) {
            #expect(DailyWordScreen.tile() == ["Not played yet"])
            var random = Games.Random(seed: 1)
            var s = DailyWordEngine.start(level: .fair, options: Self.options(), random: &random)
            let answer = Games.DailyWord.answer(day: s.game.day, language: .en)
            let wrong = Games.WordBank.daily(.en).first { $0 != answer }!
            let e = GameTable.play(DailyWordScreen.self, .word(wrong), on: &s, random: &random)
            let row = DailyWordScreen.board(s, events: e, options: Self.options())
            #expect((Self.part(row, "letters")?["flip"] as? Int) == 0, "the row just played flips")
            // Reopened, the day's rows are there.
            #expect(DailyWordEngine.start(level: .fair, options: Self.options(), random: &random).game.rows.count == 1)
            _ = GameTable.play(DailyWordScreen.self, .word(answer), on: &s, random: &random)
            #expect(s.game.solved && DailyWordScreen.tile().map(\.seen) == ["Solved in 2"])
            let r = PlaytimeRecords.load().daily
            #expect(r.streak == 1 && r.played == 1)
            #expect(GameTable.play(DailyWordScreen.self, .word(wrong), on: &s, random: &random) == [.refused("over")], "once a day")
            let page = PlaytimePage.render()
            #expect(page.summary?.title.seen == "Daily Word: Solved in 2")
        }
    }

    /// "Only one word in one day, but I want to play more": after the day's word, practice words as many as wanted,
    /// at random from the same list, none twice before it runs out, never the day's, and never in its streak or tile.
    @Test func dailyWordPracticeLeavesTheDayAlone() throws {
        let date = ISO8601DateFormatter().date(from: "2026-11-02T12:00:00Z")!
        DailyWordEngine.now = { date }
        defer { DailyWordEngine.now = { Date() } }
        PlaytimeRecords.update { $0 = PlaytimeRecords() }
        try Language.with("en", strings: PlaytimeGameTests.strings) {
            var random = Games.Random(seed: 3)
            var s = DailyWordEngine.start(level: .fair, options: Self.options(), random: &random)
            let answer = Games.DailyWord.answer(day: s.game.day, language: .en)
            #expect(GameTable.play(DailyWordScreen.self, .button("practice"), on: &s, random: &random) == [.refused("not_now")], "the day's word first")
            let wrong = Games.WordBank.daily(.en).first { $0 != answer }!
            _ = GameTable.play(DailyWordScreen.self, .word(wrong), on: &s, random: &random)
            _ = GameTable.play(DailyWordScreen.self, .word(answer), on: &s, random: &random)
            let end = DailyWordScreen.board(s, events: [.reveal], options: Self.options())
            let actions = Self.part(end, "result")?["actions"] as? [[String: Any]]
            #expect(actions?.map { $0["move"] as! String } == ["practice"] && actions?.first?["style"] as? String == "primary")
            #expect(actions?.first?["label"] as? String == "Play another word")
            let day = PlaytimeRecords.load()
            let tile = DailyWordScreen.tile()
            #expect(day.daily.streak == 1 && tile.map(\.seen) == ["Solved in 2"])
            #expect(PlaytimePage.render().games?.records[DailyWordScreen.id]?.today?.done == true, "the Game Center shows the day's word done")

            var practiced: [String] = []
            for round in 0..<3 {
                _ = GameTable.play(DailyWordScreen.self, .button("practice"), on: &s, random: &random)
                #expect(s.isPractice && s.game.rows.isEmpty && !s.game.over)
                // The word just drawn is the last in the practice list (the game keeps it sealed).
                let word = try #require(PlaytimeRecords.load().practiceWords?["en"]?.last)
                #expect(word != answer && !practiced.contains(word))
                practiced.append(word)
                let board = DailyWordScreen.board(s, events: [.turn(.you)], options: Self.options())
                #expect((Self.part(board, "prompt")?["eyebrow"] as? String) == "Practice word · not in your streak")
                #expect(Self.part(board, "keys") != nil)
                if round == 1 {
                    // Missed: six wrong words.
                    for w in Games.WordBank.daily(.en).filter({ $0 != word }).prefix(6) {
                        _ = GameTable.play(DailyWordScreen.self, .word(w), on: &s, random: &random)
                    }
                } else {
                    _ = GameTable.play(DailyWordScreen.self, .word(word), on: &s, random: &random)
                }
                #expect(s.game.over)
                let card = DailyWordScreen.board(s, events: [.reveal], options: Self.options())
                #expect((Self.part(card, "result")?["actions"] as? [[String: Any]])?.first?["move"] as? String == "practice")
            }
            let after = PlaytimeRecords.load()
            #expect(after.daily == day.daily && after.dailyGame == day.dailyGame && DailyWordScreen.tile() == tile, "the day untouched")
            #expect(after.games[DailyWordScreen.id] == day.games[DailyWordScreen.id])
            let practice = try #require(after.games[DailyWordScreen.practiceId])
            #expect(practice.played == 3 && practice.won == 2)
            #expect(after.practiceWords?["en"] == practiced)
            // Opened again: the day's own board, over, with practice one press away.
            let reopened = DailyWordEngine.start(level: .fair, options: Self.options(), random: &random)
            #expect(!reopened.isPractice && reopened.game.over && reopened.game.shown == answer)
        }
    }

    @Test func practiceWordsDontRepeatUntilTheListRunsOut() {
        for language in Games.Language.allCases {
            var rng = Games.Random(seed: 11)
            let day = 303
            let today = Games.DailyWord.answer(day: day, language: language)
            let count = Set(Games.WordBank.daily(language)).count - 1
            var played: [String] = []
            for _ in 0..<count {
                let (word, next) = Games.DailyWord.practiceWord(language: language, day: day, played: played, using: &rng)
                #expect(word != today && !played.contains(word), "\(language)")
                played = next
            }
            #expect(Set(played).count == count, "\(language): every word but the day's, once")
            let (word, restarted) = Games.DailyWord.practiceWord(language: language, day: day, played: played, using: &rng)
            #expect(word != today && restarted == [word], "\(language): then the list again")
            // A practice word plays like the day's, in its script.
            let game = Games.DailyWord(language: language, day: day, word: word)
            #expect(game.length == Games.WordBank.dailyLength(language) && game.shown == nil)
        }
    }

    // MARK: The table and the keyboards

    @Test func everyEventHasACueFromSidefolksLists() {
        let moves: Set<String> = ["think", "cheer", "celebrate", "sulk", "bow", "nod", "shrug", "giggle", "wince", "gasp", "tease", "sweat", "dizzy",
                                  "ready", "shuffle", "hop", "spin", "wave", "dance"]
        let effects: Set<String> = ["confetti", "sparkles", "hearts", "question", "exclaim", "sweat", "stars", "frost", "flame"]
        let lines: Set<String> = ["hello", "your_turn", "my_turn", "thinking", "close_one", "you_win", "i_win", "draw", "record", "streak", "encourage",
                                  "tease", "caught_cheating", "hint_intro", "bye"]
        let sounds: Set<String> = ["tap", "flip", "rattle", "pop", "ding", "boop", "tick", "whoosh", "stamp", "shuffle", "snap", "cork", "fanfare", "trombone"]
        let all: [Games.Event] = [.turn(.you), .turn(.companion), .think(ms: 900), .sealed, .reveal, .point(.you), .point(.companion),
                                  .roundOver(winner: .you), .roundOver(winner: .companion), .roundOver(winner: nil), .matchOver(winner: .you),
                                  .matchOver(winner: .companion), .matchOver(winner: nil), .streak(3), .streak(10), .newBest(4), .threat(.you),
                                  .threat(.companion), .fork(.you), .unbeatable, .hint, .tooSoon, .tooSlow, .mistake, .grew(3), .caught, .innocent,
                                  .confess, .higher, .lower, .contradiction, .found(guesses: 5), .hit(2), .miss(left: 3), .pair(.you),
                                  .noPair(.companion), .recalls, .learned, .forgot, .offerSecret, .lifeline(sure: true), .lifeline(sure: false),
                                  .opened, .refused("taken")]
        for event in all {
            guard let cue = EventCues.cue(for: event) else { Issue.record("\(event) has no reaction"); continue }
            #expect(cue.move.map(moves.contains) ?? true, "\(event)")
            #expect(cue.effect.map(effects.contains) ?? true, "\(event)")
            #expect(cue.line.map(lines.contains) ?? true, "\(event)")
            #expect(cue.sound.map(sounds.contains) ?? true, "\(event)")
        }
        // The weightiest wins: an ended match before the point that ended it, a point before a turn.
        #expect(EventCues.cue([.point(.you), .matchOver(winner: .you)])?.line == "you_win")
        #expect(EventCues.cue([.turn(.companion), .point(.companion)])?.move == "giggle")
        #expect(EventCues.cue([.matchOver(winner: .companion)])?.move == "celebrate" && EventCues.cue([.roundOver(winner: nil)])?.line == "draw")
        #expect(EventCues.animate([.pair(.you)]) == "flip" && EventCues.animate([.turn(.you)]) == "stamp")
    }

    @Test func keyboardsFitEachScript() {
        for language in Games.Language.allCases {
            for use in [Games.WordScript.Use.balloon, .daily] {
                let alphabet = Games.WordScript.alphabet(language, for: use)
                let keys = Keyboards.pages(language, for: use).flatMap { $0.rows.flatMap { $0 } }
                #expect(keys.sorted() == alphabet.sorted(), "\(language.key) \(use): every letter once")
                #expect(Keyboards.pages(language, for: use).allSatisfy { $0.rows.count <= 6 && $0.rows.allSatisfy { $0.count <= 14 } })
            }
        }
        #expect(Keyboards.pages(.de, for: .daily)[0].rows[0].last == "ü" && Keyboards.pages(.fr, for: .daily)[0].rows[0].first == "a")
        #expect(Keyboards.pages(.ja, for: .daily).map(\.label) == ["あ", "が", "ゃ"] && Keyboards.pages(.ja, for: .balloon).count == 1)
        #expect(Keyboards.pages(.ko, for: .daily)[0].rows[0].first == "ㅂ" && Keyboards.pages(.ar, for: .daily)[0].rows[0].first == "ض")
        #expect(Keyboards.pages(.zh, for: .daily).isEmpty, "Chinese idioms are typed with the input method")
        #expect(Keyboards.script(.ko) == "hangul" && Keyboards.script(.ar) == "arabic" && Keyboards.script(.ja) == "kana")
    }

    @Test func recordsKeepTalliesAndBests() {
        PlaytimeRecords.update { $0 = PlaytimeRecords() }
        PlaytimeRecords.finish("quick_paws", .won, you: 3, companion: 1, best: 250, lower: true)
        #expect(PlaytimeRecords.finish("quick_paws", .won, you: 3, companion: 2, best: 230, lower: true), "a quicker press is a new best")
        #expect(!PlaytimeRecords.finish("quick_paws", .lost, you: 1, companion: 3, best: 400, lower: true))
        let t = PlaytimeRecords.load().games["quick_paws"]!
        #expect(t.played == 3 && t.won == 2 && t.lost == 1 && t.best == 230 && t.bestStreak == 2 && t.streak == 0)
        for _ in 0..<12 { PlaytimeRecords.finish("tictactoe", .draw, you: 1, companion: 1) }
        #expect(PlaytimeRecords.load().history.count == 10)
    }

    // MARK: Boards for Sidefolk's UI snapshots

    /// With `PLAYTIME_SAMPLE_BOARDS=<folder>`, writes each game's boards (the bot's game, in each language asked by
    /// `PLAYTIME_SAMPLE_LANGUAGES`, English by default) as JSON for `SidefolkApp --ui-snapshots --game-boards`.
    @Test func writeSampleBoards() throws {
        guard let folder = ProcessInfo.processInfo.environment["PLAYTIME_SAMPLE_BOARDS"] else { return }
        let languages = (ProcessInfo.processInfo.environment["PLAYTIME_SAMPLE_LANGUAGES"] ?? "en").split(separator: ",").map(String.init)
        try SampleBoards.write(to: folder, languages: languages)
    }
}
