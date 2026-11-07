import Foundation
import Testing
@testable import ext_sideflow
import SidefolkExtensionKit

/// A flow that calls another one that's off: Turn on asks for both on one card, and each is then kept, ended and changed on its own.
@MainActor @Suite(.serialized) struct SideflowTurnOnTogetherTests {
    typealias World = SideflowTests.World

    /// A caller and the flow it calls, both drafts: "Other" saves a note, so it has something to read on the card.
    private func pair(_ w: World, call: [String: Any] = ["id": "c", "call_flow": "Other"]) throws -> (caller: Flow, other: Flow) {
        var other = try w.flow([["id": "s", "do": "notes.save", "with": ["text": "hello"]]], state: .draft)
        other.name = "Other"
        w.store.save(other)
        var caller = try w.flow([["id": "t", "do": "changes.it", "with": ["text": "x"]], call], state: .draft)
        caller.name = "Caller"
        w.store.save(caller)
        return (caller, other)
    }

    @Test func oneAnswerTurnsBothOn() async throws {
        let w = try World()
        let (caller, other) = try pair(w)
        #expect(w.engine.goesWith(caller)?.id == other.id)
        w.host.planAnswer = .allowed(standing: [true])
        w.host.alsoAnswer = .allowed(standing: [true])
        w.engine.turnOn(caller.id)
        await w.quiet()
        #expect(w.host.alsoPlans.map(\.id) == [other.planId], "the card holds the called flow's own plan, under its own id")
        #expect(w.host.alsoPlans.first?.steps.map(\.tool) == ["notes.save"])
        #expect(w.host.plans.map(\.id) == [caller.planId])
        #expect(w.store.flow(caller.id)?.state == .on)
        #expect(w.store.flow(other.id)?.state == .on)
        #expect(w.store.flow(other.id)?.live == other.draft)
    }

    @Test func noOrChangedTurnsNeitherOn() async throws {
        let w = try World()
        let (caller, other) = try pair(w)
        w.host.planAnswer = .refused("changed")
        w.host.alsoAnswer = .allowed(standing: [true])
        w.engine.turnOn(caller.id)
        await w.quiet()
        #expect(w.store.flow(caller.id)?.state == .draft)
        #expect(w.store.flow(other.id)?.state == .draft)
        #expect(w.store.flow(caller.id)?.startProblem != nil)
    }

    /// A copy of Sidefolk without it shows the caller's card alone: the called flow stays off, and the run says so, as before.
    @Test func anOlderSidefolkTurnsOnTheCallerAlone() async throws {
        let w = try World()
        let (caller, other) = try pair(w)
        w.host.planAnswer = .allowed(standing: [true])
        w.host.alsoAnswer = nil
        w.engine.turnOn(caller.id)
        await w.quiet()
        #expect(w.store.flow(caller.id)?.state == .on)
        #expect(w.store.flow(other.id)?.state == .draft)
    }

    /// Ending the called flow's approval leaves the caller on, and its call then says why it can't run.
    @Test func endingOneLeavesTheOther() async throws {
        let w = try World()
        let (caller, other) = try pair(w)
        w.host.planAnswer = .allowed(standing: [true])
        w.host.alsoAnswer = .allowed(standing: [true])
        w.engine.turnOn(caller.id)
        await w.quiet()
        w.engine.planEnded(other.id)
        #expect(w.store.flow(caller.id)?.state == .on)
        #expect(w.store.flow(other.id)?.state == .paused)
        let run = await w.settled(w.engine.start(try #require(w.store.flow(caller.id)), mode: .live, why: "t"))
        #expect(run?.status == .failed)
        #expect(run?.problem?.contains(L("You ended what you'd allowed in Settings, so it asks again before running.")) == true, "it says which approval ended")
    }

    /// Changing the called flow later asks for it alone; and a caller that names two flows, or one that calls another, gets cards of their own.
    @Test func onlyOneCalledFlowAndNoChains() async throws {
        let w = try World()
        let (caller, other) = try pair(w)
        #expect(w.engine.goesWith(other) == nil, "it calls nothing")
        w.host.planAnswer = .allowed(standing: [true])
        w.engine.turnOn(other.id)
        await w.quiet()
        #expect(w.host.alsoPlans.isEmpty && w.host.plans.map(\.id) == [other.planId])
        #expect(w.engine.goesWith(caller) == nil, "the flow it calls is on already")

        let w2 = try World()
        var third = try w2.flow([["id": "s", "do": "notes.save", "with": ["text": "three"]]], state: .draft)
        third.name = "Third"
        w2.store.save(third)
        let (two, _) = try pair(w2, call: ["id": "c", "call_flow": "Other"])
        var both = try #require(w2.store.flow(two.id))
        both.draft = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "c", "call_flow": "Other"], ["id": "d", "run_flow": "Third"]]])
        w2.store.save(both)
        #expect(w2.engine.goesWith(both) == nil, "two flows named")

        var chained = try #require(w2.store.flow(two.id))
        chained.draft = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "d", "run_flow": "Third"]]])
        w2.store.save(chained)
        var middle = try #require(w2.store.named("Third"))
        middle.draft = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "e", "run_flow": "Other"]]])
        w2.store.save(middle)
        #expect(w2.engine.goesWith(chained) == nil, "what it calls calls another")
    }

    /// The page and the tool say both are asked for.
    @Test func thePageAndAnAgentHearOfBoth() async throws {
        let w = try World()
        let app = App(folder: w.folder.appendingPathComponent("app"))
        app.engine.host = w.host
        _ = app.newFlow(name: "Other", body: try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "s", "do": "notes.save", "with": ["text": "hello"]]]]))
        let caller = app.newFlow(name: "Caller", body: try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "c", "call_flow": "Other"]]]))
        #expect("\(Pages.head(caller, app, ready: true))".contains(L("You read what it and “{name}” will do first, and both are turned on.", ["name": "Other"])))
    }
}
