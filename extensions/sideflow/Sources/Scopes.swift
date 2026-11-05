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
        case .parallel(let lanes): out.kind = .parallel(lanes: lanes.enumerated().map { Lane(name: $0.element.name, steps: lists[$0.offset]) })
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
    var count: Int?
    var separator: String?

    /// What it does to a value. A wrong shape is said, never guessed around: a list is a list, text is text, and text that looks like a number stays text until asked.
    func apply(to value: JSON, than resolved: String) throws -> JSON {
        func list() throws -> [JSON] {
            guard case .array(let items) = Values.structured(value) else { throw Problem(L("It needs a list, and this isn't one. “Lines” or “Read JSON” can make one.")) }
            return items
        }
        func at(_ item: JSON) -> JSON? { field?.nonEmpty.map { Values.walk(item, path: Values.parts(of: $0)) } ?? item }
        switch op {
        case .parse_json:
            guard let parsed = JSONText.read(Values.text(value)) else { throw Problem(L("That isn't JSON.")) }
            return JSON(parsed)
        case .parse_csv:
            let rows = CSV.rows(Values.text(value))
            guard let head = rows.first else { return .array([]) }
            return .array(rows.dropFirst().map { row in .object(Dictionary(zip(head, row.map { JSON.string($0) }), uniquingKeysWith: { a, _ in a })) })
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
            if [nil, .contains, .not_contains].contains(test), resolved.trimmed.isEmpty { throw Problem(L("Say what to compare it with.")) }
            return .array(try list().filter { item in Condition.test(test ?? .contains, left: at(item).map(Values.text) ?? "", right: resolved) })
        case .sort:
            let sorted = try list().sorted { a, b in
                let (x, y) = (at(a).map(Values.text) ?? "", at(b).map(Values.text) ?? "")
                if let n = Double(x), let m = Double(y) { return n < m }
                return x.localizedStandardCompare(y) == .orderedAscending
            }
            return .array(descending ? sorted.reversed() : sorted)
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
                guard let text = at(item).map(Values.text) else { return sum }
                if Condition.couldBeEither(text) { throw Problem(L("“{value}” could be more than one number, so it stopped.", ["value": text.clipped(80)])) }
                return sum + (Condition.number(text) ?? 0)
            }
            guard total.isFinite else { throw Problem(L("Those numbers add up to too much.")) }
            return .number(total)
        case .number:
            if Condition.couldBeEither(Values.text(value)) { throw Problem(L("“{value}” could be more than one number, so it stopped.", ["value": Values.text(value).clipped(80)])) }
            guard let n = Condition.number(Values.text(value)) else { throw Problem(L("There's no number in that.")) }
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
