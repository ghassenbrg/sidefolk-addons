import Foundation
import Testing
@testable import ext_sideflow
import SidefolkExtensionKit

/// A flow says what it takes and gives, and a call can stay on one of its versions.
@MainActor @Suite(.serialized) struct SideflowCalledFlowTests {
    typealias World = SideflowTests.World

    private func callee(_ w: World, name: String = "Pay", steps: [[String: Any]], inputs: [[String: Any]] = [], output: String? = nil) throws -> Flow {
        var definition: [String: Any] = ["trigger": ["type": "manual"], "steps": steps]
        if !inputs.isEmpty { definition["inputs"] = inputs }
        if let output { definition["output"] = output }
        var flow = Flow(id: UUID().uuidString.lowercased(), name: name, draft: try FlowCodec.body(definition), state: .on, createdAt: w.now, updatedAt: w.now)
        flow.live = flow.draft
        w.store.save(flow)
        return flow
    }

    private func runs(_ w: World, _ caller: Flow) async throws -> Run {
        let run = try #require(w.engine.start(caller, mode: .live, why: "t"))
        await w.quiet()
        return try #require(w.store.run(run.id))
    }

    @Test func whatPlainlyIsWhatItWantsIsMadeThat() async throws {
        let w = try World()
        _ = try callee(w, steps: [["id": "a", "text": "ok"], ["finish": "{{input.count}}"]], inputs: [["name": "count", "type": "number"], ["name": "note", "required": false]], output: "number")
        let caller = try w.flow([["id": "t", "text": "12"], ["id": "r", "call_flow": "Pay", "inputs": ["count": "{{t}}"]], ["id": "d", "data": ["op": "sum", "from": "[{{r}}, 1]"]]])
        let back = try await runs(w, caller)
        #expect(back.status == .done, "\(back.problem ?? "")")
        #expect(back.values.named["r"] == .number(12), "a number, for what comes after")
    }

    @Test func wordsThatCouldBeAThousandDontBecomeOneOnTheWay() async throws {
        let w = try World()
        w.catalog.use(Actions.Listing(tools: [Actions.Tool(name: "changes.it", title: "Change it", schema: #"{"properties":{"count":{"type":"integer"}}}"#)]))
        _ = try callee(w, steps: [["id": "c", "do": "changes.it", "with": ["count": "{{input.n}}"]]], inputs: [["name": "n", "type": "number"]])
        for words in ["1.000", "12.000"] {
            let caller = try w.flow([["id": "t", "text": words], ["id": "r", "call_flow": "Pay", "inputs": ["n": "{{t}}"]]])
            let back = try await runs(w, caller)
            #expect(back.status == .failed, "\(words)")
            #expect(back.problem?.contains(words) == true, "\(back.problem ?? "")")
        }
        #expect(!w.host.calls.contains { $0.tool == "changes.it" })
        _ = try callee(w, name: "Gives", steps: [["finish": "1.000"]], output: "number")
        #expect(try await runs(w, try w.flow([["id": "r", "call_flow": "Gives"]])).status == .failed)
        #expect(ValueType.number.fit(.string("3.142")) == .number(3.142), "a decimal that's plainly one stays one")
        #expect(ValueType.number.fit(.string("12.50")) == .number(12.5))
    }

    @Test func aRequiredOneLeftOutStopsBeforeItStarts() async throws {
        let w = try World()
        let pay = try callee(w, steps: [["id": "a", "text": "{{input.count}}"]], inputs: [["name": "count", "type": "number"]])
        let caller = try w.flow([["id": "r", "call_flow": "Pay"]])
        let back = try await runs(w, caller)
        #expect(back.status == .failed)
        #expect(back.problem?.contains("count") == true, "\(back.problem ?? "")")
        #expect(w.store.runs(of: pay.id).isEmpty, "it never began")
        #expect(caller.draft.problems(w.catalog).contains { $0.step == "r" }, "and the editor said so")
    }

    @Test func theWrongKindStopsAndSaysWhat() async throws {
        let w = try World()
        let pay = try callee(w, steps: [["id": "a", "text": "{{input.count}}"]], inputs: [["name": "count", "type": "number"]])
        let caller = try w.flow([["id": "t", "text": "many"], ["id": "r", "call_flow": "Pay", "inputs": ["count": "{{t}}"]]])
        let back = try await runs(w, caller)
        #expect(back.status == .failed)
        #expect(back.problem?.contains("many") == true, "\(back.problem ?? "")")
        #expect(w.store.runs(of: pay.id).isEmpty)
    }

    @Test func oneItCanGoWithoutIsThereAsNothing() async throws {
        let w = try World()
        _ = try callee(w, steps: [["id": "a", "text": "note:{{input.note}}"]], inputs: [["name": "note", "required": false]])
        let caller = try w.flow([["id": "r", "call_flow": "Pay"]])
        let back = try await runs(w, caller)
        #expect(back.status == .done, "\(back.problem ?? "")")
    }

    @Test func noneSaidIsAsBefore() async throws {
        let w = try World()
        _ = try callee(w, steps: [["id": "a", "text": "{{input.anything}}"]])
        let caller = try w.flow([["id": "r", "call_flow": "Pay", "inputs": ["anything": "x", "else": "y"]]])
        let back = try await runs(w, caller)
        #expect(back.status == .done, "\(back.problem ?? "")")
        #expect(back.values.value("r") == "x")
        #expect(caller.draft.problems(w.catalog).isEmpty)
    }

    @Test func whatItGivesIsHeldToWhatItSaid() async throws {
        let w = try World()
        _ = try callee(w, steps: [["finish": "lots"]], output: "number")
        let caller = try w.flow([["id": "r", "call_flow": "Pay"]])
        let back = try await runs(w, caller)
        #expect(back.status == .failed)
        #expect(back.problem?.contains("lots") == true, "\(back.problem ?? "")")

        _ = try callee(w, name: "Silent", steps: [["id": "a", "do": "changes.it", "with": ["text": "x"]]], output: "number")
        let other = try w.flow([["id": "r", "call_flow": "Silent"]])
        #expect(try await runs(w, other).status == .failed, "it said it would give one")
    }

    @Test func theEditorCatchesWhatItCan() throws {
        let w = try World()
        _ = try callee(w, steps: [["id": "a", "text": "{{input.count}}"]], inputs: [["name": "count", "type": "number"]])
        func problems(_ inputs: [String: String]) throws -> [String] {
            try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "r", "call_flow": "Pay", "inputs": inputs]]]).problems(w.catalog).map(\.text)
        }
        #expect(try problems(["count": "3"]).isEmpty)
        #expect(try problems(["count": "{{x}}"]).allSatisfy { !$0.contains("Pay") }, "what a value will be isn't known yet")
        #expect(try problems(["count": "lots"]).contains { $0.contains("count") })
        #expect(try problems(["count": "3", "other": "y"]).contains { $0.contains("other") })
        // And inside the flow that said it.
        let own = try FlowCodec.body(["trigger": ["type": "manual"], "inputs": [["name": "a"]], "steps": [["id": "s", "text": "{{input.a}} {{input.b}}"]]])
        #expect(own.problems(w.catalog).contains { $0.text.contains("input.b") })
        #expect(!own.problems(w.catalog).contains { $0.text.contains("input.a") })
    }

    @Test func whatItTakesIsChecked() {
        func body(_ extra: [String: Any]) throws -> FlowBody { try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "s", "text": "x"]]].merging(extra) { _, new in new }) }
        #expect(throws: Problem.self) { try body(["inputs": [["name": "a b"]]]) }
        #expect(throws: Problem.self) { try body(["inputs": [["name": "a", "type": "date"]]]) }
        #expect(throws: Problem.self) { try body(["inputs": [["name": "a"], ["name": "a"]]]) }
        #expect(throws: Problem.self) { try body(["inputs": "a"]) }
        #expect(throws: Problem.self) { try body(["output": "date"]) }
        #expect(throws: Problem.self) { try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "s", "text": "x", "version": 2]]]) }
        #expect(throws: Problem.self) { try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "s", "call_flow": "A", "version": 0]]]) }
    }

    @Test func itComesBackFromAFile() throws {
        let body = try FlowCodec.body(["trigger": ["type": "manual"], "inputs": [["name": "a", "type": "list", "required": false]], "output": "record", "steps": [["id": "s", "call_flow": "A", "version": 2]]])
        let back = try FlowCodec.body(FlowCodec.json(body), saved: true)
        #expect(back == body)
        #expect(back.inputs.first?.type == .list)
        #expect(back.step("s")?.pin == 2)
    }

    @Test func aCallCanStayOnAVersion() async throws {
        let w = try World()
        var pay = try callee(w, steps: [["finish": "old"]])
        let old = try #require(pay.live)
        pay.keep(old, at: w.now, keeping: [])
        pay.live = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["finish": "new"]]])
        w.store.save(pay)
        #expect(pay.version == 2)

        let held = try w.flow([["id": "r", "call_flow": "Pay", "version": 1]])
        #expect(try await runs(w, held).values.value("r") == "old")
        let latest = try w.flow([["id": "r", "call_flow": "Pay"]])
        #expect(try await runs(w, latest).values.value("r") == "new")
        let now = try w.flow([["id": "r", "call_flow": "Pay", "version": 2]])
        #expect(try await runs(w, now).values.value("r") == "new", "the number of what's live is that")
    }

    @Test func aHeldVersionDoesntBringBackAnAIStepNoLongerAllowed() async throws {
        let w = try World()
        var pay = try callee(w, steps: [["id": "x", "ai": "the old words"]])
        pay.keep(try #require(pay.live), at: w.now, keeping: [])
        pay.live = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "x", "ai": "the new words"]]])
        w.store.save(pay)
        let held = try w.flow([["id": "r", "call_flow": "Pay", "version": 1]])
        #expect(held.draft.problems(w.catalog).contains { $0.step == "r" }, "the editor says so")
        let back = try await runs(w, held)
        #expect(back.status == .failed, "not stuck waiting, and not run: \(back.status)")
        #expect(back.problem?.contains("version") == true, "\(back.problem ?? "")")
        #expect(w.store.runs(of: pay.id).isEmpty)
        #expect(!w.host.written.contains { $0.contains("old words") })
    }

    @Test func aHeldVersionWithNothingBeyondWhatsAllowedRuns() async throws {
        let w = try World()
        var pay = try callee(w, steps: [["id": "same", "ai": "same words"], ["finish": "old"]])
        pay.keep(try #require(pay.live), at: w.now, keeping: [])
        pay.live = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "same", "ai": "same words"], ["id": "more", "text": "x"], ["finish": "new"]]])
        w.store.save(pay)
        let held = try w.flow([["id": "r", "call_flow": "Pay", "version": 1]])
        let back = try await runs(w, held)
        #expect(back.status == .done, "\(back.problem ?? "")")
        #expect(back.values.value("r") == "old")
    }

    @Test func aLongNameIsItsWholeName() throws {
        let w = try World()
        let own = try FlowCodec.body(["trigger": ["type": "manual"], "inputs": [["name": "customer"]], "steps": [["id": "s", "text": "{{input.customer}} {{input.customer.name}} {{input.customer[0]}}"]]])
        #expect(own.problems(w.catalog).isEmpty, "\(own.problems(w.catalog).map(\.text))")
        let wrong = try FlowCodec.body(["trigger": ["type": "manual"], "inputs": [["name": "customer"]], "steps": [["id": "s", "text": "{{input.customers}}"]]])
        #expect(wrong.problems(w.catalog).contains { $0.text.contains("customers") })
    }

    @Test func aListOrARecordIsTheThingNotWhatATooSaidAboutIt() async throws {
        let w = try World()
        w.catalog.use(Actions.Listing(tools: [Actions.Tool(name: "reads.it", title: "Read", schema: #"{"properties":{}}"#, mutates: false, readsOnly: true, outputSchema: #"{"properties":{"n":{"type":"number"}}}"#)]))
        func said(_ text: String) { w.host.answers["reads.it"] = [Actions.Outcome(status: .ok, text: text, summary: "", data: #"{"n":3}"#)] }
        _ = try callee(w, steps: [["id": "a", "text": "{{input.it.n}}"]], inputs: [["name": "it", "type": "record"]])
        let caller = try w.flow([["id": "f", "do": "reads.it"], ["id": "r", "call_flow": "Pay", "inputs": ["it": "{{f}}"]]])
        said("Found 3")
        let back = try await runs(w, caller)
        #expect(back.status == .done, "a record's fields, not “Found 3”: \(back.problem ?? "")")
        #expect(back.values.value("r") == "3")

        _ = try callee(w, name: "Listed", steps: [["id": "a", "text": "x"]], inputs: [["name": "them", "type": "list"]])
        let other = try w.flow([["id": "f", "do": "reads.it"], ["id": "r", "call_flow": "Listed", "inputs": ["them": "{{f}}"]]])
        said("Found 3")
        let refused = try await runs(w, other)
        #expect(refused.status == .failed, "a record isn't a list, and its words aren't one either")
    }

    @Test func whatItGivesIsTheThingToo() async throws {
        let w = try World()
        w.catalog.use(Actions.Listing(tools: [Actions.Tool(name: "reads.it", title: "Read", schema: #"{"properties":{}}"#, mutates: false, readsOnly: true, outputSchema: #"{"properties":{"n":{"type":"number"}}}"#)]))
        _ = try callee(w, steps: [["id": "f", "do": "reads.it"]], output: "record")
        let caller = try w.flow([["id": "r", "call_flow": "Pay"], ["id": "s", "text": "{{r.n}}"]])
        w.host.answers["reads.it"] = [Actions.Outcome(status: .ok, text: "Found 3", summary: "", data: #"{"n":3}"#)]
        let back = try await runs(w, caller)
        #expect(back.status == .done, "\(back.problem ?? "")")
        #expect(back.values.value("s") == "3")

        _ = try callee(w, name: "Finished", steps: [["id": "f", "do": "reads.it"], ["finish": "{{f}}"]], output: "record")
        let other = try w.flow([["id": "r", "call_flow": "Finished"], ["id": "s", "text": "{{r.n}}"]])
        w.host.answers["reads.it"] = [Actions.Outcome(status: .ok, text: "Found 3", summary: "", data: #"{"n":3}"#)]
        let finished = try await runs(w, other)
        #expect(finished.status == .done, "\(finished.problem ?? "")")
        #expect(finished.values.value("s") == "3")
    }

    @Test func aVersionNoLongerKeptSaysSo() async throws {
        let w = try World()
        _ = try callee(w, steps: [["finish": "x"]])
        let held = try w.flow([["id": "r", "call_flow": "Pay", "version": 9]])
        #expect(held.draft.problems(w.catalog).contains { $0.text.contains("no longer kept") })
        let back = try await runs(w, held)
        #expect(back.status == .failed)
        #expect(back.problem?.contains("no longer kept") == true)
    }

    @Test func aVersionHeldToIsKeptPastTheUsualNumber() throws {
        var flow = Flow(id: "f", name: "F", draft: FlowBody(), createdAt: Date(), updatedAt: Date())
        for _ in 0..<(Flow.keptRevisions + 5) { flow.keep(FlowBody(), at: Date(), keeping: [2]) }
        #expect(flow.revisions.contains { $0.version == 2 })
        #expect(flow.revisions.count == Flow.keptRevisions)
        #expect(!flow.revisions.contains { $0.version == 1 })
    }

    @Test func revisionsFromBeforeNumbersGetThem() throws {
        var flow = Flow(id: "f", name: "F", draft: FlowBody(), createdAt: Date(), updatedAt: Date())
        flow.keep(FlowBody(), at: Date(), keeping: [])
        flow.keep(FlowBody(), at: Date(), keeping: [])
        var written = FlowStore.json(flow)
        written["version"] = nil
        written["revisions"] = (written["revisions"] as? [[String: Any]])?.map { var r = $0; r["version"] = nil; return r }
        let back = try #require(FlowStore.flow(written))
        #expect(back.version == 3)
        #expect(back.revisions.map(\.version) == [1, 2])
    }

    @Test func renamingKeepsThePin() throws {
        let step = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "s", "call_flow": "A", "version": 2]]]).calling("A", instead: "B").step("s")
        #expect(step?.pin == 2)
        if case .call(let name, _)? = step?.kind { #expect(name == "B") } else { Issue.record("not a call") }
    }

    private func page(_ app: App, _ op: String, _ flow: Flow, _ extra: [String: Any] = [:]) async throws {
        var input: [String: Any] = ["op": op, "flow": flow.id]
        input.merge(extra) { _, new in new }
        _ = try await Actions_UI.handle(Arguments(input), app)
    }

    @Test func thePageSetsAllOfIt() async throws {
        let w = try World()
        let app = App(folder: w.folder.appendingPathComponent("app"))
        app.engine.host = w.host
        let flow = app.newFlow(name: "F", body: try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "s", "text": "x"]]]))
        func body() throws -> FlowBody { try #require(app.store.flow(flow.id)?.draft) }
        try await page(app, "takes_add", flow)
        #expect(try body().inputs.map(\.name) == ["input_1"])
        try await page(app, "takes_name", flow, ["at": 0, "text": "customer"])
        try await page(app, "takes_type", flow, ["at": 0, "value": "number"])
        try await page(app, "takes_required", flow, ["at": 0, "on": false])
        #expect(try body().inputs == [FlowInput(name: "customer", type: .number, required: false)])
        await #expect(throws: Problem.self) { try await self.page(app, "takes_name", flow, ["at": 0, "text": "a b"]) }
        try await page(app, "takes_add", flow)
        await #expect(throws: Problem.self) { try await self.page(app, "takes_name", flow, ["at": 1, "text": "customer"]) }
        try await page(app, "takes_remove", flow, ["at": 1])
        try await page(app, "gives", flow, ["value": "list"])
        #expect(try body().output == .list)
        try await page(app, "gives", flow, ["value": ""])
        #expect(try body().output == nil)
    }

    @Test func thePageHoldsACallToAVersionAndLetsGoForAnotherFlow() async throws {
        let w = try World()
        let app = App(folder: w.folder.appendingPathComponent("app"))
        app.engine.host = w.host
        let flow = app.newFlow(name: "F", body: try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "s", "call_flow": "A"]]]))
        func step() throws -> Step { try #require(app.store.flow(flow.id)?.draft.step("s")) }
        try await page(app, "call_pin", flow, ["step": "s", "value": "3"])
        #expect(try step().pin == 3)
        try await page(app, "call_pin", flow, ["step": "s", "value": ""])
        #expect(try step().pin == nil)
        try await page(app, "call_pin", flow, ["step": "s", "value": "3"])
        try await page(app, "call_flow", flow, ["step": "s", "value": "B"])
        #expect(try step().pin == nil)
    }
}
