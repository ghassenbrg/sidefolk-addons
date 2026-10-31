import Foundation
import SidefolkExtensionKit

/// Quick Paws, a reflex duel, best of five: "Steady…", then "Boop!", and whoever presses first takes the round.
/// Playtime only says how long to wait; Sidefolk shows the signal and times the press, so the clock is fair. The
/// companion's time is drawn when the round begins, before the person's press exists.
enum QuickPawsEngine: GameEngine {
    struct State: Codable, Equatable {
        var game: Games.QuickPaws
        /// The round waiting for a press; nil between rounds.
        var round: Games.QuickPaws.Round?
        var number = 1
        var early = false
        var record = false
    }

    enum Action: Equatable { case press(Int), early, timeout, next, again, level(GameLevel) }

    static func start(level: GameLevel, options: GameOptions, random: inout Games.Random) -> State {
        var game = Games.QuickPaws(level: level, best: PlaytimeRecords.load().games[QuickPawsScreen.id]?.best)
        let round = try? game.start(using: &random)
        return State(game: game, round: round)
    }

    static func play(_ action: Action, on s: inout State, random: inout Games.Random) throws -> [Games.Event] {
        var events: [Games.Event]
        switch action {
        case .press(let ms):
            events = try s.game.press(ms: ms)
            s.early = false
        case .early:
            events = try s.game.early()
            s.early = true
        case .timeout:
            events = try s.game.timeout()
            s.early = false
        case .next:
            guard !s.game.over, s.round == nil else { throw Games.Refusal("not_now") }
            s.round = try s.game.start(using: &random)
            s.number += 1
            return [.turn(.you)]
        case .again, .level:
            let level: GameLevel = if case .level(let l) = action { l } else { s.game.level }
            s = start(level: level, options: GameOptions(), random: &random)
            return [.turn(.you)]
        }
        s.round = nil
        if events.contains(where: { if case .newBest = $0 { true } else { false } }) { s.record = true }
        if s.game.over, let outcome = outcome(of: s) {
            PlaytimeRecords.finish(QuickPawsScreen.id, outcome, you: s.game.score.you, companion: s.game.score.companion, best: s.game.best,
                                   lower: true)
        }
        return events
    }

    static func outcome(of s: State) -> GameOutcome? {
        guard s.game.over else { return nil }
        return s.game.score.leader == .you ? .won : .lost
    }
}

enum QuickPawsScreen: GameScreen {
    typealias Engine = QuickPawsEngine
    static let id = "quick_paws"

    static func action(for move: Move, in s: QuickPawsEngine.State) -> QuickPawsEngine.Action? {
        switch move {
        case .press(let ms): .press(ms)
        case .early: .early
        case .timeout: .timeout
        case .next: .next
        case .button("again"): .again
        case .choice("level", let l): GameLevel(rawValue: l).map { .level($0) }
        default: nil
        }
    }

    static func board(_ s: QuickPawsEngine.State, events: [Games.Event], options o: GameOptions) -> Board {
        let g = s.game
        let ms = { (n: Int) in L("{n} ms", ["n": n]) }
        let shows: String? = s.round != nil ? nil
            : s.early ? L("Too soon!")
            : g.lastYouMs == nil ? L("Too slow!")
            : L("You {you} · {name} {companion}", ["you": ms(g.lastYouMs ?? 0), "name": o.companion, "companion": ms(g.lastCompanionMs ?? 0)])
        var parts: [BoardPart] = [
            ScreenKit.score(g.score, rounds: Games.QuickPaws.target),
            .prompt(s.round != nil || g.lastCompanionMs == nil ? L("Boop the button the moment it says Boop!")
                        : g.lastYouMs.map { $0 <= g.lastCompanionMs! } == true ? L("You were quicker!") : L("{name} was quicker.", ["name": o.companion]),
                    eyebrow: L("Round {n} · {level}", ["n": s.number, "level": ScreenKit.level(g.level)])),
            .play(.reflex(afterMs: s.round?.waitMs, windowMs: s.round?.windowMs ?? Games.QuickPaws.window, wait: L("Steady…"), go: L("Boop!"),
                          early: L("Too soon!"), shows: shows)),
        ]
        if let best = g.best { parts.append(.facts([(L("Your best"), ms(best))])) }
        if let outcome = QuickPawsEngine.outcome(of: s) {
            parts.append(ScreenKit.result(outcome, figure: "\(Format.integer(g.score.you)) – \(Format.integer(g.score.companion))",
                                          ribbon: s.record ? L("New best!") : nil, companion: o.companion))
            parts.append(ScreenKit.levels(g.level))
        }
        var cue = EventCues.cue(events)
        if events.contains(.opened) || events == [.turn(.you)] { cue = Cue(move: "ready", line: events.contains(.opened) ? "hello" : nil, look: "panel") }
        // Between rounds Sidefolk waits a moment on the times, then asks for the next round.
        let between = s.round == nil && !g.over
        return Board(parts, companion: cue, over: g.over, afterMs: between ? 1800 : nil)
    }
}
