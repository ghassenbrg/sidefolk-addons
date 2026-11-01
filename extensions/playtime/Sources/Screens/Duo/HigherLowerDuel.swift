import Foundation
import SidefolkExtensionKit

/// Higher or Lower between two people (D96): each hides a number for the other in turn. The one who hides types it
/// while the other looks away, a cover passes the Mac over (so the number is gone from the screen), and the other
/// guesses with the usual higher, lower and thermometer. After both rounds, fewer guesses wins.
struct HigherLowerDuel: Codable, Equatable {
    enum Stage: String, Codable {
        /// The Mac goes to the one who hides (the other looks away).
        case toHider
        /// The hider types the number.
        case hiding
        /// The Mac goes to the one who guesses.
        case toGuesser
        case guessing
        /// A round is found; the next one, or the end.
        case found
    }

    var hider = Games.Side.you
    var stage = Stage.toHider
    var game: Games.HigherLower.GuessMine?
    /// How many guesses each took to find the other's number: the first player's, then the second's.
    var guesses: [Int?] = [nil, nil]

    var guesser: Games.Side { hider.other }
    var over: Bool { guesses.allSatisfy { $0 != nil } }
    /// Fewer guesses wins; nil is a draw.
    var winner: Games.Side? {
        guard let a = guesses[0], let b = guesses[1], a != b else { return nil }
        return a < b ? .you : .companion
    }

    typealias Engine = HigherLowerEngine

    static func play(_ action: Engine.Action, on s: inout Engine.State, random: inout Games.Random) throws -> [Games.Event] {
        switch action {
        case .duo(let setup):
            guard s.duel == nil || s.duel?.over == true else { throw Games.Refusal("not_now") }
            if TwoPlayers.apply(setup, to: &s.duo) { s.duel = s.duo.on ? HigherLowerDuel() : nil }
            return s.duel != nil ? [.turn(.you)] : []
        case .top(let value) where s.duel == nil || s.duel?.stage == .toHider && s.duel?.hider == .you && s.duel?.game == nil:
            Engine.choose(top: value, &s)
            return []
        case .otherTop:
            throw Games.Refusal("bad_top")
        case .ready:
            guard var duel = s.duel else { throw Games.Refusal("not_now") }
            switch duel.stage {
            case .toHider: duel.stage = .hiding
            case .toGuesser: duel.stage = .guessing
            default: throw Games.Refusal("not_now")
            }
            s.duel = duel
            return [.turn(duel.stage == .hiding ? duel.hider : duel.guesser)]
        case .guess(let n):
            guard var duel = s.duel else { throw Games.Refusal("not_now") }
            if duel.stage == .hiding {
                guard s.range.contains(n) else { throw Games.Refusal("out_of_range") }
                // The number is set; the board that follows is the cover, which never shows it.
                duel.game = Games.HigherLower.GuessMine(range: s.range, secret: n)
                duel.stage = .toGuesser
                s.duel = duel
                return [.sealed]
            }
            guard duel.stage == .guessing, var game = duel.game else { throw Games.Refusal("not_now") }
            let events = try game.guess(n)
            duel.game = game
            if game.found {
                duel.guesses[duel.guesser == .you ? 0 : 1] = game.guesses.count
                duel.stage = .found
                s.duel = duel
                var out: [Games.Event] = [.reveal, .found(guesses: game.guesses.count), .point(duel.guesser)]
                if duel.over {
                    TwoPlayers.record(HigherLowerScreen.id, s.duo, winner: duel.winner)
                    out.append(.matchOver(winner: duel.winner))
                }
                return out
            }
            s.duel = duel
            return events
        case .next:
            // The second round: the other one hides.
            guard var duel = s.duel, duel.stage == .found, !duel.over else { throw Games.Refusal("not_now") }
            duel.hider = .companion
            duel.stage = .toHider
            duel.game = nil
            s.duel = duel
            return [.turn(.companion)]
        case .again:
            s.duel = HigherLowerDuel()
            return [.turn(.you)]
        case .start:
            guard s.duo.playing else { throw Games.Refusal("not_now") }
            s.duel = s.duel ?? HigherLowerDuel()
            return []
        default:
            throw Games.Refusal("not_now")
        }
    }

    static func board(_ s: Engine.State, events: [Games.Event], options o: GameOptions) -> Board {
        let d = s.duo
        if d.naming != nil { return TwoPlayers.namesBoard(d, companion: o.companion, title: L("Higher or Lower")) }
        let duel = s.duel ?? HigherLowerDuel()
        let round = L("Round {n} of 2", ["n": duel.hider == .you ? 1 : 2])
        var parts: [BoardPart] = [TwoPlayers.score(d, duel.guesses[0] ?? 0, duel.guesses[1] ?? 0)]
        var cue = TwoPlayers.cue(events)
        switch duel.stage {
        case .toHider:
            parts += TwoPlayers.cover(d, to: duel.hider, eyebrow: round)
            parts.append(.note(L("{name} hides a number; {other} finds it. Fewer guesses wins.", ["name": d.name(duel.hider), "other": d.name(duel.guesser)])))
            if duel.hider == .you, duel.game == nil { parts += HigherLowerScreen.tops(s) }
        case .hiding:
            parts.append(.prompt(L("{name}, type a secret number.", ["name": d.name(duel.hider)]),
                                 eyebrow: HigherLowerScreen.numbers(s) + " · " + L("{name}, look away!", ["name": d.name(duel.guesser)])))
            parts.append(.play(.number(min: s.low, max: s.high, label: L("Return hides it"))))
        case .toGuesser:
            parts += TwoPlayers.cover(d, to: duel.guesser, eyebrow: round)
            cue = Cue(move: "tease", prop: "sealed_card", look: "panel")
        case .guessing, .found:
            let game = duel.game!
            let last = game.guesses.last
            let text: String = if game.found { L("Yes! It was {n}.", ["n": game.shown ?? 0]) }
                else if let last { last < game.low ? L("Higher than {n}!", ["n": last]) : L("Lower than {n}!", ["n": last]) }
                else { L("{name}, find {other}'s number.", ["name": d.name(duel.guesser), "other": d.name(duel.hider)]) }
            parts.append(.prompt(text, eyebrow: round + " · " + L("Guess {n} · par {par}", ["n": game.guesses.count + (game.found ? 0 : 1), "par": game.par])))
            if last != nil, !game.found {
                parts.append(.play(.meter(game.warmth, label: HigherLowerScreen.warmth(game.warmth), low: L("Cold"), high: L("Hot"))))
            }
            let history = game.guesses.map { g -> (Int, String) in (g, g == game.shown ? "right" : g < game.low ? "higher" : "lower") }
            parts.append(.play(.number(min: s.low, max: s.high, label: L("Between {low} and {high}", ["low": game.low, "high": game.high]),
                                       history: history, locked: game.found)))
            if duel.over {
                var facts: [(String, String)] = [(d.names[0], Format.integer(duel.guesses[0] ?? 0)), (d.names[1], Format.integer(duel.guesses[1] ?? 0))]
                if let tally = TwoPlayers.tally(HigherLowerScreen.id, d) { facts.append(tally) }
                parts.append(TwoPlayers.result(d, winner: duel.winner,
                                               figure: "\(Format.integer(duel.guesses[0] ?? 0)) – \(Format.integer(duel.guesses[1] ?? 0))", facts: facts))
            } else if game.found {
                parts.append(.button(GameButton(L("Next round"), move: "next_round", style: .primary, symbol: "arrow.right")))
            }
        }
        if let note = HigherLowerScreen.refusal(events, low: s.low, high: s.high) { parts.append(note) }
        return Board(parts, companion: cue, over: duel.over)
    }
}
