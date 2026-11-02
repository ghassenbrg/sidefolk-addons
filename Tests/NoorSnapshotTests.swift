import Foundation
import Testing
@testable import ext_prayer_times

/// The one value Home, Today and Ask read, and the small derivations around it.
struct NoorSnapshotTests {
    typealias S = NoorSupport

    let now = S.instant("2026-11-02T12:00:00+09:00")

    private func prefs(source: TimetableSource? = S.tokyoSource, place: Place? = S.tokyo) -> Preferences {
        var prefs = Preferences()
        prefs.place = place
        prefs.sourceID = source?.id
        prefs.convention = S.mwl
        return prefs
    }

    private func snapshot(_ prefs: Preferences, sources: [TimetableSource] = [S.tokyoSource], days: [PrayerDay] = [], calendar: CalendarDay? = nil, qibla: QiblaBearing? = nil,
                          load: NoorSnapshot.LoadState = .settled, at instant: Date? = nil) -> NoorSnapshot {
        NoorSnapshot.make(now: instant ?? now, prefs: prefs, sources: sources, days: days, calendar: calendar, qibla: qibla, name: nil, load: load)
    }

    @Test func nothingChosenYet() throws {
        let first = snapshot(prefs(source: nil, place: nil), sources: [])
        #expect(first.validity == .noPlace && first.place == nil && first.zoneID == nil && first.localDate == nil)
        #expect(first.next == .unavailable(reason: .noToday), "loading or empty never invents a time")
        #expect(snapshot(prefs(source: nil)).validity == .noSource)
        #expect(snapshot(prefs(source: S.tokyoSource, place: nil)).validity == .noPlace)
    }

    @Test func readyAndOffline() throws {
        let days = [S.day("2026-11-02"), S.day("2026-11-03")]
        let ready = snapshot(prefs(), days: days)
        #expect(ready.validity == .ready && ready.today?.date == S.date("2026-11-02") && ready.tomorrow?.date == S.date("2026-11-03"))
        #expect(ready.next == .prayerStart(id: .asr, at: S.at("2026-11-02", "14:30"), day: S.date("2026-11-02")))
        #expect(ready.zoneID == "Asia/Tokyo" && ready.localDate == S.date("2026-11-02") && ready.sourceRevision == 1 && ready.calendarMethod == .uaq && ready.convention == S.mwl)
        #expect(snapshot(prefs(), days: days, load: .offline).validity == .offlineValid, "cached and still covering today")
        #expect(snapshot(prefs(), days: days, load: .loading).validity == .ready, "a refresh in the background hides nothing")
    }

    @Test func noDataYet() throws {
        #expect(snapshot(prefs(), load: .loading).validity == .loading)
        #expect(snapshot(prefs()).validity == .loading)
        #expect(snapshot(prefs(), load: .failed).validity == .error)
        #expect(snapshot(prefs(), load: .offline).validity == .error)
    }

    @Test func aDayFromAnotherDateCoversNothing() throws {
        let stale = snapshot(prefs(), days: [S.day("2026-11-01")])
        #expect(stale.today == nil && stale.validity == .loading && stale.next == .unavailable(reason: .noToday))
        let elsewhere = snapshot(prefs(), days: [S.day("2026-11-02", source: "manual.other")])
        #expect(elsewhere.today == nil, "another source's day")
    }

    @Test func itsDateIsThePlacesDate() throws {
        // 20:00 UTC on the 2nd is already the 3rd in Tokyo, and it doesn't matter what any device says.
        let instant = S.instant("2026-11-02T20:00:00Z")
        let snapshot = snapshot(prefs(), days: [S.day("2026-11-02"), S.day("2026-11-03")], at: instant)
        #expect(snapshot.localDate == S.date("2026-11-03") && snapshot.today?.date == S.date("2026-11-03") && snapshot.tomorrow == nil)
    }

    @Test func afterIshaWithoutTomorrowInTheSnapshot() throws {
        let late = snapshot(prefs(), days: [S.day("2026-11-02")], at: S.at("2026-11-02", "22:00"))
        #expect(late.validity == .ready && late.next == .unavailable(reason: .noTomorrow))
    }

    @Test func aManualSourceThatEndedIsExpired() throws {
        let manual = try #require(TimetableSource(id: "manual.m", kind: .manual, name: "M", zoneID: "Asia/Tokyo", coverage: S.date("2026-10-01")...S.date("2026-11-01"), attribution: ""))
        let days = [S.day("2026-11-01", source: "manual.m"), S.day("2026-11-02", source: "manual.m")]
        let snapshot = snapshot(prefs(source: manual), sources: [manual], days: days)
        #expect(snapshot.validity == .expired && snapshot.today == nil && snapshot.coverage == manual.coverage, "a stray day past coverage doesn't count")
        #expect(snapshot.next == .unavailable(reason: .noToday))
        let lastDay = self.snapshot(prefs(source: manual), sources: [manual], days: days, at: S.at("2026-11-01", "20:00"))
        #expect(lastDay.validity == .ready && lastDay.next == .unavailable(reason: .noTomorrow), "the day after coverage isn't borrowed")
    }

    @Test func aManualSourceThatHasNotBegunSaysSo() throws {
        let manual = try #require(TimetableSource(id: "manual.m", kind: .manual, name: "M", zoneID: "Asia/Tokyo", coverage: S.date("2026-12-01")...S.date("2026-12-31"), attribution: "M"))
        let snapshot = snapshot(prefs(source: manual), sources: [manual], days: [S.day("2026-12-01", source: "manual.m")])
        #expect(snapshot.validity == .notStarted && snapshot.today == nil, "a timetable that starts next month hasn't ended")
    }

    @Test func aManualSourceNeedsNoPlace() throws {
        let manual = try #require(TimetableSource(id: "manual.m", kind: .manual, name: "M", zoneID: "America/New_York", coverage: S.date("2026-11-01")...S.date("2026-11-30"), attribution: ""))
        let snapshot = snapshot(prefs(source: manual, place: nil), sources: [manual], days: [S.day("2026-11-01", zone: "America/New_York", source: "manual.m")], at: S.instant("2026-11-01T16:00:00Z"))
        #expect(snapshot.validity == .ready && snapshot.zoneID == "America/New_York" && snapshot.today != nil, "the source's zone, not a place's")
    }

    @Test func calendarAndQiblaMustMatchWhatIsChosen() throws {
        let paired = try AlAdhanDecoder.conversion(S.fixture("date-conversion"), gregorian: S.date("2026-11-02"), method: .uaq)
        #expect(snapshot(prefs(), calendar: paired).calendar == paired)
        #expect(snapshot(prefs(), calendar: paired, at: S.at("2026-11-03", "08:00")).calendar == nil, "yesterday's paired date")
        var diyanet = prefs()
        diyanet.calendarMethod = .diyanet
        #expect(snapshot(diyanet, calendar: paired).calendar == nil, "another method's")

        let fetched = Date(timeIntervalSince1970: 100)
        let bearing = try AlAdhanDecoder.qibla(S.fixture("qibla-tokyo"), place: S.tokyo, fetched: fetched)
        #expect(snapshot(prefs(), qibla: bearing).qibla == bearing)
        let kyoto = try Place(id: "kyoto", label: "Kyoto", latitude: 35.0116, longitude: 135.7681, zoneID: "Asia/Tokyo")
        #expect(snapshot(prefs(place: kyoto), qibla: bearing).qibla == nil, "a bearing from another place is no bearing")
    }

    @Test func reminderStatusAndFreshness() throws {
        var settings = prefs()
        #expect(snapshot(settings).reminderStatus == .off)
        settings.reminders.master = true
        #expect(snapshot(settings).reminderStatus == .on)
        settings.reminders.pausedUntil = now.addingTimeInterval(3600)
        #expect(snapshot(settings).reminderStatus == .paused(until: now.addingTimeInterval(3600)))
        settings.reminders.pausedUntil = now.addingTimeInterval(-1)
        #expect(snapshot(settings).reminderStatus == .on)
        let fetched = TimetableSource.calculated(for: S.tokyo, revision: 7, lastFetch: Date(timeIntervalSince1970: 9))
        let fresh = snapshot(prefs(), sources: [fetched])
        #expect(fresh.fetchedAt == Date(timeIntervalSince1970: 9) && fresh.sourceRevision == 7)
    }

    @Test func nameOfTheDayRotatesThroughAll99() throws {
        let start = S.date("2026-11-02")
        let numbers = (0..<99).map { NoorSnapshot.nameOfTheDay(start.adding(days: $0)) }
        #expect(Set(numbers) == Set(1...99))
        for (a, b) in zip(numbers, numbers.dropFirst()) { #expect(b == a % 99 + 1) }
        #expect(NoorSnapshot.nameOfTheDay(start.adding(days: 99)) == numbers[0])
        #expect(NoorSnapshot.nameOfTheDay(S.date("2000-01-01")) == 1)
        #expect((1...99).contains(NoorSnapshot.nameOfTheDay(S.date("1999-12-31"))), "dates before the count begins still land on a Name")
        // By the place's date: the same instant can be two different Names in two places.
        let instant = S.instant("2026-11-02T20:00:00Z")
        let tokyo = NoorSnapshot.nameOfTheDay(CivilDate(instant, in: S.tokyoZone))
        let newYork = NoorSnapshot.nameOfTheDay(CivilDate(instant, in: TimeZone(identifier: "America/New_York")!))
        #expect(tokyo == newYork % 99 + 1)
    }

    @Test func nextRamadanYearFollowsTheHijriDate() throws {
        func next(_ month: Int, _ day: Int = 1) -> Int { RamadanMonth.nextYear(from: HijriDate(year: 1448, month: month, day: day)!) }
        #expect(next(5, 22) == 1448 && next(8, 29) == 1448)
        #expect(next(9, 15) == 1448, "during Ramadan it is this one")
        #expect(next(10) == 1449 && next(12, 29) == 1449)
    }

    @Test func ramadanMonthRefusesAnythingButAWholeMonth9() throws {
        let days = try AlAdhanDecoder.hijriPrayerCalendar(S.fixture("ramadan-month"), year: 1448, month: 9, query: S.query)
        #expect(RamadanMonth(days: days)?.dayCount == 29)
        #expect(RamadanMonth(days: Array(days.dropLast())) == nil, "28 days")
        #expect(RamadanMonth(days: Array(days.dropFirst())) == nil, "no first day")
        #expect(RamadanMonth(days: []) == nil)
        var skipped = days
        skipped.remove(at: 5)
        #expect(RamadanMonth(days: skipped) == nil)
        let month = try AlAdhanDecoder.prayerCalendarDaysFromAnotherMonth()
        #expect(RamadanMonth(days: month) == nil)
    }
}

private extension AlAdhanDecoder {
    /// Ramadan's own days relabelled as month 8: right length, wrong month.
    static func prayerCalendarDaysFromAnotherMonth() throws -> [PrayerDay] {
        let days = try hijriPrayerCalendar(NoorSupport.fixture("ramadan-month"), year: 1448, month: 9, query: NoorSupport.query)
        return days.map { day in
            let hijri = day.hijri!
            return PrayerDay(date: day.date, zoneID: day.zoneID, sourceID: day.sourceID, starts: day.starts, solar: day.solar, method: day.method,
                             hijri: HijriDate(year: hijri.year, month: 8, day: hijri.day))!
        }
    }
}
