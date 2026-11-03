import CoreGraphics
import Foundation
import Testing
@testable import ext_clipboard
@testable import ext_keep_awake
@testable import ext_miraya
@testable import ext_system_vitals_plus
@testable import SidefolkExtensionKit

/// Every state of the four composed pages: what each must keep, whatever a design's first screen shows. With `SIDEFOLK_PAGE_DUMP` set, each page's JSON is saved there too, in the
/// form Sidefolk's UI snapshots read (`SIDEFOLK_SNAPSHOT_PAGES`), so all of them can be looked at.
@MainActor
struct HomepageStatesTests {
    static let now = Date(timeIntervalSince1970: 1_800_000_000)
    static let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()

    static func dump(_ name: String, _ page: Page, title: String, ext: String, width: Double = 848, alerts: [[String: Any]] = [], folder: String? = nil) throws {
        guard let out = ProcessInfo.processInfo.environment["SIDEFOLK_PAGE_DUMP"] else { return }
        var file: [String: Any] = ["title": title, "width": width, "icon": repo.appendingPathComponent("extensions/\(ext)/icon.pdf").path, "page": page.json, "alerts": alerts]
        if let folder { file["folder"] = folder }
        let data = try JSONSerialization.data(withJSONObject: file, options: [.sortedKeys])
        #expect(data.count < 128 * 1024)
        try data.write(to: URL(fileURLWithPath: out).appendingPathComponent("\(name).json"))
    }

    static func blocks(_ page: Page) -> [[String: Any]] {
        (page.json["sections"] as? [[String: Any]] ?? []).flatMap { s in (s["blocks"] as? [[String: Any]] ?? []) + (s["accessories"] as? [[String: Any]] ?? []) }
    }

    /// All the words and tools on a page, however deep.
    static func flat(_ value: Any) -> String {
        switch value {
        case let d as [String: Any]: d.values.map(flat).joined(separator: " ")
        case let a as [Any]: a.map(flat).joined(separator: " ")
        case let s as String: s
        default: ""
        }
    }

    static func says(_ page: Page, _ words: String...) {
        let all = flat(page.json).replacingOccurrences(of: "\u{2068}", with: "").replacingOccurrences(of: "\u{2069}", with: "")
        for w in words { #expect(all.contains(w), "\(w)") }
    }

    // MARK: Keep Awake

    @Test func keepAwakeInEveryState() throws {
        let start = Self.now.addingTimeInterval(-35 * 60)
        let timed = Session(started: start, until: Self.now.addingTimeInterval(85 * 60), screen: true, active: true)
        let pages: [String: Page] = [
            "awake-inactive": AwakePage.make(AwakePage.Now(lastEnd: (Self.now.addingTimeInterval(-600), "Its time is up.")), now: Self.now),
            "awake-timed": AwakePage.make(AwakePage.Now(session: timed, hold: .holding, nudges: 0), now: Self.now),
            "awake-untimed": AwakePage.make(AwakePage.Now(session: Session(started: start), hold: .holding), now: Self.now),
            "awake-app": AwakePage.make(AwakePage.Now(session: Session(started: start, whileApp: "Zoom"), hold: .holding), now: Self.now),
            "awake-waiting": AwakePage.make(AwakePage.Now(session: Session(started: start, pluggedOnly: true), hold: .waiting("Waiting to be plugged in.")), now: Self.now),
        ]
        let watcher: [[String: Any]] = [["watcher": "ended", "title": "Keep Awake ended", "description": "Tells you when keeping the Mac awake ends by itself: its time is up, or the app it waited on quit."]]
        for (name, page) in pages { try Self.dump(name, page, title: "Keep Awake", ext: "keep-awake", alerts: watcher) }
        func hero(_ name: String) -> [String: Any] { Self.blocks(pages[name]!).first { $0["type"] as? String == "hero" } ?? [:] }

        // A ring only with an end, from when the session began: 85 min of 120 left.
        let ring = try #require(hero("awake-timed")["ring"] as? [String: Any])
        #expect(abs((ring["fraction"] as? Double ?? 0) - 85.0 / 120.0) < 0.001)
        for name in ["awake-untimed", "awake-app", "awake-inactive"] { #expect(hero(name)["ring"] == nil, "\(name) has no end to count down to") }
        // Nothing held is never called active.
        Self.says(pages["awake-waiting"]!, "Waiting", "Waiting to be plugged in.")
        #expect(!Self.flat(pages["awake-waiting"]!.json).contains("Active session"))
        // The start presets, Extend only with an end, and Stop whenever there is a session.
        let inactive = Self.flat(hero("awake-inactive"))
        #expect(inactive.contains("1 hour") && inactive.contains("2 hours") && !inactive.contains("stop_keeping_awake"))
        #expect(Self.flat(hero("awake-timed")).contains("extend") && !Self.flat(hero("awake-untimed")).contains("extend") && Self.flat(hero("awake-untimed")).contains("stop_keeping_awake"))
        // Every choice, the three routes to Ask, and the main switch where people are.
        for page in pages.values {
            Self.says(page, "screen", "active", "plugged_only", "battery_floor", "Keep my Mac awake while Zoom is open", "Keep my Mac awake until 6pm", "Keep me active for an hour")
            #expect((page.json["summary"] as? [String: Any])?["control"] != nil)
        }
        Self.says(pages["awake-app"]!, "Awake while Zoom is open", "Ends by itself when Zoom quits.")
    }

    // MARK: Clipboard

    static func clipboard() -> History {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("home-\(UUID().uuidString)")
        let h = History(folder: folder)
        let t = now
        h.add(Entry(id: "code", kind: .code, text: "func hello() {\n    print(\"hi\")\n}", source: "Xcode", copied: t.addingTimeInterval(-7200)))
        h.add(Entry(id: "color", kind: .color, text: "#2ED4D9", source: "Figma", copied: t.addingTimeInterval(-3600)))
        var link = Entry(id: "link", kind: .link, text: "https://example.com/sidefolk/pull/2", source: "Safari", copied: t.addingTimeInterval(-180))
        link.pinned = true
        h.add(link)
        h.add(Entry(id: "text", kind: .text, text: "Meeting notes\nShip on Friday\nCharts reach back a day", source: "Notes", copied: t.addingTimeInterval(-20)))
        return h
    }

    @Test func clipboardInEveryState() throws {
        let h = Self.clipboard()
        defer { try? FileManager.default.removeItem(at: h.folder) }
        let emptied = History(folder: FileManager.default.temporaryDirectory.appendingPathComponent("home-\(UUID().uuidString)"))
        defer { try? FileManager.default.removeItem(at: emptied.folder) }
        var pages: [String: Page] = [
            "clipboard-list": ClipboardPage.make(h, now: Self.now),
            "clipboard-link": ClipboardPage.make(h, place: .init(picked: "link"), now: Self.now),
            "clipboard-code": ClipboardPage.make(h, place: .init(picked: "code"), now: Self.now),
            "clipboard-color": ClipboardPage.make(h, place: .init(picked: "color"), now: Self.now),
            "clipboard-pinned": ClipboardPage.make(h, place: .init(pinned: true), now: Self.now),
            "clipboard-nomatch": ClipboardPage.make(h, place: .init(query: "zebra"), now: Self.now),
            "clipboard-settings": ClipboardPage.make(h, place: .init(settings: true), now: Self.now),
            "clipboard-empty": ClipboardPage.make(emptied, now: Self.now),
        ]
        h.set { $0.skipNext = true }
        pages["clipboard-skip"] = ClipboardPage.make(h, now: Self.now)
        h.set { $0.skipNext = false; $0.pausedUntil = Self.now.addingTimeInterval(600) }
        pages["clipboard-paused"] = ClipboardPage.make(h, now: Self.now)
        h.set { $0.pausedUntil = nil; $0.keeping = false }
        pages["clipboard-off"] = ClipboardPage.make(h, now: Self.now)
        for (name, page) in pages { try Self.dump(name, page, title: "Clipboard", ext: "clipboard") }

        Self.says(pages["clipboard-list"]!, "Pause", "Skip my next copy", "pin_copy", "delete_copy", "copy_again", "Search copies…", "All copies", "Pinned", "History & privacy")
        Self.says(pages["clipboard-paused"]!, "Resume now")
        #expect(!Self.flat(pages["clipboard-skip"]!.json).contains("Skip my next copy"))
        Self.says(pages["clipboard-nomatch"]!, "No copy matches “zebra”.")
        Self.says(pages["clipboard-empty"]!, "Nothing copied yet.", "Pick a copy to see it whole.")
        // Picking draws it and pastes nothing: a row only moves the page's state.
        let rows = Self.blocks(pages["clipboard-list"]!).first { $0["type"] as? String == "list" }?["items"] as? [[String: Any]] ?? []
        #expect(rows.count == 4 && rows.allSatisfy { ($0["press"] as? [String: Any])?["go"] != nil && ($0["press"] as? [String: Any])?["tool"] == nil })
        // With nothing picked yet, the first copy shows: the palette's own order, pins on top.
        #expect(rows.first?["selected"] as? Bool == true && rows.filter { $0["selected"] as? Bool == true }.count == 1)
        #expect(rows.contains { $0["mark"] as? String == "pin.fill" })
        // A picked copy that went away falls back to the first, rather than showing nothing.
        Self.says(ClipboardPage.make(h, place: .init(picked: "gone"), now: Self.now), "https://example.com/sidefolk/pull/2")
        // Every setting and route stays reachable from the settings place.
        Self.says(pages["clipboard-settings"]!, "keeping", "hide_secrets", "paste", "plain", "limit", "sort", "pins", "search", "keep_images", "keep_files", "keep_formatting", "clear_history",
                  "ignore", "What did I copy today?", "Find the last link I copied", "Save the last thing I copied to my notes", "host_controls", "Copies", "Links", "Files")
    }

    @Test func aHiddenCopyNeverShowsItsWords() {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("home-\(UUID().uuidString)")
        let h = History(folder: folder)
        defer { try? FileManager.default.removeItem(at: folder) }
        h.add(Entry(id: "s", kind: .text, text: "hunter2-secret", source: "Notes", copied: Self.now, secret: true))
        let page = ClipboardPage.make(h, now: Self.now)
        #expect(!Self.flat(page.json).contains("hunter2"))
        // And it can't be kept past its two minutes, from the page or the palette.
        #expect(!Self.flat(page.json).contains("pin_copy"))
        #expect(Words.item(h.entries[0]).actions.contains("pin") == false)
        h.togglePin("s")
        #expect(h.entries[0].pinned == false)
    }

    // MARK: Your Mac

    static let heads: [[String: Any]] = [
        ["watcher": "cpu_busy", "title": "Mac working hard", "description": "Tells you when the processor stays very busy, and which app is behind it.", "on": true],
        ["watcher": "app_hog", "title": "An app using a lot", "description": "Tells you when one app takes an unusual share of the processor or memory."],
        ["watcher": "memory_pressure", "title": "Memory tight", "description": "Tells you when macOS runs short of memory and apps may slow down.", "on": true],
        ["watcher": "hot", "title": "Mac running hot", "description": "Tells you when the Mac gets hot enough to slow itself down."],
        ["watcher": "disk_low", "title": "Disk space low", "description": "Tells you once when free space on the startup disk drops below a size."],
        ["watcher": "battery_low", "title": "Battery low", "description": "Tells you once when the battery drops below a level while it isn't plugged in."],
        ["watcher": "battery_health", "title": "Battery worn", "description": "Tells you when the battery's health drops below a level or it reports a fault."],
    ]

    @Test func yourMacInEveryState() throws {
        let healthy = SystemVitalsPlusTests.snapshot(load: 0.18, free: 214e9, battery: SystemVitalsPlusTests.battery(84))
        var noGPU = SystemVitalsPlusTests.snapshot(); noGPU.gpu = nil; noGPU.memory = nil
        let pages: [String: Page] = [
            "mac-healthy": MacPage.make(healthy), "mac-memory": MacPage.make(healthy, appsBy: "memory"), "mac-desktop": MacPage.make(SystemVitalsPlusTests.snapshot()), "mac-sparse": MacPage.make(noGPU),
            "mac-trouble": MacPage.make(SystemVitalsPlusTests.snapshot(load: 0.95, pressure: 4, free: 3e9, battery: SystemVitalsPlusTests.battery(15, health: 0.7), thermal: .serious, days: 20)),
        ]
        for (name, page) in pages { try Self.dump(name, page, title: "Your Mac", ext: "system-vitals-plus", alerts: Self.heads) }

        Self.says(pages["mac-healthy"]!, "Processor", "Memory", "Storage", "Battery", "Top apps", "Temperature", "Download", "Upload", "Uptime", "Heads-ups", "Manage heads-ups",
                  "What's slowing my Mac?", "Should I restart my Mac?", "How do I free up space on my Mac?", "Is my battery healthy?", "Over time", "Memory used", "Battery charge",
                  "Kept by macOS", "Compressed", "Cached files", "Swap", "Pressure", "Free space counts", "Charge cycles", "Health", "Address on this network", "Received since start-up", "This Mac", "Chip", "Cores")
        // No battery: the fourth number is the graphics, and nobody is asked about a battery.
        Self.says(pages["mac-desktop"]!, "Graphics")
        for missing in ["Battery charge", "Is my battery healthy?", "Charge cycles"] { #expect(!Self.flat(pages["mac-desktop"]!.json).contains(missing)) }
        // Without a memory reading: no made-up numbers for it.
        #expect(!Self.flat(pages["mac-sparse"]!.json).contains("Kept by macOS") && !Self.flat(pages["mac-sparse"]!.json).contains("Memory used"))
        // A problem is on the page, with what to do about it.
        Self.says(pages["mac-trouble"]!, "Memory is very tight")
        // Every chart stays in the page, so its past keeps being read.
        let ids = Self.blocks(pages["mac-healthy"]!).compactMap { $0["type"] as? String == "chart" ? $0["id"] as? String : nil }
        #expect(Set(ids) == ["cpu", "memory", "network", "battery"])
    }

    // MARK: Miraya

    @Test func mirayaInEveryState() throws {
        let display2 = Screens.Display(id: 2, name: "External display · 2560 × 1440", size: CGSize(width: 2560, height: 1440))
        let win = [Screens.Window(id: 42, name: "Safari · Apple", app: "Safari", title: "Apple"), Screens.Window(id: 43, name: "Keynote · Presentation", app: "Keynote", title: "Presentation")]
        let target = Session.Target(kind: .display, displayID: 1, label: "Built-in display")
        func sample(_ change: (inout MirayaPage.Now) -> Void = { _ in }) -> MirayaPage.Now {
            MirayaTests.ready { n in
                n.displays.append(display2)
                n.shots = ["display:1": "shots/display-1.png", "display:2": "shots/display-2.png", "window:42": "shots/display-1.png", "window:43": "shots/display-2.png",
                           "area:left": "shots/display-1.png", "area:right": "shots/display-1.png", "area:center": "shots/display-1.png"]
                change(&n)
            }
        }
        let all: [String: MirayaPage.Now] = [
            "notv": MirayaPage.Now(displays: [MirayaTests.display]),
            "ready": sample(), "window": sample { $0.choices.kind = "window"; $0.windows = win }, "nowindow": sample { $0.choices.kind = "window"; $0.windows = [] },
            "windowlocked": sample { $0.choices.kind = "window"; $0.windows = nil },
            "area": sample { $0.choices.kind = "area"; $0.choices.area = "center" },
            "norecord": sample { $0.canRecord = false; $0.shots = [:] },
            "newtv": sample { $0.tv = MirayaTests.bedroom },
            "offline": sample { $0.tv?.online = false },
            "pairing": sample { $0.phase = .pairing; $0.tv = MirayaTests.bedroom; $0.pairingCode = "482731" },
            "authorizing": sample { $0.phase = .authorizing; $0.tv = MirayaTests.bedroom },
            "connecting": sample { $0.phase = .connecting }, "reconnecting": sample { $0.phase = .reconnecting; $0.note = "The network dropped." },
            "sharing": sample { $0.phase = .sharing; $0.target = target; $0.fps = 30; $0.rttMs = 18; $0.picture = "1920 × 1080"; $0.bitrate = 8_000_000; $0.startedAt = Self.now },
            "paused": sample { $0.phase = .paused; $0.target = target },
            "playing": sample { $0.phase = .sharing; $0.mode = .media; $0.mediaTitle = "Film.mp4"; $0.mediaState = "playing"; $0.position = 754; $0.duration = 6310; $0.seekable = true },
            "finished": sample { $0.phase = .paused; $0.mode = .media; $0.mediaTitle = "Film.mp4"; $0.mediaState = "ended" },
            "problem": sample { $0.problem = "The TV didn't answer. Check the network and try again." },
        ]
        let folder = ProcessInfo.processInfo.environment["SIDEFOLK_PAGE_PICTURES"]
        let watchers: [[String: Any]] = [["watcher": "tv_on", "title": "A paired TV is on", "description": "Tells you when Miraya opens on a TV you paired, so you can share to it."],
                                         ["watcher": "ended", "title": "Sharing to the TV ended", "description": "Tells you when sharing or a video on the TV ends without you stopping it."]]
        for (name, n) in all { try Self.dump("miraya-\(name)", MirayaPage.make(n), title: "Miraya", ext: "miraya", alerts: watchers, folder: folder) }
        let page = { (name: String) in MirayaPage.make(all[name]!) }

        Self.says(page("ready"), "Screen", "Window", "Area", "Slow network", "Efficient motion", "Smooth motion", "Mac only", "TV only", "Mac and TV", "Forget", "More picture settings", "detail", "follow_tv",
                  "Play a video on the TV", "play_on_tv", "Connect by address", "pair_tv", "find_tvs", "share_screen", "the microphone is never shared", "temporarily mutes")
        // One way to start, and no way to start while something's under way.
        #expect(Self.flat(page("ready").json).contains("Start sharing"))
        for name in ["pairing", "authorizing", "connecting", "reconnecting", "sharing", "paused"] { #expect(!Self.flat(page(name).json).contains("share_screen"), "\(name)") }
        Self.says(page("pairing"), "482 731", "confirm_pairing", "stop")
        Self.says(page("authorizing"), "Choose Allow on Bedroom", "Cancel")
        Self.says(page("sharing"), "Sending", "Frames dropped on the TV", "Direct and encrypted", "pause", "stop", "quality", "audio_destination", "detail", "follow_tv")
        Self.says(page("paused"), "The TV may keep showing the last picture", "resume")
        #expect(!Self.flat(page("paused").json).contains("Sharing · live"))
        Self.says(page("playing"), "Film.mp4", "seek", "Back 30 seconds")
        Self.says(page("finished"), "Done", "Finished")
        Self.says(page("problem"), "The TV didn't answer", "Try again", "Couldn't share")
        Self.says(page("notv"), "No TV found yet", "Look again", "TV address", "pair_tv")
        Self.says(page("windowlocked"), "list_windows")
        Self.says(page("nowindow"), "No window to share is open.")
        Self.says(page("norecord"), "Screen & System Audio Recording")
        Self.says(page("offline"), "Open Miraya on the TV")
    }
}
