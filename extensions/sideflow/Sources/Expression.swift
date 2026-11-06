import Foundation
import SidefolkExtensionKit

/// A small language for working a value out: arithmetic, comparison, text, lists, and reading a number whose shape the person states.
/// It can only compute: there's no way in it to name a tool, a file, the network or the clock, nothing goes round, and every run has a limit on how much it can do.
/// A value comes in by `{{name}}`, and only ever as a value: words it holds are never read as part of the expression, so they can't change what it does.
enum Expression {
    /// What a page or an agent wrote can be this long, this deep, and what it works with this big.
    static let longest = 2000
    static let deepest = 32
    static let mostWork = 20_000
    static let biggestText = 100_000

    indirect enum Node: Equatable {
        case value(JSON)
        case slot(String, String)
        case not(Node), negate(Node)
        case binary(String, Node, Node)
        case call(String, [Node])
    }

    // MARK: Reading what's written

    private enum Token: Equatable {
        case number(Double), text(String), name(String), slot(String, String), mark(String), end
    }

    private static func tokens(_ written: String) throws -> [Token] {
        guard written.utf8.count <= longest else { throw Problem(L("That's too long to work out: {count} characters at most.", ["count": Format.integer(longest)])) }
        let chars = Array(written)
        var out: [Token] = [], at = 0
        func wrong(_ what: String) -> Problem { Problem(L("It can't read “{what}” in what to work out.", ["what": String(what.prefix(40))])) }
        while at < chars.count {
            let c = chars[at]
            if c.isWhitespace { at += 1; continue }
            if c == "{", at + 1 < chars.count, chars[at + 1] == "{" {
                var end = at + 2
                while end + 1 < chars.count, !(chars[end] == "}" && chars[end + 1] == "}") { end += 1 }
                guard end + 1 < chars.count else { throw wrong(String(chars[at...])) }
                let whole = String(chars[at...(end + 1)])
                guard let slot = Values.slots(whole).first else { throw wrong(whole) }
                out.append(.slot(slot.name, slot.path))
                at = end + 2
            } else if c == "\"" {
                var end = at + 1, words = ""
                while end < chars.count, chars[end] != "\"" {
                    if chars[end] == "\\", end + 1 < chars.count {
                        end += 1
                        words.append(chars[end] == "n" ? "\n" : chars[end])
                    } else {
                        words.append(chars[end])
                    }
                    end += 1
                }
                guard end < chars.count else { throw wrong(String(chars[at...])) }
                out.append(.text(words))
                at = end + 1
            } else if c.isASCII, c.isNumber {
                var end = at
                while end < chars.count, chars[end].isASCII, chars[end].isNumber || chars[end] == "." { end += 1 }
                let word = String(chars[at..<end])
                // One plain way of writing a number here too.
                guard let number = NumberWords.typed(word) else { throw wrong(word) }
                out.append(.number(number))
                at = end
            } else if c.isASCII, c.isLetter || c == "_" {
                var end = at
                while end < chars.count, chars[end].isASCII, chars[end].isLetter || chars[end].isNumber || chars[end] == "_" { end += 1 }
                out.append(.name(String(chars[at..<end])))
                at = end
            } else {
                let two = at + 1 < chars.count ? String(chars[at...(at + 1)]) : ""
                if ["==", "!=", "<=", ">=", "&&", "||"].contains(two) {
                    out.append(.mark(two))
                    at += 2
                } else if "+-*/%<>!(),".contains(c) {
                    out.append(.mark(String(c)))
                    at += 1
                } else {
                    throw wrong(String(c))
                }
            }
        }
        return out + [.end]
    }

    /// What's written, read: or why it can't be, in words for whoever wrote it.
    static func parse(_ written: String) throws -> Node {
        let list = try tokens(written)
        var at = 0, depth = 0
        func peek() -> Token { list[at] }
        func wrong() -> Problem {
            if case .end = peek() { return Problem(L("What to work out stops too soon.")) }
            return Problem(L("It can't follow what to work out near “{what}”.", ["what": describe(peek())]))
        }
        func eat(_ mark: String) -> Bool {
            if peek() == .mark(mark) {
                at += 1
                return true
            }
            return false
        }
        func nested(_ inner: () throws -> Node) throws -> Node {
            depth += 1
            defer { depth -= 1 }
            guard depth <= deepest else { throw Problem(L("That goes too deep to work out.")) }
            return try inner()
        }
        func level(_ marks: [String], _ next: () throws -> Node) throws -> Node {
            var left = try next()
            while let mark = marks.first(where: { peek() == .mark($0) }) {
                at += 1
                left = .binary(mark, left, try next())
            }
            return left
        }
        func or() throws -> Node { try level(["||"]) { try and() } }
        func and() throws -> Node { try level(["&&"]) { try equal() } }
        func equal() throws -> Node { try level(["==", "!="]) { try compare() } }
        func compare() throws -> Node { try level(["<=", ">=", "<", ">"]) { try sum() } }
        func sum() throws -> Node { try level(["+", "-"]) { try product() } }
        func product() throws -> Node { try level(["*", "/", "%"]) { try unary() } }
        func unary() throws -> Node {
            try nested {
                if eat("!") { return .not(try unary()) }
                if eat("-") { return .negate(try unary()) }
                return try atom()
            }
        }
        func atom() throws -> Node {
            let token = peek()
            switch token {
            case .number(let n):
                at += 1
                return .value(.number(n))
            case .text(let words):
                at += 1
                return .value(.string(words))
            case .slot(let name, let path):
                at += 1
                return .slot(name, path)
            case .name(let name):
                at += 1
                switch name {
                case "true": return .value(.bool(true))
                case "false": return .value(.bool(false))
                case "null": return .value(.null)
                default: break
                }
                guard Functions.known.contains(name) else { throw Problem(L("There's nothing called “{name}” to work out with. These there are: {list}.", ["name": String(name.prefix(40)), "list": Functions.known.sorted().joined(separator: ", ")])) }
                guard eat("(") else { throw wrong() }
                var arguments: [Node] = []
                if !eat(")") {
                    repeat { arguments.append(try nested { try or() }) } while eat(",")
                    guard eat(")") else { throw wrong() }
                }
                return .call(name, arguments)
            case .mark("("):
                at += 1
                let inside = try nested { try or() }
                guard eat(")") else { throw wrong() }
                return inside
            default:
                throw wrong()
            }
        }
        let node = try or()
        guard peek() == .end else { throw wrong() }
        return node
    }

    private static func describe(_ token: Token) -> String {
        switch token {
        case .number(let n): Values.text(.number(n))
        case .text(let words): String(words.prefix(40))
        case .name(let name): name
        case .slot(let name, let path): "{{\(name)\(path)}}"
        case .mark(let mark): mark
        case .end: ""
        }
    }

    /// The values it names, for what's checked and what a plan says it reads: `{{name}}`, as anywhere else.
    static func slots(_ node: Node) -> [String] {
        switch node {
        case .value: []
        case .slot(let name, _): [name]
        case .not(let a), .negate(let a): slots(a)
        case .binary(_, let a, let b): slots(a) + slots(b)
        case .call(_, let arguments): arguments.flatMap(slots)
        }
    }

    // MARK: Working it out

    static func evaluate(_ written: String, values: Values) throws -> JSON {
        try evaluate(try parse(written), values: values)
    }

    static func evaluate(_ node: Node, values: Values) throws -> JSON {
        var work = 0
        return try run(node, values, &work)
    }

    private static func spend(_ work: inout Int, _ cost: Int = 1) throws {
        work += cost
        guard work <= mostWork else { throw Problem(L("That's too much to work out in one step.")) }
    }

    private static func run(_ node: Node, _ values: Values, _ work: inout Int) throws -> JSON {
        try spend(&work)
        switch node {
        case .value(let value):
            return value
        case .slot(let name, let path):
            guard let found = values.resolve(name, path: path) else { throw Problem(L("“{name}” has nothing in it here, so it can't be worked out.", ["name": name + path])) }
            // A tool's `{{step}}` is what it said, as everywhere else. Words stay words: nothing in them is read as the expression.
            if path.isEmpty, let words = values.said[name] { return .string(words) }
            return found
        case .not(let a):
            return .bool(!(try truth(try run(a, values, &work))))
        case .negate(let a):
            return .number(-(try number(try run(a, values, &work))))
        case .binary("&&", let a, let b):
            return .bool(try truth(try run(a, values, &work)) && truth(try run(b, values, &work)))
        case .binary("||", let a, let b):
            return .bool(try truth(try run(a, values, &work)) || truth(try run(b, values, &work)))
        case .binary(let mark, let a, let b):
            return try binary(mark, try run(a, values, &work), try run(b, values, &work), &work)
        case .call("if", let arguments):
            guard arguments.count == 3 else { throw Problem(L("“{name}” takes {count} things.", ["name": "if", "count": "3"])) }
            return try run(try truth(try run(arguments[0], values, &work)) ? arguments[1] : arguments[2], values, &work)
        case .call(let name, let arguments):
            return try Functions.call(name, try arguments.map { try run($0, values, &work) }, &work)
        }
    }

    private static func binary(_ mark: String, _ a: JSON, _ b: JSON, _ work: inout Int) throws -> JSON {
        switch mark {
        case "==": return .bool(same(a, b))
        case "!=": return .bool(!same(a, b))
        case "+":
            // Words joined, numbers added: which is decided by what they are, never by what they look like.
            if case .string(let x) = a, case .string(let y) = b {
                try fits(x.utf8.count + y.utf8.count)
                return try text(x + y, &work)
            }
            if case .number = a, case .number = b { break }
            throw Problem(L("“+” adds two numbers or joins two pieces of words. To use words as a number, say how to read them: number(…)."))
        default: break
        }
        let x = try number(a), y = try number(b)
        let made: Double
        switch mark {
        case "+": made = x + y
        case "-": made = x - y
        case "*": made = x * y
        case "/", "%":
            guard y != 0 else { throw Problem(L("It would divide by zero.")) }
            made = mark == "/" ? x / y : x.truncatingRemainder(dividingBy: y)
        case "<": return .bool(x < y)
        case ">": return .bool(x > y)
        case "<=": return .bool(x <= y)
        case ">=": return .bool(x >= y)
        default: throw Problem(L("It can't follow what to work out near “{what}”.", ["what": mark]))
        }
        guard abs(made) < 9_007_199_254_740_992 else { throw Problem(L("That number is too big to work out exactly.")) }
        return .number(made)
    }

    static func same(_ a: JSON, _ b: JSON) -> Bool { a == b }

    /// Nothing passes for true or false by looking like it: a condition says one.
    static func truth(_ value: JSON) throws -> Bool {
        if case .bool(let yes) = value { return yes }
        throw Problem(L("It needs a yes or a no here, and has “{what}”.", ["what": Values.text(value).clipped(40)]))
    }

    /// A number given as one, or words written plainly as one: anything else says how to read it, with `number`.
    static func number(_ value: JSON) throws -> Double {
        if case .number(let n) = value { return n }
        if case .string(let words) = value, let n = NumberWords.number(words) { return n }
        throw Problem(L("It needs a number here, and has “{what}”. To read words as a number, say how: number(…).", ["what": Values.text(value).clipped(40)]))
    }

    static func text(_ words: String, _ work: inout Int) throws -> JSON {
        try spend(&work, words.utf8.count / 1000)
        try fits(words.utf8.count)
        return .string(words)
    }

    /// Asked before words are put together, with how long they'd come out: past the limit nothing is built, so a few short words can't make a huge one on the way.
    static func fits(_ bytes: Int) throws {
        guard bytes <= biggestText else { throw Problem(L("That's too much to work out in one step.")) }
    }

    /// How many times `find` is in `words`, as a replace counts them: not overlapping, from the start.
    static func occurrences(of find: String, in words: String) -> Int {
        var count = 0, from = words.startIndex
        while let hit = words.range(of: find, range: from ..< words.endIndex) {
            count += 1
            from = hit.upperBound
        }
        return count
    }

    // MARK: What it can do

    enum Functions {
        static let known: Set<String> = ["if", "round", "floor", "ceil", "abs", "min", "max", "number", "percent", "text", "upper", "lower", "trim", "length", "contains", "starts_with", "ends_with", "replace", "split", "join", "first", "last", "sum", "average", "field", "default"]

        static func call(_ name: String, _ a: [JSON], _ work: inout Int) throws -> JSON {
            func needs(_ counts: ClosedRange<Int>) throws {
                guard counts.contains(a.count) else { throw Problem(L("“{name}” takes {count} things.", ["name": name, "count": counts.count == 1 ? "\(counts.lowerBound)" : "\(counts.lowerBound)-\(counts.upperBound)"])) }
            }
            func words(_ at: Int) -> String { Values.text(a[at]) }
            func list(_ at: Int) throws -> [JSON] {
                guard case .array(let items) = Values.structured(a[at]) else { throw Problem(L("“{name}” needs a list here.", ["name": name])) }
                try spend(&work, items.count)
                return items
            }
            func bounded(_ made: Double) throws -> JSON {
                guard made.isFinite, abs(made) < 9_007_199_254_740_992 else { throw Problem(L("That number is too big to work out exactly.")) }
                return .number(made)
            }
            switch name {
            case "round":
                try needs(1...2)
                let places = a.count == 2 ? Int(try Expression.number(a[1])) : 0
                guard (0...10).contains(places) else { throw Problem(L("“{name}” keeps 0 to 10 places.", ["name": name])) }
                let scale = pow(10, Double(places))
                return try bounded((try Expression.number(a[0]) * scale).rounded() / scale)
            case "floor":
                try needs(1...1)
                return try bounded(try Expression.number(a[0]).rounded(.down))
            case "ceil":
                try needs(1...1)
                return try bounded(try Expression.number(a[0]).rounded(.up))
            case "abs":
                try needs(1...1)
                return try bounded(abs(try Expression.number(a[0])))
            case "min", "max":
                guard !a.isEmpty else { throw Problem(L("“{name}” takes {count} things.", ["name": name, "count": "1+"])) }
                let numbers = try (a.count == 1 ? try list(0) : a).map(Expression.number)
                guard let found = name == "min" ? numbers.min() : numbers.max() else { throw Problem(L("“{name}” needs a list here.", ["name": name])) }
                return .number(found)
            case "sum", "average":
                try needs(1...1)
                let numbers = try list(0).map(Expression.number)
                let total = numbers.reduce(0, +)
                if name == "sum" { return try bounded(total) }
                guard !numbers.isEmpty else { throw Problem(L("There's nothing to average.")) }
                return try bounded(total / Double(numbers.count))
            case "number":
                try needs(1...2)
                return try bounded(try read(words(0), style: a.count == 2 ? words(1) : nil))
            case "percent":
                try needs(1...1)
                let plain = words(0).trimmed
                guard plain.hasSuffix("%"), let n = NumberWords.typed(String(plain.dropLast()).trimmed) else { throw Problem(L("It needs words like 12%, and has “{what}”.", ["what": plain.clipped(40)])) }
                return try bounded(n / 100)
            case "text":
                try needs(1...1)
                return try Expression.text(words(0), &work)
            case "upper":
                try needs(1...1)
                return try Expression.text(words(0).uppercased(), &work)
            case "lower":
                try needs(1...1)
                return try Expression.text(words(0).lowercased(), &work)
            case "trim":
                try needs(1...1)
                return try Expression.text(words(0).trimmed, &work)
            case "length":
                try needs(1...1)
                if case .array(let items) = Values.structured(a[0]) { return .number(Double(items.count)) }
                return .number(Double(words(0).count))
            case "contains":
                try needs(2...2)
                if case .array(let items) = a[0] { return .bool(items.contains(a[1])) }
                return .bool(words(0).localizedCaseInsensitiveContains(words(1)))
            case "starts_with":
                try needs(2...2)
                return .bool(words(0).lowercased().hasPrefix(words(1).lowercased()))
            case "ends_with":
                try needs(2...2)
                return .bool(words(0).lowercased().hasSuffix(words(1).lowercased()))
            case "replace":
                try needs(3...3)
                guard !words(1).isEmpty else { throw Problem(L("“{name}” needs something to look for.", ["name": name])) }
                let (whole, find, with) = (words(0), words(1), words(2))
                let found = Expression.occurrences(of: find, in: whole)
                try spend(&work, whole.utf8.count / 1000)
                try Expression.fits(whole.utf8.count + found * (with.utf8.count - find.utf8.count))
                return try Expression.text(whole.replacingOccurrences(of: find, with: with), &work)
            case "split":
                try needs(2...2)
                guard !words(1).isEmpty else { throw Problem(L("“{name}” needs something to look for.", ["name": name])) }
                let parts = words(0).components(separatedBy: words(1))
                try spend(&work, parts.count)
                return .array(parts.map { .string($0) })
            case "join":
                try needs(2...2)
                let parts = try list(0).map(Values.text), between = words(1)
                try spend(&work, parts.count)
                try Expression.fits(parts.reduce(0) { $0 + $1.utf8.count } + max(parts.count - 1, 0) * between.utf8.count)
                return try Expression.text(parts.joined(separator: between), &work)
            case "first", "last":
                try needs(1...1)
                let items = try list(0)
                guard let found = name == "first" ? items.first : items.last else { throw Problem(L("The list is empty, so there's no “{name}”.", ["name": name])) }
                return found
            case "field":
                try needs(2...2)
                guard let found = Values.walk(a[0], path: Values.parts(of: words(1))) else { throw Problem(L("It has no “{field}”.", ["field": words(1)])) }
                return found
            case "default":
                try needs(2...2)
                if a[0] == .null || words(0).trimmed.isEmpty { return a[1] }
                return a[0]
            default:
                throw Problem(L("There's nothing called “{name}” to work out with. These there are: {list}.", ["name": name, "list": known.sorted().joined(separator: ", ")]))
            }
        }

        /// Words read as a number, by what the person says they are. Plain, or a stated way of writing thousands and decimals, and a unit or currency around it is left off. With no way stated, only a plain number: guessing is what this replaces.
        static func read(_ words: String, style: String?) throws -> Double {
            func cant() -> Problem { Problem(L("It can't read “{what}” as a number written that way.", ["what": words.clipped(40)])) }
            var plain = words.trimmed
            guard let style else {
                guard let n = NumberWords.typed(plain) else { throw Problem(L("“{what}” isn't plainly a number. Say how it's written: number(words, \"1,234.56\") or number(words, \"1.234,56\").", ["what": words.clipped(40)])) }
                return n
            }
            let (group, point): (Character, Character)
            switch style {
            case "1,234.56": (group, point) = (",", ".")
            case "1.234,56": (group, point) = (".", ",")
            case "1 234,56": (group, point) = (" ", ",")
            default: throw Problem(L("“{what}” isn't a way of writing a number it knows. These there are: {list}.", ["what": style.clipped(20), "list": "1,234.56, 1.234,56, 1 234,56"]))
            }
            // One number, with what's around it left off: `$`, `USD`, `°C`. Two of them is more than one number, however it's written.
            let digits = CharacterSet(charactersIn: "0123456789")
            let shape = plain.unicodeScalars.map { digits.contains($0) ? "d" : String($0) }.joined()
            guard let first = plain.firstIndex(where: { $0.isASCII && $0.isNumber }), let last = plain.lastIndex(where: { $0.isASCII && $0.isNumber }), shape.contains("d") else { throw cant() }
            let negative = plain[..<first].contains("-") || plain[..<first].contains("−")
            let before = plain[..<first].filter { !"-− ".contains($0) }, after = String(plain[plain.index(after: last)...]).trimmed
            guard !before.contains(where: \.isNumber), !after.contains(where: \.isNumber) else { throw cant() }
            plain = String(plain[first...last])
            let spaced = group == " " ? plain.replacingOccurrences(of: "\u{00A0}", with: " ").replacingOccurrences(of: "\u{202F}", with: " ") : plain
            let parts = spaced.split(separator: point, omittingEmptySubsequences: false)
            guard parts.count <= 2 else { throw cant() }
            let whole = parts[0].split(separator: group, omittingEmptySubsequences: false).map(String.init)
            // Grouped the way thousands are, or not grouped: `1,50` read by "1,234.56" isn't one.
            guard whole.allSatisfy({ !$0.isEmpty && $0.allSatisfy { $0.isASCII && $0.isNumber } }), whole.count == 1 || (whole[0].count <= 3 && whole.dropFirst().allSatisfy { $0.count == 3 }) else { throw cant() }
            let fraction = parts.count == 2 ? String(parts[1]) : ""
            guard fraction.allSatisfy({ $0.isASCII && $0.isNumber }), parts.count == 1 || !fraction.isEmpty else { throw cant() }
            let joined = whole.joined(), count = joined.count + fraction.count
            guard count <= 15, let n = Double(joined + (fraction.isEmpty ? "" : "." + fraction)) else { throw cant() }
            return negative ? -n : n
        }
    }
}
