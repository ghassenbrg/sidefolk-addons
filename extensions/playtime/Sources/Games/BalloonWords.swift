import Foundation

extension Games {
    /// Balloon Words, a kind hangman: guess the word before the companion's seven balloons are gone. A right letter
    /// fills every place it's in; a miss pops a balloon. One hint a word shows a letter for free (the plan's spoken
    /// clue, "It's yellow and you peel it", would need a written clue per word in ten languages; the category chip
    /// is the clue instead). How each language is guessed is `WordScript`'s (Chinese guesses the pinyin).
    ///
    /// Flow: `guess(letter)` per key; `hint()` once. Events: `hit(n)`, `miss(left:)`, then `reveal` and `roundOver`
    /// (you when the word is complete, the companion when the last balloon pops).
    struct BalloonWords: Codable, Equatable, Sendable {
        struct Entry: Codable, Equatable, Hashable, Sendable {
            /// As shown at the end (熊猫 for Chinese).
            let word: String
            /// What is guessed (the word itself, or its pinyin "xiong mao").
            let spelling: String
            /// A `words.<category>` phrase key's last part.
            let category: String
        }

        static let balloons = 7

        let language: Language
        let entry: Entry
        let units: [WordScript.Unit]
        /// Keys guessed, in order (hits and misses).
        private(set) var guessed: [String] = []
        private(set) var left = Self.balloons
        private(set) var hintUsed = false

        /// A word for the level: the language's list sorted by length and cut in thirds, so Easy is its shortest third
        /// in any script. `avoid` keeps recent words out while others remain.
        init(language: Language, level: Level, avoid: Set<String> = [], using rng: inout Random) {
            let all = WordBank.balloon(language).sorted { ($0.units(language), $0.word) < ($1.units(language), $1.word) }
            let third = max(1, all.count / 3)
            let slice: ArraySlice<Entry> = switch level {
            case .easy: all.prefix(third)
            case .fair: all.dropFirst(third).prefix(third)
            case .hard: all.dropFirst(2 * third)
            }
            let fresh = slice.filter { !avoid.contains($0.word) }
            self.init(language: language, entry: rng.pick(fresh.isEmpty ? Array(slice) : fresh))
        }

        init(language: Language, entry: Entry) {
            self.language = language
            self.entry = entry
            units = WordScript.units(entry.spelling, language, for: .balloon)
        }

        var won: Bool { units.allSatisfy { $0.key.isEmpty || guessed.contains($0.key) } }
        var lost: Bool { left == 0 }
        var over: Bool { won || lost }

        /// What each place shows now: its letter once guessed (or at the end), nil while hidden.
        var slots: [String?] { units.map { over || $0.key.isEmpty || guessed.contains($0.key) ? $0.shown : nil } }
        var misses: [String] { guessed.filter { k in !units.contains { $0.key == k } } }
        var keys: [String] { WordScript.alphabet(language, for: .balloon) }

        mutating func guess(_ typed: String) throws -> [Event] {
            guard !over else { throw Refusal("over") }
            guard let key = WordScript.key(typed: typed, language, for: .balloon) else { throw Refusal("not_letters") }
            guard !guessed.contains(key) else { throw Refusal("already_guessed") }
            guessed.append(key)
            let found = units.filter { $0.key == key }.count
            if found == 0 {
                left -= 1
                return [.miss(left: left)] + (lost ? [.reveal, .roundOver(winner: .companion)] : [])
            }
            return [.hit(found)] + (won ? [.reveal, .roundOver(winner: .you)] : [])
        }

        /// Shows the hidden letter that fills the most places, without popping a balloon.
        mutating func hint() throws -> (key: String, events: [Event]) {
            guard !over else { throw Refusal("over") }
            guard !hintUsed else { throw Refusal("hint_used") }
            let hidden = units.map(\.key).filter { !$0.isEmpty && !guessed.contains($0) }
            let key = Dictionary(grouping: hidden, by: { $0 }).max { ($0.value.count, $1.key) < ($1.value.count, $0.key) }!.key
            hintUsed = true
            guessed.append(key)
            return (key, [.hint, .hit(hidden.filter { $0 == key }.count)] + (won ? [.reveal, .roundOver(winner: .you)] : []))
        }
    }
}

extension Games.BalloonWords.Entry {
    /// Its length in guessable letters, for the levels.
    func units(_ language: Games.Language) -> Int { Games.WordScript.units(spelling, language, for: .balloon).filter { !$0.key.isEmpty }.count }
}
