import Foundation
import SidefolkExtensionKit

/// Which Cup? between two people (D96): the companion shuffles for both, and they take rounds in turn, five each,
/// each round waiting for its player to say they're ready. Most cups found wins. Sneaky stays the companion's trick
/// alone: two people always get an honest gem.
extension WhichCupScreen {
    static func duoBoard(_ s: WhichCupEngine.State, events: [Games.Event], options o: GameOptions) -> Board {
        let d = s.duo
        if d.naming != nil { return TwoPlayers.namesBoard(d, companion: o.companion, title: L("Which Cup?")) }
        let g = s.game
        let side = WhichCupEngine.player(s)
        let round = min(g.played / 2 + 1, Games.WhichCup.rounds)
        var parts: [BoardPart] = [TwoPlayers.score(d, s.found[0], s.found[1])]
        let eyebrow = L("Round {n} of {total}", ["n": round, "total": Games.WhichCup.rounds])
        if !s.ready, !s.lifted {
            parts.append(.prompt(L("{name}'s turn: keep your eye on the gem.", ["name": d.name(side)]), eyebrow: eyebrow))
            parts.append(.button(GameButton(L("I'm {name}: ready", ["name": d.name(side)]), move: "ready", style: .primary, symbol: "eye")))
        } else {
            let prompt: String = if s.lifted { s.gemAt == s.picked ? L("{name} found it!", ["name": d.name(side)]) : L("Not that one.") }
                else { L("{name}'s turn: which cup?", ["name": d.name(side)]) }
            parts.append(.prompt(prompt, eyebrow: eyebrow))
            parts.append(.play(.cups(count: g.cups, hide: s.lifted ? nil : s.shuffle?.hide, swaps: s.lifted ? [] : s.shuffle?.swaps ?? [],
                                     swapMs: s.shuffle?.swapMs ?? 400, picked: s.picked, revealed: s.lifted, gem: s.gemAt, locked: s.lifted)))
        }
        if g.over {
            var facts: [(String, String)] = []
            if let tally = TwoPlayers.tally(id, d) { facts.append(tally) }
            parts.append(TwoPlayers.result(d, winner: WhichCupEngine.duoWinner(s), figure: "\(Format.integer(s.found[0])) – \(Format.integer(s.found[1]))",
                                           facts: facts))
        } else if s.lifted {
            parts.append(.button(GameButton(L("Next round"), move: "next", style: .primary, symbol: "arrow.right")))
        }
        var cue = TwoPlayers.cue(events)
        if s.ready, !s.lifted { cue = Cue(move: "shuffle", prop: "gem", look: "panel") }
        return Board(parts, companion: cue, over: g.over)
    }
}
