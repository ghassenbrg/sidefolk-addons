import Foundation
import SidefolkExtensionKit

/// Sideflow's screens, one page per state of the program: all flows, one flow and its runs, one run, all runs, the templates. They take the window: places at the start, what's
/// selected at the end. Sidefolk draws them; the words and what's where are here.
@MainActor enum Pages {
    static let tile = ["#4FA8F5", "#7C5CFC"]
    /// The thread, as on the icon: blue to violet.
    static let line = ["#4FA8F5", "#7C5CFC"]
    /// Numbers aren't something to press: their symbols stay out of the accent's way.
    static let quiet = "#6B7A90"
    /// Flat, a shade for each job: violet for the one main action, blue for what's selected. Everything else stays the theme's.
    static let accent = ["#6E4BF2", "#2A6FE8"]

    static func make(_ app: App, state: Arguments, background: Bool) async -> Page {
        // Today and the sidebar read only the summary, once a minute.
        if background { return Page(summary: summary(app)) }
        // An extension just turned on or off shows on the next look, not at the next tick.
        if app.catalog.loadedAt.map({ Date().timeIntervalSince($0) > 5 }) ?? true { Task { await app.catalog.refresh() } }
        switch Nav.place(state) {
        case .flow(let id):
            if let flow = app.store.flow(id) {
                return state.string("tab") == "runs" ? flowRunsPage(flow, app, state: state) : flowPage(flow, app, state: state)
            }
        case .run(let id):
            if let run = app.store.run(id) { return runPage(run, app, state: state) }
        case .history:
            return historyPage(app, state: state)
        case .templates:
            return templatesPage(app, state: state)
        case .home:
            break
        }
        return homePage(app, state: state)
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

    // MARK: The frame

    /// Every screen: the places, what's in the middle, and what's selected. The companion stands by.
    static func frame(_ app: App, state: Arguments, here: String?, flow: String? = nil, back: String? = nil, _ main: [Section], end: [Section] = []) -> Page {
        Page(summary: summary(app), sections: places(app, state: state, here: here, flow: flow) + main + end, back: back, workspace: true, companion: true, accent: accent)
    }

    /// Goes to a place, leaving what the page was showing.
    static func place(_ set: [String: Any]) -> [String: Any] {
        var out: [String: Any] = ["flow": NSNull(), "run": NSNull(), "view": NSNull(), "tab": NSNull()]
        out.merge(set) { _, new in new }
        return out
    }

    static func places(_ app: App, state: Arguments, here: String?, flow selected: String?) -> [Section] {
        func to(_ label: String, _ set: [String: Any]) -> Action { Action(label, act: .go(Go(set: set, push: true))) }
        let top = PageNav(brand: true, items: [
            .init("flows", L("Flows"), symbol: "point.3.connected.trianglepath.dotted", selected: here == "flows", press: to(L("Flows"), place([:]))),
            .init("history", L("Run history"), symbol: "clock.arrow.circlepath", selected: here == "history", press: to(L("Run history"), place(["view": "history"]))),
            .init("templates", L("Templates"), symbol: "square.stack.3d.up", selected: here == "templates", press: to(L("Templates"), place(["view": "templates"]))),
        ])
        let filter = state.string("filter") ?? "all"
        func keep(_ flow: Flow) -> Bool {
            switch filter {
            case "on": flow.state == .on
            case "drafts": flow.state == .draft
            default: true
            }
        }
        func pick(_ id: String, _ label: String) -> PageNav.Item {
            .init(id, label, selected: filter == id, press: Action(label, act: .go(Go(set: ["filter": id]))))
        }
        let stuck = Set(app.store.unfinished().filter { $0.status == .needs_you || $0.status == .interrupted }.map(\.flow))
        let mine = PageNav(title: L("My flows"), add: button(L("New flow"), "new", symbol: "plus"), filters: [pick("all", L("All")), pick("on", L("On")), pick("drafts", L("Drafts"))],
                           items: app.store.flows().filter(keep).sorted { stuck.contains($0.id) && !stuck.contains($1.id) }.map { flow in
                               let look = flowLook(flow)
                               let word = stuck.contains(flow.id) ? (L("Needs you"), Tone.warn) : stateWord(flow, app)
                               return .init(flow.id, flow.name, status: word.0, tone: word.1, symbol: look.symbol, color: look.color, selected: selected == flow.id,
                                            press: to(flow.name, place(Nav.open(flow: flow.id))))
                           }, empty: L("Nothing here yet"))
        return [Section(nil, [.nav(top), .nav(mine)], place: .side)]
    }

    /// A template's own look, kept by what it was made from; otherwise what sets it off.
    static func flowLook(_ flow: Flow) -> (symbol: String, color: String) {
        if let t = Templates.all.first(where: { $0.name == flow.name }) { return (t.symbol, t.color) }
        return (triggerSymbol(flow.draft.trigger), tile[0])
    }

    /// A flow's state in one word and its colour, always together (D78).
    static func stateWord(_ flow: Flow, _ app: App) -> (String, Tone) {
        if app.engine.isRunning(flow.id) { return (L("Running now"), .info) }
        switch flow.state {
        case .on: return flow.hasChanges ? (L("On · changes waiting"), .info) : (L("On"), .good)
        case .paused: return (L("Paused"), .neutral)
        case .draft: return practised(flow, app) != nil ? (L("Practised"), .info) : (L("Draft"), .neutral)
        }
    }

    /// The practice run of what's written now, if it finished.
    static func practised(_ flow: Flow, _ app: App) -> Run? {
        guard let run = practice(flow, app), run.status.isOver, run.status != .failed else { return nil }
        return run
    }

    /// The last practice run, as long as the flow hasn't changed since.
    static func practice(_ flow: Flow, _ app: App) -> Run? {
        app.store.runs(of: flow.id).first { $0.mode == .practice && $0.body == flow.draft }
    }

    // MARK: All flows

    static func homePage(_ app: App, state: Arguments) -> Page {
        let flows = app.store.flows()
        guard !flows.isEmpty else { return firstRun(app, state: state) }
        var main: [Section] = [Section(nil, [.bar(PageBar(L("Your flows"), detail: L("Your companion runs these for you."), actions: [button(L("New flow"), "new", style: .primary, symbol: "plus")]))])]
        var body: [Section] = []
        let on = flows.filter { $0.state == .on }
        let nextUp = on.compactMap { flow in Summaries.next(flow).map { (flow, $0) } }.min { $0.1 < $1.1 }
        let week = app.store.runs().filter { $0.mode != .practice && $0.startedAt > Date().addingTimeInterval(-7 * 86400) }
        let bad = week.filter { $0.status == .failed || $0.status == .needs_you || $0.status == .interrupted }.count
        body.append(Section(nil, [.stats([
            StatItem(L("Next run"), nextUp.map { Format.dateTime($0.1) } ?? L("None yet"), symbol: "calendar", color: quiet),
            StatItem(L("Flows on"), Format.integer(on.count), symbol: "play", color: quiet),
            StatItem(L("Runs this week"), Format.integer(week.count), symbol: "chart.bar", tone: bad > 0 ? .warn : .neutral, color: bad > 0 ? nil : quiet),
        ])], wide: true))
        body += needsYou(app)
        body.append(Section(nil, [.cards(size: .small, flows.map { card($0, app) })], wide: true))
        body.append(Section(nil, describing(app), wide: true))
        main += body
        return frame(app, state: state, here: "flows", main)
    }

    static func needsYou(_ app: App) -> [Section] {
        let stuck = app.store.unfinished().filter { $0.status == .needs_you || $0.status == .interrupted }
        guard !stuck.isEmpty else { return [] }
        return [Section(nil, [.cards(size: .small, stuck.prefix(6).map { run in
            let open = go(L("Answer"), place(["run": run.id]), style: .accent)
            return Card(run.flowName, detail: run.problem ?? L("It stopped midway. It needs one answer from you."), symbol: "exclamationmark.bubble", color: "#C2610F",
                        badge: Badge(L("Needs you"), tone: .warn), actions: [open], press: open)
        })], wide: true)]
    }

    static func card(_ flow: Flow, _ app: App) -> Card {
        var meta: String
        if let next = Summaries.next(flow) {
            meta = L("Next: {when}", ["when": Format.dateTime(next)])
        } else if let last = app.store.runs(of: flow.id).first {
            meta = L("Last: {status}, {when}", ["status": Summaries.status(last), "when": Format.dateTime(last.startedAt)])
        } else {
            meta = flow.state == .draft ? L("Nothing runs yet") : L("Waiting for a change")
        }
        if flow.state == .draft, practised(flow, app) != nil { meta = L("Ready to turn on") }
        let look = flowLook(flow), word = stateWord(flow, app)
        return Card(flow.name, detail: meta, symbol: look.symbol, color: look.color, badge: Badge(word.0, tone: word.1), tree: mini(flow.running, pending: flow.state == .draft && practised(flow, app) == nil, app),
                    press: go(L("Open"), place(Nav.open(flow: flow.id))))
    }

    /// A flow's small drawing of itself: its shape, for recognising it.
    static func mini(_ body: FlowBody, pending: Bool, _ app: App) -> CardTree {
        func nodes(_ steps: [Step]) -> [CardTree.Node] {
            steps.map { step in
                let look = look(step, app)
                var branches: [CardTree.Branch] = []
                if case .branch(_, let then, let otherwise) = step.kind {
                    branches = [CardTree.Branch("then:\(step.id)", L("Yes"), nodes: nodes(then)), CardTree.Branch("else:\(step.id)", L("No"), nodes: nodes(otherwise))]
                }
                return CardTree.Node(step.id, Words.label(step, catalog: app.catalog), symbol: look.symbol, color: look.color, state: pending ? .pending : .none, branches: branches)
            }
        }
        let first = CardTree.Node("start", Words.trigger(body.trigger), symbol: triggerSymbol(body.trigger), color: tile[0], state: pending ? .pending : .none)
        return CardTree([first] + nodes(body.steps), line: line)
    }

    static func describing(_ app: App) -> [Block] {
        var out: [Block] = []
        if AI.available != nil {
            out.append(.field(L("Say what you repeat"), detail: L("Your AI drafts it. Nothing runs until you've read it."), placeholder: L("Every Friday at 4, sum up my notes and save it"), button: L("Draft it"), tool: "ui", input: ui("describe")))
        }
        if let drafting = app.drafting { out.append(.note(L("Drafting “{words}”…", ["words": drafting]), tone: .info)) }
        if let problem = app.draftProblem { out.append(.note(problem, tone: .warn)) }
        return out
    }

    static func templateCards(_ app: App) -> [Card] {
        Templates.all.map { t in
            let use = button(L("Use this"), "new", ["template": t.id])
            return Card(t.name, detail: t.line, symbol: t.symbol, color: t.color, actions: [use], tree: (try? FlowCodec.body(t.body)).map { mini($0, pending: true, app) }, press: use)
        }
    }

    static func firstRun(_ app: App, state: Arguments) -> Page {
        var hero = Hero(L("Teach your companion a routine"), detail: L("Say it once. Watch it practise, with nothing changed. Then it's yours."), symbol: "point.3.connected.trianglepath.dotted")
        hero.figure = .companion(.full)
        hero.says = L("What should I take off your hands?")
        // Flat, as the buttons are: the line alone runs from one colour to the other.
        hero.tile = [accent[0]]
        hero.wash = [accent[1]]
        var main = [Section(nil, [.hero(hero)], wide: true)]
        if !describing(app).isEmpty { main.append(Section(nil, describing(app), wide: true)) }
        main.append(Section(L("Or start from one of these"), [.cards(size: .small, templateCards(app)), .action(button(L("Start blank"), "new", style: .plain, symbol: "plus"))], wide: true))
        main.append(Section(L("Good to know"), [
            .note(L("Flows run while Sidefolk is running and your Mac is awake. If the Mac was asleep at the time, a flow runs once when it's back, or says it missed it: you choose per flow.")),
            .settings(L("How it tells you"), keys: ["tell"], ai: true),
        ], collapsed: true))
        var page = frame(app, state: state, here: "flows", main)
        page.companion = false
        return page
    }

    static func templatesPage(_ app: App, state: Arguments) -> Page {
        frame(app, state: state, here: "templates", [
            Section(nil, [.bar(PageBar(L("Templates"), detail: L("Start from one, then make it yours.")))]),
            Section(nil, [.cards(size: .small, templateCards(app))], wide: true),
        ])
    }

    static func historyPage(_ app: App, state: Arguments) -> Page {
        let runs = app.store.runs().prefix(40)
        return frame(app, state: state, here: "history", [
            Section(nil, [.bar(PageBar(L("Run history"), detail: L("Everything your flows did, newest first.")))]),
            Section(nil, runs.isEmpty ? [.note(L("No runs yet."))] : [runList(Array(runs), named: true)], wide: true),
        ])
    }

    static func runList(_ runs: [Run], named: Bool) -> Block {
        .cards(size: .small, runs.map { run in
            let open = go(L("Open"), place(["run": run.id]))
            let title = named ? run.flowName : (run.mode == .practice ? L("Practice run") : Format.dateTime(run.startedAt))
            return Card(title, detail: named ? "\(Summaries.status(run)) · \(Format.dateTime(run.startedAt))" : Summaries.status(run), symbol: statusSymbol(run), color: tile[1], badge: Badge(Summaries.status(run), tone: tone(run)), press: open)
        })
    }

    static func tone(_ run: Run) -> Tone {
        switch run.status {
        case .done: .good
        case .failed: .bad
        case .needs_you, .interrupted: .warn
        case .running, .waiting: .info
        case .stopped: .neutral
        }
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
        case .event: "bolt"
        }
    }

    static func look(_ step: Step, _ app: App) -> (symbol: String, color: String) {
        switch step.kind {
        case .ai: return ("sparkles", "#8E6CF0")
        case .ask: return ("questionmark.bubble", "#F2B33D")
        case .text: return ("text.quote", "#6B7A90")
        case .branch: return ("arrow.triangle.branch", "#1FA88A")
        case .wait: return ("hourglass", "#6B7A90")
        case .flow: return ("arrow.triangle.turn.up.right.circle", "#5B8DEF")
        case .action(let tool, _):
            if tool == "notify.user" { return ("bell", "#FF7B6B") }
            if tool == "companion.job" { return ("wand.and.stars", "#C65CD6") }
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

    // MARK: One flow

    static func tabs(_ flow: Flow, state: Arguments) -> Block {
        var builder = PageTab("builder", L("Builder"), symbol: "point.3.connected.trianglepath.dotted", sections: [])
        builder.go = Go(set: ["tab": "builder"])
        var runs = PageTab("runs", L("Runs"), symbol: "chart.bar", sections: [])
        runs.go = Go(set: ["tab": "runs"])
        return .tabs(selected: state.string("tab") == "runs" ? "runs" : "builder", [builder, runs])
    }

    static func head(_ flow: Flow, _ app: App, ready: Bool) -> PageBar {
        let practice = practice(flow, app), running = app.engine.isRunning(flow.id)
        let fix = ready ? nil : L("Fix what's marked first.")
        let id = ["flow": flow.id]
        var actions: [Action] = [], extra: [Action] = []
        var pill = Badge(stateWord(flow, app).0, tone: stateWord(flow, app).1)
        var sentence = Words.aloud(flow.draft, catalog: app.catalog)
        if running, practice?.status == .running {
            pill = Badge(L("Practising"), tone: .info)
            sentence = L("It reads for real and changes nothing.")
            if let practice { actions = [button(L("Stop practising"), "proceed", ["run": practice.id, "how": "stop"], symbol: "stop.fill")] }
        } else {
            switch flow.state {
            case .draft:
                if practised(flow, app) != nil {
                    actions = [button(L("Practice run"), "practice", id, symbol: "play.fill", detail: fix ?? L("Reads for real, changes nothing."), disabled: !ready),
                               button(L("Turn on"), "start", id, style: .primary, symbol: "power", detail: fix ?? L("You read what it will do first."), disabled: !ready)]
                } else {
                    actions = [button(L("Practice run"), "practice", id, style: .primary, symbol: "play.fill", detail: fix ?? L("Reads for real, changes nothing."), disabled: !ready)]
                    extra.append(button(L("Turn on without practising"), "start", id, symbol: "power", detail: fix ?? L("You read what it will do first."), disabled: !ready))
                }
            case .on:
                actions = flow.hasChanges
                    ? [button(L("Practice run"), "practice", id, symbol: "play.fill", disabled: !ready), button(L("Apply changes"), "start", id, style: .primary, symbol: "checkmark", detail: fix, disabled: !ready)]
                    : [button(L("Run now"), "run", id, symbol: "play.fill"), button(L("Pause"), "pause", id, symbol: "pause.fill")]
                if flow.hasChanges { extra.append(button(L("Discard changes"), "discard", id, symbol: "arrow.uturn.backward")) }
            case .paused:
                actions = [button(L("Practice run"), "practice", id, symbol: "play.fill", disabled: !ready), button(L("Resume"), "resume", id, style: .primary, symbol: "play.fill", detail: fix, disabled: !ready)]
            }
        }
        if flow.hasChanges, !running { sentence = L("On, as before. Your changes aren't live.") }
        extra += [button(L("Duplicate"), "duplicate", id, symbol: "plus.square.on.square"),
                  Action(L("Copy it in words"), act: .copy(Words.aloud(flow.draft, catalog: app.catalog)), symbol: "doc.on.doc"),
                  button(L("Delete this flow"), "delete", id, style: .destructive, symbol: "trash")]
        return PageBar(flow.name, pill: pill, detail: sentence, actions: actions, menu: extra)
    }

    static func flowPage(_ flow: Flow, _ app: App, state: Arguments) -> Page {
        if app.preflight[flow.id] == nil { app.refreshPreflight(flow.id) }
        let problems = flow.draft.problems(app.catalog)
        var main = [Section(nil, [.bar(head(flow, app, ready: problems.isEmpty)), tabs(flow, state: state)])]
        var notes: [Block] = []
        if let why = flow.pausedBecause { notes.append(.note(why, tone: .warn)) }
        if let why = flow.startProblem { notes.append(.note(why, tone: .warn)) }
        if let last = flow.missed.last {
            notes.append(.note(L(one: "It missed {count} run, last at {time}: Sidefolk or your Mac was off.", other: "It missed {count} runs, last at {time}: Sidefolk or your Mac was off.", count: flow.missed.count, ["time": Format.dateTime(last)]), tone: .warn))
        }
        for p in problems where p.step == nil { notes.append(.note(p.text, tone: .warn)) }
        main.append(Section(nil, [.tree(tree(flow, app, problems: problems))], wide: true))
        var end: [Section] = []
        if !notes.isEmpty { end.append(Section(nil, notes, place: .trailing)) }
        if case .nothing = app.nav.inspecting(flow) {} else {
            end.append(Section(inspectorTitle(flow, app), Inspector.blocks(flow, app, problems: problems), place: .trailing))
        }
        end.append(Section(L("What you'll get"), [arriving(flow, app)], place: .trailing))
        return frame(app, state: state, here: nil, flow: flow.id, back: L("All flows"), main, end: end)
    }

    static func inspectorTitle(_ flow: Flow, _ app: App) -> String {
        switch app.nav.inspecting(flow) {
        case .trigger, .nothing: return L("When it runs")
        case .step(let id): return flow.draft.step(id).map { kindWord($0) } ?? L("Step")
        }
    }

    static func kindWord(_ step: Step) -> String {
        switch step.kind {
        case .action(let tool, _): tool == "companion.job" ? L("Your companion") : L("Action")
        case .ai: L("Write with AI")
        case .ask: L("Ask")
        case .text: L("Compose")
        case .branch: L("Condition")
        case .wait: L("Wait")
        case .flow: L("Another flow")
        }
    }

    /// What the flow does, its last practice run's results on it while it hasn't changed since.
    static func tree(_ flow: Flow, _ app: App, problems: [FlowProblem]) -> CardTree {
        // An On flow shows how its last real run went; anything else, its practice of what's written now.
        let live = flow.state == .on && !flow.hasChanges
        let run = live ? app.store.runs(of: flow.id).first { $0.mode == .live && $0.body == flow.draft } : practice(flow, app)
        let untested: CardTree.Node.State = flow.state == .draft || flow.hasChanges ? .pending : .none
        var nodes = [CardTree.Node("start", Words.trigger(flow.draft.trigger), kind: L("Trigger"), symbol: triggerSymbol(flow.draft.trigger), color: tile[0], state: run != nil ? .done : untested)]
        nodes += treeNodes(flow.draft.steps, body: flow.draft, app, run: run, untested: untested, flow: flow, problems: problems)
        let selected: String? = switch app.nav.inspecting(flow) {
        case .trigger: "start"
        case .step(let id): id
        case .nothing: nil
        }
        let last = selected ?? flow.draft.allSteps.last?.id ?? "start"
        func quick(_ label: String, _ kind: String, _ symbol: String) -> Action { button(label, "add_kind", ["flow": flow.id, "after": last, "kind": kind], symbol: symbol) }
        return CardTree(nodes, selected: selected, select: .init(tool: "ui", input: ui("inspect", ["flow": flow.id]), key: "target"),
                        insert: .init(tool: "ui", input: ui("add_kind", ["flow": flow.id]), key: "after", label: L("Add a step")),
                        reorder: .init(tool: "ui", input: ui("reorder", ["flow": flow.id]), key: "move"), picker: picker(app),
                        tools: [quick(L("Add a condition"), "if", "arrow.triangle.branch"), quick(L("Write with AI"), "ai", "sparkles"), quick(L("Tell me"), "tell", "bell"),
                                button(L("Practice run"), "practice", ["flow": flow.id], symbol: "play", disabled: !problems.isEmpty)], line: line)
    }

    static func treeNodes(_ steps: [Step], body: FlowBody, _ app: App, run: Run?, untested: CardTree.Node.State, flow: Flow?, problems: [FlowProblem], notTaken: Bool = false) -> [CardTree.Node] {
        steps.map { step in
            let look = look(step, app)
            let check = flow.flatMap { app.preflight[$0.id]?[step.id] }
            var title = Words.step(step, body: body, catalog: app.catalog)
            if step.name == nil, case .action = step.kind, let said = check?.summary.nonEmpty { title = Words.pretty(said, body: body, catalog: app.catalog) }
            var node = CardTree.Node(step.id, title, kind: kindWord(step), symbol: look.symbol, color: look.color, state: untested)
            if let problem = problems.first(where: { $0.step == step.id }) {
                node.state = .attention
                node.pill = Badge(L("To fix"), tone: .warn)
                node.title = problem.text
            } else if check?.decision == .deny {
                node.state = .attention
                node.pill = Badge(L("Not allowed"), tone: .warn)
            } else if let r = run?.record(of: step.id) {
                (node.state, node.pill) = result(r)
            } else if notTaken {
                node.state = .skipped
                node.pill = Badge(L("Not this time"), tone: .neutral)
            } else if let run, !run.status.isOver, run.status != .interrupted, run.status != .needs_you {
                node.state = .pending
            } else if run != nil {
                node.state = .pending
                node.pill = Badge(L("Not reached"), tone: .neutral)
            } else if Hints.asksEachTime(step, catalog: app.catalog) {
                node.pill = Badge(L("Asks you each time"), tone: .neutral)
            } else if case .ai = step.kind, AI.available == nil {
                node.state = .attention
                node.pill = Badge(L("No AI set up"), tone: .warn)
            }
            if case .branch(_, let then, let otherwise) = step.kind {
                let tested = run?.record(of: step.id) != nil
                // What ran says which way it went; an empty way was taken when the other didn't run.
                let ranYes = then.contains { run?.record(of: $0.id) != nil }, ranNo = otherwise.contains { run?.record(of: $0.id) != nil }
                let yes = tested && (ranYes || (then.isEmpty && !ranNo))
                let no = tested && (ranNo || (otherwise.isEmpty && !ranYes && !then.isEmpty))
                @MainActor func one(_ prefix: String, _ label: String, _ tone: Tone, _ list: [Step], taken: Bool) -> CardTree.Branch {
                    CardTree.Branch("\(prefix):\(step.id)", label, tone: tone, taken: tested ? taken : nil,
                                    nodes: treeNodes(list, body: body, app, run: run, untested: untested, flow: flow, problems: problems, notTaken: notTaken || (tested && !taken)))
                }
                node.branches = [one("then", L("Yes"), .good, then, taken: yes), one("else", L("No"), .bad, otherwise, taken: no)]
            }
            return node
        }
    }

    static func result(_ r: Run.Record) -> (CardTree.Node.State, Badge?) {
        switch r.status {
        case .running: (.active, Badge(L("Working…"), tone: .info))
        case .done: (.done, nil)
        case .would: (.pending, Badge(L("Would, not done"), tone: .neutral))
        case .failed: (.attention, Badge(L("Failed"), tone: .bad))
        case .skipped: (.skipped, Badge(L("Skipped"), tone: .neutral))
        case .needs_you: (.attention, Badge(L("Needs you"), tone: .warn))
        case .waiting: (.active, Badge(L("Waiting"), tone: .info))
        case .unknown: (.attention, Badge(L("Unknown"), tone: .warn))
        }
    }

    /// What can be added: Sideflow's own first, then every tool Sidefolk offers right now, each saying what it's like. An extension installed tomorrow is here by itself.
    static func picker(_ app: App) -> CardTree.Picker {
        var items: [CardTree.Picker.Item] = [
            .init("tell", L("Tell me"), detail: L("A notice from your companion"), meta: L("Reaches you"), symbol: "bell", color: "#FF7B6B", categories: ["suggested", "logic"]),
            .init("ai", L("Write with AI"), detail: L("Summarise, rewrite, sum up"), meta: L("No tools"), symbol: "sparkles", color: "#C65CD6", categories: ["suggested", "logic"]),
            .init("ask", L("Ask me"), detail: L("A question, and it waits for you"), meta: L("Reaches you"), symbol: "questionmark.bubble", color: "#F2B33D", categories: ["suggested", "logic"]),
            .init("if", L("If…"), detail: L("Do something only sometimes"), meta: L("Logic"), symbol: "arrow.triangle.branch", color: "#1FA88A", categories: ["suggested", "logic"]),
            .init("text", L("Compose text"), detail: L("Put values together"), meta: L("Logic"), symbol: "text.quote", color: "#6B7A90", categories: ["logic"]),
            .init("wait", L("Wait"), detail: L("Up to a day; survives quitting"), meta: L("Logic"), symbol: "hourglass", color: "#6B7A90", categories: ["logic"]),
            .init("flow", L("Run another flow"), detail: L("Sets it off and carries on"), meta: L("Logic"), symbol: "arrow.triangle.turn.up.right.circle", color: "#5B8DEF", categories: ["logic"]),
        ]
        if app.catalog.tool("companion.job") != nil {
            items.insert(.init("job", L("Let your companion do it"), detail: L("A whole job, with all its tools"), meta: L("Your trust settings"), symbol: "wand.and.stars", color: "#C65CD6", categories: ["suggested"]), at: 0)
        }
        let hidden: Set<String> = ["notify.user", "ask.user", "companion.job"]
        for t in app.catalog.tools where !hidden.contains(t.name) {
            let category = t.fromExtension != nil ? "extensions" : t.category
            items.append(.init("tool:\(t.name)", t.title, detail: t.fromExtension?.capitalizedFirst ?? String(t.description.prefix(70)), meta: t.mutates ? L("Changes things") : L("Only reads"),
                               symbol: Inspector.toolSymbol(t), color: toolColor(t), categories: [category]))
        }
        let present = Set(items.flatMap(\.categories))
        let names: [(id: String, label: String, symbol: String?)] = [
            ("suggested", L("Suggested"), "sparkles"), ("notes", L("Notes"), "note.text"), ("time", L("Time and reminders"), "calendar"), ("web", L("The web"), "globe"), ("files", L("Files"), "folder"),
            ("watch", L("Watches"), "eye"), ("system", L("This Mac"), "desktopcomputer"), ("agents", L("Agents"), "person.2"), ("extensions", L("Your add-ons"), "puzzlepiece.extension"), ("logic", L("Logic"), "arrow.triangle.branch"),
        ].filter { present.contains($0.id) }
        return CardTree.Picker(key: "kind", placeholder: L("What should it do next?"), note: L("Add-ons you install appear here by themselves."), categories: names, items: items)
    }

    static func toolColor(_ t: Catalog.Tool) -> String {
        switch t.category {
        case "notes": "#52C08A"
        case "time": "#5B8DEF"
        case "web": "#3B6FF5"
        case "files": "#C99A5B"
        case "watch": "#F2B33D"
        default: "#A68BFA"
        }
    }

    /// What the person will get: the real words once it has run, and until then only the shape of it.
    static func arriving(_ flow: Flow, _ app: App) -> Block {
        let real = app.store.runs(of: flow.id).first { $0.mode != .practice && $0.status == .done && $0.body == flow.draft }
        let run = flow.state == .on ? real ?? practice(flow, app) : practice(flow, app) ?? real
        let next = Summaries.next(flow)
        let footer = next.map { L("Next: {when}", ["when": Format.dateTime($0)]) }
        let time = next.map { Format.time($0) }
        guard let run else { return .notice(PageNotice(placeholder: L("Practise it to see the real thing"))) }
        let tells = run.body.allSteps.last { if case .action("notify.user", _) = $0.kind { true } else { false } }
        if let tells, case .action(_, let input) = tells.kind {
            let title = input["title"]?.string.map { Words.resolved($0, values: run.values) } ?? flow.name
            let words = input["body"]?.string.map { Words.resolved($0, values: run.values) }
            return .notice(PageNotice(title: title, body: words, time: time, footer: footer, forming: !run.status.isOver))
        }
        let output = run.records.reversed().first { $0.output?.nonEmpty != nil }?.output
        return .notice(PageNotice(title: flow.name, body: output ?? run.records.last?.summary, time: time, footer: footer, forming: !run.status.isOver))
    }

    // MARK: A flow's runs

    static func flowRunsPage(_ flow: Flow, _ app: App, state: Arguments) -> Page {
        let runs = app.store.runs(of: flow.id)
        let live = runs.filter { $0.mode != .practice }
        var body: [Section] = []
        if !live.isEmpty || !flow.missed.isEmpty {
            let done = live.prefix(14).reversed().map { run in PageTicks.Item("\(Format.dateTime(run.startedAt)), \(Summaries.status(run))", tone: tone(run)) }
            let missed = flow.missed.suffix(7).map { PageTicks.Item("\(Format.dateTime($0)), \(L("Missed"))", tone: .neutral, hollow: true) }
            body.append(Section(nil, [.ticks(PageTicks(L("Lately"), caption: flow.missed.isEmpty ? nil : L("Missed: Sidefolk or your Mac was off."), items: Array(missed) + Array(done)))], wide: true))
        }
        body.append(Section(nil, runs.isEmpty ? [.note(L("No runs yet."))] : [runList(Array(runs.prefix(20)), named: false)], wide: true))
        var end = [Section(L("What arrived"), [arriving(flow, app)], place: .trailing)]
        if flow.state != .draft {
            end.append(Section(nil, [.note(L("It may only do what you read when you turned it on. You can end that in Settings › Add-ons."))], place: .trailing))
        }
        return frame(app, state: state, here: nil, flow: flow.id, back: L("All flows"), [Section(nil, [.bar(head(flow, app, ready: flow.draft.problems(app.catalog).isEmpty)), tabs(flow, state: state)])] + body, end: end)
    }

    // MARK: One run

    static func runPage(_ run: Run, _ app: App, state: Arguments) -> Page {
        let id = ["run": run.id]
        var detail = run.why
        var end: [Section] = []
        func choices(_ title: String, _ options: [Option], note: Block? = nil) -> Section {
            var blocks: [Block] = note.map { [$0] } ?? []
            blocks.append(.picker(title, style: .rows, options, selected: "", tool: "ui", input: ui("proceed", id), key: "how"))
            return Section(nil, blocks, place: .trailing)
        }
        let current = currentStep(run)
        let said = current.flatMap { run.record(of: $0)?.summary } ?? ""
        switch run.status {
        case .interrupted:
            detail = L("Sidefolk stopped in the middle of this: {step}. It may have happened already.", ["step": said])
            end.append(choices(L("Which is true?"), [
                Option("try_again", L("It didn't happen: try again"), detail: L("Does it now, then carries on."), symbol: "arrow.clockwise"),
                Option("carry_on", L("It happened: carry on"), detail: L("Doesn't do it again."), symbol: "play"),
                Option("stop", L("Stop here"), detail: L("Nothing else runs."), symbol: "stop"),
            ]))
        case .needs_you, .waiting:
            if let problem = run.problem { detail = problem }
            end.append(choices(L("What now?"), [
                Option("try_again", L("Try again"), detail: L("Does it now, then carries on."), symbol: "arrow.clockwise"),
                Option("carry_on", L("Skip this step"), detail: L("Goes on without it."), symbol: "forward"),
                Option("stop", L("Stop here"), detail: L("Nothing else runs."), symbol: "stop"),
            ]))
        case .failed:
            if let problem = run.problem { detail = problem }
        default:
            break
        }
        if run.mode == .practice { end.append(Section(nil, [.note(L("Practice run: nothing was changed."))], place: .trailing)) }
        if let output = run.records.reversed().first(where: { $0.output?.nonEmpty != nil })?.output {
            end.append(Section(L("What it came to"), [.notice(PageNotice(title: run.flowName, body: output, time: run.endedAt.map { Format.time($0) }))], place: .trailing))
        }
        var nodes = [CardTree.Node("start", run.why, kind: L("Trigger"), symbol: triggerSymbol(run.body.trigger), color: tile[0], state: .done)]
        nodes += treeNodes(run.body.steps, body: run.body, app, run: run, untested: .pending, flow: nil, problems: [])
        return frame(app, state: state, here: nil, flow: run.flow, back: run.flowName, [
            Section(nil, [.bar(PageBar(run.flowName, pill: Badge(Summaries.status(run), tone: tone(run)), detail: detail))]),
            Section(nil, [.tree(CardTree(nodes, line: line))], wide: true),
        ], end: end)
    }

    static func currentStep(_ run: Run) -> String? {
        let program = FlowProgram(run.body)
        guard program.ops.indices.contains(run.pc), case .step(let step) = program.ops[run.pc] else { return nil }
        return step.id
    }
}

/// What a step will need, said in advance. Sidefolk holds the rule and enforces it: this only tells the person before the card does.
@MainActor enum Hints {
    private static let fillable: [String: Set<String>] = ["notes.save": ["text"], "notes.search": ["query"], "reminders.create": ["title", "notes"], "notify.user": ["title", "body"], "ask.user": ["question"]]

    static func asksEachTime(_ step: Step, catalog: Catalog? = nil) -> Bool {
        guard case .action(let tool, let input) = step.kind else { return false }
        if tool == "clipboard.read" || catalog?.tool(tool)?.risk == "high" { return true }
        let open = fillable[tool] ?? []
        return input.contains { key, value in !open.contains(key) && value.strings.contains { !Values.references($0).isEmpty } }
    }
}
