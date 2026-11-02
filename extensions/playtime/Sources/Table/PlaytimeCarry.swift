import Foundation
import SidefolkExtensionKit

/// What the app used to keep for games, handed over once (D100's `settings_from` and `carries`): how the companion takes a win, sounds, Sneaky, each game's level,
/// two people's names, whether the AI may make questions, and History's rows of games played, for the menu's and the center's numbers. Copies: History keeps its own.
@MainActor
enum PlaytimeCarry {
    static let owner = "dev.sidefolk.playtime/"

    static func install(on ext: Extension) {
        ext.carryAll { _, values, store, history in receive(values, store: store, history: history) }
    }

    static func receive(_ values: Arguments, store: [String: Any], history: [String: [[String: Any]]]) -> [String: Any] {
        var settings: [String: Any] = [:]
        if let tone = values.string("tone") { settings["tone"] = tone }
        if let sneaky = values.bool("sneaky") { settings["sneaky"] = sneaky }
        let sounds = values.bool("sounds") ?? false
        settings["sounds"] = sounds
        let speakers = values.values["speakers"] as? [String: Any] ?? [:], levels = values.values["levels"] as? [String: Any] ?? [:]
        for game in GameTable.drivers.keys {
            settings[GameSoundSetting.key(game)] = speakers[owner + game] as? Bool ?? sounds
            if let level = levels[owner + game] as? String, GameLevel(rawValue: level) != nil { settings[GameSoundSetting.levelKey(game)] = level }
        }
        // Rock, paper, scissors was the app's own game until it moved here.
        settings[GameSoundSetting.key(RockPaperScissorsScreen.id)] = speakers["sidefolk/" + RockPaperScissorsScreen.id] as? Bool ?? sounds
        let rows = (history["games.play"] ?? []).compactMap(play)
        let tally = (store["companion.handsScore"] as? [String: Any]).map(Arguments.init)
        let duels = store["companion.handsDuels"] as? [String: Any] ?? [:]
        PlaytimeRecords.update { r in
            r.soundsSeen = sounds
            let names = values.strings("players")
            if r.players == nil, names.count == 2 { r.players = names }
            if r.plays == nil { r.plays = Array(rows.prefix(1000)) }
            if r.hands == nil, let tally {
                r.hands = PlaytimeRecords.HandsTally(person: tally.int("person") ?? 0, companion: tally.int("companion") ?? 0, draws: tally.int("draws") ?? 0)
            }
            if r.duels?[RockPaperScissorsScreen.id] == nil, !duels.isEmpty {
                var pairs: [String: PlaytimeRecords.Duel] = [:]
                for (pair, value) in duels {
                    guard let wins = (value as? [String: Any])?["wins"] as? [String: Any] else { continue }
                    pairs[pair] = PlaytimeRecords.Duel(wins: wins.compactMapValues { ($0 as? NSNumber)?.intValue })
                }
                r.duels = (r.duels ?? [:]).merging([RockPaperScissorsScreen.id: pairs]) { own, _ in own }
            }
            r.carried = true
        }
        var reply: [String: Any] = ["settings": settings]
        // A "no" the person gave in the app stays a no.
        if values.bool("aiTrivia") == false { reply["ai"] = false }
        return reply
    }

    /// One of History's rows of a game played (newest first as History gives them), its game by name, or nothing if it isn't one of these.
    private static func play(_ row: [String: Any]) -> PlaytimeRecords.Play? {
        let args = Arguments(row["args"] as? [String: Any] ?? [:])
        guard let game = args.string("game"), args.string("extension") == "dev.sidefolk.playtime" || args.string("extension") == "sidefolk" else { return nil }
        let at = (row["at"] as? String).flatMap { ISO8601DateFormatter().date(from: $0) } ?? (row["at"] as? Double).map { Date(timeIntervalSince1970: $0) } ?? .distantPast
        return PlaytimeRecords.Play(game: game, result: args.string("result"), at: at)
    }
}
