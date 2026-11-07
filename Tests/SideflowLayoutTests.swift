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
        // Read from JSON, 0 and 1 are numbers, and true is not.
        let fromJSON = try #require(JSONText.read(#"{"a": [0, 1], "b": [true, 1]}"#))
        #expect(Layout.read(fromJSON) == ["a": Layout.Place(x: 0, y: 1)])
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
        // A definition copied on its own carries its places too, for steps it has.
        #expect(try FlowFile.read(#"{"name": "X", "flow": {"trigger": {"type": "manual"}, "steps": [{"id": "a", "text": "x"}]}, "layout": {"a": [1, 2], "gone": [3, 4]}}"#).first?.layout == ["a": Layout.Place(x: 1, y: 2)])
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

    /// Past the bound, which places a file keeps follows the ids' order, not how a dictionary happens to list them.
    @Test func readingKeepsTheSamePlacesEveryTime() {
        let many = Dictionary(uniqueKeysWithValues: (0..<300).map { (String(format: "s%03d", $0), [Double($0), 0] as [Any]) })
        let read = Layout.read(many)
        #expect(read.count == Layout.most * 2)
        #expect(read["s000"] != nil && read["s199"] != nil && read["s200"] == nil)
    }

    /// A copied card sits beside the one it copies; a new holder takes the first wrapped step's place, and what it holds is laid out with it.
    @Test func duplicatingAndWrappingKeepPlacesSensible() async throws {
        let w = try World()
        let app = app(w)
        let flow = try on(app, [["id": "a", "text": "x"], ["id": "b", "text": "y"]])
        try await place(app, flow, ["id": "a", "x": 100, "y": 200])
        _ = try await Actions_UI.handle(Arguments(["op": "dup_step", "flow": flow.id, "step": "a"]), app)
        let copied = try #require(app.store.flow(flow.id))
        let new = try #require(copied.draft.steps.map(\.id).first { $0 != "a" && $0 != "b" })
        #expect(copied.layout[new] == Layout.Place(x: 140, y: 240))
        _ = try await Actions_UI.handle(Arguments(["op": "wrap", "flow": flow.id, "step": "a", "value": "try"]), app)
        let wrapped = try #require(app.store.flow(flow.id))
        let holder = try #require(wrapped.draft.steps.first { $0.id != "b" && $0.id != new })
        #expect(wrapped.layout[holder.id] == Layout.Place(x: 100, y: 200))
        #expect(wrapped.layout["a"] == nil, "inside the holder now, laid out with it")
    }

    /// Copy as a definition carries the places, and bringing it back keeps them.
    @Test func copyAsADefinitionCarriesThePlaces() async throws {
        let w = try World()
        let app = app(w)
        let flow = try on(app, [["id": "a", "text": "x"]])
        try await place(app, flow, ["id": "a", "x": 7, "y": 8])
        let placed = try #require(app.store.flow(flow.id))
        let copied = "\(Pages.copyDefinition(placed))"
        #expect(copied.contains("layout"))
        #expect(!"\(Pages.copyDefinition(flow))".contains("layout"), "nothing placed, nothing extra")
    }

    /// Undo takes a move back, one step, and Redo brings it again; a second drag of the same card a moment later is the same move.
    @Test func undoTakesAMoveBack() async throws {
        let w = try World()
        let app = app(w)
        let flow = try on(app, [["id": "a", "text": "x"]])
        try await place(app, flow, ["id": "a", "x": 10, "y": 10])
        try await place(app, flow, ["id": "a", "x": 30, "y": 30])
        #expect(app.store.flow(flow.id)?.layout["a"] == Layout.Place(x: 30, y: 30))
        _ = try await Actions_UI.handle(Arguments(["op": "undo", "flow": flow.id]), app)
        #expect(app.store.flow(flow.id)?.layout.isEmpty == true, "one drag, one step back")
        _ = try await Actions_UI.handle(Arguments(["op": "redo", "flow": flow.id]), app)
        #expect(app.store.flow(flow.id)?.layout["a"] == Layout.Place(x: 30, y: 30))
        let after = try #require(app.store.flow(flow.id))
        #expect(after.draft == flow.draft && after.live == flow.live && !after.hasChanges, "nothing that runs moved")
        try await place(app, after, ["clear": true])
        _ = try await Actions_UI.handle(Arguments(["op": "undo", "flow": flow.id]), app)
        #expect(app.store.flow(flow.id)?.layout["a"] == Layout.Place(x: 30, y: 30), "Tidy up is a step of its own")
    }

    /// A run waiting on a form shows that form on the flow's own page, so nobody has to go looking in its runs.
    @Test func aWaitingFormIsOnTheFlowsOwnPage() async throws {
        let w = try World()
        let app = app(w)
        let flow = try on(app, [["id": "f", "form": ["title": "Tell me", "fields": [["name": "who", "label": "What should it call you?", "kind": "text", "required": true]]]], ["id": "t", "text": "{{f.who}}"]])
        #expect(!"\(Pages.flowPage(flow, app, state: Arguments([:])))".contains("form_send"))
        let run = try #require(app.engine.start(flow, mode: .live, why: "t"))
        await w.quiet(app.store)
        #expect(app.store.run(run.id)?.form != nil)
        let now = try #require(app.store.flow(flow.id))
        let page = "\(Pages.flowPage(now, app, state: Arguments([:])))"
        #expect(page.contains("form_send") && page.contains("What should it call you?"))
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
