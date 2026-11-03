import Foundation
import Testing
@testable import ext_prayer_times

/// Manual timetables: the file format, its limits, and what blocks saving.
struct NoorTimetableTests {
    typealias S = NoorSupport

    private func day(_ date: String, zone: String = "Asia/Tokyo", iqamah: Bool = true) -> String {
        """
        \(date),fajr,05:30,\(iqamah ? "05:50" : ""),\(zone)
        \(date),dhuhr,11:50,,\(zone)
        \(date),asr,14:20,\(iqamah ? "14:30" : ""),\(zone)
        \(date),maghrib,16:50,16:55,\(zone)
        \(date),isha,18:20,,\(zone)
        """
    }

    private func csv(_ body: String...) -> ImportReview {
        CSVImport.parse(data: Data(([CSVImport.header] + body).joined(separator: "\n").utf8), name: "Masjid")
    }

    @Test func aValidFileMakesAManualSource() throws {
        let review = csv(day("2026-11-02"), day("2026-11-03", iqamah: false))
        #expect(review.canSave && review.errors.isEmpty && review.rows.count == 10)
        #expect(review.coverage == S.date("2026-11-02")...S.date("2026-11-03") && review.zone == "Asia/Tokyo")
        let table = try #require(review.timetable(id: "manual.masjid", attribution: "Masjid board"))
        #expect(table.source.kind == .manual && table.source.name == "Masjid" && table.source.lastFetch == nil && table.source.revision == 1)
        #expect(table.source.coverage == review.coverage && table.source.attribution == "Masjid board")
        #expect(table.days.map(\.date) == [S.date("2026-11-02"), S.date("2026-11-03")])
        let first = table.days[0], second = table.days[1]
        #expect(S.clock(first.starts[.fajr]!) == "2026-11-02 05:30" && S.clock(first.iqamah[.fajr]!) == "2026-11-02 05:50")
        #expect(first.iqamah[.dhuhr] == nil, "a missing iqamah is missing, never inferred")
        #expect(second.iqamah[.fajr] == nil && second.iqamah[.maghrib] != nil)
        #expect(first.friday.isEmpty && first.solar.isEmpty && first.method == nil && first.hijri == nil)
        #expect(first.sourceID == "manual.masjid")
    }

    @Test func theTemplateParsesAndHasANamedFridaySession() throws {
        let review = CSVImport.parse(data: Data(CSVImport.template.utf8), name: "Template")
        #expect(review.canSave, "\(review.errors)")
        let table = try #require(review.timetable(id: "t", attribution: ""))
        #expect(table.days[0].friday.map(\.id) == ["friday-1"] && S.clock(table.days[0].friday[0].start) == "2027-01-01 12:30")
        #expect(table.days[0].friday[0].iqamah != nil)
    }

    @Test func aBOMAndWindowsLineEndingsAreFine() throws {
        let text = "\u{FEFF}" + ([CSVImport.header, day("2026-11-02")].joined(separator: "\n")).replacingOccurrences(of: "\n", with: "\r\n") + "\r\n\r\n"
        let review = CSVImport.parse(data: Data(text.utf8), name: "Masjid")
        #expect(review.canSave, "\(review.errors)")
    }

    @Test func aRepeatedRowIsADuplicateAndADifferentOneAConflict() throws {
        let duplicate = csv(day("2026-11-02"), "2026-11-02,fajr,05:30,05:50,Asia/Tokyo")
        #expect(!duplicate.canSave && duplicate.duplicates.count == 1 && duplicate.conflicts.isEmpty)
        #expect(duplicate.duplicates[0].line == 7 && duplicate.duplicates[0].firstLine == 2 && duplicate.duplicates[0].slot == .prayer(.fajr))
        let conflict = csv(day("2026-11-02"), "2026-11-02,fajr,05:31,05:50,Asia/Tokyo")
        #expect(!conflict.canSave && conflict.conflicts.count == 1 && conflict.duplicates.isEmpty)
        #expect(conflict.conflicts[0].line == 7)
        #expect(conflict.timetable(id: "x", attribution: "") == nil, "nothing to save while it is blocked")
        let iqamah = csv(day("2026-11-02"), "2026-11-02,fajr,05:30,06:00,Asia/Tokyo")
        #expect(iqamah.conflicts.count == 1, "the same start with another iqamah still disagrees")
    }

    @Test func zonesAreCheckedAndNeverMixed() throws {
        let bad = csv(day("2026-11-02", zone: "Mars/Olympus"))
        #expect(!bad.canSave && bad.errors.first == ImportIssue(line: 2, kind: .badZone("Mars/Olympus")) && bad.zone == nil)
        let abbreviation = csv(day("2026-11-02", zone: "JST"))
        #expect(abbreviation.errors.first?.kind == .badZone("JST"))
        let mixed = csv(day("2026-11-02"), day("2026-11-03", zone: "Asia/Seoul"))
        #expect(!mixed.canSave && mixed.errors.contains(ImportIssue(line: 7, kind: .mixedZone("Asia/Seoul"))) && mixed.zone == "Asia/Tokyo")
    }

    @Test func impossibleAndAmbiguousDatesAreRefused() throws {
        let impossible = csv("2027-02-31,fajr,05:30,,Asia/Tokyo")
        #expect(!impossible.canSave && impossible.errors == [ImportIssue(line: 2, kind: .badDate("2027-02-31"))])
        for ambiguous in ["03/04/2027", "2027-3-4", "04-03-2027", "tomorrow"] {
            let review = csv("\(ambiguous),fajr,05:30,,Asia/Tokyo")
            #expect(!review.canSave && review.errors == [ImportIssue(line: 2, kind: .badDate(ambiguous))])
        }
    }

    @Test func rowsWithBadFieldsAreNamedByLine() throws {
        let review = csv(day("2026-11-02"), "2026-11-03,sunrise,06:00,,Asia/Tokyo", "2026-11-03,fajr,5:30,,Asia/Tokyo", "2026-11-03,dhuhr,11:50,noon,Asia/Tokyo", "2026-11-03,asr", "2026-11-04,friday-1,12:00,,Asia/Tokyo")
        let kinds = Dictionary(uniqueKeysWithValues: review.errors.map { ($0.line, $0.kind) })
        #expect(kinds[7] == .badPrayer("sunrise"), "sunrise isn't a prayer")
        #expect(kinds[8] == .badStart("5:30") && kinds[9] == .badIqamah("noon") && kinds[10] == .wrongColumns)
        #expect(kinds[11] == .notAFriday, "4 November 2026 is a Wednesday")
        #expect(!review.canSave)
    }

    @Test func headerAndEmptiness() throws {
        #expect(CSVImport.parse(data: Data("date,start\n".utf8), name: "x").errors == [ImportIssue(line: 1, kind: .badHeader)])
        #expect(CSVImport.parse(data: Data("".utf8), name: "x").errors.first?.kind == .badHeader)
        #expect(!csv().canSave && csv().errors.first?.kind == .noRows)
        #expect(CSVImport.parse(data: Data([0xff, 0xfe, 0x00]), name: "x").errors.first?.kind == .notText)
        let unnamed = CSVImport.parse(data: Data(([CSVImport.header, day("2026-11-02")].joined(separator: "\n")).utf8), name: "  ")
        #expect(!unnamed.canSave && unnamed.errors.first?.kind == .emptyName)
    }

    @Test func limits() throws {
        let tooBig = CSVImport.parse(data: Data(count: CSVImport.maximumBytes + 1), name: "x")
        #expect(!tooBig.canSave && tooBig.errors.first?.kind == .tooLarge)

        let rows = (0...CSVImport.maximumRows).map { _ in "2026-11-02,fajr,05:30,,Asia/Tokyo" }
        let tooMany = csv(rows.joined(separator: "\n"))
        #expect(!tooMany.canSave && tooMany.errors.first?.kind == .tooManyRows && tooMany.rows.isEmpty)

        let span = csv(day("2026-01-01"), day("2027-02-05"))
        #expect(!span.canSave && span.errors.contains { $0.kind == .tooManyDays })
        #expect(span.missingDates.isEmpty, "too long to walk, so it doesn't")

        // Exactly 400 days pass, in a file or a pattern; a day more doesn't.
        var date = S.date("2026-01-01")
        var whole: [String] = []
        for _ in 0..<ImportReview.maximumDays { whole.append(day(date.iso)); date = date.next }
        #expect(csv(whole.joined(separator: "\n")).canSave)
        #expect(!csv((whole + [day(date.iso)]).joined(separator: "\n")).canSave)
        let pattern = FixedPattern(zoneID: "UTC", starts: Dictionary(uniqueKeysWithValues: zip(PrayerID.allCases, ["05:00", "12:00", "15:00", "18:00", "19:00"].map { LocalTime(text: $0)! })))
        #expect(pattern.review(name: "x", range: S.date("2026-01-01")...S.date("2026-01-01").adding(days: 399)).canSave)
        #expect(!pattern.review(name: "x", range: S.date("2026-01-01")...S.date("2026-01-01").adding(days: 400)).canSave)
    }

    @Test func missingRowsAndDatesBlockSaving() throws {
        let hole = csv(day("2026-11-02"), day("2026-11-04"))
        #expect(!hole.canSave && hole.missingDates == [S.date("2026-11-03")])
        #expect(hole.timetable(id: "x", attribution: "") == nil)
        let partial = csv(day("2026-11-02"), "2026-11-03,fajr,05:30,,Asia/Tokyo")
        #expect(!partial.canSave && partial.missingRows.count == 4 && partial.missingRows.first == MissingRow(date: S.date("2026-11-03"), prayer: .dhuhr))
    }

    @Test func rowsThatCannotBeRightAreRefused() throws {
        let early = csv("2026-11-02,fajr,05:30,05:00,Asia/Tokyo", "2026-11-02,dhuhr,11:50,,Asia/Tokyo", "2026-11-02,asr,14:20,,Asia/Tokyo", "2026-11-02,maghrib,16:50,,Asia/Tokyo", "2026-11-02,isha,18:20,,Asia/Tokyo")
        #expect(early.errors.first == ImportIssue(line: 2, kind: .iqamahBeforeStart))
        let order = csv("2026-11-02,fajr,05:30,,Asia/Tokyo", "2026-11-02,dhuhr,11:50,,Asia/Tokyo", "2026-11-02,asr,14:20,,Asia/Tokyo", "2026-11-02,maghrib,16:50,,Asia/Tokyo", "2026-11-02,isha,00:10,,Asia/Tokyo")
        #expect(order.errors == [ImportIssue(line: 6, kind: .outOfOrder)], "the row's date says it is before Fajr; it isn't quietly moved to tomorrow")
    }

    @Test func dstTimesAreReportedNotGuessed() throws {
        let zone = "America/New_York"
        func newYork(_ date: String, fajr: String, iqamah: String = "") -> ImportReview {
            csv("\(date),fajr,\(fajr),\(iqamah),\(zone)", "\(date),dhuhr,11:50,,\(zone)", "\(date),asr,14:20,,\(zone)", "\(date),maghrib,16:50,,\(zone)", "\(date),isha,18:20,,\(zone)")
        }
        let gap = newYork("2026-03-08", fajr: "02:30")
        #expect(!gap.canSave && gap.errors == [ImportIssue(line: 2, kind: .timeInGap("02:30"))])
        let fold = newYork("2026-11-01", fajr: "01:30")
        #expect(!fold.canSave && fold.errors == [ImportIssue(line: 2, kind: .timeInFold("01:30"))])
        let iqamahGap = newYork("2026-03-08", fajr: "01:50", iqamah: "02:10")
        #expect(!iqamahGap.canSave && iqamahGap.errors == [ImportIssue(line: 2, kind: .timeInGap("02:10"))])
        #expect(newYork("2026-03-09", fajr: "02:30").canSave, "the next day has that time")

        let london = "Europe/London"
        let row = "2026-10-25,fajr,01:30,,\(london)"
        let foldLondon = csv(row, "2026-10-25,dhuhr,11:50,,\(london)", "2026-10-25,asr,14:20,,\(london)", "2026-10-25,maghrib,16:50,,\(london)", "2026-10-25,isha,18:20,,\(london)")
        #expect(foldLondon.errors == [ImportIssue(line: 2, kind: .timeInFold("01:30"))])
    }

    @Test func dstDaysKeepTheirOwnClockTimes() throws {
        let zone = "America/New_York"
        let times = ["2026-03-07", "2026-03-08", "2026-03-09"].map {
            ["\($0),fajr,05:30,,\(zone)", "\($0),dhuhr,12:00,,\(zone)", "\($0),asr,15:00,,\(zone)", "\($0),maghrib,18:00,,\(zone)", "\($0),isha,19:30,,\(zone)"].joined(separator: "\n")
        }
        let table = try #require(csv(times.joined(separator: "\n")).timetable(id: "ny", attribution: ""))
        #expect(table.days[0].starts[.fajr] == S.instant("2026-03-07T10:30:00Z"), "EST")
        #expect(table.days[1].starts[.fajr] == S.instant("2026-03-08T09:30:00Z"), "EDT, a day later by the calendar and 23 hours by the clock")
        #expect(table.days[2].starts[.fajr] == S.instant("2026-03-09T09:30:00Z"))
    }

    @Test func aFixedPatternNeedsAnExplicitBoundedRange() throws {
        func time(_ text: String) -> LocalTime { LocalTime(text: text)! }
        let starts: [PrayerID: LocalTime] = [.fajr: time("02:30"), .dhuhr: time("12:00"), .asr: time("15:00"), .maghrib: time("18:00"), .isha: time("19:30")]
        let pattern = FixedPattern(zoneID: "America/New_York", starts: starts, iqamah: [.dhuhr: time("12:15")])
        let plain = pattern.review(name: "Pattern", range: S.date("2026-03-10")...S.date("2026-03-12"))
        #expect(plain.canSave && plain.rows.count == 15)
        let table = try #require(plain.timetable(id: "pattern", attribution: ""))
        #expect(table.days.count == 3 && table.days[0].iqamah.keys.elementsEqual([.dhuhr]) && table.source.coverage == plain.coverage)

        let acrossDST = pattern.review(name: "Pattern", range: S.date("2026-03-07")...S.date("2026-03-09"))
        #expect(!acrossDST.canSave && acrossDST.errors.map(\.kind) == [.timeInGap("02:30")], "one date is impossible and it says so")

        let tooLong = pattern.review(name: "Pattern", range: S.date("2026-01-01")...S.date("2030-01-01"))
        #expect(!tooLong.canSave && tooLong.errors.first?.kind == .tooManyDays && tooLong.rows.isEmpty)

        let incomplete = FixedPattern(zoneID: "Asia/Tokyo", starts: [.fajr: time("05:00")]).review(name: "P", range: S.date("2026-11-02")...S.date("2026-11-02"))
        #expect(!incomplete.canSave && incomplete.missingRows.count == 4)
    }

    @Test func datedManualEntryUsesItsOwnRange() throws {
        func row(_ date: String, _ prayer: PrayerID, _ start: String) -> TimetableRow {
            TimetableRow(line: 0, date: S.date(date), slot: .prayer(prayer), start: LocalTime(text: start)!, iqamah: nil, zoneID: "Asia/Tokyo")
        }
        let rows = zip(PrayerID.allCases, ["05:00", "12:00", "15:00", "17:00", "19:00"]).map { row("2026-11-02", $0, $1) }
        let range = S.date("2026-11-02")...S.date("2026-11-03")
        let short = ImportReview(name: "M", rows: rows, range: range)
        #expect(!short.canSave && short.missingDates == [S.date("2026-11-03")], "the person asked for two days and gave one")
        let outside = ImportReview(name: "M", rows: rows, range: S.date("2026-11-03")...S.date("2026-11-03"))
        #expect(outside.errors.contains { $0.kind == .outsideRange })
    }

    @Test func anExpiredTimetableKeepsHistoryAndAnswersNothingNew() throws {
        let table = try #require(csv(day("2026-11-02"), day("2026-11-03")).timetable(id: "m", attribution: ""))
        #expect(try table.day(on: S.date("2026-11-03")).get().date == S.date("2026-11-03"))
        #expect(table.day(on: S.date("2026-11-04")) == .failure(.expired))
        #expect(table.day(on: S.date("2026-11-01")) == .failure(.noCoverage))
    }

    @Test func parsingTouchesNothing() throws {
        let folder = S.temporaryFolder()
        _ = CSVImport.parse(data: Data(CSVImport.template.utf8), name: "Template")
        #expect(!FileManager.default.fileExists(atPath: folder.path))
        let store = NoorStore(folder: folder)
        #expect(store.sources() == .absent, "cancelling an import leaves no source")
    }
}
