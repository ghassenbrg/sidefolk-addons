import Foundation

extension Games {
    /// Garden Plots (the Shikaku family of puzzles): split the garden into rectangular plots so that each plot holds
    /// exactly one number, and that number is how many squares the plot covers. 6 × 6 on Easy, 7 × 7 on Fair, 8 × 8 on
    /// Hard. A plot is drawn by dragging from one corner to the other; a new plot replaces any it overlaps.
    ///
    /// Levels are the techniques the board needs: Easy a number with only one plot that fits, or a square only one
    /// number can reach; Fair also a plot that would leave another number nowhere to go; Hard also a short chain.
    struct GardenPlots: PuzzleRules {
        struct Plot: Codable, Hashable, Sendable {
            let row: Int
            let column: Int
            let height: Int
            let width: Int

            var area: Int { height * width }

            func contains(_ cell: Int, width w: Int) -> Bool {
                let r = cell / w, c = cell % w
                return r >= row && r < row + height && c >= column && c < column + width
            }

            func cells(width w: Int) -> [Int] {
                (row..<(row + height)).flatMap { r in (column..<(column + width)).map { r * w + $0 } }
            }

            /// The plot between two corners, in either order, as a drag draws it.
            static func corners(_ a: Int, _ b: Int, width w: Int) -> Plot {
                Plot(row: min(a / w, b / w), column: min(a % w, b % w), height: abs(a / w - b / w) + 1, width: abs(a % w - b % w) + 1)
            }
        }

        struct Clue: Codable, Equatable, Sendable {
            let cell: Int
            let area: Int
        }

        enum Move: Codable, Equatable, Sendable {
            /// A plot, replacing any it overlaps.
            case draw(Plot)
            /// Takes away the plot over this cell.
            case erase(Int)
        }

        enum Rule: String, Codable, Sendable {
            case noNumber
            case twoNumbers
            /// One number, but not as many squares as it says.
            case wrongSize
        }

        enum Reason: String, Codable, Sendable {
            /// This plot isn't right: take it away.
            case mistake
            /// Only one plot of that size fits around this number.
            case onlyFit
            /// A square here only this number can reach.
            case onlyReach
            /// Squares every plot of another number covers are taken.
            case claimed
            /// Any other plot for this number would leave another number, or a square, with nowhere to go.
            case wouldBlock
            /// Any other plot leads to a dead end a few plots on.
            case chain
            /// One plot of the solution (only for a board this solver didn't make).
            case reveal
        }

        typealias Grid = [Plot]

        static let id = "plots"

        let level: Level
        let width: Int
        let height: Int
        /// In reading order.
        let clues: [Clue]
        /// The plot of each clue, in the same order.
        let solution: [Plot]

        var start: Grid { [] }

        static func generate(level: Level, using rng: inout Random) -> GardenPlots {
            let size = switch level { case .easy: 6; case .fair: 7; case .hard: 8 }
            let technique: Technique = switch level { case .easy: .claimed; case .fair: .block; case .hard: .chain }
            let largest = switch level { case .easy: 6; case .fair: 9; case .hard: 12 }
            while true {
                let plots = partition(size: size, largest: largest, using: &rng)
                // Numbers placed at random in each plot until the techniques find the one way; else a new partition.
                for _ in 0..<12 {
                    let numbered = plots.map { ($0, rng.pick($0.cells(width: size))) }.sorted { $0.1 < $1.1 }
                    let board = GardenPlots(level: level, width: size, height: size,
                                            clues: numbered.map { Clue(cell: $0.1, area: $0.0.area) }, solution: numbered.map(\.0))
                    if Logic(board).solves(with: technique) { return board }
                }
            }
        }

        /// Plots covering the whole garden: from the first open cell in reading order, a random rectangle of open
        /// cells (single cells only when nothing larger fits).
        private static func partition(size n: Int, largest: Int, using rng: inout Random) -> [Plot] {
            var taken = Array(repeating: false, count: n * n)
            var plots: [Plot] = []
            while let first = taken.firstIndex(of: false) {
                let r = first / n, c = first % n
                var options: [Plot] = []
                for h in 1...(n - r) {
                    for w in 1...(n - c) where h * w <= largest && h * w > 1 {
                        let plot = Plot(row: r, column: c, height: h, width: w)
                        if plot.cells(width: n).allSatisfy({ !taken[$0] }) { options.append(plot) }
                    }
                }
                let plot = options.isEmpty ? Plot(row: r, column: c, height: 1, width: 1) : rng.pick(options)
                for cell in plot.cells(width: n) { taken[cell] = true }
                plots.append(plot)
            }
            return plots
        }

        // MARK: Playing

        func apply(_ move: Move, to grid: inout Grid) throws {
            switch move {
            case .draw(let plot):
                guard plot.row >= 0, plot.column >= 0, plot.height > 0, plot.width > 0,
                      plot.row + plot.height <= height, plot.column + plot.width <= width else { throw Refusal("off_board") }
                guard !grid.contains(plot) else { return }
                let cells = Set(plot.cells(width: width))
                grid.removeAll { !cells.isDisjoint(with: $0.cells(width: width)) }
                grid.append(plot)
            case .erase(let cell):
                grid.removeAll { $0.contains(cell, width: width) }
            }
        }

        func conflicts(in grid: Grid) -> [PuzzleConflict<Rule>] {
            grid.compactMap { plot in
                let inside = clues.filter { plot.contains($0.cell, width: width) }
                let rule: Rule? = inside.isEmpty ? .noNumber : inside.count > 1 ? .twoNumbers : inside[0].area != plot.area ? .wrongSize : nil
                return rule.map { PuzzleConflict(rule: $0, cells: plot.cells(width: width)) }
            }
        }

        func isSolved(_ grid: Grid) -> Bool {
            grid.reduce(0) { $0 + $1.area } == width * height && conflicts(in: grid).isEmpty
        }

        func hint(for grid: Grid) -> PuzzleHint<Move, Reason> {
            if let wrong = grid.first(where: { !solution.contains($0) }) {
                return PuzzleHint(move: .erase(wrong.row * width + wrong.column), reason: .mistake, cells: wrong.cells(width: width))
            }
            if let (k, reason) = Logic(self).step(placed: grid) {
                return PuzzleHint(move: .draw(solution[k]), reason: reason, cells: solution[k].cells(width: width))
            }
            let k = solution.firstIndex { !grid.contains($0) } ?? 0
            return PuzzleHint(move: .draw(solution[k]), reason: .reveal, cells: solution[k].cells(width: width))
        }

        // MARK: The solver

        enum Technique: Int, Comparable, CaseIterable {
            case fit, reach, claimed, block, chain
            static func < (a: Technique, b: Technique) -> Bool { a.rawValue < b.rawValue }

            var reason: Reason {
                switch self {
                case .fit: .onlyFit
                case .reach: .onlyReach
                case .claimed: .claimed
                case .block: .wouldBlock
                case .chain: .chain
                }
            }
        }

        /// Each number's possible plots as bit masks over the garden (at most 8 × 8, one bit a cell). A number with
        /// one plot left has it.
        struct Logic {
            let full: UInt64
            let cells: Int
            /// Per clue, the plots that fit: the right size, around it, over no other number.
            let options: [[UInt64]]
            let plots: [[Plot]]

            init(_ board: GardenPlots) {
                let w = board.width, h = board.height
                cells = w * h
                full = cells == 64 ? .max : (UInt64(1) << cells) - 1
                let clueCells = Set(board.clues.map(\.cell))
                var options: [[UInt64]] = [], plots: [[Plot]] = []
                for clue in board.clues {
                    let r = clue.cell / w, c = clue.cell % w
                    var masks: [UInt64] = [], found: [Plot] = []
                    for ph in 1...h where clue.area % ph == 0 && clue.area / ph <= w {
                        let pw = clue.area / ph
                        for top in max(0, r - ph + 1)...min(r, h - ph) {
                            for left in max(0, c - pw + 1)...min(c, w - pw) {
                                let plot = Plot(row: top, column: left, height: ph, width: pw)
                                let inside = plot.cells(width: w)
                                guard inside.allSatisfy({ $0 == clue.cell || !clueCells.contains($0) }) else { continue }
                                masks.append(inside.reduce(UInt64(0)) { $0 | 1 << UInt64($1) })
                                found.append(plot)
                            }
                        }
                    }
                    options.append(masks)
                    plots.append(found)
                }
                self.options = options
                self.plots = plots
            }

            /// One round of the techniques up to `technique`: nil when the board can't be finished, else whether
            /// anything was ruled out.
            func pass(_ alive: inout [[UInt64]], _ technique: Technique) -> Bool? {
                var changed = false
                func keep(_ k: Int, _ test: (UInt64) -> Bool) {
                    let before = alive[k].count
                    alive[k] = alive[k].filter(test)
                    if alive[k].count != before { changed = true }
                }
                // A number with one plot has it: the others can't overlap it.
                for k in alive.indices where alive[k].count == 1 {
                    let fixed = alive[k][0]
                    for j in alive.indices where j != k { keep(j) { $0 & fixed == 0 } }
                }
                if alive.contains(where: \.isEmpty) { return nil }
                if technique >= .reach {
                    let reach = alive.map { $0.reduce(UInt64(0), |) }
                    for cell in 0..<cells {
                        let bit = UInt64(1) << UInt64(cell)
                        let by = reach.indices.filter { reach[$0] & bit != 0 }
                        if by.isEmpty { return nil }
                        if by.count == 1 { keep(by[0]) { $0 & bit != 0 } }
                    }
                    if alive.contains(where: \.isEmpty) { return nil }
                }
                if technique >= .claimed {
                    for k in alive.indices where alive[k].count > 1 {
                        let common = alive[k].reduce(full, &)
                        if common == 0 { continue }
                        for j in alive.indices where j != k { keep(j) { $0 & common == 0 } }
                    }
                    if alive.contains(where: \.isEmpty) { return nil }
                }
                if technique >= .block {
                    for k in alive.indices where alive[k].count > 1 {
                        keep(k) { x in
                            var covered = x
                            for j in alive.indices where j != k {
                                let room = alive[j].filter { $0 & x == 0 }
                                if room.isEmpty { return false }
                                covered |= room.reduce(UInt64(0), |)
                            }
                            return covered == full
                        }
                    }
                    if alive.contains(where: \.isEmpty) { return nil }
                }
                if technique >= .chain, !changed {
                    for k in alive.indices where alive[k].count > 1 {
                        keep(k) { x in
                            var trial = alive
                            trial[k] = [x]
                            return reduce(&trial, .block)
                        }
                        if changed { break }
                    }
                    if alive.contains(where: \.isEmpty) { return nil }
                }
                return changed
            }

            /// Every round until nothing changes; false when the board can't be finished.
            func reduce(_ alive: inout [[UInt64]], _ technique: Technique) -> Bool {
                while true {
                    guard let changed = pass(&alive, technique) else { return false }
                    if !changed { return true }
                }
            }

            func solves(with technique: Technique) -> Bool {
                var alive = options
                return reduce(&alive, technique) && alive.allSatisfy { $0.count == 1 }
            }

            /// The next plot forced from the right plots already drawn: the number (its index) and the simplest
            /// technique that leaves it one plot.
            func step(placed: [Plot]) -> (Int, Reason)? {
                var start = options
                var open: [Int] = []
                for k in plots.indices {
                    if let i = plots[k].firstIndex(where: placed.contains) { start[k] = [options[k][i]] } else { open.append(k) }
                }
                for technique in Technique.allCases {
                    var alive = start
                    while true {
                        if let k = open.first(where: { alive[$0].count == 1 }) { return (k, technique.reason) }
                        guard pass(&alive, technique) == true else { break }
                    }
                }
                return nil
            }
        }

        init(level: Level, width: Int, height: Int, clues: [Clue], solution: [Plot]) {
            self.level = level
            self.width = width
            self.height = height
            self.clues = clues
            self.solution = solution
        }
    }
}
