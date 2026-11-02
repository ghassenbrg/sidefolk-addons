import Foundation
import SidefolkExtensionKit

/// Trivia questions made by the person's AI (D95, now through D100's AI help): the program asks in its own fixed words (`TriviaPrompt`), through `AI.ask`, and
/// checks what comes back as anything from outside (`TriviaPackCheck`). Sidefolk only takes the request while the person's switch is on and an AI is set up,
/// which it says by naming the AI with every request. The questions are kept with the round, so a game left open survives Playtime stopping; nothing else is kept.
enum TriviaAI {
    /// How the program asks: `AI.ask` in the program, a recorder in tests. The answer comes to `answered` or `refused`.
    nonisolated(unsafe) static var send: (_ id: String, _ prompt: String, _ label: String) -> Void = { _, _, _ in }
    /// What came back, by request id, until the round takes it.
    nonisolated(unsafe) private static var arrived: [String: Reply] = [:]
    /// What each request asked for, to check its answer against.
    nonisolated(unsafe) private static var asked: [String: (topic: String, count: Int)] = [:]

    enum Reply: Equatable {
        case pack(topic: String, madeBy: String, questions: [TriviaQuestion])
        /// A short reason: off, busy, limit, unusable, failed, denied.
        case failed(String)
    }

    /// Asks for a pack; the id comes back with the answer.
    static func ask(topic: String, count: Int, level: GameLevel, language: String) -> String {
        let id = UUID().uuidString
        let topic = String(topic.prefix(TriviaPrompt.longestTopic)), count = min(max(count, 10), 20)
        asked[id] = (topic, count)
        send(id, TriviaPrompt.request(topic: topic, count: count, level: level.rawValue, language: Localized.normalized(language)), topic.isEmpty ? "Trivia questions" : "Trivia about \(topic)")
        return id
    }

    /// The answer, once: nil while it hasn't come.
    static func take(_ id: String) -> Reply? { arrived.removeValue(forKey: id) }

    /// The AI's words, checked as anything from outside.
    static func answered(_ id: String, text: String, madeBy: String) {
        guard let request = asked.removeValue(forKey: id) else { return }
        switch TriviaPackCheck.parse(text, count: request.count, topic: request.topic) {
        case .failure:
            arrived[id] = .failed("unusable")
        case .success(let pack):
            let questions = pack.questions.compactMap { question($0, topic: pack.topic) }
            arrived[id] = questions.count >= 5 ? .pack(topic: String(pack.topic.prefix(40)), madeBy: String(madeBy.prefix(40)), questions: questions) : .failed("unusable")
        }
    }

    static func refused(_ id: String, reason: String) {
        asked[id] = nil
        arrived[id] = .failed(reason)
    }

    /// One question as a round asks it: an id from its text (so "asked lately" works for these too), the right answer first as the bank keeps it, the AI's
    /// difficulty, its fact.
    static func question(_ q: TriviaPackCheck.Question, topic: String) -> TriviaQuestion? {
        let ordered = [q.choices[q.answer]] + q.choices.enumerated().filter { $0.offset != q.answer }.map(\.element)
        return TriviaQuestion(id: "ai-" + String(Games.stableHash(topic.lowercased() + "/" + q.text), radix: 36), category: category(topic), difficulty: q.difficulty, text: q.text,
                              choices: ordered, answer: 0, fact: q.fact ?? "")
    }

    /// A pack's questions belong to their own topic, so the companion has a steady strength in it like any other.
    static func category(_ topic: String) -> String { "ai:" + topic.lowercased() }

    /// What to tell the person when no pack came, in their words.
    static func words(_ reason: String, provider: String) -> String {
        switch reason {
        case "limit": L("That's enough new questions for today. Here are mine.")
        case "busy": L("Questions are already being made. Try again in a moment.")
        case "unusable": sentence(L("{name} wrote questions I couldn't use. Here are mine.", ["name": provider]))
        case "off", "denied": L("Making questions with AI is off. Here are mine.")
        case "slow": sentence(L("{name} is taking too long. Here are mine.", ["name": provider]))
        default: sentence(L("{name} couldn't make questions just now. Here are mine.", ["name": provider]))
        }
    }

    /// A line that may begin with the AI's name: Sidefolk names a custom one "your AI" (lower case, for the middle of a
    /// sentence), so the line's first letter is raised, past the direction marks `L` puts around a name.
    static func sentence(_ line: String) -> String {
        guard let i = line.firstIndex(where: \.isLetter) else { return line }
        return line[..<i] + line[i].uppercased() + line[line.index(after: i)...]
    }
}
