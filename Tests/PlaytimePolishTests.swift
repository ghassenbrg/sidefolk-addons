import Foundation
import Testing
@testable import SidefolkExtensionKit
@testable import ext_playtime

/// What the playtest asked for, held: an end card fits and is true, a wrong press in Copy Me reads at once, the footer is one line a game, the companion has one place in a game's scene and moves only on a change.
@Suite(.serialized) @MainActor
struct PlaytimePolishTests {
    private static func entry(_ id: String) -> GameEntry { GameCatalog.entry(id)! }

    /// Every node with its place in the canvas.
    private static func nodes(_ scene: Scene) -> [(node: [String: Any], x: Double, y: Double)] {
        var out: [(node: [String: Any], x: Double, y: Double)] = []
        func visit(_ node: [String: Any], _ x: Double, _ y: Double) {
            let nx = x + (node["x"] as? Double ?? 0), ny = y + (node["y"] as? Double ?? 0)
            out.append((node, nx, ny))
            for child in node["children"] as? [[String: Any]] ?? [] { visit(child, nx, ny) }
        }
        (scene.json["nodes"] as? [[String: Any]] ?? []).forEach { visit($0, 0, 0) }
        return out
    }

    private static func node(_ scene: Scene, _ id: String) -> (node: [String: Any], x: Double, y: Double)? {
        nodes(scene).first { $0.node["id"] as? String == id }
    }

    private static func anims(_ scene: Scene, on target: String) -> [[String: Any]] {
        var out: [[String: Any]] = []
        func walk(_ anim: [String: Any]) {
            for key in ["sequence", "together"] { (anim[key] as? [[String: Any]])?.forEach(walk) }
            if anim["target"] as? String == target { out.append(anim) }
        }
        (scene.json["animations"] as? [[String: Any]] ?? []).forEach(walk)
        return out
    }

    private func endCard<S: GameScreen>(_ screen: S.Type, language: String, seed: UInt64 = 1) throws {
        PlaytimeRecords.update { $0 = PlaytimeRecords() }
        let boards = try PlaytimeScreensTests.play(S.self, seed: seed, language: language).boards
        let scene = BoardDrawing(boards.last!, StageContext(entry: Self.entry(S.id), previous: boards.dropLast().last)).scene()
        let all = Self.nodes(scene)
        #expect(Self.node(scene, "board.end") != nil, "\(S.id): the card has its room, and nothing scrolls")
        #expect(Self.node(scene, "board")?.node["type"] as? String != "scroll", "\(S.id)")
        // Nothing cut: every part of the card ends above the line of keys.
        if let inCard = Self.node(scene, "end") {
            let bottom = inCard.y + (inCard.node["h"] as? Double ?? 0)
            #expect(bottom <= BoardDrawing.canvas - BoardDrawing.footerRoom + 0.5, "\(S.id) \(language): the card ends at \(bottom)")
        }
        let words = all.compactMap { $0.node["text"] as? String }
        #expect(Set(words.filter { $0.count > 6 && !$0.contains("·") }).count == words.filter { $0.count > 6 && !$0.contains("·") }.count, "\(S.id) \(language): a line said twice in \(words)")
        // A card comes in under a hand that may still be clicking.
        #expect(scene.json["input_after_ms"] as? Int == BoardDrawing.cardHoldMs, "\(S.id)")
    }

    @Test func everyEndCardFitsInEnglishAndGerman() throws {
        for language in ["en", "de"] {
            try Language.with(language, strings: PlaytimeGameTests.strings) {
                try endCard(TriviaScreen.self, language: language)
                try endCard(TicTacToeScreen.self, language: language)
                try endCard(CopyMeScreen.self, language: language)
                try endCard(QuickPawsScreen.self, language: language)
                try endCard(WhichCupScreen.self, language: language)
                try endCard(HigherLowerScreen.self, language: language)
                try endCard(GuessAnimalScreen.self, language: language)
                try endCard(BalloonWordsScreen.self, language: language)
                try endCard(LastStickScreen.self, language: language)
                try endCard(MemoryPairsScreen.self, language: language)
                try endCard(RockPaperScissorsScreen.self, language: language)
                PlaytimeRecords.update { $0.dailyGame = nil; $0.daily = Games.DailyWord.Record() }
                try endCard(DailyWordScreen.self, language: language)
                try endCard(PuzzleScreen<GardenPlotsKind>.self, language: language)
            }
        }
    }

    /// What is shown, without the marks that keep a filled-in value's direction.
    private func texts(_ scene: Scene) -> [String] {
        Self.nodes(scene).compactMap { ($0.node["text"] as? String)?.replacingOccurrences(of: "\u{2068}", with: "").replacingOccurrences(of: "\u{2069}", with: "") }
    }

    @Test func aCardNeverSaysALossThatWasnt() throws {
        try Language.with("en", strings: PlaytimeGameTests.strings) {
            let o = PlaytimeScreensTests.options("en")
            // The companion guesses, and the person says it found the number.
            PlaytimeRecords.update { $0 = PlaytimeRecords() }
            var random = Games.Random(seed: 3)
            var hl = HigherLowerScreen.Engine.start(level: .fair, options: o, random: &random)
            _ = GameTable.play(HigherLowerScreen.self, .choice(name: "mode", value: "yours"), on: &hl, random: &random)
            _ = GameTable.play(HigherLowerScreen.self, .button("start"), on: &hl, random: &random)
            _ = GameTable.play(HigherLowerScreen.self, .next, on: &hl, random: &random)
            _ = GameTable.play(HigherLowerScreen.self, .answer(2), on: &hl, random: &random)
            let found = HigherLowerScreen.board(hl, events: [], options: o)
            #expect(found.over && found.endFriendly)
            let words = texts(BoardDrawing(found, StageContext(entry: Self.entry(HigherLowerScreen.id))).scene())
            #expect(!words.contains("Not this time") && !words.contains { $0.contains("wins") } && !words.contains { $0.contains("draw") }, "\(words)")
            // Copy Me, one wrong press.
            var copy = CopyMeScreen.Engine.start(level: .fair, options: o, random: &random)
            let right = copy.game.pads.firstIndex(of: copy.game.sequence[0])!
            let events = GameTable.play(CopyMeScreen.self, .pad((right + 1) % copy.game.pads.count), on: &copy, random: &random)
            let end = CopyMeScreen.board(copy, events: events, options: o)
            let said = texts(BoardDrawing(end, StageContext(entry: Self.entry(CopyMeScreen.id))).scene())
            #expect(!said.contains { $0.contains("draw") } && said.contains("You copied 0 moves."), "\(said)")
            // What is shown changed; what it records didn't.
            #expect(CopyMeScreen.Engine.outcome(of: copy) == .draw)
        }
    }

    @Test func aWrongPressShowsThePadThatWasRight() throws {
        try Language.with("en", strings: PlaytimeGameTests.strings) {
            let o = PlaytimeScreensTests.options("en")
            var random = Games.Random(seed: 5)
            var s = CopyMeScreen.Engine.start(level: .fair, options: o, random: &random)
            let before = CopyMeScreen.board(s, events: [], options: o)
            let right = s.game.pads.firstIndex(of: s.game.sequence[0])!, wrong = (right + 1) % s.game.pads.count
            let events = GameTable.play(CopyMeScreen.self, .pad(wrong), on: &s, random: &random)
            let next = CopyMeScreen.board(s, events: events, options: o)
            let (build, ms) = try #require(Suspense.buildUp(from: before, to: next, picked: nil))
            #expect(ms == BoardDrawing.padMissMs && !Suspense.showsVerdict(build))
            var ctx = StageContext(entry: Self.entry(CopyMeScreen.id), previous: before)
            ctx.buildUp = true
            ctx.local.lit = wrong
            let scene = BoardDrawing(build, ctx).scene()
            let padName = CopyMeScreen.name(s.game.pads[right])
            #expect(texts(scene).contains("Oops! It was \(padName)."), "\(texts(scene))")
            #expect(!texts(scene).contains { $0.hasPrefix("Watch") })
            #expect(!Self.anims(scene, on: "pad.\(wrong).face").isEmpty, "the pad pressed shakes")
            #expect(!Self.anims(scene, on: "pad.\(right).face").isEmpty, "the pad that was right lights")
            try PlaytimeStageTests.check(scene, "the wrong press")
        }
    }

    /// One line a game, whoever's turn it is.
    private func footerHolds<S: GameScreen>(_ screen: S.Type) throws {
        PlaytimeRecords.update { $0 = PlaytimeRecords() }
        let boards = try PlaytimeScreensTests.play(S.self, seed: 2).boards
        var seen: String?
        var previous: Board?
        for board in boards where !board.over {
            defer { previous = board }
            // A moment with a main button says that instead; a name or a setup isn't play.
            guard board.primary == nil, board.scorePart?.players == nil else { continue }
            let footer = BoardDrawing(board, StageContext(entry: Self.entry(S.id), previous: previous)).footer
            if let seen, !footer.contains(" to take") { #expect(seen == footer, "\(S.id): \(seen) to \(footer)") }
            seen = footer
        }
    }

    @Test func theFooterIsOneLineAGame() throws {
        try Language.with("en", strings: PlaytimeGameTests.strings) {
            try footerHolds(TicTacToeScreen.self)
            try footerHolds(CopyMeScreen.self)
            try footerHolds(QuickPawsScreen.self)
            try footerHolds(LastStickScreen.self)
        }
    }

    /// Where the figure stands, over a game: once its toy or board is out, one place.
    private func figureStays<S: GameScreen>(_ screen: S.Type) throws {
        PlaytimeRecords.update { $0 = PlaytimeRecords() }
        let boards = try PlaytimeScreensTests.play(S.self, seed: 1).boards
        var seen: [Double]?
        var previous: Board?
        for board in boards where !board.over {
            defer { previous = board }
            let drawing = BoardDrawing(board, StageContext(entry: Self.entry(S.id), previous: previous))
            guard drawing.figurePlace != nil else { continue }
            let scene = drawing.scene()
            guard let at = Self.node(scene, "companion"), let bubble = Self.node(scene, "bubble") else { Issue.record("\(S.id): no figure"); continue }
            let place = [at.x, at.y, at.node["w"] as? Double ?? 0, at.node["h"] as? Double ?? 0, bubble.x, bubble.y]
            if let seen { #expect(seen == place, "\(S.id): \(seen) to \(place)") }
            seen = place
            // Inside the canvas, feet and bubble alike.
            #expect(at.x >= 0 && at.x + place[2] <= BoardDrawing.width && bubble.x + (bubble.node["w"] as? Double ?? 0) <= BoardDrawing.width, "\(S.id)")
        }
        #expect(seen != nil, "\(S.id) has a place")
    }

    @Test func theCompanionHasOnePlaceInAGame() throws {
        try Language.with("en", strings: PlaytimeGameTests.strings) {
            try figureStays(TicTacToeScreen.self)
            try figureStays(CopyMeScreen.self)
            try figureStays(QuickPawsScreen.self)
            try figureStays(WhichCupScreen.self)
            try figureStays(LastStickScreen.self)
            try figureStays(MemoryPairsScreen.self)
            try figureStays(GuessAnimalScreen.self)
            PlaytimeRecords.update { $0.dailyGame = nil; $0.daily = Games.DailyWord.Record() }
            try figureStays(DailyWordScreen.self)
            try figureStays(PuzzleScreen<GardenPlotsKind>.self)
        }
    }

    /// The machine has the word at Quick Paws' signal: the bubble goes without moving anything, stays away through the wait for the verdict and comes back with it.
    @Test func quickPawsBubbleNeverArguesWithTheSignal() throws {
        try Language.with("en", strings: PlaytimeGameTests.strings) {
            PlaytimeRecords.update { $0 = PlaytimeRecords() }
            let boards = try PlaytimeScreensTests.play(QuickPawsScreen.self, seed: 1).boards
            let armed = try #require(boards.first { $0.reflexArmed })
            let scene = BoardDrawing(armed, StageContext(entry: Self.entry(QuickPawsScreen.id))).scene()
            #expect(Self.anims(scene, on: "bubble").contains { ($0["to"] as? [String: Any])?["opacity"] as? Double == 0 })
            var waiting = StageContext(entry: Self.entry(QuickPawsScreen.id), previous: armed)
            waiting.buildUp = true
            let build = BoardDrawing(armed, waiting).scene()
            #expect(Self.node(build, "bubble")?.node["opacity"] as? Double == 0)
            let rest = BoardDrawing(armed, StageContext(entry: Self.entry(QuickPawsScreen.id))).scene()
            #expect(Self.node(rest, "bubble")?.node["opacity"] as? Double ?? 1 == 1)
        }
    }

    @Test func theFigureMovesOnlyOnAChangeAndEndsWhereItRests() throws {
        try Language.with("en", strings: PlaytimeGameTests.strings) {
            PlaytimeRecords.update { $0 = PlaytimeRecords() }
            let boards = try PlaytimeScreensTests.play(TicTacToeScreen.self, seed: 1).boards
            var previous: Board?
            var moved = 0
            for board in boards where !board.over {
                defer { previous = board }
                // Drawn again for a key: it rests as it did, and plays nothing.
                let again = BoardDrawing(board, StageContext(entry: Self.entry(TicTacToeScreen.id), previous: board, fresh: false)).scene()
                #expect(Self.anims(again, on: "companion.figure").isEmpty)
                let scene = BoardDrawing(board, StageContext(entry: Self.entry(TicTacToeScreen.id), previous: previous)).scene()
                let tracks = Self.anims(scene, on: "companion.figure")
                #expect(tracks.count <= 1, "one track per value")
                let rest = Self.node(scene, "companion.figure")?.node["rotate"] as? Double ?? 0
                #expect(rest == Self.node(again, "companion.figure")?.node["rotate"] as? Double ?? 0, "a redraw keeps its rest")
                if let frames = tracks.first?["keys"] as? [[String: Double]], let last = frames.last {
                    moved += 1
                    #expect(frames.count <= 32)
                    #expect(abs((last["rotate"] ?? 0) - rest) < 0.01, "it ends where it rests")
                }
            }
            #expect(moved > 0)
        }
    }

    @Test func itListensOnceTheCupsHaveStopped() throws {
        try Language.with("en", strings: PlaytimeGameTests.strings) {
            let o = PlaytimeScreensTests.options("en")
            var random = Games.Random(seed: 1)
            let s = WhichCupScreen.Engine.start(level: .fair, options: o, random: &random)
            let board = WhichCupScreen.board(s, events: [.opened], options: o)
            var local = LocalParts()
            local.playback = Playback(what: board.plays?.what ?? "", ms: 1000, startedAt: Date().timeIntervalSince1970)
            #expect(BoardDrawing(board, StageContext(entry: Self.entry(WhichCupScreen.id), local: local)).pose == "thinking")
            local.playback?.done = true
            #expect(BoardDrawing(board, StageContext(entry: Self.entry(WhichCupScreen.id), local: local)).pose == "listening")
        }
    }
}
