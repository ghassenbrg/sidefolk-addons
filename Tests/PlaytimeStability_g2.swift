import Foundation
import Testing
@testable import SidefolkExtensionKit
@testable import ext_playtime

/// The founder's complaint that started the remaster: a question going from one line to two moved the border under it while they were clicking. Over a real play-through of
/// Trivia, Higher or Lower, Guess My Animal and Rock, Paper, Scissors, every part keeps its y and height from the first move to the last before the end card: the board, the
/// stage, the bubble, and everything named inside them that is on more than one board. Words shrink; nothing pushes.
@Suite(.serialized) @MainActor
struct PlaytimeStabilityG2 {
    init() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("playtime-stability-\(UUID().uuidString)").path
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        setenv("SIDEFOLK_DATA_DIR", dir, 1)
    }

    /// Every node with an id, by id: where it stands in the canvas and how tall it is. Animations aside: what it rests at. Things that come and go by themselves aren't checked
    /// here unless they stayed: a mark may appear, but not at another place.
    private func places(_ scene: Scene) -> [String: (y: Double, h: Double)] {
        var out: [String: (y: Double, h: Double)] = [:]
        func visit(_ node: [String: Any], _ top: Double) {
            let y = top + (node["y"] as? Double ?? 0)
            if let id = node["id"] as? String, let h = node["h"] as? Double { out[id] = (y, h) }
            for child in node["children"] as? [[String: Any]] ?? [] { visit(child, y) }
            for key in ["front", "back"] { if let face = node[key] as? [String: Any] { visit(face, y) } }
        }
        scene.nodes.forEach { visit($0.json, 0) }
        return out
    }

    /// What may differ between boards without being a shift: a digit's card (as many as the number has digits), a guess in the row, the marker on the bar, the thrown toys and their boxes stepping
    /// forward, which are the game moving.
    private func isFree(_ id: String) -> Bool {
        id.hasPrefix("counter.") || id.hasPrefix("guess.") || id.hasPrefix("meter.mark") || id.hasPrefix("reveal") || id.hasPrefix("box") || id.hasPrefix("result.") || id.hasPrefix("toy.")
    }

    /// The dock's place: a smaller button (Ask) and a larger one (Next) share a middle.
    private func same(_ id: String, _ a: (y: Double, h: Double), _ b: (y: Double, h: Double)) -> Bool {
        id.hasPrefix("dock") ? a.y + a.h / 2 == b.y + b.h / 2 : a.y == b.y && a.h == b.h
    }

    /// Plays to the end, drawing each board and each build-up as Sidefolk would see it, and holds every id to the place it first had. `from`: boards before it are a set-up.
    private func check<S: GameScreen>(_ screen: S.Type, seed: UInt64, language: String = "en", options: GameOptions? = nil, first: Int = 0) throws {
        try Language.with(language, strings: PlaytimeGameTests.strings) {
            PlaytimeRecords.update { $0 = PlaytimeRecords() }
            TriviaRecords.update { $0 = TriviaRecords() }
            let boards = try PlaytimeScreensTests.play(S.self, seed: seed, language: language, options: options).boards
            var seen: [String: (y: Double, h: Double)] = [:]
            var previous: Board?
            let entry = PlaytimeStageTests.entry(S.id)
            var drawn = 0
            for (i, board) in boards.enumerated() where i >= first && board.resultPart == nil {
                var scenes: [Scene] = []
                if let (build, _) = Suspense.buildUp(from: previous, to: board, picked: nil) {
                    var ctx = StageContext(entry: entry, previous: previous)
                    ctx.buildUp = true
                    scenes.append(BoardDrawing(build, ctx).scene())
                }
                scenes.append(BoardDrawing(board, StageContext(entry: entry, previous: previous)).scene())
                for scene in scenes {
                    for (id, place) in places(scene) where !isFree(id) {
                        if let was = seen[id] {
                            #expect(same(id, was, place), "\(S.id) seed \(seed) board \(i): \(id) moved from y \(was.y) h \(was.h) to y \(place.y) h \(place.h)")
                        } else {
                            seen[id] = place
                        }
                    }
                    drawn += 1
                }
                previous = board
            }
            #expect(drawn > 2, "\(S.id): it was played")
            #expect(seen["board"] != nil && seen["stage"] != nil && seen["table"] != nil, "\(S.id): laid out as one table")
        }
    }

    private static func mode(_ m: String) -> GameOptions {
        var o = PlaytimeScreensTests.options()
        o.mode = m
        return o
    }

    /// Past the set-up: its one board is another layout, which has its own test below.
    @Test func triviaKeepsEveryPartInPlace() throws {
        for seed in [1, 2, 3] as [UInt64] { try check(TriviaScreen.self, seed: seed, first: 1) }
    }

    @Test func higherOrLowerKeepsEveryPartInPlaceBothWays() throws {
        for seed in [1, 2, 3] as [UInt64] {
            try check(HigherLowerScreen.self, seed: seed, options: Self.mode("mine"))
            try check(HigherLowerScreen.self, seed: seed, options: Self.mode("yours"))
        }
    }

    @Test func guessMyAnimalKeepsEveryPartInPlace() throws {
        // The asking pages and the page for a new animal are two layouts; each holds still. The bot says Yes to one and No to another, and reaches both.
        for seed in [1, 2, 3, 4, 5, 6] as [UInt64] { try checkAnimal(seed: seed) }
    }

    private func checkAnimal(seed: UInt64) throws {
        try Language.with("en", strings: PlaytimeGameTests.strings) {
            PlaytimeRecords.update { $0 = PlaytimeRecords() }
            let boards = try PlaytimeScreensTests.play(GuessAnimalScreen.self, seed: seed).boards
            var seen: [String: (y: Double, h: Double)] = [:]
            var previous: Board?
            let entry = PlaytimeStageTests.entry(GuessAnimalScreen.id)
            for (i, board) in boards.enumerated() where board.resultPart == nil {
                let drawing = BoardDrawing(board, StageContext(entry: entry, previous: previous))
                for (id, place) in places(drawing.scene()) where !isFree(id) {
                    // The two pages share only what's round them.
                    let key = (drawing.gameTable == .animalTeach ? "teach/" : "asks/") + id
                    if let was = seen[key] {
                        #expect(was.y == place.y && was.h == place.h, "seed \(seed) board \(i): \(id) moved")
                    } else {
                        seen[key] = place
                    }
                }
                previous = board
            }
        }
    }

    @Test func rockPaperScissorsKeepsEveryPartInPlace() throws {
        for seed in [1, 2, 3, 4] as [UInt64] { try check(RockPaperScissorsScreen.self, seed: seed) }
    }

    /// A question of one line or of five: the same plaque, the same tickets, the same bubble. It is the board's words that shrink.
    @Test func aLongQuestionMovesNothing() throws {
        try Language.with("en", strings: PlaytimeGameTests.strings) {
            func board(_ question: String, _ answers: [String]) -> Board {
                Board([.score(you: 1, companion: 0, companionPicked: true), .prompt(question, eyebrow: "Question 1 of 5", chip: "Space"),
                       .answers(answers.map { Tile($0) }), .button(GameButton("Ask", move: "hint", style: .plain))], said: "Your turn!")
            }
            let entry = PlaytimeStageTests.entry(TriviaScreen.id)
            let short = places(BoardDrawing(board("Mars?", ["A", "B", "C", "D"]), StageContext(entry: entry)).scene())
            let long = places(BoardDrawing(board(String(repeating: "Which of these is the question that goes on and on? ", count: 4),
                                                 Array(repeating: "An answer that is much too long for its ticket by a long way", count: 4)), StageContext(entry: entry)).scene())
            #expect(Set(short.keys) == Set(long.keys))
            for (id, place) in short {
                #expect(long[id]?.y == place.y && long[id]?.h == place.h, "\(id)")
            }
        }
    }

    /// The bubble never holds the question, and a verdict's words wait for the verdict.
    @Test func theQuestionStaysOutOfTheBubble() throws {
        try Language.with("en", strings: PlaytimeGameTests.strings) {
            let boards = try PlaytimeScreensTests.play(TriviaScreen.self, seed: 2).boards
            let entry = PlaytimeStageTests.entry(TriviaScreen.id)
            for board in boards where board.answersPart != nil {
                let words = BoardDrawing(board, StageContext(entry: entry)).stageWordsOverride
                #expect(words != nil && words != board.promptPart?.text)
            }
        }
    }

    /// The founder's note on the toys: the one chosen goes into the box itself, with no copy left behind; the other two leave; and nothing of the row is left faded.
    @Test func aPickGoesIntoItsBoxAndTheRowLeaves() throws {
        try Language.with("en", strings: PlaytimeGameTests.strings) {
            let entry = PlaytimeStageTests.entry(RockPaperScissorsScreen.id)
            let tiles = Games.Hand.allCases.map { Tile(RockPaperScissorsScreen.title($0), art: $0.rawValue) }
            let before = Board([.score(you: 0, companion: 0, rounds: 2, companionPicked: true), .prompt("Rock, paper or scissors?"), .answers(tiles, layout: .row)])
            let after = Board([.score(you: 1, companion: 0, rounds: 2), .reveal(.hands(you: "rock", companion: "scissors")), .answers(tiles, layout: .row, locked: true)])
            let (build, ms) = try #require(Suspense.buildUp(from: before, to: after, picked: 0))
            #expect(ms == Suspense.revealMs)
            var ctx = StageContext(entry: entry, previous: before)
            ctx.buildUp = true
            ctx.pendingAnswer = 0
            let scene = BoardDrawing(build, ctx).scene()
            let runs = scene.animations.map(\.json)
            func frames(_ id: String, _ value: String) -> [Double] {
                runs.filter { $0["target"] as? String == id }.flatMap { ($0["keys"] as? [[String: Double]] ?? []).compactMap { $0[value] } }
            }
            #expect(frames("tile.0.toy", "opacity") == [0, 0], "no copy stays on its plate")
            let hop = frames("toy.hop", "x")
            #expect(hop.first != hop.last, "it travels")
            #expect(frames("toy.hop", "opacity").last == 0, "and it's gone, into the box")
            for i in [1, 2] {
                let x = frames("tile.\(i).toy", "x")
                #expect(abs((x.last ?? 0) - (x.first ?? 0)) > 100, "the others leave the table")
                #expect(frames("tile.\(i).toy", "opacity").last == 0)
            }
            for i in 0..<3 { #expect(frames("tile.\(i).plate", "opacity").last == 0, "no plate is left behind") }
            // The verdict's board has none of the row either, and its room is kept.
            let verdict = places(BoardDrawing(after, StageContext(entry: entry, previous: build)).scene())
            let choosing = places(BoardDrawing(before, StageContext(entry: entry)).scene())
            for i in 0..<3 { #expect(verdict["tile.\(i)"]?.y == choosing["tile.\(i)"]?.y) }
        }
    }

    /// The bluff still says its line, and its box only wiggles, once the row is home: nothing about it says which hand is inside.
    @Test func aBluffIsWordsAndAWiggle() throws {
        try Language.with("en", strings: PlaytimeGameTests.strings) {
            let entry = PlaytimeStageTests.entry(RockPaperScissorsScreen.id)
            let tiles = Games.Hand.allCases.map { Tile(RockPaperScissorsScreen.title($0), art: $0.rawValue) }
            let thrown = Board([.score(you: 1, companion: 0, rounds: 2), .reveal(.hands(you: "rock", companion: "scissors")), .answers(tiles, layout: .row, locked: true)])
            let next = Board([.score(you: 1, companion: 0, rounds: 2, companionPicked: true), .prompt("I'm going rock…"), .answers(tiles, layout: .row)], companion: Cue(move: "tease", look: "you"))
            let scene = BoardDrawing(next, StageContext(entry: entry, previous: thrown)).scene()
            let wiggle = scene.animations.map(\.json).filter { ["box.them", "boxtop.them"].contains($0["target"] as? String) && ($0["keys"] as? [[String: Double]])?.contains { $0["rotate"] != nil } == true }
            #expect(wiggle.count == 2)
            let text = String(decoding: try JSONSerialization.data(withJSONObject: scene.json), as: UTF8.self)
            #expect(text.contains("I'm going rock…"))
        }
    }

    /// One thing has one track for each value, within what Sidefolk reads: a second would cut the first off from the start (it did: the box under the blow lost its thumps, so it gave
    /// the result away), and points past 32 are dropped. And both boxes thump alike until the lids go.
    @Test func everyThrowPlaysAsItIsWritten() throws {
        try Language.with("en", strings: PlaytimeGameTests.strings) {
            let names = Games.Hand.allCases.map(\.rawValue)
            for you in names {
                for companion in names {
                    let drawing = BoardDrawing(Board([]), StageContext(entry: PlaytimeStageTests.entry(RockPaperScissorsScreen.id), previous: nil))
                    _ = drawing.hands(you: you, companion: companion, width: 260, playing: true, prefix: "toss", beat: .init(width: 260, height: 170))
                    var seen = Set<String>()
                    for run in drawing.anims.map(\.json) {
                        guard let target = run["target"] as? String, let keys = run["keys"] as? [[String: Double]] else { continue }
                        #expect(keys.count <= 32, "\(you)/\(companion): \(target) has \(keys.count) points")
                        for value in Set(keys.flatMap(\.keys)).subtracting(["t"]) {
                            #expect(seen.insert("\(target).\(value)").inserted, "\(you)/\(companion): \(target).\(value) twice")
                        }
                    }
                    func thumps(_ side: String) -> [[String: Double]] {
                        let run = drawing.anims.map(\.json).first { $0["target"] as? String == "box.\(side)" && ($0["keys"] as? [[String: Double]])?.first?["sy"] != nil }
                        return (run?["keys"] as? [[String: Double]] ?? []).filter { ($0["t"] ?? 1) <= BoardDrawing.ToyTime.opens / BoardDrawing.ToyTime.total }
                    }
                    #expect(thumps("you") == thumps("them") && !thumps("you").isEmpty, "\(you)/\(companion)")
                }
            }
        }
    }

    /// Any number up to a million has cards in the counter's window, however many digits it takes.
    @Test func aMillionFitsTheCounter() throws {
        try Language.with("en", strings: PlaytimeGameTests.strings) {
            let drawing = BoardDrawing(Board([]), StageContext(entry: PlaytimeStageTests.entry(HigherLowerScreen.id)))
            let w = 166.0
            func spread(_ words: String) -> (low: Double, high: Double) {
                var low = Double.infinity, high = -Double.infinity
                func visit(_ node: [String: Any]) {
                    if let id = node["id"] as? String, id.hasPrefix("counter."), id.dropFirst(8).allSatisfy(\.isNumber), let x = node["x"] as? Double, let cw = node["w"] as? Double {
                        low = min(low, x)
                        high = max(high, x + cw)
                    }
                    (node["children"] as? [[String: Any]] ?? []).forEach(visit)
                }
                visit(drawing.counter(words, caption: nil, w: w).json)
                return (low, high)
            }
            for words in ["7", "62", "100", "1,000", "999,999", "1,000,000"] {
                let s = spread(words)
                #expect(s.low >= w * 0.18 && s.high <= w * 0.71, "\(words): \(s)")
            }
        }
    }
}
