import Foundation
import SidefolkExtensionKit

/// Which Cup?: the companion hides its gem, Sidefolk shows the shuffle the engine drew, and the person picks; five
/// rounds, quicker each time. On Sneaky (off unless the person turns it on) it may palm the gem, and "Check its paw"
/// catches it. Where the gem ends is fixed when the round is drawn, before any pick.
enum WhichCupEngine: GameEngine {
    struct State: Codable, Equatable {
        var game: Games.WhichCup
        var shuffle: Games.WhichCup.Shuffle?
        /// The last round's pick and where the gem was (nil: in the companion's paw), once lifted.
        var picked: Int?
        var gemAt: Int?
        var lifted = false
        var caught = false
    }

    enum Action: Equatable { case pick(Int), accuse, next, again, level(GameLevel) }

    static func start(level: GameLevel, options: GameOptions, random: inout Games.Random) -> State {
        var game = Games.WhichCup(level: level, sneaky: options.sneaky)
        let shuffle = try? game.start(using: &random)
        return State(game: game, shuffle: shuffle)
    }

    static func play(_ action: Action, on s: inout State, random: inout Games.Random) throws -> [Games.Event] {
        var events: [Games.Event]
        switch action {
        case .pick(let cup):
            let (gem, e) = try s.game.pick(cup)
            (s.picked, s.gemAt, s.lifted, s.caught) = (cup, gem, true, false)
            events = e
        case .accuse:
            events = try s.game.accuse()
            if events.contains(.caught) { (s.picked, s.gemAt, s.lifted, s.caught) = (nil, nil, true, true) }
        case .next:
            guard s.lifted, !s.game.over else { throw Games.Refusal("not_now") }
            s.shuffle = try s.game.start(using: &random)
            (s.picked, s.gemAt, s.lifted, s.caught) = (nil, nil, false, false)
            return [.turn(.you)]
        case .again, .level:
            let level: GameLevel = if case .level(let l) = action { l } else { s.game.level }
            var options = GameOptions()
            options.sneaky = s.game.sneaky
            s = start(level: level, options: options, random: &random)
            return [.turn(.you)]
        }
        if s.game.over, let outcome = outcome(of: s) {
            PlaytimeRecords.finish(WhichCupScreen.id, outcome, you: s.game.score.you, companion: s.game.score.companion, best: s.game.score.you)
        }
        return events
    }

    static func outcome(of s: State) -> GameOutcome? {
        guard s.game.over else { return nil }
        return switch s.game.score.leader { case .you?: .won; case .companion?: .lost; case nil: .draw }
    }
}

enum WhichCupScreen: GameScreen {
    typealias Engine = WhichCupEngine
    static let id = "which_cup"

    static func action(for move: Move, in s: WhichCupEngine.State) -> WhichCupEngine.Action? {
        switch move {
        case .cell(0, let c): .pick(c)
        case .button("accuse"): .accuse
        case .next, .button("next"): .next
        case .button("again"): .again
        case .choice("level", let l): GameLevel(rawValue: l).map { .level($0) }
        default: nil
        }
    }

    static func board(_ s: WhichCupEngine.State, events: [Games.Event], options o: GameOptions) -> Board {
        let g = s.game
        let shuffle = s.shuffle
        let round = min(g.played + (s.lifted ? 0 : 1), Games.WhichCup.rounds)
        let prompt: String = if s.caught { L("Caught! The gem was in {name}'s paw.", ["name": o.companion]) }
            else if s.lifted, s.gemAt == nil { L("It was in {name}'s paw all along!", ["name": o.companion]) }
            else if s.lifted { s.gemAt == s.picked ? L("Found it!") : L("Not that one.") }
            else { L("Keep your eye on the gem… which cup?") }
        var parts: [BoardPart] = [
            ScreenKit.score(g.score),
            .prompt(prompt, eyebrow: L("Round {n} of {total} · {level}", ["n": round, "total": Games.WhichCup.rounds, "level": ScreenKit.level(g.level)])),
            .play(.cups(count: g.cups, hide: s.lifted ? nil : shuffle?.hide, swaps: s.lifted ? [] : shuffle?.swaps ?? [], swapMs: shuffle?.swapMs ?? 400,
                        picked: s.picked, revealed: s.lifted, gem: s.gemAt, locked: s.lifted)),
        ]
        if g.sneaky, !s.lifted {
            parts.append(.button(GameButton(L("Check {name}'s paw", ["name": o.companion]), move: "accuse", style: .plain, symbol: "hand.raised",
                                            key: "c")))
        }
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
