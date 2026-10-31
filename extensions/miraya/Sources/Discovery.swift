import Foundation
import Network

/// A TV running Miraya: found on the network now, saved after pairing, or both.
struct Receiver: Equatable, Sendable {
    let id: String
    var name: String
    let endpoint: NWEndpoint
    var host: String?
    var port: UInt16?

    var address: String? { host.map { "\($0):\(port ?? 7421)" } }

    static func manual(host: String, port: UInt16) -> Receiver? {
        guard let p = NWEndpoint.Port(rawValue: port) else { return nil }
        return Receiver(id: "manual:\(host):\(port)", name: host, endpoint: .hostPort(host: .init(host), port: p), host: host, port: port)
    }
}

/// TVs that advertise `_miraya._tcp` on the local network (the TV app does while it's open), with the stable id in their
/// TXT record. The Mac app used NetService on its run loop; NWBrowser takes a queue, which suits a program with no UI.
/// Browsing goes through mDNSResponder, which `permissions.network` already opens; macOS may ask about the local network.
final class Discovery: @unchecked Sendable {
    private let queue = DispatchQueue(label: "dev.sidefolk.miraya.discovery")
    private var browser: NWBrowser?
    private var found: [Receiver] = []
    private(set) var problem: String?
    private(set) var startedAt: Date?
    var onChange: (([Receiver]) -> Void)?

    var receivers: [Receiver] { queue.sync { found } }

    func start() {
        queue.async { [self] in
            guard browser == nil else { return }
            startedAt = Date()
            let browser = NWBrowser(for: .bonjourWithTXTRecord(type: "_miraya._tcp", domain: "local."), using: NWParameters())
            browser.stateUpdateHandler = { [weak self] state in
                guard let self else { return }
                switch state {
                case .failed(let error):
                    self.problem = "Looking for TVs stopped: \(error.localizedDescription)"
                    self.browser?.cancel(); self.browser = nil
                    // The network may come back (Wi-Fi rejoined): look again a little later.
                    self.queue.asyncAfter(deadline: .now() + 10) { self.start() }
                case .waiting(let error):
                    self.problem = "Can't look for TVs on this network: \(error.localizedDescription). Allow Sidefolk in Privacy & Security › Local Network."
                case .ready:
                    self.problem = nil
                default: break
                }
            }
            browser.browseResultsChangedHandler = { [weak self] results, _ in
                guard let self else { return }
                self.found = Self.receivers(from: results)
                self.onChange?(self.found)
            }
            browser.start(queue: queue)
            self.browser = browser
        }
    }

    func refresh() {
        queue.async { [self] in browser?.cancel(); browser = nil; found = []; start() }
    }

    /// One row per stable TV id: a TV being renamed can be advertised under both names for a moment.
    static func receivers(from results: Set<NWBrowser.Result>) -> [Receiver] {
        var byID: [String: Receiver] = [:]
        for result in results {
            guard case .service(let name, _, _, _) = result.endpoint, case .bonjour(let txt) = result.metadata,
                  let receiver = receiver(name: name, txt: txt.dictionary, endpoint: result.endpoint) else { continue }
            byID[receiver.id] = receiver
        }
        return byID.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// The TV's advertisement as the Mac app reads it: protocol version 1 and a UUID; anything else isn't one we can use.
    static func receiver(name: String, txt: [String: String], endpoint: NWEndpoint) -> Receiver? {
        guard txt["v"] == "1", let raw = txt["id"], let uuid = UUID(uuidString: raw) else { return nil }
        return Receiver(id: uuid.uuidString.lowercased(), name: name, endpoint: endpoint)
    }
}
