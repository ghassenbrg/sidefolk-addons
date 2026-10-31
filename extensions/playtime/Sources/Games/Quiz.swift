import Foundation

extension Games {
    /// Trivia as a game, "Quiz with Mochi": a round of 5, 10 or endless questions against the companion, no AI. For
    /// each question the companion thinks, then seals its pick (hidden until you answer, so it can't sway you); once a
    /// round you can "Ask Mochi", which fades two options it believes wrong. Its knowledge is honest chance: per
    /// category a strength between 55% and 85% drawn from the companion's own seed (so each companion has its strong and
    /// weak topics), a little more on easy questions and less on hard ones. In its weak topics (below 70%) its whisper
    /// can be wrong, and it says it isn't sure.
    ///
    /// Flow: on start and after `next(using:)`, the events are `think(ms)` then `sealed`; `answer(i)` (i in the shown
    /// order, nil for the Quick pace's timeout); `askCompanion()` before answering; `next(using:)` until `over`.
    /// Events: `think`, `sealed`, `lifeline(sure:)`, `reveal`, `point` (for each side right), `streak` (3, 5, 10, then
    /// every 5), `matchOver`, `newBest` (a better score than `Record.best` for this length).
    struct Quiz: Codable, Equatable, Sendable {
        enum Phase: String, Codable, Sendable { case question, answered, over }

        /// One question as asked this round.
        struct Asked: Codable, Equatable, Sendable {
            let id: String
            /// Shown position → the bank's option index (0 is right).
            let order: [Int]
            /// The companion's sealed pick, a shown position.
            let companionPick: Int
            let thinkMs: Int
            var yours: Int?
            /// Positions faded by the lifeline.
            var faded: [Int] = []
            var answered = false

            var right: Int { order.firstIndex(of: 0)! }
            var youRight: Bool { yours == right }
            var companionRight: Bool { companionPick == right }
        }

        /// The current question as the board shows it.
        struct Shown: Equatable, Sendable {
            let id: String
            let category: String
            let number: Int
            let total: Int?
            let text: String
            let options: [String]
        }

        let language: Language
        /// nil is Mix.
        let category: String?
        /// 5 or 10; nil is endless (until the topic runs out).
        let length: Int?
        private let strengths: [String: Double]
        private let previousBest: Int
        private var queue: [String]
        private(set) var asked: [Asked] = []
        private(set) var score = Score()
        private(set) var streak = 0
        private(set) var bestStreak = 0
        private(set) var lifelineUsed = false
        private(set) var phase = Phase.question

        /// `companion` names the companion (its id) for its strengths; `record` keeps recent questions out.
        init(language: Language, category: String?, length: Int?, companion: String, record: Record = Record(), using rng: inout Random) {
            self.language = language
            self.category = category
            self.length = length
            strengths = Self.strengths(companion)
            previousBest = record.best[length.map(String.init) ?? "endless"] ?? 0
            let pool = QuizBank.all.filter { category == nil || $0.category == category }.map(\.id)
            let recent = Set(record.recent)
            // Fresh questions first, the recently asked ones only once those run out.
            queue = rng.shuffled(pool.filter { !recent.contains($0) }) + rng.shuffled(pool.filter { recent.contains($0) })
            if let length { queue = Array(queue.prefix(length)) }
            if queue.isEmpty { phase = .over } else { ask(using: &rng) }
        }

        /// The events that open the first question.
        var opening: [Event] { asked.last.map { [.think(ms: $0.thinkMs), .sealed] } ?? [] }

        var over: Bool { phase == .over }

        var current: Shown? {
            guard let a = asked.last, let q = QuizBank.byId[a.id] else { return nil }
            return Shown(id: q.id, category: q.category, number: asked.count, total: length, text: q.text[language],
                         options: a.order.map { q.options[$0][language] })
        }

        /// The companion's strength in a category, 0.55–0.85.
        func strength(_ category: String) -> Double { strengths[category] ?? 0.7 }

        mutating func askCompanion() throws -> (faded: [Int], sure: Bool, events: [Event]) {
            guard phase == .question, var a = asked.popLast() else { throw Refusal("not_now") }
            guard !lifelineUsed else { asked.append(a); throw Refusal("hint_used") }
            lifelineUsed = true
            let category = QuizBank.byId[a.id]?.category ?? ""
            let sure = strength(category) >= 0.7
            // Sure: it keeps the right one and fades two wrong ones. Unsure: it keeps its own pick, right or not, so
            // its whisper can fade the right answer. The one other option kept is fixed by the question.
            let keep = sure ? a.right : a.companionPick
            var others = (0..<4).filter { $0 != keep }
            others.remove(at: Int(stableHash(a.id) % 3))
            a.faded = others
            asked.append(a)
            return (others, sure, [.lifeline(sure: sure)])
        }

        mutating func answer(_ position: Int?) throws -> [Event] {
            guard phase == .question, var a = asked.popLast() else { throw Refusal("not_now") }
            if let position, !(0..<4).contains(position) || a.faded.contains(position) { asked.append(a); throw Refusal("taken") }
            a.yours = position
            a.answered = true
            asked.append(a)
            phase = .answered
            var events: [Event] = [.reveal]
            if a.youRight {
                score.you += 1
                streak += 1
                bestStreak = max(bestStreak, streak)
                events.append(.point(.you))
                if [3, 5].contains(streak) || (streak >= 10 && streak % 5 == 0) { events.append(.streak(streak)) }
            } else {
                streak = 0
            }
            if a.companionRight {
                score.companion += 1
                events.append(.point(.companion))
            }
            if asked.count == queue.count { events += finish() }
            return events
        }

        mutating func next(using rng: inout Random) throws -> [Event] {
            guard phase == .answered else { throw Refusal("not_now") }
            ask(using: &rng)
            return opening
        }

        /// The end card: the scores, your best streak, whether it's a new best, each question's category and result.
        var summary: (score: Score, bestStreak: Int, newBest: Bool, results: [(category: String, right: Bool)]) {
            (score, bestStreak, score.you > previousBest,
             asked.filter(\.answered).map { (QuizBank.byId[$0.id]?.category ?? "", $0.youRight) })
        }

        private mutating func ask(using rng: inout Random) {
            let id = queue[asked.count]
            let q = QuizBank.byId[id]!
            let order = rng.shuffled([0, 1, 2, 3])
            let p = min(0.95, max(0.3, strength(q.category) + Double(2 - q.difficulty) * 0.1))
            let believed = rng.chance(p) ? 0 : rng.pick([0, 1, 2, 3])
            asked.append(Asked(id: id, order: order, companionPick: order.firstIndex(of: believed)!, thinkMs: rng.between(2000, 4000)))
            phase = .question
        }

        private mutating func finish() -> [Event] {
            phase = .over
            return [.matchOver(winner: score.leader)] + (score.you > previousBest ? [.newBest(score.you)] : [])
        }

        private static func strengths(_ companion: String) -> [String: Double] {
            Dictionary(uniqueKeysWithValues: QuizBank.categories.map { c in
                var r = Random(seed: stableHash(companion + "/" + c))
                return (c, 0.55 + 0.30 * Double(r.below(1001)) / 1000)
            })
        }

        /// What trivia keeps between rounds (the adapter saves it): best scores by length, best streak, recent ids.
        struct Record: Codable, Equatable, Sendable {
            /// By "5", "10" or "endless".
            var best: [String: Int] = [:]
            var bestStreak = 0
            var recent: [String] = []
            var rounds = 0

            mutating func finish(_ quiz: Quiz) {
                let key = quiz.length.map(String.init) ?? "endless"
                best[key] = max(best[key] ?? 0, quiz.score.you)
                bestStreak = max(bestStreak, quiz.bestStreak)
                // Half the bank, so a question comes back only after many others.
                recent = Array((recent + quiz.asked.map(\.id)).suffix(QuizBank.all.count / 2))
                rounds += 1
            }
        }
    }
}
