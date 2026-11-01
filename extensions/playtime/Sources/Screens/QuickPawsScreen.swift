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
        /// The companion, or two people on one button, each on a key (D96).
        var duo: TwoPlayers.Duo
        /// Two people: who took the last round, and how (their time, or the other pressed too soon).
        var lastWinner: Games.Side?
    }

    enum Action: Equatable { case press(Int), early, timeout, next, again, level(GameLevel), key(Games.Side, ms: Int?), duo(TwoPlayers.Setup) }

    /// The two players' keys, far apart on any keyboard: the first player's on the left.
    static let keys = ["a", "l"]

    static func start(level: GameLevel, options: GameOptions, random: inout Games.Random) -> State {
        fresh(level: level, duo: TwoPlayers.start(options), random: &random)
    }

    static func fresh(level: GameLevel, duo: TwoPlayers.Duo, random: inout Games.Random) -> State {
        var game = Games.QuickPaws(level: level, best: duo.on ? nil : PlaytimeRecords.load().games[QuickPawsScreen.id]?.best)
        // Two people's first round waits for their names.
        let round = duo.on && !duo.playing ? nil : try? game.start(using: &random)
        return State(game: game, round: round, duo: duo)
    }

    static func play(_ action: Action, on s: inout State, random: inout Games.Random) throws -> [Games.Event] {
        var events: [Games.Event]
        switch action {
        case .duo(let setup):
            guard s.number == 1, s.game.score == Games.Score() || s.duo.on else { throw Games.Refusal("not_now") }
            _ = TwoPlayers.apply(setup, to: &s.duo)
            s = fresh(level: s.game.level, duo: s.duo, random: &random)
            return [.turn(.you)]
        case .key(let side, let ms):
            guard s.duo.playing else { throw Games.Refusal("not_now") }
            events = try s.game.keyed(side, ms: ms)
            s.early = ms == nil
            s.lastWinner = ms == nil ? side.other : side
        case .timeout where s.duo.on:
            guard s.duo.playing else { throw Games.Refusal("not_now") }
            events = try s.game.unplayed()
            s.lastWinner = nil
            s.early = false
        case .press where s.duo.on, .early where s.duo.on:
            // Two people press their own keys; a click can't say whose it was.
            throw Games.Refusal("not_now")
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
            s = fresh(level: level, duo: s.duo, random: &random)
            return [.turn(.you)]
        }
        s.round = nil
        if events.contains(where: { if case .newBest = $0 { true } else { false } }) { s.record = true }
        if s.game.over, s.duo.on {
            TwoPlayers.record(QuickPawsScreen.id, s.duo, winner: s.game.score.leader)
        } else if s.game.over, let outcome = outcome(of: s) {
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
        if let setup = TwoPlayers.setup(move) { return .duo(setup) }
        return switch move {
        case .pressKey(let ms, let key): QuickPawsEngine.keys.firstIndex(of: key).map { .key($0 == 0 ? .you : .companion, ms: ms) }
        case .earlyKey(let key): QuickPawsEngine.keys.firstIndex(of: key).map { .key($0 == 0 ? .you : .companion, ms: nil) }
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
        if s.duo.on { return duoBoard(s, events: events, options: o) }
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
        if s.number == 1, g.score == Games.Score() { parts.append(TwoPlayers.opponent(two: false, companion: o.companion)) }
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
