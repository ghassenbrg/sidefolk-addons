import Foundation
import SidefolkExtensionKit

/// What's selected on the rail, as a form: from each tool's own schema, so an extension installed tomorrow has its form with no change here.
@MainActor enum Inspector {
    static func blocks(_ flow: Flow, _ app: App, problems: [FlowProblem]) -> [Block] {
        switch app.nav.inspecting(flow) {
        case .trigger: return trigger(flow)
        case .adding(let after): return adding(flow, after: after, app)
        case .step(let id):
            // The rows that open a branch hold nothing of their own: they're where to add.
            if id.hasPrefix("then:") || id.hasPrefix("else:") { return adding(flow, after: id, app) }
            guard let step = flow.draft.step(id) else { return trigger(flow) }
            return self.step(step, flow, app, problems: problems)
        }
    }

    private static func base(_ flow: Flow, _ op: String, _ extra: [String: Any] = [:]) -> [String: Any] {
        extra.merging(["op": op, "flow": flow.id]) { own, _ in own }
    }

    // MARK: When

    static func trigger(_ flow: Flow) -> [Block] {
        let t = flow.draft.trigger
        let kind: String = switch t {
        case .manual: "manual"
        case .days: "days"
        case .every: "every"
        case .watch: "watch"
        }
        var out: [Block] = [.picker(L("Sets it off"), style: .cards, [
            Option("days", L("On a schedule"), detail: L("Days and a time"), symbol: "calendar.badge.clock"),
            Option("every", L("Every so often"), detail: L("Every so many minutes"), symbol: "clock.arrow.2.circlepath"),
            Option("watch", L("When something changes"), detail: L("A page, a file, a program"), symbol: "eye"),
            Option("manual", L("Only when I ask"), detail: L("A button, or say its name"), symbol: "hand.tap"),
        ], selected: kind, tool: "ui", input: base(flow, "trigger_kind"), key: "value")]
        switch t {
        case .manual:
            out.append(.note(L("Run it from here, or say “run {name}”.", ["name": flow.name])))
        case .days(let days, let hour, let minute, let catchUp):
            let names = [("mon", L("Mon")), ("tue", L("Tue")), ("wed", L("Wed")), ("thu", L("Thu")), ("fri", L("Fri")), ("sat", L("Sat")), ("sun", L("Sun"))]
            out.append(.several(MultiChoice(L("Days"), options: names, selected: days.map { FlowCodec.days[$0 - 1] }, tool: "ui", input: base(flow, "days"))))
            out.append(.edit(EditField("at", L("At"), value: String(format: "%02d:%02d", hour, minute), placeholder: "08:30", kind: .time, tool: "ui", input: base(flow, "at"))))
            out.append(catchUpSwitch(flow, catchUp))
        case .every(let minutes, let catchUp):
            out.append(.edit(EditField("every", L("Every (minutes)"), value: String(minutes), detail: L("{count} at the least.", ["count": Format.integer(FlowBody.shortestEvery)]), kind: .number, tool: "ui", input: base(flow, "every"))))
            out.append(catchUpSwitch(flow, catchUp))
        case .watch(let w):
            out.append(.choice(L("What to watch"), options: [("url_change", L("A web page changes")), ("site_status", L("A site goes down or comes back")), ("file_changes", L("A file changes")),
                                                             ("file_appears", L("A file appears")), ("folder_new_file", L("A new file in a folder")), ("process_exits", L("A program quits"))],
                               selected: w.kind, tool: "ui", input: base(flow, "watch_kind")))
            out.append(.edit(EditField("target", L("Where"), value: w.target, detail: L("A web address, a full path or a program's name."), tool: "ui", input: base(flow, "watch_target"))))
            if w.kind == "url_change" {
                out.append(.edit(EditField("contains", L("Only when it says"), value: w.contains ?? "", placeholder: L("Any change"), tool: "ui", input: base(flow, "watch_contains"))))
            }
            if w.kind == "folder_new_file" {
                out.append(.edit(EditField("pattern", L("Only files like"), value: w.pattern ?? "", placeholder: "*.pdf", tool: "ui", input: base(flow, "watch_pattern"))))
            }
            out.append(.note(L("What it saw goes on to the steps as “What set it off”.")))
        }
        return out
    }

    private static func catchUpSwitch(_ flow: Flow, _ on: Bool) -> Block {
        .toggle(L("If the Mac was off, run once when it's back"), detail: on ? nil : L("Otherwise it notes that it missed the run."), on: on, tool: "ui", input: base(flow, "catch_up"))
    }

    // MARK: Adding

    /// The whole choice in one place: what Sideflow does itself first, then every tool by what it's for.
    static func adding(_ flow: Flow, after: String, _ app: App) -> [Block] {
        let add = base(flow, "add_kind", ["after": after])
        var out: [Block] = [.picker(L("Sideflow itself"), style: .rows, [
            Option("tell", L("Tell me"), detail: L("A notice from your companion"), symbol: "bell"),
            Option("ai", L("Write with AI"), detail: L("Summarise, rewrite, sum up"), symbol: "sparkles"),
            Option("ask", L("Ask me"), detail: L("A question, and it waits for you"), symbol: "questionmark.bubble"),
            Option("if", L("If…"), detail: L("Do something only sometimes"), symbol: "arrow.triangle.branch"),
            Option("text", L("Compose text"), detail: L("Put values together"), symbol: "text.quote"),
            Option("wait", L("Wait"), detail: L("Up to a day; survives quitting"), symbol: "hourglass"),
        ], selected: "", tool: "ui", input: add, key: "kind")]
        out.append(.field(L("Find a tool"), placeholder: app.nav.search.isEmpty ? L("Note, weather, file…") : app.nav.search, button: L("Find"), tool: "ui", input: base(flow, "search")))
        let words = app.nav.search.lowercased()
        let tools = app.catalog.tools.filter { $0.name != "notify.user" && $0.name != "ask.user" && (words.isEmpty || ($0.title + " " + $0.name + " " + ($0.fromExtension ?? "")).lowercased().contains(words)) }
        let order = ["notes", "time", "web", "files", "watch", "system", "extensions", "agents"]
        for category in order {
            let group = tools.filter { $0.category == category || (category == "extensions" && $0.fromExtension != nil && !order.dropLast(2).contains($0.category)) }
            guard !group.isEmpty else { continue }
            out.append(.picker(categoryName(category), style: .rows, group.prefix(24).map { t in
                Option("tool:\(t.name)", t.title, detail: t.fromExtension?.capitalizedFirst, symbol: toolSymbol(t))
            }, selected: "", tool: "ui", input: add, key: "kind"))
        }
        if tools.isEmpty, !words.isEmpty { out.append(.note(L("Nothing matches “{words}”.", ["words": app.nav.search]))) }
        return out
    }

    static func categoryName(_ c: String) -> String {
        switch c {
        case "notes": L("Notes")
        case "time": L("Time and reminders")
        case "web": L("The web")
        case "files": L("Files")
        case "watch": L("Watches")
        case "system": L("This Mac")
        case "agents": L("Agents")
        default: L("From your extensions")
        }
    }

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

    // MARK: A step

    /// Chips for what earlier steps made, in reading order.
    static func tokens(before id: String, flow: Flow, _ app: App) -> [EditField.Token] {
        var out = [EditField.Token]()
        if case .watch = flow.draft.trigger { out.append(.init(L("What set it off"), value: "{{trigger}}", symbol: "eye")) }
        for step in flow.draft.allSteps {
            if step.id == id { break }
            if step.hasOutput { out.append(.init(Words.label(step, catalog: app.catalog), value: "{{\(step.id)}}", symbol: Pages.look(step, app).symbol)) }
        }
        out.append(.init(L("Today's date"), value: "{{today}}", symbol: "calendar"))
        return out
    }

    static func step(_ step: Step, _ flow: Flow, _ app: App, problems: [FlowProblem]) -> [Block] {
        let on = base(flow, "", ["step": step.id])
        func input(_ op: String, _ extra: [String: Any] = [:]) -> [String: Any] { on.merging(extra.merging(["op": op]) { a, _ in a }) { _, new in new } }
        let tokens = tokens(before: step.id, flow: flow, app)
        var out: [Block] = []
        for p in problems where p.step == step.id { out.append(.note(p.text, tone: .warn)) }
        if Hints.asksEachTime(step) {
            out.append(.note(L("A value filled in when it runs could send it anywhere, so this step asks you each time. Write it out in full and it won't.")))
        }
        switch step.kind {
        case .action(let name, let values):
            guard let tool = app.catalog.tool(name) else {
                out.append(.note(L("This tool isn't here now: {tool}.", ["tool": name]), tone: .warn))
                break
            }
            if !tool.description.isEmpty, tool.fromExtension == nil { out.append(.note(String(tool.description.prefix(200)))) }
            for p in tool.parameters {
                let current = values[p.name]
                switch p.kind {
                case .boolean:
                    if case .bool(let v)? = current {
                        out.append(.toggle(p.title, detail: p.detail, on: v, tool: "ui", input: input("param", ["name": p.name])))
                    } else {
                        out.append(.toggle(p.title, detail: p.detail, on: false, tool: "ui", input: input("param", ["name": p.name])))
                    }
                case .choice(let options):
                    let list = p.required ? options : [""] + options
                    out.append(.choice(p.title, detail: p.detail, options: list.map { ($0, $0.isEmpty ? L("Not set") : $0.replacingOccurrences(of: "_", with: " ")) },
                                       selected: current?.string ?? "", tool: "ui", input: input("param", ["name": p.name])))
                case .other:
                    continue
                default:
                    let text: String = switch current {
                    case .string(let s)?: s
                    case .number(let n)?: n == n.rounded() ? String(Int(n)) : String(n)
                    case .array(let a)?: a.compactMap(\.string).joined(separator: ", ")
                    default: ""
                    }
                    out.append(.edit(EditField("\(step.id).\(p.name)", p.title + (p.required ? "" : " " + L("(optional)")), value: text, detail: p.detail.map { String($0.prefix(140)) },
                                               kind: p.name == "text" || p.name == "body" ? .multiline : (p.kind == .integer || p.kind == .number ? .number : .text),
                                               tokens: p.kind == .text ? tokens : [], tool: "ui", input: input("param", ["name": p.name]))))
                }
            }
        case .ai(let prompt):
            out.append(.edit(EditField("\(step.id).prompt", L("What should the AI write?"), value: prompt, detail: L("It gets only these words and has no tools. Each use counts toward your AI's usage."),
                                       placeholder: L("Three short lines about {{agenda}}"), kind: .multiline, tokens: tokens, tool: "ui", input: input("ai_prompt"))))
        case .ask(let question, let options):
            out.append(.edit(EditField("\(step.id).question", L("The question"), value: question, kind: .multiline, tokens: tokens, tool: "ui", input: input("question"))))
            out.append(.edit(EditField("\(step.id).options", L("Answers"), value: options.joined(separator: ", "), detail: L("2 to 4, with commas between them. None lets you type."), tool: "ui", input: input("options"))))
        case .text(let text):
            out.append(.edit(EditField("\(step.id).text", L("The text"), value: text, kind: .multiline, tokens: tokens, tool: "ui", input: input("compose"))))
        case .branch(let c, _, _):
            out.append(.edit(EditField("\(step.id).value", L("Look at"), value: c.value, tokens: tokens, tool: "ui", input: input("cond_value"))))
            out.append(.choice(L("Test"), options: Condition.Test.allCases.map { ($0.rawValue, testName($0)) }, selected: c.test.rawValue, tool: "ui", input: input("cond_test")))
            if c.test != .is_empty, c.test != .not_empty {
                out.append(.edit(EditField("\(step.id).than", L("Than"), value: c.than, tool: "ui", input: input("cond_than"))))
            }
        case .wait(let minutes):
            out.append(.edit(EditField("\(step.id).minutes", L("Minutes"), value: String(minutes), detail: L("Up to a day. It carries on after Sidefolk restarts."), kind: .number, tool: "ui", input: input("wait"))))
        }
        out.append(.edit(EditField("\(step.id).name", L("Its name"), value: step.name ?? "", placeholder: Words.label(step, catalog: app.catalog), tool: "ui", input: input("step_name"))))
        if step.hasOutput {
            var failure = [("stop", L("Stop the flow")), ("carry_on", L("Carry on"))]
            if step.reads(app.catalog) { failure.append(("retry", L("Try again later"))) }
            out.append(.choice(L("If it fails"), options: failure, selected: step.onFailure.rawValue, tool: "ui", input: input("on_failure")))
        }
        out.append(.action(Action(L("Move up"), tool: "ui", input: input("up"), style: .plain, symbol: "chevron.up")))
        out.append(.action(Action(L("Move down"), tool: "ui", input: input("down"), style: .plain, symbol: "chevron.down")))
        out.append(.action(Action(L("Remove this step"), tool: "ui", input: input("remove"), style: .destructive, symbol: "trash")))
        return out
    }

    static func testName(_ t: Condition.Test) -> String {
        switch t {
        case .contains: L("mentions")
        case .not_contains: L("doesn't mention")
        case .is: L("is")
        case .is_not: L("isn't")
        case .is_empty: L("is empty")
        case .not_empty: L("has something")
        case .more_than: L("is more than")
        case .less_than: L("is less than")
        }
    }
}
