import Foundation
import SidefolkExtensionKit

/// Loops, tries, flows that call flows, lanes, forms and waits for something: what holds or waits for steps. `Engine` walks; this says what each does when the walk reaches it.
extension Engine {
    // MARK: Going round

    /// A list of things as they are, or lines of text if it's text: never guessed from words that look like a list.
    func startLoop(_ step: Step, end: Int, in run: inout Run) -> Bool {
        if case .repeatUntil(_, let times, let steps) = step.kind { return startRepeat(step, times: times, steps: steps, end: end, in: &run) }
        guard case .forEach(let items, let limit, let failure, let steps) = step.kind else { return true }
        if let wrong = step.saysNothing { return failed(step, why: wrong, reads: false, in: &run) }
        if let name = run.values.stopsFor([items], practice: run.mode == .practice) {
            return failed(step, why: run.values.whyMissing(name), reads: false, in: &run)
        }
        var list: [JSON]
        switch Values.structured(run.values.fill(native: .string(items))) {
        case .array(let a): list = a
        case .string(let text): list = text.split(whereSeparator: \.isNewline).map { .string(String($0).trimmed) }.filter { $0 != .string("") }
        // A field saying nothing is a list of nothing: no item to send blank to a real action.
        case .null: list = []
        case let other: list = [other]
        }
        // Past the check, anything missing is a field of a sample: once round, since what it does each time is what a practice is for.
        if !run.values.missing(in: [items]).isEmpty { list = [.string(L("(sample)"))] }
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

    /// Going round until something holds. Its goes are numbers, so a restart comes back to the right one like any loop's. A practice run goes round
    /// once: what would end it hasn't happened, and what it does each go is what there is to see.
    private func startRepeat(_ step: Step, times: Int, steps: [Step], end: Int, in run: inout Run) -> Bool {
        guard !steps.isEmpty else {
            return failed(step, why: L("There's nothing inside it to repeat."), reads: false, in: &run)
        }
        let goes = run.mode == .practice ? 1 : times
        run.frames.append(Run.Frame(kind: .loop, step: step.id, items: (1...goes).map { .number(Double($0)) }, collect: false, top: run.pc + 1, end: end))
        setItem(in: &run)
        run.record(.init(step: step.id, status: .running, summary: L("Going round, {count} times at most", ["count": Format.integer(times)]), at: clock(), scope: "0"))
        run.pc += 1
        store.save(run)
        changed()
        return true
    }

    /// The end of a go: done if it holds now, with what this go's steps made still there to look at. False when it's run out of goes and that stops the run.
    func nextInRepeat(_ step: Step, until: Condition, in run: inout Run) -> Bool {
        guard let at = run.frames.indices.last, run.frames[at].kind == .loop, case .repeatUntil(_, let times, let steps) = step.kind else {
            run.pc += 1
            return true
        }
        let inside = FlowBody(steps: steps).allSteps
        // The last that made something: a path not taken at the end of a go made nothing.
        let made = run.values.lastAnswer(of: inside)
        let holds = until.holds(run.values)
        let go = run.frames[at].index + 1
        func leave() {
            for s in inside { run.values.named[s.id] = nil }
            run.frames.removeLast()
            setItem(in: &run)
            run.records.removeAll { $0.step == step.id && $0.scope == "0" }
        }
        if run.mode != .practice, let unknown = run.values.undecided(until) {
            leave()
            return failed(step, why: L("It looks at “{name}”, which is empty or isn't there this time, so it can't tell which way to go.", ["name": unknown]), reads: false, in: &run)
        }
        // What it can't see won't change by asking again. A go that only read is what a poll asks again, but one that did something would do it again, so one of its checks has
        // to be able to come out differently: something this go answered, or which go this is. Not an earlier value, a name gone with a loop inside, a misspelt one, or a blank.
        // Alone, a repeat's item is its go; inside a list it's the list's. Words a check doesn't compare with don't count, even if they're still written there.
        let body = run.body
        let inAList = run.frames.contains { frame in frame.kind == .loop && { if case .forEach? = body.step(frame.step)?.kind { true } else { false } }() }
        let answeredHere = Set(inside.map(\.id)).union(inAList || run.startItem != nil ? ["index"] : ["index", "item"])
        func looksAt(_ check: Condition) -> [(name: String, path: String)] { Values.slots(check.value) + (check.test == .is_empty || check.test == .not_empty ? [] : Values.slots(check.than)) }
        let canChange = until.checks.contains { check in
            looksAt(check).contains { slot in
                // A tool's `{{step}}` is its words, whatever fields came beside them.
                answeredHere.contains(slot.name) && (slot.path.isEmpty ? run.values.whole(slot.name) ?? run.values.resolve(slot.name) : run.values.resolve(slot.name, path: slot.path)).map { !Condition.isBlank(Values.text($0).trimmed) } == true
            }
        }
        if run.mode != .practice, !holds, run.frames[at].wrote, !canChange {
            let name = until.checks.flatMap(looksAt).first.map { $0.name + $0.path } ?? until.checks.first?.value ?? ""
            leave()
            return failed(step, why: L("“{name}” doesn't answer it yet, and going round would do this all again, so it stopped here.", ["name": name]), reads: false, in: &run)
        }
        if holds || run.mode == .practice {
            leave()
            // Nothing inside made anything: nothing for a later step to be sent as if it were an answer.
            if let made { run.values.set(step.id, made) }
            let summary = run.mode == .practice ? L("Went round once for practice; it would go on until this holds, {count} times at most", ["count": Format.integer(times)])
                : L(one: "It held after {count} time", other: "It held after {count} times", count: go)
            var record = Run.Record(step: step.id, status: run.mode == .practice ? .would : .done, summary: summary, output: made.map { Values.text($0).clipped(Self.keptOutput) }, at: clock())
            record.scope = run.scope
            run.record(record)
            run.pc += 1
            store.save(run)
            changed()
            return true
        }
        run.frames[at].index = go
        if go < run.frames[at].items.count {
            for s in inside { run.values.named[s.id] = nil }
            run.frames[at].wrote = false
            run.pc = run.frames[at].top
            setItem(in: &run)
            store.save(run)
            changed()
            return true
        }
        // Out of goes, and that's this step failing. Back at the start of it, because that's where carrying on goes past it from.
        let top = run.frames[at].top
        leave()
        run.pc = top - 1
        store.save(run)
        changed()
        return failed(step, why: L(one: "It went round {count} time and it still doesn't hold.", other: "It went round {count} times and it still doesn't hold.", count: go), reads: false, in: &run)
    }

    func setItem(in run: inout Run) {
        let loops = run.frames.filter { $0.kind == .loop }
        guard let frame = loops.last, frame.items.indices.contains(frame.index) else {
            // Out of the last loop here. A lane inside a loop goes back to the item it started with.
            run.values.named["item"] = run.startItem
            run.values.named["index"] = run.startIndex
            return
        }
        let body = run.body
        func goesRound(_ f: Run.Frame) -> Bool { if case .repeatUntil? = body.step(f.step)?.kind { true } else { false } }
        // A repeat's go is its number, not an item: inside a list, the item stays the list's. A go number sent to a real action would be nobody's item.
        let list = loops.last { !goesRound($0) && $0.items.indices.contains($0.index) }
        if goesRound(frame), let list {
            run.values.set("item", list.items[list.index])
        } else if goesRound(frame), let outer = run.startItem {
            run.values.named["item"] = outer
        } else {
            run.values.set("item", frame.items[frame.index])
        }
        run.values.set("index", JSON.number(Double(frame.index + 1)))
    }

    func nextInLoop(_ step: Step, in run: inout Run) {
        guard let at = run.frames.indices.last, run.frames[at].kind == .loop, case .forEach(_, _, _, let steps) = step.kind else {
            run.pc += 1
            return
        }
        let inside = FlowBody(steps: steps).allSteps
        // What this go gave: what the last step that makes something made. Steps inside start each go with nothing.
        let made = run.values.lastAnswer(of: inside) ?? run.frames[at].items[run.frames[at].index]
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
        let body: FlowBody
        if let pin = step.pin {
            guard let held = other.body(version: pin) else {
                return failed(step, why: L("It stays on version {count} of “{name}”, and that version is no longer kept.", ["count": Format.integer(pin), "name": other.name]), reads: false, in: &run)
            }
            if !practicing, Contract.goesBeyond(held, other.running) {
                return failed(step, why: L("Version {count} of “{name}” has an AI step or sets off a flow that what you've allowed for “{name}” now doesn't have, so it can't stay on that version.", ["count": Format.integer(pin), "name": other.name]), reads: false, in: &run)
            }
            body = held
        } else {
            body = practicing ? other.draft : other.running
        }
        var given = inputs.mapValues { run.values.fill(native: .string($0)) }
        for input in body.inputs where input.type.wantsItself { if let found = inputs[input.name].flatMap(run.values.itself) { given[input.name] = found } }
        // A practice run's values from earlier steps may be stand-ins: only what's written out can be held to it.
        let written = practicing ? Set(inputs.filter { Values.slots($0.value).isEmpty }.keys).union(body.inputs.map(\.name).filter { inputs[$0] == nil }) : nil
        if let wrong = Contract.check(&given, body.inputs, flow: other.name, written: written) { return failed(step, why: wrong, reads: false, in: &run) }
        var values = Values()
        (values.today, values.now) = (run.values.today, run.values.now)
        values.set("input", JSON.object(given))
        let child = startChild(of: run, flow: other.id, flowName: other.name, body: body, mode: practicing ? .practice : run.mode == .once ? .once : .live, why: L("{flow} called it.", ["flow": run.flowName]), values: values)
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
            var child = startChild(of: run, flow: run.flow, flowName: run.flowName, body: FlowBody(steps: lane.steps), mode: run.mode, why: lane.name, values: values)
            child.deadline = lane.timeoutMinutes.map { child.startedAt.addingTimeInterval(Double($0) * 60) }
            started.append(child)
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

    /// Back at a call or a parallel. Carries on when all it waits for are over, so nothing's still working behind it; a child that needs the person leaves this waiting too.
    /// Enough having finished, or a lost cause it was told not to sit out, stops the rest: it goes on once they have.
    func joined(_ step: Step, in run: inout Run) -> Bool {
        let children = run.waitingOn.compactMap { store.run($0) }
        guard children.count == run.waitingOn.count else {
            run.waitingOn = []
            return failed(step, why: L("What it was waiting for is gone."), reads: false, in: &run)
        }
        let done = children.filter { $0.status == .done }, need = step.join.needs(children.count)
        let going = children.filter { !$0.status.isOver }
        guard going.isEmpty else {
            run.status = .waiting
            store.save(run)
            if (need > 0 && done.count >= need) || (step.failFast && done.count + going.count < need) {
                for child in going { stop(run: child.id, windingDown: true) }
            }
            return false
        }
        run.waitingOn = []
        if done.count < need, let bad = children.first(where: { $0.status == .failed || $0.timedOut }) ?? children.first(where: { $0.status != .done }) {
            return failed(step, why: Self.whyNotDone(bad), reads: false, in: &run)
        }
        let result: JSON
        if case .parallel(let list) = step.kind {
            var fields = Dictionary(zip(Self.keys(list), children).map { ($0, $1.status == .done ? $1.answer : .null) }, uniquingKeysWith: { a, _ in a })
            // Beside the lanes' own, and a lane by that name keeps it.
            if case .first = step.join, fields[Self.winner] == nil, let first = done.min(by: { ($0.endedAt ?? .distantFuture) < ($1.endedAt ?? .distantFuture) }) { fields[Self.winner] = first.answer }
            if case .settled = step.join, fields[Self.notFinished] == nil { fields[Self.notFinished] = .array(children.filter { $0.status != .done }.map { .string($0.why) }) }
            result = .object(fields)
        } else if let wanted = children[0].body.output, children[0].mode != .practice {
            let gave = children[0].output
            guard let fitted = gave.flatMap(wanted.fit) else {
                return failed(step, why: L("“{flow}” says it gives {type}, and it gave “{value}”.", ["flow": children[0].flowName, "type": wanted.word, "value": gave.map { Values.text($0).clipped(80) } ?? ""]), reads: false, in: &run)
            }
            result = fitted
        } else {
            result = children[0].answer
        }
        // A flow that made nothing has given nothing. A null it made is its answer, and so is the blank of a failure it was told to carry past.
        if case .parallel = step.kind { run.values.set(step.id, result) } else if children[0].output != nil { run.values.set(step.id, result) }
        let said = done.count < children.count ? L("{done} of {count} finished", ["done": Format.integer(done.count), "count": Format.integer(children.count)]) : Words.step(step, body: run.body, catalog: catalog)
        run.record(.init(step: step.id, status: .done, summary: said, output: Values.text(result).clipped(2000), at: clock()))
        run.pc += 1
        run.retries = 0
        store.save(run)
        return true
    }

    static let winner = "winner", notFinished = "not_finished"

    private static func whyNotDone(_ child: Run) -> String {
        if child.timedOut, let limit = child.deadline {
            let minutes = Int((limit.timeIntervalSince(child.startedAt) / 60).rounded())
            return L(one: "“{lane}” took longer than {count} minute, so it was stopped.", other: "“{lane}” took longer than {count} minutes, so it was stopped.", count: minutes, ["lane": child.why])
        }
        return child.problem ?? L("{flow} didn't finish.", ["flow": child.flowName])
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
                // Left empty is an answer.
                kept[field.name] = .string("")
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

    /// What this step uses isn't here: an extension off or removed, a server gone. Nothing was done, so nothing's lost by waiting: it goes
    /// on by itself when it's back, and asks the person if that takes too long.
    func waitingForConnection(_ step: Step, tool: String, in run: inout Run) -> Bool {
        let name = Connections.id(of: tool).map { Connections.title($0, catalog, store) } ?? tool
        let sentence = Words.step(step, body: run.body, catalog: catalog)
        if let waited = run.connection, waited.tool == tool, waited.until <= clock() {
            run.connection = nil
            run.resumeAt = nil
            run.status = .needs_you
            run.problem = catalog.tool(tool) != nil ? L("{name} is back, but it's been so long that this step is for you to say.", ["name": name]) : L("{name} still isn't here, so this step didn't run.", ["name": name])
            run.record(.init(step: step.id, status: .needs_you, summary: sentence, note: run.problem, at: clock()))
            store.save(run)
            return false
        }
        let first = run.connection?.tool != tool
        let until = first ? clock().addingTimeInterval(Connections.longestWait) : run.connection!.until
        run.connection = Run.WaitingConnection(tool: tool, until: until)
        run.resumeAt = until
        run.status = .waiting
        run.record(.init(step: step.id, status: .waiting, summary: sentence, note: L("It needs {name}, which isn't here now. This step hasn't run, and it goes on by itself once it's back.", ["name": name]), at: clock()))
        store.save(run)
        if first {
            let flow = run.flowName
            Task { await host?.notify(title: L("{flow} is waiting for {name}", ["flow": flow, "name": name]), body: L("It goes on by itself once it's back."), attention: true) }
        }
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
