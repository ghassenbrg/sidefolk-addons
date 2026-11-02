import Foundation

/// A prayer's times regardless of what the dial is focused on: asking for Maghrib means Maghrib's start.
struct PrayerWhen: Equatable, Sendable {
    let prayer: PrayerID
    let start: Date
    /// Only when the source gives one.
    let iqamah: Date?
    let date: CivilDate
    let zoneID: String
    let sourceID: String
}

extension PrayerDay {
    func whenIs(_ prayer: PrayerID) -> PrayerWhen {
        PrayerWhen(prayer: prayer, start: starts[prayer]!, iqamah: iqamah[prayer], date: date, zoneID: zoneID, sourceID: sourceID)
    }
}

/// What the Overview focuses on.
enum NextEvent: Hashable, Sendable {
    enum Unavailable: Hashable, Sendable {
        /// No day was given for the place-local date.
        case noToday
        /// The day given isn't the place-local date any more.
        case staleToday
        /// Today has nothing left and tomorrow's data isn't there, or isn't the next date of the same source.
        case noTomorrow
    }

    case prayerStart(id: PrayerID, at: Date, day: CivilDate)
    case iqamah(id: PrayerID, at: Date, startedAt: Date)
    case unavailable(reason: Unavailable)

    /// After a start, a same-source iqamah still ahead holds the focus until it begins; then the next start. After the
    /// last start of the day comes tomorrow's Fajr, and without a valid tomorrow it says so rather than reuse any other
    /// day's times.
    static func compute(now: Date, today: PrayerDay?, tomorrow: PrayerDay?) -> NextEvent {
        guard let today else { return .unavailable(reason: .noToday) }
        guard today.date == CivilDate(now, in: today.zone) else { return .unavailable(reason: .staleToday) }

        let ordered = today.ordered
        let nextIndex = ordered.firstIndex { $0.at > now }
        let current = (nextIndex ?? ordered.count) > 0 ? ordered[(nextIndex ?? ordered.count) - 1] : nil
        let upcoming = nextIndex.map { ordered[$0] }
        if let current, let at = today.iqamah[current.id], at > now, upcoming.map({ at <= $0.at }) ?? true {
            return .iqamah(id: current.id, at: at, startedAt: current.at)
        }
        if let upcoming { return .prayerStart(id: upcoming.id, at: upcoming.at, day: today.date) }

        guard let tomorrow, tomorrow.date == today.date.next, tomorrow.sourceID == today.sourceID, tomorrow.zoneID == today.zoneID,
              let fajr = tomorrow.starts[.fajr], fajr > now else { return .unavailable(reason: .noTomorrow) }
        return .prayerStart(id: .fajr, at: fajr, day: tomorrow.date)
    }
}
