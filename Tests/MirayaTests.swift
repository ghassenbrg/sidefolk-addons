import Foundation
import Network
import Testing
import SidefolkExtensionKit
@testable import ext_miraya

/// Miraya's sending side with canned TVs and temporary files: nothing here reaches the network, records the screen or
/// starts WebRTC. Pairing and playback against Miraya's TV app, and the sandbox, are checked in Sidefolk.
@MainActor
struct MirayaTests {
    static func folder() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("miraya-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test func theCodeIsDerivedAsTheTVDerivesIt() {
        // The shared vector in Miraya's protocol/PROTOCOL.md: both apps must show 447474.
        let code = PairingSession.code(fingerprint: String(repeating: "ab", count: 32), clientID: "12345678-1234-1234-1234-123456789abc",
                                       senderNonce: String(repeating: "01", count: 32), receiverNonce: String(repeating: "02", count: 32))
        #expect(code == "447474")
        #expect(PairingSession.validHex(PairingSession.nonce()) && !PairingSession.validHex("xyz"))
        #expect(PairingCode.normalize("447 474") == "447474" && PairingCode.normalize("44747") == nil)
    }

    @Test func onlyMirayaTVsOfThisVersionAreListed() {
        let endpoint = NWEndpoint.service(name: "Living Room", type: "_miraya._tcp", domain: "local.", interface: nil)
        let id = "6F1C2B9A-1111-4222-8333-944455556666"
        #expect(Discovery.receiver(name: "Living Room", txt: ["v": "1", "id": id], endpoint: endpoint)?.id == id.lowercased())
        #expect(Discovery.receiver(name: "Living Room", txt: ["v": "2", "id": id], endpoint: endpoint) == nil, "a newer protocol")
        #expect(Discovery.receiver(name: "Living Room", txt: ["v": "1", "id": "kitchen"], endpoint: endpoint) == nil, "an id that isn't a UUID")
    }

    @Test func signalingStaysWithinTheTVsLimits() throws {
        #expect(RTCSignaling.h264ReceiveLimit("a=rtpmap:102 H264/90000\na=fmtp:102 profile-level-id=42e02a").fps == 60)
        #expect(RTCSignaling.h264ReceiveLimit("a=rtpmap:102 H264/90000\na=fmtp:102 profile-level-id=42e01f").width == 1280)
        #expect(throws: (any Error).self) { try RTCSignaling.validateCandidate("candidate:1 1 tcp 1 192.168.1.2 9 typ host", mid: "0", index: 0) }
        #expect(throws: (any Error).self) { try RTCSignaling.validateCandidate("candidate:1 1 udp 1 203.0.113.9 3478 typ relay", mid: "0", index: 0) }
        try RTCSignaling.validateCandidate("candidate:1 1 udp 2122260223 192.168.1.2 52000 typ host", mid: "0", index: 0)
        #expect(DirectMedia.validRemoteURL("https://example.com/film.mp4") && !DirectMedia.validRemoteURL("http://example.com/film.mp4"))
        #expect(!DirectMedia.validRemoteURL("https://user:pw@example.com/film.mp4"))
    }

    @Test func areasArePartsOfTheDisplay() throws {
        let display = Screens.Display(id: 1, name: "Built-in display · 3024 × 1964", size: CGSize(width: 1512, height: 982))
        let left = try #require(Screens.region("left", of: display))
        let center = try #require(Screens.region("center", of: display))
        #expect(left == CaptureRegion(x: 0, y: 0, width: 756, height: 982))
        #expect(center.validated(displayWidth: 1512, displayHeight: 982) && abs(center.width / center.height - 16.0 / 9) < 0.01)
        #expect(Screens.region("everything", of: display) == nil)
        #expect(Screens.name(app: "Safari", title: "Apple") == "Safari · Apple" && Screens.name(app: "Notes", title: "Notes") == "Notes")
    }

    @Test func pairingsAreKeptPrivately() throws {
        let store = TrustStore(folder: try Self.folder())
        let tv = TrustedReceiver(id: "6f1c2b9a-1111-4222-8333-944455556666", name: "Living Room", fingerprint: String(repeating: "a", count: 64),
                                 token: String(repeating: "t", count: 43), clientID: UUID().uuidString, host: "192.168.1.20", port: 7421)
        try store.save(tv)
        #expect(store.all() == [tv])
        let mode = try FileManager.default.attributesOfItem(atPath: store.file.path)[.posixPermissions] as? Int
        #expect(mode == 0o600)
        // A TV paired by address is reached by that address, even when its network name is seen too.
        let advertised = Receiver(id: tv.id, name: "Living Room", endpoint: .service(name: "Living Room", type: "_miraya._tcp", domain: "local.", interface: nil))
        #expect(tv.receiver(found: [advertised])?.host == "192.168.1.20")
        try store.remove(tv.id)
        #expect(store.all().isEmpty)
    }

    static func endpoint(_ name: String) -> NWEndpoint { .service(name: name, type: "_miraya._tcp", domain: "local.", interface: nil) }

    static func pairing(_ id: String, _ name: String, host: String? = nil) -> TrustedReceiver {
        TrustedReceiver(id: id, name: name, fingerprint: String(repeating: "a", count: 64), token: String(repeating: "t", count: 43),
                        clientID: UUID().uuidString, host: host, port: host == nil ? nil : 7421)
    }

    // Sidefolk lets a call that reaches only a paired TV run without a card after outside content (Sidefolk D72): a
    // device that takes that TV's name, id or address must never get the screen in its place.
    @Test func aDeviceUsingAPairedTVsNameNeverStandsInForIt() throws {
        let folder = try Self.folder()
        let paired = Self.pairing("6f1c2b9a-1111-4222-8333-944455556666", "Living Room TV")
        try TrustStore(folder: folder).save(paired)
        let s = Session(folder: folder)
        let impostor = Receiver(id: "11111111-2222-4333-8444-555555555555", name: "Living Room TV", endpoint: Self.endpoint("Living Room TV (2)"))
        s.found = [impostor, Receiver(id: paired.id, name: "Living Room TV", endpoint: Self.endpoint("Living Room TV"))]
        #expect(s.tv(named: "Living Room TV")?.id == paired.id && s.tv(named: "living room")?.id == paired.id, "the paired one first")
        #expect(Tools.reach("share_screen", Arguments(["tv": "living room"]), in: s) == .device(paired.id))
        #expect(Tools.reach("share_screen", Arguments([:]), in: s) == .device(paired.id), "no TV named: the paired one that's on")

        // Sidefolk binds the call to that id: it reaches the paired TV, and the connection demands its pinned key.
        let bound = try Tools.tv(paired.id, in: s)
        #expect(bound.id == paired.id && s.pin(for: bound)?.fingerprint == paired.fingerprint)
        // A device advertising the paired TV's id is held to the same pin, and a different key is refused at TLS,
        // before the token or any picture is sent.
        #expect(s.pin(for: Receiver(id: paired.id, name: "Living Room TV", endpoint: Self.endpoint("Spoof")))?.fingerprint == paired.fingerprint)
        #expect(!TVConnection.accepts(String(repeating: "b", count: 64), pinned: paired.fingerprint))
        #expect(TVConnection.accepts(paired.fingerprint, pinned: paired.fingerprint))

        // The paired TV is off: the name now fits only the other device, which isn't paired, so Sidefolk asks, and a
        // call to it would first need the six digits compared on both screens (no pin: a first contact).
        s.found = [impostor]
        #expect(s.tv(named: "living room")?.id == impostor.id)
        #expect(Tools.reach("share_screen", Arguments(["tv": "living room"]), in: s) == .unpaired)
        #expect(s.pin(for: impostor) == nil)
        #expect(throws: Problem.self) { try Tools.tv(paired.id, in: s) }
    }

    @Test func theCheckNamesOnlyAPinnedPairing() throws {
        let folder = try Self.folder()
        let byAddress = Self.pairing("6f1c2b9a-1111-4222-8333-944455556666", "Bedroom", host: "192.168.1.20")
        try TrustStore(folder: folder).save(byAddress)
        let s = Session(folder: folder)
        #expect(Tools.reach("play_on_tv", Arguments(["tv": "192.168.1.20"]), in: s) == .device(byAddress.id), "paired by its address")
        #expect(Tools.reach("play_on_tv", Arguments(["tv": "bedroom"]), in: s) == .device(byAddress.id))
        #expect(Tools.reach("play_on_tv", Arguments([:]), in: s) == .device(byAddress.id), "the only TV")
        #expect(Tools.reach("share_screen", Arguments(["tv": "192.168.1.30"]), in: s) == .unpaired, "an address never paired")
        #expect(Tools.reach("share_screen", Arguments(["tv": "kitchen"]), in: s) == .unpaired, "no such TV")
        // Nothing is on the TV: stopping or pausing reaches no device.
        #expect(Tools.reach("stop", Arguments([:]), in: s) == .nothing && Tools.reach("pause", Arguments([:]), in: s) == .nothing)
        #expect(Tools.reach("pair_tv", Arguments(["tv": "bedroom"]), in: s) == .unpaired, "only the tools that declare it")
        // The manifest declares it on exactly the tools that send to the TV in use or the one named.
        let manifest = try JSONSerialization.jsonObject(with: Data(contentsOf: Self.manifest)) as! [String: Any]
        let tools = manifest["tools"] as! [String: [String: Any]]
        #expect(Set(tools.filter { $0.value["reach"] as? String == "paired" }.keys)
                == ["share_screen", "play_on_tv", "stop", "pause", "resume", "seek", "tv_volume"])
        #expect(tools["share_screen"]?["device"] as? String == "tv" && tools["play_on_tv"]?["device"] as? String == "tv")
    }

    static var manifest: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("extensions/miraya/sidefolk-extension.json")
    }

    @Test func aNamedFileIsLentAsACloneAndGivenBack() throws {
        let home = try Self.folder()
        let film = home.appendingPathComponent("Film.mp4")
        try Data(repeating: 7, count: 4096).write(to: film)
        let inbox = Inbox(folder: home.appendingPathComponent("data"))
        let request = try inbox.lend(file: film.path, subtitle: nil, url: nil, tv: "living room")
        let copy = try #require(request.file)
        #expect(copy.hasPrefix(inbox.dir.path + "/") && request.title == "Film.mp4")
        #expect(try Data(contentsOf: URL(fileURLWithPath: copy)) == Data(repeating: 7, count: 4096))
        try inbox.post(request)
        #expect(inbox.take() == [request] && inbox.take().isEmpty, "taken once")
        inbox.remove([copy, film.path])
        #expect(!FileManager.default.fileExists(atPath: copy) && FileManager.default.fileExists(atPath: film.path), "only lent copies are deleted")

        let notes = home.appendingPathComponent("notes.txt")
        try Data("hi".utf8).write(to: notes)
        #expect(throws: ConnectionFailure.self) { try inbox.lend(file: notes.path, subtitle: nil, url: nil, tv: nil) }
    }

    @Test func thePageSaysOnlyWhatIsTrue() throws {
        let s = Session(folder: try Self.folder())
        #expect(MirayaPage.summary(s).title == "Miraya found no TV")
        #expect(s.tv(named: nil) == nil && s.tv(named: "living room") == nil)
        let page = MirayaPage.make(s, windows: nil)
        let blocks = page.sections.flatMap(\.blocks)
        #expect(!blocks.contains { if case .button(let label, _, _, _, _) = $0 { label.hasPrefix("Codes match") } else { false } },
                "no pairing button without a code")
        #expect(MirayaPage.spaced("447474") == "447 474" && MirayaPage.clock(3725) == "1:02:05" && MirayaPage.clock(65) == "1:05")
    }
}
