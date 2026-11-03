import Foundation
import Testing
@testable import ext_prayer_times

/// What Preferences compares: whether a draft differs from what is saved, and whether a file is one already kept.
struct NoorPreferencesTests {
    @Test func aPrayerWithNothingChosenIsNoChange() {
        let saved = Reminders()
        var draft = saved
        for id in PrayerID.allCases { draft.prayers[id] = Reminders.Prayer() }
        #expect(draft != saved)
        #expect(draft.withoutEmptyPrayers == saved.withoutEmptyPrayers)
        draft.prayers[.asr] = Reminders.Prayer(atStart: true)
        #expect(draft.withoutEmptyPrayers != saved.withoutEmptyPrayers)
    }

    private func table(_ id: String, name: String, fajr: String = "05:30") -> ManualTimetable? {
        let rows = """
        \(CSVImport.header)
        2026-11-03,fajr,\(fajr),05:50,Asia/Tokyo
        2026-11-03,dhuhr,11:50,,Asia/Tokyo
        2026-11-03,asr,14:20,,Asia/Tokyo
        2026-11-03,maghrib,16:50,16:55,Asia/Tokyo
        2026-11-03,isha,18:20,,Asia/Tokyo
        """
        return CSVImport.parse(data: Data(rows.utf8), name: name).timetable(id: id, attribution: name)
    }

    @Test func theSameFileHasTheSameTimesWhateverItIsCalled() throws {
        let kept = try #require(table("manual.a", name: "Masjid"))
        let again = try #require(table("manual.b", name: "Masjid 2"))
        let other = try #require(table("manual.c", name: "Masjid", fajr: "05:31"))
        #expect(kept.sameTimes(as: again))
        #expect(!kept.sameTimes(as: other))
    }
}
