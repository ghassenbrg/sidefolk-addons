import Foundation
import SidefolkExtensionKit

/// A run read closely: any step's input, what it made, its tries and why it ran, item by item in a loop; the runs it waited for; and a form it's waiting on. Everything here is
/// what the run wrote down at the time, on this Mac, in Sideflow's own folder.
@MainActor extension Pages {
    /// The form a run waits on, to fill in here. Each field is kept as it's typed, so a restart loses nothing.
    static func formSection(_ run: Run, _ app: App) -> Section? {
        guard let waiting = run.form, let step = run.body.step(waiting.step), case .form(let form) = step.kind else { return nil }
        var blocks: [Block] = []
        for field in form.fields {
            let input = ui("form_field", ["run": run.id, "name": field.name, "page_token": app.pageKey])
            let now = waiting.answers[field.name].map(Values.text) ?? ""
            let label = field.required ? field.label : L("{field} (optional)", ["field": field.label])
            switch field.kind {
            case .text: blocks.append(.edit(EditField("\(run.id).\(field.name)", label, value: now, kind: .multiline, tool: "ui", input: input)))
            case .number: blocks.append(.edit(EditField("\(run.id).\(field.name)", label, value: now, kind: .number, tool: "ui", input: input)))
            case .yes_no: blocks.append(.toggle(label, on: now == "true", tool: "ui", input: input))
            case .choice: blocks.append(.picker(label, style: .menu, field.options.map { Option($0, $0) }, selected: now, tool: "ui", input: input))
            }
        }
        blocks.append(.action(Action(L("Send"), tool: "ui", input: ui("form_send", ["run": run.id, "page_token": app.pageKey]), style: .primary, symbol: "paperplane")))
        let until = run.resumeAt.map { L("It waits until {time}.", ["time": Format.dateTime($0)]) }
        return Section(run.values.fill(form.title).clipped(Engine.longestFormTitle).nonEmpty ?? L("A form for you"), blocks, place: .trailing, detail: until)
    }

    /// What's selected on a run's tree: what it was given, what it made, how many tries, and why this and not another.
    static func stepDetail(_ whole: Run, step id: String, scope: String?, _ app: App) -> [Section] {
        let run = withLanes(whole, app)
        guard let step = run.body.step(id) else { return [] }
        let all = run.records.filter { $0.step == id }
        guard !all.isEmpty else {
            return [Section(Words.label(step, catalog: app.catalog), [.note(L("It didn't get this far in this run, or the path it's on wasn't taken."))], place: .trailing)]
        }
        let record = all.first { $0.scope == scope } ?? all.last!
        var blocks: [Block] = []
        if all.count > 1 {
            let options = all.compactMap { r in r.scope.map { ($0, L("Item {place} · {status}", ["place": $0, "status": recordWord(r)])) } }
            // A menu holds so many: the rest are still in the run's story, and saying so beats a list that looks whole.
            if options.count > 24 { blocks.append(.note(L("Only the first {count} goes can be picked here.", ["count": Format.integer(24)]))) }
            if !options.isEmpty { blocks.append(.picker(L("Which go"), style: .menu, options.map { Option($0.0, $0.1) }, selected: record.scope ?? "", tool: "ui", input: ui("inspect_scope", ["run": run.id, "step": id]))) }
        }
        var facts: [(String, String)] = [(L("How it went"), recordWord(record)), (L("When"), Format.dateTime(record.at))]
        if record.attempt > 1 { facts.append((L("Tries"), Format.integer(record.attempt))) }
        if let took = record.took, took >= 1 { facts.append((L("Took"), Format.duration(took))) }
        blocks.append(.facts(nil, facts))
        blocks.append(.note(record.summary))
        if let note = record.note { blocks.append(.note(note, tone: record.status == .failed || record.status == .unknown ? .warn : .neutral)) }
        // Whole, in its own sections: a note is cut at 400 characters, and a long notice has to be readable after the run.
        var whole: [Section] = []
        // Each field in a section of its own, so a long one can't push another out; where it goes first.
        let fields = record.input?.nonEmpty.map(Self.given) ?? []
        for (at, field) in fields.prefix(Self.mostFields).enumerated() { whole.append(Section(at == 0 ? L("It was given") : nil, field.map { .note($0) }, place: .trailing)) }
        var also: [Block] = []
        if fields.count > Self.mostFields { also.append(.note(L(one: "And {count} more field, not shown.", other: "And {count} more fields, not shown.", count: fields.count - Self.mostFields))) }
        if record.inputCut { also.append(.note(L("Some words of this step were not kept; the places it used are shown."), tone: .neutral)) }
        if !also.isEmpty { whole.append(Section(fields.isEmpty ? L("It was given") : nil, also, place: .trailing)) }
        if let output = record.output?.nonEmpty { whole.append(Section(L("It made"), Self.notes(L("Answer"), output).map { .note($0) }, place: .trailing)) }
        // A file it made or used, by its place: one press shows it in Finder, through Sidefolk, which checks the folder is one shared with it.
        for file in Self.files(in: run.values.named[id]).prefix(3) {
            blocks.append(.action(button(FlowFile.short((file as NSString).lastPathComponent, 40), "reveal", ["path": file], style: .plain, symbol: "doc", detail: L("Show in Finder"))))
        }
        var out = [Section(Words.label(step, catalog: app.catalog), blocks, place: .trailing)] + whole
        let called = app.store.runs().filter { $0.parent == run.id }
        if !called.isEmpty, [.call, .parallel].contains(where: { $0 == step.waitKind }) {
            out.append(Section(L("What it waited for"), called.map { child in
                .action(Action(child.flowName == run.flowName ? child.why : child.flowName, act: .go(Go(set: place(["run": child.id]), push: true)), symbol: statusSymbol(child), detail: Summaries.status(child)))
            }, place: .trailing))
        }
        return out
    }

    /// What a practice can go by: choosing one, and each thing it holds to change, so a practice can go down another way.
    static func examples(_ flow: Flow, _ app: App) -> Section? {
        guard !flow.examples.isEmpty else { return nil }
        var blocks: [Block] = [.picker(L("A practice goes by"), style: .menu, [Option("", L("Nothing kept: reads for real"))] + flow.examples.map { Option($0.id, $0.name) }, selected: flow.chosenExample ?? "", tool: "ui", input: ui("choose_example", ["flow": flow.id]))]
        if let chosen = flow.examples.first(where: { $0.id == flow.chosenExample }) {
            blocks.append(.edit(EditField("example.\(chosen.id).name", L("Its name"), value: chosen.name, tool: "ui", input: ui("name_example", ["flow": flow.id, "example": chosen.id]))))
            for step in flow.draft.allSteps {
                guard let value = chosen.values[step.id], blocks.count < 20 else { continue }
                let words: String = if case .string(let plain) = value { plain } else { Values.text(value) }
                blocks.append(.edit(EditField("example.\(chosen.id).\(step.id)", String(Words.label(step, catalog: app.catalog).prefix(40)), value: words, kind: .multiline, tool: "ui", input: ui("example_value", ["flow": flow.id, "example": chosen.id, "step": step.id]))))
            }
            let left = chosen.values.keys.filter { flow.draft.step($0) == nil }.count
            if left > 0 { blocks.append(.note(L(one: "It holds {count} step this flow no longer has.", other: "It holds {count} steps this flow no longer has.", count: left))) }
            blocks.append(.action(button(L("Delete this example"), "drop_example", ["flow": flow.id, "example": chosen.id], style: .plain, symbol: "trash")))
        }
        blocks.append(.note(L("It stays on this Mac, in this flow. It doesn't go in a copy or a file.")))
        return Section(L("Practice examples"), blocks, place: .trailing, collapsed: flow.chosenExample == nil)
    }

    /// What a step was given, field by field: a notice's title and message read as words, not as the JSON it was sent as. The names are the step's own fields.
    /// Field by field, each its notes: where it goes first (Sidefolk's place words), then the rest by name.
    static func given(_ raw: String) -> [[String]] {
        guard let fields = JSONText.read(raw) as? [String: Any] else { return [notes(L("Input"), raw)] }
        let keys = fields.keys.sorted { (FieldNames.isPlace($0) ? 0 : 1, $0) < (FieldNames.isPlace($1) ? 0 : 1, $1) }
        return keys.map { key in notes(key.replacingOccurrences(of: "_", with: " ").capitalizedFirst, (fields[key] as? String) ?? fields[key].map { JSONText.write($0) } ?? "") }
    }

    /// A section holds 24 blocks; one is kept for saying there's more.
    static let mostNotes = 23
    static let mostFields = 8

    /// One field's words in notes a page holds whole, broken between words. Each starts with Sideflow's own words, the field's name or "…", never with the field's,
    /// and the words are one line with nothing hidden: a message can't make a note that reads as another field, or as Sidefolk.
    static func notes(_ name: String, _ text: String, size: Int = 360) -> [String] {
        var out: [String] = [], rest = Substring(plain(text))
        while !rest.isEmpty, out.count < mostNotes {
            var piece = rest
            if rest.count > size {
                let cut = rest.index(rest.startIndex, offsetBy: size)
                piece = rest[..<(rest[..<cut].lastIndex(of: " ").map { rest.index(after: $0) } ?? cut)]
            }
            rest = rest[piece.endIndex...]
            let words = piece.trimmingCharacters(in: .whitespaces)
            guard !words.isEmpty else { continue }
            out.append(out.isEmpty ? "\(name): \(words)" : "… \(words)")
        }
        if !rest.trimmingCharacters(in: .whitespaces).isEmpty {
            out.append(L(one: "… and about {count} more part, not shown.", other: "… and about {count} more parts, not shown.", count: (rest.count + size - 1) / size))
        }
        return out
    }

    /// Words with nothing hidden in them and on one line: what turns text round or hides it goes, and line breaks become spaces.
    static func plain(_ text: String) -> String {
        let kept = text.unicodeScalars.map { scalar -> String in
            if scalar.properties.generalCategory == .format || scalar.properties.isDefaultIgnorableCodePoint { return "" }
            return CharacterSet.newlines.contains(scalar) || scalar.properties.generalCategory == .control ? " " : String(scalar)
        }.joined()
        return kept.split(separator: " ", omittingEmptySubsequences: true).joined(separator: " ")
    }

    /// A run in a few cards, for where it was asked about: how far it got, the step that's working or went wrong, and how much is left. The run's page has the rest.
    static func compact(_ run: Run, _ app: App) -> CardTree {
        let shown = withLanes(run, app)
        let steps = shown.body.allSteps
        let done = steps.filter { step in shown.record(of: step.id).map { [.done, .would, .skipped].contains($0.status) } == true }.count
        var nodes = [CardTree.Node("start", FlowFile.short(run.flowName, 60), kind: Summaries.status(run), symbol: statusSymbol(run), color: tile[0], state: run.status.isOver ? .done : .active)]
        if done > 0 { nodes.append(CardTree.Node("done", L(one: "{count} step done", other: "{count} steps done", count: done), symbol: "checkmark", state: .done)) }
        // The one that matters now: the step it's on, or the one that stopped it.
        if let here = shown.records.last(where: { [.running, .waiting, .needs_you, .failed, .unknown].contains($0.status) }), let step = shown.body.step(here.step) {
            var node = CardTree.Node(here.step, FlowFile.short(here.summary, 120), kind: FlowFile.short(Words.label(step, catalog: app.catalog), 30), symbol: look(step, app).symbol, color: look(step, app).color, state: .attention)
            (node.state, node.pill) = result(here)
            nodes.append(node)
        }
        let left = max(0, steps.count - done - (nodes.count > 2 ? 1 : 0))
        if left > 0, !run.status.isOver { nodes.append(CardTree.Node("left", L(one: "{count} step to go", other: "{count} steps to go", count: left), symbol: "ellipsis", state: .pending)) }
        return CardTree(nodes, line: line)
    }

    /// When it ran, how long for and what it used, counting the runs it waited for: lanes and called flows use the same AI and do things too.
    static func runFacts(_ run: Run, _ app: App) -> Section {
        var runs = [run], next = [run.id]
        while let id = next.popLast() {
            let children = app.store.runs().filter { $0.parent == id }
            runs += children
            next += children.map(\.id)
        }
        let requests = runs.reduce(0) { $0 + $1.aiRequests }, actions = runs.reduce(0) { $0 + $1.actionsDone }
        var facts = [(L("Started"), Format.dateTime(run.startedAt))]
        facts.append((run.endedAt == nil ? L("So far") : L("Took"), Format.duration((run.endedAt ?? Date()).timeIntervalSince(run.startedAt))))
        if let version = run.version { facts.append((L("Version"), Format.integer(version))) }
        facts.append((L("AI requests"), Format.integer(requests)))
        facts.append((L("Actions done"), Format.integer(actions)))
        return Section(L("About this run"), [.facts(nil, facts)], place: .trailing, collapsed: true)
    }

    /// The files a value names, by the fields that say where a file is: `path`, `file`, `files`, `output`, and the like. Only a whole place from the top of the disk or the home folder.
    static func files(in value: JSON?) -> [String] {
        guard let value else { return [] }
        var out: [String] = []
        func look(_ v: JSON, key: String?) {
            switch v {
            case .string(let s):
                guard let key, key.range(of: #"(?i)^(path|paths|file|files|output|outputs|saved|made)$"#, options: .regularExpression) != nil else { return }
                let place = s.trimmed
                if (place.hasPrefix("/") || place.hasPrefix("~/")), !place.contains("\n"), place.count < 1024, !out.contains(place) { out.append(place) }
            case .array(let items): for item in items.prefix(20) { look(item, key: key) }
            case .object(let fields): for (k, item) in fields { look(item, key: k) }
            default: break
            }
        }
        look(Values.structured(value), key: nil)
        return out
    }

    static func recordWord(_ r: Run.Record) -> String {
        switch r.status {
        case .running: L("Under way")
        case .done: L("Done")
        case .would: L("Would have run")
        case .failed: L("Failed")
        case .skipped: L("Skipped")
        case .needs_you: L("Needs you")
        case .waiting: L("Waiting")
        case .unknown: L("May or may not have happened")
        }
    }

    /// Which ways through have been seen working in practice, of what's written now: a run takes one way, so the others are still untried.
    /// A parallel's lanes keep their records in runs of their own: what ran there ran here, as far as anyone reading this run goes.
    static func withLanes(_ run: Run, _ app: App) -> Run {
        let lanes = app.store.runs(of: run.flow).filter { $0.parent == run.id }.sorted { $0.startedAt < $1.startedAt }
        guard !lanes.isEmpty else { return run }
        var shown = run
        shown.records += lanes.flatMap { withLanes($0, app).records }
        return shown
    }

    static func untried(_ flow: Flow, _ app: App) -> [String] {
        let practiced = app.store.runs(of: flow.id).filter { $0.mode == .practice && $0.body == flow.draft }
        guard !practiced.isEmpty else { return [] }
        let seen = Set(practiced.flatMap { withLanes($0, app).records.map(\.step) })
        var out: [String] = []
        for step in flow.draft.allSteps where !step.parts.isEmpty {
            guard seen.contains(step.id) else { continue }
            for part in step.parts where !part.steps.isEmpty && !part.steps.contains(where: { seen.contains($0.id) }) && part.id != "always" {
                out.append(L("“{way}” of “{step}”", ["way": partLabel(part.id, of: step), "step": Words.label(step, catalog: app.catalog)]))
            }
        }
        return out
    }

    /// Earlier versions of what went live, newest first: any can come back as a draft to read and save.
    static func versions(_ flow: Flow, _ app: App) -> Section? {
        guard !flow.revisions.isEmpty else { return nil }
        let rows: [Block] = flow.revisions.reversed().prefix(10).enumerated().map { at, revision in
            let index = flow.revisions.count - 1 - at
            let changes = flow.live.map { Editing.changes(from: $0, to: revision.body, catalog: app.catalog).count } ?? 0
            return .action(button(Format.dateTime(revision.at), "bring_back", ["flow": flow.id, "revision": index], style: .plain, symbol: "clock.arrow.circlepath",
                                  detail: changes == 0 ? L("The same as what's running") : L(one: "{count} difference from what's running. Comes back as unsaved changes.", other: "{count} differences from what's running. Comes back as unsaved changes.", count: changes)))
        }
        return Section(L("Earlier versions"), rows, place: .trailing, collapsed: true)
    }
}

extension Step {
    /// A step that waits for other runs, by what kind of waiting.
    enum WaitKind { case call, parallel }

    var waitKind: WaitKind? {
        switch kind {
        case .call: .call
        case .parallel: .parallel
        default: nil
        }
    }
}
