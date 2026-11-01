import Foundation

extension Games {
    /// Last Stick (misère Nim): 21 sticks in a row, each turn takes 1, 2 or 3 from the right, and whoever takes the
    /// last one loses. The trick: leave your opponent one more than a multiple of four (17, 13, 9, 5, 1).
    /// Easy rarely plays the trick, Fair mostly, Hard always when it can (`companionTake`). Who starts alternates
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
                return turn == .companion ? [.turn(.companion), .think(ms: Games.pause(650 + 55 * min(left, 12), spread: 250, seed: UInt64(left * 13 + losses)))] : [.turn(.you)]
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

        /// Its take, as a person of the level plays: everyone sees the end coming (with four or fewer left, even Easy
        /// usually leaves you the last stick) and nobody takes the last stick while another take is left. Easy rarely
        /// plays the trick before that, Fair most of the time and nearly always near the end, Hard always: it wins
        /// every position it can win. With no winning take it stalls, mostly taking one, which leaves you the most
        /// room to slip.
        func companionTake(using rng: inout Random) -> Int {
            let takes = legalTakes.filter { $0 < left || left == 1 }
            guard let best = Self.winningTake(left) else {
                return level == .hard && rng.chance(0.6) ? 1 : rng.pick(takes)
            }
            let sees: Double = switch level {
            case .easy: left <= 4 ? 0.7 : 0.15
            case .fair: left <= 8 ? 0.9 : 0.6
            case .hard: 1
            }
            return rng.chance(sees) ? best : rng.pick(takes)
        }
    }
}
