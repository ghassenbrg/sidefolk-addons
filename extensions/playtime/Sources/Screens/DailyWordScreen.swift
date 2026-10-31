import Foundation
import SidefolkExtensionKit

/// Daily Word: one word a day in the person's language, six tries, the same word for everyone whose calendar shows that
/// date. The day's rows are kept, so reopening it shows them; the streak and the Today tile come from its record. Once
/// the day's word is over, "Play another word" plays practice words, as many as the person likes: kept only in the
/// session and in a tally of their own (`practiceId`), never in the streak, the tile or the day's rows.
enum DailyWordEngine: GameEngine {
    struct State: Codable, Equatable {
        var game: Games.DailyWord
        /// The word's hint: which place, and its letter.
        var hintPlace: Int?
        var hintShown: String?
        /// A practice word, not the day's (optional, so a session from an older Playtime still reads).
        var practice: Bool?

        var isPractice: Bool { practice == true }
    }

    enum Action: Equatable { case word(String), hint, practice }

    /// The date it is for the person; tests set another.
    nonisolated(unsafe) static var now: () -> Date = { Date() }

    /// Today on the person's own calendar, as Daily Word counts days.
    static func today(_ date: Date = now(), calendar: Calendar = .current) -> Int {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return Games.DailyWord.day(year: c.year ?? 2026, month: c.month ?? 1, day: c.day ?? 1)
    }

    static func start(level: GameLevel, options: GameOptions, random: inout Games.Random) -> State {
        let day = today(), language = options.gamesLanguage
        if let kept = PlaytimeRecords.load().dailyGame, kept.day == day, kept.language == language { return State(game: kept) }
        return State(game: Games.DailyWord(language: language, day: day))
    }

    static func play(_ action: Action, on s: inout State, random: inout Games.Random) throws -> [Games.Event] {
        let events: [Games.Event]
        switch action {
        case .word(let w): events = try s.game.guess(w)
        case .hint:
            let (place, shown, e) = try s.game.hint()
            (s.hintPlace, s.hintShown) = (place, shown)
            events = e
        case .practice:
            // Only after a word is over: the day's is played first.
            guard s.game.over else { throw Games.Refusal("not_now") }
            let language = s.game.language, day = today()
            let (word, played) = Games.DailyWord.practiceWord(language: language, day: day,
                                                              played: PlaytimeRecords.load().practiceWords?[language.key] ?? [], using: &random)
            PlaytimeRecords.update { $0.practiceWords = ($0.practiceWords ?? [:]).merging([language.key: played]) { $1 } }
            s = State(game: Games.DailyWord(language: language, day: day, word: word), practice: true)
            return [.turn(.you)]
        }
        let game = s.game
        if s.isPractice {
            if game.over {
                PlaytimeRecords.finish(DailyWordScreen.practiceId, game.solved ? .won : .lost, you: game.solved ? game.rows.count : 0, companion: 0,
                                       best: game.solved ? game.rows.count : nil, lower: true)
            }
            return events
        }
        PlaytimeRecords.update { r in
            r.dailyGame = game
            if game.over, r.daily.lastDay != game.day {
                r.daily.finish(game)
            }
        }
        if game.over {
            PlaytimeRecords.finish(DailyWordScreen.id, game.solved ? .won : .lost, you: game.solved ? game.rows.count : 0, companion: 0,
                                   best: game.solved ? game.rows.count : nil, lower: true)
        }
        return events
    }

    static func outcome(of s: State) -> GameOutcome? { s.game.over ? (s.game.solved ? .won : .lost) : nil }
}

enum DailyWordScreen: GameScreen {
    typealias Engine = DailyWordEngine
    static let id = "daily_word"
    /// Practice words' tally and Home rows, apart from the day's.
    static let practiceId = "daily_word_practice"

    static func action(for move: Move, in s: DailyWordEngine.State) -> DailyWordEngine.Action? {
        switch move {
        case .word(let w): .word(w)
        case .button("hint"): .hint
        case .button("practice"): .practice
        default: nil
        }
    }

    static func board(_ s: DailyWordEngine.State, events: [Games.Event], options o: GameOptions) -> Board {
        let g = s.game
        let language = g.language
        let rows = g.rows.map { row in
            zip(row.units, row.marks).map { LetterTile($0.shown, mark: $1.rawValue, group: $0.group) }
        }
        let played = events.contains(.reveal)
        let marks = g.keyMarks
        let text: String = if g.solved { L("Solved in {n}!", ["n": g.rows.count]) }
            else if g.over { s.isPractice ? L("The word was {word}.", ["word": g.shown ?? ""]) : L("Today's word was {word}.", ["word": g.shown ?? ""]) }
            else if let shown = s.hintShown, let place = s.hintPlace { L("Hint: letter {n} is {letter}.", ["n": place + 1, "letter": shown]) }
            else if s.isPractice { L("Guess this word in six tries.") }
            else { L("Guess today's word in six tries.") }
        var parts: [BoardPart] = [
            .prompt(text, eyebrow: s.isPractice ? L("Practice word · not in your streak")
                                                : L("Daily Word · {date}", ["date": Format.date(DailyWordEngine.now())])),
            .play(.letters(rows: rows, length: g.length, tries: Games.DailyWord.tries, draft: !g.over, flip: played ? rows.count - 1 : nil,
                           script: Keyboards.script(language))),
        ]
        if !g.over {
            if let keys = Keyboards.part(language, for: .daily, mode: "spell", length: g.length, mark: { marks[$0]?.rawValue ?? "none" }) {
                parts.append(keys)
            } else {
                // Chinese idioms are typed with the input method.
                parts.append(.play(.entry(name: "word", kind: "word", label: L("Four characters"), placeholder: L("Type an idiom"), button: L("Try"),
                                          max: g.length)))
            }
        }
        if let note = ScreenKit.refusal(events) { parts.append(note) }
        if let outcome = DailyWordEngine.outcome(of: s) {
            let records = PlaytimeRecords.load()
            let r = records.daily
            let missed = s.isPractice ? L("{name} didn't get it either.", ["name": o.companion]) : L("{name} didn't get it either. Tomorrow!", ["name": o.companion])
            // The day's streak is the same after a practice word: shown beside the practice tally, untouched.
            let practice = records.games[practiceId]
            let facts: [(String, String)] = s.isPractice
                ? [(L("Streak"), Format.integer(r.streak)), (L("Practice words"), Format.integer(practice?.played ?? 0)),
                   (L("Solved"), Format.integer(practice?.won ?? 0))]
                : [(L("Streak"), Format.integer(r.streak)), (L("Best streak"), Format.integer(r.best)), (L("Played"), Format.integer(r.played))]
            // Today's word stays once a day; more words to play come after it, at random and as many as wanted.
            parts.append(ScreenKit.result(outcome, figure: g.shown ?? "", line: outcome == .won ? L("Solved in {n}!", ["n": g.rows.count]) : missed,
                                          facts: facts, companion: o.companion,
                                          actions: [GameButton(L("Play another word"), move: "practice", style: .primary, symbol: "arrow.clockwise")]))
        } else if s.hintPlace == nil, !g.rows.isEmpty {
            parts.append(.button(GameButton(L("A hint"), move: "hint", style: .plain, symbol: "lightbulb")))
        }
        var cue = EventCues.cue(events)
        if played, !g.over, let greens = g.rows.last?.marks.filter({ $0 == .right }).count {
            cue = greens >= 4 ? Cue(move: "gasp", effect: "exclaim", line: "close_one") : greens >= 2 ? Cue(move: "cheer", line: "encourage") : Cue(move: "nod")
        }
        return Board(parts, companion: cue, over: g.over)
    }

    /// The Today tile's lines: not played yet, solved in 4, missed, and the streak while it's alive.
    static func tile() -> [String] {
        let r = PlaytimeRecords.load().daily
        let t = r.tile(today: DailyWordEngine.today())
        let first: String = switch t.state {
        case .notPlayed: L("Not played yet")
        case .solved(let n): L("Solved in {n}", ["n": n])
        case .missed: L("Missed today")
        }
        return [first] + (t.streak > 1 ? [L("Streak {n}", ["n": t.streak])] : [])
    }
}
