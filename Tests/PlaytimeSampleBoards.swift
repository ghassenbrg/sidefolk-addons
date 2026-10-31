import Foundation
@testable import SidefolkExtensionKit
@testable import ext_playtime

/// Real boards for Sidefolk's UI snapshots: the bot plays each game (PlaytimeScreensTests) with a few seeds, and the
/// moments worth looking at are written as JSON, each with the board before it so Sidefolk can draw the build-up:
/// the start, a turn, the companion thinking, a point scored (its build-up and its verdict), and the end card won,
/// lost or drawn when a seed got there.
enum SampleBoards {
    static func write(to folder: String, languages: [String]) throws {
        for language in languages {
            try Language.with(language, strings: PlaytimeGameTests.strings) {
                let dir = folder + "/" + language
                try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
                let titles = Dictionary(uniqueKeysWithValues: PlaytimePage.games.map { ($0.id, $0) })
                func save<S: GameScreen>(_ s: S.Type, seeds: [UInt64] = [1, 2, 3, 4, 5, 6]) throws {
                    var picked: [String: (Board?, Board)] = [:]
                    for seed in seeds {
                        PlaytimeRecords.update { $0 = PlaytimeRecords() }
                        let boards = try PlaytimeScreensTests.play(S.self, seed: seed, language: language).boards
                        for (i, b) in boards.enumerated() {
                            let before = i > 0 ? boards[i - 1] : nil
                            func keep(_ name: String) { if picked[name] == nil { picked[name] = (before, b) } }
                            if i == 0 { keep("start") }
                            if i > 0, b.afterMs == nil, !b.over, b.companion?.move != "think" { keep("turn") }
                            if b.afterMs != nil, b.companion?.move == "think" { keep("thinking") }
                            if let before, score(b) != score(before), !b.over { keep("point") }
                            if b.over, let tone = PlaytimeScreensTests.part(b, "result")?["tone"] as? String {
                                keep(["good": "end-win", "bad": "end-loss"][tone] ?? "end-draw")
                            }
                        }
                    }
                    for (name, (before, board)) in picked {
                        var out: [String: Any] = ["game": S.id, "title": titles[S.id]?.title ?? S.id, "symbol": titles[S.id]?.symbol ?? "gamecontroller",
                                                  "board": board.json]
                        if let before { out["previous"] = before.json }
                        let data = try JSONSerialization.data(withJSONObject: out, options: [.sortedKeys])
                        FileManager.default.createFile(atPath: dir + "/\(S.id)-\(name).json", contents: data)
                    }
                }
                try save(TriviaScreen.self)
                try save(TicTacToeScreen.self)
                try save(CopyMeScreen.self)
                try save(QuickPawsScreen.self)
                try save(WhichCupScreen.self)
                try save(HigherLowerScreen.self)
                try save(GuessAnimalScreen.self)
                try save(BalloonWordsScreen.self)
                try save(LastStickScreen.self)
                try save(MemoryPairsScreen.self)
                try save(DailyWordScreen.self)
            }
        }
    }

    static func score(_ b: Board) -> String {
        guard let s = PlaytimeScreensTests.part(b, "score") else { return "" }
        return "\(s["you"] ?? "")-\(s["companion"] ?? "")"
    }
}
