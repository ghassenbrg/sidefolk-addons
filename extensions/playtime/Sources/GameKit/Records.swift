import Foundation
import SidefolkExtensionKit

/// What Playtime keeps between games, in its own data folder (never the person's other files): each game's tallies and
/// best, the last ten games for Home, Daily Word's day and streak, Last Stick's lessons, and what the companion learned
/// in Guess My Animal (a file of its own, it grows). Trivia keeps its own as well (`TriviaRecords`). Fields added
/// later are optional, so a file from an older Playtime still reads.
struct PlaytimeRecords: Codable, Equatable {
    struct Tally: Codable, Equatable {
        var played = 0
        var won = 0
        var lost = 0
        var drawn = 0
        /// The game's own best: a longest sequence, a quickest press, fewest guesses.
        var best: Int?
        /// Wins in a row, and the most ever.
        var streak = 0
        var bestStreak = 0
    }

    struct Played: Codable, Equatable {
        var game: String
        var date: Date
        var outcome: GameOutcome
        var you: Int
        var companion: Int
    }

    var games: [String: Tally] = [:]
    var history: [Played] = []
    var daily = Games.DailyWord.Record()
    /// Today's Daily Word as far as it was played, so reopening it shows the rows.
    var dailyGame: Games.DailyWord?
    /// Last Stick: losses so far, and whether the companion offered its trick.
    var stickLosses = 0
    var stickSecretOffered = false
    /// Higher or Lower's way last played ("mine" or "yours"), picked first on its start board.
    var higherLowerMode: String?
    /// Daily Word's practice words played per language since its list last ran out, so none comes back before.
    var practiceWords: [String: [String]]?
    /// The logic puzzles' best times, daily streaks and practice tallies, by puzzle id (`PuzzleRecords.swift`).
    var puzzles: [String: Games.PuzzleRecord]?

    static var file: String { Paths.data + "/records.json" }
    static var animalsFile: String { Paths.data + "/animals.json" }

    static func load() -> PlaytimeRecords {
        FileManager.default.contents(atPath: file).flatMap { try? JSONDecoder().decode(PlaytimeRecords.self, from: $0) } ?? PlaytimeRecords()
    }

    static func update(_ change: (inout PlaytimeRecords) -> Void) {
        var records = load()
        change(&records)
        try? FileManager.default.createDirectory(atPath: Paths.data, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(records) { FileManager.default.createFile(atPath: file, contents: data) }
    }

    /// A game finished: its tally, its best (`lower` when less is better, a reaction time), and a row for Home.
    /// - Returns: whether `best` beat the record.
    @discardableResult
    static func finish(_ game: String, _ outcome: GameOutcome, you: Int, companion: Int, best: Int? = nil, lower: Bool = false,
                       at date: Date = Date()) -> Bool {
        var beaten = false
        update { r in
            var t = r.games[game] ?? Tally()
            t.played += 1
            switch outcome {
            case .won: t.won += 1; t.streak += 1
            case .lost: t.lost += 1; t.streak = 0
            case .draw: t.drawn += 1
            }
            t.bestStreak = max(t.bestStreak, t.streak)
            if let best, t.best.map({ lower ? best < $0 : best > $0 }) ?? true {
                beaten = t.best != nil
                t.best = best
            }
            r.games[game] = t
            r.history = Array(([Played(game: game, date: date, outcome: outcome, you: you, companion: companion)] + r.history).prefix(10))
        }
        return beaten
    }

    /// What the companion learned about animals, per language.
    static func animals() -> Games.GuessAnimal.Memory {
        FileManager.default.contents(atPath: animalsFile).flatMap { try? JSONDecoder().decode(Games.GuessAnimal.Memory.self, from: $0) }
            ?? Games.GuessAnimal.Memory()
    }

    static func saveAnimals(_ memory: Games.GuessAnimal.Memory) {
        try? FileManager.default.createDirectory(atPath: Paths.data, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(memory) { FileManager.default.createFile(atPath: animalsFile, contents: data) }
    }
}
