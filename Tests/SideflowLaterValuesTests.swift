import Foundation
import Testing
@testable import ext_sideflow
import SidefolkExtensionKit

/// The later list, about values: what was skipped, what gave nothing, calls never reached, and a sort the person says is by name.
@MainActor @Suite(.serialized) struct SideflowLaterValuesTests {
    typealias World = SideflowTests.World

    @Test func aSkippedStepsBlankIsntSentAsAnAnswer() async throws {
        let w = try World()
        let flow = try w.flow([["id": "q", "do": "fails.it"], ["id": "send", "do": "changes.it", "with": ["q": "{{q}}"]]])
        let run = try #require(w.engine.start(flow, mode: .live, why: "t"))
        await w.quiet()
        w.engine.proceed(run.id, .carry_on)
        await w.quiet()
        #expect(w.store.run(run.id)?.status == .failed)
        #expect(w.store.run(run.id)?.problem?.contains("skipped") == true, "\(w.store.run(run.id)?.problem ?? "")")
        #expect(!w.host.calls.contains { $0.tool == "changes.it" })
    }

    @Test func aCallNeverReachedDoesntRefuseTheRun() async throws {
        let w = try World()
        var off = try w.flow([["id": "x", "text": "x"]], state: .draft)
        off.name = "Off"
        w.store.save(off)
        let flow = try w.flow([["id": "b", "if": ["value": "a", "test": "is", "than": "b"], "then": [["id": "c", "call_flow": "Off"]], "else": []], ["id": "t", "text": "fine"]])
        let run = try #require(w.engine.start(flow, mode: .live, why: "t"))
        await w.quiet()
        #expect(w.store.run(run.id)?.status == .done, "\(w.store.run(run.id)?.problem ?? "")")
        let direct = try w.flow([["id": "c", "call_flow": "Off"]])
        #expect(w.engine.start(direct, mode: .live, why: "t")?.status == .failed, "one that always runs still stops before anything's done")
    }

    @Test func aGrandchildThatsOffIsFoundBeforeAnythingRuns() async throws {
        let w = try World()
        var off = try w.flow([["id": "x", "text": "x"]], state: .draft)
        off.name = "Off"
        w.store.save(off)
        var middle = try w.flow([["id": "c", "call_flow": "Off"]])
        middle.name = "Middle"
        w.store.save(middle)
        let flow = try w.flow([["id": "first", "do": "changes.it"], ["id": "m", "call_flow": "Middle"]])
        let run = try #require(w.engine.start(flow, mode: .live, why: "t"))
        #expect(run.status == .failed && run.problem?.contains("Off") == true)
        #expect(!w.host.calls.contains { $0.tool == "changes.it" }, "nothing done before it would fail")
    }

    @Test func whatGaveNothingSaysSoAndWhatDidntRunSaysThat() {
        var run = Run(id: "r", flow: "f", flowName: "F", mode: .live, status: .running, why: "", startedAt: Date(), body: FlowBody())
        #expect(run.whyMissing("a").contains("didn't run"))
        run.record(.init(step: "a", status: .done, summary: "", at: Date()))
        #expect(run.whyMissing("a").contains("gave nothing"))
    }

    @Test func aSortByNameIsThePersonsWord() throws {
        func sort(_ items: [String], byName: Bool) throws -> JSON {
            var step = DataStep(op: .sort, from: "")
            step.byName = byName
            return try step.apply(to: .array(items.map { .string($0) }), than: "")
        }
        #expect(throws: Condition.Unreadable.self) { try sort(["Item 12", "Item 9"], byName: false) }
        #expect(try sort(["Item 12", "Item 9", "item 100"], byName: true) == .array([.string("Item 9"), .string("Item 12"), .string("item 100")]))
        let body = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "s", "data": ["op": "sort", "from": "x", "by_name": true]]]])
        guard case .data(let d)? = body.step("s")?.kind else { Issue.record("not data"); return }
        #expect(d.byName && (FlowCodec.json(body)["steps"] as? [[String: Any]])?.first.flatMap { ($0["data"] as? [String: Any])?["by_name"] as? Bool } == true)
    }
}
