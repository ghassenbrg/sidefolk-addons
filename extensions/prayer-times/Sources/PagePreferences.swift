import Foundation
import SidefolkExtensionKit

/// Preferences. Every change is a draft in the page's state until Save; a preview says what it would do, and Cancel leaves everything as it was. Reminders is one pearl sheet (F05), place, calculation, calendar and data
/// one board of four framed panels (F06), and `section` says which of them is meant; Sources is its own list.
@MainActor
enum PreferencesPage {
    static let tabs: [(id: String, word: String, symbol: String)] = [("place", L("Place"), Node.Glyph.pin), ("sources", L("Sources"), "cylinder.split.1x2"), ("calculation", L("Calculation"), "square.grid.3x3.square"), ("calendar", L("Calendar"), "calendar"), ("reminders", L("Reminders"), "bell"), ("data", L("Data"), "square.and.arrow.down")]

    static func sections(_ ctx: Context) -> [Section] {
        let section = ctx.state.string("section") ?? "place"
        switch section {
        case "sources": return [Section(nil, [strip(ctx, section: section)], wide: true)] + sources(ctx)
        case "reminders": return RemindersSheet.sections(ctx)
        default: return SettingsBoard.sections(ctx, section: section)
        }
    }

    /// Its six sections side by side, wrapping onto a second line where the window is narrow.
    private static func strip(_ ctx: Context, section: String) -> Block {
        let margin = 16.0, w = ctx.width - margin * 2
        let perRow = ctx.narrow ? 3 : 6
        let cell = (w - Double(perRow - 1) * 8) / Double(perRow), h = 40.0
        let rows = Int(ceil(Double(tabs.count) / Double(perRow)))
        var acts: [String: PageAct] = [:]
        for tab in tabs { acts["s\(tab.0)"] = .go(Go(set: ["section": tab.0])) }
        let scene = Scene(width: ctx.width, height: Double(rows) * h + Double(rows - 1) * 8 + 12) {
            for (i, tab) in tabs.enumerated() {
                let on = tab.0 == section
                Node.group {
                    Node.rect(fill: on ? Noor.chosen : Noor.surface, stroke: on ? Noor.chosen : Noor.hairline, lineWidth: 1, corner: 10).size(cell, h)
                    Node.icon(tab.2, color: on ? Noor.onChosen : Noor.text, side: 16).at(12, 12)
                    Node.say(tab.1, 34, 0, cell - 40, h, size: 13, weight: on ? "semibold" : "medium", color: on ? Noor.onChosen : Noor.text)
                }
                .size(cell, h).at(margin + Double(i % perRow) * (cell + 8), 12 + Double(i / perRow) * (h + 8))
                .area("s\(tab.0)", label: tab.1, hover: .init(scale: 1.0), selected: on)
            }
        }
        return .scene(PageSceneBlock(scene, acts: acts))
    }

    // MARK: Sources

    private static func sources(_ ctx: Context) -> [Section] {
        var rows: [Row] = ctx.model.sources.map { source in
            let current = source.id == ctx.model.prefs.sourceID
            var detail = [Words.sourceKind(source), source.zoneID]
            if let coverage = source.coverage { detail.append(L("{from} to {to}", ["from": coverage.lowerBound.iso, "to": coverage.upperBound.iso])) }
            if let fetched = source.lastFetch { detail.append(L("Fetched {when}", ["when": Format.dateTime(fetched, timeZone: source.zone)])) }
            return Row(source.name + (current ? " ✓" : ""), detail: detail.joined(separator: " · "), symbol: source.kind == .manual ? "pencil" : "function",
                       action: current ? nil : Action(L("Preview"), act: .go(Go(set: ["compare": source.id]))))
        }
        if rows.isEmpty { rows = [Row(L("No saved timetables"), symbol: "tray")] }
        var out = [Section(L("Saved timetables"), [.list(nil, rows)], wide: true)]
        if let id = ctx.state.string("compare"), let source = ctx.model.sources.first(where: { $0.id == id }) {
            out.append(Section(L("Source-change preview"), comparison(ctx, to: source), wide: true))
        }
        if ctx.model.prefs.sourceID != nil, let current = ctx.model.source, current.kind == .manual {
            out.append(Section(nil, [.action(Action(L("Remove {name}", ["name": current.name]), tool: "remove_source", input: ["id": current.id], style: .destructive, symbol: "trash", detail: L("Removes its saved times. Noor goes back to calculated times if a method is set.")))], wide: true))
        }
        out.append(Section(L("Add a mosque's timetable"), SourcePage.addButtons(ctx), detail: L("A source you enter is labelled Manual. An imported file is checked before anything is saved."), wide: true))
        out.append(Section(L("Supported feeds"), [.note(L("No validated feed is connected. Noor doesn't follow any mosque automatically, and doesn't use anyone's private API."), tone: .neutral)], wide: true))
        return out
    }

    /// The proposed source's own day. A calculated one isn't asked for until it is chosen, so it has none yet: better a dash than the current times under its name.
    static func proposedDay(_ ctx: Context, _ next: TimetableSource) -> PrayerDay? {
        if case .ok(let table) = ctx.model.store.timetable(sourceID: next.id), case .success(let day) = table.day(on: CivilDate(ctx.snapshot.now, in: next.zone)) { return day }
        return nil
    }

    /// The same date under both, each in its own zone. Reminders you chose stay chosen; a missing iqamah is called out rather than borrowed.
    private static func comparison(_ ctx: Context, to next: TimetableSource) -> [Block] {
        guard let today = ctx.snapshot.localDate, let current = ctx.model.source else { return [] }
        let nextDay = proposedDay(ctx, next)
        let old = ctx.model.day(today)
        var rows: [(String, String)] = []
        for id in PrayerID.allCases {
            let a = old?.starts[id].map { Words.time($0, zone: current.zone) } ?? "—", b = nextDay?.starts[id].map { Words.time($0, zone: next.zone) } ?? "—"
            rows.append((Words.prayer(id), "\(a) → \(b)"))
        }
        let missing = ctx.model.prefs.reminders.prayers.contains { $0.value.iqamahMinutes != nil } && (nextDay?.iqamah.isEmpty ?? true)
        var out: [Block] = [.facts(L("{old} → {new}", ["old": current.name, "new": next.name]), rows)]
        if next.kind == .calculated { out.append(.note(L("Calculated times come from the provider once you switch, then replace what is planned. Your reminder choices stay."), tone: .info)) }
        if missing { out.append(.note(L("This source has no iqamah times, so your iqamah reminders won't come from it. Your choices are kept."), tone: .warn)) }
        out.append(.action(Action(L("Use {name}", ["name": next.name]), tool: "choose_source", input: ["id": next.id], style: .primary, symbol: "checkmark")))
        out.append(.action(Action(L("Cancel"), act: .go(Go(set: ["compare": NSNull()])))))
        return out
    }

    // MARK: Method

    /// Methods as the provider lists them, in its order. None is marked as recommended, on purpose.
    static func methodChoice(_ ctx: Context, selected: String, list: Bool = false) -> [Block] {
        guard !ctx.model.prayerMethods.isEmpty else {
            return [.note(ctx.model.load == .loading ? L("Loading the methods…") : (Words.problem(ctx.model.problem).isEmpty ? L("The list of methods isn't here yet.") : Words.problem(ctx.model.problem)), tone: .neutral),
                    .action(Action(L("Try again"), tool: "refresh", symbol: "arrow.clockwise"))]
        }
        return [.draftChoice(L("Calculation method"), detail: L("From the provider's list, in its order."), options: ctx.model.prayerMethods.filter { $0.id != 99 }.prefix(24).map { Option("\($0.id)", $0.name) }, selected: selected, key: "d_method", style: list ? .rows : nil)]
    }
}

/// About how many lines words take in a width: enough to give them the room, which matters more than a point or two spare.
func lineCount(_ words: String, width: Double, size: Double) -> Int {
    max(1, Int(ceil(Double(words.count) * size * 0.5 / max(width, 40))))
}

/// A scene being put together in the page's own numbers: what it draws, the native controls laid into it, and what its areas do.
struct Sketch {
    var nodes: [Node] = []
    var inlays: [PageInlay] = []
    var tools: [String: (tool: String, input: [String: Any])] = [:]
    var acts: [String: PageAct] = [:]

    mutating func add(_ node: Node) { nodes.append(node) }
    mutating func add(_ more: [Node]) { nodes += more }
    mutating func inlay(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ part: Block) { inlays.append(PageInlay(x: x, y: y, w: w, h: h, part)) }
    mutating func take(_ other: Sketch) {
        nodes += other.nodes
        inlays += other.inlays
        tools.merge(other.tools) { $1 }
        acts.merge(other.acts) { $1 }
    }

    func block(_ w: Double, _ h: Double) -> Block {
        let all = nodes
        return .scene(PageSceneBlock(Scene(width: w, height: h) { all }, actions: tools, acts: acts, inlays: inlays))
    }
}

extension Node {
    /// A map pin in a `w × h` box, outlined, or filled with its hole showing `hole`.
    static func pin(x: Double, y: Double, w: Double, h: Double, color: Color, hole: Color? = nil, lineWidth: Double = 1.6) -> Node {
        let cx = w / 2, side = w * 0.42
        let shape = "M \(n(cx)) \(n(h)) C \(n(cx - w * 0.18)) \(n(h * 0.72)) 0 \(n(h * 0.56)) 0 \(n(h * 0.38)) C 0 \(n(h * 0.16)) \(n(w * 0.22)) 0 \(n(cx)) 0 C \(n(w * 0.78)) 0 \(n(w)) \(n(h * 0.16)) \(n(w)) \(n(h * 0.38)) C \(n(w)) \(n(h * 0.56)) \(n(cx + w * 0.18)) \(n(h * 0.72)) \(n(cx)) \(n(h)) Z"
        return Node.group {
            if let hole {
                Node.path(shape, fill: color).size(w, h)
                Node.ellipse(fill: hole).size(side, side).at(cx - side / 2, h * 0.38 - side / 2)
            } else {
                Node.path(shape, stroke: color, lineWidth: lineWidth).size(w, h)
                Node.ellipse(stroke: color, lineWidth: lineWidth).size(side, side).at(cx - side / 2, h * 0.38 - side / 2)
            }
        }
        .size(w, h).at(x, y)
    }

    /// What a menu looks like before it opens: its words and a chevron on a drawn pill. The native menu lies invisibly over it.
    static func menuPill(_ words: String, x: Double, y: Double, w: Double, h: Double, size: Double, fill: Color, line: Color, ink: Color, corner: Double, disabled: Bool = false) -> Node {
        let chevron = max(size * 0.72, 9)
        return Node.group {
            Node.rect(fill: fill, stroke: line, lineWidth: 1, corner: corner).size(w, h)
            Node.say(words, h * 0.38, 0, w - h * 0.38 - chevron - h * 0.5, h, size: size, color: ink, tabular: true)
            Node.symbol("chevron.down", color: ink).symbolLook(weight: "semibold").size(chevron, chevron).at(w - chevron - h * 0.36, (h - chevron) / 2)
        }
        .size(w, h).at(x, y).opacity(disabled ? 0.5 : 1)
    }
}
