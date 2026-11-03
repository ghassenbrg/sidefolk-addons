import Foundation
import Testing
@testable import ext_prayer_times

/// Civil dates, zones and DST, with reference checks worked out here rather than copied from the provider.
struct NoorTimeTests {
    typealias S = NoorSupport

    let newYork = TimeZone(identifier: "America/New_York")!
    let london = TimeZone(identifier: "Europe/London")!

    @Test func civilDatesAreValidated() throws {
        #expect(CivilDate(year: 2027, month: 2, day: 31) == nil)
        #expect(CivilDate(year: 2026, month: 13, day: 1) == nil && CivilDate(year: 2026, month: 0, day: 1) == nil && CivilDate(year: 2026, month: 4, day: 31) == nil)
        #expect(CivilDate(year: 2028, month: 2, day: 29) != nil && CivilDate(year: 2100, month: 2, day: 29) == nil && CivilDate(year: 2000, month: 2, day: 29) != nil)
        #expect(CivilDate(iso: "2026-3-4") == nil && CivilDate(iso: "03/04/2026") == nil && CivilDate(iso: "2026-11-02T00:00") == nil && CivilDate(iso: "2027-02-31") == nil)
        let date = try #require(CivilDate(iso: "2026-11-02"))
        #expect(date.iso == "2026-11-02" && date.api == "02-11-2026" && CivilDate(api: "02-11-2026") == date)
        #expect(try JSONDecoder().decode(CivilDate.self, from: JSONEncoder().encode(date)) == date)
        #expect(throws: (any Error).self) { try JSONDecoder().decode(CivilDate.self, from: Data(#""2027-02-31""#.utf8)) }
    }

    @Test func nextAndPreviousGoByTheCalendar() throws {
        #expect(S.date("2026-12-31").next == S.date("2027-01-01") && S.date("2027-01-01").previous == S.date("2026-12-31"))
        #expect(S.date("2028-02-28").next == S.date("2028-02-29") && S.date("2027-02-28").next == S.date("2027-03-01"))
        // Both DST days and the ones around them: 23- and 25-hour days are still one date each.
        #expect(S.date("2026-03-07").next == S.date("2026-03-08") && S.date("2026-03-08").next == S.date("2026-03-09"))
        #expect(S.date("2026-10-31").next == S.date("2026-11-01") && S.date("2026-11-01").next == S.date("2026-11-02"))
        #expect(S.date("2026-11-02").adding(days: 35) == S.date("2026-12-07") && S.date("2026-11-02").days(until: S.date("2026-12-07")) == 35)
        #expect(S.date("2026-11-02") < S.date("2026-11-03") && S.date("2026-12-01") > S.date("2026-11-30"))
    }

    /// Zeller's congruence, which owes nothing to Foundation or the provider.
    @Test func weekdayAgreesWithAnIndependentFormula() throws {
        func zeller(_ date: CivilDate) -> Int {
            let (m, y) = date.month < 3 ? (date.month + 12, date.year - 1) : (date.month, date.year)
            let h = (date.day + (13 * (m + 1)) / 5 + y + y / 4 - y / 100 + y / 400) % 7
            return (h + 6) % 7 + 1 // Zeller's 0 is Saturday; here 1 is Sunday.
        }
        var date = S.date("2026-01-01")
        for _ in 0..<800 {
            #expect(date.weekday == zeller(date), Comment(rawValue: date.iso))
            date = date.next
        }
        #expect(S.date("2026-11-02").weekday == 2, "the fixture's Monday")
    }

    @Test func thePlacesDateIsNotAnyoneElses() throws {
        let instant = S.instant("2026-11-02T20:00:00Z")
        #expect(CivilDate(instant, in: S.tokyoZone) == S.date("2026-11-03"))
        #expect(CivilDate(instant, in: newYork) == S.date("2026-11-02"))
        #expect(CivilDate(instant, in: TimeZone(identifier: "Pacific/Kiritimati")!) == S.date("2026-11-03"))
        #expect(CivilDate(instant, in: TimeZone(identifier: "Pacific/Pago_Pago")!) == S.date("2026-11-02"))
    }

    /// With the process's own zone set to the far side of the world, nothing moves. Restored straight after; tests run
    /// serially here (D18).
    @Test func theDeviceZoneChangesNothing() throws {
        func useZone(_ id: String?) {
            if let id { setenv("TZ", id, 1) } else { unsetenv("TZ") }
            tzset()
            NSTimeZone.resetSystemTimeZone()
        }
        let original = ProcessInfo.processInfo.environment["TZ"]
        defer { useZone(original) }
        func results() -> [String] {
            let instant = S.instant("2026-11-02T20:00:00Z")
            let days = [S.day("2026-11-02"), S.day("2026-11-03")]
            var prefs = Preferences()
            prefs.place = S.tokyo
            prefs.sourceID = S.tokyoSource.id
            prefs.reminders.master = true
            prefs.reminders.route.companion = true
            prefs.reminders.prayers[.fajr] = .init(atStart: true)
            let snapshot = NoorSnapshot.make(now: instant, prefs: prefs, sources: [S.tokyoSource], days: days, calendar: nil, qibla: nil, name: nil)
            let plan = Planner.plan(now: instant, prefs: prefs, days: days, ramadan: nil, occasions: [], names: [])
            return [CivilDate(instant, in: S.tokyoZone).iso, snapshot.localDate?.iso ?? "", String(describing: snapshot.next), plan.map(\.id).joined(), String(describing: plan.map(\.at)),
                    String(describing: DialGeometry.nodes(day: days[1], now: instant)), CivilDate(iso: "2026-03-08")!.next.iso]
        }
        useZone("Pacific/Kiritimati")
        #expect(TimeZone.current.identifier == "Pacific/Kiritimati")
        let east = results()
        useZone("Pacific/Pago_Pago")
        #expect(TimeZone.current.identifier == "Pacific/Pago_Pago")
        #expect(results() == east)
        #expect(east[0] == "2026-11-03" && east[1] == "2026-11-03")
    }

    @Test func dstGapAndFoldInNewYork() throws {
        #expect(CivilClock.resolve(S.date("2026-03-08"), LocalTime(hour: 2, minute: 30)!, in: newYork) == .gap(shifted: S.instant("2026-03-08T07:30:00Z")))
        #expect(CivilClock.resolve(S.date("2026-03-08"), LocalTime(hour: 3, minute: 0)!, in: newYork) == .exact(S.instant("2026-03-08T07:00:00Z")))
        #expect(CivilClock.resolve(S.date("2026-03-08"), LocalTime(hour: 1, minute: 59)!, in: newYork) == .exact(S.instant("2026-03-08T06:59:00Z")))
        #expect(CivilClock.resolve(S.date("2026-11-01"), LocalTime(hour: 1, minute: 30)!, in: newYork)
            == .fold(earlier: S.instant("2026-11-01T05:30:00Z"), later: S.instant("2026-11-01T06:30:00Z")))
        #expect(CivilClock.resolve(S.date("2026-11-01"), LocalTime(hour: 2, minute: 0)!, in: newYork) == .exact(S.instant("2026-11-01T07:00:00Z")))
        #expect(CivilClock.resolve(S.date("2026-11-02"), LocalTime(hour: 1, minute: 30)!, in: newYork) == .exact(S.instant("2026-11-02T06:30:00Z")))
    }

    @Test func dstGapAndFoldInLondon() throws {
        #expect(CivilClock.resolve(S.date("2026-03-29"), LocalTime(hour: 1, minute: 30)!, in: london) == .gap(shifted: S.instant("2026-03-29T01:30:00Z")))
        #expect(CivilClock.resolve(S.date("2026-10-25"), LocalTime(hour: 1, minute: 30)!, in: london)
            == .fold(earlier: S.instant("2026-10-25T00:30:00Z"), later: S.instant("2026-10-25T01:30:00Z")))
    }

    /// The law, not the provider: US clocks go forward on the second Sunday of March, UK clocks on the last Sunday of March.
    /// Found by weekday here, then only that date may have a gap.
    @Test func knownDSTDatesFromTheirRules() throws {
        let march = (1...31).map { CivilDate(year: 2026, month: 3, day: $0)! }
        let secondSunday = march.filter { $0.weekday == 1 }[1]
        let lastSunday = march.filter { $0.weekday == 1 }.last!
        #expect(secondSunday == S.date("2026-03-08") && lastSunday == S.date("2026-03-29"))
        func isGap(_ date: CivilDate, _ hour: Int, _ zone: TimeZone) -> Bool {
            if case .gap = CivilClock.resolve(date, LocalTime(hour: hour, minute: 30)!, in: zone) { return true }
            return false
        }
        #expect(march.filter { isGap($0, 2, newYork) } == [secondSunday])
        #expect(march.filter { isGap($0, 1, london) } == [lastSunday])
        func hours(_ date: CivilDate, _ zone: TimeZone) -> Double {
            CivilClock.startOfDay(date.next, in: zone).timeIntervalSince(CivilClock.startOfDay(date, in: zone)) / 3600
        }
        #expect(hours(secondSunday, newYork) == 23 && hours(S.date("2026-11-01"), newYork) == 25 && hours(S.date("2026-11-02"), newYork) == 24)
        #expect(hours(lastSunday, london) == 23 && hours(S.date("2026-10-25"), london) == 25)
    }

    @Test func aSkippedMidnightStartsTheDayAtTheJump() throws {
        let havana = TimeZone(identifier: "America/Havana")!
        #expect(CivilClock.startOfDay(S.date("2026-03-08"), in: havana) == S.instant("2026-03-08T05:00:00Z"))
        #expect(CivilDate(CivilClock.startOfDay(S.date("2026-03-08"), in: havana), in: havana) == S.date("2026-03-08"))
    }

    @Test func localTimesAreStrict() throws {
        #expect(LocalTime(text: "07:05")?.text == "07:05" && LocalTime(text: "23:59") != nil && LocalTime(text: "00:00") != nil)
        for bad in ["7:05", "24:00", "12:60", "7:05 PM", "0705", "", "12:5"] { #expect(LocalTime(text: bad) == nil, Comment(rawValue: bad)) }
    }

    @Test func zonesMustBeRealNames() throws {
        for good in ["Asia/Tokyo", "America/New_York", "Europe/London", "America/Argentina/Buenos_Aires", "UTC", "Etc/GMT+5", "Asia/Kolkata"] {
            #expect(IANAZone.zone(good) != nil, Comment(rawValue: good))
        }
        for bad in ["Mars/Olympus", "", "EST", "GMT+5", "Tokyo", "asia/tokyo", "Asia/Tokyo ", "../etc/passwd", "+09:00"] {
            #expect(IANAZone.zone(bad) == nil, Comment(rawValue: bad))
        }
    }

    @Test func placesAreValidated() throws {
        func place(latitude: Double = 35, longitude: Double = 139, zone: String = "Asia/Tokyo", id: String = "a", label: String = "A") throws -> Place {
            try Place(id: id, label: label, latitude: latitude, longitude: longitude, zoneID: zone)
        }
        #expect(throws: Place.Problem.badLatitude) { try place(latitude: .nan) }
        #expect(throws: Place.Problem.badLatitude) { try place(latitude: .infinity) }
        #expect(throws: Place.Problem.badLatitude) { try place(latitude: 90.5) }
        #expect(throws: Place.Problem.badLongitude) { try place(longitude: -181) }
        #expect(throws: Place.Problem.badLongitude) { try place(longitude: .nan) }
        #expect(throws: Place.Problem.badZone) { try place(zone: "Mars/Olympus") }
        #expect(throws: Place.Problem.badID) { try place(id: "../up") }
        #expect(throws: Place.Problem.emptyLabel) { try place(label: "  ") }
        #expect(throws: Place.Problem.badID) { try place(id: String(repeating: "a", count: 125)) }
        let longest = try place(id: String(repeating: "a", count: 117))
        #expect(TimetableSource.calculated(for: longest).id.count == 128, "the longest id still makes a source")
        #expect(AlAdhan.coordinate(-0.00001) == "0.0000" && AlAdhan.coordinate(-74.00604) == "-74.0060" && AlAdhan.coordinate(35.6762) == "35.6762")
        let shared = try Place(id: "s", label: "Here", latitude: 1, longitude: 2, zoneID: "UTC", origin: .shared, consentRevision: 4)
        #expect(try JSONDecoder().decode(Place.self, from: JSONEncoder().encode(shared)) == shared)
        let tampered = try JSONSerialization.data(withJSONObject: ["id": "s", "label": "Here", "latitude": 91, "longitude": 2, "zoneID": "UTC", "origin": "manual"])
        #expect(throws: (any Error).self) { try JSONDecoder().decode(Place.self, from: tampered) }
    }

    @Test func conventionsAreBounded() throws {
        #expect(throws: PrayerConvention.Problem.badSchool) { try PrayerConvention(method: 3, school: 2) }
        #expect(throws: PrayerConvention.Problem.badMethod) { try PrayerConvention(method: 99) }
        #expect(throws: PrayerConvention.Problem.badMethod) { try PrayerConvention(method: -1) }
        #expect(throws: PrayerConvention.Problem.badLatitudeAdjustment) { try PrayerConvention(method: 3, latitudeAdjustment: 4) }
        #expect(throws: PrayerConvention.Problem.tuneOutOfBounds) { try PrayerConvention(method: 3, tune: [.fajr: 31]) }
        #expect(throws: PrayerConvention.Problem.tuneOutOfBounds) { try PrayerConvention(method: 3, tune: [.isha: -31]) }
        let tuned = try PrayerConvention(method: 3, tune: [.fajr: 30, .isha: -30, .asr: 0])
        #expect(tuned.tune == [.fajr: 30, .isha: -30], "zero is no adjustment")
        #expect(try JSONDecoder().decode(PrayerConvention.self, from: JSONEncoder().encode(tuned)) == tuned)
        let tampered = Data(#"{"method":3,"school":0,"tune":{"fajr":90}}"#.utf8)
        #expect(throws: (any Error).self) { try JSONDecoder().decode(PrayerConvention.self, from: tampered) }
    }

    @Test func prayerAndCalendarMethodsAreIndependent() throws {
        var prefs = Preferences()
        prefs.convention = S.mwl
        prefs.calendarMethod = .diyanet
        #expect(prefs.convention == S.mwl)
        prefs.convention = try PrayerConvention(method: 2, school: 1)
        #expect(prefs.calendarMethod == .diyanet)
        #expect(CalendarMethod(rawValue: "UAQ") == .uaq && CalendarMethod(rawValue: "HIJRI") != nil && CalendarMethod(rawValue: "../x") == nil && CalendarMethod(rawValue: "") == nil)
    }

    @Test func hijriDatesAreValidatedBeforeAsking() throws {
        #expect(HijriDate(year: 1448, month: 5, day: 30) != nil)
        #expect(HijriDate(year: 1448, month: 5, day: 31) == nil && HijriDate(year: 1448, month: 13, day: 1) == nil && HijriDate(year: 1448, month: 5, day: 0) == nil)
        #expect(HijriDate(year: 1448, month: 9, day: 30, monthLength: 29) == nil, "a 29-day month has no 30th")
        #expect(HijriDate(year: 1448, month: 9, day: 1, monthLength: 28) == nil)
        #expect(HijriDate(api: "22-05-1448")?.api == "22-05-1448" && HijriDate(api: "1448-05-22") == nil)
    }

    @Test func aPrayerDayRefusesAnythingInferred() throws {
        let starts = S.day("2026-11-02").starts
        var four = starts
        four[.asr] = nil
        #expect(PrayerDay(date: S.date("2026-11-02"), zoneID: "Asia/Tokyo", sourceID: "a", starts: four) == nil)
        #expect(PrayerDay(date: S.date("2026-11-02"), zoneID: "Mars/Olympus", sourceID: "a", starts: starts) == nil)
        #expect(PrayerDay(date: S.date("2026-11-02"), zoneID: "Asia/Tokyo", sourceID: "a", starts: starts, iqamah: [.fajr: starts[.fajr]!.addingTimeInterval(-60)]) == nil, "iqamah before its start")
        let encoder = JSONEncoder()
        let day = S.day("2026-11-02", iqamah: [.asr: "14:45"])
        #expect(try JSONDecoder().decode(PrayerDay.self, from: encoder.encode(day)) == day)
        #expect(TimetableSource.Kind.allCases == [.calculated, .manual], "there is no Connected or Verified to claim")
    }

    // MARK: - Independent reference checks

    /// The great-circle initial bearing to the Kaaba, worked out here: the provider's answer has to land near it.
    @Test func qiblaAgreesWithTheGreatCircleFormula() throws {
        func radians(_ degrees: Double) -> Double { degrees * .pi / 180 }
        let (fromLat, fromLon) = (radians(35.6762), radians(139.6503))
        let (kaabaLat, kaabaLon) = (radians(21.4225), radians(39.8262))
        let y = sin(kaabaLon - fromLon) * cos(kaabaLat)
        let x = cos(fromLat) * sin(kaabaLat) - sin(fromLat) * cos(kaabaLat) * cos(kaabaLon - fromLon)
        let bearing = (atan2(y, x) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
        let fixture = try AlAdhanDecoder.qibla(S.fixture("qibla-tokyo"), place: S.tokyo, fetched: Date())
        #expect(abs(bearing - fixture.degrees) < 0.5, "formula \(bearing), fixture \(fixture.degrees)")
    }

    /// Solar noon from longitude and the equation of time: Dhuhr comes just after it, whatever the method.
    @Test func dhuhrIsNearSolarNoon() throws {
        let day = try AlAdhanDecoder.timings(S.fixture("prayer-day"), date: S.date("2026-11-02"), query: S.query)
        let dayOfYear = Double(S.date("2026-01-01").days(until: day.date) + 1)
        let b = 360.0 / 365 * (dayOfYear - 81) * .pi / 180
        let equationOfTime = 9.87 * sin(2 * b) - 7.53 * cos(b) - 1.5 * sin(b)
        let noon = 12 * 60 - (139.6503 - 135) * 4 - equationOfTime
        let dhuhr = S.clock(day.starts[.dhuhr]!).suffix(5).split(separator: ":").map { Double($0)! }
        #expect(abs(dhuhr[0] * 60 + dhuhr[1] - noon) < 3, "solar noon at minute \(noon) of the day")
    }
}
