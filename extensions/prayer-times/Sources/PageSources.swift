import Foundation
import SidefolkExtensionKit

/// F02: which timetable, and a mosque's own by hand or from a file that is looked over before anything is kept. The same board in first run and in Preferences: two panels where they fit, one above the other where they don't.
@MainActor
enum SourcePage {
    // MARK: What a page holds

    /// Calculated, or a mosque's timetable by hand or from a file. No directory of mosques: nothing here pretends to one.
    static func sections(_ ctx: Context) -> [Section] {
        if ctx.model.review != nil { return review(ctx) }
        return two(ctx, right: { w, h, ox, oy, r, wiring in guide(ctx, w: w, h: h, ox: ox, oy: oy, r: r, wiring: &wiring) })
    }

    /// What the file holds, for looking over: nothing is saved until Add, and Cancel leaves no source.
    static func review(_ ctx: Context) -> [Section] {
        guard ctx.model.review != nil else {
            return [NoorPage.status(ctx, symbol: "doc", title: L("There's no file being looked at."), detail: "", tint: Noor.text, buttons: [("back", L("Back"), false, .go(.backward))])]
        }
        return two(ctx, right: { w, h, ox, oy, r, wiring in check(ctx, w: w, h: h, ox: ox, oy: oy, r: r, wiring: &wiring) }, rightFirst: true)
    }

    /// Choosing a file, a button that says so.
    private static func importButton(first: Bool) -> Block {
        .action(Action(first ? L("Import a CSV file") : L("Choose another file"), act: .file(tool: "import_csv", param: "path", types: ["csv", "txt"]), symbol: first ? "square.and.arrow.down" : "doc"))
    }

    private static var copyButton: Block { .action(Action(L("Copy a CSV template"), act: .copy(CSVImport.template), style: .plain, symbol: "doc.on.doc")) }

    private static func mosqueChosen(_ ctx: Context) -> Bool {
        let manual = ctx.model.source?.kind == .manual || ctx.model.review != nil || ctx.state.string("sheet") == "import"
        return (ctx.state.string("src_kind") ?? (manual ? "mosque" : "calculated")) == "mosque"
    }

    /// As tall as the board's panels where two stand side by side; stacked, each is only what it holds.
    private static func least(_ ctx: Context, _ r: Ruler) -> Double { ctx.narrow ? 0 : r.u(720) }

    /// A native button over the pill drawn for it: a scene's area may only move around the page or run a tool (host D105, D109).
    private static func slot(_ part: Block, x: Double, y: Double, w: Double, h: Double, ox: Double, oy: Double, wiring: inout SceneWiring) -> Node {
        wiring.inlays.append(PageInlay(x: ox + x, y: oy + y, w: w, h: h, part))
        return Node.capsule(fill: Noor.quiet, stroke: Noor.edge, lineWidth: 1.2).size(w, h).at(x, y)
    }

    private typealias Panel = (_ w: Double, _ h: Double?, _ ox: Double, _ oy: Double, _ r: Ruler, _ wiring: inout SceneWiring) -> (node: Node, height: Double)

    private static func two(_ ctx: Context, left: Panel? = nil, right: @escaping Panel, rightFirst: Bool = false) -> [Section] {
        let w = ctx.width
        let left: Panel = left ?? { w, h, ox, oy, r, wiring in chooser(ctx, w: w, h: h, ox: ox, oy: oy, r: r, wiring: &wiring) }
        if ctx.narrow {
            // One above the other, what is being looked at first, a scene each: together they could pass a scene's tallest size.
            let margin = 16.0, inner = w - margin * 2
            let r = Ruler(width: inner / 621 * 1290)
            return (rightFirst ? [right, left] : [left, right]).map { panel in
                var skip = SceneWiring(), wiring = SceneWiring()
                let height = panel(inner, nil, margin, 0, r, &skip).height
                let drawn = panel(inner, height, margin, 0, r, &wiring)
                let scene = Scene(width: w, height: height + 12) { drawn.node.at(margin, 0) }
                return Section(nil, [.scene(PageSceneBlock(scene, actions: wiring.tools, acts: wiring.acts, inlays: wiring.inlays))], wide: true)
            }
        }
        let r = ctx.ruler, margin = r.u(23), gap = r.u(17)
        let leftW = (w - margin * 2 - gap) * 0.504, rightW = w - margin * 2 - gap - leftW, rightX = margin + leftW + gap
        var skip = SceneWiring(), wiring = SceneWiring()
        let h = max(left(leftW, nil, margin, 0, r, &skip).height, right(rightW, nil, rightX, 0, r, &skip).height)
        let a = left(leftW, h, margin, 0, r, &wiring), b = right(rightW, h, rightX, 0, r, &wiring)
        let scene = Scene(width: w, height: h + r.u(14)) {
            a.node.at(margin, 0)
            b.node.at(rightX, 0)
        }
        return [Section(nil, [.scene(PageSceneBlock(scene, actions: wiring.tools, acts: wiring.acts, inlays: wiring.inlays))], wide: true)]
    }

    /// The boards' panel: a rim of lattice inside its line, the plate standing on it, and the lattice coming in at each corner, widest at the top where the title makes way for it.
    private static func panelChrome(_ w: Double, _ h: Double, r: Ruler) -> Node {
        let rim = r.u(7), side = r.u(120), low = r.u(66), corner = r.u(18)
        return Node.group {
            Node.image("art/lattice-l.jpg", dark: "art/panel-lattice-d.jpg", fit: "cover").size(w, h).corner(corner).clip().opacity(0.75)
            Node.rect(fill: Color.adaptive(light: "#FFFFFF", dark: "#0B1640"), stroke: Color.adaptive(light: "#C9AB72", dark: "#B55A4E"), lineWidth: 1, corner: r.u(13)).size(w - rim * 2, h - rim * 2).at(rim, rim)
            Node.group {
                Node.image("art/corner-l.png", dark: "art/corner-d.png", fit: "contain").size(side, side).at(w - side, 0)
                Node.image("art/corner-l.png", dark: "art/corner-d.png", fit: "contain").size(side, side).at(0, 0).scale(x: -1, y: 1)
                Node.image("art/corner-l.png", dark: "art/corner-d.png", fit: "contain").size(low, low).at(w - low, h - low).scale(x: 1, y: -1)
                Node.image("art/corner-l.png", dark: "art/corner-d.png", fit: "contain").size(low, low).at(0, h - low).scale(x: -1, y: -1)
            }
            .size(w, h).corner(corner).clip().opacity(0.85)
            Node.rect(stroke: Color.adaptive(light: "#C9AB72", dark: "#C47F6A"), lineWidth: 1.2, corner: corner).size(w, h)
        }
        .size(w, h)
    }

    /// The way back, on a plate of its own: it stands where the corner's lattice comes in, and a bleed page has no host Back to see.
    private static func backMark(_ act: PageAct, r: Ruler, wiring: inout SceneWiring) -> Node {
        wiring.acts["back"] = act
        let d = r.u(32), glyphW = r.f(10, min: 8), glyphH = r.f(16, min: 12)
        return Node.group {
            Node.ellipse(fill: Noor.quiet, stroke: NoorLine.soft, lineWidth: 1).size(d, d).at(0, 0)
            Node.symbol("chevron.backward", color: Noor.text).size(glyphW, glyphH).at((d - glyphW) / 2 - r.u(1), (d - glyphH) / 2)
        }
        .size(d, d).at(r.u(14), r.u(26))
        .area("back", label: L("Back"), hover: .init(scale: 1.05))
    }

    private static func heading(_ title: String, _ detail: String, r: Ruler, w: Double) -> [Node] {
        [Node.say(title, r.u(52), r.u(18), w - r.u(120), r.u(48), size: r.f(30, min: 18), weight: "medium"),
         Node.say(detail, r.u(52), r.u(62), w - r.u(120), r.u(28), size: r.f(17.5, min: 11.5), color: Noor.muted)]
    }

    // MARK: Choose your timetable

    private static func chooser(_ ctx: Context, w: Double, h: Double?, ox: Double, oy: Double, r: Ruler, wiring: inout SceneWiring) -> (node: Node, height: Double) {
        let mosque = mosqueChosen(ctx)
        wiring.acts["kind-calculated"] = .go(Go(set: ["src_kind": "calculated"]))
        wiring.acts["kind-mosque"] = .go(Go(set: ["src_kind": "mosque"]))
        let x = r.u(21), inner = w - x * 2
        var nodes = heading(L("Choose your timetable"), L("Select where your prayer times come from."), r: r, w: w)
        // First run goes back a step, anywhere else to where this was opened from.
        nodes.append(backMark(ctx.state.string("sheet") == nil ? .go(Go(set: ["setup": "place"])) : .go(.backward), r: r, wiring: &wiring))
        let gap = r.u(12), cardW = (inner - gap) / 2, cardH = r.u(120), cardY = r.u(101)
        nodes.append(kindCard("kind-calculated", symbol: Node.Glyph.pin, title: L("Calculated for my place"), detail: L("Times calculated for your place by AlAdhan, with a method you choose."), on: !mosque, x: x, y: cardY, w: cardW, h: cardH, r: r))
        nodes.append(kindCard("kind-mosque", symbol: Node.Glyph.arch, title: L("My mosque's timetable"), detail: L("A timetable from your own mosque, entered by you or from a file."), on: mosque, x: x + cardW + gap, y: cardY, w: cardW, h: cardH, r: r))
        var y = cardY + cardH + r.u(20)
        if mosque {
            mosquePart(ctx, x: x, w: inner, y: &y, ox: ox, oy: oy, r: r, nodes: &nodes, wiring: &wiring)
        } else {
            calculatedPart(ctx, x: x, w: inner, y: &y, ox: ox, oy: oy, r: r, nodes: &nodes, wiring: &wiring)
        }
        let buttonH = r.u(52)
        let height = max(y + buttonH + r.u(30), least(ctx, r))
        let foot = (h ?? height) - buttonH - r.u(22)
        if mosque {
            let picked = pick(ctx)
            let current = picked?.id == ctx.model.prefs.sourceID
            if let picked { wiring.tools["use"] = ("choose_source", ["id": picked.id]) }
            let mainW = inner * 0.56
            nodes.append(Node.ctaPill("use", label: L("Use selected timetable"), x: x, y: foot, w: mainW, h: buttonH, symbol: "chevron.forward", disabled: picked == nil || current, size: r.f(17, min: 12)))
            nodes.append(slot(importButton(first: true), x: x + mainW + r.u(14), y: foot, w: inner - mainW - r.u(14), h: buttonH, ox: ox, oy: oy, wiring: &wiring))
        } else {
            let method = ctx.state.string("d_method") ?? ctx.model.prefs.convention.map { "\($0.method)" } ?? ""
            let ready = !method.isEmpty && ctx.model.prefs.place != nil
            // Already what is in use, there is nothing for it to do.
            let inUse = ctx.model.source?.kind == .calculated && method == ctx.model.prefs.convention.map { "\($0.method)" }
            wiring.tools["use"] = ("use_calculated", ["method": Int(method) ?? -1])
            nodes.append(Node.ctaPill("use", label: L("Use calculated times"), x: x, y: foot, w: inner, h: buttonH, disabled: !ready || inUse, size: r.f(17, min: 12)))
        }
        let finalH = h ?? height
        return (Node.group {
            panelChrome(w, finalH, r: r)
            nodes
        }
        .size(w, finalH), height)
    }

    private static func kindCard(_ id: String, symbol: String, title: String, detail: String, on: Bool, x: Double, y: Double, w: Double, h: Double, r: Ruler) -> Node {
        let glyph = r.f(30, min: 18)
        return Node.group {
            Node.rect(fill: on ? Color.adaptive(light: "#F3EEFA", dark: "#23206A") : Noor.quiet, stroke: on ? NoorLine.chosen : NoorLine.soft, lineWidth: on ? 1.6 : 1, corner: r.u(14)).size(w, h)
            Node.radio(cx: r.u(26), cy: r.u(30), d: r.u(21), on: on)
            Node.icon(symbol, color: Noor.text, side: glyph).at(r.u(50), r.u(14))
            Node.say(title, r.u(92), r.u(16), w - r.u(100), r.u(30), size: r.f(16.5, min: 11.5), weight: "medium")
            Node.say(detail, r.u(92), r.u(46), w - r.u(104), r.u(66), size: r.f(14, min: 10.5), color: Noor.muted, lines: 3)
        }
        .size(w, h).at(x, y)
        .area(id, label: title, hover: .init(scale: 1.008), selected: on)
    }

    private static func pick(_ ctx: Context) -> TimetableSource? {
        let saved = ctx.model.sources.filter { $0.kind == .manual }
        if let id = ctx.state.string("src_pick"), let found = saved.first(where: { $0.id == id }) { return found }
        return saved.first { $0.id == ctx.model.prefs.sourceID } ?? saved.first
    }

    /// Five rows, the rest in a menu, the picked one always among the rows.
    private static func rows(_ saved: [TimetableSource], picked: TimetableSource?) -> [TimetableSource] {
        var shown = Array(saved.prefix(5))
        if let picked, !shown.contains(where: { $0.id == picked.id }) { shown[shown.count - 1] = picked }
        return shown
    }

    private static func mosquePart(_ ctx: Context, x: Double, w: Double, y: inout Double, ox: Double, oy: Double, r: Ruler, nodes: inout [Node], wiring: inout SceneWiring) {
        let saved = ctx.model.sources.filter { $0.kind == .manual }
        let picked = pick(ctx), removing = ctx.state.string("src_remove")
        nodes.append(Node.say(L("Saved timetables"), x + r.u(2), y, w, r.u(28), size: r.f(17, min: 12), weight: "medium"))
        y += r.u(32)
        if saved.isEmpty {
            nodes.append(Node.group {
                Node.rect(fill: Noor.quiet, stroke: NoorLine.soft, lineWidth: 1, corner: r.u(12), dash: [3, 4]).size(w, r.u(58))
                Node.symbol("tray", color: Noor.muted).size(r.f(22, min: 14), r.f(22, min: 14)).at(r.u(20), (r.u(58) - r.f(22, min: 14)) / 2)
                Node.say(L("No saved timetables"), r.u(58), 0, w - r.u(70), r.u(58), size: r.f(15.5, min: 11.5), color: Noor.muted)
            }
            .size(w, r.u(58)).at(x, y))
            y += r.u(68)
        }
        let shown = rows(saved, picked: picked)
        for (i, source) in shown.enumerated() {
            let on = source.id == picked?.id, inUse = source.id == ctx.model.prefs.sourceID, rowH = r.u(60)
            wiring.acts["src-\(i)"] = .go(Go(set: ["src_pick": source.id]))
            var detail = [Words.sourceKind(source)]
            if source.zoneID != ctx.model.prefs.place?.zoneID { detail.append(source.zoneID) }
            if let coverage = source.coverage { detail.append(L("Valid to {date}", ["date": Words.date(coverage.upperBound, weekday: false)])) }
            let chipW = r.u(82), wordsW = w - r.u(106) - r.u(56) - (inUse ? chipW + r.u(8) : 0)
            nodes.append(Node.group {
                Node.rect(fill: on ? Color.adaptive(light: "#F3EEFA", dark: "#23206A") : Noor.quiet, stroke: on ? NoorLine.chosen : NoorLine.soft, lineWidth: 1, corner: r.u(12)).size(w, rowH)
                Node.radio(cx: r.u(29), cy: rowH / 2, d: r.u(23), on: on)
                Node.archIcon(side: r.f(24, min: 15), color: Noor.text).at(r.u(62), (rowH - r.f(24, min: 15)) / 2)
                Node.say(source.name, r.u(106), r.u(7), wordsW, r.u(26), size: r.f(16, min: 11.5))
                Node.say(detail.joined(separator: " · "), r.u(106), r.u(31), wordsW, r.u(24), size: r.f(13.5, min: 10.5), color: Noor.muted)
                if inUse { Node.chip(L("In use"), x: w - r.u(56) - chipW, y: (rowH - r.u(30)) / 2, w: chipW, h: r.u(30), size: r.f(13, min: 10.5)) }
            }
            .size(w, rowH).at(x, y)
            .area("src-\(i)", label: inUse ? L("{name}, in use", ["name": source.name]) : source.name, hover: .init(scale: 1.005), selected: on))
            wiring.acts["remove-\(i)"] = .go(Go(set: ["src_remove": removing == source.id ? NSNull() : source.id]))
            nodes.append(Node.group { Node.symbol("ellipsis", color: Noor.text).size(r.f(18, min: 13), r.f(18, min: 13)).at(r.u(10), r.u(10)) }
                .size(r.u(38), r.u(38)).at(x + w - r.u(50), y + (rowH - r.u(38)) / 2)
                .area("remove-\(i)", label: L("Remove {name}", ["name": source.name])))
            y += rowH + r.u(6)
            // Removing asks once more, in place: it takes its saved times with it.
            if removing == source.id {
                wiring.tools["remove-yes"] = ("remove_source", ["id": source.id])
                wiring.acts["remove-no"] = .go(Go(set: ["src_remove": NSNull()]))
                let bandH = r.u(84), yesW = r.u(100), noW = r.u(78), wordsW = w - yesW - noW - r.u(50)
                nodes.append(Node.rect(fill: Noor.quiet, stroke: NoorLine.danger, lineWidth: 1, corner: r.u(12)).size(w, bandH).at(x, y))
                nodes.append(Node.say(L("Remove {name}?", ["name": source.name]), x + r.u(16), y + r.u(8), wordsW, r.u(26), size: r.f(15, min: 11.5), weight: "medium"))
                nodes.append(Node.say(inUse ? L("Removes its saved times. Noor goes back to calculated times if a method is set.") : L("Removes its saved times."), x + r.u(16), y + r.u(32), wordsW, r.u(46), size: r.f(13.5, min: 10.5), color: Noor.muted, lines: 2))
                nodes.append(dangerPill("remove-yes", label: L("Remove"), spoken: L("Remove {name}", ["name": source.name]), x: x + w - yesW - noW - r.u(22), y: y + (bandH - r.u(36)) / 2, w: yesW, h: r.u(36), size: r.f(13.5, min: 10.5)))
                nodes.append(Node.pill("remove-no", label: L("Keep"), x: x + w - noW - r.u(12), y: y + (bandH - r.u(36)) / 2, w: noW, h: r.u(36), size: r.f(13.5, min: 10.5)))
                y += bandH + r.u(6)
            }
        }
        let rest = saved.filter { source in !shown.contains { $0.id == source.id } }
        if !rest.isEmpty {
            // The rest, in the system's own menu over a drawn row.
            let moreH = r.u(44), words = L("More timetables ({count})", ["count": Format.integer(rest.count)])
            nodes.append(Node.well(w, moreH, corner: r.u(10), fill: Noor.quiet).at(x, y))
            nodes.append(Node.say(words, x + r.u(24), y, w - r.u(80), moreH, size: r.f(15, min: 11.5)))
            nodes.append(Node.symbol("chevron.up.chevron.down", color: Noor.muted).size(r.f(14), r.f(14)).at(x + w - r.u(34), y + (moreH - r.f(14)) / 2))
            wiring.inlays.append(PageInlay(x: ox + x, y: oy + y, w: w, h: moreH, .draftChoice(words, options: rest.map { Option($0.id, $0.name, detail: Words.sourceKind($0)) }, selected: picked?.id ?? "", key: "src_pick", style: .rows)))
            y += moreH + r.u(6)
        }
        y += r.u(12)
        nodes.append(Node.say(L("Supported feeds"), x + r.u(2), y, w, r.u(28), size: r.f(16, min: 11.5)))
        y += r.u(30)
        let feedH = r.u(76)
        nodes.append(Node.group {
            Node.well(w, feedH, corner: r.u(12), fill: Noor.quiet)
            Node.symbol("cylinder.split.1x2", color: Noor.text).size(r.f(26, min: 16), r.f(26, min: 16)).at(r.u(24), (feedH - r.f(26, min: 16)) / 2)
            Node.say(L("No validated feed is connected. Noor doesn't follow any mosque automatically, and doesn't use anyone's private API."), r.u(74), 0, w - r.u(92), feedH, size: r.f(14.5, min: 11), color: Noor.muted, lines: 2)
        }
        .size(w, feedH).at(x, y))
        y += feedH + r.u(12)
        if let picked {
            preview(ctx, picked, x: x, w: w, y: &y, r: r, nodes: &nodes)
        } else {
            noTimes(L("A saved timetable's times show here."), x: x, w: w, y: &y, r: r, nodes: &nodes)
        }
    }

    /// An outline in the danger colour, for the one thing here that can't be taken back.
    private static func dangerPill(_ id: String, label: String, spoken: String, x: Double, y: Double, w: Double, h: Double, size: Double) -> Node {
        Node.group {
            Node.capsule(fill: Noor.quiet, stroke: NoorLine.danger, lineWidth: 1.2).size(w, h).at(0, 0)
            Node.say(label, 8, 0, w - 16, h, size: size, weight: "medium", color: NoorLine.danger, align: "center")
        }
        .size(w, h).at(x, y)
        .area(id, label: spoken)
    }

    /// A day from the picked timetable, read from what is saved: today's if it covers today, otherwise its first.
    private static func preview(_ ctx: Context, _ source: TimetableSource, x: Double, w: Double, y: inout Double, r: Ruler, nodes: inout [Node]) {
        guard case .ok(let table) = ctx.model.store.timetable(sourceID: source.id) else { return }
        let today = CivilDate(ctx.snapshot.now, in: source.zone)
        let date = source.coverage.map { $0.contains(today) ? today : $0.lowerBound } ?? today
        guard case .success(let day) = table.day(on: date) else { return }
        let chip = source.kind == .manual ? (L("Manual"), "pencil") : (L("Calculated"), "function")
        nodes.append(timesBox(L("Source preview"), L("Sample times from {name}", ["name": source.name]), chip: chip, corner: L("Date"), rows: [(Words.dateShort(date), day, source.zone)], w: w, r: r).at(x, y))
        y += timesHeight(rows: 1, r: r) + r.u(12)
    }

    private static func timesHeight(rows: Int, r: Ruler) -> Double { r.u(60 + 36 + 38 * Double(rows) + 12) }

    /// The boards' table of a day's five times under a title: a row each for what is being read or compared.
    private static func timesBox(_ title: String, _ detail: String, chip: (words: String, symbol: String)?, corner: String, rows: [(label: String, day: PrayerDay?, zone: TimeZone)], w: Double, r: Ruler) -> Node {
        let boxH = timesHeight(rows: rows.count, r: r), head = r.u(36), row = r.u(38), top = r.u(60)
        let tx = r.u(14), tw = w - tx * 2, first = tw * 0.25, col = (tw - first) / Double(PrayerID.allCases.count)
        return Node.group {
            Node.well(w, boxH, corner: r.u(12), fill: Noor.quiet)
            Node.say(title, r.u(18), r.u(8), w * 0.6, r.u(26), size: r.f(16.5, min: 12), weight: "medium")
            Node.say(detail, r.u(18), r.u(32), w * 0.66, r.u(22), size: r.f(13.5, min: 10.5), color: Noor.muted)
            if let chip { Node.chip(chip.words, symbol: chip.symbol, x: w - r.u(130), y: r.u(12), w: r.u(116), h: r.u(32), size: r.f(13, min: 10.5)) }
            Node.rect(fill: Noor.surface, stroke: NoorLine.soft, lineWidth: 1, corner: r.u(8)).size(tw, head + row * Double(rows.count)).at(tx, top)
            for i in 0..<rows.count { Node.rect(fill: NoorLine.soft).size(tw, 1).at(tx, top + head + row * Double(i)) }
            for i in 0..<PrayerID.allCases.count { Node.rect(fill: NoorLine.soft).size(1, head + row * Double(rows.count)).at(tx + first + Double(i) * col, top) }
            Node.say(corner, tx + r.u(14), top, first - r.u(18), head, size: r.f(13.5, min: 10.5), color: Noor.muted)
            for (i, id) in PrayerID.allCases.enumerated() {
                Node.say(Words.prayer(id), tx + first + Double(i) * col, top, col, head, size: r.f(13.5, min: 10), color: Noor.muted, align: "center")
            }
            for (n, line) in rows.enumerated() {
                let ry = top + head + row * Double(n)
                Node.say(line.label, tx + r.u(14), ry, first - r.u(18), row, size: r.f(14, min: 10.5))
                for (i, id) in PrayerID.allCases.enumerated() {
                    Node.say(line.day?.starts[id].map { Words.time($0, zone: line.zone) } ?? "—", tx + first + Double(i) * col, ry, col, row, size: r.f(14, min: 10.5), align: "center", tabular: true)
                }
            }
        }
        .size(w, boxH)
    }

    private static func calculatedPart(_ ctx: Context, x: Double, w: Double, y: inout Double, ox: Double, oy: Double, r: Ruler, nodes: inout [Node], wiring: inout SceneWiring) {
        let method = ctx.state.string("d_method") ?? ctx.model.prefs.convention.map { "\($0.method)" } ?? ""
        nodes.append(Node.say(L("Calculation method"), x + r.u(2), y, w, r.u(28), size: r.f(17, min: 12), weight: "medium"))
        y += r.u(32)
        let wellH = r.u(52)
        let methods = ctx.model.prayerMethods.filter { $0.id != 99 }
        if methods.isEmpty {
            let words = ctx.model.load == .loading ? L("Loading the methods…") : (Words.problem(ctx.model.problem).isEmpty ? L("The list of methods isn't here yet.") : Words.problem(ctx.model.problem))
            nodes.append(Node.well(w, wellH, corner: r.u(10), fill: Noor.quiet).at(x, y))
            nodes.append(Node.say(words, x + r.u(18), y, w - r.u(170), wellH, size: r.f(15, min: 11.5), color: Noor.muted, lines: 2))
            wiring.tools["methods-retry"] = ("refresh", [:])
            nodes.append(Node.pill("methods-retry", label: L("Try again"), x: x + w - r.u(142), y: y + r.u(8), w: r.u(130), h: r.u(36), symbol: "arrow.clockwise", size: r.f(13.5, min: 10.5)))
        } else {
            let name = methods.first { "\($0.id)" == method }?.name
            nodes.append(Node.well(w, wellH, corner: r.u(10), fill: Noor.quiet).at(x, y))
            nodes.append(Node.say(name ?? L("Choose a method first."), x + r.u(18), y, w - r.u(60), wellH, size: r.f(16, min: 11.5), color: name == nil ? Noor.muted : Noor.text))
            nodes.append(Node.symbol("chevron.up.chevron.down", color: Noor.muted).size(r.f(15), r.f(15)).at(x + w - r.u(34), y + (wellH - r.f(15)) / 2))
            wiring.inlays.append(PageInlay(x: ox + x, y: oy + y, w: w, h: wellH, .draftChoice(L("Calculation method"), detail: L("From the provider's list, in its order."), options: methods.prefix(24).map { Option("\($0.id)", $0.name) }, selected: method, key: "d_method", style: .rows)))
        }
        y += wellH + r.u(14)
        let noteH = r.u(84), glyph = r.f(20, min: 14)
        nodes.append(Node.group {
            Node.well(w, noteH, corner: r.u(12), fill: Noor.quiet)
            Node.symbol("info.circle", color: Noor.text).size(glyph, glyph).at(r.u(20), (noteH - glyph) / 2)
            Node.say(L("There is no one right method: pick what your community follows. You can change it at any time."), r.u(58), 0, w - r.u(76), noteH, size: r.f(15, min: 11.5), color: Noor.muted, lines: 3)
        }
        .size(w, noteH).at(x, y))
        y += noteH + r.u(14)
        calculatedTimes(ctx, method: method, x: x, w: w, y: &y, r: r, nodes: &nodes)
    }

    /// Today's calculated times, while they are the ones the chosen method gives.
    private static func calculatedTimes(_ ctx: Context, method: String, x: Double, w: Double, y: inout Double, r: Ruler, nodes: inout [Node]) {
        let chip = (words: L("Calculated"), symbol: "function")
        if let source = ctx.model.source, source.kind == .calculated, method == ctx.model.prefs.convention.map({ "\($0.method)" }),
           let today = ctx.snapshot.localDate, let day = ctx.model.day(today) {
            nodes.append(timesBox(L("Source preview"), L("Sample times from {name}", ["name": source.name]), chip: chip, corner: L("Date"), rows: [(Words.dateShort(today), day, source.zone)], w: w, r: r).at(x, y))
            y += timesHeight(rows: 1, r: r) + r.u(12)
            return
        }
        noTimes(L("Times from this method show here once you use it."), x: x, w: w, y: &y, r: r, nodes: &nodes)
    }

    /// Where the preview will stand, with no number that isn't real.
    private static func noTimes(_ words: String, x: Double, w: Double, y: inout Double, r: Ruler, nodes: inout [Node]) {
        let boxH = r.u(110), glyph = r.f(24, min: 15)
        nodes.append(Node.group {
            Node.rect(fill: Noor.quiet, stroke: NoorLine.soft, lineWidth: 1, corner: r.u(12), dash: [3, 4]).size(w, boxH)
            Node.symbol("clock", color: Noor.muted).size(glyph, glyph).at(r.u(20), (boxH - glyph) / 2)
            Node.say(L("Source preview"), r.u(60), r.u(18), w - r.u(76), r.u(28), size: r.f(16.5, min: 12), weight: "medium")
            Node.say(words, r.u(60), r.u(48), w - r.u(76), r.u(44), size: r.f(14, min: 10.5), color: Noor.muted, lines: 2)
        }
        .size(w, boxH).at(x, y))
        y += boxH + r.u(12)
    }

    // MARK: Before a file: what the other side says

    private static func guide(_ ctx: Context, w: Double, h: Double?, ox: Double, oy: Double, r: Ruler, wiring: inout SceneWiring) -> (node: Node, height: Double) {
        let mosque = mosqueChosen(ctx)
        let x = r.u(21), inner = w - x * 2
        wiring.acts["by-hand"] = .go(Go(set: ["sheet": "manual"], push: true))
        var nodes = heading(mosque ? L("Check your timetable") : L("Calculated for your place"), mosque ? L("Your file is looked over before it is added.") : L("Where these times come from."), r: r, w: w)
        var y = r.u(107)
        // What stands at the panel's foot, level with the other panel's buttons, and how much room it takes.
        let footH: Double
        if mosque {
            footH = r.u(52)
            if !compareBox(ctx, x: x, w: inner, y: &y, r: r, nodes: &nodes) {
                let boxH = r.u(172)
                nodes.append(Node.group {
                    Node.rect(fill: Noor.quiet, stroke: NoorLine.soft, lineWidth: 1, corner: r.u(14), dash: [3, 4]).size(inner, boxH)
                    Node.medallion("doc.text", cx: inner / 2, cy: r.u(50), d: r.u(64), ink: Noor.text)
                    Node.say(L("No file yet"), r.u(20), r.u(88), inner - r.u(40), r.u(30), size: r.f(19, min: 13), weight: "medium", align: "center")
                    Node.say(L("Enter it by hand or import a CSV file. Noor doesn't search for mosques and never guesses an iqamah."), r.u(30), r.u(116), inner - r.u(60), r.u(50), size: r.f(14.5, min: 11), color: Noor.muted, align: "center", lines: 2)
                }
                .size(inner, boxH).at(x, y))
                y += boxH + r.u(20)
            }
            let copyW = r.u(220), labelH = r.u(36)
            nodes.append(Node.say(L("A file looks like this"), x + r.u(2), y, inner - copyW - r.u(10), labelH, size: r.f(17, min: 12), weight: "medium"))
            wiring.inlays.append(PageInlay(x: ox + x + inner - copyW, y: oy + y, w: copyW, h: labelH, copyButton))
            y += labelH + r.u(4)
            let lines = CSVImport.template.split(separator: "\n").prefix(5).map(String.init)
            let lineH = r.u(32), tableH = lineH * Double(lines.count) + r.u(18)
            nodes.append(Node.group {
                Node.well(inner, tableH, corner: r.u(12), fill: Noor.quiet)
                for (i, line) in lines.enumerated() {
                    Node.text(line, size: r.f(13.5, min: 9.5), design: "monospaced", color: i == 0 ? Noor.text : Noor.muted, align: "leading", lines: 1).size(inner - r.u(36), lineH).at(r.u(18), r.u(9) + Double(i) * lineH)
                }
            }
            .size(inner, tableH).at(x, y).leftToRight())
            y += tableH + r.u(14)
            nodes.append(Node.say(L("One row per date and prayer. Leave iqamah empty where the mosque gives none."), x + r.u(4), y, inner - r.u(8), r.u(50), size: r.f(14.5, min: 11), color: Noor.muted, lines: 2))
            y += r.u(56)
        } else {
            footH = r.u(158)
            let place = ctx.model.prefs.place
            var rows: [(String, String, String)] = [
                ("mappin.and.ellipse", L("Place"), place.map(PlaceParts.title) ?? "—"),
                ("clock", L("Time zone"), place.map { SetupPage.zoneLine($0.zoneID, now: ctx.snapshot.now) } ?? "—"),
                ("function", L("Calculated by"), TimetableSource.calculatedAttribution),
            ]
            // Times have been fetched only once a method is set; before that only the lists of methods and Names have.
            if ctx.model.source?.kind == .calculated, ctx.model.prefs.convention != nil, let fetched = ctx.model.source?.lastFetch {
                rows.append(("arrow.clockwise", L("Last successful sync"), Format.dateTime(fetched, timeZone: ctx.zone)))
            }
            let rowH = r.u(70)
            for row in rows {
                nodes.append(Node.group {
                    Node.well(inner, rowH, corner: r.u(14), fill: Noor.quiet)
                    Node.symbol(row.0, color: Noor.text).size(r.f(26, min: 16), r.f(26, min: 16)).at(r.u(22), (rowH - r.f(26, min: 16)) / 2)
                    Node.say(row.1, r.u(70), r.u(8), inner - r.u(84), r.u(24), size: r.f(14.5, min: 11), color: Noor.muted)
                    Node.say(row.2, r.u(70), r.u(32), inner - r.u(84), r.u(30), size: r.f(17, min: 12.5))
                }
                .size(inner, rowH).at(x, y))
                y += rowH + r.u(10)
            }
            // Coming from a mosque's timetable, saying what the switch does is part of the choice.
            let fromMosque = ctx.model.source?.kind == .manual
            let note = L("Saving sends these coordinates to AlAdhan to calculate times and the bearing.") + (fromMosque ? " " + L("Calculated times come from the provider once you switch, then replace what is planned. Your reminder choices stay.") : "")
            let noteH = r.u(fromMosque ? 72 : 50)
            nodes.append(Node.say(note, x + r.u(4), y + r.u(2), inner - r.u(8), noteH, size: r.f(14.5, min: 11), color: Noor.muted, lines: fromMosque ? 3 : 2))
            y += noteH + r.u(10)
            if place == nil {
                // Preferences stands over first run, so the way to a place leaves it.
                wiring.acts["to-place"] = .go(Go(set: ["setup": "place", "sheet": NSNull()]))
                nodes.append(Node.ctaPill("to-place", label: L("Choose a place"), x: x, y: y, w: inner, h: r.u(50), filled: false, size: r.f(16.5, min: 12)))
                y += r.u(60)
            }
        }
        let height = max(y + footH + r.u(30), least(ctx, r)), finalH = h ?? height
        let foot = finalH - footH - r.u(22)
        if mosque {
            nodes.append(Node.ctaPill("by-hand", label: L("Enter by hand"), x: x, y: foot, w: inner, h: footH, symbol: nil, leading: "pencil", filled: false, size: r.f(17, min: 12)))
        } else {
            nodes.append(addWell(x: x, y: foot, w: inner, h: footH, ox: ox, oy: oy, r: r, wiring: &wiring))
        }
        return (Node.group {
            panelChrome(w, finalH, r: r)
            nodes
        }
        .size(w, finalH), height)
    }

    /// A mosque's timetable can still be added from here, without leaving calculated times.
    private static func addWell(x: Double, y: Double, w: Double, h: Double, ox: Double, oy: Double, r: Ruler, wiring: inout SceneWiring) -> Node {
        let pad = r.u(16), gap = r.u(10), buttonH = r.u(42), buttonY = h - buttonH - r.u(14)
        let room = w - pad * 2 - gap * 2, importW = room * 0.33, handW = room * 0.26, copyW = room - importW - handW
        return Node.group {
            Node.well(w, h, corner: r.u(14), fill: Noor.quiet)
            Node.say(L("Add a mosque's timetable"), pad, r.u(10), w - pad * 2, r.u(26), size: r.f(16.5, min: 12), weight: "medium")
            Node.say(L("A source you enter is labelled Manual. An imported file is checked before anything is saved."), pad, r.u(36), w - pad * 2, r.u(46), size: r.f(14, min: 10.5), color: Noor.muted, lines: 2)
            slot(importButton(first: true), x: pad, y: buttonY, w: importW, h: buttonH, ox: ox + x, oy: oy + y, wiring: &wiring)
            Node.ctaPill("by-hand", label: L("Enter by hand"), x: pad + importW + gap, y: buttonY, w: handW, h: buttonH, symbol: nil, filled: false, size: r.f(14, min: 11))
            slot(copyButton, x: pad + importW + handW + gap * 2, y: buttonY, w: copyW, h: buttonH, ox: ox + x, oy: oy + y, wiring: &wiring)
        }
        .size(w, h).at(x, y)
    }

    /// The same date under what is in use and what is picked, before anything changes. Reminders you chose stay chosen; a missing iqamah is called out rather than borrowed.
    private static func compareBox(_ ctx: Context, x: Double, w: Double, y: inout Double, r: Ruler, nodes: inout [Node]) -> Bool {
        guard let next = pick(ctx), let current = ctx.model.source, next.id != current.id, let today = ctx.snapshot.localDate else { return false }
        let nextDay = PreferencesPage.proposedDay(ctx, next)
        nodes.append(timesBox(L("Source-change preview"), L("{old} → {new}", ["old": current.name, "new": next.name]), chip: nil, corner: "", rows: [(current.name, ctx.model.day(today), current.zone), (next.name, nextDay, next.zone)], w: w, r: r).at(x, y))
        y += timesHeight(rows: 2, r: r) + r.u(8)
        if ctx.model.prefs.reminders.prayers.contains(where: { $0.value.iqamahMinutes != nil }), nextDay?.iqamah.isEmpty ?? true {
            nodes.append(Node.say(L("This source has no iqamah times, so your iqamah reminders won't come from it. Your choices are kept."), x + r.u(4), y, w - r.u(8), r.u(44), size: r.f(14, min: 10.5), color: Noor.warm, lines: 2))
            y += r.u(46)
        }
        y += r.u(10)
        return true
    }

    // MARK: Check your timetable

    private static func check(_ ctx: Context, w: Double, h: Double?, ox: Double, oy: Double, r: Ruler, wiring: inout SceneWiring) -> (node: Node, height: Double) {
        guard let pending = ctx.model.review else { return (Node.group { panelChrome(w, h ?? r.u(650), r: r) }.size(w, h ?? r.u(650)), r.u(650)) }
        let review = pending.review, name = pending.name
        let x = r.u(21), inner = w - x * 2
        var nodes = heading(L("Check your timetable"), L("Nothing is added until you say so."), r: r, w: w)
        var y = r.u(107)

        // The file, and what was read from it.
        let cardH = r.u(85), glyph = r.f(34, min: 20)
        let withIqamah = review.rows.filter { $0.iqamah != nil }.count
        let tally = L("{rows} rows · {iqamah} with iqamah", ["rows": Format.integer(review.rows.count), "iqamah": Format.integer(withIqamah)])
        wiring.tools["cancel"] = ("discard_import", [:])
        nodes.append(Node.group {
            Node.well(inner, cardH, corner: r.u(14), fill: Noor.quiet)
            Node.symbol("doc.text", color: Noor.text).size(glyph, glyph).at(r.u(20), (cardH - glyph) / 2)
            Node.say(name, r.u(76), r.u(10), inner - r.u(220), r.u(36), size: r.f(21, min: 13.5), weight: "medium")
            Node.say((review.canSave ? L("Checked") : L("Needs fixing")) + " · " + tally, r.u(76), r.u(44), inner - r.u(220), r.u(28), size: r.f(14.5, min: 10.5), color: review.canSave ? Noor.muted : NoorLine.danger)
            Node.pill("cancel", label: L("Cancel"), x: inner - r.u(136), y: r.u(21), w: r.u(120), h: r.u(44), size: r.f(15.5, min: 11.5))
        }
        .size(inner, cardH).at(x, y))
        y += cardH + r.u(4)

        // Where and when.
        let gap = r.u(13), factW = (inner - gap) / 2, factH = r.u(75)
        let span = review.coverage.map { L("{from} to {to}", ["from": Words.date($0.lowerBound, weekday: false, year: false), "to": Words.date($0.upperBound, weekday: false)]) } ?? "—"
        let facts: [(String, String, String)] = [("mappin.and.ellipse", L("Time zone"), review.zone ?? "—"), ("calendar", L("Dates"), span)]
        for (i, fact) in facts.enumerated() {
            nodes.append(Node.group {
                Node.well(factW, factH, corner: r.u(12), fill: Noor.quiet)
                Node.symbol(fact.0, color: Noor.text).size(r.f(26, min: 15), r.f(26, min: 15)).at(r.u(18), (factH - r.f(26, min: 15)) / 2)
                Node.say(fact.1, r.u(62), r.u(12), factW - r.u(72), r.u(24), size: r.f(14.5, min: 10.5), color: Noor.muted)
                Node.say(fact.2, r.u(62), r.u(32), factW - r.u(70), r.u(38), size: r.f(14.5, min: 10.5), lines: 2)
            }
            .size(factW, factH).at(x + Double(i) * (factW + gap), y))
        }
        y += factH + r.u(12)

        // What it will be called: the file's own name until they say otherwise.
        let typed = ctx.state.string("import_name") ?? name
        let nameH = r.u(46)
        nodes.append(Node.say(L("Name"), x + r.u(4), y, r.u(80), nameH, size: r.f(15.5, min: 11.5), color: Noor.muted))
        nodes.append(Node.well(inner - r.u(90), nameH, corner: r.u(10), fill: Noor.quiet).at(x + r.u(90), y))
        wiring.inlays.append(PageInlay(x: ox + x + r.u(102), y: oy + y, w: inner - r.u(112), h: nameH, .draftField(L("Name"), placeholder: name, button: L("Clear"), key: "import_name", value: typed, live: true)))
        y += nameH + r.u(12)

        // What's wrong with it, every line, or what adding it does.
        var problems: [String] = review.errors.prefix(8).map(Words.importIssue)
        problems += review.duplicates.prefix(4).map { L("Line {line} repeats line {first}.", ["line": "\($0.line)", "first": "\($0.firstLine)"]) }
        problems += review.conflicts.prefix(4).map { L("Line {line} contradicts line {first}.", ["line": "\($0.line)", "first": "\($0.firstLine)"]) }
        problems += review.missingDates.prefix(4).map { L("{date} is missing from this file.", ["date": Words.date($0, weekday: false)]) }
        problems += review.missingRows.prefix(4).map { L("{prayer} is missing on {date}.", ["prayer": Words.prayer($0.prayer), "date": Words.date($0.date, weekday: false)]) }
        if problems.isEmpty, let twin = twin(ctx, of: review) {
            let bannerH = r.u(64)
            nodes.append(Node.group {
                Node.rect(fill: Color.adaptive(light: "#FFF7EA", dark: "#2A2030"), stroke: NoorLine.caution, lineWidth: 1, corner: r.u(10)).size(inner, bannerH)
                Node.symbol("exclamationmark.triangle.fill", color: NoorLine.caution).size(r.f(24, min: 15), r.f(24, min: 15)).at(r.u(18), (bannerH - r.f(24, min: 15)) / 2)
                Node.say(L("You already have these same times, as {name}. Adding this makes a second copy.", ["name": twin]), r.u(58), 0, inner - r.u(70), bannerH, size: r.f(14, min: 11), color: Noor.warm, lines: 2)
            }
            .size(inner, bannerH).at(x, y))
            y += bannerH + r.u(10)
        }
        if problems.isEmpty {
            let boxH = r.u(92)
            nodes.append(Node.group {
                Node.rect(fill: Noor.quiet, stroke: NoorLine.chosen, lineWidth: 1, corner: r.u(12)).size(inner, boxH)
                Node.symbol("checkmark.circle", color: Noor.text).size(r.f(24, min: 15), r.f(24, min: 15)).at(r.u(20), (boxH - r.f(24, min: 15)) / 2)
                Node.say(L("Adding it makes it your timetable, labelled Manual. Your reminder choices stay, and planned reminders move to its times. Check the times against your mosque's own timetable."), r.u(60), 0, inner - r.u(76), boxH, size: r.f(14, min: 10.5), color: Noor.muted, lines: 3)
            }
            .size(inner, boxH).at(x, y))
            y += boxH + r.u(12)
        } else {
            let bannerH = r.u(54)
            nodes.append(Node.group {
                Node.rect(fill: Color.adaptive(light: "#FFF7EA", dark: "#2A2030"), stroke: NoorLine.caution, lineWidth: 1, corner: r.u(10)).size(inner, bannerH)
                Node.symbol("exclamationmark.triangle.fill", color: NoorLine.caution).size(r.f(24, min: 15), r.f(24, min: 15)).at(r.u(18), (bannerH - r.f(24, min: 15)) / 2)
                Node.say(L(one: "{count} thing to fix · Choose the file again after", other: "{count} things to fix · Choose the file again after", count: problems.count), r.u(58), 0, inner - r.u(70), bannerH, size: r.f(16, min: 11.5), color: Noor.warm)
            }
            .size(inner, bannerH).at(x, y))
            y += bannerH + r.u(10)
            let lineH = r.u(30), boxH = lineH * Double(problems.count) + r.u(16)
            nodes.append(Node.group {
                Node.well(inner, boxH, corner: r.u(12), fill: Noor.quiet)
                for (i, line) in problems.enumerated() {
                    Node.say(line, r.u(20), r.u(8) + Double(i) * lineH, inner - r.u(36), lineH, size: r.f(14, min: 10.5), color: Noor.text)
                }
            }
            .size(inner, boxH).at(x, y))
            y += boxH + r.u(12)
        }

        // A sample of the rows, as they will be read.
        let sample = Array(review.rows.prefix(4))
        let copyW = r.u(220)
        wiring.inlays.append(PageInlay(x: ox + x + inner - copyW, y: oy + y, w: copyW, h: r.u(32), copyButton))
        if sample.isEmpty { y += r.u(40) } else {
            nodes.append(Node.say(L("Sample of imported times"), x + r.u(2), y, inner - copyW - r.u(10), r.u(32), size: r.f(17, min: 12)))
            y += r.u(34)
            let row = r.u(38), tableH = row * Double(sample.count + 1)
            let cols = [0.0, inner * 0.36, inner * 0.62, inner * 0.82]
            let titles = [L("Date"), L("Prayer"), L("Starts"), L("Iqamah")]
            nodes.append(Node.group {
                Node.well(inner, tableH, corner: r.u(10), fill: Noor.quiet)
                for (i, title) in titles.enumerated() {
                    Node.say(title, cols[i] + r.u(16), 0, inner * 0.3, row, size: r.f(14.5, min: 10.5), color: Noor.muted)
                }
                for (n, line) in sample.enumerated() {
                    let ry = row * Double(n + 1)
                    Node.rect(fill: NoorLine.soft).size(inner, 1).at(0, ry)
                    Node.say(Words.dateShort(line.date, year: true), cols[0] + r.u(16), ry, cols[1] - r.u(20), row, size: r.f(14.5, min: 10.5))
                    Node.say(slotName(line.slot), cols[1] + r.u(16), ry, cols[2] - cols[1] - r.u(20), row, size: r.f(14.5, min: 10.5))
                    Node.say(line.start.text, cols[2] + r.u(16), ry, cols[3] - cols[2] - r.u(20), row, size: r.f(14.5, min: 10.5), tabular: true)
                    Node.say(line.iqamah?.text ?? "—", cols[3] + r.u(16), ry, inner - cols[3] - r.u(20), row, size: r.f(14.5, min: 10.5), tabular: true)
                }
            }
            .size(inner, tableH).at(x, y))
            y += tableH + r.u(14)
        }

        let buttonH = r.u(50)
        let height = max(y + buttonH + r.u(30), ctx.narrow ? 0 : r.u(650)), finalH = h ?? height
        wiring.tools["add"] = ("save_import", ["name": typed])
        let addW = inner * 0.6, buttonY = finalH - buttonH - r.u(22)
        nodes.append(Node.ctaPill("add", label: L("Add timetable"), x: x, y: buttonY, w: addW, h: buttonH, symbol: "checkmark", disabled: !review.canSave, size: r.f(17, min: 12)))
        nodes.append(slot(importButton(first: false), x: x + addW + r.u(14), y: buttonY, w: inner - addW - r.u(14), h: buttonH, ox: ox, oy: oy, wiring: &wiring))
        return (Node.group {
            panelChrome(w, finalH, r: r)
            nodes
        }
        .size(w, finalH), height)
    }

    /// The saved timetable with exactly these times, if there is one: a warning, as a second copy may be meant.
    private static func twin(_ ctx: Context, of review: ImportReview) -> String? {
        guard let table = review.timetable(id: "manual.check", attribution: review.name) else { return nil }
        return ctx.model.sources.first { source in
            guard source.kind == .manual, case .ok(let saved) = ctx.model.store.timetable(sourceID: source.id) else { return false }
            return saved.sameTimes(as: table)
        }?.name
    }

    private static func slotName(_ slot: TimetableSlot) -> String {
        switch slot {
        case .prayer(let id): Words.prayer(id)
        case .friday(let name): name
        }
    }

    // MARK: By hand

    /// By hand: a fixed pattern over a date range you state. Never open-ended, and iqamah only where you say.
    static func manual(_ ctx: Context) -> [Section] {
        let s = ctx.state
        let name = s.string("m_name") ?? "", zone = s.string("m_zone") ?? ctx.snapshot.zoneID ?? "", from = s.string("m_from") ?? "", to = s.string("m_to") ?? ""
        var starts: [String: Any] = [:], iqamah: [String: Any] = [:]
        for id in PrayerID.allCases {
            starts[id.rawValue] = s.string("m_\(id.rawValue)") ?? ""
            iqamah[id.rawValue] = s.string("m_\(id.rawValue)_iq") ?? ""
        }
        var problem: String?
        var preview: ImportReview?
        if let r = manualReview(name: name, zone: zone, from: from, to: to, starts: starts as? [String: String] ?? [:], iqamah: iqamah as? [String: String] ?? [:]) {
            preview = r
            problem = r.canSave ? nil : (r.errors.first.map(Words.importIssue) ?? L("Something in this doesn't add up."))
        } else if !name.isEmpty || !from.isEmpty {
            problem = L("Fill in a name, a real time zone, both dates and all five starts, as HH:mm.")
        }
        let left: Panel = { w, h, ox, oy, r, wiring in
            let x = r.u(21), inner = w - x * 2
            var nodes = heading(L("Enter a timetable"), L("The same times every day of a range you choose."), r: r, w: w)
            nodes.append(backMark(.go(.backward), r: r, wiring: &wiring))
            var y = r.u(112)
            let fields: [(String, String, String, String)] = [
                (L("Name of the source"), L("Community Mosque"), "m_name", name), (L("Time zone"), "Europe/London", "m_zone", zone),
                (L("First date"), "2026-11-01", "m_from", from), (L("Last date"), "2026-11-30", "m_to", to),
            ]
            for field in fields {
                nodes.append(Node.say(field.0, x + r.u(4), y, inner, r.u(26), size: r.f(15.5, min: 11.5), color: Noor.muted))
                nodes.append(Node.well(inner, r.u(48), corner: r.u(10), fill: Noor.quiet).at(x, y + r.u(28)))
                wiring.inlays.append(PageInlay(x: ox + x + r.u(14), y: oy + y + r.u(28), w: inner - r.u(24), h: r.u(48), .draftField(field.0, placeholder: field.1, button: L("Clear"), key: field.2, value: field.3.isEmpty ? nil : field.3, live: true)))
                y += r.u(90)
            }
            nodes.append(Node.say(L("For times that change daily, import a file."), x + r.u(4), y + r.u(4), inner - r.u(8), r.u(26), size: r.f(14.5, min: 11), color: Noor.muted))
            y += r.u(40)
            let height = max(y + r.u(20), ctx.narrow ? 0 : r.u(640)), finalH = h ?? height
            return (Node.group { panelChrome(w, finalH, r: r); nodes }.size(w, finalH), height)
        }
        let right: Panel = { w, h, ox, oy, r, wiring in
            let x = r.u(21), inner = w - x * 2
            var nodes = heading(L("Times"), L("Iqamah only where you know it. Noor never guesses one."), r: r, w: w)
            var y = r.u(112)
            let first = inner * 0.26, col = (inner - first - r.u(16)) / 2
            nodes.append(Node.say(L("Starts"), x + first, y, col, r.u(26), size: r.f(14.5, min: 11), color: Noor.muted))
            nodes.append(Node.say(L("Iqamah"), x + first + col + r.u(16), y, col, r.u(26), size: r.f(14.5, min: 11), color: Noor.muted))
            y += r.u(28)
            for id in PrayerID.allCases {
                let a = s.string("m_\(id.rawValue)") ?? "", b = s.string("m_\(id.rawValue)_iq") ?? ""
                nodes.append(Node.say(Words.prayer(id), x + r.u(4), y, first - r.u(8), r.u(46), size: r.f(16, min: 12)))
                nodes.append(Node.well(col, r.u(46), corner: r.u(10), fill: Noor.quiet).at(x + first, y))
                nodes.append(Node.well(col, r.u(46), corner: r.u(10), fill: Noor.quiet).at(x + first + col + r.u(16), y))
                wiring.inlays.append(PageInlay(x: ox + x + first + r.u(12), y: oy + y, w: col - r.u(20), h: r.u(46), .draftField(L("{prayer} start", ["prayer": Words.prayer(id)]), placeholder: "HH:mm", button: L("Clear"), key: "m_\(id.rawValue)", value: a.isEmpty ? nil : a, live: true)))
                wiring.inlays.append(PageInlay(x: ox + x + first + col + r.u(28), y: oy + y, w: col - r.u(20), h: r.u(46), .draftField(L("{prayer} iqamah (optional)", ["prayer": Words.prayer(id)]), placeholder: "HH:mm", button: L("Clear"), key: "m_\(id.rawValue)_iq", value: b.isEmpty ? nil : b, live: true)))
                y += r.u(58)
            }
            if let problem {
                nodes.append(Node.say(problem, x + r.u(4), y + r.u(2), inner - r.u(8), r.u(48), size: r.f(14, min: 10.5), color: NoorLine.caution, lines: 2))
            }
            y += r.u(52)
            let height = max(y + r.u(80), ctx.narrow ? 0 : r.u(640)), finalH = h ?? height
            wiring.tools["save"] = ("save_manual", ["name": name, "zone": zone, "from": from, "to": to, "starts": starts, "iqamah": iqamah])
            wiring.acts["cancel"] = .go(.backward)
            let buttonH = r.u(50), foot = finalH - buttonH - r.u(22)
            nodes.append(Node.ctaPill("save", label: L("Save timetable"), x: x, y: foot, w: inner * 0.62, h: buttonH, symbol: "checkmark", disabled: preview?.canSave != true, size: r.f(17, min: 12)))
            nodes.append(Node.ctaPill("cancel", label: L("Cancel"), x: x + inner * 0.62 + r.u(14), y: foot, w: inner * 0.38 - r.u(14), h: buttonH, symbol: nil, filled: false, size: r.f(17, min: 12)))
            return (Node.group { panelChrome(w, finalH, r: r); nodes }.size(w, finalH), height)
        }
        return two(ctx, left: left, right: right)
    }

    static func manualReview(name: String, zone: String, from: String, to: String, starts: [String: String], iqamah: [String: String]) -> ImportReview? {
        guard !name.isEmpty, IANAZone.zone(zone) != nil, let a = CivilDate(iso: from), let b = CivilDate(iso: to), a <= b else { return nil }
        var s: [PrayerID: LocalTime] = [:], q: [PrayerID: LocalTime] = [:]
        for id in PrayerID.allCases {
            guard let t = starts[id.rawValue].flatMap(LocalTime.init(text:)) else { return nil }
            s[id] = t
            if let text = iqamah[id.rawValue], !text.isEmpty {
                guard let t2 = LocalTime(text: text) else { return nil }
                q[id] = t2
            }
        }
        return FixedPattern(zoneID: zone, starts: s, iqamah: q).review(name: name, range: a...b)
    }
}
