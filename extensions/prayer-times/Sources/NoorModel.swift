import Foundation
import SidefolkExtensionKit

/// What Noor holds while its program runs: what is saved on disk, and what the provider last said. Pages read it and never wait for the network:
/// requests run one at a time, so a render that fetched would hold up every click. `freshen` fetches beside them, and the next reading shows it.
@MainActor
final class NoorModel {
    static let shared = NoorModel()

    let store: NoorStore
    let provider: Provider
    private(set) var prefs = Preferences()
    private(set) var sources: [TimetableSource] = []
    private(set) var bookmarks: Set<Int> = []
    /// A saved file that couldn't be read: said on the page, and never overwritten without the person's word.
    private(set) var unreadable: String?
    private(set) var timetable: ManualTimetable?

    /// The current source's days by date, from the provider or the saved timetable.
    private(set) var days: [CivilDate: PrayerDay] = [:]
    private(set) var calendar: [String: CalendarMonth] = [:]
    private(set) var names: [NameEntry] = []
    private(set) var qibla: QiblaBearing?
    private(set) var occasions: [Int: [Occasion]] = [:]
    private(set) var ramadan: [Int: RamadanMonth] = [:]
    private(set) var calendarMethods: [CalendarMethodInfo] = []
    private(set) var prayerMethods: [PrayerMethodInfo] = []
    private(set) var load: NoorSnapshot.LoadState = .settled
    private(set) var problem: UnavailableReason?
    private(set) var fetchedAt: Date?

    /// A place search's answer, an import being looked over and a conversion's result: what a tool found and the page shows until it is done with.
    var placeResults: [Place] = []
    var placeProblem: String?
    var review: (name: String, review: ImportReview)?
    var conversion: CalendarDay?
    var conversionProblem: String?
    /// The time a plan was last sent.
    private(set) var loadedKey = ""
    private var freshening: Task<Void, Never>?
    private var freshAt = Date.distantPast
    private var extras: Set<String> = []

    init(folder: URL = URL(fileURLWithPath: Paths.data)) {
        let store = NoorStore(folder: folder)
        self.store = store
        provider = Provider(fetching: Self.fetching(folder), store: store)
        reread()
    }

    private static func fetching(_ folder: URL) -> any Fetching {
        #if DEBUG
        if let fixtures = NoorDebug.fixtures(folder) { return fixtures }
        #endif
        return URLSessionFetching()
    }

    var now: Date {
        #if DEBUG
        if let now = NoorDebug.now(store) { return now }
        #endif
        return Date()
    }

    /// Reads what is saved. A file it can't read is said, and left where it is.
    func reread() {
        func take<T>(_ loaded: Loaded<T>, _ what: String, _ apply: (T) -> Void) {
            switch loaded {
            case .ok(let value): apply(value)
            case .absent: break
            case .unreadable: unreadable = what
            }
        }
        unreadable = nil
        take(store.preferences(), "preferences") { prefs = $0 }
        take(store.sources(), "sources") { sources = $0 }
        take(store.bookmarks(), "bookmarks") { bookmarks = $0 }
        loadTimetable()
    }

    private func loadTimetable() {
        timetable = nil
        guard let id = prefs.sourceID, let source = sources.first(where: { $0.id == id }), source.kind == .manual else { return }
        if case .ok(let table) = store.timetable(sourceID: id) { timetable = table }
    }

    var source: TimetableSource? { sources.first { $0.id == prefs.sourceID } }
    var isSetUp: Bool { prefs.place != nil && source != nil && (source?.kind == .manual || prefs.convention != nil) }

    func snapshot(_ at: Date? = nil) -> NoorSnapshot {
        let now = at ?? self.now
        let zone = source?.zone ?? prefs.place?.zone
        let today = zone.map { CivilDate(now, in: $0) }
        let paired = today.flatMap { date in calendarMonths.flatMap(\.days).first { $0.gregorian == date && $0.method == prefs.calendarMethod } }
        let name = today.flatMap { date in names.first { $0.number == NoorSnapshot.nameOfTheDay(date) } }
        return NoorSnapshot.make(now: now, prefs: prefs, sources: sources, days: Array(allDays.values), calendar: paired, qibla: qibla, name: name, load: load)
    }

    private var calendarMonths: [CalendarMonth] { Array(calendar.values) }

    /// A saved timetable's days alone, or what the provider gave for the calculated source.
    private var allDays: [CivilDate: PrayerDay] {
        guard let timetable else { return days }
        return Dictionary(timetable.days.map { ($0.date, $0) }, uniquingKeysWith: { a, _ in a })
    }

    func day(_ date: CivilDate) -> PrayerDay? { allDays[date] }

    // MARK: Changing what is saved

    func save(_ change: (inout Preferences) -> Void) throws {
        var next = prefs
        change(&next)
        try store.save(next)
        let moved = next.place != prefs.place || next.convention != prefs.convention || next.calendarMethod != prefs.calendarMethod || next.sourceID != prefs.sourceID
        prefs = next
        loadTimetable()
        if moved { forgetLoaded() }
        unreadable = nil
    }

    /// One step: the place, its source and the timetable that goes with it all change, or none does.
    func commit(place: Place?, sourceID: String?, sources next: [TimetableSource], timetable table: ManualTimetable? = nil, change: (inout Preferences) -> Void = { _ in }) throws {
        var saved = prefs
        saved.place = place
        saved.sourceID = sourceID
        change(&saved)
        try store.commitSource(preferences: saved, sources: next, timetable: table)
        prefs = saved
        sources = next
        loadTimetable()
        forgetLoaded()
    }

    func setBookmark(_ number: Int, _ on: Bool) throws {
        var next = bookmarks
        if on { next.insert(number) } else { next.remove(number) }
        try store.save(bookmarks: next)
        bookmarks = next
    }

    func clear(_ scope: NoorStore.Scope) throws {
        try store.clear(scope)
        forgetLoaded()
        names = []
        qibla = nil
        calendar = [:]
        occasions = [:]
        ramadan = [:]
        if scope == .all {
            prefs = Preferences()
            sources = []
            bookmarks = []
            timetable = nil
        }
    }

    private func forgetLoaded() {
        days = [:]
        calendar = [:]
        ramadan = [:]
        qibla = nil
        loadedKey = ""
        problem = nil
        freshAt = .distantPast
    }

    // MARK: Fetching beside the pages

    /// Sees that what the page will want is on its way. Cached answers come at once, so this costs little to ask again; the network is only asked as the
    /// provider's own ages say. Pages ask for `extra` things they alone need (`calendar:…`, `ramadan:…`).
    func freshen(extra wanted: [String] = [], refresh: Bool = false) {
        let newExtras = wanted.filter { !extras.contains($0) }
        extras.formUnion(newExtras)
        let now = self.now
        let key = "\(prefs.place?.id ?? "")|\(prefs.sourceID ?? "")|\(prefs.calendarMethod.rawValue)|\(String(describing: prefs.convention))"
        let stale = now.timeIntervalSince(freshAt) > 15 * 60 || key != loadedKey || refresh
        guard stale || !newExtras.isEmpty else { return }
        guard freshening == nil || refresh else {
            // What is running may have read the list already: once it ends, another round picks these up.
            againAfter = true
            return
        }
        freshening?.cancel()
        loadedKey = key
        if stale { freshAt = now }
        load = .loading
        freshening = Task { @MainActor [weak self] in
            await self?.fetchAll(now: now, refresh: refresh)
            guard let self else { return }
            self.freshening = nil
            if self.againAfter {
                self.againAfter = false
                self.freshen()
                await self.fetchAll(now: self.now, refresh: false)
            }
        }
    }

    private var againAfter = false

    /// Waits a moment for what is on its way, so opening a page with a good cache doesn't flash its loading state.
    func settle(ms: Int = 700) async {
        guard let running = freshening else { return }
        let waited = Task { await running.value }
        let timer = Task { try? await Task.sleep(for: .milliseconds(ms)) }
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await waited.value }
            group.addTask { await timer.value }
            _ = await group.next()
            group.cancelAll()
        }
    }

    private func note<V>(_ outcome: Outcome<V>, into worst: inout UnavailableReason?, at: inout Date?) -> V? {
        switch outcome {
        case .fresh(let value):
            return value
        case .cached(let value, let fetched):
            if at == nil || fetched < at! { at = fetched }
            return value
        case .unavailable(let reason):
            worst = worst ?? reason
            return nil
        }
    }

    private func fetchAll(now: Date, refresh: Bool) async {
        var failed: UnavailableReason?
        var fetched: Date?
        let prefs = prefs
        // The Names ask for no place, so they can be read before there is one.
        if let list = note(await provider.load(AlAdhan.names(), now: now, refresh: refresh), into: &failed, at: &fetched) { names = list }
        if let list = await provider.load(AlAdhan.calendarMethods(), now: now).value { calendarMethods = list }
        if let list = await provider.load(AlAdhan.prayerMethods(), now: now).value { prayerMethods = list }

        guard let place = prefs.place else {
            load = failed == .offline ? .offline : .settled
            problem = failed
            return
        }
        let zone = source?.zone ?? place.zone
        let today = CivilDate(now, in: zone)
        if let bearing = note(await provider.qibla(place: place, now: now, refresh: refresh), into: &failed, at: &fetched) { qibla = bearing }
        // This month and the next: tomorrow's Fajr and the reminders' horizon cross into it.
        let months = [(today.year, today.month), Self.monthAfter(today.year, today.month)]
        if source?.kind == .calculated, let convention = prefs.convention {
            for (year, month) in months {
                if let list = note(await provider.prayerMonth(year: year, month: month, place: place, convention: convention, calendarMethod: prefs.calendarMethod, now: now, refresh: refresh), into: &failed, at: &fetched) {
                    for day in list { days[day.date] = day }
                }
            }
        }
        for (year, month) in months {
            if let list = note(await provider.load(AlAdhan.gregorianMonth(year: year, month: month, method: prefs.calendarMethod), now: now, refresh: refresh), into: &failed, at: &fetched) {
                calendar["g\(year)-\(month)-\(prefs.calendarMethod.rawValue)"] = list
            }
        }
        for extra in extras.sorted() { await fetchExtra(extra, now: now, refresh: refresh, failed: &failed, fetched: &fetched) }
        if let year = snapshot(now).calendar?.hijri.year, occasions[year] == nil,
           let list = note(await provider.load(AlAdhan.occasions(hijriYear: year, method: prefs.calendarMethod), now: now, refresh: refresh), into: &failed, at: &fetched) {
            occasions[year] = Occasion.dedupe(list)
        }
        problem = failed
        fetchedAt = fetched ?? (failed == nil ? now : fetchedAt)
        load = failed == nil ? .settled : (failed == .offline ? .offline : .failed)
        rememberFetch(now: now, failed: failed)
    }

    /// `g:<year>:<month>` and `h:<year>:<month>` a calendar month; `r:<year>` a Ramadan; `o:<year>` a year's occasions.
    private func fetchExtra(_ extra: String, now: Date, refresh: Bool, failed: inout UnavailableReason?, fetched: inout Date?) async {
        let parts = extra.split(separator: ":").map(String.init)
        let method = prefs.calendarMethod
        switch parts.first {
        case "g" where parts.count == 3:
            guard let y = Int(parts[1]), let m = Int(parts[2]) else { return }
            if let list = note(await provider.load(AlAdhan.gregorianMonth(year: y, month: m, method: method), now: now, refresh: refresh), into: &failed, at: &fetched) { calendar["g\(y)-\(m)-\(method.rawValue)"] = list }
        case "h" where parts.count == 3:
            guard let y = Int(parts[1]), let m = Int(parts[2]) else { return }
            if let list = note(await provider.load(AlAdhan.hijriMonth(year: y, month: m, method: method), now: now, refresh: refresh), into: &failed, at: &fetched) { calendar["h\(y)-\(m)-\(method.rawValue)"] = list }
        case "r" where parts.count == 2:
            guard let y = Int(parts[1]), let place = prefs.place, let convention = prefs.convention else { return }
            if let list = note(await provider.hijriPrayerMonth(year: y, month: 9, place: place, convention: convention, calendarMethod: method, now: now, refresh: refresh), into: &failed, at: &fetched),
               let month = RamadanMonth(days: list) { ramadan[y] = month }
        case "o" where parts.count == 2:
            guard let y = Int(parts[1]) else { return }
            if let list = note(await provider.load(AlAdhan.occasions(hijriYear: y, method: method), now: now, refresh: refresh), into: &failed, at: &fetched) { occasions[y] = Occasion.dedupe(list) }
        case "d" where parts.count == 2:
            // A date being looked at, outside the months already here.
            guard let date = CivilDate(iso: parts[1]), let place = prefs.place, let convention = prefs.convention, source?.kind == .calculated else { return }
            if let day = note(await provider.prayerDay(date, place: place, convention: convention, calendarMethod: method, now: now, refresh: refresh), into: &failed, at: &fetched) { days[day.date] = day }
        default:
            return
        }
    }

    /// The source says when it last heard from its provider, for the page's "saved at" and the snapshot's freshness.
    private func rememberFetch(now: Date, failed: UnavailableReason?) {
        guard failed == nil, let id = prefs.sourceID, let index = sources.firstIndex(where: { $0.id == id }), sources[index].kind == .calculated else { return }
        let old = sources[index]
        guard let updated = TimetableSource(id: old.id, kind: old.kind, name: old.name, zoneID: old.zoneID, coverage: old.coverage, revision: old.revision,
                                            attribution: old.attribution, lastFetch: fetchedAt ?? now) else { return }
        sources[index] = updated
        try? store.save(sources: sources)
    }

    static func monthAfter(_ year: Int, _ month: Int) -> (Int, Int) { month == 12 ? (year + 1, 1) : (year, month + 1) }
    static func monthBefore(_ year: Int, _ month: Int) -> (Int, Int) { month == 1 ? (year - 1, 12) : (year, month - 1) }

    func gregorianMonth(_ year: Int, _ month: Int) -> CalendarMonth? { calendar["g\(year)-\(month)-\(prefs.calendarMethod.rawValue)"] }
    func hijriMonth(_ year: Int, _ month: Int) -> CalendarMonth? { calendar["h\(year)-\(month)-\(prefs.calendarMethod.rawValue)"] }

    func pairedDay(_ date: CivilDate) -> CalendarDay? {
        calendar.values.lazy.filter { $0.method == self.prefs.calendarMethod }.flatMap(\.days).first { $0.gregorian == date }
    }

    func occasions(on date: CivilDate) -> [Occasion] {
        guard let year = pairedDay(date)?.hijri.year else { return [] }
        let listed = (occasions[year] ?? []).filter { $0.gregorian == date }
        return listed.isEmpty ? (pairedDay(date)?.occasions ?? []) : listed
    }

    /// Everything the reminders need from what is here, so a preview and a plan can't differ.
    func planned(_ prefs: Preferences? = nil, at now: Date? = nil) -> [PlannedOccurrence] {
        let chosen = prefs ?? self.prefs
        let year = snapshot().calendar?.hijri.year
        let ramadanYear = snapshot().calendar.map { RamadanMonth.nextYear(from: $0.hijri) } ?? year
        return Planner.plan(now: now ?? self.now, prefs: chosen, days: Array(allDays.values), ramadan: ramadanYear.flatMap { ramadan[$0] },
                            occasions: occasions.values.flatMap { $0 }, names: names)
    }
}

/// Only in a debug build, for looking at Noor at a chosen moment and with chosen answers: nothing here exists in a pack anyone installs.
#if DEBUG
enum NoorDebug {
    /// A file `debug-now.txt` in the data folder holds an ISO 8601 instant.
    @MainActor static func now(_ store: NoorStore) -> Date? {
        guard let text = try? String(contentsOf: URL(fileURLWithPath: Paths.data).appendingPathComponent("debug-now.txt"), encoding: .utf8) else { return nil }
        return ISO8601DateFormatter().date(from: text.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    /// A folder `debug-fixtures/` answers instead of the network: `<last path parts joined by _>.json`, or `debug-network.txt` says `offline`, `429` or `malformed`.
    static func fixtures(_ folder: URL) -> (any Fetching)? {
        let root = folder.appendingPathComponent("debug-fixtures", isDirectory: true)
        guard FileManager.default.fileExists(atPath: root.path) else { return nil }
        return FixtureFetching(root: root, control: folder.appendingPathComponent("debug-network.txt"))
    }

    struct FixtureFetching: Fetching {
        let root: URL
        let control: URL

        func get(_ url: URL) async throws -> (status: Int, body: Data) {
            let mode = (try? String(contentsOf: control, encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines)
            switch mode {
            case "offline": throw URLError(.notConnectedToInternet)
            case "429": return (429, Data())
            case "malformed": return (200, Data("{\"code\":200,\"data\":{}}".utf8))
            default: break
            }
            let parts = url.path.split(separator: "/").dropFirst().map(String.init)
            let name = parts.joined(separator: "_") + ".json"
            guard let data = try? Data(contentsOf: root.appendingPathComponent(name)) else { return try await URLSessionFetching().get(url) }
            return (200, data)
        }
    }
}
#endif
