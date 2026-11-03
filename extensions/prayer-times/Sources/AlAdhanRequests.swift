import Foundation

/// One call to the provider: where it goes, what it is cached under, how long before asking again, and how to read the
/// answer. Keeping them together means a cache key can't drift from the URL it stands for.
struct AlAdhanRequest<Value: Codable & Sendable>: Sendable {
    let url: URL
    let cacheKey: String
    /// Fetch age only: a cached answer past this is asked for again, but it still counts until then and after a failure.
    /// Whether it covers a date is settled by the key and the decoder, never by how old it is.
    let refreshAfter: TimeInterval
    let decode: @Sendable (Data, Date) throws -> Value
}

/// Everything that changes the times a place gets. The label isn't here, so renaming a place reuses its cache.
struct PrayerQuery: Hashable, Sendable {
    let place: Place
    let convention: PrayerConvention
    let calendarMethod: CalendarMethod

    var sourceID: String { TimetableSource.calculatedID(for: place) }

    /// The provider's tune string has nine slots; Noor only adjusts the five prayers.
    var tune: String? {
        guard !convention.tune.isEmpty else { return nil }
        func t(_ id: PrayerID) -> Int { convention.tune[id] ?? 0 }
        return [0, t(.fajr), 0, t(.dhuhr), t(.asr), t(.maghrib), 0, t(.isha), 0].map(String.init).joined(separator: ",")
    }

    var items: [(String, String)] {
        var items = [("latitude", AlAdhan.coordinate(place.latitude)), ("longitude", AlAdhan.coordinate(place.longitude)),
                     ("method", String(convention.method)), ("school", String(convention.school)), ("timezonestring", place.zoneID),
                     ("calendarMethod", calendarMethod.rawValue), ("iso8601", "true")]
        if let adjustment = convention.latitudeAdjustment { items.append(("latitudeAdjustmentMethod", String(adjustment))) }
        if let tune { items.append(("tune", tune)) }
        return items
    }

    var key: String {
        [sourceID, AlAdhan.coordinate(place.latitude), AlAdhan.coordinate(place.longitude), place.zoneID, "m\(convention.method)", "s\(convention.school)",
         "la\(convention.latitudeAdjustment.map(String.init) ?? "-")", "t\(tune ?? "-")", "c\(calendarMethod.rawValue)"].joined(separator: "|")
    }
}

/// The provider's endpoints as typed requests. Prayer times, calendars and conversions all carry the method they were asked
/// for, and each decoder checks the answer is the one asked for.
enum AlAdhan {
    static let base = URL(string: "https://api.aladhan.com/v1")!

    private static let week: TimeInterval = 7 * 24 * 3600
    private static let month: TimeInterval = 30 * 24 * 3600

    /// Four decimals, about ten metres: all the precision these answers can use, and no more than they need of where
    /// someone is. Requests, cache keys and "is this for that place" all use it, so they can't disagree.
    static func coordinate(_ value: Double) -> String {
        let rounded = (value * 10_000).rounded() / 10_000
        return String(format: "%.4f", rounded == 0 ? 0 : rounded) // Never "-0.0000", which wouldn't match an echoed 0.
    }

    static func url(_ path: String..., query: [(String, String)] = []) -> URL {
        var components = URLComponents(url: path.reduce(base) { $0.appending(path: $1) }, resolvingAgainstBaseURL: false)!
        // URLComponents leaves "+" and "/" alone in query values, and a server reads that "+" (Etc/GMT+5) as a space.
        let unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
        if !query.isEmpty {
            components.percentEncodedQueryItems = query.map {
                URLQueryItem(name: $0.0, value: $0.1.addingPercentEncoding(withAllowedCharacters: unreserved))
            }
        }
        return components.url!
    }

    private static func methodQuery(_ method: CalendarMethod) -> [(String, String)] { [("calendarMethod", method.rawValue)] }

    static func timings(_ date: CivilDate, _ query: PrayerQuery) -> AlAdhanRequest<PrayerDay> {
        AlAdhanRequest(url: url("timings", date.api, query: query.items), cacheKey: "timings|\(date.iso)|\(query.key)", refreshAfter: week) { data, _ in
            try AlAdhanDecoder.timings(data, date: date, query: query)
        }
    }

    /// A Gregorian month of prayer days.
    static func prayerCalendar(year: Int, month gregorianMonth: Int, _ query: PrayerQuery) -> AlAdhanRequest<[PrayerDay]> {
        AlAdhanRequest(url: url("calendar", String(year), String(gregorianMonth), query: query.items),
                       cacheKey: "calendar|\(year)-\(gregorianMonth)|\(query.key)", refreshAfter: week) { data, _ in
            try AlAdhanDecoder.prayerCalendar(data, year: year, month: gregorianMonth, query: query)
        }
    }

    /// A Hijri month of prayer days: the Ramadan planner's month 9.
    static func hijriPrayerCalendar(year: Int, month hijriMonth: Int, _ query: PrayerQuery) -> AlAdhanRequest<[PrayerDay]> {
        AlAdhanRequest(url: url("hijriCalendar", String(year), String(hijriMonth), query: query.items),
                       cacheKey: "hijriCalendar|\(year)-\(hijriMonth)|\(query.key)", refreshAfter: week) { data, _ in
            try AlAdhanDecoder.hijriPrayerCalendar(data, year: year, month: hijriMonth, query: query)
        }
    }

    static func gregorianMonth(year: Int, month gregorian: Int, method: CalendarMethod) -> AlAdhanRequest<CalendarMonth> {
        AlAdhanRequest(url: url("gToHCalendar", String(gregorian), String(year), query: methodQuery(method)),
                       cacheKey: "gToHCalendar|\(year)-\(gregorian)|\(method)", refreshAfter: week) { data, _ in
            try AlAdhanDecoder.gregorianMonth(data, year: year, month: gregorian, method: method)
        }
    }

    static func hijriMonth(year: Int, month hijri: Int, method: CalendarMethod) -> AlAdhanRequest<CalendarMonth> {
        AlAdhanRequest(url: url("hToGCalendar", String(hijri), String(year), query: methodQuery(method)),
                       cacheKey: "hToGCalendar|\(year)-\(hijri)|\(method)", refreshAfter: week) { data, _ in
            try AlAdhanDecoder.hijriMonth(data, year: year, month: hijri, method: method)
        }
    }

    static func gregorianToHijri(_ date: CivilDate, method: CalendarMethod) -> AlAdhanRequest<CalendarDay> {
        AlAdhanRequest(url: url("gToH", date.api, query: methodQuery(method)), cacheKey: "gToH|\(date.iso)|\(method)", refreshAfter: week) { data, _ in
            try AlAdhanDecoder.conversion(data, gregorian: date, method: method)
        }
    }

    static func hijriToGregorian(_ date: HijriDate, method: CalendarMethod) -> AlAdhanRequest<CalendarDay> {
        AlAdhanRequest(url: url("hToG", date.api, query: methodQuery(method)), cacheKey: "hToG|\(date.api)|\(method)", refreshAfter: week) { data, _ in
            try AlAdhanDecoder.conversion(data, hijri: date, method: method)
        }
    }

    static func qibla(_ place: Place) -> AlAdhanRequest<QiblaBearing> {
        let (latitude, longitude) = (coordinate(place.latitude), coordinate(place.longitude))
        return AlAdhanRequest(url: url("qibla", latitude, longitude), cacheKey: "qibla|\(latitude)|\(longitude)", refreshAfter: month) { data, now in
            try AlAdhanDecoder.qibla(data, place: place, fetched: now)
        }
    }

    static func names() -> AlAdhanRequest<[NameEntry]> {
        AlAdhanRequest(url: url("asmaAlHusna"), cacheKey: "asmaAlHusna", refreshAfter: month) { data, _ in try AlAdhanDecoder.names(data) }
    }

    static func calendarMethods() -> AlAdhanRequest<[CalendarMethodInfo]> {
        AlAdhanRequest(url: url("islamicCalendar", "methods"), cacheKey: "islamicCalendar/methods", refreshAfter: month) { data, _ in
            try AlAdhanDecoder.calendarMethods(data)
        }
    }

    static func prayerMethods() -> AlAdhanRequest<[PrayerMethodInfo]> {
        AlAdhanRequest(url: url("methods"), cacheKey: "methods", refreshAfter: month) { data, _ in try AlAdhanDecoder.prayerMethods(data) }
    }

    static func occasions(hijriYear: Int, method: CalendarMethod) -> AlAdhanRequest<[Occasion]> {
        AlAdhanRequest(url: url("islamicHolidaysByHijriYear", String(hijriYear), query: methodQuery(method)),
                       cacheKey: "islamicHolidaysByHijriYear|\(hijriYear)|\(method)", refreshAfter: week) { data, _ in
            try AlAdhanDecoder.occasions(data, hijriYear: hijriYear, method: method)
        }
    }
}
