import Foundation
import SidefolkExtensionKit

/// Guess My Animal: the person thinks of an animal, the companion asks yes-or-no questions down its tree and guesses;
/// when it's wrong it asks what it was and a question to tell them apart, and remembers that in Playtime's folder, in
/// the language it was taught.
enum GuessAnimalEngine: GameEngine {
    struct State: Codable, Equatable {
        var game: Games.GuessAnimal
        var language: String
        /// Teaching, step by step: the animal's name, then the question, then its answer for the new animal.
        var animal: String?
        var question: String?
        var thinking = false
        var outcome: GameOutcome?
        var learned = false
    }

    enum Action: Equatable {
        case answer(Games.GuessAnimal.Answer), verdict(Bool), animal(String), question(String), newAnswer(Bool), next, again
    }

    static func start(level: GameLevel, options: GameOptions, random: inout Games.Random) -> State {
        State(game: Games.GuessAnimal(language: options.gamesLanguage, memory: PlaytimeRecords.animals()), language: options.language)
    }

    static func play(_ action: Action, on s: inout State, random: inout Games.Random) throws -> [Games.Event] {
        guard !s.thinking || action == .next else { throw Games.Refusal("not_now") }
        switch action {
        case .answer(let a): return try s.game.answer(a)
        case .verdict(let right):
            let events = try s.game.verdict(right: right)
            if events.contains(where: { if case .think = $0 { true } else { false } }) { s.thinking = true }
            if right { finish(&s, .lost) }
            return events
        case .animal(let name):
            guard s.game.phase == .teaching, s.animal == nil else { throw Games.Refusal("not_now") }
            let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { throw Games.Refusal("empty") }
            guard name.count <= Games.GuessAnimal.Memory.longestName else { throw Games.Refusal("too_long") }
            guard name.lowercased() != s.game.guess?.name.lowercased() else { throw Games.Refusal("same_animal") }
            s.animal = name
            return []
        case .question(let q):
            guard s.animal != nil, s.question == nil else { throw Games.Refusal("not_now") }
            let q = q.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !q.isEmpty else { throw Games.Refusal("empty") }
            guard q.count <= Games.GuessAnimal.Memory.longestQuestion else { throw Games.Refusal("too_long") }
            s.question = q
            return []
        case .newAnswer(let yes):
            guard let animal = s.animal, let question = s.question else { throw Games.Refusal("not_now") }
            var memory = PlaytimeRecords.animals()
            let events = try s.game.teach(animal: animal, question: question, answerForNew: yes, memory: &memory)
            PlaytimeRecords.saveAnimals(memory)
            s.learned = true
            finish(&s, .won)
            return events
        case .next:
            s.thinking = false
            return [.turn(.you)]
        case .again:
            s = start(level: .fair, options: { var o = GameOptions(); o.language = s.language; return o }(), random: &random)
            return [.turn(.you)]
        }
    }

    private static func finish(_ s: inout State, _ outcome: GameOutcome) {
        s.outcome = outcome
        PlaytimeRecords.finish(GuessAnimalScreen.id, outcome, you: outcome == .won ? 1 : 0, companion: outcome == .lost ? 1 : 0)
    }

    static func outcome(of s: State) -> GameOutcome? { s.outcome }
}

enum GuessAnimalScreen: GameScreen {
    typealias Engine = GuessAnimalEngine
    static let id = "guess_animal"

    static func action(for move: Move, in s: GuessAnimalEngine.State) -> GuessAnimalEngine.Action? {
        switch move {
        case .answer(let i) where s.game.phase == .asking: [Games.GuessAnimal.Answer.yes, .no, .unsure][safe: i].map { .answer($0) }
        case .answer(let i) where s.game.phase == .guessing: i < 2 ? .verdict(i == 0) : nil
        case .answer(let i) where s.question != nil: i < 2 ? .newAnswer(i == 0) : nil
        case .text("animal", let v): .animal(v)
        case .text("question", let v): .question(v)
        case .next: .next
        case .button("again"): .again
        default: nil
        }
    }

    static func board(_ s: GuessAnimalEngine.State, events: [Games.Event], options o: GameOptions) -> Board {
        let g = s.game
        var parts: [BoardPart] = []
        var cue = EventCues.cue(events)
        var after: Int?
        let yesNo = [Tile(L("Yes"), key: "y"), Tile(L("No"), key: "n")]
        if s.thinking {
            parts.append(.prompt(L("Hmm… let me think again."), eyebrow: L("Question {n}", ["n": g.asked])))
            after = 900
            cue = Cue(move: "think", prop: "magnifier", line: "thinking", look: "panel")
        } else if let question = g.question {
            parts.append(.prompt(question, eyebrow: L("Question {n} of {total}", ["n": g.asked + 1, "total": Games.GuessAnimal.maxQuestions])))
            parts.append(.answers(yesNo + [Tile(L("Not sure"), key: "?")], layout: .row))
            if events.contains(.opened) { cue = Cue(move: "think", prop: "magnifier", line: "hello", look: "panel") }
            else if cue == nil || events.isEmpty { cue = Cue(move: "think", prop: "magnifier", look: "panel") }
        } else if g.phase == .guessing, let guess = g.guess {
            parts.append(.prompt(L("Is it… {animal}?", ["animal": [guess.emoji, guess.name].filter { !$0.isEmpty }.joined(separator: " ")]),
                                 eyebrow: L("My guess")))
            parts.append(.answers([Tile(L("Yes, that's it!"), key: "y"), Tile(L("No"), key: "n")], layout: .row))
            cue = Cue(move: "gasp", effect: "exclaim", prop: "magnifier", look: "you")
        } else if g.phase == .teaching, let wrong = g.guess?.name {
            if s.animal == nil {
                parts.append(.prompt(L("You win! What was it?")))
                parts.append(.play(.entry(name: "animal", label: L("Your animal"), placeholder: L("Your animal"), button: L("Tell"),
                                          max: Games.GuessAnimal.Memory.longestName)))
            } else if s.question == nil {
                parts.append(.prompt(L("A yes-or-no question that tells {new} from {old}?", ["new": s.animal!, "old": wrong])))
                parts.append(.play(.entry(name: "question", label: L("Your question"), placeholder: L("Does it…?"), button: L("Teach"),
                                          max: Games.GuessAnimal.Memory.longestQuestion)))
            } else {
                parts.append(.prompt(L("And for {new}, the answer is…", ["new": s.animal!]), eyebrow: s.question))
                parts.append(.answers(yesNo, layout: .row))
            }
            if s.animal == nil, events.contains(where: { if case .roundOver = $0 { true } else { false } }) {
                cue = Cue(move: "sulk", prop: "none", line: "you_win", look: "you")
            }
        }
        if let note = ScreenKit.refusal(events) { parts.append(note) }
        if let outcome = s.outcome {
            let line = outcome == .won ? L("Thank you! I'll remember {animal}.", ["animal": s.animal ?? ""]) : L("I got it!")
            parts.append(ScreenKit.result(outcome, figure: Format.integer(g.asked), line: line,
                                          facts: [(L("Questions"), Format.integer(g.asked))], companion: o.companion))
        }
        return Board(parts, companion: cue, over: s.outcome != nil, afterMs: after)
    }
}
