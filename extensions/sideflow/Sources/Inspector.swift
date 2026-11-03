import Foundation
import SidefolkExtensionKit

/// What's selected on the tree, as a form: from each tool's own schema, so an extension installed tomorrow has its form with no change here.
@MainActor enum Inspector {
    static func blocks(_ flow: Flow, _ app: App, problems: [FlowProblem]) -> [Block] {
        switch app.nav.inspecting(flow) {
        case .nothing: return []
        case .trigger: return trigger(flow)
        case .step(let id):
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
        case .event: "event"
        }
        var out: [Block] = [.edit(EditField("name", L("Its name"), value: flow.name, tool: "ui", input: base(flow, "rename")))]
        out.append(.picker(L("Sets it off"), style: .cards, [
            Option("days", L("On a schedule"), detail: L("Days and a time"), symbol: "calendar.badge.clock"),
            Option("every", L("Every so often"), detail: L("Every so many minutes"), symbol: "clock.arrow.2.circlepath"),
            Option("event", L("When something happens"), detail: L("A reminder, a note, a meeting"), symbol: "bolt"),
            Option("watch", L("When something changes"), detail: L("A page, a file, a program"), symbol: "eye"),
            Option("manual", L("Only when I ask"), detail: L("A button, or say its name"), symbol: "hand.tap"),
        ], selected: kind, tool: "ui", input: base(flow, "trigger_kind"), key: "value"))
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
        case .event(let name, let contains):
            out.append(.choice(L("What happens"), options: Trigger.events.map { ($0, Words.eventName($0)) }, selected: name, tool: "ui", input: base(flow, "event_kind")))
            out.append(.edit(EditField("event_contains", L("Only if it mentions"), value: contains ?? "", placeholder: L("Anything"), tool: "ui", input: base(flow, "event_contains"))))
            out.append(.note(L("Its words go on to the steps as “What set it off”.")))
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

    // MARK: A step

    /// Chips for what earlier steps made, in reading order.
    static func tokens(before id: String, flow: Flow, _ app: App) -> [EditField.Token] {
        var out = [EditField.Token]()
        switch flow.draft.trigger {
        case .watch, .event: out.append(.init(L("What set it off"), value: "{{trigger}}", symbol: "bolt"))
        default: break
        }
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
            if name == "companion.job" { out.append(.note(L("Your companion does this with all its tools, under your own trust settings. It uses your AI, and what it does is in History."))) }
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
                                               kind: p.name == "text" || p.name == "body" || p.name == "job" ? .multiline : (p.kind == .integer || p.kind == .number ? .number : .text),
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
        case .flow(let name):
            out.append(.choice(L("Which flow"), options: app.store.flows().filter { $0.id != flow.id }.map { ($0.name, $0.name) }, selected: name, tool: "ui", input: input("run_flow")))
            out.append(.note(L("It sets that flow off and carries on, without waiting for it.")))
        case .wait(let minutes):
            out.append(.edit(EditField("\(step.id).minutes", L("Minutes"), value: String(minutes), detail: L("Up to a day. It carries on after Sidefolk restarts."), kind: .number, tool: "ui", input: input("wait"))))
        }
        out.append(.edit(EditField("\(step.id).name", L("Its name"), value: step.name ?? "", placeholder: Words.label(step, catalog: app.catalog), tool: "ui", input: input("step_name"))))
        if step.hasOutput {
            var failure = [("stop", L("Stop the flow")), ("carry_on", L("Carry on"))]
            if step.reads(app.catalog) { failure.append(("retry", L("Try again later"))) }
            out.append(.choice(L("If it fails"), options: failure, selected: step.onFailure.rawValue, tool: "ui", input: input("on_failure")))
        }
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
