import Foundation

/// A step's values as they were written. Kept typed so two definitions can be compared, and so a plan's values go out exactly as saved.
enum JSON: Equatable, Sendable {
    case null, bool(Bool), number(Double), string(String), array([JSON]), object([String: JSON])

    init(_ any: Any?) {
        switch any {
        // Only a real true or false: a plain 1 also passes for a Bool in Swift.
        case let b as Bool where CFGetTypeID(any! as CFTypeRef) == CFBooleanGetTypeID(): self = .bool(b)
        // A number too big for a Double to hold exactly (a 16-digit id, or past any size) stays as what it said, so it's never quietly another number.
        case let n as NSNumber: self = abs(n.doubleValue) < 9_007_199_254_740_992 ? .number(n.doubleValue) : .string(n.stringValue)
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

    /// What's in these words, if they're JSON that says one thing. The parser keeps one of two keys with a word to no one, and takes `1e-999` for 0: neither is what's written, so neither is read.
    static func read(_ text: String) -> Any? {
        guard let data = text.data(using: .utf8), let parsed = try? JSONSerialization.jsonObject(with: data), saysOneThing(data) else { return nil }
        return parsed
    }

    /// Over JSON the parser already took, so it only has to tell strings, numbers and brackets apart.
    static func saysOneThing(_ data: Data) -> Bool {
        let bytes = [UInt8](data)
        var open: [Set<String>?] = [], at = 0
        func isNumberByte(_ byte: UInt8) -> Bool { (48...57).contains(byte) || [43, 45, 46, 69, 101].contains(byte) }
        while at < bytes.count {
            switch bytes[at] {
            case 0x7B:
                open.append([])
                at += 1
            case 0x5B:
                open.append(nil)
                at += 1
            case 0x7D, 0x5D:
                _ = open.popLast()
                at += 1
            case 0x22:
                var end = at + 1
                while end < bytes.count, bytes[end] != 0x22 { end += bytes[end] == 0x5C ? 2 : 1 }
                var next = end + 1
                while next < bytes.count, [32, 9, 10, 13].contains(bytes[next]) { next += 1 }
                if next < bytes.count, bytes[next] == 0x3A, !open.isEmpty, open[open.count - 1] != nil {
                    // Escapes count: `"a"` and `"\u0061"` are one key.
                    let key = (try? JSONSerialization.jsonObject(with: Data(bytes[at...min(end, bytes.count - 1)]), options: .fragmentsAllowed)) as? String ?? ""
                    guard open[open.count - 1]!.insert(key).inserted else { return false }
                }
                at = end + 1
            case let byte where byte == 45 || (48...57).contains(byte):
                var end = at
                while end < bytes.count, isNumberByte(bytes[end]) { end += 1 }
                let word = String(decoding: bytes[at..<end], as: UTF8.self)
                guard let number = Double(word), number.isFinite else { return false }
                let digits = word.prefix { $0 != "e" && $0 != "E" }
                if number == 0, digits.contains(where: { ("1"..."9").contains($0) }) { return false }
                at = end
            default:
                at += 1
            }
        }
        return true
    }
}
