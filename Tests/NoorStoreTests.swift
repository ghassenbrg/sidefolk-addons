import Foundation
import Testing
@testable import ext_prayer_times

/// Noor's files in a temporary folder: what survives, what is refused, what each scope reaches.
struct NoorStoreTests {
    typealias S = NoorSupport

    let folder = S.temporaryFolder()
    private var store: NoorStore { NoorStore(folder: folder) }

    private func file(_ path: String) -> URL { folder.appending(path: path) }

    private func put(_ text: String, _ path: String) throws {
        try FileManager.default.createDirectory(at: file(path).deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: file(path))
    }

    private func manualTable() throws -> ManualTimetable {
        let review = CSVImport.parse(data: Data(CSVImport.template.utf8), name: "Mosque")
        return try #require(review.timetable(id: "manual.mosque", attribution: "Board"))
    }

    @Test func nothingSavedIsNotAnError() throws {
        #expect(store.preferences() == .absent && store.sources() == .absent && store.bookmarks() == .absent && store.timetable(sourceID: "x") == .absent)
    }

    @Test func documentsRoundTrip() throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        var prefs = Preferences()
        prefs.place = S.tokyo
        prefs.sourceID = "calculated.tokyo"
        prefs.convention = try PrayerConvention(method: 3, school: 1, latitudeAdjustment: 2, tune: [.fajr: 2])
        prefs.calendarMethod = .diyanet
        prefs.timeFormat = .hour24
        prefs.reminders.master = true
        prefs.reminders.prayers[.fajr] = .init(beforeMinutes: 10, atStart: true, iqamahMinutes: 5)
        prefs.reminders.pausedUntil = Date(timeIntervalSince1970: 1_793_570_400.25)
        prefs.reminders.ramadan = .init(enabled: true, days: [1, 2], suhoorMinutesBeforeFajr: 30, iftar: true)
        prefs.reminders.occasions = .init(selected: ["ashura"], daysBefore: 2, time: LocalTime(hour: 8, minute: 0)!)
        prefs.reminders.nameOfDay = .init(enabled: true, hour: 8, minute: 30)
        try store.save(prefs)
        #expect(store.preferences() == .ok(prefs))

        let sources = [S.tokyoSource, TimetableSource(id: "manual.m", kind: .manual, name: "M", zoneID: "Asia/Tokyo", coverage: S.date("2026-11-01")...S.date("2026-11-30"), revision: 3, attribution: "Board", lastFetch: Date(timeIntervalSince1970: 7))!]
        try store.save(sources: sources)
        #expect(store.sources() == .ok(sources))

        let table = try manualTable()
        try store.save(table)
        #expect(store.timetable(sourceID: "manual.mosque") == .ok(table))
        try store.deleteTimetable(sourceID: "manual.mosque")
        #expect(store.timetable(sourceID: "manual.mosque") == .absent)

        try store.save(bookmarks: [1, 99])
        #expect(store.bookmarks() == .ok([1, 99]))
        let text = try String(contentsOf: file("bookmarks.json"), encoding: .utf8)
        #expect(!text.contains("Rahmaan"), "numbers only")
    }

    @Test func preferencesDecodeFromAStableEnvelope() throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        try store.save(Preferences())
        let object = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: file("preferences.json"))) as? [String: Any])
        #expect(object["version"] as? Int == Preferences.schemaVersion && object["data"] is [String: Any])
    }

    @Test func anUnreadableFileIsKeptAndNotOverwritten() throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let broken = "{ this is not json"
        try put(broken, "preferences.json")
        guard case .unreadable = store.preferences() else { Issue.record("Expected unreadable"); return }
        #expect(throws: NoorStoreError.self) { try store.save(Preferences()) }
        #expect(try String(contentsOf: file("preferences.json"), encoding: .utf8) == broken, "still exactly what it was")

        let aside = try #require(try store.setAside(.preferences))
        #expect(try String(contentsOf: aside, encoding: .utf8) == broken, "moved, not lost")
        #expect(store.preferences() == .absent)
        try store.save(Preferences())
        #expect(store.preferences().value != nil)
    }

    @Test func aFileThatMeansSomethingElseIsUnreadable() throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        try put(#"{"version":1,"data":[1,2]}"#, "preferences.json")
        guard case .unreadable = store.preferences() else { Issue.record("Expected unreadable"); return }
        try put(#"{"version":1,"data":[500]}"#, "bookmarks.json")
        guard case .unreadable = store.bookmarks() else { Issue.record("Expected unreadable"); return }
        #expect(throws: NoorStoreError.badBookmark(100)) { try store.save(bookmarks: [100]) }
    }

    @Test func aTamperedFileIsUnreadableNotACrash() throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        try put(#"{"version":1,"data":[{"id":"a","kind":"calculated","name":"A","zoneID":"Mars/Olympus","revision":1,"attribution":""}]}"#, "sources.json")
        guard case .unreadable = store.sources() else { Issue.record("Expected a bad zone to be refused"); return }
        try put(#"{"version":1,"data":[{"id":"a","kind":"connected","name":"A","zoneID":"UTC","revision":1,"attribution":""}]}"#, "sources.json")
        guard case .unreadable = store.sources() else { Issue.record("Expected a kind that doesn't exist to be refused"); return }
        let huge = Data(#"{"latitude":1,"longitude":2,"degrees":1e300,"fetched":0}"#.utf8)
        #expect(throws: (any Error).self) { try JSONDecoder().decode(QiblaBearing.self, from: huge) }
    }

    @Test func aNewerFileIsLeftAlone() throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let newer = #"{"version":99,"data":{"future":true}}"#
        try put(newer, "sources.json")
        guard case .unreadable(let why) = store.sources() else { Issue.record("Expected unreadable"); return }
        #expect(why.contains("newer"))
        #expect(throws: NoorStoreError.self) { try store.save(sources: []) }
        #expect(try String(contentsOf: file("sources.json"), encoding: .utf8) == newer)
    }

    @Test func migrationsAreExplicitAndKeepTheOldFile() throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let old = #"{"version":1,"data":{"numbers":[7,8]}}"#
        try put(old, "bookmarks.json")
        // Without a step, an older shape isn't reinterpreted.
        let noStep = NoorStore(folder: folder, migrations: Migrations(current: 2, steps: [:]))
        guard case .unreadable = noStep.bookmarks() else { Issue.record("Expected unreadable"); return }
        #expect(try String(contentsOf: file("bookmarks.json"), encoding: .utf8) == old)

        let migrating = NoorStore(folder: folder, migrations: Migrations(current: 2, steps: [1: { document, payload in
            #expect(document == "bookmarks.json")
            return (payload as! [String: Any])["numbers"]!
        }]))
        #expect(migrating.bookmarks() == .ok([7, 8]))
        let moved = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: file("bookmarks.json"))) as? [String: Any])
        #expect(moved["version"] as? Int == 2)
        #expect(try String(contentsOf: file("set-aside/bookmarks.json.v1"), encoding: .utf8) == old, "the old one is kept")
        #expect(migrating.bookmarks() == .ok([7, 8]), "and it doesn't migrate twice")
    }

    @Test func aMigrationThatFailsChangesNothing() throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let old = #"{"version":1,"data":{"numbers":[7,8]}}"#
        try put(old, "bookmarks.json")
        let failing = NoorStore(folder: folder, migrations: Migrations(current: 2, steps: [1: { _, _ in throw CocoaError(.featureUnsupported) }]))
        guard case .unreadable = failing.bookmarks() else { Issue.record("Expected unreadable"); return }
        #expect(try String(contentsOf: file("bookmarks.json"), encoding: .utf8) == old)
    }

    @Test func identifiersCantLeaveTheFolder() throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        #expect(store.timetable(sourceID: "../../etc/passwd") == .absent)
        #expect(throws: NoorStoreError.self) { try store.deleteTimetable(sourceID: "../preferences") }
        #expect(TimetableSource(id: "../x", kind: .manual, name: "", zoneID: "UTC", attribution: "") == nil)
    }

    @Test func cacheFilesAndKeysStayApart() throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let key = "qibla|35.6762|139.6503"
        try store.cache([1, 2, 3], key: key, fetchedAt: Date(timeIntervalSince1970: 50))
        let entry: CacheEntry<[Int]>? = store.cached(key: key)
        #expect(entry?.value == [1, 2, 3] && entry?.fetchedAt == Date(timeIntervalSince1970: 50))
        let names = try FileManager.default.contentsOfDirectory(atPath: file("cache").path)
        #expect(names.count == 1 && !names[0].contains("35.67"), "no coordinates in a file name")
        let wrongType: CacheEntry<String>? = store.cached(key: key)
        #expect(wrongType == nil)
        #expect(names[0].hasSuffix(".json"))
    }

    @Test func pruningRemovesOnlyTheOld() throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        try store.cache("old", key: "a", fetchedAt: Date(timeIntervalSince1970: 10))
        try store.cache("new", key: "b", fetchedAt: Date(timeIntervalSince1970: 100))
        store.pruneCache(olderThan: Date(timeIntervalSince1970: 50))
        let old: CacheEntry<String>? = store.cached(key: "a"), new: CacheEntry<String>? = store.cached(key: "b")
        #expect(old == nil && new?.value == "new")
    }

    @Test func clearReachesItsScopeAndNothingElse() throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        try store.save(Preferences())
        try store.save(sources: [S.tokyoSource])
        try store.save(bookmarks: [5])
        try store.save(try manualTable())
        try store.cache("value", key: "k", fetchedAt: Date(timeIntervalSince1970: 1))
        try put("host's", "shared-place.json")

        try store.clear(.cache)
        let gone: CacheEntry<String>? = store.cached(key: "k")
        #expect(gone == nil && store.preferences().value != nil && store.sources().value != nil && store.bookmarks().value == [5] && store.timetable(sourceID: "manual.mosque").value != nil)

        try store.cache("value", key: "k", fetchedAt: Date(timeIntervalSince1970: 1))
        try store.clear(.all)
        let alsoGone: CacheEntry<String>? = store.cached(key: "k")
        #expect(alsoGone == nil && store.preferences() == .absent && store.sources() == .absent && store.bookmarks() == .absent && store.timetable(sourceID: "manual.mosque") == .absent)
        #expect(try String(contentsOf: file("shared-place.json"), encoding: .utf8) == "host's", "not Noor's to clear")
    }

    @Test func exportCarriesItsScope() throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        try store.save(Preferences())
        try store.save(bookmarks: [5])
        try store.save(try manualTable())
        try store.cache("value", key: "k", fetchedAt: Date(timeIntervalSince1970: 1))
        try put("not json", "sources.json")

        func files(_ scope: NoorStore.Scope) throws -> [String: Any] {
            try #require(try JSONSerialization.jsonObject(with: store.export(scope)) as? [String: Any])
        }
        let cacheOnly = try files(.cache)
        #expect(cacheOnly["scope"] as? String == "cache")
        let cached = try #require(cacheOnly["files"] as? [String: Any])
        #expect(cached.count == 1 && cached.keys.allSatisfy { $0.hasPrefix("cache/") })

        let all = try files(.all)
        let everything = try #require(all["files"] as? [String: Any])
        #expect(everything["preferences.json"] != nil && everything["bookmarks.json"] != nil && everything["timetables/manual.mosque.json"] != nil)
        #expect(everything.keys.contains { $0.hasPrefix("cache/") })
        #expect(all["unreadable"] as? [String] == ["sources.json"], "named, not carried")
    }

    @Test func committingASourceWritesThePointerLast() throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        var before = Preferences()
        before.sourceID = "calculated.tokyo"
        try store.save(before)

        var after = before
        after.sourceID = "manual.mosque"
        let table = try manualTable()
        // If the source list can't be written, the preferences must still name the old source.
        try put("{ broken", "sources.json")
        #expect(throws: NoorStoreError.self) { try store.commitSource(preferences: after, sources: [table.source], timetable: table) }
        #expect(store.preferences().value?.sourceID == "calculated.tokyo")

        try store.setAside(.sources)
        try store.commitSource(preferences: after, sources: [table.source], timetable: table)
        #expect(store.preferences().value?.sourceID == "manual.mosque" && store.sources().value == [table.source] && store.timetable(sourceID: "manual.mosque").value == table)
    }
}
