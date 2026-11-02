import Foundation

/// What a run knows so far: each step's output by its id, and `trigger`, what set the run off. A value reaches a tool only where a flow's
/// definition put `{{name}}`: outside words never choose a tool, and the host checks where each can go.
struct Values: Equatable, Sendable {
    /// Names a step can't take.
    static let reserved: Set<String> = ["trigger", "today", "now"]
    /// Longest kept per value; what a model is given is bounded again.
    static let keep = 8000

    var named: [String: String] = [:]
    var today = ""
    var now = ""

    private static let slot = try! NSRegularExpression(pattern: #"\{\{\s*([A-Za-z0-9_]{1,40})\s*\}\}"#)

    /// The names a text refers to, in order.
    static func references(_ text: String) -> [String] {
        slot.matches(in: text, range: NSRange(text.startIndex..., in: text)).compactMap { Range($0.range(at: 1), in: text).map { String(text[$0]) } }
    }

    func fill(_ text: String) -> String {
        var out = "", from = text.startIndex
        for match in Self.slot.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
            guard let whole = Range(match.range, in: text), let name = Range(match.range(at: 1), in: text) else { continue }
            out += text[from..<whole.lowerBound]
            out += value(String(text[name]))
            from = whole.upperBound
        }
        return out + text[from...]
    }

    func value(_ name: String) -> String {
        switch name {
        case "today": today
        case "now": now
        default: named[name] ?? ""
        }
    }

    func fill(_ input: [String: JSON]) -> [String: Any] {
        input.mapValues { $0.mapStrings(fill).any }
    }

    mutating func set(_ name: String, _ text: String) {
        named[name] = String(text.prefix(Self.keep))
    }
}
