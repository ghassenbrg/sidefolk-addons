import Foundation
import SidefolkExtensionKit

/// A flow in sentences: what a person reads on the rail, on a card, in a run, and what a model is told.
@MainActor enum Words {
    static func dayNames(_ days: [Int]) -> String {
        let set = Set(days)
        if set.count == 7 { return L("Every day") }
        if set == [1, 2, 3, 4, 5] { return L("Every weekday") }
        if set == [6, 7] { return L("Every weekend day") }
        let names = [L("Monday"), L("Tuesday"), L("Wednesday"), L("Thursday"), L("Friday"), L("Saturday"), L("Sunday")]
        return L("Every {days}", ["days": Format.list(days.sorted().map { names[$0 - 1] })])
    }

    static func trigger(_ t: Trigger) -> String {
        switch t {
        case .manual: return L("When you ask")
        case .days(let days, let hour, let minute, _):
            var parts = DateComponents()
            parts.hour = hour
            parts.minute = minute
            parts.year = 2026
            parts.month = 1
            parts.day = 5
            let at = Calendar.autoupdatingCurrent.date(from: parts).map { Format.time($0) } ?? String(format: "%02d:%02d", hour, minute)
            return L("{days} at {time}", ["days": dayNames(days), "time": at])
        case .every(let minutes, _):
            if minutes % 60 == 0 { return L(one: "Every hour", other: "Every {count} hours", count: minutes / 60) }
            return L("Every {count} minutes", ["count": Format.integer(minutes)])
        case .watch(let w):
            switch w.kind {
            case "url_change":
                if let c = w.contains { return L("When {target} says “{words}”", ["target": w.target, "words": c]) }
                return L("When {target} changes", ["target": w.target])
            case "site_status": return L("When {target} goes down or comes back", ["target": w.target])
            case "file_changes": return L("When {target} changes", ["target": Paths.show(w.target)])
            case "file_appears": return L("When {target} appears", ["target": Paths.show(w.target)])
            case "folder_new_file":
                if let p = w.pattern { return L("When a new {pattern} lands in {target}", ["pattern": p, "target": Paths.show(w.target)]) }
                return L("When a new file lands in {target}", ["target": Paths.show(w.target)])
            default: return L("When {target} quits", ["target": w.target])
            }
        case .event(let name, let contains):
            let said = eventName(name)
            return contains.map { L("{event}, if it mentions “{words}”", ["event": said, "words": $0]) } ?? said
        }
    }

    static func eventName(_ name: String) -> String {
        switch name {
        case "reminder.fired": L("When a reminder fires")
        case "reminder.created": L("When a reminder is set")
        case "note.saved": L("When a note is saved")
        case "calendar.starting": L("Five minutes before a meeting")
        case "companion.finished": L("When your companion finishes a job")
        case "agent.finished": L("When a connected agent finishes")
        case "attention.changed": L("When Focus or Quiet changes")
        default: L("When your Mac wakes")
        }
    }

    /// `{{x}}` as the name a person gave what makes it.
    static func pretty(_ text: String, body: FlowBody, catalog: Catalog) -> String {
        Values.replacingSlots(in: text) { name, path in
            let inner = Values.parts(of: path).joined(separator: " › ")
            let label = valueLabel(name, body: body, catalog: catalog)
            return inner.isEmpty ? "[\(label)]" : "[\(label) › \(inner)]"
        }
    }

    static func valueLabel(_ name: String, body: FlowBody, catalog: Catalog) -> String {
        switch name {
        case "trigger": return L("What set it off")
        case "today": return L("Today's date")
        case "now": return L("The time")
        case "item": return L("This item")
        case "index": return L("Its number")
        case "error": return L("What went wrong")
        case "input": return L("What it was given")
        default: return body.step(name).map { label($0, catalog: catalog) } ?? name
        }
    }

    /// A step's short name: the person's, or its tool's title, or what it does.
    static func label(_ step: Step, catalog: Catalog) -> String {
        if let name = step.name { return name }
        switch step.kind {
        case .action(let tool, _): return catalog.title(of: tool)
        case .ai: return L("Write with AI")
        case .ask: return L("Ask me")
        case .text: return L("Compose text")
        case .branch: return L("If…")
        case .wait(let minutes): return L("Wait {time}", ["time": Format.duration(Double(minutes) * 60)])
        case .flow(let name): return L("Run {flow}", ["flow": name])
        case .forEach: return L("For each")
        case .repeatUntil: return L("Repeat until")
        case .choose: return L("Choose a path")
        case .attempt: return L("Try")
        case .parallel: return L("At the same time")
        case .call(let flow, _): return L("Run {flow} and wait", ["flow": flow])
        case .finish: return L("Finish here")
        case .data(let data): return dataName(data.op)
        case .form(let form): return form.title.nonEmpty ?? L("A form for you")
        case .waitFor: return L("Wait for something")
        }
    }

    static func dataName(_ op: DataStep.Op) -> String {
        switch op {
        case .parse_json: L("Read JSON")
        case .parse_csv: L("Read a table")
        case .lines: L("Split into lines")
        case .join: L("Join into text")
        case .field: L("Take a field")
        case .filter: L("Keep only some")
        case .sort: L("Sort")
        case .unique: L("Remove repeats")
        case .count: L("Count")
        case .first: L("Keep the first few")
        case .sum: L("Add up")
        case .number: L("Read a number")
        case .batches: L("Split into batches")
        case .group: L("Group by a field")
        case .fallback: L("Use this if it's empty")
        }
    }

    /// The whole step as a sentence.
    static func step(_ step: Step, body: FlowBody, catalog: Catalog) -> String {
        if let name = step.name { return name }
        switch step.kind {
        case .action(let tool, let input):
            let title = catalog.title(of: tool)
            let main = input.keys.sorted().compactMap { input[$0]?.string }.first
            return main.map { "\(title): \(pretty($0, body: body, catalog: catalog))" } ?? title
        case .ai(let prompt): return L("Have the AI write: {what}", ["what": pretty(prompt, body: body, catalog: catalog)])
        case .ask(let question, _): return L("Ask you: {question}", ["question": pretty(question, body: body, catalog: catalog)])
        case .text(let text): return L("Compose: {text}", ["text": pretty(text, body: body, catalog: catalog)])
        case .branch(let c, _, _): return condition(c, body: body, catalog: catalog)
        case .wait(let minutes): return L("Wait {time}", ["time": Format.duration(Double(minutes) * 60)])
        case .flow(let name): return L("Run {flow}", ["flow": name])
        default: return card(step, body: body, catalog: catalog).line
        }
    }

    static func condition(_ c: Condition, body: FlowBody, catalog: Catalog) -> String {
        let all = c.checks.map { check(of: $0, body: body, catalog: catalog) }
        guard all.count > 1 else { return L("If {check}", ["check": all[0]]) }
        return c.any ? L("If any of: {checks}", ["checks": Format.list(all)]) : L("If all of: {checks}", ["checks": Format.list(all)])
    }

    /// What's said on a step's card: its name or what it is, then what it's about. The sentence it replaces read "Action: Notify: First".
    static func card(_ step: Step, body: FlowBody, catalog: Catalog, setUp: String? = nil) -> (head: String, line: String) {
        let name = step.name
        switch step.kind {
        case .action(let tool, let input):
            let title = catalog.title(of: tool)
            let main = catalog.tool(tool)?.parameters.compactMap { input[$0.name]?.string }.first { !$0.isEmpty } ?? input.keys.sorted().compactMap { input[$0]?.string }.first { !$0.isEmpty }
            return (name ?? title, main.map { pretty($0, body: body, catalog: catalog) } ?? (name != nil ? title : setUp ?? L("Nothing to set up")))
        case .ai(let prompt): return (name ?? L("Write with AI"), prompt.isEmpty ? L("Say what to write") : pretty(prompt, body: body, catalog: catalog))
        case .ask(let question, _): return (name ?? L("Ask me"), question.isEmpty ? L("Write the question") : pretty(question, body: body, catalog: catalog))
        case .text(let text): return (name ?? L("Compose text"), text.isEmpty ? L("Write the text") : pretty(text, body: body, catalog: catalog))
        case .branch(let c, _, _): return (name ?? L("Condition"), c.value.isEmpty ? L("Say what to check") : condition(c, body: body, catalog: catalog))
        case .wait(let minutes): return (name ?? L("Wait"), Format.duration(Double(minutes) * 60))
        case .flow(let flow): return (name ?? L("Run another flow"), flow.isEmpty ? L("Pick which flow") : flow)
        case .repeatUntil(let until, let times, _):
            let said = until.value.isEmpty ? L("Say what has to hold") : check(of: until, body: body, catalog: catalog)
            return (name ?? L("Repeat until"), L("{what}, {count} times at most", ["what": said, "count": Format.integer(times)]))
        case .forEach(let items, _, _, _): return (name ?? L("For each"), items.isEmpty ? L("Say which list") : L("Each item of {list}", ["list": pretty(items, body: body, catalog: catalog)]))
        case .choose(let value, let paths, _): return (name ?? L("Choose a path"), value.isEmpty ? L("Say what to look at") : L("By {value}: {count} ways", ["value": pretty(value, body: body, catalog: catalog), "count": Format.integer(paths.count)]))
        case .attempt: return (name ?? L("Try"), L("If a step fails, do something else"))
        case .parallel(let lanes): return (name ?? L("At the same time"), L("{count} things at once", ["count": Format.integer(lanes.count)]))
        case .call(let flow, _): return (name ?? L("Run a flow and wait"), flow.isEmpty ? L("Pick which flow") : flow)
        case .finish(let value): return (name ?? L("Finish here"), value.isEmpty ? L("With no result") : L("With {value}", ["value": pretty(value, body: body, catalog: catalog)]))
        case .data(let data): return (name ?? dataName(data.op), data.from.isEmpty ? L("Say what from") : pretty(data.from, body: body, catalog: catalog))
        case .form(let form): return (name ?? L("A form for you"), form.title.nonEmpty ?? L("Say what it asks"))
        case .waitFor(let event, let contains, let minutes):
            let what = contains.map { "\(eventName(event)): “\($0)”" } ?? eventName(event)
            return (name ?? L("Wait for something"), L("{what}, for up to {time}", ["what": what, "time": Format.duration(Double(minutes) * 60)]))
        }
    }

    private static func check(of c: Condition, body: FlowBody, catalog: Catalog) -> String {
        let value = pretty(c.value, body: body, catalog: catalog), than = pretty(c.than, body: body, catalog: catalog)
        switch c.test {
        case .contains: return L("{value} mentions “{than}”", ["value": value, "than": than])
        case .not_contains: return L("{value} doesn't mention “{than}”", ["value": value, "than": than])
        case .is: return L("{value} is “{than}”", ["value": value, "than": than])
        case .is_not: return L("{value} isn't “{than}”", ["value": value, "than": than])
        case .is_empty: return L("{value} is empty", ["value": value])
        case .not_empty: return L("{value} has something", ["value": value])
        case .more_than: return L("{value} is more than {than}", ["value": value, "than": than])
        case .less_than: return L("{value} is less than {than}", ["value": value, "than": than])
        }
    }

    /// Every way it starts, read aloud.
    static func triggers(_ body: FlowBody) -> String {
        Format.list(body.triggers.map(trigger), or: true)
    }

    /// The same, in about `room` characters. Each way keeps its share, so the ones read last don't fall off the end, and a long address gives way before a short time.
    static func triggers(_ body: FlowBody, room: Int) -> String {
        var said = body.triggers.map(trigger)
        var left = room, waiting = said.count
        for i in said.indices.sorted(by: { said[$0].count < said[$1].count }) {
            let share = left / waiting
            if said[i].count > share { said[i] = said[i].prefix(share) + "…" }
            left -= min(said[i].count, share)
            waiting -= 1
        }
        return Format.list(said, or: true)
    }

    static func branch(_ c: Condition, holds: Bool, body: FlowBody, catalog: Catalog) -> String {
        let said = condition(c, body: body, catalog: catalog)
        return holds ? L("{condition}: yes", ["condition": said]) : L("{condition}: no", ["condition": said])
    }

    /// A tool's own sentence about a call, once its values are filled in, kept short.
    static func resolved(_ text: String, values: Values) -> String {
        String(values.fill(text).prefix(240))
    }

    /// The flow read aloud.
    static func aloud(_ body: FlowBody, catalog: Catalog) -> String {
        func said(_ list: [Step]) -> [String] {
            list.flatMap { s -> [String] in
                guard case .branch(let c, let then, let otherwise) = s.kind else {
                    let own = step(s, body: body, catalog: catalog)
                    return s.parts.isEmpty ? [own + "."] : [own + ":"] + s.parts.flatMap { said($0.steps) }
                }
                var out = [condition(c, body: body, catalog: catalog) + ":"] + said(then)
                if !otherwise.isEmpty { out += [L("Otherwise:")] + said(otherwise) }
                return out
            }
        }
        return Format.sentences([triggers(body) + ":"] + said(body.steps))
    }

    static func aiRefusal(_ reason: String) -> String {
        switch reason {
        case "off": return L("The AI is off for Sideflow, or there's no AI set up.")
        case "busy": return L("The AI was busy with another request.")
        case "limit": return L("Sideflow has used its AI requests for today.")
        case "denied": return L("The AI request wasn't allowed.")
        default: return L("The AI didn't answer.")
        }
    }

    static func planRefusal(_ reason: String) -> String {
        switch reason {
        case "denied": return L("You said no, so it stays as it was.")
        case "unanswered": return L("Nobody answered the card in time, so it stays as it was.")
        case "not_asked": return L("Turning a flow on starts with your own click or request. Press Turn on.")
        case "not_contained": return L("Sidefolk gives plans only to extensions that can't reach the internet by themselves.")
        case "unknown_tool": return L("One of its steps uses a tool that isn't available now.")
        case "busy": return L("There's already a card up from Sideflow. Answer that, then try this again.")
        default: return L("Sidefolk didn't accept the plan.")
        }
    }
}
