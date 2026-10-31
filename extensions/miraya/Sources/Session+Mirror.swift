import Foundation
import SidefolkExtensionKit
@preconcurrency import ScreenCaptureKit
import CoreGraphics

/// Mirroring, in the Mac app's order: the TV is paired, macOS lets Sidefolk record, the TV gets ready, WebRTC
/// connects, then capture starts, and sharing counts once the TV says it showed a picture.
extension Session {
    func prepareMirror(session: TVConnection, receiver: Receiver, generation: UUID) {
        setPhase(.starting)
        lifecycle = Task {
            do {
                // The first look at what can be shared is where macOS asks the person (for Sidefolk) to allow recording.
                _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                guard !Task.isCancelled, self.generation == generation, self.connection === session else { return }
                session.sendControl(["op": "start", "transport": RTCSignaling.transport, "audio": self.choices.sound, "volume": self.choices.volume])
                self.expire(after: 10, in: .starting, L("The TV didn't get ready in time. Trying again…"))
            } catch {
                guard !Task.isCancelled, self.generation == generation, self.connection === session else { return }
                self.captureFailed(error, receiver: receiver, generation: generation)
            }
        }
    }

    func captureFailed(_ failure: Error, receiver: Receiver, generation: UUID) {
        let message = CaptureEngine.isPermissionDenied(failure)
            ? L("macOS hasn't allowed Sidefolk to record the screen. Turn on Sidefolk in System Settings › Privacy & Security › Screen & System Audio Recording, then share again. (Miraya runs inside Sidefolk, so the permission is Sidefolk's.)")
            : L("Couldn't record the screen: {error}", ["error": Said.shown(failure.localizedDescription)])
        failed(ConnectionFailure(message: message, retryable: false), receiver: receiver, generation: generation)
    }

    func ready(_ message: [String: Any], session: TVConnection, receiver: Receiver, generation: UUID) {
        deadline?.cancel(); deadline = nil
        guard mode == .mirror, phase == .starting, capture == nil, message["transport"] as? String == RTCSignaling.transport,
              let mediaID = message["session"] as? String, RTCSignaling.validSession(mediaID) else {
            failed(ConnectionFailure(message: L("The TV answered in a way this version doesn't know. Update Miraya on the TV."), retryable: false), receiver: receiver, generation: generation)
            return
        }
        if let rtc {
            guard rtc.sessionID == mediaID else { failed(ConnectionFailure(message: L("The TV started a different video session."), retryable: false), receiver: receiver, generation: generation); return }
            rtc.update(quality: choices.preset, audio: choices.sound, prioritizeDetail: choices.detail)
            startCapture(session: session, receiver: receiver, generation: generation)
        } else {
            startRTC(session: session, receiver: receiver, generation: generation, mediaID: mediaID)
        }
    }

    private func startRTC(session: TVConnection, receiver: Receiver, generation: UUID, mediaID: String) {
        expire(after: 12, in: .starting, L("The video connection took too long to start. Try sharing again."), retryable: false)
        let quality = choices.preset, sound = choices.sound, detail = choices.detail
        lifecycle = Task { [self, weak session] in
            do {
                // Building the factory and its audio device can take seconds: off the main actor.
                let stream = try await Task.detached(priority: .userInitiated) { [weak self, weak session] in
                    try RTCStreamSender(sessionID: mediaID, quality: quality, audio: sound, prioritizeDetail: detail,
                        signal: { [weak session] in session?.sendControl($0) },
                        connected: { [weak self, weak session] in
                            Task { @MainActor in
                                guard let self, let session, self.generation == generation, self.connection === session,
                                      self.phase == .starting, self.capture == nil else { return }
                                self.startCapture(session: session, receiver: receiver, generation: generation)
                            }
                        },
                        failure: { [weak self, weak session] failure in
                            Task { @MainActor in
                                guard let self, let session, self.generation == generation, self.connection === session else { return }
                                self.failed(failure, receiver: receiver, generation: generation)
                            }
                        },
                        stats: { [weak self] stats in Task { @MainActor in self?.senderStats(stats) } })
                }.value
                guard !Task.isCancelled, let session, self.generation == generation, self.connection === session else { stream.close(); return }
                self.rtc = stream
                self.expire(after: 12, in: .starting, L("The TV couldn't open a direct video connection. Check the local network permission, any VPN, and Wi-Fi client isolation."))
                stream.start()
            } catch {
                guard !Task.isCancelled, let session, self.generation == generation, self.connection === session else { return }
                self.failed(ConnectionFailure(message: L("Couldn't start the video connection: {error}", ["error": Said.shown(error.localizedDescription)]), retryable: false), receiver: receiver, generation: generation)
            }
        }
    }

    func startCapture(session: TVConnection, receiver: Receiver, generation: UUID) {
        guard let target else { return }
        captureRunning = false
        let engine = CaptureEngine(); capture = engine
        engine.onFrame = { [weak rtc] buffer, pts in rtc?.submitVideo(buffer, pts: pts) }
        engine.onAudio = { [weak rtc] data, pts in rtc?.submitAudio(data, pts: pts) }
        engine.onError = { [weak self, weak engine] failure in
            Task { @MainActor in
                guard let self, let engine, self.generation == generation, self.capture === engine else { return }
                self.captureFailed(failure, receiver: receiver, generation: generation)
            }
        }
        let quality = choices.preset, sound = choices.sound
        let limit = choices.followTV ? tvSize : nil
        lifecycle = Task {
            do {
                try await engine.start(displayID: target.displayID, quality: quality, audio: sound, maximumOutputSize: limit,
                                       source: target.kind, windowID: target.windowID, region: target.region)
                guard !Task.isCancelled, self.generation == generation, self.connection === session, self.capture === engine else { await engine.stop(); return }
                self.markCaptureRunning()
                if self.phase == .starting {
                    self.expire(after: 12, in: .starting, L("The TV connected but hasn't shown a picture. Check the Wi-Fi and try again."))
                }
                self.onChange?()
            } catch {
                guard !Task.isCancelled, self.generation == generation, self.connection === session, self.capture === engine else { await engine.stop(); return }
                self.captureFailed(error, receiver: receiver, generation: generation)
            }
        }
    }

    /// Stops capture; the TV may keep the last picture. Resume starts capture again on the same connection.
    func pause() throws {
        if mode == .media { try mediaCommand("pause"); return }
        guard phase == .sharing, let session = connection else { throw ConnectionFailure(message: L("Nothing is being shared.")) }
        rtc?.update(quality: choices.preset, audio: choices.sound, paused: true, prioritizeDetail: choices.detail)
        let engine = capture; capture = nil; captureRunning = false
        setPhase(.pausing)
        let generation = self.generation
        lifecycle = Task {
            await engine?.stop()
            guard !Task.isCancelled, self.generation == generation, self.connection === session else { return }
            session.sendControl(["op": "pause"])
        }
    }

    func resume() throws {
        if mode == .media { try mediaCommand("play"); return }
        guard phase == .paused, let session = connection else { throw ConnectionFailure(message: L("Sharing isn't paused.")) }
        setPhase(.starting)
        session.sendControl(["op": "resume", "audio": choices.sound, "volume": choices.volume])
        expire(after: 10, in: .starting, L("The TV didn't get ready in time. Trying again…"))
    }

    /// A quality or sound change while sharing: capture stops, the TV reconfigures, capture starts again; WebRTC's
    /// connection stays (the Mac app's settingsChanged).
    func applyChoices() {
        synchronizeOutputMute()
        guard phase == .sharing, mode == .mirror, let session = connection else { return }
        rtc?.update(quality: choices.preset, audio: choices.sound, paused: true, prioritizeDetail: choices.detail)
        let engine = capture; capture = nil; captureRunning = false
        setPhase(.starting)
        let generation = self.generation
        lifecycle = Task {
            await engine?.stop()
            guard !Task.isCancelled, self.generation == generation, self.connection === session else { return }
            session.sendControl(["op": "reconfigure", "audio": self.choices.sound, "volume": self.choices.volume])
            self.expire(after: 10, in: .starting, L("The TV didn't get ready in time. Trying again…"))
        }
    }

    func setVolume(_ volume: Double) throws {
        choices.volume = min(1, max(0, volume))
        if mode == .media { try mediaCommand("volume", extra: ["volume": choices.volume]) }
        else if phase == .sharing || phase == .paused { connection?.sendControl(["op": "setVolume", "volume": choices.volume]) }
    }
}

/// What can be shared, read without asking macOS for anything (displays come from Core Graphics); windows need the
/// recording permission, so they're listed only when the person asks.
enum Screens {
    struct Display { let id: CGDirectDisplayID; let name: String; let size: CGSize }

    static func displays() -> [Display] {
        var ids = [CGDirectDisplayID](repeating: 0, count: 16)
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(16, &ids, &count) == .success else { return [] }
        var external = 0
        return ids.prefix(Int(count)).map { id in
            let bounds = CGDisplayBounds(id)
            let mode = CGDisplayCopyDisplayMode(id)
            let pixels = "\(mode?.pixelWidth ?? Int(bounds.width)) × \(mode?.pixelHeight ?? Int(bounds.height))"
            let name: String
            if CGDisplayIsBuiltin(id) != 0 { name = L("Built-in display") } else {
                external += 1
                name = external == 1 ? L("External display") : L("External display {number}", ["number": external])
            }
            return Display(id: id, name: "\(name) · \(pixels)", size: bounds.size)
        }
    }

    struct Window {
        let id: UInt32
        let name: String
        var app = ""
        var title = ""
    }

    /// Windows people would share: ordinary app windows, big enough to see, named by app and title.
    static func windows() async throws -> [Window] {
        let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
        return content.windows
            .filter { $0.windowLayer == 0 && $0.frame.width >= 32 && $0.frame.height >= 32 }
            .map { w in
                let app = w.owningApplication?.applicationName ?? ""
                return Window(id: w.windowID, name: name(app: app, title: w.title), app: app.isEmpty ? L("App") : app, title: w.title ?? "")
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    static func name(app: String?, title: String?) -> String {
        let app = app?.isEmpty == false ? app! : L("App")
        guard let title, !title.isEmpty, title != app else { return app }
        return "\(app) · \(title.count > 60 ? String(title.prefix(59)) + "…" : title)"
    }

    /// Named parts of a display, for sharing a region without drawing one (Sidefolk has no area picker yet).
    static func region(_ name: String, of display: Display) -> CaptureRegion? {
        let w = display.size.width, h = display.size.height
        switch name {
        case "left": return CaptureRegion(x: 0, y: 0, width: (w / 2).rounded(.down), height: h)
        case "right": return CaptureRegion(x: (w / 2).rounded(.down), y: 0, width: w - (w / 2).rounded(.down), height: h)
        case "top": return CaptureRegion(x: 0, y: 0, width: w, height: (h / 2).rounded(.down))
        case "bottom": return CaptureRegion(x: 0, y: (h / 2).rounded(.down), width: w, height: h - (h / 2).rounded(.down))
        case "center":
            // The middle of the screen at 16:9, two thirds as wide: where a video usually plays.
            let width = (w * 2 / 3).rounded(.down), height = min(h, (width * 9 / 16).rounded(.down))
            return CaptureRegion(x: ((w - width) / 2).rounded(.down), y: ((h - height) / 2).rounded(.down), width: width, height: height)
        default: return nil
        }
    }
}
