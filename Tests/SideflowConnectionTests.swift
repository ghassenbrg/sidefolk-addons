import Foundation
import Testing
@testable import ext_sideflow
import SidefolkExtensionKit

/// What Connections has to do: a run waits for a tool that went away, and it says so.
@MainActor @Suite(.serialized) struct SideflowConnectionTests {
    typealias World = SideflowTests.World

    static let tools = [
        Actions.Tool(name: "reads.it", title: "Read it", mutates: false, readsOnly: true),
        Actions.Tool(name: "ext.gh.pr", title: "Open a request", mutates: true, extensionName: "gh", extensionTitle: "GitHub tools", fromServer: true),
    ]

    private func gone(_ w: World) { w.catalog.use(Actions.Listing(tools: [Self.tools[0]])) }
    private func back(_ w: World) { w.catalog.use(Actions.Listing(tools: Self.tools)) }

    private func flow(_ w: World) throws -> Flow {
        try w.flow([["id": "pr", "do": "ext.gh.pr", "with": ["title": "x"]], ["id": "after", "text": "done"]])
    }

    @Test func aRunWaitsForWhatsMissingAndGoesOnWhenItsBack() async throws {
        let w = try World()
        gone(w)
        let run = try #require(w.engine.start(try flow(w), mode: .live, why: "t"))
        await w.quiet()
        let waiting = try #require(w.store.run(run.id))
        #expect(waiting.status == .waiting)
        #expect(waiting.connection?.tool == "ext.gh.pr")
        #expect(w.host.calls.isEmpty, "nothing was done")
        #expect(w.host.notices.count == 1)
        w.engine.tick()
        await w.quiet()
        #expect(w.store.run(run.id)?.status == .waiting, "still not here")
        #expect(w.host.notices.count == 1, "said once")
        back(w)
        w.engine.tick()
        w.engine.tick()
        await w.quiet()
        let done = try #require(w.store.run(run.id))
        #expect(done.status == .done)
        #expect(done.connection == nil)
        #expect(w.host.calls.map(\.tool) == ["ext.gh.pr"], "once, however many looks")
    }

    @Test func aRestartKeepsTheWait() async throws {
        let w = try World()
        gone(w)
        let run = try #require(w.engine.start(try flow(w), mode: .live, why: "t"))
        await w.quiet()
        let until = try #require(w.store.run(run.id)?.connection?.until)
        w.restart()
        w.engine.recover()
        w.engine.tick()
        await w.quiet()
        #expect(w.store.run(run.id)?.status == .waiting)
        #expect(w.store.run(run.id)?.connection?.until == until, "the wait isn't made longer by coming back")
        #expect(w.engine.isRunning(run.flow))
        back(w)
        w.engine.tick()
        await w.quiet()
        #expect(w.store.run(run.id)?.status == .done)
    }

    @Test func aWaitTooLongAsksThePerson() async throws {
        let w = try World()
        gone(w)
        let run = try #require(w.engine.start(try flow(w), mode: .live, why: "t"))
        await w.quiet()
        w.now = w.now.addingTimeInterval(Connections.longestWait + 1)
        w.engine.tick()
        await w.quiet()
        let asked = try #require(w.store.run(run.id))
        #expect(asked.status == .needs_you)
        #expect(asked.connection == nil)
        #expect(asked.problem?.contains("GitHub") == false, "never seen by this store, so it goes by its id")
        #expect(w.host.calls.isEmpty)
        back(w)
        w.engine.proceed(run.id, .try_again)
        await w.quiet()
        #expect(w.store.run(run.id)?.status == .done)
    }

    @Test func stopAndSkipBothEndTheWait() async throws {
        let w = try World()
        gone(w)
        let body = try flow(w)
        let stopped = try #require(w.engine.start(body, mode: .live, why: "t"))
        await w.quiet()
        w.engine.stop(run: stopped.id)
        #expect(w.store.run(stopped.id)?.status == .stopped)
        #expect(w.store.run(stopped.id)?.connection == nil)
        #expect(!w.engine.isRunning(body.id))
        back(w)
        w.engine.tick()
        await w.quiet()
        #expect(w.host.calls.isEmpty, "a stopped run stays stopped")
        gone(w)
        let skipped = try #require(w.engine.start(body, mode: .live, why: "t"))
        await w.quiet()
        w.engine.proceed(skipped.id, .carry_on)
        await w.quiet()
        let after = try #require(w.store.run(skipped.id))
        #expect(after.status == .done)
        #expect(after.record(of: "pr")?.status == .skipped)
        #expect(w.host.calls.isEmpty)
    }

    @Test func aToolThatLeftBetweenLooksWaitsToo() async throws {
        let w = try World()
        back(w)
        w.host.answers["ext.gh.pr"] = [Actions.Outcome(status: .unavailable, text: "gone")]
        let run = try #require(w.engine.start(try flow(w), mode: .live, why: "t"))
        await w.quiet()
        #expect(w.store.run(run.id)?.status == .waiting)
        #expect(w.host.calls.count == 1)
        w.engine.tick()
        await w.quiet()
        #expect(w.store.run(run.id)?.status == .done, "the list says it's here, and this time it answers")
    }

    @Test func aPausedFlowsRunWaitsOnWhenItsToolComesBack() async throws {
        let w = try World()
        gone(w)
        let flow = try flow(w)
        let run = try #require(w.engine.start(flow, mode: .live, why: "t"))
        await w.quiet()
        w.engine.pause(flow.id)
        await w.quiet()
        back(w)
        w.engine.tick()
        await w.quiet()
        #expect(!w.host.calls.contains { $0.tool == "ext.gh.pr" }, "Pause means it: nothing goes without them")
        #expect(w.store.run(run.id)?.connection != nil)
        w.engine.resume(flow.id)
        await w.quiet()
        w.engine.tick()
        await w.quiet()
        #expect(w.host.calls.contains { $0.tool == "ext.gh.pr" })
    }

    @Test func aPausedFlowSaysPausedWhileItsRunWaits() async throws {
        let w = try World()
        let app = App(folder: w.folder.appendingPathComponent("app"))
        app.engine.host = w.host
        app.catalog.use(Actions.Listing(tools: [Self.tools[0]]))
        var flow = app.newFlow(name: "F", body: try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "pr", "do": "ext.gh.pr"]]]))
        flow.live = flow.draft
        flow.state = .on
        app.store.save(flow)
        _ = try #require(app.engine.start(flow, mode: .live, why: "t"))
        await w.quiet(app.store)
        app.engine.pause(flow.id)
        await w.quiet(app.store)
        #expect(Pages.stateWord(try #require(app.store.flow(flow.id)), app).0 == L("Paused"))
    }

    @Test func aToolGoneFromAnExtensionThatsStillHereIsNoMissingConnection() async throws {
        let w = try World()
        w.catalog.use(Actions.Listing(tools: [Self.tools[0], Actions.Tool(name: "ext.gh.other", title: "Other", mutates: false, readsOnly: true, extensionName: "gh", extensionTitle: "GitHub")]))
        w.host.answers["ext.gh.pr"] = [Actions.Outcome(status: .unavailable, text: "It isn't here.")]
        let flow = try flow(w)
        let run = try #require(w.engine.start(flow, mode: .live, why: "t"))
        await w.quiet()
        #expect(w.store.run(run.id)?.status == .needs_you, "it won't come back by waiting a week")
        #expect(w.store.run(run.id)?.connection == nil)
        let said = flow.running.problems(w.catalog).map(\.text).joined()
        #expect(!said.contains("isn't here"))
    }

    @Test func aFlowsOwnToolIsNoConnection() async throws {
        #expect(Connections.id(of: "ext.sideflow.run_flow") == nil)
        #expect(Connections.id(of: "ext.gh.pr") == "gh")
    }

    @Test func aWaitThatRanOutAsksEvenIfTheToolIsBack() async throws {
        let w = try World()
        gone(w)
        let run = try #require(w.engine.start(try flow(w), mode: .live, why: "t"))
        await w.quiet()
        w.now = w.now.addingTimeInterval(Connections.longestWait + 1)
        back(w)
        w.engine.tick()
        await w.quiet()
        #expect(w.store.run(run.id)?.status == .needs_you, "three weeks on, it's for them to say")
        #expect(!w.host.calls.contains { $0.tool == "ext.gh.pr" })
    }

    @Test func sidefolksOwnToolIsNoConnection() async throws {
        let w = try World()
        w.host.answers["notes.save"] = [Actions.Outcome(status: .unavailable, text: "Not here")]
        let run = try #require(w.engine.start(try w.flow([["id": "a", "do": "notes.save", "with": ["text": "x"]]]), mode: .live, why: "t"))
        await w.quiet()
        #expect(w.store.run(run.id)?.status == .needs_you)
        #expect(w.store.run(run.id)?.connection == nil)
    }

    @Test func practiceDoesntWait() async throws {
        let w = try World()
        gone(w)
        let body = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "pr", "do": "ext.gh.pr", "with": ["title": "x"]]]])
        var draft = try flow(w)
        draft.draft = body
        w.store.save(draft)
        w.host.decision = .unknown
        let run = try #require(w.engine.start(draft, mode: .practice, why: "t"))
        let done = await w.settled(run)
        #expect(done?.status != .waiting)
        #expect(done?.connection == nil)
        #expect(done?.record(of: "pr")?.note?.contains("isn't here") == true)
    }

    @Test func aCalledFlowWaitsAndItsCallerWithIt() async throws {
        let w = try World()
        gone(w)
        var child = try flow(w)
        child.name = "Child"
        w.store.save(child)
        let run = try #require(w.engine.start(try w.flow([["id": "c", "call_flow": "Child"]]), mode: .live, why: "t"))
        await w.quiet()
        #expect(w.store.run(run.id)?.status == .waiting)
        #expect(w.store.runs(of: child.id).first?.connection != nil)
        back(w)
        w.engine.tick()
        await w.quiet()
        #expect(w.store.run(run.id)?.status == .done)
        #expect(w.store.runs(of: child.id).first?.status == .done)
    }

    @Test func thePageSaysWhatsMissingWhoUsesItAndWhatWaits() async throws {
        let w = try World()
        back(w)
        Connections.remember(w.catalog, w.store)
        var used = try flow(w)
        used.name = "Open requests"
        w.store.save(used)
        #expect(Connections.all(w.catalog, w.store).first?.isHere == true)
        #expect(Connections.missing(used, w.catalog, w.store).isEmpty)
        gone(w)
        let run = try #require(w.engine.start(used, mode: .live, why: "t"))
        await w.quiet()
        let c = try #require(Connections.all(w.catalog, w.store).first)
        #expect(c.title == "GitHub tools", "remembered, because nothing else can say it now")
        #expect(c.server)
        #expect(!c.isHere)
        #expect(c.flows == ["Open requests"])
        #expect(c.waiting == [run.id])
        #expect(Connections.missing(used, w.catalog, w.store) == ["GitHub tools"])
        w.restart()
        #expect(w.store.connectionNames["gh"] == "GitHub tools", "kept on disk too")
        #expect(Connections.id(of: "notes.save") == nil)
        #expect(w.catalog.title(of: "ext.gh.pr") == "Open a request", "and never its id")
        #expect(w.catalog.title(of: "ext.other.make_it") == "Make it")
        #expect(used.draft.problems(w.catalog).contains { $0.text.contains("GitHub tools") })
    }
}
