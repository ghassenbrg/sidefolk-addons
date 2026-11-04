import Foundation
import SidefolkExtensionKit

/// What sets a flow off, beside being run by hand or by name, which every flow can be.
enum Trigger: Equatable, Sendable {
    case manual
    /// Chosen weekdays at a time. `days` are 1 (Monday) to 7 (Sunday).
    case days([Int], hour: Int, minute: Int, catchUp: Bool)
    case every(minutes: Int, catchUp: Bool)
    /// One of Sidefolk's watches, made for this flow: `watch.create`'s own kinds.
    case watch(WatchTrigger)
    /// Something happening in Sidefolk, as it tells those who asked to hear: a reminder firing, a note saved. `contains`: only when its words say this.
    case event(String, contains: String?)

    static let events = ["reminder.fired", "reminder.created", "note.saved", "calendar.starting", "companion.finished", "agent.finished", "attention.changed", "mac.woke"]
}

struct WatchTrigger: Equatable, Sendable {
    static let kinds = ["url_change", "site_status", "file_changes", "file_appears", "folder_new_file", "process_exits"]

    var kind: String
    var target: String
    var contains: String?
    var pattern: String?
    /// How often it looks, when not at Sidefolk's usual pace for this kind. Sidefolk keeps to the shortest it allows.
    var everySeconds: Int?
    /// How long it stays quiet after it fires. By default it looks again at its next check.
    var restMinutes: Int?
}

struct Condition: Equatable, Sendable {
    enum Test: String, CaseIterable, Sendable { case contains, not_contains, `is`, is_not, is_empty, not_empty, more_than, less_than }

    var value: String
    var test: Test
    var than: String
    /// More checks after this one, and whether any of them is enough rather than all.
    var also: [Condition] = []
    var any = false

    /// This check and those after it, one level: what the words and the form go through.
    var checks: [Condition] { [self] + also }

    func holds(_ values: Values) -> Bool {
        let one = checks.map { $0.checkHolds(values) }
        return any ? one.contains(true) : !one.contains(false)
    }

    /// Numbers read from the first number in the value, so "18 °C" compares as 18.
    private func checkHolds(_ values: Values) -> Bool {
        let left = values.fill(value).trimmingCharacters(in: .whitespacesAndNewlines), right = values.fill(than).trimmingCharacters(in: .whitespacesAndNewlines)
        switch test {
        case .contains: return left.range(of: right, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        case .not_contains: return left.range(of: right, options: [.caseInsensitive, .diacriticInsensitive]) == nil
        case .is: return left.compare(right, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        case .is_not: return left.compare(right, options: [.caseInsensitive, .diacriticInsensitive]) != .orderedSame
        case .is_empty: return left.isEmpty
        case .not_empty: return !left.isEmpty
        case .more_than, .less_than:
            guard let a = Self.number(left), let b = Self.number(right) else { return false }
            return test == .more_than ? a > b : a < b
        }
    }

    private static let digits = try! NSRegularExpression(pattern: #"-?\d+(?:[.,]\d+)?"#)

    static func number(_ text: String) -> Double? {
        guard let match = digits.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)), let range = Range(match.range, in: text) else { return nil }
        // Hundreds of digits come out as infinity, which no file can hold.
        return Double(text[range].replacingOccurrences(of: ",", with: ".")).flatMap { $0.isFinite ? $0 : nil }
    }
}

struct Step: Equatable, Sendable {
    indirect enum Kind: Equatable, Sendable {
        case action(tool: String, input: [String: JSON])
        case ai(prompt: String)
        case ask(question: String, options: [String])
        case text(String)
        case branch(Condition, then: [Step], otherwise: [Step])
        case wait(minutes: Int)
        /// Sets off another flow, by name, and carries on.
        case flow(String)
    }

    enum OnFailure: String, CaseIterable, Sendable { case stop, carry_on, retry }

    /// The words of this step that may name other steps' results.
    var usedTexts: [String] {
        switch kind {
        case .action(_, let input): input.values.flatMap(\.strings)
        case .ai(let prompt): [prompt]
        case .ask(let question, _): [question]
        case .text(let text): [text]
        case .branch, .wait, .flow: []
        }
    }

    var id: String
    /// The person's words for it; the tool's own sentence otherwise.
    var name: String?
    var kind: Kind
    var onFailure: OnFailure = .stop

    /// Whether it leaves a value later steps can use.
    var hasOutput: Bool {
        switch kind {
        case .action, .ai, .ask, .text: true
        case .branch, .wait, .flow: false
        }
    }
}

/// A flow's definition: what a person edits and an agent writes, and the one shape both read.
struct FlowBody: Equatable, Sendable {
    var trigger: Trigger = .manual
    var steps: [Step] = []

    static let maxSteps = 40
    /// Top level, inside an `if`, inside an `if` within that.
    static let maxDepth = 3
    static let shortestEvery = 15
    static let longestEvery = 7 * 24 * 60
    static let longestWait = 1440

    /// Depth first, in reading order.
    var allSteps: [Step] {
        func walk(_ list: [Step]) -> [Step] {
            list.flatMap { step -> [Step] in
                if case .branch(_, let a, let b) = step.kind { return [step] + walk(a) + walk(b) }
                return [step]
            }
        }
        return walk(steps)
    }

    func step(_ id: String) -> Step? { allSteps.first { $0.id == id } }

    /// How many levels of steps it goes down: what `maxDepth` limits.
    var depth: Int {
        func down(_ steps: [Step]) -> Int {
            steps.map { step in
                guard case .branch(_, let then, let otherwise) = step.kind else { return 1 }
                return 1 + max(down(then), down(otherwise), 1)
            }.max() ?? 0
        }
        return down(steps)
    }
}

/// A flow's life: `draft` is what's on the person's screen, `saved` what Save last kept when that differs, `live` what runs, once the person allowed it. Editing changes only the draft.
struct Flow: Equatable, Sendable, Identifiable {
    enum State: String, Sendable { case draft, on, paused }

    var id: String
    var name: String
    var draft: FlowBody
    /// What Save last kept, while the draft has moved on from it.
    var saved: FlowBody?
    var live: FlowBody?
    var state: State = .draft
    var createdAt: Date
    var updatedAt: Date
    /// Scheduled up to here: what the clock counts on from.
    var lastFire: Date?
    /// The watch this flow made, by its title.
    var watchTitle: String?
    /// That watch looks at what's no longer on and wouldn't stop. Resume tries again, rather than bringing it back.
    var watchOutdated = false
    /// Times it was meant to run and couldn't, newest last.
    var missed: [Date] = []
    /// Why the card didn't end in On, for the page.
    var startProblem: String?
    /// Stopped by the runaway guard.
    var pausedBecause: String?
    /// What practice showed, for the draft it practiced: nil once it changed.
    var practiced: FlowBody?

    /// What a Save last kept: what turning on or applying uses.
    var kept: FlowBody { saved ?? draft }
    /// On the screen, not saved yet.
    var hasUnsaved: Bool { saved != nil }
    /// Saved, not live yet.
    var hasChanges: Bool { live != nil && live != kept }

    /// After an edit: remembers what was saved, or says there's nothing to save if the edit came back to it.
    /// Shows an earlier or later version on the page: what's kept stays what's kept, so it's unsaved unless it's the same.
    mutating func show(_ body: FlowBody) {
        let keptBefore = kept
        draft = body
        saved = body == keptBefore ? nil : keptBefore
    }

    mutating func hold(_ before: FlowBody) {
        if saved == nil { saved = before }
        if saved == draft { saved = nil }
    }

    var running: FlowBody { live ?? draft }
    var planId: String { "flow-\(id)" }
    var practiceId: String { "practice-\(id)" }
}

// MARK: The one shape, as JSON

enum FlowCodec {
    static let days = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]

    static func json(_ body: FlowBody) -> [String: Any] {
        ["trigger": json(body.trigger), "steps": body.steps.map(json)]
    }

    static func json(_ trigger: Trigger) -> [String: Any] {
        switch trigger {
        case .manual: return ["type": "manual"]
        case .days(let days, let hour, let minute, let catchUp):
            return ["type": "schedule", "days": days.sorted().map { Self.days[$0 - 1] }, "at": String(format: "%02d:%02d", hour, minute), "catch_up": catchUp]
        case .every(let minutes, let catchUp): return ["type": "schedule", "every_minutes": minutes, "catch_up": catchUp]
        case .watch(let w):
            var out: [String: Any] = ["type": "watch", "kind": w.kind, "target": w.target]
            if let c = w.contains { out["contains"] = c }
            if let p = w.pattern { out["pattern"] = p }
            if let every = w.everySeconds { out["every_seconds"] = every }
            if let rest = w.restMinutes { out["rest_minutes"] = rest }
            return out
        case .event(let name, let contains):
            var out: [String: Any] = ["type": "event", "event": name]
            if let contains { out["contains"] = contains }
            return out
        }
    }

    static func json(_ step: Step) -> [String: Any] {
        var out: [String: Any] = ["id": step.id]
        if let name = step.name { out["name"] = name }
        if step.onFailure != .stop { out["on_failure"] = step.onFailure.rawValue }
        switch step.kind {
        case .action(let tool, let input):
            out["do"] = tool
            if !input.isEmpty { out["with"] = input.mapValues(\.any) }
        case .ai(let prompt): out["ai"] = prompt
        case .ask(let question, let options):
            out["ask"] = question
            if !options.isEmpty { out["options"] = options }
        case .text(let text): out["text"] = text
        case .branch(let c, let then, let otherwise):
            var check: [String: Any] = ["value": c.value, "test": c.test.rawValue, "than": c.than]
            // "Or" with nothing in it yet still says "any of": removing the last check doesn't change what adding one back means.
            if !c.also.isEmpty || c.any {
                check[c.any ? "or" : "and"] = c.also.map { ["value": $0.value, "test": $0.test.rawValue, "than": $0.than] as [String: Any] }
            }
            out["if"] = check
            out["then"] = then.map(json)
            out["else"] = otherwise.map(json)
        case .wait(let minutes): out["wait_minutes"] = minutes
        case .flow(let name): out["run_flow"] = name
        }
        return out
    }

    /// Reads a definition, saying what to fix in words a person and a model can both act on. Unknown keys are mistakes: one
    /// silently dropped would run something other than what was meant.
    /// `saved`: read back from disk, where the limit on depth doesn't apply: what was kept is never lost to a limit that came later.
    static func body(_ any: Any?, saved: Bool = false) throws -> FlowBody {
        guard let o = any as? [String: Any] else { throw Problem(L("A flow is an object with “trigger” and “steps”.")) }
        try only(o, ["trigger", "steps"], in: "flow")
        var used = Set<String>()
        let made = FlowBody(trigger: try trigger(o["trigger"], saved: saved), steps: try steps(o["steps"] ?? [], depth: saved ? -64 : 1, used: &used))
        if !saved, made.allSteps.count > FlowBody.maxSteps {
            throw Problem(L("A flow can have at most {count} steps.", ["count": Format.integer(FlowBody.maxSteps)]))
        }
        return made
    }

    /// `saved`: what's on disk. A page saves as it goes, so a target cleared is a trigger being written: it reads back as it is and is marked to fix,
    /// rather than losing the flow.
    static func trigger(_ any: Any?, saved: Bool = false) throws -> Trigger {
        guard let any else { return .manual }
        guard let o = any as? [String: Any], let type = o["type"] as? String else { throw Problem(L("“trigger” needs a “type”: manual, schedule, watch or event.")) }
        switch type {
        case "manual":
            try only(o, ["type"], in: "trigger")
            return .manual
        case "schedule":
            try only(o, ["type", "days", "at", "every_minutes", "catch_up"], in: "trigger")
            let catchUp = o["catch_up"] as? Bool ?? true
            if let minutes = (o["every_minutes"] as? NSNumber)?.intValue {
                guard saved || (minutes >= FlowBody.shortestEvery && minutes <= FlowBody.longestEvery) else {
                    throw Problem(L("“every_minutes” must be at least {count}.", ["count": Format.integer(FlowBody.shortestEvery)]))
                }
                return .every(minutes: minutes, catchUp: catchUp)
            }
            guard let at = o["at"] as? String, let (hour, minute) = clock(at) else { throw Problem(L("A schedule needs “at”, a time like 08:30, or “every_minutes”.")) }
            let names = (o["days"] as? [String]) ?? days
            let picked = try names.map { name -> Int in
                guard let i = days.firstIndex(of: name.lowercased().prefixString(3)) else { throw Problem(L("“{day}” isn't a day: use mon, tue, wed, thu, fri, sat or sun.", ["day": name])) }
                return i + 1
            }
            guard saved || !picked.isEmpty else { throw Problem(L("A schedule needs at least one day.")) }
            return .days(Array(Set(picked)).sorted(), hour: hour, minute: minute, catchUp: catchUp)
        case "watch":
            try only(o, ["type", "kind", "target", "contains", "pattern", "every_seconds", "rest_minutes"], in: "trigger")
            guard let kind = o["kind"] as? String, WatchTrigger.kinds.contains(kind) else {
                throw Problem(L("A watch needs “kind”, one of {kinds}.", ["kinds": WatchTrigger.kinds.joined(separator: ", ")]))
            }
            let target = (o["target"] as? String)?.trimmed ?? ""
            guard saved || !target.isEmpty else { throw Problem(L("A watch needs “target”: a web address, a full path or a program.")) }
            return .watch(WatchTrigger(kind: kind, target: target, contains: (o["contains"] as? String)?.nonEmpty, pattern: (o["pattern"] as? String)?.nonEmpty,
                                       everySeconds: ((o["every_seconds"] as? NSNumber)?.intValue).flatMap { $0 > 0 ? $0 : nil },
                                       restMinutes: ((o["rest_minutes"] as? NSNumber)?.intValue).flatMap { $0 >= 0 ? $0 : nil }))
        case "event":
            try only(o, ["type", "event", "contains"], in: "trigger")
            guard let name = o["event"] as? String, Trigger.events.contains(name) else {
                throw Problem(L("An event trigger needs “event”, one of {kinds}.", ["kinds": Trigger.events.joined(separator: ", ")]))
            }
            return .event(name, contains: (o["contains"] as? String)?.nonEmpty)
        default:
            throw Problem(L("“trigger” needs a “type”: manual, schedule, watch or event."))
        }
    }

    /// `08:30`, `8:30`.
    static func clock(_ text: String) -> (Int, Int)? {
        let parts = text.trimmed.split(separator: ":")
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]), (0...23).contains(h), (0...59).contains(m) else { return nil }
        return (h, m)
    }

    static func steps(_ any: Any?, depth: Int, used: inout Set<String>) throws -> [Step] {
        guard let list = any as? [Any] else { throw Problem(L("“steps” must be a list.")) }
        guard depth <= FlowBody.maxDepth else { throw Problem(L("An “if” can hold another “if”, but no deeper.")) }
        return try list.map { try step($0, depth: depth, used: &used) }
    }

    static func step(_ any: Any, depth: Int, used: inout Set<String>) throws -> Step {
        // Read back from disk, where `body` starts the depth below any limit: what a page saved as it went is kept and marked, never refused.
        let saved = depth < 0
        guard let o = any as? [String: Any] else { throw Problem(L("Each step is an object.")) }
        try only(o, ["id", "name", "on_failure", "do", "with", "ai", "ask", "options", "text", "if", "then", "else", "wait_minutes", "run_flow"], in: "step")
        let kinds = ["do", "ai", "ask", "text", "if", "wait_minutes", "run_flow"].filter { o[$0] != nil }
        guard kinds.count == 1 else { throw Problem(L("A step does one thing: do, ai, ask, text, if, wait_minutes or run_flow.")) }
        var id = (o["id"] as? String)?.trimmed ?? ""
        if id.isEmpty {
            var n = used.count + 1
            while used.contains("s\(n)") { n += 1 }
            id = "s\(n)"
        }
        guard id.range(of: #"^[a-z0-9_]{1,24}$"#, options: .regularExpression) != nil, !Values.reserved.contains(id) else {
            throw Problem(L("“{id}” can't name a step: use up to 24 lowercase letters, digits and _.", ["id": id]))
        }
        guard used.insert(id).inserted else { throw Problem(L("Two steps are called “{id}”.", ["id": id])) }
        var failure = Step.OnFailure.stop
        if let raw = o["on_failure"] as? String {
            guard let f = Step.OnFailure(rawValue: raw) else { throw Problem(L("“on_failure” is stop, carry_on or retry.")) }
            failure = f
        }
        let kind: Step.Kind
        if let tool = o["do"] as? String {
            guard let input = (o["with"] ?? [String: Any]()) as? [String: Any] else { throw Problem(L("“with” is an object of the tool's values.")) }
            kind = .action(tool: tool, input: input.mapValues { JSON($0) })
        // Empty is a step being written: it reads back, and `problems` marks it.
        } else if let prompt = o["ai"] as? String, saved || !prompt.trimmed.isEmpty {
            kind = .ai(prompt: prompt)
        } else if let question = o["ask"] as? String, saved || !question.trimmed.isEmpty {
            let options = o["options"] as? [String] ?? []
            guard options.isEmpty || (2...4).contains(options.count) else { throw Problem(L("“options” are 2 to 4 answers, or none to let them type.")) }
            kind = .ask(question: question, options: options)
        } else if let text = o["text"] as? String {
            kind = .text(text)
        } else if let c = o["if"] as? [String: Any] {
            guard let value = c["value"] as? String, let raw = c["test"] as? String, let test = Condition.Test(rawValue: raw) else {
                throw Problem(L("“if” needs “value” and “test”: {tests}.", ["tests": Condition.Test.allCases.map(\.rawValue).joined(separator: ", ")]))
            }
            var condition = Condition(value: value, test: test, than: c["than"] as? String ?? "")
            // "Any of" or "all of", and a list: anything else would quietly read as something it doesn't say.
            guard c["and"] == nil || c["or"] == nil else { throw Problem(L("A condition is “and” or “or”, not both.")) }
            if let joined = c["and"] ?? c["or"], !(joined is [[String: Any]]) { throw Problem(L("Each check in “and” or “or” needs “value” and “test”.")) }
            for raw in (c["and"] ?? c["or"]) as? [[String: Any]] ?? [] {
                guard let v = raw["value"] as? String, let t = (raw["test"] as? String).flatMap(Condition.Test.init(rawValue:)) else { throw Problem(L("Each check in “and” or “or” needs “value” and “test”.")) }
                condition.also.append(Condition(value: v, test: t, than: raw["than"] as? String ?? ""))
            }
            condition.any = c["or"] != nil
            kind = .branch(condition,
                           then: try steps(o["then"] ?? [], depth: depth + 1, used: &used), otherwise: try steps(o["else"] ?? [], depth: depth + 1, used: &used))
        } else if let minutes = (o["wait_minutes"] as? NSNumber)?.intValue {
            guard (1...FlowBody.longestWait).contains(minutes) else {
                throw Problem(L("A wait is 1 to {count} minutes.", ["count": Format.integer(FlowBody.longestWait)]))
            }
            kind = .wait(minutes: minutes)
        } else if let name = o["run_flow"] as? String, saved || !name.trimmed.isEmpty {
            kind = .flow(name)
        } else {
            throw Problem(L("A step does one thing: do, ai, ask, text, if, wait_minutes or run_flow."))
        }
        return Step(id: id, name: (o["name"] as? String)?.nonEmpty, kind: kind, onFailure: failure)
    }

    private static func only(_ o: [String: Any], _ keys: Set<String>, in what: String) throws {
        if let extra = o.keys.sorted().first(where: { !keys.contains($0) }) {
            throw Problem(L("“{key}” isn't something a {what} has.", ["key": extra, "what": what]))
        }
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
    var nonEmpty: String? { let t = trimmed; return t.isEmpty ? nil : t }
    func prefixString(_ n: Int) -> String { String(prefix(n)) }
}
