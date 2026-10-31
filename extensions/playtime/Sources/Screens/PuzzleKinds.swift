import Foundation
import SidefolkExtensionKit

// The four puzzles' words and grids, on the shared PuzzleScreen.

enum SeesawKind: PuzzleKind {
    typealias Rules = Games.Seesaw
    static let id = Games.Seesaw.id

    static var rules: String { L("As many hearts as stars in every row and column, never three alike in a line. = means the same, × different.") }

    static func reason(_ r: Rules.Reason) -> String {
        switch r {
        case .mistake: L("This mark isn't right: take it back.")
        case .pair: L("Two alike side by side: the next one is the other.")
        case .gap: L("The cells on either side match, so this one is the other.")
        case .clue: L("The clue beside it decides this one.")
        case .full: L("This line already has its half of one: the rest are the other.")
        case .line: L("Every way to finish this line puts this here.")
        case .chain: L("The other mark here would break a rule a few moves on.")
        case .reveal: L("Here's one to keep you going.")
        }
    }

    static func rule(_ r: Rules.Rule) -> String {
        switch r {
        case .threeInARow: L("Three alike in a line: change one.")
        case .tooMany: L("Too many of one in that line.")
        case .clue: L("That = or × isn't kept.")
        }
    }

    static func move(_ move: Move, in game: Games.PuzzleGame<Rules>) -> Rules.Move? {
        guard case .cell(let r, let c) = move, (0..<game.puzzle.size).contains(r), (0..<game.puzzle.size).contains(c) else { return nil }
        return .cycle(r * game.puzzle.size + c)
    }

    static func cell(of move: Rules.Move) -> Int? {
        switch move { case .set(let c, _), .cycle(let c): c }
    }

    static func name(_ mark: Rules.Mark?) -> String? { mark.map { $0 == .heart ? L("Heart") : L("Star") } }

    static func part(_ g: Games.PuzzleGame<Rules>, hint: Games.PuzzleHint<Rules.Move, Rules.Reason>?, fresh: Int?, now: Double) -> BoardPart {
        let b = g.puzzle, n = b.size
        let broken = Set(g.conflicts.flatMap(\.cells)), lit = Set(hint?.cells ?? [])
        var target: (cell: Int, mark: Rules.Mark?)?
        if case .set(let c, let m)? = hint?.move { target = (c, m) }
        let cells = g.grid.indices.map { i -> PuzzleCell in
            let mark = target?.cell == i && g.grid[i] == nil ? target?.mark : g.grid[i]
            let state = target?.cell == i ? "target" : broken.contains(i) ? "conflict" : lit.contains(i) ? "hint" : nil
            return PuzzleCell(symbol: mark.map { $0 == .heart ? "heart" : "star" }, given: b.givens[i] != nil, state: state, fresh: fresh == i,
                              label: PuzzleParts.label(i, columns: n, name(g.grid[i])))
        }
        let edges = b.edges.map { PuzzleEdge(cell: $0.cell, down: $0.down, clue: $0.clue.rawValue) }
        return .play(.puzzle(rows: n, columns: n, cells: cells, input: "tap", edges: edges, seconds: g.elapsed(at: now), running: !g.solved,
                             locked: g.solved))
    }
}

enum SudokuKind: PuzzleKind {
    typealias Rules = Games.Sudoku
    static let id = Games.Sudoku.id

    static var rules: String { L("Fill the grid: every row, column and box holds each number once.") }

    static func reason(_ r: Rules.Reason) -> String {
        switch r {
        case .mistake: L("This number isn't right: take it back.")
        case .lastInCell: L("Only one number still fits this cell.")
        case .lastInBox: L("The only place left for this number in its box.")
        case .lastInRow: L("The only place left for this number in its row.")
        case .lastInColumn: L("The only place left for this number in its column.")
        case .locked: L("A number kept to one line of a box rules it out elsewhere, leaving this.")
        case .pair: L("Two cells share the same two numbers, ruling them out elsewhere, leaving this.")
        case .reveal: L("Here's one to keep you going.")
        }
    }

    static func rule(_ r: Rules.Rule) -> String {
        switch r {
        case .row: L("That number is twice in a row.")
        case .column: L("That number is twice in a column.")
        case .box: L("That number is twice in a box.")
        }
    }

    static func move(_ move: Move, in game: Games.PuzzleGame<Rules>) -> Rules.Move? {
        let n = game.puzzle.size
        guard case .place(let r, let c, let v, let note) = move, (0..<n).contains(r), (0..<n).contains(c) else { return nil }
        let cell = r * n + c
        return note ? .note(cell, v) : v == 0 ? .clear(cell) : .set(cell, v)
    }

    static func cell(of move: Rules.Move) -> Int? {
        switch move { case .set(let c, _), .clear(let c), .note(let c, _): c }
    }

    static func part(_ g: Games.PuzzleGame<Rules>, hint: Games.PuzzleHint<Rules.Move, Rules.Reason>?, fresh: Int?, now: Double) -> BoardPart {
        let b = g.puzzle, n = b.size
        let broken = Set(g.conflicts.flatMap(\.cells)), lit = Set(hint?.cells ?? [])
        var target: (cell: Int, digit: Int?)?
        switch hint?.move {
        case .set(let c, let d)?: target = (c, d)
        case .clear(let c)?: target = (c, nil)
        default: break
        }
        let cells = g.grid.digits.indices.map { i -> PuzzleCell in
            let digit = g.grid.digits[i] != 0 ? g.grid.digits[i] : target?.cell == i ? target?.digit : nil
            let state = target?.cell == i ? "target" : broken.contains(i) ? "conflict" : lit.contains(i) ? "hint" : nil
            return PuzzleCell(text: digit.map(String.init), given: b.givens[i] != 0, notes: g.grid.noted(i), state: state, fresh: fresh == i,
                              label: PuzzleParts.label(i, columns: n, g.grid.digits[i] == 0 ? nil : String(g.grid.digits[i])))
        }
        return .play(.puzzle(rows: n, columns: n, cells: cells, input: "digits", digits: n, box: (b.boxRows, b.boxColumns),
                             seconds: g.elapsed(at: now), running: !g.solved, locked: g.solved))
    }
}

enum GardenPlotsKind: PuzzleKind {
    typealias Rules = Games.GardenPlots
    static let id = Games.GardenPlots.id

    static var rules: String { L("Split the garden into rectangles, one number in each: as many squares as it says.") }

    static func reason(_ r: Rules.Reason) -> String {
        switch r {
        case .mistake: L("This plot isn't right: take it away.")
        case .onlyFit: L("Only one plot of that size fits around this number.")
        case .onlyReach: L("A square here can only belong to this number.")
        case .claimed: L("Squares another number always covers are taken, leaving this.")
        case .wouldBlock: L("Any other plot would leave a number or a square with nowhere to go.")
        case .chain: L("Any other plot leads to a dead end a few plots on.")
        case .reveal: L("Here's one to keep you going.")
        }
    }

    static func rule(_ r: Rules.Rule) -> String {
        switch r {
        case .noNumber: L("A plot needs one number in it.")
        case .twoNumbers: L("A plot can hold only one number.")
        case .wrongSize: L("A plot has as many squares as its number.")
        }
    }

    static func move(_ move: Move, in game: Games.PuzzleGame<Rules>) -> Rules.Move? {
        let b = game.puzzle, w = b.width
        func inside(_ r: Int, _ c: Int) -> Bool { (0..<b.height).contains(r) && (0..<w).contains(c) }
        switch move {
        case .area(let r, let c, let r2, let c2) where inside(r, c) && inside(r2, c2):
            return .draw(.corners(r * w + c, r2 * w + c2, width: w))
        case .cell(let r, let c) where inside(r, c):
            // A click takes away the plot it lands on, or plants a one-square plot.
            let cell = r * w + c
            return game.grid.contains { $0.contains(cell, width: w) } ? .erase(cell) : .draw(.corners(cell, cell, width: w))
        default:
            return nil
        }
    }

    static func cell(of move: Rules.Move) -> Int? { nil }

    static func part(_ g: Games.PuzzleGame<Rules>, hint: Games.PuzzleHint<Rules.Move, Rules.Reason>?, fresh: Int?, now: Double) -> BoardPart {
        let b = g.puzzle, w = b.width
        let clues = Dictionary(uniqueKeysWithValues: b.clues.map { ($0.cell, $0.area) })
        let broken = Set(g.conflicts.map { Set($0.cells) })
        var hinted: Rules.Plot?
        switch hint?.move {
        case .draw(let p)?: hinted = p
        case .erase(let c)?: hinted = g.grid.first { $0.contains(c, width: w) }
        default: break
        }
        let cells = (0..<(w * b.height)).map { i in
            PuzzleCell(text: clues[i].map(String.init), given: clues[i] != nil,
                       label: PuzzleParts.label(i, columns: w, clues[i].map(String.init)))
        }
        // Each plot keeps the colour of the number in it, so a plot redrawn looks the same.
        var plots = g.grid.filter { $0 != hinted }.map { p -> PuzzlePlot in
            let tint = b.clues.firstIndex { p.contains($0.cell, width: w) }
            return PuzzlePlot(row: p.row, column: p.column, height: p.height, width: p.width,
                              state: broken.contains(Set(p.cells(width: w))) ? "conflict" : nil, tint: tint.map { $0 % 12 })
        }
        if let p = hinted { plots.append(PuzzlePlot(row: p.row, column: p.column, height: p.height, width: p.width, state: "hint")) }
        return .play(.puzzle(rows: b.height, columns: w, cells: cells, input: "drag", plots: plots, seconds: g.elapsed(at: now),
                             running: !g.solved, locked: g.solved))
    }
}

enum BlossomsKind: PuzzleKind {
    typealias Rules = Games.Blossoms
    static let id = Games.Blossoms.id

    static var rules: String { L("One blossom in every row, column and bed. Blossoms never touch, not even corner to corner.") }

    static func reason(_ r: Rules.Reason) -> String {
        switch r {
        case .mistake: L("This mark isn't right: take it back.")
        case .lastInRow: L("The last place left in this row.")
        case .lastInColumn: L("The last place left in this column.")
        case .lastInBed: L("The last place left in this bed.")
        case .locked: L("A bed kept to one line rules out the rest of that line, leaving this.")
        case .wouldEmpty: L("A blossom in the other places would leave a row, column or bed no room, leaving this.")
        case .group: L("These beds fill those lines between them, ruling out the rest, leaving this.")
        case .chain: L("A blossom in the other places leads to a dead end a few moves on.")
        case .reveal: L("Here's one to keep you going.")
        }
    }

    static func rule(_ r: Rules.Rule) -> String {
        switch r {
        case .row: L("Two blossoms in one row.")
        case .column: L("Two blossoms in one column.")
        case .bed: L("Two blossoms in one bed.")
        case .touching: L("Blossoms can't touch, not even corner to corner.")
        case .noRoom: L("No room is left there for its blossom.")
        }
    }

    static func move(_ move: Move, in game: Games.PuzzleGame<Rules>) -> Rules.Move? {
        let n = game.puzzle.size
        guard case .cell(let r, let c) = move, (0..<n).contains(r), (0..<n).contains(c) else { return nil }
        return .cycle(r * n + c)
    }

    static func cell(of move: Rules.Move) -> Int? {
        switch move { case .set(let c, _), .cycle(let c): c }
    }

    static func part(_ g: Games.PuzzleGame<Rules>, hint: Games.PuzzleHint<Rules.Move, Rules.Reason>?, fresh: Int?, now: Double) -> BoardPart {
        let b = g.puzzle, n = b.size
        let broken = Set(g.conflicts.flatMap(\.cells)), lit = Set(hint?.cells ?? [])
        var target: (cell: Int, mark: Rules.Mark?)?
        if case .set(let c, let m)? = hint?.move { target = (c, m) }
        let cells = g.grid.indices.map { i -> PuzzleCell in
            let mark = target?.cell == i && g.grid[i] == nil ? target?.mark : g.grid[i]
            let state = target?.cell == i ? "target" : broken.contains(i) ? "conflict" : lit.contains(i) ? "hint" : nil
            let words: String? = switch g.grid[i] { case .blossom?: L("Blossom"); case .dot?: L("Ruled out"); case nil: nil }
            return PuzzleCell(symbol: mark.map { $0 == .blossom ? "blossom" : "dot" }, region: b.beds[i], state: state, fresh: fresh == i,
                              label: PuzzleParts.label(i, columns: n, words))
        }
        return .play(.puzzle(rows: n, columns: n, cells: cells, input: "tap", seconds: g.elapsed(at: now), running: !g.solved, locked: g.solved))
    }
}

