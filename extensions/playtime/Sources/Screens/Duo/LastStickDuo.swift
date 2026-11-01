import Foundation
import SidefolkExtensionKit

/// Last Stick between two people (D96): turns taken on the same row, whoever takes the last stick loses, and who starts
/// alternates game to game; each game won is a point, and every game goes into their head-to-head.
extension LastStickScreen {
    static func duoBoard(_ s: LastStickEngine.State, events: [Games.Event], options o: GameOptions) -> Board {
        let d = s.duo
        if d.naming != nil { return TwoPlayers.namesBoard(d, companion: o.companion, title: L("Last Stick")) }
        let g = s.game
        let text: String = if let winner = g.winner {
            L("{loser} took the last stick. {name} wins!", ["loser": d.name(winner.other), "name": d.name(winner)])
        } else {
            L("{name}'s turn: take 1, 2 or 3.", ["name": d.name(g.turn)])
        }
        var parts: [BoardPart] = [
            TwoPlayers.score(d, s.wins.you, s.wins.companion),
            .prompt(text, eyebrow: L(one: "{count} stick left", other: "{count} sticks left", count: g.left)),
            .play(.sticks(total: Games.LastStick.sticks, left: g.left, take: min(3, max(g.left, 1)), taken: s.taken,
                          takenBy: s.takenBy == .companion ? "companion" : s.takenBy == .you ? "you" : nil, locked: g.over)),
        ]
        if let note = ScreenKit.refusal(events) { parts.append(note) }
        if g.over {
            var facts: [(String, String)] = []
            if let tally = TwoPlayers.tally(id, d) { facts.append(tally) }
            parts.append(.result(figure: "\(Format.integer(s.wins.you)) – \(Format.integer(s.wins.companion))",
                                 line: L("{name} wins!", ["name": d.name(g.winner ?? .you)]), tone: .info, facts: facts,
                                 actions: [GameButton(L("Next game"), move: "again", style: .primary, symbol: "arrow.right")]))
        }
        return Board(parts, companion: TwoPlayers.cue(events), over: g.over)
    }
}
