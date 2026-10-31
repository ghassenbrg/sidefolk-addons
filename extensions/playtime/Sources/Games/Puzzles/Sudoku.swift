import Foundation

extension Games {
    /// Sudoku: every row, column and box holds each number once. A 6 × 6 board with boxes of 2 rows × 3 columns on Easy
    /// and Fair, the classic 9 × 9 on Hard. Small pencil notes per cell, which a placed number tidies from its row,
    /// column and box.
    ///
    /// Levels are the techniques the board needs: Easy the last number a cell, row, column or box can take (with a few
    /// numbers to spare), Fair also a number locked in one line of a box, Hard also pairs that rule numbers out.
    struct Sudoku: PuzzleRules {
        struct Grid: Codable, Equatable, Sendable {
            /// 0 for an empty cell.
            var digits: [Int]
            /// Pencil notes: bit d for the number d.
            var notes: [UInt16]

            func noted(_ cell: Int) -> [Int] { (1...9).filter { notes[cell] >> $0 & 1 == 1 } }
        }

        enum Move: Codable, Equatable, Sendable {
            case set(Int, Int)
            case clear(Int)
            /// Adds or takes away a pencil note.
            case note(Int, Int)
        }

        enum Rule: String, Codable, Sendable { case row, column, box }

        enum Reason: String, Codable, Sendable {
            /// This number isn't right: take it back.
            case mistake
            /// The only number this cell can still take.
            case lastInCell
            /// The only place left for the number in its box, row or column.
            case lastInBox, lastInRow, lastInColumn
            /// A number kept to one line of a box (or one box of a line) rules it out elsewhere, leaving this.
            case locked
            /// Two cells that share two numbers rule them out elsewhere, leaving this.
            case pair
            /// One cell of the solution (only for a board this solver didn't make).
            case reveal
        }

        static let id = "sudoku"

        let level: Level
        let size: Int
        /// A box's height and width: 2 × 3 on the small board, 3 × 3 on the big one.
        let boxRows: Int
        let boxColumns: Int
        /// 0 where the person fills in.
        let givens: [Int]
        let solution: [Int]

        var start: Grid { Grid(digits: givens, notes: Array(repeating: 0, count: givens.count)) }

        init(level: Level, size: Int, givens: [Int], solution: [Int]) {
            self.level = level
            self.size = size
            boxRows = size == 9 ? 3 : 2
            boxColumns = size == 9 ? 3 : size / 2
            self.givens = givens
            self.solution = solution
        }

        func box(of cell: Int) -> Int { (cell / size / boxRows) * (size / boxColumns) + (cell % size) / boxColumns }

        static func generate(level: Level, using rng: inout Random) -> Sudoku {
            let size = level == .hard ? 9 : 6
            let technique: Technique = switch level { case .easy: .singles; case .fair: .locked; case .hard: .pairs }
            var best: Sudoku?
            // A few tries for a board that needs more than the last-number rules; the last one is kept regardless.
            for _ in 0..<4 {
                let board = make(size: size, level: level, technique: technique, using: &rng)
                best = board
                if technique == .singles || !Logic(board).solves(board.givens, with: .singles) { break }
            }
            return best!
        }

        private static func make(size n: Int, level: Level, technique: Technique, using rng: inout Random) -> Sudoku {
            var board = Sudoku(level: level, size: n, givens: [], solution: [])
            let logic = Logic(board)
            let solution = logic.randomFill(using: &rng)
            var givens = solution
            // Numbers leave in pairs mirrored through the centre, the classic look, while the techniques still finish.
            let keep = level == .easy ? n * n / 2 : 0
            for cell in rng.shuffled(Array(0..<(n * n))) where givens[cell] != 0 && givens.filter({ $0 != 0 }).count > keep {
                let mirror = n * n - 1 - cell
                let saved = (givens[cell], givens[mirror])
                givens[cell] = 0
                givens[mirror] = 0
                if !logic.solves(givens, with: technique) { (givens[cell], givens[mirror]) = saved }
            }
            board = Sudoku(level: level, size: n, givens: givens, solution: solution)
            return board
        }

        // MARK: Playing

        func apply(_ move: Move, to grid: inout Grid) throws {
            let cell: Int = switch move { case .set(let c, _), .clear(let c), .note(let c, _): c }
            guard grid.digits.indices.contains(cell) else { throw Refusal("off_board") }
            guard givens[cell] == 0 else { throw Refusal("given") }
            switch move {
            case .set(_, let d):
                guard (1...size).contains(d) else { throw Refusal("not_a_number") }
                grid.digits[cell] = d
                grid.notes[cell] = 0
                for peer in Logic(self).peers[cell] { grid.notes[peer] &= ~(1 << d) }
            case .clear:
                grid.digits[cell] = 0
            case .note(_, let d):
                guard (1...size).contains(d) else { throw Refusal("not_a_number") }
                guard grid.digits[cell] == 0 else { throw Refusal("filled") }
                grid.notes[cell] ^= 1 << d
            }
        }

        func conflicts(in grid: Grid) -> [PuzzleConflict<Rule>] {
            let logic = Logic(self)
            var out: [PuzzleConflict<Rule>] = []
            for (u, unit) in logic.units.enumerated() {
                for d in 1...size {
                    let cells = unit.filter { grid.digits[$0] == d }
                    if cells.count > 1 { out.append(PuzzleConflict(rule: u < size ? .row : u < 2 * size ? .column : .box, cells: cells)) }
                }
            }
            return out
        }

        func isSolved(_ grid: Grid) -> Bool { !grid.digits.contains(0) && conflicts(in: grid).isEmpty }

        func hint(for grid: Grid) -> PuzzleHint<Move, Reason> {
            if let wrong = grid.digits.indices.first(where: { grid.digits[$0] != 0 && grid.digits[$0] != solution[$0] }) {
                return PuzzleHint(move: .clear(wrong), reason: .mistake, cells: [wrong])
            }
            if let step = Logic(self).step(grid.digits) {
                return PuzzleHint(move: .set(step.cell, step.digit), reason: step.reason, cells: step.cells)
            }
            let cell = grid.digits.firstIndex(of: 0) ?? 0
            return PuzzleHint(move: .set(cell, solution[cell]), reason: .reveal, cells: [cell])
        }

        // MARK: The solver

        enum Technique: Int, Comparable {
            case singles, locked, pairs
            static func < (a: Technique, b: Technique) -> Bool { a.rawValue < b.rawValue }
        }

        /// Candidates as bit masks (bit d for the number d) over the board's rows, columns and boxes.
        struct Logic {
            let n: Int
            /// Rows, then columns, then boxes.
            let units: [[Int]]
            let peers: [[Int]]
            /// The units each cell is in: its row, column and box.
            let unitsOf: [[Int]]
            let all: UInt16
            /// Boxes first, then rows and columns: a box's last place is the easiest to see.
            let unitOrder: [Int]

            init(_ board: Sudoku) {
                let n = board.size
                self.n = n
                var units = (0..<n).map { r in (0..<n).map { r * n + $0 } }
                units += (0..<n).map { c in (0..<n).map { $0 * n + c } }
                units += (0..<n).map { b in (0..<(n * n)).filter { board.box(of: $0) == b } }
                self.units = units
                unitsOf = (0..<(n * n)).map { cell in units.indices.filter { units[$0].contains(cell) } }
                peers = (0..<(n * n)).map { cell in
                    var seen = Array(repeating: false, count: n * n)
                    for u in units where u.contains(cell) { for p in u where p != cell { seen[p] = true } }
                    return seen.indices.filter { seen[$0] }
                }
                all = UInt16((1 << (n + 1)) - 2)
                unitOrder = Array((2 * n)..<(3 * n)) + Array(0..<(2 * n))
            }

            /// A full board at random: cells in order, numbers in a random order, backing up when stuck.
            func randomFill(using rng: inout Random) -> [Int] {
                var digits = Array(repeating: 0, count: n * n)
                func fill(_ cell: Int) -> Bool {
                    if cell == n * n { return true }
                    let used = peers[cell].reduce(0) { $0 | (1 << digits[$1]) }
                    for d in rng.shuffled(Array(1...n)) where used >> d & 1 == 0 {
                        digits[cell] = d
                        if fill(cell + 1) { return true }
                    }
                    digits[cell] = 0
                    return false
                }
                _ = fill(0)
                return digits
            }

            func candidates(_ digits: [Int]) -> [UInt16] {
                digits.indices.map { cell in
                    digits[cell] != 0 ? 0 : all & ~peers[cell].reduce(UInt16(0)) { $0 | UInt16(1 << digits[$1]) }
                }
            }

            /// A placement the singles force: the last place for a number in a unit (boxes first, the easiest to
            /// see), then the last number of a cell. nil when there is none; a broken board gives one anyway, which
            /// `propagate` then finds.
            func single(_ digits: [Int], _ cands: [UInt16]) -> (cell: Int, digit: Int, reason: Reason, cells: [Int])? {
                for u in unitOrder {
                    let unit = units[u]
                    var placed: UInt16 = 0
                    for c in unit where digits[c] != 0 { placed |= 1 << digits[c] }
                    for d in 1...n where placed >> d & 1 == 0 {
                        var place = -1, count = 0
                        for c in unit where cands[c] >> d & 1 == 1 {
                            count += 1
                            place = c
                        }
                        guard count == 1 else { continue }
                        return (place, d, u < n ? .lastInRow : u < 2 * n ? .lastInColumn : .lastInBox, unit)
                    }
                }
                for cell in digits.indices where digits[cell] == 0 && cands[cell].nonzeroBitCount == 1 {
                    return (cell, cands[cell].trailingZeroBitCount, .lastInCell, [cell])
                }
                return nil
            }

            /// One elimination by the technique: the candidates to take away and the cells that rule them out.
            func elimination(_ cands: [UInt16], _ technique: Technique) -> (remove: [(Int, UInt16)], cells: [Int], reason: Reason)? {
                // A number in a box kept to one row or column, or in a row or column kept to one box.
                for (a, unitA) in units.enumerated() {
                    for d in 1...n {
                        let places = unitA.filter { cands[$0] >> d & 1 == 1 }
                        guard places.count > 1 else { continue }
                        for (b, unitB) in units.enumerated() where b != a && (a >= 2 * n) != (b >= 2 * n) && places.allSatisfy(unitB.contains) {
                            let remove = unitB.filter { !places.contains($0) && cands[$0] >> d & 1 == 1 }.map { ($0, UInt16(1 << d)) }
                            if !remove.isEmpty { return (remove, places, .locked) }
                        }
                    }
                }
                guard technique >= .pairs else { return nil }
                for unit in units {
                    // Two cells with the same two numbers: no other cell of the unit takes them.
                    let twos = unit.filter { cands[$0].nonzeroBitCount == 2 }
                    for (i, x) in twos.enumerated() {
                        for y in twos[(i + 1)...] where cands[x] == cands[y] {
                            let remove = unit.filter { $0 != x && $0 != y && cands[$0] & cands[x] != 0 }.map { ($0, cands[x]) }
                            if !remove.isEmpty { return (remove, [x, y], .pair) }
                        }
                    }
                    // Two numbers with the same two places: those cells take nothing else.
                    let placesOf = (1...n).map { d in unit.filter { cands[$0] >> d & 1 == 1 } }
                    for d in 1...n where placesOf[d - 1].count == 2 {
                        for e in 1...n where e > d && placesOf[e - 1] == placesOf[d - 1] {
                            let keep = UInt16(1 << d | 1 << e)
                            let remove = placesOf[d - 1].filter { cands[$0] & ~keep != 0 }.map { ($0, ~keep) }
                            if !remove.isEmpty { return (remove, placesOf[d - 1], .pair) }
                        }
                    }
                }
                return nil
            }

            /// Fills what the technique forces; false when the board breaks (a cell or a unit with no way left).
            func propagate(_ digits: inout [Int], with technique: Technique) -> Bool {
                var cands = candidates(digits)
                while true {
                    for cell in digits.indices where digits[cell] == 0 && cands[cell] == 0 { return false }
                    for unit in units {
                        let have = unit.reduce(UInt16(0)) { $0 | cands[$1] | (digits[$1] == 0 ? 0 : UInt16(1 << digits[$1])) }
                        if have != all { return false }
                    }
                    if let s = single(digits, cands) {
                        digits[s.cell] = s.digit
                        cands[s.cell] = 0
                        for p in peers[s.cell] { cands[p] &= ~UInt16(1 << s.digit) }
                        continue
                    }
                    guard technique >= .locked, let e = elimination(cands, technique) else { return true }
                    for (cell, bits) in e.remove { cands[cell] &= ~bits }
                }
            }

            func solves(_ digits: [Int], with technique: Technique) -> Bool {
                var d = digits
                return propagate(&d, with: technique) && !d.contains(0)
            }

            /// The simplest forced placement from right numbers: a single, or a single once a locked number or a pair
            /// has ruled others out (the reason is then that technique, with its cells).
            func step(_ digits: [Int]) -> (cell: Int, digit: Int, reason: Reason, cells: [Int])? {
                var cands = candidates(digits)
                if let s = single(digits, cands) { return s }
                for technique in [Technique.locked, .pairs] {
                    var trial = cands
                    while let e = elimination(trial, technique) {
                        for (cell, bits) in e.remove { trial[cell] &= ~bits }
                        if let s = single(digits, trial) { return (s.cell, s.digit, e.reason, e.cells + [s.cell]) }
                    }
                    cands = trial
                }
                return nil
            }
        }
    }
}
