import Foundation
import SidefolkExtensionKit

/// A flow as a file (D200): `name.sideflow`, readable JSON that an agent can write too. What it holds is the definition and what that needs, never an approval, a run or an account.
/// A file comes from anywhere: it's read here, shown in plain words, and only then brought in, always as a draft and off.
enum FlowFile {
    /// 2 once a flow in it has a layout; a file without one stays 1, so an older Sideflow still reads it.
    static let format = 2
    static let type = "sideflow"
    static let longest = 1_000_000
    static let mostFlows = 12
    static let madeBy = "1.0.0"

    struct Incoming: Equatable {
        var name: String
        var body: FlowBody
        /// Where its cards were on the board: checked and bounded, and dropped where it names no step.
        var layout: [String: Layout.Place] = [:]
    }

    // MARK: Writing

    /// These flows as they are on the page, the same as a copy, and the flows they call as last saved. The samples go: a practice's made-up values can be the person's own words. What's typed into a step stays, and the page says so.
    @MainActor static func write(_ flows: [Flow], store: FlowStore, catalog: Catalog, sideflow: String) -> String {
        var all = flows.map { (name: $0.name, body: $0.draft, layout: Layout.kept($0.layout, for: $0.draft)) }, seen = Set(flows.map(\.id)), next = flows.map(\.draft)
        while let body = next.popLast() {
            for name in calls(body) {
                guard let called = store.named(name), seen.insert(called.id).inserted else { continue }
                all.append((called.name, called.kept, [:]))
                next.append(called.kept)
            }
        }
        let tools = Set(all.flatMap { flow in flow.body.allSteps.compactMap { step -> String? in
            if case .action(let tool, _) = step.kind { tool } else { nil }
        } }).sorted()
        let places = Set(all.flatMap(\.body.triggers).compactMap { trigger -> String? in
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
        // Readable, as a file you might open and keep: the order of its keys stays put from one export to the next.
        let placed = all.contains { !$0.layout.isEmpty }
        let whole: [String: Any] = ["sideflow": placed ? format : 1, "needs": needs, "flows": all.map { flow in
            var one: [String: Any] = ["name": flow.name, "flow": withoutSamples(FlowCodec.json(flow.body))]
            if !flow.layout.isEmpty { one["layout"] = Layout.json(flow.layout) }
            return one
        }]
        let data = (try? JSONSerialization.data(withJSONObject: whole, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])) ?? Data()
        return String(decoding: data, as: UTF8.self) + "\n"
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

    /// What it wrote, as a file for Sidefolk to take, checked as anything coming back would be: what can't come back in shouldn't look saved. Its name, from the data folder.
    static func handOver(_ words: String, in folder: URL) throws -> String {
        guard words.utf8.count <= longest else { throw Problem(L("That's too big to be one file. Export fewer flows at a time.")) }
        let count = try read(words).count
        guard count <= mostFlows else { throw Problem(L("A file holds at most {count} flows.", ["count": Format.integer(mostFlows)])) }
        let name = "\(exportsFolder)/\(UUID().uuidString.lowercased()).\(type)"
        let exports = folder.appendingPathComponent(exportsFolder, isDirectory: true)
        try FileManager.default.createDirectory(at: exports, withIntermediateDirectories: true)
        // Sidefolk has copied them by now, or the person said no: they hold words of the person's, so they don't stay.
        for old in (try? FileManager.default.contentsOfDirectory(at: exports, includingPropertiesForKeys: [.contentModificationDateKey])) ?? [] {
            let at = (try? old.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            if Date().timeIntervalSince(at) > 3600 { try? FileManager.default.removeItem(at: old) }
        }
        try Data(words.utf8).write(to: folder.appendingPathComponent(name), options: .atomic)
        return name
    }

    private static let exportsFolder = "exports"

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
            guard Set(top.keys).isSubset(of: ["name", "flow", "layout"]), top["flow"] != nil else { throw Problem(L("That isn't a Sideflow file or a flow's definition.")) }
            raw = [top]
        }
        var names = Set<String>()
        return try raw.map { item in
            guard Set(item.keys).isSubset(of: ["name", "flow", "layout"]) else { throw Problem(L("That isn't a Sideflow file or a flow's definition.")) }
            // A definition on its own can leave its name out. In a file, a call may be naming it.
            let written = (item["name"] as? String)?.trimmed ?? ""
            if written.isEmpty, top["sideflow"] != nil { throw Problem(L("Every flow in a file needs a name.")) }
            let name = written.isEmpty ? stripped(L("New flow")) : written
            // Never cut or cleaned to fit: a step calling it would then go by another name.
            // In what's stored, not what's seen: a letter can carry thousands of marks.
            guard name == stripped(name), !name.unicodeScalars.contains(where: { $0.properties.isWhitespace && $0 != " " }), name.count <= 60, name.utf8.count <= 240 else {
                throw Problem(L("“{name}” isn't a plain name for a flow: it's too long, or has hidden characters in it.", ["name": short(name, 60)]))
            }
            guard names.insert(folded(name)).inserted else { throw Problem(L("Two flows in this file are called “{name}”.", ["name": name])) }
            do {
                // A practice's made-up answers aren't for someone else's practice to go by.
                let body = try FlowCodec.body((item["flow"] as? [String: Any]).map(withoutSamples) ?? item["flow"])
                return Incoming(name: name, body: body, layout: Layout.kept(Layout.read(item["layout"]), for: body))
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

    /// To show: nothing hidden, at most so many characters as they're stored, and an ending that says when there was more.
    static func short(_ words: String, _ most: Int) -> String {
        let plain = stripped(words).unicodeScalars
        return plain.count <= most ? String(String.UnicodeScalarView(plain)) : String(String.UnicodeScalarView(plain.prefix(most))) + "…"
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
            return Incoming(name: renamed[item.name] ?? item.name, body: body, layout: item.layout)
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
            var out = Survey(name: item.name, starts: item.body.triggers.map { short(Words.trigger($0), 240) })
            func add(_ line: String, to list: inout [String], most: Int = 120) {
                let line = short(line, most)
                if !list.contains(line) { list.append(line) }
            }
            for trigger in item.body.triggers {
                if case .watch(let watch) = trigger { add(watch.target, to: &out.watches, most: 240) }
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
                    // Where it goes or what it touches, if that's written in: "Read a file" says little, the file says more.
                    let places = input.keys.sorted().filter { $0.range(of: #"(?i)url|path|address|recipient|^to$|channel|host|repo|file|folder|email|target"#, options: .regularExpression) != nil }.flatMap { input[$0]?.strings ?? [] }.map { short($0, 80) }
                    let line = places.isEmpty ? tool.title : "\(tool.title) (\(places.prefix(2).joined(separator: ", "))\(places.count > 2 ? ", …" : ""))"
                    if !tool.readsOnly { add(line, to: &out.changes) } else if filled { add(line, to: &out.readsFilled) } else { add(line, to: &out.reads) }
                    if !tool.readsOnly, name.range(of: #"(?i)trash|delete|remove|erase|wipe|clear"#, options: .regularExpression) != nil { add(tool.title, to: &out.deletes) }
                    if tool.fromServer { add(tool.title, to: &out.servers) }
                    if tool.category == "files" { add(tool.title, to: &out.files) }
                case .ai: out.usesAI += 1
                case .call(let name, _), .flow(let name):
                    if here.contains(folded(name.trimmed)) { add(name, to: &out.setsOff) }
                    else if store.named(name) != nil { add(name, to: &out.setsOffYours) }
                    else { add(name, to: &out.missingFlows) }
                default: break
                }
            }
            return out
        }
    }
}
