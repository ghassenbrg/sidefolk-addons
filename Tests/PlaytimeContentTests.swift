import Foundation
import Testing
@testable import ext_playtime

/// The games' bundled words in all ten of Sidefolk's languages: every question, word and animal is complete and
/// well formed. Whether a fact is true is checked by people; these catch what a typo breaks.
struct PlaytimeContentTests {
    typealias G = Games

    @Test func triviaIsCompleteInEveryLanguage() {
        let problems = G.QuizBank.problems()
        #expect(problems.isEmpty, "\(problems.prefix(20).joined(separator: "\n"))")
        #expect(G.QuizBank.all.count >= 400)
        for category in G.QuizBank.categories {
            let questions = G.QuizBank.all.filter { $0.category == category }
            #expect(questions.count >= 35, "\(category)")
            #expect(Set(questions.map(\.difficulty)).count >= 2, "\(category) has easy and harder questions")
        }
        // One id, one right answer (the first as written), four different options, in each language.
        for q in G.QuizBank.all {
            for language in G.Language.allCases {
                let options = q.options.map { $0[language] }
                #expect(Set(options.map { $0.lowercased() }).count == 4, "\(q.id) \(language.key)")
                #expect(!q.text[language].contains("|"), "\(q.id)")
            }
        }
        // Each language's questions are really in that language: no line left in English by mistake.
        for language in G.Language.allCases where language != .en {
            let same = G.QuizBank.all.filter { $0.text[language] == $0.text[.en] }
            #expect(same.isEmpty, "\(language.key): \(same.map(\.id))")
        }
    }

    @Test func phrasesAreCompleteAndCoverTheGames() {
        #expect(G.Phrases.malformed.isEmpty, "\(G.Phrases.malformed)")
        var keys = G.Level.allCases.map { "level.\($0.rawValue)" } + ["category.mix"]
        keys += G.QuizBank.categories.map { "category.\($0)" } + G.WordBank.categories.map { "words.\($0)" }
        keys += G.CopyMe.Pad.allCases.map { "pad.\($0.rawValue)" } + G.MemoryPairs.symbols.map { "symbol.\($0)" }
        keys += ["daily.title", "daily.notPlayed", "daily.solved", "daily.missed", "daily.streak", "animal.guess", "numbers.ask"]
        for key in keys {
            #expect(G.Phrases.table[key]?.missing.isEmpty == true, "\(key)")
        }
        #expect(G.Phrases.text("animal.guess", .ja, ["name": "ネコ"]) == "答えは… ネコ！")
        #expect(G.Phrases.text("no.such.key", .fr) == "no.such.key")
    }

    @Test func wordListsSuitEachLanguage() {
        let problems = G.WordBank.problems()
        #expect(problems.isEmpty, "\(problems.prefix(30).joined(separator: "\n"))")
        for language in G.Language.allCases {
            #expect(G.WordBank.balloon(language).count >= 100, "\(language.key) balloon")
            #expect(G.WordBank.daily(language).count >= 100, "\(language.key) daily")
        }
        // Chinese guesses pinyin in Balloon Words and shows the characters; the other languages guess the word itself.
        #expect(G.WordBank.balloon(.zh).allSatisfy { $0.word != $0.spelling })
        #expect(G.WordBank.balloon(.fr).allSatisfy { $0.word == $0.spelling })
    }

    @Test func animalTreeIsWholeInEveryLanguage() {
        let problems = G.AnimalBank.problems()
        #expect(problems.isEmpty, "\(problems.joined(separator: "\n"))")
        #expect(G.AnimalBank.animals.count >= 50)
        #expect(G.AnimalBank.animals.values.allSatisfy { !$0.emoji.isEmpty })
        for language in G.Language.allCases {
            // Every animal is reachable by some answers, and in this language.
            func leaves(_ node: G.GuessAnimal.Node) -> [String] {
                switch node {
                case .animal(_, let name, _): [name]
                case .question(_, let yes, let no): leaves(yes) + leaves(no)
                }
            }
            #expect(Set(leaves(G.AnimalBank.tree(language))).count == G.AnimalBank.animals.count, "\(language.key)")
        }
    }
}
