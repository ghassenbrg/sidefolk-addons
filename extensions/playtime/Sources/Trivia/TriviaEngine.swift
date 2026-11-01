import Foundation

/// Trivia as a round against the companion (D75): a topic, 5, 10 or endless questions, relaxed or 15 s each. The
/// companion picks too, sealed until you answer, and is right as often as it knows the question: well on easy ones and
/// in its favourite topics, less in its weak ones, more on Hard. Once a round it can be asked for help, and in a weak
/// topic its help can be wrong. The 400-question bank always works; with the person's AI allowed (D95), any topic they
/// name, or one the AI picks ("Any topic" left empty), gets fresh questions in their language (`TriviaAI`). Two people can play
/// it too, a question each in turn (D96).
enum TriviaEngine: GameEngine {
    struct State: Codable, Equatable {
        enum Phase: String, Codable { case setup, making, question, answered, done }

        /// A pack being made: its request, what was asked, and how many times the board has checked.
        struct Asking: Codable, Equatable {
            var id: String
            var topic: String
            var checks = 0
        }

        var phase = Phase.setup
        var level = GameLevel.fair
        var language = "en"
        var topic = "mix"
        /// Questions in the round; 0 is endless (until Finish).
        var length = 10
        var quick = false
        /// Whose strengths these are: each companion has its own strong and weak topics.
        var companionName = "Mochi"
        var round: [String] = []
        var index = 0
        /// The order the current question's choices are shown in (indexes into its choices).
        var order: [Int] = []
        var you = 0
        var companion = 0
        var streak = 0
        var bestStreak = 0
        /// Where the person and the companion picked, as shown; nil when the time ran out.
        var picked: Int?
        var companionPick = 0
        /// Tiles faded by the lifeline.
        var faded: [Int] = []
        var lifelineUsed = false
        /// Whether each answer was right, for the end card.
        var results: [Bool] = []
        /// A new best round, found at the end.
        var record = false
        /// The companion, or two people answering a question each in turn (D96).
        var duo = TwoPlayers.Duo(names: ["", ""])
        /// The AI that may make questions, by name, while Sidefolk allows it (D95); nil keeps to the bank.
        var aiMaker: String?
        /// The round's questions when the AI made them, kept with the round; empty for the bank's.
        var made: [TriviaQuestion] = []
        var madeTopic: String?
        var asking: Asking?
        /// Why the last request brought nothing (`TriviaAI.words`), for the set-up board.
        var notice: String?
    }

    enum Action: Equatable {
        case topic(String), length(Int), pace(quick: Bool), start
        case answer(Int), timeout, hint, next, finish, again, topics
        case custom(String), duo(TwoPlayers.Setup)
    }

    static let lengths = [5, 10, 0]
    static let quickSeconds = 15.0
    /// The topic card that leaves the choice to the AI.
    static let surprise = "surprise"
    /// How long a pack may take: checks every 1.5 s, about a minute.
    static let checkMs = 1500
    static let patience = 45

    static func start(level: GameLevel, options: GameOptions, random: inout Games.Random) -> State {
        var state = State()
        let setup = TriviaRecords.load().setup
        state.level = level
        state.companionName = options.companion
        state.language = options.language
        state.topic = setup.topic == surprise && options.aiTrivia == nil ? "mix" : setup.topic
        state.length = setup.length
        state.quick = setup.quick
        state.duo = TwoPlayers.start(options)
        state.aiMaker = options.aiTrivia
        if let count = options.count { state.length = count <= 5 ? 5 : count <= 10 ? 10 : 0 }
        // "Trivia about space": a topic of the bank's is picked; any other is the AI's to make, when allowed.
        if let asked = options.topic {
            let known = TriviaLibrary.categories(language: state.language)
            if let id = known.first(where: { $0 == asked.lowercased() || TriviaScreen.topic($0).lowercased() == asked.lowercased() }) {
                state.topic = id
            } else if state.aiMaker != nil, !state.duo.on {
                make(asked, &state)
            }
        }
        return state
    }

    /// Asks Sidefolk for a pack and waits on the board for it.
    static func make(_ topic: String, _ state: inout State) {
        let count = state.length == 0 ? 20 : 10
        state.asking = State.Asking(id: TriviaAI.ask(topic: topic, count: count, level: state.level, language: state.language), topic: topic)
        state.notice = nil
        state.phase = .making
    }

    static func outcome(of state: State) -> GameOutcome? {
        guard state.phase == .done else { return nil }
        return state.you > state.companion ? .won : state.you < state.companion ? .lost : .draw
    }

    static func question(_ state: State) -> TriviaQuestion? {
        guard state.round.indices.contains(state.index) else { return nil }
        let id = state.round[state.index]
        return state.made.first { $0.id == id } ?? TriviaLibrary.questions(language: state.language).first { $0.id == id }
    }

    /// Whose question it is when two people play: the first player's first.
    static func player(_ state: State) -> Games.Side { state.index.isMultiple(of: 2) ? .you : .companion }

    /// Where the right answer is shown.
    static func rightTile(_ state: State) -> Int? {
        question(state).flatMap { q in state.order.firstIndex(of: q.answer) }
    }

    static func play(_ action: Action, on state: inout State, random: inout Games.Random) throws -> [Games.Event] {
        switch (state.phase, action) {
        case (.setup, .duo(let setup)):
            _ = TwoPlayers.apply(setup, to: &state.duo)
            return []
        case (.setup, .topic(let t)):
            guard t == "mix" || TriviaLibrary.categories(language: state.language).contains(t) || t == surprise && state.aiMaker != nil
            else { throw Games.Refusal("not_now") }
            state.topic = t
            return []
        case (.setup, .custom(let text)):
            guard state.aiMaker != nil, !state.duo.on || state.duo.playing else { throw Games.Refusal("not_now") }
            make(text, &state)
            return [.think(ms: checkMs)]
        case (.setup, .start) where state.topic == surprise:
            make("", &state)
            return [.think(ms: checkMs)]
        case (.setup, .topics):
            state.topic = "mix"
            return []
        case (.making, .next):
            return arrived(&state, random: &random)
        case (.making, .topics):
            state.asking = nil
            state.phase = .setup
            return []
        case (.setup, .length(let n)):
            guard lengths.contains(n) else { throw Games.Refusal("not_now") }
            state.length = n
            return []
        case (.setup, .pace(let quick)):
            state.quick = quick
            return []
        case (.setup, .start), (.done, .again):
            guard !state.duo.on || state.duo.playing else { throw Games.Refusal("not_now") }
            TriviaRecords.update { $0.setup = TriviaRecords.Setup(topic: state.topic, length: state.length, quick: state.quick) }
            if state.phase == .setup { state.made = [] }
            begin(&state, random: &random)
            return [.sealed]
        case (.done, .topics):
            state.phase = .setup
            state.made = []
            state.madeTopic = nil
            return []
        case (.question, .answer(let i)) where state.order.indices.contains(i) && !state.faded.contains(i):
            return answer(i, &state)
        case (.question, .timeout):
            return answer(nil, &state)
        case (.question, .hint) where !state.lifelineUsed && !state.duo.on:
            return hint(&state, random: &random)
        case (.answered, .next):
            state.index += 1
            if state.length > 0, state.index >= state.round.count { return finish(&state) }
            if state.index >= state.round.count {
                // Endless: another lap of the topic, shuffled again.
                state.round = pool(state).shuffled(using: &random).map(\.id)
                state.index = 0
            }
            ask(&state, random: &random)
            return [.sealed]
        case (.question, .finish), (.answered, .finish):
            return finish(&state)
        default:
            throw Games.Refusal(state.phase == .question && action == .hint ? "hint_used" : "not_now")
        }
    }

    static func pool(_ state: State) -> [TriviaQuestion] {
        if !state.made.isEmpty { return state.made }
        return TriviaLibrary.questions(language: state.language).filter { state.topic == "mix" || $0.category == state.topic }
    }

    /// The board checked whether the pack came: the round starts with it; or, when it can't come, the set-up board
    /// says why and the bank is there as ever.
    private static func arrived(_ state: inout State, random: inout Games.Random) -> [Games.Event] {
        guard var asking = state.asking else { state.phase = .setup; return [] }
        switch TriviaAI.take(asking.id) {
        case .pack(let topic, let madeBy, let questions)?:
            state.made = questions
            state.madeTopic = topic
            state.aiMaker = madeBy
            state.asking = nil
            begin(&state, random: &random)
            return [.sealed]
        case .failed(let reason)?:
            state.asking = nil
            state.notice = reason
            state.phase = .setup
            if state.topic == surprise { state.topic = "mix" }
            return [.refused("no_pack")]
        case nil:
            asking.checks += 1
            guard asking.checks < patience else {
                state.asking = nil
                state.notice = "slow"
                state.phase = .setup
                return [.refused("no_pack")]
            }
            state.asking = asking
            return [.think(ms: checkMs)]
        }
    }

    private static func begin(_ state: inout State, random: inout Games.Random) {
        let recent = Set(TriviaRecords.load().recent)
        var all = pool(state).shuffled(using: &random)
        // Questions asked lately go last, so a round rarely repeats the one before.
        all.sort { !recent.contains($0.id) && recent.contains($1.id) }
        state.round = (state.length > 0 ? Array(all.prefix(state.length)) : all).map(\.id)
        state.length = state.length > 0 ? min(state.length, state.round.count) : 0
        state.index = 0
        state.you = 0
        state.companion = 0
        state.streak = 0
        state.bestStreak = 0
        state.results = []
        state.lifelineUsed = false
        state.record = false
        ask(&state, random: &random)
    }

    /// The next question: its choices shuffled, and the companion's sealed pick.
    private static func ask(_ state: inout State, random: inout Games.Random) {
        state.phase = .question
        state.picked = nil
        state.faded = []
        guard let q = question(state) else { return }
        state.order = Array(q.choices.indices).shuffled(using: &random)
        // Two people: nobody's pick is sealed but their own.
        guard !state.duo.on else { return }
        let right = state.order.firstIndex(of: q.answer) ?? 0
        let wrong = state.order.indices.filter { $0 != right }
        state.companionPick = Double.random(in: 0..<1, using: &random) < skill(q, state.level, companion: state.companionName) ? right : wrong.randomElement(using: &random) ?? right
        TriviaRecords.update { $0.recent = Array(($0.recent + [q.id]).suffix(40)) }
    }

    /// How likely the companion is to know a question: by its difficulty, how strong it is in the topic, and the level.
    static func skill(_ q: TriviaQuestion, _ level: GameLevel, companion: String = "Mochi") -> Double {
        let base: Double = [1: 0.86, 2: 0.72, 3: 0.56][q.difficulty] ?? 0.72
        let lean: Double = [GameLevel.easy: -0.15, .fair: 0, .hard: 0.14][level] ?? 0
        return min(0.95, max(0.3, base + (strength(q.category, companion: companion) - 0.7) + lean))
    }

    /// The companion's strength in a topic, 0.55–0.85, drawn once from its name and the topic (the engines' Quiz idea):
    /// the same companion is always good at the same things, and two companions differ.
    static func strength(_ category: String, companion: String) -> Double {
        var r = Games.Random(seed: Games.stableHash(companion + "/" + category))
        return 0.55 + 0.30 * Double(r.below(1001)) / 1000
    }

    private static func answer(_ picked: Int?, _ state: inout State) -> [Games.Event] {
        guard let right = rightTile(state) else { return [] }
        state.phase = .answered
        state.picked = picked
        if state.duo.on {
            // The question's player scores; the other waits for theirs.
            let side = player(state), right = picked == rightTile(state)
            if right { if side == .you { state.you += 1 } else { state.companion += 1 } }
            state.results.append(right)
            return [.reveal] + (right ? [.point(side)] : [])
        }
        let youRight = picked == right, itRight = state.companionPick == right
        if youRight { state.you += 1 }
        if itRight { state.companion += 1 }
        state.streak = youRight ? state.streak + 1 : 0
        state.bestStreak = max(state.bestStreak, state.streak)
        state.results.append(youRight)
        // `reveal`: an answer was given; each side right scores its point.
        var events: [Games.Event] = [.reveal] + (youRight ? [.point(.you)] : []) + (itRight ? [.point(.companion)] : [])
        if youRight, [3, 5, 10].contains(state.streak) || state.streak > 10 && state.streak.isMultiple(of: 5) { events.append(.streak(state.streak)) }
        return events
    }

    /// Two tiles fade. The companion is as sure as it knows the question: unsure, one of the two it fades is the right one.
    private static func hint(_ state: inout State, random: inout Games.Random) -> [Games.Event] {
        guard let q = question(state), let right = rightTile(state) else { return [] }
        state.lifelineUsed = true
        let trusty = Double.random(in: 0..<1, using: &random) < min(0.97, skill(q, state.level, companion: state.companionName) + 0.12)
        var wrong = state.order.indices.filter { $0 != right }.shuffled(using: &random)
        state.faded = trusty ? Array(wrong.prefix(2)) : [wrong.removeFirst(), right]
        return [.lifeline(sure: trusty)]
    }

    private static func finish(_ state: inout State) -> [Games.Event] {
        state.phase = .done
        let asked = state.results.count
        var events: [Games.Event] = []
        if state.duo.on {
            let winner: Games.Side? = state.you == state.companion ? nil : state.you > state.companion ? .you : .companion
            if asked > 0 { TwoPlayers.record(TriviaScreen.id, state.duo, winner: winner) }
            return [.matchOver(winner: winner)]
        }
        TriviaRecords.update { r in
            state.record = asked > 0 && state.length > 0 && state.you > (r.best[String(state.length)] ?? 0)
            if state.record { r.best[String(state.length)] = state.you }
            r.bestStreak = max(r.bestStreak, state.bestStreak)
            guard asked > 0 else { return }
            r.played += 1
            r.you += state.you
            r.companion += state.companion
            r.history = Array(([TriviaRecords.Game(date: Date(), topic: state.madeTopic ?? state.topic, asked: asked, you: state.you, companion: state.companion)]
                + r.history).prefix(10))
        }
        if state.record { events.append(.newBest(state.you)) }
        let outcome = outcome(of: state) ?? .draw
        events.append(.matchOver(winner: outcome == .won ? .you : outcome == .lost ? .companion : nil))
        if asked > 0 { PlaytimeRecords.finish(TriviaScreen.id, outcome, you: state.you, companion: state.companion, best: state.length == 10 ? state.you : nil) }
        return events
    }
}
