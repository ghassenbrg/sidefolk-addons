import Foundation
import SidefolkExtensionKit

/// Rock, paper, scissors as a best of three (Sidefolk D75). The companion's hand is drawn as each round begins, before the person picks, and kept sealed (its card
/// in the score bar) until both show; nothing reads the person's hand to choose it. Now and then it bluffs before a round ("I'm going rock…"), naming a hand drawn
/// apart from the one it holds, so the bluff is true about a third of the time. Two people can play each other instead (D96): the first picks while the second looks
/// away, a cover passes the Mac over, the second picks, and only then both hands show.
enum RockPaperScissorsEngine: GameEngine {
    typealias Hand = Games.Hand
    static let toWin = 2

    struct Throw: Codable, Equatable {
        var you: Hand
        var companion: Hand
    }

    struct State: Codable, Equatable {
        var round = 1
        var you = 0
        var companion = 0
        /// The last throw, while its result shows.
        var last: Throw?
        /// The companion's hand for the round under way, sealed until the person picks.
        var sealed: Hand?
        /// Its hands so far, for its "not three in a row".
        var thrown: [Hand] = []
        /// The hand it says it's going for this round; it has no bearing on the one it holds.
        var bluff: Hand?
        /// The companion, or two people on this Mac.
        var duo: TwoPlayers.Duo
        /// The first player's hand this round, in and hidden until the second has picked.
        var firstHand: Hand?
        /// The Mac was passed to the second player.
        var handedOver = false

        var over: Bool { you >= toWin || companion >= toWin }
    }

    enum Action: Equatable { case hand(Int), next, again, ready, duo(TwoPlayers.Setup) }

    /// A fresh match against the companion, its first hand already sealed.
    private static func match(_ duo: TwoPlayers.Duo, random: inout Games.Random) -> State {
        var s = State(duo: duo)
        guard !duo.on else { return s }
        let sealed = Hand.draw(after: [], using: &random)
        s.sealed = sealed
        s.thrown = [sealed]
        return s
    }

    static func start(level: GameLevel, options: GameOptions, random: inout Games.Random) -> State {
        match(TwoPlayers.start(options), random: &random)
    }

    static func play(_ action: Action, on s: inout State, random: inout Games.Random) throws -> [Games.Event] {
        switch action {
        case .duo(let setup):
            guard s.round == 1, s.last == nil, s.firstHand == nil else { throw Games.Refusal("not_now") }
            let begin = TwoPlayers.apply(setup, to: &s.duo)
            s = match(s.duo, random: &random)
            return begin ? [.turn(.you)] : []
        case .hand(let i):
            guard Hand.allCases.indices.contains(i), s.last == nil, !s.over, !s.duo.on || s.duo.playing else { throw Games.Refusal("not_now") }
            let picked = Hand.allCases[i]
            if s.duo.on { return try duel(picked, on: &s) }
            guard let mine = s.sealed else { throw Games.Refusal("not_now") }
            PlaytimeRecords.addThrow(person: picked, companion: mine)
            finishRound(Throw(you: picked, companion: mine), on: &s)
            s.sealed = nil
            s.bluff = nil
            if s.over {
                let won = s.you > s.companion
                PlaytimeRecords.finish(RockPaperScissorsScreen.id, won ? .won : .lost, you: s.you, companion: s.companion)
                return [.matchOver(winner: won ? .you : .companion)]
            }
            return [.roundOver(winner: picked == mine ? nil : picked.beats == mine ? .you : .companion)]
        case .ready:
            guard s.duo.on, s.firstHand != nil else { throw Games.Refusal("not_now") }
            s.handedOver = true
            return [.turn(.companion)]
        case .next:
            guard s.last != nil, !s.over else { throw Games.Refusal("not_now") }
            s.last = nil
            s.round += 1
            guard !s.duo.on else { return [.turn(.you)] }
            let sealed = Hand.draw(after: s.thrown, using: &random)
            // A bluff now and then, before the count: a wink and a hand named at random, apart from the one it holds.
            s.bluff = random.below(3) == 0 ? Hand.allCases[random.below(3)] : nil
            s.sealed = sealed
            s.thrown = Array((s.thrown + [sealed]).suffix(2))
            return [.turn(.you)]
        case .again:
            s = match(s.duo, random: &random)
            return s.duo.on ? [.turn(.you)] : [.opened]
        }
    }

    private static func duel(_ picked: Hand, on s: inout State) throws -> [Games.Event] {
        guard let first = s.firstHand else {
            s.firstHand = picked
            s.handedOver = false
            return [.sealed]
        }
        guard s.handedOver else { throw Games.Refusal("not_now") }
        finishRound(Throw(you: first, companion: picked), on: &s)
        s.firstHand = nil
        s.handedOver = false
        if s.over {
            let winner: Games.Side = s.you > s.companion ? .you : .companion
            TwoPlayers.record(RockPaperScissorsScreen.id, s.duo, winner: winner)
            return [.matchOver(winner: winner)]
        }
        return [.roundOver(winner: first == picked ? nil : first.beats == picked ? .you : .companion)]
    }

    private static func finishRound(_ thrown: Throw, on s: inout State) {
        s.last = thrown
        if thrown.you.beats == thrown.companion { s.you += 1 } else if thrown.companion.beats == thrown.you { s.companion += 1 }
    }

    static func outcome(of s: State) -> GameOutcome? {
        guard s.over else { return nil }
        return s.you > s.companion ? .won : .lost
    }
}

enum RockPaperScissorsScreen: GameScreen {
    typealias Engine = RockPaperScissorsEngine
    typealias Hand = Games.Hand
    static let id = "rock_paper_scissors"

    static func title(_ hand: Hand) -> String {
        switch hand {
        case .rock: L("Rock")
        case .paper: L("Paper")
        case .scissors: L("Scissors")
        }
    }

    static func action(for move: Move, in s: RockPaperScissorsEngine.State) -> RockPaperScissorsEngine.Action? {
        if let setup = TwoPlayers.setup(move) { return .duo(setup) }
        return switch move {
        case .answer(let i): .hand(i)
        case .button("next"): .next
        case .button("again"): .again
        case .button("ready"): .ready
        default: nil
        }
    }

    static func board(_ s: RockPaperScissorsEngine.State, events: [Games.Event], options o: GameOptions) -> Board {
        if s.duo.on { return duoBoard(s, events: events, options: o) }
        var parts: [BoardPart] = [.score(you: s.you, companion: s.companion, rounds: RockPaperScissorsEngine.toWin, companionPicked: s.sealed != nil)]
        let tiles = Hand.allCases.map { hand -> Tile in
            var state = TileState.none
            if let last = s.last {
                // The person's hand shows how it went; the companion's carries its face; the third steps back.
                state = hand == last.you ? (last.you.beats == last.companion ? .right : last.companion.beats == last.you ? .wrong : .picked)
                    : hand == last.companion ? .none : .faded
            }
            return Tile(title(hand), state: state, companion: s.last?.companion == hand, art: hand.rawValue)
        }
        let eyebrow = roundTitle(s.round)
        if let last = s.last {
            parts.append(.reveal(.hands(you: last.you.rawValue, companion: last.companion.rawValue)))
            parts.append(.prompt(TossWords.verdict(person: last.you, companion: last.companion), eyebrow: eyebrow))
        } else {
            // The bluff stays in the panel's own bubble: the companion says nothing on the desktop (D98).
            parts.append(.prompt(s.bluff.map(bluff) ?? L("Rock, paper or scissors?"), eyebrow: eyebrow))
        }
        parts.append(.answers(tiles, layout: .row, locked: s.last != nil))
        // Before the first throw: against the companion, or two people on this Mac.
        if s.round == 1, s.last == nil { parts.append(TwoPlayers.opponent(two: false, companion: o.companion)) }
        if s.over {
            let won = s.you > s.companion
            parts.append(.result(figure: figure(s), line: won ? L("You win the match!") : L("{name} wins the match.", ["name": o.companion]), tone: won ? .good : .bad,
                                 actions: [rematch]))
        } else if s.last != nil {
            parts.append(.button(GameButton(L("Next round"), move: "next", style: .primary, symbol: "arrow.right")))
        }
        return Board(parts, companion: cue(s, events: events), over: s.over)
    }

    static var rematch: GameButton { GameButton(L("Rematch"), move: "again", style: .primary, symbol: "arrow.clockwise") }

    static func figure(_ s: RockPaperScissorsEngine.State) -> String { "\(Format.integer(s.you)) – \(Format.integer(s.companion))" }

    static func roundTitle(_ round: Int) -> String { L("Round {n}", ["n": round]) }

    static func bluff(_ hand: Hand) -> String {
        switch hand {
        case .rock: L("I'm going rock…")
        case .paper: L("I'm going paper…")
        case .scissors: L("I'm going scissors…")
        }
    }

    /// After a throw: a round is a small moment, the match a big one. Against the companion only: two people have `TwoPlayers.cue`.
    private static func cue(_ s: RockPaperScissorsEngine.State, events: [Games.Event]) -> Cue? {
        if events.contains(.opened) { return Cue(move: "ready", line: "hello", look: "panel") }
        for event in events {
            switch event {
            case .matchOver(let winner):
                return winner == .you ? Cue(move: "bow", effect: "confetti", line: "you_win", sound: "fanfare") : Cue(move: "celebrate", prop: "crown", line: "i_win", sound: "fanfare")
            case .roundOver(let winner?):
                return winner == .you ? Cue(move: "gasp", sound: "snap") : Cue(move: "giggle", line: "tease", sound: "snap")
            case .roundOver(nil): return Cue(move: "shrug", line: "draw", sound: "boop")
            case .turn: return s.bluff != nil ? Cue(move: "tease", look: "you") : Cue(move: "ready", look: "panel")
            default: continue
            }
        }
        return nil
    }
}
