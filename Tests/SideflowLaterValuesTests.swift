import Foundation
import Testing
@testable import ext_sideflow
import SidefolkExtensionKit

/// The later list, about values: what was skipped, what gave nothing, calls never reached, and a sort the person says is by name.
@MainActor @Suite(.serialized) struct SideflowLaterValuesTests {
    typealias World = SideflowTests.World

    @Test func aSkippedStepsBlankIsntSentAsAnAnswer() async throws {
        let w = try World()
        w.host.answers["asks.it"] = [Actions.Outcome(status: .denied, text: "Not allowed", summary: "")]
        let flow = try w.flow([["id": "q", "do": "asks.it"], ["id": "send", "do": "changes.it", "with": ["q": "{{q}}"]]])
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

    @Test func aCallWhoseFailureWouldEndTheRunIsFoundBeforeAnythingRuns() throws {
        let w = try World()
        var off = try w.flow([["id": "x", "text": "x"]], state: .draft)
        off.name = "Off"
        w.store.save(off)
        let call: [String: Any] = ["id": "c", "call_flow": "Off"]
        let shapes: [String: [String: Any]] = [
            "a try with nothing to recover with": ["id": "b", "try": [call], "recover": []],
            "a try's last steps, nothing to recover with": ["id": "b", "try": [["id": "t", "text": "t"]], "recover": [], "always": [call]],
            "a repeat": ["id": "b", "repeat": [call], "until": ["value": "a", "test": "is", "than": "a"], "times": 2],
            "a lane it waits for": ["id": "b", "parallel": [["name": "one", "steps": [call]], ["name": "two", "steps": [["id": "t", "text": "t"]]]]],
        ]
        for (shape, step) in shapes {
            let flow = try w.flow([["id": "first", "do": "changes.it"], step])
            let run = try #require(w.engine.start(flow, mode: .live, why: "t"))
            #expect(run.status == .failed && run.problem?.contains("Off") == true, "\(shape): \(run.problem ?? "")")
        }
        #expect(!w.host.calls.contains { $0.tool == "changes.it" }, "nothing done before it would fail")
    }

    @Test func aFailureSomethingCatchesIsntRefusedUpFront() async throws {
        let w = try World()
        var off = try w.flow([["id": "x", "text": "x"]], state: .draft)
        off.name = "Off"
        w.store.save(off)
        let call: [String: Any] = ["id": "c", "call_flow": "Off"]
        let shapes: [String: [String: Any]] = [
            "a try that recovers": ["id": "b", "try": [call], "recover": [["id": "r", "text": "{{error}}"]]],
            "a parallel that settles": ["id": "b", "parallel": [["name": "one", "steps": [call]], ["name": "two", "steps": [["id": "t", "text": "t"]]]], "join": "settled"],
            "a call that carries on": ["id": "c", "call_flow": "Off", "on_failure": "carry_on"],
            "inside a step that carries on": ["id": "b", "parallel": [["name": "one", "steps": [call]]], "on_failure": "carry_on"],
        ]
        for (shape, step) in shapes {
            let flow = try w.flow([step, ["id": "after", "text": "went on"]])
            let run = try #require(w.engine.start(flow, mode: .live, why: "t"))
            #expect(run.status != .failed, "\(shape): \(run.problem ?? "")")
            await w.quiet()
            #expect(w.store.run(run.id)?.status == .done, "\(shape) runs, and what catches it does: \(w.store.run(run.id)?.problem ?? "")")
        }
    }

    @Test func aPinnedCallIsFollowedInTheVersionItStaysOn() throws {
        let w = try World()
        var off = try w.flow([["id": "x", "text": "x"]], state: .draft)
        off.name = "Off"
        w.store.save(off)
        var middle = try w.flow([["id": "c", "call_flow": "Off"]])
        middle.name = "Middle"
        // Version 1 called Off; what's live now, version 2, doesn't.
        let first = try #require(middle.live)
        middle.keep(first, at: Date(), keeping: [1])
        middle.live = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "t", "text": "t"]]])
        middle.draft = middle.live!
        w.store.save(middle)
        let latest = try w.flow([["id": "m", "call_flow": "Middle"]])
        #expect(w.engine.start(latest, mode: .live, why: "t")?.status != .failed, "what's live calls nothing that's off")
        let held = try w.flow([["id": "first", "do": "changes.it"], ["id": "m", "call_flow": "Middle", "version": 1]])
        let run = try #require(w.engine.start(held, mode: .live, why: "t"))
        #expect(run.status == .failed && run.problem?.contains("Off") == true, "\(run.problem ?? "")")
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
