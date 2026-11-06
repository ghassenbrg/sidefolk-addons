import Foundation
import SidefolkExtensionKit

/// The steps that hold other steps, and the other kinds a flow grew: what each is, and the one way to reach what's inside any of them.
extension Step {
    /// A way through a step that holds others. `id` is what a place inside it is called: `then:<step>`.
    struct Part: Equatable {
        var id: String
        var steps: [Step]
    }

    /// One way a `choose` can go.
    struct Path: Equatable, Sendable {
        var when: String
        var steps: [Step]
    }

    /// One of the things a `parallel` does at once.
    struct Lane: Equatable, Sendable {
        var name: String
        var steps: [Step]
        /// How long it gets before it's stopped and counts as not having finished.
        var timeoutMinutes: Int?
    }

    /// When a `parallel` carries on.
    enum Join: Equatable, Sendable {
        case all
        /// With the first lane to finish; the rest are stopped.
        case first
        /// With this many; the rest are stopped.
        case atLeast(Int)
        /// When every lane has ended, whichever way: one that failed gives nothing and the step still goes on.
        case settled

        /// How many have to finish.
        func needs(_ lanes: Int) -> Int {
            switch self {
            case .all: lanes
            case .first: min(1, lanes)
            case .atLeast(let count): min(count, lanes)
            case .settled: 0
            }
        }

        var json: Any? {
            switch self {
            case .all: nil
            case .first: "first"
            case .atLeast(let count): count
            case .settled: "settled"
            }
        }

        /// What a menu holds it as.
        var word: String {
            switch self {
            case .all: "all"
            case .first: "first"
            case .atLeast(let count): String(count)
            case .settled: "settled"
            }
        }

        init?(_ any: Any?) {
            guard let any else { self = .all; return }
            if let count = any as? Int { self = .atLeast(count); return }
            switch any as? String {
            case "all": self = .all
            case "first": self = .first
            case "settled": self = .settled
            case let words?: guard let count = Int(words) else { return nil }; self = .atLeast(count)
            case nil: return nil
            }
        }
    }

    enum LoopFailure: String, Equatable, Sendable, CaseIterable {
        /// One item failing fails the loop.
        case stop
        /// It's noted with that item, and the rest go on.
        case collect
    }

    /// What's sure to be there after it. `common`: what every way through it made. `own`: only its own result: a loop's inside is gone when it ends, and a parallel's lanes answer under its name.
    enum After { case common, own }

    var after: After {
        switch kind {
        case .forEach, .repeatUntil, .parallel: .own
        default: .common
        }
    }

    /// The same step, naming another flow by its new name.
    func calling(_ old: String, instead name: String) -> Step {
        var out = holding(parts.map { $0.steps.map { $0.calling(old, instead: name) } })
        func same(_ flow: String) -> Bool { flow.trimmed.compare(old.trimmed, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }
        switch out.kind {
        case .flow(let flow) where same(flow): out.kind = .flow(name)
        case .call(let flow, let inputs) where same(flow): out.kind = .call(flow: name, inputs: inputs)
        default: break
        }
        return out
    }

    /// Everything inside this step, way by way.
    var parts: [Part] {
        switch kind {
        case .branch(_, let then, let otherwise): [Part(id: "then", steps: then), Part(id: "else", steps: otherwise)]
        case .forEach(_, _, _, let steps), .repeatUntil(_, _, let steps): [Part(id: "each", steps: steps)]
        case .choose(_, let paths, let otherwise): paths.enumerated().map { Part(id: "path\($0.offset)", steps: $0.element.steps) } + [Part(id: "else", steps: otherwise)]
        case .attempt(let steps, let recover, let always): [Part(id: "try", steps: steps), Part(id: "recover", steps: recover), Part(id: "always", steps: always)]
        case .parallel(let lanes): lanes.enumerated().map { Part(id: "lane\($0.offset)", steps: $0.element.steps) }
        default: []
        }
    }

    /// The same step holding these instead, in the order `parts` gives them.
    func holding(_ lists: [[Step]]) -> Step {
        var out = self
        switch kind {
        case .branch(let c, _, _): out.kind = .branch(c, then: lists[0], otherwise: lists[1])
        case .forEach(let items, let limit, let failure, _): out.kind = .forEach(items: items, limit: limit, onFailure: failure, steps: lists[0])
        case .repeatUntil(let until, let times, _): out.kind = .repeatUntil(until: until, times: times, steps: lists[0])
        case .choose(let value, let paths, _):
            out.kind = .choose(value: value, paths: paths.enumerated().map { Path(when: $0.element.when, steps: lists[$0.offset]) }, otherwise: lists[paths.count])
        case .attempt: out.kind = .attempt(steps: lists[0], recover: lists[1], always: lists[2])
        case .parallel(let lanes): out.kind = .parallel(lanes: lanes.enumerated().map { Lane(name: $0.element.name, steps: lists[$0.offset], timeoutMinutes: $0.element.timeoutMinutes) })
        default: break
        }
        return out
    }

    /// The same step with this done to the list of each way through it.
    func mappingParts(_ change: ([Step]) -> [Step]) -> Step {
        parts.isEmpty ? self : holding(parts.map { change($0.steps) })
    }
}

/// A form a flow puts in front of the person: what it asks, and how long it waits. It waits on the disk, not in memory, so days and restarts are nothing to it.
struct FormStep: Equatable, Sendable {
    struct Field: Equatable, Sendable {
        enum Kind: String, Equatable, Sendable, CaseIterable { case text, number, yes_no, choice }

        var name: String
        var label: String
        var kind: Kind
        var options: [String] = []
        var required = true
    }

    var title: String
    var fields: [Field]
    /// Hours it waits, then it counts as a failure of the step, with what that does.
    var hours: Int
    static let longestHours = 24 * 30
}

/// One thing done to data, with no code and nothing outside the run.
struct DataStep: Equatable, Sendable {
    enum Op: String, Equatable, Sendable, CaseIterable {
        case parse_json, parse_csv, lines, join, field, filter, sort, unique, count, first, sum, number, batches, group, fallback
    }

    var op: Op
    var from: String
    /// What it looks at in each item, for field, filter, sort, unique and sum: `a.b` or nothing for the item itself.
    var field: String?
    var test: Condition.Test?
    var than: String?
    var descending = false
    /// A sort that reads every item as a name, as Finder does: `Item 9` before `Item 12`. The person's word that these are names, not numbers.
    var byName = false
    var count: Int?
    var separator: String?

    /// What it does to a value. A wrong shape is said, never guessed around: a list is a list, text is text, and text that looks like a number stays text until asked.
    /// `thanValue` is what `than` came to before it was words: a tool's 1.125 is that number, whatever its words look like.
    func apply(to value: JSON, than resolved: String, thanValue: JSON? = nil) throws -> JSON {
        func list() throws -> [JSON] {
            guard case .array(let items) = Values.structured(value) else { throw Problem(L("It needs a list, and this isn't one. “Lines” or “Read JSON” can make one.")) }
            return items
        }
        func at(_ item: JSON) -> JSON? { field?.nonEmpty.map { Values.walk(item, path: Values.parts(of: $0)) } ?? item }
        switch op {
        case .parse_json:
            guard let parsed = JSONText.read(Values.text(value)) else { throw Problem(L("That isn't JSON, or it says something twice, or it has a number too big or small to hold.")) }
            return JSON(parsed)
        case .parse_csv:
            let rows = CSV.rows(Values.text(value))
            guard let head = rows.first else { return .array([]) }
            // A cell with something in it and no column usually means a comma in a value (`A,1,299.00`), and two columns of one name can't both be kept: what's left would look whole. Trailing commas lose nothing.
            let named = Array(head.reversed().drop { $0.trimmed.isEmpty }.reversed())
            if let twice = named.first(where: { name in named.filter { $0 == name }.count > 1 }) {
                throw Problem(twice.trimmed.isEmpty ? L("Some columns have no name.") : L("Two columns are called “{name}”.", ["name": twice]))
            }
            if let at = rows.firstIndex(where: { $0.dropFirst(named.count).contains { !$0.trimmed.isEmpty } }) { throw Problem(L("Row {row} has more cells than there are columns. A value with a comma in it needs quotes around it.", ["row": Format.integer(at)])) }
            return .array(rows.dropFirst().map { row in .object(Dictionary(zip(named, row.map { JSON.string($0) }), uniquingKeysWith: { a, _ in a })) })
        case .lines:
            return .array(Values.text(value).split(whereSeparator: \.isNewline).map { .string(String($0).trimmed) }.filter { $0 != .string("") })
        case .join:
            return .string(try list().map(Values.text).joined(separator: separator ?? ", "))
        case .field:
            let shaped = Values.structured(value)
            if case .array(let items) = shaped { return .array(items.map { at($0) ?? .null }) }
            guard let found = at(shaped) else { throw Problem(L("It has no “{field}”.", ["field": field ?? ""])) }
            return found
        case .filter:
            // What the page shows selected before anyone picks. Looking for nothing would look like an answer: an empty list.
            if [nil, .contains, .not_contains, .more_than, .less_than].contains(test), resolved.trimmed.isEmpty { throw Problem(L("Say what to compare it with.")) }
            return .array(try list().filter { item in
                let found = at(item)
                let left = found.map(Values.text) ?? ""
                if test == .more_than || test == .less_than {
                    // A row with nothing there has nothing to compare. One with words that aren't one number can't be told.
                    if left.trimmed.isEmpty || found == .null { return false }
                    guard case .number(let a)? = found.map(Condition.reading(of:)) else { throw Condition.Unreadable(words: left) }
                    guard case .number(let b) = Condition.reading(of: thanValue ?? .string(resolved)) else { throw Condition.Unreadable(words: resolved) }
                    return test == .more_than ? a > b : a < b
                }
                return Condition.test(test ?? .contains, left: left, right: resolved)
            })
        case .sort:
            let items = try list()
            // What it's sorted by, each once. Blanks and rows without it go last either way round, and if nothing has it the field's name is probably wrong.
            let keys = try items.map { item -> SortKey in
                guard let found = at(item), found != .null, !Values.text(found).trimmed.isEmpty else { return .blank }
                if byName { return .name(Values.text(found).trimmed) }
                if case .number(let n) = Condition.reading(of: found) { return .number(n) }
                let text = Values.text(found).trimmed
                guard SortKey.canOrder(text) else { throw Condition.Unreadable(words: text) }
                return .words(text)
            }
            if !items.isEmpty, field?.nonEmpty != nil, keys.allSatisfy({ $0 == .blank }) { throw Problem(L("None of these has “{field}”, so there's nothing to sort by.", ["field": field ?? ""])) }
            // Numbers and words in one list can't be one order: `N/A` among prices means something's wrong with that row.
            if keys.contains(where: \.isNumber), let words = keys.lazy.compactMap(\.words).first { throw Condition.Unreadable(words: words) }
            let filled = zip(items, keys).filter { $0.1 != .blank }.sorted { $0.1.isBefore($1.1) }.map(\.0)
            let blanks = zip(items, keys).filter { $0.1 == .blank }.map(\.0)
            return .array((descending ? filled.reversed() : filled) + blanks)
        case .unique:
            var seen = Set<String>()
            return .array(try list().filter { seen.insert(at($0).map(Values.text) ?? "").inserted })
        case .count:
            if case .array(let items) = Values.structured(value) { return .number(Double(items.count)) }
            return .number(Double(Values.text(value).count))
        case .first:
            return .array(Array(try list().prefix(max(count ?? 1, 0))))
        case .sum:
            let total = try list().reduce(0) { sum, item in
                guard let found = at(item), found != .null, !Values.text(found).trimmed.isEmpty else { return sum }
                guard case .number(let n) = Condition.reading(of: found) else { throw Condition.Unreadable(words: Values.text(found)) }
                return sum + n
            }
            // Past what can be held exactly it wouldn't be the sum, and it wouldn't come back from disk as a number.
            guard abs(total) < 9_007_199_254_740_992 else { throw Problem(L("Those numbers add up to too much.")) }
            return .number(total)
        case .number:
            guard case .number(let n) = Condition.reading(of: value) else { throw Condition.Unreadable(words: Values.text(value)) }
            return .number(n)
        case .batches:
            let size = max(count ?? 10, 1), items = try list()
            return .array(stride(from: 0, to: items.count, by: size).map { .array(Array(items[$0..<min($0 + size, items.count)])) })
        case .group:
            var groups: [String: [JSON]] = [:]
            for item in try list() { groups[at(item).map(Values.text) ?? "", default: []].append(item) }
            return .object(groups.mapValues { .array($0) })
        case .fallback:
            // Nothing there, or nothing in it: the words given instead.
            let empty = switch value {
            case .null: true
            case .string(let s): s.trimmed.isEmpty
            case .array(let a): a.isEmpty
            default: false
            }
            return empty ? .string(resolved) : value
        }
    }
}

/// Comma-separated text, as spreadsheets write it: quotes around what holds commas, doubled quotes inside.
enum CSV {
    static func rows(_ text: String) -> [[String]] {
        var rows: [[String]] = [], row: [String] = [], cell = "", quoted = false
        var chars = Array(text)[...]
        while let c = chars.popFirst() {
            if quoted {
                if c == "\"" {
                    if chars.first == "\"" { cell.append("\""); chars.removeFirst() } else { quoted = false }
                } else { cell.append(c) }
            } else if c == "\"" {
                quoted = true
            } else if c == "," {
                row.append(cell)
                cell = ""
            } else if c.isNewline {
                if !(row.isEmpty && cell.isEmpty) { row.append(cell); rows.append(row) }
                (row, cell) = ([], "")
            } else {
                cell.append(c)
            }
        }
        if !(row.isEmpty && cell.isEmpty) { row.append(cell); rows.append(row) }
        return rows
    }
}

/// An AI's answer as a record: its fields or nothing. What it writes is read like anything from outside.
enum AIFields {
    static func instruction(_ fields: [String: String]) -> String {
        "Answer with only a JSON object with exactly these fields: " + fields.keys.sorted().map { "\($0) (\(fields[$0] ?? "text"))" }.joined(separator: ", ") + "."
    }

    static func read(_ text: String, _ fields: [String: String]) -> JSON? {
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}"), start < end,
              let raw = JSONText.read(String(text[start...end])) as? [String: Any] else { return nil }
        var out: [String: JSON] = [:]
        for (name, kind) in fields {
            guard let value = raw[name] else { return nil }
            let json = JSON(value)
            switch (kind, json) {
            case ("text", .string), ("number", .number), ("yes_no", .bool), ("list", .array): out[name] = json
            default: return nil
            }
        }
        return .object(out)
    }
}

/// What a sort orders by.
enum SortKey: Equatable {
    case number(Double), words(String), name(String), blank

    var isNumber: Bool { if case .number = self { true } else { false } }
    var words: String? { if case .words(let text) = self { text } else { nil } }

    func isBefore(_ other: SortKey) -> Bool {
        switch (self, other) {
        case (.number(let a), .number(let b)): a < b
        case (.words(let a), .words(let b)): a.localizedCaseInsensitiveCompare(b) == .orderedAscending
        case (.name(let a), .name(let b)): a.localizedStandardCompare(b) == .orderedAscending
        default: false
        }
    }

    /// Words with no digits in them, or a date written year first, which sorts as it reads. Anything else with digits in it holds a number or a date that could land in the wrong place with no one seeing: `Item 12`, `USD 1,500`, `Temp -5`, `Q1 2026`, `at 9pm`.
    /// Which of those read as numbers never ends, as it didn't for reading a number out of words, so none do. A sort that says it's by name is on the later list.
    static func canOrder(_ text: String) -> Bool {
        text.range(of: #"\p{N}"#, options: .regularExpression) == nil
            || text.range(of: #"^[0-9]{4}-(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])(T([01][0-9]|2[0-3]):[0-5][0-9](:[0-5][0-9])?Z?)?$"#, options: .regularExpression) != nil
    }
}
