import Foundation
import SidefolkExtensionKit

/// The tools a step can use, as Sidefolk offers them now. Any extension installed later is here with no change to anything in this program.
@MainActor final class Catalog {
    struct Parameter: Equatable {
        enum Kind: Equatable { case text, number, integer, boolean, choice([String]), list, other }

        var name: String
        var kind: Kind
        var required: Bool
        var detail: String?
        var title: String
    }

    struct Tool: Equatable {
        var name: String
        var title: String
        var description: String
        var mutates: Bool
        var readsOnly: Bool
        /// Sidefolk's word for it, for this caller: high asks every single time.
        var risk = "medium"
        var category: String
        var fromExtension: String?
        var parameters: [Parameter]
    }

    private(set) var tools: [Tool] = []
    private(set) var plans: [Plans.Standing] = []
    private(set) var loadedAt: Date?

    func tool(_ name: String) -> Tool? { tools.first { $0.name == name } }

    func use(_ listing: Actions.Listing, at now: Date = Date()) {
        tools = listing.tools.map(Self.tool).sorted { $0.title < $1.title }
        plans = listing.plans
        loadedAt = now
    }

    func plan(_ id: String) -> Plans.Standing? { plans.first { $0.id == id } }

    func refresh() async {
        guard let listing = await Actions.list() else { return }
        use(listing)
    }

    static func tool(_ t: Actions.Tool) -> Tool {
        let schema = JSONText.read(t.schema) as? [String: Any] ?? [:]
        let properties = schema["properties"] as? [String: Any] ?? [:]
        let required = Set(schema["required"] as? [String] ?? [])
        let parameters = properties.keys.sorted { (required.contains($0) ? 0 : 1, $0) < (required.contains($1) ? 0 : 1, $1) }.map { name -> Parameter in
            let p = properties[name] as? [String: Any] ?? [:]
            let kind: Parameter.Kind
            if let values = p["enum"] as? [String], !values.isEmpty {
                kind = .choice(values)
            } else {
                switch p["type"] as? String {
                case "string": kind = .text
                case "number": kind = .number
                case "integer": kind = .integer
                case "boolean": kind = .boolean
                case "array": kind = (p["items"] as? [String: Any])?["type"] as? String == "string" ? .list : .other
                default: kind = .other
                }
            }
            return Parameter(name: name, kind: kind, required: required.contains(name), detail: (p["description"] as? String)?.nonEmpty,
                             title: (p["title"] as? String)?.nonEmpty ?? name.replacingOccurrences(of: "_", with: " ").capitalizedFirst)
        }
        return Tool(name: t.name, title: t.title, description: t.description, mutates: t.mutates, readsOnly: t.readsOnly, risk: t.risk, category: t.category, fromExtension: t.extensionName, parameters: parameters)
    }
}

extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}

/// What's wrong with a definition, for a person to fix and a model to read: before anything runs.
struct FlowProblem: Equatable {
    var step: String?
    var text: String
}

extension FlowBody {
    /// What's wrong with what sets it off: a page saves as it goes, so it can be halfway through being written.
    var triggerProblem: String? {
        switch trigger {
        case .every(let minutes, _) where minutes < FlowBody.shortestEvery || minutes > FlowBody.longestEvery:
            L("“every_minutes” must be from {least} to {most}.", ["least": Format.integer(FlowBody.shortestEvery), "most": Format.integer(FlowBody.longestEvery)])
        case .days(let days, _, _, _) where days.isEmpty:
            L("A schedule needs at least one day.")
        case .watch(let w) where w.target.trimmed.isEmpty:
            L("A watch needs “target”: a web address, a full path or a program.")
        default: nil
        }
    }

    @MainActor func problems(_ catalog: Catalog) -> [FlowProblem] {
        var out: [FlowProblem] = []
        if steps.isEmpty { out.append(FlowProblem(step: nil, text: L("It has no steps yet."))) }
        if let wrong = triggerProblem { out.append(FlowProblem(step: nil, text: wrong)) }
        let actions = Engine.planSteps(self, title: "").count
        if actions > Plans.maxSteps {
            out.append(FlowProblem(step: nil, text: L("It has {count} different things to allow, counting what it watches. A flow can have {limit}: move some into a flow of their own.", ["count": Format.integer(actions), "limit": Format.integer(Plans.maxSteps)])))
        }
        /// What only one path of a condition made: there, but not for sure.
        var onOnePath = Set<String>()
        func refs(_ strings: [String], _ step: Step, seen: Set<String>) {
            for name in strings.flatMap(Values.references) where !seen.contains(name) {
                out.append(FlowProblem(step: step.id, text: onOnePath.contains(name)
                    ? L("It uses “{name}”, which only one path of the condition before it makes. Use it inside that path, or make it on both.", ["name": name])
                    : L("It uses “{name}”, which no earlier step makes.", ["name": name])))
            }
        }
        func walk(_ list: [Step], seen: inout Set<String>) {
            for step in list {
                switch step.kind {
                case .action(let tool, let input):
                    refs(input.values.flatMap(\.strings), step, seen: seen)
                    if tool == "companion.job", (input["job"]?.string?.count ?? 0) > 200 {
                        out.append(FlowProblem(step: step.id, text: L("A job is at most {count} characters, so a card can show all of it.", ["count": Format.integer(200)])))
                    }
                    if catalog.loadedAt != nil {
                        if let known = catalog.tool(tool) {
                            for p in known.parameters where p.required && (input[p.name] == nil || input[p.name]?.string?.trimmed.isEmpty == true) {
                                out.append(FlowProblem(step: step.id, text: L("“{name}” needs a value.", ["name": p.title])))
                            }
                            for key in input.keys.sorted() where !known.parameters.contains(where: { $0.name == key }) {
                                out.append(FlowProblem(step: step.id, text: L("“{tool}” has no value called “{name}”.", ["tool": known.title, "name": key])))
                            }
                        } else {
                            out.append(FlowProblem(step: step.id, text: L("“{tool}” isn't available now. Its extension may be off or gone, or Sidefolk doesn't let extensions use it.", ["tool": tool])))
                        }
                    }
                case .ai(let prompt): refs([prompt], step, seen: seen)
                case .ask(let question, _): refs([question], step, seen: seen)
                case .text(let text): refs([text], step, seen: seen)
                case .branch(let c, let then, let otherwise):
                    // Looking at something only one path made is how a flow asks whether it ran: only that test may.
                    for check in c.checks where check.test != .is_empty && check.test != .not_empty { refs([check.value, check.than], step, seen: seen) }
                    var yes = seen, no = seen
                    walk(then, seen: &yes)
                    walk(otherwise, seen: &no)
                    onOnePath.formUnion(yes.symmetricDifference(no))
                    seen = yes.intersection(no)
                case .wait: break
                case .flow(let name):
                    if name.trimmed.isEmpty { out.append(FlowProblem(step: step.id, text: L("Pick which flow to run."))) }
                }
                if step.hasOutput { seen.insert(step.id) }
            }
        }
        var seen: Set<String> = Values.reserved
        walk(steps, seen: &seen)
        return out
    }
}
