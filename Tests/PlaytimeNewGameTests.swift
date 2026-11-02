import Foundation
import Testing
@testable import SidefolkExtensionKit
@testable import ext_playtime

/// A game nobody has seen before, with no line of Sidefolk changed (D101): what adding one takes is its engine, its screen, a menu card, a
/// driver and its sentences, all here. It is drawn as a scene Sidefolk takes, and it plays to its end through the same moves as any other.
@Suite(.serialized) @MainActor
struct PlaytimeNewGameTests {
    enum JarEngine: GameEngine {
        struct State: Codable { var taps = 0 }
        static func start(level: GameLevel, options: GameOptions, random: inout Games.Random) -> State { State() }
        static func play(_ action: Void, on state: inout State, random: inout Games.Random) throws -> [Games.Event] {
            state.taps += 1
            return []
        }
        static func outcome(of state: State) -> GameOutcome? { state.taps >= 2 ? .won : nil }
    }

    enum JarScreen: GameScreen {
        typealias Engine = JarEngine
        static let id = "coin_jar"
        static func action(for move: Move, in state: JarEngine.State) -> Void? { move == .button("tap") ? () : nil }
        static func board(_ state: JarEngine.State, events: [Games.Event], options: GameOptions) -> Board {
            if JarEngine.outcome(of: state) != nil { return Board([.result(figure: "2", line: "Full", tone: .good)], over: true) }
            return Board([.prompt("Fill the jar", eyebrow: "\(state.taps) of 2"), .button(GameButton("Add a coin", move: "tap", style: .primary))])
        }
    }

    static let entry = GameEntry(id: JarScreen.id, title: "Coin Jar", tagline: "Fill it up", symbol: "circle.fill", look: GameCatalog.all[0].look, levels: false)

    func area(_ id: String, in scene: Scene) -> [String: Any]? {
        func visit(_ list: [[String: Any]]) -> [String: Any]? {
            for node in list {
                if let area = node["area"] as? [String: Any], area["id"] as? String == id { return area }
                if let found = visit(node["children"] as? [[String: Any]] ?? []) { return found }
            }
            return nil
        }
        return visit(scene.json["nodes"] as? [[String: Any]] ?? [])
    }

    @Test func itDrawsAndPlaysToItsEnd() throws {
        let driver = GameTable.driver(JarScreen.self)
        var (state, board) = driver.start(GameOptions(), .fair)
        var local = LocalParts()
        for step in 0..<2 {
            StageMoves.settle(board, local: &local)
            let scene = BoardDrawing(board, StageContext(entry: Self.entry, fresh: step == 0, local: local)).scene()
            try PlaytimeStageTests.check(scene, "step \(step)")
            let press = try #require(scene.keys.first { $0["area"] != nil } ?? nil, "its button takes Return")
            let name = try #require(press["area"] as? String)
            #expect(area(name, in: scene) != nil, "\(press)")
            guard case .play(let move) = StageMoves.action(.click(area: name, value: press["value"] as? String, ms: nil), board: board, local: &local) else {
                Issue.record("a press of the button is the game's move")
                return
            }
            #expect(move == .button("tap"))
            let next = try #require(driver.move(move, state, GameOptions()))
            (state, board) = (next.state, next.board)
        }
        #expect(board.over)
        let end = BoardDrawing(board, StageContext(entry: Self.entry, local: local)).scene()
        try PlaytimeStageTests.check(end, "end")
        #expect(end.json["outcome"] as? String == "win")
    }
}
