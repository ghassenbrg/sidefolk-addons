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
        #expect(Editing.number("1,5") == nil, "written plainly, it's 1.5")
        #expect(Editing.number("1,234") == nil, "a thousand or one and a bit: not a guess")
        #expect(Editing.number("0x10") == nil)
        #expect(Editing.number("many") == nil)
        #expect(Editing.number("1e400") == nil)
        #expect(Editing.number(".5") == nil)
        #expect(Editing.number("+5") == nil)
    }

    /// One changes.it after an earlier step made `made`, its result going in as `with`.
    private func refused(_ with: [String: Any], made: String = "x") async throws -> (run: Run, sent: [[String: Any]]) {
        let w = try World()
        w.catalog.use(Actions.Listing(tools: [Actions.Tool(name: "changes.it", title: "Change it", schema: Self.schema)]))
        let flow = try w.flow([["id": "n", "text": made], ["id": "c", "do": "changes.it", "with": with]])
        let run = try #require(await w.settled(w.engine.start(flow, mode: .live, why: "t")))
        return (run, w.host.calls.filter { $0.tool == "changes.it" }.map(\.input))
    }

    @Test func aCountIsAWholeNumberAndNothingElse() async throws {
        for words in ["1.000", "12.0", "1,234", "1e3", "many"] {
            let (run, sent) = try await refused(["text": "x", "count": "{{n}}"], made: words)
            #expect(sent.isEmpty, "\(words) never reaches it")
            #expect(run.status == .failed)
            #expect(run.problem?.contains(words) == true && run.problem?.contains("Count") == true, "\(run.problem ?? "")")
        }
        let (_, sent) = try await refused(["text": "x", "count": "{{n}}"], made: "12")
        #expect(sent.first?["count"] as? Int == 12)
        let (_, written) = try await refused(["text": "x", "count": "1.000"])
        #expect(written.isEmpty, "written out the same")
    }

    @Test func aPersonTypingACountHasToTypeOne() async throws {
        let w = try World()
        let app = try app(w)
        let flow = try flow(app)
        for words in ["1.000", "12.5", "1e3"] {
            await #expect(throws: Problem.self) { _ = try await Actions_UI.handle(Arguments(["op": "param", "flow": flow.id, "step": "c", "name": "count", "text": words]), app) }
        }
        _ = try await Actions_UI.handle(Arguments(["op": "param", "flow": flow.id, "step": "c", "name": "count", "text": "12"]), app)
        guard case .action(_, let input)? = app.store.flow(flow.id)?.draft.step("c")?.kind else { Issue.record("not a step"); return }
        #expect(input["count"] == .number(12))
    }

    @Test func aListEntryThatCameBackWithNothingStopsIt() async throws {
        let w = try World()
        w.catalog.use(Actions.Listing(tools: [Actions.Tool(name: "reads.it", title: "Read it", schema: #"{"properties":{}}"#, mutates: false, readsOnly: true), Actions.Tool(name: "changes.it", title: "Change it", schema: Self.schema)]))
        w.host.answers["reads.it"] = [Actions.Outcome(status: .ok, text: #"{"n":null}"#, summary: "")]
        for tags: Any in ["one, {{r.n}}", ["one", "{{r.n}}"]] {
            w.host.answers["reads.it"] = [Actions.Outcome(status: .ok, text: #"{"n":null}"#, summary: "")]
            let flow = try w.flow([["id": "r", "do": "reads.it"], ["id": "c", "do": "changes.it", "with": ["text": "x", "tags": tags]]])
            let run = try #require(await w.settled(w.engine.start(flow, mode: .live, why: "t")))
            #expect(run.status == .failed, "\(tags)")
            #expect(!w.host.calls.contains { $0.tool == "changes.it" }, "a null never reaches the tool: \(tags)")
        }
    }

    @Test func aListInsideAListStopsIt() async throws {
        let w = try World()
        w.catalog.use(Actions.Listing(tools: [Actions.Tool(name: "reads.it", title: "Read it", schema: #"{"properties":{}}"#, mutates: false, readsOnly: true), Actions.Tool(name: "changes.it", title: "Change it", schema: Self.schema)]))
        w.host.answers["reads.it"] = [Actions.Outcome(status: .ok, text: #"{"tags":["a","b"]}"#, summary: "")]
        let flow = try w.flow([["id": "x", "do": "reads.it"], ["id": "c", "do": "changes.it", "with": ["text": "y", "tags": "one, {{x.tags}}"]]])
        let run = try #require(await w.settled(w.engine.start(flow, mode: .live, why: "t")))
        #expect(run.status == .failed)
        #expect(run.problem?.contains("Tags") == true, "\(run.problem ?? "")")
        #expect(!w.host.calls.contains { $0.tool == "changes.it" }, "not flattened, not sent")
    }

    @Test func onlyCommasIsNothingAndNeverAnEmptyList() async throws {
        let (run, sent) = try await refused(["text": "x", "tags": ","])
        #expect(run.status == .done, "it can go without: \(run.problem ?? "")")
        #expect(sent.first?["tags"] == nil, "left out, not []")
        for words in [",", " , ", ",,"] { #expect(Editing.value(words, for: Catalog.Parameter(name: "t", kind: .list, required: false, title: "T")) == nil) }

        let w = try World()
        w.catalog.use(Actions.Listing(tools: [Actions.Tool(name: "changes.it", title: "Change it", schema: #"{"properties":{"tags":{"type":"array","items":{"type":"string"}}},"required":["tags"]}"#)]))
        let flow = try w.flow([["id": "c", "do": "changes.it", "with": ["tags": ","]]])
        let needed = try #require(await w.settled(w.engine.start(flow, mode: .live, why: "t")))
        #expect(needed.status == .failed, "it can't")
        #expect(needed.problem?.contains("Tags") == true, "\(needed.problem ?? "")")
        #expect(w.host.calls.isEmpty)
    }

    @Test func aBlankWhereItCantGoWithoutOneStopsIt() async throws {
        let w = try World()
        w.catalog.use(Actions.Listing(tools: [Actions.Tool(name: "reads.it", title: "Read", schema: #"{"properties":{}}"#, mutates: false, readsOnly: true), Actions.Tool(name: "changes.it", title: "Change", schema: #"{"properties":{"i":{"type":"integer"}},"required":["i"]}"#)]))
        w.host.answers["reads.it"] = [Actions.Outcome(status: .ok, text: #"{"x":""}"#, summary: "")]
        let flow = try w.flow([["id": "r", "do": "reads.it"], ["id": "c", "do": "changes.it", "with": ["i": "{{r.x}}"]]])
        let run = try #require(await w.settled(w.engine.start(flow, mode: .live, why: "t")))
        #expect(run.status == .failed)
        #expect(!w.host.calls.contains { $0.tool == "changes.it" })
    }

    @Test func nothingIsntEnoughWhereItsNeededWhateverTheSchemaSays() async throws {
        for schema in [#"{"anyOf":[{"type":"integer"},{"type":"null"}]}"#, #"{"type":"integer"}"#] {
            let w = try World()
            w.catalog.use(Actions.Listing(tools: [Actions.Tool(name: "changes.it", title: "Change", schema: #"{"properties":{"parent":"# + schema + #"},"required":["parent"]}"#)]))
            let flow = try w.flow([["id": "c", "do": "changes.it", "with": ["parent": NSNull()]]])
            let run = try #require(await w.settled(w.engine.start(flow, mode: .live, why: "t")))
            #expect(run.status == .failed, "Sidefolk counts it as missing, and this says so plainly: \(schema)")
            #expect(run.problem?.contains("Parent") == true, "\(run.problem ?? "")")
            #expect(w.host.calls.isEmpty, "\(schema)")
        }
    }

    @Test func aBlankForSomethingItCanGoWithoutIsLeftOut() async throws {
        let w = try World()
        w.catalog.use(Actions.Listing(tools: [Actions.Tool(name: "reads.it", title: "Read", schema: #"{"properties":{}}"#, mutates: false, readsOnly: true), Actions.Tool(name: "changes.it", title: "Change it", schema: Self.schema)]))
        w.host.answers["reads.it"] = [Actions.Outcome(status: .ok, text: #"{"x":""}"#, summary: "")]
        let flow = try w.flow([["id": "r", "do": "reads.it"], ["id": "t", "text": ""], ["id": "c", "do": "changes.it", "with": ["text": "x", "tags": "{{r.x}}", "count": "{{t}}"]]])
        let run = try #require(await w.settled(w.engine.start(flow, mode: .live, why: "t")))
        #expect(run.status == .done, "\(run.problem ?? "")")
        let sent = try #require(w.host.calls.first { $0.tool == "changes.it" }?.input)
        #expect(sent["tags"] == nil, "left out: not [\"\"], not a blank, not a null")
        #expect(sent["count"] == nil)
    }

    @Test func anEmptyRecordSaidOnPurposeStaysOne() async throws {
        let w = try World()
        w.catalog.use(Actions.Listing(tools: [Actions.Tool(name: "changes.it", title: "Change it", schema: #"{"properties":{"to":{"type":"object","properties":{"city":{"type":"string"}}}}}"#)]))
        let flow = try w.flow([["id": "c", "do": "changes.it", "with": ["to": [String: Any]()]]])
        _ = await w.settled(w.engine.start(flow, mode: .live, why: "t"))
        #expect((w.host.calls.first?.input["to"] as? [String: Any])?.isEmpty == true)
        // What it needs inside is still needed.
        let other = try World()
        other.catalog.use(Actions.Listing(tools: [Actions.Tool(name: "changes.it", title: "Change it", schema: Self.schema)]))
        let wanting = try other.flow([["id": "c", "do": "changes.it", "with": ["text": "x", "to": [String: Any]()]]])
        #expect(try #require(await other.settled(other.engine.start(wanting, mode: .live, why: "t"))).status == .failed)
    }

    @Test func blankWordsWhereTheyreNeededStopItPlainly() async throws {
        let (run, sent) = try await refused(["text": "{{n}}"], made: "x")
        #expect(sent.count == 1, "with words it goes")
        #expect(run.status == .done)
        let w = try World()
        w.catalog.use(Actions.Listing(tools: [Actions.Tool(name: "changes.it", title: "Change it", schema: Self.schema)]))
        let flow = try w.flow([["id": "t", "text": ""], ["id": "c", "do": "changes.it", "with": ["text": "{{t}}"]]])
        let blank = try #require(await w.settled(w.engine.start(flow, mode: .live, why: "t")))
        #expect(blank.status == .failed)
        #expect(blank.problem?.contains("Text") == true, "\(blank.problem ?? "")")
        #expect(!w.host.calls.contains { $0.tool == "changes.it" }, "nothing ran, so nothing may have happened")
        #expect(blank.record(of: "c")?.status == .failed, "not “may or may not have happened”")
    }

    @Test func wordsCutOnTheWayAreSaid() async throws {
        for mode in [Run.Mode.live, .practice] {
            let w = try World()
            w.catalog.use(Actions.Listing(tools: [Actions.Tool(name: "changes.it", title: "Change it", schema: Self.schema)]))
            let flow = try w.flow([["id": "n", "text": String(repeating: "x", count: Values.wordsKept + 1)], ["id": "c", "do": "changes.it", "with": ["text": "{{n}}"]]])
            let run = try #require(await w.settled(w.engine.start(flow, mode: mode, why: "t")))
            let note = (run.record(of: "c")?.note ?? "").filter { !"\u{2068}\u{2069}".contains($0) }
            #expect(note.contains("cut to 8,000 characters"), "\(mode): \(note)")
            #expect(note.contains("Text"), "\(mode): \(note)")
            if mode == .live { #expect((w.host.calls.first { $0.tool == "changes.it" }?.input["text"] as? String)?.count == Values.wordsKept) }
        }
    }

    @Test func whatsSaidAboutCuttingIsAboutWhatsSent() async throws {
        let w = try World()
        w.catalog.use(Actions.Listing(tools: [Actions.Tool(name: "reads.it", title: "Read", schema: #"{"properties":{}}"#, mutates: false, readsOnly: true), Actions.Tool(name: "changes.it", title: "Change it", schema: Self.schema)]))
        let long = String(repeating: "x", count: Values.wordsKept + 1)
        // A tool's words are what `{{r}}` sends, whatever its fields hold.
        w.host.answers["reads.it"] = [Actions.Outcome(status: .ok, text: long, summary: "", data: #"{"n":3}"#)]
        let wordy = try w.flow([["id": "r", "do": "reads.it"], ["id": "c", "do": "changes.it", "with": ["text": "{{r}}"]]])
        let cut = try #require(await w.settled(w.engine.start(wordy, mode: .live, why: "t")))
        #expect(cut.record(of: "c")?.note?.contains("cut to") == true)
        w.host.answers["reads.it"] = [Actions.Outcome(status: .ok, text: "Found 3", summary: "", data: "{\"n\":\"\(long)\"}")]
        let brief = try w.flow([["id": "r", "do": "reads.it"], ["id": "c", "do": "changes.it", "with": ["text": "{{r}}"]]])
        let whole = try #require(await w.settled(w.engine.start(brief, mode: .live, why: "t")))
        #expect(whole.record(of: "c")?.note == nil, "its fields weren't sent")
    }

    @Test func whatWasntSentWasntCut() async throws {
        let w = try World()
        w.catalog.use(Actions.Listing(tools: [Actions.Tool(name: "changes.it", title: "Change it", schema: Self.schema)]))
        w.host.answers["changes.it"] = [Actions.Outcome(status: .denied, text: "No", summary: "")]
        let flow = try w.flow([["id": "n", "text": String(repeating: "x", count: Values.wordsKept + 1)], ["id": "c", "do": "changes.it", "with": ["text": "{{n}}"]]])
        let run = try #require(await w.settled(w.engine.start(flow, mode: .live, why: "t")))
        #expect(run.record(of: "c")?.note?.contains("cut to") != true, "\(run.record(of: "c")?.note ?? "")")
    }

    @Test func blankWordsInsideARecordCanBeWhatsMeant() async throws {
        let w = try World()
        w.catalog.use(Actions.Listing(tools: [Actions.Tool(name: "changes.it", title: "Change", schema: #"{"properties":{"change":{"type":"object","properties":{"replace":{"type":"string"}},"required":["replace"]}}}"#)]))
        let flow = try w.flow([["id": "c", "do": "changes.it", "with": ["change": ["replace": ""]]]])
        let run = try #require(await w.settled(w.engine.start(flow, mode: .live, why: "t")))
        #expect(run.status == .done, "\(run.problem ?? "")")
        #expect((w.host.calls.first?.input["change"] as? [String: Any])?["replace"] as? String == "")
    }

    @Test func wordsAreANumberOnlyWhenWrittenPlainly() {
        for (words, value) in [("12", 12.0), ("-3", -3), ("12.5", 12.5), ("0", 0), ("0.5", 0.5), ("-0.25", -0.25), ("  7  ", 7), ("1000", 1000), ("1234.567", 1234.567), ("12.50", 12.5), ("0.500", 0.5), ("100000000000000", 1e14)] {
            #expect(NumberWords.read(words) == .number(value), "\(words)")
        }
        // Everything that was read before, and everything a read found wrong: none of it is plainly one number.
        let others = ["18 °C", "$1,299.00", "12%", "CPU: 12%", "Rain at 18", "12 apples", "5 EUR", "1 GB", "Ports: 80,81", "Color: 255,255,255", "100,200,300", "Version: 1.2", "Down: 5%", "Minus: 5", "1,5", "1.299,50", "1,000", "1,000,000", "1.000", "1.500", "1.299", "3.142", "1.000.000", "192.168.100.200", "1.2.3", "5e3", "1e-05", "1.5e3", "12E-5", "0x10", "nan", "inf", "+3", "--5", "- 5", "−5", "–5", ".5", "5.", ",5", "007", "05.11", "00", "1 299", "100 200", "10:30", "2026-11-05", "(5)", "5k", "5M", "٣٠٠", "１２３", "1234567890123456", "1.1234567890123456"]
        for words in others { #expect(NumberWords.read(words) == .unreadable || NumberWords.read(words) == .none, "\(words)") }
        for words in ["", "   ", "many", "three", "三百", "٣٠٠"] { #expect(NumberWords.read(words) == .none, "\(words)") }
    }

    @Test func aNumberAToolGaveAsANumberIsThatNumberHoweverItLooks() {
        var values = Values()
        values.set("price", JSON.object(["n": .number(1.125), "words": .string("1.125")]))
        #expect(Condition(value: "{{price.n}}", test: .more_than, than: "1").holds(values))
        #expect(Condition(value: "{{price.n}}", test: .more_than, than: "1").doubtful(values) == nil)
        #expect(Condition(value: "{{price.words}}", test: .more_than, than: "1").doubtful(values) == "1.125", "words aren't")
        #expect(Condition(value: "about {{price.n}}", test: .more_than, than: "1").doubtful(values) != nil, "nor is a sentence with one in it")
    }

    @Test func aStepThatReadsANumberFromWordsIsMarkedBeforeARealRun() throws {
        let w = try World()
        let app = try app(w)
        func marked(_ steps: [[String: Any]]) throws -> Set<String> { try w.flow(steps).draft.readsNumbersFromWords(app.catalog) }
        func check(_ value: String, than: String = "5") -> [String: Any] { ["id": "c", "if": ["value": value, "test": "more_than", "than": than], "then": [["id": "y", "text": "yes"]]] }
        let source: [[String: Any]] = [["id": "t", "text": "Rain at 18"], ["id": "n", "text": "18"], ["id": "r", "do": "reads.it"], ["id": "a", "ai": "How many?", "fields": ["n": "number", "w": "text"]], ["id": "s", "data": ["op": "sum", "from": "{{r.rows}}", "field": "n"]]]
        for value in ["{{t}}", "{{r}}", "{{a}}", "{{a.w}}", "about {{r.n}}", "{{r.n}} {{a.n}}", "{{nobody}}", "12 apples", "18 °C"] {
            #expect(try marked(source + [check(value)]) == ["c"], "\(value)")
        }
        for value in ["{{n}}", "{{r.n}}", "{{a.n}}", "{{s}}", "12"] {
            #expect(try marked(source + [check(value)]) == [], "\(value)")
        }
        #expect(try marked(source + [check("{{a.n}}", than: "1.500")]) == ["c"], "its other side too")
        #expect(try marked(source + [["id": "c", "if": ["value": "{{t}}", "test": "contains", "than": "Rain"], "then": [["id": "y", "text": "yes"]]]]) == [], "only what compares a number")
        #expect(try marked(source + [["id": "d", "data": ["op": "sum", "from": "{{r}}"]]]) == ["d"])
        #expect(try marked(source + [["id": "d", "data": ["op": "sum", "from": "{{r}}", "field": "n"]]]) == [])
        #expect(try marked(source + [["id": "d", "data": ["op": "number", "from": "{{r}}"]]]) == ["d"])
        #expect(try marked(source + [["id": "d", "data": ["op": "filter", "from": "{{r}}", "field": "n", "test": "less_than", "than": "many"]]]) == ["d"])
        #expect(try marked(source + [["id": "again", "repeat": [["id": "p", "text": "words"]], "until": ["value": "{{p}}", "test": "more_than", "than": "5"], "times": 3]]) == ["again"])
        // It holds nothing up: it isn't a problem, and it can still be turned on.
        #expect(try w.flow(source + [check("{{t}}")]).draft.problems(app.catalog).isEmpty)
    }

    @Test func aStopForWordsThatArentOneNumberSaysTheWordsAndWhatToDo() async throws {
        let w = try World()
        let flow = try w.flow([["id": "p", "text": "Rain at 18"], ["id": "b", "name": "Check it", "if": ["value": "{{p}}", "test": "more_than", "than": "5"], "then": [["id": "y", "text": "yes"]]]])
        let run = try #require(w.engine.start(flow, mode: .live, why: "t"))
        await w.quiet()
        let ended = try #require(w.store.run(run.id))
        #expect(ended.status == .failed)
        for words in ["Check it", "Rain at 18", "tool's field"] { #expect(ended.problem?.contains(words) == true, "\(words)") }
    }

    @Test func onlyThePagesOwnFieldsAnswerAForm() async throws {
        let w = try World()
        let app = try app(w)
        app.engine.host = w.host
        let flow = app.newFlow(name: "F", body: try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "f", "form": ["title": "W", "fields": [["name": "who", "label": "Who", "kind": "text", "required": true]]]], ["id": "t", "text": "{{f.who}}"]]]))
        let run = try #require(app.engine.start(flow, mode: .practice, why: "t").map(\.id).flatMap(app.store.run))
        guard var waiting = app.store.run(run.id) else { return }
        waiting.status = .waiting
        waiting.form = .init(step: "f")
        app.store.save(waiting)
        _ = try await Actions_UI.handle(Arguments(["op": "form_field", "run": run.id, "name": "who", "text": "words from a page"]), app)
        #expect(app.store.run(run.id)?.form?.answers["who"] == nil, "with no token, nothing is kept")
        _ = try await Actions_UI.handle(Arguments(["op": "form_field", "run": run.id, "name": "who", "text": "words from a page", "page_token": "guess"]), app)
        #expect(app.store.run(run.id)?.form?.answers["who"] == nil)
        _ = try await Actions_UI.handle(Arguments(["op": "form_send", "run": run.id]), app)
        #expect(app.store.run(run.id)?.form != nil, "and it isn't sent")
        _ = try await Actions_UI.handle(Arguments(["op": "form_field", "run": run.id, "name": "who", "text": "Sam", "page_token": app.pageKey]), app)
        #expect(app.store.run(run.id)?.form?.answers["who"] == .string("Sam"), "the page's own does")
    }

    @Test func aNumberFieldTakesOnlyWhatPlainlyIsOne() {
        for words in ["1.000", "12.000", "1.500", "1,000", "12,5", "1e3", "abc", "$5"] { #expect(Editing.number(words) == nil, "\(words)") }
        for (words, value) in [("1.299", 1.299), ("12.5", 12.5), ("0.500", 0.5), ("12", 12.0), ("-3", -3.0)] { #expect(Editing.number(words) == value, "typed: \(words)") }
        for words in ["1.299", "$5", "12 apples", "1e3", "12,5"] { #expect(Editing.number(fromWords: words) == nil, "from a step nobody's there to mean it: \(words)") }
        for (words, value) in [("12.5", 12.5), ("0.500", 0.5), ("12", 12.0)] { #expect(Editing.number(fromWords: words) == value, "\(words)") }
        #expect(Editing.couldBeMoreThanOne("12,5") && Editing.couldBeMoreThanOne("1e3") && !Editing.couldBeMoreThanOne("abc") && !Editing.couldBeMoreThanOne("12"))
    }

    @Test func aConditionThatCantTellSaysSoRatherThanGoingOneWay() async throws {
        for (made, than) in [("1,500", "2000"), ("12.000", "10"), ("5", "1,000")] {
            let w = try World()
            let flow = try w.flow([["id": "p", "text": made], ["id": "b", "name": "Check price", "if": ["value": "{{p}}", "test": "less_than", "than": than], "then": [["id": "y", "text": "yes"]], "else": [["id": "n", "text": "no"]]]])
            let run = try #require(await w.settled(w.engine.start(flow, mode: .live, why: "t")))
            #expect(run.status == .failed, "\(made) \(than): \(run.status)")
            let said = (run.problem ?? "").filter { !"\u{2068}\u{2069}".contains($0) }
            #expect(said.contains("as one number") && said.contains("tool's field") && said.contains("Check price"), "it names the step: \(said)")
            #expect(said.contains(made) || said.contains(than), "and the words: \(said)")
            #expect(run.record(of: "y") == nil && run.record(of: "n") == nil, "neither way")
        }
        let w = try World()
        let flow = try w.flow([["id": "p", "text": "1299.50"], ["id": "b", "if": ["value": "{{p}}", "test": "less_than", "than": "2000"], "then": [["id": "y", "text": "yes"]], "else": [["id": "n", "text": "no"]]]])
        let run = try #require(await w.settled(w.engine.start(flow, mode: .live, why: "t")))
        #expect(run.record(of: "y") != nil, "that one's plain")
        // Words that aren't compared as numbers aren't its business.
        #expect(Condition(value: "1,500", test: .contains, than: "500").doubtful(Values()) == nil)
    }

    @Test func aRepeatThatCantTellSaysSo() async throws {
        let w = try World()
        let flow = try w.flow([["id": "again", "name": "Keep checking", "repeat": [["id": "p", "text": "1,500"]], "until": ["value": "{{p}}", "test": "more_than", "than": "2000"], "times": 3]])
        let run = try #require(await w.settled(w.engine.start(flow, mode: .live, why: "t")))
        #expect(run.status == .failed)
        #expect(run.problem?.contains("as one number") == true && run.problem?.contains("Keep checking") == true, "\(run.problem ?? "")")
        #expect(run.records.filter { $0.step == "p" }.count == 1, "it didn't go round on a guess")
    }

    @Test func aFilterThatCantTellSaysSo() async throws {
        let w = try World()
        let flow = try w.flow([["id": "d", "name": "Pick cheap ones", "data": ["op": "filter", "from": #"["1,500","10"]"#, "test": "less_than", "than": "2000"]]])
        let run = try #require(await w.settled(w.engine.start(flow, mode: .live, why: "t")))
        #expect(run.status == .failed)
        #expect(run.problem?.contains("1,500") == true && run.problem?.contains("Pick cheap ones") == true, "\(run.problem ?? "")")
    }

    @Test func aWordThatIsntOneOfTheChoicesIsSaid() async throws {
        let (run, sent) = try await refused(["text": "x", "mode": "{{n}}"], made: "High")
        #expect(sent.isEmpty)
        #expect(run.status == .failed)
        #expect(run.problem?.contains("High") == true && run.problem?.contains("fast") == true, "\(run.problem ?? "")")
        let (fine, went) = try await refused(["text": "x", "mode": "{{n}}"], made: "fast")
        #expect(fine.status == .done)
        #expect(went.first?["mode"] as? String == "fast")
    }

    @Test func aDataStepDoesntGuessEither() async throws {
        for op: [String: Any] in [["op": "number", "from": "1,000"], ["op": "sum", "from": #"["1,000","2"]"#]] {
            let w = try World()
            let flow = try w.flow([["id": "d", "data": op], ["id": "s", "text": "went on"]])
            let run = try #require(await w.settled(w.engine.start(flow, mode: .live, why: "t")))
            #expect(run.status == .failed, "\(op)")
            #expect(run.problem?.contains("1,000") == true, "\(run.problem ?? "")")
        }
    }

    @Test func aFormsNumberIsntAGuess() async throws {
        let w = try World()
        let app = try app(w)
        let flow = app.newFlow(name: "Asked", body: try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "f", "form": ["title": "T", "fields": [["name": "n", "label": "N", "kind": "number"]]]]]]))
        let run = try #require(app.engine.start(flow, mode: .once, why: "t"))
        await w.quiet(app.store)
        for words in ["1,000", "1.000"] {
            #expect(throws: Problem.self, "\(words)") { try app.engine.answer(run: run.id, form: ["n": .string(words)]) }
        }
        try app.engine.answer(run: run.id, form: ["n": .string("1000")])
        await w.quiet(app.store)
        #expect(app.store.run(run.id)?.values.named["f"] == .object(["n": .number(1000)]))
    }

    @Test func aHugeNumberFromAToolIsntACount() async throws {
        let w = try World()
        w.catalog.use(Actions.Listing(tools: [Actions.Tool(name: "reads.it", title: "Read", schema: #"{"properties":{}}"#, mutates: false, readsOnly: true), Actions.Tool(name: "changes.it", title: "Change it", schema: Self.schema)]))
        w.host.answers["reads.it"] = [Actions.Outcome(status: .ok, text: #"{"n":12345678901234567890}"#, summary: "")]
        let flow = try w.flow([["id": "r", "do": "reads.it"], ["id": "c", "do": "changes.it", "with": ["text": "x", "count": "{{r.n}}"]]])
        let run = try #require(await w.settled(w.engine.start(flow, mode: .live, why: "t")))
        #expect(run.status == .failed)
        #expect(!w.host.calls.contains { $0.tool == "changes.it" })
    }

    @Test func wordsThatFitSayNothing() async throws {
        let w = try World()
        w.catalog.use(Actions.Listing(tools: [Actions.Tool(name: "changes.it", title: "Change it", schema: Self.schema)]))
        let flow = try w.flow([["id": "n", "text": String(repeating: "x", count: Values.wordsKept)], ["id": "c", "do": "changes.it", "with": ["text": "{{n}}"]]])
        let run = try #require(await w.settled(w.engine.start(flow, mode: .live, why: "t")))
        #expect(run.record(of: "c")?.note == nil)
    }

    @Test func anEmptyListSaidOnPurposeStaysOne() async throws {
        let (run, sent) = try await refused(["text": "x", "tags": [String]()])
        #expect(run.status == .done)
        #expect((sent.first?["tags"] as? [Any])?.isEmpty == true)
    }

    @Test func aFieldThatsWrongIsSaidInPlainWords() async throws {
        let (run, sent) = try await refused(["text": "x", "urgent": "{{n}}"], made: "perhaps")
        #expect(sent.isEmpty)
        #expect(run.problem?.contains("perhaps") == true, "\(run.problem ?? "")")
    }

    @Test func wordsAnAgentStoredAreShownAsWhatsSent() throws {
        let w = try World()
        let app = try app(w)
        let f = app.newFlow(name: "F", body: try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "c", "do": "changes.it", "with": ["text": "x", "urgent": "yes", "count": "12", "tags": "one", "mode": "fast"]]]]))
        let shown = form(f, app)
        for value in ["\"yes\"", "\"12\"", "\"one\""] { #expect(shown.contains(value) || shown.contains(value.replacingOccurrences(of: "\"", with: "")), "\(value) in \(shown)") }
        #expect(!shown.contains("Use a value from an earlier step") || shown.contains("Write it here instead"))
    }

    @Test func wordsStoredForAListGoAsTypingThemWouldSendThem() async throws {
        let w = try World()
        w.catalog.use(Actions.Listing(tools: [Actions.Tool(name: "changes.it", title: "Change it", schema: Self.schema)]))
        let flow = try w.flow([["id": "n", "text": "Smith, John"],
                               ["id": "a", "do": "changes.it", "with": ["text": "x", "tags": "one, two"]],
                               ["id": "b", "do": "changes.it", "with": ["text": "y", "tags": "one"]],
                               ["id": "c", "do": "changes.it", "with": ["text": "z", "tags": "{{n}}"]],
                               ["id": "d", "do": "changes.it", "with": ["text": "v", "tags": "one, {{n}}"]]])
        _ = await w.settled(w.engine.start(flow, mode: .live, why: "t"))
        let sent = w.host.calls.filter { $0.tool == "changes.it" }.map { $0.input["tags"] as? [String] }
        #expect(sent == [["one", "two"], ["one"], ["Smith, John"], ["one", "Smith, John"]], "a value from a step is one entry")
    }

    @Test func aFieldShowsWhatItHoldsWhateverItHolds() throws {
        let w = try World()
        let app = try app(w)
        let f = app.newFlow(name: "F", body: try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "c", "do": "changes.it", "with": ["text": 42]]]]))
        #expect(form(f, app).contains("42"), "a number in a words field isn't a blank")
        let g = app.newFlow(name: "G", body: try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "c", "do": "changes.it", "with": ["text": "x", "tags": ["one", "two"]]]]]))
        app.nav.useValue(true, flow: g.id, step: "c", parameter: "tags")
        let shown = form(g, app)
        #expect(shown.contains("one, two") && !shown.contains("[\"one\""), "a list is shown as it's typed, either way")
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
