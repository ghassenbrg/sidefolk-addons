import Foundation

extension Games {
    /// Daily Word: one word a day, six tries, the same word for everyone on a date and language. Each try marks every
    /// piece right (green, ●), elsewhere (yellow, ◐) or absent (grey). The word is five letters in the Latin-script
    /// languages and Arabic, four kana in Japanese, two syllables (their jamo) in Korean and a four-character idiom
    /// in Chinese (`WordScript` has why).
    ///
    /// The date is the person's own calendar day, passed in (no time zone here): `day(year:month:day:)`. Each list is
    /// put in a fixed shuffled order and day n takes word n, so it cycles through the whole list before any repeat.
    ///
    /// Which guesses are words: the bundled lists can't hold every word of ten languages, so by default any guess of
    /// the right length in the game's letters is accepted; the adapter can pass `isWord` (a system spell checker, say)
    /// to refuse non-words. Flow: `guess(word)`; `hint()` once a day. Events: `reveal` (flip the row), `hit(n)` with
    /// the greens of a row that didn't solve it, `found(guesses:)`, `roundOver` (you, or the companion when missed).
    struct DailyWord: Codable, Equatable, Sendable {
        enum Mark: String, Codable, Sendable { case right, elsewhere, absent }

        struct Row: Codable, Equatable, Sendable {
            let units: [WordScript.Unit]
            let marks: [Mark]
        }

        static let tries = 6

        let language: Language
        let day: Int
        private let answer: [WordScript.Unit]
        private let answerWord: String
        private(set) var rows: [Row] = []
        /// The place the day's hint showed.
        private(set) var hintPlace: Int?

        init(language: Language, day: Int) {
            self.language = language
            self.day = day
            answerWord = Self.answer(day: day, language: language)
            answer = WordScript.units(answerWord, language, for: .daily)
        }

        var length: Int { answer.count }
        var solved: Bool { rows.last?.marks.allSatisfy { $0 == .right } ?? false }
        var over: Bool { solved || rows.count >= Self.tries }
        /// The word, once the day's game is over.
        var shown: String? { over ? answerWord : nil }
        var keys: [String] { WordScript.alphabet(language, for: .daily) }

        /// The best mark each key has earned, for the keyboard.
        var keyMarks: [String: Mark] {
            var best: [String: Mark] = [:]
            for row in rows {
                for (unit, mark) in zip(row.units, row.marks) {
                    let old = best[unit.key]
                    if old == nil || mark == .right || (mark == .elsewhere && old == .absent) { best[unit.key] = mark }
                }
            }
            return best
        }

        mutating func guess(_ word: String, isWord: ((String) -> Bool)? = nil) throws -> [Event] {
            guard !over else { throw Refusal("over") }
            let units = WordScript.units(word.trimmingCharacters(in: .whitespaces), language, for: .daily)
            guard units.count == length else { throw Refusal("wrong_length") }
            guard units.allSatisfy({ WordScript.isKey($0.key, language, .daily) }) else { throw Refusal("not_letters") }
            guard !rows.contains(where: { $0.units.map(\.key) == units.map(\.key) }) else { throw Refusal("already_guessed") }
            if let isWord, !isWord(word) { throw Refusal("not_a_word") }
            let marks = Self.marks(units.map(\.key), answer.map(\.key))
            rows.append(Row(units: units, marks: marks))
            if solved { return [.reveal, .found(guesses: rows.count), .roundOver(winner: .you)] }
            if over { return [.reveal, .roundOver(winner: .companion)] }
            let greens = marks.filter { $0 == .right }.count
            return [.reveal] + (greens > 0 ? [.hit(greens)] : [])
        }

        /// Shows one place not yet found green.
        mutating func hint() throws -> (place: Int, shown: String, events: [Event]) {
            guard !over else { throw Refusal("over") }
            guard hintPlace == nil else { throw Refusal("hint_used") }
            let found = Set(rows.flatMap { row in row.marks.indices.filter { row.marks[$0] == .right } })
            let place = answer.indices.first { !found.contains($0) } ?? 0
            hintPlace = place
            return (place, answer[place].shown, [.hint])
        }

        /// Wordle's marking: greens first, then yellows only as many times as the letter is left in the answer.
        static func marks(_ guess: [String], _ answer: [String]) -> [Mark] {
            var marks = Array(repeating: Mark.absent, count: guess.count)
            var left: [String: Int] = [:]
            for i in guess.indices {
                if guess[i] == answer[i] { marks[i] = .right } else { left[answer[i], default: 0] += 1 }
            }
            for i in guess.indices where marks[i] != .right {
                if let n = left[guess[i]], n > 0 {
                    marks[i] = .elsewhere
                    left[guess[i]] = n - 1
                }
            }
            return marks
        }

        // MARK: The day's word

        /// Days since 1 January 2026 on the proleptic Gregorian calendar (negative before), from the person's local
        /// date, with no time zone involved: everyone whose calendar says that date gets the same word.
        static func day(year: Int, month: Int, day: Int) -> Int {
            // Howard Hinnant's days-from-civil.
            let y = month <= 2 ? year - 1 : year
            let era = (y >= 0 ? y : y - 399) / 400
            let yoe = y - era * 400
            let doy = (153 * (month + (month > 2 ? -3 : 9)) + 2) / 5 + day - 1
            let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
            return era * 146_097 + doe - 719_468 - 20_454
        }

        static func answer(day: Int, language: Language) -> String {
            let order = WordBank.dailyOrder(language)
            let n = order.count
            return order[((day % n) + n) % n]
        }

        /// What Daily Word keeps between days (the adapter saves it): the streak and the last games, for the Today
        /// tile and the end card.
        struct Record: Codable, Equatable, Sendable {
            var lastDay: Int?
            var lastSolved = false
            var lastGuesses = 0
            var lastSolvedDay: Int?
            var streak = 0
            var best = 0
            var played = 0
            var won = 0

            /// Records the day's game once.
            mutating func finish(_ game: DailyWord) {
                guard game.over, lastDay != game.day else { return }
                played += 1
                lastDay = game.day
                lastSolved = game.solved
                lastGuesses = game.rows.count
                if game.solved {
                    won += 1
                    streak = lastSolvedDay == game.day - 1 ? streak + 1 : 1
                    best = max(best, streak)
                    lastSolvedDay = game.day
                } else {
                    streak = 0
                }
            }

            /// The Today tile for `today`: the streak shown only while it's alive (solved yesterday or today).
            func tile(today: Int) -> Tile {
                let alive = lastSolvedDay.map { $0 >= today - 1 } ?? false
                let state: Tile.State = lastDay != today ? .notPlayed : (lastSolved ? .solved(guesses: lastGuesses) : .missed)
                return Tile(state: state, streak: alive ? streak : 0)
            }
        }

        /// The Today tile's value: "Daily Word: not played yet", "Solved in 4", "Streak 12" (`Phrases` daily.*).
        struct Tile: Codable, Equatable, Sendable {
            enum State: Codable, Equatable, Sendable { case notPlayed, solved(guesses: Int), missed }
            let state: State
            let streak: Int

            func lines(_ language: Language) -> [String] {
                let first: String = switch state {
                case .notPlayed: Phrases.text("daily.notPlayed", language)
                case .solved(let n): Phrases.text("daily.solved", language, ["n": "\(n)"])
                case .missed: Phrases.text("daily.missed", language)
                }
                return [first] + (streak > 1 ? [Phrases.text("daily.streak", language, ["n": "\(streak)"])] : [])
            }
        }
    }
}
