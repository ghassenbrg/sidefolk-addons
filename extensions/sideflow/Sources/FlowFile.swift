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
            let name = plain(item["name"] as? String ?? "")
            guard !name.isEmpty else { throw Problem(L("Every flow in a file needs a name.")) }
            guard names.insert(name.lowercased()).inserted else { throw Problem(L("Two flows in this file are called “{name}”.", ["name": name])) }
            do {
                return Incoming(name: name, body: try FlowCodec.body(item["flow"]))
            } catch let problem as Problem {
                throw Problem(L("“{name}” can't be brought in: {why}", ["name": name, "why": problem.message]))
            }
        }
    }

    /// A name to show: one line, nothing hidden in it, and short enough to be a flow's.
    private static func plain(_ name: String) -> String {
        let hidden: Set<Unicode.GeneralCategory> = [.control, .format, .lineSeparator, .paragraphSeparator, .privateUse, .unassigned, .surrogate]
        let shown = name.unicodeScalars.filter { !hidden.contains($0.properties.generalCategory) }
        return String(String(String.UnicodeScalarView(shown)).trimmed.prefix(60))
    }

    /// What each will be called here: never one that's taken, and what's in the file calls each other by the new names.
    @MainActor static func arriving(_ incoming: [Incoming], store: FlowStore) -> [Incoming] {
        var taken = Set(incoming.map(\.name))
        var renamed: [String: String] = [:]
        for item in incoming where store.nameInUse(item.name) {
            // `plain`: a name is kept and matched, so it holds none of what L() puts round a value for showing.
            var name = plain(L("{name} (imported)", ["name": item.name])), n = 2
            while store.nameInUse(name) || taken.contains(name) {
                name = plain(L("{name} (imported {count})", ["name": item.name, "count": Format.integer(n)]))
                n += 1
            }
            taken.insert(name)
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
        var when: String
        var reads: [String] = []
        var changes: [String] = []
        /// By the tool's name alone: a hint, on top of `changes`.
        var deletes: [String] = []
        var servers: [String] = []
        var files: [String] = []
        var usesAI = 0
        var companionJobs = 0
        var setsOff: [String] = []
        var missingTools: [String] = []
        var missingFlows: [String] = []
    }

    @MainActor static func survey(_ incoming: [Incoming], store: FlowStore, catalog: Catalog) -> [Survey] {
        let here = Set(incoming.map(\.name))
        return incoming.map { item in
            var out = Survey(name: item.name, when: Words.triggers(item.body))
            func add(_ line: String, to list: inout [String]) { if !list.contains(line) { list.append(line) } }
            for step in item.body.allSteps {
                switch step.kind {
                case .action("companion.job", _): out.companionJobs += 1
                case .action(let name, _):
                    guard let tool = catalog.tool(name) else {
                        add(name, to: &out.missingTools)
                        continue
                    }
                    if tool.readsOnly { add(tool.title, to: &out.reads) } else { add(tool.title, to: &out.changes) }
                    if !tool.readsOnly, name.range(of: #"(?i)trash|delete|remove|erase|wipe|clear"#, options: .regularExpression) != nil { add(tool.title, to: &out.deletes) }
                    if tool.fromServer { add(tool.title, to: &out.servers) }
                    if tool.category == "files" { add(tool.title, to: &out.files) }
                case .ai: out.usesAI += 1
                case .call(let name, _), .flow(let name):
                    add(name, to: &out.setsOff)
                    if !here.contains(name), store.named(name) == nil { add(name, to: &out.missingFlows) }
                default: break
                }
            }
            return out
        }
    }
}
