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
        func last(_ e: GameEntry) -> Date? { history.first { $0.game == e.id || $0.game.hasPrefix(e.id + "_") }?.date }

        var out: [Section] = [Section(nil, [hero(dailies: dailies, record: record, kept: kept), stats(totals)])]
        if !dailies.isEmpty {
            let date = Date().formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Language.locale))
            out.append(Section(L("Today"), [.cards(size: .small, dailies.map { daily($0, record($0)) })], detail: date))
        }
        func group(_ title: String, solo: Bool, picture: Picture?) {
            let games = entries.filter { $0.solo == solo }
            guard !games.isEmpty else { return }
            out.append(Section(title, [.cards(size: .large, games.map { card($0, record($0), kept: kept == $0.id, last: last($0)) })], picture: picture))
        }
        group(L("Play against {name}", ["name": "{companion}"]), solo: false, picture: .companion(.face))
        group(L("Puzzles"), solo: true, picture: nil)
        out.append(Section(L("Last games"), [lastGames(history)]))
        if !duels.isEmpty {
            out.append(Section(L("Head to head"), [.facts(nil, duels.map { d in
                (GameCatalog.entry(d.game)?.title ?? d.game, "\(d.names[0]) \(Format.integer(d.wins[0])) · \(d.names[1]) \(Format.integer(d.wins[1]))")
            })]))
        }
        let all = badges(totals, entries: entries, record: record, dailies: dailies)
        let earned = all.filter(\.earned).count
        out.append(Section(L("Badges"), [.badges(nil, all.filter(\.earned) + all.filter { !$0.earned })], detail: L("{n} of {total} earned", ["n": earned, "total": all.count])))
        out.append(Section(L("Game settings"), [.settings(nil, keys: ["tone", "sounds", "sneaky"], ai: true)]))
        out.append(Section(L("Levels"), [.settings(nil, keys: entries.filter(\.levels).map { GameSoundSetting.levelKey($0.id) })], collapsed: true))
        return out
    }

    /// Continue the game put away; else the first daily not done today; else a surprise.
    private static func hero(dailies: [GameEntry], record: (GameEntry) -> Record, kept: String?) -> Block {
        var action = Action(L("Surprise me"), tool: "open", input: ["game": "random", "person": true], style: .primary, symbol: "dice.fill")
        var says = L("Pick a game! Can you beat me?")
        if let kept, let entry = GameCatalog.entry(kept) {
            action = Action(L("Continue {title}", ["title": entry.title]), tool: "open", input: ["game": kept, "person": true], style: .primary, symbol: "play.fill")
            says = L("Ready when you are!")
        } else if let daily = dailies.first(where: { record($0).today?.done != true }) {
            action = Action(L("Play today's {title}", ["title": daily.title]), tool: "open", input: ["game": daily.id, "person": true], style: .primary, symbol: "sun.max.fill")
            says = L("Today's boards are waiting!")
        }
        return .hero(Hero(L("Playtime"), detail: L("Games against {name}, and puzzles of your own", ["name": "{companion}"]), symbol: "gamecontroller.fill",
                          actions: [action, Action(L("All games"), tool: "open", input: ["game": "menu", "person": true], symbol: "square.grid.2x2.fill")],
                          scene: .pack(Look.dance.scene, dark: Look.dance.sceneAtNight), figure: .companion(.full), says: says))
    }

    /// Wins, puzzles solved, the best run of wins and games played.
    private static func stats(_ t: Totals) -> Block {
        .stats([StatItem(L("Wins"), Format.integer(t.wins), symbol: "trophy.fill"),
                StatItem(L("Solved"), Format.integer(t.solved), symbol: "checkmark.seal.fill", tone: .good),
                StatItem(L("Best streak"), Format.integer(t.bestStreak), symbol: "flame.fill"),
                StatItem(L("Played"), Format.integer(t.played), symbol: "gamecontroller.fill")])
    }

    private static func picture(_ e: GameEntry) -> Picture { .pack(e.look.icon) }

    private static func daily(_ e: GameEntry, _ r: Record) -> Card {
        let streak = r.today?.streak ?? 0
        return Card(e.title, detail: r.today?.text, meta: streak > 1 ? L("{n} days in a row", ["n": streak]) : nil, picture: picture(e), color: e.look.bottom.json as? String, done: r.today?.done == true,
                    actions: [Action(L("Play"), tool: "open", input: ["game": e.id, "person": true], symbol: "play.fill")])
    }

    /// A game as a card: its art, title and tagline, its best and record, when it was last played, Play (with a level from the menu beside it), and Resume when it was put away.
    private static func card(_ e: GameEntry, _ r: Record, kept: Bool, last: Date?) -> Card {
        var actions = [Action(kept ? L("Resume") : L("Play"), tool: "open", input: ["game": e.id, "person": true], symbol: "play.fill")]
        if TwoPlayers.games.contains(e.id) {
            actions.append(Action(L("2 players"), tool: "open", input: ["game": e.id, "players": 2, "person": true], symbol: "person.2.fill", detail: L("Play against a friend on this Mac")))
        }
        let levels = e.levels ? GameLevel.allCases.map { Action(ScreenKit.level($0), tool: "open", input: ["game": e.id, "level": $0.rawValue, "person": true]) } : []
        let chosen = PlayOptions.chosenLevel(e.id)
        return Card(e.title, detail: e.tagline, meta: recordLine(e, r, last: last), at: last, picture: picture(e), color: e.look.bottom.json as? String,
                    badge: chosen.map { Badge(ScreenKit.level($0), tone: .info) }, actions: actions, menu: levels.isEmpty ? nil : (L("Level"), levels))
    }

    /// Its record in plain words: the game's own best, then wins of games played (a puzzle's solves), or not yet played. Nothing when a game was opened but none finished.
    private static func recordLine(_ e: GameEntry, _ r: Record, last: Date?) -> String? {
        guard r.played > 0 else { return last == nil ? L("Not played yet") : nil }
        var parts: [String] = []
        if let best = r.best { parts.append(best) }
        parts.append(e.solo ? L("{n} solved", ["n": r.won]) : L("Won {won} of {played}", ["won": r.won, "played": r.played]))
        if r.streak > 1 { parts.append(L("{n} wins in a row", ["n": r.streak])) }
        return parts.joined(separator: " · ")
    }

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
