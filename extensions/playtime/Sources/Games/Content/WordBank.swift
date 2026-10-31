import Foundation

extension Games {
    /// The word games' lists, per language (Content/BalloonWordList.swift, Content/DailyWordList.swift). Each
    /// language's words are its own everyday words, not translations of the English ones: a word that is easy in one
    /// language can be long or rare in another.
    ///
    /// Balloon Words: `# <category>` blocks, a line of comma-separated words per language; Chinese gives each word as
    /// characters and pinyin, `熊猫=xiong mao`. Daily Word: `# daily` blocks of answers, one or more lines per language.
    enum WordBank {
        static let categories = ["animals", "food", "home", "nature", "clothes", "transport", "sports", "music"]

        /// The length of a Daily Word answer in `WordScript` units, by language.
        static func dailyLength(_ language: Language) -> Int {
            switch language {
            case .ja, .zh: 4
            default: 5
            }
        }

        static func balloon(_ language: Language) -> [BalloonWords.Entry] { balloonLists[language.key] ?? [] }
        static func daily(_ language: Language) -> [String] { dailyLists[language.key] ?? [] }
        static func dailyOrder(_ language: Language) -> [String] { dailyOrders[language.key] ?? [] }

        private static let balloonLists: [String: [BalloonWords.Entry]] = {
            var lists: [String: [BalloonWords.Entry]] = [:]
            for block in Block.parse(balloonSource) {
                let category = block.header.first ?? ""
                for language in Language.allCases {
                    for item in (block.values[language.key] ?? []).flatMap(items) {
                        let parts = item.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
                        lists[language.key, default: []].append(
                            BalloonWords.Entry(word: parts[0], spelling: parts.count == 2 ? parts[1] : parts[0], category: category))
                    }
                }
            }
            return lists
        }()

        private static let dailyLists: [String: [String]] = {
            var lists: [String: [String]] = [:]
            for block in Block.parse(dailySource) {
                for language in Language.allCases {
                    lists[language.key, default: []] += (block.values[language.key] ?? []).flatMap(items)
                }
            }
            return lists
        }()

        /// Each list in a fixed shuffled order (the same on every Mac), so consecutive days aren't alphabetical.
        private static let dailyOrders: [String: [String]] = Dictionary(uniqueKeysWithValues: dailyLists.map { key, words in
            var seen: Set<String> = []
            var rng = Random(seed: stableHash("daily/" + key))
            return (key, rng.shuffled(words.filter { seen.insert($0).inserted }))
        })

        /// Everything wrong with the lists, for the content test.
        static func problems() -> [String] {
            var found: [String] = []
            for language in Language.allCases {
                let balloon = balloon(language)
                for category in categories where balloon.filter({ $0.category == category }).count < 8 {
                    found.append("\(language.key) balloon \(category): fewer than 8 words")
                }
                for entry in balloon {
                    let units = WordScript.units(entry.spelling, language, for: .balloon).filter { !$0.key.isEmpty }
                    if units.count < 3 { found.append("\(language.key) balloon \(entry.word): too short") }
                    if let bad = units.first(where: { !WordScript.isKey($0.key, language, .balloon) }) {
                        found.append("\(language.key) balloon \(entry.word): \(bad.shown) isn't a key")
                    }
                }
                let words = balloon.map(\.word)
                if Set(words).count != words.count { found.append("\(language.key) balloon: a word twice") }
                let daily = daily(language)
                if daily.count < 100 { found.append("\(language.key) daily: only \(daily.count) words") }
                if Set(daily).count != daily.count { found.append("\(language.key) daily: a word twice") }
                for word in daily {
                    let units = WordScript.units(word, language, for: .daily)
                    if units.count != dailyLength(language) { found.append("\(language.key) daily \(word): length \(units.count)") }
                    if let bad = units.first(where: { !WordScript.isKey($0.key, language, .daily) }) {
                        found.append("\(language.key) daily \(word): \(bad.shown) isn't a key")
                    }
                }
            }
            return found
        }
    }
}
