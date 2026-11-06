import Foundation
import Testing
@testable import ext_sideflow
import SidefolkExtensionKit

/// Reading a run closely: how long each part took and what it used. Reading a flow closely: what it may do, in Sidefolk's own answer.
@MainActor @Suite(.serialized) struct SideflowRunFactsTests {
    typealias World = SideflowTests.World

    private func app(_ w: World) -> App {
        let app = App(folder: w.folder.appendingPathComponent("app"))
        app.engine.host = w.host
        return app
    }

    @Test func aGoOfAStepCountsFromWhenItBeganAndANewGoStartsAfresh() {
        let start = Date(timeIntervalSince1970: 1000)
        var run = Run(id: "r", flow: "f", flowName: "F", mode: .live, status: .running, why: "", startedAt: start, body: FlowBody())
        run.record(.init(step: "a", status: .running, summary: "", at: start))
        run.record(.init(step: "a", status: .done, summary: "", at: start.addingTimeInterval(12)))
        #expect(run.record(of: "a")?.took == 12)
        run.record(.init(step: "a", status: .done, summary: "", at: start.addingTimeInterval(20)))
        #expect(run.record(of: "a")?.took == nil, "done, then done again, isn't one long go")
    }

    @Test func whatARunUsedSurvivesARestart() throws {
        var run = Run(id: "r", flow: "f", flowName: "F", mode: .live, status: .done, why: "", startedAt: Date(), body: FlowBody())
        run.aiRequests = 3
        run.actionsDone = 2
        run.version = 4
        run.record(.init(step: "a", status: .running, summary: "", at: Date(timeIntervalSince1970: 5)))
        run.record(.init(step: "a", status: .done, summary: "", at: Date(timeIntervalSince1970: 9)))
        let back = try #require(FlowStore.run(JSONText.read(JSONText.write(FlowStore.json(run))) as? [String: Any] ?? [:]))
        #expect(back.aiRequests == 3 && back.actionsDone == 2 && back.version == 4)
        #expect(back.record(of: "a")?.took == 4)
    }

    @Test func aRunSaysWhatItUsedCountingWhatItWaitedFor() async throws {
        let w = try World()
        let app = app(w)
        let flow = app.newFlow(name: "Mine", body: try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "a", "text": "x"]]]))
        var parent = Run(id: "p", flow: flow.id, flowName: "Mine", mode: .live, status: .done, why: "", startedAt: Date(timeIntervalSince1970: 0), body: flow.draft)
        parent.endedAt = Date(timeIntervalSince1970: 90)
        parent.aiRequests = 1
        parent.actionsDone = 2
        parent.version = 3
        var child = Run(id: "c", flow: flow.id, flowName: "Mine", mode: .live, status: .done, why: "", startedAt: Date(timeIntervalSince1970: 1), body: flow.draft)
        child.parent = "p"
        child.aiRequests = 4
        app.store.save(parent)
        app.store.save(child)
        let facts = String(describing: Pages.runFacts(parent, app)).filter { !"\u{2068}\u{2069}".contains($0) }
        #expect(facts.contains("AI requests") && facts.contains("5"), "\(facts)")
        #expect(facts.contains("Actions done") && facts.contains("2"))
        #expect(facts.contains("Version") && facts.contains("3"))
    }

    @Test func thePermissionsTabNamesEachStepAndOffersTheEnd() async throws {
        let w = try World()
        let app = app(w)
        let flow = app.newFlow(name: "Mine", body: try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "w", "text": "x"], ["id": "ai", "ai": "say hi"]]]))
        let page = String(describing: Pages.flowAllowedPage(flow, app, state: Arguments([:]))).filter { !"\u{2068}\u{2069}\\".contains($0) }
        #expect(page.contains("Permissions"))
        #expect(page.contains("Nothing is allowed yet"))
        #expect(page.contains("Still looking") || page.contains("Named on the card") || page.contains("Runs by itself"), "the AI step has a line")
    }
}

/// An agent's edits, and what a problem offers to put it right.
@MainActor @Suite(.serialized) struct SideflowAgentEditTests {
    typealias World = SideflowTests.World

    private let two: [String: Any] = ["trigger": ["type": "manual"], "steps": [["id": "a", "text": "one"], ["id": "b", "text": "two"]]]

    private func app(_ w: World) -> App {
        let app = App(folder: w.folder.appendingPathComponent("app"))
        app.engine.host = w.host
        return app
    }

    @Test func aPatchMakesTheSameEditsAndTheWholeIsChecked() throws {
        let body = try FlowCodec.body(two)
        let out = try AgentEdits.apply([
            ["op": "add", "after": "a", "step": ["id": "c", "text": "three"]],
            ["op": "replace", "id": "b", "step": ["id": "ignored", "text": "changed"]],
            ["op": "move", "id": "b", "after": "start"],
            ["op": "remove", "id": "a"],
        ], to: body)
        #expect(out.steps.map(\.id) == ["b", "c"])
        guard case .text("changed")? = out.step("b")?.kind else { Issue.record("not replaced"); return }
    }

    @Test func aWrongEditChangesNothingAndSaysWhichItWas() throws {
        let body = try FlowCodec.body(two)
        for (bad, says) in [([["op": "remove", "id": "nope"]], "Edit 1"),
                            ([["op": "add", "after": "a", "step": ["id": "b", "text": "dup"]]], "Edit 1"),
                            ([["op": "add", "after": "nope", "step": ["id": "c", "text": "x"]]], "Edit 1"),
                            ([["op": "remove", "id": "a"], ["op": "fly"]], "Edit 2")] as [([[String: Any]], String)] {
            #expect { try AgentEdits.apply(bad, to: body) } throws: { ($0 as? Problem)?.message.filter { !"\u{2068}\u{2069}".contains($0) }.contains(says) == true }
        }
    }

    @Test func aDraftChangedSinceItWasReadIsntWrittenOver() throws {
        let one = AgentEdits.fingerprint(try FlowCodec.body(two))
        #expect(one == AgentEdits.fingerprint(try FlowCodec.body(two)), "the same draft, the same mark")
        #expect(one != AgentEdits.fingerprint(try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "a", "text": "other"]]])))
    }

    @Test func aValueThatComesTooLateCanBeMovedAndOneThatsGoneCanBeTakenOut() async throws {
        let w = try World()
        let app = app(w)
        let flow = app.newFlow(name: "Mine", body: try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "use", "text": "{{made}} and {{gone}}"], ["id": "made", "text": "x"]]]))
        let problems = flow.draft.problems(app.catalog)
        #expect(Set(problems.compactMap(\.uses)) == ["made", "gone"])
        let offers = String(describing: problems.flatMap { Repairs.offers($0, flow: flow) }).filter { !"\u{2068}\u{2069}\\".contains($0) }
        #expect(offers.contains("Move “made” before this step") && offers.contains("Take “gone” out of this step"))
        _ = try await Actions_UI.handle(Arguments(["op": "repair_move", "flow": flow.id, "step": "use", "name": "made"]), app)
        #expect(app.store.flow(flow.id)?.draft.steps.map(\.id) == ["made", "use"])
        _ = try await Actions_UI.handle(Arguments(["op": "repair_drop", "flow": flow.id, "step": "use", "name": "gone"]), app)
        guard case .text(let words)? = app.store.flow(flow.id)?.draft.step("use")?.kind else { Issue.record("not text"); return }
        #expect(words == "{{made}} and ")
        #expect(app.store.flow(flow.id)?.draft.problems(app.catalog).isEmpty == true)
        _ = try await Actions_UI.handle(Arguments(["op": "undo", "flow": flow.id]), app)
        guard case .text(let back)? = app.store.flow(flow.id)?.draft.step("use")?.kind else { Issue.record("not text"); return }
        #expect(back.contains("gone"), "Undo takes it back")
    }

    @Test func thePersonSeesWhatAnAgentChangedAndCanTakeItBack() async throws {
        let w = try World()
        let app = app(w)
        var flow = app.newFlow(name: "Mine", body: try FlowCodec.body(two))
        let before = flow.draft
        flow.draft = try AgentEdits.apply([["op": "remove", "id": "b"]], to: before)
        app.store.save(flow)
        app.agentEdits[flow.id] = AgentEdit(before: before, after: flow.draft, changes: Editing.changes(from: before, to: flow.draft, catalog: app.catalog))
        let page = String(describing: Pages.flowPage(flow, app, state: Arguments([:]))).filter { !"\u{2068}\u{2069}\\".contains($0) }
        #expect(page.contains("An agent changed this") && page.contains("Removed"))
        _ = try await Actions_UI.handle(Arguments(["op": "agent_undo", "flow": flow.id, "page_token": "guess"]), app)
        #expect(app.store.flow(flow.id)?.draft != before, "another extension can call ui, but can't read the page's token")
        _ = try await Actions_UI.handle(Arguments(["op": "agent_undo", "flow": flow.id, "page_token": app.pageKey]), app)
        #expect(app.store.flow(flow.id)?.draft == before)
        #expect(app.agentEdits[flow.id] == nil)
    }
}

/// A practice going by what a run gave.
@MainActor @Suite(.serialized) struct SideflowExampleTests {
    typealias World = SideflowTests.World

    private func app(_ w: World) -> App {
        let app = App(folder: w.folder.appendingPathComponent("app"))
        app.engine.host = w.host
        return app
    }

    @Test func aPracticeGoesByTheExampleAndAsksAndReadsNothing() async throws {
        let w = try World()
        let app = app(w)
        var flow = app.newFlow(name: "Mine", body: try FlowCodec.body(["trigger": ["type": "manual"], "steps": [
            ["id": "q", "ask": "Which way?", "options": ["left", "right"]],
            ["id": "w", "ai": "write something"],
            ["id": "said", "text": "{{q}} and {{w}}"],
        ]]))
        flow.examples = [PracticeExample(id: "e", name: "Mine", at: Date(), trigger: nil, values: ["q": .string("right"), "w": .string("kept words")])]
        flow.chosenExample = "e"
        app.store.save(flow)
        app.engine.practice(flow)
        for _ in 0..<200 where app.store.runs(of: flow.id).first?.status.isOver != true { try await Task.sleep(for: .milliseconds(10)) }
        let run = try #require(app.store.runs(of: flow.id).first)
        #expect(run.status == .done)
        #expect(run.record(of: "said")?.output == "right and kept words")
        #expect(run.record(of: "w")?.note?.contains("Mine") == true)
        #expect(run.aiRequests == 0, "no AI asked")
    }

    @Test func itKeepsWhatAskedAndFetchedNotWhatWordsWereMadeOf() throws {
        var run = Run(id: "r", flow: "f", flowName: "F", mode: .live, status: .done, why: "", startedAt: Date(), body: try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "w", "ai": "x"], ["id": "t", "text": "y"]]]))
        run.values.set("w", "from ai")
        run.values.set("t", "words")
        let kept = try PracticeExample.from(run, at: Date())
        #expect(kept.values == ["w": .string("from ai")])
        run.values.set("w", String(repeating: "x", count: PracticeExample.longest + 1))
        #expect(throws: Problem.self) { try PracticeExample.from(run, at: Date()) }
    }

    @Test func aValueKeepsItsShapeWhenItsChanged() async throws {
        let w = try World()
        let app = app(w)
        var flow = app.newFlow(name: "Mine", body: try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "w", "ai": "x"]]]))
        flow.examples = [PracticeExample(id: "e", name: "Mine", at: Date(), trigger: nil, values: ["w": .number(1), "l": .array([.number(1)])])]
        app.store.save(flow)
        func set(_ step: String, _ text: String) async throws { _ = try await Actions_UI.handle(Arguments(["op": "example_value", "flow": flow.id, "example": "e", "step": step, "text": text]), app) }
        try await set("w", "12.5")
        #expect(app.store.flow(flow.id)?.examples[0].values["w"] == .number(12.5))
        await #expect(throws: Problem.self) { try await set("w", "many") }
        await #expect(throws: Problem.self) { try await set("l", "{\"a\": 1}") }
        try await set("l", "[2]")
        #expect(app.store.flow(flow.id)?.examples[0].values["l"] == .array([.number(2)]))
    }

    @Test func itGoesInNoCopyOrFileAndComesBackAfterARestart() throws {
        let w = try World()
        let app = app(w)
        var flow = app.newFlow(name: "Mine", body: try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "w", "ai": "x"]]]))
        flow.examples = [PracticeExample(id: "e", name: "Secret words", at: Date(), trigger: "t", values: ["w": .string("private")])]
        flow.chosenExample = "e"
        #expect(!JSONText.write(FlowCodec.json(flow.draft)).contains("private"))
        let back = try #require(FlowStore.flow(JSONText.read(JSONText.write(FlowStore.json(flow))) as? [String: Any] ?? [:]))
        #expect(back.examples == flow.examples.map { var e = $0; e.at = back.examples[0].at; return e } && back.chosenExample == "e")
    }
}

@MainActor @Suite(.serialized) struct SideflowCompactCardTests {
    @Test func aRunInAFewCardsSaysHowFarAndWhatMattersNow() throws {
        let w = try SideflowTests.World()
        let app = App(folder: w.folder.appendingPathComponent("app"))
        let body = try FlowCodec.body(["trigger": ["type": "manual"], "steps": (0..<30).map { ["id": "s\($0)", "text": "x"] }])
        var run = Run(id: "r", flow: "f", flowName: "Big", mode: .live, status: .failed, why: "", startedAt: Date(), body: body)
        for i in 0..<10 { run.record(.init(step: "s\(i)", status: .done, summary: "", at: Date())) }
        run.record(.init(step: "s10", status: .failed, summary: "It broke", at: Date()))
        let tree = Pages.compact(run, app)
        #expect(tree.nodes.count <= 4)
        #expect(tree.nodes.contains { $0.title.contains("10") } && tree.nodes.contains { $0.id == "s10" })
    }
}

@MainActor @Suite(.serialized) struct SideflowRepairMoreTests {
    @Test func aValueOnlyOneWayMakesGetsAFallbackBeforeTheStepThatUsesIt() async throws {
        let w = try SideflowTests.World()
        let app = App(folder: w.folder.appendingPathComponent("app"))
        app.engine.host = w.host
        let flow = app.newFlow(name: "Mine", body: try FlowCodec.body(["trigger": ["type": "manual"], "steps": [
            ["id": "b", "if": ["value": "a", "test": "is", "than": "a"], "then": [["id": "made", "text": "x"]], "else": []],
            ["id": "use", "text": "{{made}} here"],
        ]]))
        let problem = try #require(flow.draft.problems(app.catalog).first { $0.uses == "made" })
        #expect(problem.onOnePath)
        #expect(String(describing: Repairs.offers(problem, flow: flow)).contains("repair_fallback"))
        _ = try await Actions_UI.handle(Arguments(["op": "repair_fallback", "flow": flow.id, "step": "use", "name": "made"]), app)
        let body = try #require(app.store.flow(flow.id)?.draft)
        #expect(body.steps.map(\.id) == ["b", "made_or", "use"])
        guard case .text(let words)? = body.step("use")?.kind else { Issue.record("not text"); return }
        #expect(words == "{{made_or}} here")
        #expect(body.problems(app.catalog).allSatisfy { $0.uses != "made" }, "\(body.problems(app.catalog))")
        let form = String(describing: Inspector.sections(try #require(app.store.flow(flow.id)), app, problems: [])).filter { !"\u{2068}\u{2069}\\".contains($0) }
        #expect(form.contains("Nothing is written to use instead"), "what to use is left to write, and its form says so")
    }
}
