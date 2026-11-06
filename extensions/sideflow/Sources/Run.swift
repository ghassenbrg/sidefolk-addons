import Foundation

/// One go through a flow, journalled: each step's start is on disk before its call, and its end after. That is what tells a step that finished
/// from one that may or may not have happened when Sidefolk stopped in between.
struct Run: Equatable, Sendable, Identifiable {
    enum Mode: String, Sendable {
        /// Reads for real, changes nothing, says what the rest would do.
        case practice
        /// An On flow, under the plan the person read.
        case live
        /// A draft run for real once: every action on its own card.
        case once
    }

    enum Status: String, Sendable {
        case running, waiting, done, failed, stopped
        /// Waiting on the person: a card nobody answered, or a tool that needs a look.
        case needs_you
        /// Sidefolk stopped in the middle of a step that changes things.
        case interrupted

        var isOver: Bool { self == .done || self == .failed || self == .stopped }
    }

    struct Record: Equatable, Sendable {
        enum Status: String, Sendable { case running, done, would, failed, skipped, needs_you, waiting, unknown }

        var step: String
        var status: Status
        /// What it did or would do, in a sentence.
        var summary: String
        var output: String?
        var note: String?
        var at: Date
        /// Which go of a loop it's from: `3`, or `3.1` inside another. Nil outside any.
        var scope: String?
        /// Which try of the step: 1 and up.
        var attempt = 1
        /// What it was given, as words.
        var input: String?
    }

    /// Somewhere a run is inside: a loop going round, or a try. On disk with it, so a restart comes back to item 37 of 40.
    struct Frame: Equatable, Sendable {
        enum Kind: String, Sendable { case loop, attempt }

        var kind: Kind
        var step: String
        // A loop: its items, where it is, what each gave, and the program's place to come back to and to end at.
        var items: [JSON] = []
        var index = 0
        var results: [JSON] = []
        var failedItems = 0
        var collect = false
        /// This time round something was done that going round would do again, or may have been.
        var wrote = false
        var top = 0
        var end = 0
        // A try: where its other ways are, and which it's in.
        var recover = 0
        var always = 0
        var inRecover = false
        var inAlways = false
        /// It failed for this, and goes on failing once its last steps are done.
        var failing: String?
        /// The flow ended inside it, and goes on ending once its last steps are done.
        var returning = false
    }

    /// A form waiting for the person.
    struct WaitingConnection: Equatable, Sendable {
        var tool: String
        var until: Date
    }

    struct WaitingForm: Equatable, Sendable {
        var step: String
        var answers: [String: JSON] = [:]
    }

    var id: String
    var flow: String
    var flowName: String
    var mode: Mode
    var status: Status
    /// Why it started, in the person's words.
    var why: String
    var startedAt: Date
    var endedAt: Date?
    /// Its definition when it started: an edit never changes a run under way.
    var body: FlowBody
    /// Where it is in `FlowProgram`.
    var pc = 0
    var values = Values()
    var records: [Record] = []
    /// A wait or a retry: when to carry on.
    var resumeAt: Date?
    var retries = 0
    /// How many times the person said "Try again": a plan's limit for one run counts each afresh.
    var triedAgain = 0
    /// What the person should know, when it stopped.
    var problem: String?
    var frames: [Frame] = []
    /// The run that waits for this one, and every flow on the way here: a flow can't end up calling itself.
    var parent: String?
    var lineage: [String] = []
    /// Runs this one waits for, at a call or a parallel.
    var waitingOn: [String] = []
    /// What it answers to the run that called it.
    var output: JSON?
    var form: WaitingForm?
    /// Another flow's step started it, rather than someone asking.
    var setOff = false
    /// Stopped between steps at the person's asking, to go on when they say.
    var paused = false
    /// Other flows' runs this one set off: separate, each with its own approval, so Stop here doesn't end them, and the page says where to press it.
    var setOffRuns: [String] = []
    /// A lane's item and its number, from the loop it's in.
    var startItem: JSON?
    var startIndex: JSON?
    /// The tool it's waiting to come back, and until when.
    var connection: WaitingConnection?
    /// A lane's limit: past this, it's stopped.
    var deadline: Date?
    /// Stopped because its time ran out, not because something else was enough.
    var timedOut: Bool { status == .stopped && deadline.flatMap { limit in endedAt.map { limit <= $0 } } == true }

    /// What it answers to a run that called it: what it said at its end, or what its last step made.
    var answer: JSON { output ?? .null }

    /// Where it is among the loops it's in.
    var scope: String? {
        let places = frames.filter { $0.kind == .loop }.map { String($0.index + 1) }
        return places.isEmpty ? nil : places.joined(separator: ".")
    }

    mutating func record(_ r: Record) {
        var r = r
        if r.scope == nil { r.scope = scope }
        if r.attempt == 1 { r.attempt = retries + 1 }
        if let i = records.lastIndex(where: { $0.step == r.step && $0.scope == r.scope }) {
            if r.input == nil { r.input = records[i].input }
            records[i] = r
        } else {
            records.append(r)
        }
        // A long loop keeps what's most use: the latest, and every step outside it.
        if records.count > Self.longestStory, let old = records.firstIndex(where: { $0.scope != nil && $0.status == .done }) { records.remove(at: old) }
    }

    static let longestStory = 400

    func record(of step: String) -> Record? { records.last { $0.step == step } }
}

/// A flow in order, with what holds other steps as jumps, so where a run is fits in one number on disk, and the loops and tries it's in in a short list.
struct FlowProgram {
    enum Op: Equatable {
        case step(Step)
        case branch(Step, Condition, otherwise: Int)
        case jump(Int)
        case loopStart(Step, end: Int)
        case loopNext(Step)
        case choose(Step, targets: [Int], otherwise: Int)
        case tryStart(Step, recover: Int, always: Int)
        case alwaysStart
        case tryEnd
    }

    var ops: [Op] = []

    init(_ body: FlowBody) { add(body.steps) }

    /// Where a run goes next when it leaves what's at `pc` undone: past all of it, not into what it holds.
    func past(_ pc: Int) -> Int {
        guard ops.indices.contains(pc) else { return pc + 1 }
        switch ops[pc] {
        case .loopStart(_, let end): return end + 1
        case .choose(_, _, let otherwise), .branch(_, _, let otherwise):
            // Every path but the last way ends in a jump past them all.
            if otherwise > 0, case .jump(let end) = ops[otherwise - 1] { return end }
            return otherwise
        default: return pc + 1
        }
    }

    private mutating func add(_ steps: [Step]) {
        for step in steps {
            switch step.kind {
            case .branch(let c, let then, let otherwise):
                let test = ops.count
                ops.append(.branch(step, c, otherwise: 0))
                add(then)
                let leave = ops.count
                ops.append(.jump(0))
                ops[test] = .branch(step, c, otherwise: ops.count)
                add(otherwise)
                ops[leave] = .jump(ops.count)
            case .forEach(_, _, _, let inside), .repeatUntil(_, _, let inside):
                let start = ops.count
                ops.append(.loopStart(step, end: 0))
                add(inside)
                ops.append(.loopNext(step))
                ops[start] = .loopStart(step, end: ops.count - 1)
            case .choose(_, let paths, let otherwise):
                let start = ops.count
                ops.append(.choose(step, targets: [], otherwise: 0))
                var targets: [Int] = [], leaves: [Int] = []
                for path in paths {
                    targets.append(ops.count)
                    add(path.steps)
                    leaves.append(ops.count)
                    ops.append(.jump(0))
                }
                ops[start] = .choose(step, targets: targets, otherwise: ops.count)
                add(otherwise)
                for leave in leaves { ops[leave] = .jump(ops.count) }
            case .attempt(let inside, let recover, let always):
                let start = ops.count
                ops.append(.tryStart(step, recover: 0, always: 0))
                add(inside)
                let leave = ops.count
                ops.append(.jump(0))
                let toRecover = ops.count
                add(recover)
                let toAlways = ops.count
                ops[leave] = .jump(toAlways)
                ops[start] = .tryStart(step, recover: toRecover, always: toAlways)
                ops.append(.alwaysStart)
                add(always)
                ops.append(.tryEnd)
            default:
                ops.append(.step(step))
            }
        }
    }
}

extension Run {
    /// Why it can't go on with this value, knowing whether the step it names ran.
    func whyMissing(_ name: String) -> String {
        let root = name.split(whereSeparator: { $0 == "." || $0 == "[" }).first.map(String.init) ?? name
        return values.whyMissing(name, ran: record(of: root) != nil)
    }
}
