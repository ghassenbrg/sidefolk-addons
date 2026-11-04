import Foundation
import Testing
@testable import ext_sideflow
import SidefolkExtensionKit

/// What holds other steps, typed values, and what lasts across a restart. Sidefolk is scripted.
@MainActor @Suite(.serialized) struct SideflowEngineTests {
    typealias World = SideflowTests.World

    private func done(_ w: World, _ steps: [[String: Any]], trigger: [String: Any] = ["type": "manual"]) async throws -> Run? {
        let flow = try w.flow(steps, trigger: trigger)
        return await w.settled(w.engine.start(flow, mode: .live, why: "t"))
    }

    // MARK: Values keep what they are

    @Test func aListStaysAListAndAnIdStaysText() throws {
        var v = Values()
        v.set("list", JSON.array([.string("a,b"), .string("c")]))
        v.set("id", "0012")
        v.set("rec", JSON.object(["total": .number(12.5), "who": .string("Ada"), "items": .array([.string("x")])]))
        #expect(v.fill(native: .string("{{list}}")) == .array([.string("a,b"), .string("c")]), "a comma inside an item stays inside it")
        #expect(v.fill(native: .string("{{id}}")) == .string("0012"))
        #expect(v.fill(native: .string("{{rec.total}}")) == .number(12.5))
        #expect(v.fill("Total: {{rec.total}} for {{rec.who}}, {{rec.items[0]}}") == "Total: 12.5 for Ada, x")
        #expect(v.fill(native: .string("n={{rec.total}}")) == .string("n=12.5"), "inside a sentence it's words")
    }

    @Test func missingIsToldFromEmpty() {
        var v = Values()
        v.set("empty", "")
        v.set("rec", JSON.object(["a": .null]))
        #expect(v.missing(in: ["{{empty}}", "{{rec.a}}"]).isEmpty, "empty and null are there")
        #expect(v.missing(in: ["{{nothing}}"]) == ["nothing"])
        #expect(v.missing(in: ["{{rec.b}}"]) == ["rec.b"])
        #expect(v.missing(in: ["{{trigger}} {{today}}"]).isEmpty, "these mean nothing when they're not set")
    }

    // MARK: Data

    @Test func dataStepsDoWhatTheySayAndSayWhenTheyCant() throws {
        let items = JSON.array([.object(["n": .string("b"), "v": .number(2)]), .object(["n": .string("a"), "v": .number(1)]), .object(["n": .string("a"), "v": .number(3)])])
        func run(_ d: DataStep, _ value: JSON, than: String = "") throws -> JSON { try d.apply(to: value, than: than) }
        #expect(try run(DataStep(op: .field, from: "", field: "n"), items) == .array([.string("b"), .string("a"), .string("a")]))
        #expect(try run(DataStep(op: .sum, from: "", field: "v"), items) == .number(6))
        #expect(try run(DataStep(op: .count, from: ""), items) == .number(3))
        #expect(try run(DataStep(op: .unique, from: "", field: "n"), items) == .array([items.arrayItems[0], items.arrayItems[1]]))
        #expect(try run(DataStep(op: .filter, from: "", field: "n", test: .is), items, than: "a") == .array([items.arrayItems[1], items.arrayItems[2]]))
        #expect(try run(DataStep(op: .sort, from: "", field: "v", descending: true), items).arrayItems.first == items.arrayItems[2])
        #expect(try run(DataStep(op: .first, from: "", count: 2), items).arrayItems.count == 2)
        #expect(try run(DataStep(op: .lines, from: ""), .string("a\n\n b \n")) == .array([.string("a"), .string("b")]))
        #expect(try run(DataStep(op: .join, from: "", separator: "+"), .array([.string("a"), .number(1)])) == .string("a+1"))
        #expect(try run(DataStep(op: .parse_json, from: ""), .string(#"{"a":[1]}"#)) == .object(["a": .array([.number(1)])]))
        #expect(try run(DataStep(op: .parse_csv, from: ""), .string("name,note\nAda,\"a, b\"\n")) == .array([.object(["name": .string("Ada"), "note": .string("a, b")])]))
        #expect(try run(DataStep(op: .number, from: ""), .string("18 °C")) == .number(18))
        #expect(throws: Problem.self) { try run(DataStep(op: .sort, from: ""), .string("not a list")) }
        #expect(throws: Problem.self) { try run(DataStep(op: .parse_json, from: ""), .string("nope")) }
    }

    @Test func aDataStepInAFlowGivesTheNextStepARealList() async throws {
        let w = try World()
        let run = try await done(w, [["id": "t", "text": "x\ny"], ["id": "l", "data": ["op": "lines", "from": "{{t}}"]], ["id": "c", "data": ["op": "count", "from": "{{l}}"]], ["id": "s", "text": "{{c}} lines"]])
        #expect(run?.status == .done)
        #expect(run?.values.value("s") == "2 lines")
    }

    // MARK: For each

    @Test func aLoopGoesThroughEachAndCollects() async throws {
        let w = try World()
        let run = try await done(w, [["id": "list", "text": "one\ntwo\nthree"], ["id": "each", "for_each": "{{list}}", "steps": [["id": "out", "text": "{{index}}: {{item}}"]]], ["id": "after", "text": "{{each[1]}}"]])
        #expect(run?.status == .done)
        #expect(run?.values.value("after") == "2: two")
        #expect(run?.values.resolve("item") == nil, "gone when the loop is")
        #expect(run?.records.filter { $0.step == "out" }.map(\.scope) == ["1", "2", "3"], "each go has its own record")
    }

    @Test func aLoopWontUseWhatsInsideItAfterward() throws {
        let w = try World()
        let body = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "each", "for_each": "a\nb", "steps": [["id": "in", "text": "x"]]], ["id": "later", "text": "{{in}}"]]])
        #expect(body.problems(w.catalog).contains { $0.step == "later" })
    }

    @Test func aLoopTheLimitStopsAndAnEmptyListJustGoesOn() async throws {
        let w = try World()
        let over = try await done(w, [["id": "each", "for_each": "a\nb\nc", "limit": 2, "steps": [["id": "x", "text": "y"]]]])
        #expect(over?.status == .failed)
        let w2 = try World()
        let none = try await done(w2, [["id": "e", "text": ""], ["id": "each", "for_each": "{{e}}", "steps": [["id": "x", "text": "y"]]], ["id": "z", "text": "{{each}}"]])
        #expect(none?.status == .done)
    }

    @Test func oneFailedItemCanBeNotedAndTheRestGoOn() async throws {
        let w = try World()
        w.host.answers["changes.it"] = [Actions.Outcome(status: .ok, text: "fine", summary: "ok"), Actions.Outcome(status: .error, text: "boom", summary: ""), Actions.Outcome(status: .ok, text: "fine", summary: "ok")]
        let run = try await done(w, [["id": "each", "for_each": "a\nb\nc", "item_failure": "collect", "steps": [["id": "act", "do": "changes.it", "with": ["text": "{{item}}"]]]]])
        #expect(run?.status == .done)
        #expect(w.host.calls.filter { $0.tool == "changes.it" }.count == 3)
        #expect(run?.record(of: "each")?.status == .failed, "and it says one failed")
        #expect(run?.records.first { $0.step == "act" && $0.scope == "2" }?.status == .failed, "item 2 can be found")
    }

    /// Item 2 of 3 is what's in the air: a restart doesn't go back to item 1, or do item 2 again by itself.
    @Test func aRestartInTheMiddleOfALoopComesBackThere() async throws {
        let w = try World()
        w.host.hold = "changes.it"
        let flow = try w.flow([["id": "each", "for_each": "a\nb\nc", "steps": [["id": "act", "do": "changes.it", "with": ["text": "{{item}}"]]]]])
        let run = try #require(w.engine.start(flow, mode: .live, why: "t"))
        await w.quiet()
        w.host.hold = nil
        w.restart()
        w.engine.recover()
        await w.quiet()
        let back = try #require(w.store.run(run.id))
        #expect(back.status == .interrupted, "it may have happened: the person says")
        #expect(back.frames.first?.index == 0)
        #expect(back.frames.first?.items.count == 3, "and it knows where it was")
    }

    // MARK: Choose, try, finish

    @Test func theFirstPathThatFitsIsTaken() async throws {
        let w = try World()
        let steps: [[String: Any]] = [["id": "v", "text": "the invoice is late"], ["choose": "{{v}}", "paths": [["when": "paid", "steps": [["id": "a", "text": "A"]]], ["when": "late", "steps": [["id": "b", "text": "B"]]]], "else": [["id": "c", "text": "C"]]]]
        let run = try await done(w, steps)
        #expect(run?.values.value("b") == "B")
        #expect(run?.values.resolve("a") == nil)
        #expect(run?.values.resolve("c") == nil)
    }

    @Test func aFailureGoesToRecoverAndTheLastStepsRunEitherWay() async throws {
        let w = try World()
        w.host.answers["changes.it"] = [Actions.Outcome(status: .error, text: "boom", summary: "")]
        let run = try await done(w, [["try": [["id": "act", "do": "changes.it", "with": ["text": "x"]]], "recover": [["id": "r", "text": "saw: {{error}}"]], "always": [["id": "z", "text": "cleaned"]]], ["id": "after", "text": "on"]])
        #expect(run?.status == .done)
        #expect(run?.values.value("r") == "saw: boom")
        #expect(run?.values.value("z") == "cleaned")
        #expect(run?.values.value("after") == "on")
        #expect(run?.values.resolve("error") == nil)
    }

    @Test func aFailureWithNoRecoverStillRunsTheLastStepsThenFails() async throws {
        let w = try World()
        w.host.answers["changes.it"] = [Actions.Outcome(status: .error, text: "boom", summary: "")]
        let run = try await done(w, [["try": [["id": "act", "do": "changes.it", "with": ["text": "x"]]], "always": [["id": "z", "text": "cleaned"]]], ["id": "after", "text": "on"]])
        #expect(run?.status == .failed)
        #expect(run?.problem == "boom")
        #expect(run?.values.value("z") == "cleaned")
        #expect(run?.values.resolve("after") == nil)
    }

    @Test func finishEndsTheFlowByWayOfItsLastSteps() async throws {
        let w = try World()
        let run = try await done(w, [["try": [["id": "a", "text": "kept"], ["finish": "{{a}}"], ["id": "no", "text": "never"]], "always": [["id": "z", "text": "cleaned"]]], ["id": "after", "text": "never"]])
        #expect(run?.status == .done)
        #expect(run?.output == .string("kept"))
        #expect(run?.values.value("z") == "cleaned")
        #expect(run?.values.resolve("no") == nil)
        #expect(run?.values.resolve("after") == nil)
    }

    // MARK: Flows and lanes

    @Test func aCalledFlowGetsItsInputsAndGivesBackItsResult() async throws {
        let w = try World()
        var child = try w.flow([["id": "made", "text": "for {{input.who}}"], ["finish": "{{made}}"]])
        child.name = "Child"
        w.store.save(child)
        let run = try await done(w, [["id": "r", "call_flow": "Child", "inputs": ["who": "Ada"]], ["id": "s", "text": "got {{r}}"]])
        await w.quiet()
        let id = try #require(run).id
        let back = try #require(w.store.run(id))
        #expect(back.status == .done)
        #expect(back.values.value("s") == "got for Ada")
    }

    @Test func aChildsFailureIsTheParentsToHandle() async throws {
        let w = try World()
        var child = try w.flow([["id": "act", "do": "changes.it", "with": ["text": "x"]]])
        child.name = "Child"
        w.store.save(child)
        w.host.answers["changes.it"] = [Actions.Outcome(status: .error, text: "boom", summary: "")]
        let flow = try w.flow([["try": [["id": "r", "call_flow": "Child"]], "recover": [["id": "h", "text": "handled {{error}}"]]]])
        let run = try #require(w.engine.start(flow, mode: .live, why: "t"))
        await w.quiet()
        let back = try #require(w.store.run(run.id))
        #expect(back.status == .done)
        #expect(back.values.value("h") == "handled boom")
    }

    @Test func flowsCantEndUpCallingThemselves() async throws {
        let w = try World()
        var a = try w.flow([["id": "x", "call_flow": "B"]])
        a.name = "A"
        w.store.save(a)
        var b = try w.flow([["id": "y", "call_flow": "A"]])
        b.name = "B"
        w.store.save(b)
        let run = try #require(w.engine.start(a, mode: .live, why: "t"))
        await w.quiet()
        let back = try #require(w.store.run(run.id))
        #expect(back.status == .failed)
        #expect(w.store.runs(of: a.id).filter { $0.parent == nil }.count == 1, "and it doesn't run away")
    }

    @Test func lanesAllFinishThenItCarriesOnWithEach() async throws {
        let w = try World()
        let flow = try w.flow([["id": "both", "parallel": [["name": "First one", "steps": [["id": "a", "text": "A"]]], ["name": "Second", "steps": [["id": "b", "text": "B"]]]]], ["id": "s", "text": "{{both.first_one}}{{both.second}}"]])
        let run = try #require(w.engine.start(flow, mode: .live, why: "t"))
        await w.quiet()
        let back = try #require(w.store.run(run.id))
        #expect(back.status == .done)
        #expect(back.values.value("s") == "AB")
    }

    @Test func oneLaneFailingFailsTheStepAfterTheOthersFinish() async throws {
        let w = try World()
        w.host.answers["changes.it"] = [Actions.Outcome(status: .error, text: "boom", summary: "")]
        let flow = try w.flow([["id": "both", "parallel": [["name": "bad", "steps": [["id": "a", "do": "changes.it", "with": ["text": "x"]]]], ["name": "good", "steps": [["id": "b", "text": "B"]]]]], ["id": "s", "text": "after"]])
        let run = try #require(w.engine.start(flow, mode: .live, why: "t"))
        await w.quiet()
        let back = try #require(w.store.run(run.id))
        #expect(back.status == .failed)
        #expect(w.store.runs(of: flow.id).filter { $0.parent != nil }.count == 2, "its lanes ran once")
        #expect(back.values.resolve("s") == nil)
    }

    // MARK: Waiting for people and things

    private let form: [[String: Any]] = [["id": "f", "form": ["title": "Check it", "hours": 72, "fields": [["name": "n", "label": "How many", "kind": "number"], ["name": "ok", "label": "Right?", "kind": "yes_no", "required": false]]]], ["id": "s", "text": "{{f.n}}"]]

    @Test func aFormWaitsAcrossARestartAndIsAnsweredOnce() async throws {
        let w = try World()
        let flow = try w.flow(form)
        let run = try #require(w.engine.start(flow, mode: .live, why: "t"))
        await w.quiet()
        #expect(w.store.run(run.id)?.status == .waiting)
        #expect(w.host.notices.contains { $0.attention }, "and it says so")
        w.restart()
        w.engine.recover()
        #expect(w.store.run(run.id)?.form != nil, "it's on the disk, not in memory")
        #expect(throws: Problem.self, "a number is a number") { try w.engine.answer(run: run.id, form: ["n": .string("many")]) }
        try w.engine.answer(run: run.id, form: ["n": .string("12")])
        #expect(throws: Problem.self, "once") { try w.engine.answer(run: run.id, form: ["n": .string("13")]) }
        await w.quiet()
        let back = try #require(w.store.run(run.id))
        #expect(back.status == .done)
        #expect(back.values.resolve("f", path: ".n") == .number(12))
        #expect(back.values.value("s") == "12")
    }

    @Test func aFormNobodyAnswersFailsTheStepAtItsTime() async throws {
        let w = try World()
        let flow = try w.flow(form)
        let run = try #require(w.engine.start(flow, mode: .live, why: "t"))
        await w.quiet()
        w.now = w.now.addingTimeInterval(73 * 3600)
        w.engine.tick()
        await w.quiet()
        #expect(w.store.run(run.id)?.status == .failed)
        #expect(w.store.run(run.id)?.problem?.contains("in time") == true)
    }

    @Test func waitingForSomethingGoesOnOnceOrFailsInTime() async throws {
        let w = try World()
        let steps: [[String: Any]] = [["id": "e", "wait_for": ["event": "note.saved", "contains": "invoice", "minutes": 60]], ["id": "s", "text": "saw {{e}}"]]
        let flow = try w.flow(steps)
        let run = try #require(w.engine.start(flow, mode: .live, why: "t"))
        await w.quiet()
        w.engine.happened(name: "note.saved", title: "Groceries", detail: nil)
        await w.quiet()
        #expect(w.store.run(run.id)?.status == .waiting, "not what it's waiting for")
        w.engine.happened(name: "note.saved", title: "The invoice", detail: nil)
        w.engine.happened(name: "note.saved", title: "The invoice again", detail: nil)
        await w.quiet()
        #expect(w.store.run(run.id)?.status == .done)
        #expect(w.store.run(run.id)?.values.value("s") == "saw The invoice", "once")

        let late = try #require(w.engine.start(try w.flow(steps), mode: .live, why: "t"))
        await w.quiet()
        w.now = w.now.addingTimeInterval(61 * 60)
        w.engine.tick()
        await w.quiet()
        #expect(w.store.run(late.id)?.status == .failed)
    }

    // MARK: AI answers as data

    @Test func anAIAnswerWithFieldsIsARecordOrAFailure() async throws {
        let w = try World()
        w.host.aiAnswer = .answer(text: #"Here: {"total": 12.5, "who": "Ada"}"#, madeBy: "Scripted")
        let good = try await done(w, [["id": "x", "ai": "Read it", "fields": ["total": "number", "who": "text"]], ["id": "s", "text": "{{x.who}} {{x.total}}"]])
        #expect(good?.values.value("s") == "Ada 12.5")
        w.host.aiAnswer = .answer(text: #"{"total": "lots"}"#, madeBy: "Scripted")
        let bad = try await done(w, [["id": "y", "ai": "Read it", "fields": ["total": "number"]]])
        #expect(bad?.status == .failed, "what doesn't fit never goes on as data")
        #expect(AIFields.read("no json", ["a": "text"]) == nil)
    }

    // MARK: A second start

    @Test func aSecondStartQueuesOnDiskOrIsLetGo() async throws {
        let w = try World()
        w.host.hold = "changes.it"
        var flow = try w.flow([["id": "act", "do": "changes.it", "with": ["text": "x"]]])
        flow.live?.overlap = .queue
        w.store.save(flow)
        #expect(w.engine.start(flow, mode: .live, why: "1", trigger: "a") != nil)
        try await Task.sleep(for: .milliseconds(10))
        #expect(w.engine.start(flow, mode: .live, why: "2", trigger: "b") == nil)
        #expect(w.engine.start(flow, mode: .live, why: "3", trigger: "c") == nil)
        #expect(w.store.flow(flow.id)?.waitingStarts == ["b", "c"])
        w.host.hold = nil
        w.restart()
        #expect(w.store.flow(flow.id)?.waitingStarts == ["b", "c"], "a restart keeps its place in line")

        var skip = try w.flow([["id": "t", "wait_minutes": 5]])
        skip.live?.overlap = .skip
        w.store.save(skip)
        #expect(w.engine.start(skip, mode: .live, why: "1") != nil)
        try await Task.sleep(for: .milliseconds(10))
        #expect(w.engine.start(skip, mode: .live, why: "2") == nil)
        #expect(w.store.flow(skip.id)?.waitingStarts.isEmpty == true)
    }

    // MARK: On the page

    @Test func everyNewKindReadsBackExactly() throws {
        let raw: [String: Any] = ["trigger": ["type": "manual"], "overlap": "queue", "time_zone": "Europe/Paris", "steps": [
            ["id": "x", "ai": "w", "fields": ["a": "text"]],
            ["id": "each", "for_each": "{{x.a}}", "limit": 5, "item_failure": "collect", "steps": [["id": "i", "text": "{{item}}"]]],
            ["id": "c", "choose": "{{x}}", "paths": [["when": "p", "steps": [["id": "p1", "text": "q"]]]], "else": [["id": "p2", "text": "r"]]],
            ["id": "t", "try": [["id": "t1", "text": "a"]], "recover": [["id": "t2", "text": "b"]], "always": [["id": "t3", "text": "c"]]],
            ["id": "both", "parallel": [["name": "a", "steps": [["id": "l1", "text": "a"]]], ["name": "b", "steps": [["id": "l2", "text": "b"]]]]],
            ["id": "r", "call_flow": "Other", "inputs": ["who": "Ada"]],
            ["id": "d", "data": ["op": "filter", "from": "{{x}}", "field": "a.b", "test": "contains", "than": "z", "descending": true, "count": 2, "separator": ";"]],
            ["id": "f", "form": ["title": "T", "hours": 5, "fields": [["name": "n", "label": "N", "kind": "choice", "options": ["a", "b"], "required": false]]]],
            ["id": "e", "wait_for": ["event": "note.saved", "contains": "w", "minutes": 9]],
            ["id": "z", "finish": "{{r}}"],
        ]]
        let body = try FlowCodec.body(raw)
        #expect(try FlowCodec.body(FlowCodec.json(body)) == body)
        #expect(body.overlap == .queue)
        #expect(body.timeZone == "Europe/Paris")
    }

    @Test func aStepCanBePutInsideAnyWayThroughAnother() throws {
        let body = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "a", "text": "x"], ["id": "t", "try": [], "recover": [], "always": []], ["id": "e", "for_each": "x", "steps": []]]])
        let put = Editing.place("a", after: "recover:t", in: body)
        guard case .attempt(_, let recover, _)? = put.step("t")?.kind else { Issue.record("not a try"); return }
        #expect(recover.map(\.id) == ["a"])
        #expect(Editing.place("e", after: "each:e", in: body) == body, "not inside itself")
    }

    @Test func aFieldOffersWhatsThereInsideAScope() throws {
        let w = try World()
        let body = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "e", "for_each": "x", "steps": [["id": "i", "text": "y"]]], ["id": "t", "try": [["id": "j", "text": "z"]], "recover": [["id": "r", "text": "q"]]]]])
        #expect(Editing.around("i", in: body) == [.loop])
        #expect(Editing.around("r", in: body) == [.recover])
        #expect(Editing.available(before: "r", in: body).map(\.id) == ["e"], "not what the try may not have made")
        #expect(body.problems(w.catalog).isEmpty)
    }

    @Test func aFlowsInputsAreWhatItUses() throws {
        let body = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "a", "text": "{{input.who}} and {{input.what}} and {{input.who}}"]]])
        #expect(Inspector.inputs(of: body) == ["who", "what"])
    }
}

extension JSON {
    var arrayItems: [JSON] { if case .array(let a) = self { a } else { [] } }
}

@MainActor @Suite(.serialized) struct SideflowDiagnosisTests {
    typealias World = SideflowTests.World

    /// A practice run on a sample takes the way a real answer would.
    @Test func aPracticeSampleSendsItDownAnotherWay() async throws {
        let w = try World()
        let flow = try w.flow([["id": "r", "do": "reads.it", "with": ["q": "x"], "sample": #"{"late": "yes"}"#],
                               ["id": "c", "if": ["value": "{{r.late}}", "test": "is", "than": "yes"], "then": [["id": "y", "text": "late"]], "else": [["id": "n", "text": "fine"]]]], state: .draft)
        let run = await w.settled(w.engine.start(flow, mode: .practice, why: "t"))
        #expect(run?.values.value("y") == "late")
        #expect(!w.host.calls.contains { $0.tool == "reads.it" }, "not run")
    }

    @Test func practiceSaysWhichWaysHaventBeenTried() async throws {
        let w = try World()
        let app = App(folder: w.folder.appendingPathComponent("app"))
        app.engine.host = w.host
        let body = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "c", "if": ["value": "a", "test": "not_empty"], "then": [["id": "y", "text": "yes"]], "else": [["id": "n", "text": "no"]]]]])
        let flow = app.newFlow(name: "F", body: body)
        #expect(Pages.untried(flow, app).isEmpty, "no practice, nothing to say yet")
        let run = app.engine.start(flow, mode: .practice, why: "t")
        await w.quiet(app.store)
        #expect(app.store.run(run!.id)?.status == .done)
        #expect(Pages.untried(flow, app).count == 1)
        #expect(Pages.untried(flow, app).first?.contains("Otherwise") == true)
    }

    @Test func eachGoOfALoopCanBeReadOnItsOwn() async throws {
        let w = try World()
        let app = App(folder: w.folder.appendingPathComponent("app"))
        app.engine.host = w.host
        let flow = app.newFlow(name: "F", body: try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "e", "for_each": "a\nb", "steps": [["id": "t", "text": "got {{item}}"]]]]]))
        let run = try #require(app.engine.start(flow, mode: .once, why: "t"))
        await w.quiet(app.store)
        let done = try #require(app.store.run(run.id))
        // The first, not the second: with the scope ignored it would show the last go.
        let first = Pages.stepDetail(done, step: "t", scope: "1", app)
        #expect(JSONText.write(first.map { $0.blocks.map { "\($0)" } }).contains("got a"))
        #expect(!JSONText.write(first.map { $0.blocks.map { "\($0)" } }).contains("got b"))
    }

    /// What was live comes back as a draft, to read, and nothing runs differently until it's applied.
    @Test func anEarlierVersionIsKeptWhenAnotherGoesLive() async throws {
        let w = try World()
        var flow = try w.flow([["id": "a", "text": "first"]])
        let first = try #require(flow.live)
        flow.draft = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "a", "text": "second"]]])
        w.store.save(flow)
        w.engine.turnOn(flow.id)
        await w.quiet()
        let after = try #require(w.store.flow(flow.id))
        #expect(after.revisions.map(\.body) == [first])
        w.restart()
        #expect(w.store.flow(flow.id)?.revisions.count == 1)
    }
}

@MainActor @Suite(.serialized) struct SideflowStopTests {
    typealias World = SideflowTests.World

    @Test func stoppingAWaitingRunEndsItAndWhatItWaitsFor() async throws {
        let w = try World()
        var child = try w.flow([["id": "wait", "wait_minutes": 60]])
        child.name = "Child"
        w.store.save(child)
        let flow = try w.flow([["id": "r", "call_flow": "Child"]])
        let run = try #require(w.engine.start(flow, mode: .live, why: "t"))
        await w.quiet()
        let children = w.store.runs(of: child.id)
        #expect(children.first?.status == .waiting)
        w.engine.stop(run: run.id)
        #expect(w.store.run(run.id)?.status == .stopped)
        #expect(w.store.runs(of: child.id).first?.status == .stopped)
        #expect(!w.engine.isRunning(flow.id))
    }

    @Test func stoppingARunningRunLetsTheStepFinishAndNothingAfter() async throws {
        let w = try World()
        w.host.hold = nil
        let flow = try w.flow([["id": "a", "do": "changes.it", "with": ["text": "x"]], ["id": "b", "do": "changes.it", "with": ["text": "y"]]])
        let run = try #require(w.engine.start(flow, mode: .live, why: "t"))
        w.engine.stop(run: run.id)
        await w.quiet()
        #expect(w.store.run(run.id)?.status == .stopped)
        #expect(w.host.calls.filter { $0.tool == "changes.it" }.count <= 1)
        #expect(!w.engine.isRunning(flow.id))
    }
}

/// What an independent read of the engine found, each kept from coming back.
@MainActor @Suite(.serialized) struct SideflowEngineReviewTests {
    typealias World = SideflowTests.World

    @Test func aFlowThatOnlyCallsOthersStillShowsACard() async throws {
        let w = try World()
        var other = try w.flow([["id": "x", "text": "y"]])
        other.name = "Other"
        w.store.save(other)
        let flow = try w.flow([["id": "r", "call_flow": "Other", "inputs": ["who": "Ada"]]], state: .draft)
        w.engine.turnOn(flow.id)
        await w.quiet()
        #expect(w.host.plans.count == 1)
        #expect(w.host.plans.first?.when.contains("Other") == true)
        #expect(w.host.plans.first?.when.contains("Ada") == true, "and what it hands over")
    }

    @Test func aWaitAfterLanesStaysWaitingAndCanBeStopped() async throws {
        let w = try World()
        let flow = try w.flow([["id": "both", "parallel": [["name": "a", "steps": [["id": "a1", "text": "A"]]], ["name": "b", "steps": [["id": "b1", "text": "B"]]]]], ["id": "w", "wait_minutes": 30]])
        let run = try #require(w.engine.start(flow, mode: .live, why: "t"))
        await w.quiet()
        #expect(w.store.run(run.id)?.status == .waiting)
        w.engine.stop(run: run.id)
        #expect(w.store.run(run.id)?.status == .stopped)
        #expect(!w.engine.isRunning(flow.id))
    }

    @Test func aFormAfterLanesIsntFailedByALateWake() async throws {
        let w = try World()
        let flow = try w.flow([["id": "both", "parallel": [["name": "a", "steps": [["id": "a1", "text": "A"]]], ["name": "b", "steps": [["id": "b1", "text": "B"]]]]],
                               ["id": "f", "form": ["title": "T", "fields": [["name": "n", "label": "N", "kind": "text"]]]]])
        let run = try #require(w.engine.start(flow, mode: .live, why: "t"))
        await w.quiet()
        #expect(w.store.run(run.id)?.status == .waiting)
        #expect(w.store.run(run.id)?.form != nil)
    }

    @Test func stoppingACalledRunWakesTheOneWaitingForItAndLetsItsFlowGo() async throws {
        let w = try World()
        var child = try w.flow([["id": "wait", "wait_minutes": 60]])
        child.name = "Child"
        w.store.save(child)
        let flow = try w.flow([["id": "r", "call_flow": "Child"]])
        let run = try #require(w.engine.start(flow, mode: .live, why: "t"))
        await w.quiet()
        let called = try #require(w.store.runs(of: child.id).first)
        w.engine.stop(run: called.id)
        await w.quiet()
        #expect(w.store.run(run.id)?.status == .failed)
        #expect(!w.engine.isRunning(flow.id), "the flow isn't held until a restart")
        #expect(!w.engine.isRunning(child.id))
    }

    @Test func carryingOnPastALoopDoesntWalkIntoIt() async throws {
        let w = try World()
        let run = try await { () -> Run? in
            let flow = try w.flow([["id": "each", "for_each": "{{nothing_here}}", "on_failure": "carry_on", "steps": [["id": "in", "text": "never"]]], ["id": "after", "text": "on"]])
            return await w.settled(w.engine.start(flow, mode: .live, why: "t"))
        }()
        #expect(run?.status == .done)
        #expect(run?.values.value("after") == "on")
        #expect(run?.values.resolve("in") == nil)
    }

    @Test func aFirstWithANegativeCountDoesntCrash() throws {
        #expect(try DataStep(op: .first, from: "", count: -3).apply(to: .array([.number(1)]), than: "") == .array([]))
        let body = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "d", "data": ["op": "first", "from": "x", "count": -3]]]])
        guard case .data(let d)? = body.step("d")?.kind else { Issue.record("not data"); return }
        #expect(d.count == 1)
    }

    /// A step just added is empty, and a restart comes before it's written.
    @Test func aStepNotWrittenYetSurvivesARestart() throws {
        let w = try World()
        var flow = try w.flow([["id": "z", "text": "x"]], state: .draft)
        flow.draft = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "a", "ai": ""], ["id": "b", "ask": ""], ["id": "c", "run_flow": ""], ["id": "d", "call_flow": ""]]], saved: true)
        w.store.save(flow)
        w.restart()
        #expect(w.store.flow(flow.id)?.draft.allSteps.count == 4)
    }

    @Test func undoAndSaveKeepStraightWhatsSaved() throws {
        let (one, two) = (try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "a", "text": "1"]]]), try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "a", "text": "2"]]]))
        var flow = Flow(id: "f", name: "F", draft: one, createdAt: Date(), updatedAt: Date())
        flow.show(two)
        #expect(flow.hasUnsaved)
        #expect(flow.kept == one)
        flow.saved = nil // Save
        flow.show(one) // Undo after saving
        #expect(flow.hasUnsaved, "what's saved is two now, so this is a change")
        #expect(flow.kept == two)
        flow.show(two) // Redo
        #expect(!flow.hasUnsaved)
    }

    @Test func wordsForAToolStayWords() {
        var v = Values()
        v.set("count", JSON.number(3))
        v.set("list", JSON.array([.string("a")]))
        let filled = v.fill(["body": .string("{{count}}"), "items": .string("{{list}}")], wordsIn: ["body"])
        #expect(filled["body"] as? String == "3")
        #expect(filled["items"] as? [String] == ["a"])
    }

    @Test func tooManyInAMinuteRestsAndComesBack() async throws {
        let w = try World()
        w.host.answers["changes.it"] = [Actions.Outcome(status: .busy, text: "Too many", summary: "")]
        let flow = try w.flow([["id": "a", "do": "changes.it", "with": ["text": "x"]]])
        let run = try #require(w.engine.start(flow, mode: .live, why: "t"))
        await w.quiet()
        #expect(w.store.run(run.id)?.status == .waiting, "not a failure, and not the person's to answer")
        w.now = w.now.addingTimeInterval(62)
        w.engine.tick()
        await w.quiet()
        #expect(w.store.run(run.id)?.status == .done)
    }

    @Test func aModelCantSkipAFormOrWhatARunWaitsFor() async throws {
        let w = try World()
        let flow = try w.flow([["id": "f", "form": ["title": "T", "fields": [["name": "n", "label": "N", "kind": "text"]]]], ["id": "s", "text": "after"]])
        let run = try #require(w.engine.start(flow, mode: .live, why: "t"))
        await w.quiet()
        #expect(w.store.run(run.id)?.status == .waiting)
        #expect(w.store.run(run.id)?.form != nil)
    }

    @Test func lanesDontCountTowardWhatsKeptOrTheRunawayLimit() async throws {
        let w = try World()
        w.engine.runawayLimit = 3
        let flow = try w.flow([["id": "both", "parallel": [["name": "a", "steps": [["id": "a1", "text": "A"]]], ["name": "b", "steps": [["id": "b1", "text": "B"]]]]]])
        for n in 1...3 {
            let run = try #require(w.engine.start(flow, mode: .live, why: "\(n)"))
            await w.quiet()
            #expect(w.store.run(run.id)?.status == .done)
        }
        #expect(w.engine.start(flow, mode: .live, why: "4") == nil, "the fourth trips it, not the second")
    }
}

@MainActor @Suite(.serialized) struct SideflowEngineRereadTests {
    typealias World = SideflowTests.World

    @Test func aStepNotWrittenYetIsMarkedSoItCantTurnOn() throws {
        let w = try World()
        let body = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "a", "ai": ""], ["id": "b", "ask": " "]]], saved: true)
        let problems = body.problems(w.catalog)
        #expect(problems.contains { $0.step == "a" })
        #expect(problems.contains { $0.step == "b" })
    }

    @Test func stoppingWhileACardIsUpEndsItThere() async throws {
        let w = try World()
        w.host.answers["changes.it"] = [Actions.Outcome(status: .denied, text: "no", summary: "")]
        let flow = try w.flow([["id": "a", "do": "changes.it", "with": ["text": "x"]], ["id": "b", "text": "after"]])
        let run = try #require(w.engine.start(flow, mode: .live, why: "t"))
        w.engine.stop(run: run.id)
        await w.quiet()
        #expect(w.store.run(run.id)?.status == .stopped)
        #expect(!w.engine.isRunning(flow.id))
    }

    @Test func aLongLoopKeepsItsListAList() async throws {
        let w = try World()
        let long = String(repeating: "word ", count: 2000)
        let items = (0..<300).map { "line \($0)" }.joined(separator: "\n")
        let flow = try w.flow([["id": "l", "text": items], ["id": "each", "for_each": "{{l}}", "steps": [["id": "t", "text": long]]], ["id": "n", "data": ["op": "count", "from": "{{each}}"]]])
        let run = await w.settled(w.engine.start(flow, mode: .live, why: "t"), seconds: 15)
        #expect(run?.status == .done, "\(run?.problem ?? "")")
        #expect(run?.values.value("n") == "300")
    }

    @Test func aLongOutputStaysShortOnThePageAndWholeForTheNextStep() async throws {
        let w = try World()
        let long = String(repeating: "語", count: 30_000)
        let flow = try w.flow([["id": "a", "text": long], ["id": "b", "text": "{{a}}"]])
        let run = await w.settled(w.engine.start(flow, mode: .live, why: "t"))
        #expect((run?.record(of: "a")?.output?.count ?? 0) <= Engine.keptOutput + 1)
        #expect(run?.values.value("b").count == 30_000)
    }

    @Test func stoppingARunUnderWayWorksFromATool() async throws {
        let w = try World()
        let flow = try w.flow([["id": "a", "do": "changes.it", "with": ["text": "x"]], ["id": "b", "do": "changes.it", "with": ["text": "y"]]])
        let run = try #require(w.engine.start(flow, mode: .live, why: "t"))
        w.engine.proceed(run.id, .stop)
        await w.quiet()
        #expect(w.store.run(run.id)?.status == .stopped)
    }
}


/// What reading the engine independently found, each kept from coming back.
@MainActor @Suite(.serialized) struct SideflowSecondReadTests {
    typealias World = SideflowTests.World

    private func onDisk(_ w: World) -> String { (try? String(contentsOf: w.folder.appendingPathComponent("flows.json"), encoding: .utf8)) ?? "" }

    @Test func whatAPageSavesAsItGoesAlwaysReadsBack() throws {
        for trigger: [String: Any] in [["type": "watch", "kind": "url_change", "target": "https://x.example"], ["type": "schedule", "every_minutes": 60]] {
            let w = try World()
            var flow = try w.flow([["id": "a", "text": "x"]], trigger: trigger)
            switch flow.draft.trigger {
            case .watch(var t):
                t.target = ""
                flow.draft.trigger = .watch(t)
            default:
                flow.draft.trigger = .every(minutes: 20000, catchUp: false)
            }
            flow.live = flow.draft
            w.store.save(flow)
            w.restart()
            let back = try #require(w.store.flow(flow.id), "the flow is still there")
            #expect(back.draft.trigger == flow.draft.trigger)
            #expect(w.store.unreadableCount == 0)
            #expect(!back.draft.problems(w.catalog).isEmpty, "and it's marked to fix before it can run")
            #expect(throws: Problem.self) { _ = try FlowCodec.body(FlowCodec.json(back.draft)) }
        }
    }

    @Test func aNumberNoFileCanHoldNeverStopsTheSaving() throws {
        let w = try World()
        let number = Catalog.Parameter(name: "n", kind: .number, required: false, title: "n")
        #expect(Editing.value("inf", for: number) == .string("inf"))
        #expect(Editing.value("nan", for: number) == .string("nan"))
        #expect(Condition.number(String(repeating: "9", count: 400)) == nil)
        var flow = try w.flow([["id": "a", "do": "reads.it", "with": ["q": "x"]]])
        flow.name = "Kept"
        if case .action(let tool, var input) = flow.draft.steps[0].kind {
            input["n"] = .number(.infinity)
            flow.draft.steps[0].kind = .action(tool: tool, input: input)
        }
        w.store.save(flow)
        #expect(!w.store.flowsNotSaved, "even one that got in some other way")
        #expect(w.store.failedSaves == 0)
        w.restart()
        #expect(w.store.flow(flow.id)?.name == "Kept")
    }

    @Test func aHugeNumberInWhatARunReadDoesntWedgeIt() async throws {
        let w = try World()
        let digits = String(repeating: "9", count: 400)
        let flow = try w.flow([["id": "n", "data": ["from": digits, "op": "number"], "on_failure": "carry_on"], ["id": "b", "text": "after"]])
        let run = await w.settled(w.engine.start(flow, mode: .live, why: "t"))
        #expect(run?.status == .done)
        #expect(w.store.failedSaves == 0)
    }

    @Test func aFlowsFileThatCantBeReadIsPutAsideNotWrittenOver() throws {
        let w = try World()
        let file = w.folder.appendingPathComponent("flows.json")
        try Data("this isn't a list".utf8).write(to: file)
        w.restart()
        let aside = try #require(w.store.damagedFile)
        #expect((try? String(contentsOf: aside, encoding: .utf8)) == "this isn't a list")
        _ = try w.flow([["id": "a", "text": "x"]])
        #expect((try? String(contentsOf: aside, encoding: .utf8)) == "this isn't a list", "still there after a save")
    }

    @Test func oneStrangeEntryKeepsItsPlaceAndTheRestStay() throws {
        let w = try World()
        let good = try w.flow([["id": "a", "text": "x"]])
        let file = w.folder.appendingPathComponent("flows.json")
        var list = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [Any])
        list.append("not a flow")
        try JSONSerialization.data(withJSONObject: list).write(to: file)
        w.restart()
        #expect(w.store.flow(good.id) != nil)
        #expect(w.store.unreadableCount == 1)
        w.store.save(try #require(w.store.flow(good.id)))
        #expect(onDisk(w).contains("not a flow"))
    }

    @Test func aFailedSaveOfFlowsReachesThePage() throws {
        let w = try World()
        let flow = try w.flow([["id": "a", "text": "x"]])
        // A folder where the file goes: nothing can be written there.
        let file = w.folder.appendingPathComponent("flows.json")
        try FileManager.default.removeItem(at: file)
        try FileManager.default.createDirectory(at: file, withIntermediateDirectories: false)
        w.store.save(flow)
        #expect(w.store.flowsNotSaved)
        try FileManager.default.removeItem(at: file)
        w.store.save(flow)
        #expect(!w.store.flowsNotSaved)
    }

    @Test func anAIStepThatNeverFitsDoesntGoRoundForEver() async throws {
        let w = try World()
        w.host.aiAnswer = .answer(text: "not the fields", madeBy: "Scripted")
        let flow = try w.flow([["id": "a", "ai": "Write", "fields": ["name": "text"], "on_failure": "retry"]])
        let run = try #require(w.engine.start(flow, mode: .live, why: "t"))
        for _ in 0..<12 {
            await w.quiet()
            w.now = w.now.addingTimeInterval(3600)
            w.engine.tick()
        }
        await w.quiet()
        #expect(w.store.run(run.id)?.status == .needs_you || w.store.run(run.id)?.status == .failed)
        #expect(w.host.written.count <= 8, "three goes and a second look at each, not until the day's AI is gone")
    }

    @Test func stopStaysPressedAcrossARestart() async throws {
        let w = try World()
        w.host.hold = "reads.it"
        let flow = try w.flow([["id": "a", "do": "reads.it"], ["id": "b", "do": "changes.it", "with": ["text": "x"]]])
        let run = try #require(w.engine.start(flow, mode: .live, why: "t"))
        await w.quiet()
        w.engine.stop(run: run.id)
        #expect(w.store.run(run.id)?.status == .running, "the step under way finishes first")
        w.host.hold = nil
        w.restart()
        w.engine.recover()
        await w.quiet()
        #expect(w.store.run(run.id)?.status == .stopped)
        #expect(!w.host.calls.contains { $0.tool == "changes.it" })
        #expect(!w.engine.isRunning(flow.id))
    }

    @Test func stoppedInTheMiddleOfAChangeSaysItMayHaveHappened() async throws {
        let w = try World()
        w.host.hold = "changes.it"
        let flow = try w.flow([["id": "a", "do": "changes.it", "with": ["text": "x"]]])
        let run = try #require(w.engine.start(flow, mode: .live, why: "t"))
        await w.quiet()
        w.engine.stop(run: run.id)
        w.host.hold = nil
        w.restart()
        w.engine.recover()
        await w.quiet()
        let back = try #require(w.store.run(run.id))
        #expect(back.status == .stopped)
        #expect(back.record(of: "a")?.status == .unknown)
    }

    @Test func aFlowWithNoActionsStillNeedsAPersonToRunByItself() async throws {
        let w = try World()
        let scheduled = try w.flow([["id": "a", "text": "x"]], trigger: ["type": "schedule", "every_minutes": 60], state: .draft)
        w.engine.turnOn(scheduled.id)
        await w.quiet()
        #expect(w.host.plans.count == 1, "a schedule is on a card even with nothing to allow")
        let writes = try w.flow([["id": "a", "ai": "Write"]], state: .draft)
        w.engine.turnOn(writes.id)
        await w.quiet()
        #expect(w.host.plans.last?.when.contains("your AI") == true, "and it says what goes to the AI")
        let inert = try w.flow([["id": "a", "text": "x"]], state: .draft)
        let before = w.host.plans.count
        w.engine.turnOn(inert.id)
        await w.quiet()
        #expect(w.host.plans.count == before, "started by hand and working only on its own values: nothing to read")
        #expect(w.store.flow(inert.id)?.state == .on)
    }

    @Test func whatAStepSetsOffGoesByItsExactName() async throws {
        let w = try World()
        var other = try w.flow([["id": "a", "do": "changes.it", "with": ["text": "x"]]])
        other.name = "Monthly report to boss"
        w.store.save(other)
        let run = try #require(w.engine.start(try w.flow([["id": "go", "run_flow": "report"]]), mode: .live, why: "t"))
        let done = await w.settled(run)
        #expect(done?.status == .needs_you || done?.status == .failed)
        #expect(w.store.runs(of: other.id).isEmpty, "the words appear in its name, which isn't enough")
        #expect(w.store.named("MONTHLY REPORT TO BOSS")?.id == other.id)
    }

    @Test func aLongValueLeavesEveryNameOnTheCard() throws {
        let w = try World()
        let long = String(repeating: "x", count: 900)
        let flow = try w.flow([["id": "a", "call_flow": "First", "inputs": ["v": long]], ["id": "b", "run_flow": "Second"]], state: .draft)
        let when = w.engine.livePlan(flow).when
        #expect(when.contains("First"))
        #expect(when.contains("Second"))
        #expect(!when.contains(long))
        #expect(when.count < 600)
    }

    @Test func aRunFromADraftDoesntLendItsWayToAnOnFlow() async throws {
        let w = try World()
        var other = try w.flow([["id": "a", "do": "reads.it"]])
        other.name = "Other"
        w.store.save(other)
        let draft = try w.flow([["id": "c", "call_flow": "Other"]], state: .draft)
        let run = try #require(w.engine.start(draft, mode: .once, why: "t"))
        await w.quiet()
        #expect(w.store.run(run.id)?.status == .done)
        #expect(w.store.runs(of: other.id).first?.mode == .once)
        #expect(w.host.calls.first { $0.tool == "reads.it" }?.plan == nil, "on a card, not under Other's plan")
    }

    @Test func aRestartBetweenAStepAndWhatItStartedDoesntStartASecond() async throws {
        let w = try World()
        var other = try w.flow([["id": "a", "wait_minutes": 60]])
        other.name = "Other"
        w.store.save(other)
        let flow = try w.flow([["id": "c", "call_flow": "Other"]])
        let run = try #require(w.engine.start(flow, mode: .live, why: "t"))
        await w.quiet()
        let child = try #require(w.store.runs(of: other.id).first)
        try FileManager.default.removeItem(at: w.folder.appendingPathComponent("runs/\(child.id).json"))
        w.restart()
        w.engine.recover()
        await w.quiet()
        #expect(w.store.runs(of: other.id).isEmpty, "nothing started again")
        #expect(w.store.run(run.id)?.problem != nil, "and it says what it was waiting for is gone")
    }

    @Test func aLaneKeepsItsItemAfterALoopOfItsOwn() async throws {
        let w = try World()
        let lane: [String: Any] = ["name": "a", "steps": [
            ["id": "inner", "for_each": "1\n2", "steps": [["id": "t", "text": "{{item}}"]]],
            ["id": "after", "text": "still {{item}}"],
        ]]
        let flow = try w.flow([["id": "outer", "for_each": "one\ntwo", "steps": [["id": "both", "parallel": [lane, ["name": "b", "steps": [["id": "b1", "text": "b"]]]]]]]])
        let run = await w.settled(w.engine.start(flow, mode: .live, why: "t"), seconds: 30)
        await w.quiet()
        #expect(w.store.run(run!.id)?.status == .done)
        let lanes = w.store.runs(of: flow.id).filter { $0.parent == run?.id }
        #expect(lanes.contains { $0.values.value("after") == "still one" })
    }

    @Test func anAnswerInTheMomentAFormRunsOutIsRefused() throws {
        let w = try World()
        let flow = try w.flow([["id": "f", "form": ["title": "Q", "fields": [["name": "a", "kind": "text"]]]]])
        var run = Run(id: "r", flow: flow.id, flowName: flow.name, mode: .live, status: .running, why: "t", startedAt: w.now, body: flow.running)
        run.form = Run.WaitingForm(step: "f")
        w.store.save(run)
        #expect(throws: Problem.self) { try w.engine.answer(run: "r", form: ["a": .string("late")]) }
    }

    @Test func aDeletedFlowsRunDoesntComeBack() async throws {
        let w = try World()
        w.host.hold = "reads.it"
        let flow = try w.flow([["id": "a", "do": "reads.it"]])
        let run = try #require(w.engine.start(flow, mode: .live, why: "t"))
        await w.quiet()
        w.engine.delete(flow.id)
        await w.quiet()
        w.store.save(run)
        #expect(w.store.run(run.id) == nil)
        #expect(!FileManager.default.fileExists(atPath: w.folder.appendingPathComponent("runs/\(run.id).json").path))
    }

    @Test func resumingAfterAWatchThatNeverStartedMakesIt() async throws {
        let w = try World()
        let trigger: [String: Any] = ["type": "watch", "kind": "url_change", "target": "https://x.example"]
        let flow = try w.flow([["id": "a", "do": "reads.it"]], trigger: trigger, state: .draft)
        w.host.answers["watch.create"] = [Actions.Outcome(status: .denied, text: "Share the folder first")]
        w.engine.turnOn(flow.id)
        await w.quiet()
        #expect(w.store.flow(flow.id)?.state == .paused)
        #expect(w.store.flow(flow.id)?.startProblem != nil)
        #expect(w.store.flow(flow.id)?.watchTitle == nil)
        w.engine.resume(flow.id)
        await w.quiet()
        let back = try #require(w.store.flow(flow.id))
        #expect(back.state == .on)
        #expect(back.watchTitle != nil)
        #expect(back.startProblem == nil)
        #expect(w.host.calls.filter { $0.tool == "watch.create" }.count == 2)
    }

    @Test func resumingWhenTheWatchStillCantStartStaysPaused() async throws {
        let w = try World()
        let trigger: [String: Any] = ["type": "watch", "kind": "url_change", "target": "https://x.example"]
        let flow = try w.flow([["id": "a", "do": "reads.it"]], trigger: trigger, state: .draft)
        w.host.answers["watch.create"] = [Actions.Outcome(status: .denied, text: "No"), Actions.Outcome(status: .denied, text: "Still no")]
        w.engine.turnOn(flow.id)
        await w.quiet()
        w.engine.resume(flow.id)
        await w.quiet()
        #expect(w.store.flow(flow.id)?.state == .paused, "not On with nothing looking")
    }

    @Test func endingThePlanStopsItsWatchAndKeepsWhatWasOn() async throws {
        let w = try World()
        var flow = try w.flow([["id": "a", "do": "reads.it"]], trigger: ["type": "watch", "kind": "url_change", "target": "https://x.example"])
        flow.watchTitle = "Test · Sideflow"
        w.store.save(flow)
        w.engine.planEnded(flow.id)
        await w.quiet()
        let after = try #require(w.store.flow(flow.id))
        #expect(after.state == .paused)
        #expect(after.live == nil)
        #expect(after.revisions.count == 1, "what was on can be brought back")
        #expect(after.watchTitle == nil)
        #expect(w.host.calls.contains { $0.tool == "watch.stop" && $0.plan == nil })
    }

    @Test func deletingStopsTheWatchWhileThePlanStillStands() async throws {
        let w = try World()
        var flow = try w.flow([["id": "a", "do": "reads.it"]], trigger: ["type": "watch", "kind": "url_change", "target": "https://x.example"])
        flow.watchTitle = "Test · Sideflow"
        w.store.save(flow)
        w.engine.delete(flow.id)
        await w.quiet()
        #expect(w.host.calls.contains { $0.tool == "watch.stop" && $0.plan == flow.planId })
        #expect(w.host.forgotten.contains(flow.planId))
    }

    @Test func aFormInALaneShowsWhereThePersonLooks() async throws {
        let w = try World()
        let app = App(folder: w.folder.appendingPathComponent("app"))
        app.engine.host = w.host
        let body = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "both", "parallel": [
            ["name": "a", "steps": [["id": "f", "form": ["title": "Q", "fields": [["name": "x", "kind": "text"]]]]]],
            ["name": "b", "steps": [["id": "b1", "text": "b"]]],
        ]]]])
        let flow = app.newFlow(name: "F", body: body)
        _ = app.engine.start(flow, mode: .once, why: "t")
        await w.quiet(app.store)
        #expect(!Pages.needsYou(app).isEmpty)
        #expect(Pages.summary(app).tone == .warn)
    }
}

/// What reading those fixes found, kept from coming back too.
@MainActor @Suite(.serialized) struct SideflowThirdReadTests {
    typealias World = SideflowTests.World

    @Test func aScheduleNoPageCouldSaveIsNeverDue() throws {
        let w = try World()
        for minutes in [0, -5, 3, 20000] {
            #expect(Schedule.due(.every(minutes: minutes, catchUp: false), last: w.now, now: w.now.addingTimeInterval(9000)) == nil)
        }
        #expect(Schedule.due(.every(minutes: 15, catchUp: false), last: w.now, now: w.now.addingTimeInterval(9000)) != nil)
    }

    @Test func aTriggerThatCantRunNeverReachesACard() async throws {
        let w = try World()
        var flow = try w.flow([["id": "a", "do": "reads.it"]], trigger: ["type": "watch", "kind": "url_change", "target": "https://x.example"], state: .paused)
        flow.draft.trigger = .watch(WatchTrigger(kind: "url_change", target: ""))
        w.store.save(flow)
        w.engine.turnOn(flow.id)
        await w.quiet()
        #expect(w.host.plans.isEmpty)
        #expect(w.store.flow(flow.id)?.startProblem != nil)
    }

    @Test func aCalledRunRemovedWithItsCallerStaysRemoved() async throws {
        let w = try World()
        var other = try w.flow([["id": "a", "wait_minutes": 60]])
        other.name = "Other"
        w.store.save(other)
        let flow = try w.flow([["id": "c", "call_flow": "Other"]])
        _ = try #require(w.engine.start(flow, mode: .live, why: "t"))
        await w.quiet()
        let child = try #require(w.store.runs(of: other.id).first)
        w.engine.delete(flow.id)
        await w.quiet()
        w.store.save(child)
        #expect(w.store.run(child.id) == nil)
    }

    @Test func aFlowsFileThatCantBeMovedOrReadIsNeverWrittenOver() throws {
        let w = try World()
        let file = w.folder.appendingPathComponent("flows.json")
        try Data("this isn't a list".utf8).write(to: file)
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: file.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: file.path) }
        w.restart()
        #expect(w.store.flowsNotSaved)
        _ = try w.flow([["id": "a", "text": "x"]])
        try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: file.path)
        #expect((try? String(contentsOf: file, encoding: .utf8)) == "this isn't a list")
    }

    @Test func aRunWhoseFlowCantBeReadDoesNothingMore() async throws {
        let w = try World()
        w.host.hold = "reads.it"
        let flow = try w.flow([["id": "a", "do": "reads.it"], ["id": "b", "do": "changes.it", "with": ["text": "x"]]])
        let run = try #require(w.engine.start(flow, mode: .live, why: "t"))
        await w.quiet()
        w.host.hold = nil
        try FileManager.default.removeItem(at: w.folder.appendingPathComponent("flows.json"))
        w.restart()
        w.engine.recover()
        await w.quiet()
        #expect(w.store.run(run.id)?.status == .stopped)
        #expect(!w.host.calls.contains { $0.tool == "changes.it" })
    }

    @Test func aStopForARunThatEndedIsForgotten() async throws {
        let w = try World()
        w.host.hold = "reads.it"
        let run = try #require(w.engine.start(try w.flow([["id": "a", "do": "reads.it"]]), mode: .live, why: "t"))
        await w.quiet()
        w.engine.stop(run: run.id)
        w.host.hold = nil
        w.restart()
        w.engine.recover()
        await w.quiet()
        let stopped = try #require(w.store.run(run.id))
        #expect(stopped.status == .stopped)
        #expect(stopped.record(of: "a")?.status != .running, "not Working… for ever")
        #expect(!w.store.takeStop(run.id))
    }

    @Test func aFlowNobodyReadAsksBeforeRunningAgain() async throws {
        let w = try World()
        let flow = try w.flow([["id": "a", "ai": "Write about {{trigger}}"]], trigger: ["type": "schedule", "every_minutes": 60])
        let hand = try w.flow([["id": "a", "text": "x"]])
        let actions = try w.flow([["id": "a", "do": "reads.it"]], trigger: ["type": "schedule", "every_minutes": 60])
        w.engine.pauseWhatNobodyRead()
        await w.quiet()
        #expect(w.store.flow(flow.id)?.state == .paused)
        #expect(w.store.flow(hand.id)?.state == .on, "started by hand and only its own values")
        #expect(w.store.flow(actions.id)?.state == .on, "each action is checked as it's called")
        w.engine.resume(flow.id)
        await w.quiet()
        #expect(w.host.plans.count == 1, "resuming shows the card this time")
    }

    @Test func everythingItSetsOffStaysOnTheCard() throws {
        let w = try World()
        let names = (1...14).map { "A flow with quite a long name to it, number \($0)" }
        let steps: [[String: Any]] = names.enumerated().map { ["id": "f\($0.offset)", "run_flow": $0.element] }
        let address = "https://example.com/" + String(repeating: "a", count: 700)
        let flow = try w.flow(steps, trigger: ["type": "watch", "kind": "url_change", "target": address], state: .draft)
        let when = w.engine.livePlan(flow).when
        #expect(when.count <= 600)
        #expect(when.contains(names[0]))
        #expect(when.contains("more"), "and it says how many more there are")
    }

    @Test func aNameNoStepCanFindIsMarkedAndPracticeSaysSo() async throws {
        let w = try World()
        var other = try w.flow([["id": "a", "text": "x"]])
        other.name = "Monthly report"
        w.store.save(other)
        let flow = try w.flow([["id": "go", "run_flow": "report"]], state: .draft)
        #expect(flow.draft.problems(w.catalog).contains { $0.step == "go" })
        let done = await w.settled(w.engine.start(flow, mode: .practice, why: "t"))
        #expect(done?.record(of: "go")?.status == .failed)
    }

    @Test func aNewFlowCantShadowAnotherAndARenameCarriesTheStepsThatNameIt() throws {
        let w = try World()
        let app = App(folder: w.folder.appendingPathComponent("app"))
        let body = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "a", "text": "x"]]])
        var first = app.newFlow(name: "Morning", body: body)
        #expect(app.newFlow(name: "morning", body: body).name == "morning 2")
        let caller = app.newFlow(name: "Caller", body: try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "c", "call_flow": "Morning"], ["id": "r", "run_flow": "morning"]]]))
        try app.rename(&first, to: "Sunrise")
        app.store.save(first)
        let now = try #require(app.store.flow(caller.id))
        #expect(now.draft.step("c").map { if case .call("Sunrise", _) = $0.kind { true } else { false } } == true)
        #expect(now.draft.step("r")?.kind == .flow("Sunrise"))
        #expect(throws: Problem.self) { try app.rename(&first, to: "CALLER") }
        try app.rename(&first, to: "SUNRISE")
        #expect(first.name == "SUNRISE", "its own name in another case is fine")
    }

    @Test func aDraftsSetOffRunsWhatsOnAndCountsTowardTheRunawayStop() async throws {
        let w = try World()
        w.engine.runawayLimit = 3
        var a = try w.flow([["id": "t", "text": "on"], ["id": "b", "run_flow": "B"]])
        a.name = "A"
        a.draft = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "t", "text": "unsaved"]]])
        w.store.save(a)
        var b = try w.flow([["id": "a", "run_flow": "A"]])
        b.name = "B"
        w.store.save(b)
        _ = try #require(w.engine.start(try w.flow([["id": "go", "run_flow": "A"]], state: .draft), mode: .once, why: "t"))
        await w.quiet()
        let runs = w.store.runs(of: a.id)
        #expect(!runs.isEmpty)
        #expect(runs.allSatisfy { $0.body == a.live }, "what's on, not its draft")
        #expect(runs.count <= 4, "the loop ends")
        #expect(w.store.flow(a.id)?.state == .paused || w.store.flow(b.id)?.state == .paused)
    }

    @Test func endingThePlanStopsWhatsUnderWay() async throws {
        let w = try World()
        let flow = try w.flow([["id": "w", "wait_minutes": 60], ["id": "a", "ai": "Write"]])
        let run = try #require(w.engine.start(flow, mode: .live, why: "t"))
        await w.quiet()
        w.engine.planEnded(flow.id)
        await w.quiet()
        #expect(w.store.run(run.id)?.status == .stopped)
        #expect(w.host.written.isEmpty)
    }

    @Test func anUnclearResumeDoesntMakeASecondWatch() async throws {
        let w = try World()
        var flow = try w.flow([["id": "a", "do": "reads.it"]], trigger: ["type": "watch", "kind": "url_change", "target": "https://x.example"], state: .paused)
        flow.watchTitle = "Test · Sideflow"
        w.store.save(flow)
        w.host.answers["watch.resume"] = [Actions.Outcome(status: .lost, text: "")]
        w.engine.resume(flow.id)
        await w.quiet()
        #expect(!w.host.calls.contains { $0.tool == "watch.create" })
        #expect(w.store.flow(flow.id)?.state == .on)
    }

    @Test func aFlowThatStopsBeingAWatchTakesItsWatchWithIt() async throws {
        let w = try World()
        var flow = try w.flow([["id": "a", "do": "reads.it"]], trigger: ["type": "watch", "kind": "url_change", "target": "https://x.example"])
        flow.watchTitle = "Test · Sideflow"
        flow.draft = try FlowCodec.body(["trigger": ["type": "schedule", "every_minutes": 60], "steps": [["id": "a", "do": "reads.it"]]])
        w.store.save(flow)
        #expect(w.engine.livePlan(flow).steps.contains { $0.tool == "watch.stop" }, "on the card")
        w.engine.turnOn(flow.id)
        await w.quiet()
        #expect(w.host.calls.contains { $0.tool == "watch.stop" })
        #expect(w.store.flow(flow.id)?.watchTitle == nil)
    }
}

/// What reading those found in turn.
@MainActor @Suite(.serialized) struct SideflowFourthReadTests {
    typealias World = SideflowTests.World

    @Test func aDraftsSetOffNeverQueuesARunThatAsksNobody() async throws {
        let w = try World()
        w.host.hold = "reads.it"
        var target = try w.flow([["id": "a", "do": "reads.it"]])
        target.name = "T"
        target.live?.overlap = .one_more
        w.store.save(target)
        _ = try #require(w.engine.start(target, mode: .live, why: "busy"))
        await w.quiet()
        let draft = try w.flow([["id": "go", "run_flow": "T"]], state: .draft)
        let run = await w.settled(w.engine.start(draft, mode: .once, why: "t"))
        #expect(run?.status == .done)
        w.host.hold = nil
        #expect(w.engine.queuedCount(target.id) == 0)
    }

    @Test func aWatchStopThatDidntWorkKeepsTheName() async throws {
        let w = try World()
        var flow = try w.flow([["id": "a", "do": "reads.it"]], trigger: ["type": "watch", "kind": "url_change", "target": "https://x.example"])
        flow.watchTitle = "Test · Sideflow"
        flow.draft = try FlowCodec.body(["trigger": ["type": "schedule", "every_minutes": 60], "steps": [["id": "a", "do": "reads.it"]]])
        w.store.save(flow)
        w.engine.busyPause = 0
        w.host.answers["watch.stop"] = [Actions.Outcome(status: .busy, text: ""), Actions.Outcome(status: .busy, text: "")]
        w.engine.turnOn(flow.id)
        await w.quiet()
        #expect(w.host.calls.filter { $0.tool == "watch.stop" }.count == 2, "it waited once")
        #expect(w.store.flow(flow.id)?.watchTitle == "Test · Sideflow", "still the way to reach it")
        #expect(w.store.flow(flow.id)?.state == .paused, "and a way out on the page")
    }

    @Test func aResumeNobodyAnsweredMakesNoSecondWatch() async throws {
        for status in [Actions.Outcome.Status.denied, .unanswered, .lost, .failed, .error] {
            let w = try World()
            var flow = try w.flow([["id": "a", "do": "reads.it"]], trigger: ["type": "watch", "kind": "url_change", "target": "https://x.example"], state: .paused)
            flow.watchTitle = "Test · Sideflow"
            w.store.save(flow)
            w.host.answers["watch.resume"] = [Actions.Outcome(status: status, text: "")]
            w.engine.resume(flow.id)
            await w.quiet()
            #expect(!w.host.calls.contains { $0.tool == "watch.create" }, "\(status)")
            #expect(w.store.flow(flow.id)?.startProblem != nil, "\(status)")
        }
    }

    @Test func endingAPlanStopsItsFlowWhereverItsRunning() async throws {
        let w = try World()
        var called = try w.flow([["id": "w", "wait_minutes": 60], ["id": "ai", "ai": "Write"]])
        called.name = "Called"
        w.store.save(called)
        let caller = try #require(w.engine.start(try w.flow([["id": "c", "call_flow": "Called"]]), mode: .live, why: "t"))
        await w.quiet()
        let child = try #require(w.store.runs(of: called.id).first)
        w.engine.planEnded(called.id)
        await w.quiet()
        #expect(w.store.run(child.id)?.status == .stopped)
        #expect(w.store.run(caller.id)?.status != .waiting, "and whoever waited for it hears")
        #expect(w.host.written.isEmpty)
    }

    @Test func aRenameCarriesARunUnderWay() async throws {
        let w = try World()
        let app = App(folder: w.folder.appendingPathComponent("app"))
        app.engine.host = w.host
        let body = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "a", "text": "x"]]])
        var target = app.newFlow(name: "Report", body: body)
        target.live = body
        target.state = .on
        app.store.save(target)
        var caller = app.newFlow(name: "Caller", body: try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "w", "wait_minutes": 5], ["id": "c", "call_flow": "Report"]]]))
        caller.live = caller.draft
        caller.state = .on
        app.store.save(caller)
        let run = try #require(app.engine.start(caller, mode: .live, why: "t"))
        await w.quiet(app.store)
        try app.rename(&target, to: "Daily")
        app.store.save(target)
        #expect(app.store.run(run.id)?.body.step("c").map { if case .call("Daily", _) = $0.kind { true } else { false } } == true)
    }

    @Test func oneOfTwoWithTheSameNameRewritesNothing() throws {
        let w = try World()
        let store = w.store
        let body = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "a", "text": "x"]]])
        let now = Date()
        for (id, name) in [("one", "Report"), ("two", "report")] { store.save(Flow(id: id, name: name, draft: body, createdAt: now, updatedAt: now)) }
        let app = App(folder: w.folder)
        var first = try #require(app.store.flow("one"))
        let caller = app.newFlow(name: "Caller", body: try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "c", "run_flow": "report"]]]))
        try app.rename(&first, to: "Daily")
        #expect(app.store.flow(caller.id)?.draft.step("c")?.kind == .flow("report"), "it could have meant either")
    }

    @Test func aRunWhoseFlowCantBeReadWaitsForItNotEndsWithoutIt() async throws {
        let w = try World()
        let flow = try w.flow([["id": "a", "wait_minutes": 60], ["id": "b", "do": "changes.it", "with": ["text": "x"]]])
        let run = try #require(w.engine.start(flow, mode: .live, why: "t"))
        await w.quiet()
        let file = w.folder.appendingPathComponent("flows.json")
        let good = try Data(contentsOf: file)
        // The same flow, in a form this version can't read.
        var list = try #require(try JSONSerialization.jsonObject(with: good) as? [[String: Any]])
        list[0]["draft"] = ["trigger": ["type": "from_the_future"], "steps": []]
        try JSONSerialization.data(withJSONObject: list).write(to: file)
        w.restart()
        w.engine.recover()
        w.now = w.now.addingTimeInterval(7200)
        w.engine.tick()
        await w.quiet()
        #expect(w.store.run(run.id)?.status == .waiting, "not ended, not run")
        #expect(w.host.calls.isEmpty)
        try good.write(to: file)
        w.restart()
        w.engine.recover()
        w.engine.tick()
        await w.quiet()
        #expect(w.store.run(run.id)?.status == .done, "and it comes back when the file does")
    }

    @Test func aFlowsFileThatWontOpenRunsNothing() async throws {
        let w = try World()
        let flow = try w.flow([["id": "a", "wait_minutes": 60], ["id": "b", "do": "changes.it", "with": ["text": "x"]]])
        let run = try #require(w.engine.start(flow, mode: .live, why: "t"))
        await w.quiet()
        let file = w.folder.appendingPathComponent("flows.json")
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: file.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: file.path) }
        w.restart()
        w.engine.recover()
        w.now = w.now.addingTimeInterval(7200)
        w.engine.tick()
        await w.quiet()
        #expect(w.store.run(run.id)?.status == .waiting)
        #expect(w.host.calls.isEmpty)
    }

    @Test func aFlowWithAnAIStepAndNoPlanBehindItAsksToo() async throws {
        let w = try World()
        let mixed = try w.flow([["id": "a", "do": "reads.it"], ["id": "b", "ai": "Write {{a}}"]], trigger: ["type": "schedule", "every_minutes": 60])
        let plain = try w.flow([["id": "a", "do": "reads.it"]], trigger: ["type": "schedule", "every_minutes": 60])
        let waiting = try w.flow([["id": "w", "wait_minutes": 60], ["id": "b", "ai": "Write"]], trigger: ["type": "schedule", "every_minutes": 60])
        let run = try #require(w.engine.start(waiting, mode: .live, why: "t"))
        await w.quiet()
        w.engine.pauseWhatNobodyRead()
        await w.quiet()
        #expect(w.store.flow(mixed.id)?.state == .paused)
        #expect(w.store.flow(plain.id)?.state == .on)
        #expect(w.store.run(run.id)?.status == .stopped, "what's under way doesn't carry on without it")
    }

    @Test func aSetOffFromADraftThatFailsIsSaid() async throws {
        let w = try World()
        w.host.answers["changes.it"] = [Actions.Outcome(status: .error, text: "broken")]
        var target = try w.flow([["id": "a", "do": "changes.it", "with": ["text": "x"]]])
        target.name = "Other"
        w.store.save(target)
        let draft = try w.flow([["id": "go", "run_flow": "Other"]], state: .draft)
        _ = await w.settled(w.engine.start(draft, mode: .once, why: "t"))
        await w.quiet()
        #expect(w.host.notices.contains { $0.title.contains("Other") })
    }

    @Test func practiceSaysWhenItCouldntRunForReal() async throws {
        let w = try World()
        var target = try w.flow([["id": "a", "text": "x"]], state: .paused)
        target.name = "Sleeping"
        w.store.save(target)
        let flow = try w.flow([["id": "go", "run_flow": "Sleeping"]], state: .draft)
        let run = await w.settled(w.engine.start(flow, mode: .practice, why: "t"))
        #expect(run?.record(of: "go")?.note?.contains("has to be on") == true)
    }

    @Test func oneLineTooManyIsSaidBeforeTheCard() async throws {
        let w = try World()
        let steps: [[String: Any]] = (0..<Plans.maxSteps).map { ["id": "s\($0)", "do": "reads.it", "with": ["q": "\($0)"]] }
        var flow = try w.flow(steps, state: .paused)
        flow.watchTitle = "Old"
        w.store.save(flow)
        w.engine.turnOn(flow.id)
        await w.quiet()
        #expect(w.host.plans.isEmpty)
        #expect(w.store.flow(flow.id)?.startProblem != nil)
    }
}

/// What the fourth read found.
@MainActor @Suite(.serialized) struct SideflowFifthPassTests {
    typealias World = SideflowTests.World

    private func damaged(_ w: World) throws {
        try Data("this isn't a list".utf8).write(to: w.folder.appendingPathComponent("flows.json"))
        w.restart()
    }

    @Test func afterADamagedFileNewFlowsRunAsAnyWould() async throws {
        let w = try World()
        try damaged(w)
        #expect(w.store.damagedFile != nil)
        let flow = try w.flow([["id": "a", "text": "x"]], trigger: ["type": "schedule", "every_minutes": 60])
        let run = await w.settled(w.engine.start(flow, mode: .live, why: "t"))
        #expect(run?.status == .done, "not stuck running for the rest of the launch")
        #expect(!w.engine.isRunning(flow.id))
        w.now = w.now.addingTimeInterval(61 * 60)
        w.engine.tick()
        await w.quiet()
        #expect(w.store.runs(of: flow.id).count == 2, "its schedule fires too")
    }

    @Test func runsOfFlowsInADamagedFileWaitForItAcrossLaunches() async throws {
        let w = try World()
        let flow = try w.flow([["id": "a", "wait_minutes": 60], ["id": "b", "do": "changes.it", "with": ["text": "x"]]])
        let run = try #require(w.engine.start(flow, mode: .live, why: "t"))
        await w.quiet()
        let good = try Data(contentsOf: w.folder.appendingPathComponent("flows.json"))
        try damaged(w)
        w.engine.recover()
        w.now = w.now.addingTimeInterval(7200)
        w.engine.tick()
        await w.quiet()
        #expect(w.store.run(run.id)?.status == .waiting)
        // Launched again, with the file still aside: it hasn't turned into "gone".
        _ = try w.flow([["id": "n", "text": "new"]])
        w.restart()
        w.engine.recover()
        await w.quiet()
        #expect(w.store.run(run.id)?.status == .waiting)
        #expect(w.host.calls.isEmpty)
        // Put back, it picks up.
        var list = try #require(try JSONSerialization.jsonObject(with: good) as? [[String: Any]])
        list.append(contentsOf: try JSONSerialization.jsonObject(with: Data(contentsOf: w.folder.appendingPathComponent("flows.json"))) as? [[String: Any]] ?? [])
        try JSONSerialization.data(withJSONObject: list).write(to: w.folder.appendingPathComponent("flows.json"))
        w.restart()
        w.engine.recover()
        w.engine.tick()
        await w.quiet()
        #expect(w.store.run(run.id)?.status == .done)
    }

    @Test func withTheFileHeldNothingStarts() throws {
        let w = try World()
        let file = w.folder.appendingPathComponent("flows.json")
        try Data("mine".utf8).write(to: file)
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: file.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: file.path) }
        w.restart()
        let flow = try w.flow([["id": "a", "text": "x"]], trigger: ["type": "schedule", "every_minutes": 60])
        #expect(w.engine.start(flow, mode: .live, why: "t") == nil)
        #expect(!w.engine.isRunning(flow.id))
        #expect(w.store.runs(of: flow.id).isEmpty)
    }

    @Test func aHeldBackRunIsntMovedByAnyoneAndKeepsItsReason() async throws {
        let w = try World()
        let flow = try w.flow([["id": "f", "form": ["title": "Q", "fields": [["name": "a", "kind": "text"]]]], ["id": "b", "text": "x"]])
        let run = try #require(w.engine.start(flow, mode: .live, why: "t"))
        await w.quiet()
        let file = w.folder.appendingPathComponent("flows.json")
        var list = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [[String: Any]])
        list[0]["draft"] = ["trigger": ["type": "from_the_future"], "steps": []]
        try JSONSerialization.data(withJSONObject: list).write(to: file)
        w.restart()
        #expect(throws: Problem.self) { try w.engine.answer(run: run.id, form: ["a": .string("x")]) }
        #expect(w.store.run(run.id)?.status == .waiting)
        #expect(w.store.run(run.id)?.form != nil)
    }

    @Test func aStopThatFailedOnApplyMakesNoSecondWatch() async throws {
        for status in [Actions.Outcome.Status.lost, .failed, .denied] {
            let w = try World()
            let trigger: [String: Any] = ["type": "watch", "kind": "url_change", "target": "https://x.example"]
            var flow = try w.flow([["id": "a", "do": "reads.it"]], trigger: trigger)
            flow.watchTitle = "Test · Sideflow"
            flow.draft = try FlowCodec.body(["trigger": ["type": "watch", "kind": "url_change", "target": "https://y.example"], "steps": [["id": "a", "do": "reads.it"]]])
            w.store.save(flow)
            w.host.answers["watch.stop"] = [Actions.Outcome(status: status, text: "")]
            w.engine.turnOn(flow.id)
            await w.quiet()
            #expect(!w.host.calls.contains { $0.tool == "watch.create" }, "\(status)")
            let after = try #require(w.store.flow(flow.id))
            #expect(after.state == .paused)
            #expect(after.startProblem != nil)
            #expect(after.watchTitle == "Test · Sideflow")
        }
    }

    @Test func aBusyStopOnApplyWaitsAndGoesOn() async throws {
        let w = try World()
        w.engine.busyPause = 0
        var flow = try w.flow([["id": "a", "do": "reads.it"]], trigger: ["type": "watch", "kind": "url_change", "target": "https://x.example"])
        flow.watchTitle = "Test · Sideflow"
        flow.draft = try FlowCodec.body(["trigger": ["type": "watch", "kind": "url_change", "target": "https://y.example"], "steps": [["id": "a", "do": "reads.it"]]])
        w.store.save(flow)
        w.host.answers["watch.stop"] = [Actions.Outcome(status: .busy, text: "")]
        w.engine.turnOn(flow.id)
        await w.quiet()
        #expect(w.host.calls.filter { $0.tool == "watch.stop" }.count == 2)
        #expect(w.host.calls.filter { $0.tool == "watch.create" }.count == 1)
        #expect(w.store.flow(flow.id)?.state == .on)
    }

    @Test func aWatchThatsAlreadyGoneLetsTheNameGo() async throws {
        let w = try World()
        var flow = try w.flow([["id": "a", "do": "reads.it"]], trigger: ["type": "watch", "kind": "url_change", "target": "https://x.example"])
        flow.watchTitle = "Test · Sideflow"
        flow.draft = try FlowCodec.body(["trigger": ["type": "schedule", "every_minutes": 60], "steps": [["id": "a", "do": "reads.it"]]])
        w.store.save(flow)
        w.host.answers["watch.stop"] = [Actions.Outcome(status: .failed, text: "gone", notFound: true)]
        w.engine.turnOn(flow.id)
        await w.quiet()
        #expect(w.store.flow(flow.id)?.watchTitle == nil)
        #expect(w.store.flow(flow.id)?.startProblem == nil)
    }

    @Test func anOldWatchNoLongerSetsOffAFlowThatStoppedBeingOne() async throws {
        let w = try World()
        var flow = try w.flow([["id": "a", "text": "x"]], trigger: ["type": "schedule", "every_minutes": 60])
        flow.watchTitle = "Test · Sideflow"
        w.store.save(flow)
        w.engine.watchFired(title: "Test · Sideflow", summary: "changed")
        await w.quiet()
        #expect(w.store.runs(of: flow.id).isEmpty)
    }

    @Test func aResumeThatFoundNothingMakesItAgain() async throws {
        let w = try World()
        var flow = try w.flow([["id": "a", "do": "reads.it"]], trigger: ["type": "watch", "kind": "url_change", "target": "https://x.example"], state: .paused)
        flow.watchTitle = "Test · Sideflow"
        w.store.save(flow)
        w.host.answers["watch.resume"] = [Actions.Outcome(status: .failed, text: "gone", notFound: true)]
        w.engine.resume(flow.id)
        await w.quiet()
        #expect(w.host.calls.filter { $0.tool == "watch.create" }.count == 1)
        #expect(w.store.flow(flow.id)?.state == .on)
    }

    @Test func aResumeNothingCameOfSaysPausedNotOn() async throws {
        for status in [Actions.Outcome.Status.denied, .unanswered] {
            let w = try World()
            var flow = try w.flow([["id": "a", "do": "reads.it"]], trigger: ["type": "watch", "kind": "url_change", "target": "https://x.example"], state: .paused)
            flow.watchTitle = "Test · Sideflow"
            w.store.save(flow)
            w.host.answers["watch.resume"] = [Actions.Outcome(status: status, text: "No")]
            w.engine.resume(flow.id)
            await w.quiet()
            #expect(w.store.flow(flow.id)?.state == .paused, "\(status)")
        }
    }

    @Test func endingAPlanLeavesPracticeAloneAndStopsWhatRanTheEndedBody() async throws {
        let w = try World()
        let flow = try w.flow([["id": "w", "wait_minutes": 60]])
        // A practice's wait is pretended, so its stop would show in nothing: hold it on a form it pretends too, and look at what's stopped.
        var practice = Run(id: "p", flow: flow.id, flowName: flow.name, mode: .practice, status: .waiting, why: "t", startedAt: w.now, body: flow.draft)
        practice.resumeAt = w.now.addingTimeInterval(9000)
        w.store.save(practice)
        var once = Run(id: "o", flow: flow.id, flowName: flow.name, mode: .once, status: .waiting, why: "t", startedAt: w.now, body: flow.running)
        once.resumeAt = w.now.addingTimeInterval(9000)
        w.store.save(once)
        var older = Run(id: "s", flow: flow.id, flowName: flow.name, mode: .once, status: .waiting, why: "t", startedAt: w.now, body: try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "z", "text": "old"]]]))
        older.setOff = true
        older.resumeAt = w.now.addingTimeInterval(9000)
        w.store.save(older)
        w.engine.planEnded(flow.id)
        await w.quiet()
        #expect(w.store.run("p")?.status == .waiting, "practice changes nothing")
        #expect(w.store.run("o")?.status == .stopped, "it ran the body they just ended")
        #expect(w.store.run("s")?.status == .stopped, "set off, on an older one")
    }

    @Test func aRenameReachesARunInTheMiddleOfAStep() async throws {
        let w = try World()
        let app = App(folder: w.folder.appendingPathComponent("app"))
        app.engine.host = w.host
        app.catalog.use(Actions.Listing(tools: [Actions.Tool(name: "reads.it", title: "Read it", mutates: false, readsOnly: true)]))
        let plain = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "a", "text": "x"]]])
        var target = app.newFlow(name: "Report", body: plain)
        target.live = plain
        target.state = .on
        app.store.save(target)
        var caller = app.newFlow(name: "Caller", body: try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "r", "do": "reads.it"], ["id": "c", "run_flow": "Report"]]]))
        caller.live = caller.draft
        caller.state = .on
        app.store.save(caller)
        w.host.hold = "reads.it"
        w.host.honoursCancel = true
        w.host.releaseQuietly = true
        let run = try #require(app.engine.start(caller, mode: .live, why: "t"))
        await w.quiet(app.store)
        try app.rename(&target, to: "Daily")
        app.store.save(target)
        // Someone takes the old name, and the walk comes back from its step.
        var impostor = app.newFlow(name: "Report", body: plain)
        impostor.live = plain
        impostor.state = .on
        app.store.save(impostor)
        w.host.cancel(run: run.id)
        await w.quiet(app.store)
        #expect(app.store.run(run.id)?.status == .done, "\(app.store.run(run.id)?.problem ?? "")")
        #expect(app.store.runs(of: target.id).count == 1, "the flow it meant")
        #expect(app.store.runs(of: impostor.id).isEmpty, "not the one that took its name")
    }

    @Test func aFlowWithAPlanBehindItStaysOn() async throws {
        let w = try World()
        let flow = try w.flow([["id": "b", "ai": "Write"]], trigger: ["type": "schedule", "every_minutes": 60])
        w.catalog.use(Actions.Listing(tools: [], plans: [Plans.Standing(id: flow.planId, title: flow.name, standing: [])]))
        w.engine.pauseWhatNobodyRead()
        await w.quiet()
        #expect(w.store.flow(flow.id)?.state == .on)
    }

    @Test func aDraftsSetOffThatFoundItBusySaysItDidntStart() async throws {
        let w = try World()
        w.host.hold = "reads.it"
        var target = try w.flow([["id": "a", "do": "reads.it"]])
        target.name = "T"
        w.store.save(target)
        _ = try #require(w.engine.start(target, mode: .live, why: "busy"))
        await w.quiet()
        let run = await w.settled(w.engine.start(try w.flow([["id": "go", "run_flow": "T"]], state: .draft), mode: .once, why: "t"))
        #expect(run?.record(of: "go")?.summary.contains("didn't start") == true)
    }
}

/// What the fifth read found, and the one routine that replaced what it found it in.
@MainActor @Suite(.serialized) struct SideflowWatchSyncTests {
    typealias World = SideflowTests.World
    static let x: [String: Any] = ["type": "watch", "kind": "url_change", "target": "https://x.example"]
    static let y: [String: Any] = ["type": "watch", "kind": "url_change", "target": "https://y.example"]

    private func applied(_ w: World, from: [String: Any] = x, to: [String: Any]) throws -> Flow {
        var flow = try w.flow([["id": "a", "do": "reads.it"]], trigger: from)
        flow.watchTitle = "Test · Sideflow"
        flow.draft = try FlowCodec.body(["trigger": to, "steps": [["id": "a", "do": "reads.it"]]])
        w.store.save(flow)
        return flow
    }

    @Test func resumingAfterAFailedStopTriesAgainAndEndsWithTheNewWatch() async throws {
        let w = try World()
        let flow = try applied(w, to: Self.y)
        w.host.answers["watch.stop"] = [Actions.Outcome(status: .failed, text: "no")]
        w.engine.turnOn(flow.id)
        await w.quiet()
        let held = try #require(w.store.flow(flow.id))
        #expect(held.state == .paused)
        #expect(!held.hasChanges, "the only way out on the page is Resume")
        w.engine.resume(flow.id)
        await w.quiet()
        let after = try #require(w.store.flow(flow.id))
        #expect(after.state == .on)
        #expect(after.startProblem == nil)
        #expect(!w.host.calls.contains { $0.tool == "watch.resume" }, "not the old one brought back")
        #expect(w.host.calls.filter { $0.tool == "watch.stop" }.count == 2)
        let made = try #require(w.host.calls.first { $0.tool == "watch.create" })
        #expect(made.input["target"] as? String == "https://y.example")
    }

    @Test func movingAwayFromAWatchHasAWayOutToo() async throws {
        let w = try World()
        let flow = try applied(w, to: ["type": "schedule", "every_minutes": 60])
        w.host.answers["watch.stop"] = [Actions.Outcome(status: .failed, text: "no")]
        w.engine.turnOn(flow.id)
        await w.quiet()
        #expect(w.store.flow(flow.id)?.state == .paused)
        w.engine.resume(flow.id)
        await w.quiet()
        let after = try #require(w.store.flow(flow.id))
        #expect(after.state == .on)
        #expect(after.watchTitle == nil)
    }

    @Test func deletingDuringTheWaitDoesntBringTheFlowBackOrLeaveAWatch() async throws {
        let w = try World()
        w.engine.busyPause = 0.2
        let flow = try applied(w, to: Self.y)
        w.host.answers["watch.stop"] = [Actions.Outcome(status: .busy, text: "")]
        w.engine.turnOn(flow.id)
        try await Task.sleep(for: .milliseconds(60))
        w.engine.delete(flow.id)
        try await Task.sleep(for: .milliseconds(500))
        await w.quiet()
        #expect(w.store.flow(flow.id) == nil, "not written back")
        #expect(!w.host.calls.contains { $0.tool == "watch.create" }, "and nothing made for it")
    }

    @Test func pausingDuringTheWaitStaysPaused() async throws {
        let w = try World()
        w.engine.busyPause = 0.2
        let flow = try applied(w, to: Self.y)
        w.host.answers["watch.stop"] = [Actions.Outcome(status: .busy, text: "")]
        w.engine.turnOn(flow.id)
        try await Task.sleep(for: .milliseconds(60))
        w.engine.pause(flow.id)
        try await Task.sleep(for: .milliseconds(400))
        await w.quiet()
        #expect(w.store.flow(flow.id)?.state == .paused)
        #expect(!w.host.calls.contains { $0.tool == "watch.create" })
    }

    @Test func twoAppliesInARowEndOnTheLastOne() async throws {
        let w = try World()
        w.engine.busyPause = 0.1
        let flow = try applied(w, to: Self.y)
        w.host.answers["watch.stop"] = [Actions.Outcome(status: .busy, text: "")]
        w.engine.turnOn(flow.id)
        try await Task.sleep(for: .milliseconds(40))
        var again = try #require(w.store.flow(flow.id))
        again.draft = try FlowCodec.body(["trigger": ["type": "watch", "kind": "url_change", "target": "https://z.example"], "steps": [["id": "a", "do": "reads.it"]]])
        w.store.save(again)
        w.engine.turnOn(flow.id)
        try await Task.sleep(for: .milliseconds(400))
        await w.quiet()
        let creates = w.host.calls.filter { $0.tool == "watch.create" }
        #expect(creates.last?.input["target"] as? String == "https://z.example")
        #expect(w.store.flow(flow.id)?.watchTitle != nil)
        let stops = w.host.calls.filter { $0.tool == "watch.stop" }.count
        #expect(creates.count == 1 || stops >= 2, "never two standing")
    }

    @Test func anUnchangedApplyKeepsTheWatch() async throws {
        let w = try World()
        var flow = try w.flow([["id": "a", "do": "reads.it"]], trigger: Self.x, state: .draft)
        w.engine.turnOn(flow.id)
        await w.quiet()
        flow = try #require(w.store.flow(flow.id))
        let title = try #require(flow.watchTitle)
        w.host.calls.removeAll()
        flow.draft = try FlowCodec.body(["trigger": Self.x, "steps": [["id": "a", "do": "reads.it"], ["id": "b", "do": "reads.it"]]])
        w.store.save(flow)
        w.engine.turnOn(flow.id)
        await w.quiet()
        #expect(!w.host.calls.contains { $0.tool == "watch.stop" || $0.tool == "watch.create" }, "same address, same watch")
        #expect(w.store.flow(flow.id)?.watchTitle == title)
    }

    @Test func aFlowFromBeforeThisKeepsItsWatchOnResume() async throws {
        let w = try World()
        var flow = try w.flow([["id": "a", "do": "reads.it"]], trigger: Self.x, state: .paused)
        flow.watchTitle = "Test · Sideflow"
        w.store.save(flow)
        w.engine.resume(flow.id)
        await w.quiet()
        #expect(w.host.calls.map(\.tool) == ["watch.resume"], "nothing recorded, so what it has is what it was given")
    }

    @Test func aSecondBusyOnResumeSaysPaused() async throws {
        let w = try World()
        w.engine.busyPause = 0
        var flow = try w.flow([["id": "a", "do": "reads.it"]], trigger: Self.x, state: .paused)
        flow.watchTitle = "Test · Sideflow"
        w.store.save(flow)
        w.host.answers["watch.resume"] = [Actions.Outcome(status: .busy, text: ""), Actions.Outcome(status: .busy, text: "")]
        w.engine.resume(flow.id)
        await w.quiet()
        #expect(w.store.flow(flow.id)?.state == .paused)
        #expect(!w.host.calls.contains { $0.tool == "watch.create" })
    }
}

@MainActor @Suite(.serialized) struct SideflowRunBodyTests {
    typealias World = SideflowTests.World

    private func on(_ app: App, _ name: String, _ steps: [[String: Any]]) throws -> Flow {
        var flow = app.newFlow(name: name, body: try FlowCodec.body(["trigger": ["type": "manual"], "steps": steps]))
        flow.live = flow.draft
        flow.state = .on
        app.store.save(flow)
        return flow
    }

    @Test func aChainOfRenamesDoesntSendARunToTheWrongFlow() async throws {
        let w = try World()
        let app = App(folder: w.folder.appendingPathComponent("app"))
        app.engine.host = w.host
        var other = try on(app, "B", [["id": "a", "text": "other"]])
        var target = try on(app, "A", [["id": "a", "text": "target"]])
        let caller = try on(app, "Caller", [["id": "w", "wait_minutes": 5], ["id": "c", "run_flow": "A"]])
        let run = try #require(app.engine.start(caller, mode: .live, why: "t"))
        await w.quiet(app.store)
        try app.rename(&other, to: "C")
        app.store.save(other)
        try app.rename(&target, to: "B")
        app.store.save(target)
        app.engine.clock = { Date().addingTimeInterval(3600) }
        app.engine.tick()
        await w.quiet(app.store)
        #expect(app.store.run(run.id)?.status == .done)
        #expect(app.store.runs(of: target.id).count == 1)
        #expect(app.store.runs(of: other.id).isEmpty)
    }

    @Test func aWalksSaveDoesntPutTheOldNameBackAndARestartKeepsTheNew() async throws {
        let w = try World()
        let app = App(folder: w.folder.appendingPathComponent("app"))
        app.engine.host = w.host
        app.catalog.use(Actions.Listing(tools: [Actions.Tool(name: "reads.it", title: "Read it", mutates: false, readsOnly: true)]))
        var target = try on(app, "Report", [["id": "a", "text": "x"]])
        let caller = try on(app, "Caller", [["id": "r", "do": "reads.it"], ["id": "w", "wait_minutes": 5], ["id": "c", "call_flow": "Report"]])
        w.host.hold = "reads.it"
        w.host.honoursCancel = true
        w.host.releaseQuietly = true
        let run = try #require(app.engine.start(caller, mode: .live, why: "t"))
        await w.quiet(app.store)
        try app.rename(&target, to: "Daily")
        app.store.save(target)
        w.host.cancel(run: run.id)
        await w.quiet(app.store)
        #expect(app.store.run(run.id)?.status == .waiting)
        let again = App(folder: w.folder.appendingPathComponent("app"))
        #expect(again.store.run(run.id)?.body.step("c").map { if case .call("Daily", _) = $0.kind { true } else { false } } == true)
    }

    @Test func aLanesFlowNameFollowsARenameToo() async throws {
        let w = try World()
        let app = App(folder: w.folder.appendingPathComponent("app"))
        app.engine.host = w.host
        app.catalog.use(Actions.Listing(tools: [Actions.Tool(name: "reads.it", title: "Read it", mutates: false, readsOnly: true)]))
        var target = try on(app, "Report", [["id": "a", "text": "x"]])
        let caller = try on(app, "Caller", [["id": "r", "do": "reads.it"], ["id": "both", "parallel": [["name": "a", "steps": [["id": "c", "run_flow": "Report"]]], ["name": "b", "steps": [["id": "t", "text": "b"]]]]]])
        w.host.hold = "reads.it"
        w.host.honoursCancel = true
        w.host.releaseQuietly = true
        let run = try #require(app.engine.start(caller, mode: .live, why: "t"))
        await w.quiet(app.store)
        try app.rename(&target, to: "Daily")
        app.store.save(target)
        var impostor = app.newFlow(name: "Report", body: try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "a", "text": "no"]]]))
        impostor.live = impostor.draft
        impostor.state = .on
        app.store.save(impostor)
        w.host.cancel(run: run.id)
        await w.quiet(app.store)
        #expect(app.store.runs(of: target.id).count == 1)
        #expect(app.store.runs(of: impostor.id).isEmpty)
    }

    @Test func stoppingAHeldBackRunEndsIt() async throws {
        let w = try World()
        w.host.hold = "reads.it"
        let flow = try w.flow([["id": "a", "do": "reads.it"]])
        let run = try #require(w.engine.start(flow, mode: .live, why: "t"))
        await w.quiet()
        let file = w.folder.appendingPathComponent("flows.json")
        var list = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [[String: Any]])
        list[0]["draft"] = ["trigger": ["type": "from_the_future"], "steps": []]
        try JSONSerialization.data(withJSONObject: list).write(to: file)
        w.restart()
        #expect(w.store.heldBackRuns.count == 1)
        w.engine.stop(run: run.id)
        #expect(w.store.run(run.id)?.status == .stopped)
    }

    @Test func thePersonCanLetHeldRunsGoAndTheyHearWhy() async throws {
        let w = try World()
        let flow = try w.flow([["id": "a", "wait_minutes": 60]])
        let run = try #require(w.engine.start(flow, mode: .live, why: "t"))
        await w.quiet()
        let file = w.folder.appendingPathComponent("flows.json")
        try Data("this isn't a list".utf8).write(to: file)
        w.restart()
        w.engine.endHeldRuns()
        #expect(w.store.run(run.id)?.status == .stopped)
        #expect(w.store.heldBackRuns.isEmpty)
    }

    @Test func aHeldBackRunIgnoresTryAgainAndWhatItWaitsFor() async throws {
        let w = try World()
        let flow = try w.flow([["id": "wf", "wait_for": ["event": "note.saved", "minutes": 60]], ["id": "b", "text": "x"]])
        let run = try #require(w.engine.start(flow, mode: .live, why: "t"))
        await w.quiet()
        let file = w.folder.appendingPathComponent("flows.json")
        var list = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [[String: Any]])
        list[0]["draft"] = ["trigger": ["type": "from_the_future"], "steps": []]
        try JSONSerialization.data(withJSONObject: list).write(to: file)
        w.restart()
        w.engine.happened(name: "note.saved", title: "x", detail: nil)
        w.engine.proceed(run.id, .carry_on)
        await w.quiet()
        let after = try #require(w.store.run(run.id))
        #expect(after.status == .waiting)
        #expect(after.record(of: "wf")?.status == .waiting)
    }

    @Test func nobodyReadIsLookedForBeforeAnythingGoesOn() async throws {
        let w = try World()
        let app = App(folder: w.folder.appendingPathComponent("app"))
        app.engine.host = w.host
        app.catalog.use(Actions.Listing(tools: []))
        var flow = app.newFlow(name: "F", body: try FlowCodec.body(["trigger": ["type": "schedule", "every_minutes": 60], "steps": [["id": "b", "ai": "Write"]]]))
        flow.live = flow.draft
        flow.state = .on
        app.store.save(flow)
        var run = Run(id: "r", flow: flow.id, flowName: flow.name, mode: .live, status: .running, why: "t", startedAt: Date(), body: flow.draft)
        run.pc = 0
        app.store.save(run)
        app.firstLook()
        await w.quiet(app.store)
        #expect(app.store.flow(flow.id)?.state == .paused)
        #expect(w.host.written.isEmpty, "it doesn't get one more step first")
        #expect(app.store.run("r")?.status == .stopped)
    }

    @Test func whatACalledFlowAnswersIsItsLastResultThatExists() async throws {
        let w = try World()
        let flow = try w.flow([["id": "l", "text": "a\nb"], ["id": "each", "for_each": "{{l}}", "steps": [["id": "t", "text": "{{item}}"]]]])
        let run = await w.settled(w.engine.start(flow, mode: .live, why: "t"))
        #expect(run?.answer != .null, "a loop's own result, not its insides")
    }
}

@MainActor @Suite(.serialized) struct SideflowJobTests {
    typealias World = SideflowTests.World

    @Test func stopTellsATheToolAndTheRunSaysItMayHaveHappened() async throws {
        let w = try World()
        w.host.hold = "changes.it"
        w.host.honoursCancel = true
        let flow = try w.flow([["id": "a", "do": "changes.it", "with": ["text": "x"]], ["id": "b", "do": "reads.it"]])
        let run = try #require(w.engine.start(flow, mode: .live, why: "t"))
        await w.quiet()
        #expect(w.store.run(run.id)?.status == .running)
        w.engine.stop(run: run.id)
        #expect(w.store.run(run.id)?.status == .running, "stopping until it answers: never a label saying it already has")
        await w.quiet()
        let done = try #require(w.store.run(run.id))
        #expect(done.status == .stopped)
        #expect(done.record(of: "a")?.status == .unknown, "it was told, which isn't proof")
        #expect(!w.host.calls.contains { $0.tool == "reads.it" })
        #expect(!w.engine.isRunning(flow.id))
    }

    @Test func aReadingStepStoppedDoesntTryAgain() async throws {
        let w = try World()
        w.host.hold = "reads.it"
        w.host.honoursCancel = true
        let flow = try w.flow([["id": "a", "do": "reads.it", "on_failure": "retry"], ["id": "b", "do": "changes.it", "with": ["text": "x"]]])
        let run = try #require(w.engine.start(flow, mode: .live, why: "t"))
        await w.quiet()
        w.engine.stop(run: run.id)
        await w.quiet()
        #expect(w.store.run(run.id)?.status == .stopped)
        #expect(w.store.run(run.id)?.resumeAt == nil)
        #expect(!w.host.calls.contains { $0.tool == "changes.it" })
    }

    @Test func thePageSaysHowFarAlongAndForgetsAfterwards() async throws {
        let w = try World()
        let app = App(folder: w.folder.appendingPathComponent("app"))
        app.engine.host = w.host
        app.catalog.use(Actions.Listing(tools: [Actions.Tool(name: "reads.it", title: "Read it", mutates: false, readsOnly: true)]))
        w.host.hold = "reads.it"
        w.host.honoursCancel = true
        w.host.progressWords = "two of five"
        let flow = app.newFlow(name: "F", body: try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "a", "do": "reads.it"]]]))
        let run = try #require(app.engine.start(flow, mode: .once, why: "t"))
        await w.quiet(app.store)
        #expect(app.engine.progress[run.id]?.message == "two of five")
        let page = await Pages.make(app, state: Arguments(["run": run.id]), background: false)
        #expect(String(describing: page.sent).contains("two of five"))
        app.engine.stop(run: run.id)
        await w.quiet(app.store)
        #expect(app.engine.progress[run.id] == nil)
    }
}

@MainActor @Suite(.serialized) struct SideflowTriggersTests {
    typealias World = SideflowTests.World

    private func flow(_ w: World, _ trigger: [String: Any] = ["type": "manual"], also: [[String: Any]], state: Flow.State = .on) throws -> Flow {
        let body = try FlowCodec.body(["trigger": trigger, "also_when": also, "steps": [["id": "a", "text": "x"]]])
        var made = try w.flow([["id": "a", "text": "x"]], trigger: trigger, state: state)
        made.draft = body
        if state != .draft { made.live = body }
        w.store.save(made)
        return made
    }

    @Test func itReadsBackAndRefusesWhatItCantDo() throws {
        let also: [[String: Any]] = [["type": "schedule", "every_minutes": 60], ["type": "event", "event": "note.saved"]]
        let body = try FlowCodec.body(["trigger": ["type": "manual"], "also_when": also, "steps": [["id": "a", "text": "x"]]])
        #expect(body.alsoWhen.count == 2)
        #expect(try FlowCodec.body(FlowCodec.json(body)) == body)
        #expect(throws: Problem.self) { _ = try FlowCodec.body(["trigger": ["type": "manual"], "also_when": [["type": "watch", "kind": "url_change", "target": "https://x.example"]], "steps": []]) }
        #expect(throws: Problem.self) { _ = try FlowCodec.body(["trigger": ["type": "manual"], "also_when": [["type": "manual"]], "steps": []]) }
        let many = Array(repeating: ["type": "schedule", "every_minutes": 60] as [String: Any], count: FlowBody.mostTriggers)
        #expect(throws: Problem.self) { _ = try FlowCodec.body(["trigger": ["type": "manual"], "also_when": many, "steps": []]) }
    }

    @Test func aSecondScheduleSetsItOff() async throws {
        let w = try World()
        let made = try flow(w, also: [["type": "schedule", "every_minutes": 60]])
        w.now = w.now.addingTimeInterval(61 * 60)
        w.engine.tick()
        await w.quiet()
        #expect(w.store.runs(of: made.id).count == 1)
    }

    @Test func eachEverySoOftenCountsFromItsOwnLastTime() async throws {
        let w = try World()
        let made = try flow(w, ["type": "schedule", "every_minutes": 60], also: [["type": "schedule", "every_minutes": 90]])
        w.now = w.now.addingTimeInterval(60 * 60)
        w.engine.tick()
        await w.quiet()
        #expect(w.store.runs(of: made.id).count == 1)
        #expect(Summaries.next(try #require(w.store.flow(made.id))) == w.now.addingTimeInterval(30 * 60), "the other one comes first, not an hour from now")
        w.now = w.now.addingTimeInterval(30 * 60)
        w.engine.tick()
        await w.quiet()
        #expect(w.store.runs(of: made.id).count == 2, "starting for one way doesn't put the other off")
        w.restart()
        w.now = w.now.addingTimeInterval(30 * 60)
        w.engine.tick()
        await w.quiet()
        #expect(w.store.runs(of: made.id).count == 3, "a restart remembers: the hourly one is due again, counted from its own last time")
    }

    @Test func turningOnAgainCountsEachFromThen() async throws {
        let w = try World()
        var made = try flow(w, ["type": "schedule", "every_minutes": 60], also: [["type": "schedule", "every_minutes": 90]])
        made.lastEvery = [90: w.now.addingTimeInterval(-3 * 3600)]
        w.store.save(made)
        w.engine.pause(made.id)
        w.engine.resume(made.id)
        await w.quiet()
        #expect(w.store.flow(made.id)?.state == .on)
        #expect(w.store.flow(made.id)?.lastEvery.isEmpty == true)
    }

    @Test func theCardNamesEveryWayEvenBesideALongAddress() throws {
        let w = try World()
        let long = "https://x.example/" + String(repeating: "a", count: 400)
        let also: [[String: Any]] = (1...7).map { ["type": "schedule", "every_minutes": 20 + $0] }
        let made = try flow(w, ["type": "watch", "kind": "url_change", "target": long], also: also)
        let when = w.engine.livePlan(made).when
        for n in 1...7 { #expect(when.contains(Format.integer(20 + n)), "the way read last is as much on the card as the first") }
        #expect(when.contains("https://x.example/"))
        #expect(when.count < 300)
    }

    @Test func twoDueTogetherAreOneRun() async throws {
        let w = try World()
        let made = try flow(w, ["type": "schedule", "every_minutes": 60], also: [["type": "schedule", "every_minutes": 30]])
        w.now = w.now.addingTimeInterval(61 * 60)
        w.engine.tick()
        await w.quiet()
        #expect(w.store.runs(of: made.id).count == 1)
    }

    @Test func aHappeningSetsItOffOnceHoweverManyMatch() async throws {
        let w = try World()
        let made = try flow(w, ["type": "event", "event": "note.saved"], also: [["type": "event", "event": "note.saved", "contains": "bread"]])
        w.engine.happened(name: "note.saved", title: "bread", detail: nil)
        await w.quiet()
        #expect(w.store.runs(of: made.id).count == 1)
    }

    @Test func theSameEventTwiceIsOnce() async throws {
        let w = try World()
        let made = try flow(w, ["type": "event", "event": "note.saved"], also: [])
        w.engine.happened(name: "note.saved", title: "a", detail: nil, id: "e1")
        await w.quiet()
        w.engine.happened(name: "note.saved", title: "a", detail: nil, id: "e1")
        await w.quiet()
        #expect(w.store.runs(of: made.id).count == 1)
        w.restart()
        w.engine.happened(name: "note.saved", title: "a", detail: nil, id: "e1")
        await w.quiet()
        #expect(w.store.runs(of: made.id).count == 1, "nor after a restart")
        w.engine.happened(name: "note.saved", title: "a", detail: nil, id: "e2")
        await w.quiet()
        #expect(w.store.runs(of: made.id).count == 2, "another one does")
    }

    @Test func aManualFlowWithAScheduleOnTheSideStillNeedsACardAndItSaysSo() throws {
        let w = try World()
        let made = try flow(w, also: [["type": "schedule", "every_minutes": 60]], state: .draft)
        #expect(Engine.needsCard(made.kept))
        let when = w.engine.livePlan(made).when
        #expect(when.contains(Words.trigger(.every(minutes: 60, catchUp: false))))
    }

    @Test func aBadOneOfManyIsMarkedAndNeverDue() async throws {
        let w = try World()
        var made = try flow(w, also: [["type": "schedule", "every_minutes": 60]])
        made.draft.alsoWhen = [.every(minutes: 3, catchUp: false)]
        made.live = made.draft
        w.store.save(made)
        w.restart()
        let back = try #require(w.store.flow(made.id))
        #expect(!back.draft.problems(w.catalog).isEmpty)
        w.now = w.now.addingTimeInterval(9000)
        w.engine.tick()
        await w.quiet()
        #expect(w.store.runs(of: made.id).isEmpty)
    }

    @Test func thePageAddsEditsAndRemovesThem() async throws {
        let w = try World()
        let app = App(folder: w.folder.appendingPathComponent("app"))
        let made = app.newFlow(name: "F", body: try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "a", "text": "x"]]]))
        func op(_ name: String, _ extra: [String: Any]) async throws {
            var input: [String: Any] = ["op": name, "flow": made.id]
            input.merge(extra) { _, new in new }
            _ = try await Actions_UI.handle(Arguments(input), app)
        }
        try await op("also_add", ["kind": "days"])
        try await op("also_add", ["kind": "event"])
        try await op("at", ["also": 0, "text": "18:15"])
        guard case .days(_, 18, 15, _)? = app.store.flow(made.id)?.draft.alsoWhen.first else { Issue.record("not edited"); return }
        #expect(app.store.flow(made.id)?.draft.trigger == .manual, "the first way wasn't touched")
        try await op("also_remove", ["also": 0])
        #expect(app.store.flow(made.id)?.draft.alsoWhen.count == 1)
        let sections = Inspector.trigger(try #require(app.store.flow(made.id)))
        #expect(!sections.isEmpty)
    }
}

@MainActor @Suite(.serialized) struct SideflowMoreTests {
    typealias World = SideflowTests.World

    private func data(_ op: DataStep.Op, _ from: JSON, than: String = "", count: Int? = nil, field: String? = nil) throws -> JSON {
        var step = DataStep(op: op, from: "")
        step.count = count
        step.field = field
        return try step.apply(to: from, than: than)
    }

    @Test func batchesGroupsAndFallbacks() throws {
        let items = JSON.array((1...5).map { .number(Double($0)) })
        guard case .array(let batches) = try data(.batches, items, count: 2) else { Issue.record("not a list"); return }
        #expect(batches.count == 3)
        #expect(batches.last == .array([.number(5)]))
        #expect(try data(.batches, .array([]), count: 2) == .array([]))
        #expect(throws: Problem.self) { _ = try data(.batches, .string("x"), count: 2) }
        let people = JSON.array([.object(["team": .string("a")]), .object(["team": .string("b")]), .object(["team": .string("a")])])
        guard case .object(let groups) = try data(.group, people, field: "team") else { Issue.record("not a record"); return }
        #expect(groups.count == 2)
        #expect(groups["a"].map { if case .array(let a) = $0 { a.count } else { 0 } } == 2)
        #expect(try data(.fallback, .string("  "), than: "none") == .string("none"))
        #expect(try data(.fallback, .null, than: "none") == .string("none"))
        #expect(try data(.fallback, .array([]), than: "none") == .string("none"))
        #expect(try data(.fallback, .string("here"), than: "none") == .string("here"))
    }

    @Test func aFallbackLooksPastAStepThatDidntRun() async throws {
        let w = try World()
        let flow = try w.flow([["id": "c", "if": ["value": "a", "test": "is", "than": "b"], "then": [["id": "x", "text": "made"]], "else": []],
                               ["id": "d", "data": ["op": "fallback", "from": "{{x}}", "than": "nothing"]], ["id": "t", "text": "{{d}}"]])
        let run = await w.settled(w.engine.start(flow, mode: .live, why: "t"))
        #expect(run?.status == .done, "\(run?.problem ?? "")")
        #expect(run?.values.value("t") == "nothing")
    }

    @Test func pauseHoldsBetweenStepsAndGoesOn() async throws {
        let w = try World()
        w.host.hold = "reads.it"
        w.host.honoursCancel = false
        let flow = try w.flow([["id": "a", "text": "x"], ["id": "b", "wait_minutes": 1], ["id": "c", "text": "y"]])
        let run = try #require(w.engine.start(flow, mode: .live, why: "t"))
        await w.quiet()
        w.engine.stop(run: run.id)
        await w.quiet()
        let second = try #require(w.engine.start(flow, mode: .live, why: "t"))
        w.engine.pause(run: second.id)
        await w.quiet()
        let paused = try #require(w.store.run(second.id))
        #expect(paused.status == .waiting)
        #expect(paused.paused)
        w.restart()
        w.engine.recover()
        w.now = w.now.addingTimeInterval(9000)
        w.engine.tick()
        await w.quiet()
        #expect(w.store.run(second.id)?.status == .waiting, "only the person goes on")
        w.engine.proceed(second.id, .try_again)
        await w.quiet()
        #expect(w.store.run(second.id)?.paused == false)
    }

    @Test func pauseOnlyOnWhatsRunning() async throws {
        let w = try World()
        let done = await w.settled(w.engine.start(try w.flow([["id": "a", "text": "x"]]), mode: .live, why: "t"))
        w.engine.pause(run: done!.id)
        #expect(!w.store.takeStop(Engine.pauseKey(done!.id)))
    }

    @Test func runAgainUsesWhatSetItOffAndGoesFromTheStart() async throws {
        let w = try World()
        let flow = try w.flow([["id": "a", "text": "{{trigger}}"]])
        let first = await w.settled(w.engine.start(flow, mode: .live, why: "t", trigger: "bread"))
        let second = try #require(w.engine.runAgain(first!.id, fromHere: false))
        let done = await w.settled(second)
        #expect(done?.values.value("a") == "bread")
        #expect(second.id != first!.id)
    }

    @Test func tryingAgainFromHereKeepsWhatCameBeforeAndRepeatsOnlyWhatFailed() async throws {
        let w = try World()
        w.host.answers["reads.it"] = [Actions.Outcome(status: .ok, text: "first read", summary: "")]
        w.host.answers["changes.it"] = [Actions.Outcome(status: .error, text: "broken")]
        let flow = try w.flow([["id": "r", "do": "reads.it"], ["id": "c", "do": "changes.it", "with": ["text": "{{r}}"]], ["id": "t", "text": "after {{r}}"]])
        let failed = await w.settled(w.engine.start(flow, mode: .live, why: "t"))
        #expect(failed?.status == .failed)
        #expect(w.engine.canGoOn(from: failed!))
        #expect(w.engine.stepsFromHere(failed!).map(\.id) == ["c", "t"], "what's shown before pressing")
        let again = try #require(w.engine.runAgain(failed!.id, fromHere: true))
        let done = await w.settled(again)
        #expect(done?.status == .done, "\(done?.problem ?? "")")
        #expect(done?.values.value("t") == "after first read")
        #expect(w.host.calls.filter { $0.tool == "reads.it" }.count == 1, "what came before isn't repeated")
        #expect(w.host.calls.filter { $0.tool == "changes.it" }.count == 2)
    }

    @Test func tryingAgainFromHereIsntOfferedWhenItWouldntBeTrue() async throws {
        let w = try World()
        w.host.answers["changes.it"] = [Actions.Outcome(status: .error, text: "broken")]
        var flow = try w.flow([["id": "c", "do": "changes.it", "with": ["text": "x"]]])
        let failed = await w.settled(w.engine.start(flow, mode: .live, why: "t"))
        #expect(w.engine.canGoOn(from: failed!))
        flow.live = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "c", "do": "reads.it"]]])
        w.store.save(flow)
        #expect(!w.engine.canGoOn(from: failed!), "what's on isn't what ran")
        #expect(w.engine.runAgain(failed!.id, fromHere: true) == nil)
        let inLoop = try w.flow([["id": "each", "for_each": "a\nb", "steps": [["id": "c", "do": "changes.it", "with": ["text": "x"]]]]])
        w.host.answers["changes.it"] = [Actions.Outcome(status: .error, text: "broken")]
        let looped = await w.settled(w.engine.start(inLoop, mode: .live, why: "t"))
        #expect(!w.engine.canGoOn(from: looped!), "a loop's place isn't kept")
    }

    @Test func aStepBecomesItsOwnFlowAndReadsTheSame() async throws {
        let w = try World()
        let app = App(folder: w.folder.appendingPathComponent("app"))
        app.engine.host = w.host
        app.catalog.use(Actions.Listing(tools: [Actions.Tool(name: "reads.it", title: "Read it", mutates: false, readsOnly: true)]))
        var flow = app.newFlow(name: "Outer", body: try FlowCodec.body(["trigger": ["type": "manual"], "steps": [
            ["id": "r", "text": "bread"],
            ["id": "w", "text": "buy {{r}}", "name": "Say what to buy"],
            ["id": "s", "text": "said {{w}}"],
        ]]))
        _ = try await Actions_UI.handle(Arguments(["op": "extract", "flow": flow.id, "step": "w"]), app)
        flow = try #require(app.store.flow(flow.id))
        guard case .call(let name, let inputs)? = flow.draft.step("w")?.kind else { Issue.record("not a call"); return }
        #expect(name == "Say what to buy")
        #expect(inputs == ["r": "{{r}}"])
        var made = try #require(app.store.named(name))
        #expect(made.draft.step("w")?.kind == .text("buy {{input.r}}"))
        #expect(made.state == .draft)
        made.live = made.draft
        made.state = .on
        app.store.save(made)
        let body = flow.draft
        var on = flow
        on.live = body
        on.state = .on
        app.store.save(on)
        let run = try #require(app.engine.start(on, mode: .live, why: "t"))
        await w.quiet(app.store)
        #expect(app.store.run(run.id)?.status == .done, "\(app.store.run(run.id)?.problem ?? "")")
        #expect(app.store.run(run.id)?.values.value("s") == "said buy bread", "what used its result still does")
    }

    @Test func aLoopCarriesItsOwnItemIntoTheNewFlow() throws {
        let body = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "l", "text": "a"], ["id": "each", "for_each": "{{l}}", "steps": [["id": "t", "text": "{{item}} of {{trigger}}"]]]]])
        let (outer, inner) = try Editing.extract("each", in: body, named: "New")
        #expect(inner.step("t")?.kind == .text("{{item}} of {{input.trigger}}"))
        guard case .forEach(let items, _, _, _)? = inner.step("each")?.kind, case .call(_, let inputs)? = outer.step("each")?.kind else { Issue.record("shape"); return }
        #expect(items == "{{input.l}}")
        #expect(Set(inputs.keys) == ["l", "trigger"])
    }

    @Test func aStepThatEndsTheFlowCantBeLifted() async throws {
        let w = try World()
        let app = App(folder: w.folder.appendingPathComponent("app"))
        let flow = app.newFlow(name: "Outer", body: try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "t", "try": [["id": "f", "finish": "x"]], "recover": [], "always": []]]]))
        await #expect(throws: Problem.self) { _ = try await Actions_UI.handle(Arguments(["op": "extract", "flow": flow.id, "step": "t"]), app) }
        #expect(app.store.flows().count == 1, "and leaves no empty flow behind")
    }
}

