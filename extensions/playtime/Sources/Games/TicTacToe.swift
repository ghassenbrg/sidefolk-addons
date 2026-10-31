import Foundation

extension Games {
    /// Tic-tac-toe, "Noughts with Mochi": you are X, the companion O, and a series is the first to three games, the
    /// first move alternating. Cells are 0–8 row by row; `cell(forKey:)` maps the number pad (7 8 9 on top).
    ///
    /// Flow: `play(cell, by: .you)`; when the events say `.turn(.companion)`, show `think` for the `.think` time, then
    /// `play(companionMove(using:), by: .companion)`. After `.roundOver`, `nextGame()`; after `.matchOver`, a new value.
    /// Events: `turn`, `think`, `threat` (a side can win next move: the companion grins, or sweats when it's you),
    /// `fork`, `roundOver`, `matchOver`, `unbeatable` (three draws in a row on Hard), `hint`.
    struct TicTacToe: Codable, Equatable, Sendable {
        static let lines = [[0, 1, 2], [3, 4, 5], [6, 7, 8], [0, 3, 6], [1, 4, 7], [2, 5, 8], [0, 4, 8], [2, 4, 6]]
        static let seriesTarget = 3

        let level: Level
        private(set) var cells: [Side?] = Array(repeating: nil, count: 9)
        private(set) var turn: Side
        private(set) var starter: Side
        /// The three cells of the last win, for the line drawn through them.
        private(set) var winningLine: [Int]?
        private(set) var gameOver = false
        private(set) var series = Score()
        /// Draws in a row, for Hard's confession after three.
        private(set) var drawsInARow = 0
        /// One hint a game.
        private(set) var hintUsed = false

        init(level: Level, first: Side = .you) {
            self.level = level
            turn = first
            starter = first
        }

        var seriesOver: Bool { series.you >= Self.seriesTarget || series.companion >= Self.seriesTarget }
        var legalMoves: [Int] { gameOver ? [] : cells.indices.filter { cells[$0] == nil } }

        /// The cell for a number-pad key: 7 8 9 is the top row, 1 2 3 the bottom.
        static func cell(forKey key: Int) -> Int? {
            guard (1...9).contains(key) else { return nil }
            return (2 - (key - 1) / 3) * 3 + (key - 1) % 3
        }

        mutating func play(_ cell: Int, by side: Side) throws -> [Event] {
            guard !gameOver else { throw Refusal("over") }
            guard side == turn else { throw Refusal("not_your_turn") }
            guard cells.indices.contains(cell), cells[cell] == nil else { throw Refusal("taken") }
            cells[cell] = side
            if let line = Self.lines.first(where: { $0.allSatisfy { cells[$0] == side } }) {
                winningLine = line
                return finish(winner: side)
            }
            if !cells.contains(nil) { return finish(winner: nil) }
            turn = side.other
            var events: [Event] = []
            let made = threats(for: side).count
            if made >= 2 { events.append(.fork(side)) } else if made == 1, side == .you { events.append(.threat(.you)) }
            if turn == .companion {
                if !threats(for: .companion).isEmpty { events.append(.threat(.companion)) }
                events += [.turn(.companion), .think(ms: thinkTime())]
            } else {
                events.append(.turn(.you))
            }
            return events
        }

        /// The companion's cell by level: Easy is mostly random, Fair wins when it can and blocks when it must, Hard is
        /// perfect (minimax), choosing at random between equally good cells so its games differ.
        func companionMove(using rng: inout Random) -> Int {
            let open = legalMoves
            let win = threats(for: .companion), block = threats(for: .you)
            switch level {
            case .easy:
                if let w = win.first, rng.chance(0.5) { return w }
                if let b = block.first, rng.chance(0.3) { return b }
                return rng.pick(open)
            case .fair:
                if !win.isEmpty { return rng.pick(win) }
                if !block.isEmpty { return rng.pick(block) }
                return rng.pick(open)
            case .hard:
                return rng.pick(Self.bestMoves(cells, for: .companion))
            }
        }

        /// The best cell for you, shown by the companion pointing at it: once a game.
        mutating func hint() throws -> (cell: Int, events: [Event]) {
            guard !gameOver, turn == .you else { throw Refusal("not_your_turn") }
            guard !hintUsed else { throw Refusal("hint_used") }
            hintUsed = true
            return (Self.bestMoves(cells, for: .you).first ?? legalMoves[0], [.hint])
        }

        /// The next game of the series; whoever didn't start the last one starts.
        mutating func nextGame() throws -> [Event] {
            guard gameOver, !seriesOver else { throw Refusal(gameOver ? "over" : "not_over") }
            starter = starter.other
            turn = starter
            cells = Array(repeating: nil, count: 9)
            winningLine = nil
            gameOver = false
            hintUsed = false
            return turn == .companion ? [.turn(.companion), .think(ms: thinkTime())] : [.turn(.you)]
        }

        private mutating func finish(winner: Side?) -> [Event] {
            gameOver = true
            var events: [Event] = [.roundOver(winner: winner)]
            if let winner {
                series[winner] += 1
                drawsInARow = 0
            } else {
                drawsInARow += 1
                if level == .hard, drawsInARow % 3 == 0 { events.append(.unbeatable) }
            }
            if seriesOver { events.append(.matchOver(winner: series.leader)) }
            return events
        }

        /// Cells where `side` would complete a line.
        func threats(for side: Side) -> [Int] {
            Self.lines.compactMap { line in
                let mine = line.filter { cells[$0] == side }.count
                let empty = line.filter { cells[$0] == nil }
                return mine == 2 && empty.count == 1 ? empty[0] : nil
            }.reduce(into: []) { if !$0.contains($1) { $0.append($1) } }
        }

        /// 0.6–1.4 s: longer when you have a threat it must deal with. Fixed by the board, so a replay looks the same.
        private func thinkTime() -> Int {
            let filled = cells.compactMap { $0 }.count
            return 600 + filled * 60 + (threats(for: .you).isEmpty ? 0 : 400)
        }

        /// Every cell with the best minimax value for `side`.
        static func bestMoves(_ cells: [Side?], for side: Side) -> [Int] {
            var memo: [Int: Int] = [:]
            let open = cells.indices.filter { cells[$0] == nil }
            let scored = open.map { cell -> (Int, Int) in
                var next = cells
                next[cell] = side
                return (cell, -value(next, mover: side.other, memo: &memo))
            }
            let best = scored.map(\.1).max() ?? 0
            return scored.filter { $0.1 == best }.map(\.0)
        }

        /// Negamax for the side to move: positive when it wins, quicker wins worth more. Memoised on the board (3^9).
        private static func value(_ cells: [Side?], mover: Side, memo: inout [Int: Int]) -> Int {
            let key = cells.reduce(0) { $0 * 3 + ($1 == nil ? 0 : ($1 == .you ? 1 : 2)) }
            if let known = memo[key] { return known }
            let empty = cells.filter { $0 == nil }.count
            let result: Int
            if lines.contains(where: { $0.allSatisfy { cells[$0] == mover.other } }) {
                result = -(empty + 1)
            } else if empty == 0 {
                result = 0
            } else {
                result = cells.indices.filter { cells[$0] == nil }.map { cell -> Int in
                    var next = cells
                    next[cell] = mover
                    return -value(next, mover: mover.other, memo: &memo)
                }.max()!
            }
            memo[key] = result
            return result
        }
    }
}
