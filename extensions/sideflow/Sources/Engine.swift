import Foundation
import SidefolkExtensionKit

/// What the engine needs of Sidefolk; tests script it.
@MainActor protocol FlowHost: AnyObject {
    /// `written`: the call before words were filled in, for History to keep instead of them.
    func call(_ tool: String, _ input: [String: Any], plan: String?, written: [String: Any]?) async -> Actions.Outcome
    func check(_ tool: String, _ input: [String: Any], plan: String?) async -> Actions.Check?
    func write(_ prompt: String, label: String) async -> AI.Result
    func approve(_ plan: Plan) async -> Plans.Answer
    func forgetPlan(_ id: String)
    func notify(title: String, body: String?, attention: Bool) async
}

/// Runs flows. It decides nothing about what is allowed: every action goes to Sidefolk, which asks or doesn't; here is only the order of
/// steps, what is kept when something stops, and what a run says happened.
@MainActor final class Engine {
    let store: FlowStore
    let catalog: Catalog
    weak var host: FlowHost?
    var clock: () -> Date = { Date() }
    var calendar = Calendar.autoupdatingCurrent
    /// Backoff for `retry`: what is tried again, and after how long.
    var retryWaits: [TimeInterval] = [30, 120, 600]
    /// Runs in an hour past which a flow is paused and the person told: something set off that shouldn't be.
    var runawayLimit = 30
    /// Called after anything a page shows changed.
    var changed: () -> Void = {}

    private var active: Set<String> = []
    /// One more wanted while it runs, with what set it off.
    private var queued: [String: String?] = [:]
    var resuming: Set<String> = []
    /// Started this time round: `recover` is for what the last time left behind.
    var startedHere: Set<String> = []

    init(store: FlowStore, catalog: Catalog) {
        self.store = store
        self.catalog = catalog
        catalog.findsFlow = { [store] in store.named($0) != nil }
    }

    // MARK: Starting

    /// Starts a run unless the flow is at one; one more waits behind it at most, so a flood of triggers can't pile up.
    @discardableResult
    /// `setOff`: another flow's step started it, not someone looking at this one. It's the On flow that runs, in its turn, and it counts toward the runaway stop whichever mode it's in.
    func start(_ flow: Flow, mode: Run.Mode, why: String, trigger: String? = nil, setOff: Bool = false) -> Run? {
        // With the file held nothing here can be kept, and a run that can't save isn't one to start.
        guard !store.flowsFileIsHeld else { return nil }
        if active.contains(flow.id) {
            // Waiting in line runs under its plan when its turn comes, so only a run that has one may join it.
            guard mode == .live else { return nil }
            switch flow.running.overlap {
            case .skip: break
            case .one_more: queued[flow.id] = .some(trigger)
            case .queue:
                // On disk: a restart keeps its place in line.
                guard var current = store.flow(flow.id), current.waitingStarts.count < FlowBody.longestQueue else { break }
                current.waitingStarts.append(trigger ?? "")
                store.save(current)
            }
            return nil
        }
        let now = clock()
        if mode == .live || setOff, store.runs(of: flow.id, since: now.addingTimeInterval(-3600)).filter({ $0.parent == nil }).count >= runawayLimit {
            pauseRunaway(flow)
            return nil
        }
        var run = Run(id: UUID().uuidString.lowercased(), flow: flow.id, flowName: flow.name, mode: mode, status: .running, why: why, startedAt: now,
                      body: mode == .live || setOff ? flow.running : flow.draft)
        run.values.today = Format.date(now, year: true, weekday: true)
        run.values.now = Format.time(now)
        if let trigger { run.values.set("trigger", trigger) }
        if mode == .practice, trigger == nil, let sample = run.body.triggerSample { run.values.set("trigger", sample) }
        run.setOff = setOff
        store.save(run)
        active.insert(flow.id)
        startedHere.insert(run.id)
        Task { await advance(run.id) }
        return run
    }

    private func pauseRunaway(_ flow: Flow) {
        var flow = flow
        flow.state = .paused
        flow.pausedBecause = L("It set off {count} times in an hour, so I paused it.", ["count": Format.integer(runawayLimit)])
        store.save(flow)
        Task {
            // Paused, not stopped: Resume brings the same watch back.
            await pauseWatch(flow)
            await host?.notify(title: L("{flow} is paused", ["flow": flow.name]), body: flow.pausedBecause, attention: true)
        }
        changed()
    }

    // MARK: Going through it

    func advance(_ id: String) async {
        guard resuming.insert(id).inserted else { return }
        defer { resuming.remove(id) }
        // Two lanes ending together both wake the run that waits for them: the second finds it moved on.
        guard var run = store.run(id), !run.status.isOver, !store.isHeldBack(flow: run.flow) else { return }
        let program = FlowProgram(run.body)
        // A wait's end stays: it's what the wait step comes back to look at. A retry's doesn't.
        var atWait = false
        if run.pc < program.ops.count, case .step(let step) = program.ops[run.pc] {
            switch step.kind {
            case .wait, .form, .waitFor: atWait = true
            default: break
            }
        }
        run.status = .running
        if !atWait { run.resumeAt = nil }
        store.save(run)
        changed()
        var walked = 0
        while run.pc < program.ops.count {
            // Lets anything else in, a press of Stop among them, however little each step waits for.
            await Task.yield()
            walked += 1
            if walked > Self.longestWalk {
                run.status = .failed
                run.problem = L("It went on too long in one go, so it stopped: more than {count} steps. Loops inside loops add up.", ["count": Format.integer(Self.longestWalk)])
                finish(&run)
                return
            }
            // Asked to stop: between steps, never in the middle of one. What's done stays done.
            if store.takeStop(id) {
                run.status = .stopped
                run.frames = []
                finish(&run)
                return
            }
            switch program.ops[run.pc] {
            case .jump(let to):
                run.pc = to
            case .branch(let step, let condition, let otherwise):
                let holds = condition.holds(run.values)
                run.record(.init(step: step.id, status: .done, summary: Words.branch(condition, holds: holds, body: run.body, catalog: catalog), at: clock()))
                run.pc = holds ? run.pc + 1 : otherwise
                store.save(run)
            case .step(let step):
                guard await perform(step, in: &run) else {
                    // Asked to stop while this was under way, a card up, say: it stops here, rather than waiting for an answer it no longer wants.
                    if store.takeStop(id) {
                        for child in run.waitingOn { stop(run: child) }
                        run.status = .stopped
                        run.problem = nil
                        run.resumeAt = nil
                        run.form = nil
                        run.waitingOn = []
                        run.frames = []
                    }
                    finish(&run)
                    return
                }
            case .loopStart(let step, let end):
                guard startLoop(step, end: end, in: &run) else {
                    finish(&run)
                    return
                }
            case .loopNext(let step):
                nextInLoop(step, in: &run)
            case .choose(let step, let targets, let otherwise):
                guard case .choose(let value, let paths, _) = step.kind else { break }
                if let name = run.values.missing(in: [value]).first {
                    guard failed(step, why: L("It uses “{name}”, but that step didn't run this time.", ["name": name]), reads: false, in: &run) else {
                        finish(&run)
                        return
                    }
                    break
                }
                let seen = run.values.fill(value).trimmed
                let way = paths.firstIndex { $0.when.trimmed.compare(run.values.fill($0.when).trimmed, options: []) == .orderedSame && seen.range(of: $0.when.trimmed, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
                run.record(.init(step: step.id, status: .done, summary: way.map { L("“{value}”: {way}", ["value": String(seen.prefix(60)), "way": paths[$0].when]) } ?? L("“{value}”: none of them, so the rest", ["value": String(seen.prefix(60))]), at: clock()))
                run.pc = way.map { targets[$0] } ?? otherwise
                store.save(run)
            case .tryStart(let step, let recover, let always):
                run.frames.append(Run.Frame(kind: .attempt, step: step.id, recover: recover, always: always))
                run.record(.init(step: step.id, status: .done, summary: Words.step(step, body: run.body, catalog: catalog), at: clock()))
                run.pc += 1
                store.save(run)
            case .alwaysStart:
                if let last = run.frames.indices.last, run.frames[last].kind == .attempt { run.frames[last].inAlways = true }
                run.pc += 1
                store.save(run)
            case .tryEnd:
                guard let frame = run.frames.popLast() else { break }
                run.values.named["error"] = nil
                if let why = frame.failing {
                    guard unwind(why, in: &run) else {
                        run.status = .failed
                        run.problem = why
                        finish(&run)
                        return
                    }
                } else if frame.returning {
                    ending(in: &run, length: program.ops.count)
                } else {
                    run.pc += 1
                }
                store.save(run)
            }
        }
        run.status = .done
        finish(&run)
    }

    /// One step. False stops the walk: the run is over, or it waits for something and comes back here.
    private func perform(_ step: Step, in run: inout Run) async -> Bool {
        if let name = run.values.missing(in: step.usedTexts).first {
            return failed(step, why: L("It uses “{name}”, but that step didn't run this time.", ["name": name]), reads: false, in: &run)
        }
        switch step.kind {
        case .call(let flow, let inputs):
            return run.waitingOn.isEmpty ? calling(step, flow: flow, inputs: inputs, in: &run) : joined(step, in: &run)
        case .parallel(let list):
            return run.waitingOn.isEmpty ? lanes(step, list, in: &run) : joined(step, in: &run)
        case .form(let form):
            return waitingForm(step, form, in: &run)
        case .waitFor(_, _, let minutes):
            return waitingForEvent(step, minutes: minutes, in: &run)
        case .finish(let value):
            run.output = run.values.fill(native: .string(value))
            run.record(.init(step: step.id, status: .done, summary: Words.step(step, body: run.body, catalog: catalog), output: run.output.map { Values.text($0).clipped(Self.keptOutput) }, at: clock()))
            ending(in: &run, length: FlowProgram(run.body).ops.count)
            store.save(run)
            return true
        case .data(let data):
            do {
                let from = run.values.fill(native: .string(data.from))
                let made = try data.apply(to: from, than: run.values.fill(data.than ?? ""))
                guard run.values.fits(made) else { throw Problem(L("The result is too long to keep.")) }
                run.values.set(step.id, made)
                run.record(.init(step: step.id, status: .done, summary: Words.step(step, body: run.body, catalog: catalog), output: Values.text(made).clipped(2000), at: clock(), input: Values.text(from).clipped(2000)))
                run.pc += 1
                store.save(run)
                return true
            } catch {
                return failed(step, why: (error as? Problem)?.message ?? L("It didn't work."), reads: true, in: &run)
            }
        case .forEach, .choose, .attempt:
            return true
        case .wait(let minutes):
            if run.mode == .practice {
                run.record(.init(step: step.id, status: .would, summary: L("Would wait {time}", ["time": Format.duration(Double(minutes) * 60)]), at: clock()))
                run.pc += 1
                store.save(run)
                return true
            }
            if let due = run.resumeAt {
                guard due <= clock() else {
                    // Woken early: it's still waiting, and the clock still looks after it.
                    run.status = .waiting
                    store.save(run)
                    return false
                }
                run.resumeAt = nil
                run.record(.init(step: step.id, status: .done, summary: L("Waited {time}", ["time": Format.duration(Double(minutes) * 60)]), at: clock()))
                run.pc += 1
                store.save(run)
                return true
            }
            let until = clock().addingTimeInterval(Double(minutes) * 60)
            run.resumeAt = until
            run.status = .waiting
            run.record(.init(step: step.id, status: .waiting, summary: L("Waiting until {time}", ["time": Format.dateTime(until)]), at: clock()))
            store.save(run)
            return false
        case .text(let text):
            let output = run.values.fill(text)
            run.values.set(step.id, output)
            run.record(.init(step: step.id, status: .done, summary: Words.step(step, body: run.body, catalog: catalog), output: output.clipped(Self.keptOutput), at: clock()))
            run.pc += 1
            store.save(run)
            return true
        case .ai(let prompt):
            return await writing(step, prompt: prompt, in: &run)
        case .ask(let question, let options):
            var input: [String: Any] = ["question": run.values.fill(question), "timeout_seconds": 300]
            if !options.isEmpty { input["options"] = options }
            if run.mode == .practice {
                let first = options.first ?? L("(your answer)")
                run.values.set(step.id, first)
                run.record(.init(step: step.id, status: .would, summary: L("Would ask you: {question}", ["question": run.values.fill(question)]), output: first,
                                 note: options.isEmpty ? nil : L("Going on as if you answered “{answer}”.", ["answer": first]), at: clock()))
                run.pc += 1
                store.save(run)
                return true
            }
            var written = input
            written["question"] = question
            return await acting(step, tool: "ask.user", input: input, written: written, in: &run)
        case .action(let tool, let input):
            let wordy = Set(catalog.tool(tool)?.parameters.filter { if case .text = $0.kind { true } else { false } }.map(\.name) ?? [])
            let filled = run.values.fill(input, wordsIn: wordy)
            if run.mode == .practice { return await practicing(step, tool: tool, input: filled, in: &run) }
            return await acting(step, tool: tool, input: filled, written: input.mapValues(\.any), in: &run)
        case .branch:
            return true
        case .flow(let name):
            run.record(.init(step: step.id, status: .running, summary: Words.step(step, body: run.body, catalog: catalog), at: clock()))
            if run.mode == .practice {
                // What the real run would find: passing practice and then failing live helps nobody.
                let other = store.named(name)
                let found = other != nil && other?.id != run.flow
                run.record(.init(step: step.id, status: found ? .would : .failed, summary: L("Would run {flow}", ["flow": name]),
                                 note: !found ? L("There's no other one flow called “{name}”. Pick it again.", ["name": name])
                                     : other?.state != .on ? L("“{name}” has to be on for this step to run. It can practice without that.", ["name": name]) : nil, at: clock()))
            } else if !store.save(run) {
                return cantSave(step, summary: Words.step(step, body: run.body, catalog: catalog), in: &run)
            } else if let other = store.named(name, forRun: run.id), other.id != run.flow, other.state == .on {
                // Each keeps to its own, and the runaway stop counts every start, so two can't set each other off for ever.
                // A run from a draft was never read on a card: what it sets off asks on cards too, not under its own plan.
                let started = start(other, mode: run.mode == .once ? .once : .live, why: L("{flow} set it off.", ["flow": run.flowName]), setOff: true)
                run.record(.init(step: step.id, status: .done, summary: started != nil ? L("Ran {flow}", ["flow": other.name]) : run.mode == .once ? L("{flow} was already running, so it didn't start", ["flow": other.name]) : L("{flow} was already running or held back, so its own rule for that decides", ["flow": other.name]), at: clock()))
            } else {
                return failed(step, why: L("“{name}” can't run: it isn't on, or there's no other flow by that name.", ["name": name]), reads: false, in: &run)
            }
            run.pc += 1
            store.save(run)
            return true
        }
    }

    private func writing(_ step: Step, prompt: String, in run: inout Run, secondLook: Bool = false) async -> Bool {
        let filled = String(run.values.fill(prompt).prefix(7000))
        run.record(.init(step: step.id, status: .running, summary: Words.step(step, body: run.body, catalog: catalog), at: clock()))
        store.save(run)
        changed()
        let asked = step.fields.map { filled + "\n\n" + AIFields.instruction($0) } ?? filled
        switch await host?.write(asked, label: run.flowName) ?? .refused("off") {
        case .answer(let text, let madeBy):
            if let fields = step.fields {
                guard let record = AIFields.read(text, fields) else {
                    // Words that don't fit never go on as data: once more, then it's a failure like any other.
                    guard secondLook else { return await writing(step, prompt: prompt, in: &run, secondLook: true) }
                    return failed(step, why: L("The AI's answer didn't have the fields this step needs."), reads: true, in: &run)
                }
                run.values.set(step.id, record)
                run.record(.init(step: step.id, status: .done, summary: Words.step(step, body: run.body, catalog: catalog), output: JSONText.write(record.any).clipped(Self.keptOutput), note: L("Written by {who}, not checked.", ["who": madeBy]), at: clock()))
                run.pc += 1
                run.retries = 0
                store.save(run)
                return true
            }
            run.values.set(step.id, text)
            run.record(.init(step: step.id, status: .done, summary: Words.step(step, body: run.body, catalog: catalog), output: text.clipped(Self.keptOutput),
                             note: L("Written by {who}, not checked.", ["who": madeBy]), at: clock()))
            run.pc += 1
            run.retries = 0
            store.save(run)
            return true
        case .refused(let reason):
            // A practice run goes on, and says what's missing: that's what it's for.
            if run.mode == .practice {
                run.values.set(step.id, L("(sample)"))
                run.record(.init(step: step.id, status: .failed, summary: Words.step(step, body: run.body, catalog: catalog), note: Words.aiRefusal(reason), at: clock()))
                run.pc += 1
                store.save(run)
                return true
            }
            return failed(step, why: Words.aiRefusal(reason), reads: true, in: &run)
        }
    }

    /// Reads for real what Sidefolk would let through without a card, and says what everything else would do. Only what Sidefolk itself says
    /// changes nothing is ever run: an extension's own word that a tool only reads isn't enough.
    private func practicing(_ step: Step, tool: String, input: [String: Any], in run: inout Run) async -> Bool {
        if let sample = step.sample {
            let made: JSON = JSONText.read(sample).map { JSON($0) } ?? .string(sample)
            run.values.set(step.id, made)
            run.record(.init(step: step.id, status: .would, summary: L("Would: {what}", ["what": Words.step(step, body: run.body, catalog: catalog)]), output: sample, note: L("Pretending it gave what you wrote for practice."), at: clock()))
            run.pc += 1
            store.save(run)
            return true
        }
        let check = await host?.check(tool, input, plan: run.flowPractice)
        let sentence = Words.resolved(check?.summary ?? Words.step(step, body: run.body, catalog: catalog), values: run.values)
        let readsOnly = catalog.tool(tool)?.readsOnly == true
        if readsOnly, check?.decision == .allow {
            let outcome = await host?.call(tool, input, plan: run.flowPractice, written: nil)
            if let outcome, outcome.ok {
                run.values.set(step.id, outcome.text)
                run.record(.init(step: step.id, status: .done, summary: sentence, output: outcome.text.clipped(Self.keptOutput), at: clock()))
                run.pc += 1
                store.save(run)
                return true
            }
            let note = outcome?.text.nonEmpty ?? L("It didn't work.")
            run.record(.init(step: step.id, status: .failed, summary: sentence, note: note, at: clock()))
            run.values.set(step.id, L("(sample)"))
            run.pc += 1
            store.save(run)
            return true
        }
        let note: String? = switch check?.decision {
        case .deny?: check?.why ?? L("Sidefolk wouldn't allow this.")
        case nil, .unknown?: L("Sidefolk doesn't offer this now.")
        default: readsOnly ? L("It would read this; you didn't allow it for practice.") : nil
        }
        run.record(.init(step: step.id, status: check?.decision == .deny || check == nil ? .failed : .would, summary: L("Would: {what}", ["what": sentence]), note: note, at: clock()))
        run.values.set(step.id, L("(sample)"))
        run.pc += 1
        store.save(run)
        return true
    }

    private func acting(_ step: Step, tool: String, input: [String: Any], written: [String: Any]? = nil, in run: inout Run) async -> Bool {
        let sentence = Words.step(step, body: run.body, catalog: catalog)
        run.record(.init(step: step.id, status: .running, summary: sentence, at: clock(), input: JSONText.write(input).clipped(2000)))
        // Written down first, or not done: after a stop, the run must know what it may have done.
        guard store.save(run) else { return cantSave(step, summary: sentence, in: &run) }
        changed()
        let reads = step.reads(catalog)
        let plan = run.mode == .live ? "flow-\(run.flow)" : nil
        let outcome = await host?.call(tool, input, plan: plan, written: written) ?? Actions.Outcome(status: .lost, text: "", summary: "", untrusted: false, standing: false)
        let said = outcome.summary.nonEmpty.map { Words.resolved($0, values: run.values) } ?? sentence
        switch outcome.status {
        case .ok:
            run.values.set(step.id, outcome.text)
            // Cut for keeping: it says so, rather than a list that looks whole.
            let cut = outcome.text.count > Values.keep ? L("Its answer was long: only the first {count} characters were kept.", ["count": Format.integer(Values.keep)]) : nil
            // What a notice answers ("shown", "held for now") is for a model, not for the person's story.
            run.record(.init(step: step.id, status: .done, summary: step.name ?? said, output: tool == "notify.user" ? nil : outcome.text.clipped(Self.keptOutput), note: cut, at: clock()))
            run.pc += 1
            run.retries = 0
            store.save(run)
            return true
        case .denied, .unanswered:
            // Nothing happened, and only the person can change that.
            run.status = .needs_you
            run.problem = outcome.status == .unanswered ? L("Nobody answered the card for this step, so it didn't run.") : outcome.text.nonEmpty ?? L("This step wasn't allowed, so it didn't run.")
            run.record(.init(step: step.id, status: .needs_you, summary: step.name ?? said, note: run.problem, at: clock()))
            store.save(run)
            return false
        case .busy:
            // Nothing happened, and a minute puts it right: a long list isn't a failure.
            run.resumeAt = clock().addingTimeInterval(Self.busyWait)
            run.status = .waiting
            run.record(.init(step: step.id, status: .waiting, summary: sentence, note: L("Going through a lot at once, so it takes a minute's rest."), at: clock()))
            store.save(run)
            return false
        case .failed, .lost:
            // It may have happened. That's for the person to look at unless they said to carry on, and never to repeat by itself.
            guard !reads, step.onFailure != .carry_on else {
                return failed(step, why: outcome.text.nonEmpty ?? L("It didn't work."), reads: reads, in: &run, said: step.name ?? said)
            }
            run.status = .interrupted
            let didntFinish = L("This step didn't finish. It may or may not have happened.")
            run.problem = outcome.text.nonEmpty.map { "\(didntFinish) \($0)" } ?? didntFinish
            run.record(.init(step: step.id, status: .unknown, summary: step.name ?? said, note: run.problem, at: clock()))
            store.save(run)
            return false
        case .error:
            return failed(step, why: outcome.text.nonEmpty ?? L("It didn't work."), reads: reads, in: &run, said: step.name ?? said)
        }
    }

    /// The disk won't take the run's progress: it stops here, with nothing done, and says so where it can.
    private func cantSave(_ step: Step, summary: String, in run: inout Run) -> Bool {
        run.status = .needs_you
        run.problem = L("Sidefolk couldn't save this run's progress, so it stopped before this step. Nothing was done.")
        run.record(.init(step: step.id, status: .needs_you, summary: summary, note: run.problem, at: clock()))
        store.save(run)
        let (name, why) = (run.flowName, run.problem)
        Task { await host?.notify(title: L("{flow} stopped", ["flow": name]), body: why, attention: true) }
        return false
    }

    /// What a failure does, as the step says. Trying again is only for what changes nothing: repeating an action that may have happened
    /// is the one thing that must not happen by itself.
    func failed(_ step: Step, why: String, reads: Bool, in run: inout Run, said: String? = nil) -> Bool {
        let summary = said ?? Words.step(step, body: run.body, catalog: catalog)
        switch step.onFailure {
        case .retry where reads && run.retries < retryWaits.count:
            let until = clock().addingTimeInterval(retryWaits[run.retries])
            run.retries += 1
            run.resumeAt = until
            run.status = .waiting
            run.record(.init(step: step.id, status: .waiting, summary: summary, note: L("It didn't work, so I'll try again at {time}: {why}", ["time": Format.time(until), "why": why]), at: clock()))
            store.save(run)
            return false
        case .carry_on:
            run.record(.init(step: step.id, status: .failed, summary: summary, note: why, at: clock()))
            run.values.set(step.id, "")
            run.pc = FlowProgram(run.body).past(run.pc)
            run.retries = 0
            store.save(run)
            return true
        default:
            run.retries = 0
            run.record(.init(step: step.id, status: .failed, summary: summary, note: why, at: clock()))
            if unwind(why, in: &run) {
                store.save(run)
                return true
            }
            run.status = .failed
            run.problem = why
            store.save(run)
            return false
        }
    }

    func finish(_ run: inout Run) {
        // A flow's own run holds the flow; one that another waits for doesn't: it's that run's business.
        let holds = run.parent == nil
        if run.output == nil, run.status == .done, let last = run.body.allSteps.last(where: { $0.hasOutput }) { run.output = run.values.resolve(last.id) }
        if run.status.isOver {
            run.endedAt = clock()
            _ = store.takeStop(run.id)
            if holds { active.remove(run.flow) }
        }
        if holds, run.status == .needs_you || run.status == .interrupted { active.remove(run.flow) }
        store.save(run)
        changed()
        let ended = run
        if let parent = ended.parent, ended.status.isOver {
            let child = ended.id
            // Asked as it runs: two lanes ending together wake it twice, and the second finds it's no longer waiting for them.
            Task {
                guard store.run(parent)?.waitingOn.contains(child) == true else { return }
                await advance(parent)
            }
            return
        }
        Task { await self.tell(ended) }
        guard holds else { return }
        if ended.status.isOver || ended.status == .needs_you, var waiting = store.flow(ended.flow), let next = waiting.waitingStarts.first, waiting.state == .on {
            waiting.waitingStarts.removeFirst()
            store.save(waiting)
            start(waiting, mode: .live, why: L("Its turn came."), trigger: next.nonEmpty)
            return
        }
        if ended.status.isOver || ended.status == .needs_you, let trigger = queued.removeValue(forKey: ended.flow), let flow = store.flow(ended.flow), flow.state == .on {
            start(flow, mode: .live, why: L("It was set off again while it ran."), trigger: trigger)
        }
    }

    /// What the person hears: always when it needs them or failed; a finished run's result in one line, when they asked for that.
    private func tell(_ run: Run) async {
        // Cards are how a run from a draft talks to the person, but one a run is waiting for has nothing else to say it's stuck.
        guard run.mode == .live || (run.mode == .once && (run.parent != nil || run.setOff)) else { return }
        switch run.status {
        case .needs_you, .interrupted:
            await askTheWayForward(run)
        case .failed:
            await host?.notify(title: L("{flow} stopped", ["flow": run.flowName]), body: run.problem, attention: true)
        case .done:
            guard ExtensionSettings.string("tell") == "always" else { return }
            let last = run.records.reversed().first { $0.status == .done && $0.output?.nonEmpty != nil }
            await host?.notify(title: L("{flow} is done", ["flow": run.flowName]), body: last?.output.map { String($0.prefix(160)) }, attention: false)
        default:
            break
        }
    }

    /// Where they are, the question that gets a stopped run going again, answered right there. Nobody answering leaves it where it is, on the page.
    private func askTheWayForward(_ run: Run) async {
        let step = run.records.last?.summary ?? ""
        let question = run.status == .interrupted
            ? L("{flow} stopped in the middle of this: {step}. Did it happen?", ["flow": run.flowName, "step": step])
            : L("{flow} needs you. {why}", ["flow": run.flowName, "why": run.problem ?? step])
        let choices: [(words: String, how: Forward)] = run.status == .interrupted
            ? [(L("It didn't: try again"), .try_again), (L("It did: carry on"), .carry_on), (L("Stop here"), .stop)]
            : [(L("Try again"), .try_again), (L("Skip this step"), .carry_on), (L("Stop here"), .stop)]
        guard let answer = await host?.call("ask.user", ["question": question, "options": choices.map(\.words), "timeout_seconds": 300], plan: nil, written: nil), answer.ok,
              let chosen = choices.first(where: { $0.words == answer.text.trimmed }),
              let now = store.run(run.id), now.status == run.status, now.pc == run.pc else { return }
        proceed(run.id, chosen.how)
    }

    // MARK: After a stop

    /// On launch: what was mid-air. A step that only reads goes again; a step that changes things isn't repeated, because it may have
    /// happened: the person says which. Waits carry on at their time.
    func recover() {
        for var run in store.unfinished() {
            // Set off in the moment before this looked: it's under way here, not left over.
            if startedHere.contains(run.id) || resuming.contains(run.id) { continue }
            if run.parent == nil { active.insert(run.flow) }
            // Its flow is there but can't be read now: left exactly as it is, neither run nor ended, in case it can be next time. A wait of days isn't lost to one bad read.
            if store.isHeldBack(flow: run.flow) { continue }
            // Stop was pressed, and Sidefolk quit before the step under way came back. It stays pressed.
            // Or its flow is gone, so what it was allowed to do can't be told from here: nothing more of it runs.
            let orphaned = store.flow(run.flow) == nil
            if orphaned || store.takeStop(run.id) {
                let program = FlowProgram(run.body)
                if run.status == .running, run.pc < program.ops.count, case .step(let step) = program.ops[run.pc], var r = run.record(of: step.id), r.status == .running {
                    let reads = step.reads(catalog)
                    r.status = reads ? .skipped : .unknown
                    r.note = reads ? L("Stopped before this came back.") : L("Sidefolk stopped in the middle of this. It may or may not have happened.")
                    run.record(r)
                }
                for child in run.waitingOn { stop(run: child) }
                run.status = .stopped
                run.problem = nil
                run.resumeAt = nil
                run.form = nil
                run.waitingOn = []
                run.frames = []
                finish(&run)
                continue
            }
            switch run.status {
            case .running:
                let program = FlowProgram(run.body)
                guard run.pc < program.ops.count, case .step(let step) = program.ops[run.pc], run.records.last(where: { $0.step == step.id && $0.scope == run.scope })?.status == .running else {
                    Task { await advance(run.id) }
                    continue
                }
                if step.reads(catalog) || run.mode == .practice {
                    Task { await advance(run.id) }
                } else {
                    run.status = .interrupted
                    run.problem = L("Sidefolk stopped while this was running. It may or may not have happened.")
                    if var r = run.record(of: step.id) {
                        r.status = .unknown
                        r.note = run.problem
                        run.record(r)
                    }
                    store.save(run)
                    if run.parent == nil { active.remove(run.flow) }
                    let told = run
                    Task { await tell(told) }
                }
            case .waiting:
                // What it waited for may have ended while Sidefolk was off.
                if !run.waitingOn.isEmpty, run.waitingOn.allSatisfy({ store.run($0)?.status.isOver ?? true }) {
                    let id = run.id
                    Task { await advance(id) }
                }
            default:
                // Not when another of its runs is going, one this has just let start among them.
                let going = store.unfinished().contains { $0.flow == run.flow && $0.parent == nil && ($0.status == .running || $0.status == .waiting) }
                if run.parent == nil, !going { active.remove(run.flow) }
            }
        }
        changed()
    }

    /// The way forward from a stop, from the page or a request.
    enum Forward: String, Sendable { case try_again, carry_on, stop }

    func proceed(_ id: String, _ how: Forward) {
        if how == .stop { return stop(run: id) }
        guard let current = store.run(id), !current.status.isOver, current.status != .running, !store.isHeldBack(flow: current.flow) else { return }
        // A form or another run is what it's waiting for: going past that isn't anyone's to choose from here.
        guard var run = store.run(id), run.form == nil, run.waitingOn.isEmpty else { return }
        switch how {
        case .stop:
            break
        case .try_again:
            run.retries = 0
            run.resumeAt = nil
            run.problem = nil
            store.save(run)
            if run.parent == nil { active.insert(run.flow) }
            Task { await advance(id) }
        case .carry_on:
            let program = FlowProgram(run.body)
            if run.pc < program.ops.count, case .step(let step) = program.ops[run.pc] {
                run.values.set(step.id, "")
                if var r = run.record(of: step.id) {
                    r.status = .skipped
                    r.note = nil
                    run.record(r)
                }
            }
            run.pc = program.past(run.pc)
            run.problem = nil
            run.retries = 0
            run.resumeAt = nil
            store.save(run)
            if run.parent == nil { active.insert(run.flow) }
            Task { await advance(id) }
        }
    }

    // MARK: The clock

    /// Called every little while. A Mac asleep or a Sidefolk quit misses its moment, which the flow's rule decides: run once when back, or say it was missed.
    /// Flows that went on before a schedule or an AI step needed a card. Nobody read what these do, so they ask once, now, rather than go on as they were.
    func pauseWhatNobodyRead() {
        guard catalog.loadedAt != nil else { return }
        for var flow in store.flows() where flow.state == .on && nobodyRead(flow) {
            flow.state = .paused
            flow.pausedBecause = L("It now asks before running by itself. Resume it to read what it does.")
            store.save(flow)
            for run in store.unfinished() where run.flow == flow.id && run.mode == .live { stop(run: run.id) }
            let told = flow
            Task { await host?.notify(title: L("{flow} is paused", ["flow": told.name]), body: told.pausedBecause, attention: false) }
        }
        changed()
    }

    /// It would run by itself with nothing the person allowed behind it. One with actions has them checked at each call, so only this kind can.
    func nobodyRead(_ flow: Flow) -> Bool {
        guard Self.needsCard(flow.running), catalog.plan(flow.planId) == nil else { return false }
        // Its actions ask if nothing stands behind them. An AI step or a set-off never would.
        return Self.planSteps(flow.running, title: Self.watchTitle(flow)).isEmpty
            || flow.running.allSteps.contains { switch $0.kind { case .ai, .flow, .call: true; default: false } }
    }

    func tick() {
        guard !store.flowsFileIsHeld else { return }
        let now = clock()
        for var flow in store.flows() where flow.state == .on {
            let trigger = flow.running.trigger
            var clock = calendar
            if let zone = flow.running.timeZone.flatMap(TimeZone.init(identifier:)) { clock.timeZone = zone }
            guard let from = flow.lastFire, let due = Schedule.due(trigger, last: from, now: now, calendar: clock) else { continue }
            flow.lastFire = due.latest
            let late = now.timeIntervalSince(due.latest) > Schedule.onTime
            if late, !Schedule.catchesUp(trigger) {
                flow.missed = Array((flow.missed + [due.latest]).suffix(8))
                store.save(flow)
                continue
            }
            store.save(flow)
            let why = late ? L("Meant for {time}; Sidefolk or your Mac was off then.", ["time": Format.dateTime(due.latest)]) : Words.trigger(trigger)
            start(flow, mode: .live, why: why)
        }
        for run in store.unfinished() where run.status == .waiting {
            if let at = run.resumeAt, at <= now { Task { await advance(run.id) } }
        }
    }

    /// Something happened in Sidefolk: every On flow waiting for it goes.
    func happened(name: String, title: String?, detail: String?) {
        let words = [title, detail].compactMap(\.self).joined(separator: "\n")
        wakeWaiting(name: name, words: words)
        for flow in store.flows() where flow.state == .on {
            guard case .event(let wanted, let contains) = flow.running.trigger, wanted == name else { continue }
            if let contains, words.range(of: contains, options: [.caseInsensitive, .diacriticInsensitive]) == nil { continue }
            start(flow, mode: .live, why: Words.trigger(flow.running.trigger), trigger: words)
        }
    }

    /// A watch this flow made fired.
    func watchFired(title: String, summary: String) {
        guard let flow = store.flows().first(where: { flow in
            guard flow.state == .on, flow.watchTitle == title, case .watch = flow.running.trigger else { return false }
            return true
        }) else { return }
        start(flow, mode: .live, why: L("The watch saw a change."), trigger: summary)
    }

    func isRunning(_ flow: String) -> Bool { active.contains(flow) }

    func queuedCount(_ flow: String) -> Int { (queued[flow] == nil ? 0 : 1) + (store.flow(flow)?.waitingStarts.count ?? 0) }

    /// Stops a run the person is looking at, and any it waits for. Something under way finishes first, because it can't be taken back halfway: the page says so.
    func stop(run id: String) {
        guard var run = store.run(id), !run.status.isOver else { return }
        for child in run.waitingOn { stop(run: child) }
        if run.status == .running {
            store.askStop(id)
        } else {
            run.status = .stopped
            run.problem = nil
            run.resumeAt = nil
            run.form = nil
            run.waitingOn = []
            run.frames = []
            // The one way out: lets go of the flow, wakes a run waiting for it, and starts what's in line.
            finish(&run)
        }
    }

    // MARK: Turning on and off

    /// The practice run's plan: what only reads, written out. It ends by itself.
    func practicePlan(_ flow: Flow) -> Plan? {
        let reads = flow.draft.allSteps.compactMap { step -> PlanStep? in
            guard case .action(let tool, let input) = step.kind, catalog.tool(tool)?.readsOnly == true else { return nil }
            guard !input.values.flatMap(\.strings).contains(where: { !Values.references($0).isEmpty }) else { return nil }
            return PlanStep(tool, input.mapValues(\.any))
        }
        guard !reads.isEmpty else { return nil }
        return Plan(id: flow.practiceId, title: L("Practice run of {flow}", ["flow": flow.name]), when: L("Now, and for the next hour if you practice it again"), steps: reads, ttl: 3600)
    }

    /// The practice run: a card first when it would read something, then the run. Never blocks the page's own call.
    func practice(_ flow: Flow) {
        guard !active.contains(flow.id) else { return }
        Task {
            if let plan = practicePlan(flow) { _ = await host?.approve(plan) }
            start(flow, mode: .practice, why: L("You asked for a practice run."))
        }
    }

    /// What a definition asks to be allowed, one line each, the same line once: what the card shows and what Sidefolk's limit on a plan counts.
    static func planSteps(_ body: FlowBody, title: String, oldWatch: String? = nil) -> [PlanStep] {
        var steps: [PlanStep] = []
        var seen = Set<String>()
        func add(_ tool: String, _ input: [String: Any]) {
            let key = tool + JSONText.write(input)
            if seen.insert(key).inserted { steps.append(PlanStep(tool, input)) }
        }
        for step in body.allSteps {
            switch step.kind {
            case .action(let tool, let input): add(tool, input.mapValues(\.any))
            case .ask(let question, let options):
                var input: [String: Any] = ["question": question, "timeout_seconds": 300]
                if !options.isEmpty { input["options"] = options }
                add("ask.user", input)
            default: break
            }
        }
        if case .watch(let w) = body.trigger {
            add("watch.create", watchInput(w, title: title))
            add("watch.stop", ["id": title])
            add("watch.pause", ["id": title])
            add("watch.resume", ["id": title])
            // Named differently before: the one it replaces goes too.
            if let oldWatch, oldWatch != title { add("watch.stop", ["id": oldWatch]) }
        } else if let oldWatch {
            // It was a watch and isn't now: the watch goes, or it would go on firing.
            add("watch.stop", ["id": oldWatch])
        }
        return steps
    }

    /// Everything the draft may do, as the person will read it.
    func livePlan(_ flow: Flow) -> Plan {
        let steps = Self.planSteps(flow.kept, title: Self.watchTitle(flow), oldWatch: flow.watchTitle)
        // Setting another flow off needs no tool of its own, so the card says it here.
        let others = flow.kept.allSteps.compactMap { step -> (name: String, full: String)? in
            switch step.kind {
            case .flow(let name): (name, name)
            case .call(let name, let inputs): (name, inputs.isEmpty ? name : "\(name) (" + inputs.keys.sorted().map { "\($0): \(inputs[$0] ?? "")" }.joined(separator: ", ") + ")")
            default: nil
            }
        }
        // Sidefolk shows so much of this and no more. What a flow sets off appears nowhere else on the card, so a long address gives way to it.
        let said = Words.trigger(flow.kept.trigger)
        var when = said.count > Self.longestTriggerWords ? said.prefix(Self.longestTriggerWords) + "…" : said
        if flow.kept.allSteps.contains(where: { if case .ai = $0.kind { true } else { false } }) {
            when = L("{when}. What its steps read goes to your AI, to write from.", ["when": when])
        }
        if !others.isEmpty {
            let full = others.map(\.full).joined(separator: ", ")
            var names = full
            if full.count > Self.longestSetsOff {
                var fit: [String] = []
                for name in others.map(\.name) where (fit + [name]).joined(separator: ", ").count <= Self.longestSetsOff { fit.append(name) }
                names = fit.joined(separator: ", ")
                if fit.count < others.count { names += " " + L(one: "and {count} more", other: "and {count} more", count: others.count - fit.count) }
            }
            when = L("{when}. Also sets off: {flows}", ["when": when, "flows": names])
        }
        // A loop does its lines many times over: the card says the higher limit that takes.
        let goesRound = flow.kept.allSteps.contains { if case .forEach = $0.kind { true } else { false } }
        return Plan(id: flow.planId, title: flow.name, when: when, steps: steps, perDay: goesRound ? Self.loopsPerDay : nil)
    }

    static let loopsPerDay = 1000
    static let longestSetsOff = 300
    static let longestTriggerWords = 160

    /// There's something to read before it runs by itself. Only a flow someone starts by hand that does nothing but work on its own values has nothing to say.
    static func needsCard(_ body: FlowBody) -> Bool {
        if case .manual = body.trigger {} else { return true }
        return !planSteps(body, title: "").isEmpty || body.allSteps.contains { switch $0.kind { case .flow, .call, .ai: true; default: false } }
    }

    static let busyWait: TimeInterval = 61
    /// How long to wait out the minute's calls. Tests make it short.
    var busyPause: TimeInterval = Engine.busyWait
    /// What a run's story keeps of a step's output: it goes on the page, which has a limit of its own. The value itself is kept whole for the next step.
    static let keptOutput = 2000
    /// Steps in a run between two waits.
    static let longestWalk = 20_000

    static func watchTitle(_ flow: Flow) -> String { "\(flow.name) · Sideflow" }

    static func watchInput(_ w: WatchTrigger, title: String) -> [String: Any] {
        var input: [String: Any] = ["kind": w.kind, "target": w.target, "title": title, "mode": "repeat", "level": "gentle"]
        if let c = w.contains { input["contains"] = c }
        if let p = w.pattern { input["pattern"] = p }
        if let every = w.everySeconds { input["interval_minutes"] = Double(every) / 60 }
        if let rest = w.restMinutes { input["cooldown_minutes"] = rest }
        return input
    }

    /// Asks the person, then turns it on. False when a stopped flow has nothing to run. The answer comes back to the flow, not to the caller.
    func turnOn(_ id: String) {
        guard var flow = store.flow(id) else { return }
        // Whoever asked, a page's button or an agent: it can't read this on a card, because it can't run.
        if let wrong = flow.kept.triggerProblem {
            flow.startProblem = wrong
            store.save(flow)
            return changed()
        }
        flow.startProblem = nil
        store.save(flow)
        changed()
        let plan = livePlan(flow)
        // Stopping the watch it had can be the line too many, which only shows here.
        if plan.steps.count > Plans.maxSteps {
            flow.startProblem = L("It has {count} different things to allow, counting what it watches. A flow can have {limit}: move some into a flow of their own.", ["count": Format.integer(plan.steps.count), "limit": Format.integer(Plans.maxSteps)])
            store.save(flow)
            return changed()
        }
        // What they read is what goes live: anything changed while the card waits stays in the draft.
        let reviewed = flow.kept, reviewedTitle = Self.watchTitle(flow)
        Task {
            let answer: Plans.Answer? = Self.needsCard(reviewed) ? await host?.approve(plan) : .allowed(standing: [])
            guard let answer, var current = store.flow(id) else { return }
            switch answer {
            case .allowed:
                let oldWatch = current.watchTitle
                if let was = current.live, was != reviewed {
                    current.revisions.append(Flow.Revision(at: clock(), body: was))
                    current.revisions = Array(current.revisions.suffix(Flow.keptRevisions))
                }
                current.live = reviewed
                current.state = .on
                current.pausedBecause = nil
                current.lastFire = clock()
                current.startProblem = nil
                store.save(current)
                if case .watch(let w) = reviewed.trigger {
                    let title = reviewedTitle
                    // One name, one watch: a second under the same name would leave neither reachable, and the old one still firing.
                    if oldWatch != nil, !(await stopWatch(current)) {
                        guard var after = store.flow(id) else { return }
                        after.startProblem = L("Its old watch didn't stop, so it hasn't made the new one. Try turning it on again.")
                        after.state = .paused
                        store.save(after)
                        changed()
                        return
                    }
                    let made = await host?.call("watch.create", Self.watchInput(w, title: title), plan: current.planId, written: nil)
                    guard var after = store.flow(id) else { return }
                    if made?.ok == true {
                        after.watchTitle = title
                    } else {
                        after.startProblem = made?.text.nonEmpty ?? L("The watch didn't start.")
                        after.state = .paused
                    }
                    store.save(after)
                } else if oldWatch != nil, var after = store.flow(id) {
                    if await stopWatch(current) {
                        after.watchTitle = nil
                    } else {
                        // Only once it's really gone: the name is the only way to reach it, from a later card or from deleting the flow.
                        after.startProblem = L("Its old watch didn't stop. It no longer sets this flow off; try turning it on again to stop it.")
                    }
                    store.save(after)
                }
            case .refused(let reason):
                current.startProblem = Words.planRefusal(reason)
                store.save(current)
            }
            changed()
        }
    }

    func pause(_ id: String) {
        guard var flow = store.flow(id), flow.state == .on else { return }
        flow.state = .paused
        store.save(flow)
        changed()
        Task { await pauseWatch(flow) }
    }

    /// Goes on with what the person already allowed. Anything changed needs the card, by `turnOn`.
    func resume(_ id: String) {
        guard var flow = store.flow(id), flow.state == .paused, !flow.hasChanges, flow.live != nil, !nobodyRead(flow) else { return turnOn(id) }
        flow.state = .on
        flow.pausedBecause = nil
        flow.startProblem = nil
        flow.lastFire = clock()
        store.save(flow)
        changed()
        Task { await resumeWatch(flow) }
    }

    func delete(_ id: String) {
        guard let flow = store.flow(id) else { return }
        for run in store.unfinished() where run.flow == id { stop(run: run.id) }
        store.remove(flow: id)
        host?.forgetPlan(flow.practiceId)
        changed()
        // The watch first: forgotten, the plan could no longer stop what it made.
        Task {
            await stopWatch(flow)
            host?.forgetPlan(flow.planId)
        }
    }

    /// Whether it's gone: stopped now, or not there to stop. With the minute's calls used up it waits once.
    @discardableResult private func stopWatch(_ flow: Flow) async -> Bool {
        guard let title = flow.watchTitle else { return true }
        var stopped = await host?.call("watch.stop", ["id": title], plan: flow.planId, written: nil)
        if stopped?.status == .busy {
            try? await Task.sleep(for: .seconds(busyPause))
            stopped = await host?.call("watch.stop", ["id": title], plan: flow.planId, written: nil)
        }
        return stopped?.ok == true || stopped?.notFound == true
    }

    private func pauseWatch(_ flow: Flow) async {
        guard let title = flow.watchTitle else { return }
        _ = await host?.call("watch.pause", ["id": title], plan: flow.planId, written: nil)
    }

    private func resumeWatch(_ flow: Flow) async {
        guard case .watch(let w) = flow.running.trigger else { return }
        // Never made: it failed when it was turned on, a folder not shared, say, and that's what they've just put right.
        let title = flow.watchTitle ?? Self.watchTitle(flow)
        if flow.watchTitle != nil {
            var back = await host?.call("watch.resume", ["id": title], plan: flow.planId, written: nil)
            if back?.status == .busy {
                try? await Task.sleep(for: .seconds(busyPause))
                guard store.flow(flow.id)?.state == .on else { return }
                back = await host?.call("watch.resume", ["id": title], plan: flow.planId, written: nil)
            }
            if back?.ok == true { return }
            // Only what's really not there is made again: a second of the same name would leave neither reachable by name.
            if back?.notFound != true {
                guard var current = store.flow(flow.id) else { return }
                switch back?.status {
                case .denied?, .unanswered?, .busy?:
                    // Nothing happened: saying On would be a flow that never fires.
                    current.startProblem = back?.text.nonEmpty ?? L("The watch didn't start.")
                    current.state = .paused
                default:
                    current.startProblem = L("Sidefolk didn't say whether its watch started again. If it doesn't fire, pause and resume it.")
                }
                store.save(current)
                changed()
                return
            }
        }
        // The watch has gone: an earlier version stopped it when it paused for setting off too often, or the person stopped it in Home.
        var made = await host?.call("watch.create", Self.watchInput(w, title: title), plan: flow.planId, written: nil)
        if made?.status == .busy {
            try? await Task.sleep(for: .seconds(busyPause))
            guard store.flow(flow.id)?.state == .on else { return }
            made = await host?.call("watch.create", Self.watchInput(w, title: title), plan: flow.planId, written: nil)
        }
        guard var current = store.flow(flow.id) else { return }
        if made?.ok == true {
            current.watchTitle = title
        } else {
            // Saying On here would be a flow that never fires.
            current.startProblem = made?.text.nonEmpty ?? L("The watch didn't start.")
            current.state = .paused
        }
        store.save(current)
        changed()
    }

    private func note(_ id: String, problem: String) {
        guard var flow = store.flow(id) else { return }
        flow.startProblem = problem
        store.save(flow)
        changed()
    }

    /// The person ended what they'd allowed, in Settings.
    func planEnded(_ id: String) {
        guard var flow = store.flow(id) else { return }
        flow.state = .paused
        flow.pausedBecause = L("You ended what you'd allowed in Settings, so it asks again before running.")
        let ended = flow.live
        if let was = flow.live {
            flow.revisions.append(Flow.Revision(at: clock(), body: was))
            flow.revisions = Array(flow.revisions.suffix(Flow.keptRevisions))
        }
        flow.live = nil
        store.save(flow)
        // What's under way was running on what they just ended, called by another flow or set off by a draft too. An AI step or a set-off never reaches Sidefolk's check, so this is what stops those.
        for run in store.unfinished() where run.flow == id && run.mode != .practice && (run.mode == .live || run.setOff || run.body == ended) { stop(run: run.id) }
        changed()
        guard let title = flow.watchTitle else { return }
        // Its watch was made under that plan, so this asks: leaving it looking would go past what they just ended.
        Task {
            let stopped = await host?.call("watch.stop", ["id": title], plan: nil, written: nil)
            guard stopped?.ok == true, var current = store.flow(id) else { return }
            current.watchTitle = nil
            store.save(current)
        }
    }
}

extension Run {
    /// The plan a practice run reads under.
    var flowPractice: String { "practice-\(flow)" }
}

@MainActor extension Step {
    /// Whether repeating it is harmless: for a tool, only what Sidefolk itself vouches for as reading.
    func reads(_ catalog: Catalog) -> Bool {
        switch kind {
        case .action(let tool, _): catalog.tool(tool)?.readsOnly == true
        // Asking again after a stop changes nothing: the person just answers.
        case .ai, .ask, .text, .branch, .wait: true
        // Setting another flow off twice isn't the same as once.
        case .flow, .call: false
        // What holds steps answers for itself no further than its steps do, each of which is asked in turn.
        case .forEach, .choose, .attempt, .parallel, .finish, .data, .form, .waitFor: true
        }
    }
}
