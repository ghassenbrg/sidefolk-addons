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
    /// What the plan would be if approved now, by flow: Sidefolk's own answer, with nothing shown or changed.
    var planChecks: [String: PlanLook] = [:]
    /// Where what sets a flow off sits among its steps' checks.
    static let triggerCheck = "start"
    /// A request to the AI to draft a flow, while it runs, and what came of the last.
    var drafting: String?
    var draftProblem: String?
    var startDelay: Double = 8

    init(folder: URL) {
        store = FlowStore(folder: folder)
        engine = Engine(store: store, catalog: catalog)
        Connections.remember(catalog, store)
        engine.host = host
    }

    /// While the program runs. Sidefolk starts its extensions one after another, so the tools a flow needs may not be there in the first moments:
    /// it looks after a moment, so that what's mid-air is judged, and what's due is run, with the whole list in hand.
    func run() async {
        try? await Task.sleep(for: .seconds(startDelay))
        await catalog.refresh()
        var lookedForWhatNobodyRead = firstLook()
        while !Task.isCancelled {
            await catalog.refresh()
            Connections.remember(catalog, store)
            // Once, with the list in hand: without it, it would look as if nothing had been allowed.
            if !lookedForWhatNobodyRead, catalog.loadedAt != nil {
                lookedForWhatNobodyRead = true
                engine.pauseWhatNobodyRead()
            }
            engine.tick()
            try? await Task.sleep(for: .seconds(30))
        }
    }

    /// An agent changed it from outside: steps back on the page would go past that, with nothing to say so.
    func saved(byAnAgent id: String) { history[id] = nil }
    /// Whether what nobody read got looked for. Before anything goes on, so it doesn't get one more step first.
    @discardableResult func firstLook() -> Bool {
        let can = catalog.loadedAt != nil
        if can { engine.pauseWhatNobodyRead() }
        engine.recover()
        return can
    }

    func flow(named words: String) throws -> Flow {
        guard let flow = store.find(words) else {
            throw Problem(L("I don't have a flow called “{name}”. You have: {list}.", ["name": words, "list": store.flows().map(\.name).joined(separator: ", ")]))
        }
        return flow
    }

    func newFlow(name: String, body: FlowBody) -> Flow {
        var base = name.nonEmpty ?? L("New flow"), n = 2
        while store.nameInUse(base) {
            base = "\(name.nonEmpty ?? L("New flow")) \(n)"
            n += 1
        }
        let now = Date()
        let flow = Flow(id: String(UUID().uuidString.lowercased().prefix(8)), name: base, draft: body, createdAt: now, updatedAt: now)
        store.save(flow)
        return flow
    }

    /// A new name, and every step that names it goes with it: what sets a flow off or calls it finds it by name, and it's still the same flow.
    func rename(_ flow: inout Flow, to name: String) throws {
        if store.nameInUse(name, except: flow.id) { throw Problem(L("There's already a flow called “{name}”.", ["name": name])) }
        let old = flow.name
        // Only if the steps that name it could only have meant this one.
        let wasTheOne = store.named(old)?.id == flow.id
        flow.name = name
        if wasTheOne { store.rewriteCalls(from: old, to: name, except: flow.id) }
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
            let plan = flow.live == nil ? nil : flow.planId
            for step in flow.draft.allSteps {
                guard case .action(let tool, let input) = step.kind else { continue }
                if let check = await host.check(tool, catalog.filled(tool, input, from: values), plan: plan) { out[step.id] = check }
            }
            // What sets it off is asked about too: a watch on a folder that isn't shared wouldn't start.
            if case .watch(let w) = flow.draft.trigger, let check = await host.check("watch.create", Engine.watchInput(w, title: Engine.watchTitle(flow)), plan: plan) {
                out[Self.triggerCheck] = check
            }
            let plan2 = engine.livePlan(flow)
            let looked = await host.checkPlan(plan2)
            // A slower look from before an edit doesn't overwrite a newer one.
            guard preflightAsked[id] == asked else { return }
            preflight[id] = out
            planChecks[id] = looked.map { PlanLook($0, of: plan2) }
        }
    }
}

/// What Sidefolk says of a flow's plan: how many things are new, and each step's line by the step's name.
struct PlanLook {
    var silent: Bool
    var new: Int
    var byStep: [String: Plans.Checked.Line]

    init(_ checked: Plans.Checked, of plan: Plan) {
        silent = checked.silent
        new = Set(checked.new.compactMap { plan.steps.indices.contains($0) ? plan.steps[$0].line : nil }).count
        byStep = Dictionary(zip(plan.steps, checked.steps).compactMap { step, line in step.named.map { ($0, line) } }, uniquingKeysWith: { first, _ in first })
    }

    /// What the flow's head says before anyone presses anything.
    var head: String {
        silent || new == 0 ? L("Nothing new to allow") : L(one: "{count} new thing to allow", other: "{count} new things to allow", count: new)
    }

    /// What a step's form says of how it'll behave, if that's anything but running by itself.
    static func mark(_ line: Plans.Checked.Line) -> (words: String, tone: Tone)? {
        if line.state == "refused" {
            return (line.why == "code_field" ? L("Write this part yourself: words from outside can't go in here.") : L("Sidefolk won't let a flow do this."), .bad)
        }
        if line.state == "stands_in_full_access" { return (L("Runs by itself only under Full access."), .info) }
        if line.state == "asks" {
            switch line.why {
            case "reach_field": return (L("This says where it goes. Write it here, or it asks each run."), .warn)
            case "server_unpinned": return (L("Its program can't be checked, so it asks each run."), .warn)
            default: return (L("This step will ask each run."), .info)
            }
        }
        if line.warning == "crossing" { return (L("It passes on what this flow reads. The card says so."), .warn) }
        return nil
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
        case connections
    }

    enum Inspecting: Equatable {
        case nothing
        case trigger
        case step(String)
    }

    /// What's selected on each flow's tree. Nothing to start with: the flow itself and what it will give are what there is to read.
    private var inspected: [String: Inspecting] = [:]

    func inspecting(_ flow: Flow) -> Inspecting { inspected[flow.id] ?? .nothing }

    /// The flow whose definition is showing to copy.
    var exporting: String?
    /// What's selected on a run's tree, and which go of a loop.
    var runStep: [String: String] = [:]
    var runScope: [String: String] = [:]

    mutating func inspect(_ what: Inspecting, in flow: String) { inspected[flow] = what }

    /// Where the page's state says it is: Sidefolk keeps it while Home is open, with the way back.
    static func place(_ state: Arguments) -> Place {
        if let run = state.string("run") { return .run(run) }
        if let flow = state.string("flow") { return .flow(flow) }
        switch state.string("view") {
        case "history": return .history
        case "templates": return .templates
        case "connections": return .connections
        default: return .home
        }
    }

    static func open(flow id: String) -> [String: Any] { ["flow": id] }
}
