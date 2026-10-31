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
                try scripted(language: language, dir: dir, titles: titles)
            }
        }
    }

    /// Moments a bot clicking at random rarely reaches: Daily Word solved, Balloon Words won, the companion's animal
    /// guess and being taught a new one.
    static func scripted(language: String, dir: String, titles: [String: PlaytimePage.Game]) throws {
        let options = PlaytimeScreensTests.options(language)
        var random = Games.Random(seed: 3)
        func write(_ id: String, _ name: String, _ before: Board?, _ board: Board) throws {
            var out: [String: Any] = ["game": id, "title": titles[id]?.title ?? id, "symbol": titles[id]?.symbol ?? "gamecontroller", "board": board.json]
            if let before { out["previous"] = before.json }
            FileManager.default.createFile(atPath: dir + "/\(id)-\(name).json", contents: try JSONSerialization.data(withJSONObject: out, options: [.sortedKeys]))
        }
        PlaytimeRecords.update { $0 = PlaytimeRecords() }
        var d = DailyWordEngine.start(level: .fair, options: options, random: &random)
        let answer = Games.DailyWord.answer(day: d.game.day, language: d.game.language)
        let others = Games.WordBank.daily(d.game.language).filter { $0 != answer }
        var before = DailyWordScreen.board(d, events: [], options: options)
        for word in others.prefix(2) { _ = GameTable.play(DailyWordScreen.self, .word(word), on: &d, random: &random) }
        let rows = DailyWordScreen.board(d, events: [.reveal], options: options)
        try write(DailyWordScreen.id, "rows", before, rows)
        before = rows
        let solved = GameTable.play(DailyWordScreen.self, .word(answer), on: &d, random: &random)
        before = DailyWordScreen.board(d, events: solved, options: options)
        try write(DailyWordScreen.id, "end-win", rows, before)
        // Practice words after the day's: the first board, two rows, and one missed.
        var e = GameTable.play(DailyWordScreen.self, .button("practice"), on: &d, random: &random)
        let practice = DailyWordScreen.board(d, events: e, options: options)
        try write(DailyWordScreen.id, "practice", before, practice)
        let word = PlaytimeRecords.load().practiceWords?[d.game.language.key]?.last ?? ""
        let misses = Games.WordBank.daily(d.game.language).filter { $0 != word }
        for w in misses.prefix(2) { e = GameTable.play(DailyWordScreen.self, .word(w), on: &d, random: &random) }
        before = DailyWordScreen.board(d, events: e, options: options)
        try write(DailyWordScreen.id, "practice-rows", practice, before)
        for w in misses.dropFirst(2).prefix(4) { e = GameTable.play(DailyWordScreen.self, .word(w), on: &d, random: &random) }
        try write(DailyWordScreen.id, "practice-end-loss", before, DailyWordScreen.board(d, events: e, options: options))

        // Higher or Lower: opened again after "I'll guess yours" (picked first), its question with the switch, its end card.
        PlaytimeRecords.update { $0.higherLowerMode = "yours" }
        var h = HigherLowerEngine.start(level: .fair, options: options, random: &random)
        try write(HigherLowerScreen.id, "start-remembered", nil, HigherLowerScreen.board(h, events: [.opened], options: options))
        e = GameTable.play(HigherLowerScreen.self, .button("start"), on: &h, random: &random)
        e = GameTable.play(HigherLowerScreen.self, .next, on: &h, random: &random)
        try write(HigherLowerScreen.id, "yours-asking", nil, HigherLowerScreen.board(h, events: e, options: options))
        before = HigherLowerScreen.board(h, events: e, options: options)
        while !h.over {
            e = GameTable.play(HigherLowerScreen.self, h.thinking ? .next : .answer(h.yours!.asked >= 4 ? 2 : 0), on: &h, random: &random)
            if !h.thinking, !h.over { before = HigherLowerScreen.board(h, events: e, options: options) }
        }
        try write(HigherLowerScreen.id, "yours-end", before, HigherLowerScreen.board(h, events: e, options: options))
        // Guessing its number: the thermometer after two guesses.
        PlaytimeRecords.update { $0.higherLowerMode = "mine" }
        h = HigherLowerEngine.start(level: .fair, options: options, random: &random)
        _ = GameTable.play(HigherLowerScreen.self, .button("start"), on: &h, random: &random)
        for n in [50, 30] where !h.over { e = GameTable.play(HigherLowerScreen.self, .number(n), on: &h, random: &random) }
        try write(HigherLowerScreen.id, "meter", nil, HigherLowerScreen.board(h, events: e, options: options))

        var b = BalloonWordsEngine.start(level: .fair, options: options, random: &random)
        let wrong = b.game.keys.first { k in !b.game.units.contains { $0.key == k } }!
        e = GameTable.play(BalloonWordsScreen.self, .letter(wrong), on: &b, random: &random)
        for unit in b.game.units where !unit.key.isEmpty && !b.game.over {
            if !b.game.guessed.contains(unit.key) {
                before = BalloonWordsScreen.board(b, events: e, options: options)
                e = GameTable.play(BalloonWordsScreen.self, .letter(unit.key), on: &b, random: &random)
            }
        }
        try write(BalloonWordsScreen.id, "end-win", before, BalloonWordsScreen.board(b, events: e, options: options))

        var a = GuessAnimalEngine.start(level: .fair, options: options, random: &random)
        while a.game.phase == .asking { e = GameTable.play(GuessAnimalScreen.self, .answer(0), on: &a, random: &random) }
        try write(GuessAnimalScreen.id, "guess", nil, GuessAnimalScreen.board(a, events: e, options: options))
        e = GameTable.play(GuessAnimalScreen.self, .answer(1), on: &a, random: &random)
        while a.thinking || a.game.phase == .asking || a.game.phase == .guessing {
            e = GameTable.play(GuessAnimalScreen.self, a.thinking ? .next : .answer(1), on: &a, random: &random)
        }
        try write(GuessAnimalScreen.id, "teach", nil, GuessAnimalScreen.board(a, events: e, options: options))
    }

    static func score(_ b: Board) -> String {
        guard let s = PlaytimeScreensTests.part(b, "score") else { return "" }
        return "\(s["you"] ?? "")-\(s["companion"] ?? "")"
    }
}
