import Foundation
import SidefolkExtensionKit

/// Last Stick (Nim, whoever takes the last stick loses): take 1, 2 or 3 from the right, the companion counting under its
/// breath before its paw swipe. Who starts alternates game to game. After the person's third loss it offers its trick
/// and lights the sticks in fours.
enum LastStickEngine: GameEngine {
    struct State: Codable, Equatable {
        var game: Games.LastStick
        var first: Games.Side
        var taken = 0
        var takenBy: Games.Side?
        var lesson = false
        var wins = Games.Score()
    }

    enum Action: Equatable { case take(Int), next, lesson, again, level(GameLevel) }

    static func start(level: GameLevel, options: GameOptions, random: inout Games.Random) -> State {
        let r = PlaytimeRecords.load()
        return State(game: Games.LastStick(level: level, first: .you, losses: r.stickLosses, secretOffered: r.stickSecretOffered), first: .you)
    }

    static func opening(_ s: State) -> [Games.Event] { [.turn(.you)] }

    static func play(_ action: Action, on s: inout State, random: inout Games.Random) throws -> [Games.Event] {
        var events: [Games.Event]
        switch action {
        case .take(let n):
            events = try s.game.take(n, by: .you)
            (s.taken, s.takenBy) = (n, .you)
        case .next:
            guard s.game.turn == .companion, !s.game.over else { throw Games.Refusal("not_now") }
            let n = s.game.companionTake(using: &random)
            events = try s.game.take(n, by: .companion)
            (s.taken, s.takenBy) = (n, .companion)
        case .lesson:
            guard s.game.secretOffered else { throw Games.Refusal("not_now") }
            s.lesson = true
            return [.hint]
        case .again, .level:
            let level: GameLevel = if case .level(let l) = action { l } else { s.game.level }
            let first = s.first.other
            s = State(game: Games.LastStick(level: level, first: first, losses: s.game.losses, secretOffered: s.game.secretOffered), first: first,
                      lesson: s.lesson, wins: s.wins)
            return first == .companion ? [.turn(.companion), .think(ms: 900)] : [.turn(.you)]
        }
        if let winner = s.game.winner {
            s.wins[winner] += 1
            PlaytimeRecords.update { $0.stickLosses = s.game.losses; $0.stickSecretOffered = s.game.secretOffered }
            PlaytimeRecords.finish(LastStickScreen.id, winner == .you ? .won : .lost, you: s.wins.you, companion: s.wins.companion)
        }
        return events
    }

    static func outcome(of s: State) -> GameOutcome? { s.game.winner.map { $0 == .you ? .won : .lost } }
}

enum LastStickScreen: GameScreen {
    typealias Engine = LastStickEngine
    static let id = "last_stick"

    static func action(for move: Move, in s: LastStickEngine.State) -> LastStickEngine.Action? {
        switch move {
        case .number(let n): .take(n)
        case .next: .next
        case .button("lesson"): .lesson
        case .button("again"): .again
        case .choice("level", let l): GameLevel(rawValue: l).map { .level($0) }
        default: nil
        }
    }

    static func board(_ s: LastStickEngine.State, events: [Games.Event], options o: GameOptions) -> Board {
        let g = s.game
        let thinking = events.compactMap { if case .think(let ms) = $0 { ms } else { nil } }.first
        let lesson = s.lesson && !g.over ? g.lesson : nil
        let text: String = if let winner = g.winner {
            winner == .you ? L("{name} took the last stick. You win!", ["name": o.companion]) : L("You took the last stick.")
        } else if g.turn == .companion {
            L("{name} counts… {n} left.", ["name": o.companion, "n": g.left])
        } else {
            L("Take 1, 2 or 3. Don't take the last one!")
        }
        var parts: [BoardPart] = [
            ScreenKit.score(s.wins),
            .prompt(text, eyebrow: L(one: "{count} stick left · {level}", other: "{count} sticks left · {level}", count: g.left, ["level": ScreenKit.level(g.level)])),
            .play(.sticks(total: Games.LastStick.sticks, left: g.left, take: min(3, max(g.left, 1)), groups: lesson?.groups ?? [],
                          hint: lesson?.takeNow ?? [], taken: s.taken, takenBy: s.takenBy == .companion ? "companion" : s.takenBy == .you ? "you" : nil,
                          locked: g.over || g.turn != .you)),
        ]
        if lesson != nil {
            parts.append(.note(L("Leave one more than a multiple of four: 17, 13, 9, 5, then 1.") + " " + L("Every round, make four together."),
                               title: L("{name}'s secret", ["name": o.companion])))
        }
        if let outcome = LastStickEngine.outcome(of: s) {
            parts.append(ScreenKit.result(outcome, figure: "\(Format.integer(s.wins.you)) – \(Format.integer(s.wins.companion))", companion: o.companion))
            parts.append(ScreenKit.levels(g.level))
        }
        if g.secretOffered, !s.lesson {
            parts.append(.button(GameButton(L("Want to know my secret?"), move: "lesson", style: g.over ? .secondary : .plain, symbol: "lightbulb")))
        }
        var cue = EventCues.cue(events)
        if thinking != nil { cue = Cue(move: "think", line: "my_turn", look: "panel") }
        return Board(parts, companion: cue, over: g.over, afterMs: thinking)
    }
}
