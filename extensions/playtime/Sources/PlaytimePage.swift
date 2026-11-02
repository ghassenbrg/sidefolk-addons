import Foundation
import SidefolkExtensionKit

/// Playtime's page in Home and its Today tile: the Game Center, built here from the extension's own records (Sidefolk D100, D101). A hero with the companion and the
/// one big action (continue the game put away, today's daily, or a surprise), the day's boards, every game as a card in its group, the person's numbers, last games and
/// badges, and the games' settings in one place. A new game in the catalog is a new card in its group, nothing else.
enum PlaytimePage {
    /// The puzzles, by id and title.
    static var puzzles: [(id: String, title: String)] {
        [(GardenPlotsKind.id, L("Garden Plots")), (SeesawKind.id, L("Seesaw")), (SudokuKind.id, L("Sudoku")), (BlossomsKind.id, L("Blossoms"))]
    }

    @MainActor static func render() -> Page {
        let r = PlaytimeRecords.load()
        let today = DailyWordEngine.today()
        let tile = DailyWordScreen.tile()
        return Page(summary: summary(today: today, tile: tile), sections: GameCenterPage.sections(records(r, today: today, tile: tile), history: r.history, duels: duels(r)))
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

    /// A game's numbers.
    struct Record {
        var played = 0, won = 0, lost = 0, drawn = 0, streak = 0, bestStreak = 0
        var best: String?
        var today: (text: String, done: Bool, streak: Int)?
    }

    /// Each game's record for the Game Center.
    static func records(_ r: PlaytimeRecords, today: Int, tile: [String]) -> [String: Record] {
        let ids = Set(GameCatalog.all.map(\.id))
        var out: [String: Record] = [:]
        for (id, t) in r.games where ids.contains(id) {
            out[id] = Record(played: t.played, won: t.won, lost: t.lost, drawn: t.drawn, streak: t.streak, bestStreak: t.bestStreak, best: best(id, t))
        }
        // Daily Word: the day's word and its streak in days, with the practice words played beside it.
        var word = out[DailyWordScreen.id] ?? Record()
        word.today = (tile[0], r.daily.lastDay == today, r.daily.tile(today: today).streak)
        word.bestStreak = max(word.bestStreak, r.daily.best)
        if let practice = r.games[DailyWordScreen.practiceId], practice.played > 0 {
            word.best = [word.best, L(one: "{count} practice word", other: "{count} practice words", count: practice.played)]
                .compactMap { $0 }.joined(separator: " · ")
        }
        out[DailyWordScreen.id] = word
        for p in puzzles { out[p.id] = puzzle(p.id, today: today) }
        return out
    }

    /// Two people's head-to-heads (D96), the latest first.
    static func duels(_ r: PlaytimeRecords) -> [(game: String, names: [String], wins: [Int])] {
        (r.duels ?? [:]).flatMap { game, pairs in pairs.map { (game, $0.key, $0.value) } }
            .sorted { ($0.2.last ?? .distantPast) > ($1.2.last ?? .distantPast) }.prefix(10)
            .compactMap { game, pair, d in
                let names = pair.components(separatedBy: " · ")
                return names.count == 2 ? (game, names, names.map { d.wins[$0] ?? 0 }) : nil
            }
    }

    /// A puzzle: boards solved, today's boards (each level solved with its time, how many are left), the daily streak
    /// and the best time per level.
    static func puzzle(_ id: String, today: Int) -> Record {
        let r = PlaytimeRecords.puzzle(id)
        let tile = r.tile(today: today)
        let count = r.dailies + r.practice.values.reduce(0, +)
        let solved = tile.solved.map { ScreenKit.level($0.level) + " " + PuzzleParts.clock($0.seconds) }
        var line = solved.isEmpty ? L(one: "Today: {count} board to play", other: "Today: {count} boards to play", count: GameLevel.allCases.count)
            : L("Today: {solved}", ["solved": solved.joined(separator: ", ")])
        if !solved.isEmpty, tile.left > 0 { line += " · " + L(one: "{count} more to play", other: "{count} more to play", count: tile.left) }
        let bests = GameLevel.allCases.compactMap { l in r.best[l.rawValue].map { ScreenKit.level(l) + " " + PuzzleParts.clock($0) } }
        return Record(played: count, won: count, streak: tile.streak, bestStreak: r.bestStreak,
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
