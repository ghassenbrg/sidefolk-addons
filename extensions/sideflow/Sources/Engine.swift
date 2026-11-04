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
    private var resuming: Set<String> = []

    init(store: FlowStore, catalog: Catalog) {
        self.store = store
        self.catalog = catalog
    }

    // MARK: Starting

    /// Starts a run unless the flow is at one; one more waits behind it at most, so a flood of triggers can't pile up.
    @discardableResult
    func start(_ flow: Flow, mode: Run.Mode, why: String, trigger: String? = nil) -> Run? {
        // On from before a blank step was marked: pausing says so once, where running would do what comes before it each time and then stop.
        if mode == .live, let wrong = flow.running.blank {
            guard var current = store.flow(flow.id), current.state == .on else { return nil }
            current.state = .paused
            current.startProblem = wrong
            current.pausedBecause = L("It has a step that says nothing, so it's paused until that's fixed.")
            store.save(current)
            changed()
            let told = current
            Task { await host?.notify(title: L("{flow} is paused", ["flow": told.name]), body: told.pausedBecause, attention: true) }
            return nil
        }
        if active.contains(flow.id) {
            if mode == .live { queued[flow.id] = .some(trigger) }
            return nil
        }
        let now = clock()
        if mode == .live, store.runs(of: flow.id, since: now.addingTimeInterval(-3600)).count >= runawayLimit {
            pauseRunaway(flow)
            return nil
        }
        var run = Run(id: UUID().uuidString.lowercased(), flow: flow.id, flowName: flow.name, mode: mode, status: .running, why: why, startedAt: now,
                      // Practice tries what's on the page. A run for real uses what was kept: "only here so far" means that.
                      body: mode == .live ? flow.running : mode == .once ? flow.kept : flow.draft)
        run.values.today = Format.date(now, year: true, weekday: true)
        run.values.now = Format.time(now)
        if let trigger { run.values.set("trigger", trigger) }
        store.save(run)
        active.insert(flow.id)
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
        guard var run = store.run(id) else { return }
        let program = FlowProgram(run.body)
        // A wait's end stays: it's what the wait step comes back to look at. A retry's doesn't.
        var atWait = false
        if run.pc < program.ops.count, case .step(let step) = program.ops[run.pc], case .wait = step.kind { atWait = true }
        run.status = .running
        if !atWait { run.resumeAt = nil }
        store.save(run)
        changed()
        while run.pc < program.ops.count {
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
                    finish(&run)
                    return
                }
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
        case .wait(let minutes):
            if run.mode == .practice {
                run.record(.init(step: step.id, status: .would, summary: L("Would wait {time}", ["time": Format.duration(Double(minutes) * 60)]), at: clock()))
                run.pc += 1
                store.save(run)
                return true
            }
            if let due = run.resumeAt {
                guard due <= clock() else { return false }
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
            run.record(.init(step: step.id, status: .done, summary: Words.step(step, body: run.body, catalog: catalog), output: output, at: clock()))
            run.pc += 1
            store.save(run)
            return true
        // Reached only by a flow that went on before this was marked: nothing goes to the AI or the person for a step that says nothing.
        case .ai(let prompt) where prompt.trimmed.isEmpty:
            return failed(step, why: L("Say what to write."), reads: false, in: &run)
        case .ask(let question, _) where question.trimmed.isEmpty:
            return failed(step, why: L("Say what to ask."), reads: false, in: &run)
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
            let filled = run.values.fill(input)
            if run.mode == .practice { return await practicing(step, tool: tool, input: filled, in: &run) }
            return await acting(step, tool: tool, input: filled, written: input.mapValues(\.any), in: &run)
        case .branch:
            return true
        case .flow(let name):
            run.record(.init(step: step.id, status: .running, summary: Words.step(step, body: run.body, catalog: catalog), at: clock()))
            if run.mode == .practice {
                run.record(.init(step: step.id, status: .would, summary: L("Would run {flow}", ["flow": name]), at: clock()))
            } else if !store.save(run) {
                return cantSave(step, summary: Words.step(step, body: run.body, catalog: catalog), in: &run)
            } else if let other = store.find(name), other.id != run.flow, other.state == .on {
                // Each keeps to its own, and the runaway stop counts every start, so two can't set each other off for ever.
                _ = start(other, mode: .live, why: L("{flow} set it off.", ["flow": run.flowName]))
                run.record(.init(step: step.id, status: .done, summary: L("Ran {flow}", ["flow": other.name]), at: clock()))
            } else {
                return failed(step, why: L("“{name}” can't run: it isn't on, or there's no other flow by that name.", ["name": name]), reads: false, in: &run)
            }
            run.pc += 1
            store.save(run)
            return true
        }
    }

    private func writing(_ step: Step, prompt: String, in run: inout Run) async -> Bool {
        let filled = String(run.values.fill(prompt).prefix(7000))
        run.record(.init(step: step.id, status: .running, summary: Words.step(step, body: run.body, catalog: catalog), at: clock()))
        store.save(run)
        changed()
        switch await host?.write(filled, label: run.flowName) ?? .refused("off") {
        case .answer(let text, let madeBy):
            run.values.set(step.id, text)
            run.record(.init(step: step.id, status: .done, summary: Words.step(step, body: run.body, catalog: catalog), output: text,
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
        let check = await host?.check(tool, input, plan: run.flowPractice)
        let sentence = Words.resolved(check?.summary ?? Words.step(step, body: run.body, catalog: catalog), values: run.values)
        let readsOnly = catalog.tool(tool)?.readsOnly == true
        if readsOnly, check?.decision == .allow {
            let outcome = await host?.call(tool, input, plan: run.flowPractice, written: nil)
            if let outcome, outcome.ok {
                run.values.set(step.id, outcome.text)
                run.record(.init(step: step.id, status: .done, summary: sentence, output: outcome.text, at: clock()))
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
        run.record(.init(step: step.id, status: .running, summary: sentence, at: clock()))
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
            // What a notice answers ("shown", "held for now") is for a model, not for the person's story.
            run.record(.init(step: step.id, status: .done, summary: step.name ?? said, output: tool == "notify.user" ? nil : outcome.text, at: clock()))
            run.pc += 1
            run.retries = 0
            store.save(run)
            return true
        // Too many actions this minute is one more thing nothing happened over: a flow here has no loops to run into it for long.
        case .denied, .unanswered, .busy:
            // Nothing happened, and only the person can change that.
            run.status = .needs_you
            run.problem = outcome.status == .unanswered ? L("Nobody answered the card for this step, so it didn't run.") : outcome.text.nonEmpty ?? L("This step wasn't allowed, so it didn't run.")
            run.record(.init(step: step.id, status: .needs_you, summary: step.name ?? said, note: run.problem, at: clock()))
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
    private func failed(_ step: Step, why: String, reads: Bool, in run: inout Run, said: String? = nil) -> Bool {
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
            run.pc += 1
            run.retries = 0
            store.save(run)
            return true
        default:
            run.status = .failed
            run.problem = why
            run.record(.init(step: step.id, status: .failed, summary: summary, note: why, at: clock()))
            store.save(run)
            return false
        }
    }

    private func finish(_ run: inout Run) {
        if run.status.isOver {
            run.endedAt = clock()
            active.remove(run.flow)
        }
        if run.status == .needs_you || run.status == .interrupted { active.remove(run.flow) }
        store.save(run)
        changed()
        let ended = run
        Task { await self.tell(ended) }
        if ended.status.isOver || ended.status == .needs_you, let trigger = queued.removeValue(forKey: ended.flow), let flow = store.flow(ended.flow), flow.state == .on {
            start(flow, mode: .live, why: L("It was set off again while it ran."), trigger: trigger)
        }
    }

    /// What the person hears: always when it needs them or failed; a finished run's result in one line, when they asked for that.
    private func tell(_ run: Run) async {
        guard run.mode == .live else { return }
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
            active.insert(run.flow)
            switch run.status {
            case .running:
                let program = FlowProgram(run.body)
                guard run.pc < program.ops.count, case .step(let step) = program.ops[run.pc], run.record(of: step.id)?.status == .running else {
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
                    active.remove(run.flow)
                    let told = run
                    Task { await tell(told) }
                }
            case .waiting:
                break
            default:
                active.remove(run.flow)
            }
        }
        changed()
    }

    /// The way forward from a stop, from the page or a request.
    enum Forward: String, Sendable { case try_again, carry_on, stop }

    func proceed(_ id: String, _ how: Forward) {
        guard var run = store.run(id), !run.status.isOver, run.status != .running else { return }
        switch how {
        case .stop:
            run.status = .stopped
            run.endedAt = clock()
            run.problem = nil
            run.resumeAt = nil
            store.save(run)
            active.remove(run.flow)
            changed()
        case .try_again:
            run.retries = 0
            run.resumeAt = nil
            store.save(run)
            active.insert(run.flow)
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
            run.pc += 1
            run.problem = nil
            run.retries = 0
            run.resumeAt = nil
            store.save(run)
            active.insert(run.flow)
            Task { await advance(id) }
        }
    }

    // MARK: The clock

    /// Called every little while. A Mac asleep or a Sidefolk quit misses its moment, which the flow's rule decides: run once when back, or say it was missed.
    func tick() {
        let now = clock()
        for var flow in store.flows() where flow.state == .on {
            let trigger = flow.running.trigger
            guard let from = flow.lastFire, let due = Schedule.due(trigger, last: from, now: now, calendar: calendar) else { continue }
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
        for flow in store.flows() where flow.state == .on {
            guard case .event(let wanted, let contains) = flow.running.trigger, wanted == name else { continue }
            if let contains, words.range(of: contains, options: [.caseInsensitive, .diacriticInsensitive]) == nil { continue }
            start(flow, mode: .live, why: Words.trigger(flow.running.trigger), trigger: words)
        }
    }

    /// A watch this flow made fired.
    func watchFired(title: String, summary: String) {
        // Only if it's a watch that sets it off now: one that wouldn't stop isn't on the card any more.
        guard let flow = store.flows().first(where: { flow in
            guard flow.state == .on, flow.watchTitle == title, case .watch = flow.running.trigger else { return false }
            return true
        }) else { return }
        start(flow, mode: .live, why: L("The watch saw a change."), trigger: summary)
    }

    func isRunning(_ flow: String) -> Bool { active.contains(flow) }

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
            // It was a watch and isn't now: the watch goes, or it would go on looking.
            add("watch.stop", ["id": oldWatch])
        }
        return steps
    }

    /// Everything the draft may do, as the person will read it.
    func livePlan(_ flow: Flow) -> Plan {
        let steps = Self.planSteps(flow.kept, title: Self.watchTitle(flow), oldWatch: flow.watchTitle)
        // Setting another flow off needs no tool of its own, so the card says it here.
        let others = flow.kept.allSteps.compactMap { step -> String? in if case .flow(let name) = step.kind { name } else { nil } }
        // Sidefolk shows so much of this and no more. What a flow sets off appears nowhere else on the card, so a long address gives way to it.
        let said = Words.trigger(flow.kept.trigger)
        var when = said.count > Self.longestTriggerWords ? said.prefix(Self.longestTriggerWords) + "…" : said
        if flow.kept.allSteps.contains(where: { if case .ai = $0.kind { true } else { false } }) {
            when = L("{when}. What its steps read goes to your AI, to write from.", ["when": when])
        }
        if !others.isEmpty { when = L("{when}. Also sets off: {flows}", ["when": when, "flows": others.joined(separator: ", ")]) }
        return Plan(id: flow.planId, title: flow.name, when: when, steps: steps)
    }

    static let longestTriggerWords = 160

    /// There's something to read before it runs by itself. Only a flow someone starts by hand that does nothing but work on its own values has nothing to say.
    static func needsCard(_ body: FlowBody) -> Bool {
        if case .manual = body.trigger {} else { return true }
        return !planSteps(body, title: "").isEmpty || body.allSteps.contains { switch $0.kind { case .flow, .ai: true; default: false } }
    }

    /// It would run by itself with nothing the person allowed behind it. One with only actions has them checked at each call, so it can't.
    func nobodyRead(_ flow: Flow) -> Bool {
        guard Self.needsCard(flow.running), catalog.plan(flow.planId) == nil else { return false }
        return Self.planSteps(flow.running, title: Self.watchTitle(flow)).isEmpty
            || flow.running.allSteps.contains { switch $0.kind { case .ai, .flow: true; default: false } }
    }

    /// Flows that went on before a schedule or an AI step needed a card. Nobody read what these do, so they ask once, now, rather than go on as they were.
    func pauseWhatNobodyRead() {
        guard catalog.loadedAt != nil else { return }
        for var flow in store.flows() where flow.state == .on && nobodyRead(flow) {
            flow.state = .paused
            flow.pausedBecause = L("It now asks before running by itself. Resume it to read what it does.")
            store.save(flow)
            let told = flow
            Task { await host?.notify(title: L("{flow} is paused", ["flow": told.name]), body: told.pausedBecause, attention: false) }
        }
        changed()
    }

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
        if let wrong = flow.kept.unfinished {
            flow.startProblem = wrong
            store.save(flow)
            return changed()
        }
        flow.startProblem = nil
        store.save(flow)
        changed()
        let plan = livePlan(flow)
        // What they read is what goes live: anything changed while the card waits stays in the draft.
        let reviewed = flow.kept, reviewedTitle = Self.watchTitle(flow)
        Task {
            let answer: Plans.Answer? = Self.needsCard(reviewed) ? await host?.approve(plan) : .allowed(standing: [])
            guard let answer, var current = store.flow(id) else { return }
            switch answer {
            case .allowed:
                let oldWatch = current.watchTitle, wasLive = current.live, wasOn = current.state == .on
                current.live = reviewed
                current.state = .on
                current.pausedBecause = nil
                current.lastFire = clock()
                current.startProblem = nil
                store.save(current)
                // A new name too: the card's lines go by it, and every call to the watch from now on has to fit them.
                if oldWatch != nil, oldWatch != reviewedTitle || !Self.watchInputs(was: wasLive, now: reviewed) {
                    await replaceWatch(id, stopping: oldWatch)
                } else if oldWatch == nil, case .watch = reviewed.trigger {
                    await makeWatch(id)
                } else if !wasOn || current.watchOutdated {
                    // Paused, or on its way out: approving an edit is what brings it back, the same as Resume.
                    await resumeWatch(current)
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
        if let wrong = flow.running.unfinished {
            flow.startProblem = wrong
            store.save(flow)
            return changed()
        }
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
        store.remove(flow: id)
        host?.forgetPlan(flow.planId)
        host?.forgetPlan(flow.practiceId)
        changed()
        Task { await stopWatch(flow) }
    }

    private func stopWatch(_ flow: Flow) async {
        guard let title = flow.watchTitle else { return }
        _ = await host?.call("watch.stop", ["id": title], plan: flow.planId, written: nil)
    }

    private func pauseWatch(_ flow: Flow) async {
        // One on its way out is stopped, not paused: the plan has no line for that.
        guard let title = flow.watchTitle, case .watch = flow.running.trigger, !flow.watchOutdated else { return }
        _ = await host?.call("watch.pause", ["id": title], plan: flow.planId, written: nil)
    }

    private func resumeWatch(_ flow: Flow) async {
        guard let title = flow.watchTitle else {
            // It never started: what they've just put right is what stopped it.
            if case .watch = flow.running.trigger { await makeWatch(flow.id) }
            return
        }
        // Left over from a version that's no longer on: this is the try again the page offers.
        var isWatch = false
        if case .watch = flow.running.trigger { isWatch = true }
        guard isWatch, !flow.watchOutdated else { return await replaceWatch(flow.id, stopping: title) }
        let back = await host?.call("watch.resume", ["id": title], plan: flow.planId, written: nil)
        guard back?.ok != true, var current = store.flow(flow.id) else { return }
        // Only what's really not there is made again: a second of the same name would leave neither reachable by name.
        guard back?.notFound == true else {
            switch back?.status {
            case .denied?, .unanswered?, .busy?:
                // Nothing happened: saying On would be a flow that never fires.
                current.startProblem = back?.text.nonEmpty ?? L("The watch didn't start.")
                current.state = .paused
            default:
                current.startProblem = L("Sidefolk didn't say whether its watch started again. If it doesn't fire, pause and resume it.")
            }
            store.save(current)
            return changed()
        }
        current.watchTitle = nil
        store.save(current)
        await makeWatch(flow.id)
    }

    /// Whether the watch made for the old version is the one the new version wants. A different address is a new watch.
    private static func watchInputs(was: FlowBody?, now: FlowBody) -> Bool {
        guard case .watch(let old)? = was?.trigger, case .watch(let new) = now.trigger else { return false }
        return JSONText.write(watchInput(old, title: "")) == JSONText.write(watchInput(new, title: ""))
    }

    /// One name, one watch: the old one goes first, or a second of the same name would leave neither reachable and the old one still looking. Everything's read again
    /// after each wait: the flow may have been paused or deleted meanwhile.
    private func replaceWatch(_ id: String, stopping title: String?) async {
        guard let title, let flow = store.flow(id) else { return }
        let stopped = await host?.call("watch.stop", ["id": title], plan: flow.planId, written: nil)
        guard var after = store.flow(id) else { return }
        guard stopped?.ok == true || stopped?.notFound == true else {
            after.watchOutdated = true
            after.state = .paused
            after.startProblem = L("Its old watch didn't stop, so this flow is paused. Resume it to try again.")
            store.save(after)
            return changed()
        }
        after.watchTitle = nil
        after.watchOutdated = false
        after.startProblem = nil
        store.save(after)
        changed()
        await makeWatch(id)
    }

    private func makeWatch(_ id: String) async {
        guard let flow = store.flow(id), flow.state == .on, case .watch(let w) = flow.running.trigger else { return }
        let title = Self.watchTitle(flow)
        let made = await host?.call("watch.create", Self.watchInput(w, title: title), plan: flow.planId, written: nil)
        guard var after = store.flow(id) else {
            // Deleted while this was asking: what it just made has nobody else to stop it.
            if made?.ok == true { _ = await host?.call("watch.stop", ["id": title], plan: nil, written: nil) }
            return
        }
        if made?.ok == true {
            after.watchTitle = title
        } else {
            // Saying On here would be a flow that never fires.
            after.startProblem = made?.text.nonEmpty ?? L("The watch didn't start.")
            after.state = .paused
        }
        store.save(after)
        changed()
        if made?.ok == true, after.state == .paused { await pauseWatch(after) }
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
        case .flow: false
        }
    }
}
