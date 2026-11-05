import Foundation
import Testing
@testable import ext_sideflow
import SidefolkExtensionKit

/// One approval for a flow: Run goes under the same plan as Turn on, and the plan says what the card and the limits need.
@MainActor @Suite(.serialized) struct SideflowApprovalTests {
    typealias World = SideflowTests.World

    private func wire(_ step: PlanStep) -> [String: Any] {
        var out: [String: Any] = ["line": step.line]
        out["named"] = step.named
        out["title"] = step.title
        return out
    }

    @Test func runAsksUnderThePlanAndStartsForReal() async throws {
        let w = try World()
        let flow = try w.flow([["id": "c", "do": "changes.it", "with": ["text": "x"]]], state: .draft)
        let run = try #require(await w.engine.runNow(flow.id, why: "t"))
        await w.quiet()
        #expect(run.mode == .live, "there's one version, and it's the one they read")
        #expect(w.host.plans.count == 1)
        #expect(w.host.plans.first?.intent == "run")
        #expect(w.host.plans.first?.id == flow.planId)
        #expect(w.host.calls.contains { $0.tool == "changes.it" && $0.plan == flow.planId })
        #expect(w.host.runIds.contains(run.id), "what the limit for one run counts by")
        let after = try #require(w.store.flow(flow.id))
        #expect(after.state == .draft, "running it isn't turning it on")
        #expect(after.live == flow.draft, "what ran is what's approved")
    }

    @Test func runSavesWhatsOnThePageFirst() async throws {
        let w = try World()
        var flow = try w.flow([["id": "c", "do": "changes.it", "with": ["text": "kept"]]], state: .draft)
        flow.saved = flow.draft
        flow.draft = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "c", "do": "changes.it", "with": ["text": "typed"]]]])
        w.store.save(flow)
        _ = try #require(await w.engine.runNow(flow.id, why: "t", saving: true))
        await w.quiet()
        #expect(w.store.flow(flow.id)?.hasUnsaved == false)
        #expect(w.host.calls.first { $0.tool == "changes.it" }?.input["text"] as? String == "typed", "what's on the page is what's asked about and run")
    }

    @Test func anyoneElseRunsWhatWasKeptAndLeavesWhatsBeingTyped() async throws {
        let w = try World()
        var flow = try w.flow([["id": "c", "do": "changes.it", "with": ["text": "kept"]]], state: .draft)
        flow.saved = flow.draft
        flow.draft = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "c", "do": "changes.it", "with": ["text": "typed"]]]])
        w.store.save(flow)
        _ = try #require(await w.engine.runNow(flow.id, why: "t"))
        await w.quiet()
        #expect(w.store.flow(flow.id)?.hasUnsaved == true)
        #expect(w.host.calls.first { $0.tool == "changes.it" }?.input["text"] as? String == "kept")
    }

    @Test func whatStillStandsRunsWithNoCardSoNoClickIsNeeded() async throws {
        let w = try World()
        let flow = try w.flow([["id": "c", "do": "changes.it", "with": ["text": "x"]]])
        w.host.planChecked = Plans.Checked(steps: [.init(state: "stands")], silent: true)
        w.host.planAnswer = .refused("not_asked")
        let run = await w.engine.runNow(flow.id, why: "t")
        #expect(run != nil, "a schedule or an agent can go on with what's approved")
        #expect(w.host.plans.isEmpty)
    }

    @Test func anApprovalThatStoodOnlyUnderFullAccessAsksAgain() async throws {
        let w = try World()
        let flow = try w.flow([["id": "c", "do": "changes.it", "with": ["text": "x"]]])
        w.host.planChecked = Plans.Checked(steps: [.init(state: "stands")], silent: false)
        w.host.planAnswer = .refused("denied")
        let run = await w.engine.runNow(flow.id, why: "t")
        #expect(run == nil)
        #expect(w.host.plans.count == 1)
    }

    @Test func aPausedFlowIsntRunBehindItsOwnPause() async throws {
        let w = try World()
        var flow = try w.flow([["id": "c", "do": "changes.it", "with": ["text": "x"]]])
        flow.state = .paused
        w.store.save(flow)
        #expect(await w.engine.runNow(flow.id, why: "t") == nil)
        #expect(w.host.plans.isEmpty && w.host.calls.isEmpty)
        #expect(w.store.flow(flow.id)?.startProblem != nil)
    }

    @Test func tryAgainIsCountedAfresh() async throws {
        let w = try World()
        w.host.answers["changes.it"] = [Actions.Outcome(status: .failed, text: "no"), Actions.Outcome(status: .ok, text: "yes")]
        let flow = try w.flow([["id": "c", "do": "changes.it", "with": ["text": "x"]]])
        let run = await w.settled(w.engine.start(flow, mode: .live, why: "t"))
        #expect(run?.status == .interrupted)
        w.engine.proceed(try #require(run).id, .try_again)
        await w.quiet()
        #expect(w.host.runIds.count == 2)
        #expect(Set(w.host.runIds).count == 2, "the person asked, so the limit for one run doesn't count the first try against it")
        #expect(w.host.runIds.allSatisfy { $0.count <= 64 })
    }

    @Test func aWriteInASchedulesDayIsAllowedForByTheLimit() throws {
        let body = try FlowCodec.body(["trigger": ["type": "schedule", "every_minutes": 15], "steps": [["id": "a", "do": "changes.it", "with": ["text": "a"]], ["id": "b", "do": "changes.it", "with": ["text": "b"]], ["id": "c", "do": "changes.it", "with": ["text": "c"]]]])
        #expect(Engine.callsPerDay(body, perRun: 3, goesRound: false) == 288)
        let manual = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "a", "do": "changes.it", "with": ["text": "a"]]]])
        #expect(Engine.callsPerDay(manual, perRun: 1, goesRound: false) == Engine.ordinaryPerDay)
        #expect(Engine.callsPerDay(manual, perRun: 1, goesRound: true) == Engine.loopsPerDay)
        #expect(Engine.callsPerDay(body, perRun: 1000, goesRound: true) == Engine.loopsPerDay, "the most a plan can say")
    }

    @Test func sayingNoStartsNothingAndKeepsTheEditAndWhatWasLive() async throws {
        let w = try World()
        var flow = try w.flow([["id": "c", "do": "changes.it", "with": ["text": "old"]]])
        let live = flow.draft
        flow.draft = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "c", "do": "changes.it", "with": ["text": "new"]]]])
        w.store.save(flow)
        w.host.planAnswer = .refused("denied")
        let run = await w.engine.runNow(flow.id, why: "t")
        #expect(run == nil)
        await w.quiet()
        #expect(w.host.calls.isEmpty)
        let after = try #require(w.store.flow(flow.id))
        #expect(after.live == live)
        #expect(after.draft != live)
        #expect(after.startProblem != nil, "the page says what's waiting")
    }

    @Test func aCoveredEditRunsWithNoFurtherWord() async throws {
        let w = try World()
        var flow = try w.flow([["id": "c", "do": "changes.it", "with": ["text": "old"]]])
        flow.draft = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "c", "do": "changes.it", "with": ["text": "new"]]]])
        w.store.save(flow)
        w.host.planAnswer = .allowed(standing: [true], silent: true, new: 0)
        let run = try #require(await w.engine.runNow(flow.id, why: "t"))
        await w.quiet()
        #expect(w.store.run(run.id)?.status == .done)
        #expect(w.store.flow(flow.id)?.live == w.store.flow(flow.id)?.kept)
        #expect(w.store.flow(flow.id)?.state == .on)
    }

    @Test func aBlankStepStopsRunBeforeAnyCard() async throws {
        let w = try World()
        var flow = try w.flow([["id": "c", "text": "x"]], state: .draft)
        flow.draft = FlowBody(steps: [Step(id: "a", kind: .ai(prompt: ""))])
        w.store.save(flow)
        #expect(await w.engine.runNow(flow.id, why: "t") == nil)
        #expect(w.host.plans.isEmpty)
        #expect(w.store.flow(flow.id)?.startProblem != nil)
    }

    @Test func thePlanNamesEachStepAndKindForTheCard() throws {
        let body = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [
            ["id": "r", "do": "reads.it", "name": "Read the page"],
            ["id": "write", "ai": "Sum up {{r}}"],
            ["id": "all", "ai": "Sum up what's above"],
            ["id": "ok", "ask": "Send it?"],
            ["id": "c", "do": "changes.it", "with": ["text": "{{write}}"]],
            ["id": "f", "run_flow": "Other"],
            ["id": "g", "call_flow": "Another"],
        ]])
        let rows = Engine.planSteps(body, title: "t")
        #expect(rows.map(\.named) == ["r", "write", "all", "ok", "c", "f", "g"])
        #expect(rows.first?.title == "Read the page")
        #expect(rows.map(\.line).contains { $0.hasPrefix("ai") && $0.contains("r") })
        #expect(rows.map(\.line).contains { $0.hasPrefix("flow Other") })
        #expect(rows.map(\.line).contains { $0.hasPrefix("flow Another") })
    }

    @Test func aNameTheHostWouldRefuseIsLeftOutNotSent() throws {
        let steps = [Step(id: "today", kind: .text("x")), Step(id: "today", kind: .action(tool: "a.b", input: [:])), Step(id: "a.b", kind: .action(tool: "a.c", input: [:])),
                     Step(id: "same", kind: .action(tool: "a.d", input: [:])), Step(id: "same", kind: .action(tool: "a.e", input: [:]))]
        let rows = Engine.planSteps(FlowBody(steps: steps), title: "t")
        #expect(rows.map(\.named) == [nil, nil, "same", nil], "one bad name makes the whole plan unusable, so none goes")
    }

    @Test func onlyAFormIsSaidToBeThePersonsOwn() throws {
        let body = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [
            ["id": "f", "form": ["title": "Who", "fields": [["name": "n", "label": "Name", "kind": "text"]]]],
            ["id": "whole", "text": "{{f.n}}"],
            ["id": "literal", "text": "https://evil.example"],
        ]])
        #expect(Engine.inside(body) == ["f"], "what's built from it says what it reads, on its own row")
    }

    @Test func noNameAFlowControlsCanPassForTheClock() throws {
        // Written by hand, past what a definition lets in: the host would refuse the whole plan over these.
        for name in ["today", "now", "Today", "NOW", "tOdAy", "Now"] {
            #expect(Engine.planSteps(FlowBody(steps: [Step(id: name, kind: .text("x"))]), title: "t").allSatisfy { $0.named == nil }, "\(name)")
            #expect(Engine.planSteps(FlowBody(steps: [Step(id: name, kind: .action(tool: "a.b", input: [:]))]), title: "t").allSatisfy { $0.named == nil }, "\(name)")
            guard case .form(let form)? = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "f", "form": ["title": "W", "fields": [["name": "n", "label": "N", "kind": "text"]]]]]]).step("f")?.kind else { Issue.record("not a form"); return }
            #expect(Engine.inside(FlowBody(steps: [Step(id: name, kind: .form(form))])).isEmpty, "\(name)")
            #expect(throws: (any Error).self, "a definition can't have one: \(name)") {
                try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": name, "text": "x"]]])
            }
        }
    }

    @Test func whatComesFromOutsideIsNeverSaidToBeTheClockOrThePersons() throws {
        let body = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [
            ["id": "f", "form": ["title": "W", "fields": [["name": "now", "label": "N", "kind": "text"]]]],
            ["id": "clock", "text": "{{now}}"],
            ["id": "field", "text": "{{f.now}}"],
            ["id": "off", "text": "{{trigger}}"],
            ["id": "called", "text": "{{input.now}}"],
            ["id": "cased", "text": "{{Now}}"],
            ["id": "each", "for_each": "{{off}}", "steps": [["id": "one", "text": "{{item}}"], ["id": "go", "text": "{{index}}"]]],
            ["id": "tool", "do": "reads.it"],
            ["id": "mix", "text": "{{tool}} {{now}}"],
        ]])
        let rows = Engine.planSteps(body, title: "t")
        func says(_ name: String, _ reads: String) -> Bool { rows.first { $0.named == name }?.line.contains("[\"\(reads)\"]") == true }
        #expect(says("clock", "now"), "the real one")
        #expect(says("field", "f"), "a field called now is what the form said, not the clock")
        #expect(says("off", "trigger"))
        #expect(says("called", "input"), "an input called now is what the caller passed")
        #expect(says("cased", "Now"), "not the clock, and at run time nothing's there")
        #expect(says("one", "item"))
        #expect(says("item", "off"), "what a loop brings is what its list reads")
        #expect(says("go", Engine.writtenWords), "which go it is says nothing about the person")
        #expect(rows.first { $0.named == "mix" }?.line.contains("tool") == true, "the clock beside a tool's words doesn't make them inside")
        #expect(Engine.inside(body) == ["f"], "a loop, a trigger and an input are never said to be the person's")
    }

    @Test func whatALoopGivesSaysItReadsItsListToo() throws {
        // A go that skips the branch keeps the item, which is the page's words, not the form's.
        let body = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [
            ["id": "page", "do": "reads.it"],
            ["id": "each", "for_each": "{{page}}", "steps": [["if": ["value": "{{item}}", "test": "contains", "than": "x"], "then": [["id": "f", "form": ["title": "W", "fields": [["name": "n", "label": "N", "kind": "text"]]]]]]]],
            ["id": "use", "text": "{{each}}"],
        ]])
        let row = Engine.planSteps(body, title: "t").first { $0.named == "each" }
        #expect(row?.line.contains("page") == true, "\(row?.line ?? "")")
        #expect(row?.line.contains("\"f\"") == true)
    }

    @Test func aFormNamedLikeWhatALoopBringsIsntTakenForTheLoopsItem() throws {
        let top = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "f", "form": ["title": "Who", "fields": [["name": "n", "label": "Name", "kind": "text"]]]]]])
        guard case .form(let form)? = top.step("f")?.kind else { Issue.record("not a form"); return }
        let body = FlowBody(steps: [Step(id: "item", kind: .form(form)), Step(id: "t", kind: .text("{{item}}"))])
        #expect(Engine.inside(body).isEmpty, "inside a loop that name is the page's item")
    }

    /// The host follows a value back through these to what really gave it: editing a step in between is new, when what it reads changes.
    @Test func aStepInBetweenSaysWhatItReads() throws {
        let body = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [
            ["id": "w", "do": "reads.it"],
            ["id": "alias", "text": "{{w}}"],
            ["id": "added", "text": "Today: {{w}}"],
            ["id": "literal", "text": "https://evil.example"],
            ["id": "d", "data": ["op": "first", "from": "{{alias}}"]],
            ["id": "c", "do": "changes.it", "with": ["text": "{{d}}"]],
        ]])
        let rows = Engine.planSteps(body, title: "t")
        func line(_ name: String) -> String { rows.first { $0.named == name }?.line ?? "" }
        #expect(line("alias").contains("[\"w\"]"))
        #expect(line("added").contains("w") && line("added").contains(Engine.writtenWords), "words written in with it aren't the step's to vouch for")
        #expect(line("literal").contains(Engine.writtenWords))
        #expect(line("d").contains("alias"))
        #expect(rows.map(\.named).firstIndex(of: "alias")! < rows.map(\.named).firstIndex(of: "d")!, "what feeds a step comes before it")
    }

    @Test func aLoopsItemAndAnswerSayWhereTheyComeFrom() throws {
        let body = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [
            ["id": "pages", "do": "reads.it"],
            ["id": "e", "for_each": "{{pages}}", "steps": [["id": "s", "ai": "Sum up {{item}}"], ["id": "c", "do": "changes.it", "with": ["text": "{{item}}"]]]],
            ["id": "after", "do": "changes.it", "with": ["text": "{{e}}"]],
        ]])
        let rows = Engine.planSteps(body, title: "t")
        let names = rows.map(\.named)
        #expect(rows.first { $0.named == "item" }?.line.contains("pages") == true)
        #expect(rows.first { $0.named == "e" }?.line.contains("c") == true)
        #expect(names.firstIndex(of: "e")! > names.firstIndex(of: "c")!, "its answer comes after what makes it")
        #expect(names.firstIndex(of: "e")! < names.firstIndex(of: "after")!)
        #expect(Set(names.compactMap(\.self)).count == names.compactMap(\.self).count, "the host refuses a whole plan over one name twice")
    }

    @Test func twoLoopsShareTheOneItemRow() throws {
        let body = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [
            ["id": "a", "do": "reads.it"], ["id": "b", "do": "reads.it"],
            ["id": "e", "for_each": "{{a}}", "steps": [["id": "c", "do": "changes.it", "with": ["text": "{{item}}"]]]],
            ["id": "f", "for_each": "{{b}}", "steps": [["id": "d", "do": "changes.it", "with": ["text": "{{item}}"]]]],
        ]])
        let rows = Engine.planSteps(body, title: "t").filter { $0.named == "item" }
        #expect(rows.count == 1)
        #expect(rows.first?.line.contains("a") == true && rows.first?.line.contains("b") == true)
    }

    @Test func nothingHereMakesThePlanUnusableOrSaysMoreThanItKnows() throws {
        let written = Engine.writtenWords
        #expect(written.contains("-"), "no step can be called this")
        #expect((try? FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": written, "text": "x"]]])) == nil)
        // A blank step, and a step with nothing but a go number: the host refuses an empty list.
        let blank = FlowBody(steps: [Step(id: "t", kind: .text("")), Step(id: "n", kind: .text("{{index}}"))])
        for row in Engine.planSteps(blank, title: "x") where row.onlyPassesOn { #expect(row.line.contains(written), "\(row.line)") }
        // A loop holding more than the host takes.
        let many: [[String: Any]] = (0..<33).map { ["id": "s\($0)", "text": "x"] }
        let body = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "e", "for_each": "x", "steps": many]]])
        let row = try #require(Engine.planSteps(body, title: "x").first { $0.named == "e" })
        #expect(row.line.contains(written) && !row.line.contains("s32"), "\(row.line)")
    }

    @Test func aStepCalledItemIsntVouchedForByTheLists() throws {
        let steps = [Step(id: "q", kind: .ask(question: "Which?", options: [])),
                     Step(id: "each", kind: .forEach(items: "{{q}}", limit: 5, onFailure: .stop, steps: [Step(id: "c", kind: .action(tool: "a.b", input: ["url": .string("{{item}}")]))])),
                     Step(id: "item", kind: .action(tool: "web.read", input: [:]))]
        let row = try #require(Engine.planSteps(FlowBody(steps: steps), title: "x").first { $0.named == "item" })
        #expect(row.line.contains(Engine.writtenWords), "\(row.line)")
        #expect(!row.line.contains("q"))
    }

    @Test func whatSetsItOffOftenIsAllowedForByTheDay() throws {
        let body = try FlowCodec.body(["trigger": ["type": "event", "event": "note.saved"], "steps": (0..<8).map { ["id": "s\($0)", "do": "changes.it", "with": ["text": "\($0)"]] }])
        #expect(Engine.callsPerDay(body, perRun: 8, goesRound: false) == Engine.loopsPerDay, "the hourly stop is what stops it running away, not this")
    }

    @Test func aFreshFlowWithNoToolsHasNothingNewToAllow() {
        let look = PlanLook(Plans.Checked(steps: [], new: [], silent: false, widened: false), of: Plan(id: "p", title: "t", steps: []))
        #expect(look.head == L("Nothing new to allow"))
    }

    @Test func manyAlikeStepsAreFewLines() throws {
        let steps: [[String: Any]] = (0..<70).map { ["id": "s\($0)", "do": "notes.save", "with": ["text": "x"]] }
        let body = try FlowCodec.body(["trigger": ["type": "manual"], "steps": steps])
        #expect(Engine.lines(Engine.planSteps(body, title: "t")) == 1, "the host counts different lines")
        #expect(!body.problems(try World().catalog).contains { $0.step == nil && $0.text.contains("different things to allow") })
    }

    @Test func thePerRunLimitIsWhatTheFlowCanDo() throws {
        func count(_ steps: [[String: Any]]) throws -> Int { Engine.callsPerRun(try FlowCodec.body(["trigger": ["type": "manual"], "steps": steps]).steps) }
        let change: [String: Any] = ["id": "c", "do": "changes.it", "with": ["text": "x"]]
        #expect(try count([change]) == 1)
        #expect(try count([["id": "e", "for_each": "x", "limit": 10, "steps": [change]]]) == 10)
        #expect(try count([["id": "r", "repeat": [change], "until": ["value": "{{c}}", "test": "contains", "than": "d"], "times": 4]]) == 4)
        #expect(try count([["id": "b", "if": ["value": "a", "test": "is", "than": "a"], "then": [change], "else": [["id": "d", "do": "reads.it"]]]]) == 2, "what either way could do")
        #expect(try count([["id": "e", "for_each": "x", "limit": 500, "steps": [["id": "e2", "for_each": "y", "limit": 500, "steps": [change]]]]]) == Plans.mostPerRun, "the most a plan can say")
        #expect(try count([["id": "t", "text": "x"]]) == 0)
    }

    @Test func thePlanCarriesItsLimits() throws {
        let w = try World()
        let flow = try w.flow([["id": "e", "for_each": "x", "limit": 10, "steps": [["id": "c", "do": "changes.it", "with": ["text": "x"]]]]])
        let plan = w.engine.livePlan(flow, intent: "turn_on")
        #expect(plan.perRun == 10)
        #expect(plan.goesRound)
        #expect(plan.intent == "turn_on")
    }

    @Test func pastItsLimitARunStopsAndTheFlowPauses() async throws {
        for limit in ["run", "day"] {
            let w = try World()
            w.host.answers["changes.it"] = [Actions.Outcome(status: .capped, text: "", limit: limit)]
            let flow = try w.flow([["id": "t", "try": [["id": "c", "do": "changes.it", "with": ["text": "x"], "on_failure": "carry_on"]], "recover": [["id": "r", "text": "recovered"]]], ["id": "after", "do": "changes.it", "with": ["text": "y"]]])
            let run = await w.settled(w.engine.start(flow, mode: .live, why: "t"))
            #expect(run?.status == .failed)
            #expect(run?.problem != nil)
            #expect(w.host.calls.filter { $0.tool == "changes.it" }.count == 1, "no try or carry on gets past what the person said")
            #expect(run?.record(of: "r") == nil)
            #expect(run?.record(of: "c")?.status == .failed, "nothing happened, and it says so")
            #expect(w.store.flow(flow.id)?.state == .paused)
            #expect(w.store.flow(flow.id)?.pausedBecause?.isEmpty == false)
        }
    }

    @Test func whatTheHostSaysOfAPlanIsReadByStepName() throws {
        let plan = Plan(id: "p", title: "t", steps: [PlanStep("a.b", ["x": 1], named: "one"), PlanStep("a.b", ["x": 1], named: "two"), PlanStep("a.c", named: "three"), PlanStep("a.d")])
        let checked = Plans.Checked(steps: [.init(state: "stands"), .init(state: "stands"), .init(state: "asks", why: "reach_field"), .init(state: "refused", why: "code_field")], new: [0, 1, 2], silent: false)
        let look = PlanLook(checked, of: plan)
        #expect(look.new == 2, "two steps with one line are one thing to allow")
        #expect(look.head.contains("2"))
        #expect(look.byStep["three"]?.why == "reach_field")
        #expect(look.byStep.count == 3, "a step with no name isn't lost track of as another's")
        let quiet = PlanLook(Plans.Checked(steps: [], silent: true), of: Plan(id: "p", title: "t", steps: []))
        #expect(quiet.head == L("Nothing new to allow"))
        let wider = PlanLook(Plans.Checked(steps: [], new: [], silent: false, widened: true), of: Plan(id: "p", title: "t", steps: []))
        #expect(wider.head != L("Nothing new to allow"), "a card is coming, so it can't say that")
    }

    @Test func eachWayAStepBehavesHasItsWords() {
        func words(_ line: Plans.Checked.Line) -> String? { PlanLook.mark(line)?.words }
        #expect(words(.init(state: "stands")) == nil, "running by itself is what's expected, so nothing's said")
        #expect(words(.init(state: "listed")) == nil)
        #expect(words(.init(state: "refused", why: "code_field"))?.contains("Write this part yourself") == true)
        #expect(words(.init(state: "refused", why: "shell"))?.contains("runs a program") == true, "those show a card: never say it can't")
        #expect(words(.init(state: "refused", why: "text_to_read"))?.contains("read in full") == true)
        #expect(words(.init(state: "stands_in_full_access", why: "reach_field"))?.contains("where it goes") == true, "what the host sends for it")
        #expect(words(.init(state: "stands_in_full_access", why: "filled_value"))?.contains("Full access") == true)
        #expect(words(.init(state: "asks", why: "reach_field"))?.contains("where it goes") == true)
        #expect(words(.init(state: "asks", why: "server_unpinned"))?.contains("program") == true)
        #expect(words(.init(state: "asks", why: "filled_value"))?.contains("ask each run") == true)
        #expect(words(.init(state: "stands", warning: "crossing"))?.contains("passes on") == true)
    }

    @Test func aStepsFormSaysHowItWillBehave() async throws {
        let w = try World()
        let app = App(folder: w.folder.appendingPathComponent("app"))
        app.engine.host = w.host
        app.catalog.use(Actions.Listing(tools: [Actions.Tool(name: "reads.it", title: "Read it", mutates: false, readsOnly: true)]))
        let flow = app.newFlow(name: "F", body: try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "a", "do": "reads.it"]]]))
        app.nav.inspect(.step("a"), in: flow.id)
        app.planChecks[flow.id] = PlanLook(Plans.Checked(steps: [.init(state: "asks", why: "reach_field")], new: [0]), of: Plan(id: "p", title: "t", steps: [PlanStep("reads.it", named: "a")]))
        let shown = String(describing: Inspector.sections(flow, app, problems: []))
        #expect(shown.contains("where it goes"), "\(shown)")
    }

    @Test func anEditWithNothingNewSaysSoWhileItsTrue() async throws {
        let w = try World()
        var flow = try w.flow([["id": "c", "do": "changes.it", "with": ["text": "old"]]])
        flow.draft = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "c", "do": "changes.it", "with": ["text": "new"]]]])
        w.store.save(flow)
        w.host.planAnswer = .allowed(standing: [true], silent: true, new: 0)
        w.engine.turnOn(flow.id)
        await w.quiet()
        var after = try #require(w.store.flow(flow.id))
        #expect(w.engine.quietlySaved(after) != nil)
        after.draft = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "c", "do": "changes.it", "with": ["text": "newer"]]]])
        w.store.save(after)
        #expect(w.engine.quietlySaved(after) == nil)
    }

    @Test func aCardShownIsntCalledNothingNew() async throws {
        let w = try World()
        let flow = try w.flow([["id": "c", "do": "changes.it", "with": ["text": "x"]]], state: .draft)
        w.host.planAnswer = .allowed(standing: [true], silent: false, new: 1)
        w.engine.turnOn(flow.id)
        await w.quiet()
        #expect(w.engine.quietlySaved(try #require(w.store.flow(flow.id))) == nil)
    }

    @Test func endingItFromTheFlowsPagePausesItAndAsksAgain() async throws {
        let w = try World()
        let flow = try w.flow([["id": "c", "do": "changes.it", "with": ["text": "x"]]])
        w.engine.endPlan(flow.id)
        await w.quiet()
        #expect(w.host.forgotten == [flow.planId])
        let after = try #require(w.store.flow(flow.id))
        #expect(after.state == .paused)
        #expect(after.live == nil)
    }

    @Test func aPracticeKeepsItsOwnPlan() throws {
        let w = try World()
        let flow = try w.flow([["id": "r", "do": "reads.it"]], state: .draft)
        let plan = try #require(w.engine.practicePlan(flow))
        #expect(plan.id == flow.practiceId)
        #expect(plan.id != flow.planId, "approving it under the flow's id would replace the plan with a reads-only one")
    }
}
