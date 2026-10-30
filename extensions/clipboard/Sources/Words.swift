import Foundation
import SidefolkExtensionKit

/// How a copy reads in the palette, on the page and in answers.
@MainActor
enum Words {
    static func title(_ e: Entry) -> String {
        if e.secret { return "•••••••• (looks like a password or key)" }
        switch e.kind {
        case .image: return "Picture" + (e.width.map { w in e.height.map { " \(w) × \($0)" } ?? "" } ?? "")
        case .file:
            let names = (e.files ?? []).map { ($0 as NSString).lastPathComponent }
            return names.count <= 3 ? names.joined(separator: ", ") : "\(names.prefix(2).joined(separator: ", ")) and \(names.count - 2) more"
        default:
            let line = (e.text ?? "").split(whereSeparator: \.isNewline).first { !$0.trimmingCharacters(in: .whitespaces).isEmpty } ?? ""
            return line.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        }
    }

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
        if s < 86_400 { return "\(Int(s / 3600)) h ago" }
        let days = Int(s / 86_400)
        return days == 1 ? "yesterday" : "\(days) days ago"
    }

    static func item(_ e: Entry, now: Date = Date()) -> PaletteItem {
        let kind = PaletteItem.Kind(rawValue: e.kind.rawValue) ?? .text
        var actions = ["pin", "delete"]
        if e.rtf != nil || e.kind == .link { actions.append("plain") }
        return PaletteItem(id: e.id, title: title(e), detail: detail(e, now: now), kind: kind, pinned: e.pinned, actions: actions)
    }

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
        return "Keeping your copies"
    }
}

/// The Clipboard page: the history's state with its switches, what it holds, where copies come from, the latest ones.
@MainActor
enum ClipboardPage {
    static func make(_ h: History, now: Date = Date()) -> Page {
        let today = h.entries.filter { Calendar.current.isDate($0.copied, inSameDayAs: now) }.count
        let keeping = h.isKeeping(now: now)
        let summary = Summary(Words.status(h, now: now), detail: "\(h.entries.count) kept · \(today) today · open them from any app with the shortcut below",
                              tone: keeping ? .good : .warn, symbol: keeping ? "doc.on.clipboard.fill" : "pause.circle.fill")
        var controls: [Block] = [
            .toggle("Keep a history of what I copy", detail: "Passwords from password managers are never kept.", on: h.options.keeping,
                    tool: "set_option", input: ["option": "keeping"]),
            .toggle("Hide passwords, keys and card numbers", detail: "They show as dots and are forgotten after two minutes.",
                    on: h.options.hideSecrets, tool: "set_option", input: ["option": "hide_secrets"]),
        ]
        if keeping {
            controls.append(.button("Pause 10 minutes", tool: "pause", input: ["minutes": 10], symbol: "pause"))
        } else if h.options.pausedUntil != nil {
            controls.append(.button("Resume now", tool: "resume", style: .primary, symbol: "play"))
        }
        controls.append(.button("Clear history", tool: "clear_history", input: ["keep_pinned": true], style: .destructive, symbol: "trash"))

        let kinds = Dictionary(grouping: h.entries, by: \.kind)
        var sections = [Section(nil, controls)]
        sections.append(Section("What it holds", [
            .stat("Copies", "\(h.entries.count)", caption: "\(today) today"),
            .stat("Pinned", "\(h.entries.filter(\.pinned).count)", caption: "kept for good"),
            .stat("Links", "\(kinds[.link]?.count ?? 0)"),
            .stat("Pictures", "\(kinds[.image]?.count ?? 0)"),
            .stat("Code", "\(kinds[.code]?.count ?? 0)"),
            .stat("Files", "\(kinds[.file]?.count ?? 0)"),
        ]))
        let apps = Dictionary(grouping: h.entries.compactMap(\.source), by: { $0 }).mapValues(\.count).sorted { $0.value > $1.value }.prefix(6)
        if let top = apps.first?.value {
            sections.append(Section("Where your copies come from", [
                .bars("Apps", caption: "The app in front when you copied.",
                      apps.map { Bar($0.key, "\($0.value)", fraction: Double($0.value) / Double(top)) }),
            ]))
        }
        let recent = h.entries.prefix(8).map { (Words.title($0), Words.detail($0, now: now)) }
        if !recent.isEmpty { sections.append(Section("Latest", [.facts(nil, Array(recent))])) }
        sections.append(Section("Ask about it", [
            .ask("What did I copy today?", "What did I copy today?"),
            .ask("Find a link I copied", "Find the last link I copied"),
            .ask("Save my last copy to notes", "Save the last thing I copied to my notes"),
        ]))
        return Page(summary: summary, sections: sections)
    }
}
