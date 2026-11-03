import Foundation
import SidefolkExtensionKit

/// Preferences' other sections, the F06 board: four framed panels and a strip that compares timetables. `section` only says which panel is meant, so it stands out; all four are always here.
@MainActor
enum SettingsBoard {
    static func sections(_ ctx: Context, section: String) -> [Section] {
        if section == "place", ctx.state.bool("place_edit") == true { return placeEditor(ctx) }
        var out: [Section] = []
        if ctx.model.unreadable != nil { out.append(Section(nil, [.note(L("A saved file couldn't be read, so Noor is using its defaults and has left the file in place."), tone: .warn)], wide: true)) }
        out.append(Section(nil, board(ctx, section: section), wide: true))
        return out
    }

    private typealias Content = (inout Sketch, _ x: Double, _ y: Double, _ w: Double) -> Double

    /// In the board's numbers: x less 245, y less 175. Below 860 points the panels stack, and each grows to what it holds.
    private static func board(_ ctx: Context, section: String) -> [Block] {
        let w = ctx.width
        let stack = w < 780
        let r = stack ? Ruler(width: 1150) : ctx.ruler
        var s = Sketch()
        let margin = stack ? 10 : r.u(21)
        let backSide = max(r.u(34), 26), titleX = margin + backSide + r.u(8)
        s.backButton(x: margin, y: r.u(9), side: backSide, fill: Noor.quiet, line: Noor.edge, ink: Noor.text)
        let titleSize = r.f(35, min: 24), titleW = max(r.u(205), wordsWidth(L("Preferences"), size: titleSize, em: 0.6) + 4), wordsX = titleX + titleW + r.u(10)
        s.add(Node.say(L("Preferences"), titleX, r.u(4), titleW, r.u(44), size: titleSize, weight: "bold"))
        if stack {
            s.add(Node.say(L("Configure how Noor calculates, displays and stores your data."), margin + r.u(6), r.u(48), w - margin * 2, r.u(24), size: r.f(14, min: 12), color: Noor.muted))
        } else {
            s.add(Node.say(L("Configure how Noor calculates, displays and stores your data."), wordsX, r.u(14), w - wordsX - r.u(190), r.u(30), size: r.f(16, min: 12.5), color: Noor.muted))
        }
        s.acts["sreminders"] = .go(Go(set: ["section": "reminders"]))
        let pillW = r.u(150), pillH = r.u(34)
        s.add(Node.pill("sreminders", label: L("Reminders"), x: w - margin - pillW, y: r.u(11), w: pillW, h: pillH, symbol: "chevron.forward", size: r.f(14, min: 12)))

        let panels: [(id: String, title: String, detail: String, symbol: String, medal: String, tint: Color, content: Content)] = [
            ("place", L("1. Place & source"), L("Set your location and calculation source."), "pin", "pin", Noor.accent, { placeBody(ctx, &$0, x: $1, y: $2, w: $3, r: r) }),
            ("calculation", L("2. Calculation"), L("Choose calculation method and adjustments."), "gearshape", "seal.fill", Noor.text, { calculationBody(ctx, &$0, x: $1, y: $2, w: $3, r: r) }),
            ("calendar", L("3. Calendar"), L("Set the Islamic calendar and display options."), "calendar", "moon.fill", Noor.accent, { calendarBody(ctx, &$0, x: $1, y: $2, w: $3, r: r) }),
            ("data", L("4. Data & privacy"), L("Manage local data and external services."), "cylinder.split.1x2", "cylinder.split.1x2.fill", Noor.text, { dataBody(ctx, &$0, x: $1, y: $2, w: $3, r: r) }),
        ]
        let widths: [Double] = stack ? [w - margin * 2, w - margin * 2, w - margin * 2, w - margin * 2] : [r.u(603), w - r.u(657), r.u(603), w - r.u(657)]
        let lefts: [Double] = stack ? [margin, margin, margin, margin] : [r.u(21), r.u(636), r.u(21), r.u(636)]
        let boards: [Double] = [r.u(355), r.u(355), r.u(318), r.u(318)]
        // Each row of panels is as tall as the board has it, or as its fullest panel needs where type has stopped shrinking.
        var inner: [Sketch] = []
        var blocks: [Block] = []
        var y = stack ? r.u(84) : r.u(56)
        var i = 0
        while i < panels.count {
            let row = stack ? [i] : [i, i + 1]
            var used = 0.0
            for j in row {
                var sketch = Sketch()
                used = max(used, panels[j].content(&sketch, lefts[j] + r.u(13), y + r.u(69), widths[j] - r.u(26)) + r.u(82))
                inner.append(sketch)
            }
            let ph = stack ? used : max(boards[i], used)
            for j in row {
                frame(&s, x: lefts[j], y: y, w: widths[j], h: ph, title: panels[j].title, detail: panels[j].detail, symbol: panels[j].symbol, medal: panels[j].medal, tint: panels[j].tint, picked: section == panels[j].id && section != "place", r: r)
                s.take(inner[j])
            }
            y += ph + (stack ? 10 : r.u(10))
            i += row.count
            // A scene has a tallest size, and four stacked panels could pass it: one column is a few scenes.
            if stack, i % 2 == 0 {
                blocks.append(s.block(w, y))
                s = Sketch()
                y = 0
            }
        }
        let stripH = comparisonStrip(ctx, &s, x: stack ? margin : r.u(23), y: y, w: stack ? w - margin * 2 : w - r.u(45), r: r, stack: stack)
        return blocks + [s.block(w, y + stripH + r.u(12))]
    }

    // MARK: Materials

    /// The panels' finer lattice: thin copper lines on lapis in the dark, as the board has them.
    private static func panelLattice(_ w: Double, _ h: Double, corner: Double) -> Node {
        Node.image("art/lattice-l.jpg", dark: "art/panel-lattice-d.jpg", fit: "cover").size(w, h).corner(corner).clip()
    }

    /// A framed panel: lattice with a gold line round it, a quiet plate for its name that ends in a curve, the medallion, and the well its controls stand in.
    private static func frame(_ s: inout Sketch, x: Double, y: Double, w: Double, h: Double, title: String, detail: String, symbol: String, medal: String, tint: Color, picked: Bool, r: Ruler) {
        let head = r.u(68), corner = r.u(14), plate = min(w * 0.77, w - r.u(130))
        s.add(panelLattice(w, h, corner: corner).at(x, y))
        s.add(Node.path("M \(n(r.u(24))) 1 L \(n(plate - r.u(62))) 1 C \(n(plate - r.u(22))) 4 \(n(plate - r.u(6))) \(n(head * 0.45)) \(n(plate)) \(n(head + 3)) L \(n(r.u(10))) \(n(head + 3)) C \(n(r.u(10))) \(n(head * 0.45)) \(n(r.u(14))) \(n(head * 0.15)) \(n(r.u(24))) 1 Z", fill: Noor.quiet).size(w, head + 3).at(x, y))
        s.add(Node.path("M \(n(plate - r.u(62))) 1 C \(n(plate - r.u(22))) 4 \(n(plate - r.u(6))) \(n(head * 0.45)) \(n(plate)) \(n(head))", stroke: Noor.inlay, lineWidth: 1.2).size(w, head).at(x, y))
        s.add(Node.rect(fill: Noor.surface, stroke: Noor.hairline, lineWidth: 1, corner: r.u(18)).size(w - r.u(26), h - r.u(82)).at(x + r.u(13), y + head + r.u(1)))
        s.add(Node.rect(stroke: picked ? Noor.pickedEdge : Noor.inlay, lineWidth: picked ? 2.5 : 1.2, corner: corner).size(w, h).at(x, y))
        let glyph = r.f(38, min: 24)
        if symbol == "pin" {
            s.add(Node.pin(x: x + r.u(42), y: y + (head - glyph) / 2, w: glyph * 0.72, h: glyph, color: tint, lineWidth: 2))
        } else {
            s.add(Node.symbol(symbol, color: tint).size(glyph * 0.86, glyph).at(x + r.u(40), y + (head - glyph) / 2))
        }
        // Words that take two lines lift the title a little: the plate's height holds.
        let long = lineCount(detail, width: plate - r.u(130), size: r.f(15.5, min: 11.5), em: 0.5) > 1
        s.add(Node.say(title, x + r.u(92), y + r.u(long ? 2 : 8), plate - r.u(150), r.u(32), size: r.f(23, min: 16), weight: "semibold"))
        s.add(Node.say(detail, x + r.u(92), y + r.u(long ? 32 : 37), plate - r.u(130), r.u(long ? 36 : 24), size: long ? r.f(14, min: 11) : r.f(15.5, min: 11.5), color: Noor.muted, valign: long ? "top" : "center", lines: long ? 2 : 1))
        // The medallion: a pointed quatrefoil in gold.
        let m = r.u(34), cx = w - r.u(66), cy = head / 2 + r.u(2)
        func foil(_ a: Double) -> String {
            "M \(n(cx)) \(n(cy - a)) C \(n(cx + a * 0.14)) \(n(cy - a * 0.62)) \(n(cx + a * 0.62)) \(n(cy - a * 0.62)) \(n(cx + a)) \(n(cy)) C \(n(cx + a * 0.62)) \(n(cy + a * 0.62)) \(n(cx + a * 0.14)) \(n(cy + a * 0.62)) \(n(cx)) \(n(cy + a)) C \(n(cx - a * 0.14)) \(n(cy + a * 0.62)) \(n(cx - a * 0.62)) \(n(cy + a * 0.62)) \(n(cx - a)) \(n(cy)) C \(n(cx - a * 0.62)) \(n(cy - a * 0.62)) \(n(cx - a * 0.14)) \(n(cy - a * 0.62)) \(n(cx)) \(n(cy - a)) Z"
        }
        s.add(Node.path(foil(m), fill: Noor.surface, stroke: Noor.inlay, lineWidth: 1.5).size(w, h).at(x, y))
        s.add(Node.path(foil(m * 0.82), stroke: Noor.inlay, lineWidth: 0.8).size(w, h).at(x, y))
        let mark = r.f(26, min: 16)
        let gold = Color.adaptive(light: "#B8862E", dark: "#F4C877")
        if medal == "pin" {
            s.add(Node.pin(x: x + cx - mark * 0.36, y: y + cy - mark / 2, w: mark * 0.72, h: mark, color: gold, hole: Noor.surface))
        } else {
            s.add(Node.symbol(medal, color: gold).size(mark, mark).at(x + cx - mark / 2, y + cy - mark / 2))
        }
    }

    /// A label, a small line under it where it has one, and a drawn menu with the native one over it. Returns the row's height.
    @discardableResult
    private static func menuRow(_ s: inout Sketch, label: String, caption: String? = nil, words: String, part: Block, x: Double, y: Double, labelW: Double, w: Double, h: Double, r: Ruler) -> Double {
        let stacked = labelW > w * 0.6
        let labelH = max(r.u(22), 18)
        let pillX = stacked ? x : x + labelW, pillW = stacked ? w : w - labelW, pillY = stacked ? y + labelH + 1 : y
        // A caption that takes two lines lifts its label a little, so it still ends above the next row's.
        let tall = caption.map { lineCount($0, width: labelW - r.u(8), size: r.f(11.5), em: 0.5) > 1 } ?? false
        s.add(Node.say(label, x, stacked ? y : (caption == nil ? y : y - r.u(tall ? 9 : 5)), stacked ? w : labelW - r.u(8), stacked || caption == nil ? (stacked ? labelH : h) : r.u(24), size: r.f(16, min: 12.5)))
        if let caption, !stacked { s.add(Node.say(caption, x, y + r.u(tall ? 12 : 17), labelW - r.u(8), tall ? max(r.u(28), 27) : r.u(18), size: tall ? 11 : r.f(11.5), color: Noor.faint, valign: "top", lines: tall ? 2 : 1)) }
        s.add(Node.menuPill(words, x: pillX, y: pillY, w: pillW, h: h, size: r.f(15.5, min: 12.5), fill: Noor.well, line: Noor.edge, ink: Noor.text, corner: r.u(8)))
        s.inlay(pillX, pillY, pillW, h, part)
        return stacked ? labelH + 1 + h : h
    }

    /// The switch's colour under it, so it says "on" as plainly while the window is behind others, when the system greys its own.
    private static func onTrack(_ s: inout Sketch, cx: Double, cy: Double) {
        s.add(Node.capsule(fill: Noor.chosen).size(38, 22).at(cx - 19, cy - 11))
    }

    private static func toggleRow(_ s: inout Sketch, title: String, detail: String, on: Bool, part: Block, x: Double, y: Double, w: Double, r: Ruler) {
        let wrap = w < 400
        s.add(Node.say(title, x, y, w - r.u(64) - 6, max(r.u(22), 18), size: r.f(15.5, min: 12.5)))
        s.add(Node.say(detail, x, y + max(r.u(20), 17), w - r.u(64) - 6, wrap ? 30 : max(r.u(20), 15), size: r.f(13, min: 11), color: Noor.muted, lines: wrap ? 2 : 1))
        if on { onTrack(&s, cx: x + w - r.u(28), cy: y + r.u(19)) }
        s.inlay(x + w - r.u(56), y + r.u(4), r.u(56), r.u(30), part)
    }

    /// What a native button stands on: the same pill as `smallButton`, and the host says its words.
    private static func nativeButton(_ s: inout Sketch, _ action: Action, x: Double, y: Double, w: Double, h: Double, r: Ruler) {
        s.add(Node.rect(fill: Noor.quiet, stroke: Noor.edge, lineWidth: 1.2, corner: r.u(11)).size(w, h).at(x, y))
        s.button(action, x: x, y: y, w: w, h: h, size: r.f(15, min: 12))
    }

    private static func smallButton(_ s: inout Sketch, _ id: String, _ word: String, x: Double, y: Double, w: Double, h: Double, destructive: Bool = false, disabled: Bool = false, filled: Bool = false, r: Ruler) {
        let red = Color.adaptive(light: "#B3261E", dark: "#FF8A80")
        let ink = filled ? Noor.onChosen : destructive ? red : Noor.text
        var node = Node.group {
            if filled {
                Node.capsule(stroke: .hex("#A58DE6"), lineWidth: 1).gradient([.hex("#7D5CCC"), .hex("#5B3FA6")]).size(w, h)
            } else {
                Node.rect(fill: destructive ? Color.adaptive(light: "#FDECEA", dark: "#2A1228") : Noor.quiet, stroke: destructive ? red : Noor.edge, lineWidth: 1.2, corner: r.u(11)).size(w, h)
            }
            Node.say(word, r.u(8), 0, w - r.u(16), h, size: r.f(15, min: 12), weight: "medium", color: ink, align: "center")
        }
        .size(w, h).at(x, y)
        if disabled { node = node.opacity(0.5) }
        s.add(node.area(id, label: word, disabled: disabled, hover: .init(scale: 1.01)))
    }

    /// A link in the page's own words, its arrow after them.
    private static func link(_ s: inout Sketch, _ id: String, _ word: String, x: Double, y: Double, w: Double, r: Ruler) {
        let ink = Color.adaptive(light: "#3F5BC4", dark: "#8FB0FF")
        s.add(Node.group {
            Node.say(word, 0, 0, w - 12, 20, size: r.f(13.5, min: 11.5), color: ink, align: "trailing")
            Node.symbol("chevron.forward", color: ink).size(6, 10).at(w - 8, 5)
        }
        .size(w, 20).at(x, y)
        .area(id, label: word, hover: .init(scale: 1.0)))
    }

    private static func line(_ s: inout Sketch, x: Double, y: Double, w: Double) {
        s.add(Node.rect(fill: Noor.hairline).size(w, 1).at(x, y))
    }

    // MARK: Place and source

    /// Returns the height it needs; `x`, `y` and `w` are the well's own.
    private static func placeBody(_ ctx: Context, _ s: inout Sketch, x: Double, y: Double, w: Double, r: Ruler) -> Double {
        let pad = r.u(22), inner = w - pad * 2, left = x + pad
        let narrow = inner < 400
        let place = ctx.model.prefs.place
        // Where it is.
        s.acts["changeplace"] = .go(Go(set: ["section": "place", "place_edit": true], push: true))
        let buttonW = max(r.u(150), 112)
        s.add(Node.say(L("Place"), left, y + r.u(14), r.u(110), r.u(26), size: r.f(16, min: 12.5)))
        let valueX = narrow ? left + 50 : left + r.u(122), valueW = left + inner - valueX - buttonW - 6
        s.add(Node.say(place.map(PlaceParts.title) ?? L("None chosen"), valueX, y + r.u(14), valueW, r.u(26), size: r.f(16, min: 12.5)))
        s.add(Node.say(place?.zoneID ?? "—", valueX, y + r.u(14) + max(r.u(24), 20), valueW, max(r.u(22), 16), size: r.f(14, min: 11.5), color: Noor.muted))
        smallButton(&s, "changeplace", L("Change place…"), x: left + inner - buttonW, y: y + r.u(16), w: buttonW, h: max(r.u(37), 30), r: r)

        // How it's set.
        let shared = sharedPlace(ctx)
        let using = place?.origin == .shared
        func radio(_ on: Bool, at ry: Double, _ s: inout Sketch) {
            let d = r.f(24, min: 18)
            s.add(Node.ellipse(stroke: on ? Noor.pickedEdge : Noor.muted, lineWidth: on ? 1.6 : 1.1).size(d, d).at(left, ry))
            if on { s.add(Node.ellipse(fill: Noor.pickedEdge).size(d * 0.56, d * 0.56).at(left + d * 0.22, ry + d * 0.22)) }
        }
        var ry = y + max(r.u(72), 58)
        radio(!using, at: ry, &s)
        s.add(Node.say(L("Chosen by you. It stays while you travel."), left + r.u(38), ry, inner - r.u(38), r.f(24, min: 18), size: r.f(14.5, min: 12)))
        ry += max(r.u(32), 24)
        radio(using, at: ry, &s)
        let controlW: Double = {
            switch shared.control {
            case .toggle: r.u(56)
            case .allow: narrow ? 0 : r.u(190)
            case .settings: narrow ? 0 : r.u(236)
            case .none: 0
            }
        }()
        s.add(Node.say(L("Use Sidefolk's place"), left + r.u(38), ry, inner - r.u(38) - controlW - r.u(6), r.f(24, min: 18), size: r.f(15.5, min: 12.5)))
        let sharedLines = lineCount(shared.words, width: inner - r.u(38), size: r.f(12.5))
        s.add(Node.text(shared.words, size: r.f(12.5), color: shared.warn ? Noor.warm : Noor.muted, align: "leading", valign: "top", lines: sharedLines, minScale: 11 / r.f(12.5)).size(inner - r.u(38), Double(sharedLines) * 14 + 2).at(left + r.u(38), ry + max(r.u(25), 20)))
        let buttonX = narrow ? left + r.u(38) : left + inner - controlW, buttonY = narrow ? ry + max(r.u(25), 20) + Double(sharedLines) * 14 + 6 : ry - r.u(5), buttonSpan = narrow ? inner - r.u(38) : controlW
        switch shared.control {
        case .toggle(let on):
            if on { onTrack(&s, cx: left + inner - r.u(28), cy: ry + r.u(11)) }
            s.inlay(left + inner - r.u(56), ry - r.u(4), r.u(56), r.u(30), .toggle(L("Use Sidefolk's place"), on: on, tool: "follow_shared_place"))
        case .allow:
            nativeButton(&s, Action(L("Share Sidefolk's place"), act: .allow("place")), x: buttonX, y: buttonY, w: buttonSpan, h: max(r.u(30), 26), r: r)
        case .settings:
            nativeButton(&s, Action(L("Open Sidefolk's place settings"), act: .settings("place")), x: buttonX, y: buttonY, w: buttonSpan, h: max(r.u(30), 26), r: r)
        case .none:
            break
        }
        let hasButton: Bool = { if case .allow = shared.control { true } else if case .settings = shared.control { true } else { false } }()
        var cy = ry + (narrow ? max(r.u(25), 20) + Double(sharedLines) * 14 + (hasButton ? 42 : 8) : max(r.u(66), 52))
        line(&s, x: left - r.u(4), y: cy, w: inner + r.u(8))
        cy += r.u(14)

        // Which timetable. Picking another compares it below, and nothing changes until "Use".
        let sources = ctx.model.sources
        let current = ctx.model.source
        let compared = ctx.state.string("compare").flatMap { id in sources.first { $0.id == id } }
        let shown = compared ?? current
        let options = sources.map { Option($0.id, "\($0.name) (\(Words.sourceKind($0)))") }
        let rowH = max(r.u(35), 28)
        let used = menuRow(&s, label: L("Calculation source"), words: shown?.name ?? L("No timetable"), part: .draftChoice(L("Calculation source"), options: options, selected: shown?.id ?? "", key: "compare", disabled: sources.count < 2), x: left, y: cy, labelW: narrow ? inner : r.u(170), w: inner, h: rowH, r: r)
        cy += used + 5
        s.acts["ssources"] = .go(Go(set: ["section": "sources"]))
        let provider = shown?.kind == .manual ? L("A source you entered is labelled Manual.") : L("Prayer times provided by AlAdhan.")
        let linkW = max(r.u(130), 112)
        s.add(Node.say(provider, narrow ? left : left + r.u(170), cy - 4, inner - linkW - (narrow ? 0 : r.u(170)), 30, size: r.f(13.5), color: Noor.muted, lines: 2))
        link(&s, "ssources", L("Manage timetables"), x: left + inner - linkW, y: cy + 1, w: linkW, r: r)
        return cy + max(r.u(26), 30) - y
    }

    private enum SharedControl {
        case toggle(Bool), allow, settings, none
    }

    /// The same four states as `PlaceParts.shared`, in one row. Sharing and following are separate yeses, and a place chosen by hand stays until the person switches.
    private static func sharedPlace(_ ctx: Context) -> (words: String, warn: Bool, control: SharedControl) {
        guard SharedPlace.shared else {
            return (L("Optional. Sidefolk asks you first, then shares your town and its zone with Noor. Noor sends the coordinates to AlAdhan."), false, .allow)
        }
        guard let shared = SharedPlace.current else {
            return (L("Sidefolk doesn't know your place yet. Choose one by hand here, or set it in Sidefolk's settings."), true, .settings)
        }
        guard shared.timeZone != nil else {
            return (L("Sidefolk knows {place} but not its time zone, so Noor can't use it. Choose a place by hand.", ["place": shared.city]), true, .none)
        }
        let using = ctx.model.prefs.place?.origin == .shared
        return (using ? L("Following Sidefolk's place: {place}. When it moves, Noor moves with it.", ["place": shared.city]) : L("Sidefolk's place is {place}. Your chosen place stays until you switch.", ["place": shared.city]), false, .toggle(using))
    }

    // MARK: Calculation

    private static func calculationBody(_ ctx: Context, _ s: inout Sketch, x: Double, y: Double, w: Double, r: Ruler) -> Double {
        let pad = r.u(18), inner = w - pad * 2, left = x + pad
        guard ctx.model.source?.kind != .manual else {
            s.add(Node.symbol("info.circle", color: Noor.muted).size(r.f(26), r.f(26)).at(left + inner / 2 - r.f(26) / 2, y + r.u(70)))
            s.add(Node.say(L("A manual timetable has its own times. These settings apply to calculated times, and never edit a mosque's published timetable."), left + r.u(30), y + r.u(106), inner - r.u(60), r.u(84), size: r.f(15, min: 12.5), color: Noor.muted, align: "center", lines: 4))
            return r.u(200)
        }
        let saved = ctx.model.prefs.convention
        let state = ctx.state
        let method = state.string("d_method") ?? saved.map { "\($0.method)" } ?? ""
        let school = state.string("d_school") ?? saved.map { "\($0.school)" } ?? "0"
        let latitude = state.string("d_lat") ?? saved?.latitudeAdjustment.map { "\($0)" } ?? "auto"
        var tune: [String: Any] = [:]
        for id in PrayerID.allCases { tune[id.rawValue] = Int(state.string("d_tune_\(id.rawValue)") ?? "\(saved?.tune[id] ?? 0)") ?? 0 }
        let changed = method != saved.map({ "\($0.method)" }) || school != saved.map({ "\($0.school)" }) || latitude != (saved?.latitudeAdjustment.map { "\($0)" } ?? "auto")
            || PrayerID.allCases.contains { (tune[$0.rawValue] as? Int ?? 0) != (saved?.tune[$0] ?? 0) }
        let badTune = tune.values.contains { !PrayerConvention.tuneBounds.contains(($0 as? Int) ?? 0) }
        let narrow = inner < 400
        let labelW = narrow ? inner : r.u(203), rowH = max(r.u(35), 28)
        var cy = y + r.u(14)
        let step = rowH + r.u(narrow ? 10 : 8)

        // Methods as the provider lists them, in its order. None is marked as recommended, on purpose.
        let methods = ctx.model.prayerMethods.filter { $0.id != 99 }.prefix(24)
        if methods.isEmpty {
            let words = ctx.model.load == .loading ? L("Loading the methods…") : (Words.problem(ctx.model.problem).isEmpty ? L("The list of methods isn't here yet.") : Words.problem(ctx.model.problem))
            s.tools["retrymethods"] = ("refresh", [:])
            s.add(Node.say(L("Calculation method"), left, cy, labelW, rowH, size: r.f(16, min: 12.5)))
            s.add(Node.say(words, narrow ? left : left + labelW, narrow ? cy + rowH : cy, inner - (narrow ? 0 : labelW) - r.u(120), rowH, size: r.f(13, min: 11), color: Noor.muted, lines: 2))
            smallButton(&s, "retrymethods", L("Try again"), x: left + inner - r.u(110), y: narrow ? cy + rowH : cy, w: r.u(110), h: rowH, r: r)
            cy += narrow ? rowH * 2 + r.u(8) : step
        } else {
            let name = methods.first { "\($0.id)" == method }?.name ?? L("Method {id}", ["id": method])
            cy += menuRow(&s, label: L("Calculation method"), caption: L("From the provider's list, in its order."), words: name, part: .draftChoice(L("Calculation method"), options: methods.map { Option("\($0.id)", $0.name) }, selected: method, key: "d_method"), x: left, y: cy, labelW: labelW, w: inner, h: rowH, r: r) + r.u(narrow ? 10 : 8)
        }
        let schools = [("0", L("Standard (Shafi'i, Maliki, Hanbali)")), ("1", L("Hanafi"))]
        cy += menuRow(&s, label: L("Asr method"), caption: L("Only Asr differs."), words: schools.first { $0.0 == school }?.1 ?? "", part: .draftChoice(L("Asr method"), options: schools.map { Option($0.0, $0.1) }, selected: school, key: "d_school"), x: left, y: cy, labelW: labelW, w: inner, h: rowH, r: r) + r.u(narrow ? 10 : 8)
        let rules = [("auto", L("Provider's default")), ("1", L("Middle of the night")), ("2", L("One seventh")), ("3", L("Angle-based"))]
        cy += menuRow(&s, label: L("High-latitude method"), words: rules.first { $0.0 == latitude }?.1 ?? "", part: .draftChoice(L("High-latitude method"), options: rules.map { Option($0.0, $0.1) }, selected: latitude, key: "d_lat"), x: left, y: cy, labelW: labelW, w: inner, h: rowH, r: r) + r.u(12)

        // Minutes for each prayer: three on a line and two under them, as the room allows.
        let perLine = narrow ? 2 : 3, cellW = (inner - (narrow ? 0 : r.u(170))) / Double(perLine), cellH = max(r.u(38), 32)
        s.add(Node.say(L("Per-prayer minutes"), left, cy, narrow ? inner : r.u(170), r.u(30), size: r.f(15.5, min: 12.5)))
        let gridX = narrow ? left : left + r.u(170)
        if narrow { cy += max(r.u(30), 24) }
        for (i, id) in PrayerID.allCases.enumerated() {
            let key = "d_tune_\(id.rawValue)", value = state.string(key) ?? "\(saved?.tune[id] ?? 0)"
            let options = stride(from: -30, through: 30, by: 5).map { Option("\($0)", $0 > 0 ? "+\($0)" : "\($0)") } + (Int(value).map { $0 % 5 != 0 ? [Option(value, value)] : [] } ?? [])
            let cx = gridX + Double(i % perLine) * cellW, ry = cy + Double(i / perLine) * cellH
            let nameW = max(r.u(62), 50), pillW = min(cellW - nameW - 6, max(r.u(74), 60)), pillH = max(r.u(30), 26)
            s.add(Node.say(Words.prayer(id), cx, ry, nameW, pillH, size: r.f(13.5, min: 11), color: Noor.muted))
            s.add(Node.menuPill(Int(value).map { $0 > 0 ? "+\($0)" : "\($0)" } ?? value, x: cx + nameW, y: ry, w: pillW, h: pillH, size: r.f(14, min: 12), fill: Noor.well, line: Noor.edge, ink: Noor.text, corner: r.u(7)))
            s.inlay(cx + nameW, ry, pillW, pillH, .draftChoice(L("{prayer}, minutes", ["prayer": Words.prayer(id)]), options: options, selected: value, key: key))
        }
        cy += cellH * Double((PrayerID.allCases.count + perLine - 1) / perLine) + r.u(narrow ? 6 : 2)

        // Nothing here is applied until Save. There's no preview of the new times: they come from the provider once saved, and the note says so.
        let saveW = max(r.u(170), 126), cancelW = max(r.u(84), 66), buttonH = max(r.u(36), 30)
        let note = badTune ? L("Minutes must be from −30 to +30.") : changed ? L("Not saved. Saving recalculates times and replaces planned reminders.") : L("Saved.") + " " + L("Added to a calculated start. They don't edit a mosque's timetable.")
        s.tools["savecalc"] = ("save_calculation", ["method": Int(method) ?? -1, "school": Int(school) ?? 0, "latitude": Int(latitude) ?? 0, "tune": tune])
        s.acts["cancelcalc"] = .go(Go(set: state.values.keys.filter { $0.hasPrefix("d_") }.reduce(into: [String: Any]()) { $0[$1] = NSNull() }))
        let textW = narrow ? inner : inner - saveW - cancelW - r.u(16)
        s.add(Node.symbol("info.circle", color: changed ? Noor.warm : Noor.muted).size(r.f(15, min: 13), r.f(15, min: 13)).at(left, cy + r.u(10)))
        s.add(Node.say(note, left + r.u(22), cy, textW - r.u(22), narrow ? 30 : buttonH, size: r.f(12), color: changed ? Noor.warm : Noor.muted, lines: 2))
        let by = narrow ? cy + 34 : cy
        smallButton(&s, "cancelcalc", L("Cancel"), x: left + inner - saveW - cancelW - r.u(8), y: by, w: cancelW, h: buttonH, disabled: !changed, r: r)
        smallButton(&s, "savecalc", L("Save calculation"), x: left + inner - saveW, y: by, w: saveW, h: buttonH, disabled: !changed || method.isEmpty || badTune, filled: true, r: r)
        return by + buttonH + r.u(4) - y
    }

    // MARK: Calendar

    private static func calendarBody(_ ctx: Context, _ s: inout Sketch, x: Double, y: Double, w: Double, r: Ruler) -> Double {
        let pad = r.u(22), inner = w - pad * 2, left = x + pad
        let p = ctx.model.prefs
        let methods = ctx.model.calendarMethods.isEmpty ? [CalendarMethodInfo(method: .uaq, name: "Umm al-Qura", description: "", validity: "")] : ctx.model.calendarMethods
        let formats = [("system", L("Follow the system")), ("hour24", L("24-hour")), ("hour12", L("12-hour"))]
        let narrow = inner < 400, labelW = narrow ? inner : r.u(208), rowH = max(r.u(31), 26)
        var cy = y + r.u(9)
        cy += menuRow(&s, label: L("Calendar method"), words: methods.first { $0.method == p.calendarMethod }?.name ?? p.calendarMethod.rawValue, part: .choice(L("Calendar method"), options: methods.map { ($0.method.rawValue, $0.name) }, selected: p.calendarMethod.rawValue, tool: "set_calendar_method"), x: left, y: cy, labelW: labelW, w: inner, h: rowH, r: r) + r.u(6)
        cy += menuRow(&s, label: L("Time format"), words: formats.first { $0.0 == p.timeFormat.rawValue }?.1 ?? "", part: .choice(L("Time format"), options: formats, selected: p.timeFormat.rawValue, tool: "set_display", input: ["what": "time"]), x: left, y: cy, labelW: labelW, w: inner, h: rowH, r: r) + r.u(6)
        toggleRow(&s, title: L("Show API-listed occasions"), detail: L("Marks dates the provider lists. Reminders for them are separate."), on: p.showOccasions, part: .toggle(L("Show API-listed occasions"), on: p.showOccasions, tool: "set_display", input: ["what": "occasions"]), x: left, y: cy, w: inner, r: r)
        cy += narrow ? 52 : max(r.u(44), 36)
        toggleRow(&s, title: L("Show a Name on Overview"), detail: L("It changes each place-local day, with no meaning in the order."), on: p.showNameOfTheDay, part: .toggle(L("Show a Name on Overview"), on: p.showNameOfTheDay, tool: "set_display", input: ["what": "name"]), x: left, y: cy, w: inner, r: r)
        cy += narrow ? 52 : max(r.u(46), 38)
        line(&s, x: left - r.u(4), y: cy, w: inner + r.u(8))
        s.add(Node.symbol("info.circle", color: Noor.muted).size(r.f(16, min: 13), r.f(16, min: 13)).at(left, cy + r.u(9)))
        s.add(Node.text(L("Separate from the prayer method. Dates are provided by this method, and local announcements may differ."), size: r.f(12.5), color: Noor.muted, align: "leading", valign: "top", lines: narrow ? 3 : 2, minScale: 11 / r.f(12.5)).size(inner - r.u(30), narrow ? 44 : max(r.u(36), 28)).at(left + r.u(28), cy + r.u(5)))
        return cy + (narrow ? 50 : max(r.u(42), 34)) - y
    }

    // MARK: Data

    private static func dataBody(_ ctx: Context, _ s: inout Sketch, x: Double, y: Double, w: Double, r: Ruler) -> Double {
        let pad = r.u(22), inner = w - pad * 2, left = x + pad
        let narrow = inner < 400
        // What is set and nothing fetched: downloaded answers would pass what one click may copy, and the button would go.
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let settings = (try? encoder.encode(ctx.model.prefs)).flatMap { String(data: $0, encoding: .utf8) }.flatMap { $0.count <= 2000 ? $0 : nil }
        let fetched = ctx.model.fetchedAt.map { Format.dateTime($0, timeZone: ctx.zone) }
        let facts: [(String, String)] = [
            (L("Last successful fetch"), fetched ?? "—"),
            (L("Provider"), "AlAdhan (api.aladhan.com)"),
            (L("Saved names"), Format.integer(ctx.model.bookmarks.count)),
            (L("Saved timetables"), Format.integer(ctx.model.sources.filter { $0.kind == .manual }.count)),
        ]
        let side = narrow ? 0 : r.u(184), factH = max(r.u(23), 18), valueX = narrow ? 118 : r.u(170)
        var cy = y + r.u(7)
        for (i, fact) in facts.enumerated() {
            s.add(Node.say(fact.0, left, cy + Double(i) * factH, valueX - 6, factH, size: r.f(14, min: 11.5)))
            s.add(Node.say(fact.1, left + valueX, cy + Double(i) * factH, inner - valueX - side - r.u(24), factH, size: r.f(14, min: 11.5), color: Noor.text, tabular: true))
        }
        if fetched != nil { s.add(Node.symbol("checkmark.circle.fill", color: .adaptive(light: "#1E8E5A", dark: "#4CC38A")).size(r.f(15, min: 12), r.f(15, min: 12)).at(left + inner - side - r.u(20), cy + r.u(4))) }
        // The two that only read: new times, and a copy of what is set.
        s.tools["refreshdata"] = ("refresh", [:])
        let sideX = narrow ? left : left + inner - side
        let sideY = narrow ? cy + factH * 4 + 6 : cy + r.u(2)
        let sideH = max(r.u(36), 28)
        smallButton(&s, "refreshdata", L("Check for new times"), x: sideX, y: sideY, w: narrow ? inner : side, h: sideH, r: r)
        if let settings {
            nativeButton(&s, Action(L("Copy my settings"), act: .copy(settings)), x: sideX, y: sideY + sideH + 6, w: narrow ? inner : side, h: sideH, r: r)
        }
        cy = narrow ? sideY + (sideH + 6) * (settings == nil ? 1 : 2) : cy + factH * 4 + r.u(6)
        let confirm = ctx.state.bool("confirm_clear") ?? false
        let red = Color.adaptive(light: "#B3261E", dark: "#FF8A80")
        let noteWords = confirm ? L("This removes your place, timetables, saved names and settings from Noor, and cancels its reminders. Sidefolk's own place isn't touched.") : L("Your choices stay here. AlAdhan receives the coordinates, date and conventions needed for an answer; Sidefolk's place search receives what you type. Noor's internet access isn't limited to these by the sandbox: it can reach any address, the local network too.")
        let noteSize = r.f(11.5), noteLines = lineCount(noteWords, width: inner, size: noteSize)
        s.add(Node.text(noteWords, size: noteSize, color: confirm ? red : Noor.muted, align: "leading", valign: "top", lines: noteLines, minScale: 11 / noteSize).size(inner, Double(noteLines) * noteSize * 1.27 + 3).at(left, cy))
        cy += Double(noteLines) * noteSize * 1.27 + max(r.u(10), 7)

        let gap = r.u(12), half = narrow ? inner : (inner - gap) / 2, buttonH = max(r.u(36), 28)
        let firstY = cy, secondX = narrow ? left : left + half + gap, secondY = narrow ? cy + buttonH + 34 : cy
        s.tools["clearcache"] = ("clear_data", ["scope": "cache"])
        smallButton(&s, "clearcache", L("Clear downloaded data"), x: left, y: firstY, w: half, h: buttonH, r: r)
        s.add(Node.say(L("Removes saved answers. They come back when next needed."), left, firstY + buttonH + 2, half, 28, size: r.f(11.5), color: Noor.muted, align: "center", lines: 2))
        if confirm {
            s.tools["deleteall"] = ("clear_data", ["scope": "all"])
            s.acts["keepall"] = .go(Go(set: ["confirm_clear": NSNull()]))
            let delete = (half - gap) * 0.62, keep = half - gap - delete
            smallButton(&s, "keepall", L("Cancel"), x: secondX, y: secondY, w: keep, h: buttonH, r: r)
            smallButton(&s, "deleteall", L("Delete Noor's data"), x: secondX + keep + gap, y: secondY, w: delete, h: buttonH, destructive: true, r: r)
        } else {
            s.acts["confirmall"] = .go(Go(set: ["confirm_clear": true]))
            smallButton(&s, "confirmall", L("Delete Noor's data…"), x: secondX, y: secondY, w: half, h: buttonH, destructive: true, r: r)
            s.add(Node.say(L("Requires confirmation."), secondX, secondY + buttonH + 2, half, 28, size: r.f(11.5), color: Noor.muted, align: "center"))
        }
        return secondY + buttonH + 30 - y
    }

    // MARK: Comparing timetables

    /// One prayer on the same date under the timetable in use and one being considered, each in its own zone. Returns the strip's height.
    private static func comparisonStrip(_ ctx: Context, _ s: inout Sketch, x: Double, y: Double, w: Double, r: Ruler, stack: Bool) -> Double {
        let current = ctx.model.source
        let next = ctx.state.string("compare").flatMap { id in ctx.model.sources.first { $0.id == id && $0.id != current?.id } }
        let prayer: PrayerID = {
            switch ctx.snapshot.next {
            case .prayerStart(let id, _, _), .iqamah(let id, _, _): id
            default: .maghrib
            }
        }()
        let today = ctx.snapshot.localDate
        let oldTime = today.flatMap { ctx.model.day($0) }?.starts[prayer].map { Words.time($0, zone: current?.zone ?? ctx.zone) } ?? "—"
        let nextDay = next.flatMap { SettingsBoard.proposed(ctx, $0) }
        let newTime = next.flatMap { source in nextDay?.starts[prayer].map { Words.time($0, zone: source.zone) } } ?? "—"
        // What it means. The words stay honest about what's known: a calculated source has no times until it's chosen, and no iqamah is ever borrowed.
        var noteHead = L("Nothing changes until you choose.")
        var noteBody = L("Pick another timetable under Calculation source to compare. Your reminder choices stay, and planned reminders move to its times.")
        if let next {
            noteHead = L("Review reminder changes before saving.")
            let missing = ctx.model.prefs.reminders.prayers.contains { $0.value.iqamahMinutes != nil } && (nextDay?.iqamah.isEmpty ?? true)
            noteBody = next.kind == .calculated ? L("Calculated times come from the provider once you switch, then replace what is planned. Your reminder choices stay.") : L("Your reminder choices stay, and planned reminders move to its times.")
            if missing { noteBody += " " + L("This source has no iqamah times, so your iqamah reminders won't come from it. Your choices are kept.") }
        }
        let noteW = stack ? w - r.u(28) : w - r.u(836) - r.u(13)
        let noteSize = r.f(11.5), textW = noteW - r.u(70)
        let noteLines = lineCount(noteBody, width: textW, size: noteSize)
        let buttonsH = next == nil ? 0 : max(r.u(32), 28) + 8
        let noteH = max(r.u(24), 20) + Double(noteLines) * noteSize * 1.27 + buttonsH + 8
        let boxTall = max(r.u(18), 15) * 2 + max(r.u(34), 26) + 8
        let h = stack ? r.u(84) + boxTall + noteH + r.u(14) + 10 : max(next == nil ? r.u(96) : r.u(120), max(noteH, boxTall) + r.u(18))
        s.add(Node.panel(w, h, corner: r.u(13), fill: Noor.quiet, line: Noor.inlay).at(x, y))
        s.add(Node.group {
            panelLattice(r.u(56), h, corner: 0)
            Node.path("M \(n(r.u(56))) 0 L \(n(r.u(56))) \(n(h)) L \(n(r.u(12))) \(n(h)) C \(n(r.u(30))) \(n(h * 0.72)) \(n(r.u(30))) \(n(h * 0.28)) \(n(r.u(12))) 0 Z", fill: Noor.quiet).size(r.u(56), h)
        }
        .size(r.u(56), h).at(x, y).corner(r.u(13)).clip())
        s.add(Node.rect(stroke: Noor.inlay, lineWidth: 1, corner: r.u(13)).size(w, h).at(x, y))
        s.add(Node.symbol("chart.bar.fill", color: Noor.accent).size(r.f(30, min: 22), r.f(30, min: 22)).at(x + r.u(44), y + r.u(24)))
        let wordsW = stack ? w - r.u(110) : r.u(250)
        s.add(Node.say(L("Source-change preview"), x + r.u(97), y + r.u(8), wordsW, max(r.u(26), 20), size: r.f(17.5, min: 13.5), weight: "semibold"))
        s.add(Node.text(L("{prayer} on the same date, each timetable in its own zone.", ["prayer": Words.prayer(prayer)]), size: r.f(13.5, min: 11.5), color: Noor.muted, align: "leading", valign: "top", lines: 3, minScale: 11 / r.f(13.5, min: 11.5)).size(wordsW, h - max(r.u(36), 28) - 4).at(x + r.u(97), y + max(r.u(36), 28)))

        // The two times.
        let boxX = stack ? x + r.u(14) : x + r.u(353), boxY = stack ? y + r.u(88) : y + r.u(10), boxW = stack ? w - r.u(28) : r.u(465), boxH = stack ? boxTall : h - r.u(20)
        s.add(Node.rect(fill: Noor.surface, stroke: Noor.hairline, lineWidth: 1, corner: r.u(11)).size(boxW, boxH).at(boxX, boxY))
        let half = boxW * 0.40, time = r.f(29, min: 20), capH = max(r.u(18), 15), timeH = max(r.u(34), 26), capY = boxY + (boxH - capH * 2 - timeH) / 2
        s.add(Node.say(L("Current · {kind}", ["kind": current?.name ?? Words.sourceKind(current)]), boxX + r.u(24), capY, half, capH, size: r.f(12.5), color: Noor.muted))
        s.add(Node.say(oldTime, boxX + r.u(24), capY + capH, half, timeH, size: time, weight: "medium", tabular: true))
        s.add(Node.symbol("arrow.forward", color: Noor.text).size(r.f(22, min: 16), r.f(18, min: 14)).at(boxX + boxW * 0.47, capY + capH + (timeH - r.f(18, min: 14)) / 2))
        let rightX = boxX + boxW * 0.58, rightW = boxW * 0.40
        s.add(Node.say(next.map { L("New · {kind}", ["kind": $0.name]) } ?? L("New · choose above"), rightX, capY, rightW, capH, size: r.f(12.5), color: Noor.muted))
        s.add(Node.say(newTime, rightX, capY + capH, rightW, timeH, size: time, weight: "medium", color: Noor.accent, tabular: true))
        if let today {
            s.add(Node.say(Words.date(today, weekday: true, year: true), rightX, capY + capH + timeH, rightW, capH, size: r.f(12.5), color: Noor.muted))
        }

        let noteX = stack ? x + r.u(14) : x + r.u(836), noteY = stack ? boxY + boxH + 10 : y + (h - min(h - r.u(16), max(noteH, h - r.u(16)))) / 2, boxNoteH = stack ? noteH : h - r.u(16)
        let amber = Noor.warm
        s.add(Node.rect(fill: Color.adaptive(light: "#FBF1DD", dark: "#241C2E"), stroke: .adaptive(light: "#C9A266", dark: "#C99A55"), lineWidth: 1, corner: r.u(11)).size(noteW, boxNoteH).at(noteX, noteY))
        s.add(Node.symbol("info.circle", color: amber).size(r.f(28, min: 20), r.f(28, min: 20)).at(noteX + r.u(18), noteY + r.u(14)))
        let textX = noteX + r.u(60)
        s.add(Node.say(noteHead, textX, noteY + 3, textW, max(r.u(20), 17), size: r.f(12.5, min: 11), weight: "semibold", color: amber))
        s.add(Node.text(noteBody, size: noteSize, color: Noor.muted, align: "leading", valign: "top", lines: noteLines, minScale: 11 / noteSize).size(textW, Double(noteLines) * noteSize * 1.27 + 3).at(textX, noteY + 3 + max(r.u(20), 17)))
        if let next {
            let useW = textW * 0.66, bh = max(r.u(32), 28), by = noteY + boxNoteH - bh - 6
            s.tools["usesource"] = ("choose_source", ["id": next.id])
            s.acts["keepsource"] = .go(Go(set: ["compare": NSNull()]))
            smallButton(&s, "keepsource", L("Cancel"), x: textX, y: by, w: textW - useW - 8, h: bh, r: r)
            smallButton(&s, "usesource", L("Use {name}", ["name": next.name]), x: textX + textW - useW, y: by, w: useW, h: bh, filled: true, r: r)
        }
        return h
    }

    private static func proposed(_ ctx: Context, _ source: TimetableSource) -> PrayerDay? { PreferencesPage.proposedDay(ctx, source) }

    // MARK: Changing the place

    /// The way to another place, from the panel's "Change place…". The search goes to Sidefolk's place search and nothing else does; saving is the only thing here that changes anything.
    private static func placeEditor(_ ctx: Context) -> [Section] {
        let w = ctx.width, stack = w < 780
        let r = stack ? Ruler(width: 1150) : ctx.ruler
        let margin = stack ? 10 : r.u(21), pw = w - margin * 2
        let picked = ctx.state.string("place_pick")
        let results = Array(ctx.model.placeResults.prefix(10))
        let found = picked.flatMap { id in results.first { $0.id == id } }
        var s = Sketch()
        s.acts["back"] = .go(.backward)
        s.add(Node.group {
            Node.symbol("chevron.backward", color: Noor.text).size(r.f(12), r.f(18)).at(0, r.u(11))
            Node.say(L("Preferences"), r.u(22), 0, r.u(200), r.u(40), size: r.f(17, min: 13), weight: "medium")
        }
        .size(r.u(220), r.u(40)).at(margin + r.u(4), r.u(8))
        .area("back", label: L("Back"), hover: .init(scale: 1.0)))
        let py = r.u(56), rowH = r.u(46), wellH = r.u(44)
        let current = ctx.model.prefs.place
        let notes = (ctx.model.placeProblem != nil ? 1 : 0)
        let preview = found != nil
        let bodyH = r.u(84) + wellH + r.u(16) + Double(notes) * r.u(30) + Double(results.count) * rowH + (preview ? r.u(118) : r.u(8))
        let ph = bodyH + r.u(82)
        frame(&s, x: margin, y: py, w: pw, h: ph, title: L("Change place"), detail: L("Your words go to Sidefolk's place search and nothing else does."), symbol: "pin", medal: "pin", tint: Noor.accent, picked: false, r: r)
        let left = margin + r.u(35), inner = pw - r.u(70)
        var y = py + r.u(82)
        s.add(Node.say(L("Your place"), left, y, r.u(150), r.u(26), size: r.f(14.5, min: 12), color: Noor.muted))
        s.add(Node.say(current.map(PlaceParts.title) ?? L("None chosen"), left + r.u(150), y, inner - r.u(150), r.u(26), size: r.f(16, min: 13), weight: "medium"))
        s.add(Node.say(L("{zone}. {how}", ["zone": current?.zoneID ?? "—", "how": current?.origin == .shared ? L("Following Sidefolk's place") : L("Chosen by you. It stays while you travel.")]), left + r.u(150), y + r.u(26), inner - r.u(150), r.u(22), size: r.f(13, min: 11), color: Noor.muted))
        y += r.u(60)
        s.add(Node.rect(fill: Noor.well, stroke: Noor.edge, lineWidth: 1, corner: r.u(11)).size(inner, wellH).at(left, y))
        s.add(Node.symbol("magnifyingglass", color: Noor.muted).size(r.f(18), r.f(18)).at(left + r.u(14), y + (wellH - r.f(18)) / 2))
        s.inlay(left + r.u(44), y + r.u(6), inner - r.u(60), wellH - r.u(12), .field(L("Search for a city or place"), placeholder: L("Search for a city or place"), button: L("Search"), tool: "search_places", key: "query"))
        y += wellH + r.u(12)
        if let problem = ctx.model.placeProblem {
            s.add(Node.say(problem, left, y, inner, r.u(26), size: r.f(13.5, min: 11.5), color: Noor.warm))
            y += r.u(30)
        }
        for (i, place) in results.enumerated() {
            let on = place.id == picked
            s.acts["r\(i)"] = .go(Go(set: ["place_pick": place.id]))
            s.add(Node.group {
                Node.rect(fill: on ? Noor.picked : Noor.quiet, stroke: on ? Noor.pickedEdge : Noor.hairline, lineWidth: 1, corner: r.u(10)).size(inner, rowH - r.u(5))
                Node.icon(Node.Glyph.pin, color: on ? Noor.onChosen : Noor.muted, side: r.f(18)).at(r.u(14), (rowH - r.u(5) - r.f(18)) / 2)
                Node.say(PlaceParts.title(place), r.u(40), 0, inner - r.u(240), rowH - r.u(5), size: r.f(15, min: 12.5), color: on ? Noor.onChosen : Noor.text)
                Node.say(place.zoneID, inner - r.u(190), 0, r.u(176), rowH - r.u(5), size: r.f(13, min: 11), color: on ? Noor.onChosen : Noor.muted, align: "trailing")
            }
            .size(inner, rowH - r.u(5)).at(left, y)
            .area("r\(i)", label: "\(PlaceParts.title(place)), \(place.zoneID)", hover: .init(scale: 1.0), selected: on))
            y += rowH
        }
        if let found {
            let reminders = ctx.model.planned().count
            let base = L("{place} is at {zone}. Saving sends its coordinates to AlAdhan, and times, the bearing and any reminders move to it.", ["place": found.label, "zone": found.zoneID])
            let words = reminders > 0 ? base + " " + L(one: "{count} planned reminder is replaced.", other: "{count} planned reminders are replaced.", count: reminders) : base
            s.add(Node.text(words, size: r.f(13.5, min: 11.5), color: Noor.muted, align: "leading", valign: "top", lines: 3, minScale: 11 / r.f(13.5, min: 11.5)).size(inner, r.u(56)).at(left, y + r.u(4)))
            y += r.u(60)
            s.tools["saveplace"] = ("choose_place", PlaceParts.input(found))
            s.acts["cancelplace"] = .go(Go(set: ["place_pick": NSNull()]))
            smallButton(&s, "cancelplace", L("Cancel"), x: left + inner - r.u(300), y: y, w: r.u(110), h: r.u(40), r: r)
            smallButton(&s, "saveplace", L("Save place"), x: left + inner - r.u(180), y: y, w: r.u(180), h: r.u(40), filled: true, r: r)
        }
        return [
            Section(nil, [s.block(w, py + ph + r.u(10))], wide: true),
            Section(L("Enter coordinates instead"), PlaceParts.coordinates(ctx), collapsed: true, wide: true),
        ]
    }
}
