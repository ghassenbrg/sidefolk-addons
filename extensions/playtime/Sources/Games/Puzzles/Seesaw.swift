import Foundation

extension Games {
    /// Seesaw (the Takuzu family of puzzles): fill the board with hearts and stars so that every row and column
    /// balances, as many of each; no three alike sit side by side in a row or a column; and the clues between two
    /// cells hold, `=` the same mark on both sides, `×` different ones. 6 × 6 on Easy and Fair, 8 × 8 on Hard.
    ///
    /// Levels are the techniques the board needs: Easy only the plain rules one cell at a time (and a few spare
    /// marks), Fair also "every way to finish this row puts a heart here", Hard also a short chain ("a star here
    /// would break a column two moves on").
    struct Seesaw: PuzzleRules {
        enum Mark: Int8, Codable, Sendable, CaseIterable {
            case heart = 1, star = 2
            var other: Mark { self == .heart ? .star : .heart }
        }

        enum Clue: String, Codable, Sendable { case same, different }

        /// A clue between `cell` and the cell right of it, or below it when `down`.
        struct Edge: Codable, Equatable, Sendable {
            let cell: Int
            let down: Bool
            let clue: Clue
        }

        /// `set` a mark (nil clears it); `cycle` goes empty, heart, star, empty, for a click.
        enum Move: Codable, Equatable, Sendable {
            case set(Int, Mark?)
            case cycle(Int)
        }

        enum Rule: String, Codable, Sendable {
            /// Three alike side by side.
            case threeInARow
            /// More than half of a row or column alike.
            case tooMany
            /// A `=` or `×` clue broken.
            case clue
        }

        enum Reason: String, Codable, Sendable {
            /// This mark isn't right: take it back.
            case mistake
            /// Two alike side by side: the cell next to them is the other mark.
            case pair
            /// The cells either side are alike: this one is the other mark.
            case gap
            /// The clue beside it decides.
            case clue
            /// Its row or column already has its half of one mark.
            case full
            /// Every way to finish this row or column puts this mark here.
            case line
            /// The other mark here would break the rules a few moves on.
            case chain
            /// One cell of the solution (only for a board this solver didn't make).
            case reveal
        }

        typealias Grid = [Mark?]

        static let id = "seesaw"

        let level: Level
        let size: Int
        /// The marks given, nil where the person fills in.
        let givens: [Mark?]
        let edges: [Edge]
        let solution: [Mark]

        var start: Grid { givens }

        init(level: Level, size: Int, givens: [Mark?], edges: [Edge], solution: [Mark]) {
            self.level = level
            self.size = size
            self.givens = givens
            self.edges = edges
            self.solution = solution
        }

        static func generate(level: Level, using rng: inout Random) -> Seesaw {
            let size = level == .hard ? 8 : 6
            let technique: Technique = switch level { case .easy: .single; case .fair: .line; case .hard: .chain }
            var best: Seesaw?
            // A few tries for a board that really needs the level's technique; the last one is kept regardless.
            for _ in 0..<4 {
                let board = make(size: size, level: level, technique: technique, using: &rng)
                best = board
                if technique == .single || !Logic(board).solves(board.givensRaw, with: technique.easier) { break }
            }
            return best!
        }

        private static func make(size n: Int, level: Level, technique: Technique, using rng: inout Random) -> Seesaw {
            let solution = randomSolution(size: n, using: &rng)
            var all: [Edge] = []
            for cell in 0..<(n * n) {
                for down in [false, true] where down ? cell / n < n - 1 : cell % n < n - 1 {
                    let other = down ? cell + n : cell + 1
                    all.append(Edge(cell: cell, down: down, clue: solution[cell] == solution[other] ? .same : .different))
                }
            }
            let edges = Array(rng.shuffled(all).prefix(n == 8 ? rng.between(9, 12) : rng.between(5, 7)))
                .sorted { ($0.cell, $0.down ? 1 : 0) < ($1.cell, $1.down ? 1 : 0) }
            func logic(_ edges: [Edge]) -> Logic { Logic(Seesaw(level: level, size: n, givens: [], edges: edges, solution: solution)) }
            // Take marks away while the level's techniques still finish the board; Easy keeps a third as a head start.
            let keep = level == .easy ? n * n / 3 : 0
            var givens = solution.map(\.rawValue)
            let withAll = logic(edges)
            for cell in rng.shuffled(Array(0..<(n * n))) where givens.filter({ $0 != 0 }).count > keep {
                let mark = givens[cell]
                givens[cell] = 0
                if !withAll.solves(givens, with: technique) { givens[cell] = mark }
            }
            // Clues that nothing needs go too, except on Easy where they are a kindness.
            var kept = edges
            if level != .easy {
                for edge in rng.shuffled(edges) {
                    let without = kept.filter { $0 != edge }
                    if logic(without).solves(givens, with: technique) { kept = without }
                }
            }
            return Seesaw(level: level, size: n, givens: givens.map { Mark(rawValue: $0) }, edges: kept, solution: solution)
        }

        /// A full balanced board, row by row from the valid rows in a random order.
        private static func randomSolution(size n: Int, using rng: inout Random) -> [Mark] {
            let rows = Logic.patterns(n)
            let full = UInt16(1 << n) - 1
            var chosen: [UInt16] = []
            var hearts = Array(repeating: 0, count: n)
            func fill() -> Bool {
                let r = chosen.count
                if r == n { return true }
                for p in rng.shuffled(rows) {
                    if r >= 2 {
                        let a = chosen[r - 1], b = chosen[r - 2]
                        if p & a & b != 0 || ~p & ~a & ~b & full != 0 { continue }
                    }
                    let ok = (0..<n).allSatisfy { c in
                        let h = hearts[c] + Int((p >> c) & 1)
                        return h <= n / 2 && (r + 1 - h) <= n / 2
                    }
                    guard ok else { continue }
                    for c in 0..<n { hearts[c] += Int((p >> c) & 1) }
                    chosen.append(p)
                    if fill() { return true }
                    chosen.removeLast()
                    for c in 0..<n { hearts[c] -= Int((p >> c) & 1) }
                }
                return false
            }
            _ = fill()
            return chosen.flatMap { p in (0..<n).map { (p >> $0) & 1 == 1 ? Mark.heart : Mark.star } }
        }

        // MARK: Playing

        func apply(_ move: Move, to grid: inout Grid) throws {
            let (cell, mark): (Int, Mark?) = switch move {
            case .set(let cell, let mark): (cell, mark)
            case .cycle(let cell): (cell, grid.indices.contains(cell) ? (grid[cell] == nil ? .heart : grid[cell] == .heart ? .star : nil) : nil)
            }
            guard grid.indices.contains(cell) else { throw Refusal("off_board") }
            guard givens[cell] == nil else { throw Refusal("given") }
            grid[cell] = mark
        }

        func conflicts(in grid: Grid) -> [PuzzleConflict<Rule>] {
            var out: [PuzzleConflict<Rule>] = []
            for line in 0..<(2 * size) {
                let cells = lineCells(line)
                // Runs of one mark, closed by a different mark, an empty cell or the edge.
                var run: [Int] = []
                for cell in cells + [-1] {
                    let mark = cell >= 0 ? grid[cell] : nil
                    if let mark, let last = run.last, grid[last] == mark {
                        run.append(cell)
                        continue
                    }
                    if run.count >= 3 { out.append(PuzzleConflict(rule: .threeInARow, cells: run)) }
                    run = mark == nil ? [] : [cell]
                }
                for mark in Mark.allCases {
                    let alike = cells.filter { grid[$0] == mark }
                    if alike.count > size / 2 { out.append(PuzzleConflict(rule: .tooMany, cells: alike)) }
                }
            }
            for edge in edges {
                let other = edge.down ? edge.cell + size : edge.cell + 1
                guard let a = grid[edge.cell], let b = grid[other] else { continue }
                if (a == b) != (edge.clue == .same) { out.append(PuzzleConflict(rule: .clue, cells: [edge.cell, other])) }
            }
            return out
        }

        func isSolved(_ grid: Grid) -> Bool { !grid.contains(nil) && conflicts(in: grid).isEmpty }

        func hint(for grid: Grid) -> PuzzleHint<Move, Reason> {
            if let wrong = grid.indices.first(where: { grid[$0] != nil && grid[$0] != solution[$0] }) {
                return PuzzleHint(move: .set(wrong, nil), reason: .mistake, cells: [wrong])
            }
            let raw = grid.map { $0?.rawValue ?? 0 }
            if let step = Logic(self).step(raw) {
                return PuzzleHint(move: .set(step.cell, Mark(rawValue: step.mark)), reason: step.reason, cells: step.cells)
            }
            let cell = grid.indices.first { grid[$0] == nil } ?? 0
            return PuzzleHint(move: .set(cell, solution[cell]), reason: .reveal, cells: [cell])
        }

        /// A row's cells (lines 0 ..< size) or a column's (size ..< 2 × size), in order.
        func lineCells(_ line: Int) -> [Int] {
            line < size ? (0..<size).map { line * size + $0 } : (0..<size).map { $0 * size + line - size }
        }

        fileprivate var givensRaw: [Int8] { givens.map { $0?.rawValue ?? 0 } }

        // MARK: The solver

        enum Technique: Int, Comparable {
            case single, line, chain
            static func < (a: Technique, b: Technique) -> Bool { a.rawValue < b.rawValue }
            var easier: Technique { Technique(rawValue: max(0, rawValue - 1))! }
        }

        /// The logic a person uses, on bit masks per row and column: bit i of a line is its i-th cell, a mark's mask
        /// the cells holding it; a clue's mask has bit i for the clue between cells i and i + 1.
        struct Logic {
            let n: Int
            let full: UInt16
            let patterns: [UInt16]
            /// Per line (rows, then columns): the `=` and `×` clues inside it.
            var same: [UInt16]
            var different: [UInt16]

            init(_ board: Seesaw) {
                n = board.size
                full = UInt16(1 << n) - 1
                patterns = Self.patterns(n)
                same = Array(repeating: 0, count: 2 * n)
                different = Array(repeating: 0, count: 2 * n)
                for edge in board.edges {
                    let line = edge.down ? n + edge.cell % n : edge.cell / n
                    let bit = UInt16(1) << (edge.down ? edge.cell / n : edge.cell % n)
                    if edge.clue == .same { same[line] |= bit } else { different[line] |= bit }
                }
            }

            /// Every valid line of n cells as the mask of its hearts: half hearts, no three alike.
            static func patterns(_ n: Int) -> [UInt16] {
                let full = (1 << n) - 1
                return (0...full).filter { p in
                    p.nonzeroBitCount == n / 2 && p & (p >> 1) & (p >> 2) == 0 && (~p & full) & ((~p & full) >> 1) & ((~p & full) >> 2) == 0
                }.map { UInt16($0) }
            }

            func cell(_ line: Int, _ i: Int) -> Int { line < n ? line * n + i : i * n + line - n }

            func masks(_ grid: [Int8], _ line: Int) -> (hearts: UInt16, stars: UInt16) {
                var h: UInt16 = 0, s: UInt16 = 0
                for i in 0..<n {
                    switch grid[cell(line, i)] {
                    case 1: h |= 1 << i
                    case 2: s |= 1 << i
                    default: break
                    }
                }
                return (h, s)
            }

            /// What the plain rules force in a line, or nil when the line already breaks one.
            func singles(_ h: UInt16, _ s: UInt16, _ line: Int) -> (hearts: UInt16, stars: UInt16)? {
                let eq = same[line], ne = different[line]
                let open = full & ~(h | s)
                if h & (h >> 1) & (h >> 2) != 0 || s & (s >> 1) & (s >> 2) != 0 { return nil }
                if h.nonzeroBitCount > n / 2 || s.nonzeroBitCount > n / 2 { return nil }
                if ((h & (s >> 1)) | (s & (h >> 1))) & eq != 0 || ((h & (h >> 1)) | (s & (s >> 1))) & ne != 0 { return nil }
                func beside(_ m: UInt16) -> UInt16 { ((m << 1) & (m << 2)) | ((m >> 1) & (m >> 2)) | ((m << 1) & (m >> 1)) }
                // Next to two alike or between them: the other mark. Across `=`: the same; across `×`: the other.
                var toHeart = beside(s) | ((h & eq) << 1) | ((h >> 1) & eq) | ((s & ne) << 1) | ((s >> 1) & ne)
                var toStar = beside(h) | ((s & eq) << 1) | ((s >> 1) & eq) | ((h & ne) << 1) | ((h >> 1) & ne)
                if h.nonzeroBitCount == n / 2 { toStar |= open }
                if s.nonzeroBitCount == n / 2 { toHeart |= open }
                toStar &= open
                toHeart &= open
                return toStar & toHeart == 0 ? (toHeart, toStar) : nil
            }

            /// What every way to finish the line agrees on, or nil when there is none.
            func lineForced(_ h: UInt16, _ s: UInt16, _ line: Int) -> (hearts: UInt16, stars: UInt16)? {
                let eq = same[line], ne = different[line]
                var all = full, any: UInt16 = 0, found = false
                for p in patterns where p & s == 0 && h & ~p == 0 {
                    let flips = p ^ (p >> 1)
                    guard flips & eq == 0, flips & ne == ne else { continue }
                    all &= p
                    any |= p
                    found = true
                }
                guard found else { return nil }
                let open = full & ~(h | s)
                return (all & open, ~any & full & open)
            }

            /// Fills everything the techniques force; false when the board breaks a rule on the way.
            func propagate(_ grid: inout [Int8], with technique: Technique) -> Bool {
                var changed = true
                while changed {
                    changed = false
                    for line in 0..<(2 * n) {
                        let (h, s) = masks(grid, line)
                        guard h | s != full else {
                            if singles(h, s, line) == nil || (technique >= .line && lineForced(h, s, line) == nil) { return false }
                            continue
                        }
                        guard var forced = singles(h, s, line) else { return false }
                        if technique >= .line {
                            guard let more = lineForced(h, s, line) else { return false }
                            forced = (forced.hearts | more.hearts, forced.stars | more.stars)
                            if forced.hearts & forced.stars != 0 { return false }
                        }
                        for i in 0..<n where (forced.hearts | forced.stars) >> i & 1 == 1 {
                            grid[cell(line, i)] = forced.hearts >> i & 1 == 1 ? 1 : 2
                            changed = true
                        }
                    }
                    if !changed, technique == .chain, let (cell, mark) = chainStep(grid) {
                        grid[cell] = mark
                        changed = true
                    }
                }
                return true
            }

            /// The first open cell where one mark leads to a broken rule (by the line technique), and the other mark.
            func chainStep(_ grid: [Int8]) -> (cell: Int, mark: Int8)? {
                for cell in grid.indices where grid[cell] == 0 {
                    for mark: Int8 in [1, 2] {
                        var trial = grid
                        trial[cell] = mark
                        if !propagate(&trial, with: .line) { return (cell, 3 - mark) }
                    }
                }
                return nil
            }

            func solves(_ grid: [Int8], with technique: Technique) -> Bool {
                var g = grid
                return propagate(&g, with: technique) && !g.contains(0)
            }

            /// The simplest forced move on a board whose marks are all right, with its reason and the cells it rests on.
            func step(_ grid: [Int8]) -> (cell: Int, mark: Int8, reason: Reason, cells: [Int])? {
                let open = grid.indices.filter { grid[$0] == 0 }
                for reason in [Reason.pair, .gap, .clue, .full] {
                    for c in open {
                        if let found = single(reason, at: c, grid) { return (c, found.mark, reason, found.cells) }
                    }
                }
                for line in 0..<(2 * n) {
                    let (h, s) = masks(grid, line)
                    guard let forced = lineForced(h, s, line), forced.hearts | forced.stars != 0 else { continue }
                    let i = (forced.hearts | forced.stars).trailingZeroBitCount
                    return (cell(line, i), forced.hearts >> i & 1 == 1 ? 1 : 2, .line, (0..<n).map { cell(line, $0) })
                }
                if let (c, mark) = chainStep(grid) { return (c, mark, .chain, [c]) }
                return nil
            }

            /// Whether one plain rule alone fixes `c`, and the cells it rests on.
            private func single(_ reason: Reason, at c: Int, _ grid: [Int8]) -> (mark: Int8, cells: [Int])? {
                let r = c / n, col = c % n
                for (line, i) in [(r, col), (n + col, r)] {
                    let at = { (j: Int) -> Int8 in (0..<n).contains(j) ? grid[cell(line, j)] : 0 }
                    switch reason {
                    case .pair:
                        for (a, b) in [(i - 1, i - 2), (i + 1, i + 2)] where at(a) != 0 && at(a) == at(b) {
                            return (3 - at(a), [cell(line, a), cell(line, b)])
                        }
                    case .gap:
                        if at(i - 1) != 0, at(i - 1) == at(i + 1) { return (3 - at(i - 1), [cell(line, i - 1), cell(line, i + 1)]) }
                    case .clue:
                        for (j, bit) in [(i - 1, i - 1), (i + 1, i)] where at(j) != 0 && bit >= 0 && bit < n - 1 {
                            if same[line] >> bit & 1 == 1 { return (at(j), [cell(line, j)]) }
                            if different[line] >> bit & 1 == 1 { return (3 - at(j), [cell(line, j)]) }
                        }
                    case .full:
                        let (h, s) = masks(grid, line)
                        if h.nonzeroBitCount == n / 2 { return (2, (0..<n).map { cell(line, $0) }) }
                        if s.nonzeroBitCount == n / 2 { return (1, (0..<n).map { cell(line, $0) }) }
                    default:
                        break
                    }
                }
                return nil
            }
        }
    }
}
