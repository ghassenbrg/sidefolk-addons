import Foundation
import Network
import CoreGraphics

/// One TV at a time, as the Mac app does it (its AppModel, MIT, licenses/Miraya-LICENSE.txt): reach the TV, pair with
/// the six digits on both screens or the saved pin and token, then mirror the screen over WebRTC or play a video on the
/// TV. Everything here runs on the main actor; the network, capture and WebRTC call back onto it.
@MainActor
final class Session {
    enum Phase: String { case idle, connecting, pairing, authorizing, starting, sharing, pausing, paused, reconnecting }
    enum Mode { case mirror, media, pair }

    /// What is shared: a whole display, one window, or a part of a display.
    struct Target: Equatable {
        var kind: CaptureSourceKind
        var displayID: CGDirectDisplayID
        var windowID: UInt32?
        var region: CaptureRegion?
        var label: String
    }

    /// What plays on the TV: a file lent by Sidefolk (a copy in the inbox), or an HTTPS address the TV fetches.
    struct Media: Equatable {
        var file: URL?
        var subtitle: URL?
        var url: String?
        var title: String
    }

    let folder: URL
    let trust: TrustStore
    let discovery = Discovery()
    var choices: Choices { didSet { if choices != oldValue { choices.save(folder) } } }

    private(set) var phase = Phase.idle
    private(set) var mode = Mode.mirror
    private(set) var receiver: Receiver?
    private(set) var target: Target?
    private(set) var media: Media?
    private(set) var pairingCode = ""
    private(set) var problem: String?
    private(set) var note: String?
    private(set) var startedAt: Date?
    private(set) var lastEnd: (at: Date, why: String)?
    private(set) var saved: [TrustedReceiver] = []
    private(set) var found: [Receiver] = []

    // What the TV and WebRTC report while sharing.
    private(set) var tvFPS = 0.0
    private(set) var tvDrops = 0
    private(set) var rttMs = 0.0
    private(set) var picture = ""
    private(set) var bitrate = 0.0
    private(set) var mediaState = ""
    private(set) var mediaPosition = 0.0
    private(set) var mediaDuration = 0.0
    private(set) var mediaSeekable = false
    private(set) var supportsDirectMedia = false

    var connection: TVConnection?
    var rtc: RTCStreamSender?
    var capture: CaptureEngine?
    let files = MediaFileProvider()
    var mediaLoadID = ""
    var lifecycle: Task<Void, Never>?
    var deadline: Task<Void, Never>?
    private var retry: Task<Void, Never>?
    private var runID = UUID()
    private var attempts = 0
    private var pairingClientID = UUID().uuidString
    private var activeClientID = ""
    private var receiverFrames = 0
    private var firstPictureBaseline = 0
    var captureRunning = false
    private var lastStatsAt = ProcessInfo.processInfo.systemUptime
    private var previousFrames = 0
    /// Called whenever something people see changed.
    var onChange: (() -> Void)?

    init(folder: URL) {
        self.folder = folder
        trust = TrustStore(folder: folder)
        choices = Choices.load(folder)
        saved = trust.all()
        discovery.onChange = { [weak self] receivers in Task { @MainActor in self?.found = receivers; self?.onChange?() } }
    }

    var busy: Bool { phase != .idle }

    /// Every TV worth listing: found now, or saved, once each.
    var tvs: [(receiver: Receiver?, saved: TrustedReceiver?, online: Bool)] {
        var rows: [(Receiver?, TrustedReceiver?, Bool)] = found.map { r in (r, saved.first { $0.id == r.id }, true) }
        for s in saved where !found.contains(where: { $0.id == s.id }) { rows.append((s.receiver(found: found), s, false)) }
        return rows
    }

    /// A TV by what the person called it: a name, part of one ("living room"), or an address.
    func tv(named words: String?) -> Receiver? {
        let list = tvs.compactMap(\.receiver)
        guard let words = words?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !words.isEmpty,
              !["the tv", "tv", "my tv", "the television"].contains(words) else {
            // No name: the one there is, or the one used last.
            if list.count == 1 { return list[0] }
            return list.first { $0.id == choices.lastTV } ?? found.first
        }
        let bare = words.replacingOccurrences(of: " tv", with: "").replacingOccurrences(of: "the ", with: "")
        if let exact = list.first(where: { $0.name.lowercased() == words }) { return exact }
        if let part = list.first(where: { $0.name.lowercased().contains(bare) }) { return part }
        if let byAddress = list.first(where: { $0.address == words || $0.host == words }) { return byAddress }
        return nil
    }

    // MARK: Starting and stopping

    func share(_ target: Target, to receiver: Receiver) throws {
        guard !busy else { throw ConnectionFailure(message: "Miraya is already busy with \(self.receiver?.name ?? "a TV"). Stop it first.") }
        mode = .mirror; self.target = target; media = nil
        begin(receiver)
    }

    func play(_ media: Media, on receiver: Receiver) throws {
        guard !busy else { throw ConnectionFailure(message: "Miraya is already busy with \(self.receiver?.name ?? "a TV"). Stop it first.") }
        mode = .media; self.media = media; target = nil
        begin(receiver)
    }

    /// Pairs and stops: the TV is saved for later, nothing is shared.
    func pair(with receiver: Receiver) throws {
        guard !busy else { throw ConnectionFailure(message: "Miraya is busy with \(self.receiver?.name ?? "a TV"). Stop it first.") }
        mode = .pair; target = nil; media = nil
        begin(receiver)
    }

    private func begin(_ receiver: Receiver) {
        problem = nil; note = nil; attempts = 0; runID = UUID(); pairingClientID = UUID().uuidString
        resetStats()
        connect(receiver, generation: runID)
    }

    func stop(_ why: String? = nil) {
        let wasBusy = busy
        files.close(); mediaLoadID = ""
        releaseLentFiles()
        captureRunning = false
        deadline?.cancel(); deadline = nil
        runID = UUID(); retry?.cancel(); retry = nil; lifecycle?.cancel(); lifecycle = nil
        rtc?.close(); rtc = nil
        connection?.close(gracefully: true); connection = nil
        let engine = capture; capture = nil; Task { await engine?.stop() }
        phase = .idle; pairingCode = ""; startedAt = nil; note = nil
        if wasBusy, let why { lastEnd = (Date(), why) }
        onChange?()
    }

    func confirmPairing() throws {
        guard phase == .pairing else { throw ConnectionFailure(message: "No TV is waiting for its code to be confirmed.") }
        connection?.confirmPairing(code: pairingCode)
        phase = .authorizing; onChange?()
    }

    func forget(_ id: String) throws {
        guard !busy || receiver?.id != id else { throw ConnectionFailure(message: "Stop sharing to that TV first.") }
        try trust.remove(id)
        saved = trust.all(); onChange?()
    }

    func reloadSaved() { saved = trust.all() }

    /// The copies Sidefolk lent for the video that played are deleted when it stops.
    private func releaseLentFiles() {
        Inbox(folder: folder).remove([media?.file?.path, media?.subtitle?.path].compactMap { $0 })
    }

    // MARK: The TV connection

    private func connect(_ requested: Receiver, generation: UUID) {
        guard runID == generation else { return }
        // A TV found on the network may have moved to a new port or name since; its stable id finds it again.
        let receiver = saved.first { $0.id == requested.id }?.receiver(found: found)
            ?? (requested.host == nil ? (found.first { $0.id == requested.id } ?? requested) : requested)
        self.receiver = receiver
        phase = attempts == 0 ? .connecting : .reconnecting
        let known = saved.first { $0.id == receiver.id || (receiver.host != nil && $0.host == receiver.host && ($0.port ?? 7421) == (receiver.port ?? 7421)) }
        let session = TVConnection(); connection = session
        session.onControl = { [weak self, weak session] message in
            Task { @MainActor in
                guard let self, let session, self.runID == generation, self.connection === session else { return }
                self.handle(message, session: session, receiver: receiver, generation: generation)
            }
        }
        session.onFailure = { [weak self, weak session] failure in
            Task { @MainActor in
                guard let self, let session, self.runID == generation, self.connection === session else { return }
                self.failed(failure, receiver: receiver, generation: generation)
            }
        }
        session.onPairingRequired = { [weak self, weak session] code in
            Task { @MainActor in
                guard let self, let session, self.runID == generation, self.connection === session else { return }
                self.pairingCode = code; self.phase = .pairing; self.onChange?()
            }
        }
        activeClientID = known?.clientID ?? pairingClientID
        session.connect(to: receiver.endpoint, expectedFingerprint: known?.fingerprint, clientID: activeClientID, name: Self.macName,
                        token: known?.token)
        onChange?()
    }

    /// What the TV shows when it asks to allow this Mac.
    static var macName: String {
        let host = ProcessInfo.processInfo.hostName.replacingOccurrences(of: ".local", with: "")
        return host.isEmpty ? "Sidefolk" : "\(host) (Sidefolk)"
    }

    private func handle(_ message: [String: Any], session: TVConnection, receiver: Receiver, generation: UUID) {
        switch message["op"] as? String {
        case "pending":
            guard [.connecting, .pairing, .authorizing, .reconnecting].contains(phase) else {
                failed(ConnectionFailure(message: "The TV asked to pair at an unexpected time. Update Miraya on the TV.", retryable: false), receiver: receiver, generation: generation); return
            }
            phase = .authorizing
        case "welcome":
            welcome(message, session: session, receiver: receiver, generation: generation)
        case "mediaRead":
            guard mode == .media, !mediaLoadID.isEmpty else { return }
            files.respond(message) { [weak session] in session?.sendControl($0) }
        case "mediaState":
            guard mode == .media, message["loadId"] as? String == mediaLoadID else { return }
            mediaUpdate(message)
        case "paused":
            guard phase == .pausing else { return }
            phase = .paused
        case "ready":
            ready(message, session: session, receiver: receiver, generation: generation)
        case "rtcAnswer", "rtcCandidate":
            guard let rtc else { failed(ConnectionFailure(message: "The TV sent video settings at an unexpected time.", retryable: false), receiver: receiver, generation: generation); return }
            rtc.receive(message)
        case "stats":
            stats(message)
        case "presentation", "requestKeyframe":
            break
        case "stopped":
            stop("Sharing ended on the TV.")
        case "error":
            let code = message["code"] as? String ?? "protocol"
            let detail = message["message"] as? String ?? "The TV refused the connection."
            let extra = code == "auth" ? " Forget this TV here, then pair again with the code on the TV." : ""
            failed(ConnectionFailure(message: detail + extra, retryable: code == "media" || code == "timeout"), receiver: receiver, generation: generation)
        default:
            failed(ConnectionFailure(message: "The TV sent something this version doesn't know. Update Miraya on the TV.", retryable: false), receiver: receiver, generation: generation)
        }
        onChange?()
    }

    private func welcome(_ message: [String: Any], session: TVConnection, receiver: Receiver, generation: UUID) {
        guard [.connecting, .authorizing, .reconnecting].contains(phase) else {
            failed(ConnectionFailure(message: "The TV repeated its greeting. Update Miraya on the TV.", retryable: false), receiver: receiver, generation: generation); return
        }
        guard (message["version"] as? Int) == 1, let rawID = message["receiverId"] as? String, UUID(uuidString: rawID) != nil,
              let token = message["token"] as? String, token.count >= 32, token.count <= 256, let name = message["name"] as? String else {
            failed(ConnectionFailure(message: "This TV runs a Miraya this extension can't talk to.", retryable: false), receiver: receiver, generation: generation); return
        }
        let id = rawID.lowercased()
        let known = saved.first { $0.id == id }
        if let known, known.fingerprint != session.fingerprint {
            failed(ConnectionFailure(message: "This TV's identity changed. Forget it here and compare a new code.", retryable: false), receiver: receiver, generation: generation); return
        }
        let record = TrustedReceiver(id: id, name: name, fingerprint: session.fingerprint, token: token, clientID: activeClientID,
                                     host: receiver.host ?? known?.host, port: receiver.host != nil ? receiver.port : known?.port)
        do {
            if known != record { try trust.save(record); saved = trust.all() }
        } catch {
            failed(ConnectionFailure(message: "Couldn't save the pairing: \(error.localizedDescription)", retryable: false), receiver: receiver, generation: generation); return
        }
        let current = Receiver(id: id, name: name, endpoint: receiver.endpoint, host: receiver.host, port: receiver.port)
        self.receiver = current; pairingCode = ""
        choices.lastTV = id
        let features = message["features"] as? [String] ?? []
        supportsDirectMedia = features.contains("direct-media-v1")
        if mode == .pair { stop(); return }
        if mode == .media { startMedia(session: session, receiver: current, generation: generation); return }
        guard (message["transports"] as? [String])?.contains(RTCSignaling.transport) == true else {
            failed(ConnectionFailure(message: "Update Miraya on the TV: this extension streams with its newer WebRTC engine.", retryable: false), receiver: receiver, generation: generation); return
        }
        tvSize = (message["display"] as? [String: Any]).flatMap { d in
            (d["width"] as? Int).flatMap { w in (d["height"] as? Int).map { (w, $0) } }
        }
        prepareMirror(session: session, receiver: current, generation: generation)
    }

    /// The TV's app viewport (not its panel), a ceiling for the picture when `followTV` is on.
    var tvSize: (width: Int, height: Int)?

    func failed(_ failure: ConnectionFailure, receiver: Receiver, generation: UUID) {
        files.close(); mediaLoadID = ""
        captureRunning = false
        deadline?.cancel(); deadline = nil
        pairingCode = ""
        rtc?.close(); rtc = nil
        connection?.close(); connection = nil
        let engine = capture; capture = nil
        lifecycle?.cancel(); lifecycle = nil
        let target = self.receiver ?? receiver
        let known = saved.contains { $0.id == target.id }
        // A saved TV that dropped out mid-mirror gets three more tries, as in the Mac app; anything else stops.
        if failure.retryable && known && attempts < 3 && mode == .mirror && phase != .pairing {
            attempts += 1; phase = .reconnecting; note = "\(failure.message) Trying again (\(attempts) of 3)."
            retry?.cancel()
            retry = Task {
                await engine?.stop()
                try? await Task.sleep(nanoseconds: UInt64(attempts) * 1_000_000_000)
                guard !Task.isCancelled, runID == generation else { return }
                connect(target, generation: generation)
            }
        } else {
            Task { await engine?.stop() }
            let wasSharing = startedAt != nil
            phase = .idle; problem = failure.message; note = nil; startedAt = nil
            releaseLentFiles()
            if wasSharing { lastEnd = (Date(), failure.message) }
        }
        onChange?()
    }

    func expire(after seconds: UInt64, in phase: Phase, _ message: String, retryable: Bool = true) {
        deadline?.cancel()
        let generation = runID
        deadline = Task { [weak self] in
            try? await Task.sleep(nanoseconds: seconds * 1_000_000_000)
            guard !Task.isCancelled, let self, self.runID == generation, self.phase == phase, let receiver = self.receiver else { return }
            self.failed(ConnectionFailure(message: message, retryable: retryable), receiver: receiver, generation: generation)
        }
    }

    var generation: UUID { runID }

    // MARK: What the TV reports

    private func resetStats() {
        tvFPS = 0; tvDrops = 0; rttMs = 0; picture = ""; bitrate = 0; receiverFrames = 0; previousFrames = 0
        mediaState = ""; mediaPosition = 0; mediaDuration = 0; mediaSeekable = false
    }

    private func stats(_ message: [String: Any]) {
        receiverFrames = message["frames"] as? Int ?? 0
        let now = ProcessInfo.processInfo.systemUptime
        let interval = now - lastStatsAt
        if interval > 0.1 { tvFPS = Double(max(0, receiverFrames - previousFrames)) / interval }
        previousFrames = receiverFrames; lastStatsAt = now
        tvDrops = max(0, message["dropped"] as? Int ?? 0)
        confirmFirstPicture()
        rtc?.playback(frames: receiverFrames, drops: tvDrops, paused: phase == .paused || phase == .pausing)
    }

    func senderStats(_ stats: [String: Any]) {
        rttMs = (stats["rttMs"] as? NSNumber)?.doubleValue ?? rttMs
        bitrate = (stats["actualBitrate"] as? NSNumber)?.doubleValue ?? bitrate
        if let w = (stats["videoWidth"] as? NSNumber)?.intValue, let h = (stats["videoHeight"] as? NSNumber)?.intValue, w > 0, h > 0 {
            picture = "\(w) × \(h)"
        }
    }

    func markCaptureRunning() {
        captureRunning = true
        firstPictureBaseline = receiverFrames
        confirmFirstPicture()
    }

    /// Sharing counts as started only when the TV says it showed a picture.
    private func confirmFirstPicture() {
        guard phase == .starting, captureRunning, receiverFrames > firstPictureBaseline else { return }
        deadline?.cancel(); deadline = nil
        phase = .sharing; note = nil
        if startedAt == nil { startedAt = Date() }
    }

    func setPhase(_ phase: Phase) { self.phase = phase; onChange?() }

    private func mediaUpdate(_ message: [String: Any]) {
        guard [.starting, .sharing, .paused].contains(phase), let state = message["state"] as? String,
              ["preparing", "buffering", "playing", "paused", "ended"].contains(state) else { return }
        func seconds(_ key: String) -> Double {
            let value = (message[key] as? NSNumber)?.doubleValue ?? 0
            return value.isFinite ? min(31_536_000, max(0, value / 1000)) : 0
        }
        mediaState = state; mediaPosition = seconds("positionMs"); mediaDuration = seconds("durationMs")
        mediaSeekable = message["seekable"] as? Bool ?? false
        let width = min(16384, max(0, message["width"] as? Int ?? 0)), height = min(16384, max(0, message["height"] as? Int ?? 0))
        picture = width > 0 && height > 0 ? "\(width) × \(height)" : ""
        if phase == .starting && (message["firstPicture"] as? Bool == true || state == "playing" && message["hasVideo"] as? Bool == false) {
            deadline?.cancel(); deadline = nil; phase = .sharing; startedAt = Date()
        }
        if phase != .starting { phase = state == "paused" || state == "ended" ? .paused : .sharing }
    }
}
