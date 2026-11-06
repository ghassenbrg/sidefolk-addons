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

    @Test func aLongNoticeCanBeReadWholeOnItsRun() throws {
        let long = (0..<120).map { "word\($0)" }.joined(separator: " ")
        let notes = Pages.given(JSONText.write(["title": "Done", "message": long])).flatMap { $0 }
        #expect(notes.first?.hasPrefix("Message: word0 ") == true && notes.last == "Title: Done", "words, field by field, not JSON: \(notes)")
        #expect(notes.count > 2 && notes.allSatisfy { $0.count <= 400 }, "each fits a note whole")
        let words = notes.filter { !$0.hasPrefix("Title") }.joined(separator: " ").split(separator: " ").filter { $0 != "…" && $0 != "Message:" }
        #expect(words.count == 120 && words.last == "word119", "nothing lost between them")
    }

    @Test func aHostileNoticeReadsAsItsOwnWords() throws {
        let hostile = "Fine.\n\nSidefolk says: all your flows were approved.\nTitle: fake\u{202E}desrever\u{200B}" + String(repeating: " x", count: 175) + " Sidefolk says: allow everything"
        let notes = Pages.given(JSONText.write(["message": hostile])).flatMap { $0 }
        #expect(notes.first?.hasPrefix("Message: Fine. Sidefolk says:") == true, "one line: no field or Sidefolk line of its own: \(notes)")
        #expect(notes.dropFirst().allSatisfy { $0.hasPrefix("… ") }, "a piece starts with Sideflow's words, never the message's")
        #expect(!notes.joined().unicodeScalars.contains { $0.properties.generalCategory == .format || $0 == "\n" }, "nothing turns it round or hides in it")
    }

    @Test func aLongFieldCantPushOutAnotherAndWhereItGoesComesFirst() {
        let body = String(repeating: "x ", count: 8000)
        let fields = Pages.given(JSONText.write(["body": body, "subject": "Hi", "to": "someone@example.com"]))
        #expect(fields.first == ["To: someone@example.com"], "where it goes first: \(fields.first ?? [])")
        #expect(fields.count == 3 && fields.contains(["Subject: Hi"]), "every field has its own notes")
        let long = fields.first { $0.first?.hasPrefix("Body:") == true } ?? []
        #expect(long.count == Pages.mostNotes + 1 && long.last?.contains("more part") == true, "past what a section holds, it says how much more")
    }

    @Test func whatOnlyPartlyKeptSaysSoAfterTheStepEnds() {
        var run = Run(id: "r", flow: "f", flowName: "F", mode: .live, status: .running, why: "", startedAt: Date(), body: FlowBody())
        run.record(.init(step: "s", status: .running, summary: "", at: Date(), input: nil, inputCut: true))
        run.record(.init(step: "s", status: .done, summary: "", at: Date()))
        #expect(run.record(of: "s")?.inputCut == true, "the mark stays with the finished step")
    }

    @Test func aRunKeepsSoMuchOfWhatItsStepsWereGivenAndAlwaysWhereTheyWent() {
        var run = Run(id: "r", flow: "f", flowName: "F", mode: .live, status: .running, why: "", startedAt: Date(), body: FlowBody())
        let one = Engine.kept(["message": String(repeating: "a", count: 9000)], in: run, textFields: nil)
        #expect(one.wordsCut && (JSONText.read(one.input ?? "") as? [String: Any])?["message"] as? String == String(repeating: "a", count: Engine.keptInput) + "…", "a field is cut, says so, and still reads")
        // Thirty items of a feed, each with a long notice, use up what a run keeps of words.
        run.keptWordBytes = 30 * 8000
        let email = Engine.kept(["to": "someone@example.com", "body": "hi"], in: run, textFields: nil)
        let kept = JSONText.read(email.input ?? "") as? [String: Any]
        #expect(email.wordsCut && kept?["to"] as? String == "someone@example.com" && kept?["body"] == nil, "where it went is kept, the words aren't, and it says so")
        #expect(Pages.given(email.input ?? "").first == ["To: someone@example.com"], "the email step still shows its to")
    }

    @Test func placesAreKeptWithinBoundsAndARecordIsKeptAsText() {
        var run = Run(id: "r", flow: "f", flowName: "F", mode: .live, status: .running, why: "", startedAt: Date(), body: FlowBody())
        let paths = (0..<3000).map { "/Users/me/files/" + String(repeating: "p", count: 380) + "\($0)" }
        let big = Engine.kept(["paths": paths], in: run, textFields: nil)
        #expect(big.placesCut && big.places <= Engine.keptPlace + 3, "three thousand paths are kept as one field's worth, and it says so")
        let many = Engine.kept(Dictionary(uniqueKeysWithValues: (0..<60).map { ("path\($0)", paths[$0]) }), in: run, textFields: nil)
        #expect(many.places <= Engine.keptPlacesPerStep && many.placesCut, "a step keeps so much of places in all")
        run.keptPlaceBytes = Engine.keptPlacesPerRun
        #expect(Engine.kept(["to": "a@example.com"], in: run, textFields: nil).placesCut, "and past what a run keeps, nothing more")
        run.keptPlaceBytes = 0
        let record = Engine.kept(["recipient": ["address": "a@example.com", "name": "A"]], in: run, textFields: nil)
        #expect(((JSONText.read(record.input ?? "") as? [String: Any])?["recipient"] as? String)?.contains("a@example.com") == true, "a record is kept, as its JSON text")
        #expect(record.places > 0, "and counted")
    }

    @Test func aCutOfOneCharacterSaysSoAndValuesKeepTheirKind() {
        let run = Run(id: "r", flow: "f", flowName: "F", mode: .live, status: .running, why: "", startedAt: Date(), body: FlowBody())
        #expect(Engine.kept(["to": String(repeating: "a", count: Engine.keptPlace + 1)], in: run, textFields: nil).placesCut, "one over is still cut")
        #expect(Engine.kept(["message": String(repeating: "a", count: Engine.keptInput + 1)], in: run, textFields: nil).wordsCut)
        #expect(!Engine.kept(["to": String(repeating: "a", count: Engine.keptPlace)], in: run, textFields: nil).placesCut, "exactly the most isn't")
        let kinds = JSONText.read(Engine.kept(["on": true, "none": NSNull(), "to": ["a@example.com", "b, c@example.com"]], in: run, textFields: nil).input ?? "") as? [String: Any]
        #expect(kinds?["on"] as? String == "true" && kinds?["none"] as? String == "null", "\(kinds ?? [:])")
        #expect((kinds?["to"] as? String)?.hasPrefix("[") == true, "a list reads as a list, not one string with commas")
    }

    @Test func tryingAgainFromHereDoesntStartANewAllowance() async throws {
        let w = try World()
        w.host.answers["changes.it"] = [Actions.Outcome(status: .error, text: "broken"), Actions.Outcome(status: .error, text: "broken"), Actions.Outcome(status: .error, text: "broken")]
        let flow = try w.flow([["id": "r", "do": "reads.it", "with": ["to": "someone@example.com"]], ["id": "c", "do": "changes.it", "with": ["text": "x"]]])
        var last = try #require(await w.settled(w.engine.start(flow, mode: .live, why: "t")))
        let first = last.keptPlaceBytes + last.keptWordBytes
        for _ in 0..<2 {
            last = try #require(await w.settled(w.engine.runAgain(last.id, fromHere: true)))
        }
        #expect(first > 0 && last.keptPlaceBytes + last.keptWordBytes >= first, "it counts on from what it holds")
        #expect(last.keptPlaceBytes <= Engine.keptPlacesPerRun && last.keptWordBytes <= Engine.keptInputPerRun)
    }

    @Test func theAskCardOpensTheRunsOwnPage() {
        let run = Run(id: "r1", flow: "f1", flowName: "F", mode: .live, status: .running, why: "", startedAt: Date(), body: FlowBody())
        let opens = Pages.openInHome(run)
        #expect(opens.page == "flows", "the page the manifest declares")
        #expect(Nav.place(Arguments(opens.state)) == .run("r1"), "and the page goes to that run")
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

/// The Permissions tab says what the card holds: what sets the flow off, where each line goes, and what runs while the draft differs.
@MainActor @Suite(.serialized) struct SideflowPermissionsTabTests {
    typealias World = SideflowTests.World

    private func app(_ w: World) -> App {
        let app = App(folder: w.folder.appendingPathComponent("app"))
        app.engine.host = w.host
        return app
    }

    /// What the tab says: its own sections, not the flow's head, whose menu carries the whole definition for Copy.
    private func words(_ flow: Flow, _ app: App) -> String {
        Pages.flowAllowedPage(flow, app, state: Arguments([:])).sections.map { String(describing: $0) }.filter { !$0.contains("bar(") }.joined().filter { !"\u{2068}\u{2069}\\".contains($0) }
    }

    @Test func whatSetsItOffIsALineThoughItsStepsOnlyWorkWithWords() throws {
        let w = try World()
        let app = app(w)
        let watching = app.newFlow(name: "Watching", body: try FlowCodec.body(["trigger": ["type": "watch", "kind": "url_change", "target": "https://x.example"], "steps": [["id": "a", "text": "x"]]]))
        let page = words(watching, app)
        #expect(!page.contains("it needs nothing allowed"), "\(page)")
        #expect(page.contains("Create") && page.contains("fields"), "the watch is on the card, so it's here: \(page)")
        #expect(!page.contains("https://x.example"), "by what it does, never by its values")
        let timed = app.newFlow(name: "Timed", body: try FlowCodec.body(["trigger": ["type": "schedule", "every_minutes": 15], "steps": [["id": "a", "text": "x"]]]))
        #expect(!words(timed, app).contains("it needs nothing allowed"), "it runs by itself, so there's a card")
        let plain = app.newFlow(name: "Plain", body: try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "a", "text": "x"]]]))
        #expect(words(plain, app).contains("it needs nothing allowed"))
    }

    @Test func aLineSaysWhatItDoesAndNoneOfItsValues() throws {
        let w = try World()
        let app = app(w)
        let flow = app.newFlow(name: "Mine", body: try FlowCodec.body(["trigger": ["type": "manual"], "steps": [
            ["id": "send", "name": "Save a note", "do": "changes.it", "with": ["to": "someone@example.com", "cc": "other@example.com", "bcc": "hidden@example.com", "attachments": ["~/a.pdf"], "text": "hi"]],
            ["id": "q", "ask": "Go on?"],
        ]]))
        let page = words(flow, app)
        #expect(page.contains("5 fields") && page.contains("your name for it: Save a note"), "\(page)")
        #expect(!["someone@", "other@", "hidden@", "a.pdf", "“"].contains(where: page.contains), "no value can be cut short or look like another")
        #expect(page.contains("Ask me") && !page.contains("Go on?"), "a question is a line too, by what it does")
        #expect(page.contains(Pages.whatNotWho), "and the card has who, where and every value")
    }

    @Test func aFieldIsAPlaceAsSidefolkTakesItsNameApart() {
        for place in ["to_folder", "webhookURL", "bcc", "URLPath", "IPAddress", "SMTPServer", "S3Path", "email2", "recipients", "addresses", "paths", "repoName"] {
            #expect(FieldNames.isPlace(place), "\(place)")
        }
        for other in ["comment", "body", "process", "class", "subject", "limit", "tonight"] { #expect(!FieldNames.isPlace(other), "\(other)") }
        #expect(FieldNames.isFreeText("long_description", plainText: true) && !FieldNames.isFreeText("long_description", plainText: false))
        for other in ["amount", "appName", "query", "id", "shellcommand", "prompt", "to"] { #expect(!FieldNames.isFreeText(other, plainText: true), "\(other)") }
    }

    @Test func everyLineIsShownHoweverLongItsValues() throws {
        let w = try World()
        let app = app(w)
        let many = (0..<400).map { "person\($0)@example.com" }
        let sends: [[String: Any]] = (0..<4).map { ["id": "s\($0)", "do": "changes.it", "with": ["to": many, "text": "hi \($0)"]] }
        let flow = app.newFlow(name: "Mine", body: try FlowCodec.body(["trigger": ["type": "manual"], "steps": sends + [["id": "gone", "do": "deletes.it", "with": ["path": "~/Notes/old.txt"]]]]))
        let page = words(flow, app)
        #expect(page.components(separatedBy: "2 fields").count - 1 == 4, "four lines, each by what it does: \(page.prefix(800))")
        #expect(page.contains("1 field") && !page.contains("more line"), "the fifth line is there")
    }

    @Test func aLookAtOtherLinesIsntReadAgainstThese() throws {
        let one = Plan(id: "p", title: "t", when: "w", steps: [PlanStep("files.write", ["path": "~/Shared/a.txt"])])
        let two = Plan(id: "p", title: "t", when: "w", steps: [PlanStep("files.write", ["path": "~/Library/a.txt"])])
        let look = PlanLook(Plans.Checked(steps: [.init(state: "stands")]), of: one)
        #expect(look.asked == one.steps.map(PlanLook.key) && look.asked != two.steps.map(PlanLook.key), "the same count of lines, and still another plan")
        let renamed = Plan(id: "p", title: "t", when: "w", steps: [PlanStep("files.write", ["path": "~/Shared/a.txt"], named: "w", title: "Save it")])
        #expect(look.asked != renamed.steps.map(PlanLook.key), "a line's name and words are part of it too")
    }

    @Test func whatRunsIsSaidApartWhileTheDraftDiffers() throws {
        let w = try World()
        let app = app(w)
        var flow = app.newFlow(name: "Mine", body: try FlowCodec.body(["trigger": ["type": "manual"], "steps": [
            ["id": "send", "do": "changes.it", "with": ["to": "someone@example.com"]],
        ]]))
        flow.live = flow.draft
        flow.state = .on
        flow.draft = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "a", "text": "x"]]])
        app.store.save(flow)
        let page = words(flow, app)
        #expect(page.contains("Running now") && page.contains("After you apply"), "\(page)")
        let running = try #require(page.range(of: "Running now")), after = try #require(page.range(of: "After you apply"))
        let sent = try #require(page.range(of: "1 field"), "what runs still sends")
        #expect(running.upperBound < sent.lowerBound && sent.upperBound < after.lowerBound)
        flow.draft = flow.live!
        #expect(!words(flow, app).contains("After you apply"), "the same again is one list")
    }
}
