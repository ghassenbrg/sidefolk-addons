import Foundation
import SidefolkExtensionKit

/// Loops, tries, flows that call flows, lanes, forms and waits for something: what holds or waits for steps. `Engine` walks; this says what each does when the walk reaches it.
extension Engine {
    // MARK: Going round

    /// A list of things as they are, or lines of text if it's text: never guessed from words that look like a list.
    func startLoop(_ step: Step, end: Int, in run: inout Run) -> Bool {
        guard case .forEach(let items, let limit, let failure, let steps) = step.kind else { return true }
        if let wrong = step.saysNothing { return failed(step, why: wrong, reads: false, in: &run) }
        if let name = run.values.missing(in: [items]).first {
            return failed(step, why: L("It uses “{name}”, but that step didn't run this time.", ["name": name]), reads: false, in: &run)
        }
        let list: [JSON]
        switch Values.structured(run.values.fill(native: .string(items))) {
        case .array(let a): list = a
        case .string(let text): list = text.split(whereSeparator: \.isNewline).map { .string(String($0).trimmed) }.filter { $0 != .string("") }
        case let other: list = [other]
        }
        guard list.count <= limit else {
            return failed(step, why: L("It has {count} items, and this step goes through {limit} at most.", ["count": Format.integer(list.count), "limit": Format.integer(limit)]), reads: false, in: &run)
        }
        guard !list.isEmpty, !steps.isEmpty else {
            run.values.set(step.id, JSON.array([]))
            run.record(.init(step: step.id, status: .done, summary: L("Nothing to go through"), at: clock()))
            run.pc = end + 1
            store.save(run)
            return true
        }
        run.frames.append(Run.Frame(kind: .loop, step: step.id, items: list, collect: failure == .collect, top: run.pc + 1, end: end))
        setItem(in: &run)
        run.record(.init(step: step.id, status: .running, summary: L("Going through {count} items", ["count": Format.integer(list.count)]), at: clock(), scope: "0"))
        run.pc += 1
        store.save(run)
        changed()
        return true
    }

    func setItem(in run: inout Run) {
        guard let frame = run.frames.last(where: { $0.kind == .loop }), frame.items.indices.contains(frame.index) else {
            // Out of the last loop here. A lane inside a loop goes back to the item it started with.
            run.values.named["item"] = run.startItem
            run.values.named["index"] = run.startIndex
            return
        }
        run.values.set("item", frame.items[frame.index])
        run.values.set("index", JSON.number(Double(frame.index + 1)))
    }

    func nextInLoop(_ step: Step, in run: inout Run) {
        guard let at = run.frames.indices.last, run.frames[at].kind == .loop, case .forEach(_, _, _, let steps) = step.kind else {
            run.pc += 1
            return
        }
        let inside = FlowBody(steps: steps).allSteps
        // What this go gave: what the last step that makes something made. Steps inside start each go with nothing.
        let made = inside.last(where: { $0.hasOutput }).flatMap { run.values.named[$0.id] } ?? run.frames[at].items[run.frames[at].index]
        // Room is left for what the items still to come will say at the least, so the list as a whole is never cut to text.
        let left = run.frames[at].items.count - run.frames[at].index - 1
        let fits = JSONText.write((run.frames[at].results + [made]).map(\.any)).utf8.count + left * 40 <= Values.keepWhole
        run.frames[at].results.append(fits ? made : .string(L("(too long to keep)")))
        for s in inside { run.values.named[s.id] = nil }
        run.frames[at].index += 1
        let frame = run.frames[at]
        if frame.index < frame.items.count {
            run.pc = frame.top
            setItem(in: &run)
        } else {
            run.frames.removeLast()
            setItem(in: &run)
            run.values.set(step.id, JSON.array(frame.results))
            let summary = frame.failedItems == 0 ? L("Went through {count} items", ["count": Format.integer(frame.items.count)])
                : L("Went through {count} items; {failed} failed", ["count": Format.integer(frame.items.count), "failed": Format.integer(frame.failedItems)])
            run.records.removeAll { $0.step == step.id && $0.scope == "0" }
            var record = Run.Record(step: step.id, status: frame.failedItems == 0 ? .done : .failed, summary: summary, output: JSONText.write(JSON.array(frame.results).any).clipped(2000), at: clock())
            record.scope = run.scope
            run.record(record)
            run.pc += 1
        }
        store.save(run)
        changed()
    }

    /// A step failed with nothing of its own to do about it: the loops and tries it's inside have their say. False when none of them takes it.
    func unwind(_ why: String, in run: inout Run) -> Bool {
        while let at = run.frames.indices.last {
            let frame = run.frames[at]
            switch frame.kind {
            case .loop:
                if frame.collect {
                    run.frames[at].failedItems += 1
                    run.pc = frame.end
                    return true
                }
                run.frames.removeLast()
                setItem(in: &run)
            case .attempt:
                if frame.inAlways {
                    run.frames.removeLast()
                } else if !frame.inRecover, frame.recover != frame.always {
                    run.frames[at].inRecover = true
                    run.values.set("error", why)
                    run.pc = frame.recover
                    return true
                } else {
                    run.frames[at].inAlways = true
                    run.frames[at].failing = why
                    run.pc = frame.always
                    return true
                }
            }
        }
        return false
    }

    /// Ends the flow here, by way of the last steps of any try it's in.
    func ending(in run: inout Run, length: Int) {
        while let at = run.frames.indices.last {
            if run.frames[at].kind == .attempt, !run.frames[at].inAlways {
                run.frames[at].inAlways = true
                run.frames[at].returning = true
                run.pc = run.frames[at].always
                return
            }
            run.frames.removeLast()
        }
        setItem(in: &run)
        run.pc = length
    }

    // MARK: Runs that wait for runs

    /// Starts a run that this one waits for: another flow's, or a lane of its own.
    /// Made, not yet written: the run that waits for it goes on disk first.
    func startChild(of parent: Run, flow: String, flowName: String, body: FlowBody, mode: Run.Mode, why: String, values: Values) -> Run {
        var child = Run(id: UUID().uuidString.lowercased(), flow: flow, flowName: flowName, mode: mode, status: .running, why: why, startedAt: clock(), body: body)
        child.parent = parent.id
        child.lineage = parent.lineage + [parent.flow]
        child.values = values
        child.startItem = values.named["item"]
        child.startIndex = values.named["index"]
        startedHere.insert(child.id)
        return child
    }

    func calling(_ step: Step, flow name: String, inputs: [String: String], in run: inout Run) -> Bool {
        guard let other = store.named(name), other.id != run.flow, !run.lineage.contains(other.id) else {
            return failed(step, why: L("“{name}” can't be called from here: there's no other flow by that name, or it would end up calling itself.", ["name": name]), reads: false, in: &run)
        }
        guard run.lineage.count < Self.deepestCalls else {
            return failed(step, why: L("Flows calling flows went {count} deep, so it stopped here.", ["count": Format.integer(Self.deepestCalls)]), reads: false, in: &run)
        }
        let practicing = run.mode == .practice
        guard practicing || other.state == .on else {
            return failed(step, why: L("“{name}” isn't on, so it can't run by itself.", ["name": name]), reads: false, in: &run)
        }
        if !practicing, pauseIfBlank(other) {
            return failed(step, why: L("It has a step that says nothing, so it's paused until that's fixed."), reads: false, in: &run)
        }
        var values = Values()
        (values.today, values.now) = (run.values.today, run.values.now)
        values.set("input", JSON.object(inputs.mapValues { run.values.fill(native: .string($0)) }))
        let child = startChild(of: run, flow: other.id, flowName: other.name, body: practicing ? other.draft : other.running, mode: practicing ? .practice : run.mode == .once ? .once : .live, why: L("{flow} called it.", ["flow": run.flowName]), values: values)
        run.waitingOn = [child.id]
        run.status = .waiting
        run.record(.init(step: step.id, status: .waiting, summary: L("Waiting for {flow}", ["flow": other.name]), at: clock()))
        // This run first: stopped between the two, it finds what it waits for gone and says so. The other way round, it would start a second one.
        store.save(run)
        store.save(child)
        changed()
        Task { await advance(child.id) }
        return false
    }

    func lanes(_ step: Step, _ lanes: [Step.Lane], in run: inout Run) -> Bool {
        var started: [Run] = []
        for lane in lanes {
            var values = run.values
            values.named["item"] = run.values.named["item"]
            started.append(startChild(of: run, flow: run.flow, flowName: run.flowName, body: FlowBody(steps: lane.steps), mode: run.mode, why: lane.name, values: values))
        }
        run.waitingOn = started.map(\.id)
        run.status = .waiting
        run.record(.init(step: step.id, status: .waiting, summary: L("Doing {count} things at once", ["count": Format.integer(lanes.count)]), at: clock()))
        store.save(run)
        for child in started { store.save(child) }
        changed()
        for child in started { Task { await advance(child.id) } }
        return false
    }

    /// Back at a call or a parallel. Carries on when all it waits for are over; a child that needs the person leaves this waiting too.
    func joined(_ step: Step, in run: inout Run) -> Bool {
        let children = run.waitingOn.compactMap { store.run($0) }
        guard children.count == run.waitingOn.count else {
            run.waitingOn = []
            return failed(step, why: L("What it was waiting for is gone."), reads: false, in: &run)
        }
        guard children.allSatisfy({ $0.status.isOver }) else {
            run.status = .waiting
            store.save(run)
            return false
        }
        run.waitingOn = []
        if let bad = children.first(where: { $0.status != .done }) {
            return failed(step, why: bad.problem ?? L("{flow} didn't finish.", ["flow": bad.flowName]), reads: false, in: &run)
        }
        let result: JSON
        if case .parallel(let list) = step.kind {
            result = .object(Dictionary(zip(Self.keys(list), children).map { ($0, $1.answer) }, uniquingKeysWith: { a, _ in a }))
        } else {
            result = children[0].answer
        }
        run.values.set(step.id, result)
        run.record(.init(step: step.id, status: .done, summary: Words.step(step, body: run.body, catalog: catalog), output: Values.text(result).clipped(2000), at: clock()))
        run.pc += 1
        run.retries = 0
        store.save(run)
        return true
    }

    /// A lane's name as a value is reached by: `{{step.first_lane}}`.
    static func key(_ name: String) -> String {
        // In the letters a value's name can have, whatever language the lane is named in.
        let latin = name.applyingTransform(.toLatin, reverse: false)?.applyingTransform(.stripDiacritics, reverse: false) ?? name
        let clean = String(latin.lowercased().map { $0.isASCII && ($0.isLetter || $0.isNumber) ? $0 : "_" }).trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        return clean.isEmpty ? "lane" : String(clean.prefix(40))
    }

    /// Each lane's own: two whose names come out the same would otherwise leave one result behind.
    static func keys(_ lanes: [Step.Lane]) -> [String] {
        var used = Set<String>()
        return lanes.enumerated().map { at, lane in
            var key = key(lane.name), suffix = at + 1
            let plain = key
            while !used.insert(key).inserted {
                key = "\(plain.prefix(36))_\(suffix)"
                suffix += 1
            }
            return key
        }
    }

    static let deepestCalls = 6
    /// What a value filled into a form's title can come to: it's a heading, and the page has a limit.
    static let longestFormTitle = 200

    // MARK: Forms

    /// What the person answered, on the page. Once: a second press finds nothing waiting.
    func answer(run id: String, form answers: [String: JSON]) throws {
        if let held = store.run(id), store.isHeldBack(flow: held.flow) { throw Problem(L("Its flow can't be read now, so this can't go on yet. It goes on if the flow comes back.")) }
        guard var run = store.run(id), let waiting = run.form, run.status == .waiting,
              let step = run.body.step(waiting.step), case .form(let form) = step.kind else { throw Problem(L("That form has been answered already.")) }
        var kept: [String: JSON] = [:]
        for field in form.fields {
            let given = answers[field.name] ?? waiting.answers[field.name]
            let text = given.map(Values.text)?.trimmed ?? ""
            // A switch left alone is an answer: no.
            if text.isEmpty, field.kind == .yes_no {
                kept[field.name] = .bool(false)
                continue
            }
            if text.isEmpty {
                guard !field.required else { throw Problem(L("“{field}” needs an answer.", ["field": field.label])) }
                kept[field.name] = .null
                continue
            }
            switch field.kind {
            case .number:
                guard let n = Condition.number(text) else { throw Problem(L("“{field}” needs a number.", ["field": field.label])) }
                kept[field.name] = .number(n)
            case .yes_no: kept[field.name] = .bool(text == "true" || text == "on" || text == "yes")
            case .choice:
                guard field.options.contains(text) else { throw Problem(L("“{field}” is one of the choices.", ["field": field.label])) }
                kept[field.name] = .string(text)
            case .text: kept[field.name] = .string(text)
            }
        }
        run.form = nil
        run.resumeAt = nil
        run.values.set(step.id, JSON.object(kept))
        run.record(.init(step: step.id, status: .done, summary: run.values.fill(form.title).clipped(Self.longestFormTitle).nonEmpty ?? L("You answered"), output: JSONText.write(JSON.object(kept).any).clipped(Engine.keptOutput), at: clock()))
        run.pc += 1
        run.status = .running
        store.save(run)
        changed()
        Task { await advance(id) }
    }

    func waitingForm(_ step: Step, _ form: FormStep, in run: inout Run) -> Bool {
        if run.mode == .practice {
            let sample = Dictionary(form.fields.map { field -> (String, JSON) in
                switch field.kind {
                case .number: (field.name, .number(1))
                case .yes_no: (field.name, .bool(true))
                case .choice: (field.name, .string(field.options.first ?? ""))
                case .text: (field.name, .string(L("(sample)")))
                }
            }, uniquingKeysWith: { a, _ in a })
            run.values.set(step.id, JSON.object(sample))
            run.record(.init(step: step.id, status: .would, summary: L("Would ask you to fill in: {title}", ["title": run.values.fill(form.title).clipped(Self.longestFormTitle)]), at: clock()))
            run.pc += 1
            store.save(run)
            return true
        }
        if run.form != nil {
            // Back here with no answer: its time ran out.
            run.form = nil
            run.resumeAt = nil
            return failed(step, why: L("Nobody filled in “{title}” in time.", ["title": run.values.fill(form.title).clipped(Self.longestFormTitle)]), reads: false, in: &run)
        }
        run.form = Run.WaitingForm(step: step.id)
        run.resumeAt = clock().addingTimeInterval(Double(form.hours) * 3600)
        run.status = .waiting
        let filled = run.values.fill(form.title).clipped(Self.longestFormTitle)
        run.record(.init(step: step.id, status: .waiting, summary: L("Waiting for you to fill in: {title}", ["title": filled]), at: clock()))
        store.save(run)
        let (name, title) = (run.flowName, filled)
        Task { await host?.notify(title: L("{flow} needs you", ["flow": name]), body: title, attention: true) }
        return false
    }

    func waitingForEvent(_ step: Step, minutes: Int, in run: inout Run) -> Bool {
        if run.mode == .practice {
            run.values.set(step.id, L("(sample)"))
            run.record(.init(step: step.id, status: .would, summary: L("Would wait for this"), at: clock()))
            run.pc += 1
            store.save(run)
            return true
        }
        if run.resumeAt != nil {
            run.resumeAt = nil
            // Not one to try again: a retry's own wait would read as this wait having run out.
            return failed(step, why: L("It didn't happen in time."), reads: false, in: &run)
        }
        run.resumeAt = clock().addingTimeInterval(Double(minutes) * 60)
        run.status = .waiting
        run.record(.init(step: step.id, status: .waiting, summary: Words.step(step, body: run.body, catalog: catalog), at: clock()))
        store.save(run)
        return false
    }

    /// Runs waiting for this: each goes on once, because the next time it's no longer at this step.
    func wakeWaiting(name: String, words: String) {
        for var run in store.unfinished() where run.status == .waiting && run.resumeAt != nil && !store.isHeldBack(flow: run.flow) {
            let program = FlowProgram(run.body)
            guard run.pc < program.ops.count, case .step(let step) = program.ops[run.pc], case .waitFor(let event, let contains, _) = step.kind, event == name else { continue }
            if let contains, words.range(of: contains, options: [.caseInsensitive, .diacriticInsensitive]) == nil { continue }
            run.values.set(step.id, words)
            run.resumeAt = nil
            run.record(.init(step: step.id, status: .done, summary: Words.step(step, body: run.body, catalog: catalog), output: words, at: clock()))
            run.pc += 1
            run.status = .running
            store.save(run)
            let id = run.id
            Task { await advance(id) }
        }
    }
}
