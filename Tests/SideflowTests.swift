import Foundation
import Testing
@testable import ext_sideflow
import SidefolkExtensionKit

/// Sideflow's own logic: what's saved, when it runs, what a run does, and what happens after a stop. Sidefolk is scripted.
@MainActor @Suite(.serialized) struct SideflowTests {
    @MainActor final class Host: FlowHost {
        var calls: [(tool: String, input: [String: Any], plan: String?)] = []
        var answers: [String: [Actions.Outcome]] = [:]
        var aiAnswer: AI.Result = .answer(text: "Three lines.", madeBy: "Scripted")
        var planAnswer: Plans.Answer = .allowed(standing: [])
        var plans: [Plan] = []
        /// How long the card stays up.
        var planWait: Duration?
        var forgotten: [String] = []
        var forward: [String] = []
        var notices: [(title: String, body: String?, attention: Bool)] = []
        var decision: Actions.Check.Decision = .allow
        /// Held until released: a call in the air, for a stop in the middle.
        var hold: String?
        var written: [String] = []
        /// What they answer when a stopped run asks the way forward: by default nobody does.
        var wayForward: String?
        /// Answers in the order they're asked, each after a moment: someone taking their time.
        var slowAnswers: [String?] = []

        func call(_ tool: String, _ input: [String: Any], plan: String?, written: [String: Any]?) async -> Actions.Outcome {
            // Asking the way forward isn't a step of the flow.
            if tool == "ask.user", input["options"] as? [String] != nil, (input["question"] as? String)?.contains("{") == false, answers[tool]?.isEmpty != false {
                forward.append(input["question"] as? String ?? "")
                if !slowAnswers.isEmpty {
                    let answer = slowAnswers.removeFirst()
                    try? await Task.sleep(for: .milliseconds(80))
                    return Actions.Outcome(status: .ok, text: answer ?? "no answer", summary: "Asked")
                }
                return Actions.Outcome(status: .ok, text: wayForward ?? "no answer", summary: "Asked")
            }
            calls.append((tool, input, plan))
            if tool == hold {
                try? await Task.sleep(for: .seconds(3600))
            }
            if var list = answers[tool], !list.isEmpty {
                let first = list.removeFirst()
                answers[tool] = list
                return first
            }
            return Actions.Outcome(status: .ok, text: "result of \(tool)", summary: "Did \(tool)")
        }

        func check(_ tool: String, _ input: [String: Any], plan: String?) async -> Actions.Check? {
            Actions.Check(decision: decision, summary: "Sentence for \(tool)", mutates: tool != "reads.it", standing: plan != nil)
        }

        func write(_ prompt: String, label: String) async -> AI.Result {
            written.append(prompt)
            return aiAnswer
        }

        func approve(_ plan: Plan) async -> Plans.Answer {
            plans.append(plan)
            if let planWait { try? await Task.sleep(for: planWait) }
            return planAnswer
        }

        func forgetPlan(_ id: String) { forgotten.append(id) }
        func notify(title: String, body: String?, attention: Bool) async { notices.append((title, body, attention)) }
    }

    @MainActor final class World {
        let folder: URL
        var store: FlowStore
        var catalog = Catalog()
        var host = Host()
        var engine: Engine
        var now = Date(timeIntervalSince1970: 1_800_000_000)

        init() throws {
            folder = FileManager.default.temporaryDirectory.appendingPathComponent("sideflow-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            store = FlowStore(folder: folder)
            engine = Engine(store: store, catalog: catalog)
            catalog.use(Actions.Listing(tools: [
                Actions.Tool(name: "reads.it", title: "Read it", schema: #"{"properties":{"q":{"type":"string"}}}"#, mutates: false, readsOnly: true),
                Actions.Tool(name: "says.it.reads", title: "Claims to read", mutates: false, readsOnly: false),
                Actions.Tool(name: "changes.it", title: "Change it", schema: #"{"properties":{"text":{"type":"string"}},"required":["text"]}"#, mutates: true),
                Actions.Tool(name: "notes.save", title: "Save a note", schema: #"{"properties":{"text":{"type":"string"}},"required":["text"]}"#, mutates: true),
            ]))
            engine.host = host
            engine.clock = { [weak self] in self?.now ?? Date() }
        }

        /// Sidefolk quit and came back: a new program over the same folder.
        func restart() {
            store = FlowStore(folder: folder)
            engine = Engine(store: store, catalog: catalog)
            engine.host = host
            engine.clock = { [weak self] in self?.now ?? Date() }
        }

        func flow(_ steps: [[String: Any]], trigger: [String: Any] = ["type": "manual"], state: Flow.State = .on) throws -> Flow {
            let body = try FlowCodec.body(["trigger": trigger, "steps": steps])
            var flow = Flow(id: UUID().uuidString.lowercased().prefixString(8), name: "Test", draft: body, createdAt: now, updatedAt: now)
            flow.state = state
            if state != .draft { flow.live = body }
            flow.lastFire = now
            store.save(flow)
            return flow
        }

        func settled(_ run: Run?, seconds: Double = 60) async -> Run? {
            guard let id = run?.id else { return nil }
            let deadline = Date().addingTimeInterval(seconds)
            while Date() < deadline {
                if let r = store.run(id), r.status != .running { return r }
                try? await Task.sleep(for: .milliseconds(5))
            }
            return store.run(id)
        }

        /// Until nothing has moved for a while. A call to the host hops off this actor, which can take longer than any fixed
        /// wait on a busy Mac, and a wait that ran out reads as a failed step. Counted in looks, not time: tests beside this one can hold
        /// the main actor past any length of time, and each look queues behind what's waiting for it.
        func quiet(_ other: FlowStore? = nil, seconds: Double = 10) async {
            func state() -> String {
                let runs = (other ?? store).runs().map { "\($0.id) \($0.status) \($0.records.count)" }.sorted()
                return "\(runs) \(host.calls.count) \(host.plans.count) \(host.notices.count) \(host.forward.count) \((other ?? store).flows().map(\.updatedAt))"
            }
            let deadline = Date().addingTimeInterval(seconds)
            var seen = state(), still = 0
            while Date() < deadline, still < 20 {
                try? await Task.sleep(for: .milliseconds(10))
                let now = state()
                still = now == seen ? still + 1 : 0
                seen = now
            }
        }

        deinit { try? FileManager.default.removeItem(at: folder) }
    }

    // MARK: What's saved

    @Test func aDefinitionReadsBackExactly() throws {
        let raw: [String: Any] = ["trigger": ["type": "schedule", "days": ["mon", "fri"], "at": "08:30", "catch_up": false], "steps": [
            ["id": "a", "do": "reads.it", "with": ["q": "x", "n": 3, "on": true], "name": "Look"],
            ["id": "b", "ai": "Write {{a}}", "on_failure": "carry_on"],
            ["id": "c", "ask": "Sure?", "options": ["Yes", "No"]],
            ["if": ["value": "{{c}}", "test": "is", "than": "Yes"], "then": [["id": "d", "text": "Hi {{b}}"]], "else": [["wait_minutes": 5]]],
        ]]
        let body = try FlowCodec.body(raw)
        #expect(try FlowCodec.body(FlowCodec.json(body)) == body)
        #expect(body.allSteps.count == 6)
        #expect(body.trigger == .days([1, 5], hour: 8, minute: 30, catchUp: false))
    }

    @Test func aMistakeInADefinitionIsSaidNotDropped() {
        #expect(throws: Problem.self) { try FlowCodec.body(["steps": [["do": "x", "wiht": [:]]]]) }
        #expect(throws: Problem.self) { try FlowCodec.body(["steps": [["do": "x", "ai": "y"]]]) }
        #expect(throws: Problem.self) { try FlowCodec.body(["steps": [["id": "a", "text": ""], ["id": "a", "text": ""]]]) }
        #expect(throws: Problem.self) { try FlowCodec.body(["trigger": ["type": "schedule", "every_minutes": 1]]) }
        #expect(throws: Problem.self) { try FlowCodec.body(["trigger": ["type": "schedule", "at": "25:00"]]) }
        #expect(throws: Problem.self) { try FlowCodec.body(["steps": [["wait_minutes": 99999]]]) }
        #expect(throws: Problem.self) { try FlowCodec.body(["steps": [["id": "trigger", "text": "x"]]]) }
    }

    @Test func problemsNameTheStepAndWhatToFix() throws {
        let w = try World()
        let body = try FlowCodec.body(["steps": [["id": "a", "do": "changes.it"], ["id": "b", "do": "gone.tool"], ["id": "c", "text": "{{nope}} {{a}}"], ["id": "d", "do": "reads.it", "with": ["wrong": "x"]]]])
        let problems = body.problems(w.catalog)
        #expect(problems.contains { $0.step == "a" && $0.text.contains("needs a value") })
        #expect(problems.contains { $0.step == "b" })
        #expect(problems.contains { $0.step == "c" && $0.text.contains("nope") })
        #expect(!problems.contains { $0.step == "c" && $0.text.contains("“a”") }, "an earlier step's value is fine")
        #expect(problems.contains { $0.step == "d" })
        #expect(FlowBody().problems(w.catalog).first?.step == nil)
    }

    @Test func editingKeepsThingsInTheirOwnList() throws {
        var body = try FlowCodec.body(["steps": [["id": "a", "text": ""], ["id": "b", "if": ["value": "x", "test": "is_empty"], "then": [["id": "c", "text": ""]], "else": []], ["id": "e", "text": ""]]])
        body = Editing.insert(Step(id: "n", kind: .text("")), after: "then:b", in: body)
        guard case .branch(_, let then, _)? = body.step("b")?.kind else { Issue.record("no branch"); return }
        #expect(then.map(\.id) == ["n", "c"])
        body = Editing.move("e", before: "a", in: body)
        #expect(body.steps.map(\.id) == ["e", "a", "b"])
        #expect(Editing.move("a", before: "c", in: body).steps.map(\.id) == ["e", "a", "b"], "a row moves only among its own")
        #expect(Editing.nudge("e", by: -1, in: body) == body)
        #expect(Editing.remove("n", from: body).allSteps.map(\.id) == ["e", "a", "b", "c"])
        #expect(Editing.freshId(body, base: "Save a note") == "save_a_note")
        #expect(Editing.freshId(body, base: "n") == "n_2")
        #expect(Editing.freshId(body, base: "予定") == "step")
    }

    @Test func aDraggedStepGoesAnywhereButInsideItself() throws {
        let body = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [
            ["id": "a", "text": "x"],
            ["id": "b", "if": ["value": "{{a}}", "test": "not_empty"], "then": [["id": "c", "text": "y"]], "else": []],
            ["id": "d", "text": "z"],
        ]])
        #expect(Editing.place("d", after: "start", in: body).steps.map(\.id) == ["d", "a", "b"])
        let inBranch = Editing.place("d", after: "then:b", in: body)
        #expect(inBranch.steps.map(\.id) == ["a", "b"])
        #expect(inBranch.allSteps.map(\.id) == ["a", "b", "d", "c"])
        #expect(Editing.place("c", after: "a", in: body).steps.map(\.id) == ["a", "c", "b", "d"], "out of a branch")
        #expect(Editing.place("b", after: "c", in: body) == body, "not inside itself")
        #expect(Editing.place("b", after: "else:b", in: body) == body)
        #expect(Editing.place("nothing", after: "a", in: body) == body)
    }

    @Test func aWatchSaysHowOftenAndHowLongItRestsOnlyIfAsked() throws {
        let plain = WatchTrigger(kind: "file_changes", target: "~/a.txt")
        #expect(Engine.watchInput(plain, title: "t")["interval_minutes"] == nil)
        #expect(Engine.watchInput(plain, title: "t")["cooldown_minutes"] == nil, "by default it looks again at its next check")
        var asked = plain
        asked.everySeconds = 30
        asked.restMinutes = 2
        #expect(Engine.watchInput(asked, title: "t")["interval_minutes"] as? Double == 0.5)
        #expect(Engine.watchInput(asked, title: "t")["cooldown_minutes"] as? Int == 2)
        let back = try FlowCodec.body(["trigger": FlowCodec.json(.watch(asked)), "steps": []])
        #expect(back.trigger == .watch(asked))
    }

    private static let ifInIf: [[String: Any]] = [["id": "a", "if": ["value": "x", "test": "not_empty"], "then": [
        ["id": "b", "if": ["value": "y", "test": "not_empty"], "then": [["id": "c", "text": "z"]], "else": []],
    ], "else": []]]

    /// It used to save, then disappear for good on the next start: the limit was tighter on reading than on writing.
    @Test func anIfInsideAnIfComesBackAfterARestart() throws {
        let w = try World()
        let flow = try w.flow(Self.ifInIf)
        #expect(flow.draft.depth == 3)
        w.restart()
        #expect(w.store.flow(flow.id)?.draft.allSteps.map(\.id) == ["a", "b", "c"])
    }

    @Test func aStepGoesNoDeeperThanAFlowCanBeWritten() throws {
        let deeper: [[String: Any]] = [["id": "a", "if": ["value": "x", "test": "not_empty"], "then": [
            ["id": "b", "if": ["value": "y", "test": "not_empty"], "then": [["id": "c", "if": ["value": "z", "test": "not_empty"], "then": [], "else": []]], "else": []],
        ], "else": []]]
        #expect(throws: Problem.self) { try FlowCodec.body(["trigger": ["type": "manual"], "steps": deeper]) }
        let kept = try FlowCodec.body(["trigger": ["type": "manual"], "steps": deeper], saved: true)
        #expect(kept.depth == 4, "what was saved before the limit still reads")
    }

    @Test func aFlowThisVersionCantReadIsKeptNotDropped() throws {
        let w = try World()
        let flow = try w.flow([["id": "a", "text": "x"]])
        let file = w.folder.appendingPathComponent("flows.json")
        var list = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [[String: Any]])
        list.append(["id": "from-tomorrow", "name": "Tomorrow", "draft": ["steps": "something new"]])
        try JSONSerialization.data(withJSONObject: list).write(to: file)
        w.restart()
        w.store.save(try #require(w.store.flow(flow.id)))
        let after = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [[String: Any]])
        #expect(after.contains { $0["id"] as? String == "from-tomorrow" })
    }

    @Test func aStaleSpotLosesNoStep() throws {
        let body = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "a", "text": "x"], ["id": "b", "text": "y"]]])
        #expect(Set(Editing.place("a", after: "then:gone", in: body).allSteps.map(\.id)) == ["a", "b"])
        #expect(Editing.insert(Step(id: "n", kind: .text("")), after: "else:gone", in: body).allSteps.map(\.id) == ["a", "b", "n"])
    }

    /// A watch stopped by an earlier version, or by the person in Home: Resume makes it again rather than saying On and never firing.
    @Test func resumingBringsAGoneWatchBack() async throws {
        let w = try World()
        var flow = try w.flow([["id": "a", "text": "x"]], trigger: ["type": "watch", "kind": "file_changes", "target": "~/a.txt"])
        flow.watchTitle = "Gone · Sideflow"
        flow.state = .paused
        w.store.save(flow)
        w.host.answers["watch.resume"] = [Actions.Outcome(status: .failed, text: "a watcher called “Gone”", summary: "", notFound: true)]
        w.engine.resume(flow.id)
        await w.quiet()
        #expect(w.host.calls.map(\.tool).contains("watch.create"))
        #expect(w.store.flow(flow.id)?.state == .on)
    }

    // MARK: Correctness (roadmap phase 0)

    private func actions(_ count: Int, trigger: [String: Any] = ["type": "manual"]) throws -> FlowBody {
        try FlowCodec.body(["trigger": trigger, "steps": (0..<count).map { ["id": "s\($0)", "do": "changes.it", "with": ["text": "line \($0)"]] as [String: Any] }])
    }

    private let watching: [String: Any] = ["type": "watch", "kind": "file_changes", "target": "~/a.txt"]

    /// What the page calls too many is what Sidefolk would refuse.
    @Test func aFlowKnowsItsPlanWouldBeTooLongBeforeItsAsked() throws {
        let w = try World()
        func tooMany(_ body: FlowBody) -> Bool { body.problems(w.catalog).contains { $0.step == nil && $0.text.contains("different things to allow") } }
        #expect(!tooMany(try actions(1)))
        #expect(!tooMany(try actions(32)))
        #expect(tooMany(try actions(33)))
        #expect(!tooMany(try actions(28, trigger: watching)), "28 and the watch's four")
        #expect(tooMany(try actions(29, trigger: watching)))
        #expect(Engine.planSteps(try actions(29, trigger: watching), title: "t").count == 33)
    }

    @Test func theSameActionTwiceIsOneLineToAllow() throws {
        let body = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "a", "do": "notes.save", "with": ["text": "x"]], ["id": "b", "do": "notes.save", "with": ["text": "x"]], ["id": "c", "do": "notes.save", "with": ["text": "y"]]]])
        #expect(Engine.planSteps(body, title: "t").count == 2)
    }

    /// No action, nothing to read on a card, and Sidefolk refuses an empty plan: it just turns on.
    @Test func aFlowWithNoActionsTurnsOnWithoutACard() async throws {
        let w = try World()
        let flow = try w.flow([["id": "a", "text": "x"]], state: .draft)
        w.engine.turnOn(flow.id)
        await w.quiet()
        #expect(w.host.plans.isEmpty)
        #expect(w.store.flow(flow.id)?.state == .on)
    }

    /// The card shows one version, the person edits another while it waits: the one they read goes live.
    @Test func whatGoesLiveIsWhatTheCardShowed() async throws {
        let w = try World()
        let flow = try w.flow([["id": "a", "do": "changes.it", "with": ["text": "read on the card"]]], state: .draft)
        w.host.planWait = .milliseconds(80)
        w.engine.turnOn(flow.id)
        try await Task.sleep(for: .milliseconds(10))
        var edited = try #require(w.store.flow(flow.id))
        edited.draft = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "a", "do": "changes.it", "with": ["text": "changed meanwhile"]]]])
        w.store.save(edited)
        await w.quiet()
        let after = try #require(w.store.flow(flow.id))
        #expect(after.state == .on)
        #expect(after.live == flow.draft)
        #expect(after.draft == edited.draft, "the edit is kept, as changes waiting")
        #expect(after.hasChanges)
    }

    private let eitherWay: [[String: Any]] = [["id": "p", "text": "x"], ["id": "c", "if": ["value": "{{p}}", "test": "not_empty"],
        "then": [["id": "yes", "text": "made here"]], "else": [["id": "no", "do": "reads.it", "with": ["q": "{{yes}}"]]]]]

    @Test func oneBranchCantUseWhatTheOtherMade() throws {
        let w = try World()
        let inOther = try FlowCodec.body(["trigger": ["type": "manual"], "steps": eitherWay])
        #expect(inOther.problems(w.catalog).contains { $0.step == "no" })
        let after = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [eitherWay[0], ["id": "c", "if": ["value": "{{p}}", "test": "not_empty"], "then": [["id": "yes", "text": "y"]], "else": []],
                                                                                 ["id": "later", "text": "{{yes}}"]]])
        #expect(after.problems(w.catalog).contains { $0.step == "later" && $0.text.contains("only one path") })
        let both = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [eitherWay[0], ["id": "c", "if": ["value": "{{p}}", "test": "not_empty"], "then": [["id": "m", "text": "y"], ["id": "yes", "text": "y"]], "else": []],
                                                                                ["id": "d", "if": ["value": "{{yes}}", "test": "is_empty"], "then": [], "else": []]]])
        #expect(!both.problems(w.catalog).contains { $0.step == "d" }, "asking whether it ran is how a flow handles it")
    }

    /// A value that was never made stops the step: it doesn't reach a tool as nothing.
    @Test func aMissingValueStopsTheStepInsteadOfBecomingEmpty() async throws {
        let w = try World()
        let flow = try w.flow([["id": "c", "if": ["value": "x", "test": "is_empty"], "then": [["id": "made", "text": "y"]], "else": []],
                               ["id": "act", "do": "changes.it", "with": ["text": "Title: {{made}}"]]])
        let run = await w.settled(w.engine.start(flow, mode: .live, why: "t"))
        #expect(run?.status == .failed)
        #expect(run?.problem?.contains("made") == true)
        #expect(!w.host.calls.contains { $0.tool == "changes.it" })
    }

    /// Written down first, or not done.
    @Test func aRunThatCantSaveDoesNothing() async throws {
        let w = try World()
        let flow = try w.flow([["id": "act", "do": "changes.it", "with": ["text": "x"]]])
        let runs = w.folder.appendingPathComponent("runs")
        try FileManager.default.removeItem(at: runs)
        try Data().write(to: runs)
        defer { try? FileManager.default.removeItem(at: runs) }
        let run = await w.settled(w.engine.start(flow, mode: .live, why: "t"))
        #expect(run?.status == .needs_you)
        #expect(run?.problem?.contains("couldn't save") == true)
        #expect(!w.host.calls.contains { $0.tool == "changes.it" })
        #expect(w.store.failedSaves > 0)
    }

    /// "It may have happened" stays that: it isn't a failure that's safe to repeat.
    @Test func aStepThatDidntFinishIsForThePersonToLookAt() async throws {
        let w = try World()
        let flow = try w.flow([["id": "act", "do": "changes.it", "with": ["text": "x"]]])
        w.host.answers["changes.it"] = [Actions.Outcome(status: .lost, text: "", summary: "")]
        let run = await w.settled(w.engine.start(flow, mode: .live, why: "t"))
        #expect(run?.status == .interrupted)
        #expect(run?.record(of: "act")?.status == .unknown)
        #expect(run?.problem?.contains("may or may not") == true)
        #expect(w.host.calls.filter { $0.tool == "changes.it" }.count == 1, "never again by itself")
    }

    // MARK: Editing

    @Test func typingInOneFieldIsOneStepBack() throws {
        var h = Editing.History()
        let (a, b, c) = (try actions(1), try actions(2), try actions(3))
        let t = Date(timeIntervalSince1970: 1000)
        h.record(a, key: "field", at: t)
        h.record(b, key: "field", at: t.addingTimeInterval(1))
        #expect(h.back(from: c) == a, "moments apart in one field: back to before the typing")
        #expect(h.back(from: a) == nil)
        #expect(h.forward(from: a) == c)
        h.record(a, key: "field", at: t)
        h.record(b, key: "field", at: t.addingTimeInterval(5))
        #expect(h.back(from: c) == b, "later typing is a step of its own")
        h.record(b, key: nil, at: t)
        #expect(!h.canRedo, "a new edit ends what could be redone")
    }

    @Test func savingAndComingBackToWhatWasSaved() throws {
        let body = try actions(1), edited = try actions(2)
        var flow = Flow(id: "f", name: "F", draft: body, createdAt: Date(), updatedAt: Date())
        #expect(!flow.hasUnsaved)
        flow.draft = edited
        flow.hold(body)
        #expect(flow.hasUnsaved)
        #expect(flow.kept == body)
        flow.draft = body
        flow.hold(edited)
        #expect(!flow.hasUnsaved, "came back to what was saved: nothing to save")
    }

    @Test func whatTurnsOnIsWhatWasSavedNotWhatsUnsaved() async throws {
        let w = try World()
        var flow = try w.flow([["id": "a", "do": "changes.it", "with": ["text": "saved"]]], state: .draft)
        let saved = flow.draft
        flow.draft = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "a", "do": "changes.it", "with": ["text": "unsaved"]]]])
        flow.saved = saved
        w.store.save(flow)
        w.engine.turnOn(flow.id)
        await w.quiet()
        #expect(w.store.flow(flow.id)?.live == saved)
        #expect(w.store.flow(flow.id)?.hasUnsaved == true, "still there to save or discard")
        w.restart()
        #expect(w.store.flow(flow.id)?.saved == saved, "and across a restart")
    }

    @Test func aDuplicateIsAWholeCopyThatUsesItsOwnValues() throws {
        let body = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "a", "text": "x"], ["id": "c", "if": ["value": "{{a}}", "test": "not_empty"], "then": [["id": "m", "text": "y"], ["id": "n", "text": "{{m}} {{a}}"]], "else": []]]])
        let (copy, id) = try #require(Editing.duplicate("c", in: body))
        #expect(copy.steps.map(\.id) == ["a", "c", id])
        #expect(Set(copy.allSteps.map(\.id)).count == copy.allSteps.count, "no id twice")
        let inside = try #require(copy.step(id))
        guard case .branch(let cond, let then, _) = inside.kind, case .text(let words)? = then.last?.kind, let made = then.first?.id else { Issue.record("not a copy"); return }
        #expect(cond.value == "{{a}}", "what it used from outside stays")
        #expect(words == "{{\(made)}} {{a}}")
        #expect(copy.depth == body.depth)
    }

    @Test func whatChangedIsSaidInWords() throws {
        let w = try World()
        let old = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "a", "text": "x", "name": "A"], ["id": "b", "text": "y", "name": "B"], ["id": "c", "text": "z", "name": "C"]]])
        let new = try FlowCodec.body(["trigger": ["type": "schedule", "every_minutes": 60], "steps": [["id": "b", "text": "y", "name": "B"], ["id": "a", "text": "changed", "name": "A"], ["id": "d", "text": "q", "name": "D"]]])
        let said = Editing.changes(from: old, to: new, catalog: w.catalog)
        #expect(said.contains { $0.hasPrefix("What sets it off") })
        #expect(said.contains { $0.hasPrefix("Added") && $0.contains("D") })
        #expect(said.contains { $0.hasPrefix("Removed") && $0.contains("C") })
        #expect(said.contains { $0.hasPrefix("Changed") && $0.contains("A") })
        #expect(Editing.changes(from: old, to: old, catalog: w.catalog).isEmpty)
        let moved = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "b", "text": "y", "name": "B"], ["id": "a", "text": "x", "name": "A"], ["id": "c", "text": "z", "name": "C"]]])
        #expect(Editing.changes(from: old, to: moved, catalog: w.catalog).contains { $0.hasPrefix("Moved") })
    }

    @Test func aFlowSurvivesARestartWithAllOfIt() throws {
        let w = try World()
        var flow = try w.flow([["id": "a", "do": "reads.it", "with": ["q": "x"]]], trigger: ["type": "schedule", "every_minutes": 60])
        flow.missed = [w.now]
        flow.watchTitle = "t"
        flow.draft = FlowBody()
        w.store.save(flow)
        w.restart()
        let back = w.store.flow(flow.id)
        #expect(back?.live == flow.live)
        #expect(back?.draft == flow.draft)
        #expect(back?.hasChanges == true)
        #expect(back?.state == .on)
        #expect(back?.watchTitle == "t")
        #expect(back?.missed.count == 1)
    }

    // MARK: Time

    @Test func theNextTimeFallsOnTheRightDay() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int) -> Date { calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))! }
        let weekdays = Trigger.days([1, 2, 3, 4, 5], hour: 8, minute: 30, catchUp: true)
        // Friday 2026-11-06, past 8:30: next is Monday.
        #expect(Schedule.next(weekdays, after: date(2026, 11, 6, 9, 0), calendar: calendar) == date(2026, 11, 9, 8, 30))
        #expect(Schedule.next(weekdays, after: date(2026, 11, 6, 8, 0), calendar: calendar) == date(2026, 11, 6, 8, 30))
        #expect(Schedule.next(.manual, after: date(2026, 11, 6, 8, 0), calendar: calendar) == nil)
        #expect(Schedule.next(.every(minutes: 30, catchUp: false), after: date(2026, 11, 6, 8, 0), calendar: calendar) == date(2026, 11, 6, 8, 30))
    }

    @Test func aGapCollapsesToItsLatestTime() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let start = calendar.date(from: DateComponents(year: 2026, month: 11, day: 2, hour: 9))!
        let due = Schedule.due(.days([1, 2, 3, 4, 5, 6, 7], hour: 8, minute: 0, catchUp: true), last: start, now: start.addingTimeInterval(3 * 86400), calendar: calendar)
        #expect(due?.count == 3)
        #expect(due?.latest == calendar.date(from: DateComponents(year: 2026, month: 11, day: 5, hour: 8)))
        #expect(Schedule.due(.every(minutes: 60, catchUp: true), last: start, now: start.addingTimeInterval(1800), calendar: calendar) == nil)
        let long = Schedule.due(.every(minutes: 15, catchUp: true), last: start, now: start.addingTimeInterval(365 * 86400), calendar: calendar)
        #expect(long.map { start.addingTimeInterval(365 * 86400).timeIntervalSince($0.latest) < 900 } == true, "a year off doesn't walk every quarter hour")
    }

    @Test func onTimeItRunsLateItCatchesUpOrSaysItMissed() async throws {
        let w = try World()
        let catches = try w.flow([["do": "reads.it"]], trigger: ["type": "schedule", "every_minutes": 60, "catch_up": true])
        let misses = try w.flow([["do": "reads.it"]], trigger: ["type": "schedule", "every_minutes": 60, "catch_up": false])
        w.now = w.now.addingTimeInterval(5 * 3600 + 1800)
        w.engine.tick()
        let late = await w.settled(w.store.runs(of: catches.id).first)
        #expect(late?.status == .done)
        #expect(late?.why.contains("Meant for") == true)
        #expect(w.store.runs(of: misses.id).isEmpty)
        #expect(w.store.flow(misses.id)?.missed.count == 1)
        w.engine.tick()
        #expect(w.store.runs(of: catches.id).count == 1, "the same time doesn't run twice")
    }

    // MARK: A run

    @Test func aLiveRunGoesThroughWithItsValues() async throws {
        let w = try World()
        let flow = try w.flow([["id": "a", "do": "reads.it", "with": ["q": "x"]], ["id": "b", "ai": "Sum up {{a}}"],
                               ["if": ["value": "{{b}}", "test": "contains", "than": "three"], "then": [["id": "c", "do": "notes.save", "with": ["text": "Note: {{b}}"]]], "else": [["id": "d", "do": "changes.it", "with": ["text": "never"]]]]])
        let run = await w.settled(w.engine.start(flow, mode: .live, why: "test"))
        #expect(run?.status == .done)
        #expect(w.host.written == ["Sum up result of reads.it"])
        #expect(w.host.calls.map(\.tool) == ["reads.it", "notes.save"])
        #expect(w.host.calls.last?.input["text"] as? String == "Note: Three lines.")
        #expect(w.host.calls.allSatisfy { $0.plan == flow.planId })
    }

    @Test func aPracticeRunReadsWhatSidefolkVouchesForAndChangesNothing() async throws {
        let w = try World()
        let flow = try w.flow([["id": "a", "do": "reads.it"], ["id": "b", "do": "says.it.reads"], ["id": "c", "do": "changes.it", "with": ["text": "{{a}}"]], ["id": "q", "ask": "Sure?", "options": ["Yes", "No"]],
                               ["wait_minutes": 60], ["id": "t", "text": "{{q}}"]], state: .draft)
        let run = await w.settled(w.engine.start(flow, mode: .practice, why: "test"))
        #expect(run?.status == .done, "a wait doesn't hold a practice run")
        #expect(w.host.calls.map(\.tool) == ["reads.it"], "an author's word that a tool reads isn't enough")
        #expect(run?.record(of: "a")?.status == .done)
        #expect(run?.record(of: "b")?.status == .would)
        #expect(run?.record(of: "c")?.summary.contains("Sentence for changes.it") == true)
        #expect(run?.values.value("t") == "Yes", "it goes on as if the first answer were given")
    }

    @Test func aPracticeRunNeverCallsWhatWouldAsk() async throws {
        let w = try World()
        w.host.decision = .ask
        let flow = try w.flow([["id": "a", "do": "reads.it"]], state: .draft)
        let run = await w.settled(w.engine.start(flow, mode: .practice, why: "test"))
        #expect(w.host.calls.isEmpty)
        #expect(run?.record(of: "a")?.note != nil)
    }

    @Test func nobodyAnsweringParksItAndTheRunCarriesOnWhenTheyDo() async throws {
        let w = try World()
        w.host.answers["changes.it"] = [Actions.Outcome(status: .unanswered, text: "")]
        let flow = try w.flow([["id": "a", "do": "changes.it", "with": ["text": "x"]], ["id": "b", "text": "after"]])
        let run = await w.settled(w.engine.start(flow, mode: .live, why: "test"))
        #expect(run?.status == .needs_you)
        #expect(run?.record(of: "b") == nil)
        #expect(!w.engine.isRunning(flow.id), "parked, the flow can be set off again")
        await w.quiet()
        #expect(!w.host.forward.isEmpty, "it asks, where they are, what to do")
        w.engine.proceed(run!.id, .try_again)
        await w.quiet()
        let done = await w.settled(w.store.run(run!.id))
        #expect(done?.status == .done)
        #expect(w.host.calls.count == 2)
    }

    @Test func afterAFailureItStopsCarriesOnOrTriesAgainAsTheStepSays() async throws {
        let w = try World()
        w.host.answers["changes.it"] = [Actions.Outcome(status: .failed, text: "boom"), Actions.Outcome(status: .failed, text: "boom")]
        let stops = try w.flow([["do": "changes.it", "with": ["text": "x"]], ["id": "z", "text": "after"]])
        let stopped = await w.settled(w.engine.start(stops, mode: .live, why: "t"))
        #expect(stopped?.status == .interrupted, "it may have happened: the person looks")
        #expect(stopped?.problem?.contains("boom") == true)
        let goes = try w.flow([["id": "x", "do": "changes.it", "with": ["text": "x"], "on_failure": "carry_on"], ["id": "z", "text": "[{{x}}]"]])
        let went = await w.settled(w.engine.start(goes, mode: .live, why: "t"))
        #expect(went?.status == .done)
        #expect(went?.values.value("z") == "[]")
    }

    @Test func onlyWhatOnlyReadsIsTriedAgainByItself() async throws {
        let w = try World()
        w.host.answers["reads.it"] = [Actions.Outcome(status: .failed, text: "down")]
        let reads = try w.flow([["do": "reads.it", "on_failure": "retry"]])
        let waiting = await w.settled(w.engine.start(reads, mode: .live, why: "t"))
        #expect(waiting?.status == .waiting)
        w.now = w.now.addingTimeInterval(31)
        w.engine.tick()
        await w.quiet()
        #expect(w.store.run(waiting!.id)?.status == .done)

        w.host.answers["changes.it"] = [Actions.Outcome(status: .failed, text: "boom")]
        let changes = try w.flow([["do": "changes.it", "with": ["text": "x"], "on_failure": "retry"]])
        let stopped = await w.settled(w.engine.start(changes, mode: .live, why: "t"))
        #expect(stopped?.status == .interrupted, "repeating what may have happened never happens by itself")
        #expect(w.host.calls.filter { $0.tool == "changes.it" }.count == 1)
    }

    // MARK: The way forward on the page

    /// What Sidefolk would keep of a page: a part it can't read is dropped, and a stopped run with no way forward is a dead end.
    @Test func aStoppedRunOffersItsWayForwardOnThePage() throws {
        let w = try World()
        let app = App(folder: w.folder)
        let body = try FlowCodec.body(["steps": [["id": "a", "do": "changes.it", "with": ["text": "x"]], ["id": "b", "text": "after"]]])
        var run = Run(id: "r", flow: "f", flowName: "Tidy", mode: .live, status: .interrupted, why: "t", startedAt: w.now, body: body)
        run.records = [.init(step: "a", status: .unknown, summary: "Change it", at: w.now)]
        for status in [Run.Status.interrupted, .needs_you] {
            run.status = status
            let page = Pages.runPage(run, app, state: Arguments([:]))
            let end = page.sections.filter { $0.place == .trailing }
            let labels: [String] = end.flatMap(\.blocks).compactMap { block in
                if case .picker(let label, _, _, let options, _, _, _, _, _) = block { return options.count == 3 ? label : nil }
                return nil
            }
            #expect(labels.count == 1)
            #expect(labels.first?.isEmpty == false, "Sidefolk drops a choice with no label")
        }
    }

    // MARK: Reaching further

    @Test func answeringWhereTheyAreGetsAStoppedRunGoing() async throws {
        let w = try World()
        w.host.answers["changes.it"] = [Actions.Outcome(status: .unanswered, text: "")]
        w.host.wayForward = L("Try again")
        let flow = try w.flow([["id": "a", "do": "changes.it", "with": ["text": "x"]], ["id": "b", "text": "after"]])
        let run = await w.settled(w.engine.start(flow, mode: .live, why: "test"))
        for _ in 0..<200 where w.store.run(run!.id)?.status != .done { try await Task.sleep(for: .milliseconds(5)) }
        #expect(w.store.run(run!.id)?.status == .done)
    }

    @Test func anAnswerToAnOldQuestionDoesntMoveALaterStop() async throws {
        let w = try World()
        w.host.answers["changes.it"] = [Actions.Outcome(status: .unanswered, text: ""), Actions.Outcome(status: .ok, text: "a"), Actions.Outcome(status: .unanswered, text: "")]
        w.host.slowAnswers = [L("Skip this step"), nil]
        let flow = try w.flow([["id": "a", "do": "changes.it", "with": ["text": "x"]], ["id": "b", "do": "changes.it", "with": ["text": "y"]], ["id": "c", "text": "after"]])
        let run = await w.settled(w.engine.start(flow, mode: .live, why: "test"))
        #expect(run?.status == .needs_you)
        // On the page, while the question about the first stop is still up.
        w.engine.proceed(run!.id, .try_again)
        await w.quiet()
        let after = w.store.run(run!.id)
        #expect(after?.status == .needs_you, "stopped at the second step, and the old answer doesn't move it")
        #expect(after?.record(of: "c") == nil)
    }

    @Test func nobodyAnsweringLeavesItWhereItIs() async throws {
        let w = try World()
        w.host.answers["changes.it"] = [Actions.Outcome(status: .unanswered, text: "")]
        let flow = try w.flow([["id": "a", "do": "changes.it", "with": ["text": "x"]]])
        let run = await w.settled(w.engine.start(flow, mode: .live, why: "test"))
        await w.quiet()
        #expect(!w.host.forward.isEmpty)
        #expect(w.store.run(run!.id)?.status == .needs_you)
    }

    @Test func somethingHappeningSetsOffTheFlowsWaitingForItWithItsWords() async throws {
        let w = try World()
        let any = try w.flow([["id": "a", "text": "{{trigger}}"]], trigger: ["type": "event", "event": "reminder.fired"])
        let only = try w.flow([["id": "a", "text": "x"]], trigger: ["type": "event", "event": "reminder.fired", "contains": "dentist"])
        let other = try w.flow([["id": "a", "text": "x"]], trigger: ["type": "event", "event": "note.saved"])
        w.engine.happened(name: "reminder.fired", title: "Call the bank", detail: nil)
        await w.quiet()
        let ran = w.store.runs(of: any.id).first
        #expect(ran?.record(of: "a")?.output == "Call the bank")
        #expect(w.store.runs(of: only.id).isEmpty, "it doesn't mention what this one waits for")
        #expect(w.store.runs(of: other.id).isEmpty)
        w.engine.happened(name: "reminder.fired", title: "The DENTIST at three", detail: nil)
        await w.quiet()
        #expect(w.store.runs(of: only.id).count == 1)
    }

    @Test func aDraftWaitingForSomethingDoesntGo() async throws {
        let w = try World()
        let draft = try w.flow([["id": "a", "text": "x"]], trigger: ["type": "event", "event": "mac.woke"], state: .draft)
        w.engine.happened(name: "mac.woke", title: nil, detail: nil)
        await w.quiet()
        #expect(w.store.runs(of: draft.id).isEmpty)
    }

    @Test func anEventAndAnotherFlowReadBackExactly() throws {
        let body = try FlowCodec.body(["trigger": ["type": "event", "event": "note.saved", "contains": "tax"], "steps": [["id": "a", "run_flow": "Other"]]])
        #expect(body.trigger == .event("note.saved", contains: "tax"))
        #expect(try FlowCodec.body(FlowCodec.json(body)) == body)
        #expect(throws: (any Error).self) { try FlowCodec.body(["trigger": ["type": "event", "event": "nonsense"], "steps": []]) }
    }

    @Test func aFlowSetsOffAnotherButNotOneThatsPaused() async throws {
        let w = try World()
        let other = try w.flow([["id": "a", "text": "x"]])
        var renamed = other
        renamed.name = "Other"
        w.store.save(renamed)
        let caller = try w.flow([["id": "go", "run_flow": "Other"]])
        let run = await w.settled(w.engine.start(caller, mode: .live, why: "t"))
        #expect(run?.status == .done)
        await w.quiet()
        #expect(w.store.runs(of: other.id).count == 1)
        renamed.state = .paused
        w.store.save(renamed)
        let again = await w.settled(w.engine.start(caller, mode: .live, why: "t"))
        #expect(again?.status == .failed, "a flow they paused stays paused")
        renamed.state = .draft
        w.store.save(renamed)
        let draft = await w.settled(w.engine.start(caller, mode: .live, why: "t"))
        #expect(draft?.status == .failed, "and a draft isn't set off by another flow")
        #expect(w.store.runs(of: other.id).count == 1)
    }

    @Test func aJobTooLongToShowIsMarkedToFix() throws {
        let w = try World()
        w.catalog.use(Actions.Listing(tools: [Actions.Tool(name: "companion.job", title: "Job", schema: #"{"properties":{"job":{"type":"string"}},"required":["job"]}"#)]))
        let long = try FlowCodec.body(["steps": [["id": "j", "do": "companion.job", "with": ["job": String(repeating: "a", count: 201)]]]])
        let fine = try FlowCodec.body(["steps": [["id": "j", "do": "companion.job", "with": ["job": "Tidy up"]]]])
        #expect(long.problems(w.catalog).contains { $0.step == "j" })
        #expect(fine.problems(w.catalog).isEmpty)
    }

    @Test func aPlanSaysWhatElseItSetsOff() throws {
        let w = try World()
        let flow = try w.flow([["id": "go", "run_flow": "Other"]])
        #expect(w.engine.livePlan(flow).when.contains("Other"))
    }

    // MARK: After a stop

    @Test func aStepThatChangesThingsIsNeverRepeatedAfterACrash() async throws {
        let w = try World()
        w.host.hold = "changes.it"
        let flow = try w.flow([["id": "a", "do": "reads.it"], ["id": "b", "do": "changes.it", "with": ["text": "x"]], ["id": "c", "text": "after"]])
        let run = w.engine.start(flow, mode: .live, why: "t")
        for _ in 0..<200 where w.store.run(run!.id)?.record(of: "b")?.status != .running { try await Task.sleep(for: .milliseconds(5)) }
        #expect(w.host.calls.count == 2)

        w.restart()
        w.host.hold = nil
        w.engine.recover()
        let after = w.store.run(run!.id)
        #expect(after?.status == .interrupted)
        #expect(after?.record(of: "b")?.status == .unknown)
        #expect(w.host.calls.count == 2, "it wasn't called again")

        w.engine.proceed(run!.id, .carry_on)
        await w.quiet()
        let done = await w.settled(w.store.run(run!.id))
        #expect(done?.status == .done)
        #expect(done?.record(of: "b")?.status == .skipped)
        #expect(w.host.calls.count == 2)
    }

    @Test func aStepThatOnlyReadsGoesAgainAfterACrash() async throws {
        let w = try World()
        w.host.hold = "reads.it"
        let flow = try w.flow([["id": "a", "do": "reads.it"], ["id": "c", "text": "{{a}}"]])
        let run = w.engine.start(flow, mode: .live, why: "t")
        for _ in 0..<200 where w.store.run(run!.id)?.record(of: "a")?.status != .running { try await Task.sleep(for: .milliseconds(5)) }
        w.restart()
        w.host.hold = nil
        w.engine.recover()
        await w.quiet()
        let done = await w.settled(w.store.run(run!.id))
        #expect(done?.status == .done)
        #expect(done?.values.value("c") == "result of reads.it")
    }

    @Test func aWaitSurvivesARestart() async throws {
        let w = try World()
        let flow = try w.flow([["wait_minutes": 10], ["id": "c", "text": "after"]])
        let run = await w.settled(w.engine.start(flow, mode: .live, why: "t"))
        #expect(run?.status == .waiting)
        w.restart()
        w.engine.recover()
        w.engine.tick()
        await w.quiet()
        #expect(w.store.run(run!.id)?.status == .waiting, "not yet")
        w.now = w.now.addingTimeInterval(601)
        w.engine.tick()
        await w.quiet()
        #expect(w.store.run(run!.id)?.status == .done)
    }

    // MARK: Turning on

    @Test func itIsOnOnlyOnceThePersonSaysYes() async throws {
        let w = try World()
        var flow = try w.flow([["do": "changes.it", "with": ["text": "x {{today}}"]], ["id": "q", "ask": "Sure?"]], state: .draft)
        w.host.planAnswer = .refused("denied")
        w.engine.turnOn(flow.id)
        await w.quiet()
        flow = w.store.flow(flow.id)!
        #expect(flow.state == .draft)
        #expect(flow.live == nil)
        #expect(flow.startProblem != nil)
        w.host.planAnswer = .allowed(standing: [true, true])
        w.engine.turnOn(flow.id)
        await w.quiet()
        flow = w.store.flow(flow.id)!
        #expect(flow.state == .on)
        #expect(flow.live == flow.draft)
        #expect(flow.startProblem == nil)
        let plan = w.host.plans.last
        #expect(plan?.id == flow.planId)
        #expect(plan?.steps.map(\.tool) == ["changes.it", "ask.user"])
        #expect(plan?.steps.first?.input["text"] as? String == "x {{today}}", "the card shows what's filled in, as written")
    }

    @Test func aChangeToAnOnFlowWaitsAndTheLiveOneKeepsRunning() async throws {
        let w = try World()
        var flow = try w.flow([["id": "a", "do": "reads.it"]])
        flow.draft = try FlowCodec.body(["steps": [["id": "z", "do": "notes.save", "with": ["text": "x"]]]])
        w.store.save(flow)
        #expect(w.store.flow(flow.id)?.hasChanges == true)
        _ = await w.settled(w.engine.start(w.store.flow(flow.id)!, mode: .live, why: "t"))
        #expect(w.host.calls.map(\.tool) == ["reads.it"], "what runs is what the person allowed")
    }

    @Test func aWatchFlowMakesItsWatchAndHearsIt() async throws {
        let w = try World()
        var flow = try w.flow([["id": "n", "text": "Saw: {{trigger}}"]], trigger: ["type": "watch", "kind": "url_change", "target": "https://example.com"], state: .draft)
        w.engine.turnOn(flow.id)
        await w.quiet()
        flow = w.store.flow(flow.id)!
        #expect(w.host.calls.first?.tool == "watch.create")
        #expect(w.host.calls.first?.input["mode"] as? String == "repeat")
        #expect(w.host.calls.first?.plan == flow.planId)
        #expect(flow.watchTitle == Engine.watchTitle(flow))
        let tools = Set(w.host.plans.last?.steps.map(\.tool) ?? [])
        #expect(tools.isSuperset(of: ["watch.create", "watch.stop"]))
        w.engine.watchFired(title: flow.watchTitle!, summary: "It changed")
        await w.quiet()
        #expect(w.store.runs(of: flow.id).first?.values.value("n") == "Saw: It changed")
        w.engine.watchFired(title: "someone else's", summary: "x")
        await w.quiet()
        #expect(w.store.runs(of: flow.id).count == 1)
    }

    @Test func aRunawayFlowPausesItself() async throws {
        let w = try World()
        w.engine.runawayLimit = 2
        let flow = try w.flow([["id": "n", "text": "x"]])
        _ = await w.settled(w.engine.start(flow, mode: .live, why: "1"))
        _ = await w.settled(w.engine.start(flow, mode: .live, why: "2"))
        #expect(w.engine.start(flow, mode: .live, why: "3") == nil)
        #expect(w.store.flow(flow.id)?.state == .paused)
        #expect(w.store.flow(flow.id)?.pausedBecause != nil)
    }

    @Test func thirtyRunsInAnHourIsTheStopAndItHoldsAgainstAFlowThatSetsItselfOff() async throws {
        let w = try World()
        #expect(w.engine.runawayLimit == 30)
        let flow = try w.flow([["id": "n", "text": "x"]], trigger: ["type": "event", "event": "attention.changed"])
        for _ in 0..<30 {
            w.engine.happened(name: "attention.changed", title: "focus", detail: nil)
            for _ in 0..<200 where w.engine.isRunning(flow.id) { try await Task.sleep(for: .milliseconds(2)) }
            w.now = w.now.addingTimeInterval(10)
        }
        #expect(w.store.runs(of: flow.id, since: w.now.addingTimeInterval(-3600)).count == 30)
        #expect(w.store.flow(flow.id)?.state == .on)
        w.engine.happened(name: "attention.changed", title: "focus", detail: nil)
        #expect(w.store.flow(flow.id)?.state == .paused, "the thirty-first pauses it, and says why")
        #expect(w.store.flow(flow.id)?.pausedBecause != nil)
        w.engine.happened(name: "attention.changed", title: "focus", detail: nil)
        #expect(w.store.runs(of: flow.id, since: w.now.addingTimeInterval(-3600)).count == 30, "paused, nothing sets it off")
    }

    @Test func oneRunAtATimeWithOneMoreWaiting() async throws {
        let w = try World()
        w.host.hold = "reads.it"
        let flow = try w.flow([["do": "reads.it"]])
        let first = w.engine.start(flow, mode: .live, why: "1")
        #expect(first != nil)
        #expect(w.engine.start(flow, mode: .live, why: "2") == nil)
        #expect(w.engine.start(flow, mode: .live, why: "3") == nil)
        #expect(w.engine.isRunning(flow.id))
    }

    @Test func pauseAndResumeNeedNoCardUnlessItChanged() async throws {
        let w = try World()
        var flow = try w.flow([["do": "reads.it"]])
        w.engine.pause(flow.id)
        #expect(w.store.flow(flow.id)?.state == .paused)
        w.engine.resume(flow.id)
        #expect(w.store.flow(flow.id)?.state == .on)
        #expect(w.host.plans.isEmpty)
        w.engine.pause(flow.id)
        flow = w.store.flow(flow.id)!
        flow.draft = FlowBody(steps: flow.draft.steps + [Step(id: "more", kind: .text("x"))])
        w.store.save(flow)
        w.engine.resume(flow.id)
        await w.quiet()
        #expect(w.host.plans.count == 1)
    }

    @Test func deletingTakesItsPlansAndRuns() async throws {
        let w = try World()
        let flow = try w.flow([["id": "n", "text": "x"]])
        _ = await w.settled(w.engine.start(flow, mode: .live, why: "1"))
        w.engine.delete(flow.id)
        #expect(w.store.flow(flow.id) == nil)
        #expect(w.store.runs(of: flow.id).isEmpty)
        #expect(Set(w.host.forgotten) == [flow.planId, flow.practiceId])
    }

    // MARK: Words and data

    @Test func conditionsReadValuesAsPeopleWould() {
        var v = Values()
        v.set("t", "Rain at 18 °C")
        #expect(Condition(value: "{{t}}", test: .contains, than: "rain").holds(v))
        #expect(!Condition(value: "{{t}}", test: .not_contains, than: "RAIN").holds(v))
        #expect(Condition(value: "{{t}}", test: .more_than, than: "17").holds(v))
        #expect(!Condition(value: "{{t}}", test: .less_than, than: "17").holds(v))
        #expect(Condition(value: "{{missing}}", test: .is_empty, than: "").holds(v))
        #expect(Condition(value: "{{t}}", test: .not_empty, than: "").holds(v))
        #expect(!Condition(value: "words", test: .more_than, than: "1").holds(v), "no number, no comparison")
    }

    @Test func valuesFillInWhereTheyreNamedAndOnlyThere() {
        var v = Values()
        v.set("a", "{{b}}")
        v.set("b", "secret")
        #expect(v.fill("x {{a}} y {{ b }}") == "x {{b}} y secret", "a value's own braces aren't read again")
        #expect(v.fill("{{none}}!") == "!")
        #expect(Values.references("{{a}} {{ b }} {c}") == ["a", "b"])
    }

    @Test func everyTemplateIsAValidFlow() throws {
        for t in Templates.all {
            let body = try FlowCodec.body(t.body)
            #expect(!body.steps.isEmpty, "\(t.id)")
        }
    }

    @Test func aFlowReadsAloud() throws {
        let w = try World()
        let body = try FlowCodec.body(["trigger": ["type": "schedule", "days": ["mon", "tue", "wed", "thu", "fri"], "at": "08:30"], "steps": [["id": "a", "do": "reads.it", "name": "Look"], ["do": "notes.save", "with": ["text": "{{a}}"]]]])
        let said = Words.aloud(body, catalog: w.catalog)
        #expect(said.contains("Every weekday"))
        #expect(said.contains("Look"))
        #expect(said.contains("[Look]"))
    }
}

/// What 1202 must not do to a person's flows.
@MainActor @Suite(.serialized) struct SideflowFlowsAreKeptTests {
    typealias World = SideflowTests.World

    private func page(_ app: App, _ op: String, _ flow: Flow, _ extra: [String: Any]) async throws {
        var input: [String: Any] = ["op": op, "flow": flow.id]
        input.merge(extra) { _, new in new }
        _ = try await Actions_UI.handle(Arguments(input), app)
    }

    private func app(_ w: World) -> App { App(folder: w.folder.appendingPathComponent("app")) }

    @Test func clearingAWatchsTargetLosesNothing() async throws {
        let w = try World()
        let app = app(w)
        let flow = app.newFlow(name: "Watch it", body: try FlowCodec.body(["trigger": ["type": "watch", "kind": "url_change", "target": "https://x.example"], "steps": [["id": "a", "text": "x"]]]))
        try await page(app, "watch_target", flow, ["text": ""])
        let again = App(folder: w.folder.appendingPathComponent("app"))
        let back = try #require(again.store.flow(flow.id), "still there at the next launch")
        #expect(back.draft.problems(again.catalog).contains { !$0.text.isEmpty }, "and marked to fix")
    }

    @Test func aNumberOverTheLimitLosesNothing() async throws {
        let w = try World()
        let app = app(w)
        let flow = app.newFlow(name: "Often", body: try FlowCodec.body(["trigger": ["type": "schedule", "every_minutes": 60], "steps": [["id": "a", "text": "x"]]]))
        await #expect(throws: Problem.self, "refused where it's typed") { try await self.page(app, "every", flow, ["text": "20000"]) }
        let again = App(folder: w.folder.appendingPathComponent("app"))
        #expect(again.store.flow(flow.id) != nil)
    }

    @Test func aFlowInAFileThatIsntValidShowsAndStaysOnDisk() async throws {
        let w = try World()
        let good = try w.flow([["id": "a", "text": "x"]])
        let file = w.folder.appendingPathComponent("flows.json")
        var list = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [Any])
        list.append(["id": "strange", "name": "From a later version", "draft": ["trigger": ["type": "from_the_future"], "steps": []]])
        list.append("not even a flow")
        try JSONSerialization.data(withJSONObject: list).write(to: file)
        w.restart()
        #expect(w.store.flow(good.id) != nil)
        #expect(w.store.unreadableCount == 2, "kept, and counted so the page can say so")
        w.store.save(try #require(w.store.flow(good.id)))
        let text = try String(contentsOf: file, encoding: .utf8)
        #expect(text.contains("From a later version"))
        #expect(text.contains("not even a flow"))
        let app = App(folder: w.folder)
        #expect(!Pages.storeWarnings(app).isEmpty, "the app says so")
        let page = await Pages.make(app, state: Arguments([:]), background: false)
        #expect(page.sections.count > Pages.places(app, state: Arguments([:]), here: "flows", flow: nil).count)
    }

    @Test func infinityAndNotANumberAreRefusedWhereTheyreTyped() async throws {
        let w = try World()
        let app = app(w)
        app.catalog.use(Actions.Listing(tools: [Actions.Tool(name: "reads.it", title: "Read it", schema: #"{"properties":{"n":{"type":"number"}}}"#, mutates: false, readsOnly: true)]))
        let flow = app.newFlow(name: "F", body: try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "a", "do": "reads.it"]]]))
        for bad in ["inf", "-inf", "nan", "infinity", "1e999"] {
            await #expect(throws: Problem.self, "\(bad)") { try await self.page(app, "param", flow, ["step": "a", "name": "n", "text": bad]) }
        }
        try await page(app, "param", flow, ["step": "a", "name": "n", "text": "2.5"])
        #expect(app.store.flowsNotSaved == false)
        let again = App(folder: w.folder.appendingPathComponent("app"))
        #expect(again.store.flow(flow.id) != nil)
    }

    @Test func aHugeNumberAFlowReadNeverStopsTheSaving() throws {
        #expect(Condition.number(String(repeating: "9", count: 400)) == nil)
        let w = try World()
        var flow = try w.flow([["id": "a", "do": "reads.it"]])
        if case .action(let tool, var input) = flow.draft.steps[0].kind {
            input["n"] = .number(.infinity)
            flow.draft.steps[0].kind = .action(tool: tool, input: input)
        }
        w.store.save(flow)
        #expect(!w.store.flowsNotSaved)
        #expect(w.store.failedSaves == 0)
    }

    @Test func aFlowsFileThatCantBeReadIsNeverWrittenOver() throws {
        let w = try World()
        let file = w.folder.appendingPathComponent("flows.json")
        try Data("this isn't a list".utf8).write(to: file)
        w.restart()
        _ = try w.flow([["id": "a", "text": "x"]])
        let kept = try FileManager.default.contentsOfDirectory(atPath: w.folder.path).filter { $0.hasPrefix("flows") && $0.hasSuffix(".json") }
        let words = try kept.map { try String(contentsOf: w.folder.appendingPathComponent($0), encoding: .utf8) }
        #expect(words.contains("this isn't a list"), "still on disk, under some name")
        #expect(w.store.damagedFile != nil, "and it says so")
    }

    @Test func aFlowsFileThatCantBeOpenedIsNeverWrittenOver() throws {
        let w = try World()
        let file = w.folder.appendingPathComponent("flows.json")
        try Data("mine".utf8).write(to: file)
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: file.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: file.path) }
        w.restart()
        _ = try w.flow([["id": "a", "text": "x"]])
        #expect(w.store.flowsNotSaved, "refused, and it says so")
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: file.path)
        #expect((try? String(contentsOf: file, encoding: .utf8)) == "mine")
    }
}

/// Pages as Sidefolk would get them, in the states worth looking at: `SIDEFLOW_PAGES_OUT=<folder> swift test --filter sideflowPages`, then
/// `SidefolkApp --page-json <file> <out.png>` draws each with Sidefolk's own parts, off every screen.
@MainActor @Suite(.serialized) struct SideflowPageShots {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["SIDEFLOW_PAGES_OUT"] != nil, "only when asked for"))
    func sideflowPages() async throws {
        let out = URL(fileURLWithPath: ProcessInfo.processInfo.environment["SIDEFLOW_PAGES_OUT"]!)
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("shots-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let app = App(folder: folder)
        app.catalog.use(Actions.Listing(tools: [
            Actions.Tool(name: "calendar.today", title: "Today's calendar", description: "Reads today", category: "time", readsOnly: true),
            Actions.Tool(name: "notes.save", title: "Save to notebook", schema: #"{"properties":{"text":{"type":"string","title":"Text"},"collection":{"type":"string"}},"required":["text"]}"#, category: "notes"),
            Actions.Tool(name: "notify.user", title: "Notify the user", schema: #"{"properties":{"title":{"type":"string"},"body":{"type":"string"},"level":{"type":"string","enum":["gentle","attention"]}},"required":["title"]}"#),
        ]))
        func write(_ page: Page, _ name: String) throws {
            try JSONSerialization.data(withJSONObject: page.sent, options: [.sortedKeys, .prettyPrinted]).write(to: out.appendingPathComponent(name + ".json"))
        }
        let body = try FlowCodec.body(["trigger": ["type": "schedule", "days": ["mon", "tue", "wed", "thu", "fri"], "at": "08:30", "catch_up": true], "steps": [
            ["id": "plan", "do": "calendar.today", "name": "Get today's plan"],
            ["id": "c", "if": ["value": "{{plan}}", "test": "contains", "than": "review"], "then": [["id": "w", "ai": "Three short lines about {{plan}}"], ["id": "tell", "do": "notify.user", "with": ["title": "Today: {{w}}"]]],
             "else": [["id": "save", "do": "notes.save", "with": ["text": "A quiet day"]]]],
        ]])
        var flow = app.newFlow(name: "Morning brief", body: body)
        app.nav.inspect(.step("c"), in: flow.id)
        app.refreshPreflight(flow.id)
        try await Task.sleep(for: .milliseconds(200))
        let state = Arguments(["flow": flow.id])
        try write(await Pages.make(app, state: state, background: false), "saved-draft")
        flow.saved = flow.draft
        flow.draft = Editing.insert(Step(id: "more", kind: .text("One more line")), after: "plan", in: flow.draft)
        app.store.save(flow)
        try write(await Pages.make(app, state: state, background: false), "unsaved")
        flow.saved = nil
        flow.live = body
        flow.state = .on
        app.store.save(flow)
        try write(await Pages.make(app, state: state, background: false), "on-changes")
        flow.live = nil
        flow.state = .draft
        app.store.save(flow)
        app.nav.inspect(.step("tell"), in: flow.id)
        try write(await Pages.make(app, state: state, background: false), "action-form")
        app.nav.inspect(.trigger, in: flow.id)
        try write(await Pages.make(app, state: state, background: false), "trigger-form")
        let fresh = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "plan", "do": "calendar.today"],
            ["id": "c", "if": ["value": "{{plan}}", "test": "contains", "than": "review", "and": [["value": "{{today}}", "test": "not_empty"]]], "then": [], "else": []]]])
        let empty = app.newFlow(name: "New condition", body: fresh)
        app.nav.inspect(.step("c"), in: empty.id)
        try write(await Pages.make(app, state: Arguments(["flow": empty.id]), background: false), "condition-empty")
    }
}

@MainActor @Suite(.serialized) struct SideflowCardTests {
    typealias World = SideflowTests.World

    @Test func aScheduleWithNothingToAllowIsStillOnACard() async throws {
        let w = try World()
        let flow = try w.flow([["id": "a", "text": "x"]], trigger: ["type": "schedule", "every_minutes": 60], state: .draft)
        w.engine.turnOn(flow.id)
        await w.quiet()
        #expect(w.host.plans.count == 1)
    }

    @Test func anAIStepIsSaidOnTheCard() async throws {
        let w = try World()
        let flow = try w.flow([["id": "a", "ai": "Write"]], state: .draft)
        w.engine.turnOn(flow.id)
        await w.quiet()
        #expect(w.host.plans.last?.when.contains("your AI") == true)
    }

    @Test func aHandStartedFlowWorkingOnItsOwnValuesHasNothingToRead() async throws {
        let w = try World()
        let flow = try w.flow([["id": "a", "text": "x"]], state: .draft)
        w.engine.turnOn(flow.id)
        await w.quiet()
        #expect(w.host.plans.isEmpty)
        #expect(w.store.flow(flow.id)?.state == .on)
    }

    @Test func whatNobodyReadAsksOnceAndWhatHasAPlanStaysOn() async throws {
        let w = try World()
        let ai = try w.flow([["id": "a", "ai": "Write"]], trigger: ["type": "schedule", "every_minutes": 60])
        let approved = try w.flow([["id": "a", "ai": "Write"]], trigger: ["type": "schedule", "every_minutes": 60])
        let actions = try w.flow([["id": "a", "do": "reads.it"]], trigger: ["type": "schedule", "every_minutes": 60])
        let hand = try w.flow([["id": "a", "text": "x"]])
        w.catalog.use(Actions.Listing(tools: [], plans: [Plans.Standing(id: approved.planId, title: approved.name, standing: [])]))
        w.engine.pauseWhatNobodyRead()
        await w.quiet()
        #expect(w.store.flow(ai.id)?.state == .paused)
        #expect(w.store.flow(approved.id)?.state == .on, "a flow someone read isn't touched")
        #expect(w.store.flow(actions.id)?.state == .on, "each action is checked as it's called")
        #expect(w.store.flow(hand.id)?.state == .on)
        let before = w.host.plans.count
        w.engine.resume(ai.id)
        await w.quiet()
        #expect(w.host.plans.count == before + 1, "resuming shows the card this time")
    }

    @Test func aLongAddressGivesWayOnTheCard() throws {
        let w = try World()
        let flow = try w.flow([["id": "a", "do": "reads.it"], ["id": "b", "run_flow": "Other"]], trigger: ["type": "watch", "kind": "url_change", "target": "https://example.com/" + String(repeating: "a", count: 700)], state: .draft)
        let when = w.engine.livePlan(flow).when
        #expect(when.count <= 600)
        #expect(when.contains("Other"))
    }
}

/// What reading the editing landing found. Each goes through the page's own actions, as a click does.
@MainActor @Suite(.serialized) struct SideflowEditingReadTests {
    typealias World = SideflowTests.World

    private func app(_ w: World) -> App {
        let app = App(folder: w.folder.appendingPathComponent("app"))
        app.engine.host = w.host
        app.catalog.use(Actions.Listing(tools: [Actions.Tool(name: "reads.it", title: "Read it", schema: #"{"properties":{"n":{"type":"number"},"q":{"type":"string"}}}"#, mutates: false, readsOnly: true)]))
        return app
    }

    private func again(_ w: World) -> App { App(folder: w.folder.appendingPathComponent("app")) }

    private func page(_ app: App, _ op: String, _ flow: Flow, _ extra: [String: Any] = [:]) async throws {
        var input: [String: Any] = ["op": op, "flow": flow.id]
        input.merge(extra) { _, new in new }
        _ = try await Actions_UI.handle(Arguments(input), app)
    }

    private func make(_ app: App, _ steps: [[String: Any]]) throws -> Flow {
        app.newFlow(name: "F", body: try FlowCodec.body(["trigger": ["type": "manual"], "steps": steps]))
    }

    @Test func undoAfterASaveShowsAsUnsavedAndKeepsWhatWasSaved() async throws {
        let w = try World()
        let app = app(w)
        let flow = try make(app, [["id": "a", "text": "one"]])
        try await page(app, "compose", flow, ["step": "a", "text": "two"])
        try await page(app, "save", flow)
        #expect(app.store.flow(flow.id)?.hasUnsaved == false)
        try await page(app, "undo", flow)
        let after = try #require(app.store.flow(flow.id))
        #expect(after.draft.step("a")?.kind == .text("one"))
        #expect(after.hasUnsaved, "the step back is on the page only")
        #expect(after.kept.step("a")?.kind == .text("two"), "what was saved is still what's kept")
        try await page(app, "redo", flow)
        #expect(app.store.flow(flow.id)?.hasUnsaved == false, "and forward again is what was saved")
    }

    @Test func undoAfterDiscardBringsItBackUnsaved() async throws {
        let w = try World()
        let app = app(w)
        let flow = try make(app, [["id": "a", "text": "one"]])
        try await page(app, "compose", flow, ["step": "a", "text": "two"])
        try await page(app, "discard", flow)
        try await page(app, "undo", flow)
        let after = try #require(app.store.flow(flow.id))
        #expect(after.draft.step("a")?.kind == .text("two"))
        #expect(after.hasUnsaved)
        #expect(after.kept.step("a")?.kind == .text("one"))
    }

    @Test func anEmptyAIOrQuestionStepReadsBackAndIsMarked() async throws {
        let w = try World()
        let app = app(w)
        let flow = try make(app, [["id": "a", "ai": "Write"], ["id": "b", "ask": "Sure?"]])
        try await page(app, "ai_prompt", flow, ["step": "a", "text": ""])
        try await page(app, "question", flow, ["step": "b", "text": ""])
        let back = try #require(again(w).store.flow(flow.id), "still there at the next launch")
        #expect(back.draft.problems(app.catalog).count >= 2, "and marked to fix")
    }

    @Test func aFlowPastTheStepLimitIsRefusedAtTheEditAndNeverLost() async throws {
        let w = try World()
        let app = app(w)
        let steps: [[String: Any]] = (0..<FlowBody.maxSteps).map { ["id": "s\($0)", "text": "x"] }
        let flow = try make(app, steps)
        await #expect(throws: Problem.self) { try await self.page(app, "dup_step", flow, ["step": "s0"]) }
        #expect(again(w).store.flow(flow.id) != nil)
        // One that got past it some other way still reads back, and is marked.
        var big = try #require(app.store.flow(flow.id))
        big.draft.steps.append(Step(id: "extra", kind: .text("x")))
        app.store.save(big)
        let back = try #require(again(w).store.flow(flow.id))
        #expect(back.draft.problems(app.catalog).contains { !$0.text.isEmpty })
    }

    @Test func aNumberZeroOrOneStaysANumber() throws {
        #expect(JSON(NSNumber(value: 1)) == .number(1))
        #expect(JSON(NSNumber(value: 0)) == .number(0))
        #expect(JSON(true) == .bool(true))
        let parsed = try #require(try JSONSerialization.jsonObject(with: Data(#"{"a":1,"b":true}"#.utf8)) as? [String: Any])
        #expect(JSON(parsed["a"]) == .number(1))
        #expect(JSON(parsed["b"]) == .bool(true))
    }

    @Test func aVeryLargeNumberDoesntStopTheProgram() async throws {
        let w = try World()
        let app = app(w)
        let flow = try make(app, [["id": "a", "do": "reads.it"]])
        try await page(app, "param", flow, ["step": "a", "name": "n", "text": "1e30"])
        let now = try #require(app.store.flow(flow.id))
        app.nav.inspect(.step("a"), in: now.id)
        #expect(!Inspector.sections(now, app, problems: []).isEmpty, "drawing its form")
    }

    @Test func aFlowThatStopsBeingAWatchTakesItsWatchWithIt() async throws {
        let w = try World()
        var flow = try w.flow([["id": "a", "do": "reads.it"]], trigger: ["type": "watch", "kind": "url_change", "target": "https://x.example"])
        flow.watchTitle = "T"
        flow.draft = try FlowCodec.body(["trigger": ["type": "schedule", "every_minutes": 60], "steps": [["id": "a", "do": "reads.it"]]])
        w.store.save(flow)
        #expect(w.engine.livePlan(flow).steps.contains { $0.tool == "watch.stop" }, "on the card")
        w.engine.turnOn(flow.id)
        await w.quiet()
        #expect(w.host.calls.contains { $0.tool == "watch.stop" })
        #expect(w.store.flow(flow.id)?.watchTitle == nil)
    }

    @Test func aWatchThatWouldntStopNoLongerSetsTheFlowOffAndItSaysSo() async throws {
        let w = try World()
        var flow = try w.flow([["id": "a", "text": "x"]], trigger: ["type": "watch", "kind": "url_change", "target": "https://x.example"])
        flow.watchTitle = "T"
        flow.draft = try FlowCodec.body(["trigger": ["type": "schedule", "every_minutes": 60], "steps": [["id": "a", "text": "x"]]])
        w.store.save(flow)
        w.host.answers["watch.stop"] = [Actions.Outcome(status: .failed, text: "no")]
        w.engine.turnOn(flow.id)
        await w.quiet()
        let after = try #require(w.store.flow(flow.id))
        #expect(after.watchTitle == "T", "still the way to reach it")
        #expect(after.startProblem != nil)
        w.engine.watchFired(title: "T", summary: "changed")
        await w.quiet()
        #expect(w.store.runs(of: flow.id).isEmpty, "what the card didn't show doesn't set it off")
    }

    @Test func aWatchAlreadyGoneLetsTheNameGo() async throws {
        let w = try World()
        var flow = try w.flow([["id": "a", "text": "x"]], trigger: ["type": "watch", "kind": "url_change", "target": "https://x.example"])
        flow.watchTitle = "T"
        flow.draft = try FlowCodec.body(["trigger": ["type": "schedule", "every_minutes": 60], "steps": [["id": "a", "text": "x"]]])
        w.store.save(flow)
        w.host.answers["watch.stop"] = [Actions.Outcome(status: .failed, text: "gone", notFound: true)]
        w.engine.turnOn(flow.id)
        await w.quiet()
        #expect(w.store.flow(flow.id)?.watchTitle == nil)
        #expect(w.store.flow(flow.id)?.startProblem == nil)
    }

    @Test func saveAlwaysHasItsKeySoWhatsBeingTypedGetsHandedOver() async throws {
        let w = try World()
        let app = app(w)
        let flow = try make(app, [["id": "a", "text": "one"]])
        let page = await Pages.make(app, state: Arguments(["flow": flow.id]), background: false)
        #expect(page.shortcuts.contains { $0.key == "cmd+s" }, "saved, and somebody typing")
        #expect(!page.shortcuts.contains { $0.key == "cmd+return" }, "that key is Ask's, on the same window")
    }

    @Test func aMalformedConditionIsRefusedNotQuietlyReadAsSomethingElse() {
        func body(_ c: [String: Any]) throws -> FlowBody { try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "c", "if": c, "then": [], "else": []]]]) }
        let check: [String: Any] = ["value": "a", "test": "is", "than": "b"]
        #expect(throws: Problem.self) { _ = try body(check.merging(["and": [check], "or": [check]]) { a, _ in a }) }
        #expect(throws: Problem.self) { _ = try body(check.merging(["or": "x"]) { a, _ in a }) }
    }

    @Test func anyOfKeepsItsMeaningWithOneCheckLeft() throws {
        var c = Condition(value: "a", test: .is, than: "b")
        c.any = true
        let body = FlowBody(steps: [Step(id: "c", kind: .branch(c, then: [], otherwise: []))])
        let back = try FlowCodec.body(FlowCodec.json(body))
        guard case .branch(let read, _, _)? = back.step("c")?.kind else { Issue.record("shape"); return }
        #expect(read.any)
    }

    @Test func aBlankCheckIsMarkedNotAlwaysFalse() throws {
        let w = try World()
        var c = Condition(value: "a", test: .contains, than: "b")
        c.also = [Condition(value: "", test: .contains, than: "")]
        let flow = FlowBody(steps: [Step(id: "c", kind: .branch(c, then: [], otherwise: []))])
        #expect(flow.problems(w.catalog).contains { $0.step == "c" })
    }

    @Test func turningOnLooksAtWhatsKeptNotWhatsBeingTyped() async throws {
        let w = try World()
        var flow = try w.flow([["id": "a", "do": "reads.it"]], trigger: ["type": "watch", "kind": "url_change", "target": "https://x.example"], state: .draft)
        flow.saved = flow.draft
        flow.draft.trigger = .watch(WatchTrigger(kind: "url_change", target: ""))
        w.store.save(flow)
        w.engine.turnOn(flow.id)
        await w.quiet()
        #expect(w.host.plans.count == 1, "what's saved is fine, and it's what goes on")
        #expect(w.store.flow(flow.id)?.state == .on)
    }

    @Test func aRunOnceUsesWhatWasSavedNotWhatsBeingTyped() async throws {
        let w = try World()
        var flow = try w.flow([["id": "a", "text": "saved"]], state: .draft)
        flow.saved = flow.draft
        flow.draft = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "a", "text": "typing"]]])
        w.store.save(flow)
        let run = await w.settled(w.engine.start(flow, mode: .once, why: "t"))
        #expect(run?.values.value("a") == "saved")
    }

    @Test func anAgentsChangeClearsThePagesUndo() async throws {
        let w = try World()
        let app = app(w)
        let flow = try make(app, [["id": "a", "text": "one"]])
        try await page(app, "compose", flow, ["step": "a", "text": "two"])
        try await page(app, "save", flow)
        app.saved(byAnAgent: flow.id)
        await #expect(throws: Never.self) { try await self.page(app, "undo", flow) }
        #expect(app.store.flow(flow.id)?.draft.step("a")?.kind == .text("two"), "nothing to step back over")
    }

    @Test func thePageSaysWhyAFlowNobodyReadIsPaused() async throws {
        let w = try World()
        let app = app(w)
        var flow = app.newFlow(name: "F", body: try FlowCodec.body(["trigger": ["type": "schedule", "every_minutes": 60], "steps": [["id": "a", "ai": "Write"]]]))
        flow.live = flow.draft
        flow.state = .on
        app.store.save(flow)
        app.engine.pauseWhatNobodyRead()
        await w.quiet(app.store)
        let paused = try #require(app.store.flow(flow.id))
        #expect(paused.pausedBecause?.isEmpty == false)
        #expect(Pages.card(paused, app).detail == paused.pausedBecause, "in Home too, not a silent state")
        let flowPage = await Pages.make(app, state: Arguments(["flow": flow.id]), background: false)
        #expect(String(describing: flowPage.sent).contains(paused.pausedBecause ?? "—"), "and on the flow")
        #expect(Pages.stateWord(paused, app).0 != L("On"))
    }
}

/// What reading the editing landing a second time found.
@MainActor @Suite(.serialized) struct SideflowEditingSecondReadTests {
    typealias World = SideflowTests.World

    private func app(_ w: World) -> App {
        let app = App(folder: w.folder.appendingPathComponent("app"))
        app.engine.host = w.host
        return app
    }

    private func page(_ app: App, _ op: String, _ flow: Flow, _ extra: [String: Any] = [:]) async throws {
        var input: [String: Any] = ["op": op, "flow": flow.id]
        input.merge(extra) { _, new in new }
        _ = try await Actions_UI.handle(Arguments(input), app)
    }

    @Test func aFlowAlreadyOverTheLimitCanBeEditedBackUnder() async throws {
        let w = try World()
        let app = app(w)
        let steps: [[String: Any]] = (0..<FlowBody.maxSteps).map { ["id": "s\($0)", "text": "x"] }
        let flow = app.newFlow(name: "F", body: try FlowCodec.body(["trigger": ["type": "manual"], "steps": steps]))
        var big = try #require(app.store.flow(flow.id))
        for n in 0..<3 { big.draft.steps.append(Step(id: "e\(n)", kind: .text("x"))) }
        big.saved = nil
        app.store.save(big)
        try await page(app, "remove", flow, ["step": "e0"])
        #expect(app.store.flow(flow.id)?.draft.allSteps.count == FlowBody.maxSteps + 2)
        try await page(app, "compose", flow, ["step": "e1", "text": "changed"])
        #expect(app.store.flow(flow.id)?.draft.step("e1")?.kind == .text("changed"))
        await #expect(throws: Problem.self) { try await self.page(app, "add_kind", flow, ["kind": "text"]) }
    }

    @Test func nothingBlankOrOverTheLimitGoesOnByAnyRoute() async throws {
        let w = try World()
        var flow = try w.flow([["id": "z", "text": "x"]], state: .paused)
        let blank = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "a", "ai": ""]]], saved: true)
        flow.draft = blank
        flow.saved = nil
        w.store.save(flow)
        w.engine.turnOn(flow.id)
        await w.quiet()
        #expect(w.store.flow(flow.id)?.state == .paused)
        #expect(w.store.flow(flow.id)?.startProblem != nil)
        var same = try #require(w.store.flow(flow.id))
        same.live = blank
        w.store.save(same)
        w.engine.resume(flow.id)
        await w.quiet()
        #expect(w.store.flow(flow.id)?.state == .paused, "the same with nothing changed")
    }

    @Test func aBlankStepInAnOnFlowCallsNothing() async throws {
        let w = try World()
        var flow = try w.flow([["id": "z", "text": "x"]])
        let body = FlowBody(steps: [Step(id: "a", kind: .ai(prompt: "")), Step(id: "b", kind: .action(tool: "changes.it", input: ["text": .string("x")]))])
        flow.draft = body
        flow.live = body
        w.store.save(flow)
        let run = await w.settled(w.engine.start(flow, mode: .live, why: "t"))
        #expect(run?.status == .failed)
        #expect(w.host.written.isEmpty)
        #expect(w.host.calls.isEmpty)
    }

    @Test func aWatchMovedToAnotherAddressMakesNoSecondWatchIfTheOldOneWontStop() async throws {
        let w = try World()
        var flow = try w.flow([["id": "a", "do": "reads.it"]], trigger: ["type": "watch", "kind": "url_change", "target": "https://x.example"])
        flow.watchTitle = "Test · Sideflow"
        flow.draft = try FlowCodec.body(["trigger": ["type": "watch", "kind": "url_change", "target": "https://y.example"], "steps": [["id": "a", "do": "reads.it"]]])
        w.store.save(flow)
        w.host.answers["watch.stop"] = [Actions.Outcome(status: .failed, text: "no")]
        w.engine.turnOn(flow.id)
        await w.quiet()
        #expect(!w.host.calls.contains { $0.tool == "watch.create" })
        let held = try #require(w.store.flow(flow.id))
        #expect(held.state == .paused)
        #expect(held.startProblem != nil)
        #expect(held.watchTitle == "Test · Sideflow")
        // Resume tries again, and ends with the address they read, not the old one back.
        w.engine.resume(flow.id)
        await w.quiet()
        let after = try #require(w.store.flow(flow.id))
        #expect(after.state == .on)
        #expect(after.startProblem == nil)
        #expect(!w.host.calls.contains { $0.tool == "watch.resume" })
        #expect(w.host.calls.first { $0.tool == "watch.create" }?.input["target"] as? String == "https://y.example")
    }

    @Test func resumeMakesAWatchAgainOnlyIfItsReallyGone() async throws {
        for (outcome, makes) in [(Actions.Outcome(status: .failed, text: "gone", notFound: true), true), (Actions.Outcome(status: .failed, text: "two match"), false), (Actions.Outcome(status: .lost, text: ""), false)] {
            let w = try World()
            var flow = try w.flow([["id": "a", "do": "reads.it"]], trigger: ["type": "watch", "kind": "url_change", "target": "https://x.example"], state: .paused)
            flow.watchTitle = "T"
            w.store.save(flow)
            w.host.answers["watch.resume"] = [outcome]
            w.engine.resume(flow.id)
            await w.quiet()
            #expect(w.host.calls.contains { $0.tool == "watch.create" } == makes, "\(outcome.status)")
            if !makes { #expect(w.store.flow(flow.id)?.startProblem != nil) }
        }
    }

    @Test func aLeftoverWatchsNoteGoesWhenItsGone() async throws {
        let w = try World()
        var flow = try w.flow([["id": "a", "text": "x"]], trigger: ["type": "watch", "kind": "url_change", "target": "https://x.example"])
        flow.watchTitle = "T"
        flow.draft = try FlowCodec.body(["trigger": ["type": "schedule", "every_minutes": 60], "steps": [["id": "a", "text": "x"]]])
        w.store.save(flow)
        w.host.answers["watch.stop"] = [Actions.Outcome(status: .failed, text: "no")]
        w.engine.turnOn(flow.id)
        await w.quiet()
        #expect(w.store.flow(flow.id)?.startProblem != nil)
        w.engine.pause(flow.id)
        await w.quiet()
        #expect(!w.host.calls.contains { $0.tool == "watch.pause" }, "no card to pause what's on its way out")
        w.engine.resume(flow.id)
        await w.quiet()
        let after = try #require(w.store.flow(flow.id))
        #expect(after.watchTitle == nil)
        #expect(after.startProblem == nil)
    }

    @Test func aBlankThanIsMarkedWhereItWouldDecideNothing() throws {
        let w = try World()
        for test in [Condition.Test.contains, .not_contains, .more_than, .less_than] {
            let body = FlowBody(steps: [Step(id: "c", kind: .branch(Condition(value: "a", test: test, than: ""), then: [], otherwise: []))])
            #expect(body.problems(w.catalog).contains { $0.step == "c" }, "\(test)")
        }
        for test in [Condition.Test.is_empty, .not_empty, .is, .is_not] {
            let body = FlowBody(steps: [Step(id: "c", kind: .branch(Condition(value: "a", test: test, than: ""), then: [], otherwise: []))])
            #expect(!body.problems(w.catalog).contains { $0.step == "c" }, "\(test)")
        }
    }

    @Test func typingAgainAfterASaveKeepsTheSavedVersionForUndo() async throws {
        let w = try World()
        let app = app(w)
        let flow = app.newFlow(name: "F", body: try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "a", "text": "one"]]]))
        try await page(app, "compose", flow, ["step": "a", "text": "two"])
        try await page(app, "save", flow)
        try await page(app, "compose", flow, ["step": "a", "text": "three"])
        try await page(app, "undo", flow)
        #expect(app.store.flow(flow.id)?.draft.step("a")?.kind == .text("two"))
    }
}

@MainActor @Suite(.serialized) struct SideflowWatchNameTests {
    typealias World = SideflowTests.World

    @Test func aReapprovedNewNameMovesTheWatchToIt() async throws {
        let w = try World()
        var flow = try w.flow([["id": "a", "do": "reads.it"]], trigger: ["type": "watch", "kind": "url_change", "target": "https://x.example"])
        flow.watchTitle = "Old · Sideflow"
        flow.name = "New"
        w.store.save(flow)
        w.engine.turnOn(flow.id)
        await w.quiet()
        #expect(w.host.calls.contains { $0.tool == "watch.stop" }, "its card's lines go by the new name")
        #expect(w.store.flow(flow.id)?.watchTitle == "New · Sideflow")
    }

    @Test func anUnchangedApplyKeepsItsWatch() async throws {
        let w = try World()
        var flow = try w.flow([["id": "a", "do": "reads.it"]], trigger: ["type": "watch", "kind": "url_change", "target": "https://x.example"])
        flow.watchTitle = "Test · Sideflow"
        flow.draft = try FlowCodec.body(["trigger": ["type": "watch", "kind": "url_change", "target": "https://x.example"], "steps": [["id": "a", "do": "reads.it"], ["id": "b", "do": "reads.it"]]])
        w.store.save(flow)
        w.engine.turnOn(flow.id)
        await w.quiet()
        #expect(!w.host.calls.contains { $0.tool == "watch.stop" || $0.tool == "watch.create" })
    }

    @Test func aChangedAddressUnderTheSameNameIsAReplacement() async throws {
        let w = try World()
        var flow = try w.flow([["id": "a", "do": "reads.it"]], trigger: ["type": "watch", "kind": "url_change", "target": "https://x.example"])
        flow.watchTitle = "Test · Sideflow"
        flow.draft = try FlowCodec.body(["trigger": ["type": "watch", "kind": "url_change", "target": "https://y.example"], "steps": [["id": "a", "do": "reads.it"]]])
        w.store.save(flow)
        w.engine.turnOn(flow.id)
        await w.quiet()
        #expect(w.host.calls.filter { $0.tool == "watch.stop" }.count == 1)
        #expect(w.host.calls.first { $0.tool == "watch.create" }?.input["target"] as? String == "https://y.example")
    }
}
