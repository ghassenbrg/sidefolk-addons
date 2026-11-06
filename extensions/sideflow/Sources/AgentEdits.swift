import CryptoKit
import Foundation
import SidefolkExtensionKit

/// How an agent changes a flow: by a list of the same edits the page makes, each checked, against the draft it read. What came of it is said in the same words the page uses, to the agent and to the person.
enum AgentEdits {
    /// What's on the draft now, to say which one an edit was made against: a person or another agent may have changed it since.
    static func fingerprint(_ body: FlowBody) -> String {
        let data = (try? JSONSerialization.data(withJSONObject: FlowCodec.json(body), options: [.sortedKeys])) ?? Data()
        return SHA256.hash(data: data).prefix(8).map { String(format: "%02x", $0) }.joined()
    }

    static func apply(_ patch: [[String: Any]], to body: FlowBody) throws -> FlowBody {
        var out = body
        for (at, edit) in patch.enumerated() {
            func wrong(_ words: String) -> Problem { Problem(L("Edit {count}: {what}", ["count": Format.integer(at + 1), "what": words])) }
            func existing(_ key: String) throws -> String {
                guard let id = edit[key] as? String else { throw wrong(L("It needs “{name}”.", ["name": key])) }
                guard out.step(id) != nil else { throw wrong(L("There's no step “{name}”.", ["name": id])) }
                return id
            }
            /// Where it goes: "start", a step's id, or the start of a way through one, like `then:check`.
            func place() throws -> String {
                guard let after = edit["after"] as? String else { throw wrong(L("It needs “{name}”.", ["name": "after"])) }
                let holder = after.firstIndex(of: ":").map { String(after[after.index(after: $0)...]) } ?? after
                guard after == "start" || out.step(holder) != nil else { throw wrong(L("There's no step “{name}”.", ["name": holder])) }
                return after
            }
            func step(replacing: String? = nil) throws -> Step {
                guard let raw = edit["step"] else { throw wrong(L("It needs “{name}”.", ["name": "step"])) }
                var used = Set(out.allSteps.map(\.id))
                if let replacing { used.remove(replacing) }
                do { return try FlowCodec.step(raw, depth: 0, used: &used) } catch let problem as Problem { throw wrong(problem.message) }
            }
            switch edit["op"] as? String {
            case "add":
                out = Editing.insert(try step(), after: try place(), in: out)
            case "remove":
                out = Editing.remove(try existing("id"), from: out)
            case "replace":
                let id = try existing("id")
                var new = try step(replacing: id)
                new.id = id
                out = Editing.change(id, in: out) { $0 = new }
            case "move":
                let id = try existing("id"), after = try place()
                let moved = Editing.place(id, after: after, in: out)
                guard moved != out || after == "start" else { throw wrong(L("“{name}” can't go inside itself.", ["name": id])) }
                out = moved
            default:
                throw wrong(L("It should say add, remove, replace or move."))
            }
        }
        // All of it as a whole, by what a whole definition has to be: two steps of one id, too deep.
        return try FlowCodec.body(FlowCodec.json(out))
    }
}

/// A problem that can be put right in one press: only where the way is plain, and as an edit to the draft that Undo takes back.
@MainActor enum Repairs {
    static func offers(_ problem: FlowProblem, flow: Flow) -> [Block] {
        guard let id = problem.step, let name = problem.uses else { return [] }
        let input: [String: Any] = ["flow": flow.id, "step": id, "name": name]
        // Made on one way and not the other: a fallback says what it is when it wasn't made.
        if problem.onOnePath {
            return [.action(Pages.button(L("Use “{name}” with a fallback", ["name": name]), "repair_fallback", input, style: .plain, symbol: "arrow.triangle.branch", detail: L("A step before this one gives what to use when it wasn't made. Write that in it: until you do, the run stops there when it's missing. You can undo this.")))]
        }
        if flow.draft.step(name) == nil {
            return [.action(Pages.button(L("Take “{name}” out of this step", ["name": name]), "repair_drop", input, style: .plain, symbol: "minus.circle", detail: L("Whatever it said there goes too. You can undo this.")))]
        }
        // A step further down the same list: what it gives comes too late, and moving it up is what's meant. Elsewhere there's more than one way, so it's theirs to choose.
        guard Editing.siblings(of: id, in: flow.draft).contains(where: { $0.id == name }) else { return [] }
        return [.action(Pages.button(L("Move “{name}” before this step", ["name": name]), "repair_move", input, style: .plain, symbol: "arrow.up", detail: L("You can undo this.")))]
    }

    static func moved(_ name: String, before id: String, in body: FlowBody) -> FlowBody { Editing.move(name, before: id, in: body) }

    /// A fallback step just before this one, and this one using it: the fallback's own "otherwise" is left to write, and the step's form shows it.
    static func withFallback(_ name: String, before id: String, in body: FlowBody) -> (FlowBody, String) {
        let fresh = Editing.freshId(body, base: "\(name)_or")
        let fallback = Step(id: fresh, kind: .data(DataStep(op: .fallback, from: "{{\(name)}}", than: "")))
        var out = Editing.change(id, in: body) { step in
            step = Editing.rewriting(step, { text in
                Values.replacingSlots(in: text) { slot, path in slot == name ? "{{\(fresh)\(path)}}" : "{{\(slot)\(path)}}" }
            }, inside: { $0 })
        }
        let list = Editing.siblings(of: id, in: out)
        let at = list.firstIndex { $0.id == id } ?? 0
        out = Editing.insert(fallback, after: at == 0 ? "start" : list[at - 1].id, in: out)
        // At the start of a way through a step, not the flow's own start.
        if at == 0, let holder = Editing.holders(of: id, in: body).last, let part = holder.parts.first(where: { $0.steps.contains { $0.id == id } }) {
            out = Editing.place(fresh, after: "\(part.id):\(holder.id)", in: out)
        }
        return (out, fresh)
    }

    static func dropped(_ name: String, from id: String, in body: FlowBody) -> FlowBody {
        Editing.change(id, in: body) { step in
            step = Editing.rewriting(step, { text in
                Values.replacingSlots(in: text) { slot, path in slot == name ? "" : "{{\(slot)\(path)}}" }
            }, inside: { $0 })
        }
    }
}
