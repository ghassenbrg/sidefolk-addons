import Foundation

extension Games {
    /// Guess My Animal: you think of an animal, the companion asks yes-or-no questions down a tree and guesses; when it
    /// is wrong you tell it the animal and one question that tells the two apart, and it remembers (the classic
    /// "Animal" game). The bundled tree is in all ten languages; what it learns is in the language it was taught in,
    /// so each language grows its own tree (`Memory`).
    ///
    /// "Not sure" takes the yes branch and keeps the no branch for later: if the guess is wrong it goes back there
    /// before giving up. After 20 questions it guesses the nearest animal.
    ///
    /// Flow: show `question`, `answer(.yes/.no/.unsure)` until `phase == .guessing`; show `guess`, then
    /// `verdict(right:)`; when `phase == .teaching`, `teach(animal:question:answerForNew:memory:)` and save the memory.
    /// Events: `think` (it goes back to an unsure branch), `reveal` (it guesses), `roundOver` (the companion when
    /// right, you when it gives up), `learned`, `forgot`.
    struct GuessAnimal: Codable, Equatable, Sendable {
        indirect enum Node: Codable, Equatable, Sendable {
            case animal(id: String, name: String, emoji: String)
            case question(String, yes: Node, no: Node)
        }

        enum Answer: String, Codable, Sendable { case yes, no, unsure }
        enum Phase: String, Codable, Sendable { case asking, guessing, teaching, over }

        static let maxQuestions = 20

        let language: Language
        private let tree: Node
        /// Where the game is: the answers from the root (true is yes).
        private(set) var path: [Bool] = []
        /// Branches left behind by "not sure", the latest last.
        private(set) var pending: [[Bool]] = []
        private(set) var asked = 0
        private(set) var phase = Phase.asking

        init(language: Language, memory: Memory = Memory()) {
            self.language = language
            tree = memory.tree(language)
            if case .animal = tree { phase = .guessing }
        }

        var question: String? {
            guard phase == .asking, case .question(let text, _, _) = node(path) else { return nil }
            return text
        }

        var guess: (name: String, emoji: String)? {
            guard phase != .asking, case .animal(_, let name, let emoji) = node(path) else { return nil }
            return (name, emoji)
        }

        mutating func answer(_ answer: Answer) throws -> [Event] {
            guard phase == .asking else { throw Refusal("not_now") }
            if answer == .unsure { pending.append(path + [false]) }
            path.append(answer != .no)
            asked += 1
            return settle()
        }

        mutating func verdict(right: Bool) throws -> [Event] {
            guard phase == .guessing else { throw Refusal("not_now") }
            if right {
                phase = .over
                return [.roundOver(winner: .companion)]
            }
            guard let back = pending.popLast() else {
                phase = .teaching
                return [.roundOver(winner: .you)]
            }
            path = back
            phase = .asking
            return [.think(ms: 900)] + settle()
        }

        /// What it was, and a question whose answer is `answerForNew` for it and the opposite for the wrong guess.
        mutating func teach(animal: String, question: String, answerForNew: Bool, memory: inout Memory) throws -> [Event] {
            guard phase == .teaching, case .animal(let id, let name, _) = node(path) else { throw Refusal("not_now") }
            let animal = animal.trimmingCharacters(in: .whitespacesAndNewlines)
            let question = question.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !animal.isEmpty, !question.isEmpty else { throw Refusal("empty") }
            guard animal.count <= Memory.longestName, question.count <= Memory.longestQuestion else { throw Refusal("too_long") }
            guard animal.lowercased() != name.lowercased() else { throw Refusal("same_animal") }
            phase = .over
            let forgot = memory.learn(language, at: id, animal: animal, question: question, answerForNew: answerForNew)
            return [.learned] + (forgot ? [.forgot] : [])
        }

        /// After a move: a guess at a leaf, or, past the question limit, at the nearest leaf down the yes side.
        private mutating func settle() -> [Event] {
            if asked >= Self.maxQuestions {
                while case .question = node(path) { path.append(true) }
            }
            guard case .animal = node(path) else { return [] }
            phase = .guessing
            return [.reveal]
        }

        private func node(_ path: [Bool]) -> Node {
            path.reduce(tree) { node, yes in
                guard case .question(_, let y, let n) = node else { return node }
                return yes ? y : n
            }
        }

        /// What the companion learned, per language, as lessons replayed onto the bundled tree: small to save, and a
        /// newer bundled tree still takes them (a lesson whose animal is gone is dropped). Capped, oldest forgotten.
        struct Memory: Codable, Equatable, Sendable {
            struct Lesson: Codable, Equatable, Sendable {
                let id: String
                /// The animal it guessed wrongly: the leaf the lesson splits.
                let at: String
                let animal: String
                let question: String
                let answerForNew: Bool
            }

            static let capacity = 150
            static let longestName = 40
            static let longestQuestion = 120

            /// By `Language.key`.
            private(set) var lessons: [String: [Lesson]] = [:]
            private var next = 1

            init() {}

            /// Learns; true when the memory was full and the oldest lesson (with the ones built on it) went.
            mutating func learn(_ language: Language, at leaf: String, animal: String, question: String, answerForNew: Bool) -> Bool {
                var list = lessons[language.key] ?? []
                list.append(Lesson(id: "taught-\(next)", at: leaf, animal: animal, question: question, answerForNew: answerForNew))
                next += 1
                var forgot = false
                while list.count > Self.capacity {
                    list.removeFirst()
                    forgot = true
                }
                lessons[language.key] = Self.reachable(list)
                return forgot
            }

            /// The bundled tree in `language` with its lessons.
            func tree(_ language: Language) -> Node {
                var tree = AnimalBank.tree(language)
                for lesson in lessons[language.key] ?? [] {
                    tree = Self.split(tree, lesson)
                }
                return tree
            }

            /// Lessons whose leaf still exists (bundled, or taught by an earlier lesson still kept).
            private static func reachable(_ list: [Lesson]) -> [Lesson] {
                var known = AnimalBank.ids
                return list.filter { lesson in
                    guard known.contains(lesson.at) else { return false }
                    known.insert(lesson.id)
                    return true
                }
            }

            private static func split(_ node: Node, _ lesson: Lesson) -> Node {
                switch node {
                case .animal(let id, _, _) where id == lesson.at:
                    let new = Node.animal(id: lesson.id, name: lesson.animal, emoji: "")
                    return .question(lesson.question, yes: lesson.answerForNew ? new : node, no: lesson.answerForNew ? node : new)
                case .animal:
                    return node
                case .question(let text, let yes, let no):
                    return .question(text, yes: split(yes, lesson), no: split(no, lesson))
                }
            }
        }
    }
}
