import Foundation
import SidefolkExtensionKit

/// What a click on the page does: the one tool `ui`, as the person (never offered to a model). Every change goes to the draft.
@MainActor enum Actions_UI {
    /// Where the click leaves the page.
    enum Leaves { case stay, flow(String), panel(String), run(String), importing(String), home }

    static func handle(_ a: Arguments, _ app: App) async throws -> Leaves {
        let op = a.string("op") ?? ""
        func flow() throws -> Flow {
            guard let id = a.string("flow"), let flow = app.store.flow(id) else { throw Problem(L("That flow is gone.")) }
            return flow
        }
        /// Changes the draft and looks again at what Guard would say of it.
        func draft(_ change: (inout FlowBody) throws -> Void) throws {
            var f = try flow()
            let before = f.draft
            try change(&f.draft)
            // Here, where it can be said. Only for an edit that grows it: one already past a limit, from before there was one, can always be brought back.
            if f.draft.allSteps.count > FlowBody.maxSteps, f.draft.allSteps.count > before.allSteps.count { throw Problem(L("A flow can have at most {count} steps.", ["count": Format.integer(FlowBody.maxSteps)])) }
            guard f.draft != before else { return }
            guard f.draft.depth <= FlowBody.maxDepth || f.draft.depth <= before.depth else { throw Problem(L("That goes too deep: a flow can hold steps inside steps {count} levels down.", ["count": Format.integer(FlowBody.maxDepth)])) }
            // Typing in a field is one step back: the same field, moments apart.
            let typing = ["step_name", "ai_prompt", "compose", "question", "options", "param", "cond_value", "cond_than", "watch_target", "watch_contains", "watch_pattern", "event_contains", "each_items", "choose_value", "path_when", "lane_name", "lane_limit", "takes_name", "call_input", "finish_value", "data_from", "data_field", "data_than", "data_separator", "form_title", "form_label", "form_options", "wait_contains", "sample", "trigger_sample", "time_zone"].contains(op)
            app.history[f.id, default: Editing.History()].record(before, key: typing ? "\(op)|\(a.string("step") ?? "")|\(a.string("name") ?? "")" : nil, at: Date())
            f.hold(before)
            app.store.save(f)
            app.refreshPreflight(f.id)
        }
        func editStep(_ edit: (inout Step) -> Void) throws {
            guard let id = a.string("step") else { return }
            try draft { $0 = Editing.change(id, in: $0, edit) }
        }
        /// Which way it starts: the first, or one of those `also` names.
        func editTrigger(_ edit: (inout Trigger) -> Void) throws {
            try draft { body in
                if let at = a.int("also") {
                    if body.alsoWhen.indices.contains(at) { edit(&body.alsoWhen[at]) }
                } else {
                    edit(&body.trigger)
                }
            }
        }
        /// A condition's checks, whichever step holds them.
        func editCondition(_ edit: (inout Condition) -> Void) throws {
            try editStep { s in
                switch s.kind {
                case .branch(var c, let then, let otherwise):
                    edit(&c)
                    s.kind = .branch(c, then: then, otherwise: otherwise)
                case .repeatUntil(var c, let times, let steps):
                    edit(&c)
                    s.kind = .repeatUntil(until: c, times: times, steps: steps)
                default: break
                }
            }
        }
        let text = a.values["text"] as? String ?? ""

        switch op {
        case "inspect":
            let target = a.string("target") ?? "start"
            let id = try flow().id
            // Pressing what's selected puts it away.
            let chosen: Nav.Inspecting = target == "start" ? .trigger : .step(target)
            app.nav.inspect(app.store.flow(id).map(app.nav.inspecting) == chosen ? .nothing : chosen, in: id)
        case "add_kind":
            let f = try flow()
            guard let kind = a.string("kind") else { return .stay }
            let new = newStep(kind, in: f.draft, of: f.id, app)
            try draft { $0 = Editing.insert(new, after: a.string("after") ?? "start", in: $0) }
            app.nav.inspect(.step(new.id), in: f.id)
        case "remove":
            if let id = a.string("step") {
                try draft { $0 = Editing.remove(id, from: $0) }
                app.nav.inspect(.nothing, in: try flow().id)
            }
        case "reorder":
            if let move = a.values["move"] as? [String: Any], let id = move["id"] as? String {
                if let after = (move["after"] as? String)?.nonEmpty {
                    try draft { $0 = Editing.place(id, after: after, in: $0) }
                } else {
                    try draft { $0 = Editing.move(id, before: (move["before"] as? String)?.nonEmpty, in: $0) }
                }
            }
        case "move_after":
            if let id = a.string("step"), let after = a.string("value") { try draft { $0 = Editing.place(id, after: after, in: $0) } }
        case "up", "down":
            if let id = a.string("step") { try draft { $0 = Editing.nudge(id, by: op == "up" ? -1 : 1, in: $0) } }
        case "rename_open":
            // Its name is on the flow's own panel, whatever was selected and whichever tab this came from.
            let f = try flow()
            app.nav.inspect(.nothing, in: f.id)
            return .panel(f.id)
        case "rename":
            var f = try flow()
            if let name = text.nonEmpty.map({ String($0.prefix(60)) }) {
                try app.rename(&f, to: name)
            }
            app.store.save(f)
        case "param":
            let f = try flow()
            guard let id = a.string("step"), let name = a.string("name"), let step = f.draft.step(id), case .action(let tool, _) = step.kind else { return .stay }
            let parameter = app.catalog.parameter(name, of: tool) ?? Catalog.Parameter(name: name, kind: .text, required: false, title: name)
            // One infinity would stop the whole file saving, so it never gets in.
            let isValue = !Values.slots(text).isEmpty
            if case .integer = parameter.kind, !isValue, !text.trimmed.isEmpty, Editing.wholeNumber(text) == nil { throw Problem(L("That isn't a whole number.")) }
            if case .number = parameter.kind, !isValue, !text.trimmed.isEmpty, Editing.number(text) == nil { throw Problem(Editing.couldBeMoreThanOne(text) ? L("That could be more than one number. Write it plainly, like 1500 or 1.5.") : L("That isn't a number.")) }
            let value: JSON? = if let on = a.bool("on") { .bool(on) } else if let picked = a.string("value") { picked == "" ? nil : .string(picked) } else { Editing.value(text, for: parameter) }
            try editStep { s in
                guard case .action(let t, let input) = s.kind else { return }
                s.kind = .action(tool: t, input: Editing.setting(app.catalog.path(name, of: t), to: value, in: input))
            }
        case "param_mode":
            // Pointing a field at an earlier step, or back to writing it here: what was there doesn't fit the other way.
            let f = try flow()
            guard let id = a.string("step"), let name = a.string("name"), let step = f.draft.step(id), case .action = step.kind else { return .stay }
            app.nav.useValue(a.bool("on") == true, flow: f.id, step: id, parameter: name)
            try editStep { s in
                guard case .action(let t, let input) = s.kind else { return }
                s.kind = .action(tool: t, input: Editing.setting(app.catalog.path(name, of: t), to: nil, in: input))
            }
        case "param_json":
            // What the form can't draw, written out: as itself, or it's said why not.
            let f = try flow()
            guard let id = a.string("step"), let name = a.string("name"), let step = f.draft.step(id), case .action = step.kind else { return .stay }
            let t = text.trimmed
            let parsed: JSON? = t.isEmpty || !JSONText.saysOneThing(Data(t.utf8)) ? nil : (try? JSONSerialization.jsonObject(with: Data(t.utf8), options: .fragmentsAllowed)).map { JSON($0) }
            if !t.isEmpty, parsed == nil { throw Problem(L("That isn't written the way it needs to be: check its brackets and quotes.")) }
            try editStep { s in
                guard case .action(let tool, let input) = s.kind else { return }
                s.kind = .action(tool: tool, input: Editing.setting(app.catalog.path(name, of: tool), to: parsed, in: input))
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
            // Which check of the condition: the first, or one of those after it.
            let at = a.int("check") ?? 0
            try editCondition { c in
                func edit(_ check: inout Condition) {
                    if op == "cond_value" { check.value = text }
                    if op == "cond_than" { check.than = text }
                    if op == "cond_test", let raw = a.string("value"), let test = Condition.Test(rawValue: raw) { check.test = test }
                }
                if at == 0 { edit(&c) } else if c.also.indices.contains(at - 1) { edit(&c.also[at - 1]) }
            }
        case "cond_add":
            try editCondition { $0.also.append(Condition(value: "", test: .contains, than: "")) }
        case "cond_remove":
            let at = a.int("check") ?? 0
            try editCondition { c in
                if c.also.indices.contains(at - 1) { c.also.remove(at: at - 1) }
            }
        case "cond_join":
            let any = a.string("value") == "any"
            try editCondition { $0.any = any }
        case "repeat_times":
            guard let times = Int(text.trimmed), (1...FlowBody.mostRepeats).contains(times) else { throw Problem(L("“times” is 1 to {count}.", ["count": Format.integer(FlowBody.mostRepeats)])) }
            try editStep { if case .repeatUntil(let until, _, let steps) = $0.kind { $0.kind = .repeatUntil(until: until, times: times, steps: steps) } }
        case "each_items":
            try editStep { if case .forEach(_, let limit, let failure, let steps) = $0.kind { $0.kind = .forEach(items: text, limit: limit, onFailure: failure, steps: steps) } }
        case "each_limit":
            guard let limit = Int(text.trimmed), (1...FlowBody.longestLoop).contains(limit) else { throw Problem(L("“limit” is 1 to {count} items.", ["count": Format.integer(FlowBody.longestLoop)])) }
            try editStep { if case .forEach(let items, _, let failure, let steps) = $0.kind { $0.kind = .forEach(items: items, limit: limit, onFailure: failure, steps: steps) } }
        case "each_failure":
            if let failure = a.string("value").flatMap(Step.LoopFailure.init(rawValue:)) {
                try editStep { if case .forEach(let items, let limit, _, let steps) = $0.kind { $0.kind = .forEach(items: items, limit: limit, onFailure: failure, steps: steps) } }
            }
        case "choose_value":
            try editStep { if case .choose(_, let paths, let otherwise) = $0.kind { $0.kind = .choose(value: text, paths: paths, otherwise: otherwise) } }
        case "path_when", "path_remove", "path_add":
            let at = a.int("path") ?? 0
            try editStep { s in
                guard case .choose(let value, var paths, let otherwise) = s.kind else { return }
                if op == "path_add" {
                    if paths.count < FlowBody.mostPaths { paths.append(Step.Path(when: "", steps: [])) }
                }
                else if paths.indices.contains(at) {
                    if op == "path_when" { paths[at].when = text } else if paths.count > 1 { paths.remove(at: at) }
                }
                s.kind = .choose(value: value, paths: paths, otherwise: otherwise)
            }
        case "lane_name", "lane_remove", "lane_add":
            let at = a.int("lane") ?? 0
            // Two that go by the same name would quietly swap what a step's `{{step.name}}` means.
            if op == "lane_name", case .parallel(let lanes)? = try flow().draft.step(a.string("step") ?? "")?.kind,
               Engine.key(text) != "lane", lanes.enumerated().contains(where: { $0.offset != at && Engine.key($0.element.name) == Engine.key(text) }) {
                throw Problem(L("Another lane already goes by that name."))
            }
            try editStep { s in
                guard case .parallel(var lanes) = s.kind else { return }
                if op == "lane_add" {
                    if lanes.count < FlowBody.mostLanes { lanes.append(Step.Lane(name: L("Lane {count}", ["count": Format.integer(lanes.count + 1)]), steps: [])) }
                }
                else if lanes.indices.contains(at) {
                    if op == "lane_name" { lanes[at].name = text.nonEmpty ?? lanes[at].name } else if lanes.count > 2 { lanes.remove(at: at) }
                }
                s.kind = .parallel(lanes: lanes)
                // Fewer lanes than it said were enough: all of them is the most it can mean.
                if case .atLeast(let need) = s.join, need >= lanes.count { s.join = .all }
            }
        case "lane_limit":
            let at = a.int("lane") ?? 0, words = text.trimmed
            guard words.isEmpty || Int(words).map({ (1...FlowBody.longestLaneMinutes).contains($0) }) == true else {
                throw Problem(L("A lane's limit is 1 to {count} minutes.", ["count": Format.integer(FlowBody.longestLaneMinutes)]))
            }
            try editStep { s in
                guard case .parallel(var lanes) = s.kind, lanes.indices.contains(at) else { return }
                lanes[at].timeoutMinutes = Int(words)
                s.kind = .parallel(lanes: lanes)
            }
        case "lane_join":
            if let join = Step.Join(a.string("value")) { try editStep { $0.join = join } }
        case "lane_fail_fast":
            if let on = a.bool("on") { try editStep { $0.failFast = on } }
        case "call_flow":
            // A version's number means nothing to another flow.
            if let name = a.string("value") { try editStep { if case .call(let was, let inputs) = $0.kind { $0.kind = .call(flow: name, inputs: inputs); if was != name { $0.pin = nil } } } }
        case "call_pin":
            try editStep { $0.pin = (a.values["value"] as? String).flatMap { Int($0) } }
        case "call_input":
            if let name = a.string("name") {
                try editStep { if case .call(let flow, var inputs) = $0.kind { inputs[name] = text.nonEmpty; $0.kind = .call(flow: flow, inputs: inputs) } }
            }
        case "finish_value":
            try editStep { if case .finish = $0.kind { $0.kind = .finish(text) } }
        case "data_op", "data_from", "data_field", "data_test", "data_than", "data_descending", "data_by_name", "data_count", "data_separator":
            try editStep { s in
                guard case .data(var d) = s.kind else { return }
                switch op {
                case "data_op": if let o = a.string("value").flatMap(DataStep.Op.init(rawValue:)) { d.op = o }
                case "data_from": d.from = text
                case "data_field": d.field = text.nonEmpty
                case "data_test": d.test = a.string("value").flatMap(Condition.Test.init(rawValue:))
                case "data_than": d.than = text
                case "data_descending": d.descending = a.bool("on") ?? false
                case "data_by_name": d.byName = a.bool("on") ?? false
                case "data_count": d.count = Int(text.trimmed).map { max(1, $0) }
                default: d.separator = text
                }
                s.kind = .data(d)
            }
        case "form_title", "form_hours", "form_label", "form_kind", "form_options", "form_remove", "form_add":
            if op == "form_hours", (Int(text.trimmed) ?? 0) < 1 || (Int(text.trimmed) ?? 0) > FormStep.longestHours {
                throw Problem(L("A form waits 1 to {count} hours.", ["count": Format.integer(FormStep.longestHours)]))
            }
            let at = a.int("field") ?? 0
            try editStep { s in
                guard case .form(var f) = s.kind else { return }
                switch op {
                case "form_title": f.title = text
                case "form_hours": f.hours = Int(text.trimmed) ?? f.hours
                case "form_add" where f.fields.count < 12:
                    var n = f.fields.count + 1
                    while f.fields.contains(where: { $0.name == "field_\(n)" }) { n += 1 }
                    f.fields.append(FormStep.Field(name: "field_\(n)", label: L("Field {count}", ["count": Format.integer(n)]), kind: .text))
                case "form_label" where f.fields.indices.contains(at): f.fields[at].label = text.nonEmpty ?? f.fields[at].label
                case "form_kind" where f.fields.indices.contains(at): if let k = a.string("value").flatMap(FormStep.Field.Kind.init(rawValue:)) { f.fields[at].kind = k }
                case "form_options" where f.fields.indices.contains(at): f.fields[at].options = text.split(separator: ",").map { String($0).trimmed }.filter { !$0.isEmpty }
                case "form_remove" where f.fields.indices.contains(at) && f.fields.count > 1: f.fields.remove(at: at)
                default: break
                }
                s.kind = .form(f)
            }
        case "end_held":
            app.engine.endHeldRuns()
        case "stop_run":
            if let id = a.string("run") { app.engine.stop(run: id, byThePerson: a.string("page_token") == app.pageKey) }
        case "inspect_run":
            if let id = a.string("run"), let target = a.string("target") {
                // Pressing what's selected puts it away, as on the board.
                app.nav.runStep[id] = app.nav.runStep[id] == target || target == "start" ? nil : target
                app.nav.runScope[id] = nil
            }
        case "inspect_scope":
            if let id = a.string("run"), let value = a.string("value") { app.nav.runScope[id] = value }
        case "bring_back":
            var f = try flow()
            guard let at = a.int("revision"), f.revisions.indices.contains(at) else { break }
            app.history[f.id, default: Editing.History()].record(f.draft, key: nil, at: Date())
            f.show(f.revisions[at].body)
            app.store.save(f)
            app.refreshPreflight(f.id)
        case "import":
            // What's pasted goes the way a file goes: read, shown, and brought in only on the page's own yes.
            return .importing(try FlowFile.stage(text, in: app.folder))
        case "import_cancel":
            if let id = a.string("id") { FlowFile.unstage(id, in: app.folder) }
            return .home
        case "import_confirm":
            // A file comes from anywhere and another extension can call this, so only the page's own button counts.
            guard a.string("page_token") == app.pageKey, let id = a.string("id"), let words = FlowFile.staged(id, in: app.folder) else { break }
            let made = try FlowFile.arriving(try FlowFile.read(words), store: app.store).map { app.newFlow(name: $0.name, body: $0.body) }
            FlowFile.unstage(id, in: app.folder)
            for flow in made { app.refreshPreflight(flow.id) }
            if let first = made.first { return .flow(first.id) }
        case "reveal":
            // Sidefolk's own tool, as Sideflow, with Guard: it shows a file only in a folder shared with it, and says so if not.
            guard let path = a.string("path"), path.hasPrefix("/") || path.hasPrefix("~/") else { break }
            if let outcome = await app.engine.host?.call("files.reveal", ["path": path], plan: nil, written: nil), !outcome.ok {
                throw Problem(outcome.text.nonEmpty ?? L("Sidefolk wouldn't show that file."))
            }
        case "takes_add":
            try draft { body in
                guard body.inputs.count < Contract.mostInputs else { return }
                var n = body.inputs.count + 1
                while body.inputs.contains(where: { $0.name == "input_\(n)" }) { n += 1 }
                body.inputs.append(FlowInput(name: "input_\(n)"))
            }
        case "takes_name", "takes_type", "takes_required", "takes_remove":
            let at = a.int("at") ?? -1
            if op == "takes_name", text.trimmed.range(of: #"^[A-Za-z0-9_]{1,40}$"#, options: .regularExpression) == nil { throw Problem(L("Up to 40 letters, digits and _.")) }
            if op == "takes_name", try flow().draft.inputs.enumerated().contains(where: { $0.offset != at && $0.element.name == text.trimmed }) { throw Problem(L("It already takes something by that name.")) }
            try draft { body in
                guard body.inputs.indices.contains(at) else { return }
                switch op {
                case "takes_name": body.inputs[at].name = text.trimmed
                case "takes_type": if let type = a.string("value").flatMap(ValueType.init(rawValue:)) { body.inputs[at].type = type }
                case "takes_required": if let on = a.bool("on") { body.inputs[at].required = on }
                default: body.inputs.remove(at: at)
                }
            }
        case "gives":
            try draft { $0.output = (a.values["value"] as? String).flatMap(ValueType.init(rawValue:)) }
        case "overlap":
            if let raw = a.string("value"), let overlap = FlowBody.Overlap(rawValue: raw) { try draft { $0.overlap = overlap } }
        case "time_zone":
            guard text.trimmed.isEmpty || TimeZone(identifier: text.trimmed) != nil else { throw Problem(L("“{zone}” isn't a time zone: use a name like Europe/Paris.", ["zone": text.trimmed])) }
            try draft { $0.timeZone = text.nonEmpty }
        case "sample":
            try editStep { $0.sample = text.nonEmpty }
        case "trigger_sample":
            try draft { $0.triggerSample = text.nonEmpty }
        case "form_field":
            // Typed so far: kept with the run, so a restart doesn't lose it. What a form says is believed to be the person's own, so only the page's own fields count.
            guard a.string("page_token") == app.pageKey else { break }
            if let id = a.string("run"), let name = a.string("name"), var run = app.store.run(id), run.form != nil {
                run.form?.answers[name] = a.values["value"] != nil ? JSON(a.values["value"]) : (a.bool("on").map { JSON.bool($0) } ?? JSON.string(text))
                app.store.save(run)
            }
        case "form_send":
            guard a.string("page_token") == app.pageKey else { break }
            if let id = a.string("run") { try app.engine.answer(run: id, form: [:]) }
        case "wait_event", "wait_contains", "wait_minutes":
            if op == "wait_minutes", (Int(text.trimmed) ?? 0) < 1 || (Int(text.trimmed) ?? 0) > FlowBody.longestWait * 30 {
                throw Problem(L("A wait is 1 to {count} minutes.", ["count": Format.integer(FlowBody.longestWait * 30)]))
            }
            try editStep { s in
                guard case .waitFor(var event, var contains, var minutes) = s.kind else { return }
                switch op {
                case "wait_event": if let name = a.string("value"), Trigger.events.contains(name) { event = name }
                case "wait_contains": contains = text.nonEmpty
                default: minutes = Int(text.trimmed) ?? minutes
                }
                s.kind = .waitFor(event: event, contains: contains, minutes: minutes)
            }
        case "on_failure":
            if let raw = a.string("value"), let f = Step.OnFailure(rawValue: raw) { try editStep { $0.onFailure = f } }
        case "also_add":
            try draft { body in
                guard body.triggers.count < FlowBody.mostTriggers else { throw Problem(L("A flow can start {count} ways at most.", ["count": Format.integer(FlowBody.mostTriggers)])) }
                body.alsoWhen.append(a.string("kind") == "event" ? .event("reminder.fired", contains: nil) : .days([1, 2, 3, 4, 5], hour: 17, minute: 0, catchUp: false))
            }
        case "also_remove":
            try draft { body in
                if let at = a.int("also"), body.alsoWhen.indices.contains(at) { body.alsoWhen.remove(at: at) }
            }
        case "trigger_kind":
            switch a.string("value") {
            case "manual": try editTrigger { $0 = .manual }
            case "days": try editTrigger { $0 = .days([1, 2, 3, 4, 5], hour: 8, minute: 30, catchUp: true) }
            case "every": try editTrigger { $0 = .every(minutes: 60, catchUp: false) }
            case "watch": try editTrigger { $0 = .watch(WatchTrigger(kind: "url_change", target: "https://example.com")) }
            case "event": try editTrigger { $0 = .event("reminder.fired", contains: nil) }
            default: break
            }
        case "event_kind":
            if let name = a.string("value"), Trigger.events.contains(name) { try editTrigger { if case .event(_, let c) = $0 { $0 = .event(name, contains: c) } } }
        case "event_contains":
            try editTrigger { if case .event(let name, _) = $0 { $0 = .event(name, contains: text.nonEmpty) } }
        case "run_flow":
            if let name = a.string("value") { try editStep { $0.kind = .flow(name) } }
        case "days":
            let picked = (a.values["values"] as? [String] ?? []).compactMap { FlowCodec.days.firstIndex(of: $0).map { $0 + 1 } }
            guard !picked.isEmpty else { throw Problem(L("A schedule needs at least one day.")) }
            try editTrigger { if case .days(_, let h, let m, let c) = $0 { $0 = .days(picked.sorted(), hour: h, minute: m, catchUp: c) } }
        case "at":
            guard let (h, m) = FlowCodec.clock(text) else { throw Problem(L("Write the time like 08:30.")) }
            try editTrigger { if case .days(let d, _, _, let c) = $0 { $0 = .days(d, hour: h, minute: m, catchUp: c) } }
        case "every":
            guard let minutes = Int(text.trimmed), minutes >= FlowBody.shortestEvery, minutes <= FlowBody.longestEvery else {
                throw Problem(L("“every_minutes” must be from {least} to {most}.", ["least": Format.integer(FlowBody.shortestEvery), "most": Format.integer(FlowBody.longestEvery)]))
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
        case "watch_kind", "watch_target", "watch_contains", "watch_pattern", "watch_every", "watch_rest":
            let number = Int(text.trimmed)
            if op == "watch_every", !text.trimmed.isEmpty, (number ?? 0) < 1 { throw Problem(L("Write how many seconds, or leave it empty.")) }
            if op == "watch_rest", !text.trimmed.isEmpty, (number ?? -1) < 0 { throw Problem(L("Write how many minutes, or leave it empty.")) }
            try editTrigger { t in
                guard case .watch(var w) = t else { return }
                switch op {
                case "watch_kind": w.kind = a.string("value") ?? w.kind
                case "watch_target": w.target = text.trimmed
                case "watch_contains": w.contains = text.nonEmpty
                case "watch_every": w.everySeconds = number
                case "watch_rest": w.restMinutes = number
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
            let f = try flow()
            guard f.draft.problems(app.catalog).isEmpty else { throw Problem(L("Fix what's marked first.")) }
            app.engine.practice(f)
        case "start":
            let f = try flow()
            guard f.kept.problems(app.catalog).isEmpty else { throw Problem(L("Fix what's marked first.")) }
            app.engine.turnOn(f.id)
        case "pause":
            app.engine.pause(try flow().id)
        case "resume":
            app.engine.resume(try flow().id)
        case "end_plan":
            let f = try flow()
            app.engine.endPlan(f.id)
        case "run":
            let f = try flow()
            // A card can wait two minutes, and the page's own call doesn't.
            Task { await app.engine.runNow(f.id, why: L("You asked for it."), saving: true) }
        case "save":
            var f = try flow()
            f.saved = nil
            f.settleNote()
            app.store.save(f)
            // Typing again afterwards is a step of its own: what was saved stays one to come back to.
            app.history[f.id]?.breakTyping()
        case "discard":
            // Back to what Save last kept. Undo brings it back.
            var f = try flow()
            guard let kept = f.saved else { break }
            app.history[f.id, default: Editing.History()].record(f.draft, key: nil, at: Date())
            f.draft = kept
            f.saved = nil
            f.settleNote()
            app.store.save(f)
            app.refreshPreflight(f.id)
        case "back_to_live":
            var f = try flow()
            guard let live = f.live else { break }
            app.history[f.id, default: Editing.History()].record(f.draft, key: nil, at: Date())
            f.hold(f.draft)
            f.draft = live
            f.saved = nil
            f.settleNote()
            app.store.save(f)
            app.refreshPreflight(f.id)
        case "undo", "redo":
            var f = try flow()
            let current = f.draft
            guard let other = op == "undo" ? app.history[f.id]?.back(from: current) : app.history[f.id]?.forward(from: current) else { break }
            f.show(other)
            app.store.save(f)
            app.refreshPreflight(f.id)
            if case .step(let id) = app.nav.inspecting(f), other.step(id) == nil { app.nav.inspect(.nothing, in: f.id) }
        case "extract":
            let f = try flow()
            guard let id = a.string("step"), let step = f.draft.step(id) else { return .stay }
            // Named now, because the step that calls it goes by its name, and made only once nothing can refuse.
            let shell = app.newFlow(name: Words.label(step, catalog: app.catalog), body: FlowBody())
            do {
                let (outer, inner) = try Editing.extract(id, in: f.draft, named: shell.name)
                var made = shell
                made.draft = inner
                app.store.save(made)
                try draft { $0 = outer }
            } catch {
                app.store.remove(flow: shell.id)
                throw error
            }
        case "pause_run":
            if let id = a.string("run") { app.engine.pause(run: id) }
        case "run_again":
            if let id = a.string("run"), let started = app.engine.runAgain(id, fromHere: a.bool("here") == true) { return .run(started.id) }
        case "dup_step":
            let f = try flow()
            guard let id = a.string("step") ?? { if case .step(let s) = app.nav.inspecting(f) { s } else { nil } }(), let (body, new) = Editing.duplicate(id, in: f.draft) else { break }
            try draft { $0 = body }
            app.nav.inspect(.step(new), in: f.id)
        case "delete_too_long":
            // The page that says so has no room for a question first, and only that page holds this.
            guard a.string("page_token") == app.pageKey, let id = a.string("flow"), Pages.isTooLong(flow: id, tab: a.string("tab"), app) else { break }
            app.engine.delete(id)
            return .home
        case "ask_delete":
            let id = try flow().id
            app.nav.pickingFlows = [id]
            app.nav.askedFromAFlow = true
            app.nav.askingToDelete = true
            app.nav.askedToDeleteAt = Date()
            return .home
        case "pick_flows":
            app.nav.pickingFlows = []
            app.nav.askingToDelete = false
            app.nav.askedFromAFlow = false
        case "pick_flow":
            if let id = a.string("picked"), app.store.flow(id) != nil {
                if a.bool("on") == false { app.nav.pickingFlows?.remove(id) } else { app.nav.pickingFlows?.insert(id) }
                app.nav.askingToDelete = false
            }
        case "pick_all":
            app.nav.pickingFlows = Set(app.store.flows().prefix(Pages.mostToPick).map(\.id))
            app.nav.askingToDelete = false
        case "pick_none":
            app.nav.pickingFlows = nil
            app.nav.askingToDelete = false
            app.nav.askedFromAFlow = false
        case "pick_delete":
            app.nav.askingToDelete = !(app.nav.pickingFlows ?? []).isEmpty
            app.nav.askedToDeleteAt = Date()
        case "pick_keep":
            app.nav.askingToDelete = false
            if app.nav.askedFromAFlow {
                app.nav.pickingFlows = nil
                app.nav.askedFromAFlow = false
            }
        case "pick_delete_sure":
            // Another extension can call this on a card that names no flow, so only the page's own button counts. And only what the page said it would delete, after it said so.
            guard a.string("page_token") == app.pageKey, app.nav.askingToDelete else { break }
            if let asked = app.nav.askedToDeleteAt, Date().timeIntervalSince(asked) < Pages.settling { break }
            // What the button was drawn with, which is what the page named. Anything else since, and it asks again.
            guard Set(a.strings("named")) == app.nav.pickingFlows else {
                app.nav.askingToDelete = false
                break
            }
            for id in app.nav.pickingFlows ?? [] { app.engine.delete(id) }
            app.nav.pickingFlows = nil
            app.nav.askingToDelete = false
            app.nav.askedFromAFlow = false
            return .home
        case "duplicate":
            let f = try flow()
            let copy = app.newFlow(name: f.name, body: f.draft)
            app.refreshPreflight(copy.id)
            return .flow(copy.id)
        case "proceed":
            if let id = a.string("run"), let how = a.string("how").flatMap(Engine.Forward.init(rawValue:)) {
                // Stop works while it's running too, between steps.
                if how == .stop { app.engine.stop(run: id, byThePerson: a.string("page_token") == app.pageKey) } else { app.engine.proceed(id, how) }
            }
        default:
            break
        }
        return .stay
    }

    static func newStep(_ kind: String, in body: FlowBody, of flow: String, _ app: App) -> Step {
        // Another flow, if there is one: run on itself it can only fail. With none it stays to be picked, and it's marked.
        let other = app.store.flows().first { $0.id != flow }?.name ?? ""
        if kind.hasPrefix("tool:") {
            let name = String(kind.dropFirst(5))
            let t = app.catalog.tool(name)
            return Step(id: Editing.freshId(body, base: t?.title ?? "step"), kind: .action(tool: name, input: [:]))
        }
        switch kind {
        case "job":
            return Step(id: Editing.freshId(body, base: "job"), name: L("Let your companion do it"), kind: .action(tool: "companion.job", input: ["job": .string("")]))
        case "flow":
            return Step(id: Editing.freshId(body, base: "flow"), kind: .flow(other))
        case "tell":
            return Step(id: Editing.freshId(body, base: "tell"), name: L("Tell me"), kind: .action(tool: "notify.user", input: ["title": .string(L("Done"))]))
        case "ai": return Step(id: Editing.freshId(body, base: "written"), kind: .ai(prompt: ""))
        case "ask": return Step(id: Editing.freshId(body, base: "answer"), kind: .ask(question: "", options: [L("Yes"), L("No")]))
        case "text": return Step(id: Editing.freshId(body, base: "text"), kind: .text(""))
        case "wait": return Step(id: Editing.freshId(body, base: "wait"), kind: .wait(minutes: 30))
        case "repeat": return Step(id: Editing.freshId(body, base: "again"), kind: .repeatUntil(until: Condition(value: "", test: .contains, than: ""), times: 10, steps: []))
        case "for_each": return Step(id: Editing.freshId(body, base: "each"), kind: .forEach(items: "", limit: FlowBody.longestLoop, onFailure: .stop, steps: []))
        case "choose": return Step(id: Editing.freshId(body, base: "choose"), kind: .choose(value: "", paths: [Step.Path(when: "", steps: []), Step.Path(when: "", steps: [])], otherwise: []))
        case "try": return Step(id: Editing.freshId(body, base: "try"), kind: .attempt(steps: [], recover: [], always: []))
        case "parallel": return Step(id: Editing.freshId(body, base: "together"), kind: .parallel(lanes: [Step.Lane(name: L("First"), steps: []), Step.Lane(name: L("Second"), steps: [])]))
        case "call": return Step(id: Editing.freshId(body, base: "called"), kind: .call(flow: other, inputs: [:]))
        case "finish": return Step(id: Editing.freshId(body, base: "finish"), kind: .finish(""))
        case "data": return Step(id: Editing.freshId(body, base: "data"), kind: .data(DataStep(op: .lines, from: "")))
        case "form": return Step(id: Editing.freshId(body, base: "form"), kind: .form(FormStep(title: "", fields: [FormStep.Field(name: "answer", label: L("Your answer"), kind: .text)], hours: 24)))
        case "wait_for": return Step(id: Editing.freshId(body, base: "event"), kind: .waitFor(event: Trigger.events[0], contains: nil, minutes: 60))
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
            switch await app.engine.askingAI(String(prompt.prefix(7800)), label: L("Draft a flow")) {
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
