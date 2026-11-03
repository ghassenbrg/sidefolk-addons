import Foundation
import Testing
@testable import SidefolkExtensionKit
@testable import ext_playtime

/// Nothing moves unless it means something: over a real play-through of Tic-tac-toe, Memory Pairs, Balloon Words and Daily Word, in each language's scripts, every part of the board
/// keeps its place and its height from the first move to the last before the end card, and in the build-ups between them.
@Suite(.serialized) @MainActor
struct PlaytimeStabilityG3 {
    nonisolated private func children(_ scene: Scene) throws -> [(id: String, y: Double, h: Double)] {
        let nodes = scene.json["nodes"] as? [[String: Any]] ?? []
        let board = try #require(nodes.first { $0["id"] as? String == "board" }, "the board has its box")
        #expect((board["type"] as? String) != "scroll", "nothing scrolls")
        return ((board["children"] as? [[String: Any]]) ?? []).map { ($0["id"] as? String ?? "?", $0["y"] as? Double ?? 0, $0["h"] as? Double ?? 0) }
    }

    /// Where the named nodes are: a place, all the way down from the board.
    nonisolated private func places(_ scene: Scene, prefixes: [String]) -> [String: [Double]] {
        var out: [String: [Double]] = [:]
        func visit(_ node: [String: Any], _ x: Double, _ y: Double) {
            let nx = x + (node["x"] as? Double ?? 0), ny = y + (node["y"] as? Double ?? 0)
            if let id = node["id"] as? String, prefixes.contains(where: { id.hasPrefix($0) }), !id.contains(".mark."), !id.contains(".bit.") {
                out[id] = [nx, ny, node["w"] as? Double ?? 0, node["h"] as? Double ?? 0]
            }
            for child in node["children"] as? [[String: Any]] ?? [] { visit(child, nx, ny) }
        }
        (scene.json["nodes"] as? [[String: Any]] ?? []).forEach { visit($0, 0, 0) }
        return out
    }

    private func stays<S: GameScreen>(_ screen: S.Type, language: String = "en", seed: UInt64, prefixes: [String]) throws {
        try Language.with(language, strings: PlaytimeGameTests.strings) {
            PlaytimeRecords.update { $0 = PlaytimeRecords() }
            let boards = try PlaytimeScreensTests.play(S.self, seed: seed, language: String(language.prefix(2))).boards
            let entry = GameCatalog.entry(S.id)!
            var previous: Board?
            var scenes: [(Scene, String)] = []
            for board in boards {
                if board.resultPart != nil, board.over { continue }
                if let (build, _) = Suspense.buildUp(from: previous, to: board, picked: nil), build.resultPart == nil {
                    var ctx = StageContext(entry: entry, previous: previous)
                    ctx.buildUp = true
                    scenes.append((BoardDrawing(build, ctx).scene(), "build-up"))
                }
                scenes.append((BoardDrawing(board, StageContext(entry: entry, previous: previous)).scene(), "board"))
                previous = board
            }
            var first: [(id: String, y: Double, h: Double)]?
            var known: [String: [Double]] = [:]
            for (scene, what) in scenes {
                let now = try children(scene)
                if let first {
                    #expect(now.map(\.y) == first.map(\.y) && now.map(\.h) == first.map(\.h), "\(S.id) \(language) \(what): \(now) after \(first)")
                } else {
                    first = now
                }
                for (id, place) in places(scene, prefixes: prefixes) {
                    if let was = known[id] { #expect(was == place, "\(S.id) \(language) \(what): \(id) moved from \(was) to \(place)") }
                    known[id] = place
                }
            }
            #expect(first != nil)
        }
    }

    @Test func ticTacToesCellsKeepTheirPlaces() throws {
        for seed in [1, 2, 3] as [UInt64] { try stays(TicTacToeScreen.self, seed: seed, prefixes: ["grid.plate", "grid.tray", "cell.", "stage", "bubble", "header"]) }
    }

    @Test func memoryPairsCardsKeepTheirPlaces() throws {
        for seed in [1, 2] as [UInt64] { try stays(MemoryPairsScreen.self, seed: seed, prefixes: ["grid.plate", "grid.tray", "cell.", "stage", "bubble", "header"]) }
    }

    @Test func balloonWordsKeepsItsBalloonsSignAndKeys() throws {
        for seed in [1, 2] as [UInt64] { try stays(BalloonWordsScreen.self, seed: seed, prefixes: ["life.", "lives", "letters", "keys", "key.", "stage", "bubble", "header"]) }
        for language in ["de", "ja", "ko", "ar", "zh-Hans"] { try stays(BalloonWordsScreen.self, language: language, seed: 1, prefixes: ["life.", "letters", "keys", "key.", "stage", "bubble", "header"]) }
    }

    @Test func dailyWordKeepsItsRowsLegendAndKeys() throws {
        try stays(DailyWordScreen.self, seed: 1, prefixes: ["letters", "legend", "keys", "key.", "stage", "bubble", "header", "entry"])
        for language in ["de", "ja", "ko", "ar", "zh-Hans"] { try stays(DailyWordScreen.self, language: language, seed: 1, prefixes: ["letters", "legend", "keys", "key.", "stage", "bubble", "header", "entry"]) }
    }

    /// Two people on one board: the same places.
    @Test func twoPeopleKeepThePlacesToo() throws {
        try Language.with("en", strings: PlaytimeGameTests.strings) {
            for run in [try PlaytimeTwoPlayersTests.duel(TicTacToeScreen.self, seed: 1), try PlaytimeTwoPlayersTests.duel(MemoryPairsScreen.self, seed: 1)] {
                let boards = run.filter { $0.gridPart != nil && !($0.over && $0.resultPart != nil) }
                #expect(!boards.isEmpty)
                let entry = GameCatalog.entry(boards[0].gridPart!.numpad ? TicTacToeScreen.id : MemoryPairsScreen.id)!
                let first = try children(BoardDrawing(boards[0], StageContext(entry: entry)).scene())
                for board in boards {
                    let now = try children(BoardDrawing(board, StageContext(entry: entry)).scene())
                    #expect(now.map(\.y) == first.map(\.y) && now.map(\.h) == first.map(\.h))
                }
            }
        }
    }

    /// A refusal is said in the bubble: no note comes in to push the board.
    @Test func aRefusalIsSaidWithoutMovingAnything() throws {
        try Language.with("en", strings: PlaytimeGameTests.strings) {
            var random = Games.Random(seed: 1)
            var state = DailyWordScreen.Engine.start(level: .fair, options: PlaytimeScreensTests.options(), random: &random)
            let options = PlaytimeScreensTests.options()
            let before = DailyWordScreen.board(state, events: [], options: options)
            let refused = GameTable.play(DailyWordScreen.self, .word("zz"), on: &state, random: &random)
            let board = DailyWordScreen.board(state, events: refused, options: options)
            #expect(board.refused && board.promptPart?.text == L("That word isn't the right length."))
            #expect(!board.parts.contains { if case .note = $0 { true } else { false } })
            let entry = GameCatalog.entry(DailyWordScreen.id)!
            let a = try children(BoardDrawing(before, StageContext(entry: entry)).scene()), b = try children(BoardDrawing(board, StageContext(entry: entry, previous: before)).scene())
            #expect(a.map(\.y) == b.map(\.y) && a.map(\.h) == b.map(\.h))
        }
    }

    /// A wrong letter pops a balloon where it hangs, once: it goes, leaves its string, and the others stay put.
    @Test func aBalloonPopsWhereItHangs() {
        let entry = GameCatalog.entry(BalloonWordsScreen.id)!
        let tiles = (0..<3).map { LetterTile("", mark: "hidden", group: $0) }
        func board(_ left: Int) -> Board {
            Board([.play(.lives(total: 7, left: left, symbol: "balloon")), .play(.letters(rows: [tiles], length: 3, style: "slots", script: "latin")),
                   .play(.keys(pages: [KeyPage(rows: [[(key: "a", mark: "none")]])], mode: "letter", script: "latin"))])
        }
        let scene = BoardDrawing(board(6), StageContext(entry: entry, previous: board(7))).scene()
        let runs = (scene.json["animations"] as? [[String: Any]] ?? []).compactMap { $0["target"] as? String }
        #expect(runs.contains("life.6") && runs.contains("life.6.string") && runs.contains("life.6.bit.0"))
        #expect(places(scene, prefixes: ["life.0"])["life.0"] == places(BoardDrawing(board(7), StageContext(entry: entry)).scene(), prefixes: ["life.0"])["life.0"])
        // Drawn again after a key, nothing pops again; the gone one is only its string.
        let again = BoardDrawing(board(6), StageContext(entry: entry, previous: board(6), fresh: false)).scene()
        #expect(places(again, prefixes: ["life.6"]).keys.sorted() == ["life.6.string"])
        #expect(!((again.json["animations"] as? [[String: Any]] ?? []).contains { ($0["target"] as? String)?.hasPrefix("life.") == true }))
    }

    /// The last line of a series and the last pair are seen, with their score, before the end card, which follows them with no second build-up.
    @Test func theLastLineShowsBeforeTheEndCard() throws {
        try Language.with("en", strings: PlaytimeGameTests.strings) {
            for boards in [try PlaytimeScreensTests.play(TicTacToeScreen.self, seed: 1).boards, try PlaytimeScreensTests.play(MemoryPairsScreen.self, seed: 1).boards] {
                let end = boards.count - 1
                #expect(boards[end].resultPart != nil && boards[end].over)
                #expect(boards[end - 1].resultPart == nil && !boards[end - 1].over && boards[end - 1].afterMs != nil)
                #expect(boards[end - 1].gridPart?.cells.contains { $0.state == "win" } == true)
                #expect(!Suspense.decides(boards[end], after: boards[end - 1]))
            }
        }
    }
}
