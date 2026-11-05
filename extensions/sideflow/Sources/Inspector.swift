import Foundation
import SidefolkExtensionKit

/// What's selected on the tree, as a form that says what it does and asks only what it needs. From each tool's own schema, so an extension installed tomorrow has its form with
/// no change here. What's needed comes first; what's optional, and how a step behaves, is under More options.
@MainActor enum Inspector {
    static func sections(_ flow: Flow, _ app: App, problems: [FlowProblem]) -> [Section] {
        switch app.nav.inspecting(flow) {
        case .nothing: return []
        case .trigger: return trigger(flow, check: app.preflight[flow.id]?[App.triggerCheck])
        case .step(let id):
            guard let step = flow.draft.step(id) else { return trigger(flow, check: app.preflight[flow.id]?[App.triggerCheck]) }
            return self.step(step, flow, app, problems: problems)
        }
    }

    private static func base(_ flow: Flow, _ op: String, _ extra: [String: Any] = [:]) -> [String: Any] {
        extra.merging(["op": op, "flow": flow.id]) { own, _ in own }
    }

    /// What Guard says of it, with the way forward: never only that it can't.
    static func refusal(_ check: Actions.Check?) -> [Block] {
        guard let check, check.decision == .deny else { return [] }
        guard let share = check.share else { return [.note(check.why ?? L("Sidefolk doesn't allow this."), tone: .warn)] }
        return [.note(L("The folder {path} is in isn't shared with Sidefolk yet.", ["path": Paths.show(share.path)]), tone: .warn),
                .action(Action(L("Share this folder…"), act: .share(path: share.path, write: share.write), style: .accent, symbol: "folder.badge.plus"))]
    }

    // MARK: What starts it

    static func trigger(_ flow: Flow, check: Actions.Check? = nil) -> [Section] {
        let t = flow.draft.trigger
        let kind: String = switch t {
        case .manual: "manual"
        case .days: "days"
        case .every: "every"
        case .watch: "watch"
        case .event: "event"
        }
        var main: [Block] = refusal(check)
        main.append(.choice(L("It starts"), options: [("days", L("On days and at a time")), ("every", L("Every so many minutes")), ("event", L("When something happens")),
                                                      ("watch", L("When something changes")), ("manual", L("Only when I ask"))],
                            selected: kind, tool: "ui", input: base(flow, "trigger_kind")))
        var more: [Block] = []
        switch t {
        case .manual:
            main.append(.note(L("Run it from here, or say “run {name}”.", ["name": flow.name])))
        case .days(let days, let hour, let minute, let catchUp):
            let names = [("mon", L("Mon")), ("tue", L("Tue")), ("wed", L("Wed")), ("thu", L("Thu")), ("fri", L("Fri")), ("sat", L("Sat")), ("sun", L("Sun"))]
            main.append(.several(MultiChoice(L("Days"), options: names, selected: days.map { FlowCodec.days[$0 - 1] }, tool: "ui", input: base(flow, "days"))))
            main.append(.edit(EditField("at", L("At"), value: String(format: "%02d:%02d", hour, minute), placeholder: "08:30", kind: .time, tool: "ui", input: base(flow, "at"))))
            more.append(catchUpSwitch(flow, catchUp))
        case .every(let minutes, let catchUp):
            main.append(.edit(EditField("every", L("Every (minutes)"), value: String(minutes), detail: L("{count} at the least.", ["count": Format.integer(FlowBody.shortestEvery)]), kind: .number, tool: "ui", input: base(flow, "every"))))
            more.append(catchUpSwitch(flow, catchUp))
        case .watch(let w):
            main.append(.choice(L("What to watch"), options: [("url_change", L("A web page changes")), ("site_status", L("A site goes down or comes back")), ("file_changes", L("A file changes")),
                                                              ("file_appears", L("A file appears")), ("folder_new_file", L("A new file in a folder")), ("process_exits", L("A program quits"))],
                                selected: w.kind, tool: "ui", input: base(flow, "watch_kind")))
            let (label, detail, placeholder): (String, String, String) = switch w.kind {
            case "url_change", "site_status": (L("The address"), L("The whole address of the page or site."), "https://example.com")
            case "folder_new_file": (L("The folder"), L("Its full path."), "~/Downloads")
            case "process_exits": (L("The program"), L("Its name, as in Activity Monitor."), "Xcode")
            default: (L("The file"), L("Its full path."), "~/Documents/report.txt")
            }
            main.append(.edit(EditField("target", label, value: w.target, detail: detail, placeholder: placeholder, tool: "ui", input: base(flow, "watch_target"))))
            if check?.decision == .ask, w.target.contains("/.") {
                main.append(.note(L("This file is in a hidden folder. Sideflow sees only when it changes, never what's in it.")))
            }
            if w.kind == "url_change" {
                main.append(.edit(EditField("contains", L("Only when it says"), value: w.contains ?? "", placeholder: L("Any change"), tool: "ui", input: base(flow, "watch_contains"))))
            }
            if w.kind == "folder_new_file" {
                main.append(.edit(EditField("pattern", L("Only files like"), value: w.pattern ?? "", placeholder: "*.pdf", tool: "ui", input: base(flow, "watch_pattern"))))
            }
            if w.kind != "process_exits" {
                more.append(.edit(EditField("every", L("Look every (seconds)"), value: w.everySeconds.map(String.init) ?? "", detail: L("Files: 15 at the least. Sites: 60. Web pages: 300."),
                                            placeholder: L("Sidefolk's usual pace"), kind: .number, tool: "ui", input: base(flow, "watch_every"))))
            }
            more.append(.edit(EditField("rest", L("Then rest (minutes)"), value: w.restMinutes.map(String.init) ?? "", detail: L("After it sets the flow off, for something that keeps changing."),
                                        placeholder: L("No rest"), kind: .number, tool: "ui", input: base(flow, "watch_rest"))))
            main.append(.note(L("Later steps can use what it saw: “What set it off”.")))
        case .event(let name, let contains):
            main.append(.choice(L("What happens"), options: Trigger.events.map { ($0, Words.eventName($0)) }, selected: name, tool: "ui", input: base(flow, "event_kind")))
            main.append(.edit(EditField("event_contains", L("Only if it mentions"), value: contains ?? "", placeholder: L("Anything"), tool: "ui", input: base(flow, "event_contains"))))
            main.append(.note(L("Later steps can use its words: “What set it off”.")))
        }
        main += alsoWhen(flow)
        more.append(.edit(EditField("name", L("This flow's name"), value: flow.name, tool: "ui", input: base(flow, "rename"))))
        if case .manual = t {} else {
            more.append(.choice(L("If it's set off while running"), options: [("one_more", L("Run once more after")), ("queue", L("Run each in turn")), ("skip", L("Let it go"))], selected: flow.draft.overlap.rawValue, tool: "ui", input: base(flow, "overlap")))
        }
        switch t {
        case .days, .every:
            more.append(.edit(EditField("zone", L("By the clock of"), value: flow.draft.timeZone ?? "", detail: L("A time zone, like Europe/Paris. Empty for this Mac's."), placeholder: L("This Mac"), tool: "ui", input: base(flow, "time_zone"))))
        case .watch, .event:
            more.append(.edit(EditField("sample", L("In practice, what set it off"), value: flow.draft.triggerSample ?? "", detail: L("Words for a practice run to go on."), kind: .multiline, tool: "ui", input: base(flow, "trigger_sample"))))
        case .manual: break
        }
        return [Section(L("When it runs"), main, place: .trailing, detail: L("What sets this flow off, without you pressing anything.")),
                Section(L("More options"), more, place: .trailing, collapsed: true)]
    }

    /// The other ways it starts, each with what it takes, and room for more.
    private static func alsoWhen(_ flow: Flow) -> [Block] {
        var out: [Block] = []
        for (at, more) in flow.draft.alsoWhen.enumerated() {
            func input(_ op: String) -> [String: Any] { base(flow, op, ["also": at]) }
            switch more {
            case .days(let days, let hour, let minute, _):
                let names = [("mon", L("Mon")), ("tue", L("Tue")), ("wed", L("Wed")), ("thu", L("Thu")), ("fri", L("Fri")), ("sat", L("Sat")), ("sun", L("Sun"))]
                out.append(.several(MultiChoice(L("Also on"), options: names, selected: days.map { FlowCodec.days[$0 - 1] }, tool: "ui", input: input("days"))))
                out.append(.edit(EditField("also.\(at).at", L("At"), value: String(format: "%02d:%02d", hour, minute), placeholder: "17:00", kind: .time, tool: "ui", input: input("at"))))
            case .every(let minutes, _):
                out.append(.edit(EditField("also.\(at).every", L("Also every (minutes)"), value: String(minutes), kind: .number, tool: "ui", input: input("every"))))
            case .event(let name, let contains):
                out.append(.choice(L("Also when"), options: Trigger.events.map { ($0, Words.eventName($0)) }, selected: name, tool: "ui", input: input("event_kind")))
                out.append(.edit(EditField("also.\(at).contains", L("Only if it mentions"), value: contains ?? "", placeholder: L("Anything"), tool: "ui", input: input("event_contains"))))
            case .manual, .watch: break
            }
            out.append(.action(Action(L("Remove this"), tool: "ui", input: input("also_remove"), style: .plain, symbol: "minus.circle")))
        }
        if flow.draft.triggers.count < FlowBody.mostTriggers {
            out.append(.action(Action(L("Also at a time"), tool: "ui", input: base(flow, "also_add", ["kind": "days"]), style: .plain, symbol: "plus.circle")))
            out.append(.action(Action(L("Also when something happens"), tool: "ui", input: base(flow, "also_add", ["kind": "event"]), style: .plain, symbol: "plus.circle")))
        }
        return out
    }

    private static func catchUpSwitch(_ flow: Flow, _ on: Bool) -> Block {
        .toggle(L("If the Mac was off, run once when it's back"), detail: on ? nil : L("Otherwise it notes that it missed the run."), on: on, tool: "ui", input: base(flow, "catch_up"))
    }

    // MARK: Parts

    static func toolSymbol(_ t: Catalog.Tool) -> String {
        switch t.category {
        case "notes": "note.text"
        case "time": "calendar"
        case "web": "globe"
        case "files": "folder"
        case "watch": "eye"
        default: "square.grid.2x2"
        }
    }

    /// What a field can use: what's sure to have run before this step, then what's always there. Nothing from a path that may not have been taken.
    static func tokens(before id: String, flow: Flow, _ app: App) -> [EditField.Token] {
        let earlier = L("From earlier steps"), always = L("Always there")
        var out = [EditField.Token]()
        let around = Editing.around(id, in: flow.draft)
        for name in inputs(of: flow.draft) { out.append(.init(L("It was given: {name}", ["name": name]), value: "{{input.\(name)}}", symbol: "arrow.down.circle", group: earlier)) }
        if around.contains(.loop) {
            out.append(.init(L("This item"), value: "{{item}}", symbol: "repeat", group: earlier))
            out.append(.init(L("Its number"), value: "{{index}}", symbol: "number", group: earlier))
        }
        if around.contains(.recover) { out.append(.init(L("What went wrong"), value: "{{error}}", symbol: "exclamationmark.triangle", group: earlier)) }
        for step in Editing.available(before: id, in: flow.draft) {
            out.append(.init(Words.label(step, catalog: app.catalog), value: "{{\(step.id)}}", symbol: Pages.look(step, app).symbol, group: earlier))
            // A record's fields, each its own: nobody has to write a path.
            let label = Words.label(step, catalog: app.catalog), symbol = Pages.look(step, app).symbol
            if case .action(let tool, _) = step.kind { for name in app.catalog.tool(tool)?.outputFields ?? [] { out.append(.init("\(label) › \(name)", value: "{{\(step.id).\(name)}}", symbol: symbol, group: earlier)) } }
            if let fields = step.fields { for name in fields.keys.sorted() { out.append(.init("\(label) › \(name)", value: "{{\(step.id).\(name)}}", symbol: symbol, group: earlier)) } }
            if case .form(let form) = step.kind { for field in form.fields { out.append(.init("\(label) › \(field.label)", value: "{{\(step.id).\(field.name)}}", symbol: symbol, group: earlier)) } }
            if case .parallel(let lanes) = step.kind { for (lane, key) in zip(lanes, Engine.keys(lanes)) { out.append(.init("\(label) › \(lane.name)", value: "{{\(step.id).\(key)}}", symbol: symbol, group: earlier)) } }
        }
        switch flow.draft.trigger {
        case .watch, .event: out.append(.init(L("What set it off"), value: "{{trigger}}", symbol: "bolt", group: always))
        default: break
        }
        out.append(.init(L("Today's date"), value: "{{today}}", symbol: "calendar", group: always))
        out.append(.init(L("The time"), value: "{{now}}", symbol: "clock", group: always))
        return out
    }

    /// What the step does, in a sentence: the first thing a form says.
    private static func explanation(_ step: Step, _ app: App) -> (title: String, detail: String) {
        switch step.kind {
        case .action(let name, _):
            if name == "companion.job" { return (L("Let your companion do it"), L("Your companion does this with all its tools, under your own trust settings. It uses your AI, and what it does is in History.")) }
            let tool = app.catalog.tool(name)
            let first = tool?.description.split(separator: ".").first.map { String($0).trimmed + "." }
            return (tool?.title ?? name, first.map { String($0.prefix(160)) } ?? L("One action. Later steps can use its result."))
        case .ai: return (L("Write with AI"), L("Your AI writes this text from only the words below, with no tools. Later steps can use it. Each use counts toward your AI's usage."))
        case .ask: return (L("Ask me"), L("It stops and asks you on a card. Later steps can use your answer."))
        case .text: return (L("Compose text"), L("Puts words and values together for later steps."))
        case .branch: return (L("Condition"), L("It checks something, then takes one of two paths: “If so” or “Otherwise”."))
        case .wait: return (L("Wait"), L("Up to a day. It carries on after Sidefolk restarts."))
        case .flow: return (L("Run another flow"), L("It sets that flow off and carries on, without waiting for it."))
        case .forEach: return (L("For each"), L("It goes through a list, doing the steps inside once per item."))
        case .repeatUntil: return (L("Repeat until"), L("It does the steps inside, looks, and goes round again until this holds. Everything it does each time counts, so keep what's inside safe to repeat."))
        case .choose: return (L("Choose a path"), L("It looks at one value and takes the first path whose words it mentions, or “Otherwise”."))
        case .attempt: return (L("Try"), L("If a step under “Try” fails, the steps under “If it fails” run instead. The steps under “Either way” run in any case."))
        case .parallel: return (L("At the same time"), L("Each lane runs at once, and it carries on when all are done. If one fails, the step fails."))
        case .call: return (L("Run a flow and wait"), L("It runs another flow from start to end, then carries on with its result."))
        case .finish: return (L("Finish here"), L("The flow ends at this step. A flow that called this one gets the result."))
        case .data: return (L("Work with data"), L("It changes a value into another, with nothing outside this run."))
        case .form: return (L("A form for you"), L("It stops and waits for you to fill this in on this page, for days if need be, and carries on after a restart."))
        case .waitFor: return (L("Wait for something"), L("It waits until this happens, or fails when the time runs out."))
        }
    }

    // MARK: A step

    static func step(_ step: Step, _ flow: Flow, _ app: App, problems: [FlowProblem]) -> [Section] {
        let on = base(flow, "", ["step": step.id])
        func input(_ op: String, _ extra: [String: Any] = [:]) -> [String: Any] { on.merging(extra.merging(["op": op]) { a, _ in a }) { _, new in new } }
        let tokens = tokens(before: step.id, flow: flow, app)
        var main: [Block] = [], more: [Block] = []
        for p in problems where p.step == step.id { main.append(.note(p.text, tone: .warn)) }
        main += refusal(app.preflight[flow.id]?[step.id])
        if flow.draft.readsNumbersFromWords(app.catalog).contains(step.id) { main.append(.note(L("This compares words, so it stops if they aren't plainly one number. Take the number from a tool's field or an AI step's field."), tone: .warn)) }
        let looked = app.planChecks[flow.id]?.byStep[step.id]
        if let looked {
            if let mark = PlanLook.mark(looked) { main.append(.note(mark.words, tone: mark.tone)) }
        } else if case .action(let name, _) = step.kind, app.catalog.tool(name)?.risk == "high" {
            main.append(.note(L("Sidefolk can't vouch for what this one does, so it asks you each time, whatever you've allowed.")))
        } else if Hints.asksEachTime(step) {
            main.append(.note(L("A value filled in when it runs could send it anywhere, so this step asks you each time. Write it out in full and it won't.")))
        }
        switch step.kind {
        case .action(let name, let values):
            guard let tool = app.catalog.tool(name) else {
                main.append(.note(L("This tool isn't here now: {tool}.", ["tool": name]), tone: .warn))
                break
            }
            let lastRun = app.store.latest(of: flow.id)?.values
            let offered = annotated(tokens, flow: flow, app, last: lastRun)
            for p in tool.parameters {
                let blocks = field(p, value: values[p.name], step: step, flow: flow.id, tokens: offered, last: lastRun, app, input: input)
                // What's optional stays out of the way unless it's been filled in.
                if p.required || values[p.name] != nil { main += blocks } else { more += blocks }
            }
            if tool.parameters.isEmpty { main.append(.note(L("Nothing to set up: it just does this."))) }
        case .ai(let prompt):
            main.append(.edit(EditField("\(step.id).prompt", L("What should the AI write?"), value: prompt, placeholder: L("Three short lines about…"), kind: .multiline, tokens: tokens, tool: "ui", input: input("ai_prompt"))))
        case .ask(let question, let options):
            main.append(.edit(EditField("\(step.id).question", L("The question"), value: question, kind: .multiline, tokens: tokens, tool: "ui", input: input("question"))))
            main.append(.edit(EditField("\(step.id).options", L("Answers to choose from"), value: options.joined(separator: ", "), detail: L("2 to 4, with commas between them. None lets you type."), tool: "ui", input: input("options"))))
        case .text(let text):
            main.append(.edit(EditField("\(step.id).text", L("The text"), value: text, kind: .multiline, tokens: tokens, tool: "ui", input: input("compose"))))
        case .branch(let c, _, _):
            main += conditionForm(c, step: step, tokens: tokens, input: input)
        case .flow(let name):
            main.append(flowPicker(flow, selected: name, app, input: input("run_flow")))
        case .wait(let minutes):
            main.append(.edit(EditField("\(step.id).minutes", L("Minutes"), value: String(minutes), kind: .number, tool: "ui", input: input("wait"))))
        case .repeatUntil(let until, let times, let steps):
            main.append(.edit(EditField("\(step.id).times", L("At most (times)"), value: String(times), detail: L("If it still doesn't hold after this many, the step fails, and “If this step fails” below says what then."), kind: .number, tool: "ui", input: input("repeat_times"))))
            // What it stops on is what its own steps make each go, which aren't "earlier" for anything else.
            var inside: [EditField.Token] = [.init(L("Its number"), value: "{{index}}", symbol: "number", group: L("Inside it"))]
            // Its own: what's inside a list or a lane in it is gone by the time it looks.
            for made in steps where made.hasOutput {
                inside.append(.init(Words.label(made, catalog: app.catalog), value: "{{\(made.id)}}", symbol: Pages.look(made, app).symbol, group: L("Inside it")))
            }
            main += conditionForm(until, step: step, tokens: inside + tokens.filter { $0.value != "{{index}}" }, input: input, stopping: true)
        case .forEach(let items, let limit, let failure, _):
            main.append(.edit(EditField("\(step.id).items", L("The list"), value: items, detail: L("A list from an earlier step, or text with one item per line. Inside, “This item” is the one it's on."), placeholder: L("Which list"), tokens: tokens, tool: "ui", input: input("each_items"))))
            more.append(.edit(EditField("\(step.id).limit", L("At most (items)"), value: String(limit), kind: .number, tool: "ui", input: input("each_limit"))))
            more.append(.choice(L("If one item fails"), options: [("stop", L("Stop the flow")), ("collect", L("Note it and go on"))], selected: failure.rawValue, tool: "ui", input: input("each_failure")))
        case .choose(let value, let paths, _):
            main.append(.edit(EditField("\(step.id).value", L("Look at"), value: value, placeholder: L("What to look at"), tokens: tokens, tool: "ui", input: input("choose_value"))))
            for (at, path) in paths.enumerated() {
                main.append(.edit(EditField("\(step.id).when.\(at)", L("Path {count}: when it mentions", ["count": Format.integer(at + 1)]), value: path.when, placeholder: L("Words"), tool: "ui", input: input("path_when", ["path": at]))))
                if paths.count > 1 { main.append(.action(Action(L("Remove this path"), tool: "ui", input: input("path_remove", ["path": at]), style: .plain, symbol: "minus.circle"))) }
            }
            if paths.count < FlowBody.mostPaths { main.append(.action(Action(L("Add a path"), tool: "ui", input: input("path_add"), style: .plain, symbol: "plus.circle"))) }
        case .attempt:
            main.append(.note(L("Add the steps on the board. Under “If it fails”, “What went wrong” says why.")))
        case .parallel(let lanes):
            for (at, lane) in lanes.enumerated() {
                main.append(.edit(EditField("\(step.id).lane.\(at)", L("Lane {count}", ["count": Format.integer(at + 1)]), value: lane.name, tool: "ui", input: input("lane_name", ["lane": at]))))
                if lanes.count > 2 { main.append(.action(Action(L("Remove this lane"), tool: "ui", input: input("lane_remove", ["lane": at]), style: .plain, symbol: "minus.circle"))) }
            }
            if lanes.count < FlowBody.mostLanes { main.append(.action(Action(L("Add a lane"), tool: "ui", input: input("lane_add"), style: .plain, symbol: "plus.circle"))) }
        case .call(let name, let inputs):
            main.append(flowPicker(flow, selected: name, app, input: input("call_flow")))
            let wanted = app.store.named(name).map { Self.inputs(of: $0.running) } ?? []
            for key in wanted {
                main.append(.edit(EditField("\(step.id).input.\(key)", key.replacingOccurrences(of: "_", with: " ").capitalizedFirst, value: inputs[key] ?? "", tokens: tokens, tool: "ui", input: input("call_input", ["name": key]))))
            }
            if wanted.isEmpty { main.append(.note(L("That flow asks for nothing to start with. A flow asks for something by using “{{input.name}}” in its steps."))) }
        case .finish(let value):
            main.append(.edit(EditField("\(step.id).value", L("Its result"), value: value, placeholder: L("Nothing"), tokens: tokens, tool: "ui", input: input("finish_value"))))
        case .data(let data):
            main.append(.picker(L("What to do"), style: .menu, DataStep.Op.allCases.map { Option($0.rawValue, Words.dataName($0)) }, selected: data.op.rawValue, tool: "ui", input: input("data_op")))
            main.append(.edit(EditField("\(step.id).from", L("From"), value: data.from, placeholder: L("Which value"), tokens: tokens, tool: "ui", input: input("data_from"))))
            if [.field, .filter, .sort, .unique, .sum, .group].contains(data.op) {
                main.append(.edit(EditField("\(step.id).field", L("The field in each"), value: data.field ?? "", detail: L("A name, or a.b for one inside another. Empty for the item itself."), tool: "ui", input: input("data_field"))))
            }
            switch data.op {
            case .filter:
                main.append(.choice(L("It"), options: Condition.Test.allCases.map { ($0.rawValue, testName($0)) }, selected: (data.test ?? .contains).rawValue, tool: "ui", input: input("data_test")))
                main.append(.edit(EditField("\(step.id).than", L("This"), value: data.than ?? "", tokens: tokens, tool: "ui", input: input("data_than"))))
            case .sort:
                main.append(.toggle(L("Largest or last first"), on: data.descending, tool: "ui", input: input("data_descending")))
            case .first:
                main.append(.edit(EditField("\(step.id).count", L("How many"), value: String(data.count ?? 1), kind: .number, tool: "ui", input: input("data_count"))))
            case .batches:
                main.append(.edit(EditField("\(step.id).count", L("How many in each"), value: String(data.count ?? 10), detail: L("Then go through them with For each: each item is one batch."), kind: .number, tool: "ui", input: input("data_count"))))
            case .fallback:
                main.append(.edit(EditField("\(step.id).than", L("Otherwise use"), value: data.than ?? "", tokens: tokens, tool: "ui", input: input("data_than"))))
            case .join:
                main.append(.edit(EditField("\(step.id).separator", L("Between each"), value: data.separator ?? ", ", tool: "ui", input: input("data_separator"))))
            default: break
            }
        case .form(let form):
            main.append(.edit(EditField("\(step.id).title", L("What it asks"), value: form.title, placeholder: L("Check this invoice"), tokens: tokens, tool: "ui", input: input("form_title"))))
            for (at, field) in form.fields.enumerated() {
                main.append(.edit(EditField("\(step.id).label.\(at)", L("Field {count}", ["count": Format.integer(at + 1)]), value: field.label, tool: "ui", input: input("form_label", ["field": at]))))
                main.append(.choice(L("Kind"), options: [("text", L("Words")), ("number", L("A number")), ("yes_no", L("Yes or no")), ("choice", L("One of a few"))], selected: field.kind.rawValue, tool: "ui", input: input("form_kind", ["field": at])))
                if field.kind == .choice { main.append(.edit(EditField("\(step.id).options.\(at)", L("The choices"), value: field.options.joined(separator: ", "), detail: L("With commas between them."), tool: "ui", input: input("form_options", ["field": at])))) }
                if form.fields.count > 1 { main.append(.action(Action(L("Remove this field"), tool: "ui", input: input("form_remove", ["field": at]), style: .plain, symbol: "minus.circle"))) }
            }
            main.append(.action(Action(L("Add a field"), tool: "ui", input: input("form_add"), style: .plain, symbol: "plus.circle")))
            more.append(.edit(EditField("\(step.id).hours", L("Wait for (hours)"), value: String(form.hours), detail: L("Then it counts as this step failing."), kind: .number, tool: "ui", input: input("form_hours"))))
        case .waitFor(let event, let contains, let minutes):
            main.append(.choice(L("What happens"), options: Trigger.events.map { ($0, Words.eventName($0)) }, selected: event, tool: "ui", input: input("wait_event")))
            main.append(.edit(EditField("\(step.id).contains", L("Only if it mentions"), value: contains ?? "", placeholder: L("Anything"), tool: "ui", input: input("wait_contains"))))
            main.append(.edit(EditField("\(step.id).minutes", L("For up to (minutes)"), value: String(minutes), kind: .number, tool: "ui", input: input("wait_minutes"))))
        }
        if case .action = step.kind {
            more.append(.edit(EditField("\(step.id).sample", L("In practice, pretend it gives"), value: step.sample ?? "", detail: L("A practice run uses this instead of running it, to try a way a real answer would take. JSON stays JSON."), kind: .multiline, tool: "ui", input: input("sample"))))
        }
        more.append(.edit(EditField("\(step.id).name", L("Call this step"), value: step.name ?? "", placeholder: Words.label(step, catalog: app.catalog), tool: "ui", input: input("step_name"))))
        if step.hasOutput {
            var failure = [("stop", L("Stop the flow")), ("carry_on", L("Carry on"))]
            // Only a step with a tool or an AI to go back to.
            switch step.kind {
            case .action, .ai: if step.reads(app.catalog) { failure.append(("retry", L("Try again later"))) }
            default: break
            }
            more.append(.choice(L("If it fails"), options: failure, selected: step.onFailure.rawValue, tool: "ui", input: input("on_failure")))
        }
        let said = explanation(step, app)
        return [Section(said.title, main, place: .trailing, detail: said.detail),
                Section(L("More options"), more, place: .trailing, collapsed: true),
                Section(nil, [.action(Action(L("Duplicate this step"), tool: "ui", input: input("dup_step"), style: .plain, symbol: "plus.square.on.square")),
                              .action(Action(L("Make this its own flow"), tool: "ui", input: input("extract"), style: .plain, symbol: "rectangle.portrait.and.arrow.right", detail: L("It becomes a flow of its own, off until you turn it on, and this step calls it."))),
                              .action(Action(L("Remove this step"), tool: "ui", input: input("remove"), style: .destructive, symbol: "trash"))], place: .trailing)]
    }

    /// A step's parameter as a form asks it: written out, or an earlier step's value, whichever it wants. A record's own fields each their own; what a form can't draw, written out.
    private static func field(_ p: Catalog.Parameter, name: String? = nil, value current: JSON?, step: Step, flow: String, tokens: [Token], last: Values?, _ app: App, input: (String, [String: Any]) -> [String: Any]) -> [Block] {
        let path = name ?? p.name
        if !p.children.isEmpty {
            var fields: [String: JSON] = [:]
            if case .object(let o)? = current { fields = o }
            // A value for the whole record has no fields to show: it's written out instead.
            if current?.string == nil {
                return p.children.flatMap { field($0, name: "\(path).\($0.name)", value: fields[$0.name], step: step, flow: flow, tokens: tokens, last: last, app, input: input) }
            }
        }
        let args = input("param", ["name": path])
        let shown = "\(step.id).\(path)"
        if p.kind == .other {
            let text = current.flatMap { try? JSONSerialization.data(withJSONObject: $0.any, options: [.fragmentsAllowed, .withoutEscapingSlashes, .sortedKeys]) }.map { String(decoding: $0, as: UTF8.self) } ?? ""
            return [.edit(EditField(shown, p.title, value: text, detail: preview(text, last) ?? p.detail.map { String($0.prefix(140)) } ?? L("Written out, as a record or a list. Values from earlier steps go in quotes."), kind: .multiline, tool: "ui", input: input("param_json", ["name": path])))]
        }
        if p.kind == .text {
            let text = current.map(Values.text) ?? ""
            return [.edit(EditField(shown, p.title, value: text, detail: preview(text, last) ?? p.detail.map { String($0.prefix(140)) },
                                    kind: path == "text" || path == "body" || path == "job" ? .multiline : .text, tokens: tokens.filter { $0.fits(p.kind) }.map(\.field), tool: "ui", input: args))]
        }
        // A number, a yes or no, a choice or a list: its own control, or an earlier step's value. Never words that look like one.
        // Words stored for one, from a flow an agent wrote: shown as they are, so what's shown is what's sent. A choice's own words are its own control.
        let pointed: Bool = {
            guard let words = current?.string else { return false }
            if case .choice(let options) = p.kind, options.contains(words) { return false }
            return true
        }()
        let written: String = if case .array(let items)? = current { items.map(Values.text).joined(separator: ", ") } else { current.map(Values.text) ?? "" }
        if pointed || app.nav.usesValue(flow: flow, step: step.id, parameter: path) {
            let text = written
            return [.edit(EditField(shown, p.title, value: text, detail: preview(text, last) ?? p.typeWord.map { L("It wants {what}.", ["what": $0]) } ?? p.detail.map { String($0.prefix(140)) },
                                    placeholder: L("Pick a value below"), tokens: tokens.filter { $0.fits(p.kind) }.map(\.field), tool: "ui", input: args)),
                    .action(Action(L("Write it here instead"), tool: "ui", input: input("param_mode", ["name": path, "on": false]), style: .plain, symbol: "pencil"))]
        }
        let own: Block
        switch p.kind {
        case .boolean:
            var on = false
            if case .bool(let v)? = current { on = v }
            own = .toggle(p.title, detail: p.detail, on: on, tool: "ui", input: args)
        case .choice(let options):
            let list = p.required ? options : [""] + options
            own = .choice(p.title, detail: p.detail, options: list.map { ($0, $0.isEmpty ? L("Not set") : $0.replacingOccurrences(of: "_", with: " ")) }, selected: current?.string ?? "", tool: "ui", input: args)
        default:
            own = .edit(EditField(shown, p.title, value: written, detail: p.detail.map { String($0.prefix(140)) }, kind: p.kind == .list ? .text : .number, tool: "ui", input: args))
        }
        return [own, .action(Action(L("Use a value from an earlier step"), tool: "ui", input: input("param_mode", ["name": path, "on": true]), style: .plain, symbol: "arrow.turn.down.right"))]
    }

    /// What a value would be, going by the last run: a look, with nothing run.
    private static func preview(_ text: String, _ last: Values?) -> String? {
        guard let last, !Values.slots(text).isEmpty, last.missing(in: [text]).isEmpty else { return nil }
        let filled = last.fill(text, each: 80)
        return filled.trimmed.isEmpty || filled.contains(L("(sample)")) ? nil : L("Last time: {value}", ["value": String(filled.prefix(80)).split(whereSeparator: \.isNewline).joined(separator: " ")])
    }

    /// A value on offer, with what it is, so a field can offer what fits and the person can tell two apart.
    private struct Token {
        var field: EditField.Token
        var type: String?

        /// Whether it can go where this wants. What isn't known might.
        func fits(_ kind: Catalog.Parameter.Kind) -> Bool {
            guard let type else { return true }
            switch kind {
            case .number, .integer: return type == "number" || type == "integer"
            case .boolean: return type == "boolean"
            case .list: return type == "array"
            case .text, .choice: return type != "array" && type != "object"
            case .other: return true
            }
        }
    }

    /// The values on offer, each with its type where the tool says and what it was in the last run.
    private static func annotated(_ tokens: [EditField.Token], flow: Flow, _ app: App, last: Values?) -> [Token] {
        var types: [String: String] = [:]
        for step in flow.draft.allSteps {
            switch step.kind {
            case .action(let tool, _):
                for (field, type) in app.catalog.tool(tool)?.outputTypes ?? [:] { types["{{\(step.id).\(field)}}"] = type }
            case .form(let form):
                for field in form.fields { types["{{\(step.id).\(field.name)}}"] = field.kind == .number ? "number" : field.kind == .yes_no ? "boolean" : "string" }
            default: break
            }
        }
        return tokens.map { token in
            var shown = token
            if let last, last.missing(in: [token.value]).isEmpty, let sample = last.fill(token.value, each: 30).trimmed.nonEmpty, !sample.contains(L("(sample)")) {
                shown.label = "\(token.label): \(String(sample.prefix(30)).split(whereSeparator: \.isNewline).joined(separator: " "))"
            }
            return Token(field: shown, type: types[token.value])
        }
    }

    /// The other flows: as a menu, since there can be one or many. None to pick is said, not left blank.
    private static func flowPicker(_ flow: Flow, selected: String, _ app: App, input: [String: Any]) -> Block {
        let others = app.store.flows().filter { $0.id != flow.id }
        guard !others.isEmpty else { return .note(L("There's no other flow to run yet."), tone: .warn) }
        return .picker(L("Which flow"), style: .menu, others.map { Option($0.name, $0.name) }, selected: selected, tool: "ui", input: input)
    }

    /// “If [this] [mentions] [that]”, as many as it takes, then where its two paths are.
    private static func conditionForm(_ c: Condition, step: Step, tokens: [EditField.Token], input: (String, [String: Any]) -> [String: Any], stopping: Bool = false) -> [Block] {
        var out: [Block] = []
        let tests = Condition.Test.allCases.map { ($0.rawValue, testName($0)) }
        for (at, check) in c.checks.enumerated() {
            let first = at == 0
            out.append(.edit(EditField("\(step.id).value.\(at)", first ? (stopping ? L("Stop when") : L("If")) : (c.any ? L("Or if") : L("And if")), value: check.value, placeholder: L("What to check"), tokens: tokens, tool: "ui", input: input("cond_value", ["check": at]))))
            out.append(.choice(L("It"), options: tests, selected: check.test.rawValue, tool: "ui", input: input("cond_test", ["check": at])))
            if check.test != .is_empty, check.test != .not_empty {
                out.append(.edit(EditField("\(step.id).than.\(at)", check.test == .more_than || check.test == .less_than ? L("This number") : L("This"), value: check.than, placeholder: L("Words or a value"), tokens: tokens, tool: "ui", input: input("cond_than", ["check": at]))))
            }
            if !first { out.append(.action(Action(L("Remove this check"), tool: "ui", input: input("cond_remove", ["check": at]), style: .plain, symbol: "minus.circle"))) }
        }
        out.append(.action(Action(L("Add another check"), tool: "ui", input: input("cond_add", [:]), style: .plain, symbol: "plus.circle")))
        if !c.also.isEmpty {
            out.append(.choice(stopping ? L("Stop when") : L("It takes"), options: [("all", L("All of these")), ("any", L("Any of these"))], selected: c.any ? "any" : "all", tool: "ui", input: input("cond_join", [:])))
        }
        out.append(.note(stopping ? L("It looks after the steps inside have run, so it can check what they made.")
            : L("Then, on the board: what goes under “If so” runs when this holds, what goes under “Otherwise” when it doesn't. Either can stay empty.")))
        return out
    }

    /// What a flow asks to be given: every `{{input.name}}` it uses, in order. Its interface is what it uses, so it can't say one thing and do another.
    static func inputs(of body: FlowBody) -> [String] {
        var out: [String] = []
        let pattern = try! NSRegularExpression(pattern: #"\{\{\s*input\.([A-Za-z0-9_]{1,40})"#)
        for text in body.allSteps.flatMap(\.usedTexts) {
            for match in pattern.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                if let r = Range(match.range(at: 1), in: text), !out.contains(String(text[r])) { out.append(String(text[r])) }
            }
        }
        return out
    }

    static func testName(_ t: Condition.Test) -> String {
        switch t {
        case .contains: L("mentions")
        case .not_contains: L("doesn't mention")
        case .is: L("is exactly")
        case .is_not: L("isn't")
        case .is_empty: L("is empty")
        case .not_empty: L("has something")
        case .more_than: L("is more than")
        case .less_than: L("is less than")
        }
    }
}
