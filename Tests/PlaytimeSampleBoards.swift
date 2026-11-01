import Foundation
@testable import SidefolkExtensionKit
@testable import ext_playtime

/// Real boards for Sidefolk's UI snapshots: the bot plays each game (PlaytimeScreensTests) with a few seeds, and the
/// moments worth looking at are written as JSON, each with the board before it so Sidefolk can draw the build-up:
/// the start, a turn, the companion thinking, a point scored (its build-up and its verdict), and the end card won,
/// lost or drawn when a seed got there.
enum SampleBoards {
    static let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("extensions/playtime")

    static func json(_ path: String) -> [String: Any] {
        (try? Data(contentsOf: folder.appendingPathComponent(path))).flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: Any] ?? [:]
    }

    /// Each game's `look` from the manifest and its tagline in the language, so Sidefolk dresses the samples (and draws
    /// its menu) as it would the games.
    static func dressed(_ out: [String: Any], _ id: String) -> [String: Any] {
        var out = out
        let game = (json("sidefolk-extension.json")["games"] as? [String: [String: Any]])?[id]
        let words = ((json("strings/\(Language.code).json")["games"] as? [String: Any])?[id] as? [String: Any])
        out["look"] = game?["look"]
        out["tagline"] = words?["tagline"] ?? game?["tagline"]
        return out
    }

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
                        let data = try JSONSerialization.data(withJSONObject: dressed(out, S.id), options: [.sortedKeys])
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
                try puzzles(language: language, dir: dir, titles: titles)
            }
        }
    }

    /// Moments a bot clicking at random rarely reaches: Daily Word solved, Balloon Words won, Which Cup? on Sneaky,
    /// the companion's animal guess and being taught a new one.
    static func scripted(language: String, dir: String, titles: [String: PlaytimePage.Game]) throws {
        let options = PlaytimeScreensTests.options(language)
        var random = Games.Random(seed: 3)
        func write(_ id: String, _ name: String, _ before: Board?, _ board: Board) throws {
            var out: [String: Any] = ["game": id, "title": titles[id]?.title ?? id, "symbol": titles[id]?.symbol ?? "gamecontroller", "board": board.json]
            if let before { out["previous"] = before.json }
            FileManager.default.createFile(atPath: dir + "/\(id)-\(name).json", contents: try JSONSerialization.data(withJSONObject: dressed(out, id), options: [.sortedKeys]))
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

        // Which Cup? on Sneaky: the companion in the scene is the paw to check.
        var sneaky = options
        sneaky.sneaky = true
        let cups = WhichCupEngine.start(level: .fair, options: sneaky, random: &random)
        try write(WhichCupScreen.id, "sneaky", nil, WhichCupScreen.board(cups, events: [.opened], options: sneaky))

        var a = GuessAnimalEngine.start(level: .fair, options: options, random: &random)
        while a.game.phase == .asking { e = GameTable.play(GuessAnimalScreen.self, .answer(0), on: &a, random: &random) }
        try write(GuessAnimalScreen.id, "guess", nil, GuessAnimalScreen.board(a, events: e, options: options))
        e = GameTable.play(GuessAnimalScreen.self, .answer(1), on: &a, random: &random)
        while a.thinking || a.game.phase == .asking || a.game.phase == .guessing {
            e = GameTable.play(GuessAnimalScreen.self, a.thinking ? .next : .answer(1), on: &a, random: &random)
        }
        try write(GuessAnimalScreen.id, "teach", nil, GuessAnimalScreen.board(a, events: e, options: options))
    }

    /// Each puzzle's moments: today's board, a rule broken, a hint, the solve and its end card, and a Hard board
    /// part-played (Sudoku's 9 × 9 with notes, the size the panel must hold).
    static func puzzles(language: String, dir: String, titles: [String: PlaytimePage.Game]) throws {
        let o = PlaytimeScreensTests.options(language)
        func write(_ id: String, _ name: String, _ before: Board?, _ board: Board) throws {
            var out: [String: Any] = ["game": id, "title": titles[id]?.title ?? id, "symbol": titles[id]?.symbol ?? "gamecontroller", "board": board.json]
            if let before { out["previous"] = before.json }
            FileManager.default.createFile(atPath: dir + "/\(id)-\(name).json", contents: try JSONSerialization.data(withJSONObject: dressed(out, id), options: [.sortedKeys]))
        }
        /// Today's board, two right moves and a wrong one (a rule broken), back and a hint, the solve, then a Hard board.
        func moments<K: PuzzleKind>(_ kind: K.Type, wrong: (PuzzleEngine<K>.State) -> [Move], hard: (inout PuzzleEngine<K>.State) -> Void = { _ in },
                                    clicks: @escaping (K.Rules.Move, PuzzleEngine<K>.State) -> [Move]) throws {
            PlaytimeRecords.update { $0 = PlaytimeRecords() }
            var random = Games.Random(seed: 4)
            var s = PuzzleEngine<K>.start(level: .fair, options: o, random: &random)
            try write(K.id, "start", nil, PuzzleScreen<K>.board(s, events: [.opened], options: o))
            for _ in 0..<6 {
                _ = GameTable.play(PuzzleScreen<K>.self, .button("hint"), on: &s, random: &random)
                for m in clicks(s.hint!.move, s) { _ = GameTable.play(PuzzleScreen<K>.self, m, on: &s, random: &random) }
            }
            var e: [Games.Event] = []
            let wrongs = wrong(s)
            for m in wrongs { e = GameTable.play(PuzzleScreen<K>.self, m, on: &s, random: &random) }
            try write(K.id, "conflict", nil, PuzzleScreen<K>.board(s, events: e, options: o))
            for _ in wrongs { _ = GameTable.play(PuzzleScreen<K>.self, .button("undo"), on: &s, random: &random) }
            e = GameTable.play(PuzzleScreen<K>.self, .button("hint"), on: &s, random: &random)
            try write(K.id, "hint", nil, PuzzleScreen<K>.board(s, events: e, options: o))
            // The end card, after its build-up from the board before the last mark (the last hint's).
            let boards = PlaytimeScreensTests.solve(K.self, &s, clicks: clicks)
            try write(K.id, "end-win", boards.dropLast().last, boards.last!)
            _ = GameTable.play(PuzzleScreen<K>.self, .choice(name: "level", value: "hard"), on: &s, random: &random)
            hard(&s)
            try write(K.id, "hard", nil, PuzzleScreen<K>.board(s, events: [], options: o))
        }
        // Rules broken on purpose: three hearts, a plot of the wrong size, a number twice in a row, blossoms touching.
        try moments(SeesawKind.self, wrong: { s in
            // Three open cells side by side, each clicked once: three hearts in a row.
            let n = s.game.puzzle.size, g = s.game.grid
            let start = g.indices.first { c in c % n <= n - 3 && (0..<3).allSatisfy { g[c + $0] == nil && s.game.puzzle.givens[c + $0] == nil } } ?? 0
            return (0..<3).map { Move.cell(row: start / n, column: start % n + $0) }
        }, clicks: { m, s in PlaytimeScreensTests.clicks(m, on: s.game.grid, size: s.game.puzzle.size) })
        try moments(GardenPlotsKind.self, wrong: { s in
            let b = s.game.puzzle
            let clue = b.clues.first { c in !s.game.grid.contains { $0.contains(c.cell, width: b.width) } && c.area > 2 }!
            return [.cell(row: clue.cell / b.width, column: clue.cell % b.width)]
        }, clicks: { m, s in PlaytimeScreensTests.clicks(m, width: s.game.puzzle.width) })
        try moments(SudokuKind.self, wrong: { s in
            let n = s.game.puzzle.size, g = s.game.grid.digits
            let cell = g.indices.first { g[$0] == 0 }!
            let twin = (0..<n).map { cell / n * n + $0 }.first { g[$0] != 0 }!
            return [.place(row: cell / n, column: cell % n, value: g[twin], note: false)]
        }, hard: { s in
            var random = Games.Random(seed: 9)
            let n = s.game.puzzle.size
            for (i, cell) in s.game.puzzle.givens.indices.filter({ s.game.puzzle.givens[$0] == 0 }).prefix(10).enumerated() {
                let move: Move = i < 6 ? .place(row: cell / n, column: cell % n, value: s.game.puzzle.solution[cell], note: false)
                    : .place(row: cell / n, column: cell % n, value: s.game.puzzle.solution[cell], note: true)
                _ = GameTable.play(PuzzleScreen<SudokuKind>.self, move, on: &s, random: &random)
            }
        }, clicks: { m, s in PlaytimeScreensTests.clicks(m, size: s.game.puzzle.size) })
        try moments(BlossomsKind.self, wrong: { s in
            let n = s.game.puzzle.size, g = s.game.grid
            let cell = g.indices.first { c in g[c] == nil && c % n < n - 1 && g[c + 1] == nil && !(0..<n).contains { g[c / n * n + $0] == .blossom } }!
            return [.cell(row: cell / n, column: cell % n), .cell(row: cell / n, column: cell % n),
                    .cell(row: cell / n, column: cell % n + 1), .cell(row: cell / n, column: cell % n + 1)]
        }, clicks: { m, s in PlaytimeScreensTests.clicks(m, on: s.game.grid, size: s.game.puzzle.size) })
    }

    static func score(_ b: Board) -> String {
        guard let s = PlaytimeScreensTests.part(b, "score") else { return "" }
        return "\(s["you"] ?? "")-\(s["companion"] ?? "")"
    }
}
