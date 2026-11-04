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
                               ["id": "b", "if": ["value": field.isEmpty ? "{{check}}" : "{{check.\(field)}}", "test": test, "than": than], "then": [["id": "deploy", "do": "changes.it", "with": ["text": "x"]]]]])
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
        #expect(run?.records.filter { $0.step == "t" }.count == 1, "only the one with an address")
        #expect(run?.record(of: "u") == nil)
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

    @Test func aToolsWordsStayAsItSaidThem() async throws {
        let w = try World()
        let said = #"{"status": "ok", "b": 10.0, "a": 12345678901234567}"#
        w.host.answers["reads.it"] = [Actions.Outcome(status: .ok, text: said, summary: "")]
        let flow = try w.flow([["id": "r", "do": "reads.it"],
                               ["id": "b", "if": ["value": "{{r}}", "test": "contains", "than": #""status": "ok""#], "then": [["id": "t", "text": "{{r}}"]]],
                               ["id": "u", "text": "{{r.status}}"]])
        let run = await w.settled(w.engine.start(flow, mode: .live, why: "t"))
        #expect(run?.status == .done)
        #expect(run?.record(of: "t")?.output == said, "looking inside doesn't rewrite it")
        #expect(run?.record(of: "u")?.output == "ok")
    }

    @Test func aToolsListAnswerGoesRoundAndWorksWithData() async throws {
        let w = try World()
        w.host.answers["reads.it"] = [Actions.Outcome(status: .ok, text: #"[{"n":"a"},{"n":"b"}]"#, summary: "")]
        let flow = try w.flow([["id": "r", "do": "reads.it"],
                               ["id": "e", "for_each": "{{r}}", "steps": [["id": "t", "text": "got {{item.n}}"]]],
                               ["id": "d", "data": ["op": "count", "from": "{{r}}"]]])
        let run = await w.settled(w.engine.start(flow, mode: .live, why: "t"))
        #expect(run?.status == .done, "the same as with a sample in a practice")
        #expect(run?.records.filter { $0.step == "t" }.count == 2)
        #expect(run?.record(of: "d")?.output == "2")
    }

    @Test(arguments: [#"{"data":"Service unavailable"}"#, #"{"data":["down"]}"#])
    func wordsDeeperDownHaveNoFieldsEither(_ reply: String) async throws {
        let (run, w) = try await deciding(reply, "is_empty", field: reply.contains("[") ? "data[0].errors" : "data.errors")
        #expect(run?.status == .failed)
        #expect(!w.host.calls.contains { $0.tool == "changes.it" })
    }

    @Test(arguments: ["is_not", "not_contains"])
    func whatGaveNothingIsntPassedByAskingWhatItIsnt(_ test: String) async throws {
        let w = try World()
        w.host.answers["reads.it"] = [Actions.Outcome(status: .error, text: "broken", summary: "")]
        let flow = try w.flow([["id": "fetch", "do": "reads.it", "on_failure": "carry_on"],
                               ["id": "b", "if": ["value": "{{fetch}}", "test": test, "than": "down"], "then": [["id": "go", "do": "changes.it", "with": ["text": "x"]]]]])
        let run = await w.settled(w.engine.start(flow, mode: .live, why: "t"))
        #expect(run?.status == .failed)
        #expect(!w.host.calls.contains { $0.tool == "changes.it" })
    }

    @Test func whatATestIgnoresDoesntStopIt() async throws {
        let w = try World()
        let flow = try w.flow([["id": "r", "text": "words"],
                               ["id": "b", "if": ["value": "{{r}}", "test": "not_empty", "than": "{{r.left_over}}"], "then": [["id": "t", "text": "x"]]]])
        let run = await w.settled(w.engine.start(flow, mode: .live, why: "t"))
        #expect(run?.status == .done)
        #expect(run?.record(of: "t") != nil)
    }

    @Test func aNewAddressApprovedWhileAWatchIsBeingMadeEndsWithIt() async throws {
        let w = try World()
        let x: [String: Any] = ["type": "watch", "kind": "url_change", "target": "https://x.example"]
        let y: [String: Any] = ["type": "watch", "kind": "url_change", "target": "https://y.example"]
        let flow = try w.flow([["id": "a", "do": "reads.it"]], trigger: x, state: .draft)
        w.host.hold = "watch.create"
        w.host.honoursCancel = true
        w.host.releaseQuietly = true
        w.engine.turnOn(flow.id)
        for _ in 0..<200 where !w.host.calls.contains(where: { $0.tool == "watch.create" }) { try await Task.sleep(for: .milliseconds(5)) }
        var moved = try #require(w.store.flow(flow.id))
        moved.draft = try FlowCodec.body(["trigger": y, "steps": [["id": "a", "do": "reads.it"]]])
        w.store.save(moved)
        w.engine.turnOn(flow.id)
        for _ in 0..<40 { await Task.yield() }
        w.host.hold = nil
        w.host.cancelled = true
        await w.quiet()
        let after = try #require(w.store.flow(flow.id))
        #expect(after.state == .on)
        #expect(after.watchTitle != nil, "not On with nothing looking")
        #expect(w.host.calls.filter { $0.tool == "watch.create" }.last?.input["target"] as? String == "https://y.example")
    }

    @Test func aToolsAnswerPassedToACalledFlowCanStillBeLookedIn() async throws {
        let w = try World()
        w.host.answers["reads.it"] = [Actions.Outcome(status: .ok, text: #"{"errors":["bad"]}"#, summary: "")]
        var child = try w.flow([["id": "b", "if": ["value": "{{input.r.errors}}", "test": "is_empty"], "then": [["id": "deploy", "do": "changes.it", "with": ["text": "x"]]]]])
        child.name = "Child"
        w.store.save(child)
        let flow = try w.flow([["id": "r", "do": "reads.it"], ["id": "c", "call_flow": "Child", "inputs": ["r": "{{r}}"]]])
        let run = try #require(w.engine.start(flow, mode: .live, why: "t"))
        await w.quiet()
        #expect(w.store.run(run.id)?.status == .done, "it waited for the flow it called")
        #expect(!w.host.calls.contains { $0.tool == "changes.it" }, "there are errors")
    }

    @Test func whatALoopCollectedFromAToolHasItsFields() async throws {
        let w = try World()
        w.host.answers["reads.it"] = [Actions.Outcome(status: .ok, text: #"{"price":2}"#, summary: ""), Actions.Outcome(status: .ok, text: #"{"price":3}"#, summary: "")]
        let flow = try w.flow([["id": "e", "for_each": "a\nb", "steps": [["id": "r", "do": "reads.it"]]],
                               ["id": "d", "data": ["op": "sum", "from": "{{e}}", "field": "price"]],
                               ["id": "t", "text": "{{e[0].price}}"]])
        let run = await w.settled(w.engine.start(flow, mode: .live, why: "t"))
        #expect(run?.status == .done)
        #expect(run?.record(of: "d")?.output == "5", "not 0")
        #expect(run?.record(of: "t")?.output == "2")
    }

    @Test func aToolsListGoesToAParameterThatTakesAList() async throws {
        let w = try World()
        w.catalog.use(Actions.Listing(tools: [Actions.Tool(name: "reads.it", title: "Read", schema: #"{"properties":{}}"#, mutates: false, readsOnly: true),
                                              Actions.Tool(name: "changes.it", title: "Change", schema: #"{"properties":{"labels":{"type":"array","items":{"type":"string"}},"text":{"type":"string"}}}"#)]))
        w.host.answers["reads.it"] = [Actions.Outcome(status: .ok, text: #"["a","b"]"#, summary: "")]
        let flow = try w.flow([["id": "r", "do": "reads.it"], ["id": "c", "do": "changes.it", "with": ["labels": "{{r}}", "text": "{{r}}"]]])
        let run = await w.settled(w.engine.start(flow, mode: .live, why: "t"))
        #expect(run?.status == .done)
        let sent = try #require(w.host.calls.first { $0.tool == "changes.it" }?.input)
        #expect(sent["labels"] as? [String] == ["a", "b"], "not one string split on its commas")
        #expect(sent["text"] as? String == #"["a","b"]"#, "and words stay words")
    }

    @Test func onlyAParameterThatTakesAListGetsOne() async throws {
        let w = try World()
        w.catalog.use(Actions.Listing(tools: [Actions.Tool(name: "reads.it", title: "Read", schema: #"{"properties":{}}"#, mutates: false, readsOnly: true),
                                              Actions.Tool(name: "changes.it", title: "Change", schema: #"{"properties":{"body":{"anyOf":[{"type":"string"},{"type":"null"}]},"anything":{},"labels":{"type":"array"}}}"#)]))
        w.host.answers["reads.it"] = [Actions.Outcome(status: .ok, text: #"{"a":1}"#, summary: "")]
        let flow = try w.flow([["id": "r", "do": "reads.it"], ["id": "c", "do": "changes.it", "with": ["body": "{{r}}", "anything": "{}", "labels": "[1] {{r}}"]]])
        _ = await w.settled(w.engine.start(flow, mode: .live, why: "t"))
        let sent = try #require(w.host.calls.first { $0.tool == "changes.it" }?.input)
        #expect(sent["body"] as? String == #"{"a":1}"#, "a string went before, and it may not take a record")
        #expect(sent["anything"] as? String == "{}", "what the card showed")
        #expect(sent["labels"] is String, "only a value that's all one slot")
    }

    @Test func aToolThatIsntListedKeepsItsWords() async throws {
        let w = try World()
        w.catalog.use(Actions.Listing(tools: []))
        w.host.answers["reads.it"] = [Actions.Outcome(status: .ok, text: #"["a"]"#, summary: "")]
        let flow = try w.flow([["id": "r", "do": "reads.it"], ["id": "c", "do": "notes.save", "with": ["text": "{{r}}"]]])
        _ = await w.settled(w.engine.start(flow, mode: .live, why: "t"))
        #expect(w.host.calls.first { $0.tool == "notes.save" }?.input["text"] as? String == #"["a"]"#)
    }

    @Test func plainWordsGivenToAFlowHaveNoFieldsEither() async throws {
        let w = try World()
        var child = try w.flow([["id": "b", "if": ["value": "{{input.r.errors}}", "test": "is_empty"], "then": [["id": "deploy", "do": "changes.it", "with": ["text": "x"]]]]])
        child.name = "Child"
        w.store.save(child)
        w.host.answers["reads.it"] = [Actions.Outcome(status: .ok, text: "Service unavailable", summary: "")]
        let flow = try w.flow([["id": "r", "do": "reads.it"], ["id": "c", "call_flow": "Child", "inputs": ["r": "{{r}}"]]])
        _ = await w.settled(w.engine.start(flow, mode: .live, why: "t"))
        await w.quiet()
        #expect(!w.host.calls.contains { $0.tool == "changes.it" })
    }

    @Test func whatWasntGivenToAFlowIsStillNothing() async throws {
        let w = try World()
        let flow = try w.flow([["id": "b", "if": ["value": "{{input.mode}}", "test": "is_not", "than": "fast"], "then": [["id": "t", "text": "slow"]]]])
        let run = await w.settled(w.engine.start(flow, mode: .live, why: "t"))
        #expect(run?.status == .done)
        #expect(run?.record(of: "t") != nil)
    }

    @Test func twoLanesCanBothAskTheAI() async throws {
        let w = try World()
        w.host.oneAITurn = true
        let flow = try w.flow([["id": "p", "parallel": [["name": "One", "steps": [["id": "a", "ai": "first"]]], ["name": "Two", "steps": [["id": "b", "ai": "second"]]]]]])
        let run = try #require(w.engine.start(flow, mode: .live, why: "t"))
        await w.quiet()
        #expect(w.store.run(run.id)?.status == .done, "Sidefolk takes one at a time, so they take turns")
        #expect(w.host.written.count == 2)
    }

    @Test func aLongAnswerGoesAsWordsAsItDidBefore() async throws {
        let w = try World()
        w.catalog.use(Actions.Listing(tools: [Actions.Tool(name: "reads.it", title: "Read", schema: #"{"properties":{}}"#, mutates: false, readsOnly: true),
                                              Actions.Tool(name: "changes.it", title: "Change", schema: #"{"properties":{"text":{"type":"string"}}}"#)]))
        let long = String(repeating: "x", count: 30_000)
        w.host.answers["reads.it"] = [Actions.Outcome(status: .ok, text: long, summary: "")]
        let flow = try w.flow([["id": "r", "do": "reads.it"], ["id": "c", "do": "changes.it", "with": ["text": "{{r}}"]]])
        let run = await w.settled(w.engine.start(flow, mode: .live, why: "t"))
        #expect(run?.status == .done)
        #expect((w.host.calls.first { $0.tool == "changes.it" }?.input["text"] as? String)?.count == Values.wordsKept, "a flow saving a page to a note goes on working")
        #expect(run?.record(of: "r")?.note != nil, "and it says so")
    }

    @Test func aLongJSONAnswerStillHasItsFields() async throws {
        let w = try World()
        let filler = String(repeating: "x", count: 30_000)
        w.host.answers["reads.it"] = [Actions.Outcome(status: .ok, text: #"{"filler":"\#(filler)","late":"yes"}"#, summary: "")]
        let flow = try w.flow([["id": "r", "do": "reads.it"], ["id": "t", "text": "{{r.late}}"]])
        let run = await w.settled(w.engine.start(flow, mode: .live, why: "t"))
        #expect(run?.record(of: "t")?.output == "yes")
    }

    @Test func aFieldSaidToBeNothingCantBeSaidToBeSomethingElse() async throws {
        let (run, w) = try await deciding(#"{"status":null}"#, "is_not", than: "down", field: "status")
        #expect(run?.status == .failed)
        #expect(!w.host.calls.contains { $0.tool == "changes.it" })
    }

    @Test func anEmptyAnswerIsAnAnswer() async throws {
        let field = try await deciding(#"{"status":""}"#, "is_not", than: "down", field: "status")
        #expect(field.1.host.calls.contains { $0.tool == "changes.it" }, "it said it's empty, and empty isn't down")
        for empty in ["[]", "{}"] {
            let found = try await deciding(empty, "not_contains", than: "P0", field: "")
            #expect(found.0?.status == .done, "nothing found has no P0 in it")
            #expect(found.1.host.calls.contains { $0.tool == "changes.it" })
        }
    }

    @Test func anOptionalFieldLeftEmptyIsAnAnswer() async throws {
        let w = try World()
        let app = app(w)
        let flow = try make(app, [["id": "f", "form": ["title": "T", "fields": [["name": "note", "label": "Note", "kind": "text", "required": false]]]],
                                  ["id": "b", "if": ["value": "{{f.note}}", "test": "not_contains", "than": "urgent"], "then": [["id": "calm", "text": "x"]]]])
        let run = try #require(app.engine.start(flow, mode: .once, why: "t"))
        await w.quiet(app.store)
        try await page(app, "form_send", flow, ["run": run.id])
        await w.quiet(app.store)
        let done = try #require(app.store.run(run.id))
        #expect(done.status == .done)
        #expect(done.record(of: "calm") != nil)
    }

    @Test func aBlankFormFieldIsNotGivenToANumberOrAChoice() async throws {
        let w = try World()
        let app = app(w)
        app.catalog.use(Actions.Listing(tools: [Actions.Tool(name: "changes.it", title: "Change", schema: #"{"properties":{"n":{"type":"number"},"pick":{"type":"string","enum":["a","b"]},"text":{"type":"string"}}}"#)]))
        let flow = try make(app, [["id": "f", "form": ["title": "T", "fields": [["name": "n", "label": "N", "kind": "number", "required": false]]]],
                                  ["id": "c", "do": "changes.it", "with": ["n": "{{f.n}}", "pick": "{{f.n}}", "text": "{{f.n}}"]]])
        let run = try #require(app.engine.start(flow, mode: .once, why: "t"))
        await w.quiet(app.store)
        try await page(app, "form_send", flow, ["run": run.id])
        await w.quiet(app.store)
        let sent = try #require(w.host.calls.first { $0.tool == "changes.it" }?.input)
        #expect(sent["n"] is NSNull, "absent, as it was, not an empty string a number can't be")
        #expect(sent["pick"] is NSNull)
        #expect(sent["text"] as? String == "")
    }

    @Test func aBlankIsNotGivenOnlyWhereEmptyIsntAllowed() async throws {
        let w = try World()
        w.catalog.use(Actions.Listing(tools: [Actions.Tool(name: "reads.it", title: "Read", schema: #"{"properties":{}}"#, mutates: false, readsOnly: true),
                                              Actions.Tool(name: "changes.it", title: "Change", schema: #"{"properties":{"i":{"type":"integer"},"b":{"type":"boolean"},"level":{"type":"string","enum":["","low"]}}}"#)]))
        w.host.answers["reads.it"] = [Actions.Outcome(status: .ok, text: #"{"x":""}"#, summary: "")]
        let flow = try w.flow([["id": "r", "do": "reads.it"], ["id": "c", "do": "changes.it", "with": ["i": "{{r.x}}", "b": "{{r.x}}", "level": "{{r.x}}"]]])
        _ = await w.settled(w.engine.start(flow, mode: .live, why: "t"))
        let sent = try #require(w.host.calls.first { $0.tool == "changes.it" }?.input)
        #expect(sent["i"] is NSNull)
        #expect(sent["b"] is NSNull)
        #expect(sent["level"] as? String == "", "empty is one of its answers")
    }

    /// A page's check and a run both go through `Catalog.filled`, so this is what each sends for a value not known yet.
    @Test func whatAPageChecksIsWhatARunSends() throws {
        let w = try World()
        w.catalog.use(Actions.Listing(tools: [Actions.Tool(name: "changes.it", title: "Change", schema: #"{"properties":{"n":{"type":"number"},"pick":{"type":"string","enum":["a","b"]},"text":{"type":"string"}}}"#)]))
        var values = Values()
        values.set("r", "…")
        let sent = w.catalog.filled("changes.it", ["n": .string("{{r.n}}"), "pick": .string("{{r.pick}}"), "text": .string("{{r.text}}")], from: values)
        #expect(sent["n"] is NSNull)
        #expect(sent["pick"] is NSNull)
        #expect(sent["text"] as? String == "")
    }

    @Test func anEmptyValueCanStillClearWhatTakesWords() async throws {
        let w = try World()
        w.catalog.use(Actions.Listing(tools: [Actions.Tool(name: "reads.it", title: "Read", schema: #"{"properties":{}}"#, mutates: false, readsOnly: true),
                                              Actions.Tool(name: "changes.it", title: "Change", schema: #"{"properties":{"who":{"anyOf":[{"type":"string"},{"type":"null"}]},"anything":{}}}"#)]))
        w.host.answers["reads.it"] = [Actions.Outcome(status: .ok, text: #"{"who":""}"#, summary: "")]
        let flow = try w.flow([["id": "r", "do": "reads.it"], ["id": "c", "do": "changes.it", "with": ["who": "{{r.who}}", "anything": "{{r.who}}"]], ["id": "u", "do": "notes.save", "with": ["text": "{{r.who}}"]]])
        _ = await w.settled(w.engine.start(flow, mode: .live, why: "t"))
        let sent = try #require(w.host.calls.first { $0.tool == "changes.it" }?.input)
        #expect(sent["who"] as? String == "", "“leave it” isn't what an empty value said")
        #expect(sent["anything"] as? String == "")
        #expect(w.host.calls.first { $0.tool == "notes.save" }?.input["text"] as? String == "", "a tool that isn't listed: words")
    }

    @Test func aFilterKeepsNoAndFalse() throws {
        let filter = DataStep(op: .filter, from: "", test: .not_empty, than: "")
        let rows = JSON.array([.string("No"), .string("false"), .string("NO"), .string("yes"), .string("")])
        let made = try filter.apply(to: rows, than: "")
        guard case .array(let kept) = made else { Issue.record("not a list"); return }
        #expect(kept.count == 4, "only what's really empty goes")
    }

    @Test func aChoiceInWritingWithNoSpacesFindsAWordInIt() {
        #expect(Condition.mentions("GitHubの通知", "GitHub"))
        #expect(Condition.mentions("3件", "3"))
        #expect(!Condition.mentions("unpaid bills", "paid"))
        #expect(!Condition.mentions("unpaid invoice from 田中", "paid"), "one name in other writing doesn't change the rest")
        #expect(Condition.mentions("unpaid invoice from 田中", "unpaid"))
        #expect(!Condition.mentions("13件", "3"))
        #expect(Condition.mentions("13件", "13"))
        #expect(Condition.mentions("C++ tools", "C++"))
        #expect(Condition.mentions("サーバーOK", "OK"), "the long vowel mark doesn't join a word")
        #expect(!Condition.mentions("बेकार", "कार"), "a vowel sign is part of the word")
        for (seen, word) in [("Slack通知が来た", "通知"), ("API障害", "障害"), ("404エラー", "エラー"), ("注文123", "注文"), ("GitHub알림", "알림"), ("サーバー障害", "障害"), ("データ", "データ")] {
            #expect(Condition.mentions(seen, word), "\(seen) mentions \(word)")
        }
    }

    @Test func emptyGivenToAFlowIsntPassedEither() async throws {
        let w = try World()
        w.host.answers["reads.it"] = [Actions.Outcome(status: .error, text: "broken", summary: "")]
        var child = try w.flow([["id": "b", "if": ["value": "{{input.r}}", "test": "is_not", "than": "down"], "then": [["id": "go", "do": "changes.it", "with": ["text": "x"]]]]])
        child.name = "Child"
        w.store.save(child)
        let flow = try w.flow([["id": "fetch", "do": "reads.it", "on_failure": "carry_on"], ["id": "c", "call_flow": "Child", "inputs": ["r": "{{fetch}}"]]])
        _ = try #require(w.engine.start(flow, mode: .live, why: "t"))
        await w.quiet()
        #expect(!w.host.calls.contains { $0.tool == "changes.it" })
    }

    @Test(arguments: ["[]", "{}"])
    func anEmptyListOrRecordIsEmpty(_ reply: String) async throws {
        let empty = try await deciding(reply, "is_empty", field: "")
        #expect(empty.1.host.calls.contains { $0.tool == "changes.it" })
        let some = try await deciding(reply, "not_empty", field: "")
        #expect(!some.1.host.calls.contains { $0.tool == "changes.it" }, "there's nothing there")
    }

    @Test func aFilterWithNoMatchesIsEmpty() async throws {
        let w = try World()
        let flow = try w.flow([["id": "t", "text": "apple\npear"], ["id": "l", "data": ["op": "lines", "from": "{{t}}"]], ["id": "d", "data": ["op": "filter", "from": "{{l}}", "than": "zzz"]],
                               ["id": "b", "if": ["value": "{{d}}", "test": "not_empty"], "then": [["id": "yes", "text": "x"]], "else": [["id": "no", "text": "y"]]]])
        let run = await w.settled(w.engine.start(flow, mode: .live, why: "t"))
        #expect(run?.record(of: "yes") == nil)
        #expect(run?.record(of: "no") != nil)
    }

    @Test func yesAndNoMeanWhatTheySay() {
        for (left, right, same) in [("true", "yes", true), ("false", "no", true), ("false", "yes", false), ("YES", "true", true), ("true", "true", true), ("maybe", "yes", false)] {
            #expect(Condition.test(.is, left: left, right: right) == same, "\(left) is \(right)")
            #expect(Condition.test(.is_not, left: left, right: right) == !same, "\(left) isn't \(right)")
        }
        #expect(Condition.test(.contains, left: "true", right: "yes"))
        #expect(!Condition.test(.contains, left: "true", right: "s"), "it doesn't spell yes")
        #expect(!Condition.test(.contains, left: "false", right: "n"))
        let values = Values()
        #expect(!Condition(value: "false", test: .not_empty, than: "").holds(values), "a condition doesn't take a No for something")
        #expect(Condition(value: "false", test: .is_empty, than: "").holds(values))
        #expect(Condition(value: "No", test: .not_empty, than: "").holds(values), "the word is a word")
        #expect(Condition(value: "NO", test: .not_empty, than: "").holds(values), "and it's a country")
    }

    @Test func aNoFromAFormGoesTheWayItSays() async throws {
        let w = try World()
        let app = app(w)
        let flow = try make(app, [["id": "f", "form": ["title": "T", "fields": [["name": "go", "label": "Go", "kind": "yes_no"]]]],
                                  ["id": "b", "if": ["value": "{{f.go}}", "test": "is_not", "than": "no"], "then": [["id": "yes", "text": "x"]], "else": [["id": "no", "text": "y"]]],
                                  ["id": "c", "choose": "{{f.go}}", "paths": [["when": "Yes", "steps": [["id": "p", "text": "x"]]], ["when": "No", "steps": [["id": "q", "text": "y"]]]]]])
        let run = try #require(app.engine.start(flow, mode: .once, why: "t"))
        await w.quiet(app.store)
        try await page(app, "form_field", flow, ["run": run.id, "name": "go", "on": false])
        try await page(app, "form_send", flow, ["run": run.id])
        await w.quiet(app.store)
        let done = try #require(app.store.run(run.id))
        #expect(done.status == .done)
        #expect(done.record(of: "yes") == nil)
        #expect(done.record(of: "no") != nil)
        #expect(done.record(of: "q") != nil, "not Otherwise")
    }

    @Test func aPathGoesByTheWordNotPartOfOne() async throws {
        for (value, took) in [("unpaid", "other"), ("paid", "p"), ("Paid in full", "p"), ("10", "other"), ("1", "o")] {
            let w = try World()
            let flow = try w.flow([["id": "t", "text": value],
                                   ["id": "c", "choose": "{{t}}", "paths": [["when": "paid", "steps": [["id": "p", "text": "x"]]], ["when": "1", "steps": [["id": "o", "text": "x"]]]], "else": [["id": "other", "text": "x"]]]])
            let run = await w.settled(w.engine.start(flow, mode: .live, why: "t"))
            #expect(run?.record(of: took) != nil, "\(value) goes to \(took)")
        }
        // Writing with no spaces has no words to tell apart.
        #expect(Condition.mentions("支払い済みです", "支払い"))
        // An exact path beats one that's only mentioned.
        let w = try World()
        let flow = try w.flow([["id": "t", "text": "not paid"],
                               ["id": "c", "choose": "{{t}}", "paths": [["when": "paid", "steps": [["id": "p", "text": "x"]]], ["when": "not paid", "steps": [["id": "n", "text": "x"]]]]]])
        let run = await w.settled(w.engine.start(flow, mode: .live, why: "t"))
        #expect(run?.record(of: "n") != nil)
    }

    @Test func lanesThatRanArentSaidNotToHave() async throws {
        let w = try World()
        let app = app(w)
        let flow = try make(app, [["id": "p", "parallel": [["name": "One", "steps": [["id": "a", "text": "x"]]], ["name": "Two", "steps": [["id": "b", "text": "y"]]]]]])
        let run = try #require(app.engine.start(flow, mode: .practice, why: "t"))
        await w.quiet(app.store)
        let done = try #require(app.store.run(run.id))
        let shown = Pages.withLanes(done, app)
        #expect(shown.record(of: "a") != nil)
        #expect(shown.record(of: "b") != nil)
        #expect(Pages.untried(try #require(app.store.flow(flow.id)), app).isEmpty, "every lane ran")
        #expect(!drawn(Pages.stepDetail(done, step: "a", scope: nil, app)).contains(L("It didn't get this far in this run, or the path it's on wasn't taken.")))
    }

    @Test func aLaneIsntTheFlowsLatestRun() async throws {
        let w = try World()
        let app = app(w)
        let flow = try make(app, [["id": "p", "parallel": [["name": "One", "steps": [["id": "a", "text": "x"]]], ["name": "Two", "steps": [["id": "b", "text": "y"]]]]]])
        let run = try #require(app.engine.start(flow, mode: .once, why: "t"))
        await w.quiet(app.store)
        #expect(app.store.latest(of: flow.id)?.id == run.id)
    }

    private func editedWhileWaiting(_ w: World, _ second: [String: Any]) async throws -> (Run, Flow) {
        var flow = try w.flow([["id": "w", "wait_minutes": 1], second])
        let run = try #require(w.engine.start(flow, mode: .live, why: "t"))
        await w.quiet()
        flow = try #require(w.store.flow(flow.id))
        let approved = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "w", "wait_minutes": 1]]])
        flow.draft = approved
        flow.live = approved
        w.store.save(flow)
        w.now = w.now.addingTimeInterval(120)
        w.engine.tick()
        await w.quiet()
        return (try #require(w.store.run(run.id)), flow)
    }

    @Test func anAIStepAnApprovedEditRemovedDoesntRun() async throws {
        let w = try World()
        let (run, _) = try await editedWhileWaiting(w, ["id": "a", "ai": "write"])
        #expect(w.host.written.isEmpty, "what they read last doesn't have it")
        #expect(run.status == .needs_you)
    }

    @Test func aSetOffAnApprovedEditRemovedDoesntRun() async throws {
        let w = try World()
        var other = try w.flow([["id": "x", "do": "reads.it"]])
        other.name = "Other"
        w.store.save(other)
        let (run, _) = try await editedWhileWaiting(w, ["id": "o", "run_flow": "Other"])
        #expect(!w.host.calls.contains { $0.tool == "reads.it" })
        #expect(run.status == .needs_you)
    }

    @Test func aCallThatsAlreadyOutComesBackAfterAnEditTookItOut() async throws {
        let w = try World()
        var child = try w.flow([["id": "w", "wait_minutes": 1], ["id": "t", "text": "made"]])
        child.name = "Child"
        w.store.save(child)
        var flow = try w.flow([["id": "c", "call_flow": "Child"], ["id": "after", "text": "{{c}}"]])
        let run = try #require(w.engine.start(flow, mode: .live, why: "t"))
        await w.quiet()
        #expect(w.store.run(run.id)?.status == .waiting)
        flow = try #require(w.store.flow(flow.id))
        let approved = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "after", "text": "other"]]])
        flow.draft = approved
        flow.live = approved
        w.store.save(flow)
        w.now = w.now.addingTimeInterval(120)
        w.engine.tick()
        await w.quiet()
        #expect(w.store.run(run.id)?.status == .done, "it already ran: nothing to ask, and nothing to lose")
        #expect(w.store.run(run.id)?.waitingOn.isEmpty == true)
    }

    @Test func aStepChangedByAnEditIsntSaidToBeGone() async throws {
        let w = try World()
        var flow = try w.flow([["id": "w", "wait_minutes": 1], ["id": "a", "ai": "write"]])
        let run = try #require(w.engine.start(flow, mode: .live, why: "t"))
        await w.quiet()
        flow = try #require(w.store.flow(flow.id))
        let approved = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "w", "wait_minutes": 1], ["id": "a", "ai": "other words"]]])
        flow.draft = approved
        flow.live = approved
        w.store.save(flow)
        w.now = w.now.addingTimeInterval(120)
        w.engine.tick()
        await w.quiet()
        let held = try #require(w.store.run(run.id))
        #expect(held.status == .needs_you)
        #expect(w.host.written.isEmpty)
        #expect(held.problem?.contains("without") == false, "it's there, in other words")
        #expect(held.problem?.contains("Skip") == true, "and Try again would ask the same")
    }

    @Test func aStepLeftBehindDoesntOfferToTryAgain() async throws {
        let w = try World()
        let app = app(w)
        var flow = try make(app, [["id": "w", "wait_minutes": 1], ["id": "a", "ai": "write"]])
        flow.live = flow.draft
        flow.state = .on
        app.store.save(flow)
        let run = try #require(app.engine.start(flow, mode: .live, why: "t"))
        await w.quiet(app.store)
        flow = try #require(app.store.flow(flow.id))
        let approved = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "w", "wait_minutes": 1]]])
        flow.draft = approved
        flow.live = approved
        app.store.save(flow)
        var late = try #require(app.store.run(run.id))
        late.resumeAt = Date().addingTimeInterval(-1)
        app.store.save(late)
        app.engine.tick()
        await w.quiet(app.store)
        let held = try #require(app.store.run(run.id))
        #expect(held.status == .needs_you)
        #expect(app.engine.stepLeftBehind(held))
        let page = await Pages.make(app, state: Arguments(["run": run.id]), background: false)
        let words = page.sections.map { "\($0)" }.joined()
        #expect(!words.contains(L("Try again")), "it would ask the same again")
        #expect(words.contains(L("Skip this step")))
        // And the question on the Sidecard, by the same rule.
        await w.quiet(app.store)
        #expect(!w.host.forwardOptions.isEmpty)
        #expect(!w.host.forwardOptions.contains(L("Try again")))
    }

    @Test func aStepThatsStillThereGoesOnAfterAnEdit() async throws {
        let w = try World()
        var flow = try w.flow([["id": "w", "wait_minutes": 1], ["id": "a", "ai": "write"]])
        let run = try #require(w.engine.start(flow, mode: .live, why: "t"))
        await w.quiet()
        flow = try #require(w.store.flow(flow.id))
        let approved = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "w", "wait_minutes": 1], ["id": "a", "ai": "write"], ["id": "t", "text": "more"]]])
        flow.draft = approved
        flow.live = approved
        w.store.save(flow)
        w.now = w.now.addingTimeInterval(120)
        w.engine.tick()
        await w.quiet()
        #expect(w.host.written.count == 1)
        #expect(w.store.run(run.id)?.status == .done)
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
        #expect(Set(Engine.keys([Step.Lane(name: "a", steps: []), Step.Lane(name: "a_3", steps: []), Step.Lane(name: "a", steps: [])])).count == 3)
    }

    @Test func bothLanesResultsCanBeReachedAfterARun() async throws {
        let w = try World()
        let flow = try w.flow([["id": "p", "parallel": [["name": "First", "steps": [["id": "a", "finish": "one"]]], ["name": "first!", "steps": [["id": "b", "finish": "two"]]]]],
                               ["id": "t", "text": "{{p.first}} {{p.first_2}}"]])
        let run = try #require(w.engine.start(flow, mode: .live, why: "t"))
        await w.quiet()
        let done = try #require(w.store.run(run.id))
        #expect(done.status == .done, "it waited for its lanes")
        #expect(done.record(of: "t")?.output == "one two")
    }

    @Test func aLaneCantTakeANameAnotherGoesBy() async throws {
        let w = try World()
        let app = app(w)
        let flow = try make(app, [["id": "p", "parallel": [["name": "First", "steps": [["id": "a", "text": "x"]]], ["name": "Second", "steps": [["id": "b", "text": "y"]]]]]])
        await #expect(throws: Problem.self) { try await self.page(app, "lane_name", flow, ["step": "p", "lane": 0, "text": "second"]) }
        if case .parallel(let lanes)? = app.store.flow(flow.id)?.draft.step("p")?.kind { #expect(lanes[0].name == "First") } else { Issue.record("not lanes") }
        // Names that make no key of their own aren't the same name.
        try await page(app, "lane_name", flow, ["step": "p", "lane": 0, "text": "🍎"])
        try await page(app, "lane_name", flow, ["step": "p", "lane": 1, "text": "🍌"])
        if case .parallel(let lanes)? = app.store.flow(flow.id)?.draft.step("p")?.kind { #expect(lanes.map(\.name) == ["🍎", "🍌"]) } else { Issue.record("not lanes") }
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
        #expect(!w.host.notices.isEmpty)
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
