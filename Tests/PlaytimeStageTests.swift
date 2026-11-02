import Foundation
import Testing
@testable import SidefolkExtensionKit
@testable import ext_playtime

/// Every game's boards as the scenes the person sees (Sidefolk D101): what the app's reader would refuse, and the order of a result, are checked here on the boards the
/// bot really plays.
@Suite(.serialized) @MainActor
struct PlaytimeStageTests {
    static func entry(_ id: String) -> GameEntry { GameCatalog.entry(id)! }

    /// A scene as Sidefolk gets it: within its size and caps, and every key and area id a plain token.
    static func check(_ scene: Scene, _ context: String) throws {
        let data = try JSONSerialization.data(withJSONObject: scene.json)
        #expect(data.count <= 64 * 1024, "\(context): \(data.count) bytes")
        #expect(scene.height <= 676 && scene.width <= 720, "\(context): \(scene.height)")
        let token = #"^[a-z0-9][a-z0-9_-]{0,39}$"#
        for key in scene.keys {
            #expect((key["id"] as? String)?.range(of: token, options: .regularExpression) != nil, "\(context): \(key)")
        }
        func visit(_ node: [String: Any]) {
            if let area = node["area"] as? [String: Any] {
                #expect((area["id"] as? String)?.range(of: token, options: .regularExpression) != nil, "\(context): \(area)")
                #expect((area["value"] as? String).map { $0.count <= 24 } ?? true, "\(context): \(area)")
                #expect(area["label"] as? String != nil, "\(context): an area without words isn't offered")
            }
            for child in node["children"] as? [[String: Any]] ?? [] { visit(child) }
        }
        (scene.json["nodes"] as? [[String: Any]] ?? []).forEach(visit)
        for run in scene.json["animations"] as? [[String: Any]] ?? [] {
            if let id = run["id"] as? String { #expect(id.range(of: token, options: .regularExpression) != nil, "\(context): \(id)") }
        }
    }

    /// Every board of a game the bot plays, and the build-up in front of any that needs one, gives nothing away and draws.
    func playAll<S: GameScreen>(_ screen: S.Type, seeds: [UInt64] = [1, 2, 3], language: String = "en") throws {
        try Language.with(language, strings: PlaytimeGameTests.strings) {
            for seed in seeds {
                PlaytimeRecords.update { $0 = PlaytimeRecords() }
                let boards = try PlaytimeScreensTests.play(S.self, seed: seed, language: language).boards
                var previous: Board?
                for board in boards {
                    if let (build, _) = Suspense.buildUp(from: previous, to: board, picked: nil) {
                        #expect(!Suspense.showsVerdict(build), "\(S.id): a build-up gives the result away")
                        var ctx = StageContext(entry: Self.entry(S.id), previous: previous)
                        ctx.buildUp = true
                        try Self.check(BoardDrawing(build, ctx).scene(), "\(S.id) build-up")
                    }
                    try Self.check(BoardDrawing(board, StageContext(entry: Self.entry(S.id), previous: previous)).scene(), S.id)
                    previous = board
                }
            }
        }
    }

    @Test func everyGamesBoardsAreScenesSidefolkTakes() throws {
        try playAll(TriviaScreen.self)
        try playAll(TicTacToeScreen.self)
        try playAll(CopyMeScreen.self)
        try playAll(QuickPawsScreen.self)
        try playAll(WhichCupScreen.self)
        try playAll(HigherLowerScreen.self)
        try playAll(GuessAnimalScreen.self)
        try playAll(BalloonWordsScreen.self)
        try playAll(LastStickScreen.self)
        try playAll(MemoryPairsScreen.self)
        try playAll(DailyWordScreen.self)
    }

    @Test func aLongLanguageAndOneThatReadsTheOtherWayFit() throws {
        for language in ["de", "ar", "ja"] { try playAll(HigherLowerScreen.self, seeds: [1], language: language) }
    }

    @Test func aMoveOnASceneIsTheBoardsMove() {
        var local = LocalParts()
        let field = Board([.play(.number(min: 1, max: 100, label: nil, history: [], locked: false))])
        func action(_ move: SurfaceMove, _ board: Board) -> StageAction { StageMoves.action(move, board: board, local: &local) }
        guard case .redraw = action(.key(id: "digit", character: "4", ms: nil), field), case .redraw = action(.click(area: "digit", value: "2", ms: nil), field) else {
            Issue.record("digits only change what is typed")
            return
        }
        #expect(local.draft == "42")
        guard case .ignore = action(.key(id: "digit", character: "9", ms: nil), Board([.play(.number(min: 1, max: 42, label: nil, history: [], locked: true))])) else {
            Issue.record("a locked field takes nothing")
            return
        }
        guard case .play(.number(42)) = action(.key(id: "draft_return", character: nil, ms: nil), field) else {
            Issue.record("Return sends the number")
            return
        }
        guard case .play(.answer(2)) = action(.click(area: "answer", value: "2", ms: nil), field), case .play(.cell(row: 1, column: 2)) = action(.click(area: "cell", value: "1,2", ms: nil), field),
              case .play(.button("again")) = action(.click(area: "button", value: "again", ms: nil), field),
              case .play(.choice(name: "top", value: "10")) = action(.click(area: "choice", value: "top|10", ms: nil), field),
              case .back = action(.back, field), case .play(.timeout) = action(.timer("round"), field), case .play(.next) = action(.next, field) else {
            Issue.record("each area is its move")
            return
        }
        // A wide range's digits in another script count as digits.
        local = LocalParts()
        _ = action(.key(id: "digit", character: "٣", ms: nil), field)
        #expect(local.draft == "3")
        // A refused number stays to be fixed; a judged one clears.
        local.guessesSeen = 0
        StageMoves.settle(Board([.play(.number(min: 1, max: 100, label: nil, history: [], locked: false))]), local: &local)
        #expect(local.draft == "3")
        StageMoves.settle(Board([.play(.number(min: 1, max: 100, label: nil, history: [(3, "higher")], locked: false))]), local: &local)
        #expect(local.draft.isEmpty)
    }

    @Test func aPickWaitsPressedAndNothingIsJudgedBeforeTheBeat() throws {
        let before = Board([.prompt("Which?"), .score(you: 0, companion: 0), .answers([Tile("A"), Tile("B")])])
        let after = Board([.prompt("Right!"), .score(you: 1, companion: 0), .answers([Tile("A", state: .right, companion: true), Tile("B", state: .faded)], locked: true),
                           .note("A fact."), .result(figure: "1", tone: .good, actions: [ScreenKit.playAgain])], companion: Cue(move: "bow"), over: true)
        let (build, ms) = try #require(Suspense.buildUp(from: before, to: after, picked: 0))
        #expect(ms == Suspense.beatMs && !Suspense.showsVerdict(build) && build.scorePart?.you == 0 && build.promptPart?.text == "Which?")
        #expect(build.answersPart?.tiles.first?.state == .picked && build.answersPart?.tiles.first?.companion == false)
    }

    @Test func neverRedForALossAndNeverColourAlone() throws {
        let board = Board([.result(figure: "1 – 3", tone: .bad, actions: [ScreenKit.playAgain])], over: true)
        let json = String(decoding: try JSONSerialization.data(withJSONObject: BoardDrawing(board, StageContext(entry: Self.entry(TicTacToeScreen.id))).scene().json), as: UTF8.self)
        for red in ["FF0000", "FF3B30", "D70015"] { #expect(!json.uppercased().contains(red)) }
        #expect(json.contains("hand.thumbsup.fill"), "a loss's mark says so with a symbol")
    }

    @Test func aPackFromTheAIIsCheckedHere() {
        func good(_ i: Int) -> [String: Any] { ["question": "Which volcano is number \(i)?", "choices": ["Etna", "Fuji", "Hekla", "Kilauea"], "answer": i % 4, "difficulty": 2] }
        func text(_ list: [[String: Any]], topic: String = "volcanoes") -> String {
            String(decoding: try! JSONSerialization.data(withJSONObject: ["topic": topic, "questions": list]), as: UTF8.self)
        }
        #expect(TriviaPackCheck.parse("not json", count: 10, topic: "x") == .failure(.notJSON))
        #expect(TriviaPackCheck.parse(text([]), count: 10, topic: "x") == .failure(.declined))
        let bad = (0..<10).map { i -> [String: Any] in var q = good(i); q["question"] = "See https://example.com \(i)?"; return q }
        #expect(TriviaPackCheck.parse(text(bad), count: 10, topic: "x") == .failure(.tooFew(0)), "links make it unusable")
        guard case .success(let pack) = TriviaPackCheck.parse(text((0..<12).map(good)), count: 10, topic: "") else {
            Issue.record("a good pack")
            return
        }
        #expect(pack.topic == "volcanoes" && pack.questions.count == 10, "the AI names a topic left to it")
    }

    @Test func whatTheAppKeptArrivesOnce() throws {
        PlaytimeRecords.update { $0 = PlaytimeRecords() }
        let rows: [[String: Any]] = [["at": "2026-11-01T10:00:00Z", "summary": "x", "args": ["extension": "dev.sidefolk.playtime", "game": "trivia", "result": "win"]],
                                     ["at": "2026-10-31T10:00:00Z", "summary": "y", "args": ["extension": "dev.sidefolk.playtime", "game": "trivia", "result": "loss"]],
                                     ["at": "2026-10-30T10:00:00Z", "summary": "z", "args": ["extension": "dev.other", "game": "chess", "result": "win"]]]
        let reply = PlaytimeCarry.receive(Arguments(["tone": "gentle", "sneaky": true, "sounds": false, "speakers": ["dev.sidefolk.playtime/sudoku": true],
                                                     "levels": ["dev.sidefolk.playtime/tictactoe": "hard"], "players": ["Ana", "Sam"], "aiTrivia": false]),
                                          store: [:], history: ["games.play": rows])
        let settings = try #require(reply["settings"] as? [String: Any])
        #expect(settings["tone"] as? String == "gentle" && settings["sneaky"] as? Bool == true && settings["sound_sudoku"] as? Bool == true && settings["sound_trivia"] as? Bool == false)
        #expect(settings["level_tictactoe"] as? String == "hard" && reply["ai"] as? Bool == false)
        let r = PlaytimeRecords.load()
        #expect(r.players == ["Ana", "Sam"] && r.stats.played == 2 && r.stats.wins == 1 && r.stats.streak == 1, "only its own games, the newest first")
    }

    @Test func thePageIsTheCenter() throws {
        PlaytimeRecords.update { $0 = PlaytimeRecords() }
        let page = PlaytimePage.render()
        let json = String(decoding: try JSONSerialization.data(withJSONObject: page.json, options: .withoutEscapingSlashes), as: UTF8.self)
        for kind in ["\"hero\"", "\"stats\"", "\"cards\"", "\"badges\"", "\"settings\""] { #expect(json.contains(kind), "\(kind)") }
        #expect(json.contains("art/game-icon-numbers.webp") && json.contains("level_tictactoe"), "its own art, its own settings")
    }

    @Test func theManifestAndTheCatalogAgree() throws {
        let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("extensions/playtime")
        let m = try JSONSerialization.jsonObject(with: Data(contentsOf: folder.appendingPathComponent("sidefolk-extension.json"))) as! [String: Any]
        #expect(m["games"] == nil, "no game channel any more")
        let commands = ((m["tools"] as! [String: [String: Any]])["open"]!["commands"] as! [[String: Any]]).compactMap { $0["name"] as? String }
        let settings = (m["settings"] as! [[String: Any]]).compactMap { $0["key"] as? String }
        for game in GameCatalog.all {
            #expect(GameTable.drivers[game.id] != nil && commands.contains(game.id), "\(game.id)")
            #expect(settings.contains(GameSoundSetting.key(game.id)), "\(game.id)")
            if game.levels { #expect(settings.contains(GameSoundSetting.levelKey(game.id)), "\(game.id)") }
            #expect(FileManager.default.fileExists(atPath: folder.appendingPathComponent("assets/\(game.look.icon)").path), "\(game.id)")
            #expect(FileManager.default.fileExists(atPath: folder.appendingPathComponent("assets/\(game.look.scene)").path), "\(game.id)")
        }
    }
}
