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
        more.append(.edit(EditField("name", L("This flow's name"), value: flow.name, tool: "ui", input: base(flow, "rename"))))
        return [Section(L("When it runs"), main, place: .trailing, detail: L("What sets this flow off, without you pressing anything.")),
                Section(L("More options"), more, place: .trailing, collapsed: true)]
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
        for step in Editing.available(before: id, in: flow.draft) {
            out.append(.init(Words.label(step, catalog: app.catalog), value: "{{\(step.id)}}", symbol: Pages.look(step, app).symbol, group: earlier))
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
        if case .action(let name, _) = step.kind, app.catalog.tool(name)?.risk == "high" {
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
            for p in tool.parameters {
                guard let block = field(p, value: values[p.name], step: step, tokens: tokens, input: input) else { continue }
                // What's optional stays out of the way unless it's been filled in.
                if p.required || values[p.name] != nil { main.append(block) } else { more.append(block) }
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
            main.append(.choice(L("Which flow"), options: app.store.flows().filter { $0.id != flow.id }.map { ($0.name, $0.name) }, selected: name, tool: "ui", input: input("run_flow")))
        case .wait(let minutes):
            main.append(.edit(EditField("\(step.id).minutes", L("Minutes"), value: String(minutes), kind: .number, tool: "ui", input: input("wait"))))
        }
        more.append(.edit(EditField("\(step.id).name", L("Call this step"), value: step.name ?? "", placeholder: Words.label(step, catalog: app.catalog), tool: "ui", input: input("step_name"))))
        if step.hasOutput {
            var failure = [("stop", L("Stop the flow")), ("carry_on", L("Carry on"))]
            if step.reads(app.catalog) { failure.append(("retry", L("Try again later"))) }
            more.append(.choice(L("If it fails"), options: failure, selected: step.onFailure.rawValue, tool: "ui", input: input("on_failure")))
        }
        let said = explanation(step, app)
        return [Section(said.title, main, place: .trailing, detail: said.detail),
                Section(L("More options"), more, place: .trailing, collapsed: true),
                Section(nil, [.action(Action(L("Duplicate this step"), tool: "ui", input: input("dup_step"), style: .plain, symbol: "plus.square.on.square")),
                              .action(Action(L("Remove this step"), tool: "ui", input: input("remove"), style: .destructive, symbol: "trash"))], place: .trailing)]
    }

    private static func field(_ p: Catalog.Parameter, value current: JSON?, step: Step, tokens: [EditField.Token], input: (String, [String: Any]) -> [String: Any]) -> Block? {
        let args = input("param", ["name": p.name])
        switch p.kind {
        case .boolean:
            if case .bool(let v)? = current { return .toggle(p.title, detail: p.detail, on: v, tool: "ui", input: args) }
            return .toggle(p.title, detail: p.detail, on: false, tool: "ui", input: args)
        case .choice(let options):
            let list = p.required ? options : [""] + options
            return .choice(p.title, detail: p.detail, options: list.map { ($0, $0.isEmpty ? L("Not set") : $0.replacingOccurrences(of: "_", with: " ")) }, selected: current?.string ?? "", tool: "ui", input: args)
        case .other:
            return nil
        default:
            let text: String = switch current {
            case .string(let s)?: s
            case .number(let n)?: n == n.rounded() ? String(Int(n)) : String(n)
            case .array(let a)?: a.compactMap(\.string).joined(separator: ", ")
            default: ""
            }
            return .edit(EditField("\(step.id).\(p.name)", p.title, value: text, detail: p.detail.map { String($0.prefix(140)) },
                                   kind: p.name == "text" || p.name == "body" || p.name == "job" ? .multiline : (p.kind == .integer || p.kind == .number ? .number : .text),
                                   tokens: p.kind == .text ? tokens : [], tool: "ui", input: args))
        }
    }

    /// “If [this] [mentions] [that]”, as many as it takes, then where its two paths are.
    private static func conditionForm(_ c: Condition, step: Step, tokens: [EditField.Token], input: (String, [String: Any]) -> [String: Any]) -> [Block] {
        var out: [Block] = []
        let tests = Condition.Test.allCases.map { ($0.rawValue, testName($0)) }
        for (at, check) in c.checks.enumerated() {
            let first = at == 0
            out.append(.edit(EditField("\(step.id).value.\(at)", first ? L("If") : (c.any ? L("Or if") : L("And if")), value: check.value, placeholder: L("What to check"), tokens: tokens, tool: "ui", input: input("cond_value", ["check": at]))))
            out.append(.choice(L("It"), options: tests, selected: check.test.rawValue, tool: "ui", input: input("cond_test", ["check": at])))
            if check.test != .is_empty, check.test != .not_empty {
                out.append(.edit(EditField("\(step.id).than.\(at)", check.test == .more_than || check.test == .less_than ? L("This number") : L("This"), value: check.than, placeholder: L("Words or a value"), tokens: tokens, tool: "ui", input: input("cond_than", ["check": at]))))
            }
            if !first { out.append(.action(Action(L("Remove this check"), tool: "ui", input: input("cond_remove", ["check": at]), style: .plain, symbol: "minus.circle"))) }
        }
        out.append(.action(Action(L("Add another check"), tool: "ui", input: input("cond_add", [:]), style: .plain, symbol: "plus.circle")))
        if !c.also.isEmpty {
            out.append(.choice(L("It takes"), options: [("all", L("All of these")), ("any", L("Any of these"))], selected: c.any ? "any" : "all", tool: "ui", input: input("cond_join", [:])))
        }
        out.append(.note(L("Then, on the board: what goes under “If so” runs when this holds, what goes under “Otherwise” when it doesn't. Either can stay empty.")))
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
