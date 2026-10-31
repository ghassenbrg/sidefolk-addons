import Foundation

extension Games {
    /// One trivia question in all ten languages. The first option is the right one, as written; the round shuffles them.
    struct QuizQuestion: Equatable, Sendable {
        let id: String
        let category: String
        /// 1 (most people know it) to 3 (a real teaser).
        let difficulty: Int
        let text: Text
        let options: [Text]
    }

    /// The bundled questions, written in `Block` form, one file per category under Content/Trivia:
    ///
    ///     # sci.gold science 1
    ///     *: Au | Ag | Gd | Go                                  (options every language shares, right one first)
    ///     en: What is the chemical symbol for gold?
    ///     fr: Quel est le symbole chimique de l'or ? | …        (a language may give its own four options)
    enum QuizBank {
        /// The topics, in the order of the set-up cards (Mix, all of them, comes first there).
        static let categories = ["science", "space", "geography", "history", "nature", "food", "arts", "tech", "sports", "mediterranean"]
        static let longestQuestion = 160
        static let longestOption = 48

        static let sources: [String] = [science, space, geography, history, nature, food, arts, tech, sports, mediterranean]
        static let all: [QuizQuestion] = sources.flatMap { Block.parse($0).map(question) }
        static let byId: [String: QuizQuestion] = Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })

        private static func question(_ block: Block) -> QuizQuestion {
            let h = block.header
            let shared = block.one("*").map(fields)
            var text: [String: String] = [:]
            var options = Array(repeating: [String: String](), count: 4)
            for language in Language.allCases {
                guard let line = block.one(language.key) else { continue }
                let f = fields(line)
                text[language.key] = f[0]
                let own = f.count == 5 ? Array(f.dropFirst()) : (f.count == 1 ? shared : nil)
                guard let own, own.count == 4 else { continue }
                for i in 0..<4 { options[i][language.key] = own[i] }
            }
            return QuizQuestion(id: h.first ?? "?", category: h.count > 1 ? h[1] : "?", difficulty: h.count > 2 ? Int(h[2]) ?? 0 : 0,
                                text: Text(byKey: text), options: options.map { Text(byKey: $0) })
        }

        /// Everything wrong with the bank, for the content test: a missing language or option, a repeated option or
        /// id, an unknown category, text too long for the tiles.
        static func problems() -> [String] {
            var found: [String] = []
            var ids: Set<String> = []
            for q in all {
                if !ids.insert(q.id).inserted { found.append("\(q.id): id used twice") }
                if !categories.contains(q.category) { found.append("\(q.id): category \(q.category)") }
                if !(1...3).contains(q.difficulty) { found.append("\(q.id): difficulty") }
                for language in Language.allCases {
                    let text = q.text[language]
                    let options = q.options.map { $0.byKey[language.key] ?? "" }
                    if q.text.byKey[language.key] == nil { found.append("\(q.id) \(language.key): no question") }
                    if options.contains("") { found.append("\(q.id) \(language.key): an option is missing") }
                    if Set(options.map { $0.lowercased() }).count != 4 { found.append("\(q.id) \(language.key): options repeat") }
                    if text.count > longestQuestion { found.append("\(q.id) \(language.key): question too long") }
                    if let long = options.first(where: { $0.count > longestOption }) { found.append("\(q.id) \(language.key): option too long: \(long)") }
                }
            }
            return found
        }
    }
}
