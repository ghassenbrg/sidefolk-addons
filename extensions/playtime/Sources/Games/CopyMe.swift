import Foundation

extension Games {
    /// Copy Me (Simon with the companion's body): it dances a sequence of moves, you repeat it on the pads, and each
    /// round adds one move and speeds up. The four pads are the plan's: wave (blue circle), hop (green triangle), spin
    /// (yellow star), bow (red square); Hard adds a fifth, a wave with the other arm, and starts at three moves.
    ///
    /// Flow: show `sequence` (each pad lit for `stepMs`, its accent move played), then `watched()`; the person
    /// `press`es; on `.grew` show the longer sequence again. A wrong pad or `timeout()` ends it with `.mistake`
    /// (the companion turns too far and goes dizzy). The score is `copied`, the longest sequence repeated.
    struct CopyMe: Codable, Equatable, Sendable {
        enum Pad: String, Codable, Sendable, CaseIterable {
            case wave, hop, spin, bow, otherWave
        }

        enum Phase: String, Codable, Sendable { case watching, copying, over }

        /// The longest game: past it you have simply won.
        static let longest = 64

        let level: Level
        /// Every move of this game, drawn at the start so the engine needs no chance later on.
        private let plan: [Pad]
        private(set) var length: Int
        /// How many moves of this round's sequence you have repeated.
        private(set) var position = 0
        private(set) var phase = Phase.watching
        /// The longest sequence you repeated this game.
        private(set) var copied = 0
        /// The best before this game (the adapter keeps it), for `.newBest`.
        let best: Int

        init(level: Level, best: Int = 0, using rng: inout Random) {
            self.level = level
            self.best = best
            let pads = level == .hard ? Pad.allCases : Array(Pad.allCases.prefix(4))
            plan = (0..<Self.longest).map { _ in rng.pick(pads) }
            length = level == .hard ? 3 : 1
        }

        var pads: [Pad] { level == .hard ? Pad.allCases : Array(Pad.allCases.prefix(4)) }
        var sequence: [Pad] { Array(plan.prefix(length)) }

        /// How long each move of the sequence shows: the tempo rises a little with every round.
        var stepMs: Int {
            let (start, fastest) = switch level { case .easy: (800, 450); case .fair: (650, 350); case .hard: (520, 280) }
            return max(fastest, start - 25 * (length - 1))
        }

        /// The adapter finished showing the sequence: your turn.
        mutating func watched() throws -> [Event] {
            guard phase == .watching else { throw Refusal("not_now") }
            phase = .copying
            position = 0
            return [.turn(.you)]
        }

        mutating func press(_ pad: Pad) throws -> [Event] {
            guard phase == .copying else { throw Refusal("not_now") }
            guard pad == plan[position] else { return end() }
            position += 1
            guard position == length else { return [] }
            copied = length
            if length == Self.longest {
                phase = .over
                return [.point(.you), .matchOver(winner: .you)] + (copied > best ? [.newBest(copied)] : [])
            }
            length += 1
            phase = .watching
            return [.point(.you), .grew(length), .turn(.companion)]
        }

        /// No press in time (the adapter's timer).
        mutating func timeout() throws -> [Event] {
            guard phase == .copying else { throw Refusal("not_now") }
            return end()
        }

        private mutating func end() -> [Event] {
            phase = .over
            return [.mistake, .matchOver(winner: nil)] + (copied > best ? [.newBest(copied)] : [])
        }
    }
}
