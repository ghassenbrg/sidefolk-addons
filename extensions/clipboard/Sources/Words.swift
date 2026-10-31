import Foundation
import SidefolkExtensionKit

/// How a copy reads in the palette, its preview, the page and answers.
@MainActor
enum Words {
    static func title(_ e: Entry) -> String {
        if e.secret { return "•••••••• (" + L("looks like a password or key") + ")" }
        switch e.kind {
        case .image: return L("Picture") + size(e)
        case .file:
            let names = (e.files ?? []).map { ($0 as NSString).lastPathComponent }
            return names.count <= 3 ? names.joined(separator: L(", "))
                : L("{names} and {count} more", ["names": names.prefix(2).joined(separator: L(", ")), "count": names.count - 2])
        default:
            let line = (e.text ?? "").split(whereSeparator: \.isNewline).first { !$0.trimmingCharacters(in: .whitespaces).isEmpty } ?? ""
            return line.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        }
    }

    static func size(_ e: Entry) -> String { e.width.map { w in e.height.map { " \(w) × \($0)" } ?? "" } ?? "" }

    /// "Safari · 5 min ago · 12 lines"
    static func detail(_ e: Entry, now: Date = Date()) -> String {
        var parts: [String] = []
        if let s = e.source { parts.append(s) }
        parts.append(ago(e.copied, now: now))
        if e.secret {
            parts.append(L("forgotten in {time}", ["time": left(e, now: now)]))
        } else if let text = e.text, e.kind != .file {
            let lines = text.split(whereSeparator: \.isNewline).count
            if lines > 1 { parts.append(L(one: "{count} line", other: "{count} lines", count: lines)) }
            else if text.count > 80 { parts.append(L(one: "{count} character", other: "{count} characters", count: text.count)) }
        }
        if e.times > 1 { parts.append(L("copied {count}×", ["count": e.times])) }
        return parts.joined(separator: " · ")
    }

    static func ago(_ date: Date, now: Date = Date()) -> String {
        let s = max(0, now.timeIntervalSince(date))
        if s < 60 { return L("just now") }
        if s < 3600 { return L("{time} ago", ["time": Format.duration(Double(Int(s / 60)) * 60, units: [.minutes])]) }
        if s < 86_400 && Calendar.current.isDate(date, inSameDayAs: now) {
            return L("{time} ago", ["time": Format.duration(Double(Int(s / 3600)) * 3600, units: [.hours])])
        }
        if let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now), Calendar.current.isDate(date, inSameDayAs: yesterday) {
            return L("yesterday")
        }
        return L(one: "{count} day ago", other: "{count} days ago", count: max(2, Int(s / 86_400)))
    }

    /// How long a masked secret stays: whole minutes, at least one.
    static func left(_ e: Entry, now: Date) -> String {
        Format.duration(Double(max(1, Int((History.secretLife - now.timeIntervalSince(e.copied)) / 60) + 1)) * 60, units: [.minutes])
    }

    /// The colour a copied colour shows as, when it is a hex one.
    static func swatch(_ e: Entry) -> String? {
        guard e.kind == .color, let t = e.text?.trimmingCharacters(in: .whitespacesAndNewlines) else { return nil }
        let hex = t.dropFirst()
        switch hex.count {
        case 6, 8: return "#" + hex.prefix(6).uppercased()
        case 3: return "#" + hex.map { "\($0)\($0)" }.joined().uppercased()
        default: return nil
        }
    }

    static func item(_ e: Entry, section: String? = nil, now: Date = Date()) -> PaletteItem {
        let kind = PaletteItem.Kind(rawValue: e.kind.rawValue) ?? .text
        var actions = ["alternate", "pin", "delete"]
        if e.rtfFile != nil || e.htmlFile != nil || e.kind == .link { actions.insert("plain", at: 0) }
        return PaletteItem(id: e.id, title: title(e), detail: detail(e, now: now), kind: kind, pinned: e.pinned, actions: actions,
                           image: e.thumb, color: swatch(e), section: section)
    }

    /// The palette's list: pins in a section of their own when there are any, where the person put them.
    static func list(_ found: [Entry], h: History, now: Date = Date()) -> [PaletteItem] {
        let shown = found.prefix(200)
        let sections = shown.contains(where: \.pinned) && shown.contains { !$0.pinned }
        return shown.map { item($0, section: sections ? ($0.pinned ? L("Pinned") : L("History")) : nil, now: now) }
    }

    /// "312 copies · ↩ pastes, ⌥↩ copies only"
    static func note(_ h: History) -> String {
        guard h.isKeeping() else { return status(h) }
        let keys = h.options.paste ? L("↩ pastes, ⌥↩ only copies") : L("↩ copies, ⌥↩ pastes")
        return L(one: "{count} copy", other: "{count} copies", count: h.entries.count) + " · " + keys + (h.options.plain ? " · " + L("without formatting") : "")
    }

    /// The picked copy in full: its text or picture, and where and when it came from.
    static func preview(_ e: Entry, now: Date = Date()) -> PalettePreview {
        var facts: [(String, String)] = []
        if let s = e.source { facts.append((L("From"), s)) }
        facts.append((L("Copied"), when(e.copied, now: now)))
        if e.times > 1 {
            facts.append((L("First copied"), when(e.firstCopied, now: now)))
            facts.append((L("Copies"), Format.integer(e.times)))
        }
        if e.secret {
            facts.append((L("Forgotten"), L("in {time}", ["time": left(e, now: now)])))
            return PalettePreview(title: title(e), facts: facts)
        }
        switch e.kind {
        case .image:
            facts.append((L("Size"), "\(size(e).trimmingCharacters(in: .whitespaces)) px" + (e.bytes.map { " · \(bytes($0))" } ?? "")))
            return PalettePreview(image: e.image, facts: facts)
        case .file:
            let files = e.files ?? []
            facts.append((L("Files"), Format.integer(files.count)))
            return PalettePreview(text: files.map(Paths.show).joined(separator: "\n"), image: e.thumb, facts: facts)
        default:
            let text = e.text ?? ""
            let lines = text.split(whereSeparator: \.isNewline).count
            facts.append((L("Length"), L(one: "{count} character", other: "{count} characters", count: text.count)
                + (lines > 1 ? " · " + L(one: "{count} line", other: "{count} lines", count: lines) : "")))
            if e.rtfFile != nil || e.htmlFile != nil { facts.append((L("Formatting"), L("kept (⇧↩ pastes without it)"))) }
            return PalettePreview(text: String(text.prefix(20_000)), code: e.kind == .code, facts: facts)
        }
    }

    static func when(_ date: Date, now: Date) -> String {
        Calendar.current.isDate(date, inSameDayAs: now) ? L("Today {time}", ["time": Format.time(date)]) : Format.dateTime(date)
    }

    static func bytes(_ n: Int) -> String { Format.bytes(Int64(n)) }

    /// One copy for the AI or a command's card: its text in full when short, else its start.
    static func line(_ e: Entry, index: Int, now: Date = Date()) -> String {
        let body: String
        switch e.kind {
        case .image, .file: body = title(e)
        default: body = e.secret ? title(e) : String((e.text ?? "").prefix(400))
        }
        return "\(index). \(body) (\(detail(e, now: now)))" + (e.pinned ? " [" + L("pinned") + "]" : "")
    }

    static func status(_ h: History, now: Date = Date()) -> String {
        if !h.options.keeping { return L("Not keeping a history") }
        if let until = h.options.pausedUntil, until > now { return L("Paused until {time}", ["time": Format.time(until)]) }
        return h.options.skipNext ? L("Skipping your next copy") : L("Keeping your copies")
    }
}
