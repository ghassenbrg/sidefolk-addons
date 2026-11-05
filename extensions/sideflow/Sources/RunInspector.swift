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
        blocks.append(.facts(nil, facts))
        blocks.append(.note(record.summary))
        if let note = record.note { blocks.append(.note(note, tone: record.status == .failed || record.status == .unknown ? .warn : .neutral)) }
        if let input = record.input?.nonEmpty { blocks.append(.note(L("It was given: {what}", ["what": input.clipped(Engine.keptOutput)]))) }
        if let output = record.output?.nonEmpty { blocks.append(.note(L("It made: {what}", ["what": output.clipped(Engine.keptOutput)]))) }
        var out = [Section(Words.label(step, catalog: app.catalog), blocks, place: .trailing)]
        let called = app.store.runs().filter { $0.parent == run.id }
        if !called.isEmpty, [.call, .parallel].contains(where: { $0 == step.waitKind }) {
            out.append(Section(L("What it waited for"), called.map { child in
                .action(Action(child.flowName == run.flowName ? child.why : child.flowName, act: .go(Go(set: place(["run": child.id]), push: true)), symbol: statusSymbol(child), detail: Summaries.status(child)))
            }, place: .trailing))
        }
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
