import Foundation
import SidefolkExtensionKit

/// Playtime's page in Home and its Today tile. Sidefolk draws the page itself as the Game Center (Sidefolk D93) from
/// the records sent here: each game's tallies and best in its own words, each daily's state and streak, and the last
/// ten games; the art, layout, buttons and settings are Sidefolk's. The summary is the Today tile: Daily Word, played
/// or not, and the puzzles' streaks still alive.
enum PlaytimePage {
    struct Game {
        let id: String
        let title: String
        let symbol: String
    }

    /// Every game with its title in the person's language (the sample boards' titles too).
    static var games: [Game] {
        [Game(id: DailyWordScreen.id, title: L("Daily Word"), symbol: "textformat.abc"),
         Game(id: TriviaScreen.id, title: L("Trivia"), symbol: "questionmark.bubble.fill"),
         Game(id: TicTacToeScreen.id, title: L("Tic-tac-toe"), symbol: "number"),
         Game(id: CopyMeScreen.id, title: L("Copy Me"), symbol: "figure.dance"),
         Game(id: QuickPawsScreen.id, title: L("Quick Paws"), symbol: "bolt.fill"),
         Game(id: WhichCupScreen.id, title: L("Which Cup?"), symbol: "cup.and.saucer.fill"),
         Game(id: HigherLowerScreen.id, title: L("Higher or Lower"), symbol: "arrow.up.arrow.down"),
         Game(id: GuessAnimalScreen.id, title: L("Guess My Animal"), symbol: "pawprint.fill"),
         Game(id: BalloonWordsScreen.id, title: L("Balloon Words"), symbol: "balloon.2.fill"),
         Game(id: LastStickScreen.id, title: L("Last Stick"), symbol: "line.3.horizontal"),
         Game(id: MemoryPairsScreen.id, title: L("Memory Pairs"), symbol: "square.grid.2x2.fill"),
         Game(id: GardenPlotsKind.id, title: L("Garden Plots"), symbol: "square.split.2x2.fill"),
         Game(id: SeesawKind.id, title: L("Seesaw"), symbol: "heart.circle.fill"),
         Game(id: SudokuKind.id, title: L("Sudoku"), symbol: "square.grid.3x3.fill"),
         Game(id: BlossomsKind.id, title: L("Blossoms"), symbol: "camera.macro")]
    }

    /// The puzzles, by id and title.
    static var puzzles: [(id: String, title: String)] {
        [(GardenPlotsKind.id, L("Garden Plots")), (SeesawKind.id, L("Seesaw")), (SudokuKind.id, L("Sudoku")), (BlossomsKind.id, L("Blossoms"))]
    }

    static func render() -> Page {
        let r = PlaytimeRecords.load()
        let today = DailyWordEngine.today()
        let tile = DailyWordScreen.tile()
        return Page(summary: summary(today: today, tile: tile), games: records(r, today: today, tile: tile))
    }

    /// The Today tile: Daily Word, then the word's streak, how many of the puzzles' boards of the day are solved (one
    /// per puzzle and level), and each puzzle's streak still alive.
    static func summary(today: Int, tile: [String]) -> Summary {
        let days = puzzles.map { PlaytimeRecords.puzzle($0.id).tile(today: today) }
        let boards = puzzles.count * GameLevel.allCases.count, solved = days.reduce(0) { $0 + $1.solved.count }
        var line = tile.count > 1 ? [tile[1]] : []
        if solved > 0 { line.append(L("Puzzles today: {n} of {total}", ["n": solved, "total": boards])) }
        line += zip(puzzles, days).compactMap { p, day in day.streak > 1 ? p.title + " " + Format.integer(day.streak) : nil }
        let detail = line.isEmpty
            ? L(one: "A new word and {count} puzzle board every day", other: "A new word and {count} puzzle boards every day", count: boards)
            : line.joined(separator: " · ")
        return Summary(L("Daily Word: {state}", ["state": tile[0]]), detail: detail, symbol: "textformat.abc")
    }

    /// Each game's record for the Game Center, and the last games.
    static func records(_ r: PlaytimeRecords, today: Int, tile: [String]) -> GameRecords {
        let ids = Set(games.map(\.id))
        var out: [String: GameRecords.Record] = [:]
        for (id, t) in r.games where ids.contains(id) {
            out[id] = GameRecords.Record(played: t.played, won: t.won, lost: t.lost, drawn: t.drawn, streak: t.streak, bestStreak: t.bestStreak,
                                         best: best(id, t))
        }
        // Daily Word: the day's word and its streak in days, with the practice words played beside it.
        var word = out[DailyWordScreen.id] ?? GameRecords.Record()
        word.today = (tile[0], r.daily.lastDay == today, r.daily.tile(today: today).streak)
        word.bestStreak = max(word.bestStreak, r.daily.best)
        if let practice = r.games[DailyWordScreen.practiceId], practice.played > 0 {
            word.best = [word.best, L(one: "{count} practice word", other: "{count} practice words", count: practice.played)]
                .compactMap { $0 }.joined(separator: " · ")
        }
        out[DailyWordScreen.id] = word
        for p in puzzles { out[p.id] = puzzle(p.id, today: today) }

        let recent = r.history.compactMap { p -> GameRecords.Recent? in
            // Higher or Lower's other way is its own tally (`higher_lower_yours`), shown under the game.
            guard ids.contains(p.game) || ids.contains(where: { p.game.hasPrefix($0 + "_") }) else { return nil }
            // A puzzle's row says its time (kept as `you`), not who won.
            if puzzles.contains(where: { $0.id == p.game }) {
                return GameRecords.Recent(game: p.game, at: p.date, outcome: .solved, text: L("Solved in {time}", ["time": PuzzleParts.clock(p.you)]))
            }
            let outcome: GameRecords.Outcome = switch p.outcome { case .won: .won; case .lost: .lost; case .draw: .draw }
            return GameRecords.Recent(game: p.game, at: p.date, outcome: outcome)
        }
        return GameRecords(records: out, recent: recent)
    }

    /// A puzzle: boards solved, today's boards (each level solved with its time, how many are left), the daily streak
    /// and the best time per level.
    static func puzzle(_ id: String, today: Int) -> GameRecords.Record {
        let r = PlaytimeRecords.puzzle(id)
        let tile = r.tile(today: today)
        let count = r.dailies + r.practice.values.reduce(0, +)
        let solved = tile.solved.map { ScreenKit.level($0.level) + " " + PuzzleParts.clock($0.seconds) }
        var line = solved.isEmpty ? L(one: "Today: {count} board to play", other: "Today: {count} boards to play", count: GameLevel.allCases.count)
            : L("Today: {solved}", ["solved": solved.joined(separator: ", ")])
        if !solved.isEmpty, tile.left > 0 { line += " · " + L(one: "{count} more to play", other: "{count} more to play", count: tile.left) }
        let bests = GameLevel.allCases.compactMap { l in r.best[l.rawValue].map { ScreenKit.level(l) + " " + PuzzleParts.clock($0) } }
        return GameRecords.Record(played: count, won: count, streak: tile.streak, bestStreak: r.bestStreak,
                                  best: bests.isEmpty ? nil : L("Best: {times}", ["times": bests.joined(separator: ", ")]),
                                  today: (line, !tile.solved.isEmpty, tile.streak))
    }

    /// A game's best in its own terms: the longest sequence, the quickest press, the fewest guesses, trivia's best of ten.
    static func best(_ id: String, _ t: PlaytimeRecords.Tally) -> String? {
        guard let best = t.best else { return nil }
        return switch id {
        case CopyMeScreen.id: L(one: "Best: {count} move", other: "Best: {count} moves", count: best)
        case QuickPawsScreen.id: L("Best: {n} ms", ["n": best])
        case HigherLowerScreen.id, DailyWordScreen.id: L(one: "Best: {count} guess", other: "Best: {count} guesses", count: best)
        case TriviaScreen.id: L("Best of 10: {n}", ["n": best])
        default: nil
        }
    }
}
