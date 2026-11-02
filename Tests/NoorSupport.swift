import Foundation
@testable import ext_prayer_times

/// What Noor's domain tests share: the saved provider answers, a Tokyo place, and days built from wall-clock times.
enum NoorSupport {
    static let fixtures = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appending(path: "extensions/prayer-times/Fixtures")

    static func fixture(_ name: String) throws -> Data {
        try Data(contentsOf: fixtures.appending(path: "\(name).json"))
    }

    static let tokyo = try! Place(id: "tokyo", label: "Tokyo", country: "Japan", latitude: 35.6762, longitude: 139.6503, zoneID: "Asia/Tokyo")
    static let mwl = try! PrayerConvention(method: 3)
    static let query = PrayerQuery(place: tokyo, convention: mwl, calendarMethod: .uaq)
    static let tokyoSource = TimetableSource.calculated(for: tokyo)
    static let tokyoZone = TimeZone(identifier: "Asia/Tokyo")!

    static func date(_ iso: String) -> CivilDate { CivilDate(iso: iso)! }

    /// `2026-11-02T04:37:00+09:00`, read by a formatter the code under test doesn't use.
    static func instant(_ text: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: text)!
    }

    static func clock(_ instant: Date, _ zone: TimeZone = tokyoZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = zone
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: instant)
    }

    static func at(_ iso: String, _ time: String, _ zone: TimeZone = tokyoZone) -> Date {
        CivilClock.resolve(date(iso), LocalTime(text: time)!, in: zone).settled
    }

    /// A day with these starts in prayer order.
    static func day(_ iso: String, zone: String = "Asia/Tokyo", source: String = "calculated.tokyo", times: [String] = ["05:00", "11:30", "14:30", "17:00", "18:30"],
                    iqamah: [PrayerID: String] = [:], shift: TimeInterval = 0) -> PrayerDay {
        let timeZone = TimeZone(identifier: zone)!
        let starts = Dictionary(uniqueKeysWithValues: zip(PrayerID.allCases, times).map { ($0, at(iso, $1, timeZone).addingTimeInterval(shift)) })
        return PrayerDay(date: date(iso), zoneID: zone, sourceID: source, starts: starts, iqamah: iqamah.mapValues { at(iso, $0, timeZone) })!
    }

    /// A saved answer with one value changed, or removed when `value` is nil. Path steps are keys and array indexes.
    static func edited(_ name: String, _ path: [Any], _ value: Any?) throws -> Data {
        func walk(_ node: Any, _ path: ArraySlice<Any>) -> Any {
            guard let step = path.first else { return value as Any }
            if let key = step as? String, var object = node as? [String: Any] {
                if path.count == 1, value == nil { object.removeValue(forKey: key) } else { object[key] = walk(object[key] as Any, path.dropFirst()) }
                return object
            }
            if let index = step as? Int, var array = node as? [Any] {
                if path.count == 1, value == nil { array.remove(at: index) } else { array[index] = walk(array[index], path.dropFirst()) }
                return array
            }
            fatalError("No \(step) in the fixture")
        }
        return try JSONSerialization.data(withJSONObject: walk(try JSONSerialization.jsonObject(with: fixture(name)), path[...]))
    }

    static func temporaryFolder() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "noor-tests-\(UUID().uuidString)")
    }
}

/// A network that plays back answers in order and remembers what it was asked.
actor ScriptedFetch: Fetching {
    enum Reply {
        case answer(Int, Data)
        case failure
    }

    private var replies: [Reply]
    private(set) var asked: [URL] = []

    init(_ replies: [Reply]) { self.replies = replies }

    func get(_ url: URL) async throws -> (status: Int, body: Data) {
        asked.append(url)
        guard !replies.isEmpty else { throw URLError(.notConnectedToInternet) }
        switch replies.removeFirst() {
        case .answer(let status, let body): return (status, body)
        case .failure: throw URLError(.notConnectedToInternet)
        }
    }
}

/// Waits nothing and writes down how long it was told to.
actor SleepLog {
    private(set) var delays: [TimeInterval] = []
    func record(_ delay: TimeInterval) { delays.append(delay) }
}
