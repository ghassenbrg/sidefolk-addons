import Foundation
import Testing
@testable import SidefolkExtensionKit
@testable import ext_playtime

/// The puzzles as scenes (Sidefolk D101): what the panel kept for a puzzle is the program's now (the arrows' cursor, a cell picked, pen or pencil, a plot stretched from the
/// keyboard), a 9 × 9 with pencil notes everywhere fits a scene, and the picture is the same in every language.
@Suite(.serialized) @MainActor
struct PlaytimePuzzleStageTests {
    static func board(input: String = "tap", digits: Int? = nil, rows: Int = 6, columns: Int = 6, cells: [PuzzleCell]? = nil, plots: [PuzzlePlot] = [], edges: [PuzzleEdge] = [],
                      box: (rows: Int, columns: Int)? = nil, locked: Bool = false, running: Bool = true) -> Board {
        Board([.prompt("Rules", eyebrow: "Today's puzzle · Fair"),
               .play(.puzzle(rows: rows, columns: columns, cells: cells ?? (0..<(rows * columns)).map { _ in PuzzleCell() }, input: input, digits: digits, box: box, edges: edges, plots: plots,
                             seconds: 7, running: running, locked: locked))])
    }

    static func entry(_ id: String) -> GameEntry { GameCatalog.entry(id)! }

    static func scene(_ board: Board, _ id: String = SudokuKind.id, local: LocalParts = LocalParts(), previous: Board? = nil, fresh: Bool = true) -> Scene {
        BoardDrawing(board, StageContext(entry: entry(id), previous: previous, fresh: fresh, local: local)).scene()
    }

    static func json(_ scene: Scene) throws -> String { String(decoding: try JSONSerialization.data(withJSONObject: scene.json, options: .withoutEscapingSlashes), as: UTF8.self) }

    /// Every node in the scene, with what its style gives it.
    static func nodes(_ scene: Scene) -> [[String: Any]] {
        var out: [[String: Any]] = []
        func visit(_ node: [String: Any]) {
            out.append(node)
            (node["children"] as? [[String: Any]] ?? []).forEach(visit)
        }
        (scene.json["nodes"] as? [[String: Any]] ?? []).forEach(visit)
        return out
    }

    static func areas(_ scene: Scene, _ id: String) -> [[String: Any]] { nodes(scene).compactMap { $0["area"] as? [String: Any] }.filter { $0["id"] as? String == id } }

    static func keys(_ scene: Scene) -> [String] { scene.keys.compactMap { $0["id"] as? String } }

    func action(_ move: SurfaceMove, _ board: Board, _ local: inout LocalParts) -> StageAction { StageMoves.action(move, board: board, local: &local) }

    func isRedraw(_ a: StageAction) -> Bool { if case .redraw = a { true } else { false } }

    @Test func aFullSudokuWithNotesEverywhereFitsAScene() throws {
        let cells = (0..<81).map { i in PuzzleCell(notes: Array(1...9), state: i % 7 == 0 ? "conflict" : nil, label: "Row \(i / 9 + 1), column \(i % 9 + 1), a long enough label") }
        let scene = Self.scene(Self.board(input: "digits", digits: 9, rows: 9, columns: 9, cells: cells, box: (3, 3)), local: LocalParts(cursor: 0))
        try PlaytimeStageTests.check(scene, "9 × 9 with notes")
        #expect(Self.nodes(scene).count < 1500)
        #expect((scene.json["styles"] as? [String: Any])?.count ?? 0 <= 48, "the reader's cap")
    }

    /// Every level's board at its real size, each one's hint and a mark on it.
    func everyLevel<K: PuzzleKind>(_ kind: K.Type) throws {
        for level in GameLevel.allCases {
            PlaytimeRecords.update { $0 = PlaytimeRecords() }
            var random = Games.Random(seed: 7)
            let options = PlaytimeScreensTests.options("en")
            var state = PuzzleEngine<K>.start(level: level, options: { var o = options; o.asked = level; return o }(), random: &random)
            for move: Move in [.button("hint"), .button("do_hint")] {
                let events = GameTable.play(PuzzleScreen<K>.self, move, on: &state, random: &random)
                let scene = Self.scene(PuzzleScreen<K>.board(state, events: events, options: options), K.id)
                try PlaytimeStageTests.check(scene, "\(K.id) \(level)")
            }
        }
    }

    @Test func everyLevelOfEveryPuzzleFitsAScene() throws {
        try Language.with("en", strings: PlaytimeGameTests.strings) {
            try everyLevel(GardenPlotsKind.self)
            try everyLevel(SeesawKind.self)
            try everyLevel(SudokuKind.self)
            try everyLevel(BlossomsKind.self)
        }
    }

    @Test func aPuzzleIsLeftToRightInEveryLanguage() throws {
        let board = Self.board(input: "digits", digits: 9, rows: 9, columns: 9, box: (3, 3))
        try Language.with("ar", strings: PlaytimeGameTests.strings) {
            let nodes = Self.nodes(Self.scene(board, local: LocalParts(cursor: 0)))
            for id in ["puzzle.frame", "pad"] { #expect(nodes.contains { $0["id"] as? String == id && $0["ltr"] as? Bool == true }, "\(id)") }
            // The arrows move as they point, in Arabic too, where a game's other grids follow the reading direction.
            var local = LocalParts(cursor: 4)
            _ = action(.key(id: "arrow_right", character: nil, ms: nil), board, &local)
            #expect(local.cursor == 5)
        }
    }

    @Test func sudokusPadTypesIntoTheCellPicked() {
        let cells = (0..<36).map { PuzzleCell(text: $0 == 0 ? "4" : nil, given: $0 == 0) }
        let board = Self.board(input: "digits", digits: 6, cells: cells, box: (2, 3))
        // Its first open cell is picked as the board shows, until the person picks another.
        var local = LocalParts()
        StageMoves.settle(board, local: &local)
        #expect(local.cursor == 1)
        guard case .play(.place(row: 0, column: 1, value: 5, note: false)) = action(.click(area: "pad", value: "5", ms: nil), board, &local) else {
            Issue.record("the pad places in the cell picked")
            return
        }
        guard isRedraw(action(.click(area: "puzzle_pick", value: "9", ms: nil), board, &local)), local.cursor == 9 else {
            Issue.record("picking a cell sends nothing")
            return
        }
        guard isRedraw(action(.click(area: "notes", value: nil, ms: nil), board, &local)), local.notes else {
            Issue.record("the switch sends nothing")
            return
        }
        guard case .play(.place(row: 1, column: 3, value: 2, note: true)) = action(.click(area: "pad", value: "2", ms: nil), board, &local) else {
            Issue.record("with notes on, a number is a note")
            return
        }
        // Clearing is never a note.
        guard case .play(.place(row: 1, column: 3, value: 0, note: false)) = action(.click(area: "pad", value: "0", ms: nil), board, &local) else {
            Issue.record("0 clears the cell")
            return
        }
        // A digit in another script counts, one past the board's numbers doesn't.
        guard case .play(.place(row: 1, column: 3, value: 3, note: true)) = action(.key(id: "pad_any", character: "٣", ms: nil), board, &local),
              case .ignore = action(.key(id: "pad_any", character: "8", ms: nil), board, &local) else {
            Issue.record("the keyboard's digits")
            return
        }
    }

    @Test func aGivenTakesNothingAndSoundsNothing() throws {
        let cells = (0..<36).map { PuzzleCell(text: $0 == 0 ? "4" : nil, given: $0 == 0) }
        let board = Self.board(input: "digits", digits: 6, cells: cells, box: (2, 3))
        let on = Self.scene(board, local: LocalParts(cursor: 0))
        #expect(!Self.keys(on).contains("pad_1") && !Self.keys(on).contains("pad_delete"), "the panel didn't offer a move on a given")
        #expect(Self.areas(on, "pad").allSatisfy { $0["sound"] == nil })
        #expect(!Self.areas(on, "puzzle_pick").contains { $0["value"] as? String == "0" }, "a click can't pick it")
        var local = LocalParts(cursor: 0)
        guard case .ignore = action(.click(area: "pad", value: "5", ms: nil), board, &local) else {
            Issue.record("nothing goes")
            return
        }
        let off = Self.scene(board, local: LocalParts(cursor: 1))
        #expect(Self.keys(off).contains("pad_1") && Self.areas(off, "pad").allSatisfy { $0["sound"] as? String == "sounds/tap.wav" && $0["disabled"] as? Bool != true })
    }

    @Test func aTapBoardsCellsAndKeys() {
        let cells = (0..<36).map { PuzzleCell(symbol: $0 == 3 ? "crescent" : nil, given: $0 == 3) }
        let board = Self.board(input: "tap", cells: cells)
        let scene = Self.scene(board, SeesawKind.id, local: LocalParts(cursor: 2))
        let open = Self.areas(scene, "cell")
        #expect(open.count == 35 && !open.contains { $0["value"] as? String == "0,3" }, "a given can't be clicked")
        #expect(scene.keys.contains { $0["id"] as? String == "puzzle_return" && $0["area"] as? String == "cell" && $0["value"] as? String == "0,2" })
        #expect(!Self.keys(Self.scene(board, SeesawKind.id, local: LocalParts(cursor: 3))).contains("puzzle_return"), "nor pressed from the keyboard")
        var local = LocalParts()
        _ = action(.key(id: "arrow_down", character: nil, ms: nil), board, &local)
        #expect(local.cursor == 0, "the arrows start at the first cell")
        _ = action(.key(id: "arrow_down", character: nil, ms: nil), board, &local)
        #expect(local.cursor == 6)
    }

    @Test func aPlotFromTheKeyboardStretchesPlantsAndLetsGo() throws {
        let board = Self.board(input: "drag")
        var local = LocalParts()
        guard isRedraw(action(.key(id: "plot_space", character: " ", ms: nil), board, &local)), local.dragFrom == 0, local.cursor == 0 else {
            Issue.record("Space starts a plot at the cursor")
            return
        }
        #expect(Self.keys(Self.scene(board, GardenPlotsKind.id, local: local)).contains("plot_letgo"), "Esc lets the plot go while one is stretched")
        #expect(!BoardDrawing(board, StageContext(entry: Self.entry(GardenPlotsKind.id), local: local)).footer.contains("Esc to close"))
        _ = action(.key(id: "arrow_right", character: nil, ms: nil), board, &local)
        _ = action(.key(id: "arrow_down", character: nil, ms: nil), board, &local)
        #expect(local.cursor == 7 && local.dragFrom == 0)
        #expect(try Self.json(Self.scene(board, GardenPlotsKind.id, local: local)).contains("plot.0.0.2.2.k"), "the dashed preview")
        var kept = local
        guard isRedraw(action(.key(id: "plot_letgo", character: nil, ms: nil), board, &kept)), kept.dragFrom == nil else {
            Issue.record("Esc lets it go")
            return
        }
        guard case .play(.area(row: 0, column: 0, toRow: 1, toColumn: 1)) = action(.key(id: "plot_return", character: nil, ms: nil), board, &local), local.dragFrom == nil, local.plantSound else {
            Issue.record("Return plants it")
            return
        }
        // On one square, it is a click there, which clears a plot or plants a one-square one.
        var one = LocalParts(cursor: 8, dragFrom: 8)
        guard case .play(.cell(row: 1, column: 2)) = action(.key(id: "plot_space", character: " ", ms: nil), board, &one) else {
            Issue.record("one square")
            return
        }
        // A new board lets a plot being stretched go.
        var stretching = LocalParts(cursor: 8, dragFrom: 2)
        StageMoves.settle(board, local: &stretching)
        #expect(stretching.dragFrom == nil)
    }

    @Test func aPlotDraggedIsTheBoardsMoveAndHeardWhenItLands() throws {
        let board = Self.board(input: "drag")
        let scene = Self.scene(board, GardenPlotsKind.id)
        let area = try #require(Self.areas(scene, "plots").first)
        #expect(area["sound"] == nil, "nothing as the pointer goes down")
        #expect((area["drag"] as? [String: Any])?["ghost"] as? String == "plot.ghost" && (area["drag"] as? [String: Any])?["columns"] as? Int == 6)
        var local = LocalParts(dragFrom: 3)
        guard case .play(.area(row: 1, column: 2, toRow: 3, toColumn: 4)) = action(.dragCells(area: "plots", value: nil, from: [1, 2], to: [3, 4]), board, &local), local.dragFrom == nil else {
            Issue.record("corner to corner")
            return
        }
        guard case .play(.cell(row: 2, column: 2)) = action(.dragCells(area: "plots", value: nil, from: [2, 2], to: [2, 2]), board, &local) else {
            Issue.record("a click without moving")
            return
        }
        #expect(try Self.json(Self.scene(board, GardenPlotsKind.id, local: local, previous: board)).contains("sounds/tap.wav"))
    }

    @Test func aLockedBoardOffersNothing() {
        for (input, game) in [("tap", SeesawKind.id), ("digits", SudokuKind.id), ("drag", GardenPlotsKind.id)] {
            let scene = Self.scene(Self.board(input: input, digits: input == "digits" ? 6 : nil, box: input == "digits" ? (2, 3) : nil, locked: true, running: false), game, local: LocalParts(cursor: 0))
            for id in ["cell", "puzzle_pick", "plots", "notes"] { #expect(Self.areas(scene, id).isEmpty, "\(input): \(id)") }
            #expect(!Self.keys(scene).contains { $0.hasPrefix("arrow_") || $0.hasPrefix("pad_") || $0.hasPrefix("plot_") }, "\(input)")
            #expect(Self.areas(scene, "pad").allSatisfy { $0["disabled"] as? Bool == true })
        }
    }

    @Test func aBrokenRuleIsTheCalmToneWithAMarkNeverRed() throws {
        let cells = (0..<36).map { PuzzleCell(symbol: $0 == 0 ? "crescent" : nil, state: $0 == 0 ? "conflict" : nil) }
        let scene = Self.scene(Self.board(input: "tap", cells: cells, plots: [PuzzlePlot(row: 0, column: 0, height: 1, width: 2, state: "conflict")]), SeesawKind.id)
        let json = try Self.json(scene)
        #expect(json.contains("exclamationmark"), "a mark goes with the colour")
        #expect(json.contains("\"loss\""))
        for red in ["FF0000", "FF3B30", "D70015"] { #expect(!json.uppercased().contains(red)) }
    }

    @Test func aMarkSettlesOnlyAsItIsPlayed() throws {
        let cells = (0..<36).map { PuzzleCell(symbol: $0 == 5 ? "sun" : nil, fresh: $0 == 5) }
        let board = Self.board(input: "tap", cells: cells)
        func settles(fresh: Bool) throws -> Bool { try Self.json(Self.scene(board, SeesawKind.id, fresh: fresh)).contains("\"target\":\"c5.m\"") }
        #expect(try settles(fresh: true))
        #expect(try !settles(fresh: false), "not when a key redraws it")
        // A calm move: Reduce Motion simply shows its end.
        #expect(try !Self.json(Self.scene(board, SeesawKind.id)).contains("essential"))
    }

    @Test func aBoardDrawnAgainSaysTheTimeItIsNow() throws {
        let board = Self.board(input: "digits", digits: 6, box: (2, 3))
        var later = Self.board(input: "digits", digits: 6, box: (2, 3))
        later.parts[1] = .play(.puzzle(rows: 6, columns: 6, cells: board.puzzlePart!.cells, input: "digits", digits: 6, box: (2, 3), seconds: 42, running: true, locked: false))
        #expect(board.clocked(from: later).puzzlePart?.seconds == 42)
        #expect(board.clocked(from: nil).puzzlePart?.seconds == 7)
        // A stopped clock stays what it said.
        let stopped = Self.board(input: "digits", digits: 6, box: (2, 3), locked: true, running: false)
        #expect(stopped.clocked(from: later).puzzlePart?.seconds == 7)
    }

    @Test func bedLinesOnlyWhereTwoBedsMeetAndWithinWhatAPathHolds() {
        // Four beds, a quarter each: one line down the middle, one across, each end reaching past its corner.
        let cells = (0..<4).map { PuzzleCell(region: $0) }
        #expect(BoardDrawing.bedLines(rows: 2, columns: 2, cells: cells, side: 10, gap: 2).split(separator: "M").count == 2)
        // The most a chequered 9 × 9 can ask, in the reader's 240 commands: each stretch is two, and a stretch of bed edge is one line.
        let chequered = (0..<81).map { PuzzleCell(region: ($0 / 9 + $0 % 9) % 2) }
        let lines = BoardDrawing.bedLines(rows: 9, columns: 9, cells: chequered, side: 30, gap: 3)
        #expect(lines.filter { $0 == "M" || $0 == "L" }.count <= 240)
    }

    @Test func theEyebrowHoldsTheClockAndOnlySudokuHasTheSwitch() throws {
        let sudoku = Self.scene(Self.board(input: "digits", digits: 6, box: (2, 3)), local: LocalParts(cursor: 1))
        #expect(!Self.areas(sudoku, "notes").isEmpty && Self.nodes(sudoku).contains { $0["type"] as? String == "clock" && $0["seconds"] as? Double == 7 })
        #expect(Self.keys(sudoku).contains("pad_notes"))
        let seesaw = Self.scene(Self.board(input: "tap"), SeesawKind.id)
        #expect(Self.areas(seesaw, "notes").isEmpty && Self.nodes(seesaw).contains { $0["type"] as? String == "clock" })
        // A real switch: it says which way it stands, to the eye and to VoiceOver, and the outline goes dashed.
        let on = Self.scene(Self.board(input: "digits", digits: 6, box: (2, 3)), local: LocalParts(cursor: 1, notes: true))
        #expect(Self.areas(on, "notes").first?["selected"] as? Bool == true)
        #expect(Self.nodes(on).contains { $0["id"] as? String == "puzzle.cursor" && $0["dash"] != nil })
    }
}
