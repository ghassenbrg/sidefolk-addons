import Foundation
import SidefolkExtensionKit

/// Memory Pairs between two people (D96): turns taken on one grid, a pair keeps the turn, most pairs wins. Each pair
/// found carries its finder's mark (the first player's cards plain, the second's marked as the other side), and the
/// companion only watches.
extension MemoryPairsScreen {
    static func duoBoard(_ s: MemoryPairsEngine.State, events: [Games.Event], options o: GameOptions) -> Board {
        let d = s.duo
        if d.naming != nil { return TwoPlayers.namesBoard(d, companion: o.companion, title: L("Memory Pairs")) }
        let g = s.game
        let cells = g.cards.indices.map { i -> Cell in
            let up = g.owner[i] != nil || g.faceUp.contains(i)
            let label = L("Card {n}", ["n": i + 1])
            let who = g.owner[i] ?? (g.faceUp.contains(i) ? g.turn : nil)
            return up ? Cell("symbol", value: symbols[g.cards[i]], companion: who == .companion,
                             label: label + ", " + name(g.cards[i]) + (g.owner[i].map { ", " + d.name($0) } ?? ""), animate: s.fresh == i ? "flip" : nil)
                : Cell("card_back", label: label)
        }
        let text: String = if g.over { L("All pairs found.") }
            else if g.waitingToCover { L("Not a pair.") + " " + L("{name} is next.", ["name": d.name(g.turn.other)]) }
            else { TwoPlayers.turn(d, g.turn) + ": " + L("turn two cards.") }
        var parts: [BoardPart] = [
            TwoPlayers.score(d, g.score.you, g.score.companion),
            .prompt(text, eyebrow: L("2 players")),
            .board(rows: 4, columns: 4, cells: cells, locked: g.over || g.waitingToCover),
        ]
        if g.over {
            var facts: [(String, String)] = []
            if let tally = TwoPlayers.tally(id, d) { facts.append(tally) }
            parts.append(TwoPlayers.result(d, winner: g.score.leader, figure: "\(Format.integer(g.score.you)) – \(Format.integer(g.score.companion))",
                                           facts: facts))
        }
        // Two cards that don't match stay up a moment, then the turn passes.
        return Board(parts, companion: TwoPlayers.cue(events), over: g.over, afterMs: g.waitingToCover ? 1400 : nil)
    }
}
