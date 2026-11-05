import Foundation
import SidefolkExtensionKit

/// Flows and runs on disk, each file written whole and atomically. One line of code from anywhere, on the main actor: there is nothing
/// to wait for, and a write can't interleave with itself.
@MainActor final class FlowStore {
    /// Runs kept per flow, as the setting says: a person diagnosing a batch may want more than the last few.
    static var keptRuns: Int { Int(ExtensionSettings.string("keep_runs") ?? "") ?? 40 }
    private let folder: URL
    private var flowsById: [String: Flow] = [:]
    private var runsById: [String: Run] = [:]
    /// Flows this version can't read: written back as they were, so a mistake here never loses one.
    private var unreadable: [Any] = []
    /// A flows file that couldn't be read at all was put aside, here.
    private(set) var damagedFile: URL?
    /// The last time flows were written, it didn't work: what's on the page isn't on disk.
    private(set) var flowsNotSaved = false
    /// Stops asked for and not done yet, on disk: a step under way finishes first, and Sidefolk may quit before it does.
    private var stopsAsked: Set<String> = []
    private var seenEvents: [String] = []
    private static let keptEvents = 300
    /// Runs removed this time: one mid-step can't save itself back after.
    private var goneRuns: Set<String> = []
    /// The flows file is there and can't be read or moved aside: nothing writes over it.
    private var flowsFileHeld = false
    /// A flows file was put aside, this time or an earlier one: runs of flows it held may yet have them back.
    private var hasFileAside = false

    var unreadableCount: Int { unreadable.count }

    var flowsFileIsHeld: Bool { flowsFileHeld }

    /// Runs waiting for a flow that can't be read now.
    var heldBackRuns: [Run] { unfinished().filter { isHeldBack(flow: $0.flow) } }

    /// A flow that's there and can't be read now, as opposed to one that's gone. Only ever one the store hasn't got: what it has, it can run.
    func isHeldBack(flow id: String) -> Bool {
        if unreadable.contains(where: { ($0 as? [String: Any])?["id"] as? String == id }) { return true }
        return flowsById[id] == nil && (flowsFileHeld || hasFileAside)
    }

    /// Whatever a flow was called in the steps that name it, in what's kept and what's running: it's the same flow.
    func rewriteCalls(from old: String, to name: String, except id: String) {
        for var other in flows() where other.id != id {
            let was = other
            other.draft = other.draft.calling(old, instead: name)
            other.saved = other.saved?.calling(old, instead: name)
            other.live = other.live?.calling(old, instead: name)
            other.practiced = other.practiced?.calling(old, instead: name)
            other.revisions = other.revisions.map { var r = $0; r.body = $0.body.calling(old, instead: name); return r }
            if other != was { save(other) }
        }
        for var run in runsById.values where run.flow != id {
            let body = run.body.calling(old, instead: name)
            if body != run.body {
                run.body = body
                runsById[run.id] = run
                save(run)
            }
        }
    }
    /// How many writes didn't reach the disk, so a test can't pass over one.
    private(set) var failedSaves = 0
    /// What each connection was called, and which are servers: all that's left to say about one that's gone.
    private(set) var connectionNames: [String: String] = [:]
    private(set) var connectionServers: Set<String> = []
    private(set) var connectionTools: [String: String] = [:]

    init(folder: URL) {
        self.folder = folder
        let fm = FileManager.default
        try? fm.createDirectory(at: runsFolder, withIntermediateDirectories: true)
        // Read once: a file that's there and won't open is held, and one read that worked is the one used.
        let flowsData = try? Data(contentsOf: flowsFile)
        if fm.fileExists(atPath: flowsFile.path), flowsData == nil {
            flowsFileHeld = true
            flowsNotSaved = true
        }
        if let data = try? Data(contentsOf: connectionsFile), let saved = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
            connectionNames = saved["names"] as? [String: String] ?? [:]
            connectionServers = Set(saved["servers"] as? [String] ?? [])
            connectionTools = saved["tools"] as? [String: String] ?? [:]
        }
        if let data = flowsData {
            if let list = (try? JSONSerialization.jsonObject(with: data)) as? [Any] {
                for raw in list {
                    if let raw = raw as? [String: Any], let flow = Self.flow(raw) { flowsById[flow.id] = flow } else { unreadable.append(raw) }
                }
            } else {
                // Not a list at all: the next save would write over whatever this is, so it goes aside first, under a name of its own.
                let aside = folder.appendingPathComponent("flows-damaged-\(Int(Date().timeIntervalSince1970)).json")
                if (try? fm.moveItem(at: flowsFile, to: aside)) != nil {
                    damagedFile = aside
                    hasFileAside = true
                } else {
                    flowsFileHeld = true
                    flowsNotSaved = true
                }
            }
        }
        for name in (try? fm.contentsOfDirectory(atPath: runsFolder.path)) ?? [] where name.hasSuffix(".json") {
            guard let data = try? Data(contentsOf: runsFolder.appendingPathComponent(name)),
                  let raw = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any], let run = Self.run(raw) else { continue }
            runsById[run.id] = run
        }
        if ((try? fm.contentsOfDirectory(atPath: folder.path)) ?? []).contains(where: { $0.hasPrefix("flows-damaged-") }) { hasFileAside = true }
        if let data = try? Data(contentsOf: eventsFile), let list = (try? JSONSerialization.jsonObject(with: data)) as? [String] { seenEvents = list }
        if let data = try? Data(contentsOf: stopsFile), let list = (try? JSONSerialization.jsonObject(with: data)) as? [String] {
            stopsAsked = Set(list.filter { $0.hasPrefix(Self.startsStopped) || runsById[$0.replacingOccurrences(of: "pause:", with: "").replacingOccurrences(of: "person:", with: "")]?.status.isOver == false })
        }
        settleStartsStopped()
    }

    /// Stop was pressed on a flow that couldn't be read, so its waiting starts couldn't be cleared then. They're cleared the first time it can be, before anything could start them.
    private func settleStartsStopped() {
        var flowsChanged = false, stopsChanged = false
        for key in stopsAsked where key.hasPrefix(Self.startsStopped) {
            let id = String(key.dropFirst(Self.startsStopped.count))
            if var flow = flowsById[id] {
                flowsChanged = flowsChanged || !flow.waitingStarts.isEmpty
                flow.waitingStarts = []
                flowsById[id] = flow
            } else if isHeldBack(flow: id) {
                continue
            }
            stopsAsked.remove(key)
            stopsChanged = true
        }
        if flowsChanged { flowsNotSaved = !write(flows().map(Self.json) + unreadable, to: flowsFile) }
        if stopsChanged { write(stopsAsked.sorted(), to: stopsFile) }
    }

    func askToStopStarts(of flow: String) { askStop(Self.startsStopped + flow) }

    private static let startsStopped = "starts:"

    private var flowsFile: URL { folder.appendingPathComponent("flows.json") }
    private var eventsFile: URL { folder.appendingPathComponent("events.json") }
    private var stopsFile: URL { folder.appendingPathComponent("stops.json") }
    private var connectionsFile: URL { folder.appendingPathComponent("connections.json") }
    private var runsFolder: URL { folder.appendingPathComponent("runs", isDirectory: true) }

    func keepConnections(names: [String: String], servers: Set<String>, tools: [String: String]) {
        guard names != connectionNames || servers != connectionServers || tools != connectionTools else { return }
        (connectionNames, connectionServers, connectionTools) = (names, servers, tools)
        write(["names": names, "servers": servers.sorted(), "tools": tools], to: connectionsFile)
    }

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
        flowsNotSaved = flowsFileHeld || !write(flows().map(Self.json) + unreadable, to: flowsFile)
    }

    func remove(flow id: String) {
        flowsById[id] = nil
        flowsNotSaved = flowsFileHeld || !write(flows().map(Self.json) + unreadable, to: flowsFile)
        for run in runsById.values where run.flow == id { removeRun(run.id) }
    }

    // MARK: Runs

    func run(_ id: String) -> Run? { runsById[id] }

    func runs(of flow: String? = nil, since: Date? = nil) -> [Run] {
        runsById.values.filter { (flow == nil || $0.flow == flow) && (since == nil || $0.startedAt >= since!) }.sorted { $0.startedAt > $1.startedAt }
    }

    /// The last run someone would call this flow's: a parallel's lanes are parts of one.
    func latest(of flow: String) -> Run? { runs(of: flow).first { run in run.parent.flatMap { self.run($0)?.flow } != flow } }

    func unfinished() -> [Run] { runsById.values.filter { !$0.status.isOver }.sorted { $0.startedAt < $1.startedAt } }

    /// Whether it reached the disk: the engine won't act on a run it couldn't write down. What's in memory is current either way, for the page to show.
    @discardableResult func save(_ run: Run) -> Bool {
        guard !goneRuns.contains(run.id) else { return true }
        // What it runs is set when it starts, and only a rename changes it, here: a walk mid-step holds an older copy and mustn't put that back.
        var run = run
        if let kept = runsById[run.id] { run.body = kept.body }
        runsById[run.id] = run
        let saved = write(Self.json(run), to: runsFolder.appendingPathComponent("\(run.id).json"))
        // Counted as the person counts them: a flow's own runs. What one waited for goes with it, and never before it.
        let mine = runs(of: run.flow).filter { $0.parent == nil }
        for old in mine.dropFirst(Self.keptRuns) where old.status.isOver { removeRun(old.id) }
        return saved
    }

    /// Events already acted on, on disk, the last few hundred.
    func firstTimeSeeing(event id: String) -> Bool {
        guard !seenEvents.contains(id) else { return false }
        seenEvents.append(id)
        if seenEvents.count > Self.keptEvents { seenEvents.removeFirst(seenEvents.count - Self.keptEvents) }
        write(seenEvents, to: eventsFile)
        return true
    }

    func askStop(_ id: String) {
        guard stopsAsked.insert(id).inserted else { return }
        write(stopsAsked.sorted(), to: stopsFile)
    }

    /// Whether a stop was asked for, which this settles.
    func takeStop(_ id: String) -> Bool {
        guard stopsAsked.remove(id) != nil else { return false }
        write(stopsAsked.sorted(), to: stopsFile)
        return true
    }

    /// By its exact name and only if it's the only one. What a step names sets off that flow, never whichever happens to contain the words.
    func named(_ name: String) -> Flow? {
        let same = flows().filter { $0.name.compare(name.trimmed, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }
        return same.count == 1 ? same[0] : nil
    }

    /// Whether another flow goes by this name, as a step would read it.
    func nameInUse(_ name: String, except id: String? = nil) -> Bool {
        flows().contains { $0.id != id && $0.name.compare(name.trimmed, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame }
    }

    private func removeRun(_ id: String) {
        for child in runsById.values where child.parent == id { removeRun(child.id) }
        runsById[id] = nil
        goneRuns.insert(id)
        try? FileManager.default.removeItem(at: runsFolder.appendingPathComponent("\(id).json"))
    }

    // MARK: On disk

    @discardableResult private func write(_ any: Any, to file: URL) -> Bool {
        guard JSONSerialization.isValidJSONObject(any), let data = try? JSONSerialization.data(withJSONObject: any, options: [.sortedKeys]) else {
            failedSaves += 1
            return false
        }
        do {
            try data.write(to: file, options: .atomic)
            return true
        } catch {
            failedSaves += 1
            FileHandle.standardError.write(Data("couldn't save \(file.lastPathComponent): \(error)\n".utf8))
            return false
        }
    }

    private static func time(_ date: Date?) -> Any? { date?.timeIntervalSince1970 }
    private static func date(_ any: Any?) -> Date? { (any as? NSNumber).map { Date(timeIntervalSince1970: $0.doubleValue) } }

    static func json(_ flow: Flow) -> [String: Any] {
        let out: [String: Any?] = [
            "id": flow.id, "name": flow.name, "draft": FlowCodec.json(flow.draft), "saved": flow.saved.map(FlowCodec.json), "live": flow.live.map(FlowCodec.json), "state": flow.state.rawValue,
            "created": time(flow.createdAt), "updated": time(flow.updatedAt), "watch_outdated": flow.watchOutdated ? true : nil, "last_fire": time(flow.lastFire), "last_every": flow.lastEvery.isEmpty ? nil : Dictionary(uniqueKeysWithValues: flow.lastEvery.map { (String($0.key), $0.value.timeIntervalSince1970) }), "watch": flow.watchTitle,
            "missed": flow.missed.map(\.timeIntervalSince1970), "start_problem": flow.startProblem, "paused_because": flow.pausedBecause,
            "practiced": flow.practiced.map(FlowCodec.json), "waiting_starts": flow.waitingStarts.isEmpty ? nil : flow.waitingStarts,
            "revisions": flow.revisions.isEmpty ? nil : flow.revisions.map { ["at": $0.at.timeIntervalSince1970, "body": FlowCodec.json($0.body), "version": $0.version] as [String: Any] }, "version": flow.version == 1 ? nil : flow.version,
        ]
        return out.compactMapValues { $0 }
    }

    static func flow(_ o: [String: Any]) -> Flow? {
        guard let id = o["id"] as? String, let name = o["name"] as? String, let draft = try? FlowCodec.body(o["draft"], saved: true) else { return nil }
        var flow = Flow(id: id, name: name, draft: draft, createdAt: date(o["created"]) ?? Date(), updatedAt: date(o["updated"]) ?? Date())
        // What's live can't be read: kept as it was, rather than an On flow running its draft.
        if let raw = o["live"] {
            guard let live = try? FlowCodec.body(raw, saved: true) else { return nil }
            flow.live = live
        }
        // A saved version that can't be read keeps the flow aside too, rather than the unsaved draft being what turning on uses.
        if let raw = o["saved"] {
            guard let saved = try? FlowCodec.body(raw, saved: true) else { return nil }
            flow.saved = saved
        }
        flow.state = Flow.State(rawValue: o["state"] as? String ?? "") ?? .draft
        flow.lastFire = date(o["last_fire"])
        for (minutes, at) in o["last_every"] as? [String: Any] ?? [:] {
            if let minutes = Int(minutes), let at = date(at) { flow.lastEvery[minutes] = at }
        }
        flow.watchTitle = o["watch"] as? String
        flow.watchOutdated = o["watch_outdated"] as? Bool ?? false
        flow.missed = (o["missed"] as? [Double] ?? []).map(Date.init(timeIntervalSince1970:))
        flow.startProblem = o["start_problem"] as? String
        flow.pausedBecause = o["paused_because"] as? String
        flow.practiced = o["practiced"].flatMap { try? FlowCodec.body($0, saved: true) }
        flow.waitingStarts = o["waiting_starts"] as? [String] ?? []
        flow.revisions = (o["revisions"] as? [[String: Any]] ?? []).compactMap { r in
            guard let at = date(r["at"]), let body = try? FlowCodec.body(r["body"], saved: true) else { return nil }
            return Flow.Revision(at: at, body: body, version: r["version"] as? Int ?? 0)
        }
        // From before versions had numbers: in the order they went.
        flow.version = o["version"] as? Int ?? flow.revisions.count + 1
        for at in flow.revisions.indices where flow.revisions[at].version == 0 { flow.revisions[at].version = at + 1 }
        return flow
    }

    static func json(_ run: Run) -> [String: Any] {
        let out: [String: Any?] = [
            "id": run.id, "flow": run.flow, "flow_name": run.flowName, "mode": run.mode.rawValue, "status": run.status.rawValue, "why": run.why,
            "started": time(run.startedAt), "ended": time(run.endedAt), "body": FlowCodec.json(run.body), "pc": run.pc, "values": run.values.named.mapValues(\.any), "said": run.values.said.isEmpty ? nil : run.values.said,
            "today": run.values.today, "now": run.values.now, "records": run.records.map(json), "resume_at": time(run.resumeAt), "retries": run.retries, "tried_again": run.triedAgain == 0 ? nil : run.triedAgain, "problem": run.problem, "frames": run.frames.isEmpty ? nil : run.frames.map(json), "parent": run.parent, "lineage": run.lineage.isEmpty ? nil : run.lineage,
            "waiting_on": run.waitingOn.isEmpty ? nil : run.waitingOn, "output": run.output?.any, "set_off": run.setOff ? true : nil, "paused": run.paused ? true : nil, "set_off_runs": run.setOffRuns.isEmpty ? nil : run.setOffRuns, "start_item": run.startItem?.any, "start_index": run.startIndex?.any, "form": run.form.map { ["step": $0.step, "answers": $0.answers.mapValues(\.any)] as [String: Any] },
            "connection": run.connection.map { ["tool": $0.tool, "until": $0.until.timeIntervalSince1970] as [String: Any] }, "deadline": time(run.deadline),
        ]
        return out.compactMapValues { $0 }
    }

    static func run(_ o: [String: Any]) -> Run? {
        guard let id = o["id"] as? String, let flow = o["flow"] as? String, let body = try? FlowCodec.body(o["body"], saved: true),
              let mode = Run.Mode(rawValue: o["mode"] as? String ?? ""), let status = Run.Status(rawValue: o["status"] as? String ?? "") else { return nil }
        var run = Run(id: id, flow: flow, flowName: o["flow_name"] as? String ?? "", mode: mode, status: status, why: o["why"] as? String ?? "",
                      startedAt: date(o["started"]) ?? Date(), body: body)
        run.endedAt = date(o["ended"])
        run.pc = (o["pc"] as? NSNumber)?.intValue ?? 0
        run.values.named = (o["values"] as? [String: Any] ?? [:]).mapValues { JSON($0) }
        run.values.said = o["said"] as? [String: String] ?? [:]
        run.values.today = o["today"] as? String ?? ""
        run.values.now = o["now"] as? String ?? ""
        run.records = (o["records"] as? [[String: Any]] ?? []).compactMap(Self.record)
        run.resumeAt = date(o["resume_at"])
        run.retries = (o["retries"] as? NSNumber)?.intValue ?? 0
        run.triedAgain = (o["tried_again"] as? NSNumber)?.intValue ?? 0
        run.problem = o["problem"] as? String
        run.frames = (o["frames"] as? [[String: Any]] ?? []).compactMap(Self.frame)
        run.parent = o["parent"] as? String
        run.lineage = o["lineage"] as? [String] ?? []
        run.waitingOn = o["waiting_on"] as? [String] ?? []
        run.output = o["output"].map { JSON($0) }
        run.setOff = o["set_off"] as? Bool ?? false
        run.paused = o["paused"] as? Bool ?? false
        run.setOffRuns = o["set_off_runs"] as? [String] ?? []
        run.deadline = date(o["deadline"])
        run.startItem = o["start_item"].map { JSON($0) }
        run.startIndex = o["start_index"].map { JSON($0) }
        if let form = o["form"] as? [String: Any], let step = form["step"] as? String {
            run.form = Run.WaitingForm(step: step, answers: (form["answers"] as? [String: Any] ?? [:]).mapValues { JSON($0) })
        }
        if let waited = o["connection"] as? [String: Any], let tool = waited["tool"] as? String, let until = date(waited["until"]) {
            run.connection = Run.WaitingConnection(tool: tool, until: until)
        }
        return run
    }

    private static func json(_ f: Run.Frame) -> [String: Any] {
        let out: [String: Any?] = ["kind": f.kind.rawValue, "step": f.step, "items": f.items.map(\.any), "index": f.index, "results": f.results.map(\.any), "failed_items": f.failedItems, "wrote": f.wrote ? true : nil,
                                   "collect": f.collect, "top": f.top, "end": f.end, "recover": f.recover, "always": f.always, "in_recover": f.inRecover, "in_always": f.inAlways,
                                   "failing": f.failing, "returning": f.returning]
        return out.compactMapValues { $0 }
    }

    private static func frame(_ o: [String: Any]) -> Run.Frame? {
        guard let kind = Run.Frame.Kind(rawValue: o["kind"] as? String ?? ""), let step = o["step"] as? String else { return nil }
        func n(_ key: String) -> Int { (o[key] as? NSNumber)?.intValue ?? 0 }
        var f = Run.Frame(kind: kind, step: step)
        f.items = (o["items"] as? [Any] ?? []).map { JSON($0) }
        f.results = (o["results"] as? [Any] ?? []).map { JSON($0) }
        (f.index, f.failedItems, f.top, f.end, f.recover, f.always) = (n("index"), n("failed_items"), n("top"), n("end"), n("recover"), n("always"))
        f.wrote = o["wrote"] as? Bool ?? false
        f.collect = o["collect"] as? Bool ?? false
        f.inRecover = o["in_recover"] as? Bool ?? false
        f.inAlways = o["in_always"] as? Bool ?? false
        f.failing = o["failing"] as? String
        f.returning = o["returning"] as? Bool ?? false
        return f
    }

    private static func json(_ r: Run.Record) -> [String: Any] {
        let out: [String: Any?] = ["step": r.step, "status": r.status.rawValue, "summary": r.summary, "output": r.output.map { String($0.prefix(4000)) }, "note": r.note, "scope": r.scope, "attempt": r.attempt == 1 ? nil : r.attempt, "input": r.input, "at": r.at.timeIntervalSince1970]
        return out.compactMapValues { $0 }
    }

    private static func record(_ o: [String: Any]) -> Run.Record? {
        guard let step = o["step"] as? String, let status = Run.Record.Status(rawValue: o["status"] as? String ?? "") else { return nil }
        return Run.Record(step: step, status: status, summary: o["summary"] as? String ?? "", output: o["output"] as? String, note: o["note"] as? String, at: date(o["at"]) ?? Date(),
                          scope: o["scope"] as? String, attempt: (o["attempt"] as? NSNumber)?.intValue ?? 1, input: o["input"] as? String)
    }
}
