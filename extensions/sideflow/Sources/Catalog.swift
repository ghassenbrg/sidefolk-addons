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
        /// A record's own parameters, when it says what it holds.
        var children: [Parameter] = []

        /// What the person is told it wants. Text says nothing: that's what's expected.
        var typeWord: String? {
            switch kind {
            case .number: L("a number")
            case .integer: L("a whole number")
            case .boolean: L("yes or no")
            case .list: L("a list")
            default: nil
            }
        }
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
        /// The fields its answer says it holds, each usable by name.
        var outputFields: [String] = []
        /// What each field is, when the tool says: `string`, `number`, `integer`, `boolean`, `array`, `object`.
        var outputTypes: [String: String] = [:]
        /// Who offers it, in their own name, and whether that's an MCP server the person added.
        var fromTitle: String?
        var fromServer = false
    }

    private(set) var tools: [Tool] = []
    private(set) var plans: [Plans.Standing] = []
    private(set) var loadedAt: Date?
    /// Whether exactly one flow goes by this name, as a step finds it. The engine says.
    var findsFlow: (String) -> Bool = { _ in true }
    /// What a call would run, by that flow's name and the version it stays on: nil when there's no such thing.
    var calledBody: (String, Int?) -> FlowBody? = { _, _ in nil }

    /// What tools and connections were called while they were here: all that's left to say about one that's gone. `Connections` keeps these on disk.
    var rememberedTools: [String: String] = [:]
    var rememberedNames: [String: String] = [:]

    func tool(_ name: String) -> Tool? { tools.first { $0.name == name } }

    /// A tool's name for people, here or not. Its id is never one.
    func title(of tool: String) -> String {
        self.tool(tool)?.title ?? rememberedTools[tool] ?? tool.split(separator: ".").last.map { $0.replacingOccurrences(of: "_", with: " ").capitalizedFirst } ?? tool
    }

    /// Whether anything of this connection is offered now: one tool gone from an extension that's here won't come back by waiting.
    func offers(connection id: String) -> Bool { tools.contains { $0.fromExtension == id } }

    func connectionTitle(_ id: String) -> String {
        tools.first { $0.fromExtension == id }?.fromTitle ?? rememberedNames[id] ?? id.replacingOccurrences(of: "-", with: " ").capitalizedFirst
    }

    func use(_ listing: Actions.Listing, at now: Date = Date()) {
        tools = listing.tools.map(Self.tool).sorted { $0.title < $1.title }
        plans = listing.plans
        loadedAt = now
    }

    /// What goes to a tool for a step's values: one way, so a page's mark and a run agree.
    func filled(_ name: String, _ input: [String: JSON], from values: Values) -> [String: Any] {
        fill(tool(name)?.parameters ?? [], input, from: values)
    }

    /// One level at a time, so a record's own fields get what its top level does.
    private func fill(_ parameters: [Parameter], _ input: [String: JSON], from values: Values) -> [String: Any] {
        let wordy = Set(parameters.filter { if case .text = $0.kind { true } else { false } }.map(\.name))
        let lists = Set(parameters.filter { $0.kind == .list }.map(\.name))
        let absent = Set(parameters.filter { switch $0.kind { case .number, .integer, .boolean: true; case .choice(let answers): !answers.contains(""); default: false } }.map(\.name))
        var plain = input
        var out: [String: Any] = [:]
        for parameter in parameters where !parameter.children.isEmpty {
            guard case .object(let inner)? = input[parameter.name] else { continue }
            plain[parameter.name] = nil
            let filled = fill(parameter.children, inner, from: values)
            // An empty record said on purpose stays one; one that came to nothing isn't given.
            if !filled.isEmpty || inner.isEmpty { out[parameter.name] = filled }
        }
        // Words stored for a list mean what typing them there would.
        for parameter in parameters where parameter.kind == .list {
            if let words = plain[parameter.name]?.string { plain[parameter.name] = Editing.value(words, for: parameter) }
        }
        for (key, value) in values.fill(plain, wordsIn: wordy, listsIn: lists, absentIn: absent) {
            let parameter = parameters.first { $0.name == key }
            // Blank words where words don't go: nothing given, not a blank a number or a list can't be.
            if (value as? String)?.trimmed.isEmpty == true, let parameter, Self.wantsMoreThanWords(parameter) { continue }
            out[key] = parameter.map { Self.asItWants(value, $0) } ?? value
        }
        return out
    }

    private static func wantsMoreThanWords(_ parameter: Parameter) -> Bool {
        switch parameter.kind {
        case .number, .integer, .boolean, .list: true
        default: false
        }
    }

    /// Words from an earlier step that plainly are what this wants: "12" for a number, "yes" for a yes or no, one entry for a list. Anything else goes as it is, and Sidefolk says it doesn't fit.
    private static func asItWants(_ value: Any, _ parameter: Parameter) -> Any {
        guard let words = (value as? String)?.trimmed, !words.isEmpty else { return value }
        switch parameter.kind {
        case .number: return Editing.number(words) ?? value
        case .integer: return Editing.wholeNumber(words) ?? value
        case .boolean:
            return Editing.yesOrNo(words) ?? value
        case .list: return [words]
        default: return value
        }
    }

    /// Why what's been filled in can't go to this tool. Nothing is reshaped to make it fit: a plain reason, before it gets there.
    func doesntFit(_ name: String, _ filled: [String: Any]) -> String? {
        func check(_ filled: [String: Any], _ parameters: [Parameter]) -> String? {
            for parameter in parameters {
                // Sidefolk counts a null as missing where something's needed, whatever the schema says: it wouldn't have got there.
                guard let given = filled[parameter.name], !(given is NSNull) else {
                    if parameter.required { return L("“{name}” is needed, and this gives it nothing.", ["name": parameter.title]) }
                    continue
                }
                let value = JSON(given)
                let wrong: Bool
                switch parameter.kind {
                case .integer:
                    if case .number(let n) = value { wrong = n != n.rounded() } else { wrong = true }
                case .number:
                    if case .number = value { wrong = false } else { wrong = true }
                case .boolean:
                    if case .bool = value { wrong = false } else { wrong = true }
                case .list:
                    guard case .array(let items) = value else { wrong = true; break }
                    if items.contains(.null) { return L("“{name}” has an entry that came back with nothing in it.", ["name": parameter.title]) }
                    if let odd = items.first(where: { $0.string == nil }) { return L("“{name}” is a list of words, and one entry isn't: “{value}”.", ["name": parameter.title, "value": Values.text(odd).clipped(80)]) }
                    wrong = false
                default:
                    wrong = false
                }
                if wrong, let what = parameter.typeWord { return L("“{name}” wants {what}, and this gives it “{value}”.", ["name": parameter.title, "what": what, "value": Values.text(value).clipped(80)]) }
                if !parameter.children.isEmpty, let inner = given as? [String: Any], let found = check(inner, parameter.children) { return found }
            }
            return nil
        }
        return check(filled, tool(name)?.parameters ?? [])
    }

    /// A dotted name's way through the parameters. A parameter whose own name has a dot in it is that parameter.
    func path(_ name: String, of tool: String) -> [String] {
        func walk(_ left: String, _ list: [Parameter]) -> [String]? {
            if list.contains(where: { $0.name == left }) { return [left] }
            for p in list where left.hasPrefix(p.name + ".") {
                if let rest = walk(String(left.dropFirst(p.name.count + 1)), p.children) { return [p.name] + rest }
            }
            return nil
        }
        return walk(name, self.tool(tool)?.parameters ?? []) ?? [name]
    }

    /// The parameters a tool needs and hasn't got, a record's own too once it's been started.
    static func unfilled(_ parameters: [Parameter], _ input: [String: JSON]) -> [Parameter] {
        parameters.flatMap { p -> [Parameter] in
            guard let value = input[p.name], value.string?.trimmed.isEmpty != true else { return p.required ? [p] : [] }
            if case .object(let inner) = value, !p.children.isEmpty { return unfilled(p.children, inner) }
            return []
        }
    }

    /// What a tool would get nothing for where it can't go without: words that are nothing but values that came back null, for a parameter it needs or doesn't say it can leave
    /// out, a record's own fields by the same rule, or inside a list or a record it doesn't describe, where there's no leaving it out. Other words around a value stand.
    func nothingFor(_ name: String, _ input: [String: JSON], from values: Values) -> String? {
        func within(_ value: JSON) -> String? {
            switch value {
            case .string(let text): values.saysNothing(text)
            case .array(let items): items.lazy.compactMap(within).first
            case .object(let fields): fields.keys.sorted().lazy.compactMap { fields[$0].flatMap(within) }.first
            default: nil
            }
        }
        func check(_ input: [String: JSON], _ parameters: [Parameter]?) -> String? {
            for (key, value) in input.sorted(by: { $0.key < $1.key }) {
                let parameter = parameters?.first { $0.name == key }
                if case .string(let text) = value {
                    if parameter?.required != false, let found = values.saysNothing(text) { return found }
                } else if case .object(let fields) = value, let inner = parameter?.children, !inner.isEmpty {
                    if let found = check(fields, inner) { return found }
                } else if let found = within(value) {
                    return found
                }
            }
            return nil
        }
        return check(input, tool(name)?.parameters)
    }

    func plan(_ id: String) -> Plans.Standing? { plans.first { $0.id == id } }

    func refresh() async {
        guard let listing = await Actions.list() else { return }
        use(listing)
    }

    private static func fields(_ schema: String?) -> [String] {
        guard let schema, let o = JSONText.read(schema) as? [String: Any], let properties = o["properties"] as? [String: Any] else { return [] }
        // What a `{{step.field}}` can reach: any other would go to a real tool as literal braces.
        return properties.keys.filter { $0.range(of: #"^[A-Za-z0-9_]{1,40}$"#, options: .regularExpression) != nil }.sorted()
    }

    /// A schema's parameters, a record's own inside it, as deep as a form can sensibly show.
    private static func parameters(_ properties: [String: Any], required: Set<String>, depth: Int = 0) -> [Parameter] {
        properties.keys.sorted { (required.contains($0) ? 0 : 1, $0) < (required.contains($1) ? 0 : 1, $1) }.map { name -> Parameter in
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
            var made = Parameter(name: name, kind: kind, required: required.contains(name), detail: (p["description"] as? String)?.nonEmpty,
                                 title: (p["title"] as? String)?.nonEmpty ?? name.replacingOccurrences(of: "_", with: " ").capitalizedFirst)
            if depth < 2, p["type"] as? String == "object", let inner = p["properties"] as? [String: Any], !inner.isEmpty {
                made.children = parameters(inner, required: Set(p["required"] as? [String] ?? []), depth: depth + 1)
            }
            return made
        }
    }

    /// What a dotted name means in a tool's parameters.
    func parameter(_ path: String, of tool: String) -> Parameter? {
        var list = self.tool(tool)?.parameters ?? []
        var found: Parameter?
        for part in self.path(path, of: tool) {
            found = list.first { $0.name == part }
            list = found?.children ?? []
        }
        return found
    }

    private static func types(_ schema: String?) -> [String: String] {
        guard let schema, let o = JSONText.read(schema) as? [String: Any], let properties = o["properties"] as? [String: Any] else { return [:] }
        return properties.compactMapValues { ($0 as? [String: Any])?["type"] as? String }
    }

    static func tool(_ t: Actions.Tool) -> Tool {
        let schema = JSONText.read(t.schema) as? [String: Any] ?? [:]
        let properties = schema["properties"] as? [String: Any] ?? [:]
        let required = Set(schema["required"] as? [String] ?? [])
        let parameters = Self.parameters(properties, required: required)
        return Tool(name: t.name, title: t.title, description: t.description, mutates: t.mutates, readsOnly: t.readsOnly, risk: t.risk, category: t.category, fromExtension: t.extensionName, parameters: parameters, outputFields: Self.fields(t.outputSchema), outputTypes: Self.types(t.outputSchema), fromTitle: t.extensionTitle, fromServer: t.fromServer)
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
    var triggerProblem: String? { triggers.lazy.compactMap(Self.problem).first }

    private static func problem(_ trigger: Trigger) -> String? {
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

    /// A step that says nothing: a page saves as it goes, so it can be halfway through being written.
    var blank: String? {
        allSteps.lazy.compactMap(\.saysNothing).first
    }

    /// What keeps it from running at all, whoever asks.
    var unfinished: String? {
        if let wrong = triggerProblem { return wrong }
        if allSteps.count > FlowBody.maxSteps { return L("A flow can have at most {count} steps.", ["count": Format.integer(FlowBody.maxSteps)]) }
        return blank
    }

    @MainActor func problems(_ catalog: Catalog) -> [FlowProblem] {
        var out: [FlowProblem] = []
        // Saying what it takes and then using something else is a call that can never get it.
        if !inputs.isEmpty {
            for step in allSteps {
                for name in step.usedTexts.flatMap(Values.slots).filter({ $0.0 == "input" }).compactMap({ $0.1.dropFirst().split(whereSeparator: { $0 == "." || $0 == "[" }).first }).map(String.init) where !inputs.contains(where: { $0.name == name }) {
                    out.append(FlowProblem(step: step.id, text: L("It uses “{value}”, and that isn't among what this flow says it takes.", ["value": "{{input.\(name)}}"])))
                }
            }
        }
        if steps.isEmpty { out.append(FlowProblem(step: nil, text: L("It has no steps yet."))) }
        if allSteps.count > FlowBody.maxSteps { out.append(FlowProblem(step: nil, text: L("A flow can have at most {count} steps.", ["count": Format.integer(FlowBody.maxSteps)]))) }
        if let wrong = triggerProblem { out.append(FlowProblem(step: nil, text: wrong)) }
        let actions = Engine.lines(Engine.planSteps(self, title: ""))
        if actions > Plans.maxSteps {
            out.append(FlowProblem(step: nil, text: L("It has {count} different things to allow, counting what it watches. A flow can have {limit}: move some into a flow of their own.", ["count": Format.integer(actions), "limit": Format.integer(Plans.maxSteps)])))
        }
        /// What only one path of a condition made: there, but not for sure.
        var onOnePath = Set<String>()
        /// What the steps that give several things give: a renamed lane or a removed field would otherwise be found out only when it runs.
        let gives: [String: Set<String>] = Dictionary(allSteps.compactMap { step -> (String, Set<String>)? in
            switch step.kind {
            case .parallel(let lanes): (step.id, Set(Engine.keys(lanes)).union(step.join == .first ? [Engine.winner] : step.join == .settled ? [Engine.notFinished] : []))
            case .form(let form): (step.id, Set(form.fields.map(\.name)))
            default: nil
            }
        }, uniquingKeysWith: { a, _ in a })
        func refs(_ strings: [String], _ step: Step, seen: Set<String>) {
            for (name, path) in strings.flatMap(Values.slots) {
                guard let known = gives[name], let field = path.dropFirst().split(whereSeparator: { $0 == "." || $0 == "[" }).first.map(String.init), !known.contains(field) else { continue }
                out.append(FlowProblem(step: step.id, text: L("It uses “{name}”, which that step doesn't give. It may have been renamed.", ["name": name + path])))
            }
            for name in strings.flatMap(Values.references) where !seen.contains(name) {
                out.append(FlowProblem(step: step.id, text: onOnePath.contains(name)
                    ? L("It uses “{name}”, which only one path of the condition before it makes. Use it inside that path, or make it on both.", ["name": name])
                    : L("It uses “{name}”, which no earlier step makes.", ["name": name])))
            }
        }
        /// What a step of the kinds that hold others needs of itself.
        func checkKind(_ step: Step) {
            switch step.kind {
            case .repeatUntil(let until, _, let steps):
                if until.checks.contains(where: { $0.value.trimmed.isEmpty }) { out.append(FlowProblem(step: step.id, text: L("Say what has to hold for it to stop."))) }
                // "Contains nothing" never holds, so every go would run.
                if until.checks.contains(where: { [.contains, .not_contains, .more_than, .less_than].contains($0.test) && $0.than.trimmed.isEmpty }) {
                    out.append(FlowProblem(step: step.id, text: L("Say what to compare it with.")))
                }
                if steps.isEmpty { out.append(FlowProblem(step: step.id, text: L("Add what to do each time round."))) }
            case .forEach(let items, _, _, let steps):
                if items.trimmed.isEmpty { out.append(FlowProblem(step: step.id, text: L("Say which list to go through."))) }
                if steps.isEmpty { out.append(FlowProblem(step: step.id, text: L("Add what to do with each item."))) }
            case .choose(let value, let paths, _):
                if value.trimmed.isEmpty { out.append(FlowProblem(step: step.id, text: L("Say what to look at."))) }
                if paths.contains(where: { $0.when.trimmed.isEmpty }) { out.append(FlowProblem(step: step.id, text: L("Say what each path is for."))) }
            case .attempt(let steps, _, _):
                if steps.isEmpty { out.append(FlowProblem(step: step.id, text: L("Add the steps to try."))) }
            case .parallel(let lanes):
                if lanes.contains(where: { $0.steps.isEmpty }) { out.append(FlowProblem(step: step.id, text: L("Each lane needs a step."))) }
            case .call(let flow, let inputs):
                if let body = catalog.calledBody(flow, step.pin) {
                    out += Contract.problems(of: inputs, to: body, flow: flow).map { FlowProblem(step: step.id, text: $0) }
                    if let pin = step.pin, let allowed = catalog.calledBody(flow, nil), Contract.goesBeyond(body, allowed) {
                        out.append(FlowProblem(step: step.id, text: L("Version {count} of “{name}” has an AI step or sets off a flow that what you've allowed for “{name}” now doesn't have, so it can't stay on that version.", ["count": Format.integer(pin), "name": flow])))
                    }
                } else if let pin = step.pin, catalog.findsFlow(flow), !flow.trimmed.isEmpty {
                    out.append(FlowProblem(step: step.id, text: L("It stays on version {count} of “{name}”, and that version is no longer kept.", ["count": Format.integer(pin), "name": flow])))
                }
                if flow.trimmed.isEmpty { out.append(FlowProblem(step: step.id, text: L("Pick which flow to run."))) } else if !catalog.findsFlow(flow) { out.append(FlowProblem(step: step.id, text: L("There's no one flow called “{name}”. Pick it again.", ["name": flow]))) }
            case .form(let form):
                if form.fields.isEmpty { out.append(FlowProblem(step: step.id, text: L("Add something for the form to ask."))) }
                else if let wrong = step.saysNothing { out.append(FlowProblem(step: step.id, text: wrong)) }
            case .data(let data):
                if data.from.trimmed.isEmpty, let wrong = step.saysNothing { out.append(FlowProblem(step: step.id, text: wrong)) }
            default: break
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
                            for p in Catalog.unfilled(known.parameters, input) {
                                out.append(FlowProblem(step: step.id, text: L("“{name}” needs a value.", ["name": p.title])))
                            }
                            for key in input.keys.sorted() where !known.parameters.contains(where: { $0.name == key }) {
                                out.append(FlowProblem(step: step.id, text: L("“{tool}” has no value called “{name}”.", ["tool": known.title, "name": key])))
                            }
                        } else {
                            out.append(FlowProblem(step: step.id, text: (Connections.isMissing(tool, catalog) ? Connections.id(of: tool) : nil).map { L("It needs {name}, which isn't here now.", ["name": catalog.connectionTitle($0)]) } ?? L("“{tool}” isn't available now. Its extension may be off or gone, or Sidefolk doesn't let extensions use it.", ["tool": catalog.title(of: tool)])))
                        }
                    }
                case .ai(let prompt):
                    if prompt.trimmed.isEmpty { out.append(FlowProblem(step: step.id, text: L("Say what to write."))) }
                    refs([prompt], step, seen: seen)
                case .ask(let question, _):
                    if question.trimmed.isEmpty { out.append(FlowProblem(step: step.id, text: L("Say what to ask."))) }
                    refs([question], step, seen: seen)
                case .text(let text): refs([text], step, seen: seen)
                case .branch(let c, _, _):
                    if c.checks.contains(where: { $0.value.trimmed.isEmpty }) { out.append(FlowProblem(step: step.id, text: L("Say what each check looks at."))) }
                    // "Contains nothing" or "more than nothing" decides nothing, and it's how a new one starts.
                    if c.checks.contains(where: { [.contains, .not_contains, .more_than, .less_than].contains($0.test) && $0.than.trimmed.isEmpty }) {
                        out.append(FlowProblem(step: step.id, text: L("Say what to compare it with.")))
                    }
                    // Looking at something only one path made is how a flow asks whether it ran: only that test may.
                    for check in c.checks where check.test != .is_empty && check.test != .not_empty { refs([check.value, check.than], step, seen: seen) }
                case .forEach, .choose, .call, .finish, .data, .form:
                    refs(step.needsThere, step, seen: seen)
                // What it stops on is looked at after its steps, so it's checked there.
                case .attempt, .parallel, .waitFor, .repeatUntil: break
                case .wait: break
                case .flow(let name):
                    if name.trimmed.isEmpty { out.append(FlowProblem(step: step.id, text: L("Pick which flow to run."))) } else if !catalog.findsFlow(name) { out.append(FlowProblem(step: step.id, text: L("There's no one flow called “{name}”. Pick it again.", ["name": name]))) }
                }
                checkKind(step)
                if !step.parts.isEmpty {
                    var ways: [Set<String>] = []
                    for part in step.parts {
                        var inside = seen
                        switch step.kind {
                        case .forEach, .repeatUntil: inside.formUnion(["item", "index"])
                        default: break
                        }
                        if part.id == "recover" { inside.insert("error") }
                        walk(part.steps, seen: &inside)
                        if case .repeatUntil(let until, _, _) = step.kind {
                            for check in until.checks where check.test != .is_empty && check.test != .not_empty { refs([check.value, check.than], step, seen: inside) }
                        }
                        ways.append(inside)
                    }
                    if step.after == .common {
                        let both = ways.dropFirst().reduce(ways[0]) { $0.intersection($1) }
                        onOnePath.formUnion(Set(ways.flatMap { $0 }).subtracting(both))
                        seen = both
                    }
                }
                if step.hasOutput { seen.insert(step.id) }
            }
        }
        var seen: Set<String> = Values.ambient.union(["input"])
        walk(steps, seen: &seen)
        return out
    }
}
