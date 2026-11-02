import Foundation

/// A time on the wall, with no date or zone.
struct LocalTime: Hashable, Comparable, Sendable, Codable, CustomStringConvertible {
    let hour: Int
    let minute: Int

    init?(hour: Int, minute: Int) {
        guard (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        (self.hour, self.minute) = (hour, minute)
    }

    /// Strict `HH:mm`, 24-hour: `7:05` and `7:05 PM` are refused.
    init?(text: String) {
        guard let m = text.wholeMatch(of: /(\d{2}):(\d{2})/), let h = Int(m.1), let min = Int(m.2) else { return nil }
        self.init(hour: h, minute: min)
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        guard let time = LocalTime(text: try container.decode(String.self)) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Not a local time")
        }
        self = time
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(text)
    }

    static func < (a: LocalTime, b: LocalTime) -> Bool { (a.hour, a.minute) < (b.hour, b.minute) }

    var text: String { String(format: "%02d:%02d", hour, minute) }
    var description: String { text }
}

/// What a wall-clock time means on one date in one zone. DST makes it none or two instants, and which callers may guess
/// differs: a timetable row must report it, a daily reminder may fire when the clock jumps.
enum LocalInstant: Equatable, Sendable {
    case exact(Date)
    /// The clock skipped this time; `shifted` is the same distance past the jump.
    case gap(shifted: Date)
    /// The clock showed this time twice.
    case fold(earlier: Date, later: Date)

    /// The instant a reminder or a day boundary uses, for callers that accept the shift.
    var settled: Date {
        switch self {
        case .exact(let date), .gap(let date), .fold(let date, _): date
        }
    }
}

enum CivilClock {
    /// Tries the zone's offsets on either side of the moment and keeps those that hold there. Foundation's own answer
    /// silently moves a gap and picks one side of a fold, which is what this exists to report.
    static func resolve(_ date: CivilDate, _ time: LocalTime, in zone: TimeZone) -> LocalInstant {
        let wall = date.anchor.addingTimeInterval(TimeInterval(time.hour * 3600 + time.minute * 60))
        // Offsets stay within a day of UTC, so these two brackets hold the real instant.
        let before = zone.secondsFromGMT(for: wall.addingTimeInterval(-86_400))
        let after = zone.secondsFromGMT(for: wall.addingTimeInterval(86_400))
        let holding = Set([before, after]).filter { zone.secondsFromGMT(for: wall.addingTimeInterval(TimeInterval(-$0))) == $0 }
            .map { wall.addingTimeInterval(TimeInterval(-$0)) }.sorted()
        switch holding.count {
        case 0: return .gap(shifted: wall.addingTimeInterval(TimeInterval(-before)))
        case 1: return .exact(holding[0])
        default: return .fold(earlier: holding[0], later: holding[1])
        }
    }

    /// The first instant of a civil date. Where midnight is skipped (Havana in March) it is the moment of the jump.
    static func startOfDay(_ date: CivilDate, in zone: TimeZone) -> Date {
        resolve(date, LocalTime(hour: 0, minute: 0)!, in: zone).settled
    }
}
