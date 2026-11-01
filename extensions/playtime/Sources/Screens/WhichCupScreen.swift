import Foundation
import SidefolkExtensionKit

/// Which Cup?: the companion hides its gem, Sidefolk shows the shuffle the engine drew, and the person picks; five
/// rounds, quicker each time. On Sneaky (off unless the person turns it on) it may palm the gem, and clicking the
/// companion in the scene (or C) checks its paw and catches it. Where the gem ends is fixed when the round is drawn,
/// before any pick.
enum WhichCupEngine: GameEngine {
    struct State: Codable, Equatable {
        var game: Games.WhichCup
        var shuffle: Games.WhichCup.Shuffle?
        /// The last round's pick and where the gem was (nil: in the companion's paw), once lifted.
        var picked: Int?
        var gemAt: Int?
        var lifted = false
        var caught = false
        /// The companion, or two people taking rounds in turn (D96): cups each found, and whether whoever's round it is
        /// has said they're ready (the shuffle waits for them).
        var duo: TwoPlayers.Duo
        var found = [0, 0]
        var ready = false
    }

    enum Action: Equatable { case pick(Int), accuse, next, again, level(GameLevel), ready, duo(TwoPlayers.Setup) }

    static func start(level: GameLevel, options: GameOptions, random: inout Games.Random) -> State {
        fresh(level: level, sneaky: options.sneaky, duo: TwoPlayers.start(options), random: &random)
    }

    /// Sneaky is the companion's trick only: two people get honest cups and ten rounds, five each.
    static func fresh(level: GameLevel, sneaky: Bool, duo: TwoPlayers.Duo, random: inout Games.Random) -> State {
        var game = Games.WhichCup(level: level, sneaky: sneaky && !duo.on, length: duo.on ? 2 * Games.WhichCup.rounds : Games.WhichCup.rounds)
        let shuffle = try? game.start(using: &random)
        return State(game: game, shuffle: shuffle, duo: duo)
    }

    /// Whose round it is when two people play: the first player's first.
    static func player(_ s: State) -> Games.Side { (s.game.played - (s.lifted ? 1 : 0)).isMultiple(of: 2) ? .you : .companion }

    static func play(_ action: Action, on s: inout State, random: inout Games.Random) throws -> [Games.Event] {
        var events: [Games.Event]
        switch action {
        case .duo(let setup):
            guard s.game.played == 0, !s.lifted else { throw Games.Refusal("not_now") }
            let begin = TwoPlayers.apply(setup, to: &s.duo)
            s = fresh(level: s.game.level, sneaky: s.game.sneaky, duo: s.duo, random: &random)
            return begin ? [.turn(.you)] : []
        case .ready:
            guard s.duo.playing, !s.ready, !s.lifted else { throw Games.Refusal("not_now") }
            s.ready = true
            return [.turn(player(s))]
        case .pick(let cup):
            guard !s.duo.on || s.ready else { throw Games.Refusal("not_now") }
            let side = player(s)
            let (gem, e) = try s.game.pick(cup)
            (s.picked, s.gemAt, s.lifted, s.caught) = (cup, gem, true, false)
            events = e
            if s.duo.on {
                let hit = gem == cup
                if hit { s.found[side == .you ? 0 : 1] += 1 }
                events = [.reveal] + (hit ? [.point(side)] : [.miss(left: 0)]) + (s.game.over ? [.matchOver(winner: duoWinner(s))] : [])
            }
        case .accuse:
            events = try s.game.accuse()
            if events.contains(.caught) { (s.picked, s.gemAt, s.lifted, s.caught) = (nil, nil, true, true) }
        case .next:
            guard s.lifted, !s.game.over else { throw Games.Refusal("not_now") }
            s.shuffle = try s.game.start(using: &random)
            (s.picked, s.gemAt, s.lifted, s.caught, s.ready) = (nil, nil, false, false, false)
            return [.turn(.you)]
        case .again, .level:
            let level: GameLevel = if case .level(let l) = action { l } else { s.game.level }
            s = fresh(level: level, sneaky: s.game.sneaky, duo: s.duo, random: &random)
            return [.turn(.you)]
        }
        if s.game.over, s.duo.on {
            TwoPlayers.record(WhichCupScreen.id, s.duo, winner: duoWinner(s))
        } else if s.game.over, let outcome = outcome(of: s) {
            PlaytimeRecords.finish(WhichCupScreen.id, outcome, you: s.game.score.you, companion: s.game.score.companion, best: s.game.score.you)
        }
        return events
    }

    static func duoWinner(_ s: State) -> Games.Side? { s.found[0] == s.found[1] ? nil : s.found[0] > s.found[1] ? .you : .companion }

    static func outcome(of s: State) -> GameOutcome? {
        guard s.game.over else { return nil }
        return switch s.game.score.leader { case .you?: .won; case .companion?: .lost; case nil: .draw }
    }
}

enum WhichCupScreen: GameScreen {
    typealias Engine = WhichCupEngine
    static let id = "which_cup"

    static func action(for move: Move, in s: WhichCupEngine.State) -> WhichCupEngine.Action? {
        if let setup = TwoPlayers.setup(move) { return .duo(setup) }
        return switch move {
        case .button("ready"): .ready
        case .cell(0, let c): .pick(c)
        case .button("accuse"): .accuse
        case .next, .button("next"): .next
        case .button("again"): .again
        case .choice("level", let l): GameLevel(rawValue: l).map { .level($0) }
        default: nil
        }
    }

    static func board(_ s: WhichCupEngine.State, events: [Games.Event], options o: GameOptions) -> Board {
        if s.duo.on { return duoBoard(s, events: events, options: o) }
        let g = s.game
        let shuffle = s.shuffle
        let round = min(g.played + (s.lifted ? 0 : 1), Games.WhichCup.rounds)
        let prompt: String = if s.caught { L("Caught! The gem was in {name}'s paw.", ["name": o.companion]) }
            else if s.lifted, s.gemAt == nil { L("It was in {name}'s paw all along!", ["name": o.companion]) }
            else if s.lifted { s.gemAt == s.picked ? L("Found it!") : L("Not that one.") }
            else if g.accused { L("Nothing in my paw! It's under a cup.") }
            else if g.sneaky { L("Keep your eye on the gem… which cup? Think I'm hiding it? Click me.") }
            else { L("Keep your eye on the gem… which cup?") }
        var parts: [BoardPart] = [
            ScreenKit.score(g.score),
            .prompt(prompt, eyebrow: L("Round {n} of {total} · {level}", ["n": round, "total": Games.WhichCup.rounds, "level": ScreenKit.level(g.level)])),
            .play(.cups(count: g.cups, hide: s.lifted ? nil : shuffle?.hide, swaps: s.lifted ? [] : shuffle?.swaps ?? [], swapMs: shuffle?.swapMs ?? 400,
                        picked: s.picked, revealed: s.lifted, gem: s.gemAt, locked: s.lifted)),
        ]
        if g.sneaky, !s.lifted {
            // The companion in the scene is the button (C presses it too); once a round, then it can't be clicked.
            parts.append(.button(GameButton(L("Check {name}'s paw", ["name": o.companion]), move: "accuse", style: .plain, symbol: "hand.raised",
                                            key: "c", disabled: g.accused, companion: true)))
        }
        if g.played == 0, !s.lifted { parts.append(TwoPlayers.opponent(two: false, companion: o.companion)) }
        if let outcome = WhichCupEngine.outcome(of: s) {
            parts.append(ScreenKit.result(outcome, figure: "\(Format.integer(g.score.you)) – \(Format.integer(g.score.companion))", companion: o.companion))
            parts.append(ScreenKit.levels(g.level))
        } else if s.lifted {
            parts.append(.button(GameButton(L("Next round"), move: "next", style: .primary, symbol: "arrow.right")))
        }
        var cue = EventCues.cue(events)
        // A new round: the companion shuffles, its gem in hand before it goes under a cup.
        if events.contains(.opened) || events == [.turn(.you)] {
            cue = Cue(move: "shuffle", prop: "gem", line: events.contains(.opened) ? "hello" : nil, look: "panel")
        }
        return Board(parts, companion: cue, over: g.over)
    }
}
