import Foundation
import SidefolkExtensionKit

/// C03: what stands in place of a tab's content when it has no times to show, or saved ones. One arch, a medallion in the state's colour, its words, the facts it really has, and what can be done. It never shows a time it doesn't have.
@MainActor
extension NoorPage {
    /// What goes in the panel beyond its words.
    struct StatusPart {
        var symbol: String? = nil
        var rosette = false
        var tint: Color = Noor.warm
        var titleTint: Color = Noor.text
        var title: String
        var subtitle: String? = nil
        var detail: String
        /// Big line, small line under its label, then the source beside it: C03's facts card.
        var facts: (label: String, value: String, sub: String?, rightLabel: String, right: [String])? = nil
        var skeleton = false
        var search = false
        var link: (id: String, words: String)? = nil
        var buttons: [(id: String, label: String, filled: Bool, symbol: String?, act: Act)] = []
    }

    /// The name every tab already uses for its own status.
    static func status(_ ctx: Context, symbol: String, title: String, detail: String, tint: Color = Noor.warm, buttons: [(id: String, label: String, filled: Bool, act: Act)] = []) -> Section {
        statusPanel(ctx, StatusPart(symbol: symbol, tint: tint, title: title, detail: detail, buttons: buttons.map { ($0.id, $0.label, $0.filled, nil, $0.act) }))
    }

    static func statusPanel(_ ctx: Context, _ part: StatusPart, extraActs: [String: PageAct] = [:]) -> Section {
        let w = ctx.width, r = ctx.narrow ? Ruler(width: 860) : ctx.ruler
        let panelW = ctx.narrow ? w - 24 : min(w - r.u(46), r.u(1040)), x = (w - panelW) / 2
        let columnW = ctx.narrow ? panelW - 56 : min(panelW - r.u(150), r.u(620)), cx = x + panelW / 2, columnX = cx - columnW / 2
        let medal = r.u(112)
        var y = max(r.u(58), panelW * 0.075)
        var nodes: [Node] = []
        var wiring = SceneWiring()
        wiring.acts = extraActs

        // The medallion, in the state's colour.
        if part.rosette {
            nodes.append(Node.ellipse(fill: Color.adaptive(light: "#EEE8F5", dark: "#20266E"), stroke: NoorLine.chosen, lineWidth: 1.4).size(medal, medal).at(cx - medal / 2, y))
            nodes.append(Node.image("art/rosette-l.png", dark: "art/rosette-d.png").size(medal * 0.74, medal * 0.74).at(cx - medal * 0.37, y + medal * 0.13).leftToRight())
        } else if let symbol = part.symbol {
            nodes.append(Node.glow(part.tint, cx: cx, cy: y + medal / 2, r: medal * 0.9, opacity: 0.35))
            nodes.append(Node.medallion(symbol, cx: cx, cy: y + medal / 2, d: medal, ink: part.tint, ring: part.tint, glyph: 0.44))
        }
        y += medal + r.u(14)
        nodes.append(Node.say(part.title, columnX - r.u(40), y, columnW + r.u(80), r.u(52), size: r.f(35, min: 19), weight: "medium", color: part.titleTint, align: "center"))
        y += r.u(54)
        if let subtitle = part.subtitle {
            nodes.append(Node.say(subtitle, columnX, y, columnW, r.u(30), size: r.f(21, min: 13), align: "center"))
            y += r.u(34)
        }
        if !part.detail.isEmpty {
            let lines = min(3, lineCount(part.detail, width: columnW, size: r.f(18.5, min: 12)))
            nodes.append(Node.say(part.detail, columnX, y, columnW, r.u(29) * Double(lines) + r.u(4), size: r.f(18.5, min: 12), color: Noor.muted, align: "center", lines: lines))
            y += r.u(29) * Double(lines) + r.u(22)
        }
        if part.skeleton {
            nodes += skeletonRows(x: columnX, y: y, w: columnW, r: r)
            y += r.u(214)
        }
        if let facts = part.facts {
            nodes += factsCard(facts, x: columnX - r.u(12), y: y, w: columnW + r.u(24), r: r)
            y += r.u(132) + r.u(18)
        }
        if part.search {
            let wellH = r.u(62), glyph = r.f(24, min: 15)
            nodes.append(Node.well(columnW, wellH, corner: wellH / 2, fill: Noor.surface, line: NoorLine.chosen).at(columnX, y))
            nodes.append(Node.symbol("magnifyingglass", color: Noor.text).size(glyph, glyph).at(columnX + r.u(26), y + (wellH - glyph) / 2))
            wiring.inlays.append(PageInlay(x: columnX + r.u(64), y: y, w: columnW - r.u(90), h: wellH,
                                           .field(L("Search for a city or place"), placeholder: L("Search for a city, region or country"), button: L("Search"), tool: "search_places", key: "query")))
            y += wellH + r.u(16)
            nodes.append(Node.say(L("or"), columnX, y, columnW, r.u(26), size: r.f(16, min: 11.5), color: Noor.muted, align: "center"))
            nodes.append(Node.rect(fill: NoorLine.soft).size(r.u(30), 1).at(cx - r.u(60), y + r.u(13)))
            nodes.append(Node.rect(fill: NoorLine.soft).size(r.u(30), 1).at(cx + r.u(30), y + r.u(13)))
            y += r.u(40)
        }
        if let link = part.link {
            // The words on the left, the one action they lead to on the right: C03's offline row.
            let glyph = r.f(24, min: 15), buttonW = r.u(150), rowH = r.u(62)
            nodes.append(Node.group {
                Node.symbol("calendar", color: Noor.text).size(glyph, glyph).at(0, (rowH - glyph) / 2)
                Node.say(link.words, glyph + r.u(14), 0, columnW - glyph - buttonW - r.u(30), rowH, size: r.f(16.5, min: 11.5), color: Noor.muted, lines: 2)
            }
            .size(columnW - buttonW - r.u(10), rowH).at(columnX, y)
            .area(link.id, label: link.words, hover: .init(scale: 1.0)))
            if let button = part.buttons.first {
                nodes.append(Node.ctaPill(button.id, label: button.label, x: columnX + columnW - buttonW, y: y + r.u(6), w: buttonW, h: r.u(50), symbol: nil, leading: button.symbol, filled: false, size: r.f(16.5, min: 12)))
                if case .tool(let name, let input) = button.act { wiring.tools[button.id] = (name, input) }
            }
            y += rowH + r.u(16)
        }
        let bw = min(columnW, r.u(530))
        for b in part.buttons.dropFirst(part.link == nil ? 0 : 1) {
            nodes.append(Node.ctaPill(b.id, label: b.label, x: cx - bw / 2, y: y, w: bw, h: r.u(64), symbol: nil, leading: b.symbol, filled: b.filled, size: r.f(19, min: 13)))
            y += r.u(64) + r.u(18)
            switch b.act {
            case .tool(let name, let input): wiring.tools[b.id] = (name, input)
            case .go(let go): wiring.acts[b.id] = .go(go)
            }
        }
        let h = max(y + r.u(92), panelW * 0.74)
        let scene = Scene(width: w, height: h + r.u(14)) {
            Node.archPanel(panelW, h, r: r, feet: false, skyline: min(panelW * 0.26, r.u(210))).at(x, 0)
            nodes
        }
        return Section(nil, [.scene(PageSceneBlock(scene, actions: wiring.tools, acts: wiring.acts, inlays: wiring.inlays))], wide: true)
    }

    private static func factsCard(_ facts: (label: String, value: String, sub: String?, rightLabel: String, right: [String]), x: Double, y: Double, w: Double, r: Ruler) -> [Node] {
        let h = r.u(132), split = w * 0.42
        var out: [Node] = [
            Node.rect(fill: Noor.surface, stroke: NoorLine.soft, lineWidth: 1, corner: r.u(18)).size(w, h).at(x, y),
            Node.rect(fill: NoorLine.soft).size(1, h - r.u(32)).at(x + split, y + r.u(16)),
            Node.say(facts.label, x + r.u(26), y + r.u(14), split - r.u(36), r.u(30), size: r.f(18, min: 12), color: Noor.text),
            Node.say(facts.value, x + r.u(26), y + r.u(42), split - r.u(36), r.u(52), size: r.f(36, min: 20), weight: "medium", tabular: true),
            Node.say(facts.rightLabel, x + split + r.u(26), y + r.u(14), w - split - r.u(40), r.u(28), size: r.f(16.5, min: 11.5), color: Noor.muted),
        ]
        if let sub = facts.sub { out.append(Node.say(sub, x + r.u(26), y + r.u(92), split - r.u(36), r.u(26), size: r.f(15.5, min: 11), color: Noor.muted)) }
        for (i, line) in facts.right.prefix(2).enumerated() {
            out.append(Node.say(line, x + split + r.u(26), y + r.u(46) + Double(i) * r.u(36), w - split - r.u(40), r.u(32), size: r.f(16.5, min: 11.5), color: i == 0 ? Noor.text : Noor.muted))
        }
        return out
    }

    /// Where the times will be, while they come: never a made-up time.
    private static func skeletonRows(x: Double, y: Double, w: Double, r: Ruler) -> [Node] {
        let bar = Color.adaptive(light: "#DAD5EA", dark: "#343A82")
        var out: [Node] = [
            Node.ellipse(fill: bar).size(r.u(58), r.u(58)).at(x, y + r.u(4)),
            Node.capsule(fill: bar).size(w * 0.46, r.u(20)).at(x + r.u(84), y),
            Node.capsule(fill: bar).size(w * 0.68, r.u(20)).at(x + r.u(84), y + r.u(40)),
        ]
        for i in 0..<3 {
            let rowY = y + r.u(90) + Double(i) * r.u(44)
            out.append(Node.ellipse(fill: bar).size(r.u(30), r.u(30)).at(x + r.u(14), rowY))
            out.append(Node.capsule(fill: bar).size(w * 0.42, r.u(18)).at(x + r.u(84), rowY + r.u(6)))
            out.append(Node.capsule(fill: bar).size(w * 0.34, r.u(18)).at(x + w * 0.66, rowY + r.u(6)))
        }
        return out.map { $0.opacity(0.75) }
    }

    /// What every tab says the same way when it has no times to show. Nil when it does.
    static func unavailable(_ ctx: Context) -> Section? {
        let s = ctx.snapshot
        let danger = NoorLine.danger, caution = NoorLine.caution
        switch s.validity {
        case .ready, .offlineValid:
            return nil
        case .noPlace:
            return statusPanel(ctx, StatusPart(symbol: Node.Glyph.pin, tint: Noor.text, title: L("Choose a place"), detail: L("Set your city to show prayer times, the calendar and Qibla direction."), search: true,
                                               buttons: [("shared", L("Use Sidefolk's place"), false, "location", .go(Go(set: ["setup": "place", "place_mode": "shared"], push: true)))]))
        case .noSource:
            return statusPanel(ctx, StatusPart(symbol: Node.Glyph.arch, tint: Noor.text, title: L("Choose your timetable"), detail: L("Calculated for your place, or your mosque's own. There is no one right method: pick what your community follows."),
                                               buttons: [("source", L("Choose your timetable"), true, "arrow.forward", .go(Go(set: ["setup": "source"], push: true)))]))
        case .loading:
            return statusPanel(ctx, StatusPart(rosette: true, title: L("Loading timetable"), detail: s.place.map { L("Fetching prayer times for {place}…", ["place": $0.label]) } ?? "", skeleton: true))
        case .expired:
            let end = s.coverage.map { Words.date($0.upperBound, weekday: false) } ?? ""
            let yesterday = s.coverage?.upperBound == s.localDate?.previous
            return statusPanel(ctx, StatusPart(symbol: "exclamationmark", tint: caution, titleTint: Noor.warm, title: yesterday ? L("Timetable ended yesterday") : L("This timetable has ended"), detail: L("The saved timetable finished on {date}. Nothing new is reminded from it until you update it.", ["date": end]),
                                               buttons: [("update", L("Update timetable"), true, "arrow.triangle.2.circlepath", .go(Go(set: ["sheet": "prefs", "section": "sources"], push: true))),
                                                         ("calculated", L("Choose calculated times"), false, "tablecells", .tool("use_calculated"))]))
        case .notStarted:
            let start = s.coverage.map { Words.date($0.lowerBound, weekday: false) } ?? ""
            return statusPanel(ctx, StatusPart(symbol: "calendar", tint: Noor.text, title: L("This timetable hasn't started"), detail: L("It begins on {date}. Until then there are no times from it.", ["date": start]),
                                               buttons: [("sources", L("Choose another timetable"), true, "arrow.forward", .go(Go(set: ["sheet": "prefs", "section": "sources"], push: true)))]))
        case .error:
            // Nothing was saved, so no sentence here may lean on a saved copy.
            let why: String
            switch ctx.model.problem {
            case .offline: why = L("No connection, and no times saved for today yet. Try again once you're online.")
            default: why = Words.problem(ctx.model.problem).isEmpty ? L("The provider didn't answer.") : Words.problem(ctx.model.problem)
            }
            return statusPanel(ctx, StatusPart(symbol: "wifi.slash", tint: danger, title: L("Couldn't get this timetable"), detail: why,
                                               buttons: [("retry", L("Try again"), true, "arrow.clockwise", .tool("refresh"))]))
        }
    }

    /// An older copy still answers for today: C03's offline and couldn't-refresh panels, until the person says the saved times will do. Then the page, under its strip.
    static func savedTimes(_ ctx: Context) -> Section? {
        let s = ctx.snapshot
        guard s.validity == .offlineValid || (s.validity == .ready && ctx.model.load == .failed), ctx.state.bool("saved_ok") != true else { return nil }
        let date = s.localDate.map { Words.date($0, weekday: false, year: false) } ?? ""
        let fetched = ctx.model.fetchedAt.map { Format.dateTime($0, timeZone: ctx.zone) }
        let keep: (id: String, label: String, filled: Bool, symbol: String?, act: Act) = ("keep", L("Keep using saved times"), false, nil, .go(Go(set: ["saved_ok": true])))
        let source = (rightLabel: L("Source"), right: [Words.provenance(s)] + (fetched.map { [L("Fetched {when}", ["when": $0])] } ?? []))
        if s.validity == .offlineValid {
            let focus = DialScene.focus(s)
            return statusPanel(ctx, StatusPart(symbol: "wifi", tint: NoorLine.caution, titleTint: Noor.warm, title: L("Offline"), subtitle: L("Saved times for {date}", ["date": date]), detail: L("You're offline. Showing the last downloaded times."),
                                               facts: (focus?.title ?? L("Next prayer"), focus?.time ?? "—", nil, source.rightLabel, source.right),
                                               link: ("prayer", L("Other prayer times for {date} are available.", ["date": date])),
                                               buttons: [("refresh", L("Refresh"), true, "arrow.clockwise", .tool("refresh")), keep]),
                               extraActs: ["prayer": .go(Go(set: ["tab": "prayer"]))])
        }
        let why = Words.problem(ctx.model.problem, saved: true).isEmpty ? L("The provider is unavailable. Showing your last downloaded times.") : Words.problem(ctx.model.problem, saved: true)
        let parts = ctx.model.fetchedAt.map { (Format.date($0, year: true, timeZone: ctx.zone), Format.time($0, timeZone: ctx.zone)) }
        return statusPanel(ctx, StatusPart(symbol: "wifi.slash", tint: NoorLine.danger, title: L("Couldn't refresh this source"), detail: why,
                                           facts: (L("Last successful sync"), parts?.0 ?? "—", parts?.1, source.rightLabel, [Words.provenance(s)]),
                                           buttons: [("retry", L("Retry"), true, "arrow.clockwise", .tool("refresh")), keep]))
    }

    /// What the head's second line says while a state stands, in place of where the times come from.
    static func headLine(_ ctx: Context) -> String? {
        let s = ctx.snapshot
        switch s.validity {
        case .noPlace: return L("Choose a place to get started")
        case .noSource: return L("Choose your timetable")
        case .loading: return L("Loading timetable")
        case .expired: return s.coverage?.upperBound == s.localDate?.previous ? L("Timetable ended yesterday") : L("Timetable ended")
        case .notStarted: return L("Timetable hasn't started")
        case .error: return L("Couldn't get this timetable")
        case .offlineValid: return L("Offline · Saved times for {date}", ["date": s.localDate.map { Words.date($0, weekday: false, year: false) } ?? ""])
        case .ready: return ctx.model.load == .failed ? L("Couldn't refresh this source") : nil
        }
    }

    /// A strip that says the times shown were saved earlier: an older copy still answers for today, so it isn't an error, only worth knowing.
    static func offlineNote(_ ctx: Context) -> Block? {
        guard ctx.snapshot.validity == .offlineValid || ctx.model.load == .failed || ctx.model.load == .offline else { return nil }
        let saved = ctx.model.fetchedAt.map { Format.dateTime($0, timeZone: ctx.zone) }
        let text = saved.map { L("Offline. Showing times saved {when}.", ["when": $0]) } ?? L("Offline. Showing saved times.")
        let words = ctx.model.problem == .offline || ctx.model.load == .offline ? text : (Words.problem(ctx.model.problem, saved: true).isEmpty ? text : Words.problem(ctx.model.problem, saved: true))
        let w = ctx.width, r = ctx.narrow ? Ruler(width: 860) : ctx.ruler
        let margin = ctx.narrow ? 16 : r.u(28), inner = w - margin * 2, h = ctx.narrow ? 56 : r.u(56)
        let buttonW = ctx.narrow ? 92 : r.u(136)
        let scene = Scene(width: w, height: h + r.u(10)) {
            Node.rect(fill: Noor.surface, stroke: NoorLine.caution, lineWidth: 1, corner: r.u(14)).size(inner, h).at(margin, 0)
            Node.symbol("wifi", color: NoorLine.caution).size(r.f(20, min: 14), r.f(20, min: 14)).at(margin + r.u(18), (h - r.f(20, min: 14)) / 2)
            Node.say(words, margin + r.u(18) + r.f(20, min: 14) + r.u(12), 0, inner - buttonW - r.u(70), h, size: r.f(15.5, min: 11.5), color: Noor.warm, lines: 2)
            Node.pill("refresh", label: L("Refresh"), x: margin + inner - buttonW - r.u(10), y: (h - r.u(38)) / 2, w: buttonW, h: r.u(38), size: r.f(14.5, min: 11.5))
        }
        return .scene(PageSceneBlock(scene, actions: ["refresh": ("refresh", [:])]))
    }
}
