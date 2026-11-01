import Foundation

extension Games {
    /// Memory Pairs against the companion: a 4 × 4 grid of eight pairs, turns taken, and a pair keeps your turn. The
    /// companion watches every card turned (yours too) and forgets as a person does: a card seen a moment ago is nearly
    /// always there in its mind, one seen many turns back fades (slowly on Hard, fast on Easy), and seeing a card again
    /// refreshes it. When the exact place has slipped it sometimes reaches for a card beside it ("I saw a moon… around
    /// here?"), the near miss people make.
    ///
    /// Flow: `flip(cell, by:)` twice a turn. A pair: `.pair`, same side again. No pair: `.noPair`; the adapter shows the
    /// two cards for a moment, then `cover()`, and the turn passes. On the companion's turn call `companionFlip(using:)`
    /// for each card (after the `.think` time); `recalled` says it used its memory (the `.recalls` cue). Events: `turn`,
    /// `think`, `pair`, `noPair`, `roundOver` (most pairs; nil when level).
    struct MemoryPairs: Codable, Equatable, Sendable {
        /// Symbol ids; the adapter draws them (SF Symbols) and names them through `Phrases` (`symbol.<id>`).
        static let symbols = ["moon", "leaf", "anchor", "star", "heart", "sun", "cloud", "flower", "fish", "bell", "key", "drop"]
        static let pairs = 8
        static let columns = 4

        /// A card the companion saw: what it was, and when (the count of cards turned by then).
        struct Sight: Codable, Equatable, Sendable {
            let symbol: String
            let at: Int
        }

        let level: Level
        private(set) var cards: [String]
        /// Who found each card's pair.
        private(set) var owner: [Side?]
        /// The cards turned this turn, in order.
        private(set) var faceUp: [Int] = []
        /// Two cards that don't match are showing until `cover()`.
        private(set) var waitingToCover = false
        private(set) var turn: Side
        private(set) var score = Score()
        /// Cards turned so far, the companion's clock for forgetting.
        private(set) var flips = 0
        /// What the companion has seen and not yet matched: cell → what and when.
        private var seen: [Int: Sight] = [:]

        init(level: Level, first: Side = .you, using rng: inout Random) {
            self.level = level
            let chosen = Array(rng.shuffled(Self.symbols).prefix(Self.pairs))
            cards = rng.shuffled(chosen + chosen)
            owner = Array(repeating: nil, count: cards.count)
            turn = first
        }

        var over: Bool { !owner.contains(nil) }

        /// How well it remembers a card seen `age` cards ago: sure of the last few, fading after.
        func recall(age: Int) -> Double {
            let (fresh, keep): (Double, Double) = switch level {
            case .easy: (0.8, 0.88)
            case .fair: (0.93, 0.95)
            case .hard: (1, 0.993)
            }
            return fresh * pow(keep, Double(max(0, age - 1)))
        }

        /// How often, when the exact place has slipped, it still reaches near it.
        private var nearMiss: Double { switch level { case .easy: 0.5; case .fair: 0.35; case .hard: 0.25 } }

        mutating func flip(_ cell: Int, by side: Side) throws -> [Event] {
            guard !over else { throw Refusal("over") }
            guard side == turn else { throw Refusal("not_your_turn") }
            guard !waitingToCover else { throw Refusal("not_now") }
            guard cards.indices.contains(cell), owner[cell] == nil, !faceUp.contains(cell) else { throw Refusal("taken") }
            faceUp.append(cell)
            flips += 1
            seen[cell] = Sight(symbol: cards[cell], at: flips)
            guard faceUp.count == 2 else { return [] }
            let (a, b) = (faceUp[0], faceUp[1])
            guard cards[a] == cards[b] else {
                waitingToCover = true
                return [.noPair(side)]
            }
            owner[a] = side
            owner[b] = side
            seen[a] = nil
            seen[b] = nil
            faceUp = []
            score[side] += 1
            if over { return [.pair(side), .roundOver(winner: score.leader)] }
            return [.pair(side)] + turnEvents()
        }

        /// The two unmatched cards turn back and the other side plays.
        mutating func cover() throws -> [Event] {
            guard waitingToCover else { throw Refusal("not_now") }
            waitingToCover = false
            faceUp = []
            turn = turn.other
            return turnEvents()
        }

        /// The companion's next card: a pair it remembers, the partner of the card it just turned if it remembers
        /// where that is (or a card beside where it thinks it was), or else a card it hasn't seen.
        func companionFlip(using rng: inout Random) -> (cell: Int, recalled: Bool) {
            let hidden = cards.indices.filter { owner[$0] == nil && !faceUp.contains($0) }
            // Its memory right now: each card it has seen comes back as well as its age allows.
            var remembered: [Int] = []
            var slipped: [Int] = []
            for cell in seen.keys.sorted() where hidden.contains(cell) {
                if rng.chance(recall(age: flips - seen[cell]!.at)) { remembered.append(cell) } else { slipped.append(cell) }
            }
            if let first = faceUp.first {
                if let partner = remembered.first(where: { cards[$0] == cards[first] }) { return (partner, true) }
                if let lost = slipped.first(where: { cards[$0] == cards[first] }), rng.chance(nearMiss) {
                    let near = hidden.filter { $0 != lost && Self.adjacent($0, lost) }
                    if !near.isEmpty { return (rng.pick(near), true) }
                }
            } else {
                let pairs = Dictionary(grouping: remembered, by: { cards[$0] }).values.filter { $0.count == 2 }
                if !pairs.isEmpty { return (rng.pick(pairs.sorted { $0[0] < $1[0] })[0], true) }
            }
            // A card it hasn't seen, or any once all have been seen.
            let unseen = hidden.filter { seen[$0] == nil }
            return (rng.pick(unseen.isEmpty ? hidden : unseen), false)
        }

        /// Side by side or one above the other on the 4 × 4 grid.
        static func adjacent(_ a: Int, _ b: Int) -> Bool {
            let (ra, ca, rb, cb) = (a / columns, a % columns, b / columns, b % columns)
            return abs(ra - rb) + abs(ca - cb) == 1
        }

        /// Its pause before a card: about a second, longer when there is more to remember, never one fixed time.
        var thinkMs: Int { Games.pause(750 + min(seen.count, 6) * 40, spread: 220, seed: UInt64(flips * 31 + score.you * 7 + score.companion)) }

        private func turnEvents() -> [Event] {
            turn == .companion ? [.turn(.companion), .think(ms: thinkMs)] : [.turn(.you)]
        }
    }
}
