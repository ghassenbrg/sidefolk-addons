import Foundation

enum AlAdhanError: Error, Equatable, Sendable {
    /// The answer can't be read, or a required value is missing or impossible.
    case malformed(String)
    /// The provider's own `code` wasn't 200.
    case apiCode(Int)
    /// A well-formed answer about some other date or month than the one asked for.
    case noCoverage(String)
}

/// Reads the provider's JSON into the domain's types. Extra fields are ignored; what the domain needs must be there and
/// make sense, because a wrong time is worse than none.
enum AlAdhanDecoder {
    /// The largest real answer is a month of timings, under 100 KB.
    static let maximumBytes = 2_000_000

    private struct Code: Decodable { let code: Int }
    private struct Envelope<T: Decodable>: Decodable { let data: T }

    private static func payload<T: Decodable>(_ type: T.Type, _ data: Data) throws -> T {
        guard data.count <= maximumBytes else { throw AlAdhanError.malformed("too large") }
        let decoder = JSONDecoder()
        guard let code = try? decoder.decode(Code.self, from: data) else { throw AlAdhanError.malformed("no code") }
        guard code.code == 200 else { throw AlAdhanError.apiCode(code.code) }
        do {
            return try decoder.decode(Envelope<T>.self, from: data).data
        } catch {
            throw AlAdhanError.malformed(String(describing: error))
        }
    }

    // MARK: - Prayer days

    static func timings(_ data: Data, date: CivilDate, query: PrayerQuery) throws -> PrayerDay {
        let day = try prayerDay(payload(Wire.TimingDay.self, data), query: query)
        guard day.date == date else { throw AlAdhanError.noCoverage("asked for \(date), got \(day.date)") }
        return day
    }

    static func prayerCalendar(_ data: Data, year: Int, month: Int, query: PrayerQuery) throws -> [PrayerDay] {
        let days = try payload([Wire.TimingDay].self, data).map { try prayerDay($0, query: query) }
        try checkGregorianMonth(days.map(\.date), year: year, month: month)
        return days
    }

    static func hijriPrayerCalendar(_ data: Data, year: Int, month: Int, query: PrayerQuery) throws -> [PrayerDay] {
        let days = try payload([Wire.TimingDay].self, data).map { try prayerDay($0, query: query) }
        let hijri = try days.map { day in
            guard let date = day.hijri else { throw AlAdhanError.malformed("no Hijri date") }
            return date
        }
        try checkHijriMonth(gregorian: days.map(\.date), hijri: hijri, year: year, month: month)
        return days
    }

    private static func prayerDay(_ wire: Wire.TimingDay, query: PrayerQuery) throws -> PrayerDay {
        let zoneID = query.place.zoneID
        let zone = query.place.zone
        guard wire.meta.timezone == zoneID else { throw AlAdhanError.malformed("answered for zone \(wire.meta.timezone)") }
        guard abs(wire.meta.latitude - query.place.latitude) < 0.001, abs(wire.meta.longitude - query.place.longitude) < 0.001 else {
            throw AlAdhanError.malformed("answered for other coordinates")
        }
        guard wire.meta.method.id == query.convention.method else { throw AlAdhanError.malformed("answered with method \(wire.meta.method.id)") }
        let date = try civilDate(wire.date.gregorian)
        let hijri = try hijriDate(wire.date.hijri, expecting: query.calendarMethod)

        func instant(_ key: String) throws -> Date? {
            guard let text = wire.timings[key] ?? nil else { return nil }
            return try parseInstant(text, zone: zone, near: date)
        }
        var starts: [PrayerID: Date] = [:]
        for (id, key) in [PrayerID.fajr: "Fajr", .dhuhr: "Dhuhr", .asr: "Asr", .maghrib: "Maghrib", .isha: "Isha"] {
            guard let at = try instant(key) else { throw AlAdhanError.malformed("no \(key)") }
            starts[id] = at
        }
        // A marker the provider left out stays absent and the page says so; one that is there but wrong is a bad answer.
        var solar: [SolarEvent: Date] = [:]
        for (id, key) in [SolarEvent.imsak: "Imsak", .sunrise: "Sunrise", .sunset: "Sunset", .midnight: "Midnight", .firstThird: "Firstthird", .lastThird: "Lastthird"] {
            solar[id] = try instant(key)
        }
        let method = MethodMetadata(id: wire.meta.method.id, name: wire.meta.method.name ?? "", school: wire.meta.school ?? "",
                                    latitudeAdjustment: wire.meta.latitudeAdjustmentMethod, midnightMode: wire.meta.midnightMode)
        guard let day = PrayerDay(date: date, zoneID: zoneID, sourceID: query.sourceID, starts: starts, solar: solar, method: method, hijri: hijri) else {
            throw AlAdhanError.malformed("not a valid day")
        }
        return day
    }

    /// `2026-11-03T01:38:00+09:00`. The offset has to be the zone's at that instant, and the date within a day of the
    /// requested one: anything else was calculated for some other place or day.
    static func parseInstant(_ text: String, zone: TimeZone, near date: CivilDate) throws -> Date {
        guard let m = text.wholeMatch(of: /(\d{4}-\d{2}-\d{2})T(\d{2}):(\d{2}):(\d{2})(?:Z|([+-])(\d{2}):(\d{2}))/),
              let civil = CivilDate(iso: String(m.1)), let hour = Int(m.2), let minute = Int(m.3), let second = Int(m.4),
              (0...23).contains(hour), (0...59).contains(minute), (0...59).contains(second) else {
            throw AlAdhanError.malformed("not a timestamp: \(text)")
        }
        var offset = 0
        if let sign = m.5, let offsetHours = m.6.flatMap({ Int($0) }), let offsetMinutes = m.7.flatMap({ Int($0) }) {
            offset = (sign == "-" ? -1 : 1) * (offsetHours * 3600 + offsetMinutes * 60)
        }
        let instant = civil.anchor.addingTimeInterval(TimeInterval(hour * 3600 + minute * 60 + second - offset))
        guard zone.secondsFromGMT(for: instant) == offset else { throw AlAdhanError.malformed("\(text) isn't in \(zone.identifier)") }
        guard abs(date.days(until: civil)) <= 1 else { throw AlAdhanError.malformed("\(text) is far from \(date)") }
        return instant
    }

    // MARK: - Calendars and conversions

    static func gregorianMonth(_ data: Data, year: Int, month: Int, method: CalendarMethod) throws -> CalendarMonth {
        let days = try payload([Wire.DatePair].self, data).map { try calendarDay($0, method: method) }
        try checkGregorianMonth(days.map(\.gregorian), year: year, month: month)
        return CalendarMonth(axis: .gregorian(year: year, month: month), method: method, days: days)
    }

    static func hijriMonth(_ data: Data, year: Int, month: Int, method: CalendarMethod) throws -> CalendarMonth {
        let days = try payload([Wire.DatePair].self, data).map { try calendarDay($0, method: method) }
        try checkHijriMonth(gregorian: days.map(\.gregorian), hijri: days.map(\.hijri), year: year, month: month)
        return CalendarMonth(axis: .hijri(year: year, month: month), method: method, days: days)
    }

    static func conversion(_ data: Data, gregorian: CivilDate, method: CalendarMethod) throws -> CalendarDay {
        let day = try calendarDay(payload(Wire.DatePair.self, data), method: method)
        guard day.gregorian == gregorian else { throw AlAdhanError.noCoverage("asked for \(gregorian), got \(day.gregorian)") }
        return day
    }

    static func conversion(_ data: Data, hijri: HijriDate, method: CalendarMethod) throws -> CalendarDay {
        let day = try calendarDay(payload(Wire.DatePair.self, data), method: method)
        guard (day.hijri.year, day.hijri.month, day.hijri.day) == (hijri.year, hijri.month, hijri.day) else {
            throw AlAdhanError.noCoverage("asked for \(hijri.api), got \(day.hijri.api)")
        }
        return day
    }

    static func occasions(_ data: Data, hijriYear: Int, method: CalendarMethod) throws -> [Occasion] {
        let days = try payload([Wire.DatePair].self, data).map { try calendarDay($0, method: method) }
        guard days.allSatisfy({ $0.hijri.year == hijriYear }) else { throw AlAdhanError.noCoverage("not all in \(hijriYear)") }
        return Occasion.dedupe(days.flatMap(\.occasions))
    }

    private static func calendarDay(_ wire: Wire.DatePair, method: CalendarMethod) throws -> CalendarDay {
        let gregorian = try civilDate(wire.gregorian)
        let hijri = try hijriDate(wire.hijri, expecting: method)
        let occasions = Occasion.dedupe((wire.hijri.holidays ?? []).filter { !$0.isEmpty }.map {
            Occasion(title: $0, method: method, hijri: hijri, gregorian: gregorian)
        })
        return CalendarDay(gregorian: gregorian, hijri: hijri, method: method, occasions: occasions)
    }

    private static func civilDate(_ wire: Wire.Gregorian) throws -> CivilDate {
        guard let date = CivilDate(api: wire.date) else { throw AlAdhanError.malformed("not a date: \(wire.date)") }
        // The provider's weekday is checked against the calendar's, so a shifted date can't pass for a right one.
        let names = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        guard wire.weekday.en == names[date.weekday - 1] else { throw AlAdhanError.malformed("\(wire.date) isn't a \(wire.weekday.en)") }
        return date
    }

    private static func hijriDate(_ wire: Wire.Hijri, expecting method: CalendarMethod) throws -> HijriDate {
        guard wire.method == method.rawValue else { throw AlAdhanError.malformed("answered with calendar \(wire.method)") }
        guard let date = HijriDate(api: wire.date, monthLength: wire.month.days, monthName: wire.month.en, monthNameArabic: wire.month.ar, method: method),
              date.month == wire.month.number, Int(wire.year) == date.year else {
            throw AlAdhanError.malformed("not a Hijri date: \(wire.date)")
        }
        return date
    }

    private static func checkGregorianMonth(_ dates: [CivilDate], year: Int, month: Int) throws {
        guard !dates.isEmpty else { throw AlAdhanError.noCoverage("no days") }
        guard dates.allSatisfy({ $0.year == year && $0.month == month }) else { throw AlAdhanError.noCoverage("not all in \(year)-\(month)") }
        guard dates.count == CivilDate.days(inMonth: month, year: year), consecutive(dates), dates[0].day == 1 else {
            throw AlAdhanError.malformed("\(year)-\(month) isn't a whole month")
        }
    }

    /// A Hijri month has the length the dates say, so long as that is 29 or 30 days with nothing skipped.
    private static func checkHijriMonth(gregorian: [CivilDate], hijri: [HijriDate], year: Int, month: Int) throws {
        guard let first = hijri.first else { throw AlAdhanError.noCoverage("no days") }
        guard hijri.allSatisfy({ $0.year == year && $0.month == month }) else { throw AlAdhanError.noCoverage("not all in \(year)/\(month)") }
        guard (29...30).contains(hijri.count), first.day == 1, consecutive(gregorian),
              hijri.map(\.day) == Array(1...hijri.count), hijri.allSatisfy({ $0.monthLength.map { $0 == hijri.count } ?? true }) else {
            throw AlAdhanError.malformed("\(year)/\(month) isn't a whole month")
        }
    }

    private static func consecutive(_ dates: [CivilDate]) -> Bool {
        zip(dates, dates.dropFirst()).allSatisfy { $0.next == $1 }
    }

    // MARK: - Everything else

    static func qibla(_ data: Data, place: Place, fetched: Date) throws -> QiblaBearing {
        let wire = try payload(Wire.Qibla.self, data)
        guard let bearing = QiblaBearing(latitude: wire.latitude, longitude: wire.longitude, degrees: wire.direction, fetched: fetched) else {
            throw AlAdhanError.malformed("not a bearing: \(wire.direction)")
        }
        guard bearing.isFor(place) else { throw AlAdhanError.malformed("answered for other coordinates") }
        return bearing
    }

    static func names(_ data: Data) throws -> [NameEntry] {
        let wire = try payload([Wire.Name].self, data)
        let entries = wire.map { NameEntry(number: $0.number, arabic: $0.name, transliteration: $0.transliteration, meaning: $0.en.meaning) }.sorted { $0.number < $1.number }
        guard entries.map(\.number) == Array(1...99),
              entries.allSatisfy({ !$0.arabic.isEmpty && !$0.transliteration.isEmpty && !$0.meaning.isEmpty }) else {
            throw AlAdhanError.malformed("not the 99 names")
        }
        return entries
    }

    static func calendarMethods(_ data: Data) throws -> [CalendarMethodInfo] {
        let entries = try payload([Wire.CalendarMethodEntry].self, data).map { entry -> CalendarMethodInfo in
            guard let method = CalendarMethod(rawValue: entry.id) else { throw AlAdhanError.malformed("not a method: \(entry.id)") }
            return CalendarMethodInfo(method: method, name: entry.name, description: entry.description ?? "", validity: entry.validity ?? "")
        }
        guard !entries.isEmpty else { throw AlAdhanError.malformed("no methods") }
        return entries
    }

    /// By id. CUSTOM has no name and takes settings Noor doesn't send, so it isn't one to offer.
    static func prayerMethods(_ data: Data) throws -> [PrayerMethodInfo] {
        let entries = try payload([String: Wire.PrayerMethodEntry].self, data).filter { $0.value.id != 99 }.map { key, entry -> PrayerMethodInfo in
            guard let name = entry.name, !name.isEmpty else { throw AlAdhanError.malformed("\(key) has no name") }
            return PrayerMethodInfo(id: entry.id, key: key, name: name, parameters: entry.params?.mapValues(\.text) ?? [:])
        }
        guard !entries.isEmpty else { throw AlAdhanError.malformed("no methods") }
        return entries.sorted { $0.id < $1.id }
    }
}

/// The provider's JSON, only as far as the domain reads it.
private enum Wire {
    struct TimingDay: Decodable {
        let timings: [String: String?]
        let date: DatePair
        let meta: Meta
    }

    struct DatePair: Decodable {
        let hijri: Hijri
        let gregorian: Gregorian
    }

    struct Hijri: Decodable {
        struct Month: Decodable {
            let number: Int
            let en: String?
            let ar: String?
            let days: Int?
        }

        let date: String
        let month: Month
        let year: String
        let holidays: [String]?
        let method: String
    }

    struct Gregorian: Decodable {
        struct Weekday: Decodable { let en: String }

        let date: String
        let weekday: Weekday
    }

    struct Meta: Decodable {
        struct Method: Decodable {
            let id: Int
            let name: String?
        }

        let latitude: Double
        let longitude: Double
        let timezone: String
        let method: Method
        let latitudeAdjustmentMethod: String?
        let midnightMode: String?
        let school: String?
    }

    struct Qibla: Decodable {
        let latitude: Double
        let longitude: Double
        let direction: Double
    }

    struct Name: Decodable {
        struct English: Decodable { let meaning: String }

        let name: String
        let transliteration: String
        let number: Int
        let en: English
    }

    struct CalendarMethodEntry: Decodable {
        let id: String
        let name: String
        let description: String?
        let validity: String?
    }

    struct PrayerMethodEntry: Decodable {
        let id: Int
        let name: String?
        let params: [String: Parameter]?
    }

    /// An angle, or words like "90 min".
    struct Parameter: Decodable {
        let text: String

        init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let number = try? container.decode(Double.self) {
                text = number.formatted(.number.locale(Locale(identifier: "en_US_POSIX")).grouping(.never))
            } else {
                text = try container.decode(String.self)
            }
        }
    }
}
