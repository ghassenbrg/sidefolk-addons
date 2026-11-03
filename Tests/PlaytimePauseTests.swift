import Foundation
import Testing
@testable import SidefolkExtensionKit
@testable import ext_playtime

/// The pause card: during any game you can keep playing, start again, change level or leave, and none of it touches a record. In a puzzle or Daily Word a new one is practice: today's stays
/// as far as it was played, and is what opens next.
@Suite(.serialized) @MainActor
struct PlaytimePauseTests {
    private func clear() {
        try? FileManager.default.removeItem(atPath: PlayTable.folder)
        PlaytimeRecords.update { $0 = PlaytimeRecords() }
    }

    private func open(_ game: String) -> String { PlayTable.open(SurfaceRequest(["session": "", "arguments": ["game": game]])).session }

    private func click(_ session: String, _ value: String, area: String = "button") -> Scene {
        PlayTable.move(SurfaceRequest(["session": session, "move": ["click": ["area": area, "value": value]]]))
    }

    private func key(_ session: String, _ id: String, _ character: String? = nil) -> Scene {
        var key: [String: Any] = ["id": id]
        if let character { key["char"] = character }
        return PlayTable.move(SurfaceRequest(["session": session, "move": ["key": key]]))
    }

    private func text(_ scene: Scene) -> String { String(decoding: (try? JSONSerialization.data(withJSONObject: scene.json)) ?? Data(), as: UTF8.self) }

    private func word(_ session: String, _ letters: String) {
        for c in letters { _ = key(session, "letter", String(c)) }
        _ = key(session, "draft_return")
        _ = PlayTable.move(SurfaceRequest(["session": session, "move": ["next": true]]))
    }

    @Test func everyGameCanBePausedAndGoesOnAsItWas() throws {
        clear()
        defer { clear() }
        try Language.with("en", strings: PlaytimeGameTests.strings) {
            for game in GameTable.drivers.keys.sorted() {
                let session = open(game)
                let paused = click(session, PauseMoves.pause)
                #expect(text(paused).contains("Paused") && text(paused).contains("Keep playing"), "\(game)")
                #expect(text(paused).contains(BoardDrawing.backMove), "\(game): leave")
                #expect(!text(paused).contains(PauseMoves.pause), "\(game): one card")
                let back = click(session, PauseMoves.resume)
                #expect(text(back).contains(PauseMoves.pause), "\(game): back in the game")
                PlayTable.close(SurfaceRequest(["session": session, "reason": "finished"]))
            }
            #expect(PlaytimeRecords.load().games.isEmpty, "no record moved")
        }
    }

    @Test func aNewGameStartsAtTheLevelPickedAndCountsForNothing() throws {
        clear()
        defer { clear() }
        try Language.with("en", strings: PlaytimeGameTests.strings) {
            let session = open("tictactoe")
            _ = key(session, "digit", "5")
            _ = click(session, PauseMoves.pause)
            let picked = click(session, "level|hard", area: "choice")
            #expect(text(picked).contains("Paused"), "picking a level doesn't start yet")
            let fresh = click(session, PauseMoves.newGame)
            #expect(text(fresh).contains(ScreenKit.level(.hard)))
            #expect(!text(fresh).contains("art/piece-"), "an empty board")
            #expect(PlaytimeRecords.load().games.isEmpty && PlaytimeRecords.load().history.isEmpty)
        }
    }

    @Test func aNewPuzzleBoardLeavesTodaysAlone() throws {
        clear()
        defer { clear() }
        try Language.with("en", strings: PlaytimeGameTests.strings) {
            let session = open("sudoku")
            _ = click(session, "hint")
            _ = click(session, "do_hint")
            let today = try #require(PlaytimeRecords.puzzleDay("sudoku", level: .fair, as: Games.PuzzleGame<SudokuKind.Rules>.self))
            _ = click(session, PauseMoves.pause)
            let practice = click(session, PauseMoves.newGame)
            #expect(text(practice).contains("Practice"))
            let kept = try #require(PlaytimeRecords.puzzleDay("sudoku", level: .fair, as: Games.PuzzleGame<SudokuKind.Rules>.self))
            #expect(kept.grid == today.grid, "today's as it was played")
            #expect(PlaytimeRecords.puzzle("sudoku").streak == 0)
            let again = click(session, PauseMoves.pause)
            #expect(text(again).contains("Back to today's puzzle"))
            let back = click(session, PauseMoves.today)
            #expect(text(back).contains("Today's puzzle"))
            // Opening it again starts from today's, too.
            PlayTable.close(SurfaceRequest(["session": session, "reason": "finished"]))
            let reopened = open("sudoku")
            #expect(text(click(reopened, PauseMoves.pause)).contains("Today's puzzle"))
        }
    }

    @Test func aNewWordLeavesTodaysAlone() throws {
        clear()
        defer { clear() }
        try Language.with("en", strings: PlaytimeGameTests.strings) {
            let session = open("daily_word")
            word(session, "crane")
            #expect(PlaytimeRecords.load().dailyGame?.rows.count == 1)
            _ = click(session, PauseMoves.pause)
            let practice = click(session, PauseMoves.newGame)
            #expect(text(practice).contains("Practice word"))
            word(session, "slate")
            #expect(PlaytimeRecords.load().dailyGame?.rows.count == 1, "a practice word isn't today's")
            let again = click(session, PauseMoves.pause)
            #expect(text(again).contains("Back to today's word"))
            let back = click(session, PauseMoves.today)
            #expect(text(back).contains("Today's word"))
            #expect(PlaytimeRecords.load().daily.played == 0, "no streak moved")
        }
    }

    /// Paused while a row is still turning: what was played stands and isn't offered again.
    @Test func pausingDuringAReveal() throws {
        clear()
        defer { clear() }
        try Language.with("en", strings: PlaytimeGameTests.strings) {
            let session = open("daily_word")
            for c in "crane" { _ = key(session, "letter", String(c)) }
            _ = key(session, "draft_return")
            #expect(PlaytimeRecords.load().dailyGame?.rows.count == 1)
            _ = click(session, PauseMoves.pause)
            let back = click(session, PauseMoves.resume)
            #expect(back.json["after_ms"] == nil, "no reveal still waiting")
            word(session, "slate")
            #expect(PlaytimeRecords.load().dailyGame?.rows.count == 2, "the next word goes in the next row, and crane isn't typed again")
        }
    }

    /// A practice board at another level still goes back to the level today's was being played at.
    @Test func backToTheLevelTodaysWasAt() throws {
        clear()
        defer { clear() }
        try Language.with("en", strings: PlaytimeGameTests.strings) {
            let session = open("sudoku")
            let start = click(session, PauseMoves.pause)
            #expect(text(start).contains("Today's puzzle"))
            _ = click(session, "level|hard", area: "choice")
            let practice = click(session, PauseMoves.newGame)
            #expect(text(practice).contains(ScreenKit.level(.hard)) && text(practice).contains("Practice"))
            _ = click(session, PauseMoves.pause)
            let back = click(session, PauseMoves.today)
            #expect(text(back).contains(ScreenKit.level(.fair)) && text(back).contains("Today's puzzle"))
        }
    }

    /// A game saved by the version before still opens.
    @Test func aSessionSavedBeforeStillLoads() throws {
        var json = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(LocalParts())) as? [String: Any])
        json["typedAhead"] = nil
        _ = try JSONDecoder().decode(LocalParts.self, from: JSONSerialization.data(withJSONObject: json))
    }
}
