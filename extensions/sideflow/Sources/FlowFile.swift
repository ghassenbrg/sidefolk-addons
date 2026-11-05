import Foundation
import SidefolkExtensionKit

/// A flow as a file (D200): `name.sideflow`, readable JSON that an agent can write too. What it holds is the definition and what that needs, never an approval, a run or an account.
/// A file comes from anywhere: it's read here, shown in plain words, and only then brought in, always as a draft and off.
enum FlowFile {
    static let format = 1
    static let type = "sideflow"
    static let longest = 1_000_000
    static let mostFlows = 12

    struct Incoming: Equatable {
        var name: String
        var body: FlowBody
    }

    // MARK: Writing

    /// These flows and the flows they call, as what was last saved. The samples go: a practice's made-up values can be the person's own words. What's typed into a step stays, and the page says so.
    @MainActor static func write(_ flows: [Flow], store: FlowStore, catalog: Catalog, sideflow: String) -> String {
        var all = flows, seen = Set(flows.map(\.id)), next = flows
        while let flow = next.popLast() {
            for name in calls(flow.kept) {
                guard let called = store.named(name), seen.insert(called.id).inserted else { continue }
                all.append(called)
                next.append(called)
            }
        }
        let tools = Set(all.flatMap { flow in flow.kept.allSteps.compactMap { step -> String? in
            if case .action(let tool, _) = step.kind { tool } else { nil }
        } }).sorted()
        let places = Set(all.flatMap(\.kept.triggers).compactMap { trigger -> String? in
            if case .watch(let watch) = trigger, watch.target.hasPrefix("/") || watch.target.hasPrefix("~") { watch.target } else { nil }
        }).sorted()
        let needs: [String: Any] = ["sideflow": sideflow, "folders": places, "tools": tools.map { name -> [String: Any] in
            var line: [String: Any] = ["name": name]
            if let tool = catalog.tool(name) {
                line["title"] = tool.title
                if let from = tool.fromTitle { line["from"] = from }
            }
            return line
        }]
        return JSONText.write(["sideflow": format, "needs": needs, "flows": all.map { flow in
            ["name": flow.name, "flow": withoutSamples(FlowCodec.json(flow.kept))] as [String: Any]
        }] as [String: Any])
    }

    /// The flows these steps name, directly.
    static func calls(_ body: FlowBody) -> [String] {
        body.allSteps.compactMap { step in
            switch step.kind {
            case .call(let name, _), .flow(let name): name
            default: nil
            }
        }
    }

    private static func withoutSamples(_ body: [String: Any]) -> [String: Any] {
        func clean(_ list: Any?) -> Any? {
            guard let list = list as? [[String: Any]] else { return list }
            return list.map { item in
                var item = item
                item["sample"] = nil
                for key in ["steps", "then", "else", "repeat", "try", "recover", "always", "parallel", "paths"] where item[key] != nil {
                    item[key] = clean(item[key])
                }
                return item
            }
        }
        var out = body
        out["trigger_sample"] = nil
        out["steps"] = clean(body["steps"])
        return out
    }

    // MARK: Reading

    /// What a file holds, or why it can't be brought in. Anything it doesn't know is refused, not guessed at. A definition copied from a flow reads the same way.
    static func read(_ text: String) throws -> [Incoming] {
        guard text.utf8.count <= longest else { throw Problem(L("That file is too big to be flows.")) }
        guard let top = JSONText.read(text) as? [String: Any] else { throw Problem(L("That isn't a Sideflow file or a flow's definition.")) }
        let raw: [[String: Any]]
        if let format = top["sideflow"] {
            guard let format = format as? Int, format >= 1 else { throw Problem(L("That isn't a Sideflow file or a flow's definition.")) }
            guard format <= Self.format else { throw Problem(L("This file was made by a newer Sideflow. Update Sideflow, then try it again.")) }
            guard Set(top.keys).isSubset(of: ["sideflow", "needs", "flows"]), let flows = top["flows"] as? [[String: Any]], !flows.isEmpty else { throw Problem(L("That isn't a Sideflow file or a flow's definition.")) }
            guard flows.count <= mostFlows else { throw Problem(L("A file holds at most {count} flows.", ["count": Format.integer(mostFlows)])) }
            raw = flows
        } else {
            guard Set(top.keys).isSubset(of: ["name", "flow"]), top["flow"] != nil else { throw Problem(L("That isn't a Sideflow file or a flow's definition.")) }
            raw = [top]
        }
        var names = Set<String>()
        return try raw.map { item in
            guard Set(item.keys).isSubset(of: ["name", "flow"]) else { throw Problem(L("That isn't a Sideflow file or a flow's definition.")) }
            // A definition on its own can leave its name out. In a file, a call may be naming it.
            let written = (item["name"] as? String)?.trimmed ?? ""
            if written.isEmpty, top["sideflow"] != nil { throw Problem(L("Every flow in a file needs a name.")) }
            let name = written.isEmpty ? stripped(L("New flow")) : written
            // Never cut or cleaned to fit: a step calling it would then go by another name.
            guard name == stripped(name), !name.unicodeScalars.contains(where: { $0.properties.isWhitespace && $0 != " " }), name.count <= 60 else {
                throw Problem(L("“{name}” isn't a plain name for a flow: it's too long, or has hidden characters in it.", ["name": String(stripped(name).prefix(60))]))
            }
            guard names.insert(folded(name)).inserted else { throw Problem(L("Two flows in this file are called “{name}”.", ["name": name])) }
            do {
                // A practice's made-up answers aren't for someone else's practice to go by.
                return Incoming(name: name, body: try FlowCodec.body((item["flow"] as? [String: Any]).map(withoutSamples) ?? item["flow"]))
            } catch let problem as Problem {
                throw Problem(L("“{name}” can't be brought in: {why}", ["name": name, "why": problem.message]))
            }
        }
    }

    /// Without anything hidden: what L() puts round a value for showing, and what a file could put in a name.
    private static func stripped(_ name: String) -> String {
        let hidden: Set<Unicode.GeneralCategory> = [.control, .format, .lineSeparator, .paragraphSeparator, .privateUse, .unassigned, .surrogate]
        return String(String.UnicodeScalarView(name.unicodeScalars.filter { !hidden.contains($0.properties.generalCategory) })).trimmed
    }

    /// Two names are the same to a step if they differ only by case or accents, as `FlowStore.named` reads them.
    private static func folded(_ name: String) -> String { name.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil) }

    /// What each will be called here: never one that's taken, and what's in the file calls each other by the new names.
    @MainActor static func arriving(_ incoming: [Incoming], store: FlowStore) -> [Incoming] {
        var taken = Set(incoming.map { folded($0.name) })
        var renamed: [String: String] = [:]
        for item in incoming where store.nameInUse(item.name) {
            // Short enough that what tells them apart fits in a name.
            let stem = String(item.name.prefix(40)).trimmed
            var name = stripped(L("{name} (imported)", ["name": stem])), n = 2
            while store.nameInUse(name) || taken.contains(folded(name)) {
                name = n < 1000 ? stripped(L("{name} (imported {count})", ["name": stem, "count": String(n)])) : stem + " " + UUID().uuidString.prefix(8)
                n += 1
            }
            taken.insert(folded(name))
            renamed[item.name] = name
        }
        return incoming.map { item in
            var body = item.body
            for (old, new) in renamed { body = body.calling(old, instead: new) }
            return Incoming(name: renamed[item.name] ?? item.name, body: body)
        }
    }

    // MARK: Waiting to be brought in

    /// A file read and checked, kept until someone says yes on the page. A call that reads a file runs in a process of its own, and this is how it hands over.
    static func stage(_ text: String, in folder: URL) throws -> String {
        _ = try read(text)
        let id = UUID().uuidString.lowercased()
        let waiting = folder.appendingPathComponent(waitingFolder, isDirectory: true)
        try FileManager.default.createDirectory(at: waiting, withIntermediateDirectories: true)
        for old in (try? FileManager.default.contentsOfDirectory(at: waiting, includingPropertiesForKeys: [.contentModificationDateKey])) ?? [] {
            let at = (try? old.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            if Date().timeIntervalSince(at) > 86400 { try? FileManager.default.removeItem(at: old) }
        }
        try Data(text.utf8).write(to: waiting.appendingPathComponent(id), options: .atomic)
        return id
    }

    static func staged(_ id: String, in folder: URL) -> String? {
        guard UUID(uuidString: id) != nil else { return nil }
        return (try? Data(contentsOf: folder.appendingPathComponent(waitingFolder, isDirectory: true).appendingPathComponent(id))).map { String(decoding: $0, as: UTF8.self) }
    }

    static func unstage(_ id: String, in folder: URL) {
        guard UUID(uuidString: id) != nil else { return }
        try? FileManager.default.removeItem(at: folder.appendingPathComponent(waitingFolder, isDirectory: true).appendingPathComponent(id))
    }

    private static let waitingFolder = "imports"

    // MARK: What it would do

    /// What a flow from a file would do and need, for someone deciding whether to bring it in. It's what Sideflow can tell, and it can't tell everything: for anything not marked as only reading, the cautious words.
    struct Survey: Equatable {
        var name: String
        var starts: [String] = []
        var watches: [String] = []
        var reads: [String] = []
        /// Only reads, with a value from an earlier step in what it's given: a read can carry that value out.
        var readsFilled: [String] = []
        var changes: [String] = []
        /// By the tool's name alone: a hint, on top of `changes`.
        var deletes: [String] = []
        var servers: [String] = []
        var files: [String] = []
        var usesAI = 0
        var companionJobs = 0
        var setsOff: [String] = []
        var setsOffYours: [String] = []
        var missingTools: [String] = []
        var missingFlows: [String] = []
    }

    @MainActor static func survey(_ incoming: [Incoming], store: FlowStore, catalog: Catalog) -> [Survey] {
        let here = Set(incoming.map { folded($0.name) })
        return incoming.map { item in
            var out = Survey(name: item.name, starts: item.body.triggers.map { String(stripped(Words.trigger($0)).prefix(200)) })
            func add(_ line: String, to list: inout [String]) {
                let line = String(stripped(line).prefix(60))
                if !list.contains(line) { list.append(line) }
            }
            for trigger in item.body.triggers {
                if case .watch(let watch) = trigger { add(watch.target, to: &out.watches) }
            }
            for step in item.body.allSteps {
                switch step.kind {
                case .action("companion.job", _): out.companionJobs += 1
                case .action(let name, let input):
                    guard let tool = catalog.tool(name) else {
                        add(name, to: &out.missingTools)
                        continue
                    }
                    let filled = input.values.flatMap(\.strings).contains { !Values.references($0).isEmpty }
                    if !tool.readsOnly { add(tool.title, to: &out.changes) } else if filled { add(tool.title, to: &out.readsFilled) } else { add(tool.title, to: &out.reads) }
                    if !tool.readsOnly, name.range(of: #"(?i)trash|delete|remove|erase|wipe|clear"#, options: .regularExpression) != nil { add(tool.title, to: &out.deletes) }
                    if tool.fromServer { add(tool.title, to: &out.servers) }
                    if tool.category == "files" { add(tool.title, to: &out.files) }
                case .ai: out.usesAI += 1
                case .call(let name, _), .flow(let name):
                    if here.contains(folded(name)) { add(name, to: &out.setsOff) }
                    else if store.named(name) != nil { add(name, to: &out.setsOffYours) }
                    else { add(name, to: &out.missingFlows) }
                default: break
                }
            }
            return out
        }
    }
}
