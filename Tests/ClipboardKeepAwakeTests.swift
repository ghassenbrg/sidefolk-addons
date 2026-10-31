import Foundation
import Testing
@testable import ext_clipboard
@testable import ext_keep_awake
@testable import SidefolkExtensionKit

/// Clipboard and Keep Awake with made-up copies, clocks and batteries: nothing here reads the clipboard or holds the
/// Mac awake. Their sandbox runs are in Sidefolk's ExtensionServiceTests.
@MainActor
struct ClipboardKeepAwakeTests {
    @Test func copiesAreRecognized() {
        #expect(Recognize.kind("https://example.com/a?b=1") == .link && Recognize.kind("mailto:pip@example.com") == .link)
        #expect(Recognize.kind("#2ED4D9") == .color && Recognize.kind("rgb(46, 212, 217)") == .color)
        #expect(Recognize.kind("func hello() {\n    print(\"hi\")\n}") == .code && Recognize.kind("git status") == .code)
        #expect(Recognize.kind("Meeting notes: ship on Friday") == .text && Recognize.kind("example.com is down") == .text)
    }

    @Test func secretsAreGuessedCarefully() {
        for secret in ["sk-proj-abcdefghij1234567890ABCDEFG", "ghp_abcdefghijklmnopqrstuvwxyz0123456789", "AKIAIOSFODNN7EXAMPLE",
                       "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxIn0.c2lnbmF0dXJl", "4242 4242 4242 4242", "Tr0ub4dor&3xyzQ!",
                       "-----BEGIN OPENSSH PRIVATE KEY-----\nabc\n-----END OPENSSH PRIVATE KEY-----"] {
            #expect(Recognize.isSecret(secret), "\(secret)")
        }
        for plain in ["hello", "Meeting notes: ship on Friday", "https://github.com/ghassenbrg/sidefolk", "pip@example.com",
                      "4242 4242 4242 4241", "SidefolkVersion", "2026-10-31", "/Users/me/Documents/report.pdf"] {
            #expect(!Recognize.isSecret(plain), "\(plain)")
        }
    }

    @Test func theHistoryKeepsOrderPinsAndForgetsSecrets() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("clip-\(UUID().uuidString)")
        let h = History(folder: folder)
        let t0 = Date(timeIntervalSince1970: 1_800_000_000)
        func copy(_ text: String, at s: Double, secret: Bool = false) -> Entry {
            Entry(id: UUID().uuidString, kind: Recognize.kind(text), text: text, copied: t0.addingTimeInterval(s), secret: secret)
        }
        h.add(copy("first", at: 0))
        h.add(copy("https://example.com", at: 10))
        h.add(copy("first", at: 20))
        #expect(h.entries.map(\.text) == ["first", "https://example.com"], "the same copy moves up, not twice")
        #expect(h.entries[0].times == 2)
        h.togglePin(h.entries[1].id)
        #expect(h.search("").map(\.text) == ["https://example.com", "first"], "pinned first")
        #expect(h.search("EXAMPLE").map(\.text) == ["https://example.com"] && h.search("link").count == 1)

        h.add(copy("sk-proj-abcdefghij1234567890ABCDEFG", at: 30, secret: true))
        #expect(h.search("sk-proj").isEmpty, "a secret's text is never searched")
        h.saveNow()
        let stored = try String(contentsOf: h.file, encoding: .utf8)
        #expect(!stored.contains("sk-proj"), "secrets never reach the disk")
        #expect(h.expireSecrets(now: t0.addingTimeInterval(30 + History.secretLife + 1)))
        #expect(!h.entries.contains { $0.secret })

        h.clear()
        #expect(h.entries.map(\.text) == ["https://example.com"], "pinned copies stay")
        let again = History(folder: folder)
        #expect(again.entries.map(\.text) == ["https://example.com"] || again.entries.count >= 1)
        try? FileManager.default.removeItem(at: folder)
    }

    @Test func copiesReadWell() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let code = Entry(id: "1", kind: .code, text: "func a() {\n}\n", source: "Xcode", copied: now.addingTimeInterval(-300))
        #expect(Words.title(code) == "func a() {" && Words.detail(code, now: now) == "Xcode · 5 min ago · 2 lines")
        let files = Entry(id: "2", kind: .file, files: ["/a/one.pdf", "/a/two.png", "/a/three.txt", "/a/four.md"], copied: now)
        #expect(Words.title(files) == "one.pdf, two.png and 2 more")
        let secret = Entry(id: "3", kind: .text, text: "hunter2hunter2", copied: now, secret: true)
        #expect(!Words.title(secret).contains("hunter") && Words.detail(secret, now: now).contains("forgotten in"))
        #expect(Words.item(code).actions == ["pin", "delete"])
    }

    @Test func keepAwakeLetsGoWhenItShould() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        var s = Session(started: now, until: now.addingTimeInterval(600))
        #expect(Rules.hold(s, now: now, plugged: true, battery: 80, appOpen: nil) == .holding)
        #expect(Rules.hold(s, now: now.addingTimeInterval(601), plugged: true, battery: 80, appOpen: nil) == .ended("Its time is up."))
        #expect(Rules.hold(s, now: now, plugged: false, battery: 10, appOpen: nil) == .waiting("The battery is below 15%, so it's letting the Mac rest."))
        s.pluggedOnly = true
        #expect(Rules.hold(s, now: now, plugged: false, battery: 90, appOpen: nil) == .waiting("Waiting to be plugged in."))
        s.whileApp = "Zoom"
        #expect(Rules.hold(s, now: now, plugged: true, battery: 90, appOpen: false) == .ended("Zoom quit."))
        // A desktop Mac has no battery: nothing to wait for.
        #expect(Rules.hold(Session(started: now), now: now, plugged: nil, battery: nil, appOpen: nil) == .holding)
    }

    /// The main switch rides on the summary (Sidefolk D67), so it shows on the Today tile and the sidebar; the time left
    /// leads the detail. Read without starting anything: no power assertion is taken here.
    @Test func keepAwakesMainSwitchAndTimeLeft() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("ka-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let page = AwakePage.make(Keeper(folder: folder)).json
        let summary = try #require(page["summary"] as? [String: Any])
        let control = try #require(summary["control"] as? [String: Any])
        #expect(control["type"] as? String == "switch" && control["tool"] as? String == "keep_awake" && control["on"] as? Bool == false)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let s = Session(started: now, until: now.addingTimeInterval(25 * 60))
        #expect(AwakePage.detail(s, nudges: 0, now: now).hasPrefix("25 min left · "))
    }

    @Test func keepAwakeNudgesOnlyWhenIdleAndReadsTimes() throws {
        #expect(!Rules.shouldNudge(idle: 10, sinceLast: 300, jitter: 0), "never while the person is using the Mac")
        #expect(Rules.shouldNudge(idle: 60, sinceLast: 55, jitter: 0) && !Rules.shouldNudge(idle: 60, sinceLast: 55, jitter: 1))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let day = 1_800_000_000 - 1_800_000_000 % 86_400
        let morning = Date(timeIntervalSince1970: Double(day + 9 * 3600)) // 09:00 UTC
        let six = try #require(Rules.time("until 6pm", now: morning, calendar: calendar))
        #expect(six.timeIntervalSince(morning) == 9 * 3600)
        let early = try #require(Rules.time("8:30", now: morning, calendar: calendar))
        #expect(early.timeIntervalSince(morning) == 23.5 * 3600, "a time already past today is tomorrow's")
        #expect(Rules.time("25:00", now: morning) == nil && Rules.time("lunch", now: morning) == nil && Rules.time("13pm", now: morning) == nil)
        #expect(Rules.left(morning.addingTimeInterval(5400), now: morning) == "1 h 30 min")
    }
}
