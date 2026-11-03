import Foundation
import Testing
@testable import SidefolkExtensionKit
@testable import ext_playtime

/// The founder's requirement: no concept shows Trivia's "Any topic", because it shows only when an AI is allowed, and it must survive the redesign. Its tile stands with the
/// others in the tray, and its page asks for a topic in the same canvas.
@Suite(.serialized) @MainActor
struct PlaytimeTriviaAnyTopicTests {
    init() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("playtime-anytopic-\(UUID().uuidString)").path
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        setenv("SIDEFOLK_DATA_DIR", dir, 1)
    }

    private func options(ai: String?) -> GameOptions {
        var o = PlaytimeScreensTests.options("en")
        o.aiTrivia = ai
        return o
    }

    private func text(_ scene: Scene) -> String { String(decoding: try! JSONSerialization.data(withJSONObject: scene.json), as: UTF8.self) }

    /// Every node with a place stays in the canvas.
    private func staysInside(_ scene: Scene) {
        func visit(_ node: [String: Any], _ x: Double, _ y: Double) {
            let at = (x + (node["x"] as? Double ?? 0), y + (node["y"] as? Double ?? 0))
            if let area = node["area"] as? [String: Any], let w = node["w"] as? Double, let h = node["h"] as? Double {
                #expect(at.0 >= -1 && at.1 >= -1 && at.0 + w <= BoardDrawing.width + 1 && at.1 + h <= BoardDrawing.canvas + 1, "\(area["id"] ?? "") at \(at)")
            }
            for child in node["children"] as? [[String: Any]] ?? [] { visit(child, at.0, at.1) }
        }
        scene.nodes.forEach { visit($0.json, 0, 0) }
    }

    @Test func anyTopicIsThereWithAnAIAndNotWithout() throws {
        var random = Games.Random(seed: 3)
        let entry = try #require(GameCatalog.entry(TriviaScreen.id))
        let without = TriviaEngine.start(level: .fair, options: options(ai: nil), random: &random)
        #expect(!text(BoardDrawing(TriviaScreen.board(without, events: [.opened], options: options(ai: nil)), StageContext(entry: entry)).scene()).contains("Any topic"))

        let o = options(ai: "Claude Code")
        var state = TriviaEngine.start(level: .fair, options: o, random: &random)
        let setup = BoardDrawing(TriviaScreen.board(state, events: [.opened], options: o), StageContext(entry: entry)).scene()
        try PlaytimeStageTests.check(setup, "trivia setup with AI")
        #expect(text(setup).contains("Any topic"), "its tile")
        staysInside(setup)

        _ = GameTable.play(TriviaScreen.self, .choice(name: "topic", value: TriviaEngine.surprise), on: &state, random: &random)
        let page = BoardDrawing(TriviaScreen.board(state, events: [], options: o), StageContext(entry: entry)).scene()
        try PlaytimeStageTests.check(page, "trivia any topic")
        let words = text(page)
        #expect(words.contains("Make questions") && words.contains("Claude Code") && words.contains("\"type\":\"entry\""), "a field to name a topic, and whose words these are")
        staysInside(page)
    }
}
