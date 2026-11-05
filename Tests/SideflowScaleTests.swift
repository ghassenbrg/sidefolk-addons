import Foundation
import Testing
@testable import ext_sideflow
import SidefolkExtensionKit

/// A long flow: wrapping steps, focusing on a part, and a board that fits.
@MainActor @Suite(.serialized) struct SideflowScaleTests {
    typealias World = SideflowTests.World

    private func app(_ w: World) -> App {
        let app = App(folder: w.folder.appendingPathComponent("app"))
        app.engine.host = w.host
        return app
    }

    private func texts(_ prefix: String, _ count: Int) -> [[String: Any]] { (0..<count).map { ["id": "\(prefix)\($0)", "text": "x"] } }

    private func nodes(_ list: [CardTree.Node]) -> Int { list.reduce(0) { $0 + 1 + $1.branches.reduce(0) { $0 + nodes($1.nodes) } } }

    @Test func stepsGoInsideSomethingAsOneEditAndUndoTakesThemOut() async throws {
        let w = try World()
        let app = app(w)
        let flow = app.newFlow(name: "Mine", body: try FlowCodec.body(["trigger": ["type": "manual"], "steps": texts("s", 4)]))
        _ = try await Actions_UI.handle(Arguments(["op": "wrap_through", "flow": flow.id, "step": "s1", "value": "s2"]), app)
        _ = try await Actions_UI.handle(Arguments(["op": "wrap", "flow": flow.id, "step": "s1", "value": "try"]), app)
        let body = try #require(app.store.flow(flow.id)?.draft)
        #expect(body.steps.map(\.id).count == 3)
        guard case .attempt(let inside, _, _) = body.steps[1].kind else { Issue.record("not inside a try"); return }
        #expect(inside.map(\.id) == ["s1", "s2"])
        #expect(app.nav.inspecting(flow) == .step(body.steps[1].id))
        _ = try await Actions_UI.handle(Arguments(["op": "undo", "flow": flow.id]), app)
        #expect(app.store.flow(flow.id)?.draft.steps.map(\.id) == ["s0", "s1", "s2", "s3"])
    }

    @Test func eachKindHoldsThem() throws {
        let body = try FlowCodec.body(["trigger": ["type": "manual"], "steps": texts("s", 2)])
        for kind: Step.Kind in [.branch(Condition(value: "", test: .contains, than: ""), then: [], otherwise: []), .forEach(items: "", limit: 5, onFailure: .stop, steps: []), .repeatUntil(until: Condition(value: "", test: .contains, than: ""), times: 3, steps: []), .attempt(steps: [], recover: [], always: []), .parallel(lanes: [Step.Lane(name: "A", steps: [])])] {
            let out = try #require(Editing.wrap(from: "s0", through: "s1", inside: Step(id: "h", kind: kind), in: body))
            #expect(out.steps.map(\.id) == ["h"])
            #expect(out.allSteps.map(\.id) == ["h", "s0", "s1"])
        }
        #expect(Editing.wrap(from: "s1", through: "s0", inside: Step(id: "h", kind: .attempt(steps: [], recover: [], always: [])), in: body) == nil, "backwards")
        #expect(Editing.wrap(from: "s0", through: "s1", inside: Step(id: "h", kind: .text("x")), in: body) == nil, "nothing to hold them")
    }

    @Test func aHugeBoardFitsAndSaysSoAndNothingIsLeftOutWithoutAWord() throws {
        let w = try World()
        let app = app(w)
        let holders: [[String: Any]] = (0..<8).map { ["id": "h\($0)", "try": texts("i\($0)x", 24)] }
        let flow = app.newFlow(name: "Mine", body: try FlowCodec.body(["trigger": ["type": "manual"], "steps": holders]))
        #expect(flow.draft.allSteps.count == 200)
        let tree = Pages.tree(flow, app, problems: [])
        #expect(nodes(tree.nodes) <= Pages.boardHolds + 1, "\(nodes(tree.nodes))")
        let page = String(describing: Pages.flowPage(flow, app, state: Arguments([:]))).filter { !"\u{2068}\u{2069}\\".contains($0) }
        #expect(page.contains("steps inside") && page.contains("Focus on one"))
    }

    @Test func whatsSelectedStaysInSight() {
        let inner = Step(id: "inner", kind: .text("x"))
        let holder = Step(id: "h", kind: .attempt(steps: [inner] + (0..<200).map { Step(id: "t\($0)", kind: .text("x")) }, recover: [], always: []))
        #expect(!Pages.foldedToFit([holder], chosen: ["h"], selected: ["h"]).contains("h"))
    }

    @Test func focusingShowsOnlyThatPartAndTheWayBack() async throws {
        let w = try World()
        let app = app(w)
        let flow = app.newFlow(name: "Mine", body: try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "o", "try": [["id": "i", "try": texts("x", 2)]]], ["id": "after", "text": "y"]]]))
        _ = try await Actions_UI.handle(Arguments(["op": "focus", "flow": flow.id, "step": "i"]), app)
        let tree = Pages.tree(flow, app, problems: [])
        #expect(tree.nodes.map(\.id) == ["i"])
        let page = String(describing: Pages.flowPage(flow, app, state: Arguments([:]))).filter { !"\u{2068}\u{2069}\\".contains($0) }
        #expect(page.contains("All steps"))
        _ = try await Actions_UI.handle(Arguments(["op": "focus", "flow": flow.id]), app)
        #expect(Pages.tree(flow, app, problems: []).nodes.map(\.id) == ["start", "o", "after"])
        #expect(Editing.holders(of: "x0", in: flow.draft).map(\.id) == ["o", "i"])
    }

    @Test func aFoldedPartSaysHowMuchItHolds() async throws {
        let w = try World()
        let app = app(w)
        let flow = app.newFlow(name: "Mine", body: try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "o", "try": texts("x", 3)]]]))
        _ = try await Actions_UI.handle(Arguments(["op": "fold", "flow": flow.id, "step": "o"]), app)
        let folded = Pages.tree(flow, app, problems: []).nodes[1]
        #expect(folded.branches.isEmpty && folded.pill?.text.contains("3") == true)
        _ = try await Actions_UI.handle(Arguments(["op": "fold", "flow": flow.id, "step": "o"]), app)
        #expect(!Pages.tree(flow, app, problems: []).nodes[1].branches.isEmpty)
    }
}
