import Foundation

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
    /// Largest whole value: past this it's cut to text, and the step that used it can see that it was.
    static let keepWhole = 256 * 1024

    var named: [String: JSON] = [:]
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

    /// What's at a path in a value, or nil when nothing is: a missing field isn't an empty one.
    static func walk(_ value: JSON, path: [String]) -> JSON? {
        var at = value
        for part in path {
            switch at {
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

    /// `name` with what's after it, or nil when nothing is there.
    func resolve(_ name: String, path: String = "") -> JSON? {
        base(name).flatMap { Self.walk($0, path: Self.parts(of: path)) }
    }

    /// Each `{{name.path}}` in a text, path and all.
    static func slots(_ text: String) -> [(name: String, path: String)] {
        slot.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { match in
            guard let n = Range(match.range(at: 1), in: text), let p = Range(match.range(at: 2), in: text) else { return nil }
            return (String(text[n]), String(text[p]))
        }
    }

    /// What a condition looks at that isn't there, so it can't decide. Asking whether a step ran at all is what "is empty" is for, and what wasn't given to a flow is the same;
    /// a field missing from what a step did give is neither: filled in as nothing, a reply without `errors` would read as a reply saying there are none.
    func undecided(_ condition: Condition) -> String? {
        for check in condition.checks {
            if check.test == .is_empty || check.test == .not_empty {
                for (name, path) in Self.slots(check.value) where !path.isEmpty && name != "input" && resolve(name, path: "") != nil && resolve(name, path: path) == nil { return name + path }
            } else if let name = missing(in: [check.value, check.than]).first {
                return name
            }
        }
        return nil
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

    func fill(_ text: String) -> String {
        var out = "", from = text.startIndex
        for match in Self.slot.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let whole = Range(match.range, in: text), let name = Range(match.range(at: 1), in: text), let path = Range(match.range(at: 2), in: text) else { continue }
            out += text[from..<whole.lowerBound]
            out += resolve(String(text[name]), path: String(text[path])).map(Self.text) ?? ""
            from = whole.upperBound
        }
        return out + text[from...]
    }

    /// What goes to a tool for a value as written. A field that is exactly one value gets that value, its own type and all: a list into a list, not JSON-shaped words.
    func fill(native json: JSON) -> JSON {
        switch json {
        case .string(let s):
            let range = NSRange(s.startIndex..., in: s)
            if let match = Self.slot.firstMatch(in: s, range: range), match.range == range, let n = Range(match.range(at: 1), in: s), let p = Range(match.range(at: 2), in: s),
               let found = resolve(String(s[n]), path: String(s[p])) { return found }
            return .string(fill(s))
        case .array(let a): return .array(a.map(fill(native:)))
        case .object(let o): return .object(o.mapValues(fill(native:)))
        default: return json
        }
    }

    func value(_ name: String) -> String { resolve(name).map(Self.text) ?? "" }

    func fill(_ input: [String: JSON]) -> [String: Any] {
        input.mapValues { fill(native: $0).any }
    }

    /// For a tool: what it wants as words stays words, whatever the value is; a list or a number goes as itself only where the tool takes one.
    func fill(_ input: [String: JSON], wordsIn textual: Set<String>) -> [String: Any] {
        Dictionary(uniqueKeysWithValues: input.map { key, value in
            if textual.contains(key), case .string(let s) = value { return (key, fill(s) as Any) }
            return (key, fill(native: value).any)
        })
    }

    /// Whether it can be kept as it is, or would be cut.
    func fits(_ value: JSON) -> Bool { JSONText.write(value.any).utf8.count <= Self.keepWhole }

    mutating func set(_ name: String, _ text: String) {
        named[name] = .string(String(text.prefix(Self.keep)))
    }

    mutating func set(_ name: String, _ value: JSON) {
        if case .string(let s) = value { return set(name, s) }
        let size = JSONText.write(value.any).utf8.count
        named[name] = size <= Self.keepWhole ? value : .string(String(Self.text(value).prefix(Self.keep)))
    }
}
