// Adapted from Miraya (macos/Sources/Miraya/StreamConnection.swift), MIT License, Copyright (c) 2026 Ghassen Bargougui:
// licenses/Miraya-LICENSE.txt. The pinned TLS, the six-digit pairing (commit, challenge, reveal, confirm) and the
// deadlines are the Mac app's, unchanged. What it drops is the older media-over-TLS path: video and sound go by
// WebRTC over UDP, so this connection carries control messages only (pairing, signaling, file reads, heartbeats).
import Foundation
import Network
import Security
import CryptoKit

/// All state belongs to `queue`; callbacks are made from it.
final class TVConnection: @unchecked Sendable {
    var onControl: (([String: Any]) -> Void)?
    var onFailure: ((ConnectionFailure) -> Void)?
    var onConnected: (() -> Void)?
    var onPairingRequired: ((String) -> Void)?
    private(set) var fingerprint = ""
    private let queue = DispatchQueue(label: "dev.sidefolk.miraya.network", qos: .userInteractive)
    private var connection: NWConnection?
    private var parser = PacketParser()
    private var sequence: UInt32 = 0
    private var closed = false
    private var established = false
    private var lastReceived = CFAbsoluteTimeGetCurrent()
    private var started = CFAbsoluteTimeGetCurrent()
    private var pending = false
    private var welcomed = false
    private var timer: DispatchSourceTimer?
    private var nonce: UInt32 = 0
    private var certificateMismatch = false
    private var identityVerified = false
    private var senderNonce: String?
    private var comparisonCode: String?
    private var pairingClientID = ""
    private var pairingStage = ""

    func connect(to endpoint: NWEndpoint, expectedFingerprint: String?, clientID: String, name: String, token: String?) {
        if let expectedFingerprint {
            guard expectedFingerprint.count == 64, expectedFingerprint.allSatisfy({ "0123456789abcdef".contains($0) }) else {
                queue.async { self.fail(ConnectionFailure(message: "The saved TV identity is invalid. Forget this TV and pair again.", retryable: false)) }
                return
            }
        } else if token != nil {
            queue.async { self.fail(ConnectionFailure(message: "The saved TV credentials are incomplete. Forget this TV and pair again.", retryable: false)) }
            return
        }
        pairingClientID = clientID
        if expectedFingerprint == nil { senderNonce = PairingSession.nonce() }
        let options = NWProtocolTLS.Options()
        sec_protocol_options_set_min_tls_protocol_version(options.securityProtocolOptions, .TLSv12)
        // A first contact is authenticated by the six digits on both screens; every later one checks all 256 bits.
        sec_protocol_options_set_verify_block(options.securityProtocolOptions, { [weak self] _, trust, complete in
            guard let self else { complete(false); return }
            let ref = sec_trust_copy_ref(trust).takeRetainedValue()
            guard let chain = SecTrustCopyCertificateChain(ref) as? [SecCertificate], let leaf = chain.first else { complete(false); return }
            let hash = SHA256.hash(data: SecCertificateCopyData(leaf) as Data).map { String(format: "%02x", $0) }.joined()
            let valid = Self.accepts(hash, pinned: expectedFingerprint)
            self.fingerprint = hash; self.certificateMismatch = !valid
            self.identityVerified = valid && expectedFingerprint != nil
            complete(valid)
            if !valid {
                self.queue.async { self.fail(ConnectionFailure(message: "The TV's identity didn't match. If the TV was reset, forget it here and pair again.", retryable: false)) }
            }
        }, queue)
        let tcp = NWProtocolTCP.Options(); tcp.noDelay = true; tcp.connectionTimeout = 8
        let parameters = NWParameters(tls: options, tcp: tcp)
        parameters.includePeerToPeer = false
        let nw = NWConnection(to: endpoint, using: parameters)
        connection = nw
        nw.stateUpdateHandler = { [weak self] state in
            guard let self, !self.closed else { return }
            switch state {
            case .ready:
                self.established = true; self.lastReceived = CFAbsoluteTimeGetCurrent()
                var hello: [String: Any] = ["op": "hello", "version": 1, "clientId": clientID, "name": name]
                if let token { hello["token"] = token }
                if let nonce = self.senderNonce {
                    hello["pairing"] = PairingSession.method
                    hello["commitment"] = PairingSession.commitment(nonce: nonce)
                }
                self.sendControlOnQueue(hello); self.receive(); self.onConnected?()
            case .failed(let error):
                self.fail(ConnectionFailure(message: self.certificateMismatch
                    ? "The TV's identity didn't match. If the TV was reset, forget it here and pair again."
                    : "Couldn't reach the TV: \(error.localizedDescription). Check that Miraya is open on it and both are on the same network.",
                    retryable: !self.certificateMismatch))
            case .waiting(let error):
                if CFAbsoluteTimeGetCurrent() - self.started > 8 { self.fail(ConnectionFailure(message: "The TV isn't answering: \(error.localizedDescription)")) }
            default: break
            }
        }
        queue.async { [weak self] in self?.installTimer() }
        nw.start(queue: queue)
    }

    /// Whether to talk to a TV whose certificate hashes to `hash`: a paired TV only with exactly its pinned key, so a
    /// device that took its name, id or address fails here, before the token or anything else is sent; a first
    /// contact with any key, which the six digits then authenticate.
    static func accepts(_ hash: String, pinned: String?) -> Bool {
        pinned.map { hash == $0 } ?? true
    }

    /// The person saw the same six digits on both screens. The code itself never goes to the TV.
    func confirmPairing(code: String) {
        queue.async { [weak self] in
            guard let self, !self.closed, self.pairingStage == "code", let expected = self.comparisonCode else { return }
            guard PairingCode.normalize(code) == expected else {
                self.fail(ConnectionFailure(message: "The pairing codes don't match. Nothing was shared.", retryable: false)); return
            }
            self.identityVerified = true; self.pairingStage = "confirmed"; self.started = CFAbsoluteTimeGetCurrent()
            self.sendControlOnQueue(["op": "pairConfirm"])
        }
    }

    func sendControl(_ object: [String: Any]) { queue.async { [weak self] in self?.sendControlOnQueue(object) } }

    private func sendControlOnQueue(_ object: [String: Any]) {
        guard !closed else { return }
        do {
            let packet = Packet(type: .control, sequence: sequence, payload: try JSONSerialization.data(withJSONObject: object))
            sequence &+= 1
            connection?.send(content: try packet.encoded(), completion: .contentProcessed { [weak self] error in
                guard let self, let error else { return }
                self.queue.async { self.fail(ConnectionFailure(message: "The connection to the TV ended: \(error.localizedDescription)")) }
            })
        } catch { fail(ConnectionFailure(message: error.localizedDescription, retryable: false)) }
    }

    private func receive() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, complete, error in
            guard let self, !self.closed else { return }
            do {
                if let data, !data.isEmpty {
                    self.lastReceived = CFAbsoluteTimeGetCurrent()
                    for packet in try self.parser.append(data) {
                        let control = try packet.control
                        if try self.handle(control) { return }
                    }
                }
                if let error { self.fail(ConnectionFailure(message: "The connection was interrupted: \(error.localizedDescription)")) }
                else if complete { self.fail(ConnectionFailure(message: "The TV closed the connection. Make sure Miraya is still open on the TV.")) }
                else { self.receive() }
            } catch { self.fail(ConnectionFailure(message: error.localizedDescription, retryable: false)) }
        }
    }

    /// The pairing state machine, as in the Mac app; true when the connection ended.
    private func handle(_ control: [String: Any]) throws -> Bool {
        let op = control["op"] as? String
        if op == "pairChallenge" {
            guard let senderNonce, comparisonCode == nil, !welcomed, control["pairing"] as? String == PairingSession.method,
                  let nonce = control["nonce"] as? String, PairingSession.validHex(nonce) else { throw WireError.invalidControl }
            comparisonCode = PairingSession.code(fingerprint: fingerprint, clientID: pairingClientID, senderNonce: senderNonce, receiverNonce: nonce)
            sendControlOnQueue(["op": "pairReveal", "nonce": senderNonce])
            return false
        }
        if op == "pending" {
            guard !welcomed else { throw WireError.invalidControl }
            let stage = control["stage"] as? String ?? "approval"
            if senderNonce != nil {
                if stage == "code" {
                    guard pairingStage.isEmpty, let code = comparisonCode else { throw WireError.invalidControl }
                    pairingStage = "code"; pending = true; started = CFAbsoluteTimeGetCurrent()
                    onPairingRequired?(code)
                    return false
                }
                guard stage == "approval", pairingStage == "confirmed", identityVerified else { throw WireError.invalidControl }
            } else { guard !pending else { throw WireError.invalidControl } }
            pairingStage = "approval"; pending = true; started = CFAbsoluteTimeGetCurrent()
        }
        if op == "welcome" {
            guard !welcomed, identityVerified else { throw WireError.invalidControl }
            welcomed = true; pending = false
        }
        if !identityVerified && op != "ping" && op != "pong" && op != "error" { throw WireError.invalidControl }
        if op == "ping" { sendControlOnQueue(["op": "pong", "nonce": control["nonce"] ?? 0]) }
        else if op != "pong" {
            onControl?(control)
            // A stop or refusal from the TV is final: close here, so no failure follows to start a retry.
            if op == "error" || op == "stopped" { closeOnQueue(); return true }
        }
        return false
    }

    private func installTimer() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 1, repeating: 1)
        timer.setEventHandler { [weak self] in
            guard let self, !self.closed else { return }
            let now = CFAbsoluteTimeGetCurrent()
            if !self.welcomed && now - self.started > (self.pairingStage == "code" ? 90 : self.pending ? 35 : 12) {
                self.fail(ConnectionFailure(message: self.pending ? "Pairing timed out. Try again and compare the new six-digit code."
                                                                  : "The TV didn't answer. Check its address and that both are on the same network.",
                                            retryable: !self.pending)); return
            }
            if self.welcomed && now - self.lastReceived > 10 { self.fail(ConnectionFailure(message: "The TV stopped answering. Check that it's on and connected.")); return }
            if self.established { self.nonce &+= 1; self.sendControlOnQueue(["op": "ping", "nonce": self.nonce]) }
        }
        self.timer = timer; timer.resume()
    }

    private func fail(_ error: ConnectionFailure) { guard !closed else { return }; closeOnQueue(); onFailure?(error) }

    func close(gracefully: Bool = false) {
        // Keep the connection alive until this runs: its owner drops it at once on Stop.
        queue.async { [self] in
            if gracefully && !self.closed {
                self.sendControlOnQueue(["op": "stop"])
                self.queue.asyncAfter(deadline: .now() + 0.15) { self.closeOnQueue() }
            } else { self.closeOnQueue() }
        }
    }

    private func closeOnQueue() {
        guard !closed else { return }
        closed = true
        timer?.cancel(); timer = nil; connection?.stateUpdateHandler = nil; connection?.cancel(); connection = nil
    }

    deinit { timer?.cancel(); connection?.cancel() }
}
