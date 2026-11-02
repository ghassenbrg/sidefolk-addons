import Foundation
import SidefolkExtensionKit

/// What a click on the page does: the one tool `ui`, as the person (never offered to a model). Every change goes to the draft.
@MainActor enum Actions_UI {
    /// Where the click leaves the page.
    enum Leaves { case stay, flow(String), home }

    static func handle(_ a: Arguments, _ app: App) async throws -> Leaves {
        let op = a.string("op") ?? ""
        func flow() throws -> Flow {
            guard let id = a.string("flow"), let flow = app.store.flow(id) else { throw Problem(L("That flow is gone.")) }
            return flow
        }
        /// Changes the draft and looks again at what Guard would say of it.
        func draft(_ change: (inout FlowBody) throws -> Void) throws {
            var f = try flow()
            try change(&f.draft)
            app.store.save(f)
            app.refreshPreflight(f.id)
        }
        func editStep(_ edit: (inout Step) -> Void) throws {
            guard let id = a.string("step") else { return }
            try draft { $0 = Editing.change(id, in: $0, edit) }
        }
        func editTrigger(_ edit: (inout Trigger) -> Void) throws { try draft { edit(&$0.trigger) } }
        let text = a.values["text"] as? String ?? ""

        switch op {
        case "inspect":
            let target = a.string("target") ?? "start"
            app.nav.inspect(target == "start" ? .trigger : .step(target), in: try flow().id)
        case "add":
            app.nav.inspect(.adding(after: a.string("target") ?? "start"), in: try flow().id)
            app.nav.search = ""
        case "search":
            app.nav.search = text
        case "add_kind":
            let f = try flow()
            guard let kind = a.string("kind") else { return .stay }
            let new = newStep(kind, in: f.draft, app)
            try draft { $0 = Editing.insert(new, after: a.string("after") ?? "start", in: $0) }
            app.nav.inspect(.step(new.id), in: f.id)
        case "remove":
            if let id = a.string("step") {
                try draft { $0 = Editing.remove(id, from: $0) }
                app.nav.inspect(.trigger, in: try flow().id)
            }
        case "reorder":
            if let move = a.values["move"] as? [String: Any], let id = move["id"] as? String {
                try draft { $0 = Editing.move(id, before: (move["before"] as? String)?.nonEmpty, in: $0) }
            }
        case "up", "down":
            if let id = a.string("step") { try draft { $0 = Editing.nudge(id, by: op == "up" ? -1 : 1, in: $0) } }
        case "rename":
            var f = try flow()
            if let name = text.nonEmpty { f.name = String(name.prefix(60)) }
            app.store.save(f)
        case "param":
            let f = try flow()
            guard let id = a.string("step"), let name = a.string("name"), let step = f.draft.step(id), case .action(let tool, _) = step.kind else { return .stay }
            let parameter = app.catalog.tool(tool)?.parameters.first { $0.name == name } ?? Catalog.Parameter(name: name, kind: .text, required: false, title: name)
            let value: JSON? = if let on = a.bool("on") { .bool(on) } else if let picked = a.string("value") { picked == "" ? nil : .string(picked) } else { Editing.value(text, for: parameter) }
            try editStep { s in
                guard case .action(let t, var input) = s.kind else { return }
                input[name] = value
                s.kind = .action(tool: t, input: input)
            }
        case "step_name":
            try editStep { $0.name = text.nonEmpty }
        case "ai_prompt":
            try editStep { $0.kind = .ai(prompt: text) }
        case "compose":
            try editStep { $0.kind = .text(text) }
        case "question":
            try editStep { if case .ask(_, let options) = $0.kind { $0.kind = .ask(question: text, options: options) } }
        case "options":
            let options = text.split(separator: ",").map { String($0).trimmed }.filter { !$0.isEmpty }
            guard options.isEmpty || (2...4).contains(options.count) else { throw Problem(L("Give 2 to 4 answers, with commas between them, or none to let yourself type.")) }
            try editStep { if case .ask(let q, _) = $0.kind { $0.kind = .ask(question: q, options: options) } }
        case "wait":
            guard let minutes = Int(text.trimmed), (1...FlowBody.longestWait).contains(minutes) else {
                throw Problem(L("A wait is 1 to {count} minutes.", ["count": Format.integer(FlowBody.longestWait)]))
            }
            try editStep { $0.kind = .wait(minutes: minutes) }
        case "cond_value", "cond_than", "cond_test":
            try editStep { s in
                guard case .branch(var c, let then, let otherwise) = s.kind else { return }
                if op == "cond_value" { c.value = text }
                if op == "cond_than" { c.than = text }
                if op == "cond_test", let raw = a.string("value"), let test = Condition.Test(rawValue: raw) { c.test = test }
                s.kind = .branch(c, then: then, otherwise: otherwise)
            }
        case "on_failure":
            if let raw = a.string("value"), let f = Step.OnFailure(rawValue: raw) { try editStep { $0.onFailure = f } }
        case "trigger_kind":
            switch a.string("value") {
            case "manual": try editTrigger { $0 = .manual }
            case "days": try editTrigger { $0 = .days([1, 2, 3, 4, 5], hour: 8, minute: 30, catchUp: true) }
            case "every": try editTrigger { $0 = .every(minutes: 60, catchUp: false) }
            case "watch": try editTrigger { $0 = .watch(WatchTrigger(kind: "url_change", target: "https://example.com")) }
            default: break
            }
        case "days":
            let picked = (a.values["values"] as? [String] ?? []).compactMap { FlowCodec.days.firstIndex(of: $0).map { $0 + 1 } }
            guard !picked.isEmpty else { throw Problem(L("A schedule needs at least one day.")) }
            try editTrigger { if case .days(_, let h, let m, let c) = $0 { $0 = .days(picked.sorted(), hour: h, minute: m, catchUp: c) } }
        case "at":
            guard let (h, m) = FlowCodec.clock(text) else { throw Problem(L("Write the time like 08:30.")) }
            try editTrigger { if case .days(let d, _, _, let c) = $0 { $0 = .days(d, hour: h, minute: m, catchUp: c) } }
        case "every":
            guard let minutes = Int(text.trimmed), minutes >= FlowBody.shortestEvery else {
                throw Problem(L("“every_minutes” must be at least {count}.", ["count": Format.integer(FlowBody.shortestEvery)]))
            }
            try editTrigger { if case .every(_, let c) = $0 { $0 = .every(minutes: minutes, catchUp: c) } }
        case "catch_up":
            let on = a.bool("on") ?? false
            try editTrigger {
                switch $0 {
                case .days(let d, let h, let m, _): $0 = .days(d, hour: h, minute: m, catchUp: on)
                case .every(let n, _): $0 = .every(minutes: n, catchUp: on)
                default: break
                }
            }
        case "watch_kind", "watch_target", "watch_contains", "watch_pattern":
            try editTrigger { t in
                guard case .watch(var w) = t else { return }
                switch op {
                case "watch_kind": w.kind = a.string("value") ?? w.kind
                case "watch_target": w.target = text.trimmed
                case "watch_contains": w.contains = text.nonEmpty
                default: w.pattern = text.nonEmpty
                }
                t = .watch(w)
            }
        case "new":
            if let id = a.string("template"), let t = Templates.template(id) {
                let f = app.newFlow(name: t.name, body: try FlowCodec.body(t.body))
                app.refreshPreflight(f.id)
                return .flow(f.id)
            }
            return .flow(app.newFlow(name: L("New flow"), body: FlowBody()).id)
        case "describe":
            Drafting.start(text, app)
        case "practice":
            app.engine.practise(try flow())
        case "start":
            app.engine.turnOn(try flow().id)
        case "pause":
            app.engine.pause(try flow().id)
        case "resume":
            app.engine.resume(try flow().id)
        case "run":
            let f = try flow()
            app.engine.start(f, mode: f.live != nil ? .live : .once, why: L("You asked for it."))
        case "discard":
            var f = try flow()
            if let live = f.live { f.draft = live }
            app.store.save(f)
            app.refreshPreflight(f.id)
        case "delete":
            app.engine.delete(try flow().id)
            return .home
        case "duplicate":
            let f = try flow()
            let copy = app.newFlow(name: f.name, body: f.draft)
            app.refreshPreflight(copy.id)
            return .flow(copy.id)
        case "proceed":
            if let id = a.string("run"), let how = a.string("how").flatMap(Engine.Forward.init(rawValue:)) { app.engine.proceed(id, how) }
        default:
            break
        }
        return .stay
    }

    static func newStep(_ kind: String, in body: FlowBody, _ app: App) -> Step {
        if kind.hasPrefix("tool:") {
            let name = String(kind.dropFirst(5))
            let t = app.catalog.tool(name)
            return Step(id: Editing.freshId(body, base: t?.title ?? "step"), kind: .action(tool: name, input: [:]))
        }
        switch kind {
        case "tell":
            return Step(id: Editing.freshId(body, base: "tell"), name: L("Tell me"), kind: .action(tool: "notify.user", input: ["title": .string(L("Done"))]))
        case "ai": return Step(id: Editing.freshId(body, base: "written"), kind: .ai(prompt: ""))
        case "ask": return Step(id: Editing.freshId(body, base: "answer"), kind: .ask(question: "", options: [L("Yes"), L("No")]))
        case "text": return Step(id: Editing.freshId(body, base: "text"), kind: .text(""))
        case "wait": return Step(id: Editing.freshId(body, base: "wait"), kind: .wait(minutes: 30))
        default:
            let last = body.allSteps.last { $0.hasOutput }.map { "{{\($0.id)}}" } ?? ""
            return Step(id: Editing.freshId(body, base: "check"), kind: .branch(Condition(value: last, test: .contains, than: ""), then: [], otherwise: []))
        }
    }
}

/// A request in the person's words becomes a draft, through their AI: it writes the definition; nothing it writes runs. What comes back is read like
/// anything from outside: only a definition that parses is kept, and it is shown for them to read.
@MainActor enum Drafting {
    static func start(_ words: String, _ app: App) {
        guard let words = words.nonEmpty, app.drafting == nil else { return }
        app.drafting = words
        app.draftProblem = nil
        Task {
            if app.catalog.loadedAt == nil { await app.catalog.refresh() }
            defer { app.drafting = nil }
            let tools = app.catalog.tools.prefix(50).map { t in "\(t.name) (\(t.parameters.map(\.name).joined(separator: ", "))): \(t.title)" }.joined(separator: "\n")
            let prompt = """
            Turn this request into one flow. Answer with only JSON: {"name": "a short name", "flow": {…}}.

            \(Grammar.text)

            Tools:
            \(tools)

            Request: \(words)
            """
            switch await app.host.write(String(prompt.prefix(7800)), label: L("Draft a flow")) {
            case .answer(let text, _):
                guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}"),
                      let o = JSONText.read(String(text[start...end])) as? [String: Any], let body = try? FlowCodec.body(o["flow"]) else {
                    app.draftProblem = L("The AI's answer wasn't a flow I could read. Try saying it another way, or start from a template.")
                    return
                }
                let flow = app.newFlow(name: (o["name"] as? String)?.nonEmpty ?? String(words.prefix(40)), body: body)
                app.refreshPreflight(flow.id)
            case .refused(let reason):
                app.draftProblem = Words.aiRefusal(reason)
            }
        }
    }
}
