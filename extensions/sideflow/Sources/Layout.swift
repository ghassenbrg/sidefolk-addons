import Foundation

/// Where the person put a flow's cards on the board (D235). Kept on the flow beside its name, never in its definition: no plan, approval, check or run
/// reads it, so arranging the board can't ask again or change what was allowed. Bounded here whatever a page, a file or an agent sends.
enum Layout {
    /// As far as Sidefolk draws a card from the board's start, either way (D234).
    static let farthest = 4_000.0
    /// One place a step, and no more than a flow can have steps.
    static let most = 100

    struct Place: Equatable, Sendable {
        var x: Double
        var y: Double
    }

    /// A place within the bounds, in whole points; nil for anything that isn't two finite numbers in them.
    static func place(_ x: Any?, _ y: Any?) -> Place? {
        func number(_ value: Any?) -> Double? {
            // A true or false isn't a place. Asked as `is Bool`, a number read from JSON that happens to be 0 or 1 would say yes too.
            if value is Bool && !(value is Int || value is Double) { return nil }
            if let n = value as? NSNumber, CFGetTypeID(n) == CFBooleanGetTypeID() { return nil }
            guard let n = (value as? NSNumber)?.doubleValue ?? (value as? Double), n.isFinite, abs(n) <= farthest else { return nil }
            return n.rounded()
        }
        guard let x = number(x), let y = number(y) else { return nil }
        return Place(x: x, y: y)
    }

    /// Only for cards the flow has (its steps and what sets it off), and at most `most` of them: anything else is dropped, not refused.
    static func kept(_ layout: [String: Place], for body: FlowBody) -> [String: Place] {
        let ids = Set(body.allSteps.map(\.id) + ["start"])
        let known = layout.filter { ids.contains($0.key) }
        guard known.count > most else { return known }
        return Dictionary(uniqueKeysWithValues: known.sorted { $0.key < $1.key }.prefix(most).map { ($0.key, $0.value) })
    }

    /// `{"step": [x, y]}`, as files and flows.json hold it.
    static func json(_ layout: [String: Place]) -> [String: Any] { layout.mapValues { [$0.x, $0.y] } }

    static func read(_ value: Any?) -> [String: Place] {
        guard let o = value as? [String: Any] else { return [:] }
        var out: [String: Place] = [:]
        // In the ids' own order, so which ones a file past the bound keeps never depends on how a dictionary happens to list them.
        for (id, at) in o.sorted(by: { $0.key < $1.key }).prefix(most * 2) {
            guard id.range(of: #"^[A-Za-z0-9_.:-]{1,64}$"#, options: .regularExpression) != nil, let pair = at as? [Any], pair.count == 2, let place = place(pair[0], pair[1]) else { continue }
            out[id] = place
        }
        return out
    }
}
