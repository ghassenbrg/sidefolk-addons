import Foundation
import SidefolkExtensionKit

/// What the companion, a connected agent and a typed sentence can do. The same saved flows as the page's, through the same engine. Writing a
/// draft changes nothing anywhere; the card when it is started is what lets anything happen.
@MainActor enum FlowTools {
    static func register(_ ext: Extension, _ app: App) {
        let flowParam = Schema.string("The flow's name or id.")
        let definition: [String: Any] = ["type": "object", "description": "The flow: {\"trigger\": …, \"steps\": […]}, as flow_guide says."]

        ext.tool("flow_guide", "How to write a flow", "How a flow is written, with every kind of step. Read this before create_flow or update_flow.") { _ in Grammar.text }

        ext.tool("list_actions", "What flows can use", "The tools a flow's steps can use, each with its values. Optionally narrowed by words.",
                 input: Schema.object(["search": Schema.string("Words to look for.", maxLength: 80)])) { args in
            await app.catalog.refresh()
            let words = args.string("search")?.lowercased()
            let tools = app.catalog.tools.filter { t in words.map { (t.title + " " + t.name + " " + t.description).lowercased().contains($0) } ?? true }
            guard !tools.isEmpty else { return L("Nothing matches. Sideflow can use Sidefolk's tools and other extensions' tools when they're on.") }
            return tools.prefix(60).map { t in
                let values = t.parameters.map { "\($0.name)\($0.required ? "*" : "")" }.joined(separator: ", ")
                return "\(t.name): \(t.title)\(t.readsOnly ? " (only reads)" : "")\(values.isEmpty ? "" : " (\(values))")\(t.outputFields.isEmpty ? "" : " gives: \(t.outputFields.joined(separator: ", "))")"
            }.joined(separator: "\n")
        }

        ext.tool("list_templates", "Flows to start from", "The templates create_flow can start from.") { _ in
            Templates.all.map { "\($0.id): \($0.name). \($0.line)" }.joined(separator: "\n")
        }

        ext.tool("list_flows", "List flows", "Every flow: its state, when it runs and how it last went.") { _ in
            let flows = app.store.flows()
            guard !flows.isEmpty else { return L("You have no flows yet.") }
            return flows.map { Summaries.line($0, app) }.joined(separator: "\n")
        }

        ext.tool("get_flow", "Read a flow", "A flow in full: its definition as JSON, in words, what's wrong with it, and what the person allowed.",
                 input: Schema.object(["flow": flowParam], required: ["flow"])) { args in
            let flow = try app.flow(named: try args.required("flow"))
            var out: [String: Any] = ["name": flow.name, "id": flow.id, "state": flow.state.rawValue, "definition": FlowCodec.json(flow.draft), "in_words": Words.aloud(flow.draft, catalog: app.catalog)]
            out["based_on"] = AgentEdits.fingerprint(flow.draft)
            if flow.hasChanges { out["running_now"] = FlowCodec.json(flow.running) }
            if flow.live != nil { out["version"] = flow.version }
            if !flow.revisions.isEmpty { out["versions"] = flow.revisions.map(\.version) }
            let problems = flow.draft.problems(app.catalog).map(\.text)
            if !problems.isEmpty { out["problems"] = problems }
            let fromWords = flow.draft.readsNumbersFromWords(app.catalog)
            if !fromWords.isEmpty { out["reads_numbers_from_words"] = fromWords.sorted() }
            // What reaches a model stops at 20 KB, and half a definition is worse than none: the words go first, then it's kept compact.
            if JSONText.write(out).utf8.count > 18_000 { out["in_words"] = nil }
            return JSONText.write(out)
        }

        ext.tool("create_flow", "Make a flow", "Saves a new flow as a draft, from a definition or a template. Nothing runs. With start, it then asks the person, on a card showing what it will do, to turn it on.",
                 input: Schema.object(["name": Schema.string("What to call it.", maxLength: 60), "definition": definition, "template": Schema.string("A template's id instead of a definition.", maxLength: 40),
                                       "start": Schema.boolean("Ask the person to turn it on now.")], required: ["name"]),
                 reply: { args in
            let name = try args.required("name")
            let body: FlowBody
            if let id = args.string("template") {
                guard let t = Templates.template(id) else { throw Problem(L("There's no template “{id}”.", ["id": id])) }
                body = try FlowCodec.body(t.body)
            } else {
                body = try FlowCodec.body(args.values["definition"] ?? ["steps": [Any]()])
            }
            let flow = app.newFlow(name: name, body: body)
            if app.store.flowsNotSaved { throw Problem(L("Your flows couldn't be saved to disk. Changes you've made may be lost when Sidefolk quits.")) }
            app.refreshPreflight(flow.id)
            let problems = body.problems(app.catalog).map(\.text)
            if args.bool("start") == true, problems.isEmpty {
                if let refused = await asking(flow.id, app) {
                    return ToolReply(L("Saved “{name}” as a draft. {why}", ["name": flow.name, "why": refused])).opening(page: "flows", state: Nav.open(flow: flow.id), push: true)
                }
                return ToolReply(Engine.needsCard(body) ? L("Saved “{name}”, and there's a card asking you to turn it on: {words}", ["name": flow.name, "words": Words.aloud(body, catalog: app.catalog)])
                                 : L("Saved “{name}” and turned it on: {words}", ["name": flow.name, "words": Words.aloud(body, catalog: app.catalog)])).opening(page: "flows", state: Nav.open(flow: flow.id), push: true)
            }
            var text = L("Saved “{name}” as a draft. Nothing runs until you turn it on. {words}", ["name": flow.name, "words": Words.aloud(body, catalog: app.catalog)])
            if !problems.isEmpty { text += "\n" + L("To fix first: {list}", ["list": problems.joined(separator: " ")]) }
            return ToolReply(text).showing(tree: Pages.mini(body, pending: true, app)).opening(page: "flows", state: Nav.open(flow: flow.id), push: true)
        })

        ext.tool("update_flow", "Change a flow", "Changes a flow's draft by a list of edits (patch) or a whole new definition, or its name, and says what changed. Pass based_on from get_flow, so a draft someone else changed since isn't written over. An On flow keeps running as it was until the person applies the change on a card.",
                 input: Schema.object(["flow": flowParam, "definition": definition, "name": Schema.string("A new name.", maxLength: 60),
                                       "patch": Schema.array(of: ["type": "object", "description": "{\"op\": \"add\", \"after\": \"start\" or a step's id or \"then:<id>\", \"step\": …}, {\"op\": \"remove\", \"id\": …}, {\"op\": \"replace\", \"id\": …, \"step\": …}, {\"op\": \"move\", \"id\": …, \"after\": …}."], "Edits, applied in order: all of them or none.", maxItems: 64),
                                       "based_on": Schema.string("The based_on get_flow gave.", maxLength: 40)], required: ["flow"])) { args in
            var flow = try app.flow(named: try args.required("flow"))
            // Someone's in the middle of it on the page: their changes aren't to be written over.
            guard !flow.hasUnsaved else { throw Problem(L("This flow has unsaved changes on its page. Ask the person to save or discard them first.")) }
            if let read = args.string("based_on"), read != AgentEdits.fingerprint(flow.draft) { throw Problem(L("This flow changed since you read it. Read it again with get_flow, and work from that.")) }
            let before = flow.draft
            if args.values["definition"] != nil, args.values["patch"] != nil { throw Problem(L("Send a patch or a definition, not both.")) }
            if let raw = args.values["definition"] { flow.draft = try FlowCodec.body(raw) }
            if let patch = args.values["patch"] as? [[String: Any]] { flow.draft = try AgentEdits.apply(patch, to: flow.draft) }
            if let name = args.string("name") {
                try app.rename(&flow, to: name)
            }
            app.store.save(flow)
            app.saved(byAnAgent: flow.id)
            if app.store.flowsNotSaved { throw Problem(L("Your flows couldn't be saved to disk. Changes you've made may be lost when Sidefolk quits.")) }
            app.refreshPreflight(flow.id)
            let changes = Editing.changes(from: before, to: flow.draft, catalog: app.catalog)
            app.agentEdits[flow.id] = before == flow.draft ? nil : AgentEdit(before: before, after: flow.draft, changes: changes)
            let problems = flow.draft.problems(app.catalog).map(\.text)
            var text = flow.state == .draft ? L("Changed the draft.") : L("Changed. It keeps running as before until you apply this.")
            if !changes.isEmpty { text += "\n" + changes.map { "- \($0)" }.joined(separator: "\n") }
            text += "\nbased_on: \(AgentEdits.fingerprint(flow.draft))"
            if !problems.isEmpty { text += "\n" + L("To fix first: {list}", ["list": problems.joined(separator: " ")]) }
            if !flow.draft.readsNumbersFromWords(app.catalog).isEmpty { text += "\n" + L("Some steps read a number from words, and stop if they aren't plainly one number. Each one's form says what to do.") }
            return text
        }

        ext.tool("practice_flow", "Practice a flow", "Runs a flow's draft for practice: what only reads runs for real (asking the person once), nothing is changed, and each other step says what it would do. The result is in get_run.",
                 input: Schema.object(["flow": flowParam], required: ["flow"]), reply: { args in
            let flow = try app.flow(named: try args.required("flow"))
            let problems = flow.draft.problems(app.catalog).map(\.text)
            guard problems.isEmpty else { throw Problem(L("To fix first: {list}", ["list": problems.joined(separator: " ")])) }
            app.engine.practice(flow)
            return ToolReply(L("Practicing “{name}”. Nothing will be changed.", ["name": flow.name])).opening(page: "flows", state: Nav.open(flow: flow.id), push: true)
        })

        ext.tool("start_flow", "Turn a flow on", "Asks the person, on a card, to let a flow run by itself as it's written now. It's on only once they say yes; say that a card is waiting.",
                 input: Schema.object(["flow": flowParam], required: ["flow"]), reply: { args in
            let flow = try app.flow(named: try args.required("flow"))
            let problems = flow.kept.problems(app.catalog).map(\.text)
            guard problems.isEmpty else { throw Problem(L("To fix first: {list}", ["list": problems.joined(separator: " ")])) }
            if let refused = await asking(flow.id, app) { throw Problem(refused) }
            return ToolReply(Engine.needsCard(flow.kept) ? L("There's a card asking to turn on “{name}”. It starts once you say yes.", ["name": flow.name]) : L("“{name}” is on.", ["name": flow.name])).opening(page: "flows", state: Nav.open(flow: flow.id), push: true)
        })

        ext.tool("pause_flow", "Pause a flow", "Stops a flow running by itself until it's resumed. Runs under way finish.", input: Schema.object(["flow": flowParam], required: ["flow"])) { args in
            let flow = try app.flow(named: try args.required("flow"))
            app.engine.pause(flow.id)
            return L("Paused “{name}”.", ["name": flow.name])
        }

        ext.tool("resume_flow", "Resume a flow", "Lets a paused flow run by itself again. If it changed since, this asks on a card.", input: Schema.object(["flow": flowParam], required: ["flow"])) { args in
            try await resuming(try app.flow(named: try args.required("flow")), app)
        }

        ext.tool("run_flow", "Run a flow now", "Runs a flow once, now, as last saved. What the person already allowed asks nothing; anything new shows them one card first, and only their own click can answer it, so this can come back saying it wasn't asked. Returns once it has started: the result is in get_run.",
                 input: Schema.object(["flow": flowParam, "input": Schema.string("Words for this run, if the person gave any: its steps read them as {{trigger}}.")], required: ["flow"])) { args in
            let flow = try app.flow(named: try args.required("flow"))
            // Paused is the person's word. Going on from it is theirs too.
            guard flow.state != .paused else { throw Problem(L("“{name}” is paused. Ask the person to resume it first.", ["name": flow.name])) }
            if app.store.flowsFileIsHeld { throw Problem(L("Your flows file can't be opened. It's untouched, and nothing runs or saves until it can be and Sidefolk starts again.")) }
            let problems = flow.kept.problems(app.catalog).map(\.text)
            guard problems.isEmpty else { throw Problem(L("To fix first: {list}", ["list": problems.joined(separator: " ")])) }
            guard let started = await app.engine.runNow(flow.id, why: L("You asked for it."), trigger: args.string("input")) else {
                // Saying no, or starting it being what paused it, says so on the flow.
                let now = app.store.flow(flow.id)
                if let why = now?.startProblem ?? now?.pausedBecause { throw Problem(why) }
                return L("“{name}” is already running.", ["name": flow.name])
            }
            if started.status.isOver, let why = started.problem { throw Problem(why) }
            return L("Running “{name}”.", ["name": flow.name])
        }

        ext.tool("list_runs", "List runs", "A flow's recent runs, or all flows', newest first.", input: Schema.object(["flow": Schema.string("The flow's name or id.")])) { args in
            let flow = try args.string("flow").map { try app.flow(named: $0) }
            let runs = app.store.runs(of: flow?.id).prefix(20)
            guard !runs.isEmpty else { return L("No runs yet.") }
            return runs.map { Summaries.line($0) }.joined(separator: "\n")
        }

        ext.tool("get_run", "Read a run", "What a run did, step by step, why it stopped and what can be done next. By run id, or a flow's latest.",
                 input: Schema.object(["run": Schema.string("The run's id."), "flow": Schema.string("A flow's name or id, for its latest run.")])) { args in
            let run: Run?
            if let id = args.string("run") { run = app.store.run(id) } else if let name = args.string("flow") { run = app.store.latest(of: try app.flow(named: name).id) } else { run = app.store.runs().first }
            guard let run else { return L("No runs yet.") }
            return Summaries.story(run)
        }

        ext.tool("continue_run", "Carry on with a run", "A stopped run's way forward: try_again runs its step again, carry_on skips it and goes on, stop ends the run. Only the person knows whether a step that was interrupted happened: ask them.",
                 input: Schema.object(["run": Schema.string("The run's id."), "how": Schema.string("What to do.", oneOf: ["try_again", "carry_on", "stop"])], required: ["run", "how"])) { args in
            guard let run = app.store.run(try args.required("run")), !run.status.isOver else { throw Problem(L("That run has already ended.")) }
            guard let how = Engine.Forward(rawValue: try args.required("how")) else { throw Problem(L("That isn't a way forward.")) }
            // A form or another run it's waiting for isn't a stop to go past: only the person's answer moves a form on.
            guard run.status == .needs_you || run.status == .interrupted || how == .stop else { throw Problem(L("That run isn't stopped: it's waiting for something.")) }
            if how != .stop, app.store.isHeldBack(flow: run.flow) { throw Problem(L("Its flow can't be read now, so this can't go on yet. It goes on if the flow comes back.")) }
            app.engine.proceed(run.id, how)
            return L("Done. See how it goes with get_run.")
        }

        ext.tool("delete_flow", "Delete a flow", "Deletes a flow, its runs and what the person allowed for it. This can't be undone.", input: Schema.object(["flow": flowParam], required: ["flow"])) { args in
            let flow = try app.flow(named: try args.required("flow"))
            app.engine.delete(flow.id)
            return L("Deleted “{name}”.", ["name": flow.name])
        }

        ext.tool("ui", "Open Sideflow", "The page's own clicks.", input: ["type": "object"], reply: { args in
            // A sentence opens the page; a click that makes or removes a flow moves it; the rest are already there.
            guard args.string("op") != nil else { return ToolReply(L("Sideflow is open in Home.")).opening(page: "flows") }
            switch try await Actions_UI.handle(args, app) {
            case .stay: return ToolReply("").row(L("Changed something in Sideflow"))
            case .flow(let id): return ToolReply("").opening(page: "flows", state: Nav.open(flow: id), push: true)
            // The builder's side panel of the same flow: another tab goes back to it, and it isn't a step to come back from.
            case .panel(let id): return ToolReply("").opening(page: "flows", state: ["flow": id, "run": NSNull(), "tab": NSNull()])
            case .run(let id): return ToolReply("").opening(page: "flows", state: ["run": id], push: true)
            case .home: return ToolReply("").opening(page: "flows", state: ["flow": NSNull(), "run": NSNull()])
            }
        })
    }
}

/// `resume_flow`'s reply: it only says it's running when it is.
@MainActor func resuming(_ flow: Flow, _ app: App) async throws -> String {
    guard flow.hasChanges || flow.live == nil || app.engine.nobodyRead(flow) else {
        app.engine.resume(flow.id)
        // A problem on one still On is what stops it next time it runs: "running again" wouldn't be true for long.
        func stopped() -> String? {
            let now = app.store.flow(flow.id)
            return now?.state != .on || now?.startProblem != nil ? now?.startProblem ?? L("It didn't start.") : nil
        }
        var problem = stopped()
        // A watch answers a moment later, and its answer can be what stops it: this flow's now, or an old one that wouldn't stop.
        var watches = flow.watchTitle != nil
        if case .watch = flow.running.trigger { watches = true }
        if watches {
            for _ in 0..<8 where problem == nil {
                try? await Task.sleep(for: .milliseconds(100))
                problem = stopped()
            }
        }
        if let problem { throw Problem(problem) }
        return L("“{name}” is running by itself again.", ["name": flow.name])
    }
    if let refused = await asking(flow.id, app) { throw Problem(refused) }
    return Engine.needsCard(flow.kept) ? L("There's a card asking to turn on “{name}”.", ["name": flow.name]) : L("“{name}” is on.", ["name": flow.name])
}

/// Asks for the card and looks for a moment: Sidefolk refuses at once when no card can be shown (another agent asked, not the person), and a reply
/// must not say there's a card when there isn't. A card that's up waits for the person, past this call.
@MainActor private func asking(_ id: String, _ app: App) async -> String? {
    app.engine.turnOn(id)
    for _ in 0..<8 {
        try? await Task.sleep(for: .milliseconds(100))
        if let problem = app.store.flow(id)?.startProblem { return problem }
    }
    return nil
}

/// A flow and a run as text, for answers.
@MainActor enum Summaries {
    static func stateWord(_ flow: Flow) -> String {
        switch flow.state {
        case .draft: L("Draft")
        case .on: flow.hasChanges ? L("On, with changes not applied") : L("On")
        case .paused: L("Paused")
        }
    }

    static func line(_ flow: Flow, _ app: App) -> String {
        var parts = ["\(flow.name) [\(stateWord(flow))]", Words.triggers(flow.running)]
        if let next = next(flow) { parts.append(L("Next: {when}", ["when": Format.dateTime(next)])) }
        if let last = app.store.latest(of: flow.id) { parts.append(L("Last: {status}", ["status": status(last)])) }
        return parts.joined(separator: " · ")
    }

    static func next(_ flow: Flow) -> Date? {
        guard flow.state == .on else { return nil }
        // By the clock it goes by, as the engine's tick does: 08:30 in Paris isn't 08:30 here.
        var clock = Calendar.autoupdatingCurrent
        if let zone = flow.running.timeZone.flatMap(TimeZone.init(identifier:)) { clock.timeZone = zone }
        return flow.running.triggers.compactMap { trigger in flow.countsFrom(trigger).flatMap { Schedule.next(trigger, after: $0, calendar: clock) } }.min()
    }

    static func status(_ run: Run) -> String {
        switch run.status {
        case .running: L("Running")
        case .waiting: run.connection == nil ? L("Waiting") : L("Waiting for a connection")
        case .done: run.mode == .practice ? L("Practiced") : L("Done")
        case .failed: L("Failed")
        case .stopped: L("Stopped")
        case .needs_you: L("Needs you")
        case .interrupted: L("Interrupted")
        }
    }

    static func line(_ run: Run) -> String {
        "\(run.id.prefix(8)) \(run.flowName): \(status(run)) · \(Format.dateTime(run.startedAt)) · \(run.why)"
    }

    static func story(_ run: Run) -> String {
        var lines = ["\(run.flowName): \(status(run)), \(Format.dateTime(run.startedAt)). id \(run.id)", run.why]
        lines.append(L("Took {time}, with {requests} AI requests and {actions} actions done.", ["time": Format.duration((run.endedAt ?? Date()).timeIntervalSince(run.startedAt)), "requests": Format.integer(run.aiRequests), "actions": Format.integer(run.actionsDone)]))
        for r in run.records {
            lines.append("- \(r.status.rawValue): \(r.summary)" + (r.note.map { " (\($0))" } ?? ""))
            if let output = r.output?.nonEmpty { lines.append("  → " + String(output.prefix(600))) }
        }
        if let problem = run.problem { lines.append(problem) }
        if !run.status.isOver { lines.append(L("Ways forward: try_again, carry_on, stop.")) }
        return lines.joined(separator: "\n")
    }
}
