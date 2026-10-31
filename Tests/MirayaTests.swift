import Foundation
import Network
import CoreGraphics
import Testing
import SidefolkExtensionKit
@testable import ext_miraya
@testable import SidefolkExtensionKit

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
        #expect(MirayaPage.summary(MirayaPage.now(s, windows: nil, shots: [:], canRecord: false)).title == "Miraya found no TV")
        #expect(s.tv(named: nil) == nil && s.tv(named: "living room") == nil)
        let page = Self.page(MirayaPage.make(MirayaPage.now(s, windows: nil, shots: [:], canRecord: false)))
        #expect(!Self.buttons(page).contains { $0["tool"] as? String == "confirm_pairing" }, "no pairing button without a code")
        #expect(MirayaPage.spaced("447474") == "447 474" && MirayaPage.clock(3725) == "1:02:05" && MirayaPage.clock(65) == "1:05")
    }

    // MARK: The page in each state, as Sidefolk receives it

    static let display = Screens.Display(id: 1, name: "Built-in display · 3024 × 1964", size: CGSize(width: 1512, height: 982))
    static let living = MirayaPage.Now.TV(id: "6f1c2b9a-1111-4222-8333-944455556666", name: "Living Room", online: true, paired: true)
    static let bedroom = MirayaPage.Now.TV(id: "7a2d3c0b-2222-4333-8444-a55566667777", name: "Bedroom", online: true, paired: false)

    static func ready(_ change: (inout MirayaPage.Now) -> Void = { _ in }) -> MirayaPage.Now {
        var n = MirayaPage.Now(tv: living, tvs: [living, bedroom], displays: [display], canRecord: true, shots: ["display:1": "shots/1/display-1.jpg"])
        change(&n)
        return n
    }

    static func page(_ page: Page) -> [String: Any] { page.json }
    static func sections(_ page: [String: Any]) -> [[String: Any]] { page["sections"] as? [[String: Any]] ?? [] }
    static func blocks(_ page: [String: Any]) -> [[String: Any]] { sections(page).flatMap { $0["blocks"] as? [[String: Any]] ?? [] } }
    static func hero(_ page: [String: Any]) -> [String: Any]? { blocks(page).first { $0["type"] as? String == "hero" } }
    /// Every button on the page: on its own, in the hero, on an option, in a transport, and the summary's.
    static func buttons(_ page: [String: Any]) -> [[String: Any]] {
        var out: [[String: Any]] = []
        for b in blocks(page) {
            if b["type"] as? String == "button" { out.append(b) }
            out += b["actions"] as? [[String: Any]] ?? []
            out += b["buttons"] as? [[String: Any]] ?? []
            out += (b["options"] as? [[String: Any]] ?? []).compactMap { $0["action"] as? [String: Any] }
        }
        return out
    }
    static func primaries(_ page: [String: Any]) -> [String] {
        buttons(page).filter { $0["style"] as? String == "primary" }.compactMap { $0["label"] as? String }
    }

    @Test func audioDestinationsMigrateAndStaleRepliesCannotRemute() throws {
        let legacy = Data(#"{"quality":"balanced","sound":false,"detail":true,"followTV":true,"volume":1}"#.utf8)
        var choices = try JSONDecoder().decode(Choices.self, from: legacy)
        #expect(choices.audio == .mac)
        choices.setAudio(.tv)
        #expect(choices.sound && choices.audio == .tv)
        choices.setAudio(.both)
        #expect(choices.sound && choices.audio == .both)

        let routing = AudioRouting()
        var requests: [(String, Bool, Int)] = []
        routing.send = { requests.append(($0, $1, $2)) }
        routing.set(true)
        #expect(routing.pending && !routing.confirmed)
        routing.set(false)
        #expect(requests.map(\.1) == [true, false] && requests.map(\.2) == [1, 2])
        routing.result(request: requests[0].0, ok: true, message: nil)
        #expect(!routing.confirmed && routing.pending, "an old enable can't override a newer disable")
        routing.result(request: requests[1].0, ok: true, message: nil)
        #expect(!routing.pending && !routing.confirmed)
        routing.set(true)
        routing.failed("old device failure", sequence: 1)
        #expect(routing.desired && routing.pending, "a failure from an earlier lease can't cancel the new one")
    }

    @Test func audioRoutingFailureReturnsToBoth() throws {
        let session = Session(folder: try Self.folder())
        var requests: [(String, Bool, Int)] = []
        session.audioRouting.send = { requests.append(($0, $1, $2)) }
        session.choices.setAudio(.tv)
        session.setPhase(.starting)
        #expect(requests.count == 1 && requests[0].1)
        session.audioRouting.result(request: requests[0].0, ok: false, message: "Unsupported output")
        #expect(session.choices.audio == .both && !session.audioRouting.confirmed)
        #expect(requests.count == 2 && !requests[1].1)
        #expect(session.problem == "Unsupported output")
    }

    @Test func exportUISamples() throws {
        guard let output = ProcessInfo.processInfo.environment["MIRAYA_FIXTURES"] else { return }
        let display2 = Screens.Display(id: 2, name: "External display · 2560 × 1440", size: CGSize(width: 2560, height: 1440))
        let win = [Screens.Window(id: 42, name: "Safari · Apple", app: "Safari", title: "Apple"), Screens.Window(id: 43, name: "Keynote · Presentation", app: "Keynote", title: "Presentation"), Screens.Window(id: 44, name: "Player · Film", app: "Player", title: "Film")]
        let target = Session.Target(kind: .display, displayID: 1, label: "Built-in display")
        func sample(_ change: (inout MirayaPage.Now) -> Void = { _ in }) -> MirayaPage.Now {
            Self.ready { n in
                n.displays.append(display2)
                n.shots = ["display:1": "shots/display-1.png", "display:2": "shots/display-2.png", "window:42": "shots/window-42.png", "window:43": "shots/window-43.png", "window:44": "shots/window-44.png"]
                n.shots.merge(["area:left": "shots/area-left.png", "area:right": "shots/area-right.png", "area:center": "shots/area-center.png"]) { _, new in new }
                change(&n)
            }
        }
        let all: [String: MirayaPage.Now] = [
            "notv": MirayaPage.Now(displays: [Self.display]),
            "ready": sample(), "window": sample { $0.choices.kind = "window"; $0.windows = win },
            "area": sample { $0.choices.kind = "area"; $0.choices.area = "center" },
            "norecord": sample { $0.canRecord = false; $0.shots = [:] },
            "pairing": sample { $0.phase = .pairing; $0.tv = Self.bedroom; $0.pairingCode = "482731" },
            "authorizing": sample { $0.phase = .authorizing; $0.tv = Self.bedroom },
            "sharing": sample { $0.phase = .sharing; $0.target = target; $0.fps = 30; $0.rttMs = 18; $0.picture = "1920 × 1080" },
            "paused": sample { $0.phase = .paused; $0.target = target },
            "playing": sample { $0.phase = .sharing; $0.mode = .media; $0.mediaTitle = "Film.mp4"; $0.mediaState = "playing"; $0.position = 754; $0.duration = 6310; $0.seekable = true },
            "problem": sample { $0.problem = "The TV didn't answer. Check the network and try again." },
        ]
        var text = "#if DEBUG\nimport Foundation\n\n/// Fixtures from MirayaPage.make, for the extension page snapshots.\nenum SampleMirayaPages {\n    static let json: [String: String] = [\n"
        for name in all.keys.sorted() {
            let json = try JSONSerialization.data(withJSONObject: MirayaPage.make(all[name]!).json, options: [.sortedKeys, .withoutEscapingSlashes])
            text += "        \"\(name)\": #\"\"\"\n        \(String(decoding: json, as: UTF8.self))\n        \"\"\"#,\n"
        }
        text += "    ]\n}\n#endif\n"
        try text.write(toFile: output, atomically: true, encoding: .utf8)
    }

    @Test func withoutATVThePageSaysHowToFindOne() throws {
        let page = Self.page(MirayaPage.make(MirayaPage.Now(displays: [Self.display])))
        let hero = try #require(Self.hero(page))
        #expect(hero["title"] as? String == "No TV found yet" && hero["busy"] as? Bool == true)
        #expect(Self.primaries(page) == ["Look again"])
        #expect((page["summary"] as? [String: Any])?["control"] == nil, "nothing to start from the tile")
        let tvs = try #require(Self.sections(page).first { $0["title"] as? String == "TVs" })
        #expect(tvs["place"] == nil, "the address has the full width when there is no TV")
        #expect(Self.blocks(page).contains { $0["type"] as? String == "field" && $0["tool"] as? String == "pair_tv" && $0["key"] as? String == "tv" })
    }

    @Test func readyHasOneThingToDoAndThePicturesToChooseFrom() throws {
        let page = Self.page(MirayaPage.make(Self.ready()))
        let hero = try #require(Self.hero(page))
        #expect(hero["title"] as? String == "Share your screen to Living Room" && hero["eyebrow"] as? String == "Ready")
        #expect(hero["image"] == nil, "the source picture belongs in the picker, not duplicated in the summary")
        let start = try #require((hero["actions"] as? [[String: Any]])?.first)
        #expect(start["tool"] as? String == "share_screen" && (start["input"] as? [String: Any])?["display"] as? Int == 1)
        #expect(Self.primaries(page) == ["Start sharing"], "one primary on the page")
        // The tile and the sidebar can start it too.
        let control = try #require((page["summary"] as? [String: Any])?["control"] as? [String: Any])
        #expect(control["tool"] as? String == "share_screen" && control["style"] as? String == "primary")
        // TVs as rows with their state, the chosen one picked, choosing runs choose_tv with `tv`.
        let tvs = try #require(Self.blocks(page).first { $0["type"] as? String == "choice" && $0["tool"] as? String == "choose_tv" })
        #expect(tvs["style"] as? String == "rows" && tvs["key"] as? String == "tv" && tvs["selected"] as? String == Self.living.id)
        let badges = (tvs["options"] as? [[String: Any]] ?? []).compactMap { ($0["badge"] as? [String: Any])?["text"] as? String }
        #expect(badges == ["Paired", "New"])
        // Displays as pictures; quality as cards.
        let screens = try #require(Self.blocks(page).first { $0["style"] as? String == "tiles" })
        #expect((screens["options"] as? [[String: Any]])?.first?["image"] as? String == "shots/1/display-1.jpg")
        let quality = try #require(Self.blocks(page).first { $0["style"] as? String == "cards" })
        #expect((quality["options"] as? [[String: Any]])?.count == 5 && quality["selected"] as? String == "balanced")
        let folded = Self.sections(page).filter { $0["collapsed"] as? Bool == true }.compactMap { $0["title"] as? String }
        #expect(folded == ["Picture & sound", "More picture settings", "Play a video on the TV", "Connect by address"])
    }

    @Test func aNewTVSaysACodeComesAndAWindowNeedsChoosing() throws {
        let page = Self.page(MirayaPage.make(Self.ready { $0.tv = Self.bedroom; $0.choices.kind = "window" }))
        let hero = try #require(Self.hero(page))
        #expect(hero["eyebrow"] as? String == "New TV" && (hero["detail"] as? String ?? "").contains("six-digit code"))
        // No window listed yet: Start is there but can't run, and the page offers to list them.
        let start = try #require((hero["actions"] as? [[String: Any]])?.first)
        #expect(start["disabled"] as? Bool == true)
        #expect(Self.buttons(page).contains { $0["tool"] as? String == "list_windows" })

        let windows = [Screens.Window(id: 42, name: "Safari · Apple", app: "Safari", title: "Apple")]
        let listed = Self.page(MirayaPage.make(Self.ready { $0.choices.kind = "window"; $0.windows = windows; $0.shots["window:42"] = "shots/2/window-42.jpg" }))
        let tile = try #require(Self.blocks(listed).first { $0["style"] as? String == "tiles" })
        #expect(tile["selected"] as? String == "42" && (tile["options"] as? [[String: Any]])?.first?["image"] as? String == "shots/2/window-42.jpg")
        let go = try #require((Self.hero(listed)?["actions"] as? [[String: Any]])?.first)
        #expect((go["input"] as? [String: Any])?["window_id"] as? Int == 42 && go["disabled"] == nil)
    }

    @Test func areaCanUseEitherDisplay() throws {
        let external = Screens.Display(id: 2, name: "External display · 2560 × 1440", size: CGSize(width: 2560, height: 1440))
        let page = Self.page(MirayaPage.make(Self.ready {
            $0.displays.append(external)
            $0.choices.kind = "area"
            $0.choices.display = 2
            $0.choices.area = "left"
        }))
        let picker = try #require(Self.blocks(page).first {
            $0["label"] as? String == "Screen" && $0["style"] as? String == "rows"
        })
        #expect(picker["selected"] as? String == "2")
        let start = try #require((Self.hero(page)?["actions"] as? [[String: Any]])?.first)
        let input = try #require(start["input"] as? [String: Any])
        #expect(input["display"] as? Int == 2 && input["area"] as? String == "left")
    }

    @Test func pairingIsTheCodeAndItsTwoButtonsAlone() throws {
        let page = Self.page(MirayaPage.make(Self.ready { $0.phase = .pairing; $0.mode = .pair; $0.tv = Self.bedroom; $0.pairingCode = "447474" }))
        #expect(Self.sections(page).count == 1)
        let hero = try #require(Self.hero(page))
        #expect(hero["code"] as? String == "447 474" && hero["title"] as? String == "Compare with Bedroom")
        #expect((hero["actions"] as? [[String: Any]])?.compactMap { $0["tool"] as? String } == ["confirm_pairing", "stop"])
        #expect(Self.primaries(page) == ["Codes match · Pair"])
    }

    @Test func sharingShowsWhatIsLiveAndStopLeads() throws {
        let target = Session.Target(kind: .display, displayID: 1, label: "Built-in display")
        let page = Self.page(MirayaPage.make(Self.ready { $0.phase = .sharing; $0.target = target; $0.fps = 29.6; $0.rttMs = 18; $0.picture = "1920 × 1080" }))
        let hero = try #require(Self.hero(page))
        #expect(hero["title"] as? String == "Sharing your screen to Living Room" && hero["eyebrow"] as? String == "Sharing · live")
        #expect((hero["facts"] as? [[String: Any]])?.compactMap { $0["value"] as? String } == ["30 fps", "18 ms", "1920 × 1080", "Mac and TV"])
        #expect((hero["actions"] as? [[String: Any]])?.compactMap { $0["style"] as? String } == ["secondary", "destructive"])
        #expect(Self.primaries(page).isEmpty, "Stop sharing leads: Sidefolk fills it")
        #expect(!Self.blocks(page).contains { $0["tool"] as? String == "share_screen" }, "nothing else to share while sharing")
        #expect(!Self.blocks(page).contains { $0["tool"] as? String == "choose_tv" }, "the TV in use is named in the hero")
        #expect(((page["summary"] as? [String: Any])?["control"] as? [String: Any])?["tool"] as? String == "stop")

        let paused = Self.page(MirayaPage.make(Self.ready { $0.phase = .paused; $0.target = target }))
        #expect(Self.primaries(paused) == ["Resume"])
    }

    @Test func aVideoHasItsTransport() throws {
        let page = Self.page(MirayaPage.make(Self.ready { $0.phase = .sharing; $0.mode = .media; $0.mediaTitle = "Film.mp4"; $0.mediaState = "playing"
            $0.position = 754; $0.duration = 6310; $0.seekable = true }))
        let transport = try #require(Self.blocks(page).first { $0["type"] as? String == "transport" })
        #expect(transport["position"] as? Double == 754 && transport["duration"] as? Double == 6310 && transport["state"] as? String == "playing")
        #expect((transport["buttons"] as? [[String: Any]])?.compactMap { $0["symbol"] as? String } == ["gobackward.30", "pause.fill", "goforward.30"])
        #expect(Self.primaries(page) == ["Pause"])
        #expect(Self.hero(page)?["title"] as? String == "Film.mp4")
    }

    @Test func everyStateHasAtMostOnePrimaryAndFitsSidefolksLimits() throws {
        let target = Session.Target(kind: .window, displayID: 1, windowID: 42, label: "Safari · Apple")
        let states: [MirayaPage.Now] = [
            MirayaPage.Now(), Self.ready(), Self.ready { $0.problem = "The TV didn't answer." },
            Self.ready { $0.phase = .connecting }, Self.ready { $0.phase = .authorizing }, Self.ready { $0.phase = .reconnecting; $0.note = "Wi-Fi dropped." },
            Self.ready { $0.phase = .pairing; $0.pairingCode = "123456" }, Self.ready { $0.phase = .sharing; $0.target = target },
            Self.ready { $0.phase = .paused; $0.target = target }, Self.ready { $0.phase = .paused; $0.mode = .media; $0.mediaState = "ended" },
        ]
        for n in states {
            let page = Self.page(MirayaPage.make(n))
            #expect(Self.primaries(page).count <= 1, "\(n.phase)")
            let data = try JSONSerialization.data(withJSONObject: page)
            #expect(data.count < 128 * 1024)
            #expect(Self.sections(page).count <= 16 && Self.sections(page).allSatisfy { ($0["blocks"] as? [Any])?.count ?? 0 <= 24 })
            let hero = try #require(Self.hero(page))
            #expect((hero["title"] as? String ?? "").count <= 80 && (hero["detail"] as? String ?? "").count <= 300)
        }
    }

    @Test func aPartOfTheScreenIsShownDimmedAroundIt() throws {
        let context = try #require(CGContext(data: nil, width: 300, height: 195, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 300, height: 195))
        let white = try #require(context.makeImage())
        let left = try #require(Screens.region("left", of: Self.display))
        let shot = try #require(Shots.highlight(left, of: Self.display, in: white))
        #expect(shot.width == 300 && shot.height == 195)
    }
}
