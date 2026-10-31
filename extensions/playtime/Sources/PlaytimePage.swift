import Foundation
import SidefolkExtensionKit

/// Playtime's page in Home (D62, D74) and its Today tile: Daily Word's day and streak on top with the button that
/// opens it (an `ask` part, reaching the game's sentence through Sidefolk), every game with its best, buttons to play
/// each, and the last ten games. The summary is the Today tile: Daily Word, played or not.
enum PlaytimePage {
    struct Game {
        let id: String
        let title: String
        let symbol: String
        /// The sentence its button asks, one of the manifest's `say`: commands stay English (D76).
        let ask: String
    }

    static var games: [Game] {
        [Game(id: DailyWordScreen.id, title: L("Daily Word"), symbol: "textformat.abc", ask: "daily word"),
         Game(id: TriviaScreen.id, title: L("Trivia"), symbol: "questionmark.bubble.fill", ask: "let's play trivia"),
         Game(id: TicTacToeScreen.id, title: L("Tic-tac-toe"), symbol: "number", ask: "let's play tic-tac-toe"),
         Game(id: CopyMeScreen.id, title: L("Copy Me"), symbol: "figure.dance", ask: "let's play copy me"),
         Game(id: QuickPawsScreen.id, title: L("Quick Paws"), symbol: "bolt.fill", ask: "let's play quick paws"),
         Game(id: WhichCupScreen.id, title: L("Which Cup?"), symbol: "cup.and.saucer.fill", ask: "let's play which cup"),
         Game(id: HigherLowerScreen.id, title: L("Higher or Lower"), symbol: "arrow.up.arrow.down", ask: "let's play higher or lower"),
         Game(id: GuessAnimalScreen.id, title: L("Guess My Animal"), symbol: "pawprint.fill", ask: "let's play guess my animal"),
         Game(id: BalloonWordsScreen.id, title: L("Balloon Words"), symbol: "balloon.2.fill", ask: "let's play balloon words"),
         Game(id: LastStickScreen.id, title: L("Last Stick"), symbol: "line.3.horizontal", ask: "let's play last stick"),
         Game(id: MemoryPairsScreen.id, title: L("Memory Pairs"), symbol: "square.grid.2x2.fill", ask: "let's play memory pairs")]
    }

    static func render() -> Page {
        let r = PlaytimeRecords.load()
        let tile = DailyWordScreen.tile()
        let won = r.games.values.reduce(0) { $0 + $1.won }, lost = r.games.values.reduce(0) { $0 + $1.lost }
        let hero = Hero(L("Daily Word: {state}", ["state": tile[0]]), eyebrow: L("Playtime"),
                        detail: L("Eleven games to play against your companion, no AI, in your language."), symbol: "gamecontroller.fill",
                        facts: [(L("Streak"), Format.integer(r.daily.tile(today: DailyWordEngine.today()).streak)),
                                (L("Your wins"), Format.integer(won)), (L("Your companion's"), Format.integer(lost))])
        var sections = [Section(nil, [.hero(hero), .ask(L("Play Daily Word"), "daily word")])]
        let rows = games.map { g -> Row in
            let t = r.games[g.id]
            return Row(g.title, detail: t.map { detail(g.id, $0) } ?? L("Not played yet"), symbol: g.symbol)
        }
        sections.append(Section(L("Your games"), [.list(nil, rows)]))
        sections.append(Section(L("Play"), games.dropFirst().map { .ask($0.title, $0.ask) }))
        if !r.history.isEmpty {
            let titles = Dictionary(uniqueKeysWithValues: games.map { ($0.id, $0) })
            let last = r.history.map { p -> Row in
                let outcome = switch p.outcome {
                case .won: L("You won")
                case .lost: L("Your companion won")
                case .draw: L("A draw")
                }
                return Row(titles[p.game]?.title ?? p.game, detail: [outcome, Format.date(p.date)].joined(separator: " · "),
                           symbol: p.outcome == .won ? "crown.fill" : p.outcome == .lost ? "hand.thumbsup" : "equal.circle")
            }
            sections.append(Section(L("Last games"), [.list(nil, last)]))
        }
        return Page(summary: Summary(L("Daily Word: {state}", ["state": tile[0]]), detail: tile.count > 1 ? tile[1] : L("A new word every day"),
                                     symbol: "textformat.abc"),
                    sections: sections)
    }

    /// A game's best in its own terms: the longest sequence, the quickest press, the fewest guesses, wins.
    static func detail(_ id: String, _ t: PlaytimeRecords.Tally) -> String {
        var parts = [L(one: "{count} game", other: "{count} games", count: t.played)]
        if let best = t.best {
            switch id {
            case CopyMeScreen.id: parts.append(L(one: "Best: {count} move", other: "Best: {count} moves", count: best))
            case QuickPawsScreen.id: parts.append(L("Best: {n} ms", ["n": best]))
            case HigherLowerScreen.id, DailyWordScreen.id: parts.append(L(one: "Best: {count} guess", other: "Best: {count} guesses", count: best))
            case TriviaScreen.id: parts.append(L("Best of 10: {n}", ["n": best]))
            default: break
            }
        }
        if id != CopyMeScreen.id { parts.append(L("Won {n}", ["n": t.won])) }
        if t.bestStreak > 1 { parts.append(L("Best streak {n}", ["n": t.bestStreak])) }
        return parts.joined(separator: " · ")
    }
}
