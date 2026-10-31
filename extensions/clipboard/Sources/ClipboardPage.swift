import Foundation
import SidefolkExtensionKit

/// The Clipboard page: the history's state and its switches, the latest copies with their pictures, then the
/// settings Maccy has in its window (pasting, how much to keep and in what order, what to leave out), and what it holds.
@MainActor
enum ClipboardPage {
    static func make(_ h: History, now: Date = Date()) -> Page {
        let today = h.entries.filter { Calendar.current.isDate($0.copied, inSameDayAs: now) }.count
        let keeping = h.isKeeping(now: now)
        let detail = L("{kept} kept · {today} today · open them from any app with the shortcut below", ["kept": h.entries.count, "today": today])
        let summary = Summary(Words.status(h, now: now), detail: detail,
                              tone: keeping ? .good : .warn, symbol: keeping ? "doc.on.clipboard.fill" : "pause.circle.fill")
        return Page(summary: summary, sections: [controls(h, keeping: keeping), latest(h, now: now), pasting(h), keepingSection(h), ignoring(h),
                                                 holds(h, today: today), apps(h), ask].compactMap { $0 })
    }

    static func controls(_ h: History, keeping: Bool) -> Section {
        var blocks: [Block] = [
            .toggle(L("Keep a history of what I copy"), detail: L("Passwords from password managers are never kept."), on: h.options.keeping,
                    tool: "set_option", input: ["option": "keeping"]),
            .toggle(L("Hide passwords, keys and card numbers"), detail: L("They show as dots, stay in memory only and are forgotten after two minutes."),
                    on: h.options.hideSecrets, tool: "set_option", input: ["option": "hide_secrets"]),
        ]
        if keeping {
            blocks.append(.button(L("Pause {time}", ["time": Format.duration(600, units: [.minutes], width: .wide)]), tool: "pause", input: ["minutes": 10], symbol: "pause"))
            if !h.options.skipNext { blocks.append(.button(L("Skip my next copy"), tool: "skip_next", symbol: "forward")) }
        } else if h.options.pausedUntil != nil {
            blocks.append(.button(L("Resume now"), tool: "resume", style: .primary, symbol: "play"))
        }
        blocks.append(.button(L("Clear history"), tool: "clear_history", input: ["keep_pinned": true], style: .destructive, symbol: "trash"))
        if h.entries.contains(where: \.pinned) {
            blocks.append(.button(L("Clear pinned too"), tool: "clear_history", input: ["keep_pinned": false], style: .destructive, symbol: "trash.slash"))
        }
        return Section(nil, blocks)
    }

    /// The latest copies as they look in the palette, each to copy again from here.
    static func latest(_ h: History, now: Date) -> Section? {
        let rows = h.ordered().prefix(10).map { e in
            Row(Words.title(e), detail: Words.detail(e, now: now), image: e.thumb, color: Words.swatch(e), symbol: symbol(e),
                button: (label: L("Copy"), tool: "copy_again", input: ["id": e.id], symbol: "doc.on.doc"))
        }
        guard !rows.isEmpty else { return nil }
        return Section(L("Latest"), [.list(nil, caption: L("In the order the palette shows them. Copy puts one back on the clipboard."), Array(rows))])
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
        Section(L("Choosing a copy"), [
            .choice(L("Return"), detail: L("What choosing a copy does. Option-Return does the other; Shift-Return pastes plain text."),
                    options: [("paste", L("Pastes it")), ("copy", L("Only copies it"))], selected: h.options.paste ? "paste" : "copy",
                    tool: "set_option", input: ["option": "paste"]),
            .choice(L("Formatting"), detail: L("Fonts, colours and links that came with copied text."),
                    options: [("keep", L("Keep it")), ("remove", L("Remove it"))], selected: h.options.plain ? "remove" : "keep",
                    tool: "set_option", input: ["option": "plain"]),
        ])
    }

    static func keepingSection(_ h: History) -> Section {
        Section(L("History"), [
            .choice(L("Keep up to"), detail: L("Copies, pinned ones aside. The oldest go first."),
                    options: Options.limits.map { ("\($0)", L(one: "{count} copy", other: "{count} copies", count: $0)) }, selected: "\(h.options.limit)",
                    tool: "set_option", input: ["option": "limit"]),
            .choice(L("Order"), options: [("recent", L("Last copied")), ("first", L("First copied")), ("count", L("Most copied"))],
                    selected: h.options.sort.rawValue, tool: "set_option", input: ["option": "sort"]),
            .choice(L("Pinned copies"), options: [("top", L("On top")), ("bottom", L("At the bottom"))], selected: h.options.pins.rawValue,
                    tool: "set_option", input: ["option": "pins"]),
            .choice(L("Search"), detail: L("Words: all of them, anywhere. Fuzzy: the letters in order. Pattern: a regular expression."),
                    options: [("words", L("Words")), ("exact", L("Exact")), ("fuzzy", L("Fuzzy")), ("regex", L("Pattern"))],
                    selected: h.options.search.rawValue, tool: "set_option", input: ["option": "search"]),
            .toggle(L("Keep pictures"), detail: L("Screenshots and copied images, {count} at most.", ["count": History.maxImages]), on: h.options.keepImages,
                    tool: "set_option", input: ["option": "keep_images"]),
            .toggle(L("Keep files"), detail: L("Files copied in Finder, by their place."), on: h.options.keepFiles,
                    tool: "set_option", input: ["option": "keep_files"]),
            .toggle(L("Keep formatting"), detail: L("Rich text and web formatting, pasted back unless you ask for plain text."), on: h.options.keepFormatting,
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
            .toggle(L("Ignore {app}", ["app": s.name]), detail: s.app == s.name ? nil : s.app, on: h.options.ignores(app: s.app, name: s.name),
                    tool: "ignore", input: ["app": s.app])
        }
        let others = h.options.ignoredApps.filter { app in !seen.contains { $0.app.lowercased() == app.lowercased() || $0.name.lowercased() == app.lowercased() } }
        let remove = L("Remove")
        let rules = others.map { Row($0, detail: L("App"), symbol: "app.dashed", button: (label: remove, tool: "ignore", input: ["app": $0, "on": false], symbol: nil)) }
            + h.options.ignoredPatterns.map { Row($0, detail: L("Text matching"), symbol: "textformat", button: (label: remove, tool: "ignore",
                                                                                                            input: ["pattern": $0, "on": false], symbol: nil)) }
            + h.options.ignoredTypes.map { Row($0, detail: L("Clipboard type"), symbol: "tag", button: (label: remove, tool: "ignore",
                                                                                                   input: ["type": $0, "on": false], symbol: nil)) }
        if !rules.isEmpty { blocks.append(.list(L("Also left out"), rules)) }
        blocks += [
            .field(L("Ignore an app"), detail: L("Its name or bundle id, like 1Password or com.apple.keychainaccess."), placeholder: L("App name or bundle id"),
                   button: L("Ignore"), tool: "ignore", key: "app"),
            // The example is written out here: a key with braces in it would read as a placeholder.
            .field(L("Ignore text that matches"), detail: L("A regular expression: {example} leaves out six-digit codes.", ["example": "^\\d{6}$"]),
                   placeholder: L("Pattern"), button: L("Ignore"), tool: "ignore", key: "pattern"),
            .field(L("Ignore a clipboard type"), detail: L("For apps that mark what they copy: com.apple.is-remote-clipboard leaves out your iPhone's copies."),
                   placeholder: L("Type"), button: L("Ignore"), tool: "ignore", key: "type"),
        ]
        return Section(L("Leave out"), blocks)
    }

    static func holds(_ h: History, today: Int) -> Section {
        let kinds = Dictionary(grouping: h.entries, by: \.kind)
        let bytes = h.entries.compactMap(\.bytes).reduce(0, +)
        return Section(L("What it holds"), [
            .stat(L("Copies"), Format.integer(h.entries.count), caption: L("{count} today", ["count": today])),
            .stat(L("Pinned"), Format.integer(h.entries.filter(\.pinned).count), caption: L("kept for good")),
            .stat(L("Pictures"), Format.integer(kinds[.image]?.count ?? 0), caption: Words.bytes(bytes)),
            .stat(L("Links"), Format.integer(kinds[.link]?.count ?? 0)),
            .stat(L("Code"), Format.integer(kinds[.code]?.count ?? 0)),
            .stat(L("Files"), Format.integer(kinds[.file]?.count ?? 0)),
        ])
    }

    static func apps(_ h: History) -> Section? {
        let apps = Dictionary(grouping: h.entries.compactMap(\.source), by: { $0 }).mapValues(\.count).sorted { $0.value > $1.value }.prefix(6)
        guard let top = apps.first?.value else { return nil }
        return Section(L("Where your copies come from"), [
            .bars(L("Apps"), caption: L("The app in front when you copied."), apps.map { Bar($0.key, Format.integer($0.value), fraction: Double($0.value) / Double(top)) }),
        ])
    }

    /// What is asked stays English: Sidefolk understands typed requests in English (its GLOSSARY, rule 1).
    static var ask: Section {
        Section(L("Ask about it"), [
            .ask(L("What did I copy today?"), "What did I copy today?"),
            .ask(L("Find a link I copied"), "Find the last link I copied"),
            .ask(L("Save my last copy to notes"), "Save the last thing I copied to my notes"),
        ])
    }
}
