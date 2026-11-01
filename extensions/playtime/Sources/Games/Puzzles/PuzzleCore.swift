import Foundation

/// The four logic puzzles (Garden Plots, Seesaw, Sudoku, Blossoms) share one way to play: a generated board with a
/// single solution, the person's marks on it, moves that can be undone, the rules' conflicts shown where they break,
/// a hint that is always the next forced move with its reason, a stopwatch, and the solved state. Each puzzle is a
/// `PuzzleRules` value (the board as dealt: givens, clues, its solution); `PuzzleGame` plays any of them.
///
/// Every board comes from a generator that only keeps a board its own logic solver finishes with the level's
/// techniques, one forced step at a time. That is what makes the solution unique (each step was forced) and the
/// hints honest (the same solver gives them, from wherever the person is). The tests check uniqueness again with
/// plain backtracking.
protocol PuzzleRules: Codable, Equatable, Sendable {
    /// The person's marks on the board (the givens included).
    associatedtype Grid: Codable, Equatable, Sendable
    associatedtype Move: Codable, Equatable, Sendable
    /// A rule's name, for the board to word a conflict (`Seesaw.Rule.threeInARow`).
    associatedtype Rule: Codable, Equatable, Sendable
    /// Why a hint's move is forced.
    associatedtype Reason: Codable, Equatable, Sendable

    /// Its id in the manifest and the records (`games.<id>`).
    static var id: String { get }
    /// A new board with exactly one solution, the level's size and techniques.
    static func generate(level: Games.Level, using rng: inout Games.Random) -> Self

    var level: Games.Level { get }
    /// The board as dealt.
    var start: Grid { get }
    /// The move on `grid`, or a refusal (a given can't change); nothing is changed when it throws.
    func apply(_ move: Move, to grid: inout Grid) throws
    /// Where the rules break now, each with the cells to light.
    func conflicts(in grid: Grid) -> [Games.PuzzleConflict<Rule>]
    func isSolved(_ grid: Grid) -> Bool
    /// The next move: a mark that disagrees with the solution first (to take back), else the simplest forced move
    /// from the marks that are right, else (never for a generated board) one cell of the solution.
    func hint(for grid: Grid) -> Games.PuzzleHint<Move, Reason>
}

extension PuzzleRules {
    /// The day's board at a level, for everyone: the same date gives the same board on every Mac (the seed is the
    /// puzzle, the level and the day, `DailyWord.day`). Fair keeps the seed it had when it was the only daily board, so
    /// that board didn't change when Easy and Hard got theirs.
    static func daily(day: Int, level: Games.Level) -> Self {
        let seed = level == .fair ? "\(id).daily.\(day)" : "\(id).daily.\(level.rawValue).\(day)"
        var rng = Games.Random(seed: Games.stableHash(seed))
        return generate(level: level, using: &rng)
    }
}

extension Games {
    /// Where a rule breaks: the rule and the cells involved (cells are `row * width + column`).
    struct PuzzleConflict<Rule: Codable & Equatable & Sendable>: Codable, Equatable, Sendable {
        let rule: Rule
        let cells: [Int]
    }

    /// A hint: the move to make, why it's forced, and the cells the reason points at (the pair, the row, the bed).
    struct PuzzleHint<Move: Codable & Equatable & Sendable, Reason: Codable & Equatable & Sendable>: Codable, Equatable, Sendable {
        let move: Move
        let reason: Reason
        let cells: [Int]
    }

    /// Time spent on a puzzle, from times the adapter passes in (seconds, any fixed origin): engines read no clock.
    /// It runs while the board is open and pauses when the panel closes or the puzzle is solved.
    struct Stopwatch: Codable, Equatable, Sendable {
        private(set) var banked: Double = 0
        private(set) var since: Double?

        var running: Bool { since != nil }

        mutating func resume(at time: Double) {
            if since == nil { since = time }
        }

        mutating func pause(at time: Double) {
            guard let since else { return }
            banked += max(0, time - since)
            self.since = nil
        }

        func elapsed(at time: Double) -> Double { banked + (since.map { max(0, time - $0) } ?? 0) }
    }

    /// A puzzle being played: the board, the person's marks, undo, hints taken, the stopwatch.
    ///
    /// Flow: `play(move, at:)` (events: `mistake` when the move breaks a rule that held before, `roundOver(you)` when
    /// it solves the board); `undo(at:)`; `hint(at:)` (`hint`; the adapter shows the reason and lights the cells, and
    /// plays the move with `play` when the person asks it to: the hint is already counted); `clear(at:)` back to the
    /// givens; `pause`/`resume` as the panel hides and shows.
    struct PuzzleGame<Rules: PuzzleRules>: Codable, Equatable, Sendable {
        /// How many moves undo remembers: enough for any solve, small enough to save after every move.
        static var undoDepth: Int { 300 }

        let puzzle: Rules
        /// The day of a daily board; nil for practice.
        let day: Int?
        private(set) var grid: Rules.Grid
        private(set) var history: [Rules.Grid] = []
        private(set) var hints = 0
        private(set) var clock = Stopwatch()
        private(set) var solved = false

        init(_ puzzle: Rules, day: Int? = nil, at time: Double) {
            self.puzzle = puzzle
            self.day = day
            grid = puzzle.start
            clock.resume(at: time)
        }

        var level: Level { puzzle.level }
        var conflicts: [PuzzleConflict<Rules.Rule>] { puzzle.conflicts(in: grid) }
        var canUndo: Bool { !solved && !history.isEmpty }

        func elapsed(at time: Double) -> Double { clock.elapsed(at: time) }
        mutating func pause(at time: Double) { clock.pause(at: time) }
        mutating func resume(at time: Double) { if !solved { clock.resume(at: time) } }

        mutating func play(_ move: Rules.Move, at time: Double) throws -> [Event] {
            guard !solved else { throw Refusal("over") }
            var next = grid
            try puzzle.apply(move, to: &next)
            guard next != grid else { return [] }
            return commit(next, at: time)
        }

        mutating func undo(at time: Double) throws -> [Event] {
            guard !solved else { throw Refusal("over") }
            guard let last = history.popLast() else { throw Refusal("nothing_to_undo") }
            grid = last
            clock.resume(at: time)
            return []
        }

        /// Back to the board as dealt (undoable); the stopwatch keeps running.
        mutating func clear(at time: Double) throws -> [Event] {
            guard !solved else { throw Refusal("over") }
            guard grid != puzzle.start else { return [] }
            return commit(puzzle.start, at: time)
        }

        mutating func hint(at time: Double) throws -> (hint: PuzzleHint<Rules.Move, Rules.Reason>, events: [Event]) {
            guard !solved else { throw Refusal("over") }
            hints += 1
            clock.resume(at: time)
            return (puzzle.hint(for: grid), [.hint])
        }

        private mutating func commit(_ next: Rules.Grid, at time: Double) -> [Event] {
            let before = puzzle.conflicts(in: grid)
            history.append(grid)
            if history.count > Self.undoDepth { history.removeFirst(history.count - Self.undoDepth) }
            grid = next
            clock.resume(at: time)
            if puzzle.isSolved(grid) {
                solved = true
                clock.pause(at: time)
                return [.roundOver(winner: .you)]
            }
            return puzzle.conflicts(in: grid).contains { !before.contains($0) } ? [.mistake] : []
        }
    }
}

extension Games {
    /// Small helpers the four generators share.
    enum PuzzleGrid {
        /// The cells beside `cell` (4 or, with `diagonals`, 8) on a `width` × `height` board.
        static func neighbours(_ cell: Int, width: Int, height: Int, diagonals: Bool = false) -> [Int] {
            let r = cell / width, c = cell % width
            var out: [Int] = []
            for dr in -1...1 {
                for dc in -1...1 where (dr, dc) != (0, 0) && (diagonals || dr == 0 || dc == 0) {
                    let rr = r + dr, cc = c + dc
                    if rr >= 0, rr < height, cc >= 0, cc < width { out.append(rr * width + cc) }
                }
            }
            return out
        }
    }
}
