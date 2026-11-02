import Foundation

/// One day of a Ramadan month. Imsak stays separate from Fajr: it is the provider's calculated value, and absent if it gave none.
struct RamadanDay: Hashable, Sendable, Codable {
    let number: Int
    let date: CivilDate
    let fajr: Date
    let imsak: Date?
    let maghrib: Date
}

/// A composition of the month-9 prayer calendar, with the length and dates it actually returned: calculated, not a local
/// announcement.
struct RamadanMonth: Hashable, Sendable, Codable {
    let hijriYear: Int
    let method: CalendarMethod?
    let sourceID: String
    let zoneID: String
    let days: [RamadanDay]

    /// Refuses anything but a whole month 9 of one year and one source, 29 or 30 days long, with no date skipped.
    init?(days prayerDays: [PrayerDay]) {
        guard let first = prayerDays.first, let year = first.hijri?.year, (29...30).contains(prayerDays.count) else { return nil }
        var built: [RamadanDay] = []
        for (index, day) in prayerDays.enumerated() {
            guard let hijri = day.hijri, hijri.year == year, hijri.month == 9, hijri.day == index + 1, day.sourceID == first.sourceID, day.zoneID == first.zoneID,
                  index == 0 || prayerDays[index - 1].date.next == day.date else { return nil }
            built.append(RamadanDay(number: hijri.day, date: day.date, fajr: day.starts[.fajr]!, imsak: day.solar[.imsak], maghrib: day.starts[.maghrib]!))
        }
        (hijriYear, method, sourceID, zoneID, days) = (year, first.hijri?.method, first.sourceID, first.zoneID, built)
    }

    var dayCount: Int { days.count }

    /// The Hijri year of the Ramadan that is on now or comes next from this date.
    static func nextYear(from date: HijriDate) -> Int {
        date.month <= 9 ? date.year : date.year + 1
    }
}
