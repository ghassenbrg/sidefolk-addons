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

    func checkHolds(_ values: Values) -> Bool {
        let left = values.fill(value)
        // A No from a form or a tool isn't something to a condition, though the word "no" is, and a list of them keeps them.
        if test == .is_empty || test == .not_empty, left.trimmed == "false" { return test == .is_empty }
        return Self.test(test, left: left, right: values.fill(than))
    }

    /// Numbers read from the first number in the value, so "18 °C" compares as 18.
    /// Nothing there, however it's written: an empty list reads as "[]".
    static func isBlank(_ text: String) -> Bool { text.isEmpty || text == "[]" || text == "{}" }

    /// Yes or no, however a form, a tool or a person says it.
    private static func answer(_ text: String) -> String? {
        switch text.trimmed.lowercased() {
        case "true", "yes", L("Yes").lowercased(): "yes"
        case "false", "no", L("No").lowercased(): "no"
        default: nil
        }
    }

    /// Whether words mention this as a word of its own: "unpaid" doesn't mention "paid".
    static func mentions(_ seen: String, _ word: String) -> Bool {
        let word = word.trimmed
        guard !word.isEmpty else { return false }
        if let a = answer(seen), let b = answer(word) { return a == b }
        let fold: (String) -> String = { $0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil) }
        let (text, wanted) = (fold(seen), fold(word))
        // A word has an edge only where it's written with spaces: "unpaid" doesn't mention "paid", but "Slack通知" mentions "通知" and "GitHubの" mentions "GitHub".
        let joins = #"[\p{L}\p{M}\p{N}&&[^\p{Han}\p{Hiragana}\p{Katakana}\p{Hangul}\p{Thai}\u30FC]]"#
        func edged(_ letter: Character?) -> Bool { letter.map { String($0).range(of: joins, options: .regularExpression) != nil } ?? false }
        return text.range(of: (edged(wanted.first) ? "(?<!\(joins))" : "") + NSRegularExpression.escapedPattern(for: wanted) + (edged(wanted.last) ? "(?!\(joins))" : ""), options: .regularExpression) != nil
    }

    static func test(_ test: Test, left: String, right: String) -> Bool {
        let left = left.trimmingCharacters(in: .whitespacesAndNewlines), right = right.trimmingCharacters(in: .whitespacesAndNewlines)
        switch test {
        case .contains: return has(left, right)
        case .not_contains: return !has(left, right)
        case .is: return same(left, right)
        case .is_not: return !same(left, right)
        case .is_empty: return isBlank(left)
        case .not_empty: return !isBlank(left)
        case .more_than, .less_than:
            guard let a = number(left), let b = number(right) else { return false }
            return test == .more_than ? a > b : a < b
        }
    }

    private static func has(_ left: String, _ right: String) -> Bool {
        let found = left.range(of: right, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        guard !found, let said = answer(left), let wanted = answer(right) else { return found }
        return said == wanted
    }

    private static func same(_ left: String, _ right: String) -> Bool {
        if let a = answer(left), let b = answer(right) { return a == b }
        return left.compare(right, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
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
        /// Goes through a list, the steps inside once per item.
        case forEach(items: String, limit: Int, onFailure: LoopFailure, steps: [Step])
        /// Round and round until it holds, at most `times`: there's always an end, and what happens at it is the step's own failure.
        case repeatUntil(until: Condition, times: Int, steps: [Step])
        /// The first path whose words match the value, or the rest.
        case choose(value: String, paths: [Path], otherwise: [Step])
        /// Steps; if one fails, the others instead; then the last ones in any case.
        case attempt(steps: [Step], recover: [Step], always: [Step])
        /// Several things at once; it carries on when all are done.
        case parallel(lanes: [Lane])
        /// Runs another flow and waits for it, with values to start from and its result to use.
        case call(flow: String, inputs: [String: String])
        /// Ends the flow here, saying what its result is.
        case finish(String)
        case data(DataStep)
        case form(FormStep)
        /// Waits for something to happen, up to a time.
        case waitFor(event: String, contains: String?, minutes: Int)
    }

    enum OnFailure: String, CaseIterable, Sendable { case stop, carry_on, retry }

    /// The words of this step that may name other steps' results.
    /// What it needs before it can do anything: a page saves as it goes, so it can be halfway through being written.
    var saysNothing: String? {
        switch kind {
        case .ai(let prompt) where prompt.trimmed.isEmpty: L("Say what to write.")
        case .ask(let question, _) where question.trimmed.isEmpty: L("Say what to ask.")
        case .flow(let name) where name.trimmed.isEmpty: L("Pick which flow to run.")
        case .call(let name, _) where name.trimmed.isEmpty: L("Pick which flow to run.")
        case .forEach(let items, _, _, _) where items.trimmed.isEmpty: L("Say which list to go through.")
        case .repeatUntil(let until, _, _) where until.checks.contains(where: { $0.value.trimmed.isEmpty }): L("Say what each check looks at.")
        case .choose(let value, _, _) where value.trimmed.isEmpty: L("Say what to look at.")
        case .data(let data) where data.from.trimmed.isEmpty: L("Say what from")
        case .form(let form) where form.fields.isEmpty: L("Add something for the form to ask.")
        case .form(let form) where form.fields.contains { $0.kind == .choice && $0.options.count < 2 }: L("A choice in a form needs at least two answers.")
        default: nil
        }
    }

    /// Whether doing it again would do something again. Another run counts, whatever it does.
    @MainActor func doesSomething(_ catalog: Catalog) -> Bool {
        switch kind {
        // A tool that's away did nothing yet, and it comes back through here if it comes back.
        case .action(let tool, _): !Connections.isMissing(tool, catalog) && !reads(catalog)
        case .call, .parallel, .flow: true
        default: false
        }
    }

    var usedTexts: [String] {
        switch kind {
        case .action(_, let input): input.values.flatMap(\.strings)
        case .ai(let prompt): [prompt]
        case .ask(let question, _): [question]
        case .text(let text): [text]
        case .forEach(let items, _, _, _): [items]
        case .repeatUntil(let c, _, _): c.checks.flatMap { [$0.value, $0.than] }
        case .call(_, let inputs): Array(inputs.values)
        case .finish(let value): [value]
        case .data(let data): [data.from, data.than ?? ""]
        case .form(let form): [form.title]
        case .choose(let value, _, _): [value]
        case .branch, .wait, .flow, .attempt, .parallel, .waitFor: []
        }
    }

    var id: String
    /// The person's words for it; the tool's own sentence otherwise.
    var name: String?
    var kind: Kind
    var onFailure: OnFailure = .stop
    /// In a practice run, what it gives instead of being run: to try the ways a real answer would take. JSON stays JSON.
    var sample: String?
    /// For an AI step: the fields its answer must have, by name, each `text`, `number`, `yes_no` or `list`. Its answer is then a record, or the step fails.
    var fields: [String: String]?

    /// Whether it leaves a value later steps can use.
    var hasOutput: Bool {
        switch kind {
        case .action, .ai, .ask, .text, .forEach, .repeatUntil, .call, .data, .form, .waitFor, .parallel: true
        case .branch, .wait, .flow, .choose, .attempt, .finish: false
        }
    }
}

/// A flow's definition: what a person edits and an agent writes, and the one shape both read.
struct FlowBody: Equatable, Sendable {
    /// A second start while a run is under way.
    enum Overlap: String, Equatable, Sendable, CaseIterable {
        /// One more waits behind it, and further ones fold into that.
        case one_more
        /// Each waits its turn, on disk, up to `FlowBody.longestQueue`.
        case queue
        /// It's let go.
        case skip
    }

    var trigger: Trigger = .manual
    /// More times or happenings that set it off. A watch has a name of its own to look after, so it's only ever the first.
    var alsoWhen: [Trigger] = []
    var steps: [Step] = []
    var overlap: Overlap = .one_more
    /// For a schedule: a place's clock instead of this Mac's, like `Europe/Paris`.
    var timeZone: String?
    /// In a practice run, what set it off.
    var triggerSample: String?

    static let maxSteps = 100
    static let longestQueue = 20
    static let longestLoop = 500
    static let mostRepeats = 100
    static let mostPaths = 6
    static let mostLanes = 4
    /// Top level, and three levels of steps inside steps.
    static let maxDepth = 4
    static let shortestEvery = 15
    static let longestEvery = 7 * 24 * 60
    static let mostTriggers = 8
    static let longestWait = 1440

    /// Depth first, in reading order.
    var allSteps: [Step] {
        func walk(_ list: [Step]) -> [Step] { list.flatMap { [$0] + $0.parts.flatMap { walk($0.steps) } } }
        return walk(steps)
    }

    func step(_ id: String) -> Step? { allSteps.first { $0.id == id } }

    var triggers: [Trigger] { [trigger] + alsoWhen }

    func calling(_ old: String, instead name: String) -> FlowBody {
        var out = self
        out.steps = steps.map { $0.calling(old, instead: name) }
        return out
    }

    /// How many levels of steps it goes down: what `maxDepth` limits.
    var depth: Int {
        func down(_ steps: [Step]) -> Int {
            steps.map { step in
                let inside = step.parts.map { down($0.steps) }.max()
                return 1 + (inside.map { max($0, 1) } ?? 0)
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
    /// When each "every so often" last came round, by its minutes: starting for another way doesn't put it off.
    var lastEvery: [Int: Date] = [:]
    func countsFrom(_ trigger: Trigger) -> Date? {
        guard let lastFire else { return nil }
        if case .every(let minutes, _) = trigger, let own = lastEvery[minutes] { return own }
        return lastFire
    }
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
    /// What went live before, oldest first.
    struct Revision: Equatable, Sendable {
        var at: Date
        var body: FlowBody
    }

    var revisions: [Revision] = []
    static let keptRevisions = 20
    /// Starts waiting their turn, on a queue: what set each off.
    var waitingStarts: [String] = []
    /// What practice showed, for the draft it practiced: nil once it changed.
    var practiced: FlowBody?

    /// What a Save last kept: what turning on or applying uses.
    var kept: FlowBody { saved ?? draft }
    /// On the screen, not saved yet.
    var hasUnsaved: Bool { saved != nil }
    /// Saved, not live yet.
    var hasChanges: Bool { live != nil && live != kept }

    /// Back to what's running: what stopped an edit going on is no longer anything to fix. What's still true stays: a step of what's running that says nothing, or a watch nobody can vouch for.
    @MainActor mutating func settleNote() {
        guard state == .on, !hasChanges, !watchOutdated, running.unfinished == nil, startProblem != Engine.watchUnclear else { return }
        startProblem = nil
    }

    /// Moves what's on the screen to this, keeping straight what's saved: undo, redo, a version brought back.
    mutating func show(_ body: FlowBody) {
        let keptBefore = kept
        draft = body
        saved = body == keptBefore ? nil : keptBefore
    }

    /// After an edit: remembers what was saved, or says there's nothing to save if the edit came back to it.
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
        var out: [String: Any] = ["trigger": json(body.trigger), "steps": body.steps.map(json)]
        if !body.alsoWhen.isEmpty { out["also_when"] = body.alsoWhen.map(json) }
        if body.overlap != .one_more { out["overlap"] = body.overlap.rawValue }
        if let zone = body.timeZone { out["time_zone"] = zone }
        if let sample = body.triggerSample { out["trigger_sample"] = sample }
        return out
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
            out["if"] = json(c)
            out["then"] = then.map(json)
            out["else"] = otherwise.map(json)
        case .wait(let minutes): out["wait_minutes"] = minutes
        case .flow(let name): out["run_flow"] = name
        case .repeatUntil(let c, let times, let steps):
            out["repeat"] = steps.map(json)
            out["until"] = json(c)
            out["times"] = times
        case .forEach(let items, let limit, let failure, let steps):
            out["for_each"] = items
            out["limit"] = limit
            if failure != .stop { out["item_failure"] = failure.rawValue }
            out["steps"] = steps.map(json)
        case .choose(let value, let paths, let otherwise):
            out["choose"] = value
            out["paths"] = paths.map { ["when": $0.when, "steps": $0.steps.map(json)] as [String: Any] }
            out["else"] = otherwise.map(json)
        case .attempt(let steps, let recover, let always):
            out["try"] = steps.map(json)
            out["recover"] = recover.map(json)
            out["always"] = always.map(json)
        case .parallel(let lanes):
            out["parallel"] = lanes.map { ["name": $0.name, "steps": $0.steps.map(json)] as [String: Any] }
        case .call(let flow, let inputs):
            out["call_flow"] = flow
            if !inputs.isEmpty { out["inputs"] = inputs }
        case .finish(let value): out["finish"] = value
        case .data(let d):
            var data: [String: Any] = ["op": d.op.rawValue, "from": d.from]
            if let v = d.field { data["field"] = v }
            if let v = d.test { data["test"] = v.rawValue }
            if let v = d.than { data["than"] = v }
            if d.descending { data["descending"] = true }
            if let v = d.count { data["count"] = v }
            if let v = d.separator { data["separator"] = v }
            out["data"] = data
        case .form(let f):
            out["form"] = ["title": f.title, "hours": f.hours, "fields": f.fields.map { field -> [String: Any] in
                var one: [String: Any] = ["name": field.name, "label": field.label, "kind": field.kind.rawValue, "required": field.required]
                if !field.options.isEmpty { one["options"] = field.options }
                return one
            }] as [String: Any]
        case .waitFor(let event, let contains, let minutes):
            var wait: [String: Any] = ["event": event, "minutes": minutes]
            if let contains { wait["contains"] = contains }
            out["wait_for"] = wait
        }
        if let fields = step.fields { out["fields"] = fields }
        if let sample = step.sample { out["sample"] = sample }
        return out
    }

    /// Reads a definition, saying what to fix in words a person and a model can both act on. Unknown keys are mistakes: one
    /// silently dropped would run something other than what was meant.
    /// `saved`: read back from disk, where the limit on depth doesn't apply: what was kept is never lost to a limit that came later.
    private static func json(_ c: Condition) -> [String: Any] {
        var check: [String: Any] = ["value": c.value, "test": c.test.rawValue, "than": c.than]
        // "Or" with nothing in it yet still says "any of": removing the last check doesn't change what adding one back means.
        if !c.also.isEmpty || c.any {
            check[c.any ? "or" : "and"] = c.also.map { ["value": $0.value, "test": $0.test.rawValue, "than": $0.than] as [String: Any] }
        }
        return check
    }

    private static func condition(_ c: [String: Any]) throws -> Condition {
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
        return condition
    }

    static func body(_ any: Any?, saved: Bool = false) throws -> FlowBody {
        guard let o = any as? [String: Any] else { throw Problem(L("A flow is an object with “trigger” and “steps”.")) }
        try only(o, ["trigger", "also_when", "steps", "overlap", "time_zone", "trigger_sample"], in: "flow")
        var used = Set<String>()
        var made = FlowBody(trigger: try trigger(o["trigger"], saved: saved), steps: try steps(o["steps"] ?? [], depth: saved ? -64 : 1, used: &used))
        let also = o["also_when"] as? [Any] ?? []
        guard also.count < FlowBody.mostTriggers else { throw Problem(L("A flow can start {count} ways at most.", ["count": Format.integer(FlowBody.mostTriggers)])) }
        made.alsoWhen = try also.map { raw in
            let more = try trigger(raw, saved: saved)
            switch more {
            case .days, .every, .event: return more
            case .manual, .watch: throw Problem(L("“also_when” is for times and things that happen. A watch can only be what first sets it off."))
            }
        }
        if let raw = o["overlap"] as? String {
            guard let overlap = FlowBody.Overlap(rawValue: raw) else { throw Problem(L("“overlap” is one_more, queue or skip.")) }
            made.overlap = overlap
        }
        made.triggerSample = (o["trigger_sample"] as? String)?.nonEmpty
        if let zone = (o["time_zone"] as? String)?.nonEmpty {
            guard TimeZone(identifier: zone) != nil else { throw Problem(L("“{zone}” isn't a time zone: use a name like Europe/Paris.", ["zone": zone])) }
            made.timeZone = zone
        }
        if !saved, made.allSteps.count > FlowBody.maxSteps {
            throw Problem(L("A flow can have at most {count} steps.", ["count": Format.integer(FlowBody.maxSteps)]))
        }
        return made
    }

    /// `saved`: what's on disk. A page saves as it goes, so a target cleared or a number out of range is a trigger being written: it reads
    /// back as it is and is marked to fix, rather than losing the flow.
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
        guard depth <= FlowBody.maxDepth else { throw Problem(L("That goes too deep: a flow can hold steps inside steps {count} levels down.", ["count": Format.integer(FlowBody.maxDepth)])) }
        return try list.map { try step($0, depth: depth, used: &used) }
    }

    private static let doers = ["do", "ai", "ask", "text", "if", "wait_minutes", "run_flow", "for_each", "repeat", "choose", "try", "parallel", "call_flow", "finish", "data", "form", "wait_for"]

    static func step(_ any: Any, depth: Int, used: inout Set<String>) throws -> Step {
        // Read back from disk, where `body` starts the depth below any limit: what a page saved as it went is kept and marked, never refused.
        let saved = depth < 0
        guard let o = any as? [String: Any] else { throw Problem(L("Each step is an object.")) }
        try only(o, ["id", "name", "on_failure", "sample", "do", "with", "ai", "fields", "ask", "options", "text", "if", "then", "else", "wait_minutes", "run_flow",
                     "for_each", "limit", "item_failure", "steps", "repeat", "until", "times", "choose", "paths", "try", "recover", "always", "parallel", "call_flow", "inputs", "finish", "data", "form", "wait_for"], in: "step")
        let kinds = doers.filter { o[$0] != nil }
        guard kinds.count == 1 else { throw Problem(L("A step does one thing: {kinds}.", ["kinds": doers.joined(separator: ", ")])) }
        var id = (o["id"] as? String)?.trimmed ?? ""
        if id.isEmpty {
            var n = used.count + 1
            while used.contains("s\(n)") { n += 1 }
            id = "s\(n)"
        }
        // Saved before a name was taken for what scopes bring, it keeps it.
        guard id.range(of: #"^[a-z0-9_]{1,24}$"#, options: .regularExpression) != nil, !(depth > 0 ? Values.reserved : Values.ambient).contains(id) else {
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
            kind = .branch(try condition(c),
                           then: try steps(o["then"] ?? [], depth: depth + 1, used: &used), otherwise: try steps(o["else"] ?? [], depth: depth + 1, used: &used))
        } else if let minutes = (o["wait_minutes"] as? NSNumber)?.intValue {
            guard (1...FlowBody.longestWait).contains(minutes) else {
                throw Problem(L("A wait is 1 to {count} minutes.", ["count": Format.integer(FlowBody.longestWait)]))
            }
            kind = .wait(minutes: minutes)
        } else if let name = o["run_flow"] as? String, saved || !name.trimmed.isEmpty {
            kind = .flow(name)
        } else if o["repeat"] != nil {
            guard let until = o["until"] as? [String: Any] else { throw Problem(L("“repeat” needs “until”: what has to hold for it to stop.")) }
            if o["times"] != nil, !(o["times"] is NSNumber) { throw Problem(L("“times” is 1 to {count}.", ["count": Format.integer(FlowBody.mostRepeats)])) }
            let times = (o["times"] as? NSNumber)?.intValue ?? FlowBody.mostRepeats
            guard (1...FlowBody.mostRepeats).contains(times) else { throw Problem(L("“times” is 1 to {count}.", ["count": Format.integer(FlowBody.mostRepeats)])) }
            kind = .repeatUntil(until: try condition(until), times: times, steps: try steps(o["repeat"], depth: depth + 1, used: &used))
        } else if let items = o["for_each"] as? String, saved || !items.trimmed.isEmpty {
            let limit = (o["limit"] as? NSNumber)?.intValue ?? FlowBody.longestLoop
            guard (1...FlowBody.longestLoop).contains(limit) else { throw Problem(L("“limit” is 1 to {count} items.", ["count": Format.integer(FlowBody.longestLoop)])) }
            var failure = Step.LoopFailure.stop
            if let raw = o["item_failure"] as? String {
                guard let f = Step.LoopFailure(rawValue: raw) else { throw Problem(L("“item_failure” is stop or collect.")) }
                failure = f
            }
            kind = .forEach(items: items, limit: limit, onFailure: failure, steps: try steps(o["steps"] ?? [], depth: depth + 1, used: &used))
        } else if let value = o["choose"] as? String, saved || !value.trimmed.isEmpty {
            let raw = o["paths"] as? [[String: Any]] ?? []
            guard saved || (1...FlowBody.mostPaths).contains(raw.count) else { throw Problem(L("“paths” are 1 to {count} ways to go.", ["count": Format.integer(FlowBody.mostPaths)])) }
            let paths = try raw.map { p -> Step.Path in
                guard let when = p["when"] as? String else { throw Problem(L("Each path says “when”.")) }
                return Step.Path(when: when, steps: try steps(p["steps"] ?? [], depth: depth + 1, used: &used))
            }
            kind = .choose(value: value, paths: paths, otherwise: try steps(o["else"] ?? [], depth: depth + 1, used: &used))
        } else if o["try"] != nil {
            kind = .attempt(steps: try steps(o["try"], depth: depth + 1, used: &used), recover: try steps(o["recover"] ?? [], depth: depth + 1, used: &used), always: try steps(o["always"] ?? [], depth: depth + 1, used: &used))
        } else if let raw = o["parallel"] as? [[String: Any]] {
            guard saved || (2...FlowBody.mostLanes).contains(raw.count) else { throw Problem(L("“parallel” is 2 to {count} lanes.", ["count": Format.integer(FlowBody.mostLanes)])) }
            kind = .parallel(lanes: try raw.enumerated().map { at, lane in
                Step.Lane(name: (lane["name"] as? String)?.nonEmpty ?? L("Lane {count}", ["count": Format.integer(at + 1)]), steps: try steps(lane["steps"] ?? [], depth: depth + 1, used: &used))
            })
        } else if let flow = o["call_flow"] as? String, saved || !flow.trimmed.isEmpty {
            kind = .call(flow: flow, inputs: o["inputs"] as? [String: String] ?? [:])
        } else if let value = o["finish"] as? String {
            kind = .finish(value)
        } else if let raw = o["data"] as? [String: Any] {
            guard let op = (raw["op"] as? String).flatMap(DataStep.Op.init(rawValue:)), let from = raw["from"] as? String, saved || !from.trimmed.isEmpty else {
                throw Problem(L("“data” needs “from” and “op”: {ops}.", ["ops": DataStep.Op.allCases.map(\.rawValue).joined(separator: ", ")]))
            }
            var test: Condition.Test?
            if let t = raw["test"] as? String {
                guard let known = Condition.Test(rawValue: t) else { throw Problem(L("“test” is one of {tests}.", ["tests": Condition.Test.allCases.map(\.rawValue).joined(separator: ", ")])) }
                test = known
            }
            kind = .data(DataStep(op: op, from: from, field: (raw["field"] as? String)?.nonEmpty, test: test, than: raw["than"] as? String, descending: raw["descending"] as? Bool ?? false,
                                  count: ((raw["count"] as? NSNumber)?.intValue).map { max($0, 1) }, separator: raw["separator"] as? String))
        } else if let raw = o["form"] as? [String: Any] {
            let list = raw["fields"] as? [[String: Any]] ?? []
            guard (1...12).contains(list.count) else { throw Problem(L("A form has 1 to 12 fields.")) }
            let hours = (raw["hours"] as? NSNumber)?.intValue ?? 24
            guard (1...FormStep.longestHours).contains(hours) else { throw Problem(L("A form waits 1 to {count} hours.", ["count": Format.integer(FormStep.longestHours)])) }
            kind = .form(FormStep(title: raw["title"] as? String ?? "", fields: try list.map { f in
                guard let name = (f["name"] as? String)?.nonEmpty, name.range(of: #"^[a-z0-9_]{1,24}$"#, options: .regularExpression) != nil else { throw Problem(L("Each field has a “name”: up to 24 lowercase letters, digits and _.")) }
                return FormStep.Field(name: name, label: (f["label"] as? String)?.nonEmpty ?? name, kind: (f["kind"] as? String).flatMap(FormStep.Field.Kind.init(rawValue:)) ?? .text,
                                      options: f["options"] as? [String] ?? [], required: f["required"] as? Bool ?? true)
            }, hours: hours))
        } else if let raw = o["wait_for"] as? [String: Any], let event = raw["event"] as? String {
            guard Trigger.events.contains(event) else { throw Problem(L("“event” is one of {events}.", ["events": Trigger.events.joined(separator: ", ")])) }
            let minutes = (raw["minutes"] as? NSNumber)?.intValue ?? 60
            guard (1...FlowBody.longestWait * 30).contains(minutes) else { throw Problem(L("A wait is 1 to {count} minutes.", ["count": Format.integer(FlowBody.longestWait * 30)])) }
            kind = .waitFor(event: event, contains: (raw["contains"] as? String)?.nonEmpty, minutes: minutes)
        } else {
            throw Problem(L("A step does one thing: {kinds}.", ["kinds": doers.joined(separator: ", ")]))
        }
        var fields: [String: String]?
        if let raw = o["fields"] as? [String: String] {
            guard case .ai = kind else { throw Problem(L("Only a step that writes with AI has “fields”.")) }
            guard raw.values.allSatisfy({ ["text", "number", "yes_no", "list"].contains($0) }) else { throw Problem(L("Each of “fields” is text, number, yes_no or list.")) }
            fields = raw
        }
        return Step(id: id, name: (o["name"] as? String)?.nonEmpty, kind: kind, onFailure: failure, sample: (o["sample"] as? String)?.nonEmpty, fields: fields)
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
    func clipped(_ longest: Int) -> String { count <= longest ? self : String(prefix(longest)) + "…" }
    func prefixString(_ n: Int) -> String { String(prefix(n)) }
}
