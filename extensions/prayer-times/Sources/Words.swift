import Foundation
import SidefolkExtensionKit

/// Noor's words for what the domain only names, and how it writes times and dates. A time is always the event's own, in its source's zone, whatever the Mac's says.
enum Words {
    static func prayer(_ id: PrayerID) -> String {
        switch id {
        case .fajr: L("Fajr")
        case .dhuhr: L("Dhuhr")
        case .asr: L("Asr")
        case .maghrib: L("Maghrib")
        case .isha: L("Isha")
        }
    }

    static func solar(_ event: SolarEvent) -> String {
        switch event {
        case .imsak: L("Imsak")
        case .sunrise: L("Sunrise")
        case .sunset: L("Sunset")
        case .midnight: L("Midnight")
        case .firstThird: L("First third")
        case .lastThird: L("Last third")
        }
    }

    static func tab(_ tab: NoorTab) -> String {
        switch tab {
        case .overview: L("Overview")
        case .prayer: L("Prayer")
        case .calendar: L("Calendar")
        case .qibla: L("Qibla")
        case .names: L("Names")
        }
    }

    private static func uses24Hours(_ prefs: Preferences) -> Bool {
        switch prefs.timeFormat {
        case .hour12: return false
        case .hour24: return true
        case .system: return !(DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: .current) ?? "").contains("a")
        }
    }

    /// Latin digits in every language: a time is read the same way round on a dial in Arabic too.
    private static var digits: Locale { Locale(identifier: Language.code + "@numbers=latn") }

    @MainActor static func time(_ date: Date, zone: TimeZone) -> String {
        let f = DateFormatter()
        f.locale = digits
        f.timeZone = zone
        f.setLocalizedDateFormatFromTemplate(uses24Hours(NoorModel.shared.prefs) ? "HHmm" : "hmma")
        return f.string(from: date)
    }

    static func date(_ date: CivilDate, weekday: Bool = true, year: Bool = true) -> String {
        let f = DateFormatter()
        f.locale = Language.locale
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.setLocalizedDateFormatFromTemplate((weekday ? "EEEE" : "") + "dMMMM" + (year ? "y" : ""))
        return f.string(from: date.anchor)
    }

    /// As a table's first column has it: "Tue, Nov 3".
    static func dateShort(_ date: CivilDate, year: Bool = false) -> String {
        let f = DateFormatter()
        f.locale = Language.locale
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.setLocalizedDateFormatFromTemplate("EEEdMMM" + (year ? "y" : ""))
        return f.string(from: date.anchor)
    }

    static func weekdayShort(_ weekday: Int) -> String {
        let f = DateFormatter()
        f.locale = Language.locale
        return f.shortWeekdaySymbols[(weekday - 1) % 7]
    }

    static func gregorianMonth(_ year: Int, _ month: Int) -> String {
        guard let date = CivilDate(year: year, month: month, day: 1) else { return "" }
        let f = DateFormatter()
        f.locale = Language.locale
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.setLocalizedDateFormatFromTemplate("MMMMy")
        return f.string(from: date.anchor)
    }

    /// The provider's name for the month: Arabic in Arabic, its English otherwise. Not translated further: the name is what it sent.
    static func hijriMonth(_ hijri: HijriDate) -> String {
        if Language.code == "ar", let arabic = hijri.monthNameArabic { return arabic }
        return hijri.monthName ?? "\(hijri.month)"
    }

    static func hijri(_ date: HijriDate) -> String { "\(date.day) \(hijriMonth(date)) \(date.year)" }

    /// "In 14 min", "In 1 hr 18 min": from now, never a tick of seconds.
    static func countdown(to target: Date, from now: Date) -> String {
        let minutes = max(0, Int((target.timeIntervalSince(now) / 60).rounded(.up)))
        if minutes < 1 { return L("Now") }
        if minutes < 60 { return L(one: "In {count} min", other: "In {count} min", count: minutes) }
        return L("In {hours} hr {minutes} min", ["hours": Format.integer(minutes / 60), "minutes": Format.integer(minutes % 60)])
    }

    static func sourceKind(_ source: TimetableSource?) -> String {
        switch source?.kind {
        case .manual: L("Manual")
        case .calculated: L("Calculated")
        case nil: L("No timetable")
        }
    }

    @MainActor static func methodName(_ convention: PrayerConvention?) -> String {
        guard let convention else { return "" }
        return NoorModel.shared.prayerMethods.first { $0.id == convention.method }?.name ?? L("Method {id}", ["id": "\(convention.method)"])
    }

    @MainActor static func calendarMethodName(_ method: CalendarMethod) -> String {
        NoorModel.shared.calendarMethods.first { $0.method == method }?.name ?? method.rawValue
    }

    /// Where the times come from, in a line: `Tokyo · Calculated · Muslim World League`.
    /// Where a time comes from, short enough for a tile.
    @MainActor static func tileSource(_ snapshot: NoorSnapshot) -> String {
        if let source = snapshot.source, source.kind == .manual { return "\(source.name) · \(L("Manual"))" }
        return [snapshot.place?.label, sourceKind(snapshot.source)].compactMap { $0 }.joined(separator: " · ")
    }

    @MainActor static func provenance(_ snapshot: NoorSnapshot) -> String {
        var parts: [String] = []
        if let source = snapshot.source, source.kind == .manual {
            parts = [source.name, L("Manual"), source.zoneID]
        } else {
            if let place = snapshot.place { parts.append(place.label) }
            parts.append(sourceKind(snapshot.source))
            let method = methodName(snapshot.convention)
            if !method.isEmpty { parts.append(method) }
        }
        return parts.joined(separator: " · ")
    }

    /// `saved`: something saved earlier is on screen. Without it nothing is, so no sentence may lean on a saved copy.
    static func problem(_ reason: UnavailableReason?, saved: Bool = false) -> String {
        switch reason {
        case .offline: saved ? L("No connection. What is shown was saved earlier.") : L("No connection right now.")
        case .rateLimited: L("The provider asked Noor to wait a moment. It will try again by itself.")
        case .malformed: saved ? L("The provider's answer couldn't be read, so the last good one stays.") : L("The provider's answer couldn't be read.")
        case .noCoverage: L("The provider has nothing for that date.")
        case .expired: L("This timetable has ended.")
        case .noPlace: L("Choose a place first.")
        case nil: ""
        }
    }

    /// What happened, in a line, for a CSV's rows that can't be taken.
    static func importIssue(_ issue: ImportIssue) -> String {
        let at = issue.line > 0 ? L("Line {line}: ", ["line": Format.integer(issue.line)]) : ""
        let what: String
        switch issue.kind {
        case .tooLarge: what = L("The file is larger than 1 MB.")
        case .notText: what = L("This isn't a text file.")
        case .emptyName: what = L("Give the timetable a name.")
        case .badHeader: what = L("The first line must be {header}.", ["header": CSVImport.header])
        case .noRows: what = L("There are no rows in it.")
        case .tooManyRows: what = L("There are more than 5,000 rows.")
        case .tooManyDays: what = L("It covers more than 400 days.")
        case .wrongColumns: what = L("This row doesn't have five columns.")
        case .badDate(let text): what = L("“{date}” isn't a date like 2027-01-31.", ["date": text])
        case .badPrayer(let text): what = L("“{prayer}” isn't fajr, dhuhr, asr, maghrib, isha or friday-1.", ["prayer": text])
        case .badStart(let text): what = L("“{time}” isn't a start time like 05:30.", ["time": text])
        case .badIqamah(let text): what = L("“{time}” isn't an iqamah time like 05:50.", ["time": text])
        case .badZone(let text): what = L("“{zone}” isn't a time zone like Europe/London.", ["zone": text])
        case .mixedZone(let text): what = L("“{zone}” differs from the file's other rows.", ["zone": text])
        case .outsideRange: what = L("This date is outside the range you chose.")
        case .notAFriday: what = L("A Friday session on a date that isn't a Friday.")
        case .iqamahBeforeStart: what = L("The iqamah is before its start.")
        case .outOfOrder: what = L("This prayer starts before the one before it.")
        case .timeInGap(let text): what = L("The clock skips {time} on this date.", ["time": text])
        case .timeInFold(let text): what = L("The clock shows {time} twice on this date.", ["time": text])
        }
        return at + what
    }
}

/// The five places inside Noor's one Home entry. Ramadan, setup and preferences are states of a tab, reached from one.
enum NoorTab: String, CaseIterable {
    case overview, prayer, calendar, qibla, names

    var symbol: String {
        switch self {
        case .overview: "square.grid.2x2"
        case .prayer: "building.columns"
        case .calendar: "calendar"
        case .qibla: "safari"
        case .names: "book"
        }
    }
}
