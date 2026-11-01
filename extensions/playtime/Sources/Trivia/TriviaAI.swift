import Foundation
import SidefolkExtensionKit

/// Trivia questions made by the person's AI (Sidefolk D95), Playtime's side. Playtime never calls a model: it asks
/// Sidefolk (`sidefolk/trivia.request`: a topic, how many, the level, the language), and Sidefolk makes one call with
/// its own fixed words, checks the answer and sends the questions back as data (`sidefolk/trivia.pack`), or why there
/// are none. Sidefolk only takes the request while the person's setting is on and an AI is set up, which it says by
/// passing `ai_trivia` (the AI's name) with the game. The questions are kept with the round, so a game left open
/// survives Playtime stopping; nothing else is kept.
enum TriviaAI {
    /// How Playtime sends the request: `ext.send` in the program, a recorder in tests.
    nonisolated(unsafe) static var send: (_ method: String, _ params: [String: Any]) -> Void = { _, _ in }
    /// What came back, by request id, until the round takes it.
    nonisolated(unsafe) private static var arrived: [String: Reply] = [:]

    enum Reply: Equatable {
        case pack(topic: String, madeBy: String, questions: [TriviaQuestion])
        /// Sidefolk's short reason: off, busy, limit, unusable, failed, denied.
        case failed(String)
    }

    /// Asks for a pack; the id comes back with the answer.
    static func ask(topic: String, count: Int, level: GameLevel, language: String) -> String {
        let id = UUID().uuidString
        send("sidefolk/trivia.request", ["request": id, "topic": String(topic.prefix(60)), "count": count, "level": level.rawValue,
                                         "language": Localized.normalized(language)])
        return id
    }

    /// The answer, once: nil while it hasn't come.
    static func take(_ id: String) -> Reply? { arrived.removeValue(forKey: id) }

    /// Sidefolk's `sidefolk/trivia.pack`. Its checks already ran; these keep a malformed one from reaching a board.
    static func receive(_ args: Arguments) {
        guard let id = args.string("request"), UUID(uuidString: id) != nil else { return }
        guard args.bool("ok") == true, let topic = args.string("topic"), let made = args.string("made_by") else {
            arrived[id] = .failed(args.string("reason") ?? "failed")
            return
        }
        let raw = args.values["questions"] as? [[String: Any]] ?? []
        let questions = raw.prefix(20).compactMap { question($0, topic: topic) }
        arrived[id] = questions.count >= 5 ? .pack(topic: String(topic.prefix(40)), madeBy: String(made.prefix(40)), questions: questions)
            : .failed("unusable")
    }

    /// One question as a round asks it: an id from its text (so "asked lately" works for these too), the right answer
    /// first as the bank keeps it, the AI's difficulty, its fact.
    static func question(_ q: [String: Any], topic: String) -> TriviaQuestion? {
        let a = Arguments(q)
        guard let text = a.string("question"), text.count <= 200, let answer = a.int("answer"), (0..<4).contains(answer) else { return nil }
        let choices = a.strings("choices").map { String($0.prefix(80)) }
        guard choices.count == 4 else { return nil }
        let ordered = [choices[answer]] + choices.enumerated().filter { $0.offset != answer }.map(\.element)
        return TriviaQuestion(id: "ai-" + String(Games.stableHash(topic.lowercased() + "/" + text), radix: 36), category: category(topic),
                              difficulty: min(max(a.int("difficulty") ?? 2, 1), 3), text: text, choices: ordered, answer: 0,
                              fact: String((a.string("fact") ?? "").prefix(220)))
    }

    /// A pack's questions belong to their own topic, so the companion has a steady strength in it like any other.
    static func category(_ topic: String) -> String { "ai:" + topic.lowercased() }

    /// What to tell the person when no pack came, in their words.
    static func words(_ reason: String, provider: String) -> String {
        switch reason {
        case "limit": L("That's enough new questions for today. Here are mine.")
        case "busy": L("Questions are already being made. Try again in a moment.")
        case "unusable": L("{name} wrote questions I couldn't use. Here are mine.", ["name": provider])
        case "off", "denied": L("Making questions with AI is off. Here are mine.")
        case "slow": L("{name} is taking too long. Here are mine.", ["name": provider])
        default: L("{name} couldn't make questions just now. Here are mine.", ["name": provider])
        }
    }
}
