import Foundation
import Testing
@testable import ext_sideflow
import SidefolkExtensionKit

/// Where the person puts a flow's cards (D235, T67): only how the board is drawn. It never reaches what runs, what's approved, or whether the flow reads as changed.
@MainActor @Suite(.serialized) struct SideflowLayoutTests {
    typealias World = SideflowTests.World

    private func app(_ w: World) -> App {
        let app = App(folder: w.folder.appendingPathComponent("app"))
        app.engine.host = w.host
        app.catalog.use(Actions.Listing(tools: [Actions.Tool(name: "reads.it", title: "Read it", schema: #"{"properties":{"n":{"type":"number"}}}"#, mutates: false, readsOnly: true)]))
        return app
    }

    private func on(_ app: App, _ steps: [[String: Any]]) throws -> Flow {
        var flow = app.newFlow(name: "F", body: try FlowCodec.body(["trigger": ["type": "manual"], "steps": steps]))
        flow.live = flow.draft
        flow.state = .on
        app.store.save(flow)
        return flow
    }

    private func place(_ app: App, _ flow: Flow, _ place: [String: Any]) async throws {
        _ = try await Actions_UI.handle(Arguments(["op": "place", "flow": flow.id, "place": place]), app)
    }

    @Test func aPlaceIsBoundedAndOnlyForCardsTheFlowHas() throws {
        #expect(Layout.place(12.4, -7.6) == Layout.Place(x: 12, y: -8), "whole points")
        #expect(Layout.place(Double.nan, 1) == nil)
        #expect(Layout.place(Double.infinity, 1) == nil)
        #expect(Layout.place(4001, 0) == nil && Layout.place(0, -4001) == nil)
        #expect(Layout.place(true, 1) == nil)
        #expect(Layout.place("12", 1) == nil)
        let body = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "a", "text": "x"]]])
        let read = Layout.read(["a": [1, 2], "gone": [3, 4], "start": [0, 0], "bad": [1], "huge": [1e9, 0], "../x": [1, 1]])
        #expect(Set(Layout.kept(read, for: body).keys) == ["a", "start"])
        let many = Dictionary(uniqueKeysWithValues: (0..<250).map { ("s\($0)", [Double($0), 0] as [Any]) })
        #expect(Layout.read(many).count <= Layout.most * 2)
    }

    /// Moving a card changes nothing that runs or is approved: the live plan is the same, the flow doesn't read as changed, no card is asked for.
    @Test func movingACardTouchesNothingThatRuns() async throws {
        let w = try World()
        let app = app(w)
        let flow = try on(app, [["id": "a", "do": "reads.it", "with": ["n": 1]], ["id": "b", "text": "x"]])
        let plan = app.engine.livePlan(flow).steps.map(\.line)
        let asked = w.host.plans.count
        try await place(app, flow, ["id": "a", "x": 120, "y": 40])
        try await place(app, flow, ["id": "start", "x": 0, "y": -80])
        let moved = try #require(app.store.flow(flow.id))
        #expect(moved.layout == ["a": Layout.Place(x: 120, y: 40), "start": Layout.Place(x: 0, y: -80)])
        #expect(moved.draft == flow.draft && moved.live == flow.live && !moved.hasChanges && moved.version == flow.version)
        #expect(app.engine.livePlan(moved).steps.map(\.line) == plan)
        #expect(w.host.plans.count == asked, "no card")
        // Ignored, not refused: a step it doesn't have, a place out of bounds.
        try await place(app, moved, ["id": "nope", "x": 1, "y": 1])
        try await place(app, moved, ["id": "b", "x": 99_999, "y": 1])
        #expect(app.store.flow(flow.id)?.layout.count == 2)
        // Tidy up.
        try await place(app, moved, ["clear": true])
        #expect(app.store.flow(flow.id)?.layout.isEmpty == true)
    }

    @Test func theBoardDrawsCardsWhereTheyWerePutAndOffersThePlacedHook() async throws {
        let w = try World()
        let app = app(w)
        let flow = try on(app, [["id": "a", "text": "x"]])
        try await place(app, flow, ["id": "a", "x": 300, "y": 20])
        let moved = try #require(app.store.flow(flow.id))
        let page = "\(Pages.flowPage(moved, app, state: Arguments([:])))"
        #expect(page.contains("placed"))
        #expect(page.contains("300"))
    }

    @Test func aLayoutIsKeptOnDiskAndDropsStepsThatAreGone() async throws {
        let w = try World()
        let app = app(w)
        let flow = try on(app, [["id": "a", "text": "x"], ["id": "b", "text": "y"]])
        try await place(app, flow, ["id": "a", "x": 10, "y": 10])
        try await place(app, flow, ["id": "b", "x": 20, "y": 20])
        var changed = try #require(app.store.flow(flow.id))
        changed.draft = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "a", "text": "x"]]])
        app.store.save(changed)
        let saved = try #require(app.store.flow(flow.id))
        let back = try #require(FlowStore.flow(FlowStore.json(saved)))
        #expect(back.layout == ["a": Layout.Place(x: 10, y: 10)])
    }

    /// A file says format 2 only when a flow in it has a layout; old files still come in, and a definition on its own can't carry one.
    @Test func aFileCarriesTheLayoutAndSaysItsFormat() async throws {
        let w = try World()
        let app = app(w)
        let flow = try on(app, [["id": "a", "text": "x"]])
        let plain = FlowFile.write([flow], store: app.store, catalog: app.catalog, sideflow: "t")
        #expect((JSONText.read(plain) as? [String: Any])?["sideflow"] as? Int == 1)
        try await place(app, flow, ["id": "a", "x": 5, "y": 6])
        let moved = try #require(app.store.flow(flow.id))
        let placed = FlowFile.write([moved], store: app.store, catalog: app.catalog, sideflow: "t")
        #expect((JSONText.read(placed) as? [String: Any])?["sideflow"] as? Int == 2)
        #expect(try FlowFile.read(placed).first?.layout == ["a": Layout.Place(x: 5, y: 6)])
        #expect(try FlowFile.read(plain).first?.layout.isEmpty == true)
        #expect(throws: (any Error).self) { try FlowFile.read(#"{"name": "X", "flow": {"trigger": {"type": "manual"}, "steps": []}, "layout": {"a": [1, 2]}}"#) }
        #expect(throws: (any Error).self) { try FlowFile.read(#"{"sideflow": 3, "flows": [{"name": "X", "flow": {"trigger": {"type": "manual"}, "steps": []}}]}"#) }
    }

    /// The tool twin: update_flow's patch places a card, or tidies up, and refuses a step that isn't there or a place out of bounds.
    @Test func anAgentPlacesACardByPatch() throws {
        let body = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "a", "text": "x"]]])
        let out = try AgentEdits.placed([["op": "place", "id": "a", "x": 40, "y": 50]], layout: [:], body: body)
        #expect(out == ["a": Layout.Place(x: 40, y: 50)])
        #expect(try AgentEdits.placed([["op": "place", "clear": true]], layout: out, body: body).isEmpty)
        #expect(throws: (any Error).self) { try AgentEdits.placed([["op": "place", "id": "nope", "x": 1, "y": 1]], layout: [:], body: body) }
        #expect(throws: (any Error).self) { try AgentEdits.placed([["op": "place", "id": "a", "x": 9_999, "y": 1]], layout: [:], body: body) }
    }

    /// After Revoke or the 60-day end, an agent reads "ended", not "allowed".
    @Test func anEndedApprovalReadsAsEnded() throws {
        let w = try World()
        let app = app(w)
        let flow = try on(app, [["id": "a", "text": "x"]])
        #expect(Summaries.approval(flow, app) == "allowed")
        app.engine.planEnded(flow.id)
        let ended = try #require(app.store.flow(flow.id))
        #expect(Summaries.approval(ended, app) == "ended")
    }
}
