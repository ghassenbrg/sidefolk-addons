import Foundation
import Testing
@testable import SidefolkExtensionKit
@testable import ext_playtime

/// Rock, paper, scissors (Sidefolk D75, D96) and the desktop's coin, dice and hands (D44, D101), now Playtime's own.
@Suite(.serialized) @MainActor
struct PlaytimeHandsAndTossTests {
    typealias Engine = RockPaperScissorsEngine
    typealias Hand = Games.Hand

    init() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("playtime-hands-\(UUID().uuidString)").path
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        setenv("SIDEFOLK_DATA_DIR", dir, 1)
    }

    /// Without the marks that keep a filled-in value apart from the words round it.
    static func plain(_ words: String?) -> String? { words?.filter { !["\u{2068}", "\u{2069}"].contains(String($0)) } }

    static func text(_ json: [String: Any]) -> String { String(data: try! JSONSerialization.data(withJSONObject: json), encoding: .utf8)! }

    // MARK: The match

    @Test func itsHandIsFixedBeforeThePersonPicksAndKeepsNoThreeInARow() throws {
        for seed in 1...60 as ClosedRange<UInt64> {
            var random = Games.Random(seed: seed)
            var s = Engine.start(level: .fair, options: PlaytimeScreensTests.options(), random: &random)
            var seen: [Hand] = []
            while !s.over {
                let sealed = try #require(s.sealed)
                seen.append(sealed)
                _ = try Engine.play(.hand(0), on: &s, random: &random)
                #expect(s.last?.companion == sealed, "the hand it held before the pick")
                #expect(s.sealed == nil && s.bluff == nil)
                if !s.over { _ = try Engine.play(.next, on: &s, random: &random) }
            }
            for i in seen.indices.dropFirst(2) { #expect(!(seen[i] == seen[i - 1] && seen[i] == seen[i - 2]), "\(seen)") }
        }
        #expect(Hand.rock.beats == .scissors && Hand.paper.beats == .rock && Hand.scissors.beats == .paper)
    }

    @Test func aMatchIsTwoWinsAndEndsOnItsCard() throws {
        try Language.with("en", strings: PlaytimeGameTests.strings) {
            var random = Games.Random(seed: 3)
            var s = Engine.start(level: .fair, options: PlaytimeScreensTests.options(), random: &random)
            s.you = 1
            s.sealed = .scissors
            let events = try Engine.play(.hand(0), on: &s, random: &random)
            #expect(events == [.matchOver(winner: .you)])
            let board = RockPaperScissorsScreen.board(s, events: events, options: PlaytimeScreensTests.options())
            #expect(board.over && board.companion?.move == "bow" && board.companion?.effect == "confetti")
            #expect(board.revealPart != nil && board.resultPart?.tone == .good)
            let tiles = try #require(board.answersPart?.tiles)
            #expect(tiles[0].state == .right && tiles[2].companion && tiles[1].state == .faded)
            #expect(PlaytimeRecords.load().games[RockPaperScissorsScreen.id]?.won == 1)
            #expect(PlaytimeRecords.load().hands?.person == 1)
        }
    }

    @Test func aRoundsWordsSayHowItWent() throws {
        try Language.with("en", strings: PlaytimeGameTests.strings) {
            #expect(TossWords.verdict(person: .paper, companion: .rock) == "Paper beats rock: you win!")
            #expect(TossWords.verdict(person: .rock, companion: .paper) == "Paper beats rock: I win!")
            #expect(TossWords.verdict(person: .rock, companion: .rock) == "We both played rock: a draw!")
            var s = Engine.State(duo: TwoPlayers.Duo(names: ["Ana", "Sam"]))
            s.bluff = .paper
            s.sealed = .rock
            let words = RockPaperScissorsScreen.board(s, events: [.turn(.you)], options: PlaytimeScreensTests.options()).promptPart?.text
            #expect(words == "I'm going paper…", "the bluff stays in the panel's bubble")
        }
    }

    /// The first hand never shows until the second is in, and two people's match is kept apart from the companion's.
    @Test func twoPeopleSeeNothingBeforeTheReveal() throws {
        try Language.with("en", strings: PlaytimeGameTests.strings) {
            let o = PlaytimeTwoPlayersTests.two()
            var random = Games.Random(seed: 5)
            var s = Engine.start(level: .fair, options: o, random: &random)
            #expect(s.sealed == nil && s.duo.naming == 0)
            _ = try Engine.play(.duo(.begin), on: &s, random: &random)
            #expect(s.duo.playing)
            func board(_ e: [Games.Event] = []) -> Board { RockPaperScissorsScreen.board(s, events: e, options: o) }
            #expect(Self.plain(board().promptPart?.text) == "Ana, pick your toy.")
            let picked = try Engine.play(.hand(2), on: &s, random: &random)
            let cover = board(picked)
            #expect(Self.plain(cover.promptPart?.text) == "Pass the Mac to Sam." && cover.answersPart == nil)
            #expect(!Self.text(cover.json).contains("scissors"), "nothing says which")
            #expect(throws: Games.Refusal.self) { try Engine.play(.hand(0), on: &s, random: &random) }
            _ = try Engine.play(.ready, on: &s, random: &random)
            #expect(Self.plain(board().promptPart?.text) == "Sam, pick your toy." && !Self.text(board().json).contains("\"picked\""))
            let round = try Engine.play(.hand(0), on: &s, random: &random)
            #expect(round == [.roundOver(winner: .companion)])
            let thrown = board(round)
            #expect(Self.plain(thrown.promptPart?.text) == "Rock beats Scissors: a point for Sam.")
            #expect(thrown.answersPart?.tiles.map(\.state) == [.picked, .faded, .picked], "whose, never who won")
            s.companion = 1
            s.last = nil
            s.firstHand = .rock
            s.handedOver = true
            let end = try Engine.play(.hand(1), on: &s, random: &random)
            #expect(end == [.matchOver(winner: .companion)])
            #expect(board(end).resultPart?.tone == .info && board(end).companion?.move == "cheer")
            #expect(PlaytimeRecords.load().duels?[RockPaperScissorsScreen.id]?["Ana · Sam"]?.wins["Sam"] == 1)
            #expect(PlaytimeRecords.load().hands == nil, "never mixed with the companion's")
        }
    }

    @Test func whatTheAppKeptIsHandedOver() {
        _ = PlaytimeCarry.receive(Arguments([:]), store: ["companion.handsScore": ["person": 3, "companion": 2, "draws": 1],
                                                          "companion.handsDuels": ["Ana · Sam": ["wins": ["Ana": 2]]]], history: [:])
        let r = PlaytimeRecords.load()
        #expect(r.hands == PlaytimeRecords.HandsTally(person: 3, companion: 2, draws: 1))
        #expect(r.duels?[RockPaperScissorsScreen.id]?["Ana · Sam"]?.wins["Ana"] == 2)
    }

    // MARK: The desktop

    @Test func theToolDrawsWithinItsLimits() throws {
        var random = Games.Random(seed: 9)
        func draw(_ a: [String: Any]) throws -> Toss { try TossTool.draw(Arguments(a), random: &random) }
        guard case .coins(let flips, let call) = try draw(["kind": "coin", "many": "n3", "call": "heads"]) else { throw Problem("a coin") }
        #expect(flips.count == 3 && call == nil, "a call is for one coin")
        guard case .coins(_, let one) = try draw(["kind": "coin", "call": "tails"]) else { throw Problem("a coin") }
        #expect(one == false)
        #expect(throws: Problem.self) { try draw(["kind": "coin", "count": 6]) }
        guard case .dice(let sides, let rolls, let modifier) = try draw(["kind": "dice", "count": 2, "sides": 20, "minus": 3]) else { throw Problem("dice") }
        #expect(sides == 20 && rolls.count == 2 && modifier == -3 && rolls.allSatisfy { (1...20).contains($0) })
        #expect(throws: Problem.self) { try draw(["kind": "dice", "count": 11]) }
        #expect(throws: Problem.self) { try draw(["kind": "dice", "sides": 101]) }
        #expect(throws: Problem.self) { try draw(["kind": "rock_paper_scissors"]) }
        guard case .hands(let person, _) = try draw(["kind": "rock_paper_scissors", "hand": "paper"]) else { throw Problem("a hand") }
        #expect(person == .paper)
    }

    @Test func whatWasDrawnReachesTheOverlayWhole() {
        for toss: Toss in [.coins([true, false, true]), .coins([false], call: true), .dice(sides: 20, rolls: [20, 1], modifier: -2), .hands(person: .rock, companion: .paper)] {
            #expect(Toss(arguments: Arguments(toss.arguments)) == toss)
        }
        #expect(Toss(arguments: Arguments([:])) == nil)
    }

    @Test func aResultInWords() throws {
        try Language.with("en", strings: PlaytimeGameTests.strings) {
            #expect(Toss.coins([true]).result == "Heads!")
            #expect(Toss.coins([true, false]).result == "Heads, tails")
            #expect(Self.plain(Toss.dice(sides: 6, rolls: [4], modifier: 0).result) == "It's 4!")
            #expect(Toss.dice(sides: 6, rolls: [4, 2], modifier: 1).result == "4 + 2 + 1 = 7")
            #expect(Toss.dice(sides: 6, rolls: [4, 2], modifier: -1).result == "4 + 2 − 1 = 5")
            #expect(Toss.notation(count: 2, sides: 6, modifier: 1) == "2d6+1")
            #expect(Toss.coins([true], call: false).called == false && Toss.coins([true], call: false).verdict == .loss)
            #expect(Toss.dice(sides: 6, rolls: [4], modifier: 0).verdict == nil)
        }
    }

    /// While it flies nothing says what came up, nothing asks to be pressed, and it stops by itself; it fits what the manifest declares, and any number of dice do.
    @Test func theOverlaysScenes() throws {
        try Language.with("en", strings: PlaytimeGameTests.strings) {
            let cases: [Toss] = [.coins([true]), .coins([true, false, true, false, true]), .dice(sides: 6, rolls: [4], modifier: 0), .dice(sides: 6, rolls: Array(repeating: 6, count: 10), modifier: 100),
                                 .dice(sides: 20, rolls: [20], modifier: 0), .dice(sides: 100, rolls: [100, 1], modifier: -1), .hands(person: .rock, companion: .scissors),
                                 .hands(person: .paper, companion: .scissors), .hands(person: .rock, companion: .rock)]
            for toss in cases {
                let flying = TossSurface.flying(toss), landed = TossSurface.landed(toss)
                for scene in [flying, landed] {
                    try PlaytimeStageTests.check(scene, "\(toss)")
                    #expect(scene.width <= 460 && scene.height <= 420, "\(toss): \(scene.width) × \(scene.height)")
                }
                #expect(flying.json["after_ms"] as? Int == TossSurface.Timing(toss).totalMs)
                #expect(flying.json["after_still_ms"] as? Int == 200)
                let words = Self.text(flying.json)
                #expect(!words.contains(toss.result.replacingOccurrences(of: "\"", with: "")), "\(toss): the result before it has landed")
                #expect(!words.contains("crown.fill") && !words.contains("toss.chip"), "\(toss)")
                #expect(landed.json["close"] as? Bool == true && landed.json["close_after_ms"] as? Int == 5000)
                #expect((landed.json["announce"] as? String)?.hasPrefix(toss.result) == true)
                let again = Self.text(landed.json).contains("\"again\"")
                if case .hands = toss { #expect(!again, "a hand isn't thrown again") } else { #expect(again) }
            }
            // A loss is never red: the calm tone, with its symbol.
            let chip = Self.text(TossToys.Tag(.hands(person: .rock, companion: .paper), line: nil).node.json)
            #expect(chip.contains("xmark.circle.fill") && chip.contains("loss"))
            // Right to left and a long language fit too.
        }
        for language in ["ar", "de", "ja"] {
            try Language.with(language, strings: PlaytimeGameTests.strings) {
                for toss: Toss in [.coins([true, false]), .dice(sides: 6, rolls: [3, 4], modifier: 1), .hands(person: .paper, companion: .rock)] {
                    try PlaytimeStageTests.check(TossSurface.landed(toss), "\(language) \(toss)")
                }
            }
        }
    }

    /// The reveal's words and its result: the count comes first and a hand shows only at its moment, in the same scene (the build-up).
    @Test func aHandStaysHiddenUntilItOpens() throws {
        try Language.with("en", strings: PlaytimeGameTests.strings) {
            let drawing = BoardDrawing(Board([]), StageContext(entry: PlaytimeStageTests.entry(RockPaperScissorsScreen.id)))
            _ = drawing.hands(you: "rock", companion: "scissors", width: 372, playing: true, prefix: "reveal", beat: .init())
            let runs = drawing.anims.map(\.json)
            // Each toy shows only as its box opens, and both in the same moment: a choice comes out then, and not before.
            func shows(_ side: String) -> Double? {
                let run = runs.first { $0["target"] as? String == "reveal.\(side)" && ($0["keys"] as? [[String: Double]])?.first?["opacity"] == 0 }
                return (run?["keys"] as? [[String: Double]])?.first { $0["opacity"] == 1 }?["t"]
            }
            let opens = BoardDrawing.ToyTime.opens / BoardDrawing.ToyTime.total
            #expect(shows("you") == shows("them"))
            #expect((shows("you") ?? 0) >= opens, "nothing shows before the lids go")
            #expect(drawing.handsVerdict("rock", "scissors") == .win && drawing.handsVerdict("rock", "paper") == .loss && drawing.handsVerdict("rock", "rock") == .draw)
        }
    }
}
