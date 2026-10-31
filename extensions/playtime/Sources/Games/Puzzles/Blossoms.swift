import Foundation

extension Games {
    /// Blossoms (the Star Battle family of puzzles, one star each): plant one blossom in every row, every column and
    /// every flower bed (the coloured regions), with no two blossoms touching, not even corner to corner. A dot marks a
    /// cell the person has ruled out. 6 × 6 on Easy, 7 × 7 or 8 × 8 on Fair, 8 × 8 or 9 × 9 on Hard.
    ///
    /// Levels are the techniques the board needs: Easy a last place, a bed kept to one row or column, and a cell whose
    /// blossom would leave a row, column or bed no room; Fair also beds that together fill as many rows; Hard also a
    /// short chain.
    struct Blossoms: PuzzleRules {
        enum Mark: Int8, Codable, Sendable {
            /// Ruled out.
            case dot = 1
            case blossom = 2
        }

        /// `set` a mark (nil clears it); `cycle` goes empty, dot, blossom, empty, for a click.
        enum Move: Codable, Equatable, Sendable {
            case set(Int, Mark?)
            case cycle(Int)
        }

        enum Rule: String, Codable, Sendable {
            /// Two blossoms in a row, a column or a bed.
            case row, column, bed
            /// Two blossoms side by side or corner to corner.
            case touching
            /// A row, column or bed with every cell ruled out.
            case noRoom
        }

        enum Reason: String, Codable, Sendable {
            /// This mark isn't right: take it back.
            case mistake
            /// The last place left in a row, column or bed.
            case lastInRow, lastInColumn, lastInBed
            /// A bed kept to one row or column (or a row or column kept to one bed) rules out the rest of it.
            case locked
            /// A blossom in the cells it rules out would leave a row, column or bed no room.
            case wouldEmpty
            /// Some beds that together fill as many rows (or columns) rule out the rest of those rows.
            case group
            /// A blossom in the cells it rules out leads to a dead end a few moves on.
            case chain
            /// One cell of the solution (only for a board this solver didn't make).
            case reveal
        }

        typealias Grid = [Mark?]

        static let id = "blossoms"

        let level: Level
        let size: Int
        /// The bed of each cell, 0 ..< size.
        let beds: [Int]
        /// The blossom's column in each row.
        let solution: [Int]

        var start: Grid { Array(repeating: nil, count: size * size) }

        func isBlossom(_ cell: Int) -> Bool { solution[cell / size] == cell % size }

        static func generate(level: Level, using rng: inout Random) -> Blossoms {
            let technique: Technique = switch level { case .easy: .single; case .fair: .group; case .hard: .chain }
            var found = 0
            while true {
                let size = switch level { case .easy: 6; case .fair: rng.between(7, 8); case .hard: rng.between(8, 9) }
                guard let board = make(size: size, level: level, using: &rng) else { continue }
                let logic = Logic(board)
                guard logic.solves(with: technique) else { continue }
                found += 1
                // Fair and Hard prefer a board the Easy techniques can't finish, within a few boards.
                if technique == .single || found >= 10 || !logic.solves(with: .single) { return board }
            }
        }

        /// A board with one solution, or nil when this layout couldn't be made unique.
        private static func make(size n: Int, level: Level, using rng: inout Random) -> Blossoms? {
            let solution = randomPlacement(size: n, using: &rng)
            var beds = Array(repeating: -1, count: n * n)
            for (r, c) in solution.enumerated() { beds[r * n + c] = r }
            // Beds grow from their blossoms, one random neighbouring cell at a time.
            while beds.contains(-1) {
                let open = beds.indices.filter { cell in
                    beds[cell] == -1 && PuzzleGrid.neighbours(cell, width: n, height: n).contains { beds[$0] >= 0 }
                }
                let cell = rng.pick(open)
                beds[cell] = beds[rng.pick(PuzzleGrid.neighbours(cell, width: n, height: n).filter { beds[$0] >= 0 })]
            }
            // While another solution exists, a cell where it puts a blossom moves to a neighbouring bed, which then
            // holds two of that solution's blossoms: it is gone, and the true one is untouched.
            for _ in 0..<80 {
                let board = Blossoms(level: level, size: n, beds: beds, solution: solution)
                guard let other = Logic(board).solution(otherThan: solution) else { return board }
                var moved = false
                for r in rng.shuffled(Array(0..<n)) where other[r] != solution[r] && !moved {
                    let cell = r * n + other[r]
                    let bed = beds[cell]
                    for target in rng.shuffled(PuzzleGrid.neighbours(cell, width: n, height: n).map { beds[$0] }) where target != bed {
                        var trial = beds
                        trial[cell] = target
                        if connected(trial, bed: bed, from: bed * n + solution[bed], size: n) {
                            beds = trial
                            moved = true
                            break
                        }
                    }
                }
                if !moved { return nil }
            }
            return nil
        }

        /// One blossom per row and column, none touching: columns row by row in a random order.
        private static func randomPlacement(size n: Int, using rng: inout Random) -> [Int] {
            var columns: [Int] = []
            func place() -> Bool {
                if columns.count == n { return true }
                for c in rng.shuffled(Array(0..<n)) where !columns.contains(c) && (columns.last.map { abs($0 - c) > 1 } ?? true) {
                    columns.append(c)
                    if place() { return true }
                    columns.removeLast()
                }
                return false
            }
            _ = place()
            return columns
        }

        private static func connected(_ beds: [Int], bed: Int, from start: Int, size n: Int) -> Bool {
            var seen: Set<Int> = [start], queue = [start]
            while let cell = queue.popLast() {
                for next in PuzzleGrid.neighbours(cell, width: n, height: n) where beds[next] == bed && seen.insert(next).inserted {
                    queue.append(next)
                }
            }
            return seen.count == beds.filter { $0 == bed }.count
        }

        init(level: Level, size: Int, beds: [Int], solution: [Int]) {
            self.level = level
            self.size = size
            self.beds = beds
            self.solution = solution
        }

        // MARK: Playing

        func apply(_ move: Move, to grid: inout Grid) throws {
            let (cell, mark): (Int, Mark?) = switch move {
            case .set(let cell, let mark): (cell, mark)
            case .cycle(let cell): (cell, grid.indices.contains(cell) ? (grid[cell] == nil ? .dot : grid[cell] == .dot ? .blossom : nil) : nil)
            }
            guard grid.indices.contains(cell) else { throw Refusal("off_board") }
            grid[cell] = mark
        }

        func conflicts(in grid: Grid) -> [PuzzleConflict<Rule>] {
            let logic = Logic(self)
            var out: [PuzzleConflict<Rule>] = []
            for (u, unit) in logic.units.enumerated() {
                let rule: Rule = u < size ? .row : u < 2 * size ? .column : .bed
                let planted = unit.filter { grid[$0] == .blossom }
                if planted.count > 1 { out.append(PuzzleConflict(rule: rule, cells: planted)) }
                if unit.allSatisfy({ grid[$0] == .dot }) { out.append(PuzzleConflict(rule: .noRoom, cells: unit)) }
            }
            for cell in grid.indices where grid[cell] == .blossom {
                for next in PuzzleGrid.neighbours(cell, width: size, height: size, diagonals: true) where next > cell && grid[next] == .blossom {
                    out.append(PuzzleConflict(rule: .touching, cells: [cell, next]))
                }
            }
            return out
        }

        func isSolved(_ grid: Grid) -> Bool {
            grid.filter { $0 == .blossom }.count == size && conflicts(in: grid).isEmpty
        }

        func hint(for grid: Grid) -> PuzzleHint<Move, Reason> {
            if let wrong = grid.indices.first(where: { grid[$0] != nil && (grid[$0] == .blossom) != isBlossom($0) }) {
                return PuzzleHint(move: .set(wrong, nil), reason: .mistake, cells: [wrong])
            }
            let known = grid.map { $0?.rawValue ?? 0 }
            if let step = Logic(self).step(known) {
                return PuzzleHint(move: .set(step.cell, .blossom), reason: step.reason, cells: step.cells)
            }
            let cell = (0..<size).map { $0 * size + solution[$0] }.first { grid[$0] != .blossom } ?? 0
            return PuzzleHint(move: .set(cell, .blossom), reason: .reveal, cells: [cell])
        }

        // MARK: The solver

        enum Technique: Int, Comparable {
            case single, group, chain
            static func < (a: Technique, b: Technique) -> Bool { a.rawValue < b.rawValue }
        }

        /// The logic on a board of 0 (open), 1 (ruled out) and 2 (a blossom).
        struct Logic {
            let n: Int
            /// Rows, then columns, then beds.
            let units: [[Int]]
            /// The three units of each cell.
            let unitsOf: [[Int]]
            /// The cells a blossom rules out: its row, column, bed and the eight around it.
            let shadow: [[Int]]
            let beds: [Int]

            init(_ board: Blossoms) {
                let n = board.size
                self.n = n
                beds = board.beds
                var units = (0..<n).map { r in (0..<n).map { r * n + $0 } }
                units += (0..<n).map { c in (0..<n).map { $0 * n + c } }
                units += (0..<n).map { b in (0..<(n * n)).filter { board.beds[$0] == b } }
                self.units = units
                unitsOf = (0..<(n * n)).map { [$0 / n, n + $0 % n, 2 * n + board.beds[$0]] }
                shadow = (0..<(n * n)).map { cell in
                    var seen = Array(repeating: false, count: n * n)
                    for u in [cell / n, n + cell % n, 2 * n + board.beds[cell]] { for c in units[u] { seen[c] = true } }
                    for c in PuzzleGrid.neighbours(cell, width: n, height: n, diagonals: true) { seen[c] = true }
                    seen[cell] = false
                    return seen.indices.filter { seen[$0] }
                }
            }

            /// A solution other than `known`, by plain search (the generator's uniqueness check).
            func solution(otherThan known: [Int]) -> [Int]? {
                var columns: [Int] = [], usedBeds = Array(repeating: false, count: n), found: [Int]?
                func go() {
                    if found != nil { return }
                    let r = columns.count
                    if r == n {
                        if columns != known { found = columns }
                        return
                    }
                    for c in 0..<n where !columns.contains(c) && (columns.last.map { abs($0 - c) > 1 } ?? true) && !usedBeds[beds[r * n + c]] {
                        usedBeds[beds[r * n + c]] = true
                        columns.append(c)
                        go()
                        columns.removeLast()
                        usedBeds[beds[r * n + c]] = false
                    }
                }
                go()
                return found
            }

            func plant(_ cell: Int, _ grid: inout [Int8]) {
                grid[cell] = 2
                for c in shadow[cell] where grid[c] == 0 { grid[c] = 1 }
            }

            enum Single { case broken, none, at(cell: Int, unit: Int) }

            /// The last open place of a unit without a blossom, or `broken` when a unit has no room or two blossoms.
            func single(_ grid: [Int8]) -> Single {
                var found = Single.none
                for (u, unit) in units.enumerated() {
                    var open = 0, planted = 0, last = -1
                    for c in unit {
                        if grid[c] == 0 {
                            open += 1
                            last = c
                        } else if grid[c] == 2 {
                            planted += 1
                        }
                    }
                    if planted > 1 || (planted == 0 && open == 0) { return .broken }
                    if planted == 0, open == 1, case .none = found { found = .at(cell: last, unit: u) }
                }
                return found
            }

            /// One way to rule cells out, the simplest first: the cells and those the reason rests on.
            func elimination(_ grid: [Int8], _ technique: Technique) -> (out: [Int], cells: [Int], reason: Reason)? {
                let open = units.map { $0.filter { grid[$0] == 0 } }
                let planted = units.map { $0.contains { grid[$0] == 2 } }
                // A unit whose open cells all lie in a unit of another kind: that unit's blossom is among them.
                for (a, cells) in open.enumerated() where !planted[a] && !cells.isEmpty {
                    for b in unitsOf[cells[0]] where b / n != a / n && cells.allSatisfy({ unitsOf[$0].contains(b) }) {
                        let out = open[b].filter { !cells.contains($0) }
                        if !out.isEmpty { return (out, cells, .locked) }
                    }
                }
                // A blossom here would leave a unit without room.
                for cell in grid.indices where grid[cell] == 0 {
                    let shade = Set(shadow[cell])
                    for (u, cells) in open.enumerated() where !planted[u] && !cells.contains(cell) && cells.allSatisfy(shade.contains) {
                        return ([cell], cells + [cell], .wouldEmpty)
                    }
                }
                guard technique >= .group else { return nil }
                // k beds whose open cells lie in k rows (or columns), and k rows (or columns) whose open cells lie in k beds.
                for (from, to) in [(2, 0), (2, 1), (0, 2), (1, 2)] {
                    let groups = (0..<n).map { from * n + $0 }.filter { !planted[$0] }
                    let spans: [Int: Int] = Dictionary(uniqueKeysWithValues: groups.map { u in
                        (u, open[u].reduce(0) { $0 | 1 << (unitsOf[$1][to] - to * n) })
                    })
                    for subset in 1..<(1 << groups.count) where (2...4).contains(subset.nonzeroBitCount) && subset.nonzeroBitCount < groups.count {
                        let chosen = groups.indices.filter { subset >> $0 & 1 == 1 }.map { groups[$0] }
                        let span = chosen.reduce(0) { $0 | spans[$1]! }
                        guard span.nonzeroBitCount == chosen.count else { continue }
                        let inside = chosen.flatMap { open[$0] }
                        let out = (0..<n).filter { span >> $0 & 1 == 1 }.flatMap { open[to * n + $0] }.filter { !inside.contains($0) }
                        if !out.isEmpty { return (out, inside, .group) }
                    }
                }
                guard technique >= .chain else { return nil }
                for cell in grid.indices where grid[cell] == 0 {
                    var trial = grid
                    plant(cell, &trial)
                    if !propagate(&trial, with: .group) { return ([cell], [cell], .chain) }
                }
                return nil
            }

            /// Plants and rules out all the techniques force; false when the board breaks.
            func propagate(_ grid: inout [Int8], with technique: Technique) -> Bool {
                while true {
                    switch single(grid) {
                    case .broken: return false
                    case .at(let cell, _):
                        plant(cell, &grid)
                        continue
                    case .none: break
                    }
                    guard let e = elimination(grid, technique) else { return true }
                    for c in e.out { grid[c] = 1 }
                }
            }

            func solves(with technique: Technique) -> Bool {
                var grid = Array(repeating: Int8(0), count: n * n)
                return propagate(&grid, with: technique) && grid.filter { $0 == 2 }.count == n
            }

            /// The next blossom forced from marks that are all right: a last place, or a last place once a technique
            /// has ruled cells out (the reason is then that technique, with the cells it rests on).
            func step(_ known: [Int8]) -> (cell: Int, reason: Reason, cells: [Int])? {
                var grid = known
                for cell in grid.indices where known[cell] == 2 { plant(cell, &grid) }
                func last(_ grid: [Int8]) -> (cell: Int, unit: Int)? {
                    guard case .at(let cell, let unit) = single(grid) else { return nil }
                    return (cell, unit)
                }
                if let s = last(grid) {
                    return (s.cell, s.unit < n ? .lastInRow : s.unit < 2 * n ? .lastInColumn : .lastInBed, units[s.unit])
                }
                for technique in [Technique.single, .group, .chain] {
                    var trial = grid
                    while let e = elimination(trial, technique) {
                        for c in e.out { trial[c] = 1 }
                        if let s = last(trial) { return (s.cell, e.reason, e.cells + [s.cell]) }
                    }
                    grid = trial
                }
                return nil
            }
        }
    }
}
