import Foundation
import Testing
@testable import ext_prayer_times
@testable import SidefolkExtensionKit

/// The host keeps a scene area only if its id is a small lowercase name, and runs only `go` or a tool from one: anything else is dropped without a word, its row dead and its VoiceOver label gone.
/// So every page Noor can draw is rendered here, on saved answers in a temp folder (`NoorDebug`'s fixtures, never the network), and its JSON read as the host reads it.
@MainActor @Suite(.serialized) struct NoorSceneTests {
    typealias S = NoorSupport

    private static let idPattern = #"^[a-z0-9][a-z0-9_-]{0,39}$"#
    private static let dropped = ["allow", "settings", "copy", "file"]
    private static let widths = [1054.0, 640.0]

    // MARK: Reading a page

    private struct Report {
        var problems: Set<String> = []
        var areas: Set<String> = []
    }

    /// Every scene anywhere in the page's JSON, with what the host would do with its areas.
    private static func read(_ json: Any, where place: String, into report: inout Report) {
        if let list = json as? [Any] {
            for item in list { read(item, where: place, into: &report) }
            return
        }
        guard let object = json as? [String: Any] else { return }
        if object["type"] as? String == "scene", let scene = object["scene"] {
            let actions = object["actions"] as? [String: Any] ?? [:]
            for (id, action) in actions {
                for word in dropped where (action as? [String: Any])?[word] != nil {
                    report.problems.insert("\(id): .\(word) on an area is dropped (\(place))")
                }
            }
            visitAreas(scene) { area in
                let id = area["id"] as? String ?? ""
                report.areas.insert(id)
                if id.range(of: idPattern, options: .regularExpression) == nil { report.problems.insert("\(id): not a name the host keeps (\(place))") }
                if area["disabled"] as? Bool != true, actions[id] == nil { report.problems.insert("\(id): no action (\(place))") }
            }
        }
        for value in object.values { read(value, where: place, into: &report) }
    }

    private static func visitAreas(_ json: Any, _ found: ([String: Any]) -> Void) {
        if let list = json as? [Any] {
            for item in list { visitAreas(item, found) }
        } else if let object = json as? [String: Any] {
            if let area = object["area"] as? [String: Any] { found(area) }
            for value in object.values { visitAreas(value, found) }
        }
    }

    private func check(_ model: NoorModel, _ state: [String: Any], named name: String, into report: inout Report) async {
        for width in Self.widths {
            let args = Arguments(["state": state, "width": width])
            // A first reading may only have started what the page needs; the second shows it.
            _ = await NoorPage.render(args, model: model)
            let page = await NoorPage.render(args, model: model)
            Self.read(page.json, where: "\(name) at \(Int(width))", into: &report)
        }
    }

    // MARK: Setting a folder up

    private static let saved = [
        ("names", "asmaAlHusna"), ("calendar-methods", "islamicCalendar_methods"), ("prayer-methods", "methods"), ("qibla-tokyo", "qibla_35.6762_139.6503"),
        ("gregorian-month", "gToHCalendar_11_2026"), ("prayer-day", "timings_02-11-2026"), ("ramadan-month", "hijriCalendar_1448_9"), ("listed-occasions", "islamicHolidaysByHijriYear_1448"),
    ]

    /// A folder whose network answers from the saved answers and nothing else, at noon on the day they are for.
    private func folder(network: String = "fixtures", now: String = "2026-11-02T03:00:00Z") throws -> URL {
        let folder = S.temporaryFolder(), answers = folder.appending(path: "debug-fixtures")
        try FileManager.default.createDirectory(at: answers, withIntermediateDirectories: true)
        for (fixture, name) in Self.saved {
            try S.fixture(fixture).write(to: answers.appending(path: "\(name).json"))
        }
        try network.write(to: folder.appending(path: "debug-network.txt"), atomically: true, encoding: .utf8)
        try now.write(to: folder.appending(path: "debug-now.txt"), atomically: true, encoding: .utf8)
        return folder
    }

    private func calculated(_ folder: URL) throws -> NoorModel {
        let model = NoorModel(folder: folder)
        try model.commit(place: S.tokyo, sourceID: S.tokyoSource.id, sources: [S.tokyoSource]) { $0.convention = S.mwl }
        return model
    }

    /// A mosque's own timetable for November, as `save_manual` keeps one.
    private func mosque(_ folder: URL, from: String = "2026-11-01", to: String = "2026-11-30") throws -> NoorModel {
        let model = NoorModel(folder: folder)
        let starts = ["fajr": "05:12", "dhuhr": "11:37", "asr": "14:39", "maghrib": "17:42", "isha": "19:02"]
        let review = try #require(SourcePage.manualReview(name: "Hira Mosque", zone: "Asia/Tokyo", from: from, to: to, starts: starts, iqamah: ["fajr": "05:30", "maghrib": "17:50", "isha": "19:30"]))
        let table = try #require(review.timetable(id: "manual.test", attribution: "Hira Mosque"))
        try model.commit(place: S.tokyo, sourceID: table.source.id, sources: [S.tokyoSource, table.source], timetable: table)
        return model
    }

    private func expectClean(_ report: Report, _ needed: Set<String> = [], sourceLocation: SourceLocation = #_sourceLocation) {
        let list = report.problems.sorted().joined(separator: "\n")
        #expect(report.problems.isEmpty, "\(report.problems.count) scene problems:\n\(list)", sourceLocation: sourceLocation)
        // A page that drew nothing would pass all of the above.
        #expect(needed.isSubset(of: report.areas), "missing: \(needed.subtracting(report.areas).sorted())", sourceLocation: sourceLocation)
    }

    // MARK: The pages

    @Test func everyTabAndSheetOfCalculatedTimes() async throws {
        let model = try calculated(folder())
        var report = Report()
        for tab in NoorTab.allCases { await check(model, ["tab": tab.rawValue], named: "tab \(tab.rawValue)", into: &report) }
        #expect(model.snapshot().validity == .ready, "the saved answers should make a ready page")
        await check(model, ["tab": "prayer", "select": "fajr"], named: "a picked row", into: &report)
        await check(model, ["tab": "prayer", "day": "2026-11-03"], named: "another date", into: &report)
        for section in PreferencesPage.tabs { await check(model, ["sheet": "prefs", "section": section.id], named: "preferences \(section.id)", into: &report) }
        await check(model, ["sheet": "ramadan"], named: "Ramadan", into: &report)
        await check(model, ["sheet": "ramadan", "r_more": true, "r_suhoor": "20", "r_iftar": true], named: "Ramadan with a draft", into: &report)
        await check(model, ["sheet": "convert"], named: "convert", into: &report)
        await check(model, ["sheet": "occasions"], named: "occasions", into: &report)
        await check(model, ["sheet": "manual"], named: "a timetable by hand", into: &report)
        await check(model, ["sheet": "name", "name": 1], named: "a Name", into: &report)
        await check(model, ["tab": "names", "name": 1], named: "Names, one open", into: &report)
        await check(model, ["tab": "calendar", "sel": "2026-11-07"], named: "a day with an occasion", into: &report)
        model.review = ("Hira", CSVImport.parse(data: Data(CSVImport.template.utf8), name: "Hira"))
        await check(model, ["sheet": "import"], named: "an import", into: &report)
        expectClean(report, ["tab-prayer", "row-fajr", "bell-fajr", "prev", "reminders"])
    }

    @Test func aMosquesTimetableInFocus() async throws {
        var report = Report()
        // Between a start and its iqamah, past the last start, and with nothing held at all.
        for (now, name) in [("2026-11-03T08:44:00Z", "between"), ("2026-11-03T10:10:00Z", "after Isha"), ("2026-11-03T00:00:00Z", "morning")] {
            let model = try mosque(folder(now: now))
            for tab in NoorTab.allCases { await check(model, ["tab": tab.rawValue], named: "\(name), tab \(tab.rawValue)", into: &report) }
            await check(model, ["tab": "prayer", "full": true], named: "\(name), the whole ledger", into: &report)
            await check(model, ["sheet": "prefs", "section": "sources"], named: "\(name), sources", into: &report)
            await check(model, ["sheet": "prefs", "section": "reminders"], named: "\(name), reminders", into: &report)
            await check(model, ["sheet": "ramadan"], named: "\(name), Ramadan", into: &report)
        }
        expectClean(report, ["col-maghrib", "full", "source", "row-isha"])
    }

    @Test func beforeSetUp() async throws {
        let model = NoorModel(folder: try folder())
        var report = Report()
        for tab in NoorTab.allCases { await check(model, ["tab": tab.rawValue], named: "no place, tab \(tab.rawValue)", into: &report) }
        await check(model, ["setup": "place"], named: "choosing a place", into: &report)
        await check(model, ["sheet": "manual"], named: "no place, a timetable by hand", into: &report)
        await check(model, ["sheet": "prefs", "section": "place"], named: "no place, preferences", into: &report)
        try model.commit(place: S.tokyo, sourceID: nil, sources: [])
        for tab in NoorTab.allCases { await check(model, ["tab": tab.rawValue], named: "no timetable, tab \(tab.rawValue)", into: &report) }
        await check(model, ["setup": "source"], named: "choosing a timetable", into: &report)
        model.review = ("Hira", CSVImport.parse(data: Data(CSVImport.template.utf8), name: "Hira"))
        await check(model, ["sheet": "import"], named: "a first import", into: &report)
        expectClean(report)
    }

    @Test func whenThingsGoWrong() async throws {
        var report = Report()
        for network in ["offline", "malformed"] {
            let model = try calculated(folder(network: network))
            for tab in NoorTab.allCases { await check(model, ["tab": tab.rawValue], named: "\(network), tab \(tab.rawValue)", into: &report) }
            await check(model, ["sheet": "ramadan"], named: "\(network), Ramadan", into: &report)
        }
        let ended = try mosque(folder(now: "2027-01-15T03:00:00Z"))
        #expect(ended.snapshot().validity == .expired)
        let early = try mosque(folder(now: "2026-10-15T03:00:00Z"))
        #expect(early.snapshot().validity == .notStarted)
        for (model, name) in [(ended, "ended"), (early, "not started")] {
            for tab in NoorTab.allCases { await check(model, ["tab": tab.rawValue], named: "\(name), tab \(tab.rawValue)", into: &report) }
        }
        let broken = try folder()
        try Data("not json".utf8).write(to: broken.appending(path: "preferences.json"))
        let unreadable = NoorModel(folder: broken)
        #expect(unreadable.unreadable != nil)
        await check(unreadable, ["tab": "overview"], named: "unreadable preferences", into: &report)
        expectClean(report)
    }

    /// What Sidefolk has said yes or no to: each way of asking it is a place a dropped act would leave someone stuck.
    @Test func everyAnswerSidefolkCanGive() async throws {
        let tokyoShared: [String: Any] = ["city": "Tokyo", "country": "Japan", "latitude": 35.6762, "longitude": 139.6503, "timeZone": "Asia/Tokyo"]
        let tellings: [(String, [String: Any], [String: Any])] = [
            ("nothing allowed", ["place_share": "off"], ["allowed": false, "notifications": "denied"]),
            ("place shared but unknown", ["place_share": "on"], ["allowed": true, "notifications": "denied"]),
            ("place shared", ["place_share": "on", "place": tokyoShared], ["allowed": true, "notifications": "allowed"]),
        ]
        defer {
            SharedPlace.use(["place_share": "off"])
            Occurrences.use(["occurrences": ["allowed": false]])
        }
        var report = Report()
        for (name, place, occurrences) in tellings {
            SharedPlace.use(place)
            Occurrences.use(["occurrences": occurrences])
            let model = try calculated(folder())
            for section in PreferencesPage.tabs {
                await check(model, ["sheet": "prefs", "section": section.id, "rm_master": true, "rm_system": true, "rm_fajr_at": true], named: "\(name), preferences \(section.id)", into: &report)
            }
            await check(model, ["sheet": "ramadan", "r_iftar": true], named: "\(name), Ramadan", into: &report)
            let first = NoorModel(folder: try folder())
            await check(first, ["tab": "overview"], named: "\(name), welcome", into: &report)
            await check(first, ["setup": "place"], named: "\(name), choosing a place", into: &report)
        }
        expectClean(report)
    }

    /// So a green run means something: what the host drops is seen.
    @Test func theReadingSeesWhatTheHostDrops() {
        let scene = Scene(width: 100, height: 100) {
            Node.rect(fill: .hex("#000000")).size(10, 10).at(0, 0).area("row.fajr", label: "dotted")
            Node.rect(fill: .hex("#000000")).size(10, 10).at(0, 0).area("allow", label: "consent")
            Node.rect(fill: .hex("#000000")).size(10, 10).at(0, 0).area("nothing", label: "no action")
            Node.rect(fill: .hex("#000000")).size(10, 10).at(0, 0).area("fine", label: "goes")
            Node.rect(fill: .hex("#000000")).size(10, 10).at(0, 0).area("off", label: "disabled", disabled: true)
        }
        let block = PageSceneBlock(scene, acts: ["row.fajr": .go(Go(set: ["select": "fajr"])), "allow": .allow("place"), "fine": .go(Go(set: ["tab": "prayer"]))])
        var report = Report()
        Self.read(Page(summary: Summary("x"), sections: [Section(nil, [.scene(block)], wide: true)]).json, where: "test", into: &report)
        #expect(report.problems == ["row.fajr: not a name the host keeps (test)", "allow: .allow on an area is dropped (test)", "nothing: no action (test)"])
        #expect(report.areas == ["row.fajr", "allow", "nothing", "fine", "off"])
    }
}
