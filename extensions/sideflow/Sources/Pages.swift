import Foundation
import SidefolkExtensionKit

/// Sideflow's screens, one page per state of the program: all flows, one flow, one run. Sidefolk draws them; the words and what's where are here.
@MainActor enum Pages {
    static let tile = ["#5B8DEF", "#0B7783"]
    static let line = ["#5B8DEF", "#0B7783"]

    static func make(_ app: App, state: Arguments, background: Bool) async -> Page {
        // Today and the sidebar read only the summary, once a minute.
        if background { return Page(summary: summary(app)) }
        switch Nav.place(state) {
        case .flow(let id):
            if let flow = app.store.flow(id) { return flowPage(flow, app) }
        case .run(let id):
            if let run = app.store.run(id) { return runPage(run, app) }
        case .home:
            break
        }
        return homePage(app)
    }

    static func ui(_ op: String, _ extra: [String: Any] = [:]) -> [String: Any] {
        extra.merging(["op": op]) { own, _ in own }
    }

    static func go(_ label: String, _ set: [String: Any], style: ButtonStyle = .secondary, symbol: String? = nil) -> Action {
        Action(label, act: .go(Go(set: set, push: true)), style: style, symbol: symbol)
    }

    static func button(_ label: String, _ op: String, _ extra: [String: Any] = [:], style: ButtonStyle = .secondary, symbol: String? = nil, detail: String? = nil, disabled: Bool = false) -> Action {
        Action(label, tool: "ui", input: ui(op, extra), style: style, symbol: symbol, detail: detail, disabled: disabled)
    }

    // MARK: What's on Today

    static func summary(_ app: App) -> Summary {
        let flows = app.store.flows(), on = flows.filter { $0.state == .on }
        let stuck = app.store.unfinished().filter { $0.status == .needs_you || $0.status == .interrupted }
        if let first = stuck.first {
            return Summary(L(one: "{count} flow needs you", other: "{count} flows need you", count: stuck.count), detail: first.flowName, tone: .warn, symbol: "exclamationmark.bubble")
        }
        if let failed = app.store.runs().first(where: { $0.mode == .live }), failed.status == .failed {
            return Summary(L("{flow} failed", ["flow": failed.flowName]), detail: failed.problem ?? "", tone: .bad, symbol: "xmark.circle")
        }
        guard !on.isEmpty else {
            return Summary(flows.isEmpty ? L("No flows yet") : L("Nothing's on"), detail: L("Teach your companion a routine."), tone: .neutral, symbol: "point.3.connected.trianglepath.dotted")
        }
        let nextUp = on.compactMap { flow in Summaries.next(flow).map { (flow, $0) } }.min { $0.1 < $1.1 }
        return Summary(L(one: "{count} flow on", other: "{count} flows on", count: on.count),
                       detail: nextUp.map { L("Next: {flow} at {time}", ["flow": $0.0.name, "time": Format.time($0.1)]) } ?? L("Waiting for a change"),
                       tone: .good, symbol: "point.3.connected.trianglepath.dotted")
    }

    // MARK: All flows

    static func homePage(_ app: App) -> Page {
        let flows = app.store.flows()
        var sections: [Section] = []
        var hero = Hero(L("Teach your companion a routine"), eyebrow: "Sideflow", detail: L("Say what you repeat, or build it here. It practises first and changes nothing. Then you read what it will do, once, and it runs by itself."),
                        symbol: "point.3.connected.trianglepath.dotted", actions: [button(L("New flow"), "new", style: .primary, symbol: "plus")])
        hero.figure = .companion(.full)
        hero.says = flows.isEmpty ? L("What should I take off your hands?") : (summary(app).tone == .good ? L("I've got these.") : L("Anything else for me?"))
        hero.tile = tile
        hero.wash = tile
        sections.append(Section(nil, [.hero(hero)]))

        let stuck = app.store.unfinished().filter { $0.status == .needs_you || $0.status == .interrupted }
        if !stuck.isEmpty {
            sections.append(Section(L("Needs you"), [.cards(size: .large, stuck.prefix(6).map { run in
                Card(run.flowName, detail: run.problem, meta: Format.dateTime(run.startedAt), symbol: "exclamationmark.bubble", color: "#F2B33D", badge: Badge(Summaries.status(run), tone: .warn),
                     actions: [go(L("See what happened"), ["run": run.id], style: .accent)])
            })], wide: true))
        }

        if !flows.isEmpty {
            sections.append(Section(L("Your flows"), [.cards(size: .large, flows.map { card($0, app) })], wide: true))
        }

        var start: [Block] = []
        if AI.available != nil {
            start.append(.field(L("Say what you repeat"), detail: L("Your AI drafts it, and you read it before anything runs."), placeholder: L("Every Friday at 4, sum up my notes and save it"), button: L("Draft it"), tool: "ui", input: ui("describe")))
        }
        if let drafting = app.drafting { start.append(.note(L("Drafting “{words}”…", ["words": drafting]), tone: .info)) }
        if let problem = app.draftProblem { start.append(.note(problem, tone: .warn)) }
        start.append(.cards(size: .small, Templates.all.map { t in
            Card(t.name, detail: t.line, symbol: t.symbol, color: t.color, actions: [button(L("Use this"), "new", ["template": t.id])])
        }))
        sections.append(Section(flows.isEmpty ? L("Start with one of these") : L("Start something new"), start, wide: true))

        let recent = app.store.runs().prefix(6)
        if !recent.isEmpty {
            sections.append(Section(L("Lately"), [.cards(size: .small, recent.map { run in
                Card(run.flowName, detail: "\(Summaries.status(run)) · \(Format.dateTime(run.startedAt))", symbol: statusSymbol(run), color: "#6B7A90", actions: [go(L("Open"), ["run": run.id])])
            })], wide: true))
        }
        sections.append(Section(L("Good to know"), [
            .note(L("Flows run while Sidefolk is running and your Mac is awake. If the Mac was asleep at the time, a flow runs once when it's back, or says it missed it: you choose per flow.")),
            .settings(L("How it tells you"), keys: ["tell"], ai: true),
        ], collapsed: true))
        return Page(summary: summary(app), sections: sections)
    }

    static func card(_ flow: Flow, _ app: App) -> Card {
        let lastRun = app.store.runs(of: flow.id).first
        let output = lastRun?.records.reversed().first { $0.status == .done && $0.output?.nonEmpty != nil }?.output
        var meta: String?
        if let next = Summaries.next(flow) { meta = L("Next: {when}", ["when": Format.dateTime(next)]) } else if let lastRun { meta = L("Last: {status}, {when}", ["status": Summaries.status(lastRun), "when": Format.dateTime(lastRun.startedAt)]) }
        let badge: Badge = switch flow.state {
        case .draft: Badge(L("Draft"), tone: .neutral)
        case .on: flow.hasChanges ? Badge(L("On · changes waiting"), tone: .info) : Badge(L("On"), tone: .good)
        case .paused: Badge(L("Paused"), tone: .neutral)
        }
        return Card(flow.name, detail: output.map { String($0.prefix(140)) } ?? Words.aloud(flow.running, catalog: app.catalog), meta: meta, symbol: triggerSymbol(flow.running.trigger), color: tile[0], badge: badge,
                    actions: [go(L("Open"), Nav.open(flow: flow.id)), button(L("Run now"), "run", ["flow": flow.id], symbol: "play.fill")])
    }

    static func statusSymbol(_ run: Run) -> String {
        switch run.status {
        case .done: "checkmark.circle"
        case .failed: "xmark.circle"
        case .running: "arrow.triangle.2.circlepath"
        case .waiting: "hourglass"
        case .stopped: "stop.circle"
        case .needs_you, .interrupted: "exclamationmark.bubble"
        }
    }

    static func triggerSymbol(_ t: Trigger) -> String {
        switch t {
        case .manual: "hand.tap"
        case .days: "calendar.badge.clock"
        case .every: "clock.arrow.2.circlepath"
        case .watch: "eye"
        }
    }

    // MARK: One flow

    static func flowPage(_ flow: Flow, _ app: App) -> Page {
        if app.preflight[flow.id] == nil { app.refreshPreflight(flow.id) }
        let problems = flow.draft.problems(app.catalog)
        let practice = app.store.runs(of: flow.id).first { $0.mode == .practice }
        let practiced = practice.map { $0.body == flow.draft && $0.status.isOver } ?? false
        var actions: [Action] = []
        var eyebrow: String, tone: Tone
        let ready = problems.isEmpty
        let fix = ready ? nil : L("Fix what's marked first.")
        switch flow.state {
        case .draft:
            eyebrow = L("Draft: nothing runs")
            tone = .neutral
            actions = [button(L("Practice run"), "practice", ["flow": flow.id], style: practiced ? .secondary : .primary, symbol: "figure.walk", detail: fix ?? L("Reads for real, changes nothing."), disabled: !ready),
                       button(L("Turn on"), "start", ["flow": flow.id], style: practiced ? .primary : .secondary, symbol: "power", detail: fix ?? L("You read what it will do first."), disabled: !ready)]
        case .on:
            eyebrow = flow.hasChanges ? L("On, as before. Your changes aren't live") : L("On: runs by itself")
            tone = .good
            actions = flow.hasChanges
                ? [button(L("Apply changes"), "start", ["flow": flow.id], style: .primary, symbol: "checkmark", detail: fix, disabled: !ready), button(L("Practice run"), "practice", ["flow": flow.id], symbol: "figure.walk", disabled: !ready), button(L("Discard changes"), "discard", ["flow": flow.id], style: .plain)]
                : [button(L("Run now"), "run", ["flow": flow.id], symbol: "play.fill"), button(L("Pause"), "pause", ["flow": flow.id], symbol: "pause.fill")]
        case .paused:
            eyebrow = L("Paused")
            tone = .neutral
            actions = [button(L("Resume"), "resume", ["flow": flow.id], style: .primary, symbol: "play.fill", detail: fix, disabled: !ready), button(L("Practice run"), "practice", ["flow": flow.id], symbol: "figure.walk", disabled: !ready)]
        }
        if app.engine.isRunning(flow.id) { eyebrow = L("Running now") }
        var hero = Hero(flow.name, eyebrow: eyebrow, detail: Words.aloud(flow.draft, catalog: app.catalog), tone: tone, symbol: triggerSymbol(flow.draft.trigger), busy: app.engine.isRunning(flow.id), actions: actions)
        hero.tile = tile

        var sections: [Section] = [Section(nil, [.hero(hero)], wide: true)]
        var notes: [Block] = []
        if let why = flow.pausedBecause { notes.append(.note(why, tone: .warn)) }
        if let why = flow.startProblem { notes.append(.note(why, tone: .warn)) }
        if !flow.missed.isEmpty, let last = flow.missed.last {
            notes.append(.note(L(one: "It missed {count} run, last at {time}: Sidefolk or your Mac was off.", other: "It missed {count} runs, last at {time}: Sidefolk or your Mac was off.", count: flow.missed.count, ["time": Format.dateTime(last)]), tone: .warn))
        }
        for p in problems where p.step == nil { notes.append(.note(p.text, tone: .warn)) }
        if !notes.isEmpty { sections.append(Section(nil, notes, wide: true)) }

        // The rail and what's selected on it, side by side where there's room.
        sections.append(Section(L("What it does"), [.steps(rail(flow, app, practice: practiced ? practice : nil, problems: problems))], place: .side))
        sections.append(Section(inspectorTitle(flow, app), Inspector.blocks(flow, app, problems: problems)))

        let runs = app.store.runs(of: flow.id).prefix(5)
        if !runs.isEmpty {
            sections.append(Section(L("Its runs"), [.cards(size: .small, runs.map { run in
                Card(run.mode == .practice ? L("Practice run") : run.why, detail: "\(Summaries.status(run)) · \(Format.dateTime(run.startedAt))", symbol: statusSymbol(run), color: "#6B7A90", actions: [go(L("Open"), ["run": run.id])])
            })], place: .bottom, wide: true))
        }
        sections.append(Section(L("More"), [
            .field(L("Name"), placeholder: flow.name, button: L("Rename"), tool: "ui", input: ui("rename", ["flow": flow.id])),
            .action(button(L("Duplicate"), "duplicate", ["flow": flow.id], symbol: "plus.square.on.square")),
            .action(Action(L("Copy it in words"), act: .copy(Words.aloud(flow.draft, catalog: app.catalog)), symbol: "doc.on.doc", detail: L("A friend can paste this to their companion."))),
            .action(button(L("Delete this flow"), "delete", ["flow": flow.id], style: .destructive, symbol: "trash")),
        ], place: .bottom, collapsed: true, wide: true))
        return Page(summary: summary(app), sections: sections, back: L("All flows"))
    }

    static func inspectorTitle(_ flow: Flow, _ app: App) -> String {
        switch app.nav.inspecting(flow) {
        case .trigger: return L("When it runs")
        case .adding: return L("Add a step")
        case .step(let id):
            if id.hasPrefix("then:") || id.hasPrefix("else:") { return L("Add a step") }
            return flow.draft.step(id).map { Words.label($0, catalog: app.catalog) } ?? L("Step")
        }
    }

    /// The rail: when, then each step in reading order, a practice run's results on it.
    static func rail(_ flow: Flow, _ app: App, practice: Run?, problems: [FlowProblem]) -> StepRail {
        var items: [StepRail.Item] = [StepRail.Item("start", Words.trigger(flow.draft.trigger), symbol: triggerSymbol(flow.draft.trigger), color: tile[0], locked: true)]
        func add(_ steps: [Step], depth: Int, label: String?) {
            var label = label
            for step in steps {
                items.append(item(step, flow, app, practice: practice, problems: problems, depth: depth, label: label))
                label = nil
                if case .branch(_, let then, let otherwise) = step.kind {
                    items.append(StepRail.Item("then:\(step.id)", L("If yes"), detail: then.isEmpty ? L("Nothing yet") : nil, symbol: "checkmark", tone: .neutral, depth: depth + 1, locked: true))
                    add(then, depth: depth + 1, label: nil)
                    items.append(StepRail.Item("else:\(step.id)", L("If not"), detail: otherwise.isEmpty ? L("Nothing happens") : nil, symbol: "xmark", tone: .neutral, depth: depth + 1, locked: true))
                    add(otherwise, depth: depth + 1, label: nil)
                }
            }
        }
        add(flow.draft.steps, depth: 0, label: nil)
        let selected: String? = switch app.nav.inspecting(flow) {
        case .trigger: "start"
        case .step(let id): id
        case .adding(let after): after
        }
        return StepRail(nil, items, selected: selected, select: .init(tool: "ui", input: ui("inspect", ["flow": flow.id]), key: "target"),
                        reorder: .init(tool: "ui", input: ui("reorder", ["flow": flow.id]), key: "move"),
                        insert: .init(tool: "ui", input: ui("add", ["flow": flow.id]), key: "target", label: L("Add a step")), line: line)
    }

    static func look(_ step: Step, _ app: App) -> (symbol: String, color: String) {
        switch step.kind {
        case .ai: return ("sparkles", "#8E6CF0")
        case .ask: return ("questionmark.bubble", "#F2B33D")
        case .text: return ("text.quote", "#6B7A90")
        case .branch: return ("arrow.triangle.branch", "#1FA88A")
        case .wait: return ("hourglass", "#6B7A90")
        case .action(let tool, _):
            if tool == "notify.user" { return ("bell", "#FF7B6B") }
            switch app.catalog.tool(tool)?.category {
            case "notes": return ("note.text", "#52C08A")
            case "time": return ("calendar", "#5B8DEF")
            case "web": return ("globe", "#3B6FF5")
            case "files": return ("folder", "#C99A5B")
            case "watch": return ("eye", "#F2B33D")
            default: return ("square.grid.2x2", "#A68BFA")
            }
        }
    }

    static func item(_ step: Step, _ flow: Flow, _ app: App, practice: Run?, problems: [FlowProblem], depth: Int, label: String?) -> StepRail.Item {
        let (symbol, color) = look(step, app)
        let check = app.preflight[flow.id]?[step.id]
        var title = Words.step(step, body: flow.draft, catalog: app.catalog)
        if step.name == nil, case .action = step.kind, let said = check?.summary.nonEmpty { title = Words.pretty(said, body: flow.draft, catalog: app.catalog) }
        var made = StepRail.Item(step.id, title, symbol: symbol, color: color, depth: depth, label: label)
        if let problem = problems.first(where: { $0.step == step.id }) {
            made.detail = problem.text
            made.tone = .warn
            made.badge = Badge(L("To fix"), tone: .warn)
        } else if check?.decision == .deny {
            made.detail = check?.why
            made.tone = .warn
            made.badge = Badge(L("Not allowed"), tone: .warn)
        } else if Hints.asksEachTime(step) {
            made.badge = Badge(L("Asks you each time"), tone: .neutral)
        } else if case .ai = step.kind, AI.available == nil {
            made.badge = Badge(L("No AI set up"), tone: .warn)
        }
        if let r = practice?.record(of: step.id) {
            made.state = railState(r.status)
            made.result = resultWord(r)
            made.output = r.output?.nonEmpty
            if let note = r.note, made.detail == nil { made.detail = note }
        }
        return made
    }

    static func railState(_ s: Run.Record.Status) -> StepRail.Item.State {
        switch s {
        case .running: .running
        case .done: .done
        case .would: .pending
        case .failed: .failed
        case .skipped: .skipped
        case .needs_you, .waiting, .unknown: .waiting
        }
    }

    static func resultWord(_ r: Run.Record) -> String? {
        switch r.status {
        case .done: L("Done")
        case .would: L("Would do this")
        case .failed: L("Failed")
        case .skipped: L("Skipped")
        case .needs_you: L("Needs you")
        case .waiting: L("Waiting")
        case .unknown: L("Unknown")
        case .running: nil
        }
    }

    // MARK: One run

    static func runPage(_ run: Run, _ app: App) -> Page {
        var actions: [Action] = []
        let id = ["run": run.id]
        var detail = run.why
        switch run.status {
        case .interrupted:
            actions = [button(L("It didn't happen: try again"), "proceed", ui("proceed", id).merging(["how": "try_again"]) { a, _ in a }, style: .primary),
                       button(L("It happened: carry on"), "proceed", ui("proceed", id).merging(["how": "carry_on"]) { a, _ in a }),
                       button(L("Stop here"), "proceed", ui("proceed", id).merging(["how": "stop"]) { a, _ in a }, style: .plain)]
            let step = FlowProgram(run.body).ops.indices.contains(run.pc) ? run.record(of: currentStep(run) ?? "")?.summary : nil
            detail = L("Sidefolk stopped in the middle of this: {step}. Check whether it happened, then pick.", ["step": step ?? ""])
        case .needs_you, .waiting:
            actions = [button(L("Try again"), "proceed", ui("proceed", id).merging(["how": "try_again"]) { a, _ in a }, style: .primary),
                       button(L("Skip this step"), "proceed", ui("proceed", id).merging(["how": "carry_on"]) { a, _ in a }),
                       button(L("Stop here"), "proceed", ui("proceed", id).merging(["how": "stop"]) { a, _ in a }, style: .plain)]
            if let problem = run.problem { detail = problem }
        case .failed:
            if let problem = run.problem { detail = problem }
        default:
            break
        }
        let tone: Tone = switch run.status {
        case .done: .good
        case .failed: .bad
        case .needs_you, .interrupted: .warn
        default: .neutral
        }
        var facts = [(L("Started"), Format.dateTime(run.startedAt))]
        if let ended = run.endedAt { facts.append((L("Took"), Format.duration(max(1, ended.timeIntervalSince(run.startedAt))))) }
        if run.mode == .practice { facts.append((L("Kind"), L("Practice run: nothing was changed"))) }
        var hero = Hero(run.flowName, eyebrow: Summaries.status(run), detail: detail, tone: tone, symbol: statusSymbol(run), busy: run.status == .running, facts: facts, actions: actions)
        hero.tile = tile
        var items: [StepRail.Item] = [StepRail.Item("start", run.why, symbol: triggerSymbol(run.body.trigger), color: tile[0], state: .done, locked: true)]
        func add(_ steps: [Step], depth: Int) {
            for step in steps {
                let r = run.record(of: step.id)
                let (symbol, color) = look(step, app)
                items.append(StepRail.Item(step.id, r?.summary ?? Words.step(step, body: run.body, catalog: app.catalog), detail: r?.note, result: r.flatMap(resultWord), symbol: symbol, color: color,
                                           tone: r?.status == .failed ? .bad : (r?.status == .needs_you || r?.status == .unknown ? .warn : .neutral),
                                           state: r.map { railState($0.status) } ?? .skipped, depth: depth, locked: true, output: r?.output?.nonEmpty))
                if case .branch(_, let then, let otherwise) = step.kind {
                    add(then, depth: depth + 1)
                    add(otherwise, depth: depth + 1)
                }
            }
        }
        add(run.body.steps, depth: 0)
        return Page(summary: summary(app), sections: [
            Section(nil, [.hero(hero)], wide: true),
            Section(L("What happened"), [.steps(StepRail(nil, items, line: line))], wide: true),
        ], back: run.flowName)
    }

    static func currentStep(_ run: Run) -> String? {
        let program = FlowProgram(run.body)
        guard program.ops.indices.contains(run.pc), case .step(let step) = program.ops[run.pc] else { return nil }
        return step.id
    }
}

/// What a step will need, said in advance. Sidefolk holds the rule and enforces it: this only tells the person before the card does.
enum Hints {
    private static let fillable: [String: Set<String>] = ["notes.save": ["text"], "reminders.create": ["title", "notes"], "notify.user": ["title", "body"], "ask.user": ["question"]]

    static func asksEachTime(_ step: Step) -> Bool {
        guard case .action(let tool, let input) = step.kind else { return false }
        if tool == "clipboard.read" { return true }
        let open = fillable[tool] ?? []
        return input.contains { key, value in !open.contains(key) && value.strings.contains { !Values.references($0).isEmpty } }
    }
}
