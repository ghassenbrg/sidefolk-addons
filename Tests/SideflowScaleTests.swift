import Foundation
import Testing
@testable import ext_sideflow
import SidefolkExtensionKit

/// A long flow: wrapping steps, focusing on a part, and a board that fits.
@MainActor @Suite(.serialized) struct SideflowScaleTests {
    typealias World = SideflowTests.World

    private func app(_ w: World) -> App {
        let app = App(folder: w.folder.appendingPathComponent("app"))
        app.engine.host = w.host
        return app
    }

    private func texts(_ prefix: String, _ count: Int) -> [[String: Any]] { (0..<count).map { ["id": "\(prefix)\($0)", "text": "x"] } }

    @Test func stepsGoInsideSomethingAsOneEditAndUndoTakesThemOut() async throws {
        let w = try World()
        let app = app(w)
        let flow = app.newFlow(name: "Mine", body: try FlowCodec.body(["trigger": ["type": "manual"], "steps": texts("s", 4)]))
        _ = try await Actions_UI.handle(Arguments(["op": "wrap_through", "flow": flow.id, "step": "s1", "value": "s2"]), app)
        _ = try await Actions_UI.handle(Arguments(["op": "wrap", "flow": flow.id, "step": "s1", "value": "try"]), app)
        let body = try #require(app.store.flow(flow.id)?.draft)
        #expect(body.steps.map(\.id).count == 3)
        guard case .attempt(let inside, _, _) = body.steps[1].kind else { Issue.record("not inside a try"); return }
        #expect(inside.map(\.id) == ["s1", "s2"])
        #expect(app.nav.inspecting(flow) == .step(body.steps[1].id))
        _ = try await Actions_UI.handle(Arguments(["op": "undo", "flow": flow.id]), app)
        #expect(app.store.flow(flow.id)?.draft.steps.map(\.id) == ["s0", "s1", "s2", "s3"])
    }

    @Test func eachKindHoldsThem() throws {
        let body = try FlowCodec.body(["trigger": ["type": "manual"], "steps": texts("s", 2)])
        for kind: Step.Kind in [.branch(Condition(value: "", test: .contains, than: ""), then: [], otherwise: []), .forEach(items: "", limit: 5, onFailure: .stop, steps: []), .repeatUntil(until: Condition(value: "", test: .contains, than: ""), times: 3, steps: []), .attempt(steps: [], recover: [], always: []), .parallel(lanes: [Step.Lane(name: "A", steps: [])])] {
            let out = try #require(Editing.wrap(from: "s0", through: "s1", inside: Step(id: "h", kind: kind), in: body))
            #expect(out.steps.map(\.id) == ["h"])
            #expect(out.allSteps.map(\.id) == ["h", "s0", "s1"])
        }
        #expect(Editing.wrap(from: "s1", through: "s0", inside: Step(id: "h", kind: .attempt(steps: [], recover: [], always: [])), in: body) == nil, "backwards")
        #expect(Editing.wrap(from: "s0", through: "s1", inside: Step(id: "h", kind: .text("x")), in: body) == nil, "nothing to hold them")
    }

    @Test func aFlowHasAsManyStepsAsTheBoardCanShow() throws {
        let fits = try FlowCodec.body(["trigger": ["type": "manual"], "steps": texts("s", FlowBody.maxSteps)])
        #expect(fits.allSteps.count == 100)
        #expect(fits.unfinished == nil)
        #expect(throws: Problem.self, "one more than the board draws, with its start card, under 128") {
            try FlowCodec.body(["trigger": ["type": "manual"], "steps": texts("s", FlowBody.maxSteps + 1)])
        }
    }

    @Test func focusingShowsOnlyThatPartAndTheWayBack() async throws {
        let w = try World()
        let app = app(w)
        let flow = app.newFlow(name: "Mine", body: try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "o", "try": [["id": "i", "try": texts("x", 2)]]], ["id": "after", "text": "y"]]]))
        _ = try await Actions_UI.handle(Arguments(["op": "focus", "flow": flow.id, "step": "i"]), app)
        let tree = Pages.tree(flow, app, problems: [])
        #expect(tree.nodes.map(\.id) == ["i"])
        let page = String(describing: Pages.flowPage(flow, app, state: Arguments([:]))).filter { !"\u{2068}\u{2069}\\".contains($0) }
        #expect(page.contains("All steps"))
        _ = try await Actions_UI.handle(Arguments(["op": "focus", "flow": flow.id]), app)
        #expect(Pages.tree(flow, app, problems: []).nodes.map(\.id) == ["start", "o", "after"])
        #expect(Editing.holders(of: "x0", in: flow.draft).map(\.id) == ["o", "i"])
    }

    @Test func aShutPartSaysHowMuchItHoldsAndWhatsWrongInside() throws {
        let w = try World()
        let app = app(w)
        // Deeper than a flow written now may go, as one saved before the limit can be: the fifth level is past what the board draws.
        var held = Step(id: "five", kind: .attempt(steps: [Step(id: "x", kind: .action(tool: "changes.it", input: ["text": .string("x")])), Step(id: "y", kind: .text("y"))], recover: [], always: []))
        for level in (0..<4).reversed() { held = Step(id: "l\(level)", kind: .attempt(steps: [held], recover: [], always: [])) }
        let flow = app.newFlow(name: "Mine", body: FlowBody(steps: [held]))
        func shut() -> CardTree.Node? {
            var level = Pages.tree(flow, app, problems: []).nodes
            for _ in 0..<4 { level = level.last?.branches.first?.nodes ?? [] }
            return level.first
        }
        #expect(shut()?.branches.isEmpty == true && shut()?.pill?.text.contains("2") == true, "\(String(describing: shut()?.pill))")
        app.preflight[flow.id] = ["x": Actions.Check(decision: .deny, summary: "", mutates: true, standing: false)]
        #expect(shut()?.pill?.text == "Not allowed inside", "a step it hides can't do what it says")
    }
}

@MainActor @Suite(.serialized) struct SideflowTemplateNeedsTests {
    typealias World = SideflowTests.World

    @Test func aTemplateSaysWhatItNeedsBeforeItsPicked() async throws {
        let w = try World()
        let app = App(folder: w.folder.appendingPathComponent("app"))
        app.engine.host = w.host
        app.catalog.use(Actions.Listing(tools: []))
        let both = try #require(Templates.template("both"))
        #expect(!Templates.missing(both, app.catalog).isEmpty, "the test world has no weather extension")
        let words = String(describing: Pages.templateCards(app)).filter { !"\u{2068}\u{2069}\\".contains($0) }
        #expect(words.contains("Needs an add-on") && words.contains("Open Add-ons"))
    }
}

@MainActor @Suite(.serialized) struct SideflowLaterListTests {
    typealias World = SideflowTests.World

    @Test func nextGoesByTheFlowsOwnClock() throws {
        var flow = Flow(id: "f", name: "F", draft: try FlowCodec.body(["trigger": ["type": "schedule", "days": ["mon", "tue", "wed", "thu", "fri", "sat", "sun"], "at": "08:30"], "time_zone": "Pacific/Kiritimati", "steps": [["id": "a", "text": "x"]]]), createdAt: Date(), updatedAt: Date())
        flow.state = .on
        flow.live = flow.draft
        flow.lastFire = Date(timeIntervalSince1970: 1_800_000_000)
        let next = try #require(Summaries.next(flow))
        var there = Calendar(identifier: .gregorian)
        there.timeZone = TimeZone(identifier: "Pacific/Kiritimati")!
        #expect(there.component(.hour, from: next) == 8 && there.component(.minute, from: next) == 30)
    }
}

extension SideflowLaterListTests {
    @Test func todayIsTheDayItGoesOnNotTheDayItBegan() async throws {
        let w = try SideflowTests.World()
        let flow = try w.flow([["id": "wait", "wait_minutes": 60 * 24], ["id": "t", "text": "{{today}}"]])
        let run = try #require(w.engine.start(flow, mode: .live, why: "t"))
        await w.quiet()
        let began = try #require(w.store.run(run.id)?.values.today)
        w.now = w.now.addingTimeInterval(2 * 86400)
        w.engine.tick()
        await w.quiet()
        #expect(w.store.run(run.id)?.record(of: "t")?.output != began)
    }
}

extension SideflowLaterListTests {
    @Test func aStepsKeyIsTheSameEachTryAndDifferentForEachGo() async throws {
        let w = try SideflowTests.World()
        w.host.answers["reads.it"] = [Actions.Outcome(status: .ok, text: "[1, 2]", summary: "")]
        let flow = try w.flow([["id": "r", "do": "reads.it"], ["id": "e", "for_each": "{{r}}", "steps": [["id": "s", "do": "changes.it", "with": ["text": "x", "q": "{{step_key}}"]]]]])
        let run = try #require(w.engine.start(flow, mode: .live, why: "t"))
        await w.quiet()
        let keys = w.host.calls.filter { $0.tool == "changes.it" }.compactMap { $0.input["q"] as? String }
        #expect(keys.count == 2 && Set(keys).count == 2 && keys.allSatisfy { $0.hasPrefix(run.id) })
    }
}

extension SideflowLaterListTests {
    @Test func aServiceThatAsksToWaitIsAskedAgainLaterAndNotForEver() throws {
        #expect(Engine.askedToWait(#"{"rate_limited": true, "retry_after_seconds": 30}"#) == 30)
        #expect(Engine.askedToWait(#"{"rate_limited": true}"#) == 60)
        #expect(Engine.askedToWait(#"{"rate_limited": false, "retry_after_seconds": 30}"#) == nil)
        #expect(Engine.askedToWait(nil) == nil)
    }

    @Test func aWaitTakesNoCallTheCardDidntCountForTheStep() async throws {
        let w = try World()
        let wait = Actions.Outcome(status: .ok, text: "", data: #"{"rate_limited": true, "retry_after_seconds": 30}"#)
        w.host.answers["reads.it"] = [wait, Actions.Outcome(status: .ok, text: "fine")]
        let flow = try w.flow([["id": "a", "do": "reads.it"], ["id": "b", "do": "changes.it", "with": ["text": "x"]]])
        let run = try #require(w.engine.start(flow, mode: .live, why: "t"))
        await w.quiet()
        let back = try #require(w.store.run(run.id))
        #expect(back.status == .failed && back.problem?.contains("Try again later") == true, "\(back.problem ?? "")")
        #expect(w.host.calls.filter { $0.tool == "reads.it" }.count == 1, "no second go: it would have been the next step's call")
        #expect(!w.host.calls.contains { $0.tool == "changes.it" })
    }

    @Test func aStepSetToTryAgainWaitsWithinItsTries() async throws {
        let w = try World()
        let wait = Actions.Outcome(status: .ok, text: "", data: #"{"rate_limited": true, "retry_after_seconds": 30}"#)
        w.host.answers["reads.it"] = [wait, Actions.Outcome(status: .ok, text: "fine")]
        let flow = try w.flow([["id": "a", "do": "reads.it", "on_failure": "retry"], ["id": "t", "text": "{{a}}"]])
        let run = try #require(w.engine.start(flow, mode: .live, why: "t"))
        await w.quiet()
        #expect(w.store.run(run.id)?.status == .waiting)
        w.now = w.now.addingTimeInterval(31)
        w.engine.tick()
        await w.quiet()
        #expect(w.store.run(run.id)?.status == .done, "\(w.store.run(run.id)?.problem ?? "")")
        #expect(Engine.waitsAllowed(try #require(flow.draft.step("a")), in: flow.draft) <= Engine.retriesAtMost, "within what the card counted")
    }

    @Test func aWaitTakesNothingWhenTheCardsNumbersWereCutDown() throws {
        let retrying: [String: Any] = ["id": "a", "do": "reads.it", "on_failure": "retry"]
        let looped = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "each", "for_each": "{{x}}", "limit": 500, "steps": [retrying]]]])
        #expect(Engine.callsPerRun(looped.steps) == Plans.mostPerRun, "500 goes of four tries is more than a run may have")
        #expect(Engine.waitsAllowed(try #require(looped.step("a")), in: looped) == 0, "so a wait would take a plain go's call")
        let watched = try FlowCodec.body(["trigger": ["type": "watch", "kind": "url_change", "target": "https://x.example"], "steps": [retrying]])
        #expect(Engine.waitsAllowed(try #require(watched.step("a")), in: watched) == 0, "720 runs a day of four tries is more than a day may have")
        let plain = try FlowCodec.body(["trigger": ["type": "schedule", "every_minutes": 15], "steps": [retrying]])
        #expect(Engine.waitsAllowed(try #require(plain.step("a")), in: plain) > 0, "96 runs of four fit, so its tries are really there")
    }
}
