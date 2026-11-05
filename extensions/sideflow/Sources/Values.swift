import Foundation
import SidefolkExtensionKit

/// What a run knows so far: each step's output by its id, and `trigger`, what set the run off. Values keep their type: a list stays a list, text that looks like a number stays text,
/// and something never made is told from something empty. A value reaches a tool only where a flow's definition put `{{name}}`: outside words never choose a tool, and the host
/// checks where each can go.
struct Values: Equatable, Sendable {
    /// Always there, or meaning nothing when not, so never "missing".
    static let ambient: Set<String> = ["trigger", "today", "now"]
    /// Names a step can't take: these, and what scopes bring.
    static let reserved: Set<String> = ambient.union(["item", "index", "error", "input"])
    /// Longest text kept per value; what a model is given is bounded again.
    static let keep = 64_000
    /// What goes to a tool as words, as it always did: what's kept above is for looking inside and for the next step, and a note takes less than a page.
    static let wordsKept = 8_000
    /// Largest whole value: past this it's cut to text, and the step that used it can see that it was.
    static let keepWhole = 256 * 1024

    var named: [String: JSON] = [:]
    /// What a tool said in words beside the fields it gave: `{{step}}` in a sentence reads this, `{{step.field}}` the field.
    var said: [String: String] = [:]
    var today = ""
    var now = ""

    private static let slot = try! NSRegularExpression(pattern: #"\{\{\s*([A-Za-z0-9_]{1,40})((?:\.[A-Za-z0-9_]{1,40}|\[\d{1,5}\])*)\s*\}\}"#)

    /// The names a text refers to, in order, without what's after them.
    static func references(_ text: String) -> [String] {
        slot.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { Range($0.range(at: 1), in: text).map { String(text[$0]) } }
    }

    /// The text with each `{{name.path}}` replaced by what `words` says of it.
    static func replacingSlots(in text: String, _ words: (_ name: String, _ path: String) -> String) -> String {
        var out = "", from = text.startIndex
        for match in slot.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let whole = Range(match.range, in: text), let name = Range(match.range(at: 1), in: text), let path = Range(match.range(at: 2), in: text) else { continue }
            out += text[from..<whole.lowerBound]
            out += words(String(text[name]), String(text[path]))
            from = whole.upperBound
        }
        return out + text[from...]
    }

    /// `a.b[2]`: each key or place in turn.
    static func parts(of path: String) -> [String] {
        path.replacingOccurrences(of: "[", with: ".").replacingOccurrences(of: "]", with: "").split(separator: ".").map(String.init)
    }

    /// Words that are a record or a list, as one, for what looks inside them: a tool's answer stays as it said it, and only a field asked for, a loop or a data step reads it this way.
    static func structured(_ value: JSON) -> JSON {
        guard case .string(let text) = value, let parsed = JSONText.read(text) else { return value }
        switch JSON(parsed) {
        case .object(let o): return .object(o)
        case .array(let a): return .array(a)
        default: return value
        }
    }

    /// What's at a path in a value, or nil when nothing is: a missing field isn't an empty one.
    static func walk(_ value: JSON, path: [String]) -> JSON? {
        var at = value
        for part in path {
            // A tool's answer stays words wherever it's been passed to: in a list a loop made, in what a called flow was given.
            switch structured(at) {
            case .object(let o):
                guard let next = o[part] else { return nil }
                at = next
            case .array(let a):
                guard let i = Int(part), a.indices.contains(i) else { return nil }
                at = a[i]
            default:
                return nil
            }
        }
        return at
    }

    /// A value as words: text as it is, a whole number without a point, a list or record as JSON, null as nothing.
    static func text(_ value: JSON) -> String {
        switch value {
        case .null: ""
        case .bool(let b): b ? "true" : "false"
        case .number(let n): n.isFinite && n == n.rounded() && abs(n) < 1e15 ? String(Int(n)) : String(n)
        case .string(let s): s
        case .array, .object: JSONText.write(value.any)
        }
    }

    private func base(_ name: String) -> JSON? {
        switch name {
        case "today": .string(today)
        case "now": .string(now)
        default: named[name]
        }
    }

    /// What a step gave as a whole, to go on from it: a tool's words, as `{{step}}` is everywhere; its fields stay with the run that asks for them by name.
    func whole(_ name: String) -> JSON? {
        named[name].map { value in said[name].map(JSON.string) ?? value }
    }

    /// Whether a step left an answer. A data step's null is one; a called flow that made nothing didn't.
    func gaveAnswer(_ step: Step) -> Bool {
        guard let value = named[step.id] else { return false }
        if case .call = step.kind { return value != .null }
        return true
    }

    /// `name` with what's after it, or nil when nothing is there.
    func resolve(_ name: String, path: String = "") -> JSON? {
        guard let value = base(name) else { return nil }
        return Self.walk(value, path: Self.parts(of: path))
    }

    /// Each `{{name.path}}` in a text, path and all.
    static func slots(_ text: String) -> [(name: String, path: String)] {
        slot.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { match in
            guard let n = Range(match.range(at: 1), in: text), let p = Range(match.range(at: 2), in: text) else { return nil }
            return (String(text[n]), String(text[p]))
        }
    }

    /// What one check can't answer from what's there. A record without a field has nothing there, and a step that never ran is the same, so "is empty" and "mentions" can say so.
    /// Two things can't be said: that something isn't what it was never seen to be ("is not", "doesn't mention"), and anything about a field of plain words,
    /// where "Service unavailable" would read as a reply saying there are no errors.
    private func blind(_ check: Condition) -> String? {
        let negative = check.test == .is_not || check.test == .not_contains
        let ignoresThan = check.test == .is_empty || check.test == .not_empty
        for (name, path) in Self.slots(check.value) + (ignoresThan ? [] : Self.slots(check.than)) {
            if Self.ambient.contains(name), path.isEmpty { continue }
            // What wasn't given to a flow is nothing, the one way to have it optional. Words given to it still have no fields.
            let cantSay = negative && name != "input"
            guard let root = base(name) else {
                if cantSay { return name + path }
                continue
            }
            if path.isEmpty {
                // A step that gave nothing, not one that found nothing: an empty list is an answer.
                if cantSay, Self.text(root).isEmpty { return name }
                continue
            }
            if let found = resolve(name, path: path) {
                // A field said to be nothing says nothing. An empty one is an answer, except what a flow was given: that may be a step that gave nothing, passed along.
                if negative, found == .null || (name == "input" && Self.text(found).isEmpty) { return name + path }
                continue
            }
            if cantSay || Self.endsInWords(root, path: Self.parts(of: path)) { return name + path }
        }
        return nil
    }

    private static func words(_ value: JSON, _ each: Int) -> String {
        let all = text(value)
        return all.count > each ? String(all.prefix(each)) : all
    }

    /// Whether a path that found nothing stopped at words, which have no fields, rather than at a record or a list that just doesn't have this one.
    private static func endsInWords(_ value: JSON, path: [String]) -> Bool {
        var at = value
        for part in path {
            at = structured(at)
            switch at {
            case .object(let o):
                guard let next = o[part] else { return false }
                at = next
            case .array(let a):
                guard let i = Int(part), a.indices.contains(i) else { return false }
                at = a[i]
            default:
                return !text(at).isEmpty
            }
        }
        return false
    }

    /// What keeps a condition from deciding, if anything does: a check that can answer for all of them settles it, the first to hold in "any of", the first to fail in "all of".
    func undecided(_ condition: Condition) -> String? {
        let unknown = condition.checks.compactMap(blind)
        guard let first = unknown.first else { return nil }
        let known = condition.checks.filter { blind($0) == nil }
        let settled = condition.any ? known.contains { $0.checkHolds(self) } : known.contains { !$0.checkHolds(self) }
        return settled ? nil : first
    }

    /// What these words use that no step has made: a step on the path not taken, a field that isn't there. Filling it in as nothing would give a real action an empty value.
    func missing(in texts: [String]) -> [String] {
        texts.flatMap { text -> [String] in
            Self.slot.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { match in
                guard let n = Range(match.range(at: 1), in: text), let p = Range(match.range(at: 2), in: text) else { return nil }
                let (name, path) = (String(text[n]), String(text[p]))
                if Self.ambient.contains(name), path.isEmpty { return nil }
                return resolve(name, path: path) == nil ? name + path : nil
            }
        }
    }

    /// `each`: how much of a value goes in, where only so much should.
    func fill(_ text: String, each: Int = .max) -> String {
        var out = "", from = text.startIndex
        for match in Self.slot.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let whole = Range(match.range, in: text), let name = Range(match.range(at: 1), in: text), let path = Range(match.range(at: 2), in: text) else { continue }
            out += text[from..<whole.lowerBound]
            out += words(String(text[name]), path: String(text[path]), each)
            from = whole.upperBound
        }
        return out + text[from...]
    }

    /// A value in a sentence. What a tool said beats its fields written out.
    private func words(_ name: String, path: String, _ each: Int = .max) -> String {
        if path.isEmpty, named[name] != nil, let said = said[name] { return String(said.prefix(each)) }
        return resolve(name, path: path).map { Self.words($0, each) } ?? ""
    }

    /// What goes to a tool for a value as written. A field that is exactly one value gets that value, its own type and all: a list into a list, not JSON-shaped words.
    func fill(native json: JSON) -> JSON {
        switch json {
        case .string(let s):
            let range = NSRange(s.startIndex..., in: s)
            if let match = Self.slot.firstMatch(in: s, range: range), match.range == range, let n = Range(match.range(at: 1), in: s), let p = Range(match.range(at: 2), in: s),
               let found = resolve(String(s[n]), path: String(s[p])) {
                // A tool's `{{step}}` is what it said, wherever it goes; its fields are asked for by name.
                if p.isEmpty, let words = said[String(s[n])] { return .string(words) }
                return found
            }
            return .string(fill(s))
        case .array(let a): return .array(a.map(fill(native:)))
        case .object(let o): return .object(o.mapValues(fill(native:)))
        default: return json
        }
    }

    func value(_ name: String) -> String { words(name, path: "") }

    func fill(_ input: [String: JSON]) -> [String: Any] {
        input.mapValues { fill(native: $0).any }
    }

    /// For a tool: what it wants as words stays words, whatever the value is; a list or a number goes as itself only where the tool takes one.
    /// A tool's answer that's a list goes as a list only to a parameter that says it takes one, and only as a whole value: anywhere else it's the words it was, what a card showed.
    /// `absentIn`: what can't be empty, a number or a choice: a field left blank isn't given to it.
    func fill(_ input: [String: JSON], wordsIn textual: Set<String>, listsIn lists: Set<String> = [], absentIn absent: Set<String> = []) -> [String: Any] {
        Dictionary(uniqueKeysWithValues: input.map { key, value in
            if textual.contains(key), case .string(let s) = value { return (key, fill(s, each: Self.wordsKept) as Any) }
            let filled = fill(native: value)
            if absent.contains(key), filled == .string(""), case .string(let s) = value, Self.isOneSlot(s), Self.slots(s).first?.path.isEmpty == false { return (key, JSON.null.any) }
            if lists.contains(key), case .string(let s) = value, Self.isOneSlot(s), case .array(let list) = Self.structured(filled) { return (key, JSON.array(list).any) }
            return (key, filled.any)
        })
    }

    private static func isOneSlot(_ text: String) -> Bool {
        let whole = NSRange(text.startIndex..., in: text)
        return slot.firstMatch(in: text, range: whole)?.range == whole
    }

    /// Whether it can be kept as it is, or would be cut.
    func fits(_ value: JSON) -> Bool { JSONText.write(value.any).utf8.count <= Self.keepWhole }

    mutating func set(_ name: String, _ text: String) {
        said[name] = nil
        named[name] = .string(String(text.prefix(Self.keep)))
    }

    /// What a practice's pretending can't answer: a field of a value it made up, however far in. A field its tool doesn't say it gives isn't one.
    func isSampleField(_ name: String) -> Bool {
        let parts = Self.parts(of: name)
        guard let root = parts.first, var at = base(root) else { return false }
        for part in parts.dropFirst() {
            if Self.text(at) == L("(sample)") { return true }
            guard let next = Self.walk(at, path: [part]) else { return false }
            at = next
        }
        return false
    }

    /// Whether these words come only from what a practice made up, so there's nothing in them to work anything out from.
    func pretends(_ text: String) -> Bool {
        Self.slots(text).contains { slot in
            isSampleField(slot.name + slot.path) || words(slot.name, path: slot.path) == L("(sample)")
        }
    }

    /// Why a run can't go on with something it uses. A step that ran may have done something, so the reason has to be the true one.
    func whyMissing(_ name: String) -> String {
        let root = name.split(whereSeparator: { $0 == "." || $0 == "[" }).first.map(String.init) ?? name
        return named[root] == nil ? L("It uses “{name}”, but that step didn't run this time.", ["name": name]) : L("It uses “{name}”, but that step's answer doesn't have it.", ["name": name])
    }

    /// What these words use that no step has made and this run has to stop for. A practice only pretended, so a field of that isn't one.
    func stopsFor(_ texts: [String], practice: Bool) -> String? {
        missing(in: texts).first { !practice || !isSampleField($0) }
    }

    /// A tool's answer: its fields if it gave any it can keep, and always its words.
    mutating func set(_ name: String, answer words: String, fields: String?) {
        guard let fields, let raw = JSONText.read(fields) else { return set(name, words) }
        set(name, JSON(raw))
        said[name] = String(words.prefix(Self.keep))
    }

    mutating func set(_ name: String, _ value: JSON) {
        if case .string(let s) = value { return set(name, s) }
        said[name] = nil
        let size = JSONText.write(value.any).utf8.count
        named[name] = size <= Self.keepWhole ? value : .string(String(Self.text(value).prefix(Self.keep)))
    }
}
