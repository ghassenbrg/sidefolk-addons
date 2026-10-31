import Foundation

extension Games {
    /// Last Stick (misère Nim): 21 sticks in a row, each turn takes 1, 2 or 3 from the right, and whoever takes the
    /// last one loses. The trick: leave your opponent one more than a multiple of four (17, 13, 9, 5, 1).
    /// Easy takes at random, Fair plays the trick 60% of the time, Hard always when it can. Who starts alternates
    /// (pass `first`): from 21 the side that moves first is the one in trouble, so on Hard you win only the games the
    /// companion starts, and only if you know the trick, which it teaches after your third loss (`.offerSecret`,
    /// then `lesson`).
    ///
    /// Flow: `take(n, by: .you)`; on `.turn(.companion)` show `think`, then `take(companionTake(using:), by: .companion)`.
    /// Events: `turn`, `think`, `roundOver` (the winner), `offerSecret`.
    struct LastStick: Codable, Equatable, Sendable {
        static let sticks = 21

        /// Sticks indexed from the left (0) to the right, as drawn: what the companion shows when it teaches.
        struct Lesson: Codable, Equatable, Sendable {
            /// The sticks to take now (at the right end); empty when there's no good move left.
            let takeNow: [Int]
            /// Groups of four: for each group, take whatever makes four with your opponent's take.
            let groups: [[Int]]
            /// The last stick, left for your opponent.
            let last: Int
        }

        let level: Level
        private(set) var left: Int
        private(set) var turn: Side
        private(set) var winner: Side?
        /// Your losses so far (the adapter keeps them), and whether the trick was offered.
        private(set) var losses: Int
        private(set) var secretOffered: Bool

        init(level: Level, first: Side = .you, sticks: Int = Self.sticks, losses: Int = 0, secretOffered: Bool = false) {
            self.level = level
            left = sticks
            turn = first
            self.losses = losses
            self.secretOffered = secretOffered
        }

        var over: Bool { winner != nil }
        var legalTakes: [Int] { over ? [] : Array(1...min(3, left)) }

        /// The take that leaves a multiple of four plus one, or nil when `left` already is one (no winning move).
        static func winningTake(_ left: Int) -> Int? {
            let take = (left - 1) % 4
            return take == 0 ? nil : take
        }

        var lesson: Lesson {
            let now = Self.winningTake(left) ?? 0
            let groups = stride(from: 1, to: left - now, by: 4).map { Array($0..<min($0 + 4, left - now)) }
            return Lesson(takeNow: Array((left - now)..<left), groups: groups, last: 0)
        }

        mutating func take(_ n: Int, by side: Side) throws -> [Event] {
            guard !over else { throw Refusal("over") }
            guard side == turn else { throw Refusal("not_your_turn") }
            guard legalTakes.contains(n) else { throw Refusal("bad_take") }
            left -= n
            guard left == 0 else {
                turn = side.other
                return turn == .companion ? [.turn(.companion), .think(ms: 700 + 60 * min(left, 12))] : [.turn(.you)]
            }
            winner = side.other
            var events: [Event] = [.roundOver(winner: side.other)]
            if side == .you {
                losses += 1
                if losses >= 3, !secretOffered {
                    secretOffered = true
                    events.append(.offerSecret)
                }
            }
            return events
        }

        func companionTake(using rng: inout Random) -> Int {
            let random = rng.between(1, min(3, left))
            guard let best = Self.winningTake(left) else { return random }
            switch level {
            case .easy: return random
            case .fair: return rng.chance(0.6) ? best : random
            case .hard: return best
            }
        }
    }
}
