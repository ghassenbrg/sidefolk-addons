import Foundation
import SidefolkExtensionKit

/// The Clipboard page: what's being captured across the top, then the copies to search on one side and the one picked, whole, on the other. Choosing here never pastes: Copy
/// puts it back on the clipboard. Everything about how it keeps and leaves out copies is its "History & privacy" place, behind Back. All of it reads the palette's own history.
@MainActor
enum ClipboardPage {
    static var dress: PageDress {
        PageDress(ground: PagePair(light: "#F5F7FB", dark: "#161A22"), card: PagePair(light: "#FFFFFF", dark: "#1F242E"), line: PagePair(light: "#E1E5EE", dark: "#333A48"),
                                 accent: PagePair(light: "#2F66DD", dark: "#7F9CFF"), selected: PagePair(light: "#2F66DD", dark: "#7F9CFF"), well: PagePair(light: "#EEF1F8", dark: "#2A303C"))
    }
    /// More than this is what the palette and search are for.
    static let shownRows = 100

    /// Where the page is (Sidefolk D105): what is searched, All or Pinned, the copy picked, and whether the settings are showing.
    struct Place {
        var query = ""
        var pinned = false
        var picked: String?
        var settings = false

        init(query: String = "", pinned: Bool = false, picked: String? = nil, settings: Bool = false) {
            self.query = query
            self.pinned = pinned
            self.picked = picked
            self.settings = settings
        }

        init(_ state: Arguments) {
            self.init(query: state.string("q") ?? "", pinned: state.string("filter") == "pinned", picked: state.string("picked"), settings: state.string("place") == "settings")
        }
    }

    static func make(_ h: History, place: Place = Place(), now: Date = Date()) -> Page {
        let today = h.entries.filter { Calendar.current.isDate($0.copied, inSameDayAs: now) }.count
        let keeping = h.isKeeping(now: now)
        let detail = L("{kept} kept · {today} today · open them from any app with the shortcut below", ["kept": h.entries.count, "today": today])
        let summary = Summary(Words.status(h, now: now), detail: detail, tone: keeping ? .good : .warn, symbol: keeping ? "doc.on.clipboard.fill" : "pause.circle.fill")
        if place.settings {
            return Page(summary: summary, sections: [settingsHead, Section(L("Capture"), controls(h, keeping: keeping)).inCard(), Section(L("Open it from anywhere"), [.hostControls]).inCard(),
                                                     pasting(h), keepingSection(h), ignoring(h), holds(h, today: today), apps(h), ask].compactMap { $0 },
                        back: L("Back"), bare: true, dress: dress, maxWidth: 1180)
        }
        let found = found(h, place)
        let picked = found.first { $0.id == place.picked } ?? found.first
        var page = Page(summary: summary, sections: [head(h, today: today), capture(h, now: now), list(h, found: found, picked: picked, place: place, now: now), preview(h, picked, now: now),
                                                     Section(nil, [.note(L("Passwords from password managers are never kept."), symbol: "checkmark.shield", style: .plain,
                                                                         link: Action(L("History & privacy"), act: .go(Go(set: ["place": "settings"], push: true)), style: .plain))])],
                        back: L("Back"), bare: true, dress: dress, maxWidth: 1180)
        page.quietHost = true
        return page
    }

    /// The copies this view shows, as the palette finds them; nil means the search isn't one it can read.
    static func found(_ h: History, _ place: Place) -> [Entry] {
        let hits = h.find(place.query) ?? []
        return Array((place.pinned ? hits.filter(\.pinned) : hits).prefix(shownRows))
    }

    static func head(_ h: History, today: Int) -> Section {
        Section(nil, [.bar(PageBar(L("Clipboard"), detail: L(one: "{count} copy", other: "{count} copies", count: h.entries.count) + " · " + L("{count} today", ["count": today]),
                               actions: [Action(L("Open clipboard"), act: .palette("history")), gear], brand: true))], wide: true)
    }

    static var gear: Action {
        var action = Action(L("History & privacy"), act: .go(Go(set: ["place": "settings"], push: true)), symbol: "gearshape")
        action.iconOnly = true
        return action
    }

    static var settingsHead: Section {
        Section(nil, [.bar(PageBar(L("History & privacy"), detail: L("What Clipboard keeps, leaves out and does when you choose a copy."), brand: true))], wide: true)
    }

    /// What's happening to what they copy, and the ways to change it for a while.
    static func capture(_ h: History, now: Date) -> Section {
        let keeping = h.isKeeping(now: now)
        var actions: [Block] = []
        if keeping {
            actions.append(.action(Action(L("Pause {time}", ["time": Format.duration(600, units: [.minutes], width: .wide)]), tool: "pause", input: ["minutes": 10], symbol: "pause")))
            if !h.options.skipNext { actions.append(.action(Action(L("Skip my next copy"), tool: "skip_next", symbol: "forward"))) }
        } else if h.options.pausedUntil != nil, h.options.keeping {
            actions.append(.action(Action(L("Resume now"), tool: "resume", style: .primary, symbol: "play")))
        } else {
            actions.append(.action(Action(L("Keep a history of what I copy"), tool: "set_option", input: ["option": "keeping", "on": true], style: .primary, symbol: "play")))
        }
        return Section(Words.status(h, now: now), []).inCard(accessories: actions, status: keeping && !h.options.skipNext ? .good : .warn)
    }

    static func list(_ h: History, found: [Entry], picked: Entry?, place: Place, now: Date) -> Section {
        let rows = found.map { e -> Row in
            var row = Row(e.secret ? "••••••••" : Words.title(e), detail: Words.detail(e, now: now), image: e.thumb, color: Words.swatch(e), symbol: kindSymbol(e))
            row.press = Action(e.secret ? L("A hidden copy") : Words.title(e), act: .go(Go(set: ["picked": e.id])))
            row.selected = e.id == picked?.id
            if e.pinned { row.mark = ("pin.fill", L("Pinned")) }
            return row
        }
        let clearPick: [String: Any] = ["picked": NSNull()]
        return Section(nil, [
            .search(L("Search"), placeholder: L("Search copies…"), clear: L("Clear"), key: "q", value: place.query.isEmpty ? nil : place.query, also: clearPick),
            .going(L("Which copies"), style: .pills, [Option("all", L("All copies")), Option("pinned", L("Pinned"))], selected: place.pinned ? "pinned" : "all", key: "filter", also: clearPick),
            .scrollingList(maxHeight: 440, empty: empty(h, place), rows),
        ]).inCard(row: "copies", weight: 41, joined: true)
    }

    /// Words for an empty list that say why.
    static func empty(_ h: History, _ place: Place) -> String {
        if !place.query.isEmpty, h.find(place.query) == nil { return L("That isn't a pattern Clipboard can read.") }
        if !place.query.isEmpty { return L("No copy matches “{query}”.", ["query": place.query]) }
        if place.pinned { return L("Nothing is pinned yet. Pin a copy to keep it for good.") }
        return h.isKeeping() ? L("Nothing copied yet.") : L("{status}, so there's nothing new.", ["status": Words.status(h)])
    }

    static func preview(_ h: History, _ e: Entry?, now: Date) -> Section {
        guard let e else { return Section(nil, [.preview(Preview(empty: L("Pick a copy to see it whole.")))]).inCard(row: "copies", weight: 59, joined: true) }
        let full = Words.preview(e, now: now)
        // The foot says where and when; its first line reads as the title, unless it's code, which stays as it was copied.
        let foot = [L("From"), L("Copied")]
        var title = full.title, text = e.kind == .color ? nil : full.text
        if title == nil, !full.code, let whole = text, e.kind != .file {
            let line = Words.title(e)
            if line.count <= 80 {
                title = line
                let rest = whole.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false).dropFirst().first.map(String.init)?.trimmingCharacters(in: .whitespacesAndNewlines)
                text = whole.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix(line) ? (rest?.isEmpty == false ? rest : nil) : whole
            }
        }
        var pin = Action(e.pinned ? L("Unpin") : L("Pin"), tool: "pin_copy", input: ["id": e.id], symbol: e.pinned ? "pin.slash" : "pin")
        pin.iconOnly = true
        var delete = Action(L("Delete"), tool: "delete_copy", input: ["id": e.id], symbol: "trash")
        delete.iconOnly = true
        let copy = Action(L("Copy"), tool: "copy_again", input: ["id": e.id], style: .primary, symbol: "doc.on.doc")
        return Section(nil, [.preview(Preview(kind: kindName(e), kindSymbol: kindSymbol(e), title: title ?? (full.code || text == nil ? Words.title(e) : nil), text: text, code: full.code,
                                              image: full.image, color: Words.swatch(e), facts: full.facts.filter { !foot.contains($0.0) }, footer: Words.detail(e, now: now), actions: e.secret ? [delete, copy] : [pin, delete, copy]))])
            .inCard(row: "copies", weight: 59, joined: true)
    }

    static func kindName(_ e: Entry) -> String {
        if e.secret { return L("Hidden") }
        switch e.kind {
        case .text: return L("Text")
        case .link: return L("Link")
        case .image: return L("Picture")
        case .file: return L("Files")
        case .color: return L("Colour")
        case .code: return L("Code")
        }
    }

    /// What the copy is, whatever else is true of it: a pin is its own mark.
    static func kindSymbol(_ e: Entry) -> String {
        if e.secret { return "lock" }
        switch e.kind {
        case .text: return "text.alignleft"
        case .link: return "link"
        case .image: return "photo"
        case .file: return "doc"
        case .color: return "paintpalette"
        case .code: return "chevron.left.forwardslash.chevron.right"
        }
    }

    static func controls(_ h: History, keeping: Bool) -> [Block] {
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
        return blocks
    }

    static func pasting(_ h: History) -> Section {
        Section(L("Choosing a copy"), [
            .choice(L("Return"), detail: L("What choosing a copy does. Option-Return does the other; Shift-Return pastes plain text."),
                    options: [("paste", L("Pastes it")), ("copy", L("Only copies it"))], selected: h.options.paste ? "paste" : "copy",
                    tool: "set_option", input: ["option": "paste"]),
            .choice(L("Formatting"), detail: L("Fonts, colours and links that came with copied text."),
                    options: [("keep", L("Keep it")), ("remove", L("Remove it"))], selected: h.options.plain ? "remove" : "keep",
                    tool: "set_option", input: ["option": "plain"]),
        ]).inCard()
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
        ]).inCard()
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
        return Section(L("Leave out"), blocks).inCard()
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
        ]).inCard()
    }

    static func apps(_ h: History) -> Section? {
        let apps = Dictionary(grouping: h.entries.compactMap(\.source), by: { $0 }).mapValues(\.count).sorted { $0.value > $1.value }.prefix(6)
        guard let top = apps.first?.value else { return nil }
        return Section(L("Where your copies come from"), [
            .bars(caption: L("The app in front when you copied."), pictured: apps.map { PicturedBar(Bar($0.key, Format.integer($0.value), fraction: Double($0.value) / Double(top))) }),
        ]).inCard()
    }

    /// What is asked stays English: Sidefolk understands typed requests in English (its GLOSSARY, rule 1).
    static var ask: Section {
        Section(L("Ask about it"), [
            .askRow(L("What did I copy today?"), "What did I copy today?"),
            .askRow(L("Find a link I copied"), "Find the last link I copied"),
            .askRow(L("Save my last copy to notes"), "Save the last thing I copied to my notes"),
        ]).inCard()
    }
}
