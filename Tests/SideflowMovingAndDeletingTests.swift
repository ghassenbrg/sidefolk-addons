import Foundation
import Testing
@testable import ext_sideflow
import SidefolkExtensionKit

/// Moving a step from the side panel, what's said about it, and deleting several flows at once.
@MainActor @Suite(.serialized) struct SideflowMovingAndDeletingTests {
    typealias World = SideflowTests.World

    private func app(_ w: World) -> App {
        let app = App(folder: w.folder.appendingPathComponent("app"))
        app.engine.host = w.host
        return app
    }

    private func flow(_ app: App, _ name: String = "F") throws -> Flow {
        app.newFlow(name: name, body: try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "a", "name": "Aye", "text": "1"], ["id": "b", "name": "Bee", "text": "2"], ["id": "c", "name": "Cee", "text": "3"], ["id": "d", "name": "Dee", "text": "4"]]]))
    }

    private func page(_ app: App, _ op: String, _ extra: [String: Any] = [:]) async throws {
        var input: [String: Any] = ["op": op]
        input.merge(extra) { _, new in new }
        _ = try await Actions_UI.handle(Arguments(input), app)
    }

    private func order(_ app: App, _ flow: Flow) -> [String] { app.store.flow(flow.id)?.draft.steps.map(\.id) ?? [] }

    private func form(_ flow: Flow, _ app: App, step: String) -> String {
        app.nav.inspect(.step(step), in: flow.id)
        return String(describing: Inspector.sections(try! #require(app.store.flow(flow.id)), app, problems: [])).filter { !"\u{2068}\u{2069}".contains($0) }
    }

    @Test func thePanelOffersMovingInPlainSight() throws {
        let w = try World()
        let app = app(w)
        let f = try flow(app)
        let shown = form(f, app, step: "b")
        for words in ["Move up", "Move down", "Move to", "The very start", "After Cee", "After Dee"] { #expect(shown.contains(words), "\(words)") }
        #expect(!shown.contains("After Aye"), "it's already there")
        #expect(!shown.contains("After Bee"), "not after itself")
    }

    @Test func theEndsCantGoFurther() throws {
        let w = try World()
        let app = app(w)
        let f = try flow(app)
        let first = form(f, app, step: "a")
        #expect(!first.contains("The very start"), "it's there")
        let up = "Move up"
        #expect(first.contains(up))
        #expect(Editing.siblings(of: "a", in: f.draft).first?.id == "a")
    }

    @Test func thePanelsMovesWork() async throws {
        let w = try World()
        let app = app(w)
        let f = try flow(app)
        try await page(app, "down", ["flow": f.id, "step": "a"])
        #expect(order(app, f) == ["b", "a", "c", "d"])
        try await page(app, "up", ["flow": f.id, "step": "a"])
        #expect(order(app, f) == ["a", "b", "c", "d"])
        try await page(app, "move_after", ["flow": f.id, "step": "a", "value": "c"])
        #expect(order(app, f) == ["b", "c", "a", "d"])
        try await page(app, "move_after", ["flow": f.id, "step": "d", "value": "start"])
        #expect(order(app, f) == ["d", "b", "c", "a"])
        try await page(app, "undo", ["flow": f.id])
        #expect(order(app, f) == ["b", "c", "a", "d"], "and it's one step back")
    }

    @Test func aStepCantMoveIntoItself() throws {
        let body = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "t", "try": [["id": "x", "text": "1"]], "recover": [["id": "y", "text": "2"]]], ["id": "z", "text": "3"]]])
        let places = Editing.placesToMove("t", in: body).map(\.id)
        #expect(!places.contains("x") && !places.contains("y"))
        #expect(places == ["z"])
        #expect(Editing.place("t", after: "x", in: body) == body, "and the place it's asked to go is checked too")
    }

    @Test func movingOneStepSaysOneMoved() throws {
        let w = try World()
        let app = app(w)
        let f = try flow(app)
        var moved = f.draft
        moved = Editing.move("d", before: "b", in: moved)
        let said = Editing.changes(from: f.draft, to: moved, catalog: app.catalog).filter { $0.contains("Moved") }
        #expect(said.count == 1, "\(said)")
        #expect(said.first?.contains("Dee") == true, "\(said)")
        let inARow = Editing.move("a", before: nil, in: f.draft)
        #expect(Editing.changes(from: f.draft, to: inARow, catalog: app.catalog).filter { $0.contains("Moved") }.count == 1)
        #expect(Editing.changes(from: f.draft, to: f.draft, catalog: app.catalog).isEmpty)
    }

    @Test func movingBetweenBranchesSaysSo() throws {
        let w = try World()
        let app = app(w)
        let body = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "t", "try": [["id": "x", "text": "1"], ["id": "x2", "text": "1"]], "recover": [["id": "y", "text": "2"]]], ["id": "z", "text": "3"]]])
        let moved = Editing.place("z", after: "x", in: body)
        let said = Editing.changes(from: body, to: moved, catalog: app.catalog).filter { $0.contains("Moved") }
        #expect(said.count == 1, "\(said)")
    }

    /// As the page's own button sends it, after long enough to read it.
    private func sure(_ app: App) async throws {
        app.nav.askedToDeleteAt = Date().addingTimeInterval(-10)
        try await page(app, "pick_delete_sure", ["page_token": app.pageKey])
    }

    private func pageWords(_ app: App) async -> String {
        String(describing: await Pages.make(app, state: Arguments([:]), background: false).sent).filter { !"\u{2068}\u{2069}".contains($0) }
    }

    @Test func deletingSeveralSaysHowManyAndWhichFirst() async throws {
        let w = try World()
        let app = app(w)
        let one = try flow(app, "Morning check"), two = try flow(app, "Invoice run"), three = try flow(app, "Stays here")
        try await page(app, "pick_flows")
        var words = await pageWords(app)
        #expect(words.contains("Pick the flows to delete"))
        try await page(app, "pick_flow", ["picked": one.id, "on": true])
        try await page(app, "pick_flow", ["picked": two.id, "on": true])
        words = await pageWords(app)
        #expect(words.contains("2 selected"), "\(words.prefix(400))")
        #expect(app.store.flows().count == 3, "picking deletes nothing")
        // Not without being sure.
        try await page(app, "pick_delete_sure")
        #expect(app.store.flows().count == 3)
        try await page(app, "pick_delete")
        words = await pageWords(app)
        #expect(words.contains("Delete these 2 flows?"))
        #expect(words.contains("Morning check") && words.contains("Invoice run"))
        let drawn = await Pages.make(app, state: Arguments([:]), background: false)
        let going = drawn.sections.flatMap(\.blocks).compactMap { block -> [String]? in
            if case .facts(_, let items) = block { items.map(\.0) } else { nil }
        }.flatMap(\.self)
        #expect(going == ["Morning check", "Invoice run"], "these and only these, the one staying isn't named: \(going)")
        #expect(words.contains("be undone"))
        #expect(app.store.flows().count == 3, "asking deletes nothing")
        try await sure(app)
        #expect(app.store.flows().map(\.id) == [three.id])
        #expect(app.nav.pickingFlows == nil)
    }

    @Test func onlyThePagesOwnButtonDeletes() async throws {
        let w = try World()
        let app = app(w)
        _ = try flow(app, "One")
        // All the way through, as another extension could on cards that name no flow.
        try await page(app, "pick_flows")
        try await page(app, "pick_all")
        try await page(app, "pick_delete")
        app.nav.askedToDeleteAt = Date().addingTimeInterval(-10)
        try await page(app, "pick_delete_sure")
        #expect(app.store.flows().count == 1, "no token")
        try await page(app, "pick_delete_sure", ["page_token": "a guess"])
        #expect(app.store.flows().count == 1, "the wrong one")
        let drawn = String(describing: await Pages.make(app, state: Arguments([:]), background: false).sections)
        #expect(drawn.contains(app.pageKey), "the button has it")
    }

    @Test func theOldWayInIsGone() async throws {
        let w = try World()
        let app = app(w)
        let one = try flow(app, "One")
        _ = try? await Actions_UI.handle(Arguments(["op": "delete", "flow": one.id]), app)
        #expect(app.store.flow(one.id) != nil)
    }

    @Test func theSecondClickOfADoubleClickIsntBeingSure() async throws {
        let w = try World()
        let app = app(w)
        let one = try flow(app, "One")
        try await page(app, "ask_delete", ["flow": one.id])
        try await page(app, "pick_delete_sure", ["page_token": app.pageKey])
        #expect(app.store.flow(one.id) != nil, "too soon after asking")
        try await sure(app)
        #expect(app.store.flow(one.id) == nil)
    }

    @Test func aLongListNamesEveryOneItWillDelete() async throws {
        let w = try World()
        let app = app(w)
        for n in 1...30 { _ = try flow(app, "Flow \(n)") }
        try await page(app, "pick_flows")
        var drawn = await Pages.make(app, state: Arguments([:]), background: false)
        #expect(drawn.sections.allSatisfy { $0.blocks.count <= Pages.inABlock }, "none is cut off")
        let switches = drawn.sections.flatMap(\.blocks).filter { if case .toggle = $0 { true } else { false } }
        #expect(switches.count == 30, "each can be picked")
        try await page(app, "pick_all")
        try await page(app, "pick_delete")
        drawn = await Pages.make(app, state: Arguments([:]), background: false)
        let lists = drawn.sections.flatMap(\.blocks).compactMap { block -> [String]? in if case .facts(_, let items) = block { items.map(\.0) } else { nil } }
        #expect(lists.allSatisfy { $0.count <= Pages.inABlock }, "none is cut off")
        #expect(Set(lists.flatMap(\.self)) == Set((1...30).map { "Flow \($0)" }))
        try await sure(app)
        #expect(app.store.flows().isEmpty)
    }

    @Test func whatCantBeShownCantBePicked() async throws {
        let w = try World()
        let app = app(w)
        for n in 1...(Pages.mostToPick + 2) { _ = try flow(app, "Flow \(n)") }
        try await page(app, "pick_flows")
        try await page(app, "pick_all")
        #expect(app.nav.pickingFlows?.count == Pages.mostToPick)
        #expect(await pageWords(app).contains("Only the first"))
    }

    @Test func aLongFlowsMenuFitsAndSaysSo() throws {
        let w = try World()
        let app = app(w)
        let steps: [[String: Any]] = (1...40).map { ["id": "s\($0)", "name": "Step \($0)", "text": "x"] }
        let f = app.newFlow(name: "Long", body: try FlowCodec.body(["trigger": ["type": "manual"], "steps": steps]))
        let sections = { () -> [Section] in
            app.nav.inspect(.step("s20"), in: f.id)
            return Inspector.sections(try! #require(app.store.flow(f.id)), app, problems: [])
        }()
        let options = sections.flatMap(\.blocks).compactMap { block -> [Option]? in if case .picker(let title, _, _, let list, _, _, _, _, _) = block, title == "Move to" { list } else { nil } }.first
        #expect(options?.count ?? 99 <= 24)
        let words = (options ?? []).map { $0.label }.joined()
        #expect(words.contains("Step 25") && words.contains("Step 15"), "the nearest")
        #expect(String(describing: sections).contains("nearest places"))
    }

    @Test func keepingAFlowFromItsOwnMenuLeavesPicking() async throws {
        let w = try World()
        let app = app(w)
        let one = try flow(app, "One")
        try await page(app, "ask_delete", ["flow": one.id])
        try await page(app, "pick_keep")
        #expect(app.nav.pickingFlows == nil)
    }

    @Test func changingWhatsPickedAsksAgain() async throws {
        let w = try World()
        let app = app(w)
        let one = try flow(app, "One"), two = try flow(app, "Two")
        try await page(app, "pick_flows")
        try await page(app, "pick_flow", ["picked": one.id, "on": true])
        try await page(app, "pick_delete")
        try await page(app, "pick_flow", ["picked": two.id, "on": true])
        #expect(!app.nav.askingToDelete, "what it asked about has changed")
        app.nav.askedToDeleteAt = Date().addingTimeInterval(-10)
        try await page(app, "pick_delete_sure", ["page_token": app.pageKey])
        #expect(app.store.flows().count == 2)
    }

    @Test func keepingThemOrLeavingDeletesNothing() async throws {
        let w = try World()
        let app = app(w)
        let one = try flow(app, "One")
        try await page(app, "pick_flows")
        try await page(app, "pick_flow", ["picked": one.id, "on": true])
        try await page(app, "pick_delete")
        try await page(app, "pick_keep")
        #expect(app.nav.pickingFlows == [one.id], "still picked")
        #expect(app.store.flow(one.id) != nil)
        try await page(app, "pick_flow", ["picked": one.id, "on": false])
        #expect(app.nav.pickingFlows == [])
        try await page(app, "pick_delete")
        #expect(!app.nav.askingToDelete, "nothing picked, nothing to ask")
        try await page(app, "pick_none")
        #expect(app.nav.pickingFlows == nil)
        #expect(app.store.flows().count == 1)
    }

    @Test func selectAllTakesThemAll() async throws {
        let w = try World()
        let app = app(w)
        _ = try flow(app, "One")
        _ = try flow(app, "Two")
        try await page(app, "pick_flows")
        try await page(app, "pick_all")
        try await page(app, "pick_delete")
        try await sure(app)
        #expect(app.store.flows().isEmpty)
    }

    @Test func aFlowThatRunsADeletedOneIsMentioned() async throws {
        let w = try World()
        let app = app(w)
        let called = try flow(app, "Called")
        var caller = app.newFlow(name: "Caller", body: try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "c", "call_flow": "Called"]]]))
        caller.live = caller.draft
        app.store.save(caller)
        try await page(app, "ask_delete", ["flow": called.id])
        let words = await pageWords(app)
        #expect(words.contains("“Caller” runs “Called”"), "\(words.prefix(500))")
        #expect(words.contains("Delete this flow?"))
    }

    @Test func oneFlowsDeleteAsksToo() async throws {
        let w = try World()
        let app = app(w)
        let one = try flow(app, "One")
        try await page(app, "ask_delete", ["flow": one.id])
        #expect(app.store.flow(one.id) != nil, "it asks first")
        try await sure(app)
        #expect(app.store.flow(one.id) == nil)
    }

    @Test func aFlowThatsOnStopsWhenDeleted() async throws {
        let w = try World()
        let app = app(w)
        var on = try flow(app, "On one")
        on.live = on.draft
        on.state = .on
        app.store.save(on)
        try await page(app, "ask_delete", ["flow": on.id])
        #expect(await pageWords(app).contains("1 of them is on"))
    }
}
