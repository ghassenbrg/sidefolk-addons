import Foundation
import SidefolkExtensionKit

/// Changes to a definition, as data: each returns the new one. Pure, so a page's click and a test do the same.
enum Editing {
    /// A new step's id, unused anywhere in the flow.
    static func freshId(_ body: FlowBody, base: String) -> String {
        let used = Set(body.allSteps.map(\.id))
        var clean = String(base.lowercased().map { $0.isLetter || $0.isNumber ? $0 : "_" }.prefix(16)).trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        if clean.isEmpty || !clean.first!.isASCII { clean = "step" }
        clean = String(clean.unicodeScalars.filter { CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789_").contains($0) })
        if clean.isEmpty { clean = "step" }
        if !used.contains(clean), !Values.reserved.contains(clean) { return clean }
        var n = 2
        while used.contains("\(clean)_\(n)") { n += 1 }
        return "\(clean)_\(n)"
    }

    /// Changes the list a step sits in, wherever it is.
    private static func mapLists(_ steps: [Step], _ change: ([Step]) -> [Step]) -> [Step] {
        change(steps).map { step in
            guard case .branch(let c, let then, let otherwise) = step.kind else { return step }
            var step = step
            step.kind = .branch(c, then: mapLists(then, change), otherwise: mapLists(otherwise, change))
            return step
        }
    }

    /// Adds after `after`: `start`, a step's id, or `then:<id>` / `else:<id>` for the start of a branch. Whatever isn't there now puts it last: a page a moment old loses nothing.
    static func insert(_ new: Step, after: String, in body: FlowBody) -> FlowBody {
        var body = body
        if after == "start" {
            body.steps.insert(new, at: 0)
            return body
        }
        if after.hasPrefix("then:") || after.hasPrefix("else:") {
            let inThen = after.hasPrefix("then:"), id = String(after.dropFirst(5))
            guard case .branch? = body.step(id)?.kind else {
                body.steps.append(new)
                return body
            }
            body.steps = mapLists(body.steps) { list in
                list.map { step in
                    guard step.id == id, case .branch(let c, var then, var otherwise) = step.kind else { return step }
                    if inThen { then.insert(new, at: 0) } else { otherwise.insert(new, at: 0) }
                    var step = step
                    step.kind = .branch(c, then: then, otherwise: otherwise)
                    return step
                }
            }
            return body
        }
        var done = false
        body.steps = mapLists(body.steps) { list in
            guard !done, let i = list.firstIndex(where: { $0.id == after }) else { return list }
            done = true
            var list = list
            list.insert(new, at: i + 1)
            return list
        }
        if !done { body.steps.append(new) }
        return body
    }

    static func remove(_ id: String, from body: FlowBody) -> FlowBody {
        var body = body
        body.steps = mapLists(body.steps) { $0.filter { $0.id != id } }
        return body
    }

    static func change(_ id: String, in body: FlowBody, _ edit: (inout Step) -> Void) -> FlowBody {
        var body = body
        body.steps = mapLists(body.steps) { list in
            list.map { step in
                guard step.id == id else { return step }
                var step = step
                edit(&step)
                return step
            }
        }
        return body
    }

    /// Moves a step before another in the same list, or to its end: a rail's rows move only among their own.
    static func move(_ id: String, before: String?, in body: FlowBody) -> FlowBody {
        var body = body
        body.steps = mapLists(body.steps) { list in
            guard let from = list.firstIndex(where: { $0.id == id }) else { return list }
            if let before, !list.contains(where: { $0.id == before }) { return list }
            var list = list
            let step = list.remove(at: from)
            if let before, let to = list.firstIndex(where: { $0.id == before }) { list.insert(step, at: to) } else { list.append(step) }
            return list
        }
        return body
    }

    /// Puts a step where `insert` would put a new one, wherever it was: another branch too. Not inside itself.
    static func place(_ id: String, after: String, in body: FlowBody) -> FlowBody {
        guard let step = body.step(id) else { return body }
        func inside(_ step: Step) -> [String] {
            guard case .branch(_, let then, let otherwise) = step.kind else { return [step.id] }
            return [step.id, "then:\(step.id)", "else:\(step.id)"] + (then + otherwise).flatMap(inside)
        }
        guard !inside(step).contains(after) else { return body }
        return insert(step, after: after, in: remove(id, from: body))
    }

    /// One place up or down among its own.
    static func nudge(_ id: String, by delta: Int, in body: FlowBody) -> FlowBody {
        var body = body
        body.steps = mapLists(body.steps) { list in
            guard let from = list.firstIndex(where: { $0.id == id }) else { return list }
            let to = from + delta
            guard list.indices.contains(to) else { return list }
            var list = list
            list.swapAt(from, to)
            return list
        }
        return body
    }

    /// A value typed for a tool's parameter, as the schema wants it. A number with `{{x}}` stays text and shows as something to fix.
    static func value(_ text: String, for parameter: Catalog.Parameter) -> JSON? {
        let t = text.trimmed
        guard !t.isEmpty else { return nil }
        switch parameter.kind {
        case .integer, .number:
            if let n = Double(t.replacingOccurrences(of: ",", with: ".")) { return .number(n) }
            return .string(t)
        case .boolean:
            return .bool(t == "true" || t == "on")
        case .list:
            return .array(t.split(separator: ",").map { .string(String($0).trimmed) })
        default:
            return .string(text)
        }
    }
}
