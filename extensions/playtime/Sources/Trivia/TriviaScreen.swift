import Foundation
import SidefolkExtensionKit

/// Trivia's boards in the Play panel (D75): the set-up, each question with the companion's sealed pick, the answer with
/// both picks shown, and the end card. Every word is the person's language (`L`, strings/); the questions come from that
/// language's pack; the companion's own lines are Sidefolk's, named by key.
enum TriviaScreen: GameScreen {
    typealias Engine = TriviaEngine
    static let id = "trivia"

    static func action(for move: Move, in state: TriviaEngine.State) -> TriviaEngine.Action? {
        if let setup = TwoPlayers.setup(move) { return .duo(setup) }
        return switch move {
        case .choice("topic", let t): .topic(t)
        case .text("topic", let t): .custom(t)
        case .next where state.phase == .making: .next
        case .choice("length", let n): Int(n).map { .length($0) } ?? (n == "endless" ? .length(0) : nil)
        case .choice("pace", let p): .pace(quick: p == "quick")
        case .answer(let i): .answer(i)
        case .timeout: .timeout
        case .button(let b): ["start": .start, "hint": .hint, "next": .next, "finish": .finish, "again": .again, "topics": .topics][b]
        default: nil
        }
    }

    static let symbols = ["mix": "shuffle", "science": "atom", "space": "moon.stars.fill", "geography": "globe.europe.africa.fill",
                          "history": "building.columns.fill", "nature": "leaf.fill", "food": "fork.knife", "arts": "paintpalette.fill",
                          "tech": "cpu", "sports": "figure.run", "mediterranean": "sun.max.fill", TriviaEngine.surprise: "sparkles"]

    static func board(_ s: TriviaEngine.State, events: [Games.Event], options: GameOptions) -> Board {
        if s.duo.on, s.duo.naming != nil { return TwoPlayers.namesBoard(s.duo, companion: options.companion, title: L("Trivia")) }
        return switch s.phase {
        case .setup: setup(s, events: events, options)
        case .making: making(s, options)
        case .question, .answered: question(s, events: events, options)
        case .done: done(s, events: events, options)
        }
    }

    static func topic(_ id: String) -> String {
        switch id {
        case "mix": L("Mix")
        case "science": L("Science")
        case "space": L("Space")
        case "geography": L("Geography")
        case "history": L("History")
        case "nature": L("Nature")
        case "food": L("Food")
        case "arts": L("Arts")
        case "tech": L("Tech")
        case "sports": L("Sports")
        case "mediterranean": L("Tunisia & the Mediterranean")
        case TriviaEngine.surprise: L("Any topic")
        default: id.hasPrefix("ai:") ? String(id.dropFirst(3)).capitalized : id.capitalized
        }
    }

    private static func setup(_ s: TriviaEngine.State, events: [Games.Event], _ o: GameOptions) -> Board {
        // With the person's AI allowed (D95), an "Any topic" card: picked, the bank's topics make room for a field where
        // the person names one; left empty, Start lets the AI pick (the board stays within the panel's height).
        var parts: [BoardPart]
        if let maker = s.aiMaker, s.topic == TriviaEngine.surprise {
            parts = [.prompt(L("Any topic"), eyebrow: L("{name} writes the questions", ["name": maker])),
                     .play(.entry(name: "topic", label: L("Leave it empty and {name} picks one.", ["name": maker]),
                                  placeholder: L("Volcanoes, jazz, Japan…"), button: L("Make questions"), max: 60)),
                     .button(GameButton(L("Back to topics"), move: "topics", style: .plain, symbol: "chevron.backward"))]
        } else {
            let ids = ["mix"] + TriviaLibrary.categories(language: s.language) + (s.aiMaker != nil ? [TriviaEngine.surprise] : [])
            let topics = ids.map { ChoiceOption($0, topic($0), symbol: symbols[$0] ?? "questionmark") }
            parts = [.prompt(L("Pick a topic"), eyebrow: s.duo.on ? L("2 players") : L("A quiz with {name}", ["name": o.companion])),
                     .choice(name: "topic", options: topics, selected: s.topic)]
        }
        if let reason = s.notice { parts.append(.note(TriviaAI.words(reason, provider: s.aiMaker ?? o.companion), tone: .info)) }
        return Board(parts + [
            .choice(name: "length", label: L("Questions"), style: .segmented,
                    options: [ChoiceOption("5", Format.integer(5)), ChoiceOption("10", Format.integer(10)), ChoiceOption("0", L("Endless"))],
                    selected: String(s.length)),
            .choice(name: "pace", label: L("Pace"), style: .segmented,
                    options: [ChoiceOption("relaxed", L("Relaxed")), ChoiceOption("quick", L("Quick, {n} s", ["n": Int(TriviaEngine.quickSeconds)]))],
                    selected: s.quick ? "quick" : "relaxed"),
            .button(GameButton(L("Start"), move: "start", style: .primary, symbol: "play.fill")),
            TwoPlayers.opponent(two: s.duo.on, companion: o.companion),
        ], companion: events.contains(.opened) ? Cue(move: "ready", line: "hello", look: "panel") : nil)
    }

    /// While the AI writes the questions: what it's writing about, a moment's patience, and a way back.
    private static func making(_ s: TriviaEngine.State, _ o: GameOptions) -> Board {
        let maker = s.aiMaker ?? o.companion
        let about = s.asking?.topic ?? ""
        return Board([
            .prompt(about.isEmpty ? L("{name} is picking a topic and writing questions…", ["name": maker])
                        : L("{name} is writing questions about {topic}…", ["name": maker, "topic": about]),
                    eyebrow: L("Fresh questions")),
            .note(L("Made by {name}. They aren't checked, so a fact may be wrong.", ["name": maker]), tone: .info),
            .button(GameButton(L("Back to topics"), move: "topics", style: .plain, symbol: "chevron.backward")),
        ], companion: Cue(move: "think", effect: "question", line: "thinking", look: "panel"), afterMs: TriviaEngine.checkMs)
    }

    private static func question(_ s: TriviaEngine.State, events: [Games.Event], _ o: GameOptions) -> Board {
        guard let q = TriviaEngine.question(s) else { return done(s, events: events, o) }
        let answered = s.phase == .answered
        let right = TriviaEngine.rightTile(s)
        let tiles = s.order.enumerated().map { i, choice -> Tile in
            var state = TileState.none
            if answered {
                state = i == right ? .right : i == s.picked ? .wrong : .faded
            } else if s.faded.contains(i) {
                state = .faded
            }
            return Tile(q.choices[choice], state: state, companion: answered && !s.duo.on && i == s.companionPick)
        }
        var progress = s.length > 0 ? L("{n} of {total}", ["n": s.index + 1, "total": s.length]) : L("Question {n}", ["n": s.index + 1])
        if s.duo.on { progress = TwoPlayers.turn(s.duo, TriviaEngine.player(s)) + " · " + progress }
        let chip = s.made.isEmpty ? topic(q.category) : s.madeTopic ?? topic(q.category)
        var parts: [BoardPart] = [
            s.duo.on ? TwoPlayers.score(s.duo, s.you, s.companion)
                : .score(you: s.you, companion: s.companion, streak: s.streak, companionPicked: !answered),
            .prompt(q.text, eyebrow: progress, chip: chip),
        ]
        if s.quick, !answered { parts.append(.timer(id: "q\(s.index)-\(q.id)", seconds: TriviaEngine.quickSeconds)) }
        parts.append(.answers(tiles, locked: answered))
        if answered {
            // The AI's facts say whose they are: nobody checked them (D95).
            if !q.fact.isEmpty {
                parts.append(.note(q.fact, title: s.made.isEmpty ? L("Did you know?") : L("Did you know? From {name}, not checked", ["name": s.aiMaker ?? ""])))
            }
            let last = s.length > 0 && s.index + 1 >= s.round.count
            parts.append(.button(GameButton(last ? L("See results") : L("Next"), move: "next", style: .primary, symbol: last ? "flag.checkered" : "arrow.right")))
        } else if !s.lifelineUsed, !s.duo.on {
            parts.append(.button(GameButton(L("Ask {name}", ["name": o.companion]), move: "hint", style: .plain, symbol: "lightbulb", key: "h")))
        }
        if s.length == 0 { parts.append(.button(GameButton(L("Finish"), move: "finish", style: .plain, symbol: "flag.checkered"))) }
        return Board(parts, companion: s.duo.on ? TwoPlayers.cue(events) : cue(events))
    }

    private static func done(_ s: TriviaEngine.State, events: [Games.Event], _ o: GameOptions) -> Board {
        if s.duo.on {
            let winner: Games.Side? = s.you == s.companion ? nil : s.you > s.companion ? .you : .companion
            var facts: [(String, String)] = [(L("Topic"), s.madeTopic ?? topic(s.topic))]
            if let tally = TwoPlayers.tally(id, s.duo) { facts.append(tally) }
            return Board([
                TwoPlayers.score(s.duo, s.you, s.companion),
                .result(figure: "\(Format.integer(s.you)) – \(Format.integer(s.companion))",
                        line: winner.map { L("{name} wins!", ["name": s.duo.name($0)]) } ?? L("A draw!"), tone: winner == nil ? .neutral : .info, facts: facts,
                        actions: [GameButton(L("Play again"), move: "again", style: .primary, symbol: "arrow.clockwise"),
                                  GameButton(L("Another topic"), move: "topics")]),
            ], companion: TwoPlayers.cue(events), over: true)
        }
        let records = TriviaRecords.load()
        let outcome = TriviaEngine.outcome(of: s) ?? .draw
        let asked = s.results.count
        let figure = s.length > 0 ? "\(Format.integer(s.you)) / \(Format.integer(s.length))" : Format.integer(s.you)
        return Board([
            .score(you: s.you, companion: s.companion, streak: s.streak),
            .result(figure: asked == 0 ? "–" : figure,
                    line: outcome == .won ? L("You beat {name}!", ["name": o.companion]) : outcome == .lost ? L("{name} wins this one.", ["name": o.companion]) : L("A draw!"),
                    ribbon: s.record ? L("New best!") : nil, tone: outcome == .won ? .good : outcome == .lost ? .bad : .neutral,
                    facts: [(o.companion, Format.integer(s.companion)), (L("Streak this round"), Format.integer(max(s.bestStreak, 0))),
                            (L("Best streak ever"), Format.integer(records.bestStreak)), (L("Topic"), s.madeTopic ?? topic(s.topic))],
                    actions: [GameButton(L("Play again"), move: "again", style: .primary, symbol: "arrow.clockwise"),
                              GameButton(L("Another topic"), move: "topics")]),
        ], companion: cue(events), over: true)
    }

    /// The companion's reaction to an answer (both picks shown): sulk when only the person was right, a nod when both
    /// were, a tease when only it was, a shrug when neither; anything else through the games' one table.
    static func cue(_ events: [Games.Event]) -> Cue? {
        if events.contains(.sealed) { return Cue(move: "think", effect: "question", sound: "tick", look: "panel") }
        let weighty = events.contains { if case .matchOver = $0 { true } else if case .streak = $0 { true } else if case .lifeline = $0 { true } else { false } }
        guard events.contains(.reveal), !weighty else { return EventCues.cue(events.filter { $0 != .opened }) }
        switch (events.contains(.point(.you)), events.contains(.point(.companion))) {
        case (true, false): return Cue(move: "sulk", sound: "ding", look: "you")
        case (true, true): return Cue(move: "nod", sound: "ding", look: "panel")
        case (false, true): return Cue(move: "tease", line: "tease", sound: "boop", look: "you")
        case (false, false): return Cue(move: "shrug", line: "draw", sound: "boop")
        }
    }
}
