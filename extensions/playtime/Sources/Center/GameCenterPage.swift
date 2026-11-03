import Foundation
import SidefolkExtensionKit

/// The Game Center's sections (GameCenterView, GameCenterParts, GameCenterRecords, GameCenterSettings), on the parts any page has (D100). Nothing is made up: a badge is
/// earned from these numbers or shown with how far there is to go. Everything it starts is the tool `open`, as the person's own click.
@MainActor
enum GameCenterPage {
    typealias Record = PlaytimePage.Record

    struct Totals {
        var wins = 0, solved = 0, played = 0, bestStreak = 0, dailyStreak = 0
    }

    static func sections(_ records: [String: Record], history: [PlaytimeRecords.Played], duels: [(game: String, names: [String], wins: [Int])]) -> [Section] {
        let entries = GameCatalog.all
        func record(_ e: GameEntry) -> Record { records[e.id] ?? Record() }
        var totals = Totals()
        for e in entries {
            let r = record(e)
            if e.solo { totals.solved += r.won } else { totals.wins += r.won }
            totals.played += r.played
            totals.bestStreak = max(totals.bestStreak, r.bestStreak)
            totals.dailyStreak = max(totals.dailyStreak, r.today?.streak ?? 0)
        }
        let dailies = entries.filter { record($0).today != nil }
        let kept = PlayTable.keptGame
        // The page as one picture, its text, tiles and numbers live; what the design leaves out stays a click away, folded beneath it.
        var out: [Section] = [Section(nil, [.scene(PlaytimeHome.block(totals: totals, dailies: dailies, record: record, kept: kept, history: history))])]
        let versus = entries.filter { TwoPlayers.games.contains($0.id) }
        if !versus.isEmpty {
            out.append(Section(L("2 players"), [.cards(size: .small, versus.map { e in
                Card(e.title, detail: L("Play against a friend on this Mac"), picture: picture(e), color: e.look.bottom.json as? String,
                     actions: [Action(L("Play"), tool: "open", input: ["game": e.id, "players": 2, "person": true], symbol: "person.2.fill", round: true)])
            })], collapsed: true))
        }
        out.append(Section(L("Last games"), [lastGames(history)], collapsed: true))
        if !duels.isEmpty {
            out.append(Section(L("Head to head"), [.facts(nil, duels.map { d in
                (GameCatalog.entry(d.game)?.title ?? d.game, "\(d.names[0]) \(Format.integer(d.wins[0])) · \(d.names[1]) \(Format.integer(d.wins[1]))")
            })], collapsed: true))
        }
        let all = badges(totals, entries: entries, record: record, dailies: dailies)
        let earned = all.filter(\.earned).count
        out.append(Section(L("Badges"), [.badges(nil, all.filter(\.earned) + all.filter { !$0.earned })], collapsed: true, detail: L("{n} of {total} earned", ["n": earned, "total": all.count])))
        out.append(Section(L("Game settings"), [.settings(nil, keys: ["game_language", "tone", "sounds", "sneaky"], ai: true, aiTitle: L("Make new trivia questions with AI"),
                                                          aiDetail: L("Trivia on any topic you name, in your language. Each new topic is one short request to your AI; the questions aren't checked."))], collapsed: true, wide: true))
        let leveled = entries.filter(\.levels)
        var pictures: [String: Picture] = [:]
        for e in leveled { pictures[GameSoundSetting.levelKey(e.id)] = picture(e) }
        out.append(Section(L("Levels"), [.settings(nil, keys: leveled.map { GameSoundSetting.levelKey($0.id) }, grid: true, pictures: pictures)], collapsed: true, wide: true))
        return out
    }

    private static func picture(_ e: GameEntry) -> Picture { .pack(e.look.icon) }

    /// The last games played: a puzzle's row says its time, not who won. Verdicts by symbol and word, in the calm tones (D78).
    private static func lastGames(_ history: [PlaytimeRecords.Played]) -> Block {
        let puzzles = Set(PlaytimePage.puzzles.map(\.id))
        let shown = history.compactMap { p -> (PlaytimeRecords.Played, GameEntry)? in
            (GameCatalog.entry(p.game) ?? GameCatalog.all.first { p.game.hasPrefix($0.id + "_") }).map { (p, $0) }
        }.prefix(10)
        guard !shown.isEmpty else { return .note(L("Games you finish show here.")) }
        return .recent(nil, shown.map { play, entry in
            let words: String, verdict: Verdict
            switch play.outcome {
            case _ where puzzles.contains(play.game):
                words = L("Solved in {time}", ["time": PuzzleParts.clock(play.you)])
                verdict = .win
            case .won:
                words = L("You won")
                verdict = .win
            case .lost:
                words = L("{name} won", ["name": "{companion}"])
                verdict = .loss
            case .draw:
                words = L("A draw")
                verdict = .draw
            }
            return RecentItem(entry.title, detail: words, at: play.date, tone: verdict == .win ? .good : .neutral, symbol: verdict.symbol, picture: picture(entry))
        })
    }

    private static func badges(_ t: Totals, entries: [GameEntry], record: (GameEntry) -> Record, dailies: [GameEntry]) -> [Achievement] {
        func badge(_ title: String, _ detail: String, _ symbol: String, _ value: Int, _ goal: Int) -> Achievement {
            Achievement(title, detail: detail, symbol: symbol, earned: value >= goal, value: min(value, goal), goal: goal)
        }
        let tried = entries.filter { record($0).played > 0 }.count
        let doneToday = dailies.filter { record($0).today?.done == true }.count
        var out = [badge(L("First win"), L("Beat your companion once"), "star.fill", t.wins, 1),
                   badge(L("Ten wins"), L("Win ten games"), "trophy.fill", t.wins, 10),
                   badge(L("Fifty wins"), L("Win fifty games"), "crown.fill", t.wins, 50),
                   badge(L("Hat trick"), L("Three wins in a row"), "flame.fill", t.bestStreak, 3),
                   badge(L("Unstoppable"), L("Five wins in a row"), "bolt.fill", t.bestStreak, 5),
                   badge(L("Explorer"), L("Play every game once"), "map.fill", tried, entries.count)]
        if entries.contains(where: \.solo) { out.append(badge(L("Puzzler"), L("Solve ten puzzles"), "puzzlepiece.fill", t.solved, 10)) }
        if !dailies.isEmpty {
            out.append(badge(L("A week of dailies"), L("A daily seven days running"), "calendar", t.dailyStreak, 7))
            if dailies.count > 1 { out.append(badge(L("Full house"), L("Every daily done today"), "sun.max.fill", doneToday, dailies.count)) }
        }
        return out
    }
}
