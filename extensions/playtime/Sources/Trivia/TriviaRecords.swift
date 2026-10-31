import Foundation
import SidefolkExtensionKit

/// What trivia keeps between games, in Playtime's data folder: the last set-up (so Return starts the same again), the
/// questions asked lately, the best round per length, the best streak, totals and the last ten games for Home.
struct TriviaRecords: Codable, Equatable {
    struct Setup: Codable, Equatable {
        var topic = "mix"
        var length = 10
        var quick = false
    }

    struct Game: Codable, Equatable {
        var date: Date
        var topic: String
        var asked: Int
        var you: Int
        var companion: Int
    }

    var setup = Setup()
    var recent: [String] = []
    /// The best round's right answers, by length ("5", "10").
    var best: [String: Int] = [:]
    var bestStreak = 0
    var played = 0
    var you = 0
    var companion = 0
    var history: [Game] = []

    static var file: String { Paths.data + "/trivia-games.json" }

    static func load() -> TriviaRecords {
        FileManager.default.contents(atPath: file).flatMap { try? JSONDecoder().decode(TriviaRecords.self, from: $0) } ?? TriviaRecords()
    }

    static func update(_ change: (inout TriviaRecords) -> Void) {
        var records = load()
        change(&records)
        if let data = try? JSONEncoder().encode(records) { FileManager.default.createFile(atPath: file, contents: data) }
    }
}
