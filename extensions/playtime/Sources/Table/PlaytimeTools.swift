import Foundation
import SidefolkExtensionKit

/// What can open a game, as tools of Playtime's own (D101): the person's words through the commands in the manifest, a menu item, the page's
/// buttons and the AI all come here, through Guard, and the reply opens the surface. Each only shows a panel or a page, or changes how games
/// play, so all are low risk.
@MainActor
enum PlaytimeTools {
    static func install(on ext: Extension) {
        ext.tool("open", "Open a game",
                 """
                 Opens a game the user plays against you beside the companion, offline and without you: the game runs itself once open. Use it when the user \
                 wants to play, or for a break ("want a round of trivia?"). Without a game (or with "game": "menu") it opens the menu of every game: do that when the \
                 user asks what games there are, to see them, or wants to play without naming one, rather than listing them in words. "game" may also be "last" (resume \
                 the game put away, or open the last one played), "again" (a new round of the last one: a rematch), "random" (you pick one), or "center" (the \
                 Game Center in Home: the user's scores, records, badges and game settings). "level" may be "harder" or "easier" (one step from the last). "players": 2 \
                 opens it for the user and a friend on this Mac. Trivia takes "topic" and "count"; Higher or Lower "min", "max" and "mode" (mine: the user guesses your \
                 number; yours: you guess theirs). Games: \(GameTable.drivers.keys.sorted().joined(separator: ", ")).
                 """,
                 input: Schema.object([
                     "game": Schema.string("A game's name; or menu, last, again, random or center. Leave it out for the menu."),
                     "level": Schema.string("easy, fair or hard, or harder or easier."),
                     "topic": Schema.string("A quiz's subject in the user's words, at most 40 characters.", maxLength: 40),
                     "count": Schema.integer("How many questions or rounds.", minimum: 1, maximum: 50),
                     "min": Schema.integer("A number game's lowest number.", minimum: 0, maximum: 1_000_000),
                     "max": Schema.integer("A number game's highest number.", minimum: 0, maximum: 1_000_000),
                     "mode": Schema.string("A number game: who guesses.", oneOf: ["mine", "yours"]),
                     "players": Schema.integer("2 when the user plays a friend on this Mac rather than you (any game but the puzzles and Guess My Animal).", minimum: 1, maximum: 2),
                     "person": Schema.boolean("Leave this out."),
                 ])) { args in try open(args) }
        ext.tool("put_away", "Put the game away",
                 "Puts the game on the panel away, to resume later from the menu, the Game Center or \"resume\".", input: Schema.none) { _ in
            ToolReply(L("Put the game away")).row(L("Put the game away")).closingSurface("play")
        }
        ext.tool("game_settings", "Change game settings",
                 """
                 Changes how the games play: "sounds" on or off for every game (each game's own speaker button follows), "tone" (how you take a win: gentle, cheeky or \
                 competitive), "sneaky" (you may cheat for fun where a game allows it, always owning up when caught), or a game's "level" (with its "game"; "default" \
                 lets the game pick). Only what is given changes.
                 """,
                 input: Schema.object([
                     "sounds": Schema.boolean("Game sounds on or off, for every game."),
                     "tone": Schema.string("How you take a win.", oneOf: ["gentle", "cheeky", "competitive"]),
                     "sneaky": Schema.boolean("Whether you may cheat for fun where a game allows it."),
                     "game": Schema.string("For a level: the game's name."),
                     "level": Schema.string("easy, fair, hard or default."),
                 ])) { args in try ToolReply(settings(args)) }
    }

    private static func open(_ a: Arguments) throws -> ToolReply {
        let person = a.bool("person") == true
        switch a.string("game") ?? "menu" {
        case "menu":
            return ToolReply(L("Show the games")).row(L("Show the games"))
                .opening(surface: "play", arguments: ["view": "menu"])
        case "center":
            return ToolReply(L("Show the Game Center")).row(L("Show the Game Center")).opening(page: "playtime")
        case "random":
            let others = GameCatalog.all.filter { $0.id != PlaytimeRecords.load().lastOpened?.game }
            guard let pick = others.randomElement() else { return try open(Arguments(["game": "menu"])) }
            return try opening(pick, a, person: person, fresh: true)
        case "last", "again":
            let again = a.string("game") == "again", step = a.string("level") == "harder" || a.string("level") == "easier"
            guard let last = PlayTable.keptGame ?? PlaytimeRecords.load().lastOpened?.game, let entry = GameCatalog.entry(last) else {
                return try open(Arguments(["game": "menu"]))
            }
            return try opening(entry, a, person: person, fresh: again || step)
        case let game:
            guard let entry = GameCatalog.entry(game) else { throw Problem("There's no such game. Games are listed in this tool's description.") }
            return try opening(entry, a, person: person, fresh: a.string("level") == "harder" || a.string("level") == "easier")
        }
    }

    /// Opens a game at the level asked (a level, or a step from the last), else the person's chosen one. A level the person asked for becomes theirs for that
    /// game, as the Game Center's setting; the AI's choice doesn't.
    private static func opening(_ entry: GameEntry, _ a: Arguments, person: Bool, fresh: Bool) throws -> ToolReply {
        let asked = a.string("level")
        let chosen = PlayOptions.chosenLevel(entry.id)
        var level = asked.flatMap(GameLevel.init(rawValue:))
        if !entry.levels { level = nil }
        if asked == "harder" || asked == "easier" {
            guard entry.levels else { throw Problem(L("{title} has no levels.", ["title": entry.title])) }
            let last = PlaytimeRecords.load().lastOpened
            let current = (last?.game == entry.id ? last?.level.flatMap(GameLevel.init(rawValue:)) : nil) ?? chosen ?? .fair
            let all = GameLevel.allCases, at = all.firstIndex(of: current) ?? 1
            let next = at + (asked == "harder" ? 1 : -1)
            guard all.indices.contains(next) else {
                throw Problem(asked == "harder" ? L("{title} is already at its hardest.", ["title": entry.title]) : L("{title} is already at its easiest.", ["title": entry.title]))
            }
            level = all[next]
        }
        if let level, person, level != chosen { ExtensionSettings.set(GameSoundSetting.levelKey(entry.id), level.rawValue) }
        var arguments: [String: Any] = ["game": entry.id]
        if let opened = level ?? chosen { arguments["level"] = opened.rawValue }
        if fresh { arguments["fresh"] = true }
        // What was said about the game only where it means something (D93).
        if entry.id == TriviaScreen.id {
            if let t = a.string("topic") { arguments["topic"] = t }
            if let n = a.int("count") { arguments["count"] = n }
        }
        if entry.id == HigherLowerScreen.id {
            let high = a.int("max"), low = a.int("min")
            if let high, (low ?? 1) < high {
                arguments["min"] = low ?? 1
                arguments["max"] = high
            }
            if let mode = a.string("mode") { arguments["mode"] = mode }
        }
        // Two people only where two can play (D96): not the puzzles, not Guess My Animal.
        if a.int("players") == 2, TwoPlayers.games.contains(entry.id) { arguments["players"] = 2 }
        // History's row, as it read: what was opened, at the level it opened at.
        var row = L("Play {title}", ["title": entry.title])
        if let opened = level ?? chosen, entry.levels { row += " · " + ScreenKit.level(opened) }
        return ToolReply(L("Play {title}", ["title": entry.title])).row(row)
            .opening(surface: "play", arguments: arguments)
    }

    private static func settings(_ a: Arguments) throws -> String {
        var said: [String] = []
        if let on = a.bool("sounds") {
            // One write: each game's own speaker follows this one until it is pressed, and a change here clears those (the manifest's `follows`).
            ExtensionSettings.set("sounds", on)
            said.append(on ? L("Game sounds on") : L("Game sounds off"))
        }
        if let tone = a.string("tone") {
            guard ["gentle", "cheeky", "competitive"].contains(tone) else { throw Problem("tone must be gentle, cheeky or competitive.") }
            ExtensionSettings.set("tone", tone)
            said.append(tone)
        }
        if let sneaky = a.bool("sneaky") {
            ExtensionSettings.set("sneaky", sneaky)
            said.append("sneaky: \(sneaky)")
        }
        if let level = a.string("level") {
            guard let entry = a.string("game").flatMap(GameCatalog.entry) else { throw Problem("There's no such game. Games are listed in the open tool's description.") }
            guard level == "default" || (entry.levels && GameLevel(rawValue: level) != nil) else { throw Problem(L("{title} has no level “{level}”.", ["title": entry.title, "level": level])) }
            ExtensionSettings.set(GameSoundSetting.levelKey(entry.id), level)
            said.append("\(entry.title): \(level)")
        }
        guard !said.isEmpty else { throw Problem("Say what to change: sounds, tone, sneaky or a game's level.") }
        return said.joined(separator: ", ")
    }

}
