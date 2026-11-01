import Foundation
import Testing
@testable import SidefolkExtensionKit
@testable import ext_playtime

/// Two people on one Mac (Sidefolk D96) and trivia made by the person's AI (D95), through the screens as Sidefolk
/// plays them: names, turns, secrets that never show before their reveal, two keys on one button, records kept apart,
/// and packs that arrive, fail, or never come.
@Suite(.serialized) struct PlaytimeTwoPlayersTests {
    init() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("playtime-duo-\(UUID().uuidString)").path
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        setenv("SIDEFOLK_DATA_DIR", dir, 1)
    }

    static func two() -> GameOptions {
        var o = PlaytimeScreensTests.options()
        o.twoPlayers = true
        o.names = ["Ana", "Sam"]
        return o
    }

    static func text(_ b: Board) -> String {
        String(data: try! JSONSerialization.data(withJSONObject: b.json), encoding: .utf8)!
    }

    /// Plays a two-player game with moves a pair would make: names kept, every cover passed, a word or number set.
    @discardableResult
    static func duel<S: GameScreen>(_ screen: S.Type, seed: UInt64, limit: Int = 800) throws -> [Board] {
        var random = Games.Random(seed: seed)
        var state = S.Engine.start(level: .fair, options: two(), random: &random)
        var board = S.board(state, events: [.opened], options: two())
        var boards = [board]
        for step in 0..<limit where !board.over {
            let ps = PlaytimeScreensTests.parts(board)
            let move: Move?
            if let e = ps.first(where: { $0["type"] as? String == "entry" }), e["name"] as? String == "word" {
                move = .text(name: "word", value: "lantern")
            } else if let r = ps.first(where: { $0["type"] as? String == "reflex" }), r["after_ms"] != nil, r["shows"] == nil,
                      let keys = r["keys"] as? [String] {
                move = .pressKey(milliseconds: 200 + step % 50, key: keys[step % 2])
            } else if board.json["after_ms"] == nil, let g = ps.first(where: { $0["type"] as? String == "board" }), g["locked"] as? Bool != true,
                      let cells = g["cells"] as? [[String: Any]], cells.contains(where: { $0["mark"] as? String == "card_back" }) {
                // Memory: two people who don't remember, turning cards about the grid until the pairs are found.
                let backs = cells.indices.filter { cells[$0]["mark"] as? String == "card_back" }
                let i = backs[(step * 7) % backs.count]
                move = .cell(row: i / 4, column: i % 4)
            } else if ps.contains(where: { $0["type"] as? String == "button" && $0["move"] as? String == "players_ready" }) {
                move = .button("players_ready")
            } else {
                move = PlaytimeScreensTests.botMove(board, step: step)
            }
            guard let move else { break }
            let events = GameTable.play(S.self, move, on: &state, random: &random)
            board = S.board(state, events: events, options: two())
            boards.append(board)
        }
        return boards
    }

    @Test func everyGameForTwoPlaysToItsEndWithNamesAndAReferee() throws {
        let games: [(String, () throws -> [Board])] = [
            (TicTacToeScreen.id, { try Self.duel(TicTacToeScreen.self, seed: 1) }),
            (LastStickScreen.id, { try Self.duel(LastStickScreen.self, seed: 2) }),
            (MemoryPairsScreen.id, { try Self.duel(MemoryPairsScreen.self, seed: 3) }),
            (CopyMeScreen.id, { try Self.duel(CopyMeScreen.self, seed: 4) }),
            (TriviaScreen.id, { try Self.duel(TriviaScreen.self, seed: 5) }),
            (QuickPawsScreen.id, { try Self.duel(QuickPawsScreen.self, seed: 6) }),
            (WhichCupScreen.id, { try Self.duel(WhichCupScreen.self, seed: 7) }),
            (HigherLowerScreen.id, { try Self.duel(HigherLowerScreen.self, seed: 8) }),
            (BalloonWordsScreen.id, { try Self.duel(BalloonWordsScreen.self, seed: 9) }),
        ]
        #expect(Set(games.map(\.0)) == TwoPlayers.games)
        for (id, play) in games {
            let boards = try play()
            let end = try #require(boards.last)
            #expect(end.over, "\(id) reached its end: \(Self.text(end).prefix(600))")
            let score = PlaytimeScreensTests.part(end, "score")
            #expect(score?["players"] as? [String] == ["Ana", "Sam"], "\(id) names both")
            let result = PlaytimeScreensTests.part(end, "result")
            #expect(["neutral", "info"].contains(result?["tone"] as? String), "\(id): a colour for who, not for a loss")
            for b in boards {
                let line = (b.json["companion"] as? [String: Any])?["line"] as? String
                #expect(line != "i_win" && line != "you_win", "\(id): the companion never takes a side")
            }
            #expect(PlaytimeRecords.load().duels?[id]?["Ana · Sam"] != nil, "\(id) keeps their head-to-head")
        }
        #expect(PlaytimeRecords.load().games.isEmpty, "no game against the companion was counted")
    }

    @Test func turnsAlternateAndNamesAreTyped() throws {
        var random = Games.Random(seed: 1)
        var s = TicTacToeEngine.start(level: .hard, options: Self.two(), random: &random)
        _ = GameTable.play(TicTacToeScreen.self, .text(name: "player1", value: "  Lina  "), on: &s, random: &random)
        _ = GameTable.play(TicTacToeScreen.self, .text(name: "player2", value: "Omar"), on: &s, random: &random)
        #expect(s.duo.names == ["Lina", "Omar"] && s.duo.playing && PlaytimeRecords.load().players == ["Lina", "Omar"])
        _ = GameTable.play(TicTacToeScreen.self, .cell(row: 1, column: 1), on: &s, random: &random)
        _ = GameTable.play(TicTacToeScreen.self, .cell(row: 0, column: 0), on: &s, random: &random)
        #expect(s.game.cells[4] == .you && s.game.cells[0] == .companion, "X, then O: no companion move in between")
        let board = TicTacToeScreen.board(s, events: [], options: Self.two())
        #expect(board.afterMs == nil && (PlaytimeScreensTests.part(board, "prompt")?["text"] as? String)?.seen.hasPrefix("Lina's turn") == true)
        // Back to the companion only before anything was played.
        #expect(GameTable.play(TicTacToeScreen.self, .choice(name: "opponent", value: "companion"), on: &s, random: &random) == [.refused("not_now")])
    }

    @Test func aHiddenNumberNeverShowsBeforeItIsFound() throws {
        var random = Games.Random(seed: 2)
        var s = HigherLowerEngine.start(level: .fair, options: Self.two(), random: &random)
        _ = GameTable.play(HigherLowerScreen.self, .button("players_ready"), on: &s, random: &random)
        _ = GameTable.play(HigherLowerScreen.self, .button("ready"), on: &s, random: &random)
        let hiding = HigherLowerScreen.board(s, events: [], options: Self.two())
        #expect(PlaytimeScreensTests.part(hiding, "number") != nil)
        _ = GameTable.play(HigherLowerScreen.self, .number(73), on: &s, random: &random)
        let cover = HigherLowerScreen.board(s, events: [.sealed], options: Self.two())
        #expect(PlaytimeScreensTests.part(cover, "number") == nil && !Self.text(cover).contains("73"), "the cover hides it")
        _ = GameTable.play(HigherLowerScreen.self, .button("ready"), on: &s, random: &random)
        let guessing = HigherLowerScreen.board(s, events: [.turn(.companion)], options: Self.two())
        #expect(!Self.text(guessing).contains("73") && (PlaytimeScreensTests.part(guessing, "number")?["history"] as? [Any])?.isEmpty != false)
        let events = GameTable.play(HigherLowerScreen.self, .number(73), on: &s, random: &random)
        #expect(events.contains(.reveal) && s.duel?.guesses == [nil, 1], "Sam found Ana's number in one")
    }

    @Test func aHiddenWordNeverShowsBeforeItsEnd() throws {
        var random = Games.Random(seed: 3)
        var s = BalloonWordsEngine.start(level: .fair, options: Self.two(), random: &random)
        _ = GameTable.play(BalloonWordsScreen.self, .button("players_ready"), on: &s, random: &random)
        _ = GameTable.play(BalloonWordsScreen.self, .button("ready"), on: &s, random: &random)
        #expect(GameTable.play(BalloonWordsScreen.self, .text(name: "word", value: "a1"), on: &s, random: &random) == [.refused("not_letters")])
        _ = GameTable.play(BalloonWordsScreen.self, .text(name: "word", value: "Lantern"), on: &s, random: &random)
        _ = GameTable.play(BalloonWordsScreen.self, .button("ready"), on: &s, random: &random)
        let guessing = BalloonWordsScreen.board(s, events: [], options: Self.two())
        #expect(!Self.text(guessing).lowercased().contains("lantern"), "the word stays hidden")
        for l in ["l", "a", "n", "t", "e", "r"] { _ = GameTable.play(BalloonWordsScreen.self, .letter(l), on: &s, random: &random) }
        #expect(s.duel?.kept == [nil, 7] && s.duel?.stage == .solved)
    }

    @Test func twoKeysShareOneButtonFairly() throws {
        var random = Games.Random(seed: 4)
        var s = QuickPawsEngine.start(level: .fair, options: Self.two(), random: &random)
        #expect(s.round == nil, "the first round waits for the names")
        _ = GameTable.play(QuickPawsScreen.self, .button("players_ready"), on: &s, random: &random)
        let board = QuickPawsScreen.board(s, events: [], options: Self.two())
        #expect(PlaytimeScreensTests.part(board, "reflex")?["keys"] as? [String] == ["a", "l"])
        #expect(GameTable.play(QuickPawsScreen.self, .press(milliseconds: 200), on: &s, random: &random) == [.refused("not_now")],
                "a click can't say whose it was")
        _ = GameTable.play(QuickPawsScreen.self, .pressKey(milliseconds: 230, key: "l"), on: &s, random: &random)
        #expect(s.game.score.companion == 1 && s.lastWinner == .companion)
        _ = GameTable.play(QuickPawsScreen.self, .next, on: &s, random: &random)
        _ = GameTable.play(QuickPawsScreen.self, .earlyKey("l"), on: &s, random: &random)
        #expect(s.game.score.you == 1 && s.lastWinner == .you, "too soon gives the round to the other")
        _ = GameTable.play(QuickPawsScreen.self, .next, on: &s, random: &random)
        _ = GameTable.play(QuickPawsScreen.self, .timeout, on: &s, random: &random)
        #expect(s.game.score == Games.Score(you: 1, companion: 1), "nobody in time: nobody scores")
    }

    // MARK: Trivia made by the person's AI (D95)

    final class Sent: @unchecked Sendable { var calls: [(String, [String: Any])] = [] }

    static func ai() -> GameOptions {
        var o = PlaytimeScreensTests.options()
        o.aiTrivia = "Claude Code"
        return o
    }

    static func pack(_ id: String, choices: Int = 4) -> Arguments {
        let questions = (0..<10).map { i -> [String: Any] in
            ["question": "Which volcano is number \(i)?", "choices": Array(["Etna", "Fuji", "Hekla", "Kilauea"].prefix(choices)), "answer": i % 4,
             "fact": "Volcano \(i) is real.", "difficulty": 2]
        }
        return Arguments(["request": id, "ok": true, "topic": "volcanoes", "made_by": "Claude Code", "questions": questions])
    }

    @Test func aTopicOfYourOwnGetsFreshQuestions() throws {
        let sent = Sent()
        TriviaAI.send = { sent.calls.append(($0, $1)) }
        var random = Games.Random(seed: 6)
        var s = TriviaEngine.start(level: .hard, options: Self.ai(), random: &random)
        let setup = TriviaScreen.board(s, events: [.opened], options: Self.ai())
        #expect((PlaytimeScreensTests.part(setup, "choice")?["options"] as? [[String: Any]])?.contains { $0["value"] as? String == "surprise" } == true)
        _ = GameTable.play(TriviaScreen.self, .choice(name: "topic", value: "surprise"), on: &s, random: &random)
        let any = TriviaScreen.board(s, events: [], options: Self.ai())
        #expect(PlaytimeScreensTests.part(any, "entry")?["name"] as? String == "topic" && PlaytimeScreensTests.part(any, "choice")?["name"] as? String != "topic",
                "the field takes the topics' place")
        _ = GameTable.play(TriviaScreen.self, .text(name: "topic", value: "volcanoes"), on: &s, random: &random)
        let request = try #require(sent.calls.last)
        #expect(request.0 == "sidefolk/trivia.request" && request.1["topic"] as? String == "volcanoes" && request.1["level"] as? String == "hard")
        #expect(request.1["count"] as? Int == 10 && Set(request.1.keys) == ["request", "topic", "count", "level", "language"], "nothing else goes")
        let waiting = TriviaScreen.board(s, events: [.think(ms: 1500)], options: Self.ai())
        #expect(s.phase == .making && waiting.afterMs == TriviaEngine.checkMs)
        _ = GameTable.play(TriviaScreen.self, .next, on: &s, random: &random)
        #expect(s.phase == .making, "still waiting")
        TriviaAI.receive(Self.pack(request.1["request"] as! String))
        _ = GameTable.play(TriviaScreen.self, .next, on: &s, random: &random)
        #expect(s.phase == .question && s.made.count == 10 && s.madeTopic == "volcanoes")
        let question = TriviaScreen.board(s, events: [.sealed], options: Self.ai())
        #expect((PlaytimeScreensTests.part(question, "prompt")?["chip"] as? String) == "volcanoes")
        let q = try #require(TriviaEngine.question(s))
        _ = GameTable.play(TriviaScreen.self, .answer(TriviaEngine.rightTile(s)!), on: &s, random: &random)
        let answered = TriviaScreen.board(s, events: [.reveal], options: Self.ai())
        let fact = PlaytimeScreensTests.parts(answered).first { $0["type"] as? String == "note" }
        #expect(fact?["text"] as? String == q.fact && (fact?["title"] as? String)?.seen.contains("not checked") == true, "the AI's facts say so")
    }

    @Test func noPackFallsBackToTheBank() throws {
        TriviaAI.send = { _, _ in }
        var random = Games.Random(seed: 7)
        // Refused by Sidefolk: back to the topics, with why, and the bank as ever.
        var s = TriviaEngine.start(level: .fair, options: Self.ai(), random: &random)
        _ = GameTable.play(TriviaScreen.self, .text(name: "topic", value: "jazz"), on: &s, random: &random)
        TriviaAI.receive(Arguments(["request": s.asking!.id, "ok": false, "reason": "limit"]))
        _ = GameTable.play(TriviaScreen.self, .next, on: &s, random: &random)
        #expect(s.phase == .setup && s.notice == "limit")
        _ = GameTable.play(TriviaScreen.self, .button("start"), on: &s, random: &random)
        #expect(s.phase == .question && s.made.isEmpty && TriviaEngine.question(s) != nil)
        // Malformed: three choices each.
        var bad = TriviaEngine.start(level: .fair, options: Self.ai(), random: &random)
        _ = GameTable.play(TriviaScreen.self, .text(name: "topic", value: "jazz"), on: &bad, random: &random)
        TriviaAI.receive(Self.pack(bad.asking!.id, choices: 3))
        _ = GameTable.play(TriviaScreen.self, .next, on: &bad, random: &random)
        #expect(bad.phase == .setup && bad.notice == "unusable")
        // Never answered: after its patience, the same.
        var slow = TriviaEngine.start(level: .fair, options: Self.ai(), random: &random)
        _ = GameTable.play(TriviaScreen.self, .text(name: "topic", value: "jazz"), on: &slow, random: &random)
        for _ in 0..<TriviaEngine.patience { _ = GameTable.play(TriviaScreen.self, .next, on: &slow, random: &random) }
        #expect(slow.phase == .setup && slow.notice == "slow")
        // Without AI there is nothing to type a topic into, and a typed one is refused.
        var plain = TriviaEngine.start(level: .fair, options: PlaytimeScreensTests.options(), random: &random)
        #expect(PlaytimeScreensTests.part(TriviaScreen.board(plain, events: [.opened], options: PlaytimeScreensTests.options()), "entry") == nil)
        #expect(GameTable.play(TriviaScreen.self, .text(name: "topic", value: "jazz"), on: &plain, random: &random) == [.refused("not_now")])
    }

    @Test func aTopicNamedInWordsIsPickedOrMade() {
        TriviaAI.send = { _, _ in }
        var random = Games.Random(seed: 8)
        var o = Self.ai()
        o.topic = "Space"
        #expect(TriviaEngine.start(level: .fair, options: o, random: &random).topic == "space")
        o.topic = "volcanoes"
        #expect(TriviaEngine.start(level: .fair, options: o, random: &random).phase == .making)
        var plain = PlaytimeScreensTests.options()
        plain.topic = "volcanoes"
        #expect(TriviaEngine.start(level: .fair, options: plain, random: &random).phase == .setup)
    }

    @Test func aRangeNamedInWordsIsPlayed() throws {
        var random = Games.Random(seed: 9)
        var o = PlaytimeScreensTests.options()
        o.max = 1000
        let s = HigherLowerEngine.start(level: .fair, options: o, random: &random)
        #expect(s.range == 1...1000 && s.mode == nil && !s.custom)
        o.mode = "mine"
        o.min = 50
        o.max = 500
        let straight = HigherLowerEngine.start(level: .fair, options: o, random: &random)
        #expect(straight.range == 50...500 && straight.mine != nil && straight.custom)
        var t = HigherLowerEngine.start(level: .fair, options: PlaytimeScreensTests.options(), random: &random)
        _ = GameTable.play(HigherLowerScreen.self, .choice(name: "top", value: "other"), on: &t, random: &random)
        #expect(PlaytimeScreensTests.part(HigherLowerScreen.board(t, events: [], options: PlaytimeScreensTests.options()), "entry") != nil)
        _ = GameTable.play(HigherLowerScreen.self, .text(name: "top", value: "5,000"), on: &t, random: &random)
        #expect(t.range == 1...5000)
        #expect(GameTable.play(HigherLowerScreen.self, .text(name: "top", value: "lots"), on: &t, random: &random) == [.refused("bad_top")])
    }
}
