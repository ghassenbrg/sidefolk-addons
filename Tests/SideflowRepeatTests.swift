import Foundation
import Testing
@testable import ext_sideflow
import SidefolkExtensionKit

/// Repeat until: round and round until it holds, with a limit.
@MainActor @Suite(.serialized) struct SideflowRepeatTests {
    typealias World = SideflowTests.World

    @Test func itWontSendAgainWhatItCantSeeInsideALoopOrLane() async throws {
        for inner: [String: Any] in [["id": "each", "for_each": "a\nb", "steps": [["id": "send", "do": "changes.it", "with": ["text": "x"]]]],
                                     ["id": "both", "parallel": [["name": "one", "steps": [["id": "send", "do": "changes.it", "with": ["text": "x"]]]], ["name": "two", "steps": [["id": "o", "text": "o"]]]]]] {
            let w = try World()
            let flow = try w.flow([["id": "again", "repeat": [inner], "until": ["value": "{{send}}", "test": "contains", "than": "done"], "times": 3]])
            let run = await w.settled(w.engine.start(flow, mode: .live, why: "t"))
            #expect(run?.status != .done)
            let sent = w.host.calls.filter { $0.tool == "changes.it" }.count
            #expect(sent == (inner["for_each"] == nil ? 1 : 2), "one go's worth, never another go")
        }
    }

    private func again(until: String = "ready", times: Int = 5, extra: [String: Any] = [:], steps: [[String: Any]] = [["id": "look", "do": "reads.it", "name": "Look"]]) -> [String: Any] {
        var step: [String: Any] = ["id": "again", "repeat": steps, "until": ["value": "{{look}}", "test": "contains", "than": until], "times": times]
        step.merge(extra) { _, new in new }
        return step
    }

    private func answers(_ w: World, _ list: [String]) {
        w.host.answers["reads.it"] = list.map { Actions.Outcome(status: .ok, text: $0, summary: "Looked") }
    }

    private func sends(_ steps: [[String: Any]], until: [String: Any], answer: String = "Sent") async throws -> (Run?, Int) {
        let w = try World()
        w.host.answers["changes.it"] = (0..<20).map { _ in Actions.Outcome(status: .ok, text: answer, summary: "") }
        var other = try w.flow([["id": "t", "text": "x"]])
        other.name = "Other"
        w.store.save(other)
        let flow = try w.flow([["id": "again", "repeat": steps, "until": until, "times": 4]])
        let run = await w.settled(w.engine.start(flow, mode: .live, why: "t"))
        return (run, w.host.calls.filter { $0.tool == "changes.it" }.count)
    }

    static let send: [String: Any] = ["id": "send", "do": "changes.it", "with": ["text": "x"]]

    @Test func aGoThatDidSomethingDoesntGoRoundOverWhatSaysNothing() async throws {
        // A read inside a loop, gone by the time it looks, beside a write.
        var (run, sent) = try await sends([["id": "each", "for_each": "a", "steps": [Self.send, ["id": "check", "do": "reads.it"]]]], until: ["value": "{{check}}", "test": "not_empty"])
        #expect(run?.status != .done && sent == 1)
        // A loop inside that made a list of nothing.
        (run, sent) = try await sends([["id": "each", "for_each": "a", "steps": [Self.send]]], until: ["value": "{{each[0]}}", "test": "not_empty"], answer: "")
        #expect(run?.status != .done && sent == 1)
        // A repeat inside.
        (run, sent) = try await sends([["id": "inner", "repeat": [Self.send], "until": ["value": "{{send}}", "test": "contains", "than": "Sent"], "times": 2]], until: ["value": "{{inner}}", "test": "contains", "than": "never"], answer: "")
        #expect(run?.status != .done && sent == 1)
        // Only spaces.
        (run, sent) = try await sends([Self.send], until: ["value": "{{send}}", "test": "not_empty"], answer: "  ")
        #expect(run?.status != .done && sent == 1)
        // An empty list, as words.
        (run, sent) = try await sends([Self.send], until: ["value": "{{send}}", "test": "not_empty"], answer: "[]")
        #expect(run?.status != .done && sent == 1)
        // A misspelt name.
        (run, sent) = try await sends([Self.send], until: ["value": "{{sned}}", "test": "not_empty"])
        #expect(run?.status != .done && sent == 1)
        // A failure carried past by a try.
        let w = try World()
        w.host.answers["changes.it"] = (0..<20).map { _ in Actions.Outcome(status: .error, text: "no") }
        let flow = try w.flow([["id": "again", "repeat": [["id": "t", "try": [Self.send], "recover": [["id": "r", "text": "ok"]]]], "until": ["value": "{{send}}", "test": "not_empty"], "times": 4]])
        let tried = await w.settled(w.engine.start(flow, mode: .live, why: "t"))
        #expect(tried?.status != .done)
        #expect(w.host.calls.filter { $0.tool == "changes.it" }.count == 1)
    }

    @Test func whatGoingRoundCantChangeDoesntSendAgainEvenIfItSaysSomething() async throws {
        let w = try World()
        w.host.answers["reads.it"] = [Actions.Outcome(status: .ok, text: "pending", summary: "")]
        w.host.answers["changes.it"] = (0..<9).map { _ in Actions.Outcome(status: .ok, text: "Sent", summary: "") }
        let flow = try w.flow([["id": "check", "do": "reads.it"], ["id": "again", "repeat": [Self.send], "until": ["value": "{{check}}", "test": "contains", "than": "done"], "times": 4]])
        let run = await w.settled(w.engine.start(flow, mode: .live, why: "t"))
        #expect(run?.status != .done)
        #expect(w.host.calls.filter { $0.tool == "changes.it" }.count == 1)
        #expect(run?.problem?.contains("check") == true, "\(run?.problem ?? "")")
    }

    @Test func oneCheckThatCanChangeIsEnoughEvenBesideOneThatSaysNothing() async throws {
        let w = try World()
        w.host.answers["changes.it"] = [Actions.Outcome(status: .ok, text: "pending", summary: ""), Actions.Outcome(status: .ok, text: "done", summary: "")]
        let flow = try w.flow([["id": "again", "repeat": [Self.send], "until": ["value": "{{send}}", "test": "contains", "than": "done", "or": [["value": "{{input.cancel}}", "test": "is", "than": "yes"]]], "times": 4]])
        let run = await w.settled(w.engine.start(flow, mode: .live, why: "t"))
        #expect(run?.status == .done, "\(run?.problem ?? "")")
        #expect(w.host.calls.filter { $0.tool == "changes.it" }.count == 2)
    }

    @Test func wordsACheckDoesntCompareWithDontCount() async throws {
        let w = try World()
        w.host.answers["reads.it"] = [Actions.Outcome(status: .ok, text: "there", summary: "")]
        w.host.answers["changes.it"] = (0..<9).map { _ in Actions.Outcome(status: .ok, text: "Sent", summary: "") }
        let flow = try w.flow([["id": "earlier", "do": "reads.it"], ["id": "again", "repeat": [Self.send], "until": ["value": "{{earlier}}", "test": "is_empty", "than": "{{send}}"], "times": 4]])
        let run = await w.settled(w.engine.start(flow, mode: .live, why: "t"))
        #expect(run?.status != .done)
        #expect(w.host.calls.filter { $0.tool == "changes.it" }.count == 1)
    }

    @Test func aRepeatsOwnItemIsItsGoAndCanEndIt() async throws {
        let (run, sent) = try await sends([Self.send], until: ["value": "{{item}}", "test": "is", "than": "2"])
        #expect(run?.status == .done, "\(run?.problem ?? "")")
        #expect(sent == 2)
    }

    @Test func insideAListTheItemCantChangeByGoingRound() async throws {
        let w = try World()
        w.host.answers["changes.it"] = (0..<9).map { _ in Actions.Outcome(status: .ok, text: "Sent", summary: "") }
        let flow = try w.flow([["id": "each", "for_each": "a", "steps": [["id": "again", "repeat": [Self.send], "until": ["value": "{{item}}", "test": "is", "than": "b"], "times": 4]]]])
        let run = await w.settled(w.engine.start(flow, mode: .live, why: "t"))
        #expect(w.host.calls.filter { $0.tool == "changes.it" }.count == 1, "\(run?.problem ?? "")")
    }

    @Test func whenItStopsItNamesWhatItLooksAtWhereverThatIsWritten() async throws {
        let w = try World()
        w.host.answers["reads.it"] = [Actions.Outcome(status: .ok, text: "there", summary: "")]
        w.host.answers["changes.it"] = (0..<9).map { _ in Actions.Outcome(status: .ok, text: "Sent", summary: "") }
        let flow = try w.flow([["id": "earlier", "do": "reads.it"], ["id": "again", "repeat": [Self.send], "until": ["value": "done", "test": "contains", "than": "{{earlier}}"], "times": 4]])
        let run = await w.settled(w.engine.start(flow, mode: .live, why: "t"))
        #expect(run?.status != .done)
        #expect(run?.problem?.contains("earlier") == true, "\(run?.problem ?? "")")
    }

    @Test func aGoThatCountsCanSayHowManyTimes() async throws {
        let (run, sent) = try await sends([Self.send], until: ["value": "{{index}}", "test": "is", "than": "2"])
        #expect(run?.status == .done, "\(run?.problem ?? "")")
        #expect(sent == 2)
    }

    @Test func aReadOfAToolThatsAwayIsntSomethingDone() throws {
        let w = try World()
        w.catalog.use(Actions.Listing(tools: []))
        let away = try #require(try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "s", "do": "ext.gone.look"]]]).step("s"))
        #expect(!away.doesSomething(w.catalog), "it comes back through here if it comes back")
        let unlisted = try #require(try FlowCodec.body(["trigger": ["type": "manual"], "steps": [Self.send]]).step("send"))
        #expect(unlisted.doesSomething(w.catalog), "not listed isn't away: it can still run, and nothing here says it only reads")
    }

    @Test func aFlowSetOffFromInsideCountsAsSomethingDone() async throws {
        let w = try World()
        var other = try w.flow([["id": "t", "text": "x"]])
        other.name = "Other"
        w.store.save(other)
        let flow = try w.flow([["id": "again", "repeat": [["id": "f", "run_flow": "Other"]], "until": ["value": "{{f}}", "test": "not_empty"], "times": 4]])
        let run = await w.settled(w.engine.start(flow, mode: .live, why: "t"))
        #expect(run?.status != .done)
        #expect(w.store.runs(of: other.id).count == 1, "set off once, not once a go")
    }

    @Test func aDeliberateTryAgainStillGoesRound() async throws {
        let (run, sent) = try await sends([Self.send], until: ["value": "{{send}}", "test": "contains", "than": "done"], answer: "not yet")
        #expect(run?.status != .done, "it ran out of goes")
        #expect(sent == 4, "it answered, and that isn't what it's waiting for: asking again is what this flow says to do")
    }

    @Test func aWriteNotReachedYetDoesntStopIt() async throws {
        let w = try World()
        w.host.answers["reads.it"] = [Actions.Outcome(status: .ok, text: "no", summary: ""), Actions.Outcome(status: .ok, text: "yes", summary: "")]
        w.host.answers["changes.it"] = [Actions.Outcome(status: .ok, text: "Sent", summary: "")]
        let flow = try w.flow([["id": "again", "repeat": [["id": "poll", "do": "reads.it"], ["id": "m", "if": ["value": "{{poll}}", "test": "is", "than": "yes"], "then": [Self.send], "else": []]],
                                "until": ["value": "{{send}}", "test": "not_empty"], "times": 5]])
        let run = await w.settled(w.engine.start(flow, mode: .live, why: "t"))
        #expect(run?.status == .done, "\(run?.problem ?? "")")
        #expect(w.host.calls.filter { $0.tool == "changes.it" }.count == 1)
    }

    @Test func whatItRememberedComesBackAfterARestart() throws {
        var frame = Run.Frame(kind: .loop, step: "s")
        frame.wrote = true
        let w = try World()
        let flow = try w.flow([["id": "a", "text": "x"]])
        var run = Run(id: "r", flow: flow.id, flowName: "F", mode: .live, status: .waiting, why: "t", startedAt: w.now, body: flow.draft)
        run.frames = [frame]
        w.store.save(run)
        w.restart()
        #expect(w.store.run("r")?.frames.first?.wrote == true)
    }

    @Test func itGoesRoundUntilItHoldsAndGivesWhatTheLastGoMade() async throws {
        let w = try World()
        answers(w, ["no", "not yet", "ready now", "never reached"])
        let run = await w.settled(w.engine.start(try w.flow([again(), ["id": "after", "text": "Got {{again}}"]]), mode: .live, why: "t"))
        #expect(run?.status == .done, "\(run?.problem ?? "")")
        #expect(w.host.calls.count == 3, "it stopped as soon as it held")
        #expect(run?.values.value("after") == "Got ready now")
        #expect(run?.record(of: "again")?.status == .done)
        #expect(run?.values.named["look"] == nil, "what's inside is gone afterwards")
        #expect(run?.frames.isEmpty == true)
    }

    @Test func whatItCantSeeStopsItRatherThanGoingRound() async throws {
        let w = try World()
        w.host.answers["reads.it"] = [Actions.Outcome(status: .ok, text: "Service unavailable", summary: "")]
        let flow = try w.flow([["id": "r", "repeat": [["id": "c", "do": "reads.it"]], "until": ["value": "{{c.status}}", "test": "is", "than": "done"], "times": 5]])
        let run = await w.settled(w.engine.start(flow, mode: .live, why: "t"))
        #expect(run?.status == .failed, "words have no status to wait for")
        #expect(w.host.calls.filter { $0.tool == "reads.it" }.count == 1, "and it doesn't ask four more times")
    }

    @Test func itGivesTheLastThatMadeSomething() async throws {
        let w = try World()
        let flow = try w.flow([["id": "r", "repeat": [["id": "a", "text": "made"], ["id": "b", "if": ["value": "x", "test": "is", "than": "y"], "then": [["id": "c", "text": "other"]]]], "until": ["value": "yes", "test": "contains", "than": "yes"], "times": 3],
                               ["id": "t", "text": "{{r}}"]])
        let run = await w.settled(w.engine.start(flow, mode: .live, why: "t"))
        #expect(run?.record(of: "t")?.output == "made", "the path not taken made nothing")
    }

    @Test func aBlankCheckIsMarkedAndDoesntGoLive() throws {
        let body = FlowBody(steps: [Step(id: "r", kind: .repeatUntil(until: Condition(value: " ", test: .contains, than: "x"), times: 3, steps: [Step(id: "a", kind: .text("x"))]))])
        #expect(body.blank != nil)
    }

    @Test func insideAListItsItemIsTheListsItem() async throws {
        let w = try World()
        w.catalog.use(Actions.Listing(tools: [Actions.Tool(name: "changes.it", title: "Change", schema: #"{"properties":{"text":{"type":"string"}}}"#)]))
        w.host.answers["changes.it"] = [Actions.Outcome(status: .ok, text: "no", summary: ""), Actions.Outcome(status: .ok, text: "sent", summary: ""), Actions.Outcome(status: .ok, text: "sent", summary: "")]
        let flow = try w.flow([["id": "e", "for_each": "alice\nbob", "steps": [
            ["id": "r", "repeat": [["id": "s", "do": "changes.it", "with": ["text": "mail {{item}} try {{index}}"]]], "until": ["value": "{{s}}", "test": "contains", "than": "sent"], "times": 3]]]])
        let run = await w.settled(w.engine.start(flow, mode: .live, why: "t"))
        #expect(run?.status == .done)
        let sent = w.host.calls.filter { $0.tool == "changes.it" }.compactMap { $0.input["text"] as? String }
        #expect(sent == ["mail alice try 1", "mail alice try 2", "mail bob try 1"], "not the go number going to a real action")
    }

    @Test func whatTheCheckCanUseIsOfferedForIt() throws {
        let w = try World()
        let app = App(folder: w.folder.appendingPathComponent("app"))
        let flow = app.newFlow(name: "F", body: try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "r", "repeat": [["id": "look", "text": "x"]], "until": ["value": "{{look}}", "test": "contains", "than": "done"], "times": 3]]]))
        app.nav.inspect(.step("r"), in: flow.id)
        let words = Inspector.sections(flow, app, problems: []).map { "\($0)" }.joined()
        #expect(words.contains("{{look}}"), "what it makes each go is what it can stop on")
        #expect(words.contains("{{index}}"))
    }

    @Test func aCheckWithNothingToCompareIsMarked() throws {
        let w = try World()
        let body = FlowBody(steps: [Step(id: "r", kind: .repeatUntil(until: Condition(value: "{{a}}", test: .contains, than: ""), times: 3, steps: [Step(id: "a", kind: .text("x"))]))])
        #expect(body.problems(w.catalog).contains { $0.step == "r" }, "it would never hold, and every go would run")
    }

    @Test func goingOnFromAWriteThatMayHaveHappenedDoesntGoRoundAgain() async throws {
        let w = try World()
        w.host.answers["changes.it"] = [Actions.Outcome(status: .error, text: "broken", summary: "")]
        let flow = try w.flow([["id": "r", "repeat": [["id": "send", "do": "changes.it", "with": ["text": "x"], "on_failure": "carry_on"]], "until": ["value": "{{send}}", "test": "contains", "than": "sent"], "times": 5]])
        let run = await w.settled(w.engine.start(flow, mode: .live, why: "t"))
        #expect(run?.status == .failed, "it gave nothing, so whether to go again can't be read from it")
        #expect(w.host.calls.filter { $0.tool == "changes.it" }.count == 1, "it doesn't send again")
    }

    @Test func aReadThatAnswersNothingYetKeepsPolling() async throws {
        let w = try World()
        w.host.answers["reads.it"] = [Actions.Outcome(status: .ok, text: "", summary: ""), Actions.Outcome(status: .ok, text: "ready", summary: "")]
        let flow = try w.flow([["id": "r", "repeat": [["id": "c", "do": "reads.it"]], "until": ["value": "{{c}}", "test": "contains", "than": "ready"], "times": 5]])
        let run = await w.settled(w.engine.start(flow, mode: .live, why: "t"))
        #expect(run?.status == .done, "asking again is what a poll is for")
        #expect(w.host.calls.filter { $0.tool == "reads.it" }.count == 2)
    }

    @Test func aDrainedQueueStopsIt() async throws {
        let w = try World()
        w.host.answers["reads.it"] = [Actions.Outcome(status: .ok, text: "", summary: "")]
        let flow = try w.flow([["id": "r", "repeat": [["id": "c", "do": "reads.it"]], "until": ["value": "{{c}}", "test": "is_empty"], "times": 5]])
        let run = await w.settled(w.engine.start(flow, mode: .live, why: "t"))
        #expect(run?.status == .done, "that's what it was waiting for")
        #expect(w.host.calls.filter { $0.tool == "reads.it" }.count == 1)
    }

    @Test func aWriteThatGaveNothingDoesntStopAConditionThatHolds() async throws {
        let w = try World()
        w.host.answers["changes.it"] = [Actions.Outcome(status: .error, text: "broken", summary: "")]
        let flow = try w.flow([["id": "r", "repeat": [["id": "a", "text": "done"], ["id": "b", "do": "changes.it", "with": ["text": "x"], "on_failure": "carry_on"]],
                                "until": ["value": "{{a}}", "test": "contains", "than": "done", "or": [["value": "{{b}}", "test": "contains", "than": "sent"]]], "times": 5]])
        let run = await w.settled(w.engine.start(flow, mode: .live, why: "t"))
        #expect(run?.status == .done)
        #expect(w.host.calls.filter { $0.tool == "changes.it" }.count == 1)
    }

    @Test func onlyWhatsThereWhenItLooksIsOffered() throws {
        let w = try World()
        let app = App(folder: w.folder.appendingPathComponent("app"))
        let flow = app.newFlow(name: "F", body: try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "r", "repeat": [["id": "look", "text": "x"], ["id": "e", "for_each": "a", "steps": [["id": "deep", "text": "y"]]]], "until": ["value": "plain", "test": "contains", "than": "done"], "times": 3]]]))
        app.nav.inspect(.step("r"), in: flow.id)
        let words = Inspector.sections(flow, app, problems: []).map { "\($0)" }.joined()
        #expect(words.contains("{{look}}"), "not just because the field says so: this check says “plain”")
        #expect(!words.contains("{{deep}}"), "gone by the time it looks")
    }

    @Test func aTimesThatIsntANumberIsRefused() {
        let raw: [String: Any] = ["trigger": ["type": "manual"], "steps": [["id": "r", "repeat": [["id": "a", "text": "x"]], "until": ["value": "{{a}}", "test": "not_empty"], "times": "5"]]]
        #expect(throws: Problem.self) { try FlowCodec.body(raw) }
    }

    @Test func itFailsAtTheLimitAndDoesNoMore() async throws {
        let w = try World()
        answers(w, Array(repeating: "no", count: 9))
        let run = await w.settled(w.engine.start(try w.flow([again(times: 3), ["id": "after", "text": "x"]]), mode: .live, why: "t"))
        #expect(w.host.calls.count == 3)
        #expect(run?.status == .failed, "the same as any step that fails with nothing to do about it")
        #expect(run?.problem?.contains("3") == true)
        #expect(run?.record(of: "after") == nil)
    }

    @Test func atTheLimitItCanCarryOnIfTheStepSaysSo() async throws {
        let w = try World()
        answers(w, Array(repeating: "no", count: 9))
        let run = await w.settled(w.engine.start(try w.flow([again(times: 2, extra: ["on_failure": "carry_on"]), ["id": "after", "text": "x"]]), mode: .live, why: "t"))
        #expect(run?.status == .done)
        #expect(run?.record(of: "again")?.status == .failed)
        #expect(run?.record(of: "after")?.status == .done)
    }

    @Test func aRestartInTheMiddleComesBackAtTheSameGo() async throws {
        let w = try World()
        answers(w, ["no"])
        w.host.hold = nil
        let flow = try w.flow([again(times: 5, steps: [["id": "look", "do": "reads.it"], ["id": "rest", "wait_minutes": 10]])])
        let run = try #require(w.engine.start(flow, mode: .live, why: "t"))
        await w.quiet()
        #expect(w.store.run(run.id)?.status == .waiting)
        answers(w, ["ready"])
        w.restart()
        w.engine.recover()
        w.now = w.now.addingTimeInterval(11 * 60)
        w.engine.tick()
        await w.quiet()
        #expect(w.store.run(run.id)?.frames.first?.index == 1, "the second go")
        w.now = w.now.addingTimeInterval(11 * 60)
        w.engine.tick()
        await w.quiet()
        #expect(w.store.run(run.id)?.status == .done)
        #expect(w.host.calls.count == 2)
    }

    @Test func stopHoldsInsideIt() async throws {
        let w = try World()
        answers(w, Array(repeating: "no", count: 9))
        let flow = try w.flow([again(times: 5, steps: [["id": "look", "do": "reads.it"], ["id": "rest", "wait_minutes": 10]])])
        let run = try #require(w.engine.start(flow, mode: .live, why: "t"))
        await w.quiet()
        w.engine.stop(run: run.id)
        w.now = w.now.addingTimeInterval(3600)
        w.engine.tick()
        await w.quiet()
        #expect(w.store.run(run.id)?.status == .stopped)
        #expect(w.host.calls.count == 1)
    }

    @Test func practiceGoesRoundOnce() async throws {
        let w = try World()
        let flow = try w.flow([again(times: 50)], state: .draft)
        let run = await w.settled(w.engine.start(flow, mode: .practice, why: "t"))
        await w.quiet()
        #expect(run?.status == .done, "\(run?.problem ?? "")")
        #expect(w.host.calls.filter { $0.tool == "reads.it" }.count <= 1)
        #expect(w.store.run(run!.id)?.record(of: "again")?.status == .would)
    }

    @Test func aFailureInsideGoesToAnEnclosingTry() async throws {
        let w = try World()
        w.host.answers["reads.it"] = [Actions.Outcome(status: .error, text: "broken")]
        let flow = try w.flow([["id": "t", "try": [again()], "recover": [["id": "r", "text": "Caught {{error}}"]]]])
        let run = await w.settled(w.engine.start(flow, mode: .live, why: "t"))
        #expect(run?.status == .done)
        #expect(run?.values.value("r") == "Caught broken")
        #expect(run?.frames.isEmpty == true)
    }

    @Test func itReadsBackExactly() throws {
        let raw: [String: Any] = ["trigger": ["type": "manual"], "steps": [again(times: 7, extra: ["name": "Keep looking"])]]
        let body = try FlowCodec.body(raw)
        #expect(try FlowCodec.body(FlowCodec.json(body)) == body)
        #expect(throws: Problem.self) { _ = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [self.again(times: 500)]]) }
        #expect(throws: Problem.self) { _ = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "a", "repeat": [["id": "x", "text": "y"]]]]]) }
    }

    @Test func whatItLooksAtCanComeFromInsideAndNowhereElse() throws {
        let w = try World()
        #expect(try w.flow([again()]).draft.problems(w.catalog).isEmpty)
        let flow = try w.flow([["id": "again", "repeat": [["id": "look", "do": "reads.it"]], "until": ["value": "{{nowhere}}", "test": "contains", "than": "x"]]])
        #expect(flow.draft.problems(w.catalog).contains { $0.step == "again" })
        let empty = try w.flow([["id": "again", "repeat": [], "until": ["value": "", "test": "contains", "than": ""]]])
        #expect(empty.draft.problems(w.catalog).count >= 2)
        // Outside it, what's inside is gone: only its own result stays.
        let after = try w.flow([again(), ["id": "t", "text": "{{look}}"]])
        #expect(after.draft.problems(w.catalog).contains { $0.step == "t" })
    }

    @Test func theCardSaysTheHigherLimitLoopsTake() throws {
        let w = try World()
        #expect(w.engine.livePlan(try w.flow([again()], state: .draft)).perDay == Engine.loopsPerDay)
    }

    @Test func thePageAddsAndEditsIt() async throws {
        let w = try World()
        let app = App(folder: w.folder.appendingPathComponent("app"))
        let flow = app.newFlow(name: "F", body: try FlowCodec.body(["trigger": ["type": "manual"], "steps": [again(times: 4)]]))
        func op(_ name: String, _ extra: [String: Any]) async throws {
            var input: [String: Any] = ["op": name, "flow": flow.id, "step": "again"]
            input.merge(extra) { _, new in new }
            _ = try await Actions_UI.handle(Arguments(input), app)
        }
        try await op("repeat_times", ["text": "9"])
        try await op("cond_value", ["text": "{{look}}", "check": 0])
        try await op("cond_than", ["text": "done", "check": 0])
        try await op("cond_add", [:])
        guard case .repeatUntil(let until, let times, _)? = app.store.flow(flow.id)?.draft.step("again")?.kind else { Issue.record("not a repeat"); return }
        #expect(times == 9)
        #expect(until.than == "done")
        #expect(until.also.count == 1)
        await #expect(throws: Problem.self) { try await op("repeat_times", ["text": "1000"]) }
        let page = await Pages.make(app, state: Arguments(["flow": flow.id]), background: false)
        #expect(!page.sections.isEmpty)
    }

    @Test func aRepeatRenamesAndDuplicatesLikeAnyStep() throws {
        let body = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [again(steps: [["id": "look", "do": "reads.it"], ["id": "c", "call_flow": "Old"]])]])
        let renamed = body.calling("Old", instead: "New")
        #expect(renamed.step("c").map { if case .call("New", _) = $0.kind { true } else { false } } == true)
        #expect(body.allSteps.count == 3)
    }
}
