import Foundation
import Testing
@testable import SidefolkExtensionKit
@testable import ext_playtime

/// The founder's rule for the toys (Which Cup?, Copy Me, Quick Paws, Last Stick): nothing moves unless it means something. Over a real play-through, from the first board to the last
/// before the end card, build-ups included, the board and the parts laid out in it keep their place and height: what comes and goes (who plays, the next round, a best time, a secret)
/// has its room kept, and what is said never pushes anything.
@Suite(.serialized) @MainActor
struct PlaytimeStabilityG1 {
    /// Everything that stands still on a toy's board: the toy's whole block, and its mats, plates, trays, rows and buttons.
    nonisolated private static let fixed = ["cups.part", "cups", "cups.mat", "cups.row", "slot", "pads", "pads.status", "pads.mat", "reflex", "reflex.mat", "reflex.body", "reflex.press",
                                "sticks.part", "sticks", "sticks.frame", "sticks.row.0", "sticks.row.1", "sticks.row.2", "take.1", "take.2", "take.3"]
        + (0..<5).map { "cup.\($0).plate" } + (0..<5).map { "pad.\($0)" } + (0..<21).map { "stick.\($0).place" }

    nonisolated private static func all(_ scene: Scene) -> [String: [String: Any]] {
        var out: [String: [String: Any]] = [:]
        func visit(_ list: [[String: Any]]) {
            for n in list {
                if let id = n["id"] as? String { out[id] = n }
                visit(n["children"] as? [[String: Any]] ?? [])
            }
        }
        visit(scene.json["nodes"] as? [[String: Any]] ?? [])
        return out
    }

    nonisolated private static func box(_ node: [String: Any]) -> [Double] {
        ["x", "y", "w", "h"].map { node[$0] as? Double ?? 0 }
    }

    /// Plays a game and compares every board's places with the first's.
    private func check<S: GameScreen>(_ screen: S.Type, language: String = "en", seeds: [UInt64] = [1, 2, 3, 4], options: GameOptions? = nil) throws {
        try Language.with(language, strings: PlaytimeGameTests.strings) {
            for seed in seeds {
                PlaytimeRecords.update { $0 = PlaytimeRecords() }
                let boards = try PlaytimeScreensTests.play(S.self, seed: seed, language: language, options: options).boards
                var seen: [String: [Double]] = [:]
                var board: [Double]?
                var childCount: Int?
                var compared = 0
                var previous: Board?
                func compare(_ scene: Scene, _ what: String) {
                    let nodes = Self.all(scene)
                    guard let room = nodes["board"] else { Issue.record("\(S.id): a board without its place"); return }
                    let place = Self.box(room)
                    if let board { #expect(board == place, "\(S.id) seed \(seed) \(what): the board moved, \(board) to \(place)") }
                    board = place
                    // One child: the toy holds the room, and nothing is stacked over or under it.
                    let children = (room["children"] as? [[String: Any]])?.count ?? 0
                    if let childCount { #expect(childCount == children, "\(S.id) seed \(seed) \(what): the board's parts changed") }
                    childCount = children
                    if let only = (room["children"] as? [[String: Any]])?.first {
                        #expect(only["y"] as? Double == 0, "\(S.id) seed \(seed) \(what): it starts at the top of its room")
                        #expect(only["h"] as? Double == place[3], "\(S.id) seed \(seed) \(what): it has the whole room")
                    }
                    for id in Self.fixed {
                        guard let node = nodes[id] else { continue }
                        let at = Self.box(node)
                        if let was = seen[id] { #expect(was == at, "\(S.id) seed \(seed) \(what): \(id) moved, \(was) to \(at)") }
                        seen[id] = at
                    }
                    compared += 1
                }
                for next in boards {
                    if let (build, _) = Suspense.buildUp(from: previous, to: next, picked: nil) {
                        var ctx = StageContext(entry: GameCatalog.entry(S.id)!, previous: previous)
                        ctx.buildUp = true
                        compare(BoardDrawing(build, ctx).scene(), "build-up")
                    }
                    if !next.over { compare(BoardDrawing(next, StageContext(entry: GameCatalog.entry(S.id)!, previous: previous)).scene(), "board") }
                    previous = next
                }
                #expect(compared > 1, "\(S.id): a real play-through")
            }
        }
    }

    @Test func whichCupStaysPut() throws { try check(WhichCupScreen.self) }
    @Test func copyMeStaysPut() throws { try check(CopyMeScreen.self) }
    @Test func quickPawsStaysPut() throws { try check(QuickPawsScreen.self) }
    @Test func lastStickStaysPut() throws { try check(LastStickScreen.self) }

    @Test func longWordsPushNothing() throws {
        for language in ["de", "ja", "ar"] {
            try check(WhichCupScreen.self, language: language, seeds: [1])
            try check(CopyMeScreen.self, language: language, seeds: [1])
            try check(QuickPawsScreen.self, language: language, seeds: [1])
            try check(LastStickScreen.self, language: language, seeds: [1])
        }
    }

    /// The three takes keep their places and their rods when fewer can be taken: faded, not pressable, no key.
    @Test func theTakesKeepTheirThreePlaces() throws {
        let scene = BoardDrawing(Board([.play(.sticks(total: 21, left: 2, take: 2))]), StageContext(entry: GameCatalog.entry(LastStickScreen.id)!)).scene()
        let nodes = Self.all(scene)
        #expect(nodes["take.3"]?["opacity"] as? Double ?? 1 < 1 && nodes["take.3.top"]?["area"] == nil)
        #expect(nodes["take.2.top"]?["area"] != nil && nodes["take.2"]?["opacity"] as? Double ?? 1 == 1)
        #expect(scene.keys.contains { $0["key"] as? String == "2" } && !scene.keys.contains { $0["key"] as? String == "3" })
        // Twenty-one places, whatever is left: what has gone can still be counted.
        #expect((0..<21).allSatisfy { nodes["stick.\($0).place"] != nil })
        #expect(nodes["stick.1.art"] != nil && nodes["stick.2.art"] == nil)
    }

    /// While the companion dances the pads take nothing and say so; then they are the person's.
    @Test func aDemonstrationIsNotPressableAndSaysSo() throws {
        let pads = (0..<4).map { Pad("P\($0)", shape: "circle", color: "blue", move: "accent:wave", art: "wave") }
        let board = Board([.play(.pads(pads, play: [1, 2], stepMs: 500, length: 2))])
        var local = LocalParts()
        StageMoves.settle(board, local: &local)
        let entry = GameCatalog.entry(CopyMeScreen.id)!
        let showing = BoardDrawing(board, StageContext(entry: entry, local: local)).scene()
        var nodes = Self.all(showing)
        #expect(nodes["pad.0.face"]?["area"] == nil && !showing.keys.contains { $0["area"] as? String == "pad" })
        #expect(nodes["pads.state.watch"] != nil && nodes["pads.state.turn"] == nil)
        #expect(nodes["pad.0"]?["opacity"] as? Double ?? 1 < 1)
        local.playback?.startedAt -= 10
        _ = StageMoves.action(.next, board: board, local: &local)
        let turn = BoardDrawing(board, StageContext(entry: entry, previous: board, fresh: false, local: local)).scene()
        nodes = Self.all(turn)
        #expect(nodes["pad.0.face"]?["area"] != nil && turn.keys.contains { $0["area"] as? String == "pad" })
        #expect(nodes["pads.state.turn"] != nil && nodes["pads.state.watch"] == nil)
    }

    /// The pick's build-up lifts the cups, and only then come the words, the score and the next round's button.
    @Test func theLiftComesBeforeTheVerdict() throws {
        let before = Board([.score(you: 0, companion: 0), .prompt("Where?", eyebrow: "R"), .play(.cups(count: 4, swapMs: 400))])
        let after = Board([.score(you: 0, companion: 1), .prompt("Not that one.", eyebrow: "R"), .play(.cups(count: 4, picked: 0, revealed: true, gem: 2, locked: true)),
                           .button(GameButton("Next round", move: "next", style: .primary))])
        let (build, ms) = try #require(Suspense.buildUp(from: before, to: after, picked: nil))
        #expect(!Suspense.showsVerdict(build) && ms > Suspense.beatMs)
        var ctx = StageContext(entry: GameCatalog.entry(WhichCupScreen.id)!, previous: before)
        ctx.buildUp = true
        let scene = BoardDrawing(build, ctx).scene()
        let text = String(decoding: try JSONSerialization.data(withJSONObject: scene.json), as: UTF8.self)
        #expect(!text.contains("Not that one") && !text.contains("Next round") && text.contains("Where?"))
        #expect(text.contains("cup.up.0") && text.contains("cup.up.2") && text.contains("cups.gem"))
    }
}
