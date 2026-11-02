import Foundation

/// One immutable picture of Noor at one instant: Home, Today and Ask all read this, so they can't disagree.
struct NoorSnapshot: Hashable, Sendable {
    enum Validity: Hashable, Sendable { case loading, ready, offlineValid, expired, notStarted, noPlace, noSource, error }

    /// How the last load went, which the data alone can't say.
    enum LoadState: Hashable, Sendable { case settled, loading, offline, failed }

    enum ReminderStatus: Hashable, Sendable {
        case off
        case on
        case paused(until: Date)
    }

    let now: Date
    let place: Place?
    let source: TimetableSource?
    let sourceRevision: Int?
    /// The source's zone once there is one: the timetable's clock is what counts, not the device's.
    let zoneID: String?
    /// The place-local date; nil before there is any zone.
    let localDate: CivilDate?
    let coverage: ClosedRange<CivilDate>?
    let convention: PrayerConvention?
    let reportedMethod: MethodMetadata?
    let calendarMethod: CalendarMethod
    let today: PrayerDay?
    let tomorrow: PrayerDay?
    let next: NextEvent
    let fetchedAt: Date?
    let reminderStatus: ReminderStatus
    let validity: Validity
    /// Today's paired date, or nil if what was given is about another date or method.
    let calendar: CalendarDay?
    /// Only a bearing fetched for this place.
    let qibla: QiblaBearing?
    let name: NameEntry?

    static func make(now: Date, prefs: Preferences, sources: [TimetableSource], days: [PrayerDay], calendar: CalendarDay?, qibla: QiblaBearing?, name: NameEntry?,
                     load: LoadState = .settled) -> NoorSnapshot {
        let source = sources.first { $0.id == prefs.sourceID }
        let zone = source?.zone ?? prefs.place?.zone
        let localDate = zone.map { CivilDate(now, in: $0) }

        func day(on date: CivilDate?) -> PrayerDay? {
            guard let date, let source, source.coverage?.contains(date) ?? true else { return nil }
            return days.first { $0.date == date && $0.sourceID == source.id && $0.zoneID == source.zoneID }
        }
        let today = day(on: localDate)
        let tomorrow = day(on: localDate?.next)

        let validity: Validity
        if source == nil {
            validity = prefs.place == nil ? .noPlace : .noSource
        } else if source?.kind == .calculated, prefs.place == nil {
            validity = .noPlace
        } else if today != nil {
            validity = load == .offline ? .offlineValid : .ready
        } else if let coverage = source?.coverage, let localDate, !coverage.contains(localDate) {
            validity = localDate < coverage.lowerBound ? .notStarted : .expired
        } else {
            switch load {
            case .loading, .settled: validity = .loading
            case .offline, .failed: validity = .error
            }
        }

        let reminders = prefs.reminders
        let status: ReminderStatus = !reminders.master ? .off : reminders.pausedUntil.map { $0 > now ? .paused(until: $0) : .on } ?? .on

        return NoorSnapshot(now: now, place: prefs.place, source: source, sourceRevision: source?.revision, zoneID: source?.zoneID ?? prefs.place?.zoneID, localDate: localDate,
                            coverage: source?.coverage, convention: prefs.convention, reportedMethod: today?.method, calendarMethod: prefs.calendarMethod,
                            today: today, tomorrow: tomorrow, next: NextEvent.compute(now: now, today: today, tomorrow: tomorrow), fetchedAt: source?.lastFetch,
                            reminderStatus: status, validity: validity,
                            calendar: calendar.flatMap { $0.gregorian == localDate && $0.method == prefs.calendarMethod ? $0 : nil },
                            qibla: qibla.flatMap { bearing in prefs.place.flatMap { bearing.isFor($0) ? bearing : nil } }, name: name)
    }

    /// Which Name a civil date shows: the next number each day, round through the 99, with no meaning in the order.
    static func nameOfTheDay(_ date: CivilDate) -> Int {
        let count = CivilDate(year: 2000, month: 1, day: 1)!.days(until: date)
        return ((count % 99) + 99) % 99 + 1
    }
}
