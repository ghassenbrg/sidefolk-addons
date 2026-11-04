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

    /// The steps sure to have run before this one, in order: on the way to it, and after a condition only what both of its paths made.
    static func available(before id: String, in body: FlowBody) -> [Step] {
        /// Walks a list; true when it reached the step, with `sure` as it stands there.
        func walk(_ list: [Step], _ sure: inout [Step]) -> Bool {
            for step in list {
                if step.id == id { return true }
                if case .branch(_, let then, let otherwise) = step.kind {
                    var yes = sure, no = sure
                    if walk(then, &yes) { sure = yes; return true }
                    if walk(otherwise, &no) { sure = no; return true }
                    let both = Set(yes.map(\.id)).intersection(no.map(\.id))
                    sure = yes.filter { both.contains($0.id) }
                } else if step.hasOutput {
                    sure.append(step)
                }
            }
            return false
        }
        var sure: [Step] = []
        return walk(body.steps, &sure) ? sure : []
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

    /// A copy right after the step, branches and all, with new ids. What's inside it that used a value made inside it uses the copy's; everything else is as it was.
    static func duplicate(_ id: String, in body: FlowBody) -> (FlowBody, String)? {
        guard let step = body.step(id) else { return nil }
        var used = body
        var renamed: [String: String] = [:]
        func copy(_ step: Step) -> Step {
            let fresh = freshId(used, base: step.id)
            renamed[step.id] = fresh
            used.steps.append(Step(id: fresh, kind: .text("")))
            var out = step
            out.id = fresh
            if case .branch(let c, let then, let otherwise) = step.kind { out.kind = .branch(c, then: then.map(copy), otherwise: otherwise.map(copy)) }
            return out
        }
        func remap(_ text: String) -> String {
            renamed.reduce(text) { $0.replacingOccurrences(of: "{{\($1.key)}}", with: "{{\($1.value)}}") }
        }
        func refs(_ step: Step) -> Step {
            var out = step
            switch step.kind {
            case .action(let tool, let input): out.kind = .action(tool: tool, input: input.mapValues { $0.mapStrings(remap) })
            case .ai(let prompt): out.kind = .ai(prompt: remap(prompt))
            case .ask(let question, let options): out.kind = .ask(question: remap(question), options: options)
            case .text(let text): out.kind = .text(remap(text))
            case .branch(var c, let then, let otherwise):
                c.value = remap(c.value)
                c.than = remap(c.than)
                c.also = c.also.map { var check = $0; check.value = remap($0.value); check.than = remap($0.than); return check }
                out.kind = .branch(c, then: then.map(refs), otherwise: otherwise.map(refs))
            case .wait, .flow: break
            }
            return out
        }
        let copied = refs(copy(step))
        return (insert(copied, after: id, in: body), copied.id)
    }

    /// What differs between two versions, in words: for reading before saving or applying.
    @MainActor static func changes(from old: FlowBody, to new: FlowBody, catalog: Catalog) -> [String] {
        var out: [String] = []
        if old.trigger != new.trigger { out.append(L("What sets it off: {what}", ["what": Words.trigger(new.trigger)])) }
        let before = Dictionary(old.allSteps.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let after = Dictionary(new.allSteps.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        for step in new.allSteps where before[step.id] == nil { out.append(L("Added: {step}", ["step": Words.label(step, catalog: catalog)])) }
        for step in old.allSteps where after[step.id] == nil { out.append(L("Removed: {step}", ["step": Words.label(step, catalog: catalog)])) }
        /// A step without what hangs from it: moving what's inside a branch isn't changing the branch.
        func own(_ step: Step) -> Step {
            var out = step
            if case .branch(let c, _, _) = step.kind { out.kind = .branch(c, then: [], otherwise: []) }
            return out
        }
        /// Where each step stands among those both versions have: what it's in, and the one before it there.
        func places(_ body: FlowBody) -> [String: String] {
            var out: [String: String] = [:]
            func walk(_ list: [Step], _ inside: String) {
                var previous = ""
                for step in list {
                    guard before[step.id] != nil, after[step.id] != nil else { continue }
                    out[step.id] = "\(inside)|\(previous)"
                    previous = step.id
                }
                for step in list {
                    if case .branch(_, let then, let otherwise) = step.kind {
                        walk(then, "then:\(step.id)")
                        walk(otherwise, "else:\(step.id)")
                    }
                }
            }
            walk(body.steps, "")
            return out
        }
        let (was, now) = (places(old), places(new))
        for step in new.allSteps {
            guard let earlier = before[step.id] else { continue }
            if own(earlier) != own(step) {
                out.append(L("Changed: {step}", ["step": Words.label(step, catalog: catalog)]))
            } else if was[step.id] != now[step.id] {
                out.append(L("Moved: {step}", ["step": Words.label(step, catalog: catalog)]))
            }
        }
        return out
    }

    /// Undo and redo for what's being edited. Typing in one field is one step back, however many times it was handed over. Only the draft: nothing here reverses anything a run did.
    struct History {
        static let longest = 100
        static let typingGap: TimeInterval = 2

        private(set) var undo: [FlowBody] = []
        private(set) var redo: [FlowBody] = []
        private var lastKey: String?
        private var lastAt: Date?

        var canUndo: Bool { !undo.isEmpty }
        var canRedo: Bool { !redo.isEmpty }

        mutating func breakTyping() { (lastKey, lastAt) = (nil, nil) }

        mutating func record(_ before: FlowBody, key: String?, at now: Date) {
            redo = []
            if let key, key == lastKey, let lastAt, now.timeIntervalSince(lastAt) < Self.typingGap {
                self.lastAt = now
                return
            }
            undo.append(before)
            if undo.count > Self.longest { undo.removeFirst() }
            (lastKey, lastAt) = (key, now)
        }

        mutating func back(from current: FlowBody) -> FlowBody? {
            guard let last = undo.popLast() else { return nil }
            redo.append(current)
            (lastKey, lastAt) = (nil, nil)
            return last
        }

        mutating func forward(from current: FlowBody) -> FlowBody? {
            guard let next = redo.popLast() else { return nil }
            undo.append(current)
            (lastKey, lastAt) = (nil, nil)
            return next
        }
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

    /// `inf`, `nan`, `1e999`: what reads as a number and isn't one.
    static func isNotARealNumber(_ text: String) -> Bool {
        Double(text.trimmed.replacingOccurrences(of: ",", with: ".")).map { !$0.isFinite } ?? false
    }

    /// A value typed for a tool's parameter, as the schema wants it. A number with `{{x}}` stays text and shows as something to fix.
    static func value(_ text: String, for parameter: Catalog.Parameter) -> JSON? {
        let t = text.trimmed
        guard !t.isEmpty else { return nil }
        switch parameter.kind {
        case .integer, .number:
            if let n = Double(t.replacingOccurrences(of: ",", with: ".")), n.isFinite { return .number(n) }
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
