import Foundation
import SidefolkExtensionKit

/// Quick Paws between two people (D96): one button, two keys (A for the first player, L for the second, by where they
/// sit on any keyboard). Sidefolk shows one signal to both and times the first key; a key before the signal gives the
/// round to the other; nobody in time plays the round again. Best of five.
extension QuickPawsScreen {
    static func duoBoard(_ s: QuickPawsEngine.State, events: [Games.Event], options o: GameOptions) -> Board {
        let d = s.duo
        if d.naming != nil { return TwoPlayers.namesBoard(d, companion: o.companion, title: L("Quick Paws")) }
        let g = s.game
        let keys = QuickPawsEngine.keys.map { $0.uppercased() }
        let shows: String? = if s.round != nil { nil }
            else if let w = s.lastWinner {
                s.early ? L("{name} pressed too soon!", ["name": d.name(w.other)]) : L("{name}: {n} ms", ["name": d.name(w), "n": g.lastYouMs ?? 0])
            } else { L("Nobody pressed.") }
        var parts: [BoardPart] = [
            TwoPlayers.score(d, g.score.you, g.score.companion, rounds: Games.QuickPaws.target),
            .prompt(s.round != nil ? L("{a} presses {ka}, {b} presses {kb}. First after Boop! wins.",
                                       ["a": d.names[0], "ka": keys[0], "b": d.names[1], "kb": keys[1]])
                        : s.lastWinner.map { L("{name} takes the round!", ["name": d.name($0)]) } ?? L("Again!"),
                    eyebrow: L("Round {n}", ["n": s.number])),
            .play(.reflex(afterMs: s.round?.waitMs, windowMs: s.round?.windowMs ?? Games.QuickPaws.window, wait: L("Steady…"), go: L("Boop!"),
                          early: L("Too soon!"), shows: shows, keys: QuickPawsEngine.keys)),
        ]
        if g.over {
            var facts: [(String, String)] = []
            if let tally = TwoPlayers.tally(id, d) { facts.append(tally) }
            parts.append(TwoPlayers.result(d, winner: g.score.leader, figure: "\(Format.integer(g.score.you)) – \(Format.integer(g.score.companion))",
                                           facts: facts))
        }
        let between = s.round == nil && !g.over
        return Board(parts, companion: TwoPlayers.cue(events), over: g.over, afterMs: between ? 1800 : nil)
    }
}
