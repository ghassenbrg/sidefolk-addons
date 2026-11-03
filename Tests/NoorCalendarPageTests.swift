import Foundation
import Testing
@testable import ext_prayer_times

/// What Calendar's two sides lead to: the same day, seen from the other calendar.
@MainActor
struct NoorCalendarPageTests {
    /// A Hijri month running from mid October to early November: its middle is in October, and today isn't.
    private let month: CalendarMonth = {
        var days: [CalendarDay] = []
        for day in 1...30 {
            let gregorian = day <= 19 ? "2026-10-\(String(format: "%02d", day + 12))" : "2026-11-\(String(format: "%02d", day - 19))"
            days.append(CalendarDay(gregorian: CivilDate(iso: gregorian)!, hijri: HijriDate(year: 1448, month: 5, day: day)!, method: .uaq, occasions: []))
        }
        return CalendarMonth(axis: .hijri(year: 1448, month: 5), method: .uaq, days: days)
    }()

    private var here: (axis: String, year: Int, month: Int, data: CalendarMonth?) { ("h", 1448, 5, month) }

    @Test func gregorianOpensTheMonthHoldingTheChosenDay() {
        #expect(CalendarPage.axisSwitch(here, to: "g", data: month, selected: CivilDate(iso: "2026-11-03")!) == "g:2026:11")
        #expect(CalendarPage.axisSwitch(here, to: "g", data: month, selected: CivilDate(iso: "2026-10-20")!) == "g:2026:10")
    }

    @Test func aChosenDayElsewhereFallsBackOnTheMonthsMiddle() {
        #expect(CalendarPage.axisSwitch(here, to: "g", data: month, selected: CivilDate(iso: "2027-01-01")!) == "g:2026:10")
    }

    @Test func theSameSideStaysWhereItIs() {
        #expect(CalendarPage.axisSwitch(here, to: "h", data: month, selected: CivilDate(iso: "2026-11-03")!) == "h:1448:5")
    }
}
