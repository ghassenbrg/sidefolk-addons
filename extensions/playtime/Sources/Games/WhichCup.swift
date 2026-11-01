import Foundation

extension Games {
    /// Which Cup?, the shell game: the companion hides its gem under a cup (three at Easy, four at Fair, five at Hard),
    /// shuffles, and you pick. Five rounds, each with more and quicker swaps.
    ///
    /// Sneaky (off unless the person turns it on): sometimes the companion palms the gem, so it is under no cup. Clicking
    /// the companion after the shuffle (`accuse()`) catches it: two points and a blushing confession. Accusing an honest
    /// companion costs nothing, and the round goes on. A palmed round you didn't catch ends with its confession. Without
    /// Sneaky the gem is always where the swaps put it.
    ///
    /// Flow: `start(using:)` gives the `Shuffle` (`.shuffle` part: show the gem under `hide`, then animate `swaps` at
    /// `swapMs` each); then `pick(cup)` or `accuse()`. Events: `reveal`, `point`, `caught`, `innocent`, `confess`,
    /// `matchOver`.
    struct WhichCup: Codable, Equatable, Sendable {
        struct Shuffle: Codable, Equatable, Sendable {
            let cups: Int
            let hide: Int
            /// Pairs of cup positions swapped, in order.
            let swaps: [[Int]]
            let swapMs: Int
        }

        static let rounds = 5

        let level: Level
        let sneaky: Bool
        private(set) var score = Score()
        private(set) var played = 0
        private(set) var current: Shuffle?
        /// Where the swaps leave the gem, for the reveal after a pick.
        private(set) var gem: Int?
        /// Whether the gem is in the companion's paw this round: never shown before the round ends.
        private var palmed = false
        /// The companion's paw was checked this round (once a round).
        private(set) var accused = false

        init(level: Level, sneaky: Bool = false) {
            self.level = level
            self.sneaky = sneaky
        }

        var cups: Int { switch level { case .easy: 3; case .fair: 4; case .hard: 5 } }
        var over: Bool { played >= Self.rounds }

        mutating func start(using rng: inout Random) throws -> Shuffle {
            guard !over else { throw Refusal("over") }
            guard current == nil else { throw Refusal("not_now") }
            let r = played
            let count: Int, ms: Int
            switch level {
            case .easy: (count, ms) = (4 + r, 600 - 30 * r)
            case .fair: (count, ms) = (5 + r, 480 - 30 * r)
            case .hard: (count, ms) = (6 + 2 * r, 380 - 25 * r)
            }
            let hide = rng.below(cups)
            var at = hide
            var swaps: [[Int]] = []
            for _ in 0..<count {
                let a = rng.below(cups)
                var b = rng.below(cups - 1)
                if b >= a { b += 1 }
                swaps.append([min(a, b), max(a, b)])
                if at == a { at = b } else if at == b { at = a }
            }
            gem = at
            palmed = sneaky && rng.chance(0.3)
            accused = false
            let shuffle = Shuffle(cups: cups, hide: hide, swaps: swaps, swapMs: max(200, ms))
            current = shuffle
            return shuffle
        }

        /// Your cup. Returns where the gem was (nil when it was in the companion's paw) with the events.
        mutating func pick(_ cup: Int) throws -> (gemAt: Int?, events: [Event]) {
            guard current != nil else { throw Refusal("not_now") }
            guard (0..<cups).contains(cup) else { throw Refusal("no_such_cup") }
            let at = palmed ? nil : gem
            let winner: Side = at == cup ? .you : .companion
            score[winner] += 1
            return (at, (palmed ? [.confess] : []) + [.reveal, .point(winner)] + endRound())
        }

        /// You click the companion: on a palmed round, caught (two points, the round ends); otherwise it's innocent.
        mutating func accuse() throws -> [Event] {
            guard current != nil else { throw Refusal("not_now") }
            guard !accused else { throw Refusal("already_accused") }
            accused = true
            guard palmed else { return [.innocent] }
            score.you += 2
            return [.caught, .reveal] + endRound()
        }

        private mutating func endRound() -> [Event] {
            current = nil
            palmed = false
            played += 1
            return over ? [.matchOver(winner: score.leader)] : []
        }
    }
}
