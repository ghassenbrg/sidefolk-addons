import Foundation
import SidefolkExtensionKit

/// Balloon Words, a kind hangman: guess the word before the companion's seven balloons are gone. Each language's own
/// everyday words; Chinese guesses the pinyin and shows the characters at the end.
enum BalloonWordsEngine: GameEngine {
    struct State: Codable, Equatable {
        var game: Games.BalloonWords
        var record = false
        /// The companion, or two people setting each other words (`BalloonWordsDuel`, D96).
        var duo: TwoPlayers.Duo
        var duel: BalloonWordsDuel?
    }

    enum Action: Equatable { case letter(String), hint, again, level(GameLevel), word(String), ready, next, duo(TwoPlayers.Setup) }

    static func start(level: GameLevel, options: GameOptions, random: inout Games.Random) -> State {
        let duo = TwoPlayers.start(options)
        return State(game: Games.BalloonWords(language: options.gamesLanguage, level: level, using: &random), duo: duo,
                     duel: duo.on ? BalloonWordsDuel() : nil)
    }

    static func play(_ action: Action, on s: inout State, random: inout Games.Random) throws -> [Games.Event] {
        if s.duo.on || action == .duo(.opponent(two: true)) { return try BalloonWordsDuel.play(action, on: &s, random: &random) }
        let events: [Games.Event]
        switch action {
        case .word, .ready, .next, .duo:
            throw Games.Refusal("not_now")
        case .letter(let l): events = try s.game.guess(l)
        case .hint: events = try s.game.hint().events
        case .again, .level:
            let level: GameLevel = if case .level(let l) = action { l } else { level(of: s) }
            var options = GameOptions()
            options.language = s.game.language.rawValue
            // A different word from the last one.
            var next = start(level: level, options: options, random: &random)
            for _ in 0..<4 where next.game.entry == s.game.entry { next = start(level: level, options: options, random: &random) }
            next.duo = s.duo
            s = next
            return [.turn(.you)]
        }
        if s.game.over {
            let won = s.game.won
            s.record = PlaytimeRecords.finish(BalloonWordsScreen.id, won ? .won : .lost, you: won ? 1 : 0, companion: won ? 0 : 1,
                                              best: won ? s.game.left : nil)
        }
        return events
    }

    /// The level isn't kept by the engine: it's the third of the list the word came from.
    static func level(of s: State) -> GameLevel {
        let all = Games.WordBank.balloon(s.game.language).sorted { ($0.units(s.game.language), $0.word) < ($1.units(s.game.language), $1.word) }
        let i = all.firstIndex(of: s.game.entry) ?? 0
        let third = max(1, all.count / 3)
        return i < third ? .easy : i < 2 * third ? .fair : .hard
    }

    static func outcome(of s: State) -> GameOutcome? { s.game.over ? (s.game.won ? .won : .lost) : nil }
}

enum BalloonWordsScreen: GameScreen {
    typealias Engine = BalloonWordsEngine
    static let id = "balloon_words"

    static func action(for move: Move, in s: BalloonWordsEngine.State) -> BalloonWordsEngine.Action? {
        if let setup = TwoPlayers.setup(move) { return .duo(setup) }
        return switch move {
        case .letter(let l): .letter(l)
        case .text("word", let w): .word(w)
        case .button("ready"): .ready
        case .button("next_round"): .next
        case .button("hint"): .hint
        case .button("again"): .again
        case .choice("level", let l): GameLevel(rawValue: l).map { .level($0) }
        default: nil
        }
    }

    static func category(_ id: String) -> String {
        switch id {
        case "animals": L("Animals")
        case "food": L("Things to eat")
        case "home": L("At home")
        case "nature": L("Outdoors")
        case "clothes": L("Clothes")
        case "transport": L("Getting around")
        case "sports": L("Games and sports")
        case "music": L("Music")
        case "": L("A word from a friend")
        default: id
        }
    }

    /// The word's places: each letter once guessed (or at the end), hidden before.
    static func tiles(_ g: Games.BalloonWords) -> [LetterTile] {
        zip(g.units, g.slots).map { unit, shown in
            LetterTile(unit.key.isEmpty ? unit.shown : shown ?? "", mark: unit.key.isEmpty || shown != nil ? (g.over && !g.guessed.contains(unit.key) && !unit.key.isEmpty ? "absent" : "none") : "hidden",
                       group: unit.group)
        }
    }

    /// The language's keyboard, each key marked hit or miss once guessed.
    static func keyboard(_ g: Games.BalloonWords) -> BoardPart? {
        Keyboards.part(g.language, for: .balloon, mode: "letter", locked: g.over, mark: { k in
            guard g.guessed.contains(k) else { return "none" }
            return g.units.contains { $0.key == k } ? "hit" : "miss"
        })
    }

    static func board(_ s: BalloonWordsEngine.State, events: [Games.Event], options o: GameOptions) -> Board {
        if s.duo.on { return BalloonWordsDuel.board(s, events: events, options: o) }
        let g = s.game
        let tiles = tiles(g)
        let text: String = if g.won { L("You saved the balloons!") }
            else if g.lost { L("The word was {word}.", ["word": g.entry.word]) }
            else { L("Guess the word, a letter at a time.") }
        var parts: [BoardPart] = [
            .play(.lives(total: Games.BalloonWords.balloons, left: g.left, symbol: "balloon")),
            .prompt(text, eyebrow: g.over && g.language == .zh ? g.entry.word : nil, chip: category(g.entry.category)),
            .play(.letters(rows: [tiles], length: tiles.count, style: "slots", script: Keyboards.script(g.language))),
        ]
        if let keys = keyboard(g) { parts.append(keys) }
        if let note = ScreenKit.refusal(events) { parts.append(note) }
        if let outcome = BalloonWordsEngine.outcome(of: s) {
            parts.append(ScreenKit.result(outcome, figure: g.entry.word, line: outcome == .won ? L(one: "{count} balloon left.", other: "{count} balloons left.", count: g.left) : nil,
                                          companion: o.companion))
            parts.append(ScreenKit.levels(BalloonWordsEngine.level(of: s)))
        } else if !g.hintUsed {
            parts.append(.button(GameButton(L("Show a letter"), move: "hint", style: .plain, symbol: "lightbulb")))
        }
        if g.guessed.isEmpty { parts.append(TwoPlayers.opponent(two: false, companion: o.companion)) }
        var cue = EventCues.cue(events)
        // The companion holds what's left of its balloons; it lets them go when you win.
        let held = g.won ? "none" : "balloons(\(max(g.left, 1)))"
        if events.contains(.opened) || events == [.turn(.you)] { cue = Cue(move: "ready", prop: held, line: events.contains(.opened) ? "hello" : nil) }
        else if cue != nil { cue?.prop = g.lost ? "none" : held }
        if g.won, events.contains(where: { if case .roundOver = $0 { true } else { false } }) { cue?.move = "hop" }
        if g.lost, events.contains(where: { if case .roundOver = $0 { true } else { false } }) { cue?.move = "giggle" }
        return Board(parts, companion: cue, over: g.over)
    }
}
