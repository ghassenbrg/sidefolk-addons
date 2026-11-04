import Foundation

/// A step's values as they were written. Kept typed so two definitions can be compared, and so a plan's values go out exactly as saved.
enum JSON: Equatable, Sendable {
    case null, bool(Bool), number(Double), string(String), array([JSON]), object([String: JSON])

    init(_ any: Any?) {
        switch any {
        // Only a real true or false: a plain 1 also passes for a Bool in Swift.
        case let b as Bool where CFGetTypeID(any! as CFTypeRef) == CFBooleanGetTypeID(): self = .bool(b)
        case let n as NSNumber: self = .number(n.doubleValue)
        case let s as String: self = .string(s)
        case let a as [Any]: self = .array(a.map { JSON($0) })
        case let o as [String: Any]: self = .object(o.mapValues { JSON($0) })
        default: self = .null
        }
    }

    var any: Any {
        switch self {
        case .null: NSNull()
        case .bool(let b): b
        // As words if it isn't a real number: one infinity would stop the whole file saving.
        case .number(let n): !n.isFinite ? String(n) as Any : n == n.rounded() && abs(n) < 1e15 ? Int(n) as Any : n as Any
        case .string(let s): s
        case .array(let a): a.map(\.any)
        case .object(let o): o.mapValues(\.any)
        }
    }

    var string: String? { if case .string(let s) = self { s } else { nil } }

    /// Every string, however deep.
    var strings: [String] {
        switch self {
        case .string(let s): [s]
        case .array(let a): a.flatMap(\.strings)
        case .object(let o): o.values.flatMap(\.strings)
        default: []
        }
    }

    /// Replaces each string through `change`.
    func mapStrings(_ change: (String) -> String) -> JSON {
        switch self {
        case .string(let s): .string(change(s))
        case .array(let a): .array(a.map { $0.mapStrings(change) })
        case .object(let o): .object(o.mapValues { $0.mapStrings(change) })
        default: self
        }
    }
}

enum JSONText {
    static func write(_ any: Any, pretty: Bool = false) -> String {
        var options: JSONSerialization.WritingOptions = [.sortedKeys, .withoutEscapingSlashes]
        if pretty { options.insert(.prettyPrinted) }
        guard JSONSerialization.isValidJSONObject(any), let data = try? JSONSerialization.data(withJSONObject: any, options: options) else { return "{}" }
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    static func read(_ text: String) -> Any? {
        guard let data = text.data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: data)
    }
}
