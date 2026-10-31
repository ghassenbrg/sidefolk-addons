import Foundation
import SidefolkExtensionKit

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

/// A set of questions in one language. Several packs in one language add up.
protocol TriviaPack: Sendable {
    /// One of `Localized.languages`.
    var language: String { get }
    var questions: [TriviaQuestion] { get }
}

/// The bundled bank (Games.QuizBank: 400 questions in every one of the ten languages, each with a difficulty) as one
/// pack per language. The bank has no "Did you know?" lines, so `fact` is empty and the board shows none.
struct BankPack: TriviaPack {
    let language: String

    var questions: [TriviaQuestion] {
        let l = Games.Language(code: language)
        return Games.QuizBank.all.map { q in
            TriviaQuestion(id: q.id, category: q.category, difficulty: q.difficulty, text: q.text[l], choices: q.options.map { $0[l] }, answer: 0,
                           fact: "")
        }
    }
}

/// Every pack Playtime ships, and the questions for a language: that language's, or English while it has none.
enum TriviaLibrary {
    static let packs: [any TriviaPack] = Localized.languages.map(BankPack.init)
    /// Built once per language: a round asks for them at every move.
    nonisolated(unsafe) private static var cache: [String: [TriviaQuestion]] = [:]

    static func questions(language: String) -> [TriviaQuestion] {
        let language = Localized.normalized(language)
        if let known = cache[language] { return known }
        let own = packs.filter { $0.language == language }.flatMap(\.questions)
        let found = own.isEmpty ? packs.filter { $0.language == "en" }.flatMap(\.questions) : own
        cache[language] = found
        return found
    }

    /// The categories with questions, in a fixed order, then any a pack adds.
    static func categories(language: String) -> [String] {
        let known = Games.QuizBank.categories
        let present = Set(questions(language: language).map(\.category))
        return known.filter(present.contains) + present.subtracting(known).sorted()
    }
}
