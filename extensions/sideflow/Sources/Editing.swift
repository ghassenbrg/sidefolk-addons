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
        change(steps).map { $0.mappingParts { mapLists($0, change) } }
    }

    /// Adds after `after`: `start`, a step's id, or `then:<id>` / `else:<id>` for the start of a branch. Whatever isn't there now puts it last: a page a moment old loses nothing.
    static func insert(_ new: Step, after: String, in body: FlowBody) -> FlowBody {
        var body = body
        if after == "start" {
            body.steps.insert(new, at: 0)
            return body
        }
        // `then:<step>` and its like: the start of that way through it.
        if let colon = after.firstIndex(of: ":") {
            let part = String(after[..<colon]), id = String(after[after.index(after: colon)...])
            guard let holder = body.step(id), holder.parts.contains(where: { $0.id == part }) else {
                body.steps.append(new)
                return body
            }
            body.steps = mapLists(body.steps) { list in
                list.map { step in
                    guard step.id == id else { return step }
                    return step.holding(step.parts.map { $0.id == part ? [new] + $0.steps : $0.steps })
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
                let before = sure
                var outcomes: [[Step]] = []
                for part in step.parts {
                    var inside = before
                    // A try's steps may not have run by the time it recovers or finishes.
                    if part.id == "recover" || part.id == "always" { inside = before }
                    if walk(part.steps, &inside) { sure = inside; return true }
                    outcomes.append(inside)
                }
                if !outcomes.isEmpty, step.after == .common {
                    let both = outcomes.dropFirst().reduce(Set(outcomes[0].map(\.id))) { $0.intersection($1.map(\.id)) }
                    sure = outcomes[0].filter { both.contains($0.id) }
                }
                if step.hasOutput { sure.append(step) }
            }
            return false
        }
        var sure: [Step] = []
        return walk(body.steps, &sure) ? sure : []
    }

    enum Surrounding { case loop, recover }

    /// What a step stands inside, so a field knows what's there for it.
    static func around(_ id: String, in body: FlowBody) -> Set<Surrounding> {
        func walk(_ list: [Step], _ have: Set<Surrounding>) -> Set<Surrounding>? {
            for step in list {
                if step.id == id { return have }
                for part in step.parts {
                    var inner = have
                    switch step.kind {
                    case .forEach, .repeatUntil: inner.insert(.loop)
                    default: break
                    }
                    if part.id == "recover" { inner.insert(.recover) }
                    if let found = walk(part.steps, inner) { return found }
                }
            }
            return nil
        }
        return walk(body.steps, []) ?? []
    }

    /// Puts a step where `insert` would put a new one, wherever it was: another branch too. Not inside itself.
    static func place(_ id: String, after: String, in body: FlowBody) -> FlowBody {
        guard let step = body.step(id) else { return body }
        func inside(_ step: Step) -> [String] {
            [step.id] + step.parts.flatMap { ["\($0.id):\(step.id)"] + $0.steps.flatMap(inside) }
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
            var out = step.mappingParts { $0.map(copy) }
            out.id = fresh
            return out
        }
        func remap(_ text: String) -> String {
            Values.replacingSlots(in: text) { name, path in "{{\(renamed[name] ?? name)\(path)}}" }
        }
        let copied = rewriting(copy(step), remap)
        return (insert(copied, after: id, in: body), copied.id)
    }

    /// The same step with every value it uses put through `remap`.
    static func rewriting(_ step: Step, _ remap: (String) -> String) -> Step {
        var out = step.mappingParts { $0.map { rewriting($0, remap) } }
        switch out.kind {
        case .action(let tool, let input): out.kind = .action(tool: tool, input: input.mapValues { $0.mapStrings(remap) })
        case .ai(let prompt): out.kind = .ai(prompt: remap(prompt))
        case .ask(let question, let options): out.kind = .ask(question: remap(question), options: options)
        case .text(let text): out.kind = .text(remap(text))
        case .branch(var c, let then, let otherwise):
            c.value = remap(c.value)
            c.than = remap(c.than)
            c.also = c.also.map { var check = $0; check.value = remap($0.value); check.than = remap($0.than); return check }
            out.kind = .branch(c, then: then, otherwise: otherwise)
        case .forEach(let items, let limit, let failure, let steps): out.kind = .forEach(items: remap(items), limit: limit, onFailure: failure, steps: steps)
        case .repeatUntil(var c, let times, let steps):
            c.value = remap(c.value)
            c.than = remap(c.than)
            c.also = c.also.map { var check = $0; check.value = remap($0.value); check.than = remap($0.than); return check }
            out.kind = .repeatUntil(until: c, times: times, steps: steps)
        case .choose(let value, let paths, let otherwise): out.kind = .choose(value: remap(value), paths: paths, otherwise: otherwise)
        case .call(let flow, let inputs): out.kind = .call(flow: flow, inputs: inputs.mapValues(remap))
        case .finish(let value): out.kind = .finish(remap(value))
        case .data(var data):
            data.from = remap(data.from)
            data.than = data.than.map(remap)
            out.kind = .data(data)
        case .form(var form):
            form.title = remap(form.title)
            out.kind = .form(form)
        case .wait, .flow, .attempt, .parallel, .waitFor: break
        }
        return out
    }

    /// A step lifted into a flow of its own, and what's left calling it. What it read from around it comes in as inputs, under the same names, so the
    /// step reads as it did and the caller shows what it hands over. Its id stays, so whatever used its result still does.
    static func extract(_ id: String, in body: FlowBody, named name: String) throws -> (outer: FlowBody, inner: FlowBody) {
        guard let step = body.step(id) else { throw Problem(L("That step is gone.")) }
        let inside = FlowBody(steps: [step]).allSteps
        if inside.contains(where: { if case .finish = $0.kind { true } else { false } }) {
            throw Problem(L("It has a step that ends the flow, which would then end only the new one. Take that out first."))
        }
        // A flow hands back a tool's words, which have no fields: a later `{{step.field}}` would stop a run that had already done things.
        if case .action = step.kind, let used = body.allSteps.flatMap(\.usedTexts).flatMap(Values.slots).first(where: { $0.name == id && !$0.path.isEmpty }) {
            throw Problem(L("Steps after it use its field “{name}”, and a flow hands back only its words. Change those first.", ["name": used.name + used.path]))
        }
        // What set the caller off isn't what sets the new flow off, so that comes in as an input too.
        var own = Set(inside.map(\.id)).union(["today", "now"])
        if inside.contains(where: { switch $0.kind { case .forEach, .repeatUntil: true; default: false } }) { own.formUnion(["item", "index"]) }
        if inside.contains(where: { if case .attempt = $0.kind { true } else { false } }) { own.insert("error") }
        // A field goes in by itself: a step's whole answer, handed over, is its words, and those have no fields.
        var inputs: [String: String] = [:], keys: [String: String] = [:]
        let inner = rewriting(step) { text in
            Values.replacingSlots(in: text) { name, path in
                guard !own.contains(name) else { return "{{\(name)\(path)}}" }
                let written = "{{\(name)\(path)}}"
                if let key = keys[written] { return "{{input.\(key)}}" }
                var key = ([name] + Values.parts(of: path)).joined(separator: "_")
                if key.count > 40 || inputs[key] != nil { key = "\(key.prefix(34))_\(inputs.count)" }
                keys[written] = key
                inputs[key] = written
                return "{{input.\(key)}}"
            }
        }
        var called = step
        called.kind = .call(flow: name, inputs: inputs)
        // What the new flow's own step goes by: it's said there, and means nothing on a call.
        called.fields = nil
        called.sample = nil
        var innerBody = FlowBody(steps: [inner])
        innerBody.triggerSample = nil
        return (change(id, in: body) { $0 = called }, innerBody)
    }

    /// What differs between two versions, in words: for reading before saving or applying.
    @MainActor static func changes(from old: FlowBody, to new: FlowBody, catalog: Catalog) -> [String] {
        var out: [String] = []
        if old.triggers != new.triggers { out.append(L("What sets it off: {what}", ["what": Words.triggers(new)])) }
        if old.overlap != new.overlap { out.append(L("Changed: {step}", ["step": L("If it's set off while running")])) }
        if old.timeZone != new.timeZone { out.append(L("Changed: {step}", ["step": L("By the clock of")])) }
        if old.triggerSample != new.triggerSample { out.append(L("Changed: {step}", ["step": L("In practice, what set it off")])) }
        let before = Dictionary(old.allSteps.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let after = Dictionary(new.allSteps.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        for step in new.allSteps where before[step.id] == nil { out.append(L("Added: {step}", ["step": Words.label(step, catalog: catalog)])) }
        for step in old.allSteps where after[step.id] == nil { out.append(L("Removed: {step}", ["step": Words.label(step, catalog: catalog)])) }
        /// A step without what hangs from it: moving what's inside a branch isn't changing the branch.
        func own(_ step: Step) -> Step { step.mappingParts { _ in [] } }
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
                    for part in step.parts { walk(part.steps, "\(part.id):\(step.id)") }
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
