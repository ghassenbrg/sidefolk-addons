import Foundation
import SidefolkExtensionKit

/// What the engine needs of Sidefolk; tests script it.
@MainActor protocol FlowHost: AnyObject {
    /// `written`: the call before words were filled in, for History to keep instead of them.
    func call(_ tool: String, _ input: [String: Any], plan: String?, written: [String: Any]?) async -> Actions.Outcome
    func check(_ tool: String, _ input: [String: Any], plan: String?) async -> Actions.Check?
    func write(_ prompt: String, label: String) async -> AI.Result
    func approve(_ plan: Plan) async -> Plans.Answer
    func checkPlan(_ plan: Plan) async -> Plans.Checked?
    func forgetPlan(_ id: String)
    func notify(title: String, body: String?, attention: Bool) async
    /// A call for a run: it can be followed while it's under way, and asked to stop.
    func call(_ tool: String, _ input: [String: Any], plan: String?, written: [String: Any]?, run: String, progress: @escaping (Actions.Progress) -> Void) async -> Actions.Outcome
    func cancel(run: String)
}

extension FlowHost {
    func call(_ tool: String, _ input: [String: Any], plan: String?, written: [String: Any]?, run: String, progress: @escaping (Actions.Progress) -> Void) async -> Actions.Outcome {
        await call(tool, input, plan: plan, written: written)
    }
    func cancel(run: String) {}
    func checkPlan(_ plan: Plan) async -> Plans.Checked? { nil }
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
    static let retriesAtMost = 3
    /// Runs in an hour past which a flow is paused and the person told: something set off that shouldn't be.
    static let runawayPerHour = 30
    var runawayLimit = Engine.runawayPerHour
    /// Called after anything a page shows changed.
    var changed: () -> Void = {}

    private var active: Set<String> = []
    /// One more wanted while it runs, with what set it off.
    private var queued: [String: String?] = [:]
    var resuming: Set<String> = []
    /// Started this time round: `recover` is for what the last time left behind.
    var startedHere: Set<String> = []
    private var aiInUse = false
    private var aiWaiting: [CheckedContinuation<Void, Never>] = []
    /// Watches being made: a card can be up for one, and pausing and resuming meanwhile would ask for a second of the same name.
    private var makingWatch: Set<String> = []
    /// How many starts were cleared so far by the person stopping a run: more can arrive while a slow step finishes, and go the same way. Not kept: it's only news now.
    private var clearedOnStop: [String: Int] = [:]
    /// What was approved with no card, because nothing in it was new. Not kept: it's only news now.
    private var quietlyApproved: [String: FlowBody] = [:]
    /// How far along the step under way is, by run, while it says. Not kept: it's only true now.
    private(set) var progress: [String: Actions.Progress] = [:]

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
        guard !store.flowsFileIsHeld, store.flow(flow.id) != nil else { return nil }
        if mode == .live || setOff, pauseIfBlank(flow) { return nil }
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
                      // Practice tries what's on the page. A run for real uses what was kept: "only here so far" means that.
                      body: mode == .live || setOff ? flow.running : mode == .once ? flow.kept : flow.draft)
        run.values.today = Format.date(now, year: true, weekday: true)
        run.values.now = Format.time(now)
        if let trigger { run.values.set("trigger", trigger) }
        if mode == .practice, trigger == nil, let sample = run.body.triggerSample { run.values.set("trigger", sample) }
        run.setOff = setOff
        // It would fail there, after what comes before it has been done.
        if mode != .practice, let off = run.body.allSteps.lazy.compactMap({ step -> String? in
            guard case .call(let name, _) = step.kind, let other = self.store.named(name), other.id != flow.id, other.state != .on else { return nil }
            return name
        }).first {
            run.status = .failed
            run.problem = L("“{name}” isn't on, so it can't run by itself.", ["name": off])
            active.insert(flow.id)
            finish(&run)
            return run
        }
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
            // Asked to pause: here, between steps, where nothing is half done.
            if store.takeStop(Self.pauseKey(id)) {
                run.status = .waiting
                run.paused = true
                store.save(run)
                finish(&run)
                return
            }
            switch program.ops[run.pc] {
            case .jump(let to):
                run.pc = to
            case .branch(let step, let condition, let otherwise):
                let unknown = run.values.undecided(condition)
                let why = unknown.map { L("It looks at “{name}”, which is empty or isn't there this time, so it can't tell which way to go.", ["name": $0]) }
                // A practice goes on, and says so: that's what it's for.
                if let why, run.mode != .practice {
                    guard failed(step, why: why, reads: false, in: &run) else {
                        finish(&run)
                        return
                    }
                    break
                }
                let holds = condition.holds(run.values)
                run.record(.init(step: step.id, status: .done, summary: Words.branch(condition, holds: holds, body: run.body, catalog: catalog), note: why, at: clock()))
                run.pc = holds ? run.pc + 1 : otherwise
                store.save(run)
            case .step(let written):
                // The steps as they stand: a flow this one names may have been renamed since it started.
                let step = store.run(id)?.body.step(written.id) ?? written
                guard await perform(step, in: &run) else {
                    // Asked to stop while this was under way, a card up, say: it stops here, rather than waiting for an answer it no longer wants.
                    if store.takeStop(id) {
                        for child in run.waitingOn { stop(run: child) }
                        run.status = .stopped
                        run.problem = nil
                        run.resumeAt = nil
                        run.form = nil
                        run.connection = nil
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
                if case .repeatUntil(let until, _, _) = step.kind {
                    guard nextInRepeat(step, until: until, in: &run) else {
                        finish(&run)
                        return
                    }
                } else {
                    nextInLoop(step, in: &run)
                }
            case .choose(let step, let targets, let otherwise):
                guard case .choose(let value, let paths, _) = step.kind else { break }
                if let why = step.saysNothing ?? run.values.stopsFor([value], practice: run.mode == .practice).map(run.values.whyMissing) {
                    guard failed(step, why: why, reads: false, in: &run) else {
                        finish(&run)
                        return
                    }
                    break
                }
                // Past the check, anything missing is a field of a sample: what this way goes by isn't known, and the record says that.
                let seen = run.values.missing(in: [value]).isEmpty ? run.values.fill(value).trimmed : L("(sample)")
                // A path that's exactly what it is, before one it only mentions.
                let written = paths.indices.filter { paths[$0].when.trimmed == run.values.fill(paths[$0].when).trimmed }
                let way = written.first { paths[$0].when.trimmed.compare(seen, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame } ?? written.first { Condition.mentions(seen, paths[$0].when) }
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
        // Reached only by a flow that went on before this was marked: nothing goes to the AI or the person for a step that says nothing.
        if let wrong = step.saysNothing { return failed(step, why: wrong, reads: false, in: &run) }
        // Sidefolk checks an action against what they read last at each call. Nothing checks these two, so it's looked at here: a run under way when they approved an edit that took one out.
        // Not a call coming back with its answer: that already ran.
        if run.waitingOn.isEmpty, isLeftBehind(step, in: run) {
            run.status = .needs_you
            run.problem = L("You approved another version of this flow while this run was under way, and this step isn't in it as it was, so it didn't run. Skip it or stop here.")
            run.record(.init(step: step.id, status: .needs_you, summary: step.name ?? Words.step(step, body: run.body, catalog: catalog), note: run.problem, at: clock()))
            store.save(run)
            return false
        }
        if let name = run.values.stopsFor(step.needsThere, practice: run.mode == .practice) {
            return failed(step, why: run.values.whyMissing(name), reads: false, in: &run)
        }
        // A real action sent a blank where it needs a value could do anything with it.
        if case .action(let tool, let input) = step.kind, run.mode != .practice, let name = catalog.nothingFor(tool, input, from: run.values) {
            return failed(step, why: L("It uses “{name}”, which came back with nothing in it.", ["name": name]), reads: false, in: &run)
        }
        // Before it's done: for a repeat, which can't tell from a value alone what going round would do again.
        if step.doesSomething(catalog) { for i in run.frames.indices { run.frames[i].wrote = true } }
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
            if run.mode == .practice, run.values.pretends(data.from) || run.values.pretends(data.than ?? "") {
                run.values.set(step.id, L("(sample)"))
                run.record(.init(step: step.id, status: .would, summary: L("Would: {what}", ["what": Words.step(step, body: run.body, catalog: catalog)]), output: L("(sample)"), at: clock()))
                run.pc += 1
                store.save(run)
                return true
            }
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
        case .forEach, .repeatUntil, .choose, .attempt:
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
            // Back or not, a wait that ran out is for the person: it could be weeks since they read the card.
            let ranOut = run.connection.map { $0.tool == tool && $0.until <= clock() } ?? false
            if run.mode != .practice, ranOut || Connections.isMissing(tool, catalog) { return waitingForConnection(step, tool: tool, in: &run) }
            run.connection = nil
            let filled = catalog.filled(tool, input, from: run.values)
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
            } else if let other = store.named(name), other.id != run.flow, other.state == .on {
                // Each keeps to its own, and the runaway stop counts every start, so two can't set each other off for ever.
                // A run from a draft was never read on a card: what it sets off asks on cards too, not under its own plan.
                let started = start(other, mode: run.mode == .once ? .once : .live, why: L("{flow} set it off.", ["flow": run.flowName]), setOff: true)
                // Starting it can be what pauses it: too often, or a step that says nothing. One waiting its turn is still on.
                guard store.flow(other.id)?.state == .on else {
                    return failed(step, why: L("“{name}” can't run: it isn't on, or there's no other flow by that name.", ["name": name]), reads: false, in: &run)
                }
                if let started, started.status.isOver, let why = started.problem { return failed(step, why: why, reads: false, in: &run) }
                if let started { run.setOffRuns.append(started.id) }
                run.record(.init(step: step.id, status: .done, summary: started != nil ? L("Ran {flow}", ["flow": other.name]) : run.mode == .once && isRunning(other.id) ? L("{flow} was already running, so it didn't start", ["flow": other.name]) : L("{flow} was already running or held back, so its own rule for that decides", ["flow": other.name]), at: clock()))
            } else {
                return failed(step, why: L("“{name}” can't run: it isn't on, or there's no other flow by that name.", ["name": name]), reads: false, in: &run)
            }
            run.pc += 1
            store.save(run)
            return true
        }
    }

    /// Sidefolk takes one AI request at a time from an extension and refuses a second, so lanes and other flows take turns here.
    func askingAI(_ prompt: String, label: String) async -> AI.Result {
        if aiInUse { await withCheckedContinuation { aiWaiting.append($0) } }
        aiInUse = true
        defer {
            if aiWaiting.isEmpty { aiInUse = false } else { aiWaiting.removeFirst().resume() }
        }
        return await host?.write(prompt, label: label) ?? .refused("off")
    }

    private func writing(_ step: Step, prompt: String, in run: inout Run, secondLook: Bool = false) async -> Bool {
        let filled = String(run.values.fill(prompt).prefix(7000))
        run.record(.init(step: step.id, status: .running, summary: Words.step(step, body: run.body, catalog: catalog), at: clock()))
        store.save(run)
        changed()
        let asked = step.fields.map { filled + "\n\n" + AIFields.instruction($0) } ?? filled
        switch await askingAI(asked, label: run.flowName) {
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
    private func setSample(_ step: Step, tool: String, words: String = L("(sample)"), in run: inout Run) {
        let fields = catalog.tool(tool)?.outputFields ?? []
        if fields.isEmpty {
            run.values.set(step.id, words)
        } else {
            run.values.set(step.id, answer: words, fields: JSONText.write(Dictionary(uniqueKeysWithValues: fields.map { ($0, L("(sample)") as Any) })))
        }
    }

    private func practicing(_ step: Step, tool: String, input: [String: Any], in run: inout Run) async -> Bool {
        if let sample = step.sample {
            // A sample that's a record says what it holds. Words say what it said, and what the tool gives beside them is still pretended.
            if case .object = Values.structured(.string(sample)) { run.values.set(step.id, sample) } else { setSample(step, tool: tool, words: sample, in: &run) }
            run.record(.init(step: step.id, status: .would, summary: L("Would: {what}", ["what": Words.step(step, body: run.body, catalog: catalog)]), output: sample, note: L("Pretending it gave what you wrote for practice."), at: clock()))
            run.pc += 1
            store.save(run)
            return true
        }
        // Made-up values: there's nothing true to ask Sidefolk about, and a real read with one would find something else.
        if step.usedTexts.contains(where: run.values.pretends) {
            run.record(.init(step: step.id, status: .would, summary: L("Would: {what}", ["what": Words.step(step, body: run.body, catalog: catalog)]), note: L("It would use what an earlier step gave, and practice only pretended that."), at: clock()))
            setSample(step, tool: tool, in: &run)
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
                run.values.set(step.id, answer: outcome.text, fields: outcome.data)
                run.record(.init(step: step.id, status: .done, summary: sentence, output: outcome.text.clipped(Self.keptOutput), at: clock()))
                run.pc += 1
                store.save(run)
                return true
            }
            let note = outcome?.text.nonEmpty ?? L("It didn't work.")
            run.record(.init(step: step.id, status: .failed, summary: sentence, note: note, at: clock()))
            setSample(step, tool: tool, in: &run)
            run.pc += 1
            store.save(run)
            return true
        }
        let note: String? = switch check?.decision {
        case .deny?: check?.why ?? L("Sidefolk wouldn't allow this.")
        case nil, .unknown?: (Connections.isMissing(tool, catalog) ? Connections.id(of: tool) : nil).map { L("It needs {name}, which isn't here now.", ["name": Connections.title($0, catalog, store)]) } ?? L("Sidefolk doesn't offer this now.")
        default: readsOnly ? L("It would read this; you didn't allow it for practice.") : nil
        }
        run.record(.init(step: step.id, status: check?.decision == .deny || check == nil ? .failed : .would, summary: L("Would: {what}", ["what": sentence]), note: note, at: clock()))
        // What a menu offered shouldn't stop a run for having only pretended.
        setSample(step, tool: tool, in: &run)
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
        let id = run.id
        // "Try again" is the person asking, so its calls are counted afresh.
        let counted = run.triedAgain == 0 ? id : "\(id)-\(run.triedAgain)"
        let outcome = await host?.call(tool, input, plan: plan, written: written, run: counted, progress: { [weak self] in
            self?.progress[id] = $0
            self?.changed()
        }) ?? Actions.Outcome(status: .lost, text: "", summary: "", untrusted: false, standing: false)
        progress[id] = nil
        let said = outcome.summary.nonEmpty.map { Words.resolved($0, values: run.values) } ?? sentence
        switch outcome.status {
        case .ok:
            run.values.set(step.id, answer: outcome.text, fields: outcome.data)
            // Cut for keeping: it says so, rather than a list that looks whole.
            let cut = outcome.text.count > Values.wordsKept ? L("Its answer was long: only the first {count} characters were kept.", ["count": Format.integer(Values.wordsKept)]) : nil
            // What a notice answers ("shown", "held for now") is for a model, not for the person's story.
            run.record(.init(step: step.id, status: .done, summary: step.name ?? said, output: tool == "notify.user" ? nil : outcome.text.clipped(Self.keptOutput), note: cut, at: clock()))
            run.pc += 1
            run.retries = 0
            store.save(run)
            return true
        // Told it's gone though the list says it's here, it left since the last look.
        case .unavailable where Connections.id(of: tool).map { catalog.tool(tool) != nil || !catalog.offers(connection: $0) } == true:
            return waitingForConnection(step, tool: tool, in: &run)
        case .denied, .unanswered, .unavailable:
            // Nothing happened, and only the person can change that.
            run.status = .needs_you
            run.problem = outcome.status == .unanswered ? L("Nobody answered the card for this step, so it didn't run.") : outcome.text.nonEmpty ?? L("This step wasn't allowed, so it didn't run.")
            run.record(.init(step: step.id, status: .needs_you, summary: step.name ?? said, note: run.problem, at: clock()))
            store.save(run)
            return false
        case .capped:
            // The limit the card said. Nothing happened, and going on would only be refused again until the person looks.
            let why = outcome.limit == "day" ? L("It reached the limit you allowed for a day, so it stopped. Nothing more was sent.")
                : L("It reached the limit you allowed for one run, so it stopped. Nothing more was sent.")
            if var flow = store.flow(run.flow), flow.state == .on {
                flow.state = .paused
                flow.pausedBecause = why
                store.save(flow)
                // Paused, not stopped: Resume brings the same watch back.
                Task { await pauseWatch(flow) }
            }
            // Not a failure a try or "carry on" gets past: the person said this much and no more.
            run.frames = []
            run.status = .failed
            run.problem = why
            run.record(.init(step: step.id, status: .failed, summary: step.name ?? said, note: why, at: clock()))
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
        // The last that has something to say: a loop's insides are gone by its end, and a path not taken never made anything.
        if run.output == nil, run.status == .done, let last = run.values.lastAnswer(of: run.body.allSteps) { run.output = last }
        if run.status.isOver, store.takeStop(Self.personStopKey(run.id)) {
            let all = (clearedOnStop.removeValue(forKey: run.id) ?? 0) + clearQueue(of: run.flow)
            if run.status == .stopped, all > 0 { run.problem = L(one: "Stopped. {count} start waiting its turn was cleared.", other: "Stopped. {count} starts waiting their turn were cleared.", count: all) }
        }
        if run.status.isOver {
            run.endedAt = clock()
            _ = store.takeStop(run.id)
            _ = store.takeStop(Self.pauseKey(run.id))
            if holds { active.remove(run.flow) }
        }
        if holds, run.status == .needs_you || run.status == .interrupted { active.remove(run.flow) }
        // It stopped by itself and the person chooses from there: a pause asked for before isn't the answer to that.
        if run.status == .needs_you || run.status == .interrupted { _ = store.takeStop(Self.pauseKey(run.id)) }
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
            // The first is the card's default, what happens if they just press on: never doing it twice.
            ? [(L("Stop here"), .stop), (L("It did: carry on"), .carry_on), (L("It didn't: try again"), .try_again)]
            // Left behind by an edit, going on means more of a version they replaced: stopping comes first, and trying again would ask the same.
            : stepLeftBehind(run) ? [(L("Stop here"), .stop), (L("Skip this step"), .carry_on)]
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
                run.connection = nil
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
                    _ = store.takeStop(Self.pauseKey(run.id))
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
        if how == .stop { return stop(run: id, byThePerson: true) }
        guard let current = store.run(id), !current.status.isOver, current.status != .running, !store.isHeldBack(flow: current.flow) else { return }
        // A form or another run is what it's waiting for: going past that isn't anyone's to choose from here.
        guard var run = store.run(id), run.form == nil, run.waitingOn.isEmpty else { return }
        run.paused = false
        switch how {
        case .stop:
            break
        case .try_again:
            run.retries = 0
            run.triedAgain += 1
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
            run.connection = nil
            store.save(run)
            if run.parent == nil { active.insert(run.flow) }
            Task { await advance(id) }
        }
    }

    static func pauseKey(_ id: String) -> String { "pause:\(id)" }
    static func personStopKey(_ id: String) -> String { "person:\(id)" }

    /// Stops it at the next step, kept where it is. Nothing is cut short: the step under way finishes.
    func pause(run id: String) {
        guard let run = store.run(id), run.status == .running else { return }
        store.askStop(Self.pauseKey(id))
        changed()
    }

    /// Whether a run that ended can go on from where it ended: only from a step in the flow's main line, because a loop's place isn't kept once it's over, and only from
    /// what's still what it ran.
    func canGoOn(from run: Run) -> Bool {
        guard run.status == .failed || run.status == .stopped, run.mode == .live, run.parent == nil, let flow = store.flow(run.flow), !isRunning(run.flow) else { return false }
        // What it ran is what's still approved.
        guard run.body == flow.live else { return false }
        let program = FlowProgram(run.body)
        guard run.pc < program.ops.count, case .step(let step) = program.ops[run.pc] else { return false }
        // It may have happened: doing it again is the person's to decide knowing that, on the run's own page, not a button's to assume.
        guard run.record(of: step.id)?.status != .unknown else { return false }
        // Another run did that part, and may still be at it or have done some: going from here would do it all a second time.
        switch step.kind {
        case .call, .parallel: return false
        default: break
        }
        return run.body.steps.contains { $0.id == step.id }
    }

    /// The steps that would run again from where it ended, and what's kept from before: what the person weighs up before pressing it.
    func stepsFromHere(_ run: Run) -> [Step] {
        let program = FlowProgram(run.body)
        guard run.pc < program.ops.count, case .step(let step) = program.ops[run.pc], let at = run.body.steps.firstIndex(where: { $0.id == step.id }) else { return [] }
        return Array(run.body.steps[at...])
    }

    /// A new run: from the start with what set it off the last time, or from where the last one ended with what it had made. The person asked, so nothing here is by itself,
    /// and each action goes through Sidefolk as any does.
    func runAgain(_ id: String, fromHere: Bool) -> Run? {
        guard let old = store.run(id), old.status.isOver, old.parent == nil, let flow = store.flow(old.flow) else { return nil }
        guard fromHere else {
            let trigger = old.values.named["trigger"].map(Values.text)
            // A practice is a look at the draft. Anything else goes by what stands: if it's changed since, that's Run's to ask about.
            if old.mode == .practice { return start(flow, mode: .practice, why: L("You ran it again."), trigger: trigger) }
            guard flow.live != nil, flow.live == flow.kept, !flow.hasUnsaved else {
                Task { await runNow(flow.id, why: L("You ran it again."), trigger: trigger) }
                return nil
            }
            return start(flow, mode: .live, why: L("You ran it again."), trigger: trigger)
        }
        guard canGoOn(from: old), let started = start(flow, mode: old.mode, why: L("You tried again from where it ended.")) else { return nil }
        // The start's own walk hasn't begun: it picks up from here instead.
        guard var run = store.run(started.id) else { return nil }
        let (today, now) = (run.values.today, run.values.now)
        run.values = old.values
        (run.values.today, run.values.now) = (today, now)
        run.pc = old.pc
        let again = Set(FlowBody(steps: stepsFromHere(old)).allSteps.map(\.id))
        run.records = old.records.filter { !again.contains($0.step) }
        store.save(run)
        return run
    }

    // MARK: The clock

    /// Flows that went on before a schedule or an AI step needed a card. Nobody read what these do, so they ask once, now, rather than go on as they were.
    func pauseWhatNobodyRead() {
        guard catalog.loadedAt != nil else { return }
        for var flow in store.flows() where flow.state == .on && nobodyRead(flow) {
            flow.state = .paused
            flow.pausedBecause = L("It now asks before running by itself. Resume it to read what it does.")
            store.save(flow)
            for run in store.unfinished() where run.flow == flow.id && run.mode != .practice { stop(run: run.id) }
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

    /// Called every little while. A Mac asleep or a Sidefolk quit misses its moment, which the flow's rule decides: run once when back, or say it was missed.
    func tick() {
        guard !store.flowsFileIsHeld else { return }
        let now = clock()
        for var flow in store.flows() where flow.state == .on {
            var clock = calendar
            if let zone = flow.running.timeZone.flatMap(TimeZone.init(identifier:)) { clock.timeZone = zone }
            let due = flow.running.triggers.compactMap { trigger in flow.countsFrom(trigger).flatMap { Schedule.due(trigger, last: $0, now: now, calendar: clock) }.map { (trigger: trigger, latest: $0.latest) } }
            guard let latest = due.map(\.latest).max() else { continue }
            // What hasn't come round yet goes on counting from where it was.
            for case .every(let minutes, _) in flow.running.triggers where flow.lastEvery[minutes] == nil { flow.lastEvery[minutes] = flow.lastFire }
            flow.lastFire = max(flow.lastFire ?? latest, latest)
            var starts: [String] = []
            for one in due {
                if case .every(let minutes, _) = one.trigger { flow.lastEvery[minutes] = one.latest }
                let late = now.timeIntervalSince(one.latest) > Schedule.onTime
                if late, !Schedule.catchesUp(one.trigger) {
                    flow.missed = Array((flow.missed + [one.latest]).suffix(8))
                    continue
                }
                starts.append(late ? L("Meant for {time}; Sidefolk or your Mac was off then.", ["time": Format.dateTime(one.latest)]) : Words.trigger(one.trigger))
            }
            store.save(flow)
            // Two ways due together are still one moment: it runs for the first, however many said so.
            if let why = starts.first { start(flow, mode: .live, why: why) }
        }
        // One the person paused goes on when they say, whatever it was waiting for before.
        for run in store.unfinished() where run.status == .waiting && !run.paused {
            // Back: the same step goes now. Whether it may is still Sidefolk's to say, by the same plan or a card.
            // Unless it's been paused: what goes by itself waits for Resume, as it would to start.
            if let waited = run.connection, !Connections.isMissing(waited.tool, catalog), waited.until > now, !heldByPause(run) {
                Task { await advance(run.id) }
            } else if let at = run.resumeAt, at <= now {
                Task { await advance(run.id) }
            }
        }
    }

    /// Something happened in Sidefolk: every On flow waiting for it goes.
    func happened(name: String, title: String?, detail: String?, id: String? = nil) {
        // Told twice is still once: a restart of either side mustn't run things again.
        if let id, !store.firstTimeSeeing(event: id) { return }
        let words = [title, detail].compactMap(\.self).joined(separator: "\n")
        wakeWaiting(name: name, words: words)
        for flow in store.flows() where flow.state == .on {
            // One happening starts it once, however many of its ways match.
            let matching = flow.running.triggers.first { trigger in
                guard case .event(let wanted, let contains) = trigger, wanted == name else { return false }
                return contains.map { words.range(of: $0, options: [.caseInsensitive, .diacriticInsensitive]) != nil } ?? true
            }
            guard let matching else { continue }
            start(flow, mode: .live, why: Words.trigger(matching), trigger: words)
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

    func queuedCount(_ flow: String) -> Int { (queued[flow] == nil ? 0 : 1) + (store.flow(flow)?.waitingStarts.count ?? 0) }

    /// Stops a run the person is looking at, and any it waits for. A step under way is told to stop, and the run stays "stopping" until it answers; its answer can only say it may or may not have happened.
    /// How many starts were waiting, now none.
    private func clearQueue(of id: String) -> Int {
        var cleared = queued.removeValue(forKey: id) == nil ? 0 : 1
        if var flow = store.flow(id), !flow.waitingStarts.isEmpty {
            cleared += flow.waitingStarts.count
            flow.waitingStarts = []
            store.save(flow)
        }
        return cleared
    }

    /// `byThePerson`: their word means nothing writes after it, so it ends all of what this run is part of, the lanes beside it too, and no try or "go on with the rest" gets past it.
    /// A flow paused or its approval ended stops a run for its own reasons, which is a failure for whatever called it.
    func stop(run id: String, byThePerson: Bool = false) {
        // Even from a run that's just ended: its page can still show Stop, and what it was part of is what they mean.
        if byThePerson {
            var top = id, above = store.run(id)?.parent, seen: Set<String> = [id]
            // A damaged file can't send this round for ever.
            while let here = above, seen.insert(here).inserted, let holder = store.run(here) {
                if !holder.status.isOver { top = here }
                above = holder.parent
            }
            // What's waiting its turn goes too: stopping a flow that then starts again isn't stopping it.
            if let root = store.run(top), !root.status.isOver, root.mode != .practice {
                // On disk: a restart before the step comes back still ends it this way.
                store.askStop(Self.personStopKey(top))
                clearedOnStop[top, default: 0] += clearQueue(of: root.flow)
            }
            if top != id { stop(run: top) }
        }
        guard var run = store.run(id), !run.status.isOver else { return }
        for child in run.waitingOn { stop(run: child) }
        // A run held back has no walk to notice a stop, so it ends here.
        if run.status == .running, !store.isHeldBack(flow: run.flow) {
            store.askStop(id)
            // A card goes away and nothing happens; a tool under way is told, and what it answers says whether it may have happened.
            host?.cancel(run: id)
        } else {
            // What it was waiting for was under way, and may have done something by now.
            let program = FlowProgram(run.body)
            if !run.waitingOn.isEmpty, run.pc < program.ops.count, case .step(let step) = program.ops[run.pc] {
                run.record(.init(step: step.id, status: .unknown, summary: Words.step(step, body: run.body, catalog: catalog), at: clock()))
            }
            run.status = .stopped
            run.problem = nil
            run.resumeAt = nil
            run.form = nil
            run.connection = nil
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
        var seen = Set<String>(), names = Set<String>()
        func add(_ tool: String, _ input: [String: Any]) {
            let key = tool + JSONText.write(input)
            if seen.insert(key).inserted { steps.append(PlanStep(tool, input)) }
        }
        // A name the host can trust to be one step's: it refuses a whole plan over a bad one.
        func name(_ step: Step) -> String? {
            step.id.count <= 60 && !Values.reserved.contains(step.id) && step.id.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_" || $0 == "-") }) && names.insert(step.id).inserted ? step.id : nil
        }
        // What a value is made from, so the host can follow a step's value back to what really gave it. Words written in with it are a source of their own: an edit
        // could change them with no card, so they never count as the person's.
        func sources(_ texts: [String]) -> [String] {
            let named = texts.flatMap(Values.references).filter { !["item", "index"].contains($0) }
            let written = texts.contains { text in !Values.replacingSlots(in: text) { _, _ in "" }.trimmed.isEmpty }
            let looped = texts.flatMap(Values.references).contains("item") ? ["item"] : []
            return Array(Set(named + looped + (written ? [writtenWords] : []))).sorted()
        }
        // The host won't take an empty list or a very long one for a value, and neither says the value is the person's.
        func said(_ reads: [String]) -> [String] { reads.isEmpty || reads.count > mostReads ? [writtenWords] : reads }
        // Every loop's list, as one: `{{item}}` is the one name for them all.
        var lists: [String] = []
        func gatherLists(_ held: [Step]) {
            for step in held {
                if case .forEach(let items, _, _, _) = step.kind { lists.append(items) }
                _ = step.mappingParts { gatherLists($0); return $0 }
            }
        }
        gatherLists(body.steps)
        let fromLists = sources(lists)
        // A step called `item` can stand for it at the top level, and that's not what the lists say.
        if !lists.isEmpty { steps.append(.value(named: "item", reads: body.allSteps.contains { $0.id == "item" } ? [writtenWords] : said(fromLists.filter { $0 != "item" }))) }
        func walk(_ held: [Step]) {
            for step in held {
                switch step.kind {
                case .action(let tool, let input): steps.append(PlanStep(tool, input.mapValues(\.any), named: name(step), title: step.name))
                case .ask(let question, let options):
                    var input: [String: Any] = ["question": question, "timeout_seconds": 300]
                    if !options.isEmpty { input["options"] = options }
                    steps.append(PlanStep("ask.user", input, named: name(step), title: step.name))
                case .ai(let prompt):
                    // Too many to name means everything before it, which is what no names says.
                    let reads = sources([prompt]).filter { $0 != writtenWords }
                    steps.append(.ai(named: name(step), title: step.name, reads: reads.count > mostReads ? [] : reads))
                case .flow(let other), .call(let other, _): steps.append(.flow(other, named: name(step), title: step.name))
                case .text(let text):
                    if let as_ = name(step) { steps.append(.value(named: as_, reads: said(sources([text])))) }
                case .data(let data):
                    if let as_ = name(step) { steps.append(.value(named: as_, reads: said(sources([data.from, data.than ?? ""].filter { !$0.isEmpty })))) }
                default: break
                }
                var inside: [Step] = []
                _ = step.mappingParts { inside += $0; return $0 }
                walk(inside)
                // What a loop or a repeat gives comes from what's in it.
                switch step.kind {
                case .forEach, .repeatUntil:
                    let made = FlowBody(steps: inside).allSteps.filter(\.hasOutput).map(\.id)
                    if !made.isEmpty, let as_ = name(step) { steps.append(.value(named: as_, reads: said(made))) }
                default: break
                }
            }
        }
        walk(body.steps)
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

    /// The steps whose values are the person's own answer. Believed from this pack, so it says no more than it knows; what's built from these says what it reads on its own row.
    /// A name that means something else in a loop or a try isn't one.
    static func inside(_ body: FlowBody) -> [String] {
        body.allSteps.filter { step in
            if case .form = step.kind { return !Values.reserved.contains(step.id) }
            return false
        }.map(\.id)
    }

    /// What a value is said to read when words were written into it: no step can be called this, so it counts as from outside.
    static let writtenWords = "written-words"
    /// The most a step can say it reads: the host's limit. Past it, say it's from outside rather than be refused.
    static let mostReads = 32

    /// The most calls one run of these can make, for the card to say and Sidefolk to hold it to.
    static func callsPerRun(_ steps: [Step]) -> Int {
        steps.reduce(0) { total, step in
            let inner: Int = switch step.kind {
            case .action, .ask: step.onFailure == .retry ? retriesAtMost + 1 : 1
            case .forEach(_, let limit, _, let inside): limit * callsPerRun(inside)
            case .repeatUntil(_, let times, let inside): times * callsPerRun(inside)
            default: {
                var held: [Step] = []
                _ = step.mappingParts { held += $0; return $0 }
                return callsPerRun(held)
            }()
            }
            return min(total + inner, Plans.mostPerRun)
        }
    }

    /// Enough for what it's set to do in a day, so that the limit stops something gone wrong and not the flow doing as it was told.
    static func callsPerDay(_ body: FlowBody, perRun: Int, goesRound: Bool) -> Int {
        let runs = body.triggers.reduce(0) { total, trigger in
            switch trigger {
            case .every(let minutes, _): total + 1440 / max(minutes, 1)
            // What sets these off isn't known: as many as the hourly stop would let through.
            case .watch, .event: total + runawayPerHour * 24
            default: total + 1
            }
        }
        return min(max(goesRound ? loopsPerDay : ordinaryPerDay, runs * perRun), loopsPerDay)
    }

    private func keepBefore(_ reviewed: FlowBody, in flow: inout Flow) {
        guard let was = flow.live, was != reviewed else { return }
        flow.revisions.append(Flow.Revision(at: clock(), body: was))
        flow.revisions = Array(flow.revisions.suffix(Flow.keptRevisions))
    }

    private func settleWatch(_ id: String, wasLive: FlowBody?, wasOn: Bool, reviewed: FlowBody, title: String) async {
        guard let current = store.flow(id) else { return }
        let oldWatch = current.watchTitle
        // A new name too: the card's lines go by it, and every call to the watch from now on has to fit them.
        if oldWatch != nil, oldWatch != title || !Self.watchInputs(was: wasLive, now: reviewed) {
            await replaceWatch(id, stopping: oldWatch)
        } else if oldWatch == nil, case .watch = reviewed.trigger {
            await makeWatch(id)
        } else if !wasOn || current.watchOutdated {
            // Paused, or on its way out: approving an edit is what brings it back, the same as Resume.
            await resumeWatch(current)
        }
    }

    /// Run: one version, the one they read. Whatever's new is asked about (nothing, if nothing is), that goes live, and it runs. A flow that isn't on stays as it is, with its
    /// approval kept. Saying no leaves the edit where it is and what was live as it was, and the page says what's waiting.
    /// `saving`: the person pressed Run on the page they're looking at, so what's on it is what they mean. Anyone else gets what was kept, and half-typed words stay half-typed.
    @discardableResult func runNow(_ id: String, why: String, trigger: String? = nil, saving: Bool = false) async -> Run? {
        guard var flow = store.flow(id) else { return nil }
        guard flow.state != .paused else {
            flow.startProblem = L("“{name}” is paused. Ask the person to resume it first.", ["name": flow.name])
            store.save(flow)
            changed()
            return nil
        }
        if saving {
            flow.saved = nil
            flow.settleNote()
        }
        if let wrong = flow.kept.unfinished {
            flow.startProblem = wrong
            store.save(flow)
            changed()
            return nil
        }
        flow.startProblem = nil
        store.save(flow)
        changed()
        let plan = livePlan(flow, intent: "run")
        let lines = Self.lines(plan.steps)
        if lines > Plans.maxSteps {
            flow.startProblem = L("It has {count} different things to allow, counting what it watches. A flow can have {limit}: move some into a flow of their own.", ["count": Format.integer(lines), "limit": Format.integer(Plans.maxSteps)])
            store.save(flow)
            changed()
            return nil
        }
        let reviewed = flow.kept, title = Self.watchTitle(flow)
        // What's approved and hasn't changed needs no one's click: a schedule, an agent or a palette can go on with it. An approval that stood only under Full access doesn't stand now.
        var standsAlready = false
        if flow.live == reviewed { standsAlready = await host?.checkPlan(plan)?.silent == true }
        if !standsAlready, Self.needsCard(reviewed), let answer = await host?.approve(plan), case .refused(let reason) = answer {
            guard var current = store.flow(id) else { return nil }
            current.startProblem = Words.planRefusal(reason)
            store.save(current)
            changed()
            return nil
        }
        quietlyApproved[id] = nil
        guard var current = store.flow(id) else { return nil }
        let wasLive = current.live, wasOn = current.state == .on
        keepBefore(reviewed, in: &current)
        current.live = reviewed
        current.startProblem = nil
        // A change to when it runs counts from now, as turning on does.
        if wasOn, wasLive != reviewed {
            current.lastFire = clock()
            current.lastEvery = [:]
        }
        store.save(current)
        if wasOn, wasLive != reviewed { await settleWatch(id, wasLive: wasLive, wasOn: true, reviewed: reviewed, title: title) }
        changed()
        return store.flow(id).flatMap { start($0, mode: .live, why: why, trigger: trigger) }
    }

    /// How many different lines the host counts: alike ones are one, whatever they're called.
    static func lines(_ steps: [PlanStep]) -> Int { Set(steps.filter { !$0.onlyPassesOn }.map(\.line)).count }

    /// Everything the draft may do, as the person will read it. `intent`: what they pressed, for the card's heading.
    func livePlan(_ flow: Flow, intent: String = "turn_on") -> Plan {
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
        var when = Words.triggers(flow.kept, room: Self.longestTriggerWords)
        // Whose clock it goes by is what it does too: changing only that has to read differently on the card.
        if let zone = flow.kept.timeZone?.nonEmpty { when = L("{when}, by the clock of {zone}", ["when": when, "zone": zone]) }
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
        let goesRound = flow.kept.allSteps.contains { switch $0.kind { case .forEach, .repeatUntil: true; default: false } }
        let perRun = max(Self.callsPerRun(flow.kept.steps), 1)
        return Plan(id: flow.planId, title: flow.name, when: when, steps: steps, perDay: Self.callsPerDay(flow.kept, perRun: perRun, goesRound: goesRound),
                    perRun: perRun, intent: intent, goesRound: goesRound, inside: Self.inside(flow.kept))
    }

    static let loopsPerDay = 1000
    static let ordinaryPerDay = 200
    static let longestSetsOff = 180
    static let longestTriggerWords = 280

    /// There's something to read before it runs by itself. Only a flow someone starts by hand that does nothing but work on its own values has nothing to say.
    static func needsCard(_ body: FlowBody) -> Bool {
        if case .manual = body.trigger, body.alsoWhen.isEmpty {} else { return true }
        return planSteps(body, title: "").contains { !$0.onlyPassesOn }
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
        if let wrong = flow.kept.unfinished {
            flow.startProblem = wrong
            store.save(flow)
            return changed()
        }
        flow.startProblem = nil
        store.save(flow)
        changed()
        let plan = livePlan(flow)
        // Stopping the watch it had can be the line too many, which only shows here.
        if Self.lines(plan.steps) > Plans.maxSteps {
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
            case .allowed(_, let silent, _):
                quietlyApproved[id] = silent ? reviewed : nil
                let wasLive = current.live, wasOn = current.state == .on
                keepBefore(reviewed, in: &current)
                current.live = reviewed
                current.state = .on
                current.pausedBecause = nil
                current.lastFire = clock()
                current.lastEvery = [:]
                current.startProblem = nil
                store.save(current)
                await settleWatch(id, wasLive: wasLive, wasOn: wasOn, reviewed: reviewed, title: reviewedTitle)
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
        flow.lastEvery = [:]
        store.save(flow)
        changed()
        Task { await resumeWatch(flow) }
    }

    /// An AI step or a set-off that what's on now doesn't have as it was. An action is checked against what they read last at each call; nothing checks these two.
    private func isLeftBehind(_ step: Step, in run: Run) -> Bool {
        switch step.kind {
        case .ai, .flow, .call: break
        default: return false
        }
        guard run.mode == .live, let current = store.flow(run.flow), current.live != nil else { return false }
        return !current.running.allSteps.contains { $0.id == step.id && $0.kind == step.kind }
    }

    /// Stopped at such a step, where trying again would only ask the same.
    func stepLeftBehind(_ run: Run) -> Bool {
        guard run.status == .needs_you, FlowProgram(run.body).ops.indices.contains(run.pc), case .step(let step) = FlowProgram(run.body).ops[run.pc] else { return false }
        return isLeftBehind(step, in: run)
    }

    /// What goes by itself waits for Resume: its own flow or a flow that called it is paused.
    func heldByPause(_ run: Run) -> Bool { pausedFlow(holding: run) != nil }

    /// Which: a called flow can be on itself, with no Resume of its own to press.
    func pausedFlow(holding run: Run) -> Flow? {
        guard run.mode == .live else { return nil }
        return ([run.flow] + run.lineage).lazy.compactMap { self.store.flow($0) }.first { $0.state == .paused }
    }

    /// On from before a blank step was marked: pausing says so once, where running would do what comes before it each time and then stop. Whether it has one.
    @discardableResult func pauseIfBlank(_ flow: Flow) -> Bool {
        guard let wrong = flow.running.blank else { return false }
        guard var current = store.flow(flow.id), current.state == .on else { return true }
        current.state = .paused
        current.startProblem = wrong
        current.pausedBecause = L("It has a step that says nothing, so it's paused until that's fixed.")
        store.save(current)
        changed()
        let told = current
        Task {
            await pauseWatch(told)
            await host?.notify(title: L("{flow} is paused", ["flow": told.name]), body: told.pausedBecause, attention: true)
        }
        return true
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
        // One on its way out is stopped, not paused: the plan has no line for that.
        guard let title = flow.watchTitle, case .watch = flow.running.trigger, !flow.watchOutdated else { return }
        _ = await host?.call("watch.pause", ["id": title], plan: flow.planId, written: nil)
    }

    static var watchUnclear: String { L("Sidefolk didn't say whether its watch started again. If it doesn't fire, pause and resume it.") }

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
        if back?.ok == true {
            // Paused while it was asking: it would go on looking with the flow saying it isn't.
            if store.flow(flow.id)?.state == .paused { await pauseWatch(flow) }
            return
        }
        guard var current = store.flow(flow.id) else { return }
        // Only what's really not there is made again: a second of the same name would leave neither reachable by name.
        guard back?.notFound == true else {
            switch back?.status {
            case .denied?, .unanswered?, .busy?:
                // Nothing happened: saying On would be a flow that never fires.
                current.startProblem = back?.text.nonEmpty ?? L("The watch didn't start.")
                current.state = .paused
            default:
                current.startProblem = Self.watchUnclear
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
        guard title != nil, let flow = store.flow(id) else { return }
        let gone = await stopWatch(flow)
        guard var after = store.flow(id) else { return }
        guard gone else {
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

    /// Lets go of runs waiting for a flow that can't be read: the person's word that it isn't coming back.
    func endHeldRuns() {
        for run in store.unfinished() where store.isHeldBack(flow: run.flow) { stop(run: run.id) }
    }

    private func makeWatch(_ id: String) async {
        guard let flow = store.flow(id), flow.state == .on, case .watch(let w) = flow.running.trigger, makingWatch.insert(id).inserted else { return }
        defer { makingWatch.remove(id) }
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
        // Changed and approved while this one was being asked for: it's looking at what they replaced.
        if made?.ok == true, after.state == .on, !Self.watchInputs(was: flow.running, now: after.running) || Self.watchTitle(after) != title {
            makingWatch.remove(id)
            await replaceWatch(id, stopping: title)
        }
    }

    /// The person ended what they'd allowed, in Settings.
    /// The person ending it from the flow's page: as if they had in Settings.
    func endPlan(_ id: String) {
        host?.forgetPlan(store.flow(id)?.planId ?? "")
        planEnded(id, here: true)
    }

    /// "Saved. Nothing new to allow." while that's still what's on the page.
    func quietlySaved(_ flow: Flow) -> String? {
        quietlyApproved[flow.id] == flow.kept ? L("Saved. Nothing new to allow.") : nil
    }

    func planEnded(_ id: String, here: Bool = false) {
        guard var flow = store.flow(id) else { return }
        flow.state = .paused
        flow.pausedBecause = here ? L("You ended what you'd allowed, so it asks again before running.") : L("You ended what you'd allowed in Settings, so it asks again before running.")
        let ended = flow.live
        if let was = flow.live {
            flow.revisions.append(Flow.Revision(at: clock(), body: was))
            flow.revisions = Array(flow.revisions.suffix(Flow.keptRevisions))
        }
        flow.live = nil
        store.save(flow)
        // What's under way was running on what they just ended, called by another flow or set off by a draft too. An AI step or a set-off never reaches Sidefolk's check, so this is what stops those.
        for run in store.unfinished() where run.flow == id && run.mode != .practice && (run.mode == .live || run.setOff || run.parent != nil || run.body == ended) { stop(run: run.id) }
        changed()
        guard let title = flow.watchTitle else { return }
        // Its watch was made under that plan, so this asks: leaving it looking would go past what they just ended.
        Task {
            let stopped = await host?.call("watch.stop", ["id": title], plan: nil, written: nil)
            guard stopped?.ok == true || stopped?.notFound == true, var current = store.flow(id) else { return }
            current.watchTitle = nil
            current.watchOutdated = false
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
        case .forEach, .repeatUntil, .choose, .attempt, .parallel, .finish, .data, .form, .waitFor: true
        }
    }
}
