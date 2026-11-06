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
    /// An agent's last change to each flow, while it's still what's there: what it said and what it replaced.
    var agentEdits: [String: AgentEdit] = [:]
    /// What Guard says of each step now: its sentence and whether it would ask.
    var preflight: [String: [String: Actions.Check]] = [:]
    private var preflightAsked: [String: Date] = [:]
    /// What Sidefolk said of a step as it stands, for a while: a page draws often, and every check counts against what Sidefolk allows an extension a minute.
    private var looked: [String: (at: Date, check: Actions.Check)] = [:]
    static let lookFor: TimeInterval = 30
    /// What the plan would be if approved now, by flow: Sidefolk's own answer, with nothing shown or changed.
    var planChecks: [String: PlanLook] = [:]
    /// The same, of what runs, while the draft differs from it: the Permissions tab says both.
    var runningChecks: [String: PlanLook] = [:]
    /// Where what sets a flow off sits among its steps' checks.
    static let triggerCheck = "start"
    /// A request to the AI to draft a flow, while it runs, and what came of the last.
    var drafting: String?
    var draftProblem: String?
    var startDelay: Double = 8

    /// On the page's own Stop buttons. Another extension can call `ui` too, on a card, but can't read this folder or a page: only with this is it the person pressing Stop.
    let pageKey: String
    let folder: URL

    init(folder: URL) {
        self.folder = folder
        let keyFile = folder.appendingPathComponent("page-key")
        if let kept = try? String(contentsOf: keyFile, encoding: .utf8), !kept.isEmpty {
            pageKey = kept
        } else {
            pageKey = UUID().uuidString
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try? pageKey.write(to: keyFile, atomically: true, encoding: .utf8)
        }
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

    /// Whether the page marks a step by what Sidefolk said of it. A "no" for a step filled from an earlier one is about the "…" standing in for that value,
    /// not about what it will be: it's checked again when it runs, so it isn't marked Not allowed on the board.
    static func shows(_ check: Actions.Check, _ input: [String: JSON]) -> Bool {
        check.decision != .deny || !input.values.flatMap(\.strings).contains { !Values.references($0).isEmpty }
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
                let filled = catalog.filled(tool, input, from: values)
                let key = "\(tool) \(plan ?? "") " + ((try? JSONSerialization.data(withJSONObject: filled, options: [.sortedKeys])).map { String(decoding: $0, as: UTF8.self) } ?? "")
                if let kept = looked[key], Date().timeIntervalSince(kept.at) < Self.lookFor { if Self.shows(kept.check, input) { out[step.id] = kept.check }; continue }
                if let check = await host.check(tool, filled, plan: plan) {
                    if Self.shows(check, input) { out[step.id] = check }
                    looked = looked.filter { Date().timeIntervalSince($0.value.at) < Self.lookFor }
                    looked[key] = (Date(), check)
                }
            }
            // What sets it off is asked about too: a watch on a folder that isn't shared wouldn't start.
            if case .watch(let w) = flow.draft.trigger, let check = await host.check("watch.create", Engine.watchInput(w, title: Engine.watchTitle(flow)), plan: plan) {
                out[Self.triggerCheck] = check
            }
            // What's on the page is what its marks are about.
            var shown = flow
            shown.saved = nil
            let plan2 = engine.livePlan(shown)
            let looked = await host.checkPlan(plan2)
            // What runs is what the person allowed, whatever the draft says now.
            var running: (Plan, Plans.Checked?)?
            if let live = flow.live, live != flow.draft {
                var it = flow
                it.draft = live
                it.saved = nil
                let plan3 = engine.livePlan(it)
                running = (plan3, await host.checkPlan(plan3))
            }
            // A slower look from before an edit doesn't overwrite a newer one.
            guard preflightAsked[id] == asked else { return }
            preflight[id] = out
            planChecks[id] = looked.map { PlanLook($0, of: plan2) }
            runningChecks[id] = running.flatMap { plan, checked in checked.map { PlanLook($0, of: plan) } }
        }
    }
}

/// What Sidefolk says of a flow's plan: how many things are new, and each step's line by the step's name.
struct PlanLook {
    var silent: Bool
    var widened: Bool
    var new: Int
    var byStep: [String: Plans.Checked.Line]
    /// Each line's answer by place in the plan, and the lines it was asked about, each as the card tells them apart: a look at another version, or at this one before
    /// a path in it changed, isn't read against what's shown now.
    var lines: [Plans.Checked.Line]
    var asked: [String]

    init(_ checked: Plans.Checked, of plan: Plan) {
        lines = checked.steps
        asked = plan.steps.map(Self.key)
        silent = checked.silent
        widened = checked.widened
        new = Set(checked.new.compactMap { plan.steps.indices.contains($0) ? plan.steps[$0].line : nil }).count
        byStep = Dictionary(zip(plan.steps, checked.steps).compactMap { step, line in step.named.map { ($0, line) } }, uniquingKeysWith: { first, _ in first })
    }

    /// A line as a look tells it apart: what the card shows of it, and what the host keeps beside it: its name, your words for it, where a field comes from.
    static func key(_ step: PlanStep) -> String {
        "\(step.line) \(step.named ?? "") \(step.title ?? "") \(step.from.map { JSONText.write($0) } ?? "")"
    }

    /// What the flow's head says before anyone presses anything.
    var head: String {
        if new > 0 { return L(one: "{count} new thing to allow", other: "{count} new things to allow", count: new) }
        return !silent && widened ? L("Its limits go further than what you allowed") : L("Nothing new to allow")
    }

    /// What a step's form says of how it'll behave, if that's anything but running by itself.
    static func mark(_ line: Plans.Checked.Line) -> (words: String, tone: Tone)? {
        switch line.why {
        case "code_field": return (L("Write this part yourself: words from outside can't go in here."), .bad)
        case "reach_field": return (L("This says where it goes. Write it here, or it asks each run."), .warn)
        case "server_unpinned": return (L("Its program can't be checked, so it asks each run."), .warn)
        case "shell": return (L("It runs a program, so it asks each run."), .info)
        case "text_to_read": return (L("Its words are read in full each time."), .info)
        case "unreadable_value": return (L("Its words have a line break or a mark the card can't show exactly, so it asks each run. Write them on one line."), .warn)
        case "ask_every_time": return (L("You set Sidefolk to ask every time, so this asks each run."), .info)
        case "switch_off": return (L("Settings › Trust keeps flows from passing what they read on to this, so it asks each run."), .info)
        case "filled_value" where line.state == "stands_in_full_access": return (L("Words an earlier step made go in here, so it runs by itself only under Full access."), .info)
        default: break
        }
        switch line.state {
        case "stands_in_full_access": return (L("Runs by itself only under Full access."), .info)
        case "asks", "refused": return (L("This step will ask each run."), .info)
        default: return line.warning == "crossing" ? (L("It passes on what this flow reads. The card says so."), .warn) : nil
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
        case connections
    }

    enum Inspecting: Equatable {
        case nothing
        case trigger
        case step(String)

        var stepId: String? { if case .step(let id) = self { id } else { nil } }
    }

    /// What's selected on each flow's tree. Nothing to start with: the flow itself and what it will give are what there is to read.
    private var inspected: [String: Inspecting] = [:]

    func inspecting(_ flow: Flow) -> Inspecting { inspected[flow.id] ?? .nothing }

    /// The flows picked on the home page, while choosing some to delete, and whether it's asking to be sure.
    var pickingFlows: Set<String>?
    var askingToDelete = false
    /// When it asked: the second click of a double click on Delete isn't being sure.
    var askedToDeleteAt: Date?
    /// Asked from one flow's own menu, not from choosing some: keeping it goes back to that.
    var askedFromAFlow = false
    /// How a board is being looked at, never what it holds: the step it's zoomed in on and how far a wrap would reach.
    var focus: [String: String] = [:]
    var wrapThrough: [String: String] = [:]
    /// What's selected on a run's tree, and which go of a loop.
    var runStep: [String: String] = [:]
    var runScope: [String: String] = [:]

    mutating func inspect(_ what: Inspecting, in flow: String) { inspected[flow] = what }
    /// Parameters the person is pointing at an earlier step's value, by step and name, before they've picked one.
    private var usingValues: Set<String> = []
    func usesValue(flow: String, step: String, parameter: String) -> Bool { usingValues.contains("\(flow) \(step) \(parameter)") }
    mutating func useValue(_ on: Bool, flow: String, step: String, parameter: String) {
        if on { usingValues.insert("\(flow) \(step) \(parameter)") } else { usingValues.remove("\(flow) \(step) \(parameter)") }
    }

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

struct AgentEdit {
    var before: FlowBody
    var after: FlowBody
    var changes: [String]
}
