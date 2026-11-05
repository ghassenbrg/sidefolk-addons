import Foundation
import Testing
@testable import ext_sideflow
import SidefolkExtensionKit

/// When a parallel carries on, what happens to the lanes it no longer needs, and how long a lane gets.
@MainActor @Suite(.serialized) struct SideflowLanesTests {
    typealias World = SideflowTests.World

    private let quick: [String: Any] = ["name": "quick", "steps": [["id": "a", "text": "A"]]]
    private let quicker: [String: Any] = ["name": "also", "steps": [["id": "c", "text": "C"]]]
    private let slow: [String: Any] = ["name": "slow", "steps": [["id": "w", "wait_minutes": 60], ["id": "b", "text": "B"]]]
    private let bad: [String: Any] = ["name": "bad", "steps": [["id": "x", "do": "changes.it", "with": ["text": "x"]]]]

    private func lanes(_ w: World, _ id: String) -> [Run] { w.store.runs(of: id).filter { $0.parent != nil } }

    private func lane(_ w: World, _ id: String, _ name: String) throws -> Run { try #require(lanes(w, id).first { $0.why == name }) }

    @Test func theFirstToFinishIsEnoughAndTheRestStop() async throws {
        let w = try World()
        let flow = try w.flow([["id": "both", "parallel": [slow, quick], "join": "first"], ["id": "s", "text": "{{both.winner}}|{{both.quick}}"]])
        let run = try #require(w.engine.start(flow, mode: .live, why: "t"))
        await w.quiet()
        let back = try #require(w.store.run(run.id))
        #expect(back.status == .done)
        #expect(back.values.value("s") == "A|A")
        #expect(try lane(w, flow.id, "slow").status == .stopped)
        #expect(back.records.contains { $0.step == "both" && $0.summary.filter(\.isNumber) == "12" }, "one of two: \(back.records.map(\.summary))")
    }

    @Test func aFailureDoesntStopTheFirstFromWinning() async throws {
        let w = try World()
        w.host.answers["changes.it"] = [Actions.Outcome(status: .error, text: "boom", summary: "")]
        let flow = try w.flow([["id": "both", "parallel": [bad, quick], "join": "first"], ["id": "s", "text": "{{both.winner}}"]])
        let run = try #require(w.engine.start(flow, mode: .live, why: "t"))
        await w.quiet()
        #expect(w.store.run(run.id)?.status == .done)
        #expect(w.store.run(run.id)?.values.value("s") == "A")
    }

    @Test func enoughCanBeANumber() async throws {
        let w = try World()
        let flow = try w.flow([["id": "both", "parallel": [quick, slow, quicker], "join": 2], ["id": "s", "text": "{{both.quick}}{{both.also}}"]])
        let run = try #require(w.engine.start(flow, mode: .live, why: "t"))
        await w.quiet()
        #expect(w.store.run(run.id)?.status == .done)
        #expect(w.store.run(run.id)?.values.value("s") == "AC")
        #expect(try lane(w, flow.id, "slow").status == .stopped)
    }

    @Test func aLostCauseWaitsForTheOthersUnlessToldNotTo() async throws {
        let w = try World()
        w.host.answers["changes.it"] = [Actions.Outcome(status: .error, text: "boom", summary: "")]
        let flow = try w.flow([["id": "both", "parallel": [bad, slow]]])
        let run = try #require(w.engine.start(flow, mode: .live, why: "t"))
        await w.quiet()
        #expect(w.store.run(run.id)?.status == .waiting, "the other one finishes first")
        #expect(try lane(w, flow.id, "slow").status == .waiting)

        w.host.answers["changes.it"] = [Actions.Outcome(status: .error, text: "boom", summary: "")]
        let fast = try w.flow([["id": "both", "parallel": [bad, slow], "fail_fast": true]])
        let other = try #require(w.engine.start(fast, mode: .live, why: "t"))
        await w.quiet()
        let back = try #require(w.store.run(other.id))
        #expect(back.status == .failed)
        #expect(back.problem?.contains("boom") == true, "the one that failed is what it says, not the one it stopped: \(back.problem ?? "")")
        #expect(try lane(w, fast.id, "slow").status == .stopped)
    }

    @Test func enoughLeftMeansFailFastHoldsOff() async throws {
        let w = try World()
        w.host.answers["changes.it"] = [Actions.Outcome(status: .error, text: "boom", summary: "")]
        let flow = try w.flow([["id": "both", "parallel": [bad, slow, quick], "join": 2, "fail_fast": true]])
        let run = try #require(w.engine.start(flow, mode: .live, why: "t"))
        await w.quiet()
        #expect(w.store.run(run.id)?.status == .waiting, "two can still finish")
        #expect(try lane(w, flow.id, "slow").status == .waiting)
    }

    @Test func settledCarriesOnWithWhatItGot() async throws {
        let w = try World()
        w.host.answers["changes.it"] = [Actions.Outcome(status: .error, text: "boom", summary: "")]
        let flow = try w.flow([["id": "both", "parallel": [bad, quick], "join": "settled"], ["id": "s", "text": "{{both.quick}} {{both.not_finished}}"]])
        let run = try #require(w.engine.start(flow, mode: .live, why: "t"))
        await w.quiet()
        let back = try #require(w.store.run(run.id))
        #expect(back.status == .done)
        #expect(back.values.value("s").contains("A"))
        #expect(back.values.value("s").contains("bad"))
        guard case .object(let fields)? = back.values.named["both"] else { Issue.record("not a record"); return }
        #expect(fields["bad"] == .null, "nothing from it, not half of it")
    }

    @Test func aLanePastItsLimitIsStoppedAndSaysSo() async throws {
        let w = try World()
        var limited = slow
        limited["timeout_minutes"] = 5
        let flow = try w.flow([["id": "both", "parallel": [limited, quick]]])
        let run = try #require(w.engine.start(flow, mode: .live, why: "t"))
        await w.quiet()
        #expect(w.store.run(run.id)?.status == .waiting)
        w.now = w.now.addingTimeInterval(4 * 60)
        w.engine.tick()
        await w.quiet()
        #expect(w.store.run(run.id)?.status == .waiting, "not yet")
        w.now = w.now.addingTimeInterval(2 * 60)
        w.engine.tick()
        await w.quiet()
        let back = try #require(w.store.run(run.id))
        #expect(back.status == .failed)
        #expect(back.problem?.contains("took longer") == true, "\(back.problem ?? "")")
        #expect(back.problem?.contains("slow") == true, "\(back.problem ?? "")")
    }

    @Test func aLimitInSettledIsJustALaneThatDidntFinish() async throws {
        let w = try World()
        var limited = slow
        limited["timeout_minutes"] = 5
        let flow = try w.flow([["id": "both", "parallel": [limited, quick], "join": "settled"], ["id": "s", "text": "{{both.not_finished}}"]])
        let run = try #require(w.engine.start(flow, mode: .live, why: "t"))
        await w.quiet()
        w.now = w.now.addingTimeInterval(6 * 60)
        w.engine.tick()
        await w.quiet()
        #expect(w.store.run(run.id)?.status == .done)
        #expect(w.store.run(run.id)?.values.value("s").contains("slow") == true)
    }

    @Test func aLanesLimitSurvivesARestart() async throws {
        let w = try World()
        var limited = slow
        limited["timeout_minutes"] = 5
        let flow = try w.flow([["id": "both", "parallel": [limited, quick]]])
        _ = w.engine.start(flow, mode: .live, why: "t")
        await w.quiet()
        let held = try lane(w, flow.id, "slow")
        #expect(held.deadline == held.startedAt.addingTimeInterval(300))
    }

    @Test func aLaneThatsMidActionIsToldToStop() async throws {
        let w = try World()
        w.host.hold = "changes.it"
        w.host.honoursCancel = true
        let flow = try w.flow([["id": "both", "parallel": [bad, quick], "join": "first"]])
        let run = try #require(w.engine.start(flow, mode: .live, why: "t"))
        await w.quiet()
        #expect(w.host.cancelled, "the tool under way is told")
        #expect(w.store.run(run.id)?.status == .done)
    }

    @Test func thePersonsStopStillEndsAll() async throws {
        let w = try World()
        let flow = try w.flow([["id": "both", "parallel": [slow, quick], "join": 2]])
        let run = try #require(w.engine.start(flow, mode: .live, why: "t"))
        await w.quiet()
        w.engine.stop(run: run.id, byThePerson: true)
        await w.quiet()
        #expect(w.store.run(run.id)?.status == .stopped)
        #expect(lanes(w, flow.id).allSatisfy { $0.status.isOver })
    }

    @Test func whatItTakesIsChecked() throws {
        let two: [[String: Any]] = [["name": "a", "steps": [["id": "a", "text": "A"]]], ["name": "b", "steps": [["id": "b", "text": "B"]]]]
        func body(_ step: [String: Any]) throws -> FlowBody { try FlowCodec.body(["trigger": ["type": "manual"], "steps": [step]]) }
        for join in [3, 0, -1] { #expect(throws: Problem.self) { try body(["parallel": two, "join": join]) } }
        #expect(throws: Problem.self) { try body(["parallel": two, "join": "most"]) }
        #expect(throws: Problem.self) { try body(["text": "x", "join": "first"]) }
        #expect(throws: Problem.self) { try body(["text": "x", "fail_fast": true]) }
        var late = two
        late[0]["timeout_minutes"] = 0
        #expect(throws: Problem.self) { try body(["parallel": late]) }
        late[0]["timeout_minutes"] = "soon"
        #expect(throws: Problem.self) { try body(["parallel": late]) }
    }

    @Test func itAllComesBackFromAFile() throws {
        var lanes: [[String: Any]] = [["name": "a", "steps": [["id": "a", "text": "A"]]], ["name": "b", "steps": [["id": "b", "text": "B"]]], ["name": "c", "steps": [["id": "c", "text": "C"]]]]
        lanes[1]["timeout_minutes"] = 7
        for join in ["first", "settled", 2] as [Any] {
            let body = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "p", "parallel": lanes, "join": join, "fail_fast": true]]])
            let back = try FlowCodec.body(FlowCodec.json(body))
            #expect(back == body)
            #expect(back.step("p")?.failFast == true)
        }
    }

    private func app(_ w: World, _ steps: [[String: Any]]) throws -> (App, Flow) {
        let app = App(folder: w.folder.appendingPathComponent("app"))
        app.engine.host = w.host
        return (app, app.newFlow(name: "F", body: try FlowCodec.body(["trigger": ["type": "manual"], "steps": steps])))
    }

    private func page(_ app: App, _ op: String, _ flow: Flow, _ extra: [String: Any] = [:]) async throws {
        var input: [String: Any] = ["op": op, "flow": flow.id, "step": "p"]
        input.merge(extra) { _, new in new }
        _ = try await Actions_UI.handle(Arguments(input), app)
    }

    @Test func thePageSetsAllOfIt() async throws {
        let w = try World()
        let three: [[String: Any]] = [quick, slow, quicker]
        let (app, flow) = try app(w, [["id": "p", "parallel": three]])
        func step() throws -> Step { try #require(app.store.flow(flow.id)?.draft.step("p")) }
        func limit(_ at: Int) throws -> Int? { if case .parallel(let lanes) = try step().kind { lanes[at].timeoutMinutes } else { nil } }

        try await page(app, "lane_limit", flow, ["lane": 1, "text": "15"])
        #expect(try limit(1) == 15)
        try await page(app, "lane_limit", flow, ["lane": 1, "text": ""])
        #expect(try limit(1) == nil, "emptied, no limit")
        await #expect(throws: Problem.self) { try await self.page(app, "lane_limit", flow, ["lane": 1, "text": "soon"]) }
        await #expect(throws: Problem.self) { try await self.page(app, "lane_limit", flow, ["lane": 1, "text": "0"]) }

        try await page(app, "lane_join", flow, ["value": "first"])
        #expect(try step().join == .first)
        try await page(app, "lane_fail_fast", flow, ["on": true])
        #expect(try step().failFast)

        try await page(app, "lane_join", flow, ["value": "2"])
        #expect(try step().join == .atLeast(2))
        try await page(app, "lane_remove", flow, ["lane": 2])
        #expect(try step().join == .all, "two of two is all of them")
    }

    @Test func theFormSaysWhatItDoes() throws {
        let w = try World()
        let (app, flow) = try app(w, [["id": "p", "parallel": [quick, slow, quicker], "join": 2, "fail_fast": true]])
        app.nav.inspect(.step("p"), in: flow.id)
        let shown = String(describing: Inspector.sections(try #require(app.store.flow(flow.id)), app, problems: []))
        for words in ["Give up after, in minutes", "When 2 have finished", "When the first has finished", "When all have ended, whichever way", "Stop the others as soon as it"] {
            #expect(shown.filter { !"\u{2068}\u{2069}".contains($0) }.contains(words), "\(words)")
        }
    }

    @Test func aValueOnlyOneJoinGivesIsCaughtForTheOthers() throws {
        let w = try World()
        let two: [[String: Any]] = [["name": "a", "steps": [["id": "a", "text": "A"]]], ["name": "b", "steps": [["id": "b", "text": "B"]]]]
        func problems(_ join: String) throws -> [FlowProblem] {
            try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "p", "parallel": two, "join": join], ["id": "s", "text": "{{p.winner}}"]]]).problems(w.catalog)
        }
        #expect(try problems("all").contains { $0.step == "s" })
        #expect(try !problems("first").contains { $0.step == "s" })
    }
}
