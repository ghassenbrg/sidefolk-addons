import Foundation
import Testing
@testable import ext_sideflow
import SidefolkExtensionKit

/// A flow's name is the first thing on its own panel, one press from anywhere on its page.
@MainActor @Suite(.serialized) struct SideflowRenameTests {
    typealias World = SideflowTests.World

    private func app(_ w: World) -> App {
        let app = App(folder: w.folder.appendingPathComponent("app"))
        app.engine.host = w.host
        return app
    }

    private func flow(_ app: App, _ name: String = "Morning") throws -> Flow {
        app.newFlow(name: name, body: try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "a", "text": "1"]]]))
    }

    private func page(_ app: App, _ flow: Flow, tab: String = "builder") async -> String {
        String(describing: await Pages.make(app, state: Arguments(["flow": flow.id, "tab": tab]), background: false)).filter { !"\u{2068}\u{2069}\\".contains($0) }
    }

    @Test func itsNameIsOnTheFlowsOwnPanel() async throws {
        let w = try World()
        let app = app(w)
        let f = try flow(app)
        #expect(await page(app, f).contains("This flow's name"))
    }

    @Test func theMenuOffersItOnEveryTabAndComesBackToIt() async throws {
        let w = try World()
        let app = app(w)
        let f = try flow(app)
        for tab in ["builder", "runs", "activity"] { #expect(await page(app, f, tab: tab).contains("Rename"), "\(tab)") }
        app.nav.inspect(.step("a"), in: f.id)
        #expect(await !page(app, f).contains("This flow's name"), "a step's panel is the step's")
        let left = try await Actions_UI.handle(Arguments(["op": "rename_open", "flow": f.id]), app)
        #expect(app.nav.inspecting(f) == .nothing)
        guard case .panel(f.id) = left else { Issue.record("it has to leave the tab it's on: \(left)"); return }
        #expect(await page(app, f).contains("This flow's name"))
    }

    @Test func aLongChoiceIsAMenuSoItCantPushThePanelOff() throws {
        let long = [("stop", "Stop the flow"), ("carry_on", "Carry on"), ("retry", "Try again later")]
        guard case .picker = Inspector.pick("If it fails", options: long, selected: "stop", tool: "ui", input: [:]) else { Issue.record("still a row"); return }
        guard case .choice = Inspector.pick("Level", options: [("g", "gentle"), ("a", "attention")], selected: "g", tool: "ui", input: [:]) else { Issue.record("short ones stay a row"); return }
        guard case .picker = Inspector.pick("X", options: [("a", "停止する流れです"), ("b", "続ける流れです"), ("c", "もう一度試します")], selected: "a", tool: "ui", input: [:]) else { Issue.record("wide letters count"); return }
    }

    @Test func movingAsksForAPlaceRatherThanSayingItsNameTwice() async throws {
        let w = try World()
        let app = app(w)
        let f = app.newFlow(name: "M", body: try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "a", "text": "1"], ["id": "b", "text": "2"], ["id": "c", "text": "3"]]]))
        app.nav.inspect(.step("b"), in: f.id)
        #expect(String(describing: Inspector.sections(try #require(app.store.flow(f.id)), app, problems: [])).contains("Choose a place"))
        _ = try await Actions_UI.handle(Arguments(["op": "move_after", "flow": f.id, "step": "b", "value": "b"]), app)
        #expect(app.store.flow(f.id)?.draft.steps.map(\.id) == ["a", "b", "c"], "the prompt moves nothing")
    }

    @Test func aNewNameIsKeptAndWhatCallsItFollows() async throws {
        let w = try World()
        let app = app(w)
        let f = try flow(app)
        let caller = app.newFlow(name: "Caller", body: try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "c", "call_flow": "Morning"]]]))
        _ = try await Actions_UI.handle(Arguments(["op": "rename", "flow": f.id, "text": "Dawn"]), app)
        #expect(app.store.flow(f.id)?.name == "Dawn")
        guard case .call(let name, _)? = app.store.flow(caller.id)?.draft.step("c")?.kind else { Issue.record("not a call"); return }
        #expect(name == "Dawn")
    }

    @Test func aNameThatsTakenIsSaidAndChangesNothing() async throws {
        let w = try World()
        let app = app(w)
        let f = try flow(app)
        _ = try flow(app, "Taken")
        await #expect(throws: Problem.self) { _ = try await Actions_UI.handle(Arguments(["op": "rename", "flow": f.id, "text": "Taken"]), app) }
        #expect(app.store.flow(f.id)?.name == "Morning")
    }
}
