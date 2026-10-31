import AppKit
import Foundation
@testable import SidefolkExtensionKit
import Testing
@testable import ext_clipboard

/// Clipboard as Maccy's replacement (Sidefolk D68): pictures with thumbnails, previews, the ways to search and order,
/// what to leave out, and thousands of copies. Copies go through a pasteboard of the test's own, never the person's.
@MainActor
struct ClipboardHistoryTests {
    static func folder() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent("clip-\(UUID().uuidString)", isDirectory: true) }
    static let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    static func text(_ text: String, at s: Double = 0, app: String? = nil) -> Entry {
        Entry(id: UUID().uuidString, kind: Recognize.kind(text), text: text, source: app, copied: t0.addingTimeInterval(s), first: t0.addingTimeInterval(s))
    }

    /// A made-up screenshot: `size` pixels of one colour, as PNG or TIFF.
    static func picture(_ size: Int, red: CGFloat, tiff: Bool = false) -> Data {
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size * 3 / 4, bitsPerSample: 8, samplesPerPixel: 4,
                                   hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSColor(red: red, green: 0.5, blue: 0.8, alpha: 1).setFill()
        NSRect(x: 0, y: 0, width: size, height: size * 3 / 4).fill()
        NSGraphicsContext.restoreGraphicsState()
        return tiff ? rep.tiffRepresentation! : rep.representation(using: .png, properties: [:])!
    }

    /// A watch over a pasteboard of its own, whose Sidefolk says every copy came from `front`.
    static func watching(_ h: History, front: Source.App?) -> (Watch, NSPasteboard) {
        let board = NSPasteboard(name: NSPasteboard.Name("dev.sidefolk.test.\(UUID().uuidString)"))
        var source: Source!
        source = Source { if let front { source.receive(change: nil, app: front.app, name: front.name) } }
        return (Watch(history: h, source: source, board: board), board)
    }

    @Test func picturesAreKeptOnceWithThumbnails() throws {
        let folder = Self.folder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let h = History(folder: folder)
        let shot = try #require(Pictures.picture(Self.picture(1200, red: 0.2, tiff: true), isPNG: false), "TIFF, as screenshots also come, becomes PNG")
        #expect(shot.width == 1200 && shot.height == 900)
        let thumb = try #require(Pictures.thumbnail(shot.png))
        let small = try #require(NSBitmapImageRep(data: thumb))
        #expect(max(small.pixelsWide, small.pixelsHigh) == Pictures.thumbSide && thumb.count < 64 * 1024)

        func add(_ p: Pictures.Picture, at s: Double) {
            let id = UUID().uuidString
            h.add(Entry(id: id, kind: .image, image: "images/\(id).png", width: p.width, height: p.height, bytes: p.png.count, thumb: "thumbs/\(id).png",
                        digest: p.digest, copied: Self.t0.addingTimeInterval(s), first: Self.t0.addingTimeInterval(s)),
                  files: ["images/\(id).png": p.png, "thumbs/\(id).png": thumb])
        }
        add(shot, at: 0)
        let other = try #require(Pictures.picture(Self.picture(1200, red: 0.9), isPNG: true))
        add(other, at: 10)
        #expect(h.entries.count == 2, "two pictures of one size are two copies")
        add(shot, at: 20)
        #expect(h.entries.count == 2 && h.entries[0].digest == shot.digest && h.entries[0].times == 2, "the same picture moves up")
        #expect(try FileManager.default.contentsOfDirectory(atPath: folder.appendingPathComponent("images").path).count == 2,
                "a picture copied again isn't written again")
        let first = h.entries[0]
        #expect(h.data(first.thumb) != nil && first.image?.hasPrefix("images/") == true)

        // What the palette and Sidefolk get: the thumbnail by its name in the data folder, the picture for the preview.
        let item = Words.item(first)
        #expect(item.image == first.thumb && item.json["image"] as? String == first.thumb)
        let preview = Words.preview(first, now: Self.t0.addingTimeInterval(30))
        #expect(preview.image == first.image && preview.facts.contains { $0.0 == "Copies" && $0.1 == "2" })

        h.delete(first.id)
        #expect(h.data(first.thumb) == nil && h.data(first.image) == nil, "a deleted picture's files go with it")
    }

    @Test func searchWaysOrdersAndPinPlaces() {
        let h = History(folder: Self.folder())
        defer { try? FileManager.default.removeItem(at: h.folder) }
        h.add(Self.text("git status --short", at: 0, app: "Terminal"))
        h.add(Self.text("Café au lait at 9", at: 10, app: "Notes"))
        h.add(Self.text("https://example.com/status", at: 20, app: "Safari"))
        h.add(Self.text("git status --short", at: 30, app: "Terminal"))
        #expect(h.find("cafe")?.map(\.text) == ["Café au lait at 9"], "accents and case don't matter")
        #expect(h.find("status git")?.count == 1, "words: all of them, in any order")
        h.set { $0.search = .exact }
        #expect(h.find("status git")?.isEmpty == true && h.find("git status")?.count == 1)
        h.set { $0.search = .fuzzy }
        #expect(h.find("gtst")?.map(\.text) == ["git status --short"])
        #expect(h.find("status")?.first?.text == "git status --short", "close matches before loose ones, in order")
        h.set { $0.search = .regex }
        #expect(h.find("^https?://")?.count == 1 && h.find("([") == nil, "a pattern that isn't one says so")

        #expect(h.ordered().map(\.text).first == "git status --short")
        h.set { $0.sort = .count }
        #expect(h.ordered().first?.times == 2)
        h.set { $0.sort = .first }
        #expect(h.ordered().first?.text == "https://example.com/status", "the newest first copy")
        h.togglePin(h.entries.first { $0.text == "Café au lait at 9" }!.id)
        #expect(h.ordered().first?.pinned == true)
        h.set { $0.pins = .bottom }
        #expect(h.ordered().last?.pinned == true)
        let items = Words.list(h.ordered(), h: h)
        #expect(items.map(\.section) == ["History", "History", "Pinned"], "pins have a section of their own, where the person put them")
    }

    @Test func rulesLeaveOutWhatThePersonSaid() async throws {
        let h = History(folder: Self.folder())
        defer { try? FileManager.default.removeItem(at: h.folder) }
        let (watch, board) = Self.watching(h, front: Source.App(app: "com.apple.Notes", name: "Notes"))

        board.clearContents()
        board.setString("Ship on Friday", forType: .string)
        board.setData(Data(#"{\rtf1\ansi {\b Ship} on Friday}"#.utf8), forType: .rtf)
        board.setData(Data("<b>Ship</b> on Friday".utf8), forType: .html)
        await watch.check(now: Self.t0)
        let note = try #require(h.entries.first)
        #expect(note.source == "Notes" && note.app == "com.apple.Notes", "Sidefolk said which app was in front")
        #expect(h.data(note.rtfFile) != nil && h.data(note.htmlFile) != nil, "formatting kept beside the history, not in it")
        #expect(Words.item(note).actions.contains("plain"))

        // Written back with its formatting, or plain; Sidefolk's own write isn't a new copy.
        watch.write(note, plain: true)
        #expect(board.data(forType: .rtf) == nil && board.string(forType: .string) == "Ship on Friday")
        watch.write(note, plain: false)
        #expect(board.data(forType: .rtf) != nil && board.data(forType: .html) != nil)
        await watch.check(now: Self.t0.addingTimeInterval(1))
        #expect(h.entries.count == 1 && h.entries[0].times == 1)

        h.set { $0.ignoredApps = ["notes"] }
        board.clearContents()
        board.setString("from an ignored app", forType: .string)
        await watch.check(now: Self.t0.addingTimeInterval(2))
        #expect(h.entries.count == 1, "an app is matched by its name or bundle id, in any case")

        h.set {
            $0.ignoredApps = []
            $0.ignoredPatterns = [#"^\d{6}$"#]
        }
        board.clearContents()
        board.setString("482913", forType: .string)
        await watch.check(now: Self.t0.addingTimeInterval(3))
        #expect(h.entries.count == 1, "a one-time code matching the person's pattern isn't kept")

        h.set { $0.skipNext = true }
        board.clearContents()
        board.setString("my password, copied once", forType: .string)
        await watch.check(now: Self.t0.addingTimeInterval(4))
        #expect(h.entries.count == 1 && !h.options.skipNext, "skipped once, then keeping again")

        board.clearContents()
        board.setString("from 1Password", forType: .string)
        board.setData(Data(), forType: NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"))
        await watch.check(now: Self.t0.addingTimeInterval(5))
        h.set { $0.ignoredTypes = ["com.apple.is-remote-clipboard"] }
        board.clearContents()
        board.setString("from the iPhone", forType: .string)
        board.setData(Data(), forType: NSPasteboard.PasteboardType("com.apple.is-remote-clipboard"))
        await watch.check(now: Self.t0.addingTimeInterval(6))
        #expect(h.entries.count == 1, "concealed copies, and types the person named, are left out")

        board.clearContents()
        board.setData(Self.picture(800, red: 0.4), forType: .png)
        await watch.check(now: Self.t0.addingTimeInterval(7))
        let shot = try #require(h.entries.first)
        #expect(shot.kind == .image && shot.width == 800 && h.data(shot.thumb) != nil && shot.source == "Notes")
        h.set { $0.keepImages = false }
        board.clearContents()
        board.setData(Self.picture(640, red: 0.7), forType: .png)
        await watch.check(now: Self.t0.addingTimeInterval(8))
        #expect(h.entries.count == 2, "pictures can be left out")

        board.clearContents()
        board.writeObjects([URL(fileURLWithPath: "/Users/someone/Documents/report.pdf") as NSURL])
        await watch.check(now: Self.t0.addingTimeInterval(9))
        #expect(h.entries.first?.kind == .file && h.entries.first?.files == ["/Users/someone/Documents/report.pdf"])
    }

    @Test func withoutAnAnswerACopyIsStillKept() async {
        let h = History(folder: Self.folder())
        defer { try? FileManager.default.removeItem(at: h.folder) }
        let (watch, board) = Self.watching(h, front: nil)
        board.clearContents()
        board.setString("Sidefolk isn't answering", forType: .string)
        board.setString("com.apple.Safari", forType: NSPasteboard.PasteboardType("org.nspasteboard.source"))
        await watch.check(now: Self.t0)
        #expect(h.entries.first?.source == "Safari" && h.entries.first?.app == "com.apple.Safari", "the app's own word on the clipboard")
    }

    @Test func settingsAndIgnoreRulesThroughTheirTools() throws {
        let h = History(folder: Self.folder())
        defer { try? FileManager.default.removeItem(at: h.folder) }
        for i in 0..<120 { h.add(Self.text("copy \(i)", at: Double(i))) }
        _ = try Settings.set(Arguments(["option": "limit", "value": "100"]), h)
        #expect(h.options.limit == 100 && h.entries.count == 100, "a smaller limit trims at once")
        #expect(throws: Problem.self) { try Settings.set(Arguments(["option": "limit", "value": "7"]), h) }
        _ = try Settings.set(Arguments(["option": "paste", "value": "copy"]), h)
        _ = try Settings.set(Arguments(["option": "plain", "value": "remove"]), h)
        _ = try Settings.set(Arguments(["option": "keep_files", "on": false]), h)
        #expect(!h.options.paste && h.options.plain && !h.options.keepFiles)
        #expect(Words.note(h).contains("↩ copies, ⌥↩ pastes"))

        _ = try Settings.ignore(Arguments(["app": "com.apple.Safari"]), h)
        _ = try Settings.ignore(Arguments(["pattern": #"^\d{6}$"#]), h)
        #expect(h.options.ignoredApps == ["com.apple.Safari"] && h.options.ignoredPatterns.count == 1)
        #expect(throws: Problem.self) { try Settings.ignore(Arguments(["pattern": "(["]), h) }
        _ = try Settings.ignore(Arguments(["app": "COM.APPLE.SAFARI", "on": false]), h)
        #expect(h.options.ignoredApps.isEmpty)

        // Saved and read back by a new start; a history written before these settings existed reads with defaults.
        h.saveNow()
        let again = History(folder: h.folder)
        #expect(again.options == h.options && again.entries.count == 100)
        let old = try JSONDecoder.history.decode(Options.self, from: Data(#"{"keeping": false, "hideSecrets": true, "limit": 200}"#.utf8))
        #expect(!old.keeping && old.limit == 200 && old.paste && old.sort == .recent && old.ignoredApps.isEmpty)
    }

    @Test func aHistoryFromTheFirstVersionIsBroughtUpToDate() throws {
        let folder = Self.folder()
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder.appendingPathComponent("images"), withIntermediateDirectories: true)
        try Self.picture(600, red: 0.3).write(to: folder.appendingPathComponent("images/old.png"))
        let rtf = Data(#"{\rtf1 hi}"#.utf8).base64EncodedString()
        let json = """
            {"entries": [{"id": "a", "kind": "text", "text": "hi", "rtf": "\(rtf)", "copied": "2026-10-30T10:00:00Z", "times": 1, "pinned": false, "secret": false},
                         {"id": "b", "kind": "image", "image": "old.png", "width": 600, "height": 450, "copied": "2026-10-30T09:00:00Z", "times": 1,
                          "pinned": true, "secret": false}],
             "options": {"keeping": true, "hideSecrets": true, "limit": 500}}
            """
        try Data(json.utf8).write(to: folder.appendingPathComponent("history.json"))
        let h = History(folder: folder)
        #expect(h.entries[0].rtfFile == "rich/a.rtf" && h.data(h.entries[0].rtfFile) == Data(#"{\rtf1 hi}"#.utf8))
        #expect(h.entries[1].image == "images/old.png" && h.data(h.entries[1].thumb) != nil && h.entries[1].digest != nil)
        #expect(!(try String(contentsOf: h.file, encoding: .utf8)).contains("\"rtf\""), "formatting moved out of the list")
    }

    @Test func thousandsOfCopiesStayQuick() throws {
        struct Stored: Encodable { var entries: [Entry]; var options: Options }
        let folder = Self.folder()
        defer { try? FileManager.default.removeItem(at: folder) }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var options = Options()
        options.limit = 5000
        let words = ["meeting", "invoice", "deploy", "kubectl", "recipe", "address", "flight", "password reset", "lorem ipsum dolor"]
        let entries = (0..<5000).reversed().map { i in
            Self.text("\(words[i % words.count]) number \(i) " + String(repeating: "filler text ", count: i % 40), at: Double(i))
        }
        try JSONEncoder.history.encode(Stored(entries: entries, options: options)).write(to: folder.appendingPathComponent("history.json"))
        let clock = ContinuousClock()
        var loaded: History?
        let loading = clock.measure { loaded = History(folder: folder) }
        let h = try #require(loaded)
        #expect(h.entries.count == 5000 && loading < .milliseconds(800), "loading 5,000 copies took \(loading)")
        let adding = clock.measure { h.add(Self.text("one more", at: 9999)) }
        #expect(adding < .milliseconds(100), "a new copy over 5,000 took \(adding)")
        _ = h.find("x")
        let typing = clock.measure {
            for q in ["d", "de", "dep", "depl", "deplo", "deploy", "deploy 4"] { _ = h.find(q) }
        }
        #expect(typing < .milliseconds(700), "seven keystrokes over 5,000 copies took \(typing)")
        h.set { $0.search = .fuzzy }
        let fuzzy = clock.measure { _ = h.find("dply") }
        #expect(fuzzy < .milliseconds(300), "fuzzy over 5,000 copies took \(fuzzy)")
        let saving = clock.measure { h.saveNow() }
        #expect(saving < .milliseconds(500), "saving 5,000 copies took \(saving)")
        let list = clock.measure { _ = PaletteList(Words.list(h.find("") ?? [], h: h)).json }
        #expect(list < .milliseconds(150), "a palette list took \(list)")
    }

    @Test func thePageHoldsTheSettingsAndThePictures() throws {
        let h = History(folder: Self.folder())
        defer { try? FileManager.default.removeItem(at: h.folder) }
        h.add(Entry(id: "p", kind: .image, image: "images/p.png", width: 10, height: 10, thumb: "thumbs/p.png", digest: "d", source: "Safari",
                    app: "com.apple.Safari", copied: Self.t0), files: ["images/p.png": Data([1]), "thumbs/p.png": Data([1])])
        h.add(Self.text("#2ED4D9", at: 5))
        let json = ClipboardPage.make(h, now: Self.t0.addingTimeInterval(60)).json
        let blocks = (json["sections"] as? [[String: Any]] ?? []).flatMap { $0["blocks"] as? [[String: Any]] ?? [] }
        let types = Set(blocks.compactMap { $0["type"] as? String })
        #expect(types.isSuperset(of: ["switch", "button", "list", "choice", "field", "stat"]))
        let rows = blocks.first { $0["type"] as? String == "list" }?["items"] as? [[String: Any]] ?? []
        #expect(rows.contains { $0["image"] as? String == "thumbs/p.png" } && rows.contains { $0["color"] as? String == "#2ED4D9" })
        #expect(blocks.contains { $0["type"] as? String == "switch" && ($0["label"] as? String) == "Ignore Safari" })
        let data = try JSONSerialization.data(withJSONObject: json)
        #expect(data.count < 128 * 1024, "within Sidefolk's page limit")
    }
}
