import Foundation
import Testing
@testable import SidefolkExtensionKit
@testable import ext_playtime

/// The four puzzles as Sidefolk sees them (D79, the puzzles), in the serialized screens suite since they share
/// Playtime's records: today's board at each level, kept as far as played, the board's puzzle part and buttons, a hint
/// played with "Do it", a whole solve through the screen by taking every hint, the end card after it naming the boards
/// left today, the level picked, practice boards after the day's, and the records, Home rows and Today tile. Words are compared with `L` in the test's own
/// language, so a suite running beside it in another language can't trip it.
extension PlaytimeScreensTests {
    /// The clicks, drags and numbers that play a puzzle's own move through its screen.
    static func clicks(_ move: Games.Seesaw.Move, on grid: Games.Seesaw.Grid, size n: Int) -> [Move] {
        guard case .set(let c, let mark) = move else { return [] }
        let order: [Games.Seesaw.Mark?] = [nil, .heart, .star]
        let times = (order.firstIndex(of: mark)! - order.firstIndex(of: grid[c])! + 3) % 3
        return Array(repeating: .cell(row: c / n, column: c % n), count: times)
    }

    static func clicks(_ move: Games.Blossoms.Move, on grid: Games.Blossoms.Grid, size n: Int) -> [Move] {
        guard case .set(let c, let mark) = move else { return [] }
        let order: [Games.Blossoms.Mark?] = [nil, .dot, .blossom]
        let times = (order.firstIndex(of: mark)! - order.firstIndex(of: grid[c])! + 3) % 3
        return Array(repeating: .cell(row: c / n, column: c % n), count: times)
    }

    static func clicks(_ move: Games.Sudoku.Move, size n: Int) -> [Move] {
        switch move {
        case .set(let c, let d): [.place(row: c / n, column: c % n, value: d, note: false)]
        case .clear(let c): [.place(row: c / n, column: c % n, value: 0, note: false)]
        case .note: []
        }
    }

    static func clicks(_ move: Games.GardenPlots.Move, width w: Int) -> [Move] {
        switch move {
        case .draw(let p): [.area(row: p.row, column: p.column, toRow: p.row + p.height - 1, toColumn: p.column + p.width - 1)]
        case .erase(let c): [.cell(row: c / w, column: c % w)]
        }
    }

    /// Solves the open board through the screen, taking a hint before every move; returns the board each hint shows
    /// (marks all right by then) and the last.
    @discardableResult
    static func solve<K: PuzzleKind>(_ kind: K.Type, _ s: inout PuzzleEngine<K>.State, clicks: (K.Rules.Move, PuzzleEngine<K>.State) -> [Move]) -> [Board] {
        var random = Games.Random(seed: 1), boards: [Board] = []
        var events: [Games.Event] = []
        for _ in 0..<300 where !s.game.solved {
            events = GameTable.play(PuzzleScreen<K>.self, .button("hint"), on: &s, random: &random)
            boards.append(PuzzleScreen<K>.board(s, events: events, options: options()))
            guard let hint = s.hint else { break }
            // A click cycles through the marks, so one on the way may break a rule a moment.
            for move in clicks(hint.move, s) { events = GameTable.play(PuzzleScreen<K>.self, move, on: &s, random: &random) }
        }
        boards.append(PuzzleScreen<K>.board(s, events: events, options: options()))
        return boards
    }

    static func puzzle(_ b: Board) -> [String: Any]? { part(b, "puzzle") }

    @Test func puzzlesPlayTodaysBoardsThenPractice() throws {
        let date = ISO8601DateFormatter().date(from: "2026-11-01T09:00:00Z")!
        DailyWordEngine.now = { date }
        defer { DailyWordEngine.now = { Date() } }
        PlaytimeRecords.update { $0 = PlaytimeRecords() }
        try Language.with("en", strings: PlaytimeGameTests.strings) {
            var random = Games.Random(seed: 1)
            let o = Self.options()
            let today = DailyWordEngine.today()
            // Seesaw from the menu (no level asked, none picked yet): today's Fair board, kept as far as played.
            var s = PuzzleEngine<SeesawKind>.start(level: .fair, options: o, random: &random)
            #expect(s.game.day == today && s.game.level == .fair)
            #expect(s.game.puzzle == Games.Seesaw.daily(day: today, level: .fair))
            let first = PuzzleScreen<SeesawKind>.board(s, events: [.opened], options: o)
            let grid = try #require(Self.puzzle(first))
            #expect(grid["input"] as? String == "tap" && grid["rows"] as? Int == 6 && (grid["edges"] as? [Any])?.isEmpty == false)
            #expect((grid["clock"] as? [String: Any])?["running"] as? Bool == true)
            #expect(Self.part(first, "prompt")?["eyebrow"] as? String == L("Today's puzzle") + " · " + ScreenKit.level(.fair))
            let buttons = Self.parts(first).filter { $0["type"] as? String == "button" }.map { $0["move"] as! String }
            #expect(buttons == ["hint", "undo", "clear"])
            let open = s.game.puzzle.givens.firstIndex(of: nil)!
            _ = GameTable.play(PuzzleScreen<SeesawKind>.self, .cell(row: open / 6, column: open % 6), on: &s, random: &random)
            let given = s.game.puzzle.givens.firstIndex { $0 != nil }!
            let refused = GameTable.play(PuzzleScreen<SeesawKind>.self, .cell(row: given / 6, column: given % 6), on: &s, random: &random)
            #expect(Self.part(PuzzleScreen<SeesawKind>.board(s, events: refused, options: o), "note")?["text"] as? String == L("That one is part of the puzzle."))
            let reopened = PuzzleEngine<SeesawKind>.start(level: .fair, options: o, random: &random)
            #expect(reopened.game.grid == s.game.grid && reopened.game.day == s.game.day, "reopening carries on")

            // A hint, then "Do it" (H again) plays it: one hint, counted once.
            _ = GameTable.play(PuzzleScreen<SeesawKind>.self, .button("hint"), on: &s, random: &random)
            let hint = try #require(s.hint)
            let hinted = PuzzleScreen<SeesawKind>.board(s, events: [.hint], options: o)
            let doIt = try #require(Self.parts(hinted).first { $0["move"] as? String == "do_hint" })
            #expect(doIt["key"] as? String == "h" && doIt["label"] as? String == L("Do it"))
            #expect(!Self.parts(hinted).contains { $0["move"] as? String == "hint" })
            var expected = s.game
            _ = try expected.play(hint.move, at: 0)
            _ = GameTable.play(PuzzleScreen<SeesawKind>.self, .button("do_hint"), on: &s, random: &random)
            #expect(s.game.grid == expected.grid && s.game.hints == 1 && s.hint == nil)
            let refusedAgain = GameTable.play(PuzzleScreen<SeesawKind>.self, .button("do_hint"), on: &s, random: &random)
            #expect(refusedAgain == [.refused("not_now")] && s.game.hints == 1, "nothing to do without a hint shown")

            // Solved through its screen, hint by hint: never a mistake, then the end card naming the boards left today.
            let boards = Self.solve(SeesawKind.self, &s) { move, s in Self.clicks(move, on: s.game.grid, size: 6) }
            #expect(s.game.solved && s.game.hints > 1)
            #expect(boards.allSatisfy { !(Self.puzzle($0)?["cells"] as? [[String: Any]] ?? []).contains { $0["state"] as? String == "conflict" } },
                    "a hint is taken with every mark right")
            let end = try #require(boards.last)
            #expect(end.over && Self.part(end, "result")?["tone"] as? String == "good" && Self.part(end, "choice")?["name"] as? String == "level")
            let waiting = L(one: "Today's {levels} board is still waiting.", other: "Today's {levels} boards are still waiting.", count: 2,
                            ["levels": ScreenKit.list([ScreenKit.level(.easy), ScreenKit.level(.hard)])])
            #expect(Self.part(end, "result")?["line"] as? String == waiting)
            #expect(end.companion?.move == "celebrate" && (Self.puzzle(end)?["clock"] as? [String: Any])?["running"] as? Bool == false)
            let record = PlaytimeRecords.puzzle(SeesawKind.id)
            #expect(record.streak == 1 && record.dailies == 1 && record.solved(.fair, day: today) && record.best["fair"] == nil, "a time with hints is no best")
            #expect(PlaytimeRecords.load().history.first?.game == SeesawKind.id)

            // The level picked on the end card: that level's board of the day, remembered for next time.
            _ = GameTable.play(PuzzleScreen<SeesawKind>.self, .choice(name: "level", value: "easy"), on: &s, random: &random)
            #expect(s.game.day == today && s.game.level == .easy && s.game.puzzle == Games.Seesaw.daily(day: today, level: .easy))
            let easy = PuzzleEngine<SeesawKind>.start(level: .fair, options: o, random: &random)
            #expect(easy.game.day == today && easy.game.level == .easy, "opened again at the level last picked")
            var asked = o
            asked.asked = .hard
            let hard = PuzzleEngine<SeesawKind>.start(level: .hard, options: asked, random: &random)
            #expect(hard.game.day == today && hard.game.level == .hard && hard.game.puzzle.size == 8, "a level asked for wins")

            // Easy solved too: one board left; then "Play another" deals practice at Easy, as does opening it again.
            let easyEnd = Self.solve(SeesawKind.self, &s) { move, s in Self.clicks(move, on: s.game.grid, size: s.game.puzzle.size) }.last!
            #expect(Self.part(easyEnd, "result")?["line"] as? String
                    == L(one: "Today's {levels} board is still waiting.", other: "Today's {levels} boards are still waiting.", count: 1,
                         ["levels": ScreenKit.list([ScreenKit.level(.hard)])]))
            #expect(PlaytimeRecords.puzzle(SeesawKind.id).streak == 1 && PlaytimeRecords.puzzle(SeesawKind.id).dailies == 2, "one day, one streak")
            _ = GameTable.play(PuzzleScreen<SeesawKind>.self, .button("another"), on: &s, random: &random)
            #expect(s.game.day == nil && s.game.level == .easy)
            let next = PuzzleEngine<SeesawKind>.start(level: .fair, options: o, random: &random)
            #expect(next.game.day == nil && next.game.level == .easy, "today's Easy board is done: practice at Easy")
            let eyebrow = Self.part(PuzzleScreen<SeesawKind>.board(next, events: [], options: o), "prompt")?["eyebrow"] as? String
            #expect(eyebrow == L("Practice") + " · " + ScreenKit.level(.easy))
            // Home: today's two boards with their times, one left.
            let row = PuzzleScreen<SeesawKind>.detail()
            #expect(row.hasPrefix(L("Today: {solved}", ["solved": ScreenKit.level(.easy) + " "])) && row.contains(", " + ScreenKit.level(.fair) + " "), "\(row)")
            #expect(row.contains(L(one: "{count} more to play", other: "{count} more to play", count: 1)), "\(row)")
        }
    }

    @Test func aDailyBoardKeptBeforeLevelsStillOpens() throws {
        let date = ISO8601DateFormatter().date(from: "2026-11-03T09:00:00Z")!
        DailyWordEngine.now = { date }
        defer { DailyWordEngine.now = { Date() } }
        // An older Playtime kept today's (Fair) board under the puzzle's id alone.
        let today = DailyWordEngine.today()
        var old = Games.PuzzleGame(Games.Blossoms.daily(day: today, level: .fair), day: today, at: 0)
        _ = try old.play(.cycle(0), at: 1)
        let kept = old
        PlaytimeRecords.update { $0 = PlaytimeRecords(); $0.puzzleDays = [BlossomsKind.id: try! JSONEncoder().encode(kept)] }
        var random = Games.Random(seed: 1)
        var s = PuzzleEngine<BlossomsKind>.start(level: .fair, options: Self.options(), random: &random)
        #expect(s.game.grid == kept.grid && s.game.day == today)
        _ = GameTable.play(PuzzleScreen<BlossomsKind>.self, .cell(row: 1, column: 1), on: &s, random: &random)
        let days = PlaytimeRecords.load().puzzleDays ?? [:]
        #expect(days[BlossomsKind.id] == nil && days[BlossomsKind.id + ".fair"] != nil, "kept again under its level")
    }

    @Test func everyPuzzleSolvesThroughItsScreen() throws {
        let date = ISO8601DateFormatter().date(from: "2026-11-02T09:00:00Z")!
        DailyWordEngine.now = { date }
        defer { DailyWordEngine.now = { Date() } }
        PlaytimeRecords.update { $0 = PlaytimeRecords() }
        try Language.with("de", strings: PlaytimeGameTests.strings) {
            var random = Games.Random(seed: 2)
            let o = Self.options("de")
            var plots = PuzzleEngine<GardenPlotsKind>.start(level: .fair, options: o, random: &random)
            let w = plots.game.puzzle.width
            let start = try #require(Self.puzzle(PuzzleScreen<GardenPlotsKind>.board(plots, events: [], options: o)))
            #expect(start["input"] as? String == "drag" && (start["cells"] as! [[String: Any]]).filter { $0["given"] as? Bool == true }.count == plots.game.puzzle.clues.count)
            // A one-square plot by a click, taken away by another; a dragged plot replaces what it overlaps.
            _ = GameTable.play(PuzzleScreen<GardenPlotsKind>.self, .cell(row: 0, column: 0), on: &plots, random: &random)
            #expect(plots.game.grid.count == 1)
            _ = GameTable.play(PuzzleScreen<GardenPlotsKind>.self, .cell(row: 0, column: 0), on: &plots, random: &random)
            #expect(plots.game.grid.isEmpty)
            _ = GameTable.play(PuzzleScreen<GardenPlotsKind>.self, .area(row: 1, column: 1, toRow: 0, toColumn: 0), on: &plots, random: &random)
            #expect(plots.game.grid == [Games.GardenPlots.Plot(row: 0, column: 0, height: 2, width: 2)])
            _ = GameTable.play(PuzzleScreen<GardenPlotsKind>.self, .button("clear"), on: &plots, random: &random)
            Self.solve(GardenPlotsKind.self, &plots) { move, _ in Self.clicks(move, width: w) }
            #expect(plots.game.solved)

            var sudoku = PuzzleEngine<SudokuKind>.start(level: .fair, options: o, random: &random)
            let n = sudoku.game.puzzle.size
            let cell = sudoku.game.puzzle.givens.firstIndex(of: 0)!
            _ = GameTable.play(PuzzleScreen<SudokuKind>.self, .place(row: cell / n, column: cell % n, value: 3, note: true), on: &sudoku, random: &random)
            let noted = try #require(Self.puzzle(PuzzleScreen<SudokuKind>.board(sudoku, events: [], options: o)))
            #expect((noted["cells"] as! [[String: Any]])[cell]["notes"] as? [Int] == [3] && noted["digits"] as? Int == 6 && noted["box"] as? [Int] == [2, 3])
            Self.solve(SudokuKind.self, &sudoku) { move, _ in Self.clicks(move, size: n) }
            #expect(sudoku.game.solved)

            var blossoms = PuzzleEngine<BlossomsKind>.start(level: .fair, options: o, random: &random)
            let size = blossoms.game.puzzle.size
            let cells = try #require(Self.puzzle(PuzzleScreen<BlossomsKind>.board(blossoms, events: [], options: o))?["cells"] as? [[String: Any]])
            #expect(Set(cells.compactMap { $0["region"] as? Int }) == Set(0..<size), "every bed has its colour")
            Self.solve(BlossomsKind.self, &blossoms) { move, s in Self.clicks(move, on: s.game.grid, size: size) }
            #expect(blossoms.game.solved)

            // Home and the Today tile: each puzzle's day, and streaks once they run past one day.
            let page = PlaytimePage.render().json
            let rows = ((page["sections"] as! [[String: Any]]).flatMap { ($0["blocks"] as? [[String: Any]]) ?? [] }
                .compactMap { $0["items"] as? [[String: Any]] }).flatMap { $0 }
            let garden = rows.first { $0["title"] as? String == L("Garden Plots") }?["detail"] as? String
            #expect(garden?.hasPrefix(L("Today: {solved}", ["solved": ScreenKit.level(.fair) + " "])) == true, "\(garden ?? "")")
            #expect(garden?.contains(L(one: "{count} more to play", other: "{count} more to play", count: 2)) == true, "\(garden ?? "")")
            let seesaw = rows.first { $0["title"] as? String == L("Seesaw") }?["detail"] as? String
            #expect(seesaw?.hasPrefix(L(one: "Today: {count} board to play", other: "Today: {count} boards to play", count: 3)) == true, "\(seesaw ?? "")")
            PlaytimeRecords.update { $0.puzzles?[SudokuKind.id]?.streak = 4; $0.puzzles?[SudokuKind.id]?.lastSolvedDay = DailyWordEngine.today() }
            let tile = (PlaytimePage.render().json["summary"] as? [String: Any])?["detail"] as? String
            #expect(tile?.contains("Sudoku 4") == true, "\(tile ?? "")")
            #expect(tile?.contains(L("Puzzles today: {n} of {total}", ["n": 3, "total": 12])) == true, "\(tile ?? "")")
        }
    }
}
