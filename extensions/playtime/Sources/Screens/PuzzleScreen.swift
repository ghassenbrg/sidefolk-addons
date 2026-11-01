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

/// The four logic puzzles played alone (D79, the puzzles): a daily board for each level, the same for everyone on a
/// date and kept as far as played; a puzzle opens on today's board at the level asked for (or last picked), and once
/// that one is solved deals practice boards at it. The clock runs while the board is open; a hint is the next forced
/// move with its reason, and "Do it" (or H again) plays it; Undo and Start over; a best time per level (without
/// hints), one daily streak and the practice tally in Playtime's records.
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

    enum Action { case move(K.Rules.Move), hint, doHint, undo, clear, another(GameLevel?) }

    /// Now, on the clock Daily Word reads (tests set another).
    static var seconds: Double { DailyWordEngine.now().timeIntervalSince1970 }

    static func start(level: GameLevel, options: GameOptions, random: inout Games.Random) -> State {
        let picked = options.asked ?? PlaytimeRecords.puzzle(K.id).lastLevel.flatMap(GameLevel.init(rawValue:)) ?? level
        return State(game: deal(picked, random: &random, at: seconds))
    }

    /// Today's board at `level` while it isn't solved (as far as it was played), else a practice board at that level.
    static func deal(_ level: GameLevel, random: inout Games.Random, at t: Double) -> Games.PuzzleGame<K.Rules> {
        let day = DailyWordEngine.today()
        guard !PlaytimeRecords.puzzle(K.id).solved(level, day: day) else {
            return Games.PuzzleGame(K.Rules.generate(level: level, using: &random), at: t)
        }
        if var kept = PlaytimeRecords.puzzleDay(K.id, level: level, as: Games.PuzzleGame<K.Rules>.self), kept.day == day, kept.level == level {
            kept.resume(at: t)
            return kept
        }
        return Games.PuzzleGame(K.Rules.daily(day: day, level: level), day: day, at: t)
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
        case .doHint:
            // The hint shown, played: it was counted when it was asked for.
            guard let hint = s.hint else { throw Games.Refusal("not_now") }
            events = try s.game.play(hint.move, at: t)
            s.hint = nil
            s.fresh = K.cell(of: hint.move)
        case .undo:
            events = try s.game.undo(at: t)
            (s.hint, s.fresh) = (nil, nil)
        case .clear:
            events = try s.game.clear(at: t)
            (s.hint, s.fresh) = (nil, nil)
        case .another(let picked):
            guard s.game.solved || picked != nil else { throw Games.Refusal("not_now") }
            let level = picked ?? s.game.level
            PlaytimeRecords.pickPuzzleLevel(K.id, level)
            // "Play another" is a practice board; a level picked is that level's board of the day while it is open.
            s = State(game: picked == nil ? Games.PuzzleGame(K.Rules.generate(level: level, using: &random), at: t) : deal(level, random: &random, at: t))
            return [.turn(.you)]
        }
        if s.game.solved, !s.recorded {
            let time = Int(s.game.elapsed(at: t).rounded())
            s.recorded = true
            s.newBest = PlaytimeRecords.finishPuzzle(K.id, level: s.game.level, day: s.game.day, seconds: time, hints: s.game.hints)
            PlaytimeRecords.finish(K.id, .won, you: time, companion: 0)
            if s.newBest { events.append(.newBest(time)) }
        }
        if s.game.day != nil { keep(s.game, at: t) }
        return events
    }

    /// Today's board is kept as far as played, its clock stopped at this move, so reopening it carries on.
    static func keep(_ game: Games.PuzzleGame<K.Rules>, at t: Double) {
        var kept = game
        kept.pause(at: t)
        PlaytimeRecords.keepPuzzleDay(K.id, level: game.level, kept)
    }

    static func outcome(of s: State) -> GameOutcome? { s.game.solved ? .won : nil }
}

enum PuzzleScreen<K: PuzzleKind>: GameScreen {
    typealias Engine = PuzzleEngine<K>
    static var id: String { K.id }

    static func action(for move: Move, in s: Engine.State) -> Engine.Action? {
        switch move {
        case .button("hint"): .hint
        case .button("do_hint"): .doHint
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
            let line = s.newBest ? L("A new best for {level}!", ["level": ScreenKit.level(g.level)]) : g.day.map { dayLine(record, day: $0) } ?? L("Solved!")
            parts.append(ScreenKit.result(.won, figure: PuzzleParts.clock(time), line: line, ribbon: s.newBest ? L("New best") : nil, facts: facts,
                                          companion: o.companion,
                                          actions: [GameButton(L("Play another"), move: "another", style: .primary, symbol: "arrow.clockwise")]))
            parts.append(ScreenKit.levels(g.level))
        } else {
            // A hint shown: the same place (and H again) plays it.
            parts.append(s.hint == nil ? .button(GameButton(L("Hint"), move: "hint", style: .plain, symbol: "lightbulb", key: "h"))
                : .button(GameButton(L("Do it"), move: "do_hint", style: .plain, symbol: "wand.and.stars", key: "h")))
            parts.append(.button(GameButton(L("Undo"), move: "undo", style: .plain, symbol: "arrow.uturn.backward", key: "u", disabled: !g.canUndo)))
            parts.append(.button(GameButton(L("Start over"), move: "clear", style: .plain, symbol: "arrow.counterclockwise",
                                            disabled: g.grid == g.puzzle.start)))
        }
        return Board(parts, companion: cue(events, s), over: g.solved)
    }

    /// A puzzle's companion is calm: a nod for a hint, a thoughtful look at a broken rule, a celebration only for the solve.
    static func cue(_ events: [Games.Event], _ s: Engine.State) -> Cue? {
        if events.contains(.roundOver(winner: .you)) {
            // Not "you win": nobody lost. A line only for a new best.
            return Cue(move: "celebrate", effect: "confetti", line: s.newBest ? "record" : nil, sound: "fanfare", look: "you")
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

    /// The end card's line after a daily board: the levels whose board of the day is still open, or come back tomorrow.
    static func dayLine(_ record: Games.PuzzleRecord, day: Int) -> String {
        let open = GameLevel.allCases.filter { !record.solved($0, day: day) }.map(ScreenKit.level)
        return open.isEmpty ? L("All three of today's boards are solved. Come back tomorrow for new ones.")
            : L(one: "Today's {levels} board is still waiting.", other: "Today's {levels} boards are still waiting.", count: open.count,
                ["levels": Format.list(open)])
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
