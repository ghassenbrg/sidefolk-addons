import Foundation
import SidefolkExtensionKit

/// Higher or Lower, both ways round, on 1–100. "Guess mine": the companion's number is drawn at the start and kept
/// sealed; a thermometer says how warm each guess is; par is seven. "I'll guess yours": the companion halves the range,
/// thinks a moment between guesses, and notices an answer that contradicts an earlier one.
enum HigherLowerEngine: GameEngine {
    enum Mode: String, Codable { case mine, yours }

    struct State: Codable, Equatable {
        var mode: Mode?
        var mine: Games.HigherLower.GuessMine?
        var yours: Games.HigherLower.GuessYours?
        /// The companion is thinking before its next "Is it…?".
        var thinking = false
        var over = false
        var outcome: GameOutcome?
    }

    enum Action: Equatable { case mode(Mode), guess(Int), answer(Games.HigherLower.GuessYours.Answer), next, again }

    static func start(level: GameLevel, options: GameOptions, random: inout Games.Random) -> State { State() }

    static func play(_ action: Action, on s: inout State, random: inout Games.Random) throws -> [Games.Event] {
        switch action {
        case .mode(let mode):
            guard s.mode == nil else { throw Games.Refusal("not_now") }
            return begin(mode, &s, &random)
        case .guess(let n):
            guard var game = s.mine, !s.over else { throw Games.Refusal("not_now") }
            let events = try game.guess(n)
            s.mine = game
            if game.found {
                s.over = true
                s.outcome = game.guesses.count <= Games.HigherLower.par ? .won : .lost
                PlaytimeRecords.finish(HigherLowerScreen.id, s.outcome!, you: game.guesses.count, companion: Games.HigherLower.par,
                                       best: game.guesses.count, lower: true)
            }
            return events
        case .answer(let a):
            guard var game = s.yours, !s.over, !s.thinking else { throw Games.Refusal("not_now") }
            let events = try game.answer(a)
            s.yours = game
            if game.found {
                s.over = true
                s.outcome = .lost
                PlaytimeRecords.finish(HigherLowerScreen.id + "_yours", .lost, you: 0, companion: game.asked)
            } else if events.contains(where: { if case .think = $0 { true } else { false } }) {
                s.thinking = true
            }
            return events
        case .next:
            guard s.thinking else { throw Games.Refusal("not_now") }
            s.thinking = false
            return [.turn(.you)]
        case .again:
            let mode = s.mode
            s = State()
            return mode.map { begin($0, &s, &random) } ?? [.turn(.you)]
        }
    }

    private static func begin(_ mode: Mode, _ s: inout State, _ random: inout Games.Random) -> [Games.Event] {
        s.mode = mode
        switch mode {
        case .mine:
            // Its number is drawn now, before any guess.
            s.mine = Games.HigherLower.GuessMine(using: &random)
            return Games.HigherLower.GuessMine.opening
        case .yours:
            s.yours = Games.HigherLower.GuessYours()
            s.thinking = true
            return [.think(ms: 900)]
        }
    }

    static func outcome(of s: State) -> GameOutcome? { s.outcome }
}

enum HigherLowerScreen: GameScreen {
    typealias Engine = HigherLowerEngine
    static let id = "higher_lower"

    static func action(for move: Move, in s: HigherLowerEngine.State) -> HigherLowerEngine.Action? {
        switch move {
        case .choice("mode", let m): HigherLowerEngine.Mode(rawValue: m).map { .mode($0) }
        case .number(let n): .guess(n)
        case .answer(let i): [.higher, .lower, .yes][safe: i].map { .answer($0) }
        case .next: .next
        case .button("again"): .again
        default: nil
        }
    }

    static func board(_ s: HigherLowerEngine.State, events: [Games.Event], options o: GameOptions) -> Board {
        var parts: [BoardPart] = []
        var cue = EventCues.cue(events)
        var after: Int?
        if s.mode == nil {
            parts = [.prompt(L("Pick a way to play"), eyebrow: L("Numbers from 1 to 100")),
                     .choice(name: "mode", style: .cards, options: [
                         ChoiceOption("mine", L("Guess mine"), detail: L("{name} hides a number", ["name": o.companion]), symbol: "questionmark.square.fill"),
                         ChoiceOption("yours", L("I'll guess yours"), detail: L("Think of a number"), symbol: "brain.head.profile"),
                     ])]
            cue = Cue(move: "ready", line: "hello", look: "panel")
        } else if let game = s.mine {
            let n = game.guesses.count
            let last = game.guesses.last
            let text: String = if game.found { L("Yes! It was {n}.", ["n": game.shown ?? 0]) }
                else if let last { last < (game.low) ? L("Higher than {n}!", ["n": last]) : L("Lower than {n}!", ["n": last]) }
                else { L("I'm hiding a number from 1 to 100. Guess it!") }
            let history = game.guesses.map { g -> (Int, String) in (g, g == game.shown ? "right" : g < game.low ? "higher" : "lower") }
            parts = [
                .score(you: n, companion: Games.HigherLower.par, best: PlaytimeRecords.load().games[HigherLowerScreen.id]?.best),
                .prompt(text, eyebrow: L("Guess {n} · par {par}", ["n": n + (game.found ? 0 : 1), "par": Games.HigherLower.par])),
            ]
            if last != nil, !game.found {
                parts.append(.play(.meter(game.warmth, label: warmth(game.warmth), low: L("Cold"), high: L("Hot"))))
            }
            parts.append(.play(.number(min: 1, max: 100, label: L("Between {low} and {high}", ["low": game.low, "high": game.high]),
                                       history: history, locked: game.found)))
            // Far off it shivers in frost; close, it fans itself.
            if last != nil, !game.found {
                cue = Cue(move: game.warmth > 0.9 ? "sweat" : game.warmth < 0.6 ? "wince" : nil, effect: game.warmth > 0.9 ? "flame" : game.warmth < 0.6 ? "frost" : nil,
                          sound: "tick", look: "panel")
            }
            if events.contains(where: { if case .sealed = $0 { true } else { false } }) { cue = Cue(move: "tease", prop: "sealed_card", line: "hello") }
        } else if let game = s.yours {
            let range = L("Between {low} and {high}", ["low": game.low, "high": game.high])
            parts = [.score(you: 0, companion: game.asked)]
            if s.thinking {
                parts.append(.prompt(L("Hmm… {range}…", ["range": range]), eyebrow: L("Question {n}", ["n": game.asked])))
                after = events.compactMap { if case .think(let ms) = $0 { ms } else { nil } }.first ?? 900
                cue = Cue(move: "think", effect: "question", line: "thinking", look: "panel")
            } else if game.found {
                parts.append(.prompt(L("Got it: {n}!", ["n": game.guess]), eyebrow: L("Found in {n}", ["n": game.asked])))
            } else {
                parts.append(.prompt(L("Is it… {n}?", ["n": game.guess]), eyebrow: range))
                if let earlier = game.contradicts {
                    parts.append(.note(L("Hmm, that doesn't fit what you said about {n} before…", ["n": earlier]), tone: .warn))
                }
                parts.append(.answers([Tile(L("Higher"), key: "h"), Tile(L("Lower"), key: "l"), Tile(L("That's it!"), key: "y")], layout: .row))
            }
        }
        if let note = ScreenKit.refusal(events) { parts.append(note) }
        if let outcome = s.outcome {
            let guesses = s.mine?.guesses.count ?? s.yours?.asked ?? 0
            parts.append(ScreenKit.result(outcome, figure: Format.integer(guesses),
                                          line: s.mode == .yours ? L(one: "{name} found it in {count} question.", other: "{name} found it in {count} questions.", count: guesses, ["name": o.companion])
                                              : outcome == .won ? L("Found in {n}, at par or better!", ["n": guesses]) : L("Found in {n}: par is {par}.", ["n": guesses, "par": Games.HigherLower.par]),
                                          companion: o.companion))
        }
        return Board(parts, companion: cue, over: s.over, afterMs: after)
    }

    static func warmth(_ w: Double) -> String {
        w > 0.95 ? L("Burning hot!") : w > 0.85 ? L("Warm") : w > 0.6 ? L("Cool") : L("Freezing")
    }
}

extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}
