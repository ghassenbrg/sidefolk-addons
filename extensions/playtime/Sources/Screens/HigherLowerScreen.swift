import Foundation
import SidefolkExtensionKit

/// Higher or Lower, both ways round, on 1 to 100 or any top up to a million (D96). "Guess mine": the companion's number
/// is drawn at the start and kept sealed; a thermometer says how warm each guess is; par is what halving needs.
/// "I'll guess yours": the companion guesses like a person (`Games.HigherLower.Guesser`), thinks a moment between
/// guesses, and notices an answer that contradicts an earlier one. The start board offers both ways and the range (the
/// last ones played picked, Return plays again), and either way can be swapped for the other during a game and on its
/// end card. Two people can play it too: each hides a number for the other in turn (`HigherLowerDuel`).
enum HigherLowerEngine: GameEngine {
    enum Mode: String, Codable { case mine, yours }

    struct State: Codable, Equatable {
        var mode: Mode?
        /// The way picked on the start board: the last one played until another card is picked.
        var chosen: Mode?
        var level = GameLevel.fair
        /// The numbers played with.
        var low = 1
        var high = Games.HigherLower.defaultTop
        /// "Other…" is picked on the start board: the field for a top of one's own shows.
        var custom = false
        var mine: Games.HigherLower.GuessMine?
        var yours: Games.HigherLower.GuessYours?
        /// The companion is thinking before its next "Is it…?".
        var thinking = false
        var over = false
        var outcome: GameOutcome?
        var duo: TwoPlayers.Duo
        /// Two people's rounds (`HigherLowerDuel`).
        var duel: HigherLowerDuel?

        var range: ClosedRange<Int> { low...high }
    }

    enum Action: Equatable {
        case mode(Mode), start, switchMode, guess(Int), answer(Games.HigherLower.GuessYours.Answer), next, again
        case top(String), otherTop, ready, duo(TwoPlayers.Setup)
    }

    static func start(level: GameLevel, options o: GameOptions, random: inout Games.Random) -> State {
        let r = PlaytimeRecords.load()
        // A range the person named ("up to 1000") wins over the last one played.
        let range = Games.HigherLower.range(o.max == nil ? 1 : o.min, o.max ?? r.higherLowerTop)
        var s = State(chosen: o.mode.flatMap(Mode.init(rawValue:)) ?? r.higherLowerMode.flatMap(Mode.init(rawValue:)) ?? .mine, level: level,
                      low: range.lowerBound, high: range.upperBound, duo: TwoPlayers.start(o))
        s.custom = !Games.HigherLower.tops.contains(s.high) || s.low != 1
        // "You guess my number up to 500": straight into the game.
        if o.mode != nil, !s.duo.on { _ = begin(s.chosen ?? .mine, &s, &random) }
        return s
    }

    static func opening(_ s: State) -> [Games.Event] {
        s.mine != nil ? Games.HigherLower.GuessMine.opening : s.yours != nil ? [.think(ms: 900)] : []
    }

    static func play(_ action: Action, on s: inout State, random: inout Games.Random) throws -> [Games.Event] {
        if s.duo.on || action == .duo(.opponent(two: true)) { return try HigherLowerDuel.play(action, on: &s, random: &random) }
        switch action {
        case .mode(let mode):
            guard s.mode == nil else { throw Games.Refusal("not_now") }
            s.chosen = mode
            return []
        case .top(let value):
            guard s.mode == nil else { throw Games.Refusal("not_now") }
            choose(top: value, &s)
            return []
        case .otherTop:
            throw Games.Refusal("bad_top")
        case .start:
            guard s.mode == nil else { throw Games.Refusal("not_now") }
            return begin(s.chosen ?? .mine, &s, &random)
        case .switchMode:
            // The game on the board is left unscored: the other way starts fresh, on the same numbers.
            guard let mode = s.mode, !s.thinking else { throw Games.Refusal("not_now") }
            s = State(level: s.level, low: s.low, high: s.high, custom: s.custom, duo: s.duo)
            return begin(mode == .mine ? .yours : .mine, &s, &random)
        case .guess(let n):
            guard var game = s.mine, !s.over else { throw Games.Refusal("not_now") }
            let events = try game.guess(n)
            s.mine = game
            if game.found {
                s.over = true
                s.outcome = game.guesses.count <= game.par ? .won : .lost
                // Bests count only on the classic 1 to 100, so they compare.
                let classic = s.range == 1...Games.HigherLower.defaultTop
                PlaytimeRecords.finish(HigherLowerScreen.id, s.outcome!, you: game.guesses.count, companion: game.par,
                                       best: classic ? game.guesses.count : nil, lower: true)
            }
            return events
        case .answer(let a):
            guard var game = s.yours, !s.over, !s.thinking else { throw Games.Refusal("not_now") }
            let events = try game.answer(a, using: &random)
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
            s = State(chosen: mode, level: s.level, low: s.low, high: s.high, custom: s.custom, duo: s.duo)
            return mode.map { begin($0, &s, &random) } ?? [.turn(.you)]
        case .ready, .duo:
            throw Games.Refusal("not_now")
        }
    }

    /// A top from the start board: one of the four, "other" to type one, or a number typed.
    static func choose(top value: String, _ s: inout State) {
        if value == "other" {
            s.custom = true
        } else if let top = Int(value) {
            (s.low, s.high) = (1, top)
            s.custom = !Games.HigherLower.tops.contains(top)
        }
    }

    /// The top the person typed, in any digits their keyboard writes (١٠٠٠, １０００) and with any grouping.
    static func typedTop(_ text: String) -> Int? {
        let digits = text.compactMap(\.wholeNumberValue)
        let allowed = Set(" ,.'\u{00A0}\u{202F}٬")
        guard !digits.isEmpty, digits.count <= 7, text.allSatisfy({ $0.wholeNumberValue != nil || allowed.contains($0) }) else { return nil }
        let n = digits.reduce(0) { $0 * 10 + $1 }
        return (2...Games.HigherLower.largest).contains(n) ? n : nil
    }

    static func begin(_ mode: Mode, _ s: inout State, _ random: inout Games.Random) -> [Games.Event] {
        s.mode = mode
        s.chosen = mode
        // Picked first on the next start board.
        PlaytimeRecords.update { [high = s.high] in
            $0.higherLowerMode = mode.rawValue
            $0.higherLowerTop = high
        }
        switch mode {
        case .mine:
            // Its number is drawn now, before any guess.
            s.mine = Games.HigherLower.GuessMine(range: s.range, using: &random)
            return Games.HigherLower.GuessMine.opening
        case .yours:
            s.yours = Games.HigherLower.GuessYours(range: s.range, level: s.level, using: &random)
            s.thinking = true
            return [.think(ms: 700 + random.between(0, 500))]
        }
    }

    static func outcome(of s: State) -> GameOutcome? { s.outcome }
}

enum HigherLowerScreen: GameScreen {
    typealias Engine = HigherLowerEngine
    static let id = "higher_lower"

    static func action(for move: Move, in s: HigherLowerEngine.State) -> HigherLowerEngine.Action? {
        if let setup = TwoPlayers.setup(move) { return .duo(setup) }
        return switch move {
        case .choice("mode", let m): HigherLowerEngine.Mode(rawValue: m).map { .mode($0) }
        case .choice("top", let t): .top(t)
        case .text("top", let t): HigherLowerEngine.typedTop(t).map { .top(String($0)) } ?? .otherTop
        case .button("start"): .start
        case .button("switch"): .switchMode
        case .button("ready"): .ready
        case .number(let n): .guess(n)
        case .answer(let i): [.higher, .lower, .yes][safe: i].map { .answer($0) }
        case .next, .button("next_round"): .next
        case .button("again"): .again
        default: nil
        }
    }

    /// "Numbers from 1 to 1,000".
    static func numbers(_ s: HigherLowerEngine.State) -> String { L("Numbers from {low} to {high}", ["low": s.low, "high": s.high]) }

    /// The range's choice: up to 10, 100, 1,000 or a million, or one's own typed in a field.
    static func tops(_ s: HigherLowerEngine.State) -> [BoardPart] {
        var parts: [BoardPart] = [.choice(name: "top", label: L("Up to"), style: .segmented,
                                          options: Games.HigherLower.tops.map { ChoiceOption(String($0), Format.integer($0)) }
                                              + [ChoiceOption("other", L("Other…"))],
                                          selected: s.custom ? "other" : String(s.high))]
        if s.custom {
            parts.append(.play(.entry(name: "top", label: L("Up to which number? 2 to {max}", ["max": Games.HigherLower.largest]),
                                      placeholder: Format.integer(s.high), button: L("Set"), max: 12)))
        }
        return parts
    }

    static func board(_ s: HigherLowerEngine.State, events: [Games.Event], options o: GameOptions) -> Board {
        if s.duo.on { return HigherLowerDuel.board(s, events: events, options: o) }
        var parts: [BoardPart] = []
        var cue = EventCues.cue(events)
        var after: Int?
        if s.mode == nil {
            parts = [.prompt(L("Pick a way to play"), eyebrow: numbers(s)),
                     .choice(name: "mode", style: .cards, options: [
                         ChoiceOption("mine", L("Guess mine"), detail: L("{name} hides one", ["name": o.companion]), symbol: "questionmark.square.fill"),
                         ChoiceOption("yours", L("I'll guess yours"), detail: L("Think of one"), symbol: "brain.head.profile"),
                     ], selected: (s.chosen ?? .mine).rawValue)]
            parts += tops(s)
            parts.append(.button(GameButton(L("Start"), move: "start", style: .primary, symbol: "play.fill")))
            parts.append(TwoPlayers.opponent(two: false, companion: o.companion))
            cue = events.contains(.opened) ? Cue(move: "ready", line: "hello", look: "panel") : nil
        } else if let game = s.mine {
            let n = game.guesses.count
            let last = game.guesses.last
            let text: String = if game.found { L("Yes! It was {n}.", ["n": game.shown ?? 0]) }
                else if let last { last < game.low ? L("Higher than {n}!", ["n": last]) : L("Lower than {n}!", ["n": last]) }
                else { L("I'm hiding a number from {low} to {high}. Guess it!", ["low": s.low, "high": s.high]) }
            let history = game.guesses.map { g -> (Int, String) in (g, g == game.shown ? "right" : g < game.low ? "higher" : "lower") }
            parts = [.prompt(text, eyebrow: L("Guess {n} · par {par}", ["n": n + (game.found ? 0 : 1), "par": game.par]))]
            if last != nil, !game.found {
                parts.append(.play(.meter(game.warmth, label: warmth(game.warmth), low: L("Cold"), high: L("Hot"))))
            }
            parts.append(.play(.number(min: s.low, max: s.high, label: L("Between {low} and {high}", ["low": game.low, "high": game.high]),
                                       history: history, locked: game.found)))
            // Far off it shivers in frost; close, it fans itself.
            if last != nil, !game.found {
                cue = Cue(move: game.warmth > 0.9 ? "sweat" : game.warmth < 0.6 ? "wince" : nil, effect: game.warmth > 0.9 ? "flame" : game.warmth < 0.6 ? "frost" : nil,
                          sound: "tick", look: "panel")
            }
            if events.contains(where: { if case .sealed = $0 { true } else { false } }) { cue = Cue(move: "tease", prop: "sealed_card", line: "hello") }
        } else if let game = s.yours {
            let range = L("Between {low} and {high}", ["low": game.low, "high": game.high])
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
        if let note = refusal(events, low: s.low, high: s.high) { parts.append(note) }
        if let mode = s.mode, !s.over, !s.thinking { parts.append(.button(switchButton(from: mode, o))) }
        if let outcome = s.outcome {
            let guesses = s.mine?.guesses.count ?? s.yours?.asked ?? 0
            let par = s.mine?.par ?? Games.HigherLower.par(s.high - s.low + 1)
            parts.append(ScreenKit.result(outcome, figure: Format.integer(guesses),
                                          line: s.mode == .yours ? L(one: "{name} found it in {count} question.", other: "{name} found it in {count} questions.", count: guesses, ["name": o.companion])
                                              : outcome == .won ? L("Found in {n}, at par or better!", ["n": guesses]) : L("Found in {n}: par is {par}.", ["n": guesses, "par": par]),
                                          facts: [(L("Numbers"), L("{low} to {high}", ["low": s.low, "high": s.high]))],
                                          companion: o.companion,
                                          actions: [ScreenKit.playAgain] + (s.mode.map { [switchButton(from: $0, o)] } ?? [])))
        }
        return Board(parts, companion: cue, over: s.over, afterMs: after)
    }

    /// A refused move in this game's words: a guess outside the range names the range; a top that isn't one says what is.
    static func refusal(_ events: [Games.Event], low: Int, high: Int) -> BoardPart? {
        if events.contains(.refused("out_of_range")) {
            return .note(L("Pick a number from {low} to {high}.", ["low": low, "high": high]), tone: .warn)
        }
        if events.contains(.refused("bad_top")) {
            return .note(L("Type a number from 2 to {max}.", ["max": Games.HigherLower.largest]), tone: .warn)
        }
        return ScreenKit.refusal(events)
    }

    /// The other way round, named by who guesses next: during a game (plain) and on its end card.
    static func switchButton(from mode: HigherLowerEngine.Mode, _ o: GameOptions) -> GameButton {
        GameButton(mode == .mine ? L("Switch: {name} guesses", ["name": o.companion]) : L("Switch: you guess"), move: "switch",
                   style: .plain, symbol: "arrow.left.arrow.right", key: "s")
    }

    static func warmth(_ w: Double) -> String {
        w > 0.95 ? L("Burning hot!") : w > 0.85 ? L("Warm") : w > 0.6 ? L("Cool") : L("Freezing")
    }
}

extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}
