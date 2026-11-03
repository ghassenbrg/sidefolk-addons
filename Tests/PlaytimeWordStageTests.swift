import Foundation
import Testing
@testable import SidefolkExtensionKit
@testable import ext_playtime

/// The word games as the scenes the person sees (Sidefolk D101): letter tiles, the keyboard, a field and the lives, in every script, played by their moves.
@Suite(.serialized) @MainActor
struct PlaytimeWordStageTests {
    init() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("playtime-words-\(UUID().uuidString)").path
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        setenv("SIDEFOLK_DATA_DIR", dir, 1)
    }

    private func entry(_ id: String) -> GameEntry { GameCatalog.entry(id)! }

    private func nodes(_ scene: Scene) -> [[String: Any]] {
        var out: [[String: Any]] = []
        func visit(_ node: [String: Any]) {
            out.append(node)
            (node["children"] as? [[String: Any]] ?? []).forEach(visit)
        }
        (scene.json["nodes"] as? [[String: Any]] ?? []).forEach(visit)
        return out
    }

    private func node(_ scene: Scene, _ id: String) -> [String: Any]? { nodes(scene).first { $0["id"] as? String == id } }

    private func tile(_ text: String, _ mark: String, _ group: Int) -> LetterTile { LetterTile(text, mark: mark, group: group) }

    private func keys(_ rows: Int, mode: String = "spell", length: Int? = 5, script: String = "latin", locked: Bool = false) -> BoardPart {
        .play(.keys(pages: [KeyPage(rows: (0..<rows).map { r in (0..<(7 + r)).map { (key: "\(UnicodeScalar(UInt8(97 + 5 * r + $0)))", mark: "none") } })],
                    mode: mode, length: length, script: script, locked: locked))
    }

    @Test func aHalfTypedKoreanWordIsTheBlocksItWillBe() {
        #expect(Hangul.split("ㅅㅏㄱㅗㅏ", script: "hangul").map(\.group) == [0, 0, 1, 1, 1])
        // A consonant closes the syllable unless a vowel follows; a final pair stays in it.
        #expect(Hangul.split("ㅎㅏㄴㄱㅡㄹ", script: "hangul").map(\.group) == [0, 0, 0, 1, 1, 1])
        #expect(Hangul.split("ㄷㅏㄹㄱ", script: "hangul").map(\.group) == [0, 0, 0, 0])
        #expect(Hangul.split("abc", script: "latin").map(\.group) == [0, 1, 2])
    }

    @Test func tilesAreAsLargeAsTheRowAndTheKeyboardAllow() {
        func side(_ board: Board) -> Double {
            let scene = BoardDrawing(board, StageContext(entry: entry("daily_word"))).scene()
            return node(scene, "letters.0.0")?["w"] as? Double ?? 0
        }
        let row = BoardPart.letters(5)
        // Whatever the keyboard leaves: larger beside a short one, and always in the tray.
        #expect(side(Board([row, keys(3)])) > side(Board([row, keys(5)])))
        #expect(side(Board([row, keys(3)])) * 5 + 4 * 5 <= 372 - 28)
        #expect(side(Board([.play(.letters(rows: [(0..<5).map { tile("", "hidden", $0) }], length: 5, style: "slots", script: "latin"))])) == 30)
        // A long word shrinks to fit the tray.
        #expect(abs(side(Board([BoardPart.letters(12)])) - (372 - 28 - 11 * 5) / 12) < 0.01)
    }

    @Test func aRowTurnsOverTileByTileAndOnlyInItsBuildUp() throws {
        let played = [tile("c", "absent", 0), tile("r", "elsewhere", 1), tile("a", "right", 2)]
        let before = Board([.play(.letters(rows: [], length: 3, tries: 6, draft: true, script: "latin")), keys(3, length: 3)])
        let after = Board([.prompt("Close!", eyebrow: nil), .play(.letters(rows: [played], length: 3, tries: 6, draft: true, flip: 0, script: "latin")), keys(3, length: 3)], companion: Cue(move: "gasp"))
        let (build, ms) = try #require(Suspense.buildUp(from: before, to: after, picked: nil))
        #expect(ms == 350 + 3 * 220)
        #expect(!Suspense.showsVerdict(build))
        var ctx = StageContext(entry: entry("daily_word"), previous: before)
        ctx.buildUp = true
        let drawing = BoardDrawing(build, ctx)
        let scene = drawing.scene()
        func opening(_ scene: Scene) -> [[String: Any]] {
            (scene.json["animations"] as? [[String: Any]] ?? []).filter { ($0["target"] as? String)?.hasPrefix("letters") == true && ($0["keys"] as? [[String: Any]])?.first?["sy"] != nil }
        }
        let paths = opening(scene)
        #expect(paths.map { $0["target"] as? String } == ["letters.0.0", "letters.0.1", "letters.0.2"])
        for (i, path) in paths.enumerated() {
            let frames = path["keys"] as? [[String: Any]] ?? []
            #expect(frames.first?["sy"] as? Double == 1 && frames.contains { $0["sy"] as? Double == 0.02 }, "it turns from the tile it was: narrowing to nothing, then opening")
            #expect(frames.last?["sy"] as? Double == 1)
            // The typed tile lies over the marked one until the middle of its turn, so no colour shows before its moment.
            let shut = (scene.json["animations"] as? [[String: Any]] ?? []).first { $0["target"] as? String == "letters.0.\(i).shut" }
            #expect((shut?["keys"] as? [[String: Any]])?.first?["opacity"] as? Double == 1)
            #expect((path["ms"] as? Double) == Double(i) * 220 + 250)
        }
        #expect(!(build.keysPart?.locked == false), "nothing to press while it turns")
        // The verdict shows the same row at rest: it doesn't play twice.
        let verdict = BoardDrawing(after, StageContext(entry: entry("daily_word"), previous: before)).scene()
        #expect(opening(verdict).isEmpty)
    }

    @Test func aMarkIsNeverColourAloneAndNeverRed() {
        let row = [tile("a", "right", 0), tile("b", "elsewhere", 1), tile("c", "absent", 2)]
        let scene = BoardDrawing(Board([.play(.letters(rows: [row], length: 3, tries: 1, script: "latin"))]), StageContext(entry: entry("daily_word"))).scene()
        let all = nodes(scene)
        // A dot, half a dot, a cross: each a shape of its own on its tile, with the colour.
        func shapes(_ id: String) -> [String] { (node(scene, id)?["children"] as? [[String: Any]] ?? []).compactMap { ($0["shape"] as? String) }.filter { $0 != "rect" } }
        #expect(shapes("letters.0.0") == ["ellipse"] && shapes("letters.0.1") == ["path"] && shapes("letters.0.2") == ["path"])
        #expect(!all.isEmpty)
        #expect(node(scene, "letters.0.0")?["label"] as? String == "a, right place")
        #expect(node(scene, "letters.0.2")?["label"] as? String == "c, not in the word")
    }

    @Test func aKeyboardsRowsRunItsWidth() {
        let scene = BoardDrawing(Board([keys(3)]), StageContext(entry: entry("daily_word"))).scene()
        // One width of key on a page: a row of its own stands in the middle; the last row runs the width, with Enter and delete at its ends.
        let first = node(scene, "key.a"), last = node(scene, "key.g")
        let right = (last?["x"] as? Double ?? 0) + (last?["w"] as? Double ?? 0)
        #expect(abs((first?["x"] as? Double ?? 0) - (BoardDrawing.inner - right)) < 0.01)
        let enter = node(scene, "key.return"), del = node(scene, "key.delete")
        #expect(enter?["x"] as? Double == 0 && abs((del?["x"] as? Double ?? 0) + (del?["w"] as? Double ?? 0) - BoardDrawing.inner) < 0.01)
    }

    @Test func typingAWordIsKeptHereUntilReturn() {
        var local = LocalParts()
        let board = Board([keys(3, length: 3)])
        func act(_ move: SurfaceMove) -> StageAction { StageMoves.action(move, board: board, local: &local) }
        guard case .redraw = act(.key(id: "letter", character: "c", ms: nil)), case .redraw = act(.click(area: "key", value: "a", ms: nil)),
              case .ignore = act(.key(id: "draft_return", character: nil, ms: nil)) else {
            Issue.record("letters only change what is typed, and a part of a word isn't one")
            return
        }
        guard case .redraw = act(.key(id: "letter", character: "t", ms: nil)), case .ignore = act(.key(id: "letter", character: "x", ms: nil)) else {
            Issue.record("the row takes as many as it has places")
            return
        }
        #expect(local.draft == "cat")
        guard case .redraw = act(.key(id: "draft_delete", character: nil, ms: nil)), case .redraw = act(.key(id: "letter", character: "T", ms: nil)) else {
            Issue.record("⌫ takes one back")
            return
        }
        guard case .play(.word("cat")) = act(.click(area: "draft", value: "return", ms: nil)) else {
            Issue.record("Return sends it, in lower case")
            return
        }
        // A refused word stays to be fixed, an accepted one clears; the page stays while there is a keyboard.
        local.page = 1
        let accepted = Board([.play(.letters(rows: [[tile("c", "right", 0)]], length: 3, script: "latin")), keys(3, length: 3)])
        StageMoves.settle(Board([.play(.letters(rows: [], length: 3, script: "latin")), keys(3, length: 3)]), local: &local)
        #expect(!local.draft.isEmpty && local.page == 1)
        StageMoves.settle(accepted, local: &local)
        #expect(local.draft.isEmpty && local.page == 1)
        StageMoves.settle(Board([.prompt("Next", eyebrow: nil)]), local: &local)
        #expect(local.page == 0)
    }

    @Test func aLetterIsAMoveAtOnceAndAUsedKeyTakesNoPress() {
        var local = LocalParts()
        let part = BoardPart.play(.keys(pages: [KeyPage(rows: [[(key: "a", mark: "hit"), (key: "b", mark: "miss"), (key: "c", mark: "none")]])], mode: "letter", script: "latin"))
        guard case .play(.letter("c")) = StageMoves.action(.click(area: "key", value: "c", ms: nil), board: Board([part]), local: &local) else {
            Issue.record("a letter goes to the game")
            return
        }
        let scene = BoardDrawing(Board([part]), StageContext(entry: entry("balloon_words"))).scene()
        #expect((node(scene, "key.a")?["area"] as? [String: Any])?["disabled"] as? Bool == true)
        #expect((node(scene, "key.c")?["area"] as? [String: Any])?["disabled"] as? Bool == false)
        // Used or missed, faded and struck through: never red.
        let struck = nodes(scene).first { $0["text"] as? String == "B" }
        #expect(struck?["strike"] as? Bool == true)
    }

    @Test func aKeyboardWithPagesSwitchesHere() {
        var local = LocalParts()
        let part = BoardPart.play(.keys(pages: [KeyPage("あ", rows: [[(key: "あ", mark: "none")]]), KeyPage("が", rows: [[(key: "が", mark: "none")]])], mode: "spell", length: 4, script: "kana"))
        guard case .redraw = StageMoves.action(.click(area: "keys_page", value: "1", ms: nil), board: Board([part]), local: &local) else {
            Issue.record("a page is the program's")
            return
        }
        var ctx = StageContext(entry: entry("daily_word"))
        ctx.local = local
        let scene = BoardDrawing(Board([part]), ctx).scene()
        #expect(node(scene, "key.が") != nil && node(scene, "key.あ") == nil)
    }

    @Test func aFieldSendsWhatItsNameSays() {
        var local = LocalParts()
        let word = BoardPart.play(.entry(name: "word", kind: "word", button: "Try", max: 4))
        let text = BoardPart.play(.entry(name: "animal", button: "Tell", max: 40))
        guard case .play(.word("一心一意")) = StageMoves.action(.entry(id: "word", text: " 一心一意 "), board: Board([word]), local: &local),
              case .play(.text(name: "animal", value: "Zebra")) = StageMoves.action(.entry(id: "animal", text: "Zebra"), board: Board([text]), local: &local),
              case .ignore = StageMoves.action(.entry(id: "animal", text: "  "), board: Board([text]), local: &local) else {
            Issue.record("a word in lower case, a text as typed, nothing empty")
            return
        }
        let scene = BoardDrawing(Board([text, .button(GameButton("Remember", move: "remember", style: .primary))]), StageContext(entry: entry("guess_animal"))).scene()
        let send = node(scene, "entry.send")?["area"] as? [String: Any]
        #expect(send?["submits"] as? String == "animal", "the whole button, so Sidefolk dims it while the field is empty")
        #expect(node(scene, "entry.animal")?["type"] as? String == "entry")
    }

    @Test func balloonsLostAreFaintAndSaySoAndHeartsToo() {
        let scene = BoardDrawing(Board([.play(.lives(total: 7, left: 5, symbol: "balloon"))]), StageContext(entry: entry("balloon_words"))).scene()
        let kept = node(scene, "life.0")
        #expect(kept?["opacity"] as? Double == 1 && kept?["image"] as? String == "art/game-balloon-0.webp")
        #expect(node(scene, "life.6.string") != nil && node(scene, "life.6") == nil, "gone, but for the string it hung by")
        // Each its own colour, in the picture's proportions.
        #expect(node(scene, "life.3")?["image"] as? String == "art/game-balloon-3.webp")
        #expect(abs((kept?["w"] as? Double ?? 0) - (kept?["h"] as? Double ?? 0) * 200 / 305) < 0.01)
        #expect(node(scene, "lives")?["label"] as? String != nil)
    }

    @Test func everyScriptsBoardsAreScenesSidefolkTakes() throws {
        for language in ["fr", "es", "de", "it", "pt-BR", "ja", "ko", "zh-Hans", "ar"] {
            try Language.with(language, strings: PlaytimeGameTests.strings) {
                let code = String(language.prefix(2))
                for screen in [0, 1, 2] {
                    PlaytimeRecords.update { $0 = PlaytimeRecords() }
                    switch screen {
                    case 0: try walk(DailyWordScreen.self, language: code)
                    case 1: try walk(BalloonWordsScreen.self, language: code)
                    default: try walk(GuessAnimalScreen.self, language: code)
                    }
                }
            }
        }
    }

    private func walk<S: GameScreen>(_ screen: S.Type, language: String) throws {
        let boards = try PlaytimeScreensTests.play(S.self, seed: 7, language: language).boards
        var previous: Board?
        for board in boards {
            if let (build, _) = Suspense.buildUp(from: previous, to: board, picked: nil) {
                #expect(!Suspense.showsVerdict(build), "\(S.id) \(language)")
                var ctx = StageContext(entry: entry(S.id), previous: previous)
                ctx.buildUp = true
                try PlaytimeStageTests.check(BoardDrawing(build, ctx).scene(), "\(S.id) \(language) build-up")
            }
            let scene = BoardDrawing(board, StageContext(entry: entry(S.id), previous: previous)).scene()
            try PlaytimeStageTests.check(scene, "\(S.id) \(language)")
            // A margin under the 64 KB, for what the channel adds.
            let bytes = try JSONSerialization.data(withJSONObject: scene.json).count
            #expect(bytes < 58_000, "\(S.id) \(language): \(bytes) bytes")
            previous = board
        }
    }

    @Test func twoPeopleSettingWordsDrawAndNeverShowTheWordToTheOther() throws {
        try Language.with("en", strings: PlaytimeGameTests.strings) {
            let boards = try PlaytimeTwoPlayersTests.duel(BalloonWordsScreen.self, seed: 3)
            for board in boards { try PlaytimeStageTests.check(BoardDrawing(board, StageContext(entry: entry("balloon_words"))).scene(), "balloon_words duel") }
            // The cover has no letters on it, and its scene none either.
            let covers = boards.filter { !$0.hasLetters && !$0.hasEntry && $0.buttons.contains { $0.move == "ready" } }
            #expect(!covers.isEmpty)
            for cover in covers {
                let words = nodes(BoardDrawing(cover, StageContext(entry: entry("balloon_words"))).scene()).filter { $0["id"] as? String == "letters" }
                #expect(words.isEmpty)
            }
        }
    }

    @Test func teachingAnAnimalGoesStepByStepAsScenes() throws {
        try Language.with("en", strings: PlaytimeGameTests.strings) {
            let driver = GameTable.driver(GuessAnimalScreen.self)
            let options = PlaytimeScreensTests.options("en")
            var (state, board) = driver.start(options, .fair)
            for _ in 0..<40 where board.answersPart?.tiles.first?.label != L("Yes, that's it!") {
                let next = try #require(driver.move(.answer(1), state, options))
                (state, board) = (next.state, next.board)
            }
            for (move, name) in [(Move.answer(1), "animal"), (Move.text(name: "animal", value: "zebra"), "question"), (Move.text(name: "question", value: "Does it have stripes?"), nil)] as [(Move, String?)] {
                let next = try #require(driver.move(move, state, options))
                (state, board) = (next.state, next.board)
                let scene = BoardDrawing(board, StageContext(entry: entry("guess_animal"))).scene()
                try PlaytimeStageTests.check(scene, "guess_animal teaching")
                if let name { #expect(node(scene, "entry.\(name)") != nil) } else { #expect(board.choicePart("new_answer")?.options.count == 2) }
            }
            // One page: the answer picked is only picked, until Remember keeps it.
            let picked = try #require(driver.move(.choice(name: "new_answer", value: "yes"), state, options))
            #expect(!picked.board.over && picked.board.buttons.first { $0.move == "remember" }?.disabled == false)
            let end = try #require(driver.move(.button("remember"), picked.state, options))
            #expect(end.board.over && end.board.resultPart?.line == L("Thank you! I'll remember {animal}.", ["animal": "zebra"]))
            #expect(Self.caps(end.board).isEmpty)
        }
    }

    private static func caps(_ board: Board) -> [String] { board.answersPart.map { BoardDrawing.keyCaps($0.tiles) } ?? [] }

    @Test func aTilesOwnKeyShowsAsACapital() {
        #expect(BoardDrawing.keyCaps([Tile("Yes", key: "y"), Tile("No", key: "n"), Tile("Not sure", key: "?")]) == ["Y", "N", "?"])
    }
}

private extension BoardPart {
    static func letters(_ n: Int) -> BoardPart { .play(.letters(rows: [], length: n, tries: 6, draft: true, script: "latin")) }
}
