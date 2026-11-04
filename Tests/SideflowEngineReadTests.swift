import Foundation
import Testing
@testable import ext_sideflow
import SidefolkExtensionKit

/// What the engine's first reads found: what a run may not decide on nothing, and what a page may not offer and then lose.
@MainActor @Suite(.serialized) struct SideflowEngineReadTests {
    typealias World = SideflowTests.World

    private func app(_ w: World) -> App {
        let app = App(folder: w.folder.appendingPathComponent("app"))
        app.engine.host = w.host
        app.catalog.use(Actions.Listing(tools: [Actions.Tool(name: "reads.it", title: "Read it", schema: #"{"properties":{"n":{"type":"number"}}}"#, mutates: false, readsOnly: true)]))
        return app
    }

    private func make(_ app: App, _ steps: [[String: Any]], name: String = "F") throws -> Flow {
        app.newFlow(name: name, body: try FlowCodec.body(["trigger": ["type": "manual"], "steps": steps]))
    }

    private func page(_ app: App, _ op: String, _ flow: Flow, _ extra: [String: Any] = [:]) async throws {
        var input: [String: Any] = ["op": op, "flow": flow.id]
        input.merge(extra) { _, new in new }
        _ = try await Actions_UI.handle(Arguments(input), app)
    }

    private func drawn(_ sections: [Section]) -> String { sections.map { "\($0)" }.joined(separator: "\n") }

    // MARK: A run

    private func deciding(_ reply: String, _ test: String, than: String = "", field: String = "errors") async throws -> (Run?, World) {
        let w = try World()
        w.host.answers["reads.it"] = [Actions.Outcome(status: .ok, text: reply, summary: "")]
        let flow = try w.flow([["id": "check", "do": "reads.it"],
                               ["id": "b", "if": ["value": "{{check.\(field)}}", "test": test, "than": than], "then": [["id": "deploy", "do": "changes.it", "with": ["text": "x"]]]]])
        return (await w.settled(w.engine.start(flow, mode: .live, why: "t")), w)
    }

    @Test(arguments: ["is_empty", "not_empty", "contains", "is", "is_not", "not_contains", "more_than"])
    func wordsHaveNoFieldsToLookIn(_ test: String) async throws {
        let (run, w) = try await deciding("Service unavailable", test, than: "1")
        #expect(run?.status == .failed, "“Service unavailable” isn't a reply saying there are no errors")
        #expect(!w.host.calls.contains { $0.tool == "changes.it" })
    }

    @Test(arguments: [("is_not", "no"), ("not_contains", "bad")])
    func aFieldThatIsntThereIsntPassedByAskingWhatItIsnt(_ test: (String, String)) async throws {
        let (run, w) = try await deciding(#"{"ok":true}"#, test.0, than: test.1)
        #expect(run?.status == .failed)
        #expect(!w.host.calls.contains { $0.tool == "changes.it" })
    }

    @Test func aRecordsAbsentFieldIsEmpty() async throws {
        let empty = try await deciding(#"{"ok":true}"#, "is_empty")
        #expect(empty.0?.status == .done)
        #expect(empty.1.host.calls.contains { $0.tool == "changes.it" }, "no errors in a record is no errors")
        let notEmpty = try await deciding(#"{"ok":true}"#, "not_empty")
        #expect(notEmpty.0?.status == .done)
        #expect(!notEmpty.1.host.calls.contains { $0.tool == "changes.it" })
    }

    @Test func aFieldInWhatAToolAnsweredCanBeRead() async throws {
        let (run, w) = try await deciding(#"{"late":"yes"}"#, "is", than: "yes", field: "late")
        #expect(run?.status == .done)
        #expect(w.host.calls.contains { $0.tool == "changes.it" }, "the same live as with a sample in a practice")
    }

    @Test func aStepThatCarriedOnGaveNothingToLookIn() async throws {
        let w = try World()
        w.host.answers["reads.it"] = [Actions.Outcome(status: .error, text: "broken", summary: "")]
        let flow = try w.flow([["id": "fetch", "do": "reads.it", "on_failure": "carry_on"],
                               ["id": "b", "if": ["value": "{{fetch.status}}", "test": "is_empty"], "then": [["id": "t", "text": "it didn't work"]]],
                               ["id": "m", "if": ["value": "{{fetch.score}}", "test": "more_than", "than": "5"], "then": [["id": "u", "text": "high"]]]])
        let run = await w.settled(w.engine.start(flow, mode: .live, why: "t"))
        #expect(run?.status == .done, "carrying on isn't undone by the next condition")
        #expect(run?.record(of: "t") != nil)
        #expect(run?.record(of: "u") == nil)
    }

    @Test func oneCheckCanAnswerForAll() async throws {
        let w = try World()
        let flow = try w.flow([["id": "a", "text": "yes"], ["id": "r", "text": "words"],
                               ["id": "any", "if": ["value": "{{a}}", "test": "contains", "than": "yes", "or": [["value": "{{r.field}}", "test": "is_not", "than": "z"]]], "then": [["id": "t", "text": "x"]]],
                               ["id": "all", "if": ["value": "{{a}}", "test": "is", "than": "no", "and": [["value": "{{r.field}}", "test": "is", "than": "z"]]], "then": [["id": "u", "text": "x"]]]])
        let run = await w.settled(w.engine.start(flow, mode: .live, why: "t"))
        #expect(run?.status == .done, "the first holding settles an “or”, the first failing settles an “and”")
        #expect(run?.record(of: "t") != nil)
        #expect(run?.record(of: "u") == nil)
    }

    @Test func anItemWithoutAFieldGoesTheOtherWay() async throws {
        let w = try World()
        let flow = try w.flow([["id": "r", "data": ["op": "parse_json", "from": #"[{"email":"a@b"},{"name":"c"}]"#]],
                               ["id": "e", "for_each": "{{r}}", "steps": [["id": "b", "if": ["value": "{{item.email}}", "test": "not_empty"], "then": [["id": "t", "text": "{{item.email}}"]]]]],
                               ["id": "first", "if": ["value": "{{r[9]}}", "test": "not_empty"], "then": [["id": "u", "text": "x"]]]])
        let run = await w.settled(w.engine.start(flow, mode: .live, why: "t"))
        #expect(run?.status == .done)
    }

    @Test func carryingOnFromAConditionSkipsBothWays() async throws {
        let w = try World()
        let flow = try w.flow([["id": "r", "text": "words"],
                               ["id": "b", "on_failure": "carry_on", "if": ["value": "{{r.field}}", "test": "is", "than": "z"], "then": [["id": "yes", "do": "changes.it", "with": ["text": "x"]]], "else": [["id": "no", "do": "changes.it", "with": ["text": "y"]]]],
                               ["id": "after", "text": "z"]])
        let run = await w.settled(w.engine.start(flow, mode: .live, why: "t"))
        #expect(run?.status == .done)
        #expect(!w.host.calls.contains { $0.tool == "changes.it" }, "not knowing which way isn't a way")
        #expect(run?.record(of: "after") != nil)
    }

    @Test func askingWhetherAStepRanStillWorks() async throws {
        let w = try World()
        let flow = try w.flow([["id": "first", "if": ["value": "a", "test": "contains", "than": "b"], "then": [["id": "made", "text": "x"]]],
                               ["id": "b", "if": ["value": "{{made}}", "test": "is_empty"], "then": [["id": "other", "text": "y"]]]])
        let run = await w.settled(w.engine.start(flow, mode: .live, why: "t"))
        #expect(run?.status == .done)
        #expect(run?.record(of: "other") != nil)
    }

    @Test func aPracticeGoesOnPastAFieldThatIsntThereAndSaysSo() async throws {
        let w = try World()
        let flow = try w.flow([["id": "check", "do": "reads.it"],
                               ["id": "b", "if": ["value": "{{check.errors}}", "test": "is_empty"], "then": [["id": "t", "text": "x"]]]], state: .draft)
        w.host.answers["reads.it"] = [Actions.Outcome(status: .ok, text: "plain words", summary: "")]
        let run = await w.settled(w.engine.start(flow, mode: .practice, why: "t"))
        #expect(run?.status == .done, "that's what a practice is for")
        #expect(run?.record(of: "b")?.note != nil)
    }

    @Test func theCardSaysWhoseClockASchedulesOn() async throws {
        let w = try World()
        var flow = try w.flow([["id": "a", "do": "reads.it"]], trigger: ["type": "schedule", "every_minutes": 60], state: .draft)
        flow.draft.timeZone = "Asia/Tokyo"
        w.store.save(flow)
        w.engine.turnOn(flow.id)
        await w.quiet()
        #expect(w.host.plans.last?.when.contains("Asia/Tokyo") == true, "or changing only that asks again with the same words")
    }

    @Test func callingAnOnFlowWithABlankStepPausesItAndRunsNothing() async throws {
        let w = try World()
        var other = try w.flow([["id": "z", "text": "x"]])
        other.name = "Other"
        other.draft = FlowBody(steps: [Step(id: "first", kind: .action(tool: "reads.it", input: [:])), Step(id: "a", kind: .ai(prompt: ""))])
        other.live = other.draft
        w.store.save(other)
        let flow = try w.flow([["id": "c", "call_flow": "Other"]])
        let run = await w.settled(w.engine.start(flow, mode: .live, why: "t"))
        #expect(run?.status == .failed)
        #expect(!w.host.calls.contains { $0.tool == "reads.it" }, "what comes before it doesn't run on every call")
        #expect(w.store.flow(other.id)?.state == .paused)
    }

    private static let blanks: [Step.Kind] = [
        .forEach(items: " ", limit: 10, onFailure: .stop, steps: []),
        .choose(value: "", paths: [Step.Path(when: "x", steps: [])], otherwise: []),
        .data(DataStep(op: .lines, from: "")),
        .form(FormStep(title: "T", fields: [], hours: 1)),
        .form(FormStep(title: "T", fields: [FormStep.Field(name: "a", label: "A", kind: .choice, options: ["only"])], hours: 1)),
    ]

    @Test(arguments: 0..<5) func aBlankOfTheNewKindsDoesntGoOn(_ at: Int) async throws {
        let w = try World()
        var flow = try w.flow([["id": "z", "text": "x"]], state: .paused)
        flow.live = flow.draft
        flow.draft = FlowBody(steps: [Step(id: "a", kind: Self.blanks[at])])
        w.store.save(flow)
        w.engine.turnOn(flow.id)
        await w.quiet()
        #expect(w.store.flow(flow.id)?.state == .paused)
        #expect(w.store.flow(flow.id)?.startProblem != nil)
        #expect(!w.host.plans.contains { $0.id == flow.planId }, "no card for what can't go")
    }

    @Test func aRunOnceThatReachesABlankLoopOrChoiceFails() async throws {
        for kind in [Self.blanks[0], Self.blanks[1]] {
            let w = try World()
            var flow = try w.flow([["id": "z", "text": "x"]], state: .draft)
            flow.draft = FlowBody(steps: [Step(id: "a", kind: kind), Step(id: "after", kind: .action(tool: "changes.it", input: ["text": .string("x")]))])
            w.store.save(flow)
            let run = await w.settled(w.engine.start(flow, mode: .once, why: "t"))
            #expect(run?.status == .failed)
            #expect(w.host.calls.isEmpty)
        }
    }

    @Test func aModelCantWriteABlankOfTheNewKinds() throws {
        let bad: [[String: Any]] = [["id": "a", "for_each": "", "steps": [["id": "b", "text": "x"]]],
                                    ["id": "a", "choose": " ", "paths": [["when": "x", "steps": []]]],
                                    ["id": "a", "data": ["op": "lines", "from": ""]]]
        for step in bad {
            let raw: [String: Any] = ["trigger": ["type": "manual"], "steps": [step]]
            #expect(throws: Problem.self) { try FlowCodec.body(raw) }
            #expect((try? FlowCodec.body(raw, saved: true)) != nil, "and what a page saved reads back")
        }
    }

    // MARK: A page

    @Test func everyDataStepOptionCanBePicked() async throws {
        let w = try World()
        let app = app(w)
        let flow = try make(app, [["id": "z", "text": "x"]])
        try await page(app, "add_kind", flow, ["kind": "data"])
        let now = try #require(app.store.flow(flow.id))
        let id = try #require(now.draft.allSteps.first { if case .data = $0.kind { true } else { false } }?.id)
        app.nav.inspect(.step(id), in: now.id)
        let words = drawn(Inspector.sections(now, app, problems: []))
        #expect(words.contains("menu"), "a plain choice keeps 8, and there are \(DataStep.Op.allCases.count)")
    }

    @Test func aLongLoopsGoesCanAllBeReached() async throws {
        let w = try World()
        let app = app(w)
        let flow = try make(app, [["id": "e", "for_each": "a\nb\nc\nd\ne\nf\ng\nh\ni\nj", "steps": [["id": "t", "text": "got {{item}}"]]]])
        let run = try #require(app.engine.start(flow, mode: .once, why: "t"))
        await w.quiet(app.store)
        let words = drawn(Pages.stepDetail(try #require(app.store.run(run.id)), step: "t", scope: "1", app))
        #expect(words.contains("menu"))
    }

    @Test func lanesWhoseNamesLookAlikeBothKeepTheirResults() {
        let keys = Engine.keys([Step.Lane(name: "First", steps: []), Step.Lane(name: "first!", steps: []), Step.Lane(name: "FIRST", steps: [])])
        #expect(Set(keys).count == 3)
        #expect(keys[0] == "first")
    }

    @Test func aFilterGivenNothingToLookForSaysSo() async throws {
        let w = try World()
        let flow = try w.flow([["id": "t", "text": "apple\npear"], ["id": "l", "data": ["op": "lines", "from": "{{t}}"]], ["id": "d", "data": ["op": "filter", "from": "{{l}}"]]])
        let run = await w.settled(w.engine.start(flow, mode: .live, why: "t"))
        #expect(run?.status == .failed, "rather than an empty list that looks like an answer")
    }

    @Test func aHugeValueInAFormsTitleDoesntStopThePage() async throws {
        let w = try World()
        let app = app(w)
        let long = String(repeating: "x", count: 5000)
        let flow = try make(app, [["id": "t", "text": long], ["id": "f", "form": ["title": "Check {{t}}", "fields": [["name": "n", "label": "N", "kind": "text"]]]]])
        let run = try #require(app.engine.start(flow, mode: .once, why: "t"))
        await w.quiet(app.store)
        let now = try #require(app.store.run(run.id))
        #expect(w.host.notices.allSatisfy { ($0.body?.count ?? 0) < 300 })
        #expect((Pages.formSection(now)?.title?.count ?? 0) < 300)
    }

    @Test func goesPastWhatAMenuHoldsAreSaid() async throws {
        let w = try World()
        let app = app(w)
        let items = (0..<30).map { "i\($0)" }.joined(separator: "\n")
        let flow = try make(app, [["id": "e", "for_each": items, "steps": [["id": "t", "text": "got {{item}}"]]]])
        let run = try #require(app.engine.start(flow, mode: .once, why: "t"))
        await w.quiet(app.store)
        let words = drawn(Pages.stepDetail(try #require(app.store.run(run.id)), step: "t", scope: "1", app))
        #expect(words.contains(L("Only the first {count} goes can be picked here.", ["count": Format.integer(24)])))
    }

    @Test func aChoiceInAFormWithTooFewAnswersIsMarked() throws {
        let w = try World()
        let body = FlowBody(steps: [Step(id: "a", kind: .form(FormStep(title: "T", fields: [FormStep.Field(name: "a", label: "A", kind: .choice, options: ["only"])], hours: 1)))])
        #expect(body.problems(w.catalog).contains { $0.step == "a" })
    }

    @Test func aNewCallIsntToItself() async throws {
        let w = try World()
        let app = app(w)
        let only = try make(app, [["id": "z", "text": "x"]], name: "Only")
        try await page(app, "add_kind", only, ["kind": "call"])
        let added = try #require(app.store.flow(only.id)?.draft.allSteps.compactMap { step -> String? in if case .call(let name, _) = step.kind { name } else { nil } }.first)
        #expect(added.isEmpty)
        #expect(app.store.flow(only.id)?.draft.problems(app.catalog).isEmpty == false, "and it's marked")
        let other = try make(app, [["id": "z", "text": "x"]], name: "Other")
        try await page(app, "add_kind", other, ["kind": "call"])
        let picked = try #require(app.store.flow(other.id)?.draft.allSteps.compactMap { step -> String? in if case .call(let name, _) = step.kind { name } else { nil } }.first)
        #expect(picked == "Only")
    }

    @Test func aFormsTitleSaysWhatItUses() async throws {
        let w = try World()
        let app = app(w)
        let flow = try make(app, [["id": "t", "text": "the draft"], ["id": "f", "form": ["title": "Check {{t}}", "fields": [["name": "n", "label": "N", "kind": "text"]]]]])
        let run = try #require(app.engine.start(flow, mode: .once, why: "t"))
        await w.quiet(app.store)
        #expect(w.host.notices.contains { $0.body == "Check the draft" }, "not its braces")
        let now = try #require(app.store.run(run.id))
        #expect(now.form != nil)
        #expect(drawn(Pages.formSection(now).map { [$0] } ?? []).contains("Check the draft"))
    }

    @Test func aLaneInAnyLanguageCanBeReached() {
        #expect(Engine.key("Première") == "premiere")
        for name in ["第一", "الأول", "첫째", "最初", "Second lane"] {
            let key = Engine.key(name)
            #expect(key.allSatisfy { $0.isASCII }, "the slot pattern is ASCII: \(name) made \(key)")
            #expect(Values.references("{{got.\(key)}}") == ["got"])
        }
    }

    @Test func aRenamedLaneOrARemovedFieldIsMarked() throws {
        let w = try World()
        let lanes = FlowBody(steps: [Step(id: "got", kind: .parallel(lanes: [Step.Lane(name: "First", steps: [Step(id: "a", kind: .text("x"))]), Step.Lane(name: "Second", steps: [Step(id: "b", kind: .text("x"))])])),
                                     Step(id: "t", kind: .text("{{got.third}}")), Step(id: "u", kind: .text("{{got.first}}"))])
        #expect(lanes.problems(w.catalog).contains { $0.step == "t" })
        #expect(!lanes.problems(w.catalog).contains { $0.step == "u" })
        let form = FlowBody(steps: [Step(id: "f", kind: .form(FormStep(title: "T", fields: [FormStep.Field(name: "ok", label: "OK", kind: .text)], hours: 1))),
                                    Step(id: "t", kind: .text("{{f.gone}}")), Step(id: "u", kind: .text("{{f.ok}}"))])
        #expect(form.problems(w.catalog).contains { $0.step == "t" })
        #expect(!form.problems(w.catalog).contains { $0.step == "u" })
    }

    @Test func addingPathsAndLanesStopsAtTheLimitAndNothingBecomesUnreadable() async throws {
        let w = try World()
        let app = app(w)
        let flow = try make(app, [["id": "c", "choose": "x", "paths": [["when": "a", "steps": []]]],
                                  ["id": "p", "parallel": [["name": "A", "steps": [["id": "a", "text": "x"]]], ["name": "B", "steps": [["id": "b", "text": "x"]]]]]])
        for _ in 0..<(FlowBody.mostPaths + 2) { try await page(app, "path_add", flow, ["step": "c"]) }
        for _ in 0..<(FlowBody.mostLanes + 2) { try await page(app, "lane_add", flow, ["step": "p"]) }
        let reread = App(folder: w.folder.appendingPathComponent("app"))
        let back = try #require(reread.store.flow(flow.id), "still there at the next launch")
        if case .choose(_, let paths, _)? = back.draft.step("c")?.kind { #expect(paths.count == FlowBody.mostPaths) } else { Issue.record("not a choice") }
        if case .parallel(let lanes)? = back.draft.step("p")?.kind { #expect(lanes.count == FlowBody.mostLanes) } else { Issue.record("not lanes") }
        // Past either, from however it got there, it still reads: a page never loses a flow.
        let many = (0...FlowBody.mostPaths).map { ["when": "w\($0)", "steps": []] as [String: Any] }
        #expect((try? FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "c", "choose": "x", "paths": many]]], saved: true)) != nil)
    }

    @Test func pretendingIsOfferedOnlyWhereAPracticeUsesIt() async throws {
        let w = try World()
        let app = app(w)
        let flow = try make(app, [["id": "r", "do": "reads.it"], ["id": "t", "ai": "words"]])
        app.nav.inspect(.step("t"), in: flow.id)
        #expect(!drawn(Inspector.sections(flow, app, problems: [])).contains(L("In practice, pretend it gives")))
        app.nav.inspect(.step("r"), in: flow.id)
        #expect(drawn(Inspector.sections(flow, app, problems: [])).contains(L("In practice, pretend it gives")))
    }

    @Test func aVersionBroughtBackIsUnsavedAndChangesNothingThatsRunning() async throws {
        let w = try World()
        let app = app(w)
        var flow = try make(app, [["id": "a", "text": "second"]])
        let second = flow.draft
        let first = FlowBody(steps: [Step(id: "a", kind: .text("first"))])
        flow.live = second
        flow.state = .on
        flow.revisions = [Flow.Revision(at: Date(), body: first)]
        app.store.save(flow)
        try await page(app, "bring_back", flow, ["revision": 0])
        let back = try #require(app.store.flow(flow.id))
        #expect(back.draft == first)
        #expect(back.hasUnsaved)
        #expect(back.live == second, "it's something to read until it's applied")
        try await page(app, "undo", flow)
        #expect(app.store.flow(flow.id)?.draft == second)
    }

    @Test func whatChangedSaysTheClockTheOverlapAndTheSample() throws {
        let w = try World()
        let old = FlowBody(steps: [Step(id: "a", kind: .text("x"))])
        var zone = old
        zone.timeZone = "Asia/Tokyo"
        #expect(!Editing.changes(from: old, to: zone, catalog: w.catalog).isEmpty)
        var overlap = old
        overlap.overlap = .queue
        #expect(!Editing.changes(from: old, to: overlap, catalog: w.catalog).isEmpty)
        var sample = old
        sample.triggerSample = "words"
        #expect(!Editing.changes(from: old, to: sample, catalog: w.catalog).isEmpty)
    }

    @Test func aFilterWithNoTestPickedDoesWhatThePageShows() async throws {
        let w = try World()
        let flow = try w.flow([["id": "t", "text": "apple\npear"], ["id": "l", "data": ["op": "lines", "from": "{{t}}"]], ["id": "d", "data": ["op": "filter", "from": "{{l}}", "than": "app"]]])
        let run = await w.settled(w.engine.start(flow, mode: .live, why: "t"))
        #expect(run?.status == .done, "the page shows “mentions” selected")
    }

    @Test func saveAndDiscardStayWhileARunWaits() async throws {
        let w = try World()
        let app = app(w)
        var flow = try make(app, [["id": "w", "wait_minutes": 30], ["id": "t", "text": "one"]])
        flow.live = flow.draft
        flow.state = .on
        app.store.save(flow)
        let run = try #require(app.engine.start(flow, mode: .live, why: "t"))
        await w.quiet(app.store)
        #expect(app.store.run(run.id)?.status == .waiting)
        try await page(app, "compose", flow, ["step": "t", "text": "two"])
        let bar = "\(Pages.head(try #require(app.store.flow(flow.id)), app, ready: true))"
        #expect(bar.contains(L("Discard")))
        #expect(bar.contains(L("Unsaved changes")))
    }
}
