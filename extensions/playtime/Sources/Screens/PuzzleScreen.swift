import Foundation
import SidefolkExtensionKit

/// What one puzzle adds to the four's shared screen: its words and how its marks become Sidefolk's puzzle part.
protocol PuzzleKind {
    associatedtype Rules: PuzzleRules

    static var id: String { get }
    /// The rules in one or two short sentences, said by the companion while there is nothing else to say.
    static var rules: String { get }
    static func reason(_ reason: Rules.Reason) -> String
    static func rule(_ rule: Rules.Rule) -> String
    /// The person's move on the board, in the puzzle's terms.
    static func move(_ move: Move, in game: Games.PuzzleGame<Rules>) -> Rules.Move?
    /// The cell a move plays, so its mark settles in.
    static func cell(of move: Rules.Move) -> Int?
    /// The grid: marks, conflicts lit, the hint's cells and its move shown faintly.
    static func part(_ game: Games.PuzzleGame<Rules>, hint: Games.PuzzleHint<Rules.Move, Rules.Reason>?, fresh: Int?, now: Double) -> BoardPart
}

/// The four logic puzzles played alone (D79, the puzzles): today's board first, the same for everyone on a date and
/// kept as far as played; once it's solved, "Play another" deals practice boards at the level picked. The clock runs
/// while the board is open; a hint is the next forced move with its reason; Undo and Start over; a best time per level
/// (without hints), the daily streak and the practice tally in Playtime's records.
enum PuzzleEngine<K: PuzzleKind>: GameEngine {
    struct State: Codable {
        var game: Games.PuzzleGame<K.Rules>
        var hint: Games.PuzzleHint<K.Rules.Move, K.Rules.Reason>?
        /// The cell just played, so its mark settles in.
        var fresh: Int?
        /// The solve was written to the records, and whether its time was a new best.
        var recorded = false
        var newBest = false
    }

    enum Action { case move(K.Rules.Move), hint, undo, clear, another(GameLevel?) }

    /// Now, on the clock Daily Word reads (tests set another).
    static var seconds: Double { DailyWordEngine.now().timeIntervalSince1970 }

    static func start(level: GameLevel, options: GameOptions, random: inout Games.Random) -> State {
        let day = DailyWordEngine.today()
        if PlaytimeRecords.puzzle(K.id).lastSolvedDay != day {
            if var kept = PlaytimeRecords.puzzleDay(K.id, as: Games.PuzzleGame<K.Rules>.self), kept.day == day {
                kept.resume(at: seconds)
                return State(game: kept)
            }
            return State(game: Games.PuzzleGame(K.Rules.daily(day: day), day: day, at: seconds))
        }
        let practice = PlaytimeRecords.puzzle(K.id).lastLevel.flatMap(GameLevel.init(rawValue:)) ?? level
        return State(game: Games.PuzzleGame(K.Rules.generate(level: practice, using: &random), at: seconds))
    }

    static func play(_ action: Action, on s: inout State, random: inout Games.Random) throws -> [Games.Event] {
        let t = seconds
        var events: [Games.Event]
        switch action {
        case .move(let move):
            events = try s.game.play(move, at: t)
            s.hint = nil
            s.fresh = K.cell(of: move)
        case .hint:
            let (hint, e) = try s.game.hint(at: t)
            s.hint = hint
            s.fresh = nil
            events = e
        case .undo:
            events = try s.game.undo(at: t)
            (s.hint, s.fresh) = (nil, nil)
        case .clear:
            events = try s.game.clear(at: t)
            (s.hint, s.fresh) = (nil, nil)
        case .another(let picked):
            guard s.game.solved || picked != nil else { throw Games.Refusal("not_now") }
            let level = picked ?? s.game.level
            PlaytimeRecords.update { r in
                var record = r.puzzles?[K.id] ?? Games.PuzzleRecord()
                record.lastLevel = level.rawValue
                r.puzzles = (r.puzzles ?? [:]).merging([K.id: record]) { $1 }
            }
            s = State(game: Games.PuzzleGame(K.Rules.generate(level: level, using: &random), at: t))
            return [.turn(.you)]
        }
        if s.game.solved, !s.recorded {
            let time = Int(s.game.elapsed(at: t).rounded())
            s.recorded = true
            s.newBest = PlaytimeRecords.finishPuzzle(K.id, level: s.game.level, day: s.game.day, seconds: time, hints: s.game.hints)
            PlaytimeRecords.finish(K.id, .won, you: time, companion: 0)
            if s.newBest { events.append(.newBest(time)) }
        }
        // Today's board is kept as far as played, its clock stopped at this move, so reopening it carries on.
        if s.game.day != nil {
            var kept = s.game
            kept.pause(at: t)
            PlaytimeRecords.update { r in r.puzzleDays = (r.puzzleDays ?? [:]).merging([K.id: PlaytimeRecords.encode(kept)]) { $1 } }
        }
        return events
    }

    static func outcome(of s: State) -> GameOutcome? { s.game.solved ? .won : nil }
}

enum PuzzleScreen<K: PuzzleKind>: GameScreen {
    typealias Engine = PuzzleEngine<K>
    static var id: String { K.id }

    static func action(for move: Move, in s: Engine.State) -> Engine.Action? {
        switch move {
        case .button("hint"): .hint
        case .button("undo"): .undo
        case .button("clear"): .clear
        case .button("another"): .another(nil)
        case .choice("level", let l): GameLevel(rawValue: l).map { .another($0) }
        default: K.move(move, in: s.game).map { .move($0) }
        }
    }

    static func board(_ s: Engine.State, events: [Games.Event], options o: GameOptions) -> Board {
        let g = s.game, t = Engine.seconds
        let time = Int(g.elapsed(at: t).rounded())
        let eyebrow = (g.day != nil ? L("Today's puzzle") : L("Practice")) + " · " + ScreenKit.level(g.level)
        let conflicts = g.conflicts
        let text: String = if g.solved { L("Solved in {time}!", ["time": PuzzleParts.clock(time)]) }
            else if let hint = s.hint { K.reason(hint.reason) }
            else if let first = conflicts.first, events.contains(.mistake) || !conflicts.isEmpty { K.rule(first.rule) }
            else { K.rules }
        var parts: [BoardPart] = [.prompt(text, eyebrow: eyebrow), K.part(g, hint: s.hint, fresh: s.fresh, now: t)]
        if let note = refusal(events) { parts.append(note) }
        if g.solved {
            let record = PlaytimeRecords.puzzle(K.id)
            var facts = [(L("Time"), PuzzleParts.clock(time)), (L("Hints"), Format.integer(g.hints))]
            if let best = record.best[g.level.rawValue] { facts.append((L("Best"), PuzzleParts.clock(best))) }
            if g.day != nil { facts.append((L("Streak"), Format.integer(record.streak))) }
            let line = s.newBest ? L("A new best for {level}!", ["level": ScreenKit.level(g.level)])
                : g.day != nil ? L("Today's puzzle is solved. Come back tomorrow for a new one.") : L("Solved!")
            parts.append(ScreenKit.result(.won, figure: PuzzleParts.clock(time), line: line, ribbon: s.newBest ? L("New best") : nil, facts: facts,
                                          companion: o.companion,
                                          actions: [GameButton(L("Play another"), move: "another", style: .primary, symbol: "arrow.clockwise")]))
            parts.append(ScreenKit.levels(g.level))
        } else {
            parts.append(.button(GameButton(L("Hint"), move: "hint", style: .plain, symbol: "lightbulb", key: "h")))
            parts.append(.button(GameButton(L("Undo"), move: "undo", style: .plain, symbol: "arrow.uturn.backward", key: "u", disabled: !g.canUndo)))
            parts.append(.button(GameButton(L("Start over"), move: "clear", style: .plain, symbol: "arrow.counterclockwise",
                                            disabled: g.grid == g.puzzle.start)))
        }
        return Board(parts, companion: cue(events, s), over: g.solved)
    }

    /// A puzzle's companion is calm: a nod for a hint, a thoughtful look at a broken rule, a celebration only for the solve.
    static func cue(_ events: [Games.Event], _ s: Engine.State) -> Cue? {
        if events.contains(.roundOver(winner: .you)) {
            return Cue(move: "celebrate", effect: "confetti", line: s.newBest ? "record" : "you_win", sound: "fanfare", look: "you")
        }
        if events.contains(.mistake) { return Cue(move: "think", effect: "question", look: "panel") }
        if events.contains(.hint) { return Cue(move: "nod", line: "hint_intro", sound: "whoosh", look: "panel") }
        if events.contains(.opened) { return Cue(move: "ready", line: "hello", look: "panel") }
        return events.contains { if case .refused = $0 { true } else { false } } ? Cue(move: "shrug") : nil
    }

    static func refusal(_ events: [Games.Event]) -> BoardPart? {
        for case .refused(let reason) in events {
            switch reason {
            case "given": return .note(L("That one is part of the puzzle."), tone: .info)
            case "nothing_to_undo": return .note(L("Nothing to undo."), tone: .info)
            default: return ScreenKit.refusal(events)
            }
        }
        return nil
    }

    /// The Home row's words and the Today tile's: today's board, the streak, the best times.
    static func detail() -> String {
        let r = PlaytimeRecords.puzzle(K.id)
        let today = DailyWordEngine.today()
        let tile = r.tile(today: today)
        var parts = [tile.solved ? L("Today: solved in {time}", ["time": PuzzleParts.clock(tile.seconds ?? 0)]) : L("Today: not played yet")]
        if tile.streak > 1 { parts.append(L("Streak {n}", ["n": tile.streak])) }
        let bests = GameLevel.allCases.compactMap { l in r.best[l.rawValue].map { ScreenKit.level(l) + " " + PuzzleParts.clock($0) } }
        if !bests.isEmpty { parts.append(L("Best: {times}", ["times": bests.joined(separator: ", ")])) }
        return parts.joined(separator: " · ")
    }
}

/// Labels every puzzle's grid shares.
enum PuzzleParts {
    /// 3:07, or 1:02:07 past an hour.
    static func clock(_ seconds: Int) -> String {
        seconds >= 3600 ? String(format: "%d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60)
            : String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    static func label(_ cell: Int, columns: Int, _ what: String?) -> String {
        L("Row {r}, column {c}", ["r": cell / columns + 1, "c": cell % columns + 1]) + (what.map { ", " + $0 } ?? "")
    }
}
