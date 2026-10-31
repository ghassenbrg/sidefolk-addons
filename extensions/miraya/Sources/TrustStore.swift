import Foundation
import Network

/// A TV this Mac paired with: its full certificate fingerprint and the token it gave, as the Mac app keeps them.
struct TrustedReceiver: Codable, Equatable, Sendable {
    let id: String
    var name: String
    let fingerprint: String
    let token: String
    let clientID: String
    var host: String?
    var port: UInt16?

    /// Where to reach it: the address it was paired by, as the Mac app does (a TV paired by address is often one whose
    /// network name can't be reached), else its name on the network now.
    func receiver(found: [Receiver]) -> Receiver? {
        if let host, let receiver = Receiver.manual(host: host, port: port ?? 7421) {
            return Receiver(id: id, name: name, endpoint: receiver.endpoint, host: host, port: port)
        }
        return found.first { $0.id == id }
    }
}

/// Saved pairings in the extension's own folder (0600), not the Keychain: the sandbox doesn't open the Keychain to
/// extensions. The token only lets this Mac stream to that TV, and the TV can revoke it (Trusted Macs).
struct TrustStore {
    let file: URL

    init(folder: URL) { file = folder.appendingPathComponent("tvs.json") }

    func all() -> [TrustedReceiver] {
        guard let data = try? Data(contentsOf: file), let list = try? JSONDecoder().decode([TrustedReceiver].self, from: data) else { return [] }
        return list.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func save(_ receiver: TrustedReceiver) throws {
        var list = all().filter { $0.id != receiver.id }
        list.append(receiver)
        try write(list)
    }

    func remove(_ id: String) throws { try write(all().filter { $0.id != id }) }

    private func write(_ list: [TrustedReceiver]) throws {
        let data = try JSONEncoder().encode(list)
        try data.write(to: file, options: [.atomic])
        chmod(file.path, 0o600)
    }
}
