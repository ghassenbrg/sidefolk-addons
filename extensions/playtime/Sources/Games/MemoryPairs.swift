import Foundation

extension Games {
    /// Memory Pairs against the companion: a 4 × 4 grid of eight pairs, turns taken, and a pair keeps your turn. The
    /// companion watches every card turned (yours too) but its memory is a goldfish's on purpose: each time it reaches
    /// for a card it has seen, it recalls it 40% (Easy), 70% (Fair) or 95% (Hard) of the time.
    ///
    /// Flow: `flip(cell, by:)` twice a turn. A pair: `.pair`, same side again. No pair: `.noPair`; the adapter shows the
    /// two cards for a moment, then `cover()`, and the turn passes. On the companion's turn call `companionFlip(using:)`
    /// for each card (after the `.think` time); `recalled` says it used its memory ("I saw a moon… around here?", the
    /// `.recalls` cue). Events: `turn`, `think`, `pair`, `noPair`, `roundOver` (most pairs; nil when level).
    struct MemoryPairs: Codable, Equatable, Sendable {
        /// Symbol ids; the adapter draws them (SF Symbols) and names them through `Phrases` (`symbol.<id>`).
        static let symbols = ["moon", "leaf", "anchor", "star", "heart", "sun", "cloud", "flower", "fish", "bell", "key", "drop"]
        static let pairs = 8

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
        /// What the companion has seen and not yet matched: cell → symbol.
        private var seen: [Int: String] = [:]

        init(level: Level, first: Side = .you, using rng: inout Random) {
            self.level = level
            let chosen = Array(rng.shuffled(Self.symbols).prefix(Self.pairs))
            cards = rng.shuffled(chosen + chosen)
            owner = Array(repeating: nil, count: cards.count)
            turn = first
        }

        var over: Bool { !owner.contains(nil) }
        var recall: Double { switch level { case .easy: 0.4; case .fair: 0.7; case .hard: 0.95 } }

        mutating func flip(_ cell: Int, by side: Side) throws -> [Event] {
            guard !over else { throw Refusal("over") }
            guard side == turn else { throw Refusal("not_your_turn") }
            guard !waitingToCover else { throw Refusal("not_now") }
            guard cards.indices.contains(cell), owner[cell] == nil, !faceUp.contains(cell) else { throw Refusal("taken") }
            faceUp.append(cell)
            seen[cell] = cards[cell]
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
        /// where that is, or else a card it hasn't seen.
        func companionFlip(using rng: inout Random) -> (cell: Int, recalled: Bool) {
            let hidden = cards.indices.filter { owner[$0] == nil && !faceUp.contains($0) }
            // Its memory right now: each card it has seen comes back with its level's chance.
            let remembered = seen.keys.sorted().filter { hidden.contains($0) && rng.chance(recall) }
            if let first = faceUp.first {
                if let partner = remembered.first(where: { cards[$0] == cards[first] }) { return (partner, true) }
            } else {
                let pairs = Dictionary(grouping: remembered, by: { cards[$0] }).values.filter { $0.count == 2 }
                if let pair = pairs.sorted(by: { $0[0] < $1[0] }).first { return (pair[0], true) }
            }
            let unseen = hidden.filter { seen[$0] == nil }
            return (rng.pick(unseen.isEmpty ? hidden : unseen), false)
        }

        private func turnEvents() -> [Event] {
            turn == .companion ? [.turn(.companion), .think(ms: 900)] : [.turn(.you)]
        }
    }
}
