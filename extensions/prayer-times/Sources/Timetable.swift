import Foundation

/// A manual or imported timetable once saved: its source and its explicit dated rows, nothing derived. An expired one
/// keeps its history and supplies nothing new.
struct ManualTimetable: Hashable, Sendable, Codable {
    let source: TimetableSource
    let days: [PrayerDay]

    func day(on date: CivilDate) -> Result<PrayerDay, UnavailableReason> {
        if let day = days.first(where: { $0.date == date }) { return .success(day) }
        if let coverage = source.coverage, date > coverage.upperBound { return .failure(.expired) }
        return .failure(.noCoverage)
    }

    /// The same dates and times, whatever each is called: choosing one file twice would otherwise make two identical sources.
    func sameTimes(as other: ManualTimetable) -> Bool {
        days.count == other.days.count && zip(days, other.days).allSatisfy { ($0.date, $0.zoneID, $0.starts, $0.iqamah, $0.friday) == ($1.date, $1.zoneID, $1.starts, $1.iqamah, $1.friday) }
    }
}

/// What a timetable row fills: one of the five prayers or a named Friday session like `friday-1`.
enum TimetableSlot: Hashable, Sendable {
    case prayer(PrayerID)
    case friday(String)

    init?(text: String) {
        let text = text.lowercased()
        if let prayer = PrayerID(rawValue: text) {
            self = .prayer(prayer)
        } else if text.wholeMatch(of: /friday-[1-9]/) != nil {
            self = .friday(text)
        } else {
            return nil
        }
    }
}

/// One row of a timetable, typed but not yet checked against the others. `line` is its place in the file; rows that didn't
/// come from a file use 0.
struct TimetableRow: Hashable, Sendable {
    let line: Int
    let date: CivilDate
    let slot: TimetableSlot
    let start: LocalTime
    let iqamah: LocalTime?
    let zoneID: String
}

struct ImportIssue: Error, Hashable, Sendable {
    enum Kind: Hashable, Sendable {
        case tooLarge, notText, emptyName, badHeader, noRows, tooManyRows, tooManyDays, wrongColumns
        case badDate(String), badPrayer(String), badStart(String), badIqamah(String), badZone(String), mixedZone(String)
        case outsideRange, notAFriday, iqamahBeforeStart, outOfOrder
        /// The clock skips this time on this date, or shows it twice. Reported, because a guess would be a wrong time.
        case timeInGap(String), timeInFold(String)
    }

    let line: Int
    let kind: Kind
}

/// Two rows for one slot: `line` is the later, `firstLine` the one it repeats or contradicts.
struct RowClash: Hashable, Sendable {
    let line: Int
    let firstLine: Int
    let date: CivilDate
    let slot: TimetableSlot
}

struct MissingRow: Hashable, Sendable {
    let date: CivilDate
    let prayer: PrayerID
}

/// A checked timetable, ready for the person to look over. Making one touches nothing, so cancelling leaves no source.
struct ImportReview: Hashable, Sendable {
    static let maximumDays = 400

    let name: String
    /// The rows that passed.
    let rows: [TimetableRow]
    let coverage: ClosedRange<CivilDate>?
    let zone: String?
    let duplicates: [RowClash]
    let conflicts: [RowClash]
    /// Dates inside the coverage with no rows at all.
    let missingDates: [CivilDate]
    /// Prayers left out of a date that has other rows.
    let missingRows: [MissingRow]
    let errors: [ImportIssue]

    var canSave: Bool {
        !rows.isEmpty && coverage != nil && zone != nil && duplicates.isEmpty && conflicts.isEmpty && missingDates.isEmpty && missingRows.isEmpty && errors.isEmpty
    }

    /// Checks rows against each other, for an import or for dated manual entry. With a `range`, it is the range the person
    /// asked for; without, the rows' own first and last dates. `earlier` carries problems from reading the rows.
    init(name: String, rows input: [TimetableRow], range: ClosedRange<CivilDate>? = nil, earlier: [ImportIssue] = []) {
        var errors = earlier
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { errors.append(ImportIssue(line: 0, kind: .emptyName)) }
        if input.isEmpty && earlier.isEmpty { errors.append(ImportIssue(line: 0, kind: .noRows)) }

        var accepted: [TimetableRow] = []
        var seen: [TimetableSlotKey: TimetableRow] = [:]
        var (duplicates, conflicts): ([RowClash], [RowClash]) = ([], [])
        var zoneID: String?
        for row in input {
            let key = TimetableSlotKey(date: row.date, slot: row.slot)
            if let first = seen[key] {
                let clash = RowClash(line: row.line, firstLine: first.line, date: row.date, slot: row.slot)
                if (first.start, first.iqamah, first.zoneID) == (row.start, row.iqamah, row.zoneID) { duplicates.append(clash) } else { conflicts.append(clash) }
                continue
            }
            seen[key] = row
            if let problem = Self.problem(with: row, zoneID: &zoneID, range: range) {
                errors.append(ImportIssue(line: row.line, kind: problem))
            } else {
                accepted.append(row)
            }
        }

        let dates = input.map(\.date)
        let coverage = range ?? dates.min().flatMap { low in dates.max().map { low...$0 } }
        var (missingDates, missingRows): ([CivilDate], [MissingRow]) = ([], [])
        if let coverage {
            if coverage.lowerBound.days(until: coverage.upperBound) >= Self.maximumDays {
                errors.append(ImportIssue(line: 0, kind: .tooManyDays))
            } else {
                var date = coverage.lowerBound
                while date <= coverage.upperBound {
                    let missing = PrayerID.allCases.filter { seen[TimetableSlotKey(date: date, slot: .prayer($0))] == nil }
                    if missing.count == PrayerID.allCases.count {
                        missingDates.append(date)
                    } else {
                        missingRows += missing.map { MissingRow(date: date, prayer: $0) }
                    }
                    date = date.next
                }
            }
        }
        errors += Self.orderProblems(accepted)

        self.name = name
        self.rows = accepted
        self.coverage = coverage
        self.zone = zoneID
        self.duplicates = duplicates
        self.conflicts = conflicts
        self.missingDates = missingDates
        self.missingRows = missingRows
        self.errors = errors.sorted { $0.line < $1.line }
    }

    private static func problem(with row: TimetableRow, zoneID: inout String?, range: ClosedRange<CivilDate>?) -> ImportIssue.Kind? {
        guard let zone = IANAZone.zone(row.zoneID) else { return .badZone(row.zoneID) }
        guard (zoneID ?? row.zoneID) == row.zoneID else { return .mixedZone(row.zoneID) }
        zoneID = row.zoneID
        if let range, !range.contains(row.date) { return .outsideRange }
        if case .friday = row.slot, row.date.weekday != 6 { return .notAFriday }
        if let iqamah = row.iqamah, iqamah < row.start { return .iqamahBeforeStart }
        for time in [row.start, row.iqamah].compactMap({ $0 }) {
            switch CivilClock.resolve(row.date, time, in: zone) {
            case .exact: continue
            case .gap: return .timeInGap(time.text)
            case .fold: return .timeInFold(time.text)
            }
        }
        return nil
    }

    /// Each row names its own date, so a start that runs backwards can't be one crossing midnight: it is a typing slip,
    /// or a time this schema can't say, and either way not one to guess about.
    private static func orderProblems(_ rows: [TimetableRow]) -> [ImportIssue] {
        var problems: [ImportIssue] = []
        for (_, dayRows) in Dictionary(grouping: rows, by: \.date) {
            var previous: LocalTime?
            for prayer in PrayerID.allCases {
                guard let row = dayRows.first(where: { $0.slot == .prayer(prayer) }) else { continue }
                if let previous, row.start < previous { problems.append(ImportIssue(line: row.line, kind: .outOfOrder)) }
                previous = row.start
            }
        }
        return problems
    }

    /// The source and days to save; nil until `canSave`. `revision` goes up when an import replaces an earlier one.
    func timetable(id: String, attribution: String, revision: Int = 1) -> ManualTimetable? {
        guard canSave, let coverage, let zone, let timeZone = IANAZone.zone(zone),
              let source = TimetableSource(id: id, kind: .manual, name: name, zoneID: zone, coverage: coverage, revision: revision, attribution: attribution) else { return nil }
        var days: [PrayerDay] = []
        for (date, dayRows) in Dictionary(grouping: rows, by: \.date).sorted(by: { $0.key < $1.key }) {
            var (starts, iqamah): ([PrayerID: Date], [PrayerID: Date]) = ([:], [:])
            var friday: [FridaySession] = []
            for row in dayRows {
                let start = CivilClock.resolve(date, row.start, in: timeZone).settled
                let rowIqamah = row.iqamah.map { CivilClock.resolve(date, $0, in: timeZone).settled }
                switch row.slot {
                case .prayer(let prayer):
                    starts[prayer] = start
                    iqamah[prayer] = rowIqamah
                case .friday(let name):
                    friday.append(FridaySession(id: name, start: start, iqamah: rowIqamah))
                }
            }
            guard let day = PrayerDay(date: date, zoneID: zone, sourceID: id, starts: starts, iqamah: iqamah, friday: friday.sorted { $0.id < $1.id }) else { return nil }
            days.append(day)
        }
        return ManualTimetable(source: source, days: days)
    }
}

private struct TimetableSlotKey: Hashable {
    let date: CivilDate
    let slot: TimetableSlot
}

/// A fixed daily pattern, only ever over an explicit range: it runs through the same checks as a file, so a time that DST
/// makes impossible on one date is reported for that date.
struct FixedPattern: Hashable, Sendable {
    let zoneID: String
    let starts: [PrayerID: LocalTime]
    let iqamah: [PrayerID: LocalTime]

    init(zoneID: String, starts: [PrayerID: LocalTime], iqamah: [PrayerID: LocalTime] = [:]) {
        (self.zoneID, self.starts, self.iqamah) = (zoneID, starts, iqamah)
    }

    func review(name: String, range: ClosedRange<CivilDate>) -> ImportReview {
        guard range.lowerBound.days(until: range.upperBound) < ImportReview.maximumDays else {
            return ImportReview(name: name, rows: [], range: range, earlier: [ImportIssue(line: 0, kind: .tooManyDays)])
        }
        var rows: [TimetableRow] = []
        var date = range.lowerBound
        while date <= range.upperBound {
            for prayer in PrayerID.allCases {
                guard let start = starts[prayer] else { continue }
                rows.append(TimetableRow(line: 0, date: date, slot: .prayer(prayer), start: start, iqamah: iqamah[prayer], zoneID: zoneID))
            }
            date = date.next
        }
        return ImportReview(name: name, rows: rows, range: range)
    }
}
