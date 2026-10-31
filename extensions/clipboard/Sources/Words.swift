import Foundation
import SidefolkExtensionKit

/// How a copy reads in the palette, its preview, the page and answers.
@MainActor
enum Words {
    static func title(_ e: Entry) -> String {
        if e.secret { return "•••••••• (looks like a password or key)" }
        switch e.kind {
        case .image: return "Picture" + size(e)
        case .file:
            let names = (e.files ?? []).map { ($0 as NSString).lastPathComponent }
            return names.count <= 3 ? names.joined(separator: ", ") : "\(names.prefix(2).joined(separator: ", ")) and \(names.count - 2) more"
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
            parts.append("forgotten in \(max(1, Int((History.secretLife - now.timeIntervalSince(e.copied)) / 60) + 1)) min")
        } else if let text = e.text, e.kind != .file {
            let lines = text.split(whereSeparator: \.isNewline).count
            if lines > 1 { parts.append("\(lines) lines") } else if text.count > 80 { parts.append("\(text.count) characters") }
        }
        if e.times > 1 { parts.append("copied \(e.times)×") }
        return parts.joined(separator: " · ")
    }

    static func ago(_ date: Date, now: Date = Date()) -> String {
        let s = max(0, now.timeIntervalSince(date))
        if s < 60 { return "just now" }
        if s < 3600 { return "\(Int(s / 60)) min ago" }
        if s < 86_400 && Calendar.current.isDate(date, inSameDayAs: now) { return "\(Int(s / 3600)) h ago" }
        if let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now), Calendar.current.isDate(date, inSameDayAs: yesterday) {
            return "yesterday"
        }
        return "\(max(2, Int(s / 86_400))) days ago"
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
        return shown.map { item($0, section: sections ? ($0.pinned ? "Pinned" : "History") : nil, now: now) }
    }

    /// "312 copies · ↩ pastes, ⌥↩ copies only"
    static func note(_ h: History) -> String {
        guard h.isKeeping() else { return status(h) }
        let keys = h.options.paste ? "↩ pastes, ⌥↩ only copies" : "↩ copies, ⌥↩ pastes"
        return "\(h.entries.count) \(h.entries.count == 1 ? "copy" : "copies") · \(keys)" + (h.options.plain ? " · without formatting" : "")
    }

    /// The picked copy in full: its text or picture, and where and when it came from.
    static func preview(_ e: Entry, now: Date = Date()) -> PalettePreview {
        var facts: [(String, String)] = []
        if let s = e.source { facts.append(("From", s)) }
        facts.append(("Copied", when(e.copied, now: now)))
        if e.times > 1 {
            facts.append(("First copied", when(e.firstCopied, now: now)))
            facts.append(("Copies", "\(e.times)"))
        }
        if e.secret {
            facts.append(("Forgotten", "in \(max(1, Int((History.secretLife - now.timeIntervalSince(e.copied)) / 60) + 1)) min"))
            return PalettePreview(title: title(e), facts: facts)
        }
        switch e.kind {
        case .image:
            facts.append(("Size", "\(size(e).trimmingCharacters(in: .whitespaces)) px" + (e.bytes.map { " · \(bytes($0))" } ?? "")))
            return PalettePreview(image: e.image, facts: facts)
        case .file:
            let files = e.files ?? []
            facts.append(("Files", "\(files.count)"))
            return PalettePreview(text: files.map(Paths.show).joined(separator: "\n"), image: e.thumb, facts: facts)
        default:
            let text = e.text ?? ""
            let lines = text.split(whereSeparator: \.isNewline).count
            facts.append(("Length", "\(text.count) characters" + (lines > 1 ? " · \(lines) lines" : "")))
            if e.rtfFile != nil || e.htmlFile != nil { facts.append(("Formatting", "kept (⇧↩ pastes without it)")) }
            return PalettePreview(text: String(text.prefix(20_000)), code: e.kind == .code, facts: facts)
        }
    }

    static func when(_ date: Date, now: Date) -> String {
        Calendar.current.isDate(date, inSameDayAs: now) ? "Today \(date.formatted(date: .omitted, time: .shortened))"
            : date.formatted(date: .abbreviated, time: .shortened)
    }

    static func bytes(_ n: Int) -> String { ByteCountFormatter.string(fromByteCount: Int64(n), countStyle: .file) }

    /// One copy for the AI or a command's card: its text in full when short, else its start.
    static func line(_ e: Entry, index: Int, now: Date = Date()) -> String {
        let body: String
        switch e.kind {
        case .image, .file: body = title(e)
        default: body = e.secret ? title(e) : String((e.text ?? "").prefix(400))
        }
        return "\(index). \(body) (\(detail(e, now: now)))\(e.pinned ? " [pinned]" : "")"
    }

    static func status(_ h: History, now: Date = Date()) -> String {
        if !h.options.keeping { return "Not keeping a history" }
        if let until = h.options.pausedUntil, until > now {
            return "Paused until \(until.formatted(date: .omitted, time: .shortened))"
        }
        return h.options.skipNext ? "Skipping your next copy" : "Keeping your copies"
    }
}
