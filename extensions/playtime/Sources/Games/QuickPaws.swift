import Foundation

extension Games {
    /// Quick Paws, a reflex duel: "Steady…" for a random 1.5–5 s, then "BOOP!", and whoever presses first wins the
    /// round; a match is the best of five. Sidefolk shows the signal and measures the press (stdin can't time a
    /// screen), so the engine only says how long to wait and how quick the companion is, and judges the press.
    ///
    /// Flow: `start(using:)` gives the `Round` (`.reflex` part: `after_ms` = `waitMs`, `window_ms` = `windowMs`); the
    /// adapter answers with `press(ms:)` (time from the signal), `early()` (a press before it: the point goes to the
    /// companion) or `timeout()`. Events: `point`, `tooSoon`, `tooSlow`, `newBest` (your quickest ever, below `best`),
    /// `matchOver`.
    struct QuickPaws: Codable, Equatable, Sendable {
        struct Round: Codable, Equatable, Sendable {
            /// How long "Steady…" lasts before the signal.
            let waitMs: Int
            /// How long after the signal a press still counts.
            let windowMs: Int
            /// When the companion's paw comes down after the signal.
            let companionMs: Int
        }

        static let target = 3
        static let window = 1500

        let level: Level
        private(set) var score = Score()
        private(set) var round: Round?
        /// Your quickest press ever before this match (the adapter keeps it), then this match's when quicker.
        private(set) var best: Int?
        /// The last round's times, for "Your 243 ms · Mochi 291 ms" (yours is nil after a press too soon or too late).
        private(set) var lastYouMs: Int?
        private(set) var lastCompanionMs: Int?

        init(level: Level, best: Int? = nil) {
            self.level = level
            self.best = best
        }

        var over: Bool { score.you >= Self.target || score.companion >= Self.target }

        /// The companion's usual reaction by level, before its jitter of up to ±60 ms.
        var companionTypicalMs: Int {
            switch level { case .easy: 450; case .fair: 320; case .hard: 240 }
        }

        mutating func start(using rng: inout Random) throws -> Round {
            guard !over else { throw Refusal("over") }
            guard round == nil else { throw Refusal("not_now") }
            let jitter = rng.between(-30, 30) + rng.between(-30, 30)
            let next = Round(waitMs: rng.between(1500, 5000), windowMs: Self.window, companionMs: companionTypicalMs + jitter)
            round = next
            return next
        }

        mutating func press(ms: Int) throws -> [Event] {
            guard let round else { throw Refusal("not_now") }
            guard ms >= 0 else { throw Refusal("bad_time") }
            guard ms <= round.windowMs else { return try timeout() }
            // A tie goes to you.
            let winner: Side = ms <= round.companionMs ? .you : .companion
            var events: [Event] = []
            if best.map({ ms < $0 }) ?? true {
                best = ms
                events.append(.newBest(ms))
            }
            return finish(winner, you: ms, extra: events)
        }

        mutating func early() throws -> [Event] {
            guard round != nil else { throw Refusal("not_now") }
            return finish(.companion, you: nil, extra: [.tooSoon])
        }

        mutating func timeout() throws -> [Event] {
            guard round != nil else { throw Refusal("not_now") }
            return finish(.companion, you: nil, extra: [.tooSlow])
        }

        private mutating func finish(_ winner: Side, you: Int?, extra: [Event]) -> [Event] {
            lastYouMs = you
            lastCompanionMs = round?.companionMs
            round = nil
            score[winner] += 1
            return extra + [.point(winner)] + (over ? [.matchOver(winner: winner)] : [])
        }
    }
}
