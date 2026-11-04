import Foundation
import Testing
@testable import ext_sideflow
import SidefolkExtensionKit

/// A tool's answer can hold fields beside its words.
@MainActor @Suite(.serialized) struct SideflowFieldsTests {
    typealias World = SideflowTests.World

    private func world(_ fields: String?) throws -> World {
        let w = try World()
        w.host.answers["reads.it"] = [Actions.Outcome(status: .ok, text: "Two invoices are due", summary: "Looked", data: fields)]
        return w
    }

    @Test func aStepUsesAFieldAndASentenceTheWords() async throws {
        let w = try world(#"{"count": 2, "who": {"name": "Ada"}, "due": ["a", "b"]}"#)
        let flow = try w.flow([["id": "r", "do": "reads.it"], ["id": "n", "text": "{{r.who.name}} has {{r.count}}"], ["id": "w", "text": "Said: {{r}}"],
                               ["id": "each", "for_each": "{{r.due}}", "steps": [["id": "t", "text": "{{item}}"]]]])
        let run = await w.settled(w.engine.start(flow, mode: .live, why: "t"))
        #expect(run?.status == .done, "\(run?.problem ?? "")")
        #expect(run?.values.value("n") == "Ada has 2")
        #expect(run?.values.value("w") == "Said: Two invoices are due", "the words it gave, not its fields written out")
        #expect(run?.values.resolve("each").map(Values.text)?.contains("a") == true, "a list of fields goes round as a list")
    }

    @Test func aFieldThatIsntThereIsMissingNotEmpty() async throws {
        let w = try world(#"{"count": 2}"#)
        let flow = try w.flow([["id": "r", "do": "reads.it"], ["id": "c", "do": "changes.it", "with": ["text": "{{r.nope}}"]]])
        let run = await w.settled(w.engine.start(flow, mode: .live, why: "t"))
        #expect(run?.status != .done)
        #expect(!w.host.calls.contains { $0.tool == "changes.it" })
    }

    @Test func aToolWithNoFieldsIsAsItWas() async throws {
        let w = try world(nil)
        let flow = try w.flow([["id": "r", "do": "reads.it"], ["id": "w", "text": "{{r}}"]])
        let run = await w.settled(w.engine.start(flow, mode: .live, why: "t"))
        #expect(run?.values.value("w") == "Two invoices are due")
    }

    @Test func fieldsThatArentJSONFallBackToTheWords() async throws {
        let w = try world("not json")
        let run = await w.settled(w.engine.start(try w.flow([["id": "r", "do": "reads.it"], ["id": "w", "text": "{{r}}"]]), mode: .live, why: "t"))
        #expect(run?.status == .done)
        #expect(run?.values.value("w") == "Two invoices are due")
    }

    @Test func aRestartKeepsBoth() async throws {
        let w = try world(#"{"count": 2}"#)
        let flow = try w.flow([["id": "r", "do": "reads.it"], ["id": "rest", "wait_minutes": 5], ["id": "w", "text": "{{r}}: {{r.count}}"]])
        let run = try #require(w.engine.start(flow, mode: .live, why: "t"))
        await w.quiet()
        w.restart()
        w.engine.recover()
        w.now = w.now.addingTimeInterval(6 * 60)
        w.engine.tick()
        await w.quiet()
        #expect(w.store.run(run.id)?.values.value("w") == "Two invoices are due: 2")
    }

    @Test func theValueMenuOffersEachField() throws {
        let w = try World()
        let app = App(folder: w.folder.appendingPathComponent("app"))
        app.catalog.use(Actions.Listing(tools: [Actions.Tool(name: "reads.it", title: "Read it", mutates: false, readsOnly: true, outputSchema: #"{"type":"object","properties":{"count":{"type":"number"},"bad name!":{"type":"string"}}}"#)]))
        #expect(app.catalog.tool("reads.it")?.outputFields == ["count"], "only names a slot can hold")
        let flow = app.newFlow(name: "F", body: try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "r", "do": "reads.it"], ["id": "w", "text": "x"]]]))
        let tokens = Inspector.tokens(before: "w", flow: flow, app)
        #expect(tokens.contains { $0.value == "{{r.count}}" })
    }

    @Test func aLoopOverAToolsAnswerStillGoesThroughItsWords() async throws {
        let w = try World()
        w.host.answers["reads.it"] = [Actions.Outcome(status: .ok, text: "alice\nbob", summary: "", data: #"{"count":2}"#)]
        let flow = try w.flow([["id": "r", "do": "reads.it"], ["id": "e", "for_each": "{{r}}", "steps": [["id": "t", "text": "got {{item}}"]]]])
        let run = await w.settled(w.engine.start(flow, mode: .live, why: "t"))
        #expect(run?.status == .done)
        #expect(run?.records.filter { $0.step == "t" }.count == 2, "not once, on the whole record")
    }

    @Test func aFieldOffersOnlyWhatASlotCanReach() {
        let tool = Catalog.tool(Actions.Tool(name: "x.y", title: "T", schema: "{}", outputSchema: #"{"properties":{"ok_1":{},"my-field":{},"\#(String(repeating: "a", count: 50))":{}}}"#))
        #expect(tool.outputFields == ["ok_1"], "a name a value can't be reached by would go to a real tool as literal braces")
    }

    @Test func aPracticeCanUseAFieldItsToolSays() async throws {
        let w = try World()
        w.catalog.use(Actions.Listing(tools: [Actions.Tool(name: "reads.it", title: "Read", schema: #"{"properties":{}}"#, mutates: false, readsOnly: true),
                                              Actions.Tool(name: "changes.it", title: "Change", schema: #"{"properties":{"text":{"type":"string"}}}"#, outputSchema: #"{"properties":{"id":{}}}"#)]))
        let flow = try w.flow([["id": "c", "do": "changes.it", "with": ["text": "x"]], ["id": "t", "text": "made {{c.id}}"]], state: .draft)
        let run = await w.settled(w.engine.start(flow, mode: .practice, why: "t"))
        #expect(run?.status == .done, "a menu picked it: a practice can't stop because it only pretended")
    }


    /// `{{r}}` is what the tool said, everywhere; `{{r.field}}` is the field.
    @Test func aBareValueIsTheWordsEverywhere() async throws {
        let w = try World()
        w.host.answers["reads.it"] = [Actions.Outcome(status: .ok, text: "alice\nbob", summary: "", data: #"{"count":2}"#)]
        let flow = try w.flow([["id": "r", "do": "reads.it"], ["id": "l", "data": ["op": "lines", "from": "{{r}}"]], ["id": "c", "text": "{{r.count}}"]])
        let run = await w.settled(w.engine.start(flow, mode: .live, why: "t"))
        #expect(run?.record(of: "l")?.output?.contains("alice") == true)
        #expect(run?.record(of: "l")?.output?.contains("count") == false, "the same two lines a loop would go through")
        #expect(run?.record(of: "c")?.output == "2")
    }

    @Test func aCalledFlowGetsTheWordsToo() async throws {
        let w = try World()
        w.host.answers["reads.it"] = [Actions.Outcome(status: .ok, text: "Two invoices", summary: "", data: #"{"count":2}"#)]
        var child = try w.flow([["id": "t", "text": "got {{input.x}}"]])
        child.name = "Child"
        w.store.save(child)
        let flow = try w.flow([["id": "r", "do": "reads.it"], ["id": "c", "call_flow": "Child", "inputs": ["x": "{{r}}"]]])
        _ = try #require(w.engine.start(flow, mode: .live, why: "t"))
        await w.quiet()
        let ran = try #require(w.store.runs(of: child.id).first)
        #expect(ran.record(of: "t")?.output == "got Two invoices", "not its fields written out")
    }

    @Test func aPracticeGoesOnPastAFieldOfASample() async throws {
        let w = try World()
        let flow = try w.flow([["id": "l", "text": "x"], ["id": "c", "do": "changes.it", "with": ["text": "x"]], ["id": "t", "text": "{{c.anything}}"]], state: .draft)
        let run = await w.settled(w.engine.start(flow, mode: .practice, why: "t"))
        #expect(run?.status == .done, "it only pretended, so there's nothing to say about a field of that")
    }

    @Test func theGuideSaysHowToReachAField() {
        #expect(Grammar.text.contains("{{step.field}}"))
    }

}
