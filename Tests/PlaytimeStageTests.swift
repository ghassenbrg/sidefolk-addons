import Foundation
import Testing
@testable import SidefolkExtensionKit
@testable import ext_playtime

/// Every game's boards as the scenes the person sees (Sidefolk D101): what the app's reader would refuse, and the order of a result, are checked here on the boards the
/// bot really plays.
@Suite(.serialized) @MainActor
struct PlaytimeStageTests {
    static func entry(_ id: String) -> GameEntry { GameCatalog.entry(id)! }

    /// A scene as Sidefolk gets it: within its size and caps, and every key and area id a plain token.
    static func check(_ scene: Scene, _ context: String) throws {
        let data = try JSONSerialization.data(withJSONObject: scene.json)
        #expect(data.count <= 64 * 1024, "\(context): \(data.count) bytes")
        #expect(scene.height <= 676 && scene.width <= 720, "\(context): \(scene.height)")
        let token = #"^[a-z0-9][a-z0-9_-]{0,39}$"#
        for key in scene.keys {
            #expect((key["id"] as? String)?.range(of: token, options: .regularExpression) != nil, "\(context): \(key)")
        }
        for timer in scene.json["timers"] as? [[String: Any]] ?? [] {
            #expect((timer["id"] as? String)?.range(of: token, options: .regularExpression) != nil, "\(context): \(timer)")
        }
        // What it names is in the pack: a picture or a sound that isn't draws or plays nothing, and nothing says so.
        let assets = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("extensions/playtime/assets")
        let names = try NSRegularExpression(pattern: #"(art|sounds)\\?/[A-Za-z0-9_.-]+\.[a-z0-9]+"#)
        let text = String(decoding: data, as: UTF8.self)
        for match in names.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            let path = (text as NSString).substring(with: match.range).replacingOccurrences(of: "\\/", with: "/")
            #expect(FileManager.default.fileExists(atPath: assets.appendingPathComponent(path).path), "\(context): \(path)")
        }
        func visit(_ node: [String: Any]) {
            if let area = node["area"] as? [String: Any] {
                #expect((area["id"] as? String)?.range(of: token, options: .regularExpression) != nil, "\(context): \(area)")
                #expect((area["value"] as? String).map { $0.count <= 24 } ?? true, "\(context): \(area)")
                #expect(area["label"] as? String != nil, "\(context): an area without words isn't offered")
            }
            for child in node["children"] as? [[String: Any]] ?? [] { visit(child) }
        }
        (scene.json["nodes"] as? [[String: Any]] ?? []).forEach(visit)
        for run in scene.json["animations"] as? [[String: Any]] ?? [] {
            if let id = run["id"] as? String { #expect(id.range(of: token, options: .regularExpression) != nil, "\(context): \(id)") }
        }
    }

    /// Every board of a game the bot plays, and the build-up in front of any that needs one, gives nothing away and draws.
    func playAll<S: GameScreen>(_ screen: S.Type, seeds: [UInt64] = [1, 2, 3], language: String = "en") throws {
        try Language.with(language, strings: PlaytimeGameTests.strings) {
            for seed in seeds {
                PlaytimeRecords.update { $0 = PlaytimeRecords() }
                let boards = try PlaytimeScreensTests.play(S.self, seed: seed, language: language).boards
                var previous: Board?
                for board in boards {
                    if let (build, _) = Suspense.buildUp(from: previous, to: board, picked: nil) {
                        #expect(!Suspense.showsVerdict(build), "\(S.id): a build-up gives the result away")
                        var ctx = StageContext(entry: Self.entry(S.id), previous: previous)
                        ctx.buildUp = true
                        try Self.check(BoardDrawing(build, ctx).scene(), "\(S.id) build-up")
                    }
                    try Self.check(BoardDrawing(board, StageContext(entry: Self.entry(S.id), previous: previous)).scene(), S.id)
                    previous = board
                }
            }
        }
    }

    @Test func everyGamesBoardsAreScenesSidefolkTakes() throws {
        try playAll(TriviaScreen.self)
        try playAll(TicTacToeScreen.self)
        try playAll(CopyMeScreen.self)
        try playAll(QuickPawsScreen.self)
        try playAll(WhichCupScreen.self)
        try playAll(HigherLowerScreen.self)
        try playAll(GuessAnimalScreen.self)
        try playAll(BalloonWordsScreen.self)
        try playAll(LastStickScreen.self)
        try playAll(MemoryPairsScreen.self)
        try playAll(DailyWordScreen.self)
        try playAll(RockPaperScissorsScreen.self)
        try playAll(PuzzleScreen<GardenPlotsKind>.self)
        try playAll(PuzzleScreen<SeesawKind>.self)
        try playAll(PuzzleScreen<SudokuKind>.self)
        try playAll(PuzzleScreen<BlossomsKind>.self)
    }

    /// Timed trivia: the clock's name is a token Sidefolk takes, though a question's id has a dot in it; without one, no time ever ran out.
    @Test func timedTriviasClockIsAToken() throws {
        try Language.with("en", strings: PlaytimeGameTests.strings) {
            var random = Games.Random(seed: 1)
            var state = TriviaScreen.Engine.start(level: .fair, options: PlaytimeScreensTests.options(), random: &random)
            _ = GameTable.play(TriviaScreen.self, .choice(name: "pace", value: "quick"), on: &state, random: &random)
            let events = GameTable.play(TriviaScreen.self, .button("start"), on: &state, random: &random)
            let board = TriviaScreen.board(state, events: events, options: PlaytimeScreensTests.options())
            let scene = BoardDrawing(board, StageContext(entry: Self.entry(TriviaScreen.id))).scene()
            try Self.check(scene, "timed trivia")
            let timers = scene.json["timers"] as? [[String: Any]] ?? []
            #expect(timers.count == 1 && timers[0]["ms"] as? Double == 15000)
            var parts = LocalParts()
            guard case .play(.timeout) = StageMoves.action(.timer(timers[0]["id"] as! String), board: board, local: &parts) else {
                Issue.record("time running out is the game's timeout")
                return
            }
        }
    }

    /// A digit on a taken cell still reaches the game, which says it's taken; a free one presses its cell.
    @Test func aNumpadDigitOnATakenCell() throws {
        var random = Games.Random(seed: 1)
        var state = TicTacToeScreen.Engine.start(level: .fair, options: PlaytimeScreensTests.options(), random: &random)
        let first = TicTacToeScreen.board(state, events: [], options: PlaytimeScreensTests.options())
        let empty = BoardDrawing(first, StageContext(entry: Self.entry(TicTacToeScreen.id))).scene()
        #expect((empty.keys.first { $0["id"] as? String == "numpad_5" })?["area"] as? String == "cell")
        _ = GameTable.play(TicTacToeScreen.self, .cell(row: 1, column: 1), on: &state, random: &random)
        var board = TicTacToeScreen.board(state, events: [], options: PlaytimeScreensTests.options())
        for _ in 0..<4 where board.gridPart?.locked == true {
            _ = GameTable.play(TicTacToeScreen.self, .next, on: &state, random: &random)
            board = TicTacToeScreen.board(state, events: [], options: PlaytimeScreensTests.options())
        }
        let taken = BoardDrawing(board, StageContext(entry: Self.entry(TicTacToeScreen.id))).scene()
        let key = try #require(taken.keys.first { $0["id"] as? String == "numpad_5" })
        #expect(key["area"] == nil, "no press of a taken cell's area")
        var parts = LocalParts()
        guard case .play(.cell(row: 1, column: 1)) = StageMoves.action(.key(id: "numpad_5", character: nil, ms: nil), board: board, local: &parts) else {
            Issue.record("it goes to the game")
            return
        }
    }

    /// A card turned over is another kind of node, so it has another id, or Sidefolk's layer would stay what it was and draw nothing.
    @Test func aMarkHasAnIdOfItsKind() throws {
        func ids(_ cell: Cell) -> String {
            let board = Board([.board(rows: 1, columns: 1, cells: [cell])])
            let scene = BoardDrawing(board, StageContext(entry: Self.entry(MemoryPairsScreen.id))).scene()
            return String(data: try! JSONSerialization.data(withJSONObject: scene.json), encoding: .utf8)!
        }
        #expect(ids(Cell("card_back")).contains("cell.0.0.mark.card_back"))
        #expect(ids(Cell("symbol", value: "moon.fill")).contains("cell.0.0.mark.symbol"))
    }


    @Test func aLongLanguageAndOneThatReadsTheOtherWayFit() throws {
        for language in ["de", "ar", "ja"] {
            try playAll(HigherLowerScreen.self, seeds: [1], language: language)
            try playAll(PuzzleScreen<SudokuKind>.self, seeds: [1], language: language)
            try playAll(PuzzleScreen<GardenPlotsKind>.self, seeds: [1], language: language)
        }
    }

    @Test func theTablePropsFitInALongLanguageAndOneThatReadsTheOtherWay() throws {
        for language in ["de", "ar", "ja"] {
            try playAll(WhichCupScreen.self, seeds: [1], language: language)
            try playAll(CopyMeScreen.self, seeds: [1], language: language)
            try playAll(QuickPawsScreen.self, seeds: [1], language: language)
            try playAll(LastStickScreen.self, seeds: [1], language: language)
        }
    }

    private static func json(_ scene: Scene) -> String {
        String(decoding: try! JSONSerialization.data(withJSONObject: scene.json, options: [.sortedKeys, .withoutEscapingSlashes]), as: UTF8.self)
    }

    private static func node(_ id: String, in scene: Scene) -> [String: Any]? {
        func visit(_ list: [[String: Any]]) -> [String: Any]? {
            for n in list {
                if n["id"] as? String == id { return n }
                if let found = visit(n["children"] as? [[String: Any]] ?? []) { return found }
            }
            return nil
        }
        return visit(scene.json["nodes"] as? [[String: Any]] ?? [])
    }

    private static func run(_ id: String, in scene: Scene) -> [String: Any]? {
        (scene.json["animations"] as? [[String: Any]] ?? []).first { $0["id"] as? String == id }
    }

    private static let cups = Board([.prompt("Which cup?", eyebrow: "Round 1"), .play(.cups(count: 3, hide: 0, swaps: [[0, 1], [1, 2]], swapMs: 400))])

    /// What a scene shows for a board the way the table draws it: settled, as a new board is.
    private func drawn(_ board: Board, _ id: String, local: inout LocalParts, previous: Board? = nil, fresh: Bool = true) -> Scene {
        StageMoves.settle(board, local: &local)
        return BoardDrawing(board, StageContext(entry: Self.entry(id), previous: previous, fresh: fresh, local: local)).scene()
    }

    @Test func aShuffleIsOneRunThatHoldsMovesThenTheBoardRests() throws {
        var local = LocalParts()
        let playing = drawn(Self.cups, WhichCupScreen.id, local: &local)
        let run = try #require(Self.run("cups_shuffle", in: playing))
        #expect(run["essential"] as? Bool == true && run["blocks_input"] as? Bool == true, "the swaps are the game, under Reduce Motion too")
        #expect(Self.json(playing).contains("Keep your eye") && Self.json(playing).contains("thinking"), "it says what it is doing")
        #expect(playing.json["after_ms"] as? Int ?? 0 >= BoardDrawing.cupsOpenMs + 2 * (400 + BoardDrawing.swapRestMs) - 100, "the gem's moment and two swaps with their rests")
        // Named by where it ends, starting where it starts: cup 0 goes 0 → 1 → 2, so it is the node at place 2, at the first slot.
        let cup = try #require(Self.node("cup.2", in: playing))
        let firstSlot = 6 + (BoardDrawing.inner - 12) / 3 * 0.5 - 48
        #expect(abs((cup["x"] as? Double ?? 0) - firstSlot) < 0.02)
        #expect(cup["area"] == nil && playing.keys.allSatisfy { $0["area"] as? String != "cell" }, "nothing to press while they move")
        #expect(Self.node("cups.gem", in: playing) != nil)
        // The companion's paw checked mid-shuffle: the same run carries on, with the time it has left.
        let same = Board([.prompt("Nothing in my paw!", eyebrow: "Round 1"), .play(.cups(count: 3, hide: 0, swaps: [[0, 1], [1, 2]], swapMs: 400))])
        let startedAt = local.playback?.startedAt
        let carried = drawn(same, WhichCupScreen.id, local: &local, previous: Self.cups)
        #expect(local.playback?.startedAt == startedAt && Self.json(carried).contains("cups_shuffle") && Self.json(carried).contains("Keep your eye"))
        // Its time up, the same board at rest: the game's words, each cup at its place, no gem, a move of its own.
        local.playback?.startedAt -= 10
        guard case .redraw? = BoardDrawing.cupsMove(.next, board: same, local: &local) else {
            Issue.record("the scene's time up only redraws")
            return
        }
        let rest = BoardDrawing(same, StageContext(entry: Self.entry(WhichCupScreen.id), previous: same, fresh: false, local: local)).scene()
        #expect(Self.run("cups_shuffle", in: rest) == nil && Self.node("cups.gem", in: rest) == nil && rest.json["after_ms"] == nil)
        #expect(!Self.json(rest).contains("Keep your eye") && Self.json(rest).contains("Nothing in my paw!"))
        for place in 0..<3 {
            let x = try #require(Self.node("cup.\(place)", in: rest)?["x"] as? Double)
            #expect(abs(x - (6 + (BoardDrawing.inner - 12) / 3 * (Double(place) + 0.5) - 48)) < 0.02)
        }
        #expect(Self.node("cups", in: rest)?["ltr"] as? Bool == true, "the table reads the same in every language")
    }

    @Test func thePropsTakeTheirKeysAndAreasAsTheBoardsMoves() throws {
        var local = LocalParts()
        local.playback = Playback(what: "done", ms: 0, startedAt: 0, done: true)
        let cups = Board([.play(.cups(count: 3))])
        let rest = BoardDrawing(cups, StageContext(entry: Self.entry(WhichCupScreen.id), local: local)).scene()
        #expect(rest.keys.contains { $0["key"] as? String == "3" && $0["value"] as? String == "0,2" && $0["area"] as? String == "cell" })
        func cup(_ move: SurfaceMove) -> StageAction { StageMoves.action(move, board: cups, local: &local) }
        guard case .redraw = cup(.key(id: "arrow_right", character: nil, ms: nil)), local.cursor == 0, case .redraw = cup(.key(id: "arrow_right", character: nil, ms: nil)), local.cursor == 1,
              case .play(.cell(row: 0, column: 1)) = cup(.key(id: "cursor_return", character: nil, ms: nil)), case .play(.cell(row: 0, column: 2)) = cup(.click(area: "cell", value: "0,2", ms: nil)) else {
            Issue.record("arrows and Return and a click pick a cup")
            return
        }
        Language.with("ar", strings: PlaytimeGameTests.strings) {
            local.cursor = 1
            _ = StageMoves.action(.key(id: "arrow_right", character: nil, ms: nil), board: cups, local: &local)
            #expect(local.cursor == 2, "the cups lie the same way in Arabic, so the arrows move as they point")
        }

        local = LocalParts()
        let pads = Board([.play(.pads([Pad("Wave", shape: "circle", color: "blue", move: "accent:wave", art: "wave"), Pad("Bow", shape: "square", color: "red", move: "accent:bow", art: "bow")]))])
        guard case .play(.pad(1)) = StageMoves.action(.click(area: "pad", value: "1", ms: nil), board: pads, local: &local), local.lit == 1 else {
            Issue.record("a pad is its move, and lights")
            return
        }
        let lit = BoardDrawing(pads, StageContext(entry: Self.entry(CopyMeScreen.id), local: local)).scene()
        #expect(Self.json(lit).contains("pad.1.glow") && !Self.json(lit).contains("pads_play") && lit.keys.contains { $0["key"] as? String == "2" && $0["value"] as? String == "1" })
        #expect(Self.json(lit).contains("sounds/note-1.wav"), "its note on the press itself")
        _ = StageMoves.action(.next, board: pads, local: &local)
        #expect(local.lit == nil, "once")

        local = LocalParts()
        let sticks = Board([.play(.sticks(total: 21, left: 14, take: 3, taken: 3))])
        let row = BoardDrawing(sticks, StageContext(entry: Self.entry(LastStickScreen.id), local: local)).scene()
        guard case .play(.number(2)) = StageMoves.action(.click(area: "stick", value: "2", ms: nil), board: sticks, local: &local),
              case .play(.number(3)) = StageMoves.action(.click(area: "take", value: "3", ms: nil), board: sticks, local: &local) else {
            Issue.record("a stick or a button takes that many")
            return
        }
        // Only the last three can be taken, and hovering one lifts it and those after it.
        let area = try #require(Self.node("stick.11", in: row)?["area"] as? [String: Any])
        #expect(area["value"] as? String == "3" && (area["highlight"] as? [[String: Any]])?.count == 3)
        #expect(Self.node("stick.10", in: row)?["area"] == nil && Self.node("stick.14", in: row)?["area"] == nil)
        #expect(Self.node("sticks", in: row)?["ltr"] as? Bool == true)
        let locked = BoardDrawing(Board([.play(.sticks(total: 21, left: 14, locked: true))]), StageContext(entry: Self.entry(LastStickScreen.id))).scene()
        #expect(!Self.json(locked).contains("\"take\"") && locked.keys.allSatisfy { ($0["area"] as? String) != "take" })
    }

    @Test func theSignalIsOneMomentOfTheSceneAndAPressIsTimedFromIt() throws {
        func reflex(_ after: Int?, shows: String? = nil, keys: [String]? = nil) -> Board {
            Board([.play(.reflex(afterMs: after, windowMs: 1500, wait: "Steady…", go: "Boop!", early: "Too soon!", shows: shows, keys: keys))])
        }
        var local = LocalParts()
        let armed = BoardDrawing(reflex(2300), StageContext(entry: Self.entry(QuickPawsScreen.id))).scene()
        let signal = try #require(Self.run("reflex_signal", in: armed))
        #expect(signal["essential"] as? Bool == true, "the signal comes under Reduce Motion too")
        #expect((armed.timers.first?["ms"] as? Double) == 3800, "its wait and its window")
        #expect(armed.keys.contains { $0["key"] as? String == "space" && $0["timed_from_ms"] as? Double == 2300 })
        #expect((Self.node("reflex.press", in: armed)?["area"] as? [String: Any])?["timed_from_ms"] as? Double == 2300)
        let board = reflex(2300)
        guard case .play(.press(milliseconds: 312)) = StageMoves.action(.click(area: "boop", value: nil, ms: 312), board: board, local: &local), !local.early,
              case .play(.early) = StageMoves.action(.click(area: "boop", value: nil, ms: -40), board: board, local: &local), local.early else {
            Issue.record("after the moment a time, before it too soon")
            return
        }
        // Too soon is said at once, with its mark, and only until the verdict's moment.
        let withheld = reflex(nil)
        let soon = BoardDrawing(withheld, StageContext(entry: Self.entry(QuickPawsScreen.id), previous: board, local: local)).scene()
        #expect(Self.json(soon).contains("Too soon!") && Self.json(soon).contains(Verdict.loss.symbol) && !Self.json(soon).contains("reflex_signal"))
        _ = StageMoves.action(.next, board: withheld, local: &local)
        #expect(!local.early)
        var build = StageContext(entry: Self.entry(QuickPawsScreen.id), previous: board)
        build.buildUp = true
        let pressed = BoardDrawing(withheld, build).scene()
        #expect(Self.json(pressed).contains("reflex.went") && Self.json(pressed).contains("…"), "a press ends the signal: it goes as it came, and the verdict waits")
        // Two people: a key each by where it sits, no click.
        let two = BoardDrawing(reflex(1800, keys: ["a", "l"]), StageContext(entry: Self.entry(QuickPawsScreen.id))).scene()
        #expect(Self.node("reflex.press", in: two)?["area"] == nil)
        #expect(two.keys.contains { $0["id"] as? String == "seat_a" && $0["seat"] as? Bool == true && $0["timed_from_ms"] as? Double == 1800 })
        guard case .play(.pressKey(milliseconds: 200, key: "l")) = StageMoves.action(.key(id: "seat_l", character: nil, ms: 200), board: board, local: &local),
              case .play(.earlyKey("a")) = StageMoves.action(.key(id: "seat_a", character: nil, ms: -1), board: board, local: &local) else {
            Issue.record("whose key, and when")
            return
        }
    }

    @Test func aDanceIsOneRunOfLightsAndNotesAndComesBackWithItsGame() throws {
        let pads = (0..<4).map { Pad("P\($0)", shape: "circle", color: "blue", move: "accent:wave", art: "wave") }
        let board = Board([.play(.pads(pads, play: [2, 0, 2], stepMs: 500))])
        #expect(board.plays?.ms == BoardDrawing.padsLeadMs + 3 * 500)
        var local = LocalParts()
        let scene = drawn(board, CopyMeScreen.id, local: &local)
        let run = try #require(Self.run("pads_play", in: scene))
        #expect(run["essential"] as? Bool == true && run["blocks_input"] as? Bool == true)
        let text = Self.json(scene)
        for sound in ["sounds/note-2.wav", "sounds/note-0.wav", "accent:wave", "Watch"] { #expect(text.contains(sound), "\(sound)") }
        // Ended, at rest; a game come back to dances again, so it can still be copied.
        local.playback?.startedAt -= 10
        _ = StageMoves.action(.next, board: board, local: &local)
        #expect(local.playback?.done == true)
        let rest = BoardDrawing(board, StageContext(entry: Self.entry(CopyMeScreen.id), previous: board, fresh: false, local: local)).scene()
        #expect(Self.run("pads_play", in: rest) == nil && !Self.json(rest).contains("Watch"))
        Playback.cameBack(board, local: &local)
        #expect(local.playback?.done == false)
        // A shuffle that ended doesn't.
        var cupsLocal = LocalParts()
        StageMoves.settle(Self.cups, local: &cupsLocal)
        cupsLocal.playback?.done = true
        Playback.cameBack(Self.cups, local: &cupsLocal)
        #expect(cupsLocal.playback?.done == true)
        // A long dance outlasts one `after`: it asks again, and the run carries on.
        let long = Board([.play(.pads(pads, play: Array(repeating: 1, count: 30), stepMs: 500))])
        var longLocal = LocalParts()
        #expect(drawn(long, CopyMeScreen.id, local: &longLocal).json["after_ms"] as? Int == 10_000)
        longLocal.playback?.startedAt -= 10
        guard case .redraw = StageMoves.action(.next, board: long, local: &longLocal), longLocal.playback?.done == false else {
            Issue.record("more to play")
            return
        }
    }

    @Test func thePropsTakeTheLongestRoundsSidefolkWouldDraw() throws {
        // A reply has 64 KB. Fourteen swaps is the most any level draws (Hard's last round); a dance can reach 64 moves.
        var local = LocalParts()
        let swaps = (0..<14).map { [$0 % 5, ($0 + 1) % 5] }
        let scene = drawn(Board([.play(.cups(count: 5, hide: 1, swaps: swaps, swapMs: 200))]), WhichCupScreen.id, local: &local)
        try Self.check(scene, "cups")
        var pads = LocalParts()
        let dance = drawn(Board([.play(.pads((0..<5).map { Pad("P\($0)", shape: "circle", color: "blue", move: "accent:wave", art: "wave") }, play: (0..<64).map { $0 % 5 }, stepMs: 280))]), CopyMeScreen.id, local: &pads)
        try Self.check(dance, "pads")
    }

    @Test func aMoveOnASceneIsTheBoardsMove() {
        var local = LocalParts()
        let field = Board([.play(.number(min: 1, max: 100, label: nil, history: [], locked: false))])
        func action(_ move: SurfaceMove, _ board: Board) -> StageAction { StageMoves.action(move, board: board, local: &local) }
        guard case .redraw = action(.key(id: "digit", character: "4", ms: nil), field), case .redraw = action(.click(area: "digit", value: "2", ms: nil), field) else {
            Issue.record("digits only change what is typed")
            return
        }
        #expect(local.draft == "42")
        guard case .ignore = action(.key(id: "digit", character: "9", ms: nil), Board([.play(.number(min: 1, max: 42, label: nil, history: [], locked: true))])) else {
            Issue.record("a locked field takes nothing")
            return
        }
        guard case .play(.number(42)) = action(.key(id: "draft_return", character: nil, ms: nil), field) else {
            Issue.record("Return sends the number")
            return
        }
        guard case .play(.answer(2)) = action(.click(area: "answer", value: "2", ms: nil), field), case .play(.cell(row: 1, column: 2)) = action(.click(area: "cell", value: "1,2", ms: nil), field),
              case .play(.button("again")) = action(.click(area: "button", value: "again", ms: nil), field),
              case .play(.choice(name: "top", value: "10")) = action(.click(area: "choice", value: "top|10", ms: nil), field),
              case .back = action(.back, field), case .play(.timeout) = action(.timer("round"), field), case .play(.next) = action(.next, field) else {
            Issue.record("each area is its move")
            return
        }
        // A wide range's digits in another script count as digits.
        local = LocalParts()
        _ = action(.key(id: "digit", character: "٣", ms: nil), field)
        #expect(local.draft == "3")
        // A refused number stays to be fixed; a judged one clears.
        local.guessesSeen = 0
        StageMoves.settle(Board([.play(.number(min: 1, max: 100, label: nil, history: [], locked: false))]), local: &local)
        #expect(local.draft == "3")
        StageMoves.settle(Board([.play(.number(min: 1, max: 100, label: nil, history: [(3, "higher")], locked: false))]), local: &local)
        #expect(local.draft.isEmpty)
    }

    @Test func aPickWaitsPressedAndNothingIsJudgedBeforeTheBeat() throws {
        let before = Board([.prompt("Which?"), .score(you: 0, companion: 0), .answers([Tile("A"), Tile("B")])])
        let after = Board([.prompt("Right!"), .score(you: 1, companion: 0), .answers([Tile("A", state: .right, companion: true), Tile("B", state: .faded)], locked: true),
                           .note("A fact."), .result(figure: "1", tone: .good, actions: [ScreenKit.playAgain])], companion: Cue(move: "bow"), over: true)
        let (build, ms) = try #require(Suspense.buildUp(from: before, to: after, picked: 0))
        #expect(ms == Suspense.beatMs && !Suspense.showsVerdict(build) && build.scorePart?.you == 0 && build.promptPart?.text == "Which?")
        #expect(build.answersPart?.tiles.first?.state == .picked && build.answersPart?.tiles.first?.companion == false)
    }

    @Test func neverRedForALossAndNeverColourAlone() throws {
        let board = Board([.result(figure: "1 – 3", tone: .bad, actions: [ScreenKit.playAgain])], over: true)
        let json = String(decoding: try JSONSerialization.data(withJSONObject: BoardDrawing(board, StageContext(entry: Self.entry(TicTacToeScreen.id))).scene().json), as: UTF8.self)
        for red in ["FF0000", "FF3B30", "D70015"] { #expect(!json.uppercased().contains(red)) }
        #expect(json.contains("art/result-loss.webp") || json.contains("art\\/result-loss.webp"), "a loss has its own quiet mark, beside the words that say it")
    }

    @Test func aPackFromTheAIIsCheckedHere() {
        func good(_ i: Int) -> [String: Any] { ["question": "Which volcano is number \(i)?", "choices": ["Etna", "Fuji", "Hekla", "Kilauea"], "answer": i % 4, "difficulty": 2] }
        func text(_ list: [[String: Any]], topic: String = "volcanoes") -> String {
            String(decoding: try! JSONSerialization.data(withJSONObject: ["topic": topic, "questions": list]), as: UTF8.self)
        }
        #expect(TriviaPackCheck.parse("not json", count: 10, topic: "x") == .failure(.notJSON))
        #expect(TriviaPackCheck.parse(text([]), count: 10, topic: "x") == .failure(.declined))
        let bad = (0..<10).map { i -> [String: Any] in var q = good(i); q["question"] = "See https://example.com \(i)?"; return q }
        #expect(TriviaPackCheck.parse(text(bad), count: 10, topic: "x") == .failure(.tooFew(0)), "links make it unusable")
        guard case .success(let pack) = TriviaPackCheck.parse(text((0..<12).map(good)), count: 10, topic: "") else {
            Issue.record("a good pack")
            return
        }
        #expect(pack.topic == "volcanoes" && pack.questions.count == 10, "the AI names a topic left to it")
    }

    @Test func whatTheAppKeptArrivesOnce() throws {
        PlaytimeRecords.update { $0 = PlaytimeRecords() }
        let rows: [[String: Any]] = [["at": "2026-11-01T10:00:00Z", "summary": "x", "args": ["extension": "dev.sidefolk.playtime", "game": "trivia", "result": "win"]],
                                     ["at": "2026-10-31T10:00:00Z", "summary": "y", "args": ["extension": "dev.sidefolk.playtime", "game": "trivia", "result": "loss"]],
                                     ["at": "2026-10-30T10:00:00Z", "summary": "z", "args": ["extension": "dev.other", "game": "chess", "result": "win"]]]
        let reply = PlaytimeCarry.receive(Arguments(["tone": "gentle", "sneaky": true, "sounds": false, "speakers": ["dev.sidefolk.playtime/sudoku": true],
                                                     "levels": ["dev.sidefolk.playtime/tictactoe": "hard"], "players": ["Ana", "Sam"], "aiTrivia": false]),
                                          store: [:], history: ["games.play": rows])
        let settings = try #require(reply["settings"] as? [String: Any])
        #expect(settings["tone"] as? String == "gentle" && settings["sneaky"] as? Bool == true && settings["sound_sudoku"] as? Bool == true && settings["sound_trivia"] == nil, "only what was pressed in a game: the others follow sounds")
        #expect(settings["level_tictactoe"] as? String == "hard" && reply["ai"] as? Bool == false)
        let r = PlaytimeRecords.load()
        #expect(r.players == ["Ana", "Sam"] && r.stats.played == 2 && r.stats.wins == 1 && r.stats.streak == 1, "only its own games, the newest first")
    }

    @Test func thePageIsTheCenter() throws {
        PlaytimeRecords.update { $0 = PlaytimeRecords() }
        let page = PlaytimePage.render()
        let json = String(decoding: try JSONSerialization.data(withJSONObject: page.json, options: .withoutEscapingSlashes), as: UTF8.self)
        for kind in ["\"scene\"", "\"cards\"", "\"badges\"", "\"settings\""] { #expect(json.contains(kind), "\(kind)") }
        #expect(json.contains("art/game-icon-numbers.webp") && json.contains("level_tictactoe"), "its own art, its own settings")
    }

    @Test func theManifestAndTheCatalogAgree() throws {
        let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("extensions/playtime")
        let m = try JSONSerialization.jsonObject(with: Data(contentsOf: folder.appendingPathComponent("sidefolk-extension.json"))) as! [String: Any]
        #expect(m["games"] == nil, "no game channel any more")
        let commands = ((m["tools"] as! [String: [String: Any]])["open"]!["commands"] as! [[String: Any]]).compactMap { $0["name"] as? String }
        let settings = (m["settings"] as! [[String: Any]]).compactMap { $0["key"] as? String }
        for game in GameCatalog.all {
            #expect(GameTable.drivers[game.id] != nil && commands.contains(game.id), "\(game.id)")
            #expect(settings.contains(GameSoundSetting.key(game.id)), "\(game.id)")
            if game.levels { #expect(settings.contains(GameSoundSetting.levelKey(game.id)), "\(game.id)") }
            #expect(FileManager.default.fileExists(atPath: folder.appendingPathComponent("assets/\(game.look.icon)").path), "\(game.id)")
            #expect(FileManager.default.fileExists(atPath: folder.appendingPathComponent("assets/\(game.look.scene)").path), "\(game.id)")
        }
    }
}
