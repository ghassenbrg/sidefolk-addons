import Foundation
import Testing
@testable import ext_prayer_times

/// Every saved provider answer, then the ways an answer can be wrong. Nothing here reaches the network.
struct NoorDecodingTests {
    typealias S = NoorSupport

    private func tokyoDay() throws -> PrayerDay {
        try AlAdhanDecoder.timings(S.fixture("prayer-day"), date: S.date("2026-11-02"), query: S.query)
    }

    @Test func prayerDayKeepsEachTimingsOwnDate() throws {
        let day = try tokyoDay()
        #expect(day.date == S.date("2026-11-02") && day.zoneID == "Asia/Tokyo" && day.sourceID == "calculated.tokyo")
        #expect(S.clock(day.starts[.fajr]!) == "2026-11-02 04:37")
        #expect(S.clock(day.starts[.dhuhr]!) == "2026-11-02 11:25")
        #expect(S.clock(day.starts[.asr]!) == "2026-11-02 14:24")
        #expect(S.clock(day.starts[.maghrib]!) == "2026-11-02 16:46")
        #expect(S.clock(day.starts[.isha]!) == "2026-11-02 18:07")
        #expect(S.clock(day.solar[.sunrise]!) == "2026-11-02 06:04")
        #expect(S.clock(day.solar[.imsak]!) == "2026-11-02 04:27")
        #expect(S.clock(day.solar[.sunset]!) == "2026-11-02 16:46")
        #expect(S.clock(day.solar[.midnight]!) == "2026-11-02 23:25")
        #expect(S.clock(day.solar[.firstThird]!) == "2026-11-02 21:12")
        #expect(S.clock(day.solar[.lastThird]!) == "2026-11-03 01:38", "the next civil day, as the provider said")
        #expect(day.iqamah.isEmpty && day.friday.isEmpty, "the provider gives neither, and nothing infers them")
        #expect(day.method?.id == 3 && day.method?.name == "Muslim World League" && day.method?.latitudeAdjustment == "ANGLE_BASED")
        let hijri = try #require(day.hijri)
        #expect((hijri.year, hijri.month, hijri.day, hijri.monthLength) == (1448, 5, 22, 30))
        #expect(hijri.method == .uaq && hijri.monthName == "Jumādá al-ūlá")
    }

    @Test func qiblaFromTokyoRoundsTo293() throws {
        let bearing = try AlAdhanDecoder.qibla(S.fixture("qibla-tokyo"), place: S.tokyo, fetched: Date(timeIntervalSince1970: 5))
        #expect(abs(bearing.degrees - 292.9987) < 0.001 && bearing.rounded == 293)
        #expect(bearing.fetched == Date(timeIntervalSince1970: 5) && bearing.isFor(S.tokyo))
    }

    @Test func conversionsBothWays() throws {
        let forward = try AlAdhanDecoder.conversion(S.fixture("date-conversion"), gregorian: S.date("2026-11-02"), method: .uaq)
        #expect(forward.hijri.api == "22-05-1448" && forward.gregorian.weekday == 2)
        let target = try #require(HijriDate(year: 1448, month: 5, day: 22))
        let back = try AlAdhanDecoder.conversion(S.fixture("hijri-to-gregorian"), hijri: target, method: .uaq)
        #expect(back.gregorian == S.date("2026-11-02") && back.method == .uaq)
        #expect(throws: AlAdhanError.self) {
            try AlAdhanDecoder.conversion(S.fixture("hijri-to-gregorian"), hijri: HijriDate(year: 1448, month: 5, day: 23)!, method: .uaq)
        }
    }

    @Test func gregorianMonthUsesTheReturnedDates() throws {
        let month = try AlAdhanDecoder.gregorianMonth(S.fixture("gregorian-month"), year: 2026, month: 11, method: .uaq)
        #expect(month.dayCount == 30 && month.axis == .gregorian(year: 2026, month: 11) && month.method == .uaq)
        #expect(month.leadingBlanks(firstWeekday: 1) == 0, "1 November 2026 is a Sunday")
        #expect(month.leadingBlanks(firstWeekday: 2) == 6, "the same day in a Monday-first grid")
        #expect(month.leadingBlanks(firstWeekday: 7) == 1)
        let tenth = month.days[9], eleventh = month.days[10]
        #expect(tenth.hijri.api == "30-05-1448" && tenth.hijri.monthLength == 30)
        #expect(eleventh.hijri.api == "01-06-1448" && eleventh.hijri.monthLength == 29, "the next Hijri month is really 29 days")
    }

    @Test func ramadanMonthIsTheLengthReturned() throws {
        let days = try AlAdhanDecoder.hijriPrayerCalendar(S.fixture("ramadan-month"), year: 1448, month: 9, query: S.query)
        let month = try #require(RamadanMonth(days: days))
        #expect(month.dayCount == 29 && month.hijriYear == 1448 && month.method == .uaq)
        #expect(month.days[0].date == S.date("2027-02-08") && month.days[0].number == 1)
        #expect(S.clock(month.days[0].fajr) == "2027-02-08 05:10")
        #expect(S.clock(month.days[0].maghrib) == "2027-02-08 17:15")
        #expect(S.clock(month.days[0].imsak!) == "2027-02-08 05:00", "kept apart from Fajr")
        #expect(S.clock(month.days[1].fajr) == "2027-02-09 05:09" && S.clock(month.days[1].maghrib) == "2027-02-09 17:16")
        #expect(month.days.last?.date == S.date("2027-03-08") && month.days.last?.number == 29)
    }

    @Test func namesMethodsAndOccasions() throws {
        let names = try AlAdhanDecoder.names(S.fixture("names"))
        #expect(names.count == 99 && names.map(\.number) == Array(1...99))
        #expect(names[0].transliteration == "Ar Rahmaan" && names[0].meaning == "The Beneficent" && names[0].arabic == "الرَّحْمَنُ")

        let calendars = try AlAdhanDecoder.calendarMethods(S.fixture("calendar-methods"))
        #expect(calendars.map(\.method) == [.uaq, .hjcosa, .diyanet, .mathematical])

        let prayers = try AlAdhanDecoder.prayerMethods(S.fixture("prayer-methods"))
        #expect(prayers.count == 23 && !prayers.contains { $0.id == 99 } && prayers.map(\.id) == prayers.map(\.id).sorted())
        let makkah = try #require(prayers.first { $0.key == "MAKKAH" })
        #expect(makkah.id == 4 && makkah.parameters["Isha"] == "90 min" && makkah.parameters["Fajr"] == "18.5")

        let occasions = try AlAdhanDecoder.occasions(S.fixture("listed-occasions"), hijriYear: 1448, method: .uaq)
        #expect(occasions.count == 77, "78 records repeat themselves; these are the distinct method, date and event triples")
        let mawlid = occasions.filter { $0.gregorian == S.date("2026-08-25") }
        #expect(mawlid.count == 7, "seven different events on one date all stay")
        #expect(mawlid.contains { $0.identity == "mawlid-birth-al-nabi" && $0.hijri.api == "12-03-1448" })
        #expect(occasions.contains { $0.identity == "1st-day-of-ramadan" && $0.gregorian == S.date("2027-02-08") })
        let month = try AlAdhanDecoder.gregorianMonth(S.fixture("gregorian-month"), year: 2026, month: 11, method: .uaq)
        #expect(month.days.allSatisfy { $0.occasions.allSatisfy { $0.method == .uaq } })
    }

    @Test func occasionDedupeKeepsDistinctEventsOnOneDate() throws {
        let hijri = try #require(HijriDate(year: 1448, month: 1, day: 10))
        let date = S.date("2026-06-25")
        func occasion(_ title: String, method: CalendarMethod = .uaq, on day: CivilDate? = nil) -> Occasion {
            Occasion(title: title, method: method, hijri: hijri, gregorian: day ?? date)
        }
        let kept = Occasion.dedupe([occasion("Ashura"), occasion("ASHURA"), occasion("Āshurā"), occasion("Urs of Shaykh"), occasion("Ashura", method: .diyanet),
                                    occasion("Ashura", on: S.date("2026-06-26")), occasion("Urs of Shaykh")])
        #expect(kept.map(\.title) == ["Ashura", "Urs of Shaykh", "Ashura", "Ashura"])
        #expect(Occasion.normalize("Urs of Shaykh Abū al‑Hassan al‑Kharqāni ق") == "urs-of-shaykh-abu-al-hassan-al-kharqani", "a non-breaking hyphen is a word break")
        #expect(!Occasion.normalize("عاشوراء").isEmpty, "a title with no Latin letters still has an identity")
    }

    @Test func extraFieldsAreIgnored() throws {
        let data = try S.edited("prayer-day", ["data", "somethingNew"], ["a": 1])
        #expect(try AlAdhanDecoder.timings(data, date: S.date("2026-11-02"), query: S.query).date == S.date("2026-11-02"))
        let extraTiming = try S.edited("prayer-day", ["data", "timings", "Tahajjud"], "nonsense")
        #expect(try AlAdhanDecoder.timings(extraTiming, date: S.date("2026-11-02"), query: S.query).solar.count == 6)
    }

    @Test func missingSolarValuesStayAbsentButAWrongOneIsRefused() throws {
        let date = S.date("2026-11-02")
        let missing = try AlAdhanDecoder.timings(S.edited("prayer-day", ["data", "timings", "Sunrise"], nil), date: date, query: S.query)
        #expect(missing.solar[.sunrise] == nil && missing.solar[.sunset] != nil && missing.starts.count == 5)
        let null = try AlAdhanDecoder.timings(S.edited("prayer-day", ["data", "timings", "Lastthird"], NSNull()), date: date, query: S.query)
        #expect(null.solar[.lastThird] == nil)
        #expect(throws: AlAdhanError.self) {
            try AlAdhanDecoder.timings(S.edited("prayer-day", ["data", "timings", "Sunrise"], "--:--"), date: date, query: S.query)
        }
    }

    @Test func aWrongAnswerIsAnError() throws {
        let wrong: [([Any], Any?, String)] = [
            (["data", "timings", "Fajr"], nil, "a prayer missing"),
            (["data", "timings", "Isha"], "18:07 (JST)", "not an ISO timestamp"),
            (["data", "timings", "Fajr"], "2026-11-02T04:37:00+08:00", "an offset this zone doesn't have"),
            (["data", "timings", "Fajr"], "2026-11-09T04:37:00+09:00", "a week from the date"),
            (["data", "timings", "Fajr"], "2026-13-02T04:37:00+09:00", "an impossible month"),
            (["data", "timings", "Fajr"], 437, "a number where a timestamp goes"),
            (["data", "meta", "timezone"], "Asia/Seoul", "another zone"),
            (["data", "meta", "method", "id"], 2, "another method"),
            (["data", "meta", "latitude"], 40.0, "another place"),
            (["data", "date", "hijri", "method"], "DIYANET", "another calendar"),
            (["data", "date", "gregorian", "weekday", "en"], "Tuesday", "a weekday that isn't this date's"),
            (["data", "date", "gregorian", "date"], "31-02-2026", "31 February"),
            (["data", "date", "hijri", "date"], "31-05-1448", "a 31st Hijri day"),
            (["code"], 400, "an API error"),
            (["data"], "Bad request", "no data"),
        ]
        for (path, value, what) in wrong {
            let data = try S.edited("prayer-day", path, value)
            #expect(throws: AlAdhanError.self, Comment(rawValue: what)) {
                try AlAdhanDecoder.timings(data, date: S.date("2026-11-02"), query: S.query)
            }
        }
    }

    @Test func anAnswerAboutAnotherDateDoesNotCoverThisOne() throws {
        #expect(throws: AlAdhanError.noCoverage("asked for 2026-11-03, got 2026-11-02")) {
            try AlAdhanDecoder.timings(S.fixture("prayer-day"), date: S.date("2026-11-03"), query: S.query)
        }
        #expect(throws: AlAdhanError.self) { try AlAdhanDecoder.gregorianMonth(S.fixture("gregorian-month"), year: 2026, month: 12, method: .uaq) }
        #expect(throws: AlAdhanError.self) { try AlAdhanDecoder.hijriPrayerCalendar(S.fixture("ramadan-month"), year: 1449, month: 9, query: S.query) }
    }

    @Test func notJSONAndAnAPICodeAreNamed() throws {
        #expect(throws: AlAdhanError.malformed("no code")) {
            try AlAdhanDecoder.names(Data("<html>maintenance</html>".utf8))
        }
        #expect(throws: AlAdhanError.apiCode(429)) {
            try AlAdhanDecoder.names(Data(#"{"code":429,"data":"slow down"}"#.utf8))
        }
        #expect(throws: AlAdhanError.self) { try AlAdhanDecoder.names(Data(count: AlAdhanDecoder.maximumBytes + 1)) }
    }

    @Test func aMonthWithAHoleIsRefused() throws {
        #expect(throws: AlAdhanError.self) { try AlAdhanDecoder.gregorianMonth(S.edited("gregorian-month", ["data", 12], nil), year: 2026, month: 11, method: .uaq) }
        #expect(throws: AlAdhanError.self, "28 days is no Hijri month") {
            let shorter = try S.edited("ramadan-month", ["data", 28], nil)
            let data = try JSONSerialization.jsonObject(with: shorter) as! [String: Any]
            var days = data["data"] as! [Any]
            days.removeLast()
            try AlAdhanDecoder.hijriPrayerCalendar(JSONSerialization.data(withJSONObject: ["code": 200, "data": days]), year: 1448, month: 9, query: S.query)
        }
        #expect(throws: AlAdhanError.self, "the month says 29 days and shows 28 plus a skip") {
            try AlAdhanDecoder.hijriPrayerCalendar(S.edited("ramadan-month", ["data", 1], nil), year: 1448, month: 9, query: S.query)
        }
    }

    @Test func aBadBearingOrAShortListIsRefused() throws {
        for direction in [400.0, -1, 360] {
            #expect(throws: AlAdhanError.self) {
                try AlAdhanDecoder.qibla(S.edited("qibla-tokyo", ["data", "direction"], direction), place: S.tokyo, fetched: Date())
            }
        }
        #expect(throws: AlAdhanError.self, "text where a number goes") {
            try AlAdhanDecoder.qibla(S.edited("qibla-tokyo", ["data", "direction"], "NaN"), place: S.tokyo, fetched: Date())
        }
        #expect(throws: AlAdhanError.self, "a bearing for somewhere else") {
            try AlAdhanDecoder.qibla(S.edited("qibla-tokyo", ["data", "latitude"], 10), place: S.tokyo, fetched: Date())
        }
        #expect(throws: AlAdhanError.self) { try AlAdhanDecoder.names(S.edited("names", ["data", 50], nil)) }
        #expect(throws: AlAdhanError.self) { try AlAdhanDecoder.names(S.edited("names", ["data", 0, "en", "meaning"], "")) }
    }

    /// `/calendar` wasn't among the saved answers. It is documented as `/hijriCalendar`'s shape, so this is the fixture's
    /// day rewritten across a month: it checks Noor's reading, not the endpoint itself.
    @Test func aGregorianPrayerMonth() throws {
        let names = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        let template = try #require(String(data: try S.fixture("prayer-day"), encoding: .utf8))
        func entry(_ day: Int) -> Any {
            let date = CivilDate(year: 2026, month: 11, day: day)!
            let text = template.replacingOccurrences(of: "2026-11-03T", with: "\(date.next.iso)T").replacingOccurrences(of: "2026-11-02T", with: "\(date.iso)T")
                .replacingOccurrences(of: "\"02-11-2026\"", with: "\"\(date.api)\"").replacingOccurrences(of: "\"Monday\"", with: "\"\(names[date.weekday - 1])\"")
            return (try! JSONSerialization.jsonObject(with: Data(text.utf8)) as! [String: Any])["data"]!
        }
        let month = try JSONSerialization.data(withJSONObject: ["code": 200, "data": (1...30).map(entry)])
        let days = try AlAdhanDecoder.prayerCalendar(month, year: 2026, month: 11, query: S.query)
        #expect(days.count == 30 && days[16].date == S.date("2026-11-17") && S.clock(days[16].solar[.lastThird]!) == "2026-11-18 01:38")
        let holed = try JSONSerialization.data(withJSONObject: ["code": 200, "data": (1...29).map(entry)])
        #expect(throws: AlAdhanError.self) { try AlAdhanDecoder.prayerCalendar(holed, year: 2026, month: 11, query: S.query) }
        #expect(throws: AlAdhanError.self, "a month that isn't in the one month") {
            try AlAdhanDecoder.prayerCalendar(S.fixture("ramadan-month"), year: 2027, month: 2, query: S.query)
        }
    }

    /// `/hToGCalendar` wasn't saved either: the Ramadan fixture's date pairs stand in, with the same caveat.
    @Test func aHijriCalendarMonth() throws {
        let object = try #require(try JSONSerialization.jsonObject(with: S.fixture("ramadan-month")) as? [String: Any])
        let pairs = (object["data"] as! [[String: Any]]).map { $0["date"]! }
        let month = try AlAdhanDecoder.hijriMonth(JSONSerialization.data(withJSONObject: ["code": 200, "data": pairs]), year: 1448, month: 9, method: .uaq)
        #expect(month.dayCount == 29 && month.axis == .hijri(year: 1448, month: 9))
        #expect(month.days[0].gregorian == S.date("2027-02-08") && month.days[0].occasions.map(\.identity) == ["1st-day-of-ramadan"])
        #expect(month.leadingBlanks(firstWeekday: 1) == 1, "8 February 2027 is a Monday")
    }

    // MARK: - Requests

    @Test func requestsAskForTheRightThing() throws {
        let timings = AlAdhan.timings(S.date("2026-11-02"), S.query).url
        #expect(timings.path() == "/v1/timings/02-11-2026")
        let query = try #require(timings.query(percentEncoded: true))
        for part in ["latitude=35.6762", "longitude=139.6503", "method=3", "school=0", "timezonestring=Asia%2FTokyo", "calendarMethod=UAQ", "iso8601=true"] {
            #expect(query.contains(part), Comment(rawValue: part))
        }
        #expect(!query.contains("tune") && !query.contains("latitudeAdjustmentMethod"))
        #expect(AlAdhan.hijriToGregorian(HijriDate(year: 1448, month: 5, day: 22)!, method: .uaq).url.absoluteString == "https://api.aladhan.com/v1/hToG/22-05-1448?calendarMethod=UAQ")
        #expect(AlAdhan.gregorianToHijri(S.date("2026-11-02"), method: .uaq).url.absoluteString == "https://api.aladhan.com/v1/gToH/02-11-2026?calendarMethod=UAQ")
        #expect(AlAdhan.gregorianMonth(year: 2026, month: 11, method: .uaq).url.absoluteString == "https://api.aladhan.com/v1/gToHCalendar/11/2026?calendarMethod=UAQ")
        #expect(AlAdhan.hijriMonth(year: 1448, month: 9, method: .uaq).url.absoluteString == "https://api.aladhan.com/v1/hToGCalendar/9/1448?calendarMethod=UAQ")
        #expect(AlAdhan.hijriPrayerCalendar(year: 1448, month: 9, S.query).url.path() == "/v1/hijriCalendar/1448/9")
        #expect(AlAdhan.prayerCalendar(year: 2026, month: 11, S.query).url.path() == "/v1/calendar/2026/11")
        #expect(AlAdhan.qibla(S.tokyo).url.absoluteString == "https://api.aladhan.com/v1/qibla/35.6762/139.6503")
        #expect(AlAdhan.names().url.absoluteString == "https://api.aladhan.com/v1/asmaAlHusna")
        #expect(AlAdhan.calendarMethods().url.absoluteString == "https://api.aladhan.com/v1/islamicCalendar/methods")
        #expect(AlAdhan.prayerMethods().url.absoluteString == "https://api.aladhan.com/v1/methods")
        #expect(AlAdhan.occasions(hijriYear: 1448, method: .uaq).url.absoluteString == "https://api.aladhan.com/v1/islamicHolidaysByHijriYear/1448?calendarMethod=UAQ")
    }

    @Test func queryValuesAreEncodedSoAPlusSurvives() throws {
        let place = try Place(id: "sea", label: "At sea", latitude: 0, longitude: -75, zoneID: "Etc/GMT+5")
        let query = PrayerQuery(place: place, convention: try PrayerConvention(method: 2, school: 1, latitudeAdjustment: 3, tune: [.fajr: 2, .isha: -5]), calendarMethod: .diyanet)
        let text = try #require(AlAdhan.timings(S.date("2026-11-02"), query).url.query(percentEncoded: true))
        #expect(text.contains("timezonestring=Etc%2FGMT%2B5"))
        #expect(text.contains("school=1") && text.contains("latitudeAdjustmentMethod=3"))
        #expect(text.contains("tune=0%2C2%2C0%2C0%2C0%2C0%2C0%2C-5%2C0"), "the provider's nine slots: Imsak, Fajr, Sunrise, Dhuhr, Asr, Maghrib, Sunset, Isha, Midnight")
    }

    @Test func prayerKeysFollowEverythingThatChangesTheTimes() throws {
        let base = AlAdhan.timings(S.date("2026-11-02"), S.query).cacheKey
        func key(_ place: Place = S.tokyo, _ convention: PrayerConvention = S.mwl, calendar: CalendarMethod = .uaq) -> String {
            AlAdhan.timings(S.date("2026-11-02"), PrayerQuery(place: place, convention: convention, calendarMethod: calendar)).cacheKey
        }
        #expect(key() == base)
        let renamed = try Place(id: "tokyo", label: "Home", latitude: 35.6762, longitude: 139.6503, zoneID: "Asia/Tokyo")
        #expect(key(renamed) == base, "a label changes no time")
        let moved = try Place(id: "tokyo", label: "Tokyo", latitude: 35.7, longitude: 139.6503, zoneID: "Asia/Tokyo")
        let rezoned = try Place(id: "tokyo", label: "Tokyo", latitude: 35.6762, longitude: 139.6503, zoneID: "Asia/Seoul")
        let others = [key(moved), key(rezoned), key(S.tokyo, try PrayerConvention(method: 2)), key(S.tokyo, try PrayerConvention(method: 3, school: 1)),
                      key(S.tokyo, try PrayerConvention(method: 3, latitudeAdjustment: 1)), key(S.tokyo, try PrayerConvention(method: 3, tune: [.asr: 1])),
                      key(calendar: .diyanet), AlAdhan.timings(S.date("2026-11-03"), S.query).cacheKey]
        #expect(Set(others + [base]).count == others.count + 1)
        #expect(AlAdhan.gregorianMonth(year: 2026, month: 11, method: .uaq).cacheKey != AlAdhan.gregorianMonth(year: 2026, month: 11, method: .diyanet).cacheKey)
        #expect(AlAdhan.occasions(hijriYear: 1448, method: .uaq).cacheKey != AlAdhan.occasions(hijriYear: 1449, method: .uaq).cacheKey)
        #expect(AlAdhan.names().cacheKey != AlAdhan.calendarMethods().cacheKey)
    }
}
