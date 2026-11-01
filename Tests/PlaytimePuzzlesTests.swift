import Foundation
import Testing
@testable import ext_playtime

/// Playtime's four logic puzzles: every generated board has exactly one solution (counted again here by plain
/// backtracking, apart from the generators' own logic), hints are always right and lead to the end from anywhere,
/// mistakes and broken rules are found, the daily board is the same for a date on every Mac, the records keep best
/// times and streaks, and boards are made quickly enough to open without a wait.
struct PlaytimePuzzlesTests {
    typealias G = Games

    // MARK: One solution

    @Test func seesawBoardsHaveOneSolution() {
        for level in G.Level.allCases {
            for seed in 0..<25 {
                var rng = G.Random(seed: UInt64(seed))
                let board = G.Seesaw.generate(level: level, using: &rng)
                #expect(board.size == (level == .hard ? 8 : 6))
                #expect(board.isSolved(board.solution.map { $0 }), "\(level) \(seed)")
                #expect(Brute.seesaw(board) == 1, "\(level) \(seed)")
                #expect(zip(board.givens, board.solution).allSatisfy { $0 == nil || $0 == $1 })
                #expect(!board.edges.isEmpty, "the = and × clues are part of every board")
            }
        }
    }

    @Test func sudokuBoardsHaveOneSolution() {
        for level in G.Level.allCases {
            for seed in 0..<(level == .hard ? 10 : 25) {
                var rng = G.Random(seed: UInt64(seed))
                let board = G.Sudoku.generate(level: level, using: &rng)
                #expect(board.size == (level == .hard ? 9 : 6))
                #expect(board.isSolved(G.Sudoku.Grid(digits: board.solution, notes: board.start.notes)), "\(level) \(seed)")
                #expect(Brute.sudoku(board) == 1, "\(level) \(seed)")
                #expect(zip(board.givens, board.solution).allSatisfy { $0 == 0 || $0 == $1 })
            }
        }
    }

    @Test func gardenPlotsBoardsHaveOneSolution() {
        for level in G.Level.allCases {
            for seed in 0..<25 {
                var rng = G.Random(seed: UInt64(seed))
                let board = G.GardenPlots.generate(level: level, using: &rng)
                #expect(board.width == [6, 7, 8][G.Level.allCases.firstIndex(of: level)!] && board.height == board.width)
                #expect(board.isSolved(board.solution), "\(level) \(seed)")
                #expect(Brute.plots(board) == 1, "\(level) \(seed)")
            }
        }
    }

    @Test func blossomsBoardsHaveOneSolution() {
        for level in G.Level.allCases {
            for seed in 0..<25 {
                var rng = G.Random(seed: UInt64(seed))
                let board = G.Blossoms.generate(level: level, using: &rng)
                #expect([6...6, 7...8, 8...9][G.Level.allCases.firstIndex(of: level)!].contains(board.size))
                #expect(Set(board.beds) == Set(0..<board.size))
                #expect(board.isSolved(Self.blossomsSolved(board)), "\(level) \(seed)")
                #expect(Brute.blossoms(board) == 1, "\(level) \(seed)")
            }
        }
    }

    static func blossomsSolved(_ b: G.Blossoms) -> G.Blossoms.Grid {
        (0..<(b.size * b.size)).map { b.isBlossom($0) ? .blossom : nil }
    }

    // MARK: Hints

    /// Takes every hint from the start to the end: each one is right, never a reveal, and nothing breaks a rule.
    static func playByHints<P: PuzzleRules>(_ board: P, right: (P.Move) -> Bool) throws -> [String] {
        var game = G.PuzzleGame(board, at: 0)
        var reasons: [String] = []
        while !game.solved, reasons.count < 200 {
            let (hint, events) = try game.hint(at: Double(reasons.count))
            #expect(events == [.hint])
            reasons.append("\(hint.reason)")
            #expect(right(hint.move), "\(hint)")
            #expect(!hint.cells.isEmpty)
            #expect(try !game.play(hint.move, at: Double(reasons.count)).contains(.mistake))
            #expect(game.conflicts.isEmpty)
        }
        #expect(game.solved && game.hints == reasons.count)
        #expect(!reasons.contains("reveal") && !reasons.contains("mistake"), "\(reasons)")
        return reasons
    }

    /// From random right marks part of the way, the hint is still right and still a forced step.
    static func hintsFromPartway<P: PuzzleRules>(_ board: P, moves: [P.Move], seed: UInt64, right: (P.Move) -> Bool) throws {
        var rng = G.Random(seed: seed)
        for _ in 0..<6 {
            var game = G.PuzzleGame(board, at: 0)
            for move in rng.shuffled(moves).prefix(rng.below(moves.count)) where !game.solved { _ = try game.play(move, at: 0) }
            guard !game.solved else { continue }
            let hint = try game.hint(at: 1).hint
            #expect(right(hint.move) && "\(hint.reason)" != "reveal" && "\(hint.reason)" != "mistake", "\(hint)")
        }
    }

    @Test func seesawHintsAreAlwaysRight() throws {
        var seen = Set<String>()
        for level in G.Level.allCases {
            for seed in 0..<8 {
                var rng = G.Random(seed: UInt64(100 + seed))
                let b = G.Seesaw.generate(level: level, using: &rng)
                let right: (G.Seesaw.Move) -> Bool = { if case .set(let c, let m) = $0 { m == b.solution[c] } else { false } }
                seen.formUnion(try Self.playByHints(b, right: right))
                let moves = b.givens.indices.filter { b.givens[$0] == nil }.map { G.Seesaw.Move.set($0, b.solution[$0]) }
                try Self.hintsFromPartway(b, moves: moves, seed: UInt64(seed), right: right)
                // A wrong mark is the first thing a hint points at.
                var game = G.PuzzleGame(b, at: 0)
                let open = b.givens.firstIndex(of: nil)!
                _ = try game.play(.set(open, b.solution[open].other), at: 0)
                #expect(try game.hint(at: 0).hint == G.PuzzleHint(move: .set(open, nil), reason: .mistake, cells: [open]))
            }
        }
        #expect(seen.isSuperset(of: ["pair", "gap", "clue", "full", "line", "chain"]), "\(seen)")
    }

    @Test func sudokuHintsAreAlwaysRight() throws {
        var seen = Set<String>()
        for level in G.Level.allCases {
            for seed in 0..<(level == .hard ? 6 : 10) {
                var rng = G.Random(seed: UInt64(200 + seed))
                let b = G.Sudoku.generate(level: level, using: &rng)
                let right: (G.Sudoku.Move) -> Bool = { if case .set(let c, let d) = $0 { d == b.solution[c] } else { false } }
                seen.formUnion(try Self.playByHints(b, right: right))
                let moves = b.givens.indices.filter { b.givens[$0] == 0 }.map { G.Sudoku.Move.set($0, b.solution[$0]) }
                try Self.hintsFromPartway(b, moves: moves, seed: UInt64(seed), right: right)
                var game = G.PuzzleGame(b, at: 0)
                let open = b.givens.firstIndex(of: 0)!
                _ = try game.play(.set(open, b.solution[open] % b.size + 1), at: 0)
                #expect(try game.hint(at: 0).hint == G.PuzzleHint(move: .clear(open), reason: .mistake, cells: [open]))
            }
        }
        #expect(seen.isSuperset(of: ["lastInBox", "lastInCell", "locked"]), "\(seen)")
    }

    @Test func gardenPlotsHintsAreAlwaysRight() throws {
        var seen = Set<String>()
        for level in G.Level.allCases {
            for seed in 0..<8 {
                var rng = G.Random(seed: UInt64(300 + seed))
                let b = G.GardenPlots.generate(level: level, using: &rng)
                let right: (G.GardenPlots.Move) -> Bool = { if case .draw(let p) = $0 { b.solution.contains(p) } else { false } }
                seen.formUnion(try Self.playByHints(b, right: right))
                try Self.hintsFromPartway(b, moves: b.solution.map { .draw($0) }, seed: UInt64(seed), right: right)
                // A plot that isn't in the solution: the hint takes it away.
                var game = G.PuzzleGame(b, at: 0)
                let wrong = [G.GardenPlots.Plot(row: 0, column: 0, height: 1, width: 1), G.GardenPlots.Plot(row: 0, column: 0, height: 1, width: 2)]
                    .first { !b.solution.contains($0) }!
                _ = try game.play(.draw(wrong), at: 0)
                let hint = try game.hint(at: 0).hint
                #expect(hint.reason == .mistake && hint.move == .erase(0))
            }
        }
        #expect(seen.isSuperset(of: ["onlyFit", "onlyReach"]), "\(seen)")
    }

    @Test func blossomsHintsAreAlwaysRight() throws {
        var seen = Set<String>()
        for level in G.Level.allCases {
            for seed in 0..<8 {
                var rng = G.Random(seed: UInt64(400 + seed))
                let b = G.Blossoms.generate(level: level, using: &rng)
                let right: (G.Blossoms.Move) -> Bool = { if case .set(let c, .blossom) = $0 { b.isBlossom(c) } else { false } }
                seen.formUnion(try Self.playByHints(b, right: right))
                // Right marks part of the way: blossoms, and dots where none grows.
                let cells = 0..<(b.size * b.size)
                let moves = cells.map { G.Blossoms.Move.set($0, b.isBlossom($0) ? .blossom : .dot) }
                try Self.hintsFromPartway(b, moves: moves, seed: UInt64(seed), right: right)
                var game = G.PuzzleGame(b, at: 0)
                let blossom = cells.first(where: b.isBlossom)!
                _ = try game.play(.set(blossom, .dot), at: 0)
                #expect(try game.hint(at: 0).hint == G.PuzzleHint(move: .set(blossom, nil), reason: .mistake, cells: [blossom]))
            }
        }
        #expect(seen.isSuperset(of: ["lastInRow", "lastInColumn", "lastInBed", "locked", "wouldEmpty", "group"]), "\(seen)")
    }

    // MARK: Playing

    @Test func seesawShowsWhereARuleBreaks() throws {
        var rng = G.Random(seed: 3)
        let solution = G.Seesaw.generate(level: .easy, using: &rng).solution
        let b = G.Seesaw(level: .easy, size: 6, givens: [.heart] + Array(repeating: nil, count: 35),
                         edges: [G.Seesaw.Edge(cell: 6, down: false, clue: .same)], solution: solution)
        var game = G.PuzzleGame(b, at: 0)
        #expect(throws: G.Refusal("given")) { _ = try game.play(.cycle(0), at: 0) }
        #expect(throws: G.Refusal("off_board")) { _ = try game.play(.cycle(36), at: 0) }
        #expect(try game.play(.cycle(1), at: 1).isEmpty && game.grid[1] == .heart)
        #expect(try game.play(.cycle(2), at: 2) == [.mistake])
        #expect(game.conflicts == [G.PuzzleConflict(rule: .threeInARow, cells: [0, 1, 2])])
        _ = try game.play(.cycle(2), at: 3)
        #expect(game.grid[2] == .star && game.conflicts.isEmpty)
        _ = try game.play(.set(3, .heart), at: 4)
        _ = try game.play(.set(4, .heart), at: 5)
        #expect(game.conflicts == [G.PuzzleConflict(rule: .tooMany, cells: [0, 1, 3, 4])])
        _ = try game.play(.set(6, .heart), at: 6)
        #expect(try game.play(.set(7, .star), at: 7) == [.mistake])
        #expect(game.conflicts.contains(G.PuzzleConflict(rule: .clue, cells: [6, 7])))
        // Undo, back to the start, undo that too.
        _ = try game.undo(at: 8)
        #expect(game.grid[7] == nil)
        _ = try game.clear(at: 9)
        #expect(game.grid == b.start)
        _ = try game.undo(at: 10)
        #expect(game.grid[6] == .heart)
        var fresh = G.PuzzleGame(b, at: 0)
        #expect(throws: G.Refusal("nothing_to_undo")) { _ = try fresh.undo(at: 0) }
    }

    @Test func aSolvedPuzzleStopsTheClock() throws {
        var rng = G.Random(seed: 9)
        let b = G.Seesaw.generate(level: .easy, using: &rng)
        var game = G.PuzzleGame(b, day: 300, at: 100)
        #expect(game.elapsed(at: 110) == 10)
        game.pause(at: 110)
        game.resume(at: 200)
        let open = b.givens.indices.filter { b.givens[$0] == nil }
        for cell in open.dropLast() { #expect(try game.play(.set(cell, b.solution[cell]), at: 205).isEmpty) }
        #expect(try game.play(.set(open.last!, b.solution[open.last!]), at: 230) == [.roundOver(winner: .you)])
        #expect(game.solved && game.day == 300 && game.elapsed(at: 999) == 40 && !game.canUndo)
        #expect(throws: G.Refusal("over")) { _ = try game.play(.cycle(open[0]), at: 231) }
        #expect(throws: G.Refusal("over")) { _ = try game.hint(at: 231) }
        game.resume(at: 500)
        #expect(game.elapsed(at: 600) == 40)
    }

    @Test func sudokuNotesAndConflicts() throws {
        var rng = G.Random(seed: 4)
        let b = G.Sudoku.generate(level: .easy, using: &rng)
        let open = b.givens.indices.filter { b.givens[$0] == 0 }
        let cell = open[0]
        let peer = open.first { $0 != cell && $0 / 6 == cell / 6 }!
        var game = G.PuzzleGame(b, at: 0)
        _ = try game.play(.note(peer, 4), at: 0)
        _ = try game.play(.note(peer, 5), at: 0)
        _ = try game.play(.note(peer, 5), at: 0)
        #expect(game.grid.noted(peer) == [4])
        _ = try game.play(.set(cell, 4), at: 0)
        #expect(game.grid.noted(peer).isEmpty, "a placed number tidies its peers' notes")
        #expect(throws: G.Refusal("filled")) { _ = try game.play(.note(cell, 1), at: 0) }
        #expect(throws: G.Refusal("not_a_number")) { _ = try game.play(.set(peer, 7), at: 0) }
        let given = b.givens.firstIndex { $0 != 0 }!
        #expect(throws: G.Refusal("given")) { _ = try game.play(.clear(given), at: 0) }
        // The same number twice in a row.
        _ = try game.play(.set(peer, 4), at: 0)
        #expect(game.conflicts.contains { $0.rule == .row && Set($0.cells).isSuperset(of: [cell, peer]) })
    }

    @Test func gardenPlotsDrawAndErase() throws {
        let b = G.GardenPlots(level: .easy, width: 3, height: 2, clues: [.init(cell: 0, area: 4), .init(cell: 5, area: 2)],
                              solution: [.init(row: 0, column: 0, height: 2, width: 2), .init(row: 0, column: 2, height: 2, width: 1)])
        #expect(G.GardenPlots.Plot.corners(4, 0, width: 3) == .init(row: 0, column: 0, height: 2, width: 2))
        var game = G.PuzzleGame(b, at: 0)
        _ = try game.play(.draw(.corners(0, 1, width: 3)), at: 0)
        #expect(game.conflicts == [G.PuzzleConflict(rule: .wrongSize, cells: [0, 1])])
        _ = try game.play(.draw(.corners(0, 5, width: 3)), at: 0)
        #expect(game.grid.count == 1 && game.conflicts.map(\.rule) == [.twoNumbers], "the new plot replaced the one it overlaps")
        _ = try game.play(.erase(4), at: 0)
        #expect(game.grid.isEmpty)
        _ = try game.play(.draw(.corners(1, 1, width: 3)), at: 0)
        #expect(game.conflicts.map(\.rule) == [.noNumber])
        #expect(throws: G.Refusal("off_board")) { _ = try game.play(.draw(.init(row: 1, column: 1, height: 2, width: 1)), at: 0) }
        _ = try game.play(.draw(b.solution[0]), at: 0)
        #expect(try game.play(.draw(b.solution[1]), at: 0) == [.roundOver(winner: .you)])
    }

    @Test func blossomsShowWhereARuleBreaks() throws {
        var rng = G.Random(seed: 5)
        let b = G.Blossoms.generate(level: .easy, using: &rng)
        var game = G.PuzzleGame(b, at: 0)
        _ = try game.play(.cycle(0), at: 0)
        #expect(game.grid[0] == .dot)
        _ = try game.play(.cycle(0), at: 0)
        #expect(game.grid[0] == .blossom)
        #expect(try game.play(.set(7, .blossom), at: 0) == [.mistake])
        #expect(game.conflicts.contains(G.PuzzleConflict(rule: .touching, cells: [0, 7])))
        _ = try game.play(.set(7, nil), at: 0)
        _ = try game.play(.set(3, .blossom), at: 0)
        #expect(game.conflicts.contains(G.PuzzleConflict(rule: .row, cells: [0, 3])))
        _ = try game.clear(at: 0)
        for c in 0..<6 { _ = try game.play(.set(c * 6 + 5, .dot), at: 0) }
        #expect(game.conflicts.contains(G.PuzzleConflict(rule: .noRoom, cells: [5, 11, 17, 23, 29, 35])))
    }

    // MARK: The daily board

    @Test func theDailyBoardIsTheSameEverywhere() throws {
        // A fingerprint of each puzzle's board for 31 October 2026: a change to a generator, the random numbers or
        // anything that orders by hash shows here (it would give people different boards on the same day).
        func fingerprint<P: PuzzleRules>(_ board: P) throws -> UInt64 {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .sortedKeys
            return G.stableHash(String(decoding: try encoder.encode(board), as: UTF8.self))
        }
        let day = G.DailyWord.day(year: 2026, month: 10, day: 31)
        func prints(_ level: G.Level) throws -> [UInt64] {
            [try fingerprint(G.GardenPlots.daily(day: day, level: level)), try fingerprint(G.Seesaw.daily(day: day, level: level)),
             try fingerprint(G.Sudoku.daily(day: day, level: level)), try fingerprint(G.Blossoms.daily(day: day, level: level))]
        }
        // Fair's boards are the ones every Mac had when Fair was the only daily board.
        let (fair, easy, hard) = (try prints(.fair), try prints(.easy), try prints(.hard))
        #expect(fair == Self.dailyPrints, "\(fair)")
        #expect(easy == Self.easyPrints, "\(easy)")
        #expect(hard == Self.hardPrints, "\(hard)")
        #expect(G.Seesaw.daily(day: day, level: .easy) != G.Seesaw.daily(day: day + 1, level: .easy))
        for level in G.Level.allCases {
            #expect(G.Blossoms.daily(day: day, level: level).level == level)
        }
        #expect(G.Sudoku.daily(day: day, level: .fair).size == 6 && G.Sudoku.daily(day: day, level: .hard).size == 9)
    }

    static let dailyPrints: [UInt64] = [12050018935995651886, 11698688161655048454, 5225241921642056051, 15984180569653739426]
    static let easyPrints: [UInt64] = [12385528809662317778, 2282117429718119570, 15368203611496630347, 15522009183301338574]
    static let hardPrints: [UInt64] = [18043583022245139531, 10355169371086943102, 6036484252021277877, 18307837935798848967]

    // MARK: Records

    @Test func recordsKeepBestTimesAndStreaks() throws {
        var r = G.PuzzleRecord()
        #expect(r.finish(level: .fair, day: 10, seconds: 90, hints: 0) == false, "a first time is a best, not a record broken")
        #expect(r.best["fair"] == 90 && r.streak == 1 && r.dailies == 1)
        #expect(r.finish(level: .fair, day: 10, seconds: 30, hints: 0) == false && r.dailies == 1, "a day counts once")
        #expect(r.finish(level: .fair, day: 11, seconds: 60, hints: 0) && r.streak == 2 && r.best["fair"] == 60)
        // Each level has its own board of the day; the streak counts days, whichever boards were solved.
        #expect(r.finish(level: .easy, day: 11, seconds: 40, hints: 0) == false && r.streak == 2 && r.dailies == 3)
        #expect(r.finish(level: .easy, day: 11, seconds: 20, hints: 0) == false && r.dailies == 3, "a level's board counts once a day")
        #expect(r.tile(today: 11) == G.PuzzleRecord.Tile(solved: [.init(level: .easy, seconds: 40), .init(level: .fair, seconds: 60)], streak: 2))
        #expect(r.tile(today: 11).left == 1 && r.solved(.easy, day: 11) && !r.solved(.hard, day: 11))
        #expect(r.tile(today: 12) == G.PuzzleRecord.Tile(solved: [], streak: 2))
        #expect(r.tile(today: 13).streak == 0, "a missed day ends the streak")
        #expect(r.finish(level: .hard, day: 13, seconds: 20, hints: 1) == false && r.streak == 1 && r.bestStreak == 2)
        #expect(r.best["hard"] == nil, "a time with hints is no best")
        r.finish(level: .hard, day: nil, seconds: 300, hints: 0)
        r.finish(level: .hard, day: nil, seconds: 400, hints: 0)
        #expect(r.practice["hard"] == 2 && r.best["hard"] == 300 && r.dailies == 4)
        // A record from an older Playtime, or with a field this one doesn't know, still loads; its one daily board
        // was Fair's.
        let old = try JSONDecoder().decode(G.PuzzleRecord.self, from: Data(#"{"streak": 3, "best": {"easy": 50}, "later": true, "lastSolvedDay": 9, "lastSeconds": 77}"#.utf8))
        #expect(old.streak == 3 && old.best == ["easy": 50] && old.practice.isEmpty)
        #expect(old.days == ["fair": 9] && old.daySeconds == ["fair": 77] && old.tile(today: 9).solved == [.init(level: .fair, seconds: 77)])
        #expect(try JSONDecoder().decode(G.PuzzleRecord.self, from: JSONEncoder().encode(old)) == old)
        let records = try JSONDecoder().decode(PlaytimeRecords.self, from: JSONEncoder().encode(PlaytimeRecords()))
        #expect(records.puzzles == nil)
        var withPuzzles = records
        withPuzzles.puzzles = ["sudoku": r]
        #expect(try JSONDecoder().decode(PlaytimeRecords.self, from: JSONEncoder().encode(withPuzzles)) == withPuzzles)
    }

    // MARK: Timing

    /// Every board in about a third of a second on an M-series Mac in release (they take a few ms to 0.1 s there);
    /// a debug build is many times slower, so it only gets a looser bound.
    @Test func boardsAreMadeQuickly() {
        #if DEBUG
        let budget = 15.0
        #else
        let budget = 0.3
        #endif
        func slowest<P: PuzzleRules>(_ type: P.Type, _ level: G.Level) -> Double {
            (0..<8).map { seed in
                var rng = G.Random(seed: UInt64(1000 + seed))
                let start = Date()
                _ = P.generate(level: level, using: &rng)
                return Date().timeIntervalSince(start)
            }.max()!
        }
        for level in G.Level.allCases {
            for (name, time) in [("plots", slowest(G.GardenPlots.self, level)), ("seesaw", slowest(G.Seesaw.self, level)),
                                 ("sudoku", slowest(G.Sudoku.self, level)), ("blossoms", slowest(G.Blossoms.self, level))] {
                #expect(time < budget, "\(name) \(level): \(Int(time * 1000)) ms")
            }
        }
    }
}

/// Independent solution counters (stopping at 2), sharing nothing with the generators.
enum Brute {
    static func seesaw(_ b: Games.Seesaw) -> Int {
        let n = b.size
        var g = b.givens.map { $0?.rawValue ?? 0 }
        var count = 0
        func ok(_ cell: Int) -> Bool {
            let r = cell / n, c = cell % n
            for line in [(0..<n).map { r * n + $0 }, (0..<n).map { $0 * n + c }] {
                for mark: Int8 in [1, 2] where line.filter({ g[$0] == mark }).count > n / 2 { return false }
                for i in 0..<(n - 2) where g[line[i]] != 0 && g[line[i]] == g[line[i + 1]] && g[line[i]] == g[line[i + 2]] { return false }
            }
            for e in b.edges {
                let o = e.down ? e.cell + n : e.cell + 1
                if g[e.cell] != 0, g[o] != 0, (g[e.cell] == g[o]) != (e.clue == .same) { return false }
            }
            return true
        }
        func go(_ i: Int) {
            if count > 1 { return }
            if i == n * n { count += 1; return }
            if g[i] != 0 { if ok(i) { go(i + 1) }; return }
            for mark: Int8 in [1, 2] {
                g[i] = mark
                if ok(i) { go(i + 1) }
                g[i] = 0
            }
        }
        go(0)
        return count
    }

    static func sudoku(_ b: Games.Sudoku) -> Int {
        let n = b.size
        var g = b.givens
        var rows = Array(repeating: 0, count: n), cols = rows, boxes = rows
        func mark(_ cell: Int, _ d: Int) {
            rows[cell / n] ^= 1 << d
            cols[cell % n] ^= 1 << d
            boxes[b.box(of: cell)] ^= 1 << d
        }
        for cell in g.indices where g[cell] != 0 { mark(cell, g[cell]) }
        var count = 0
        func go(_ i: Int) {
            if count > 1 { return }
            if i == n * n { count += 1; return }
            if g[i] != 0 { go(i + 1); return }
            let used = rows[i / n] | cols[i % n] | boxes[b.box(of: i)]
            for d in 1...n where used >> d & 1 == 0 {
                g[i] = d
                mark(i, d)
                go(i + 1)
                mark(i, d)
                g[i] = 0
            }
        }
        go(0)
        return count
    }

    static func plots(_ b: Games.GardenPlots) -> Int {
        let w = b.width, h = b.height
        // Every rectangle around each number with its area and no other number in it.
        let options: [[Set<Int>]] = b.clues.map { clue in
            var found: [Set<Int>] = []
            for top in 0..<h {
                for left in 0..<w {
                    for ph in 1...(h - top) {
                        for pw in 1...(w - left) where ph * pw == clue.area {
                            let cells = Set((top..<(top + ph)).flatMap { r in (left..<(left + pw)).map { r * w + $0 } })
                            if cells.contains(clue.cell), b.clues.filter({ cells.contains($0.cell) }).count == 1 { found.append(cells) }
                        }
                    }
                }
            }
            return found
        }
        var covered = Set<Int>(), used = Array(repeating: false, count: b.clues.count), count = 0
        func go() {
            if count > 1 { return }
            guard let cell = (0..<(w * h)).first(where: { !covered.contains($0) }) else { count += 1; return }
            for k in b.clues.indices where !used[k] {
                for option in options[k] where option.contains(cell) && option.isDisjoint(with: covered) {
                    used[k] = true
                    covered.formUnion(option)
                    go()
                    covered.subtract(option)
                    used[k] = false
                }
            }
        }
        go()
        return count
    }

    static func blossoms(_ b: Games.Blossoms) -> Int {
        let n = b.size
        var count = 0
        func go(_ placed: [Int]) {
            if count > 1 { return }
            let r = placed.count
            if r == n { count += 1; return }
            for c in 0..<n {
                let cell = r * n + c
                guard !placed.contains(c), placed.last.map({ abs($0 - c) > 1 }) ?? true else { continue }
                guard !placed.enumerated().contains(where: { b.beds[$0.offset * n + $0.element] == b.beds[cell] }) else { continue }
                go(placed + [c])
            }
        }
        go([])
        return count
    }
}
