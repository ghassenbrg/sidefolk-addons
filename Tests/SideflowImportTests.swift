import Foundation
import Testing
@testable import ext_sideflow
import SidefolkExtensionKit

/// A flow from a file: read, shown in plain words, and brought in only on the page's own yes, always as a draft and off.
@MainActor @Suite(.serialized) struct SideflowImportTests {
    typealias World = SideflowTests.World

    private func app(_ w: World) -> App {
        let app = App(folder: w.folder.appendingPathComponent("app"))
        app.engine.host = w.host
        return app
    }

    private let simple: [String: Any] = ["trigger": ["type": "manual"], "steps": [["id": "a", "text": "hello"]]]

    private func file(_ flows: [[String: Any]]) -> String { JSONText.write(["sideflow": 1, "flows": flows] as [String: Any]) }

    @Test func aFileComesBackAsTheSameFlowsAndNoApprovalComesWithIt() throws {
        let w = try World()
        let app = app(w)
        let called = app.newFlow(name: "Called", body: try FlowCodec.body(simple))
        var flow = app.newFlow(name: "Caller", body: try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "s", "sample": "my own words", "text": "x"], ["id": "c", "call_flow": "Called"]]]))
        flow.state = .on
        flow.live = flow.draft
        let written = FlowFile.write([flow], store: app.store, catalog: app.catalog, sideflow: "1.0.0")
        #expect(!written.contains("my own words"), "a sample can be the person's own")
        #expect(!written.contains("\"state\"") && !written.contains("\"live\""), "no approval or state")
        let back = try FlowFile.read(written)
        #expect(back.map(\.name) == ["Caller", "Called"], "what it calls comes with it")
        #expect(back[1].body == called.kept)
        #expect(back[0].body.step("s")?.sample == nil)
        guard case .call(let name, _)? = back[0].body.step("c")?.kind else { Issue.record("not a call"); return }
        #expect(name == "Called")
    }

    @Test func whatItDoesntKnowIsRefusedNotGuessedAt() throws {
        for bad in ["not json", "[]", #"{"sideflow": 99, "flows": []}"#, #"{"sideflow": 1, "flows": []}"#, #"{"sideflow": "1", "flows": []}"#,
                    #"{"sideflow": 1, "flows": [], "approved": true}"#,
                    file([["name": "A", "flow": simple, "state": "on"]]),
                    file([["name": "A", "flow": ["trigger": ["type": "from_the_future"], "steps": []]]]),
                    file([["name": "A", "flow": ["trigger": ["type": "manual"], "steps": [["id": "a", "teleport": "x"]]]]]),
                    file([["flow": simple]]), file([["name": "\u{202E}\u{200B}", "flow": simple]]),
                    file([["name": "A", "flow": simple], ["name": "a", "flow": simple]]),
                    file((0...FlowFile.mostFlows).map { ["name": "F\($0)", "flow": simple] }),
                    String(repeating: " ", count: FlowFile.longest + 1)] {
            #expect(throws: Problem.self, "\(bad.prefix(60))") { try FlowFile.read(bad) }
        }
    }

    @Test func aDefinitionCopiedFromAFlowStillReads() throws {
        #expect(try FlowFile.read(JSONText.write(["name": "Old", "flow": simple] as [String: Any])).map(\.name) == ["Old"])
    }

    @Test func aNameThatsTakenMakesACopyAndCallsInTheFileFollow() throws {
        let w = try World()
        let app = app(w)
        _ = app.newFlow(name: "Helper", body: try FlowCodec.body(simple))
        let arriving = FlowFile.arriving(try FlowFile.read(file([
            ["name": "Main", "flow": ["trigger": ["type": "manual"], "steps": [["id": "c", "call_flow": "Helper"]]]],
            ["name": "Helper", "flow": simple],
        ])), store: app.store)
        #expect(arriving.map(\.name) == ["Main", "Helper (imported)"])
        guard case .call(let name, _)? = arriving[0].body.step("c")?.kind else { Issue.record("not a call"); return }
        #expect(name == "Helper (imported)")
        #expect(app.store.named("Helper") != nil, "never overwritten")
    }

    @Test func itSaysWhatItDoesWithTheCautiousWordsForAnythingUnknown() throws {
        let w = try World()
        let app = app(w)
        let survey = FlowFile.survey(try FlowFile.read(file([["name": "S", "flow": ["trigger": ["type": "manual"], "steps": [
            ["id": "gone", "do": "no.such.tool"], ["id": "ai", "ai": "x"], ["id": "c", "call_flow": "Nowhere"], ["id": "j", "do": "companion.job", "with": ["job": "x"]],
        ]]]])), store: app.store, catalog: app.catalog)[0]
        #expect(survey.missingTools == ["no.such.tool"])
        #expect(survey.usesAI == 1)
        #expect(survey.companionJobs == 1)
        #expect(survey.setsOff == ["Nowhere"] && survey.missingFlows == ["Nowhere"])
    }

    @Test func nothingComesInWithoutThePagesOwnYesAndThenAsADraftAndOff() async throws {
        let w = try World()
        let app = app(w)
        let left = try await Actions_UI.handle(Arguments(["op": "import", "text": file([["name": "New", "flow": simple]])]), app)
        guard case .importing(let id) = left else { Issue.record("it should stop to show it: \(left)"); return }
        #expect(app.store.flows().isEmpty, "only read")
        let page = String(describing: await Pages.make(app, state: Arguments(["import": id]), background: false)).filter { !"\u{2068}\u{2069}\\".contains($0) }
        #expect(page.contains("Bring this in?") && page.contains("New") && page.contains("It only works with words"))
        _ = try await Actions_UI.handle(Arguments(["op": "import_confirm", "id": id]), app)
        _ = try await Actions_UI.handle(Arguments(["op": "import_confirm", "id": id, "page_token": "guess"]), app)
        #expect(app.store.flows().isEmpty, "another extension can call ui, but can't read the page's token")
        _ = try await Actions_UI.handle(Arguments(["op": "import_confirm", "id": id, "page_token": app.pageKey]), app)
        let made = try #require(app.store.flows().first)
        #expect(made.name == "New" && made.state == .draft && made.live == nil)
        #expect(FlowFile.staged(id, in: app.folder) == nil)
        _ = try await Actions_UI.handle(Arguments(["op": "import_confirm", "id": id, "page_token": app.pageKey]), app)
        #expect(app.store.flows().count == 1, "a second press brings nothing")
    }

    @Test func notNowLeavesNothingBehind() async throws {
        let w = try World()
        let app = app(w)
        guard case .importing(let id) = try await Actions_UI.handle(Arguments(["op": "import", "text": file([["name": "New", "flow": simple]])]), app) else { Issue.record("no"); return }
        _ = try await Actions_UI.handle(Arguments(["op": "import_cancel", "id": id]), app)
        #expect(FlowFile.staged(id, in: app.folder) == nil && app.store.flows().isEmpty)
    }

    @Test func aStagedNameCantWalkOutOfItsFolder() throws {
        let w = try World()
        let app = app(w)
        #expect(FlowFile.staged("../flows.json", in: app.folder) == nil)
    }
}
