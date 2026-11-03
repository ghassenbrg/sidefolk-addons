import Foundation
import Testing
@testable import SidefolkExtensionKit
@testable import ext_playtime

/// The four puzzles as a person plays them: nothing moves from the first move to the last, whatever the bubble says, and every word that goes in the bubble fits it.
@Suite(.serialized) @MainActor
struct PlaytimeStabilityG4 {
    /// Where each thing stands: the board's parts, the dock, the stage, the frame of the grid, each of the dock's buttons, and the pad.
    static func places(_ scene: Scene) -> [String: [Double]] {
        var out: [String: [Double]] = [:]
        func visit(_ node: [String: Any], x: Double, y: Double, keep: Bool) {
            let id = node["id"] as? String
            let (nx, ny) = (x + (node["x"] as? Double ?? 0), y + (node["y"] as? Double ?? 0))
            if let id, keep || ["board", "stage", "bubble", "dock", "puzzle", "puzzle.frame", "puzzle.grid", "pad", "hint"].contains(id) || id.hasPrefix("dock.") || id.hasPrefix("pad.") {
                out[id] = [nx, ny, node["w"] as? Double ?? 0, node["h"] as? Double ?? 0]
            }
            for child in node["children"] as? [[String: Any]] ?? [] { visit(child, x: nx, y: ny, keep: keep) }
        }
        (scene.json["nodes"] as? [[String: Any]] ?? []).forEach { visit($0, x: 0, y: 0, keep: false) }
        return out
    }

    /// Every board of a real solve, hints, a wrong move and Undo among them, ending with the last beat before the card, drawn as the table draws it.
    func play<K: PuzzleKind>(_ kind: K.Type, level: GameLevel, seed: UInt64) throws {
        PlaytimeRecords.update { $0 = PlaytimeRecords() }
        var random = Games.Random(seed: seed)
        let options: GameOptions = { var o = PlaytimeScreensTests.options("en"); o.asked = level; return o }()
        var state = PuzzleEngine<K>.start(level: level, options: options, random: &random)
        typealias S = PuzzleScreen<K>
        let entry = GameCatalog.entry(K.id)!
        var previous = S.board(state, events: [.opened], options: options)
        var local = LocalParts()
        StageMoves.settle(previous, local: &local)
        let first = Self.places(BoardDrawing(previous, StageContext(entry: entry, local: local)).scene())
        func check(_ board: Board, buildUp: Bool = false, _ context: String) throws {
            var ctx = StageContext(entry: entry, previous: previous, local: local)
            ctx.buildUp = buildUp
            let scene = BoardDrawing(board, ctx).scene()
            try PlaytimeStageTests.check(scene, "\(K.id) \(level) \(context)")
            #expect(Self.places(scene) == first, "\(K.id) \(level) \(context): moved")
        }
        // Undo with nothing to undo, a refusal: said in the bubble, the board stays.
        var events = GameTable.play(S.self, .button("undo"), on: &state, random: &random)
        var board = S.board(state, events: events, options: options)
        try check(board, "refused")
        previous = board
        // Solve by hints, each one shown and then done, so every reason and each mark's appearing goes through the same places.
        var steps = 0
        while !state.game.solved, steps < 400 {
            steps += 1
            for move: Move in [.button("hint"), .button("do_hint")] {
                events = GameTable.play(S.self, move, on: &state, random: &random)
                board = S.board(state, events: events, options: options)
                if state.game.solved { break }
                try check(board, "step \(steps)")
                previous = board
            }
            // Now and then a step back and forth, which brings Undo and Start over in and out of use.
            if steps % 5 == 0, !state.game.solved {
                events = GameTable.play(S.self, .button("undo"), on: &state, random: &random)
                board = S.board(state, events: events, options: options)
                try check(board, "undo \(steps)")
                previous = board
            }
        }
        #expect(state.game.solved)
        let build = try #require(Suspense.buildUp(from: previous, to: board, picked: nil))
        #expect(!Suspense.showsVerdict(build.board))
        try check(build.board, buildUp: true, "last beat")
    }

    @Test func nothingMovesOverAPlayThrough() throws {
        try Language.with("en", strings: PlaytimeGameTests.strings) {
            for level in GameLevel.allCases {
                try play(GardenPlotsKind.self, level: level, seed: 11)
                try play(SeesawKind.self, level: level, seed: 12)
                try play(SudokuKind.self, level: level, seed: 13)
                try play(BlossomsKind.self, level: level, seed: 14)
            }
        }
    }

    /// The largest scale of the bubble's 15 pt at which the words fit its one size: 278 × 44, at most three lines.
    static func fit(_ words: String) -> Double {
        var scale = 1.0
        while scale > 0.5, TextFit.height(words, size: 15 * scale, weight: "heavy", width: 278) > 44 { scale -= 0.01 }
        return scale
    }

    /// All the bubble ever says on a puzzle but the time.
    static var said: [String] {
        let plots: [GardenPlotsKind.Rules.Reason] = [.mistake, .onlyFit, .onlyReach, .claimed, .wouldBlock, .chain, .reveal]
        let plotRules: [GardenPlotsKind.Rules.Rule] = [.noNumber, .twoNumbers, .wrongSize]
        let seesaw: [SeesawKind.Rules.Reason] = [.mistake, .pair, .gap, .clue, .full, .line, .chain, .reveal]
        let seesawRules: [SeesawKind.Rules.Rule] = [.threeInARow, .tooMany, .clue]
        let sudoku: [SudokuKind.Rules.Reason] = [.mistake, .lastInCell, .lastInBox, .lastInRow, .lastInColumn, .locked, .pair, .reveal]
        let sudokuRules: [SudokuKind.Rules.Rule] = [.row, .column, .box]
        let blossoms: [BlossomsKind.Rules.Reason] = [.mistake, .lastInRow, .lastInColumn, .lastInBed, .locked, .wouldEmpty, .group, .chain, .reveal]
        let blossomRules: [BlossomsKind.Rules.Rule] = [.row, .column, .bed, .touching, .noRoom]
        var random = Games.Random(seed: 3)
        var out = plots.map(GardenPlotsKind.reason) + plotRules.map(GardenPlotsKind.rule) + seesaw.map(SeesawKind.reason) + seesawRules.map(SeesawKind.rule)
        out += sudoku.map(SudokuKind.reason) + sudokuRules.map(SudokuKind.rule) + blossoms.map(BlossomsKind.reason) + blossomRules.map(BlossomsKind.rule)
        out.append(GardenPlotsKind.rules(Games.PuzzleGame(Games.GardenPlots.generate(level: .easy, using: &random), at: 0)))
        out.append(SeesawKind.rules(Games.PuzzleGame(Games.Seesaw.generate(level: .easy, using: &random), at: 0)))
        out.append(SudokuKind.rules(Games.PuzzleGame(Games.Sudoku.generate(level: .hard, using: &random), at: 0)))
        out.append(BlossomsKind.rules(Games.PuzzleGame(Games.Blossoms.generate(level: .easy, using: &random), at: 0)))
        out += [L("That one is part of the puzzle."), L("Nothing to undo.")]
        return out
    }

    @Test func everyReasonReadsInTheBubble() {
        for language in ["en", "de"] {
            Language.with(language, strings: PlaytimeGameTests.strings) {
                for words in Self.said {
                    let scale = Self.fit(words)
                    #expect(scale >= 0.8, "\(language): \(Int(scale * 15 * 10)) tenths of a point: \(words)")
                }
            }
        }
    }

    /// The German the lead is given for the words this change wrote, at the bubble's size.
    @Test func theProposedGermanReads() {
        for words in ["Eine Zahl pro Rechteck. Die Zahl ist seine Fläche.", "In jeder Linie gleich viele Monde und Sonnen. Nie drei gleiche.",
                      "Jede Zeile, Spalte und Box enthält 1–9 einmal.", "Eine Blüte pro Zeile, Spalte und Beet. Sie berühren sich nie, auch nicht an Ecken.",
                      "Zwei Felder teilen zwei Zahlen und schließen sie anderswo aus.", "Diese Beete füllen jene Linien und schließen den Rest aus.",
                      "Anderswo bliebe einer Zeile, Spalte oder einem Beet kein Platz.", "Ein Beet in nur einer Linie schließt den Rest der Linie aus."] {
            #expect(Self.fit(words) >= 0.9, "\(words): \(Self.fit(words))")
        }
    }

    @Test func aBoardSavedWithHeartsAndStarsReadsBackAsCrescentsAndSuns() throws {
        // What a saved board says: the marks' raw values, which never changed.
        let saved = #"[1, 2, null, 2, 1]"#
        let grid = try JSONDecoder().decode(Games.Seesaw.Grid.self, from: Data(saved.utf8))
        #expect(grid == [.crescent, .sun, nil, .sun, .crescent])
        #expect(Games.Seesaw.Mark.crescent.rawValue == 1 && Games.Seesaw.Mark.sun.rawValue == 2)
        // A whole game, as the records keep today's board, comes back the same after a round trip through those numbers.
        var random = Games.Random(seed: 5)
        var game = Games.PuzzleGame(Games.Seesaw.generate(level: .easy, using: &random), day: 42, at: 0)
        let open = game.puzzle.givens.firstIndex(of: nil)!
        _ = try game.play(.cycle(open), at: 1)
        let data = try JSONEncoder().encode(game)
        let text = String(decoding: data, as: UTF8.self)
        #expect(!text.contains("heart") && !text.contains("crescent") && !text.contains("\"sun\""), "marks are saved as numbers")
        #expect(try JSONDecoder().decode(Games.PuzzleGame<Games.Seesaw>.self, from: data) == game)
    }

    /// A disc on a line keeps clear of the marks either side, at every board's size.
    @Test func aClueNeverCoversAMark() throws {
        for size in [6, 8] {
            let cells = (0..<(size * size)).map { _ in PuzzleCell(symbol: "sun") }
            let edges = [PuzzleEdge(cell: 0, down: false, clue: "same"), PuzzleEdge(cell: 1, down: true, clue: "different")]
            let board = PlaytimePuzzleStageTests.board(input: "tap", rows: size, columns: size, cells: cells, edges: edges)
            let scene = PlaytimePuzzleStageTests.scene(board, SeesawKind.id)
            let styles = try #require(scene.json["styles"] as? [String: [String: Any]])
            let mark = try #require(styles["ps"]), cell = try #require(styles["pc"])
            let disc = try #require(PlaytimePuzzleStageTests.nodes(scene).first { $0["id"] as? String == "e0r" })
            let side = cell["w"] as! Double
            #expect(mark["x"] as! Double >= (disc["w"] as! Double) / 2, "\(size) × \(size)")
            #expect(side > 40)
        }
    }

    /// The end card shows the solved board, of any of the four, with nothing to press, in the zone.
    func endCard<K: PuzzleKind>(_ kind: K.Type, level: GameLevel) throws {
        PlaytimeRecords.update { $0 = PlaytimeRecords() }
        var random = Games.Random(seed: 21)
        let options: GameOptions = { var o = PlaytimeScreensTests.options("en"); o.asked = level; return o }()
        var state = PuzzleEngine<K>.start(level: level, options: options, random: &random)
        var events: [Games.Event] = []
        var steps = 0
        while !state.game.solved, steps < 400 {
            steps += 1
            _ = GameTable.play(PuzzleScreen<K>.self, .button("hint"), on: &state, random: &random)
            events = GameTable.play(PuzzleScreen<K>.self, .button("do_hint"), on: &state, random: &random)
        }
        let board = PuzzleScreen<K>.board(state, events: events, options: options)
        let scene = BoardDrawing(board, StageContext(entry: GameCatalog.entry(K.id)!)).scene()
        try PlaytimeStageTests.check(scene, "\(K.id) end")
        let nodes = PlaytimePuzzleStageTests.nodes(scene)
        let mini = try #require(nodes.first { $0["id"] as? String == "mini" }, "\(K.id) \(level)")
        #expect((mini["h"] as! Double) >= 76, "\(K.id) \(level)")
        #expect(mini["area"] == nil && !nodes.contains { $0["id"] as? String == "board" && $0["type"] as? String == "scroll" }, "\(K.id) \(level): the card fits the zone")
        func anyArea(_ node: [String: Any]) -> Bool { node["area"] != nil || (node["children"] as? [[String: Any]] ?? []).contains(where: anyArea) }
        #expect(!anyArea(mini), "\(K.id) \(level): the picture presses nothing")
    }

    @Test func theSolvedBoardIsOnTheEndCard() throws {
        try Language.with("en", strings: PlaytimeGameTests.strings) {
            for level in GameLevel.allCases {
                try endCard(GardenPlotsKind.self, level: level)
                try endCard(SeesawKind.self, level: level)
                try endCard(SudokuKind.self, level: level)
                try endCard(BlossomsKind.self, level: level)
            }
        }
    }

    /// The last correct move ripples over the board; only a solve does, and nothing can be pressed while it does.
    @Test func theLastMoveHasItsMomentOnTheBoard() throws {
        let cells = (0..<36).map { PuzzleCell(symbol: "sun", fresh: $0 == 5) }
        let board = PlaytimePuzzleStageTests.board(input: "tap", cells: cells, locked: true, running: false)
        var ctx = StageContext(entry: GameCatalog.entry(SeesawKind.id)!, previous: board)
        ctx.buildUp = true
        ctx.afterMs = Suspense.beatMs
        let moment = try PlaytimePuzzleStageTests.json(BoardDrawing(board, ctx).scene())
        #expect(moment.contains("\"target\":\"w35\"") && moment.contains("sounds/ding.wav") && !moment.contains("essential"))
        #expect(!moment.contains("\"question\""), "a solve isn't a question")
        #expect((BoardDrawing(board, ctx).scene().json["after_ms"] as? Int ?? 0) > Suspense.beatMs, "the card waits for it")
        #expect(try !PlaytimePuzzleStageTests.json(PlaytimePuzzleStageTests.scene(board, SeesawKind.id)).contains("\"target\":\"w35\""))
    }
}
