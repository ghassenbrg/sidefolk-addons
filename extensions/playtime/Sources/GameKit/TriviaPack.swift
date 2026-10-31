import Foundation

/// One trivia question, in one language. `id` is the same in every language, so what was asked lately and how well
/// the companion knows a question carry across a change of language.
struct TriviaQuestion: Codable, Hashable {
    var id: String
    /// One of `TriviaLibrary.categories`' ids: science, space, geography, history, nature, food, arts, tech, sports, or
    /// a pack's own (mediterranean).
    var category: String
    /// 1 easy, 2 medium, 3 hard: how likely the companion is to know it.
    var difficulty: Int
    var text: String
    /// Four, the right one at `answer`; they are shuffled when asked.
    var choices: [String]
    var answer: Int
    /// A line that teaches something, shown after the answer.
    var fact: String
}

/// A set of questions in one language. The content packs (Sources/Games/) conform to this and are listed in
/// `TriviaLibrary.packs`; several packs in one language add up.
protocol TriviaPack {
    /// One of `Localized.languages`.
    static var language: String { get }
    static var questions: [TriviaQuestion] { get }
}

/// Every pack Playtime ships, and the questions for a language: that language's, or English while it has none.
enum TriviaLibrary {
    /// The 52 questions trivia started with, until the full packs land.
    nonisolated(unsafe) static var packs: [any TriviaPack.Type] = [FirstQuestions.self]

    static func questions(language: String) -> [TriviaQuestion] {
        let own = packs.filter { $0.language == language }.flatMap { $0.questions }
        return own.isEmpty ? packs.filter { $0.language == "en" }.flatMap { $0.questions } : own
    }

    /// The categories with questions, in a fixed order, then any a pack adds.
    static func categories(language: String) -> [String] {
        let known = ["science", "space", "geography", "history", "nature", "food", "arts", "tech", "sports", "mediterranean"]
        let present = Set(questions(language: language).map(\.category))
        return known.filter(present.contains) + present.subtracting(known).sorted()
    }
}

/// The original bank (Trivia.swift, still the `trivia` tool's for chat and voice), in English, each question medium.
enum FirstQuestions: TriviaPack {
    static let language = "en"
    static var questions: [TriviaQuestion] {
        Trivia.bank.enumerated().map { i, q in
            TriviaQuestion(id: "first-\(i)", category: q.category, difficulty: 2, text: q.text, choices: q.choices, answer: q.answer, fact: q.fact)
        }
    }
}
