import Foundation
import SidefolkExtensionKit

/// Trivia's boards in the Play panel (D75): the set-up, each question with the companion's sealed pick, the answer
/// with both picks shown and a fact, and the end card. Every word comes from Playtime's tables in the person's
/// language; the companion's own lines are Sidefolk's, named by key.
enum TriviaScreen: GameScreen {
    typealias Engine = TriviaEngine
    static let id = "trivia"

    static func action(for move: Move, in state: TriviaEngine.State) -> TriviaEngine.Action? {
        switch move {
        case .choice("topic", let t): .topic(t)
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
                          "tech": "cpu", "sports": "figure.run", "mediterranean": "sun.max.fill"]

    static func board(_ s: TriviaEngine.State, events: [GameEvent], words w: Localized, options: GameOptions) -> Board {
        switch s.phase {
        case .setup: setup(s, events: events, w, options)
        case .question, .answered: question(s, events: events, w, options)
        case .done: done(s, events: events, w, options)
        }
    }

    static func topic(_ id: String, _ w: Localized) -> String {
        let word = w["topic.\(id)"]
        return word == "topic.\(id)" ? id.capitalized : word
    }

    private static func setup(_ s: TriviaEngine.State, events: [GameEvent], _ w: Localized, _ o: GameOptions) -> Board {
        let topics = (["mix"] + TriviaLibrary.categories(language: s.language)).map { ChoiceOption($0, topic($0, w), symbol: symbols[$0] ?? "questionmark") }
        return Board([
            .prompt(w["setup.title"], eyebrow: w("setup.eyebrow", o.companion)),
            .choice(name: "topic", options: topics, selected: s.topic),
            .choice(name: "length", label: w["setup.length"], style: .segmented,
                    options: [ChoiceOption("5", w.number(5)), ChoiceOption("10", w.number(10)), ChoiceOption("0", w["length.endless"])],
                    selected: String(s.length)),
            .choice(name: "pace", label: w["setup.pace"], style: .segmented,
                    options: [ChoiceOption("relaxed", w["pace.relaxed"]), ChoiceOption("quick", w("pace.quick", w.number(Int(TriviaEngine.quickSeconds))))],
                    selected: s.quick ? "quick" : "relaxed"),
            .button(GameButton(w["start"], move: "start", style: .primary, symbol: "play.fill")),
        ], companion: events.contains(.other("opened")) ? Cue(move: "ready", line: "hello", look: "panel") : nil)
    }

    private static func question(_ s: TriviaEngine.State, events: [GameEvent], _ w: Localized, _ o: GameOptions) -> Board {
        guard let q = TriviaEngine.question(s) else { return done(s, events: events, w, o) }
        let answered = s.phase == .answered
        let right = TriviaEngine.rightTile(s)
        let tiles = s.order.enumerated().map { i, choice -> Tile in
            var state = TileState.none
            if answered {
                state = i == right ? .right : i == s.picked ? .wrong : .faded
            } else if s.faded.contains(i) {
                state = .faded
            }
            return Tile(q.choices[choice], state: state, companion: answered && i == s.companionPick)
        }
        let progress = s.length > 0 ? w("progress", w.number(s.index + 1), w.number(s.length)) : w("progress.endless", w.number(s.index + 1))
        var parts: [BoardPart] = [
            .score(you: s.you, companion: s.companion, streak: s.streak, companionPicked: !answered),
            .prompt(q.text, eyebrow: progress, chip: topic(q.category, w)),
        ]
        if s.quick, !answered { parts.append(.timer(id: "q\(s.index)-\(q.id)", seconds: TriviaEngine.quickSeconds)) }
        parts.append(.answers(tiles, locked: answered))
        if answered {
            parts.append(.note(q.fact, title: w["fact"]))
            let last = s.length > 0 && s.index + 1 >= s.round.count
            parts.append(.button(GameButton(last ? w["results"] : w["next"], move: "next", style: .primary, symbol: last ? "flag.checkered" : "arrow.right")))
        } else if !s.lifelineUsed {
            parts.append(.button(GameButton(w("hint", o.companion), move: "hint", style: .plain, symbol: "lightbulb", key: "h")))
        }
        if s.length == 0 { parts.append(.button(GameButton(w["finish"], move: "finish", style: .plain, symbol: "flag.checkered"))) }
        return Board(parts, companion: cue(events))
    }

    private static func done(_ s: TriviaEngine.State, events: [GameEvent], _ w: Localized, _ o: GameOptions) -> Board {
        let records = TriviaRecords.load()
        let outcome = TriviaEngine.outcome(of: s) ?? .draw
        let line = switch outcome {
        case .won: w("won", o.companion)
        case .lost: w("lost", o.companion)
        case .draw: w["draw"]
        }
        let asked = s.results.count
        let figure = s.length > 0 ? w("score", w.number(s.you), w.number(s.length)) : w.number(s.you)
        return Board([
            .score(you: s.you, companion: s.companion, streak: s.streak),
            .result(figure: asked == 0 ? "–" : figure, line: line, ribbon: s.record ? w["record"] : nil, tone: outcome == .won ? .good : .neutral,
                    facts: [(o.companion, w.number(s.companion)), (w["fact.streak"], w.number(max(s.bestStreak, 0))),
                            (w["fact.best"], w.number(records.bestStreak)), (w["fact.topic"], topic(s.topic, w))],
                    actions: [GameButton(w["again"], move: "again", style: .primary, symbol: "arrow.clockwise"),
                              GameButton(w["topics"], move: "topics")]),
        ], companion: cue(events), over: true)
    }

    /// The companion's reaction to what just happened, from Sidefolk's fixed lists.
    static func cue(_ events: [GameEvent]) -> Cue? {
        if events.contains(.other("question")) { return Cue(move: "think", sound: "tick", look: "panel") }
        for event in events {
            switch event {
            case .ended(.won): return Cue(move: "bow", effect: "confetti", line: "you_win", sound: "fanfare", look: "you")
            case .ended(.lost): return Cue(move: "celebrate", line: "i_win", sound: "trombone")
            case .ended(.draw): return Cue(move: "shrug", line: "draw", sound: "boop")
            case .streak(let n): return Cue(move: "cheer", effect: n >= 10 ? "confetti" : "sparkles", line: "streak", sound: "ding")
            case .hint(let trusty):
                return trusty ? Cue(move: "tease", line: "hint_intro", sound: "whoosh", look: "panel")
                    : Cue(move: "sweat", effect: "sweat", line: "hint_intro", sound: "whoosh", look: "panel")
            default: continue
            }
        }
        let you = events.contains(.personRight), it = events.contains(.companionRight)
        guard events.contains(.personRight) || events.contains(.personWrong) else { return nil }
        switch (you, it) {
        case (true, false): return Cue(move: "sulk", sound: "ding", look: "you")
        case (true, true): return Cue(move: "nod", sound: "ding", look: "panel")
        case (false, true): return Cue(move: "tease", line: "tease", sound: "boop", look: "you")
        case (false, false): return Cue(move: "shrug", line: "draw", sound: "boop")
        }
    }
}
