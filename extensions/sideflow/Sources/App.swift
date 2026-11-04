import Foundation
import SidefolkExtensionKit

/// Everything the program holds while it runs.
@MainActor final class App {
    let store: FlowStore
    let catalog = Catalog()
    let engine: Engine
    let host = SidefolkHost()
    var nav = Nav()
    /// Undo and redo, by flow, while the program runs.
    var history: [String: Editing.History] = [:]
    /// What Guard says of each step now: its sentence and whether it would ask.
    var preflight: [String: [String: Actions.Check]] = [:]
    private var preflightAsked: [String: Date] = [:]
    /// Where what sets a flow off sits among its steps' checks.
    static let triggerCheck = "start"
    /// A request to the AI to draft a flow, while it runs, and what came of the last.
    var drafting: String?
    var draftProblem: String?
    var startDelay: Double = 8

    init(folder: URL) {
        store = FlowStore(folder: folder)
        engine = Engine(store: store, catalog: catalog)
        engine.host = host
    }

    /// While the program runs. Sidefolk starts its extensions one after another, so the tools a flow needs may not be there in the first moments:
    /// it looks after a moment, so that what's mid-air is judged, and what's due is run, with the whole list in hand.
    func run() async {
        try? await Task.sleep(for: .seconds(startDelay))
        await catalog.refresh()
        engine.recover()
        while !Task.isCancelled {
            await catalog.refresh()
            engine.tick()
            try? await Task.sleep(for: .seconds(30))
        }
    }

    func flow(named words: String) throws -> Flow {
        guard let flow = store.find(words) else {
            throw Problem(L("I don't have a flow called “{name}”. You have: {list}.", ["name": words, "list": store.flows().map(\.name).joined(separator: ", ")]))
        }
        return flow
    }

    func newFlow(name: String, body: FlowBody) -> Flow {
        var base = name.nonEmpty ?? L("New flow"), n = 2
        let names = Set(store.flows().map(\.name))
        while names.contains(base) {
            base = "\(name.nonEmpty ?? L("New flow")) \(n)"
            n += 1
        }
        let now = Date()
        let flow = Flow(id: String(UUID().uuidString.lowercased().prefix(8)), name: base, draft: body, createdAt: now, updatedAt: now)
        store.save(flow)
        return flow
    }

    /// What Guard would say of each action now, for the rail: refreshed after any change. Values to fill in are checked with a stand-in.
    /// The rail reads Guard again while a flow is open: a folder shared since, or a trust setting changed, shows without touching the flow.
    func refreshPreflightIfOld(_ id: String) {
        if preflightAsked[id].map({ Date().timeIntervalSince($0) > 2 }) ?? true { refreshPreflight(id) }
    }

    func refreshPreflight(_ id: String) {
        guard let flow = store.flow(id) else { return }
        let asked = Date()
        preflightAsked[id] = asked
        Task {
            if catalog.loadedAt == nil { await catalog.refresh() }
            var out: [String: Actions.Check] = [:]
            var values = Values()
            for step in flow.draft.allSteps where step.hasOutput { values.set(step.id, "…") }
            values.set("trigger", "…")
            let plan = flow.state == .draft ? nil : flow.planId
            for step in flow.draft.allSteps {
                guard case .action(let tool, let input) = step.kind else { continue }
                if let check = await host.check(tool, values.fill(input), plan: plan) { out[step.id] = check }
            }
            // What sets it off is asked about too: a watch on a folder that isn't shared wouldn't start.
            if case .watch(let w) = flow.draft.trigger, let check = await host.check("watch.create", Engine.watchInput(w, title: Engine.watchTitle(flow)), plan: plan) {
                out[Self.triggerCheck] = check
            }
            // A slower look from before an edit doesn't overwrite a newer one.
            guard preflightAsked[id] == asked else { return }
            preflight[id] = out
        }
    }
}

/// Where the page is.
struct Nav {
    enum Place: Equatable {
        case home
        case flow(String)
        case run(String)
        case history
        case templates
    }

    enum Inspecting: Equatable {
        case nothing
        case trigger
        case step(String)
    }

    /// What's selected on each flow's tree. Nothing to start with: the flow itself and what it will give are what there is to read.
    private var inspected: [String: Inspecting] = [:]

    func inspecting(_ flow: Flow) -> Inspecting { inspected[flow.id] ?? .nothing }

    mutating func inspect(_ what: Inspecting, in flow: String) { inspected[flow] = what }

    /// Where the page's state says it is: Sidefolk keeps it while Home is open, with the way back.
    static func place(_ state: Arguments) -> Place {
        if let run = state.string("run") { return .run(run) }
        if let flow = state.string("flow") { return .flow(flow) }
        switch state.string("view") {
        case "history": return .history
        case "templates": return .templates
        default: return .home
        }
    }

    static func open(flow id: String) -> [String: Any] { ["flow": id] }
}
