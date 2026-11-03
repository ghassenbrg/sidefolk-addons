import Foundation

/// The one calendar date arithmetic uses: explicit Gregorian in an explicit zone, never `Calendar.current`.
enum Gregorian {
    static func calendar(in zone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }

    static let utc = calendar(in: TimeZone(secondsFromGMT: 0)!)
}

/// A date on the wall in some place, with no instant attached. Arithmetic runs in UTC, where every day has 24 hours, so
/// a DST change in the source's zone can't move it to another date. It encodes as its ISO string.
struct CivilDate: Hashable, Comparable, Sendable, Codable, CustomStringConvertible {
    let year: Int
    let month: Int
    let day: Int

    init?(year: Int, month: Int, day: Int) {
        // Foundation's Gregorian calendar turns Julian before October 1582.
        guard (1583...9999).contains(year), (1...12).contains(month),
              (1...Self.days(inMonth: month, year: year)).contains(day) else { return nil }
        (self.year, self.month, self.day) = (year, month, day)
    }

    /// Strict `YYYY-MM-DD`: `2026-3-4` and `03/04/2026` are refused, not guessed at.
    init?(iso text: String) {
        guard let m = text.wholeMatch(of: /(\d{4})-(\d{2})-(\d{2})/), let y = Int(m.1), let mo = Int(m.2), let d = Int(m.3) else { return nil }
        self.init(year: y, month: mo, day: d)
    }

    /// The API's `DD-MM-YYYY`.
    init?(api text: String) {
        guard let m = text.wholeMatch(of: /(\d{2})-(\d{2})-(\d{4})/), let d = Int(m.1), let mo = Int(m.2), let y = Int(m.3) else { return nil }
        self.init(year: y, month: mo, day: d)
    }

    /// The date this instant falls on in a zone.
    init(_ instant: Date, in zone: TimeZone) {
        let parts = Gregorian.calendar(in: zone).dateComponents([.year, .month, .day], from: instant)
        (year, month, day) = (parts.year!, parts.month!, parts.day!)
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        guard let date = CivilDate(iso: try container.decode(String.self)) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Not a civil date")
        }
        self = date
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(iso)
    }

    static func days(inMonth month: Int, year: Int) -> Int {
        switch month {
        case 2: (year % 4 == 0 && year % 100 != 0) || year % 400 == 0 ? 29 : 28
        case 4, 6, 9, 11: 30
        default: 31
        }
    }

    static func < (a: CivilDate, b: CivilDate) -> Bool { (a.year, a.month, a.day) < (b.year, b.month, b.day) }

    /// This date's midnight in UTC, only ever a handle for arithmetic.
    var anchor: Date {
        Gregorian.utc.date(from: DateComponents(year: year, month: month, day: day))!
    }

    func adding(days: Int) -> CivilDate {
        CivilDate(Gregorian.utc.date(byAdding: .day, value: days, to: anchor)!, in: Gregorian.utc.timeZone)
    }

    var next: CivilDate { adding(days: 1) }
    var previous: CivilDate { adding(days: -1) }

    /// 1 is Sunday through 7 Saturday, as Foundation counts.
    var weekday: Int { Gregorian.utc.component(.weekday, from: anchor) }

    func days(until other: CivilDate) -> Int {
        Gregorian.utc.dateComponents([.day], from: anchor, to: other.anchor).day!
    }

    var iso: String { String(format: "%04d-%02d-%02d", year, month, day) }
    var api: String { String(format: "%02d-%02d-%04d", day, month, year) }
    var description: String { iso }
}
