import Foundation

/// Talks to the host's output-mute guardian. Requests are asynchronous: the extension must never
/// claim TV-only is active until Sidefolk confirms that the Mac output was muted.
@MainActor
final class AudioRouting {
    private(set) var desired = false
    private(set) var confirmed = false
    private(set) var pending = false
    private var sequence = 0
    private var request: String?
    private var timeout: Task<Void, Never>?
    var send: ((String, Bool, Int) -> Void)?
    var onFailure: ((String) -> Void)?
    var onChange: (() -> Void)?

    func set(_ enabled: Bool) {
        guard enabled != desired || (enabled && !confirmed && !pending) else { return }
        desired = enabled
        if !enabled { confirmed = false }
        sequence += 1
        let id = UUID().uuidString
        request = id
        pending = true
        send?(id, enabled, sequence)
        timeout?.cancel()
        timeout = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled, let self, self.request == id else { return }
            self.failed(L("Sidefolk didn't confirm the Mac's sound output. Miraya selected Mac and TV; check the Mac's mute control."))
        }
        onChange?()
    }

    func result(request id: String, ok: Bool, message: String?) {
        guard request == id else { return }
        timeout?.cancel(); timeout = nil; request = nil; pending = false
        if ok {
            confirmed = desired
            onChange?()
        } else {
            failed(message ?? L("Sidefolk couldn't change the Mac's sound output."))
        }
    }

    func failed(_ message: String) {
        timeout?.cancel(); timeout = nil; request = nil; pending = false; confirmed = false
        let wasEnabled = desired
        if wasEnabled {
            // A late enable may still be in flight at the host. A newer disable cancels it.
            set(false)
        }
        onFailure?(message)
        onChange?()
    }

    func failed(_ message: String, sequence: Int) {
        guard sequence == self.sequence, desired else { return }
        failed(message)
    }
}
