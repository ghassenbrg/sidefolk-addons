import Foundation
import Testing
@testable import ext_sideflow
import SidefolkExtensionKit

/// Taking several steps off the board at once, and deleting flows from Your flows without opening them.
@MainActor @Suite(.serialized) struct SideflowRemovingTests {
    typealias World = SideflowTests.World

    private func app(_ w: World) -> App {
        let app = App(folder: w.folder.appendingPathComponent("app"))
        app.engine.host = w.host
        return app
    }

    private func make(_ app: App, _ name: String, _ steps: [[String: Any]]) throws -> Flow {
        app.newFlow(name: name, body: try FlowCodec.body(["trigger": ["type": "manual"], "steps": steps]))
    }

    private func page(_ app: App, _ input: [String: Any]) async throws {
        _ = try await Actions_UI.handle(Arguments(input), app)
    }

    /// The board's selection, removed as one change: one Undo brings them all back, a step inside one that goes isn't counted twice, and the page says what went.
    @Test func severalStepsGoAsOneChange() async throws {
        let w = try World()
        let app = app(w)
        let flow = try make(app, "F", [["id": "a", "text": "1"], ["id": "t", "try": [["id": "in", "text": "2"]], "recover": []], ["id": "c", "text": "3"]])
        #expect(Editing.removable(["in", "t", "nope", "a"], in: flow.draft) == ["a", "t"], "in the flow's order, without one inside another that goes")
        try await page(app, ["op": "remove", "flow": flow.id, "steps": ["a", "t", "in"]])
        let after = try #require(app.store.flow(flow.id))
        #expect(after.draft.allSteps.map(\.id) == ["c"])
        let words = "\(Pages.flowPage(after, app, state: Arguments([:])))"
        #expect(words.contains(L(one: "Removed {count} step, and {inner} inside it. ⌘Z brings them back.", other: "Removed {count} steps, and {inner} inside them. ⌘Z brings them back.", count: 2, ["inner": "1"])))
        try await page(app, ["op": "undo", "flow": flow.id])
        #expect(app.store.flow(flow.id)?.draft == flow.draft, "one Undo, all of them back")
        // The builder's board offers the selection's hook, to the same op, under "steps".
        #expect(Pages.tree(after, app, problems: []).removeMany?.key == "steps")
        // One card, as before.
        try await page(app, ["op": "remove", "flow": flow.id, "step": "c"])
        #expect(app.store.flow(flow.id)?.draft.allSteps.map(\.id).contains("c") == false)
    }

    /// Each flow's card on Your flows has Delete in its menu: it asks the same question, naming the flow, without opening it.
    @Test func aFlowCardCanBeDeletedFromItsMenu() async throws {
        let w = try World()
        let app = app(w)
        let flow = try make(app, "Leftover", [["id": "a", "text": "1"]])
        #expect("\(Pages.card(flow, app))".contains("ask_delete"))
        try await page(app, ["op": "ask_delete", "flow": flow.id])
        #expect(app.nav.askingToDelete && app.nav.pickingFlows == [flow.id])
        let asking = "\(Pages.homePage(app, state: Arguments([:])))"
        #expect(asking.contains("Leftover") && asking.contains(L("History keeps its record of what they did.")))
    }

    /// Every bar on these pages holds no more buttons than Sidefolk draws: Delete, on the page that picks flows, is one of them.
    @Test func barsKeepToWhatSidefolkDraws() async throws {
        let w = try World()
        let app = app(w)
        let flow = try make(app, "Deep", [["id": "a", "if": ["value": "1", "test": "is", "than": "1"], "then": [
            ["id": "b", "if": ["value": "1", "test": "is", "than": "1"], "then": [
                ["id": "c", "if": ["value": "1", "test": "is", "than": "1"], "then": [
                    ["id": "d", "text": "deep"]], "else": []]], "else": []]], "else": []]])
        _ = try make(app, "Other", [["id": "a", "text": "1"]])
        func bars(_ page: Page) -> [PageBar] {
            page.sections.flatMap { $0.blocks.compactMap { if case .bar(let bar) = $0 { bar } else { nil } } }
        }
        func fits(_ page: Page, _ why: Comment) { #expect(!bars(page).isEmpty && bars(page).allSatisfy { $0.actions.count <= Pages.barButtons }, why) }
        fits(Pages.homePage(app, state: Arguments([:])), "Your flows")
        try await page(app, ["op": "pick_flows"])
        try await page(app, ["op": "pick_state", "value": "draft"])
        let picking = Pages.homePage(app, state: Arguments([:]))
        fits(picking, "picking")
        #expect(bars(picking).contains { $0.actions.contains { $0.input["op"] as? String == "pick_delete" } })
        try await page(app, ["op": "pick_delete"])
        fits(Pages.homePage(app, state: Arguments([:])), "asking")
        try await page(app, ["op": "pick_none"])
        try await page(app, ["op": "focus", "flow": flow.id, "step": "d"])
        fits(Pages.flowPage(try #require(app.store.flow(flow.id)), app, state: Arguments([:])), "focused under three holders")
    }

    /// Picking by state, and the shortcut for old drafts that never ran: only those, and the question still comes first.
    @Test func pickingByStateAndOldDrafts() async throws {
        let w = try World()
        let app = app(w)
        let a = try make(app, "A", [["id": "a", "text": "1"]])
        let b = try make(app, "B", [["id": "a", "text": "1"]])
        var on = try make(app, "On", [["id": "a", "text": "1"]])
        on.live = on.draft
        on.state = .on
        app.store.save(on)
        try await page(app, ["op": "pick_flows"])
        try await page(app, ["op": "pick_state", "value": "draft"])
        #expect(app.nav.pickingFlows == [a.id, b.id])
        try await page(app, ["op": "pick_none"])
        #expect(Pages.oldDrafts(app).isEmpty, "touched today")
        let was = Pages.oldAfter
        Pages.oldAfter = -1
        defer { Pages.oldAfter = was }
        #expect(Set(Pages.oldDrafts(app).map(\.id)) == [a.id, b.id], "drafts only, the On one isn't")
        #expect("\(Pages.homePage(app, state: Arguments([:])))".contains("pick_old"))
        try await page(app, ["op": "pick_old"])
        #expect(app.nav.askingToDelete && app.nav.pickingFlows == [a.id, b.id], "it asks; nothing is gone yet")
        #expect(app.store.flow(a.id) != nil)
    }
}
