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

    /// These steps of one list, from one to another, put inside a new step made to hold them. What they do doesn't change but for what they're now inside, and anything that used what they make and now can't be sure of it shows as a problem to fix.
    static func wrap(from first: String, through last: String, inside holder: Step, in body: FlowBody) -> FlowBody? {
        var body = body, done = false
        func filled(_ steps: [Step]) -> Step? {
            var out = holder
            switch holder.kind {
            case .branch(let condition, _, let otherwise): out.kind = .branch(condition, then: steps, otherwise: otherwise)
            case .forEach(let items, let limit, let failure, _): out.kind = .forEach(items: items, limit: limit, onFailure: failure, steps: steps)
            case .repeatUntil(let until, let times, _): out.kind = .repeatUntil(until: until, times: times, steps: steps)
            case .attempt(_, let recover, let always): out.kind = .attempt(steps: steps, recover: recover, always: always)
            case .parallel(let lanes):
                guard let lane = lanes.first else { return nil }
                out.kind = .parallel(lanes: [Step.Lane(name: lane.name, steps: steps)] + lanes.dropFirst())
            default: return nil
            }
            return out
        }
        body.steps = mapLists(body.steps) { list in
            guard let from = list.firstIndex(where: { $0.id == first }), let to = list.firstIndex(where: { $0.id == last }), from <= to, let whole = filled(Array(list[from...to])) else { return list }
            done = true
            return Array(list[..<from]) + [whole] + Array(list[(to + 1)...])
        }
        return done ? body : nil
    }

    /// The steps holding this one, outermost first.
    static func holders(of id: String, in body: FlowBody) -> [Step] {
        func walk(_ list: [Step], _ above: [Step]) -> [Step]? {
            for step in list {
                if step.id == id { return above }
                for part in step.parts {
                    if let found = walk(part.steps, above + [step]) { return found }
                }
            }
            return nil
        }
        return walk(body.steps, []) ?? []
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
    /// `inside`: what to do with the steps it holds, if not the same.
    static func rewriting(_ step: Step, _ remap: (String) -> String, inside: ((Step) -> Step)? = nil) -> Step {
        var out = step.mappingParts { $0.map { inside?($0) ?? rewriting($0, remap) } }
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
        // What's left around it, conditions and all. A flow hands back a tool's words, which have no fields, and what's inside it goes with it: a later use of either would stop
        // a run that had already done things, or quietly take the wrong way.
        var around: [(name: String, path: String)] = []
        _ = change(id, in: body) { $0.kind = .text("") }.steps.map { rewriting($0) { text in around += Values.slots(text); return text } }
        if case .action = step.kind, let used = around.first(where: { $0.name == id && !$0.path.isEmpty }) {
            throw Problem(L("Steps after it use its field “{name}”, and a flow hands back only its words. Change those first.", ["name": used.name + used.path]))
        }
        let goesWithIt = Set(inside.dropFirst().map(\.id))
        if let used = around.first(where: { goesWithIt.contains($0.name) }) {
            throw Problem(L("Steps after it use “{name}”, which would go into the new flow. Change those first.", ["name": used.name + used.path]))
        }
        // What set the caller off isn't what sets the new flow off, so that comes in as an input too.
        let own = Set(inside.map(\.id)).union(["today", "now"])
        // A field goes in by itself: a step's whole answer, handed over, is its words, and those have no fields.
        var inputs: [String: String] = [:], keys: [String: String] = [:]
        func remap(_ text: String, keeping own: Set<String>) -> String {
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
        // `{{item}}` and `{{error}}` are its own only inside what brings them: above a loop or a try they're still the ones from outside.
        let holders = body.allSteps.filter { FlowBody(steps: [$0]).allSteps.dropFirst().contains { $0.id == id } }
        // A lane starts with the item of the go it's in, and a new flow starts with none.
        let inAList = holders.contains { if case .forEach = $0.kind { true } else { false } }
            || holders.indices.contains { lane in
                guard case .parallel = holders[lane].kind else { return false }
                return holders[..<lane].contains { if case .repeatUntil = $0.kind { true } else { false } }
            }
        func scoped(_ one: Step, keeping own: Set<String>) -> Step {
            var within = own
            var here = own
            switch one.kind {
            case .forEach: within.formUnion(["item", "index"])
            // What a repeat stops on is looked at from inside its go. Inside a list the item stays the list's, and that one comes from outside.
            case .repeatUntil:
                within.formUnion(inAList ? ["index"] : ["item", "index"])
                here = within
            case .attempt: within.insert("error")
            default: break
            }
            return rewriting(one, { remap($0, keeping: here) }, inside: { scoped($0, keeping: within) })
        }
        let inner = scoped(step, keeping: own)
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
        /// What each thing holds, of the steps both versions have, in order.
        func lists(_ body: FlowBody) -> [String: [String]] {
            var out: [String: [String]] = [:]
            func walk(_ list: [Step], _ inside: String) {
                out[inside] = list.map(\.id).filter { before[$0] != nil && after[$0] != nil }
                for step in list {
                    for part in step.parts { walk(part.steps, "\(part.id):\(step.id)") }
                }
            }
            walk(body.steps, "")
            return out
        }
        let was = lists(old)
        let home = Dictionary(was.flatMap { inside, ids in ids.map { ($0, inside) } }, uniquingKeysWith: { a, _ in a })
        // What moved is what isn't in its old order among the rest: moving the fourth up one moved one step, though the one it passed stands elsewhere now.
        var moved = Set<String>()
        for (inside, ids) in lists(new) {
            let stayed = ids.filter { home[$0] == inside }
            moved.formUnion(ids.filter { home[$0] != inside })
            moved.formUnion(Set(stayed).subtracting(longestShared(was[inside]?.filter(stayed.contains) ?? [], stayed)))
        }
        for step in new.allSteps {
            guard let earlier = before[step.id] else { continue }
            if own(earlier) != own(step) {
                out.append(L("Changed: {step}", ["step": Words.label(step, catalog: catalog)]))
            } else if moved.contains(step.id) {
                out.append(L("Moved: {step}", ["step": Words.label(step, catalog: catalog)]))
            }
        }
        return out
    }

    /// The longest run of ids both lists have in the same order.
    private static func longestShared(_ a: [String], _ b: [String]) -> [String] {
        var row = Array(repeating: [String](), count: b.count + 1)
        for x in a {
            var next = row
            for (at, y) in b.enumerated() {
                next[at + 1] = x == y ? row[at] + [y] : (next[at].count > row[at + 1].count ? next[at] : row[at + 1])
            }
            row = next
        }
        return row[b.count]
    }

    /// The list a step stands in, whichever way through the flow.
    static func siblings(of id: String, in body: FlowBody) -> [Step] {
        func find(_ list: [Step]) -> [Step]? {
            if list.contains(where: { $0.id == id }) { return list }
            for step in list {
                for part in step.parts { if let found = find(part.steps) { return found } }
            }
            return nil
        }
        return find(body.steps) ?? []
    }

    /// Where a step can go: after any step that isn't part of it. Not where it already stands.
    static func placesToMove(_ id: String, in body: FlowBody) -> [Step] {
        guard let step = body.step(id) else { return [] }
        let own = Set(FlowBody(steps: [step]).allSteps.map(\.id))
        let list = siblings(of: id, in: body)
        let before = list.firstIndex { $0.id == id }.flatMap { $0 > 0 ? list[$0 - 1].id : nil }
        return body.allSteps.filter { !own.contains($0.id) && $0.id != before }
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

    /// What someone typed into a number field, written plainly.
    static func number(_ text: String) -> Double? { NumberWords.typed(text) }

    /// Whether it has digits in it but isn't written plainly, so the field can say what it wants.
    static func couldBeMoreThanOne(_ text: String) -> Bool {
        text.contains { $0.isASCII && $0.isNumber } && NumberWords.typed(text) == nil
    }

    /// Words from an earlier step, for a number field: only what `NumberWords` reads, since nobody's there to mean it.
    static func number(fromWords words: String) -> Double? { NumberWords.number(words) }

    /// Words that are a whole number and nothing else: "1.000" could be a thousand, and "12.0" isn't how anyone writes a count.
    static func wholeNumber(_ text: String) -> Int? {
        guard let number = NumberWords.typed(text), !text.contains("."), abs(number) < 1e15 else { return nil }
        return Int(number)
    }

    static func yesOrNo(_ text: String) -> Bool? {
        switch text.trimmed.lowercased() {
        case "true", "yes", "on": true
        case "false", "no", "off": false
        default: nil
        }
    }

    /// The same input with one value set at a dotted name, a record's own field at a time. Nothing left in a record takes the record with it.
    static func setting(_ path: [String], to value: JSON?, in input: [String: JSON]) -> [String: JSON] {
        guard let first = path.first else { return input }
        var out = input
        if path.count == 1 {
            out[first] = value
            return out
        }
        var inner: [String: JSON] = [:]
        if case .object(let o)? = input[first] { inner = o }
        inner = setting(Array(path.dropFirst()), to: value, in: inner)
        out[first] = inner.isEmpty ? nil : .object(inner)
        return out
    }

    /// A value typed for a tool's parameter, as the schema wants it. A number with `{{x}}` stays text and shows as something to fix.
    static func value(_ text: String, for parameter: Catalog.Parameter) -> JSON? {
        let t = text.trimmed
        guard !t.isEmpty else { return nil }
        // An earlier step's value is filled in when it runs, as what it is then. In a list, among other words, it's one entry of it.
        if !Values.slots(t).isEmpty, parameter.kind != .text, parameter.kind != .list || Values.replacingSlots(in: t, { _, _ in "" }).trimmed.isEmpty { return .string(t) }
        switch parameter.kind {
        case .integer:
            return wholeNumber(t).map { .number(Double($0)) } ?? .string(t)
        case .number:
            return number(t).map { .number($0) } ?? .string(t)
        case .boolean:
            return yesOrNo(t).map { .bool($0) } ?? .string(t)
        case .list:
            // Only commas is nothing typed, not a list with nothing in it.
            let entries = t.split(separator: ",").map { String($0).trimmed }.filter { !$0.isEmpty }
            return entries.isEmpty ? nil : .array(entries.map { .string($0) })
        default:
            return .string(text)
        }
    }
}
