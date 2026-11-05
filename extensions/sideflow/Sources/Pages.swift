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
        let page = whole(app, state: state)
        // Sidefolk shows nothing of a page past its limit, so there'd be no way left to fix what made it so long. What's small enough to always show takes its place.
        return JSONText.write(page.sent).utf8.count <= mostOnAPage ? page : tooLong(app, state: state)
    }

    static let mostOnAPage = 126_000

    /// Whichever of the flow's tabs it was on: any can be the one that's too long.
    static func isTooLong(flow id: String, tab: String?, _ app: App) -> Bool {
        var state: [String: Any] = ["flow": id]
        if let tab { state["tab"] = tab }
        return JSONText.write(whole(app, state: Arguments(state)).sent).utf8.count > mostOnAPage
    }

    /// A flow or a list too long to draw, with what can be done about it. Every word here is short by being cut.
    static func tooLong(_ app: App, state: Arguments) -> Page {
        var body: [Block] = [.note(L("This is too long to show on a page. Delete what's too long, or ask an agent to shorten it."), tone: .warn)]
        if case .flow(let id) = Nav.place(state), let flow = app.store.flow(id) {
            body.append(.note(FlowFile.short(flow.name, 60)))
            body.append(.action(button(L("Delete this flow"), "delete_too_long", ["flow": flow.id, "tab": state.string("tab") ?? NSNull(), "page_token": app.pageKey], style: .destructive, symbol: "trash", detail: L("Its runs and what you allowed for it go too. This can't be undone."))))
            return Page(summary: summary(app), sections: [Section(L("Too long to show"), body, wide: true)], back: L("All flows"), workspace: true)
        }
        if case .run(let id) = Nav.place(state), let run = app.store.run(id), !run.status.isOver {
            body.append(.note(FlowFile.short(run.flowName, 60)))
            // Stopping comes first: it's why anyone would be here with a run under way. A form it waits on has its answers kept; its flow's page can take them once that's shorter.
            body.append(.action(button(L("Stop"), "stop_run", ["run": run.id, "page_token": app.pageKey], style: .destructive, symbol: "stop.fill")))
        }
        body.append(.action(Action(L("Run history"), act: .go(Go(set: place(["view": "history"]), push: true)), symbol: "clock.arrow.circlepath")))
        for flow in app.store.flows().prefix(20) {
            body.append(.action(Action(FlowFile.short(flow.name, 60), act: .go(Go(set: place(["flow": flow.id]), push: true)), symbol: "point.3.connected.trianglepath.dotted")))
        }
        return Page(summary: summary(app), sections: [Section(L("Too long to show"), body, wide: true)], workspace: true)
    }

    private static func whole(_ app: App, state: Arguments) -> Page {
        // An extension just turned on or off shows on the next look, not at the next tick.
        if app.catalog.loadedAt.map({ Date().timeIntervalSince($0) > 5 }) ?? true { Task { await app.catalog.refresh() } }
        if let id = state.string("import"), let page = importPage(id, app, state: state) { return page }
        switch Nav.place(state) {
        case .flow(let id):
            if let flow = app.store.flow(id) {
                switch state.string("tab") {
                case "runs": return flowRunsPage(flow, app, state: state)
                case "activity": return flowActivityPage(flow, app, state: state)
                default: return flowPage(flow, app, state: state)
                }
            }
        case .run(let id):
            if let run = app.store.run(id) { return runPage(run, app, state: state) }
        case .history:
            return historyPage(app, state: state)
        case .templates:
            return templatesPage(app, state: state)
        case .connections:
            return connectionsPage(app, state: state)
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
        let stuck = app.store.unfinished().filter { $0.status == .needs_you || $0.status == .interrupted || $0.form != nil }
        if let first = stuck.first {
            return Summary(L(one: "{count} flow needs you", other: "{count} flows need you", count: Set(stuck.map(\.flow)).count), detail: first.flowName, tone: .warn, symbol: "exclamationmark.bubble")
        }
        if let waiting = app.store.unfinished().first(where: { $0.connection != nil && !app.engine.heldByPause($0) }), let id = waiting.connection.flatMap({ Connections.id(of: $0.tool) }) {
            return Summary(L("{flow} is waiting for {name}", ["flow": waiting.flowName, "name": Connections.title(id, app.catalog, app.store)]), detail: L("It goes on by itself once it's back."), tone: .warn, symbol: "link")
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
    /// What's wrong with the file itself: the person can't see this any other way.
    static func storeWarnings(_ app: App) -> [Section] {
        var notes: [Block] = []
        if app.store.flowsFileIsHeld {
            notes.append(.note(L("Your flows file can't be opened. It's untouched, and nothing runs or saves until it can be and Sidefolk starts again."), tone: .bad))
        } else if app.store.flowsNotSaved { notes.append(.note(L("Your flows couldn't be saved to disk. Changes you've made may be lost when Sidefolk quits."), tone: .bad)) }
        if let aside = app.store.damagedFile { notes.append(.note(L("Your flows file couldn't be read, so it was kept aside as {file} and you're starting from none.", ["file": aside.lastPathComponent]), tone: .bad)) }
        if app.store.unreadableCount > 0 { notes.append(.note(L(one: "{count} flow can't be read by this version. It's kept, not shown.", other: "{count} flows can't be read by this version. They're kept, not shown.", count: app.store.unreadableCount), tone: .warn)) }
        let held = app.store.heldBackRuns.count
        if held > 0 {
            notes.append(.note(L(one: "{count} run is waiting for a flow that can't be read now. It goes on if the flow comes back.", other: "{count} runs are waiting for flows that can't be read now. They go on if the flows come back.", count: held), tone: .warn))
            notes.append(.action(button(L("Let them go"), "end_held", style: .plain, symbol: "xmark.circle", detail: L("Ends those runs. What they did stays done."))))
        }
        return notes.isEmpty ? [] : [Section(nil, notes, wide: true)]
    }

    static func frame(_ app: App, state: Arguments, here: String?, flow: String? = nil, back: String? = nil, _ main: [Section], end: [Section] = []) -> Page {
        Page(summary: summary(app), sections: places(app, state: state, here: here, flow: flow) + storeWarnings(app) + main + end, back: back, workspace: true, companion: true, accent: accent)
    }

    /// Goes to a place, leaving what the page was showing.
    static func place(_ set: [String: Any]) -> [String: Any] {
        var out: [String: Any] = ["flow": NSNull(), "run": NSNull(), "view": NSNull(), "tab": NSNull(), "import": NSNull()]
        out.merge(set) { _, new in new }
        return out
    }

    static func places(_ app: App, state: Arguments, here: String?, flow selected: String?) -> [Section] {
        func to(_ label: String, _ set: [String: Any]) -> Action { Action(label, act: .go(Go(set: set, push: true))) }
        let gone = Connections.all(app.catalog, app.store).filter { !$0.isHere }.count
        let top = PageNav(brand: true, items: [
            .init("flows", L("Flows"), symbol: "point.3.connected.trianglepath.dotted", selected: here == "flows", press: to(L("Flows"), place([:]))),
            .init("history", L("Run history"), symbol: "clock.arrow.circlepath", selected: here == "history", press: to(L("Run history"), place(["view": "history"]))),
            .init("templates", L("Templates"), symbol: "square.stack.3d.up", selected: here == "templates", press: to(L("Templates"), place(["view": "templates"]))),
            .init("connections", L("Connections"), status: gone > 0 ? L("{count} missing", ["count": Format.integer(gone)]) : nil, tone: gone > 0 ? .warn : .neutral, symbol: "link", selected: here == "connections", press: to(L("Connections"), place(["view": "connections"]))),
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
        let stuck = Set(app.store.unfinished().filter { $0.status == .needs_you || $0.status == .interrupted || $0.form != nil }.map(\.flow))
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
        let waiting = app.store.unfinished().filter { $0.flow == flow.id }
        if flow.state != .paused, waiting.contains(where: { $0.connection != nil }) { return (L("Waiting for a connection"), .warn) }
        // Paused with a run in a wait, that run isn't what's going on.
        if app.engine.isRunning(flow.id), flow.state != .paused || waiting.contains(where: { $0.status == .running }) { return (L("Running now"), .info) }
        if flow.hasUnsaved { return (L("Unsaved changes"), .warn) }
        switch flow.state {
        case .on: return flow.hasChanges ? (L("On · changes to apply"), .info) : (L("On"), .good)
        case .paused: return (L("Paused"), .neutral)
        case .draft: return practiced(flow, app) != nil ? (L("Practiced"), .info) : (L("Draft"), .neutral)
        }
    }

    /// The practice run of what's written now, if it finished.
    static func practiced(_ flow: Flow, _ app: App) -> Run? {
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
        if let picked = app.nav.pickingFlows { return pickingPage(flows, picked: picked, app, state: state) }
        var main: [Section] = [Section(nil, [.bar(PageBar(L("Your flows"), detail: L("Your companion runs these for you."), actions: [button(L("Select"), "pick_flows", symbol: "checkmark.circle"), importButton, button(L("New flow"), "new", style: .primary, symbol: "plus")]))])]
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
        body.append(Section(L("Bring one in"), [.edit(EditField("import", L("A flow's definition"), value: "", detail: L("One copied from Sideflow. It comes in as a draft: nothing runs until you've read it and turned it on."), placeholder: "{\"name\": …, \"flow\": …}", kind: .multiline, tool: "ui", input: ui("import")))], collapsed: true, wide: true))
        main += body
        return frame(app, state: state, here: "flows", main)
    }

    /// What Sidefolk keeps of a list or a section: past it, the rest wouldn't show. And how many sections that leaves room for.
    static let inABlock = 24
    static let mostToPick = inABlock * 12
    /// Long enough that the second click of a double click isn't taken for being sure.
    static let settling: TimeInterval = 0.6

    /// Choosing flows to delete, and then being sure: how many, which, and what goes with them. What's gone doesn't come back, so it's said before it happens.
    static func pickingPage(_ flows: [Flow], picked: Set<String>, _ app: App, state: Arguments) -> Page {
        let chosen = flows.filter { picked.contains($0.id) }
        var main: [Section] = []
        if app.nav.askingToDelete, !chosen.isEmpty {
            // In lists of what a list can hold: nothing goes that isn't named.
            var blocks: [Block] = stride(from: 0, to: chosen.count, by: inABlock).map { start in
                .facts(nil, chosen[start..<min(start + inABlock, chosen.count)].map { (stateWord($0), $0.name) })
            }
            let on = chosen.filter { $0.state == .on }.count
            if on > 0 { blocks.append(.note(L(one: "{count} of them is on. It stops running.", other: "{count} of them are on. They stop running.", count: on), tone: .warn)) }
            let doomed = Set(chosen.map(\.name))
            for other in flows where !picked.contains(other.id) {
                let runs = other.running.allSteps.compactMap { step -> String? in
                    switch step.kind {
                    case .call(let name, _), .flow(let name): doomed.contains(name) ? name : nil
                    default: nil
                    }
                }
                if let first = runs.first { blocks.append(.note(L("“{other}” runs “{name}”, and that step won't work after this.", ["other": other.name, "name": first]), tone: .warn)) }
            }
            blocks.append(.note(L("Their runs and what you allowed for them go too. This can't be undone.")))
            let sure = L(one: "Delete {count} flow", other: "Delete {count} flows", count: chosen.count)
            main.append(Section(nil, [.bar(PageBar(L(one: "Delete this flow?", other: "Delete these {count} flows?", count: chosen.count), detail: nil, actions: [button(L("Keep them"), "pick_keep"), button(sure, "pick_delete_sure", ["page_token": app.pageKey, "named": chosen.map(\.id)], style: .destructive, symbol: "trash")]))]))
            main.append(Section(nil, blocks, wide: true))
            return frame(app, state: state, here: "flows", main)
        }
        let detail = chosen.isEmpty ? L("Pick the flows to delete or export.") : L(one: "{count} selected", other: "{count} selected", count: chosen.count)
        main.append(Section(nil, [.bar(PageBar(L("Select flows"), detail: detail, actions: [
            button(L("Done"), "pick_none"),
            button(L("Select all"), "pick_all", disabled: chosen.count == flows.count),
            Action(L("Export"), act: .save(name: chosen.count == 1 ? chosen[0].name : L("Flows"), type: FlowFile.type, tool: "export_flows", input: ["flows": chosen.map(\.id)], note: exportNote), symbol: "square.and.arrow.up",
                   detail: chosen.count > FlowFile.mostFlows ? L("A file holds at most {count} flows.", ["count": Format.integer(FlowFile.mostFlows)]) : nil, disabled: chosen.isEmpty || chosen.count > FlowFile.mostFlows),
            button(chosen.isEmpty ? L("Delete") : L(one: "Delete {count} flow", other: "Delete {count} flows", count: chosen.count), "pick_delete", style: .destructive, symbol: "trash", disabled: chosen.isEmpty),
        ]))]))
        let shown = Array(flows.prefix(mostToPick))
        for start in stride(from: 0, to: shown.count, by: inABlock) {
            main.append(Section(nil, shown[start..<min(start + inABlock, shown.count)].map { flow in
                .toggle(flow.name, detail: stateWord(flow), on: picked.contains(flow.id), tool: "ui", input: ui("pick_flow", ["picked": flow.id]))
            }, wide: true))
        }
        if flows.count > shown.count { main.append(Section(nil, [.note(L("Only the first {count} flows can be picked at once. Delete these, and the rest come up.", ["count": Format.integer(shown.count)]))], wide: true)) }
        return frame(app, state: state, here: "flows", main)
    }

    private static func stateWord(_ flow: Flow) -> String {
        flow.state == .on ? L("On") : flow.state == .paused ? L("Paused") : L("Draft")
    }

    static func needsYou(_ app: App) -> [Section] {
        // A form in a lane or a called flow counts: nothing else shows it from here, and left alone it runs out of time.
        let stuck = app.store.unfinished().filter { $0.status == .needs_you || $0.status == .interrupted || $0.form != nil }
        guard !stuck.isEmpty else { return [] }
        return [Section(nil, [.cards(size: .small, stuck.prefix(6).map { run in
            let open = go(L("Answer"), place(["run": run.id]), style: .accent)
            return Card(run.flowName, detail: run.problem ?? (run.form != nil ? L("It's waiting for you to fill something in.") : L("It stopped midway. It needs one answer from you.")), symbol: "exclamationmark.bubble", color: "#C2610F",
                        badge: Badge(L("Needs you"), tone: .warn), actions: [open], press: open)
        })], wide: true)]
    }

    static func card(_ flow: Flow, _ app: App) -> Card {
        var meta: String
        if let next = Summaries.next(flow) {
            meta = L("Next: {when}", ["when": Format.dateTime(next)])
        } else if let last = app.store.latest(of: flow.id) {
            meta = L("Last: {status}, {when}", ["status": Summaries.status(last), "when": Format.dateTime(last.startedAt)])
        } else {
            meta = flow.state == .draft ? L("Nothing runs yet") : L("Waiting for a change")
        }
        if flow.state == .draft, practiced(flow, app) != nil { meta = L("Ready to turn on") }
        // Paused by something other than the person: Home says why, not only the flow's own page.
        if flow.state == .paused, let why = flow.pausedBecause?.nonEmpty { meta = why }
        let look = flowLook(flow), word = stateWord(flow, app)
        return Card(flow.name, detail: meta, symbol: look.symbol, color: look.color, badge: Badge(word.0, tone: word.1), tree: mini(flow.running, pending: flow.state == .draft && practiced(flow, app) == nil, app),
                    press: go(L("Open"), place(Nav.open(flow: flow.id))))
    }

    /// A flow's small drawing of itself: its shape, for recognising it.
    static func mini(_ body: FlowBody, pending: Bool, _ app: App) -> CardTree {
        // It's a picture of its shape, and a page holds many: past this it's enough to know it goes on.
        var left = 24
        func nodes(_ steps: [Step]) -> [CardTree.Node] {
            steps.prefix(while: { _ in left > 0 }).map { step in
                left -= 1
                let look = look(step, app)
                var branches: [CardTree.Branch] = []
                branches = step.parts.map { CardTree.Branch("\($0.id):\(step.id)", partLabel($0.id, of: step), nodes: nodes($0.steps)) }
                return CardTree.Node(step.id, FlowFile.short(Words.label(step, catalog: app.catalog), 60), symbol: look.symbol, color: look.color, state: pending ? .pending : .none, branches: branches)
            }
        }
        let first = CardTree.Node("start", FlowFile.short(Words.trigger(body.trigger), 60), symbol: triggerSymbol(body.trigger), color: tile[0], state: pending ? .pending : .none)
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

    static var importButton: Action { Action(L("Import a file"), act: .file(tool: "import_file", param: "path", types: [FlowFile.type, "json"]), symbol: "square.and.arrow.down") }

    /// A flow from a file, before it comes in: what it would do and need, as far as Sideflow can tell.
    static func importPage(_ id: String, _ app: App, state: Arguments) -> Page? {
        guard let words = FlowFile.staged(id, in: app.folder), let incoming = try? FlowFile.read(words) else { return nil }
        let arriving = FlowFile.arriving(incoming, store: app.store)
        var main = [Section(nil, [.bar(PageBar(L("Bring this in?"), detail: L("It comes in as a draft and off. Nothing runs until you turn it on and read its card."), actions: [
            button(L("Not now"), "import_cancel", ["id": id]),
            button(L("Bring in"), "import_confirm", ["id": id, "page_token": app.pageKey], style: .primary, symbol: "square.and.arrow.down"),
        ])), .note(L("This is what Sideflow can tell from the file. The real safeguard is the card when you turn it on."))], wide: true)]
        // A page can hold so much, and words can be long: what's most to know goes first, and if it runs out the page says so.
        var room = 90_000
        for flow in FlowFile.survey(arriving, store: app.store, catalog: app.catalog) {
            var blocks: [Block] = [], cut = false
            func say(_ words: String, tone: Tone = .neutral) {
                // As it's carried, escapes and all.
                let cost = JSONText.write([words]).utf8.count + 40
                guard blocks.count < 22, room >= cost else { return cut = true }
                room -= cost
                blocks.append(.note(words, tone: tone))
            }
            /// A list in as many notes as it takes, up to a few: what comes after it matters too.
            func line(_ list: [String], tone: Tone = .warn, notes most: Int = 4, _ words: (String) -> String) {
                var part: [String] = [], size = 0, said = 0
                func flush() {
                    guard !part.isEmpty else { return }
                    if said < most { say(words(Format.list(part)), tone: tone) } else { cut = true }
                    said += 1
                    (part, size) = ([], 0)
                }
                for item in list {
                    if size + item.unicodeScalars.count > 240 { flush() }
                    part.append(item)
                    size += item.unicodeScalars.count + 2
                }
                flush()
            }
            // Most to know first: if room runs out, what's left is what matters least, and the page says there's more.
            line(flow.deletes) { L("By their names, these may delete: {list}", ["list": $0]) }
            line(flow.setsOffYours) { L("It sets off a flow of yours: {list}", ["list": $0]) }
            line(flow.servers) { L("It uses a server you added: {list}", ["list": $0]) }
            if flow.companionJobs > 0 { say(L("It gives your companion a whole job to do."), tone: .warn) }
            if flow.usesAI > 0 { say(L("It uses your AI."), tone: .warn) }
            line(flow.watches) { L("It keeps an eye on: {list}", ["list": $0]) }
            line(flow.changes) { L("It changes or sends something: {list}", ["list": $0]) }
            line(flow.files) { L("It works with files: {list}", ["list": $0]) }
            line(flow.readsFilled) { L("It reads, using values from earlier steps, which could send them out: {list}", ["list": $0]) }
            line(flow.setsOff) { L("It sets off another flow: {list}", ["list": $0]) }
            line(flow.missingTools) { L("It needs what isn't here, so Sideflow can't say what that does: {list}", ["list": $0]) }
            line(flow.missingFlows) { L("It names a flow that isn't here: {list}", ["list": $0]) }
            line(flow.reads, tone: .neutral) { L("It reads: {list}", ["list": $0]) }
            if blocks.isEmpty, !cut { say(L("It only works with words: it reads and changes nothing.")) }
            line(flow.starts, tone: .neutral) { L("It starts: {when}", ["when": $0]) }
            if cut { blocks.append(.note(L("There's more than this page can show. Read its steps before you turn it on."), tone: .warn)) }
            main.append(Section(flow.name, blocks, wide: true))
        }
        return frame(app, state: state, here: "flows", main)
    }

    static func firstRun(_ app: App, state: Arguments) -> Page {
        var hero = Hero(L("Teach your companion a routine"), detail: L("Say it once. Watch it practice, with nothing changed. Then it's yours."), symbol: "point.3.connected.trianglepath.dotted")
        hero.figure = .companion(.full)
        hero.says = L("What should I take off your hands?")
        // Flat, as the buttons are: the line alone runs from one colour to the other.
        hero.tile = [accent[0]]
        hero.wash = [accent[1]]
        var main = [Section(nil, [.hero(hero)], wide: true)]
        if !describing(app).isEmpty { main.append(Section(nil, describing(app), wide: true)) }
        main.append(Section(nil, [.action(importButton)], wide: true))
        main.append(Section(L("Or start from one of these"), [.cards(size: .small, templateCards(app)), .action(button(L("Start blank"), "new", style: .plain, symbol: "plus"))], wide: true))
        main.append(Section(L("Good to know"), [
            .note(L("Flows run while Sidefolk is running and your Mac is awake. If the Mac was asleep at the time, a flow runs once when it's back, or says it missed it: you choose per flow.")),
            .settings(L("How it tells you"), keys: ["tell"], ai: true),
        ], collapsed: true))
        var page = frame(app, state: state, here: "flows", main)
        page.companion = false
        return page
    }

    static func connectionsPage(_ app: App, state: Arguments) -> Page {
        let all = Connections.all(app.catalog, app.store), unused = Connections.unused(app.catalog, app.store)
        let addons = Action(L("Open Add-ons"), act: .settings("addons"), symbol: "puzzlepiece.extension")
        let cards = all.map { c -> Card in
            // What's waiting first: Sidefolk shows only so much of this, and a long list of flows shouldn't take it.
            var lines = [L("Used by {flows}", ["flows": Format.list(c.flows)])]
            if !c.waiting.isEmpty { lines.insert(L(one: "{count} run waiting for it", other: "{count} runs waiting for it", count: c.waiting.count), at: 0) }
            let kind = c.server ? L("MCP server") : L("Extension")
            return Card(c.title, detail: ([kind] + lines).joined(separator: " · "), symbol: c.server ? "server.rack" : "puzzlepiece.extension", color: tile[0],
                        badge: c.isHere ? Badge(L("Here"), tone: .good) : Badge(L("Missing"), tone: .warn), press: c.waiting.first.map { go(L("Open"), place(["run": $0])) })
        }
        var main = [Section(nil, [.bar(PageBar(L("Connections"), detail: L("What your flows reach beyond Sidefolk: extensions and MCP servers."), actions: [addons]))])]
        if all.isEmpty {
            main.append(Section(nil, [.note(L("None of your flows uses an extension or a server yet."))], wide: true))
        } else {
            main.append(Section(nil, [.cards(size: .small, cards)], wide: true))
        }
        if all.contains(where: { !$0.isHere }) {
            main.append(Section(nil, [.note(L("A run that gets to a missing one waits there for up to 7 days, with nothing done, and goes on by itself once it's back. Turn it back on in Add-ons."), tone: .warn)], wide: true))
        }
        if !unused.isEmpty {
            main.append(Section(L("Also here"), [.facts(nil, unused.map { ($0.title, L(one: "{count} action", other: "{count} actions", count: $0.tools)) })], collapsed: true, wide: true))
        }
        main.append(Section(nil, [.note(L("Accounts and keys stay with each extension or server; none of it is kept in a flow."))], wide: true))
        return frame(app, state: state, here: "connections", main)
    }

    static func templatesPage(_ app: App, state: Arguments) -> Page {
        frame(app, state: state, here: "templates", [
            Section(nil, [.bar(PageBar(L("Templates"), detail: L("Start from one, then make it yours.")))]),
            Section(nil, [.cards(size: .small, templateCards(app))], wide: true),
        ])
    }

    static func historyPage(_ app: App, state: Arguments) -> Page {
        let runs = app.store.runs().filter { $0.parent == nil }.prefix(40)
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

    /// What a way through a step is called on the board.
    static func partLabel(_ part: String, of step: Step) -> String {
        switch step.kind {
        case .choose(_, let paths, _):
            if part.hasPrefix("path"), let at = Int(part.dropFirst(4)), paths.indices.contains(at) { return paths[at].when.nonEmpty ?? L("Path {count}", ["count": Format.integer(at + 1)]) }
            return L("Otherwise")
        case .parallel(let lanes):
            if part.hasPrefix("lane"), let at = Int(part.dropFirst(4)), lanes.indices.contains(at) { return lanes[at].name }
            return part
        case .forEach: return L("Each item")
        case .repeatUntil: return L("Each time round")
        case .attempt: return part == "try" ? L("Try") : part == "recover" ? L("If it fails") : L("Either way")
        default: return part == "then" ? L("If so") : L("Otherwise")
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
        case .forEach: return ("repeat", "#1FA88A")
        case .repeatUntil: return ("arrow.clockwise", "#1FA88A")
        case .choose: return ("arrow.triangle.swap", "#1FA88A")
        case .attempt: return ("shield.lefthalf.filled", "#1FA88A")
        case .parallel: return ("arrow.triangle.branch", "#3B6FF5")
        case .call: return ("arrow.triangle.turn.up.right.circle.fill", "#5B8DEF")
        case .finish: return ("flag.checkered", "#6B7A90")
        case .data: return ("tablecells", "#6B7A90")
        case .form: return ("list.clipboard", "#F2B33D")
        case .waitFor: return ("hourglass.badge.plus", "#6B7A90")
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

    /// Copies at once, as the button says, on any tab. It's what's on screen, like the words beside it, and a menu shows only its label, so the label says when that isn't saved.
    /// As a file, where the person picks: Sidefolk's panel, and Sideflow never learns where. The label's in the menu's words, so it says what a copy says.
    static var exportNote: String { L("The file holds what the flows do and anything typed into their steps. It doesn't hold what you allowed, their runs or your accounts.") }

    static func exporting(_ flow: Flow) -> Action {
        Action(flow.hasUnsaved ? L("Export, with unsaved") : L("Export"), act: .save(name: flow.name, type: FlowFile.type, tool: "export_flows", input: ["flows": [flow.id]], note: exportNote), symbol: "square.and.arrow.up")
    }

    static func copyDefinition(_ flow: Flow) -> Action {
        copying(JSONText.write(["name": flow.name, "flow": FlowCodec.json(flow.draft)] as [String: Any]), flow, L("Copy as a definition"), unsaved: L("Copy definition, with unsaved"), symbol: "curlybraces")
    }

    static func copyWords(_ flow: Flow, _ app: App) -> Action {
        copying(Words.aloud(flow.draft, catalog: app.catalog), flow, L("Copy it in words"), unsaved: L("Copy in words, with unsaved"), symbol: "doc.on.doc")
    }

    private static func copying(_ words: String, _ flow: Flow, _ label: String, unsaved: String, symbol: String) -> Action {
        // Counted as the page carries it, escapes and all.
        guard JSONText.write([words]).utf8.count <= longestCopy else {
            return Action(L("Too long to copy from here"), tool: "ui", input: ui("save", ["flow": flow.id]), symbol: symbol, disabled: true)
        }
        return Action(flow.draft != flow.kept ? unsaved : label, act: .copy(words), symbol: symbol)
    }

    /// The page holds the words on every read, and a page past its own limit doesn't draw at all, so this stays well inside it.
    static let longestCopy = 20_000

    static func tabs(_ flow: Flow, state: Arguments) -> Block {
        var builder = PageTab("builder", L("Builder"), symbol: "point.3.connected.trianglepath.dotted", sections: [])
        builder.go = Go(set: ["tab": "builder"])
        var runs = PageTab("runs", L("Runs"), symbol: "chart.bar", sections: [])
        runs.go = Go(set: ["tab": "runs"])
        var activity = PageTab("activity", L("Activity"), symbol: "list.bullet", sections: [])
        activity.go = Go(set: ["tab": "activity"])
        let chosen = state.string("tab")
        return .tabs(selected: chosen == "runs" || chosen == "activity" ? chosen : "builder", [builder, runs, activity])
    }

    static func head(_ flow: Flow, _ app: App, ready: Bool, startable: Bool = true) -> PageBar {
        let practice = practice(flow, app), running = app.engine.isRunning(flow.id)
        let fix = ready ? nil : L("Fix what's marked first.")
        // What sets it off can't start yet: it may still practice, which makes no watch.
        let cantStart = fix ?? (startable ? nil : L("Sort out what sets it off first."))
        let canStart = ready && startable
        let saveFirst = flow.hasUnsaved
        let id = ["flow": flow.id]
        var actions: [Action] = [], extra: [Action] = []
        var pill = Badge(stateWord(flow, app).0, tone: stateWord(flow, app).1)
        // The board says the rest: when it runs, and how long it is.
        var sentence = L(one: "{when} · {count} step", other: "{when} · {count} steps", count: flow.draft.allSteps.count, ["when": Words.trigger(flow.draft.trigger)])
        if running, practice?.status == .running {
            pill = Badge(L("Practicing"), tone: .info)
            sentence = L("It reads for real and changes nothing.")
            if let practice { actions = [button(L("Stop practicing"), "stop_run", ["run": practice.id, "page_token": app.pageKey], symbol: "stop.fill")] }
        } else {
            switch flow.state {
            case .draft:
                if practiced(flow, app) != nil {
                    actions = [button(L("Practice run"), "practice", id, symbol: "play.fill", detail: fix ?? L("Reads for real, changes nothing."), disabled: !ready),
                               button(L("Run now"), "run", id, symbol: "play.fill", detail: fix ?? (Engine.needsCard(flow.kept) ? L("You read what it will do first, once.") : nil), disabled: !ready),
                               button(L("Turn on"), "start", id, style: .primary, symbol: "power", detail: cantStart ?? (Engine.needsCard(flow.kept) ? L("You read what it will do first.") : L("It only runs when you start it.")), disabled: !canStart)]
                } else {
                    actions = [button(L("Practice run"), "practice", id, style: .primary, symbol: "play.fill", detail: fix ?? L("Reads for real, changes nothing."), disabled: !ready)]
                    extra.append(button(L("Run now"), "run", id, symbol: "play.fill", detail: fix ?? (Engine.needsCard(flow.kept) ? L("You read what it will do first, once.") : nil), disabled: !ready))
                    extra.append(button(L("Turn on without practicing"), "start", id, symbol: "power", detail: cantStart ?? (Engine.needsCard(flow.kept) ? L("You read what it will do first.") : L("It only runs when you start it.")), disabled: !canStart))
                }
            case .on:
                actions = flow.hasChanges
                    ? [button(L("Practice run"), "practice", id, symbol: "play.fill", disabled: !ready), button(L("Apply changes"), "start", id, style: .primary, symbol: "checkmark", detail: cantStart, disabled: !canStart)]
                    : [button(L("Run now"), "run", id, symbol: "play.fill"), button(L("Pause"), "pause", id, symbol: "pause.fill")]
                if flow.hasChanges {
                    extra.append(button(L("Run now"), "run", id, symbol: "play.fill", detail: fix ?? L("Applies your changes, asking only what's new."), disabled: !ready))
                    extra.append(button(L("Go back to what's running"), "back_to_live", id, symbol: "arrow.uturn.backward"))
                }
            case .paused:
                actions = [button(L("Practice run"), "practice", id, symbol: "play.fill", disabled: !ready), button(L("Resume"), "resume", id, style: .primary, symbol: "play.fill", detail: cantStart, disabled: !canStart)]
            }
            // Theirs to end here too, not only in Settings. What's in the way of a card is on the same plan.
            if app.catalog.plan(flow.planId) != nil {
                extra.append(button(L("End what you allowed"), "end_plan", id, symbol: "xmark.seal", detail: L("It pauses, and asks again before it runs.")))
            }
        }
        if flow.state == .on, flow.hasChanges, !running { sentence = L("On, as before. Your changes aren't live.") }
        // Unsaved comes first: the one thing to do is keep or drop them, and the mark and the button say so wherever the flow stands.
        // A run that's under way has what it was given, so it doesn't stand in the way: one in a wait can be there for a day. A practice has the bar to itself until it stops.
        if saveFirst, !(running && practice?.status == .running) {
            pill = Badge(L("Unsaved changes"), tone: .warn)
            sentence = flow.state == .on ? L("Only here so far. What's running hasn't changed.") : L("Only here so far. ⌘S keeps them, ⌘Z steps back.")
            actions = [button(L("Discard"), "discard", id, style: .plain), button(L("Practice run"), "practice", id, symbol: "play.fill", detail: fix ?? L("Reads for real, changes nothing."), disabled: !ready || running),
                       button(L("Save"), "save", id, style: .primary, symbol: "checkmark", detail: L("⌘S"))]
            extra.removeAll { $0.label == L("Turn on without practicing") }
        } else if !running {
            actions.insert(Action(L("Saved"), tool: "ui", input: ui("save", id), style: .plain, symbol: "checkmark", disabled: true), at: 0)
        }
        extra += [button(L("Rename"), "rename_open", id, symbol: "pencil"),
                  button(L("Duplicate"), "duplicate", id, symbol: "plus.square.on.square"),
                  copyDefinition(flow),
                  copyWords(flow, app),
                  exporting(flow),
                  button(L("Delete this flow"), "ask_delete", id, style: .destructive, symbol: "trash")]
        return PageBar(flow.name, pill: pill, detail: sentence, actions: actions, menu: extra)
    }

    static func flowPage(_ flow: Flow, _ app: App, state: Arguments) -> Page {
        app.refreshPreflightIfOld(flow.id)
        let problems = flow.draft.problems(app.catalog)
        let trigger = app.preflight[flow.id]?[App.triggerCheck]
        var main = [Section(nil, [.bar(head(flow, app, ready: problems.isEmpty, startable: trigger?.decision != .deny)), tabs(flow, state: state)])]

        var notes: [Block] = []
        if let why = flow.pausedBecause { notes.append(.note(why, tone: .warn)) }
        if let why = flow.startProblem { notes.append(.note(why, tone: .warn)) }
        if let said = app.engine.quietlySaved(flow) { notes.append(.note(said, tone: .good)) }
        else if flow.hasChanges || flow.live == nil, let look = app.planChecks[flow.id] { notes.append(.note(look.head)) }
        if let last = flow.missed.last {
            notes.append(.note(L(one: "It missed {count} run, last at {time}: Sidefolk or your Mac was off.", other: "It missed {count} runs, last at {time}: Sidefolk or your Mac was off.", count: flow.missed.count, ["time": Format.dateTime(last)]), tone: .warn))
        }
        for p in problems where p.step == nil { notes.append(.note(p.text, tone: .warn)) }
        if !flow.draft.readsNumbersFromWords(app.catalog).isEmpty { notes.append(.note(L("Some steps read a number from words, and stop if they aren't plainly one number. Each one's form says what to do."), tone: .warn)) }
        main.append(Section(nil, [.tree(tree(flow, app, problems: problems))], wide: true))
        var end: [Section] = []
        if !notes.isEmpty { end.append(Section(nil, notes, place: .trailing)) }
        end += Inspector.sections(flow, app, problems: problems)
        end += checks(flow, app, problems: problems)
        end.append(Section(L("What you'll get"), [arriving(flow, app)], place: .trailing))
        var page = frame(app, state: state, here: nil, flow: flow.id, back: L("All flows"), main, end: end)
        let id = ["flow": flow.id]
        page.shortcuts = [PageShortcut("cmd+z", L("Undo"), tool: "ui", input: ui("undo", id)), PageShortcut("shift+cmd+z", L("Redo"), tool: "ui", input: ui("redo", id)),
                          PageShortcut("cmd+d", L("Duplicate this step"), tool: "ui", input: ui("dup_step", id))]
        // Always: pressing it is what hands over what's being typed, which only then makes the flow unsaved. Sidefolk commits the field first.
        page.shortcuts.append(PageShortcut("cmd+s", L("Save"), tool: "ui", input: ui("save", id)))
        return page
    }

    /// How it stands: what's in the way of turning it on, and what's different from what was saved and from what's running. Read before saving or applying, nothing done.
    static func checks(_ flow: Flow, _ app: App, problems: [FlowProblem]) -> [Section] {
        var out: [Section] = []
        let denied = app.preflight[flow.id]?.filter { $0.value.decision == .deny }.count ?? 0
        let count = problems.count + denied
        let blocks: [Block] = count == 0
            ? [.note(L("Nothing to fix. Everything it needs is allowed or will ask you."), tone: .good)]
            : problems.map { .note($0.text, tone: .warn) } + (denied > 0 ? [.note(L(one: "Sidefolk wouldn't allow {count} step as it stands: it's marked on the board.", other: "Sidefolk wouldn't allow {count} steps as they stand: they're marked on the board.", count: denied), tone: .warn)] : [])
        let untried = untried(flow, app)
        var all = blocks
        if !Connections.missing(flow, app.catalog, app.store).isEmpty {
            all.append(.action(go(L("See connections"), place(["view": "connections"]), symbol: "link")))
        }
        if !untried.isEmpty { all.append(.note(L("Not practiced yet: {ways}. A practice run takes one way; “In practice, pretend it gives” on a step can send it down another.", ["ways": Format.list(untried)]))) }
        out.append(Section(count == 0 ? L("Check") : L(one: "Check: {count} thing to fix", other: "Check: {count} things to fix", count: count), all, place: .trailing, collapsed: count == 0 && untried.isEmpty))
        func changes(_ title: String, from: FlowBody, to: FlowBody) {
            let lines = Editing.changes(from: from, to: to, catalog: app.catalog)
            guard !lines.isEmpty else { return }
            let shown = lines.prefix(12).joined(separator: "\n") + (lines.count > 12 ? "\n" + L(one: "and {count} more", other: "and {count} more", count: lines.count - 12) : "")
            out.append(Section(title, [.note(shown)], place: .trailing, collapsed: false))
        }
        if let saved = flow.saved { changes(L("Changed since you saved"), from: saved, to: flow.draft) }
        if let live = flow.live, live != flow.kept { changes(L("Different from what's running"), from: live, to: flow.kept) }
        return out
    }

    /// What the flow does, its last practice run's results on it while it hasn't changed since.
    static func tree(_ flow: Flow, _ app: App, problems: [FlowProblem]) -> CardTree {
        // An On flow shows how its last real run went; anything else, its practice of what's written now.
        let live = flow.state == .on && !flow.hasChanges && !flow.hasUnsaved
        let run = live ? app.store.runs(of: flow.id).first { $0.mode == .live && $0.body == flow.draft } : practice(flow, app)
        let untested: CardTree.Node.State = flow.state == .draft || flow.hasChanges || flow.hasUnsaved ? .pending : .none
        var first = CardTree.Node("start", FlowFile.short(Words.triggers(flow.draft), 240), kind: L("It starts"), symbol: triggerSymbol(flow.draft.trigger), color: tile[0], state: run != nil ? .done : untested, fixed: true)
        if let check = app.preflight[flow.id]?[App.triggerCheck], check.decision == .deny {
            first.state = .attention
            first.pill = Badge(check.share != nil ? L("Needs a folder") : L("Not allowed"), tone: .warn)
        }
        var nodes = [first]
        nodes += treeNodes(flow.draft.steps, body: flow.draft, app, run: run.map { withLanes($0, app) }, untested: untested, flow: flow, problems: problems)
        let selected: String? = switch app.nav.inspecting(flow) {
        case .trigger: "start"
        case .step(let id): id
        case .nothing: nil
        }
        let last = selected ?? flow.draft.allSteps.last?.id ?? "start"
        func quick(_ label: String, _ kind: String, _ symbol: String) -> Action { button(label, "add_kind", ["flow": flow.id, "after": last, "kind": kind], symbol: symbol) }
        return CardTree(nodes, selected: selected, select: .init(tool: "ui", input: ui("inspect", ["flow": flow.id]), key: "target"),
                        insert: .init(tool: "ui", input: ui("add_kind", ["flow": flow.id]), key: "after", label: L("Add a step")),
                        reorder: .init(tool: "ui", input: ui("reorder", ["flow": flow.id]), key: "move"), remove: .init(tool: "ui", input: ui("remove", ["flow": flow.id]), key: "step"), picker: picker(app),
                        tools: [quick(L("Add a condition"), "if", "arrow.triangle.branch"), quick(L("Write with AI"), "ai", "sparkles"), quick(L("Tell me"), "tell", "bell"),
                                button(L("Practice run"), "practice", ["flow": flow.id], symbol: "play", disabled: !problems.isEmpty),
                                button(L("Undo"), "undo", ["flow": flow.id], symbol: "arrow.uturn.backward", detail: L("Undo (⌘Z)"), disabled: app.history[flow.id]?.canUndo != true),
                                button(L("Redo"), "redo", ["flow": flow.id], symbol: "arrow.uturn.forward", detail: L("Redo (⇧⌘Z)"), disabled: app.history[flow.id]?.canRedo != true)], line: line)
    }

    static func treeNodes(_ steps: [Step], body: FlowBody, _ app: App, run: Run?, untested: CardTree.Node.State, flow: Flow?, problems: [FlowProblem], notTaken: Bool = false) -> [CardTree.Node] {
        steps.map { step in
            let look = look(step, app)
            let check = flow.flatMap { app.preflight[$0.id]?[step.id] }
            let said = Words.card(step, body: body, catalog: app.catalog)
            // What's shown of what's written: a step can hold far more than a card, and a page fails whole past its limit.
            var node = CardTree.Node(step.id, FlowFile.short(said.line, 240), kind: FlowFile.short(said.head, 30), symbol: look.symbol, color: look.color, state: untested)
            if let problem = problems.first(where: { $0.step == step.id }) {
                node.state = .attention
                node.pill = Badge(L("To fix"), tone: .warn)
                node.title = FlowFile.short(problem.text, 240)
            } else if check?.decision == .deny {
                node.state = .attention
                node.pill = Badge(check?.share != nil ? L("Needs a folder") : L("Not allowed"), tone: .warn)
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
            if !step.parts.isEmpty {
                let tested = run?.record(of: step.id) != nil
                // What ran says which way it went; an empty way was taken when no other ran.
                let ran = step.parts.map { part in part.steps.contains { inner in run?.records.contains { $0.step == inner.id } == true } }
                let any = ran.contains(true)
                node.branches = step.parts.enumerated().map { at, part in
                    let taken: Bool? = tested ? (ran[at] || (!any && part.steps.isEmpty)) : nil
                    return CardTree.Branch("\(part.id):\(step.id)", partLabel(part.id, of: step), tone: .neutral, taken: taken,
                                           nodes: treeNodes(part.steps, body: body, app, run: run, untested: untested, flow: flow, problems: problems, notTaken: notTaken || taken == false), hint: L("Add a step"))
                }
            }
            return node
        }
    }

    static func result(_ r: Run.Record) -> (CardTree.Node.State, Badge?) {
        switch r.status {
        case .running: (.active, Badge(L("Working…"), tone: .info))
        case .done: (.done, nil)
        case .would: (.pending, Badge(L("Practice: not done"), tone: .neutral))
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
            .init("if", L("If…"), detail: L("Do something only sometimes, with an “otherwise”"), meta: L("Logic"), symbol: "arrow.triangle.branch", color: "#1FA88A", categories: ["suggested", "logic"]),
            .init("text", L("Compose text"), detail: L("Put values together"), meta: L("Logic"), symbol: "text.quote", color: "#6B7A90", categories: ["logic"]),
            .init("wait", L("Wait"), detail: L("Up to a day; survives quitting"), meta: L("Logic"), symbol: "hourglass", color: "#6B7A90", categories: ["logic"]),
            .init("flow", L("Run another flow"), detail: L("Sets it off and carries on"), meta: L("Logic"), symbol: "arrow.triangle.turn.up.right.circle", color: "#5B8DEF", categories: ["logic"]),
        ]
        items += [
            .init("for_each", L("For each"), detail: L("Do steps once per item of a list"), meta: L("Logic"), symbol: "repeat", color: "#1FA88A", categories: ["suggested", "logic"]),
            .init("repeat", L("Repeat until"), detail: L("Go round until something holds, with a limit"), meta: L("Logic"), symbol: "arrow.clockwise", color: "#1FA88A", categories: ["logic"]),
            .init("choose", L("Choose a path"), detail: L("Several ways to go, by one value"), meta: L("Logic"), symbol: "arrow.triangle.swap", color: "#1FA88A", categories: ["logic"]),
            .init("try", L("Try"), detail: L("Do something else if a step fails"), meta: L("Logic"), symbol: "shield.lefthalf.filled", color: "#1FA88A", categories: ["logic"]),
            .init("parallel", L("At the same time"), detail: L("Several things at once, then carry on"), meta: L("Logic"), symbol: "arrow.triangle.branch", color: "#3B6FF5", categories: ["logic"]),
            .init("call", L("Run a flow and wait"), detail: L("Use another flow and its result"), meta: L("Logic"), symbol: "arrow.triangle.turn.up.right.circle.fill", color: "#5B8DEF", categories: ["logic"]),
            .init("finish", L("Finish here"), detail: L("End the flow, with a result"), meta: L("Logic"), symbol: "flag.checkered", color: "#6B7A90", categories: ["logic"]),
            .init("data", L("Work with data"), detail: L("Filter, sort, count, read a table or JSON"), meta: L("Logic"), symbol: "tablecells", color: "#6B7A90", categories: ["logic"]),
            .init("form", L("A form for you"), detail: L("Several questions, and it waits days if need be"), meta: L("Reaches you"), symbol: "list.clipboard", color: "#F2B33D", categories: ["logic"]),
            .init("wait_for", L("Wait for something"), detail: L("Until something happens, or time runs out"), meta: L("Logic"), symbol: "hourglass.badge.plus", color: "#6B7A90", categories: ["logic"]),
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
        guard let run else { return .notice(PageNotice(placeholder: L("Practice it to see the real thing"))) }
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
        let runs = app.store.runs(of: flow.id).filter { $0.parent == nil }
        let live = runs.filter { $0.mode != .practice }
        var body: [Section] = []
        if !live.isEmpty || !flow.missed.isEmpty {
            let done = live.prefix(14).reversed().map { run in PageTicks.Item("\(Format.dateTime(run.startedAt)), \(Summaries.status(run))", tone: tone(run)) }
            let missed = flow.missed.suffix(7).map { PageTicks.Item("\(Format.dateTime($0)), \(L("Missed"))", tone: .neutral, hollow: true) }
            body.append(Section(nil, [.ticks(PageTicks(L("Lately"), caption: flow.missed.isEmpty ? nil : L("Missed: Sidefolk or your Mac was off."), items: Array(missed) + Array(done)))], wide: true))
        }
        body.append(Section(nil, runs.isEmpty ? [.note(L("No runs yet."))] : [runList(Array(runs.prefix(20)), named: false)], wide: true))
        var end = [Section(L("What arrived"), [arriving(flow, app)], place: .trailing)]
        if let versions = versions(flow, app) { end.append(versions) }
        if flow.state != .draft {
            end.append(Section(nil, [.note(L("It may only do what you read when you turned it on. You can end that in Settings › Add-ons."))], place: .trailing))
        }
        return frame(app, state: state, here: nil, flow: flow.id, back: L("All flows"), [Section(nil, [.bar(head(flow, app, ready: flow.draft.problems(app.catalog).isEmpty)), tabs(flow, state: state)])] + body, end: end)
    }

    // MARK: A flow's activity

    /// Every step it took, newest first, from its runs' own journals: what it did, not how each run went.
    static func flowActivityPage(_ flow: Flow, _ app: App, state: Arguments) -> Page {
        var rows: [(at: Date, item: RecentItem)] = flow.missed.map { ($0, RecentItem(L("Missed"), detail: L("Sidefolk or your Mac was off."), at: $0, tone: .neutral, symbol: "moon")) }
        for run in app.store.runs(of: flow.id).prefix(10) {
            for record in run.records {
                let (state, _) = result(record)
                let tone: Tone = state == .attention ? .warn : state == .done ? .good : .neutral
                let kind = run.mode == .practice ? L("Practice run") : run.why
                rows.append((record.at, RecentItem(record.summary, detail: kind, at: record.at, tone: tone, symbol: run.body.step(record.step).map { look($0, app).symbol })))
            }
        }
        let items = rows.sorted { $0.at > $1.at }.prefix(20).map(\.item)
        let body: Block = items.isEmpty ? .note(L("Nothing yet. Each step it takes shows here.")) : .recent(nil, Array(items))
        return frame(app, state: state, here: nil, flow: flow.id, back: L("All flows"), [
            Section(nil, [.bar(head(flow, app, ready: flow.draft.problems(app.catalog).isEmpty)), tabs(flow, state: state)]),
            Section(nil, [body], wide: true),
        ])
    }

    // MARK: One run

    static func runPage(_ run: Run, _ app: App, state: Arguments) -> Page {
        let id = ["run": run.id]
        var detail = run.why
        var end: [Section] = []
        func choices(_ title: String, _ options: [Option], note: Block? = nil) -> Section {
            var blocks: [Block] = note.map { [$0] } ?? []
            blocks.append(.picker(title, style: .rows, options, selected: "", tool: "ui", input: ui("proceed", ["run": run.id, "page_token": app.pageKey]), key: "how"))
            return Section(nil, blocks, place: .trailing)
        }
        let current = currentStep(run)
        let said = current.flatMap { run.record(of: $0)?.summary } ?? ""
        if app.store.isHeldBack(flow: run.flow), !run.status.isOver { detail = L("Its flow can't be read now, so this can't go on yet. It goes on if the flow comes back.") }
        else { switch run.status {
        case .interrupted:
            detail = L("Sidefolk stopped in the middle of this: {step}. It may have happened already.", ["step": said])
            end.append(choices(L("Which is true?"), [
                Option("try_again", L("It didn't happen: try again"), detail: L("Does it now, then carries on."), symbol: "arrow.clockwise"),
                Option("carry_on", L("It happened: carry on"), detail: L("Doesn't do it again."), symbol: "play"),
                Option("stop", L("Stop here"), detail: L("Nothing more of this run."), symbol: "stop"),
            ]))
        case .waiting where run.form != nil || !run.waitingOn.isEmpty:
            detail = said
            if let form = formSection(run, app) { end.append(form) }
            if let asking = run.waitingOn.compactMap({ app.store.run($0) }).first(where: { $0.form != nil }) {
                end.append(Section(nil, [.action(go(L("Fill it in"), place(["run": asking.id]), style: .accent, symbol: "square.and.pencil"))], place: .trailing))
            }
        case .waiting where run.paused:
            detail = L("Paused between steps. Nothing more runs until you say.")
            end.append(choices(L("What now?"), [
                Option("try_again", L("Go on"), detail: L("Carries on from the next step."), symbol: "play"),
                Option("stop", L("Stop here"), detail: L("Nothing more of this run."), symbol: "stop"),
            ]))
        case .waiting where run.connection != nil:
            let name = run.connection.flatMap { Connections.id(of: $0.tool) }.map { Connections.title($0, app.catalog, app.store) } ?? ""
            detail = app.engine.pausedFlow(holding: run).map { L("Waiting for {name}, and {flow} is paused. This step hasn't run: once it's back, it goes on when you resume {flow}.", ["name": name, "flow": $0.name]) }
                ?? L("Waiting for {name}. This step hasn't run, and it goes on by itself once it's back.", ["name": name])
            end.append(choices(L("Don't want to wait?"), [
                Option("carry_on", L("Skip this step"), detail: L("Goes on without it."), symbol: "forward"),
                Option("stop", L("Stop here"), detail: L("Nothing more of this run."), symbol: "stop"),
            ]))
            end.append(Section(nil, [.action(Action(L("Open Add-ons"), act: .settings("addons"), symbol: "puzzlepiece.extension"))], place: .trailing))
        case .needs_you, .waiting:
            if let problem = run.problem { detail = problem }
            let skip = Option("carry_on", L("Skip this step"), detail: L("Goes on without it."), symbol: "forward"), stop = Option("stop", L("Stop here"), detail: L("Nothing more of this run."), symbol: "stop")
            end.append(choices(L("What now?"), app.engine.stepLeftBehind(run) ? [stop, skip] : [Option("try_again", L("Try again"), detail: L("Does it now, then carries on."), symbol: "arrow.clockwise"), skip, stop]))
        case .failed:
            if let problem = run.problem { detail = problem }
        case .stopped:
            // Stop ends this and what it's part of. A flow it set off has its own approval and its own Stop, and they should know it's there.
            let still = run.setOffRuns.compactMap { app.store.run($0) }.filter { !$0.status.isOver }
            let says = still.map { L("Another flow it started is still running: {name}.", ["name": $0.flowName]) }
            let all = [run.problem].compactMap(\.self) + says
            if !all.isEmpty { detail = Format.sentences(all) }
            if let first = still.first { end.append(Section(nil, [.action(go(L("Open it"), place(["run": first.id]), symbol: "arrow.up.right"))], place: .trailing)) }
        case .running:
            if let now = app.engine.progress[run.id] {
                let parts = [now.fraction.map { Format.percent($0) }, now.message].compactMap(\.self)
                if !parts.isEmpty { detail = L("Working: {how}", ["how": parts.joined(separator: " · ")]) }
            }
        default:
            break
        } }
        if app.engine.canGoOn(from: run) {
            let again = app.engine.stepsFromHere(run).map { Words.label($0, catalog: app.catalog) }
            end.append(Section(L("Try again from here"), [
                .note(L("Keeps what it made before this. These run again, for real: {steps}", ["steps": Format.list(again)])),
                .action(button(L("Try again from here"), "run_again", ["run": run.id, "here": true], symbol: "arrow.uturn.forward")),
            ], place: .trailing))
        }
        if run.mode == .practice { end.append(Section(nil, [.note(L("Practice run: nothing was changed."))], place: .trailing)) }
        if let output = run.records.reversed().first(where: { $0.output?.nonEmpty != nil })?.output?.clipped(Engine.keptOutput) {
            end.append(Section(L("What it came to"), [.notice(PageNotice(title: run.flowName, body: output, time: run.endedAt.map { Format.time($0) }))], place: .trailing))
        }
        var nodes = [CardTree.Node("start", FlowFile.short(run.why, 240), kind: L("It started"), symbol: triggerSymbol(run.body.trigger), color: tile[0], state: .done, fixed: true)]
        nodes += treeNodes(run.body.steps, body: run.body, app, run: withLanes(run, app), untested: .pending, flow: nil, problems: [])
        let selected = app.nav.runStep[run.id]
        if let selected { end = stepDetail(run, step: selected, scope: app.nav.runScope[run.id], app) + end }
        return frame(app, state: state, here: nil, flow: run.flow, back: run.flowName, [
            Section(nil, [.bar(PageBar(run.flowName, pill: Badge(Summaries.status(run), tone: tone(run)), detail: detail, actions: run.status == .running || run.status == .waiting
                ? (run.status == .running && run.mode != .practice ? [button(L("Pause after this step"), "pause_run", id, symbol: "pause.fill")] : []) + [button(L("Stop"), "stop_run", ["run": run.id, "page_token": app.pageKey], symbol: "stop.fill")]
                : run.status.isOver && run.parent == nil ? [button(L("Run again"), "run_again", id, symbol: "arrow.clockwise")] : []))]),
            Section(nil, [.tree(CardTree(nodes, selected: selected, select: .init(tool: "ui", input: ui("inspect_run", ["run": run.id]), key: "target"), line: line))], wide: true),
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
    private static let fillable: [String: Set<String>] = ["notes.save": ["text"], "notes.search": ["query"], "voice.say": ["text"], "reminders.create": ["title"], "notify.user": ["title", "body"], "ask.user": ["question"]]

    static func asksEachTime(_ step: Step, catalog: Catalog? = nil) -> Bool {
        guard case .action(let tool, let input) = step.kind else { return false }
        if tool == "clipboard.read" || catalog?.tool(tool)?.risk == "high" { return true }
        let open = fillable[tool] ?? []
        return input.contains { key, value in !open.contains(key) && value.strings.contains { !Values.references($0).isEmpty } }
    }
}
