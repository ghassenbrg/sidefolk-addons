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

        func call(_ tool: String, _ input: [String: Any], plan: String?) async -> Actions.Outcome {
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

        func settled(_ run: Run?, seconds: Double = 5) async -> Run? {
            guard let id = run?.id else { return nil }
            let deadline = Date().addingTimeInterval(seconds)
            while Date() < deadline {
                if let r = store.run(id), r.status != .running { return r }
                try? await Task.sleep(for: .milliseconds(5))
            }
            return store.run(id)
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
        try await Task.sleep(for: .milliseconds(20))
        #expect(!w.host.forward.isEmpty, "it asks, where they are, what to do")
        w.engine.proceed(run!.id, .try_again)
        try await Task.sleep(for: .milliseconds(50))
        let done = await w.settled(w.store.run(run!.id))
        #expect(done?.status == .done)
        #expect(w.host.calls.count == 2)
    }

    @Test func afterAFailureItStopsCarriesOnOrTriesAgainAsTheStepSays() async throws {
        let w = try World()
        w.host.answers["changes.it"] = [Actions.Outcome(status: .failed, text: "boom"), Actions.Outcome(status: .failed, text: "boom")]
        let stops = try w.flow([["do": "changes.it", "with": ["text": "x"]], ["id": "z", "text": "after"]])
        let stopped = await w.settled(w.engine.start(stops, mode: .live, why: "t"))
        #expect(stopped?.status == .failed)
        #expect(stopped?.problem == "boom")
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
        try await Task.sleep(for: .milliseconds(50))
        #expect(w.store.run(waiting!.id)?.status == .done)

        w.host.answers["changes.it"] = [Actions.Outcome(status: .failed, text: "boom")]
        let changes = try w.flow([["do": "changes.it", "with": ["text": "x"], "on_failure": "retry"]])
        let stopped = await w.settled(w.engine.start(changes, mode: .live, why: "t"))
        #expect(stopped?.status == .failed, "repeating what may have happened never happens by itself")
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
        try await Task.sleep(for: .milliseconds(250))
        let after = w.store.run(run!.id)
        #expect(after?.status == .needs_you, "stopped at the second step, and the old answer doesn't move it")
        #expect(after?.record(of: "c") == nil)
    }

    @Test func nobodyAnsweringLeavesItWhereItIs() async throws {
        let w = try World()
        w.host.answers["changes.it"] = [Actions.Outcome(status: .unanswered, text: "")]
        let flow = try w.flow([["id": "a", "do": "changes.it", "with": ["text": "x"]]])
        let run = await w.settled(w.engine.start(flow, mode: .live, why: "test"))
        try await Task.sleep(for: .milliseconds(30))
        #expect(!w.host.forward.isEmpty)
        #expect(w.store.run(run!.id)?.status == .needs_you)
    }

    @Test func somethingHappeningSetsOffTheFlowsWaitingForItWithItsWords() async throws {
        let w = try World()
        let any = try w.flow([["id": "a", "text": "{{trigger}}"]], trigger: ["type": "event", "event": "reminder.fired"])
        let only = try w.flow([["id": "a", "text": "x"]], trigger: ["type": "event", "event": "reminder.fired", "contains": "dentist"])
        let other = try w.flow([["id": "a", "text": "x"]], trigger: ["type": "event", "event": "note.saved"])
        w.engine.happened(name: "reminder.fired", title: "Call the bank", detail: nil)
        try await Task.sleep(for: .milliseconds(50))
        let ran = w.store.runs(of: any.id).first
        #expect(ran?.record(of: "a")?.output == "Call the bank")
        #expect(w.store.runs(of: only.id).isEmpty, "it doesn't mention what this one waits for")
        #expect(w.store.runs(of: other.id).isEmpty)
        w.engine.happened(name: "reminder.fired", title: "The DENTIST at three", detail: nil)
        try await Task.sleep(for: .milliseconds(50))
        #expect(w.store.runs(of: only.id).count == 1)
    }

    @Test func aDraftWaitingForSomethingDoesntGo() async throws {
        let w = try World()
        let draft = try w.flow([["id": "a", "text": "x"]], trigger: ["type": "event", "event": "mac.woke"], state: .draft)
        w.engine.happened(name: "mac.woke", title: nil, detail: nil)
        try await Task.sleep(for: .milliseconds(30))
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
        try await Task.sleep(for: .milliseconds(30))
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
        try await Task.sleep(for: .milliseconds(50))
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
        try await Task.sleep(for: .milliseconds(50))
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
        try await Task.sleep(for: .milliseconds(20))
        #expect(w.store.run(run!.id)?.status == .waiting, "not yet")
        w.now = w.now.addingTimeInterval(601)
        w.engine.tick()
        try await Task.sleep(for: .milliseconds(50))
        #expect(w.store.run(run!.id)?.status == .done)
    }

    // MARK: Turning on

    @Test func itIsOnOnlyOnceThePersonSaysYes() async throws {
        let w = try World()
        var flow = try w.flow([["do": "changes.it", "with": ["text": "x {{today}}"]], ["id": "q", "ask": "Sure?"]], state: .draft)
        w.host.planAnswer = .refused("denied")
        w.engine.turnOn(flow.id)
        try await Task.sleep(for: .milliseconds(30))
        flow = w.store.flow(flow.id)!
        #expect(flow.state == .draft)
        #expect(flow.live == nil)
        #expect(flow.startProblem != nil)
        w.host.planAnswer = .allowed(standing: [true, true])
        w.engine.turnOn(flow.id)
        try await Task.sleep(for: .milliseconds(30))
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
        try await Task.sleep(for: .milliseconds(30))
        flow = w.store.flow(flow.id)!
        #expect(w.host.calls.first?.tool == "watch.create")
        #expect(w.host.calls.first?.input["mode"] as? String == "repeat")
        #expect(w.host.calls.first?.plan == flow.planId)
        #expect(flow.watchTitle == Engine.watchTitle(flow))
        let tools = Set(w.host.plans.last?.steps.map(\.tool) ?? [])
        #expect(tools.isSuperset(of: ["watch.create", "watch.stop"]))
        w.engine.watchFired(title: flow.watchTitle!, summary: "It changed")
        try await Task.sleep(for: .milliseconds(30))
        #expect(w.store.runs(of: flow.id).first?.values.value("n") == "Saw: It changed")
        w.engine.watchFired(title: "someone else's", summary: "x")
        try await Task.sleep(for: .milliseconds(20))
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
        try await Task.sleep(for: .milliseconds(20))
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
