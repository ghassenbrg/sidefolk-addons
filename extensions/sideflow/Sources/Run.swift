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
    /// What the person should know, when it stopped.
    var problem: String?

    mutating func record(_ r: Record) {
        if let i = records.lastIndex(where: { $0.step == r.step }) { records[i] = r } else { records.append(r) }
    }

    func record(of step: String) -> Record? { records.last { $0.step == step } }
}

/// A flow in order, with its branches as jumps, so where a run is fits in one number on disk.
struct FlowProgram {
    enum Op: Equatable {
        case step(Step)
        case branch(Step, Condition, otherwise: Int)
        case jump(Int)
    }

    var ops: [Op] = []

    init(_ body: FlowBody) { add(body.steps) }

    private mutating func add(_ steps: [Step]) {
        for step in steps {
            guard case .branch(let c, let then, let otherwise) = step.kind else {
                ops.append(.step(step))
                continue
            }
            let test = ops.count
            ops.append(.branch(step, c, otherwise: 0))
            add(then)
            let leave = ops.count
            ops.append(.jump(0))
            ops[test] = .branch(step, c, otherwise: ops.count)
            add(otherwise)
            ops[leave] = .jump(ops.count)
        }
    }
}
