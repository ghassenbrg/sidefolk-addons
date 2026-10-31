import Foundation
import SidefolkExtensionKit

/// The Clipboard page: the history's state and its switches, the latest copies with their pictures, then the
/// settings Maccy has in its window (pasting, how much to keep and in what order, what to leave out), and what it holds.
@MainActor
enum ClipboardPage {
    static func make(_ h: History, now: Date = Date()) -> Page {
        let today = h.entries.filter { Calendar.current.isDate($0.copied, inSameDayAs: now) }.count
        let keeping = h.isKeeping(now: now)
        let summary = Summary(Words.status(h, now: now), detail: "\(h.entries.count) kept · \(today) today · open them from any app with the shortcut below",
                              tone: keeping ? .good : .warn, symbol: keeping ? "doc.on.clipboard.fill" : "pause.circle.fill")
        return Page(summary: summary, sections: [controls(h, keeping: keeping), latest(h, now: now), pasting(h), keepingSection(h), ignoring(h),
                                                 holds(h, today: today), apps(h), ask].compactMap { $0 })
    }

    static func controls(_ h: History, keeping: Bool) -> Section {
        var blocks: [Block] = [
            .toggle("Keep a history of what I copy", detail: "Passwords from password managers are never kept.", on: h.options.keeping,
                    tool: "set_option", input: ["option": "keeping"]),
            .toggle("Hide passwords, keys and card numbers", detail: "They show as dots, stay in memory only and are forgotten after two minutes.",
                    on: h.options.hideSecrets, tool: "set_option", input: ["option": "hide_secrets"]),
        ]
        if keeping {
            blocks.append(.button("Pause 10 minutes", tool: "pause", input: ["minutes": 10], symbol: "pause"))
            if !h.options.skipNext { blocks.append(.button("Skip my next copy", tool: "skip_next", symbol: "forward")) }
        } else if h.options.pausedUntil != nil {
            blocks.append(.button("Resume now", tool: "resume", style: .primary, symbol: "play"))
        }
        blocks.append(.button("Clear history", tool: "clear_history", input: ["keep_pinned": true], style: .destructive, symbol: "trash"))
        if h.entries.contains(where: \.pinned) {
            blocks.append(.button("Clear pinned too", tool: "clear_history", input: ["keep_pinned": false], style: .destructive, symbol: "trash.slash"))
        }
        return Section(nil, blocks)
    }

    /// The latest copies as they look in the palette, each to copy again from here.
    static func latest(_ h: History, now: Date) -> Section? {
        let rows = h.ordered().prefix(10).map { e in
            Row(Words.title(e), detail: Words.detail(e, now: now), image: e.thumb, color: Words.swatch(e), symbol: symbol(e),
                button: (label: "Copy", tool: "copy_again", input: ["id": e.id], symbol: "doc.on.doc"))
        }
        guard !rows.isEmpty else { return nil }
        return Section("Latest", [.list(nil, caption: "In the order the palette shows them. Copy puts one back on the clipboard.", Array(rows))])
    }

    static func symbol(_ e: Entry) -> String {
        if e.pinned { return "pin.fill" }
        switch e.kind {
        case .text: return "text.alignleft"
        case .link: return "link"
        case .image: return "photo"
        case .file: return "doc"
        case .color: return "paintpalette"
        case .code: return "chevron.left.forwardslash.chevron.right"
        }
    }

    static func pasting(_ h: History) -> Section {
        Section("Choosing a copy", [
            .choice("Return", detail: "What choosing a copy does. Option-Return does the other; Shift-Return pastes plain text.",
                    options: [("paste", "Pastes it"), ("copy", "Only copies it")], selected: h.options.paste ? "paste" : "copy",
                    tool: "set_option", input: ["option": "paste"]),
            .choice("Formatting", detail: "Fonts, colours and links that came with copied text.",
                    options: [("keep", "Keep it"), ("remove", "Remove it")], selected: h.options.plain ? "remove" : "keep",
                    tool: "set_option", input: ["option": "plain"]),
        ])
    }

    static func keepingSection(_ h: History) -> Section {
        Section("History", [
            .choice("Keep up to", detail: "Copies, pinned ones aside. The oldest go first.",
                    options: Options.limits.map { ("\($0)", "\($0.formatted()) copies") }, selected: "\(h.options.limit)",
                    tool: "set_option", input: ["option": "limit"]),
            .choice("Order", options: [("recent", "Last copied"), ("first", "First copied"), ("count", "Most copied")],
                    selected: h.options.sort.rawValue, tool: "set_option", input: ["option": "sort"]),
            .choice("Pinned copies", options: [("top", "On top"), ("bottom", "At the bottom")], selected: h.options.pins.rawValue,
                    tool: "set_option", input: ["option": "pins"]),
            .choice("Search", detail: "Words: all of them, anywhere. Fuzzy: the letters in order. Pattern: a regular expression.",
                    options: [("words", "Words"), ("exact", "Exact"), ("fuzzy", "Fuzzy"), ("regex", "Pattern")],
                    selected: h.options.search.rawValue, tool: "set_option", input: ["option": "search"]),
            .toggle("Keep pictures", detail: "Screenshots and copied images, \(History.maxImages) at most.", on: h.options.keepImages,
                    tool: "set_option", input: ["option": "keep_images"]),
            .toggle("Keep files", detail: "Files copied in Finder, by their place.", on: h.options.keepFiles,
                    tool: "set_option", input: ["option": "keep_files"]),
            .toggle("Keep formatting", detail: "Rich text and web formatting, pasted back unless you ask for plain text.", on: h.options.keepFormatting,
                    tool: "set_option", input: ["option": "keep_formatting"]),
        ])
    }

    /// What to leave out: the apps copies came from as switches, and the person's own apps, patterns and types.
    static func ignoring(_ h: History) -> Section {
        var seen: [(app: String, name: String)] = []
        for e in h.entries {
            guard let app = e.app ?? e.source, !seen.contains(where: { $0.app == app }) else { continue }
            seen.append((app, e.source ?? app))
            if seen.count == 6 { break }
        }
        var blocks: [Block] = seen.map { s in
            .toggle("Ignore \(s.name)", detail: s.app == s.name ? nil : s.app, on: h.options.ignores(app: s.app, name: s.name),
                    tool: "ignore", input: ["app": s.app])
        }
        let others = h.options.ignoredApps.filter { app in !seen.contains { $0.app.lowercased() == app.lowercased() || $0.name.lowercased() == app.lowercased() } }
        let rules = others.map { Row($0, detail: "App", symbol: "app.dashed", button: (label: "Remove", tool: "ignore", input: ["app": $0, "on": false], symbol: nil)) }
            + h.options.ignoredPatterns.map { Row($0, detail: "Text matching", symbol: "textformat", button: (label: "Remove", tool: "ignore",
                                                                                                         input: ["pattern": $0, "on": false], symbol: nil)) }
            + h.options.ignoredTypes.map { Row($0, detail: "Clipboard type", symbol: "tag", button: (label: "Remove", tool: "ignore",
                                                                                                input: ["type": $0, "on": false], symbol: nil)) }
        if !rules.isEmpty { blocks.append(.list("Also left out", rules)) }
        blocks += [
            .field("Ignore an app", detail: "Its name or bundle id, like 1Password or com.apple.keychainaccess.", placeholder: "App name or bundle id",
                   button: "Ignore", tool: "ignore", key: "app"),
            .field("Ignore text that matches", detail: "A regular expression: ^\\d{6}$ leaves out six-digit codes.", placeholder: "Pattern",
                   button: "Ignore", tool: "ignore", key: "pattern"),
            .field("Ignore a clipboard type", detail: "For apps that mark what they copy: com.apple.is-remote-clipboard leaves out your iPhone's copies.",
                   placeholder: "Type", button: "Ignore", tool: "ignore", key: "type"),
        ]
        return Section("Leave out", blocks)
    }

    static func holds(_ h: History, today: Int) -> Section {
        let kinds = Dictionary(grouping: h.entries, by: \.kind)
        let bytes = h.entries.compactMap(\.bytes).reduce(0, +)
        return Section("What it holds", [
            .stat("Copies", "\(h.entries.count)", caption: "\(today) today"),
            .stat("Pinned", "\(h.entries.filter(\.pinned).count)", caption: "kept for good"),
            .stat("Pictures", "\(kinds[.image]?.count ?? 0)", caption: Words.bytes(bytes)),
            .stat("Links", "\(kinds[.link]?.count ?? 0)"),
            .stat("Code", "\(kinds[.code]?.count ?? 0)"),
            .stat("Files", "\(kinds[.file]?.count ?? 0)"),
        ])
    }

    static func apps(_ h: History) -> Section? {
        let apps = Dictionary(grouping: h.entries.compactMap(\.source), by: { $0 }).mapValues(\.count).sorted { $0.value > $1.value }.prefix(6)
        guard let top = apps.first?.value else { return nil }
        return Section("Where your copies come from", [
            .bars("Apps", caption: "The app in front when you copied.", apps.map { Bar($0.key, "\($0.value)", fraction: Double($0.value) / Double(top)) }),
        ])
    }

    static let ask = Section("Ask about it", [
        .ask("What did I copy today?", "What did I copy today?"),
        .ask("Find a link I copied", "Find the last link I copied"),
        .ask("Save my last copy to notes", "Save the last thing I copied to my notes"),
    ])
}
