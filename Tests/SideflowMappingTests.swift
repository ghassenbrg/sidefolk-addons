import Foundation
import Testing
@testable import ext_sideflow
import SidefolkExtensionKit

/// A step's fields: written out or an earlier step's value, each kept as what it is; a record's own fields; what they'd be going by the last run.
@MainActor @Suite(.serialized) struct SideflowMappingTests {
    typealias World = SideflowTests.World

    private static let schema = #"{"properties":{"text":{"type":"string"},"count":{"type":"integer"},"urgent":{"type":"boolean"},"mode":{"enum":["fast","slow"]},"tags":{"type":"array","items":{"type":"string"}},"to":{"type":"object","properties":{"city":{"type":"string"},"zip":{"type":"integer"}},"required":["city"]},"extra":{"type":"object"}},"required":["text"]}"#

    private func app(_ w: World) throws -> App {
        let app = App(folder: w.folder.appendingPathComponent("app"))
        app.engine.host = w.host
        app.catalog.use(Actions.Listing(tools: [
            Actions.Tool(name: "reads.it", title: "Read it", schema: #"{"properties":{}}"#, mutates: false, readsOnly: true, outputSchema: #"{"properties":{"total":{"type":"integer"},"who":{"type":"string"},"rows":{"type":"array"}}}"#),
            Actions.Tool(name: "changes.it", title: "Change it", schema: Self.schema),
        ]))
        return app
    }

    private func flow(_ app: App) throws -> Flow {
        app.newFlow(name: "F", body: try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "r", "do": "reads.it"], ["id": "c", "do": "changes.it", "with": ["text": "x"]]]]))
    }

    private func form(_ flow: Flow, _ app: App) -> String {
        app.nav.inspect(.step("c"), in: flow.id)
        return String(describing: Inspector.sections(try! #require(app.store.flow(flow.id)), app, problems: []))
    }

    private func input(_ flow: Flow, _ app: App) -> [String: JSON] {
        guard case .action(_, let input)? = app.store.flow(flow.id)?.draft.step("c")?.kind else { return [:] }
        return input
    }

    @Test func aRecordsOwnFieldsEachHaveTheirOwnPlace() async throws {
        let w = try World()
        let app = try app(w)
        let f = try flow(app)
        let shown = form(f, app)
        #expect(shown.contains("c.to.city") && shown.contains("c.to.zip"), "not one box of JSON, and not skipped")
        _ = try await Actions_UI.handle(Arguments(["op": "param", "flow": f.id, "step": "c", "name": "to.city", "text": "Tunis"]), app)
        _ = try await Actions_UI.handle(Arguments(["op": "param", "flow": f.id, "step": "c", "name": "to.zip", "text": "1000"]), app)
        #expect(input(f, app)["to"] == .object(["city": .string("Tunis"), "zip": .number(1000)]))
        _ = try await Actions_UI.handle(Arguments(["op": "param", "flow": f.id, "step": "c", "name": "to.city", "text": ""]), app)
        _ = try await Actions_UI.handle(Arguments(["op": "param", "flow": f.id, "step": "c", "name": "to.zip", "text": ""]), app)
        #expect(input(f, app)["to"] == nil, "an empty record isn't sent")
    }

    @Test func aFieldInARecordGetsItsValueAtRunTime() async throws {
        let w = try World()
        w.catalog.use(Actions.Listing(tools: [Actions.Tool(name: "changes.it", title: "Change it", schema: Self.schema)]))
        let flow = try w.flow([["id": "t", "text": "Tunis"], ["id": "c", "do": "changes.it", "with": ["text": "x", "to": ["city": "{{t}}"]]]])
        _ = await w.settled(w.engine.start(flow, mode: .live, why: "t"))
        let sent = w.host.calls.first { $0.tool == "changes.it" }?.input["to"] as? [String: Any]
        #expect(sent?["city"] as? String == "Tunis")
    }

    @Test func whatAFormCantDrawIsWrittenOutAndChecked() async throws {
        let w = try World()
        let app = try app(w)
        let f = try flow(app)
        #expect(form(f, app).contains("c.extra"), "not skipped, as it was")
        _ = try await Actions_UI.handle(Arguments(["op": "param_json", "flow": f.id, "step": "c", "name": "extra", "text": #"{"a": "{{r.who}}"}"#]), app)
        #expect(input(f, app)["extra"] == .object(["a": .string("{{r.who}}")]))
        await #expect(throws: Problem.self) { _ = try await Actions_UI.handle(Arguments(["op": "param_json", "flow": f.id, "step": "c", "name": "extra", "text": "{nope"]), app) }
        #expect(input(f, app)["extra"] == .object(["a": .string("{{r.who}}")]), "what was there stays")
    }

    @Test func aNumberIsItsOwnControlOrAnEarlierValueNeverWords() async throws {
        let w = try World()
        let app = try app(w)
        let f = try flow(app)
        #expect(form(f, app).contains("Use a value from an earlier step"))
        _ = try await Actions_UI.handle(Arguments(["op": "param", "flow": f.id, "step": "c", "name": "count", "text": "3"]), app)
        #expect(input(f, app)["count"] == .number(3))
        _ = try await Actions_UI.handle(Arguments(["op": "param_mode", "flow": f.id, "step": "c", "name": "count", "on": true]), app)
        var shown = form(f, app)
        #expect(shown.contains("Write it here instead"))
        #expect(shown.contains("{{r.total}}"), "the field that's a number is on offer")
        _ = try await Actions_UI.handle(Arguments(["op": "param", "flow": f.id, "step": "c", "name": "count", "text": "{{r.total}}"]), app)
        #expect(input(f, app)["count"] == .string("{{r.total}}"), "filled in when it runs, as what it is then")
        _ = try await Actions_UI.handle(Arguments(["op": "param_mode", "flow": f.id, "step": "c", "name": "count", "on": false]), app)
        #expect(input(f, app)["count"] == nil, "a value picked doesn't fit the other way")
        shown = form(f, app)
        #expect(shown.contains("Use a value from an earlier step"))
    }

    @Test func aFieldIsOfferedOnlyWhatFitsIt() async throws {
        let w = try World()
        let app = App(folder: w.folder.appendingPathComponent("app"))
        app.catalog.use(Actions.Listing(tools: [
            Actions.Tool(name: "reads.it", title: "Read it", schema: #"{"properties":{}}"#, mutates: false, readsOnly: true, outputSchema: #"{"properties":{"total":{"type":"integer"},"who":{"type":"string"},"rows":{"type":"array"},"any":{}}}"#),
            Actions.Tool(name: "counts.it", title: "Count it", schema: #"{"properties":{"count":{"type":"integer"}},"required":["count"]}"#),
        ]))
        let f = app.newFlow(name: "F", body: try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "r", "do": "reads.it"], ["id": "c", "do": "counts.it", "with": ["count": "{{r.total}}"]]]]))
        let shown = form(f, app)
        #expect(shown.contains("{{r.total}}"))
        #expect(shown.contains("{{r.any}}"), "what isn't known might fit")
        #expect(!shown.contains("{{r.who}}"), "words aren't offered to a number")
        #expect(!shown.contains("{{r.rows}}"))
    }

    @Test func aYesOrNoCanComeFromAValueToo() async throws {
        let w = try World()
        let app = try app(w)
        let f = try flow(app)
        _ = try await Actions_UI.handle(Arguments(["op": "param", "flow": f.id, "step": "c", "name": "urgent", "text": "{{r.who}}"]), app)
        #expect(input(f, app)["urgent"] == .string("{{r.who}}"), "not read as false")
        _ = try await Actions_UI.handle(Arguments(["op": "param", "flow": f.id, "step": "c", "name": "urgent", "on": true]), app)
        #expect(input(f, app)["urgent"] == .bool(true))
    }

    @Test func aListKeepsAValueWhole() async throws {
        let w = try World()
        let app = try app(w)
        let f = try flow(app)
        _ = try await Actions_UI.handle(Arguments(["op": "param", "flow": f.id, "step": "c", "name": "tags", "text": "{{r.rows}}"]), app)
        #expect(input(f, app)["tags"] == .string("{{r.rows}}"), "not a list of one odd string")
        _ = try await Actions_UI.handle(Arguments(["op": "param", "flow": f.id, "step": "c", "name": "tags", "text": "a, b"]), app)
        #expect(input(f, app)["tags"] == .array([.string("a"), .string("b")]))
    }

    @Test func wordsThatPlainlyAreWhatItWantsGoAsThat() async throws {
        let w = try World()
        w.catalog.use(Actions.Listing(tools: [Actions.Tool(name: "changes.it", title: "Change it", schema: Self.schema)]))
        let flow = try w.flow([["id": "n", "text": "12"], ["id": "y", "text": "yes"], ["id": "l", "text": "one"],
                               ["id": "c", "do": "changes.it", "with": ["text": "x", "count": "{{n}}", "urgent": "{{y}}", "tags": "{{l}}"]]])
        _ = await w.settled(w.engine.start(flow, mode: .live, why: "t"))
        let sent = try #require(w.host.calls.first { $0.tool == "changes.it" }?.input)
        #expect(sent["count"] as? Int == 12)
        #expect(sent["urgent"] as? Bool == true)
        #expect(sent["tags"] as? [String] == ["one"])
    }

    @Test func wordsThatArentWhatItWantsGoAsTheyAreForSidefolkToRefuse() async throws {
        let w = try World()
        w.catalog.use(Actions.Listing(tools: [Actions.Tool(name: "changes.it", title: "Change it", schema: Self.schema)]))
        let flow = try w.flow([["id": "n", "text": "many"], ["id": "c", "do": "changes.it", "with": ["text": "x", "count": "{{n}}"]]])
        _ = await w.settled(w.engine.start(flow, mode: .live, why: "t"))
        #expect(w.host.calls.first { $0.tool == "changes.it" }?.input["count"] as? String == "many", "never a guessed number")
    }

    @Test func aRecordsFieldsGetWhatTheTopLevelDoes() async throws {
        let w = try World()
        w.catalog.use(Actions.Listing(tools: [Actions.Tool(name: "changes.it", title: "Change it", schema: Self.schema)]))
        w.host.answers["reads.it"] = [Actions.Outcome(status: .ok, text: "Looked", summary: "", data: #"{"total": 2, "blank": null}"#)]
        w.catalog.use(Actions.Listing(tools: [Actions.Tool(name: "reads.it", title: "Read it", schema: #"{"properties":{}}"#, mutates: false, readsOnly: true), Actions.Tool(name: "changes.it", title: "Change it", schema: Self.schema)]))
        let long = String(repeating: "x", count: Values.wordsKept + 100)
        let flow = try w.flow([["id": "r", "do": "reads.it"], ["id": "big", "text": long],
                               ["id": "c", "do": "changes.it", "with": ["text": "x", "to": ["city": "{{big}}", "zip": "{{r.total}}"]]]])
        _ = await w.settled(w.engine.start(flow, mode: .live, why: "t"))
        let to = w.host.calls.first { $0.tool == "changes.it" }?.input["to"] as? [String: Any]
        #expect((to?["city"] as? String)?.count == Values.wordsKept, "words are kept to the same length")
        #expect(to?["zip"] as? Double == 2 || to?["zip"] as? Int == 2)
    }

    @Test func anOptionalFieldOfARecordIsLeftOutWhenItSaysNothingAndARequiredOneStops() async throws {
        let w = try World()
        w.host.answers["reads.it"] = [Actions.Outcome(status: .ok, text: "Looked", summary: "", data: #"{"blank": null}"#), Actions.Outcome(status: .ok, text: "Looked", summary: "", data: #"{"blank": null}"#)]
        w.catalog.use(Actions.Listing(tools: [Actions.Tool(name: "reads.it", title: "Read it", schema: #"{"properties":{}}"#, mutates: false, readsOnly: true), Actions.Tool(name: "changes.it", title: "Change it", schema: Self.schema)]))
        let leftOut = try w.flow([["id": "r", "do": "reads.it"], ["id": "c", "do": "changes.it", "with": ["text": "x", "to": ["city": "Tunis", "zip": "{{r.blank}}"]]]])
        let fine = await w.settled(w.engine.start(leftOut, mode: .live, why: "t"))
        #expect(fine?.status == .done, "\(fine?.problem ?? "")")
        let to = w.host.calls.first { $0.tool == "changes.it" }?.input["to"] as? [String: Any]
        #expect(to?["city"] as? String == "Tunis" && to?["zip"] == nil)
        w.host.calls.removeAll()
        let stops = try w.flow([["id": "r", "do": "reads.it"], ["id": "c", "do": "changes.it", "with": ["text": "x", "to": ["city": "{{r.blank}}"]]]])
        let stopped = await w.settled(w.engine.start(stops, mode: .live, why: "t"))
        #expect(stopped?.status != .done)
        #expect(!w.host.calls.contains { $0.tool == "changes.it" })
    }

    @Test func aRequiredFieldOfARecordIsAskedForOnceItsStarted() throws {
        let w = try World()
        let app = try app(w)
        let started = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "c", "do": "changes.it", "with": ["text": "x", "to": ["zip": 1000]]]]])
        #expect(started.problems(app.catalog).contains { $0.text.contains("City") }, "\(started.problems(app.catalog))")
        let optional = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "c", "do": "changes.it", "with": ["text": "x"]]]])
        #expect(!optional.problems(app.catalog).contains { $0.text.contains("City") }, "the record itself is optional")
    }

    @Test func listsAmongWordsAndWhatsTypedStayWhatTheyAre() async throws {
        let w = try World()
        let app = try app(w)
        let f = try flow(app)
        _ = try await Actions_UI.handle(Arguments(["op": "param", "flow": f.id, "step": "c", "name": "tags", "text": "a, {{r.who}}"]), app)
        #expect(input(f, app)["tags"] == .array([.string("a"), .string("{{r.who}}")]), "an entry of the list")
        await #expect(throws: Problem.self, "not a number, and not kept as if it were") { _ = try await Actions_UI.handle(Arguments(["op": "param", "flow": f.id, "step": "c", "name": "count", "text": "abc"]), app) }
        #expect(input(f, app)["count"] == nil)
        _ = try await Actions_UI.handle(Arguments(["op": "param", "flow": f.id, "step": "c", "name": "count", "text": "3"]), app)
        _ = try await Actions_UI.handle(Arguments(["op": "param_mode", "flow": f.id, "step": "c", "name": "count", "on": true]), app)
        #expect(input(f, app)["count"] == nil, "what's shown is what's sent")
    }

    @Test func whatsWrittenOutCanBeOneValue() async throws {
        let w = try World()
        let app = try app(w)
        let f = try flow(app)
        _ = try await Actions_UI.handle(Arguments(["op": "param_json", "flow": f.id, "step": "c", "name": "extra", "text": #""{{r.rows}}""#]), app)
        #expect(input(f, app)["extra"] == .string("{{r.rows}}"), "as the form says it can be")
        #expect(form(f, app).contains(#"\"{{r.rows}}\""#) || form(f, app).contains(#""{{r.rows}}""#))
    }

    @Test func aParameterWithADotInItsNameIsThatParameter() async throws {
        let w = try World()
        let app = App(folder: w.folder.appendingPathComponent("app"))
        app.catalog.use(Actions.Listing(tools: [Actions.Tool(name: "changes.it", title: "Change it", schema: #"{"properties":{"filter.status":{"type":"string"}}}"#)]))
        let f = app.newFlow(name: "F", body: try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "c", "do": "changes.it"]]]))
        _ = try await Actions_UI.handle(Arguments(["op": "param", "flow": f.id, "step": "c", "name": "filter.status", "text": "open"]), app)
        #expect(input(f, app)["filter.status"] == .string("open"))
    }

    @Test func aNumberIsOnlyWhatPlainlyIsOne() {
        #expect(Editing.number("12") == 12)
        #expect(Editing.number("-3.5") == -3.5)
        #expect(Editing.number("1,5") == 1.5)
        #expect(Editing.number("1,234") == nil, "a thousand or one and a bit: not a guess")
        #expect(Editing.number("0x10") == nil)
        #expect(Editing.number("many") == nil)
        #expect(Editing.number("1e400") == nil)
    }

    @Test func aWholeNumberWrittenWithAPointIsStillOneForAnInteger() async throws {
        let w = try World()
        w.catalog.use(Actions.Listing(tools: [Actions.Tool(name: "changes.it", title: "Change it", schema: Self.schema)]))
        let flow = try w.flow([["id": "n", "text": "12.0"], ["id": "t", "text": "1,234"], ["id": "c", "do": "changes.it", "with": ["text": "x", "count": "{{n}}"]], ["id": "d", "do": "changes.it", "with": ["text": "y", "count": "{{t}}"]]])
        _ = await w.settled(w.engine.start(flow, mode: .live, why: "t"))
        let calls = w.host.calls.filter { $0.tool == "changes.it" }
        #expect(calls.first?.input["count"] as? Int == 12)
        #expect(calls.last?.input["count"] as? String == "1,234", "as it is, for Sidefolk to refuse: never 1.234")
    }

    @Test func wordsAnAgentStoredAreShownAsWhatsSent() throws {
        let w = try World()
        let app = try app(w)
        let f = app.newFlow(name: "F", body: try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "c", "do": "changes.it", "with": ["text": "x", "urgent": "yes", "count": "12", "tags": "one", "mode": "fast"]]]]))
        let shown = form(f, app)
        for value in ["\"yes\"", "\"12\"", "\"one\""] { #expect(shown.contains(value) || shown.contains(value.replacingOccurrences(of: "\"", with: "")), "\(value) in \(shown)") }
        #expect(!shown.contains("Use a value from an earlier step") || shown.contains("Write it here instead"))
    }

    @Test func aYesOrNoTypedAsAValueIsThat() async throws {
        let w = try World()
        let app = try app(w)
        let f = try flow(app)
        _ = try await Actions_UI.handle(Arguments(["op": "param", "flow": f.id, "step": "c", "name": "urgent", "text": "yes"]), app)
        #expect(input(f, app)["urgent"] == .bool(true), "not false")
        _ = try await Actions_UI.handle(Arguments(["op": "param", "flow": f.id, "step": "c", "name": "urgent", "text": "maybe"]), app)
        #expect(input(f, app)["urgent"] == .string("maybe"), "kept to be seen, and refused when it runs, rather than quietly false")
    }

    @Test func aFieldSaysWhatItWouldBeGoingByTheLastRun() async throws {
        let w = try World()
        let app = try app(w)
        w.host.answers["reads.it"] = [Actions.Outcome(status: .ok, text: "Looked", summary: "", data: #"{"total": 2, "who": "Sam"}"#)]
        let f = app.newFlow(name: "F", body: try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "r", "do": "reads.it"], ["id": "c", "do": "changes.it", "with": ["text": "Hi {{r.who}}"]]]]))
        #expect(!form(f, app).contains("Last time"), "nothing to go by yet")
        let run = try #require(app.engine.start(f, mode: .practice, why: "t"))
        await w.quiet(app.store)
        #expect(app.store.run(run.id)?.status == .done)
        let shown = form(f, app)
        #expect(shown.contains("Hi Sam"), "\(shown)")
        #expect(w.host.calls.filter { $0.tool == "changes.it" }.isEmpty, "a look, with nothing run")
        #expect(shown.contains("Sam"), "a value on offer says what it was")
    }

    @Test func aFieldThatsMissingFromTheLastRunSaysNothingRatherThanABlank() async throws {
        let w = try World()
        let app = try app(w)
        w.host.answers["reads.it"] = [Actions.Outcome(status: .ok, text: "Looked", summary: "", data: #"{"total": 2}"#)]
        let f = app.newFlow(name: "F", body: try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "r", "do": "reads.it"], ["id": "c", "do": "changes.it", "with": ["text": "Hi {{r.nope}}"]]]]))
        _ = app.engine.start(f, mode: .practice, why: "t")
        await w.quiet(app.store)
        #expect(!form(f, app).contains("Last time"))
    }
}
