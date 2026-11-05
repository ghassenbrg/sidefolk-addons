import Foundation
import Testing
@testable import ext_sideflow
@testable import SidefolkExtensionKit

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

    @Test func aFileThatSaysOneThingTwiceIsntRead() {
        #expect(throws: Problem.self) { try FlowFile.read(#"{"sideflow": 1, "flows": [{"name": "A", "name": "B", "flow": {"trigger": {"type": "manual"}, "steps": [{"id": "a", "text": "x"}]}}]}"#) }
    }

    @Test func aDefinitionCopiedFromAFlowStillReads() throws {
        #expect(try FlowFile.read(JSONText.write(["name": "Old", "flow": simple] as [String: Any])).map(\.name) == ["Old"])
    }

    @Test func aDefinitionOnItsOwnCanLeaveItsNameOutButNotInAFile() throws {
        #expect(try FlowFile.read(JSONText.write(["flow": simple] as [String: Any])).map(\.name) == ["New flow"])
        #expect(throws: Problem.self) { try FlowFile.read(file([["flow": simple]])) }
    }

    @Test func aNameIsTakenAsItIsOrNotAtAll() {
        for name in [String(repeating: "x", count: 61), "A\u{00A0}B", "A\u{200B}B", "A\nB", "a" + String(repeating: "\u{0301}", count: 25_000)] {
            #expect(throws: Problem.self, "\(name)") { try FlowFile.read(file([["name": name, "flow": simple]])) }
        }
        #expect(throws: Problem.self, "the same to a step") { try FlowFile.read(file([["name": "Résumé", "flow": simple], ["name": "resume", "flow": simple]])) }
    }

    @Test func aLongNameTakenAgainAndAgainStillFindsOne() throws {
        let w = try World()
        let app = app(w)
        let long = String(repeating: "x", count: 60)
        _ = app.newFlow(name: long, body: try FlowCodec.body(simple))
        for _ in 0..<3 {
            let name = FlowFile.arriving(try FlowFile.read(file([["name": long, "flow": simple]])), store: app.store)[0].name
            #expect(name.count <= 60 && !app.store.nameInUse(name), "\(name)")
            _ = app.newFlow(name: name, body: try FlowCodec.body(simple))
        }
    }

    @Test func aPracticesMadeUpAnswersDontComeWithIt() throws {
        let back = try FlowFile.read(file([["name": "A", "flow": ["trigger": ["type": "manual"], "trigger_sample": "x", "steps": [["id": "a", "text": "t", "sample": "y"]]]]]))[0].body
        #expect(back.triggerSample == nil && back.step("a")?.sample == nil)
    }

    @Test func thePageNeverSaysLessThanItDoes() async throws {
        let w = try World()
        let app = app(w)
        let watching: [String: Any] = ["trigger": ["type": "watch", "kind": "url_change", "target": "https://example.com/pixel"], "steps": [["id": "a", "text": "x"]]]
        let page = try FlowFile.survey(try FlowFile.read(file([["name": "W", "flow": watching]])), store: app.store, catalog: app.catalog)[0]
        #expect(page.watches == ["https://example.com/pixel"])
        _ = app.newFlow(name: "Pay invoices", body: try FlowCodec.body(simple))
        let long: [String: Any] = ["trigger": ["type": "manual"], "steps": [["id": "s", "run_flow": String(repeating: "x", count: 400)], ["id": "p", "call_flow": "Pay invoices"]]]
        let id = try FlowFile.stage(file([["name": "L", "flow": long]]), in: app.folder)
        let words = String(describing: await Pages.make(app, state: Arguments(["import": id]), background: false)).filter { !"\u{2068}\u{2069}\\".contains($0) }
        #expect(words.contains("It sets off a flow of yours: Pay invoices"), "what's the person's own is said, and a long name can't push it off")
    }

    @Test func whereAStepGoesIsSaidAndWhatsCutSaysSo() throws {
        let w = try World()
        let app = app(w)
        let long = "https://www.apple.com." + String(repeating: "pad.", count: 80) + "evil.example/"
        let survey = FlowFile.survey(try FlowFile.read(file([["name": "S", "flow": ["trigger": ["type": "watch", "kind": "url_change", "target": long], "steps": [["id": "c", "call_flow": " S "]]]]])), store: app.store, catalog: app.catalog)[0]
        #expect(survey.watches[0].hasSuffix("…") && survey.starts[0].hasSuffix("…"))
        #expect(survey.setsOff == [" S ".trimmingCharacters(in: .whitespaces)] && survey.missingFlows.isEmpty, "the file's own, as it runs")
        #expect(FlowFile.short("a" + String(repeating: "\u{0301}", count: 70_000), 60).unicodeScalars.count <= 61)
    }

    @Test func aPageOfEscapesStaysAPage() async throws {
        let w = try World()
        let app = app(w)
        let many: [[String: Any]] = (0..<FlowFile.mostFlows).map { flow in
            ["name": "F\(flow)", "flow": ["trigger": ["type": "manual"], "steps": (0..<30).map { ["id": "s\($0)", "do": String(repeating: "\"", count: 110) + "\(flow).\($0)"] }] as [String: Any]]
        }
        let id = try FlowFile.stage(file(many), in: app.folder)
        let page = await Pages.make(app, state: Arguments(["import": id]), background: false)
        #expect(JSONText.write(page.json).utf8.count < 128_000)
    }

    @Test func aPageOfLongNamesStaysAPageAndSaysThereIsMore() async throws {
        let w = try World()
        let app = app(w)
        let many: [[String: Any]] = (0..<FlowFile.mostFlows).map { flow in
            ["name": "F\(flow)", "flow": ["trigger": ["type": "manual"], "steps": (0..<80).map { ["id": "s\($0)", "do": "x.\(flow).\($0)." + String(repeating: "界", count: 50)] }] as [String: Any]]
        }
        let id = try FlowFile.stage(file(many), in: app.folder)
        let page = await Pages.make(app, state: Arguments(["import": id]), background: false)
        let words = String(describing: page).filter { !"\u{2068}\u{2069}\\".contains($0) }
        #expect(words.contains("more than this page can show"))
    }

    @Test func goingElsewhereLeavesItBehind() {
        #expect(Pages.place(["flow": "x"])["import"] is NSNull)
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
        #expect(survey.missingFlows == ["Nowhere"] && survey.setsOff.isEmpty)
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
