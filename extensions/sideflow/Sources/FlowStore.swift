import Foundation
import SidefolkExtensionKit

/// Flows and runs on disk, each file written whole and atomically. One line of code from anywhere, on the main actor: there is nothing
/// to wait for, and a write can't interleave with itself.
@MainActor final class FlowStore {
    static let keptRuns = 40
    private let folder: URL
    private var flowsById: [String: Flow] = [:]
    private var runsById: [String: Run] = [:]

    init(folder: URL) {
        self.folder = folder
        let fm = FileManager.default
        try? fm.createDirectory(at: runsFolder, withIntermediateDirectories: true)
        if let data = try? Data(contentsOf: flowsFile), let list = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] {
            for raw in list { if let flow = Self.flow(raw) { flowsById[flow.id] = flow } }
        }
        for name in (try? fm.contentsOfDirectory(atPath: runsFolder.path)) ?? [] where name.hasSuffix(".json") {
            guard let data = try? Data(contentsOf: runsFolder.appendingPathComponent(name)),
                  let raw = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any], let run = Self.run(raw) else { continue }
            runsById[run.id] = run
        }
    }

    private var flowsFile: URL { folder.appendingPathComponent("flows.json") }
    private var runsFolder: URL { folder.appendingPathComponent("runs", isDirectory: true) }

    // MARK: Flows

    func flows() -> [Flow] { flowsById.values.sorted { $0.createdAt < $1.createdAt } }
    func flow(_ id: String) -> Flow? { flowsById[id] }

    /// By id, or by name as said: exact first, then the only one that contains the words.
    func find(_ words: String) -> Flow? {
        if let exact = flowsById[words] { return exact }
        let t = words.trimmed
        let all = flows()
        if let same = all.first(where: { $0.name.compare(t, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }) { return same }
        let some = all.filter { $0.name.range(of: t, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
        return some.count == 1 ? some[0] : nil
    }

    func save(_ flow: Flow) {
        var flow = flow
        if flowsById[flow.id] != nil, flowsById[flow.id] != flow { flow.updatedAt = Date() }
        flowsById[flow.id] = flow
        write(flows().map(Self.json), to: flowsFile)
    }

    func remove(flow id: String) {
        flowsById[id] = nil
        write(flows().map(Self.json), to: flowsFile)
        for run in runsById.values where run.flow == id { removeRun(run.id) }
    }

    // MARK: Runs

    func run(_ id: String) -> Run? { runsById[id] }

    func runs(of flow: String? = nil, since: Date? = nil) -> [Run] {
        runsById.values.filter { (flow == nil || $0.flow == flow) && (since == nil || $0.startedAt >= since!) }.sorted { $0.startedAt > $1.startedAt }
    }

    func unfinished() -> [Run] { runsById.values.filter { !$0.status.isOver }.sorted { $0.startedAt < $1.startedAt } }

    func save(_ run: Run) {
        runsById[run.id] = run
        write(Self.json(run), to: runsFolder.appendingPathComponent("\(run.id).json"))
        let mine = runs(of: run.flow)
        for old in mine.dropFirst(Self.keptRuns) where old.status.isOver { removeRun(old.id) }
    }

    private func removeRun(_ id: String) {
        runsById[id] = nil
        try? FileManager.default.removeItem(at: runsFolder.appendingPathComponent("\(id).json"))
    }

    // MARK: On disk

    private func write(_ any: Any, to file: URL) {
        guard JSONSerialization.isValidJSONObject(any), let data = try? JSONSerialization.data(withJSONObject: any, options: [.sortedKeys]) else { return }
        do {
            try data.write(to: file, options: .atomic)
        } catch {
            FileHandle.standardError.write(Data("couldn't save \(file.lastPathComponent): \(error)\n".utf8))
        }
    }

    private static func time(_ date: Date?) -> Any? { date?.timeIntervalSince1970 }
    private static func date(_ any: Any?) -> Date? { (any as? NSNumber).map { Date(timeIntervalSince1970: $0.doubleValue) } }

    static func json(_ flow: Flow) -> [String: Any] {
        let out: [String: Any?] = [
            "id": flow.id, "name": flow.name, "draft": FlowCodec.json(flow.draft), "live": flow.live.map(FlowCodec.json), "state": flow.state.rawValue,
            "created": time(flow.createdAt), "updated": time(flow.updatedAt), "last_fire": time(flow.lastFire), "watch": flow.watchTitle,
            "missed": flow.missed.map(\.timeIntervalSince1970), "start_problem": flow.startProblem, "paused_because": flow.pausedBecause,
            "practiced": flow.practiced.map(FlowCodec.json),
        ]
        return out.compactMapValues { $0 }
    }

    static func flow(_ o: [String: Any]) -> Flow? {
        guard let id = o["id"] as? String, let name = o["name"] as? String, let draft = try? FlowCodec.body(o["draft"]) else { return nil }
        var flow = Flow(id: id, name: name, draft: draft, createdAt: date(o["created"]) ?? Date(), updatedAt: date(o["updated"]) ?? Date())
        flow.live = o["live"].flatMap { try? FlowCodec.body($0) }
        flow.state = Flow.State(rawValue: o["state"] as? String ?? "") ?? .draft
        flow.lastFire = date(o["last_fire"])
        flow.watchTitle = o["watch"] as? String
        flow.missed = (o["missed"] as? [Double] ?? []).map(Date.init(timeIntervalSince1970:))
        flow.startProblem = o["start_problem"] as? String
        flow.pausedBecause = o["paused_because"] as? String
        flow.practiced = o["practiced"].flatMap { try? FlowCodec.body($0) }
        return flow
    }

    static func json(_ run: Run) -> [String: Any] {
        let out: [String: Any?] = [
            "id": run.id, "flow": run.flow, "flow_name": run.flowName, "mode": run.mode.rawValue, "status": run.status.rawValue, "why": run.why,
            "started": time(run.startedAt), "ended": time(run.endedAt), "body": FlowCodec.json(run.body), "pc": run.pc, "values": run.values.named,
            "today": run.values.today, "now": run.values.now, "records": run.records.map(json), "resume_at": time(run.resumeAt), "retries": run.retries, "problem": run.problem,
        ]
        return out.compactMapValues { $0 }
    }

    static func run(_ o: [String: Any]) -> Run? {
        guard let id = o["id"] as? String, let flow = o["flow"] as? String, let body = try? FlowCodec.body(o["body"]),
              let mode = Run.Mode(rawValue: o["mode"] as? String ?? ""), let status = Run.Status(rawValue: o["status"] as? String ?? "") else { return nil }
        var run = Run(id: id, flow: flow, flowName: o["flow_name"] as? String ?? "", mode: mode, status: status, why: o["why"] as? String ?? "",
                      startedAt: date(o["started"]) ?? Date(), body: body)
        run.endedAt = date(o["ended"])
        run.pc = (o["pc"] as? NSNumber)?.intValue ?? 0
        run.values.named = o["values"] as? [String: String] ?? [:]
        run.values.today = o["today"] as? String ?? ""
        run.values.now = o["now"] as? String ?? ""
        run.records = (o["records"] as? [[String: Any]] ?? []).compactMap(Self.record)
        run.resumeAt = date(o["resume_at"])
        run.retries = (o["retries"] as? NSNumber)?.intValue ?? 0
        run.problem = o["problem"] as? String
        return run
    }

    private static func json(_ r: Run.Record) -> [String: Any] {
        let out: [String: Any?] = ["step": r.step, "status": r.status.rawValue, "summary": r.summary, "output": r.output.map { String($0.prefix(4000)) }, "note": r.note, "at": r.at.timeIntervalSince1970]
        return out.compactMapValues { $0 }
    }

    private static func record(_ o: [String: Any]) -> Run.Record? {
        guard let step = o["step"] as? String, let status = Run.Record.Status(rawValue: o["status"] as? String ?? "") else { return nil }
        return Run.Record(step: step, status: status, summary: o["summary"] as? String ?? "", output: o["output"] as? String, note: o["note"] as? String, at: date(o["at"]) ?? Date())
    }
}
