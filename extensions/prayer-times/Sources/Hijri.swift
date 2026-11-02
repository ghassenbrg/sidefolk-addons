import Foundation

/// A Hijri date as a provider reported it, or as someone typed it for a conversion.
struct HijriDate: Hashable, Sendable, Codable {
    let year: Int
    let month: Int
    let day: Int
    /// The month's real length when the provider gave it; a lunar month is never assumed to have 30 days.
    let monthLength: Int?
    let monthName: String?
    let monthNameArabic: String?
    let method: CalendarMethod?

    /// Refuses what no month can hold, before anything is requested.
    init?(year: Int, month: Int, day: Int, monthLength: Int? = nil, monthName: String? = nil, monthNameArabic: String? = nil, method: CalendarMethod? = nil) {
        guard monthLength.map({ (29...30).contains($0) }) ?? true, (1...9999).contains(year), (1...12).contains(month),
              (1...(monthLength ?? 30)).contains(day) else { return nil }
        (self.year, self.month, self.day, self.monthLength) = (year, month, day, monthLength)
        (self.monthName, self.monthNameArabic, self.method) = (monthName, monthNameArabic, method)
    }

    /// `DD-MM-YYYY`, as the API writes and reads them.
    init?(api text: String, monthLength: Int? = nil, monthName: String? = nil, monthNameArabic: String? = nil, method: CalendarMethod? = nil) {
        guard let m = text.wholeMatch(of: /(\d{2})-(\d{2})-(\d{4})/), let d = Int(m.1), let mo = Int(m.2), let y = Int(m.3) else { return nil }
        self.init(year: y, month: mo, day: d, monthLength: monthLength, monthName: monthName, monthNameArabic: monthNameArabic, method: method)
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let date = HijriDate(year: try c.decode(Int.self, forKey: .year), month: try c.decode(Int.self, forKey: .month), day: try c.decode(Int.self, forKey: .day),
                             monthLength: try c.decodeIfPresent(Int.self, forKey: .monthLength), monthName: try c.decodeIfPresent(String.self, forKey: .monthName),
                             monthNameArabic: try c.decodeIfPresent(String.self, forKey: .monthNameArabic), method: try c.decodeIfPresent(CalendarMethod.self, forKey: .method))
        guard let date else { throw DecodingError.dataCorruptedError(forKey: .day, in: c, debugDescription: "Not a Hijri date") }
        self = date
    }

    var api: String { String(format: "%02d-%02d-%04d", day, month, year) }
}

/// One paired date: the provider's civil correspondence, which rolls at place-local midnight and says nothing about the
/// ritual day's sunset boundary.
struct CalendarDay: Hashable, Sendable, Codable {
    let gregorian: CivilDate
    let hijri: HijriDate
    let method: CalendarMethod
    let occasions: [Occasion]
}

/// A month as the provider returned it. Its length and where it starts in a week come from the returned dates.
struct CalendarMonth: Hashable, Sendable, Codable {
    enum Axis: Hashable, Sendable, Codable {
        case gregorian(year: Int, month: Int)
        case hijri(year: Int, month: Int)
    }

    let axis: Axis
    let method: CalendarMethod
    let days: [CalendarDay]

    var dayCount: Int { days.count }

    /// Empty cells before day one in a grid whose weeks start on `firstWeekday` (1 Sunday through 7 Saturday).
    func leadingBlanks(firstWeekday: Int = 1) -> Int {
        guard let first = days.first else { return 0 }
        return (first.gregorian.weekday - firstWeekday + 7) % 7
    }
}

/// An observance the provider lists under a method: calculated, and local observance may differ. Different traditions'
/// events on one date stay separate records.
struct Occasion: Hashable, Sendable, Codable {
    /// `title` normalized, the same across years: what a reminder selection stores.
    let identity: String
    let method: CalendarMethod
    let hijri: HijriDate
    let gregorian: CivilDate
    let title: String

    init(title: String, method: CalendarMethod, hijri: HijriDate, gregorian: CivilDate) {
        self.identity = Self.normalize(title)
        (self.title, self.method, self.hijri, self.gregorian) = (title, method, hijri, gregorian)
    }

    /// Lowercase ASCII words joined by dashes, so spelling marks and the API's non-breaking hyphens don't split one event
    /// in two, and it can sit in an occurrence id. A title with no Latin letters keeps its scalars, in hex.
    static func normalize(_ title: String) -> String {
        let folded = title.folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX")).lowercased()
        let words = folded.split { !($0.isASCII && ($0.isLetter || $0.isNumber)) }
        if words.isEmpty { return title.unicodeScalars.map { String($0.value, radix: 16) }.joined(separator: "-") }
        return words.joined(separator: "-")
    }

    /// One record per method, civil date and event, in the order first seen.
    static func dedupe(_ occasions: [Occasion]) -> [Occasion] {
        var seen = Set<String>()
        return occasions.filter { seen.insert("\($0.method.rawValue)|\($0.gregorian.iso)|\($0.identity)").inserted }
    }
}
