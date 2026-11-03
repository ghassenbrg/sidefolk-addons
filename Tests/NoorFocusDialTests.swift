import CoreGraphics
import Foundation
import Testing
@testable import ext_prayer_times

/// What the Overview focuses on, and where the dial puts it.
struct NoorFocusDialTests {
    typealias S = NoorSupport

    let today = S.day("2026-11-02")
    let tomorrow = S.day("2026-11-03", times: ["05:01", "11:31", "14:31", "17:01", "18:31"])

    private func at(_ time: String, _ date: String = "2026-11-02") -> Date { S.at(date, time) }

    @Test func withoutIqamahItMovesStraightToTheNextStart() throws {
        #expect(NextEvent.compute(now: at("04:00"), today: today, tomorrow: tomorrow) == .prayerStart(id: .fajr, at: at("05:00"), day: today.date))
        #expect(NextEvent.compute(now: at("05:00"), today: today, tomorrow: tomorrow) == .prayerStart(id: .dhuhr, at: at("11:30"), day: today.date), "the start has come")
        #expect(NextEvent.compute(now: at("12:00"), today: today, tomorrow: tomorrow) == .prayerStart(id: .asr, at: at("14:30"), day: today.date))
    }

    @Test func focusGoesThroughTheStartThenTheIqamah() throws {
        let day = S.day("2026-11-02", iqamah: [.dhuhr: "11:45"])
        #expect(NextEvent.compute(now: at("11:00"), today: day, tomorrow: nil) == .prayerStart(id: .dhuhr, at: at("11:30"), day: day.date))
        #expect(NextEvent.compute(now: at("11:30"), today: day, tomorrow: nil) == .iqamah(id: .dhuhr, at: at("11:45"), startedAt: at("11:30")))
        #expect(NextEvent.compute(now: at("11:44"), today: day, tomorrow: nil) == .iqamah(id: .dhuhr, at: at("11:45"), startedAt: at("11:30")))
        #expect(NextEvent.compute(now: at("11:45"), today: day, tomorrow: nil) == .prayerStart(id: .asr, at: at("14:30"), day: day.date), "once it begins")
    }

    @Test func iqamahAfterTheNextStartDoesNotHoldTheFocus() throws {
        let odd = S.day("2026-11-02", iqamah: [.fajr: "12:00"])
        #expect(NextEvent.compute(now: at("11:00"), today: odd, tomorrow: nil) == .prayerStart(id: .dhuhr, at: at("11:30"), day: odd.date))
    }

    @Test func afterIshaComesTomorrowsFajr() throws {
        #expect(NextEvent.compute(now: at("20:00"), today: today, tomorrow: tomorrow) == .prayerStart(id: .fajr, at: S.at("2026-11-03", "05:01"), day: tomorrow.date))
        let withIqamah = S.day("2026-11-02", iqamah: [.isha: "18:45"])
        #expect(NextEvent.compute(now: at("18:40"), today: withIqamah, tomorrow: tomorrow) == .iqamah(id: .isha, at: at("18:45"), startedAt: at("18:30")))
    }

    @Test func afterIshaWithoutTomorrowSaysUnavailable() throws {
        #expect(NextEvent.compute(now: at("20:00"), today: today, tomorrow: nil) == .unavailable(reason: .noTomorrow))
        #expect(NextEvent.compute(now: at("20:00"), today: today, tomorrow: S.day("2026-11-04")) == .unavailable(reason: .noTomorrow), "not the next date")
        #expect(NextEvent.compute(now: at("20:00"), today: today, tomorrow: today) == .unavailable(reason: .noTomorrow), "today again is no tomorrow")
        #expect(NextEvent.compute(now: at("20:00"), today: today, tomorrow: S.day("2026-11-03", source: "manual.other")) == .unavailable(reason: .noTomorrow), "another source's Fajr")
    }

    @Test func midnightRollover() throws {
        #expect(NextEvent.compute(now: at("23:59"), today: today, tomorrow: tomorrow) == .prayerStart(id: .fajr, at: S.at("2026-11-03", "05:01"), day: tomorrow.date))
        let midnight = S.at("2026-11-03", "00:00")
        #expect(NextEvent.compute(now: midnight, today: today, tomorrow: tomorrow) == .unavailable(reason: .staleToday), "yesterday's values aren't today's")
        #expect(NextEvent.compute(now: midnight, today: tomorrow, tomorrow: nil) == .prayerStart(id: .fajr, at: S.at("2026-11-03", "05:01"), day: tomorrow.date))
        #expect(NextEvent.compute(now: at("08:00"), today: nil, tomorrow: tomorrow) == .unavailable(reason: .noToday))
    }

    @Test func todayIsThePlacesToday() throws {
        // 01:00 in Tokyo is still the previous afternoon in New York: only the day's own zone decides.
        let instant = S.instant("2026-11-03T01:00:00+09:00")
        #expect(NextEvent.compute(now: instant, today: S.day("2026-11-03"), tomorrow: nil) == .prayerStart(id: .fajr, at: S.at("2026-11-03", "05:00"), day: S.date("2026-11-03")))
        #expect(NextEvent.compute(now: instant, today: S.day("2026-11-02", zone: "America/New_York"), tomorrow: nil) != .unavailable(reason: .staleToday))
    }

    @Test func aFixtureDayFromTheProvider() throws {
        let day = try AlAdhanDecoder.timings(S.fixture("prayer-day"), date: S.date("2026-11-02"), query: S.query)
        #expect(NextEvent.compute(now: S.instant("2026-11-02T16:50:00+09:00"), today: day, tomorrow: nil) == .prayerStart(id: .isha, at: S.instant("2026-11-02T18:07:00+09:00"), day: day.date))
        // Sunrise is no prayer: right after it the next thing is still Dhuhr.
        #expect(NextEvent.compute(now: S.instant("2026-11-02T06:10:00+09:00"), today: day, tomorrow: nil) == .prayerStart(id: .dhuhr, at: S.instant("2026-11-02T11:25:00+09:00"), day: day.date))
    }

    @Test func whenIsDoesNotFollowTheFocus() throws {
        let day = S.day("2026-11-02", iqamah: [.maghrib: "17:10"])
        let when = day.whenIs(.maghrib)
        #expect(when.start == at("17:00") && when.iqamah == at("17:10") && when.date == day.date && when.zoneID == "Asia/Tokyo" && when.sourceID == "calculated.tokyo")
        #expect(day.whenIs(.fajr).iqamah == nil)
        guard case .iqamah = NextEvent.compute(now: at("17:05"), today: day, tomorrow: nil) else { Issue.record("Expected the iqamah in focus"); return }
        #expect(day.whenIs(.maghrib).start == at("17:00"), "still the start, whatever the focus")
    }

    @Test func aFarNorthIshaAfterMidnightStaysInOrder() throws {
        // Isha is listed under the date it belongs to but lands after midnight.
        var starts = S.day("2026-06-20", times: ["02:00", "13:00", "18:00", "22:30", "23:30"]).starts
        starts[.isha] = S.at("2026-06-21", "00:40")
        let day = try #require(PrayerDay(date: S.date("2026-06-20"), zoneID: "Asia/Tokyo", sourceID: "a", starts: starts))
        #expect(day.ordered.map(\.id) == PrayerID.allCases)
        #expect(NextEvent.compute(now: S.at("2026-06-20", "23:00"), today: day, tomorrow: nil) == .prayerStart(id: .isha, at: S.at("2026-06-21", "00:40"), day: day.date))
        let face = DialGeometry.nodes(day: day, now: S.at("2026-06-20", "23:00"))
        let progress = face.nodes.map(\.progress)
        #expect(progress == progress.sorted() && progress.last! > 360, "it doesn't wrap back before Fajr")
        #expect(face.nodes.allSatisfy { (0..<360).contains($0.angle) })
    }

    // MARK: - Dial

    @Test func noonIsAtTheTopAndClockwiseIsLater() throws {
        let anyDay = today
        func hand(_ time: String) -> Double? { DialGeometry.nodes(day: anyDay, now: at(time)).nowAngle }
        #expect(hand("12:00") == 0)
        #expect(hand("18:00") == 90)
        #expect(hand("00:00") == 180)
        #expect(hand("06:00") == 270)
        #expect(hand("13:00") == 15)
        #expect(DialGeometry.nodes(day: anyDay, now: S.at("2026-11-03", "00:00")).nowAngle == nil, "tomorrow's midnight isn't in today")
        #expect(DialGeometry.nodes(day: anyDay, now: S.at("2026-11-01", "23:59")).nowAngle == nil)
    }

    @Test func aFixtureDayKeepsItsOrderAndRealPositions() throws {
        let day = try AlAdhanDecoder.timings(S.fixture("prayer-day"), date: S.date("2026-11-02"), query: S.query)
        let face = DialGeometry.nodes(day: day, now: S.instant("2026-11-02T12:00:00+09:00"))
        #expect(face.nodes.map(\.event) == [.prayer(.fajr), .solar(.sunrise), .prayer(.dhuhr), .prayer(.asr), .prayer(.maghrib), .prayer(.isha)])
        let progress = face.nodes.map(\.progress)
        #expect(progress == progress.sorted() && Set(progress).count == progress.count)
        // Fajr at 04:37 is 277 minutes past midnight, 69.25 degrees of progress: 249.25 clockwise from the top.
        #expect(abs(face.nodes[0].angle - 249.25) < 0.001)
        // Maghrib at 16:46 is 4h46 past noon: 71.5 degrees.
        #expect(abs(face.nodes[4].angle - 71.5) < 0.001)
        #expect(face.nodes.map(\.state) == [.past, .past, .current, .upcoming, .upcoming, .upcoming])
    }

    @Test func stateDependsOnNow() throws {
        func states(_ time: String, _ date: String = "2026-11-02") -> [DialState] { DialGeometry.nodes(day: today, now: S.at(date, time), solar: []).nodes.map(\.state) }
        #expect(states("04:00") == Array(repeating: .upcoming, count: 5), "nothing has started")
        #expect(states("05:00") == [.current, .upcoming, .upcoming, .upcoming, .upcoming])
        #expect(states("23:00") == [.past, .past, .past, .past, .current])
        #expect(states("12:00", "2026-11-03") == Array(repeating: .past, count: 5), "another day has no current")
        #expect(states("12:00", "2026-11-01") == Array(repeating: .upcoming, count: 5))
    }

    @Test func iqamahArcsComeOnlyFromIqamah() throws {
        let day = S.day("2026-11-02", iqamah: [.dhuhr: "11:45", .asr: "14:30"])
        let nodes = DialGeometry.nodes(day: day, now: at("10:00"), solar: []).nodes
        let dhuhr = try #require(nodes[1].iqamahArc)
        #expect(abs(dhuhr.startAngle - 352.5) < 0.001 && abs(dhuhr.endAngle - 356.25) < 0.001 && abs(dhuhr.sweep - 3.75) < 0.001)
        #expect(nodes[2].iqamahArc == nil, "an iqamah at the start is no stretch")
        #expect(nodes[0].iqamahArc == nil)
    }

    @Test func dstDaysStayInOrderAndTheHandStaysOnTheDay() throws {
        let zone = TimeZone(identifier: "America/New_York")!
        for (iso, length) in [("2026-03-08", 23.0), ("2026-11-01", 25.0)] {
            let day = S.day(iso, zone: "America/New_York", source: "a", times: ["01:15", "03:15", "12:00", "17:00", "23:45"])
            let face = DialGeometry.nodes(day: day, now: S.at(iso, "12:00", zone))
            let progress = face.nodes.map(\.progress)
            #expect(progress == progress.sorted() && Set(progress).count == progress.count)
            #expect(face.nodes.first!.progress > 0 && face.nodes.last!.progress < 360)
            // By real elapsed time: noon isn't exactly at the top on these days.
            let elapsed = S.at(iso, "12:00", zone).timeIntervalSince(CivilClock.startOfDay(S.date(iso), in: zone)) / 3600
            #expect(abs(face.nowAngle! - (360 * elapsed / length + 180).truncatingRemainder(dividingBy: 360)) < 0.001)
        }
        // An hour of a fall-back day happens twice, and the second one is further round.
        let foldDay = S.day("2026-11-01", zone: "America/New_York", source: "a", times: ["05:00", "12:00", "15:00", "17:00", "19:00"])
        let first = DialGeometry.nodes(day: foldDay, now: S.instant("2026-11-01T05:30:00Z")).nowAngle!
        let second = DialGeometry.nodes(day: foldDay, now: S.instant("2026-11-01T06:30:00Z")).nowAngle!
        #expect(second > first)
    }

    @Test func solarMarkersAreOptionalAndAbsentIsAbsent() throws {
        let day = try AlAdhanDecoder.timings(S.edited("prayer-day", ["data", "timings", "Sunrise"], nil), date: S.date("2026-11-02"), query: S.query)
        #expect(!DialGeometry.nodes(day: day, now: Date(timeIntervalSince1970: 0)).nodes.contains { $0.event == .solar(.sunrise) })
        let whole = try AlAdhanDecoder.timings(S.fixture("prayer-day"), date: S.date("2026-11-02"), query: S.query)
        let tied = DialGeometry.nodes(day: whole, now: Date(timeIntervalSince1970: 0), solar: [.sunset]).nodes.map(\.event)
        #expect(tied == [.prayer(.fajr), .prayer(.dhuhr), .prayer(.asr), .prayer(.maghrib), .solar(.sunset), .prayer(.isha)], "the prayer first where they tie")
    }

    @Test func qiblaArrowIsGeographic() throws {
        let center = CGPoint(x: 100, y: 100)
        func end(_ bearing: Double) -> CGPoint { QiblaGeometry.arrowEnd(bearing: bearing, center: center, length: 50) }
        #expect(abs(end(0).x - 100) < 1e-9 && abs(end(0).y - 50) < 1e-9, "north is up")
        #expect(abs(end(90).x - 150) < 1e-9 && abs(end(90).y - 100) < 1e-9, "east is right, whatever the interface direction")
        #expect(abs(end(180).y - 150) < 1e-9 && abs(end(270).x - 50) < 1e-9)
        let tokyo = end(292.9987)
        #expect(tokyo.x < 100 && tokyo.y < 100, "west-north-west")
        #expect(abs(hypot(tokyo.x - 100, tokyo.y - 100) - 50) < 1e-9)
    }
}
