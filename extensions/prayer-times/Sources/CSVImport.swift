import Foundation

/// The app's own timetable file: `date,prayer,start,iqamah,timezone`, ISO civil dates, stable prayer ids, 24-hour times, one
/// zone per file. It is read as data only; no column names a command, and nothing is fetched from it.
enum CSVImport {
    static let maximumBytes = 1_000_000
    static let maximumRows = 5_000
    static let header = "date,prayer,start,iqamah,timezone"

    /// Leave iqamah empty where the mosque gives none. 1 January 2027 is a Friday, so it can show a named session too.
    static let template = """
        \(header)
        2027-01-01,fajr,05:30,05:50,Asia/Tokyo
        2027-01-01,dhuhr,11:50,,Asia/Tokyo
        2027-01-01,friday-1,12:30,12:45,Asia/Tokyo
        2027-01-01,asr,14:20,14:30,Asia/Tokyo
        2027-01-01,maghrib,16:50,16:55,Asia/Tokyo
        2027-01-01,isha,18:20,18:40,Asia/Tokyo

        """

    static func parse(data: Data, name: String) -> ImportReview {
        func refused(_ kind: ImportIssue.Kind) -> ImportReview {
            ImportReview(name: name, rows: [], earlier: [ImportIssue(line: 0, kind: kind)])
        }
        guard data.count <= maximumBytes else { return refused(.tooLarge) }
        guard var text = String(data: data, encoding: .utf8) else { return refused(.notText) }
        if text.hasPrefix("\u{FEFF}") { text.removeFirst() }

        let lines = text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).enumerated().map { (number: $0.offset + 1, text: $0.element.trimmingCharacters(in: .whitespaces)) }
        let filled = lines.filter { !$0.text.isEmpty }
        guard let first = filled.first, first.text.lowercased().filter({ !$0.isWhitespace }) == header else {
            return ImportReview(name: name, rows: [], earlier: [ImportIssue(line: filled.first?.number ?? 0, kind: .badHeader)])
        }
        guard filled.count - 1 <= maximumRows else { return refused(.tooManyRows) }

        var rows: [TimetableRow] = []
        var issues: [ImportIssue] = []
        for line in filled.dropFirst() {
            switch row(line.text, number: line.number) {
            case .success(let row): rows.append(row)
            case .failure(let issue): issues.append(issue)
            }
        }
        return ImportReview(name: name, rows: rows, earlier: issues)
    }

    private static func row(_ text: String, number: Int) -> Result<TimetableRow, ImportIssue> {
        func issue(_ kind: ImportIssue.Kind) -> Result<TimetableRow, ImportIssue> { .failure(ImportIssue(line: number, kind: kind)) }
        let fields = text.split(separator: ",", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
        guard fields.count == 5 else { return issue(.wrongColumns) }
        guard let date = CivilDate(iso: fields[0]) else { return issue(.badDate(fields[0])) }
        guard let slot = TimetableSlot(text: fields[1]) else { return issue(.badPrayer(fields[1])) }
        guard let start = LocalTime(text: fields[2]) else { return issue(.badStart(fields[2])) }
        var iqamah: LocalTime?
        if !fields[3].isEmpty {
            guard let parsed = LocalTime(text: fields[3]) else { return issue(.badIqamah(fields[3])) }
            iqamah = parsed
        }
        return .success(TimetableRow(line: number, date: date, slot: slot, start: start, iqamah: iqamah, zoneID: fields[4]))
    }
}
