import Foundation
import Testing
@testable import ext_prayer_times

/// Which reminders should exist. The planner only computes, so everything is checked on its return value.
struct NoorPlannerTests {
    typealias S = NoorSupport

    let now = S.instant("2026-11-02T12:00:00+09:00")
    let source = "calculated.tokyo"

    private func prefs(_ change: (inout Reminders) -> Void = { _ in }) -> Preferences {
        var prefs = Preferences()
        prefs.place = S.tokyo
        prefs.sourceID = source
        prefs.reminders.master = true
        prefs.reminders.route.companion = true
        change(&prefs.reminders)
        return prefs
    }

    private func plan(_ prefs: Preferences, days: [PrayerDay], ramadan: RamadanMonth? = nil, occasions: [Occasion] = [], names: [NameEntry] = []) -> [PlannedOccurrence] {
        Planner.plan(now: now, prefs: prefs, days: days, ramadan: ramadan, occasions: occasions, names: names)
    }

    private func days(from iso: String = "2026-11-02", count: Int) -> [PrayerDay] {
        (0..<count).map { S.day(S.date(iso).adding(days: $0).iso) }
    }

    @Test func everythingOffGivesNothing() throws {
        let everything = Preferences()
        #expect(!everything.reminders.master && everything.reminders.prayers.isEmpty && !everything.reminders.route.companion && !everything.reminders.route.systemFallback)
        #expect(everything.reminders.pausedUntil == nil && !everything.reminders.ramadan.enabled && everything.reminders.ramadan.days.isEmpty)
        #expect(everything.reminders.ramadan.suhoorMinutesBeforeFajr == nil && !everything.reminders.ramadan.iftar)
        #expect(everything.reminders.occasions.selected.isEmpty && !everything.reminders.nameOfDay.enabled)
        #expect(everything.place == nil && everything.sourceID == nil && everything.convention == nil)
        let names = [NameEntry(number: 1, arabic: "a", transliteration: "b", meaning: "c")]
        #expect(plan(everything, days: days(count: 3), names: names).isEmpty)
        #expect(plan(prefs(), days: days(count: 3), names: names).isEmpty, "the master alone chooses nothing")

        var masterOff = prefs { $0.prayers[.fajr] = .init(atStart: true) }
        masterOff.reminders.master = false
        #expect(plan(masterOff, days: days(count: 3)).isEmpty)

        var noRoute = prefs { $0.prayers[.fajr] = .init(atStart: true) }
        noRoute.reminders.route = .init()
        #expect(plan(noRoute, days: days(count: 3)).isEmpty, "nowhere to deliver")
    }

    @Test func prayerRemindersHaveStableReadableIds() throws {
        let settings = prefs { $0.prayers[.fajr] = .init(beforeMinutes: 10, atStart: true); $0.route.systemFallback = true }
        let plan = plan(settings, days: [S.day("2026-11-03")])
        #expect(plan.map(\.id) == ["prayer.fajr.before10.2026-11-03.\(source)", "prayer.fajr.start.2026-11-03.\(source)"])
        let before = plan[0]
        #expect(before.at == S.at("2026-11-03", "04:50") && before.expiresAt == S.at("2026-11-03", "05:00"))
        #expect(before.kind == .prayerBefore && before.prayer == .fajr && before.minutesBefore == 10)
        #expect(before.sourceID == source && before.date == S.date("2026-11-03") && before.systemFallback && before.group == "prayer.fajr")
        #expect(before.intents == [ReminderIntent(kind: .prayerBefore, prayer: .fajr, minutesBefore: 10)])
        #expect(plan[1].kind == .prayerStart && plan[1].minutesBefore == nil && plan[1].at == S.at("2026-11-03", "05:00"))
    }

    @Test func aRefetchKeepsIdsAndMovesInstants() throws {
        let settings = prefs { $0.prayers[.asr] = .init(atStart: true) }
        let first = plan(settings, days: [S.day("2026-11-03")])
        let refetched = plan(settings, days: [S.day("2026-11-03", shift: 60)])
        #expect(first.map(\.id) == refetched.map(\.id))
        #expect(refetched[0].at == first[0].at.addingTimeInterval(60))
    }

    @Test func pastMomentsAreDroppedOneByOne() throws {
        let settings = prefs { $0.prayers[.dhuhr] = .init(beforeMinutes: 60, atStart: true); $0.prayers[.asr] = .init(atStart: true) }
        // At noon: Dhuhr's are gone (11:30, 10:30), Asr's is not.
        #expect(plan(settings, days: [S.day("2026-11-02")]).map(\.id) == ["prayer.asr.start.2026-11-02.\(source)"])
        // Exactly on the instant counts as gone: it is being delivered or missed, not planned.
        let onIt = Planner.plan(now: S.at("2026-11-02", "14:30"), prefs: settings, days: [S.day("2026-11-02")], ramadan: nil, occasions: [], names: [])
        #expect(onIt.isEmpty)
    }

    @Test func pauseDropsWhatComesBeforeIt() throws {
        var settings = prefs { $0.prayers[.fajr] = .init(atStart: true); $0.prayers[.isha] = .init(atStart: true) }
        let days = days(count: 3)
        #expect(plan(settings, days: days).count == 5)
        settings.reminders.pausedUntil = S.at("2026-11-03", "06:00")
        let paused = plan(settings, days: days)
        #expect(paused.map(\.id) == ["prayer.isha.start.2026-11-03.\(source)", "prayer.fajr.start.2026-11-04.\(source)", "prayer.isha.start.2026-11-04.\(source)"])
        settings.reminders.pausedUntil = S.at("2026-11-03", "18:30")
        #expect(plan(settings, days: days).first?.id == "prayer.isha.start.2026-11-03.\(source)", "the instant itself is after the pause")
        settings.reminders.pausedUntil = now.addingTimeInterval(-3600)
        #expect(plan(settings, days: days).count == 5, "a pause already over changes nothing")
    }

    @Test func anExpiredSourceGivesNothing() throws {
        let settings = prefs { $0.prayers[.fajr] = .init(atStart: true); $0.prayers[.isha] = .init(atStart: true, iqamahMinutes: 5) }
        let table = try #require(ImportReview(name: "Old", rows: PrayerID.allCases.flatMap { prayer in
            ["2026-10-30", "2026-10-31"].map { TimetableRow(line: 0, date: S.date($0), slot: .prayer(prayer), start: LocalTime(hour: 5 + 3 * PrayerID.allCases.firstIndex(of: prayer)!, minute: 0)!, iqamah: nil, zoneID: "Asia/Tokyo") }
        }).timetable(id: source, attribution: ""))
        #expect(plan(settings, days: table.days).isEmpty)
    }

    @Test func neverYesterdaysTimes() throws {
        let settings = prefs { $0.prayers[.isha] = .init(atStart: true); $0.prayers[.fajr] = .init(atStart: true) }
        #expect(plan(settings, days: [S.day("2026-11-01")]).isEmpty)
        // A hole in the data stays a hole: the 3rd gets nothing from the 2nd or the 4th.
        let hole = plan(settings, days: [S.day("2026-11-02"), S.day("2026-11-04")])
        #expect(!hole.contains { $0.date == S.date("2026-11-03") })
        #expect(hole.allSatisfy { occurrence in
            let day = occurrence.date == S.date("2026-11-02") ? S.day("2026-11-02") : S.day("2026-11-04")
            return occurrence.at == day.starts[occurrence.prayer!]
        })
        #expect(hole.map(\.date) == [S.date("2026-11-02"), S.date("2026-11-04"), S.date("2026-11-04")])
    }

    @Test func anotherSourcesDaysAreIgnored() throws {
        let settings = prefs { $0.prayers[.isha] = .init(atStart: true) }
        #expect(plan(settings, days: [S.day("2026-11-03", source: "manual.other")]).isEmpty)
        var noSource = settings
        noSource.sourceID = nil
        #expect(plan(noSource, days: [S.day("2026-11-03")]).isEmpty)
    }

    @Test func iqamahOnlyFromRealData() throws {
        let settings = prefs { $0.prayers[.asr] = .init(iqamahMinutes: 5); $0.prayers[.isha] = .init(iqamahMinutes: 0) }
        #expect(plan(settings, days: [S.day("2026-11-03")]).isEmpty, "a calculated day has no iqamah to count back from")
        let withIqamah = plan(settings, days: [S.day("2026-11-03", iqamah: [.asr: "14:45"])])
        #expect(withIqamah.map(\.id) == ["prayer.asr.iqamah5.2026-11-03.\(source)"])
        #expect(withIqamah[0].at == S.at("2026-11-03", "14:40") && withIqamah[0].expiresAt == S.at("2026-11-03", "14:45") && withIqamah[0].kind == .iqamah)
        let atIt = plan(settings, days: [S.day("2026-11-03", iqamah: [.isha: "18:45"])])
        #expect(atIt[0].expiresAt == S.at("2026-11-03", "18:45").addingTimeInterval(Planner.atEventGrace))
    }

    @Test func outOfBoundsChoicesDoNothing() throws {
        let settings = prefs { $0.prayers[.asr] = .init(beforeMinutes: 0, iqamahMinutes: 500); $0.prayers[.isha] = .init(beforeMinutes: -5) }
        #expect(plan(settings, days: [S.day("2026-11-03", iqamah: [.asr: "14:45"])]).isEmpty)
    }

    @Test func theHorizonAndTheCapHold() throws {
        let one = prefs { $0.prayers[.fajr] = .init(atStart: true) }
        let long = plan(one, days: days(from: "2026-11-03", count: 60))
        // The 2nd's Fajr is past; 3 November through 6 December are the 34 days left of the 35 from today.
        #expect(long.count == 34 && long.last?.date == S.date("2026-12-06"))

        let all = prefs { reminders in
            for prayer in PrayerID.allCases { reminders.prayers[prayer] = .init(beforeMinutes: 15, atStart: true) }
        }
        let capped = plan(all, days: days(from: "2026-11-03", count: 60))
        #expect(capped.count == Planner.maximumOccurrences)
        #expect(capped.map(\.at) == capped.map(\.at).sorted(), "the soonest are the ones kept")
    }

    @Test func civilHorizonIsNotSeconds() throws {
        // In New York across the fall-back: 35 civil days from 30 October end at midnight on 4 December, one hour later
        // than 35 times 24 hours would.
        let zone = TimeZone(identifier: "America/New_York")!
        let place = try Place(id: "ny", label: "New York", latitude: 40.7, longitude: -74, zoneID: "America/New_York")
        var settings = Preferences()
        settings.place = place
        settings.sourceID = "calculated.ny"
        settings.reminders.master = true
        settings.reminders.route.companion = true
        settings.reminders.nameOfDay = .init(enabled: true, hour: 0, minute: 30)
        let names = (1...99).map { NameEntry(number: $0, arabic: "a", transliteration: "b", meaning: "c") }
        let start = S.at("2026-10-30", "00:00", zone)
        let plan = Planner.plan(now: start, prefs: settings, days: [], ramadan: nil, occasions: [], names: names)
        #expect(plan.count == 35 && plan.first?.date == S.date("2026-10-30") && plan.last?.date == S.date("2026-12-03"))
        #expect(plan.last?.at == S.at("2026-12-03", "00:30", zone))
    }

    // MARK: - Ramadan

    private func ramadan() throws -> RamadanMonth {
        try #require(RamadanMonth(days: AlAdhanDecoder.hijriPrayerCalendar(S.fixture("ramadan-month"), year: 1448, month: 9, query: S.query)))
    }

    private var ramadanNow: Date { S.instant("2027-02-07T12:00:00+09:00") }

    private func ramadanPlan(_ settings: Preferences, days: [PrayerDay] = []) throws -> [PlannedOccurrence] {
        Planner.plan(now: ramadanNow, prefs: settings, days: days, ramadan: try ramadan(), occasions: [], names: [])
    }

    private func ramadanDays() throws -> [PrayerDay] {
        try AlAdhanDecoder.hijriPrayerCalendar(S.fixture("ramadan-month"), year: 1448, month: 9, query: S.query)
    }

    @Test func ramadanIsChosenDayByDay() throws {
        #expect(try ramadanPlan(prefs()).isEmpty)
        #expect(try ramadanPlan(prefs { $0.ramadan = .init(enabled: false, days: [1], suhoorMinutesBeforeFajr: 30, iftar: true) }).isEmpty, "not enabled")
        #expect(try ramadanPlan(prefs { $0.ramadan = .init(enabled: true, days: [], suhoorMinutesBeforeFajr: 30, iftar: true) }).isEmpty, "no days chosen")
        let plan = try ramadanPlan(prefs { $0.ramadan = .init(enabled: true, days: [1, 2], suhoorMinutesBeforeFajr: 30, iftar: true) })
        #expect(plan.map(\.id) == ["ramadan.suhoor30.2027-02-08.\(source)", "ramadan.iftar.2027-02-08.\(source)", "ramadan.suhoor30.2027-02-09.\(source)", "ramadan.iftar.2027-02-09.\(source)"])
        #expect(S.clock(plan[0].at) == "2027-02-08 04:40" && S.clock(plan[0].expiresAt) == "2027-02-08 05:10", "a Suhoor notice stops mattering at Fajr")
        #expect(S.clock(plan[1].at) == "2027-02-08 17:15" && plan[1].group == "ramadan" && plan[1].prayer == .maghrib)
        var other = prefs { $0.ramadan = .init(enabled: true, days: [1], iftar: true) }
        other.sourceID = "manual.mosque"
        #expect(try ramadanPlan(other).isEmpty, "a calculated month doesn't mix into a manual source")
    }

    @Test func ramadanMergesWithAPrayerReminderAtTheSameInstant() throws {
        let settings = prefs {
            $0.prayers[.maghrib] = .init(atStart: true)
            $0.prayers[.fajr] = .init(beforeMinutes: 10)
            $0.ramadan = .init(enabled: true, days: [1], suhoorMinutesBeforeFajr: 10, iftar: true)
        }
        let plan = try ramadanPlan(settings, days: [try ramadanDays()[0]])
        #expect(plan.count == 2)
        let iftar = plan[1]
        #expect(iftar.id == "prayer.maghrib.start.2027-02-08.\(source)", "the prayer's identity stays")
        #expect(iftar.intents.map(\.kind) == [.prayerStart, .iftar], "and both intents")
        #expect(iftar.kind == .prayerStart && iftar.at == S.instant("2027-02-08T17:15:00+09:00"))
        let suhoor = plan[0]
        #expect(suhoor.id == "prayer.fajr.before10.2027-02-08.\(source)" && suhoor.intents.map(\.kind) == [.prayerBefore, .suhoor])
        #expect(suhoor.intents[1].minutesBefore == 10)
    }

    @Test func ramadanAtFajrItselfMergesAndKeepsTheShorterExpiry() throws {
        let settings = prefs {
            $0.prayers[.fajr] = .init(atStart: true)
            $0.ramadan = .init(enabled: true, days: [1], suhoorMinutesBeforeFajr: 0)
        }
        let plan = try ramadanPlan(settings, days: [try ramadanDays()[0]])
        #expect(plan.count == 1 && plan[0].intents.map(\.kind) == [.prayerStart, .suhoor])
        #expect(plan[0].expiresAt == S.instant("2027-02-08T05:10:00+09:00").addingTimeInterval(Planner.atEventGrace))
    }

    @Test func differentInstantsDoNotMerge() throws {
        let settings = prefs {
            $0.prayers[.fajr] = .init(beforeMinutes: 10)
            $0.ramadan = .init(enabled: true, days: [1], suhoorMinutesBeforeFajr: 30)
        }
        let plan = try ramadanPlan(settings, days: [try ramadanDays()[0]])
        #expect(plan.map(\.kind) == [.suhoor, .prayerBefore] && plan.allSatisfy { $0.intents.count == 1 })
    }

    // MARK: - Occasions and Names

    @Test func onlySelectedOccasionsOfTheChosenMethod() throws {
        let hijri = try #require(HijriDate(year: 1448, month: 5, day: 25))
        func occasion(_ title: String, _ date: String = "2026-11-20", method: CalendarMethod = .uaq) -> Occasion {
            Occasion(title: title, method: method, hijri: hijri, gregorian: S.date(date))
        }
        let listed = [occasion("Birth of A"), occasion("birth of a"), occasion("Urs of B"), occasion("Other"), occasion("Birth of A", method: .diyanet), occasion("Birth of A", "2027-03-30")]
        #expect(plan(prefs(), days: [], occasions: listed).isEmpty)
        let settings = prefs { $0.occasions = .init(selected: ["birth-of-a", "urs-of-b"], daysBefore: 2) }
        let plan = plan(settings, days: [], occasions: listed)
        #expect(plan.map(\.id) == ["occasion.birth-of-a.before2.2026-11-20.UAQ", "occasion.urs-of-b.before2.2026-11-20.UAQ"], "duplicates gone, both events kept, out of horizon dropped")
        #expect(plan[0].at == S.at("2026-11-18", "09:00") && plan[0].date == S.date("2026-11-20") && plan[0].kind == .occasion)
        #expect(plan[0].expiresAt == S.at("2026-11-21", "00:00") && plan[0].intents[0].occasion == "birth-of-a" && plan[0].intents[0].daysBefore == 2)
    }

    @Test func nameOfTheDayNeedsItsSwitchAndTheNames() throws {
        let names = (1...99).map { NameEntry(number: $0, arabic: "a", transliteration: "b", meaning: "c") }
        #expect(plan(prefs(), days: [], names: names).isEmpty)
        let settings = prefs { $0.nameOfDay = .init(enabled: true, hour: 8, minute: 15) }
        #expect(plan(settings, days: []).isEmpty, "no names, no reminder about one")
        let plan = plan(settings, days: [], names: names)
        // Noon on the 2nd: that day's 08:15 has gone, and the 35-day horizon leaves 34.
        #expect(plan.count == 34 && plan[0].id == "name.2026-11-03" && plan[0].at == S.at("2026-11-03", "08:15"))
        #expect(plan[0].intents[0].nameNumber == NoorSnapshot.nameOfTheDay(S.date("2026-11-03")) && plan[0].kind == .nameOfDay)
    }

    @Test func aDailyReminderInADSTGapComesWhenTheClockJumps() throws {
        let zone = TimeZone(identifier: "America/New_York")!
        var settings = Preferences()
        settings.place = try Place(id: "ny", label: "New York", latitude: 40.7, longitude: -74, zoneID: "America/New_York")
        settings.reminders.master = true
        settings.reminders.route.companion = true
        settings.reminders.nameOfDay = .init(enabled: true, hour: 2, minute: 30)
        let names = (1...99).map { NameEntry(number: $0, arabic: "a", transliteration: "b", meaning: "c") }
        let plan = Planner.plan(now: S.at("2026-03-07", "12:00", zone), prefs: settings, days: [], ramadan: nil, occasions: [], names: names)
        #expect(plan[0].date == S.date("2026-03-08") && plan[0].at == S.instant("2026-03-08T07:30:00Z"), "03:30 EDT")
        #expect(plan[1].at == S.instant("2026-03-09T06:30:00Z"), "02:30 EDT the next day")
    }

    @Test func planningIsPureSoPreviewsAreSafe() throws {
        let settings = prefs { $0.prayers[.isha] = .init(atStart: true) }
        let days = days(count: 2)
        #expect(plan(settings, days: days) == plan(settings, days: days))
    }
}
