import Foundation
import SidefolkExtensionKit

/// Rock, paper, scissors between two people (D96): names first, then each round the first player picks while the second looks away, a cover passes the Mac over, the
/// second picks, and both hands show at once. Nothing on a board before that reveal says which hand the first player chose. The companion referees: a nod for a round, a
/// shrug for a draw, confetti for the match, and never "I win".
extension RockPaperScissorsScreen {
    static func duoBoard(_ s: RockPaperScissorsEngine.State, events: [Games.Event], options o: GameOptions) -> Board {
        let d = s.duo
        if d.naming != nil { return TwoPlayers.namesBoard(d, companion: o.companion, title: L("Rock, Paper, Scissors"), eyebrow: L("2 players"), rounds: RockPaperScissorsEngine.toWin) }
        var parts: [BoardPart] = [TwoPlayers.score(d, s.you, s.companion, rounds: RockPaperScissorsEngine.toWin)]
        let (first, second) = (d.names[0], d.names[1])
        let tiles = Hand.allCases.map { hand -> Tile in
            var state = TileState.none
            // Each player's own hand; the third steps back. Colours say whose, never who won (D96).
            if let last = s.last { state = hand == last.you || hand == last.companion ? .picked : .faded }
            return Tile(title(hand), state: state, art: hand.rawValue)
        }
        if let last = s.last {
            parts.append(.reveal(.hands(you: last.you.rawValue, companion: last.companion.rawValue)))
            parts.append(.prompt(verdict(last, names: d.names), eyebrow: roundTitle(s.round)))
            parts.append(.answers(tiles, layout: .row, locked: true))
        } else if s.firstHand == nil {
            parts.append(.prompt(L("{name}, pick your toy.", ["name": first]), eyebrow: L("{name}, look away!", ["name": second])))
            parts.append(.answers(tiles, layout: .row))
        } else if !s.handedOver {
            // The cover: the first hand is in, and nothing here says which.
            parts.append(.prompt(L("Pass the Mac to {name}.", ["name": second]), eyebrow: L("{name}, look away!", ["name": first])))
            parts.append(.button(GameButton(L("I'm {name}: ready", ["name": second]), move: "ready", style: .primary, symbol: "eye.slash")))
        } else {
            parts.append(.prompt(L("{name}, pick your toy.", ["name": second]), eyebrow: L("{name}, look away!", ["name": first])))
            parts.append(.answers(tiles, layout: .row))
        }
        if s.over {
            let winner = s.you > s.companion ? first : second
            parts.append(.result(figure: figure(s), line: L("{name} wins the match!", ["name": winner]), tone: .info, actions: [rematch]))
        } else if s.last != nil {
            parts.append(.button(GameButton(L("Next round"), move: "next", style: .primary, symbol: "arrow.right")))
        }
        var made = Board(parts, companion: cue(s, events: events), over: s.over)
        made.sealedFirst = s.firstHand != nil
        return made
    }

    private static func cue(_ s: RockPaperScissorsEngine.State, events: [Games.Event]) -> Cue? {
        for event in events {
            switch event {
            case .matchOver: return Cue(move: "cheer", effect: "confetti", sound: "fanfare")
            case .roundOver(nil): return Cue(move: "shrug", line: "draw", sound: "boop")
            case .roundOver: return Cue(move: "nod", sound: "snap")
            case .sealed: return Cue(move: "nod", sound: "tap", look: "away")
            case .turn: return Cue(move: "ready", line: s.round == 1 && s.firstHand == nil ? "your_turn" : nil, look: "panel")
            default: continue
            }
        }
        return nil
    }

    /// "Rock beats scissors: a point for Ana." or "Both rock: a draw."
    static func verdict(_ last: RockPaperScissorsEngine.Throw, names: [String]) -> String {
        if last.you == last.companion { return L("Both {hand}: a draw.", ["hand": title(last.you)]) }
        let (win, lose, name) = last.you.beats == last.companion ? (last.you, last.companion, names[0]) : (last.companion, last.you, names[1])
        return L("{win} beats {lose}: a point for {name}.", ["win": title(win), "lose": title(lose), "name": name])
    }
}
