import Foundation
import SidefolkExtensionKit

/// Names: all 99 as the provider supplied them, Arabic with its own shaping, transliteration and English meaning. Nothing is added to them: no commentary, audio or translated meanings.
@MainActor
enum NamesPage {
    private static func filtered(_ ctx: Context) -> [NameEntry] {
        let query = (ctx.state.string("q") ?? "").trimmingCharacters(in: .whitespaces).lowercased()
        let saved = ctx.state.string("filter") == "saved"
        let names = ctx.model.names.sorted { $0.number < $1.number }
        return names.filter { name in
            (!saved || ctx.model.bookmarks.contains(name.number)) && matches(name, query)
        }
    }

    private static func matches(_ name: NameEntry, _ query: String) -> Bool {
        query.isEmpty || name.transliteration.lowercased().contains(query) || name.meaning.lowercased().contains(query) || name.arabic.contains(query) || Self.bare(name.arabic).contains(Self.bare(query))
    }

    /// Arabic without its vowel marks: people type it that way.
    private static func bare(_ text: String) -> String { String(text.unicodeScalars.filter { !(0x064B...0x065F).contains($0.value) && $0.value != 0x0670 }.map(Character.init)) }

    static func sections(_ ctx: Context) -> [Section] {
        guard !ctx.model.names.isEmpty else {
            let busy = ctx.model.load == .loading
            return [NoorPage.status(ctx, symbol: "book", title: busy ? L("Loading the Names…") : L("The Names aren't here yet"), detail: busy ? "" : L("They need one connection, then they are saved. {why}", ["why": Words.problem(ctx.model.problem)]), buttons: busy ? [] : [("retry", L("Try again"), true, .tool("refresh"))])]
        }
        let list = filtered(ctx)
        let named = ctx.state.int("name").flatMap { n in ctx.model.names.first { $0.number == n } }
        // Whatever the search or the filter leaves is what's read, unless nothing is left: then the Name just left stays, so its Save can be undone.
        let selected = named.flatMap { list.contains($0) ? $0 : nil } ?? list.first ?? named ?? ctx.model.names.first!
        // Twenty at a time: a scene is sent whole, and a page has a limit. Searching or following one by number shows where it is.
        let start = shelf(ctx, list, selected: selected)
        let block: Block = ctx.narrow ? narrowList(ctx, list, start: start) : wideList(ctx, list, start: start, selected: selected)
        var out: [Section] = []
        if let note = NoorPage.offlineNote(ctx) { out.append(Section(nil, [note], wide: true)) }
        out.append(Section(nil, [block], wide: true))
        return out
    }

    // MARK: P06: the header band, the rows, and the Name in its arch

    /// Places in P06's own numbers: a board's x less 245, its y less 175.
    private static func wideList(_ ctx: Context, _ list: [NameEntry], start: Int, selected: NameEntry) -> Block {
        let r = ctx.ruler, w = ctx.width
        let rowsX = r.u(23), rowsY = r.u(145), rowsW = r.u(550), rowsH = r.u(605)
        let archX = r.u(597), archW = w - archX - r.u(26), archY = r.u(137), archH = r.u(633)
        let bandX = r.u(20), bandY = r.u(8), bandW = w - bandX * 2, bandH = r.u(129)
        let controls = bandControls(ctx, list, r: r, right: bandW, y: r.u(44), originX: bandX, originY: bandY)
        let scene = Scene(width: w, height: r.u(812)) {
            Node.group {
                band(w: bandW, h: bandH, r: r)
                Node.say(L("Names of Allah"), r.u(69), r.u(30), r.u(410), r.u(54), size: r.f(40, min: 20), weight: "semibold")
                Node.say(L("Beautiful Names to remember and reflect"), r.u(69), r.u(82), r.u(420), r.u(30), size: r.f(20, min: 12), color: Noor.muted)
                controls.nodes
            }
            .size(bandW, bandH).at(bandX, bandY)
            rowsOrEmpty(ctx, list, start: start, selected: selected.number, w: rowsW, h: rowsH, r: r, pushes: false).at(rowsX, rowsY)
            pager(start: start, count: list.count, w: rowsW, r: r).at(rowsX, rowsY + rowsH + r.u(8))
            nameInArch(ctx, selected, list: list, w: archW, h: archH, r: r).at(archX, archY)
        }
        return .scene(PageSceneBlock(scene, actions: tools(ctx, selected), acts: acts(ctx, selected, list: list, start: start, pushes: false), inlays: controls.inlays))
    }

    /// One column: the band's words over its search and filters, then the rows, each going to its own page.
    private static func narrowList(_ ctx: Context, _ list: [NameEntry], start: Int) -> Block {
        let margin = 16.0, inner = ctx.width - margin * 2
        let r = Ruler(width: inner / 550 * 1290)
        let bandH = r.u(112) + r.u(64) + r.u(64)
        let rowsY = bandH + 16, rowsH = 122 * 4.5 * r.s
        let controls = bandControls(ctx, list, r: r, right: inner, y: r.u(112) + r.u(64), originX: margin, originY: 4, searchRow: r.u(112))
        let scene = Scene(width: ctx.width, height: rowsY + rowsH + r.u(60)) {
            Node.group {
                band(w: inner, h: bandH, r: r)
                Node.say(L("Names of Allah"), r.u(64), r.u(20), inner - r.u(128), r.u(54), size: r.f(40, min: 20), weight: "semibold")
                Node.say(L("Beautiful Names to remember and reflect"), r.u(64), r.u(70), inner - r.u(128), r.u(30), size: r.f(20, min: 12), color: Noor.muted)
                controls.nodes
            }
            .size(inner, bandH).at(margin, 4)
            rowsOrEmpty(ctx, list, start: start, selected: nil, w: inner, h: rowsH, r: r, pushes: true).at(margin, rowsY)
            pager(start: start, count: list.count, w: inner, r: r).at(margin, rowsY + rowsH + r.u(8))
        }
        let first = list.first ?? ctx.model.names[0]
        return .scene(PageSceneBlock(scene, acts: acts(ctx, first, list: list, start: start, pushes: true), inlays: controls.inlays))
    }

    private static func band(w: Double, h: Double, r: Ruler) -> Node {
        // The corners keep to the first line's height: a taller band, in a narrow window, doesn't drag them down its sides.
        let drop = min(h, r.u(129))
        return Node.group {
            Node.rect(fill: Noor.surface).size(w, h).corner(r.u(14))
            Node.group {
                Node.spandrel(r.u(116), drop).at(w - r.u(116), 0)
                Node.spandrel(r.u(116), drop, flipped: true).at(0, 0)
            }
            .size(w, h).corner(r.u(14)).clip()
            Node.rect(stroke: Noor.hairline, lineWidth: 1, corner: r.u(14)).size(w, h)
        }
        .size(w, h)
    }

    /// The search as a native field over its well, All as a real menu over its pill, Saved as a pill, and how many there are. `searchRow`: the search on its own line, for a narrow window.
    private static func bandControls(_ ctx: Context, _ list: [NameEntry], r: Ruler, right: Double, y: Double, originX: Double, originY: Double, searchRow: Double? = nil) -> (nodes: [Node], inlays: [PageInlay]) {
        let saved = ctx.state.string("filter") == "saved"
        let query = ctx.state.string("q") ?? ""
        let h = r.u(46)
        let countW = r.u(112), savedW = r.u(96), allW = r.u(92), gap = r.u(15)
        let countX = right - countW - r.u(10), savedX = countX - savedW - r.u(6), allX = savedX - allW - gap
        let wide = searchRow == nil
        let fieldX = wide ? allX - gap - r.u(404) : r.u(20), fieldW = wide ? r.u(404) : right - r.u(40), fieldY = searchRow ?? y
        let glyph = r.f(20, min: 14)
        let nodes: [Node] = [
            Node.rect(fill: Noor.well.tuned(alpha: 0.65), stroke: Noor.edge.tuned(alpha: 0.7), lineWidth: 1, corner: r.u(14)).size(fieldW, h).at(fieldX, fieldY),
            Node.symbol("magnifyingglass", color: Noor.text).size(glyph, glyph).at(fieldX + r.u(16), fieldY + (h - glyph) / 2),
            // The menu's face. The system's menu lies over it, and it says the same choice the Saved pill beside it makes.
            Node.group {
                Node.rect(fill: saved ? Noor.quiet : Noor.picked, stroke: saved ? Noor.edge : Noor.pickedEdge, lineWidth: 1.1, corner: r.u(14)).size(allW, h)
                Node.say(L("All"), r.u(12), 0, allW - r.u(44), h, size: r.f(18, min: 12.5), color: saved ? Noor.text : Noor.onChosen, align: "center")
                Node.symbol("chevron.down", color: saved ? Noor.text : Noor.onChosen).size(r.f(13, min: 10), r.f(13, min: 10)).at(allW - r.u(30), (h - r.f(13, min: 10)) / 2)
            }
            .size(allW, h).at(allX, y),
            Node.group {
                Node.rect(fill: saved ? Noor.picked : Noor.quiet, stroke: saved ? Noor.pickedEdge : Noor.edge, lineWidth: 1.1, corner: r.u(14)).size(savedW, h)
                Node.say(L("Saved"), 6, 0, savedW - 12, h, size: r.f(18, min: 12.5), color: saved ? Noor.onChosen : Noor.text, align: "center")
            }
            .size(savedW, h).at(savedX, y)
            .area("saved-filter", label: saved ? L("Showing saved names. Show all") : L("Show saved names"), hover: .init(scale: 1.02), selected: saved),
            Node.say(countWords(list.count), countX, y, countW, h, size: r.f(17, min: 11.5), color: Noor.muted, align: "center"),
        ]
        let inlays = [
            PageInlay(x: originX + fieldX + r.u(16) + glyph + r.u(10), y: originY + fieldY, w: fieldW - r.u(16) - glyph - r.u(20), h: h,
                      .draftField(L("Search the Names"), placeholder: fieldW < 300 ? L("Search names") : L("Search Arabic, transliteration or meaning"), button: L("Clear"), key: "q", value: query.isEmpty ? nil : query, live: true, set: ["shelf": NSNull(), "name": NSNull()])),
            PageInlay(x: originX + allX, y: originY + y, w: allW, h: h,
                      .draftChoice(L("Show"), options: [Option("all", L("All {count}", ["count": "99"])), Option("saved", L("Saved ({count})", ["count": "\(ctx.model.bookmarks.count)"]))], selected: saved ? "saved" : "all", key: "filter")),
        ]
        return (nodes, inlays)
    }

    private static func countWords(_ count: Int) -> String { L(one: "{count} name", other: "{count} names", count: count) }

    // MARK: Rows

    private static func rowsOrEmpty(_ ctx: Context, _ list: [NameEntry], start: Int, selected: Int?, w: Double, h: Double, r: Ruler, pushes: Bool) -> Node {
        guard !list.isEmpty else { return nothingHere(ctx, w: w, h: min(h, r.u(420)), r: r) }
        let step = r.u(122), rowH = r.u(114)
        let shelf = Array(list[min(start, list.count)..<min(start + shelfSize, list.count)])
        let inShelf = selected.map { n in shelf.contains { $0.number == n } } ?? false
        return Node.scroll(contentHeight: Double(shelf.count) * step, scrollTo: inShelf && (selected ?? 0) != shelf.first?.number ? selected.map { "row-\($0)" } : nil) {
            for (i, name) in shelf.enumerated() {
                row(ctx, name, w: w, h: rowH, r: r, selected: name.number == selected, pushes: pushes).at(0, Double(i) * step).id("row-\(name.number)")
                if !pushes {
                    // The way to its own page: the row itself only brings it into the arch beside.
                    Node.group { Node.symbol("chevron.forward", color: Noor.text).size(r.f(11, min: 8), r.f(19, min: 13)).at(r.u(19), (rowH - r.f(19, min: 13)) / 2) }
                        .size(r.u(50), rowH).at(w - r.u(58), Double(i) * step)
                        .area("open-\(name.number)", label: L("Open {name}", ["name": name.transliteration]), hover: .init(scale: 1.12))
                }
            }
        }
        .size(w, h).id("names-list")
    }

    private static func row(_ ctx: Context, _ name: NameEntry, w: Double, h: Double, r: Ruler, selected: Bool, pushes: Bool) -> Node {
        let medal = r.u(50), textX = r.u(102), arabicX = w - r.u(232), arabicW = r.u(160), textW = arabicX - textX - r.u(4)
        let ink = selected ? Color.adaptive(light: "#15182F", dark: "#FFFFFF") : Noor.text
        return Node.group {
            if selected {
                Node.rect(stroke: .adaptive(light: "#7354B8", dark: "#C9BDF4"), lineWidth: 1.6, corner: r.u(14)).gradient([.adaptive(light: "#E2D4F6", dark: "#573A9C"), .adaptive(light: "#F6F1FB", dark: "#191D4C")], from: (0, 0.5), to: (0.75, 0.5)).size(w, h)
            } else {
                Node.rect(fill: Noor.surface, stroke: Noor.hairline, lineWidth: 1, corner: r.u(14)).size(w, h)
            }
            Node.ellipse(fill: selected ? .adaptive(light: "#7354B8", dark: "#6B4BB4") : .adaptive(light: "#EEE8F5", dark: "#232A66"), stroke: selected ? .hex("#A58DE6") : .adaptive(light: "#C9BFE0", dark: "#3D4390"), lineWidth: 1).size(medal, medal).at(r.u(25), (h - medal) / 2)
            Node.say(Format.integer(name.number), r.u(25), (h - medal) / 2, medal, medal, size: r.f(22, min: 13), color: selected ? .hex("#FFFFFF") : Noor.text, align: "center", tabular: true)
            Node.say(name.transliteration, textX, h * 0.15, textW, h * 0.42, size: r.f(fitted(name.transliteration, textW / r.s, 27, 0.53), min: 12.5), weight: "medium", color: ink)
            Node.say(name.meaning, textX, h * 0.53, textW, h * 0.36, size: r.f(fitted(name.meaning, textW / r.s, 20, 0.47), min: 11), color: selected ? ink.tuned(alpha: 0.85) : Noor.muted)
            arabicLine(name, arabicX, arabicW, h, size: r.f(fitted(arabic: name.arabic, arabicW / r.s, 42), min: 16))
            if ctx.model.bookmarks.contains(name.number) {
                Node.symbol("bookmark.fill", color: Noor.warm).size(r.f(13, min: 10), r.f(16, min: 12)).at(w - r.u(50), r.u(10)).label(L("Saved"))
            }
            if pushes { Node.symbol("chevron.forward", color: Noor.text).size(r.f(11, min: 8), r.f(19, min: 13)).at(w - r.u(39), (h - r.f(19, min: 13)) / 2) }
        }
        .size(w, h)
        .area("name-\(name.number)", label: "\(name.number), \(name.transliteration), \(name.meaning)", hover: nil, press: nil, selected: selected)
    }

    /// Dashed, in the rows' place: nothing saved yet, or nothing found. Never beside rows.
    private static func nothingHere(_ ctx: Context, w: Double, h: Double, r: Ruler) -> Node {
        let query = ctx.state.string("q") ?? ""
        let saved = ctx.state.string("filter") == "saved"
        if saved && query.isEmpty {
            return emptyPanel(symbol: "book", title: L("No saved names yet"), detail: L("Save names as you explore the 99 Names. They stay on this Mac."), button: ("browse", L("Browse names")), w: w, h: h, r: r)
        }
        return emptyPanel(symbol: "magnifyingglass", title: L("No results for “{query}”", ["query": query]), detail: L("Try a different spelling or name."), button: ("clear", L("Clear search")), w: w, h: h, r: r)
    }

    private static func emptyPanel(symbol: String, title: String, detail: String, button: (id: String, label: String), w: Double, h: Double, r: Ruler) -> Node {
        let box = r.u(84), glyph = r.u(36), cx = w / 2, top = max(r.u(24), h / 2 - r.u(160))
        let line = Color.adaptive(light: "#7A5AB8", dark: "#7C78D0")
        return Node.group {
            Node.rect(fill: Noor.surface.tuned(alpha: 0.6), stroke: line, lineWidth: 1.2, corner: r.u(18), dash: [4, 4]).size(w, h)
            Node.group {
                Node.rect(stroke: line, lineWidth: 1.2, corner: 2).size(box * 0.72, box * 0.72).at(box * 0.14, box * 0.14).rotate(45)
                Node.rect(stroke: line, lineWidth: 1.2, corner: 2).size(box * 0.72, box * 0.72).at(box * 0.14, box * 0.14)
                Node.symbol(symbol, color: Noor.text).size(glyph, glyph * 0.86).at((box - glyph) / 2, (box - glyph * 0.86) / 2)
            }
            .size(box, box).at(cx - box / 2, top)
            Node.say(title, r.u(16), top + box + r.u(16), w - r.u(32), r.u(40), size: r.f(24, min: 15), weight: "medium", align: "center")
            Node.say(detail, w * 0.14, top + box + r.u(56), w * 0.72, r.u(60), size: r.f(19, min: 12), color: Noor.muted, align: "center", lines: 2)
            Node.pill(button.id, label: button.label, x: cx - r.u(102), y: top + box + r.u(130), w: r.u(204), h: r.u(48), symbol: "chevron.forward", size: r.f(17, min: 12.5))
        }
        .size(w, h)
    }

    private static func pager(start: Int, count: Int, w: Double, r: Ruler) -> Node {
        Node.group {
            if count > shelfSize {
                let h = r.u(38), pill = r.u(118)
                Node.pill("shelf-back", label: L("Earlier"), x: 0, y: 0, w: pill, h: h, symbol: "chevron.backward", disabled: start == 0, size: r.f(14, min: 11.5))
                Node.say(L("{from} to {to} of {count}", ["from": "\(start + 1)", "to": "\(min(start + shelfSize, count))", "count": "\(count)"]), pill, 0, w - pill * 2, h, size: r.f(15, min: 11), color: Noor.muted, align: "center")
                Node.pill("shelf-on", label: L("Later"), x: w - pill, y: 0, w: pill, h: h, symbol: "chevron.forward", disabled: start + shelfSize >= count, size: r.f(14, min: 11.5))
            }
        }
        .size(w, r.u(38))
    }

    // MARK: The Name in its arch

    private static func nameInArch(_ ctx: Context, _ name: NameEntry, list: [NameEntry], w: Double, h: Double, r: Ruler) -> Node {
        let saved = ctx.model.bookmarks.contains(name.number)
        let beside = neighbours(ctx, name, list: list)
        let cx = w / 2, inner = w - r.u(150)
        let circle = r.u(44), navY = r.u(60)
        return Node.group {
            Node.image("art/frame-name-l.jpg", dark: "art/frame-name-d.jpg", fit: "cover").size(w, h).corner(r.u(16)).clip()
            Node.rect(stroke: Noor.inlay, lineWidth: 1.2, corner: r.u(16)).size(w, h)
            let count = L("Name {number} of 99", ["number": Format.integer(name.number)]), countSize = r.f(18, min: 12)
            // The two circles stand either side of the words, however long they run in this language.
            let reach = Double(count.count) * countSize * 0.27 + r.u(8), countX = cx - r.u(11)
            Node.say(count, countX - reach, navY, reach * 2, circle, size: countSize, color: Noor.muted, align: "center")
            if beside.before != nil { round("previous", L("Previous"), "chevron.backward", x: countX - reach - circle, y: navY, d: circle, r: r) }
            if beside.after != nil { round("following", L("Next"), "chevron.forward", x: countX + reach, y: navY, d: circle, r: r) }
            // Reading text in the source's own Unicode, drawn by the system so it shapes properly.
            Node.gilded(name.arabic, (w - inner) / 2, r.u(122), inner, r.u(178), size: r.f(fitted(arabic: name.arabic, inner * 0.92 / r.s, 96), min: 30), weight: "medium").leftToRight()
                .area("read", label: L("Open {name}", ["name": name.transliteration]), hover: .init(scale: 1.0))
            Node.say(name.transliteration, (w - inner) / 2, r.u(304), inner, r.u(60), size: r.f(fitted(name.transliteration, inner / r.s, 44, 0.54), min: 18), weight: "semibold", color: Noor.warm, align: "center")
            Node.say(name.meaning, (w - inner) / 2, r.u(362), inner, r.u(46), size: r.f(fitted(name.meaning, inner / r.s, 26, 0.47), min: 13), align: "center")
            Node.ornament(cx: cx, cy: r.u(433), rule: r.u(92), rosette: r.u(26), color: Noor.inlay)
            Node.say(L("Source: AlAdhan"), (w - inner) / 2, r.u(460), inner, r.u(26), size: r.f(18, min: 11.5), color: Noor.muted, align: "center")
            Node.say(L("English meaning"), (w - inner) / 2, r.u(486), inner, r.u(26), size: r.f(18, min: 11.5), color: Noor.muted, align: "center")
            savePill(saved: saved, name: name, x: cx - r.u(83), y: r.u(537), w: r.u(166), h: r.u(53), size: r.f(18, min: 12.5))
        }
        .size(w, h)
    }

    private static func savePill(saved: Bool, name: NameEntry, x: Double, y: Double, w: Double, h: Double, size: Double) -> Node {
        Node.pill("save", label: saved ? L("Saved") : L("Save"), spoken: saved ? L("Remove {name} from saved names", ["name": name.transliteration]) : L("Save {name}", ["name": name.transliteration]), x: x, y: y, w: w, h: h, symbol: saved ? "bookmark.fill" : "bookmark", size: size)
    }

    private static func round(_ id: String, _ spoken: String, _ symbol: String, x: Double, y: Double, d: Double, r: Ruler) -> Node {
        Node.group {
            Node.ellipse(fill: Noor.quiet, stroke: Noor.edge, lineWidth: 1.1).size(d, d)
            Node.symbol(symbol, color: Noor.text).size(d * 0.24, d * 0.4).at(d * 0.38, d * 0.3)
        }
        .size(d, d).at(x, y).area(id, label: spoken)
    }

    // MARK: F04: one Name to read, and the saved ones beside it

    /// One Name on its own: where a row's chevron and a narrow window's row go, and where "Show Ar Rahmaan" lands. Beside it, what is saved.
    static func detailOnly(_ ctx: Context) -> [Section] {
        guard let name = ctx.state.int("name").flatMap({ n in ctx.model.names.first { $0.number == n } }) else { return [] }
        let saved = savedList(ctx)
        let scene: Scene, inlays: [PageInlay]
        if ctx.narrow {
            let margin = 16.0, inner = ctx.width - margin * 2
            let r = Ruler(width: inner / 638 * 1290)
            let leftH = r.u(796), rightH = sidePanelHeight(ctx, r: r, wide: false)
            scene = Scene(width: ctx.width, height: leftH + rightH + 28) {
                reading(ctx, name, w: inner, h: leftH, r: r).at(margin, 4)
                savedPanel(ctx, saved, w: inner, h: rightH, r: r).at(margin, leftH + 16)
            }
            inlays = savedInlays(ctx, saved, x: margin, y: leftH + 16, w: inner, r: r)
        } else {
            let r = ctx.ruler, w = ctx.width, h = r.u(796)
            let rightX = r.u(686), rightW = w - rightX - r.u(21)
            scene = Scene(width: w, height: h + r.u(14)) {
                reading(ctx, name, w: r.u(638), h: h, r: r).at(r.u(25), r.u(6))
                savedPanel(ctx, saved, w: rightW, h: h, r: r).at(rightX, r.u(6))
            }
            inlays = savedInlays(ctx, saved, x: rightX, y: r.u(6), w: rightW, r: r)
        }
        var doing = tools(ctx, name)
        for one in saved.shelf { doing["remove-\(one.number)"] = ("save_name", ["number": one.number, "saved": false]) }
        var moves = acts(ctx, name, list: [], start: 0, pushes: false)
        // Back to where it says, whichever way they came: the Names, with this one in the arch.
        moves["back"] = .go(Go(set: ["sheet": NSNull(), "filter": NSNull(), "q": NSNull(), "shelf": NSNull()]))
        moves["browse"] = moves["back"]
        moves["note-away"] = .go(Go(set: ["noted": name.number]))
        moves["saved-clear"] = .go(Go(set: ["sq": NSNull(), "sshelf": NSNull()]))
        if saved.start > 0 { moves["saved-back"] = .go(Go(set: ["sshelf": max(0, saved.start - shelfSize)])) }
        if saved.start + shelfSize < saved.all.count { moves["saved-on"] = .go(Go(set: ["sshelf": saved.start + shelfSize])) }
        for one in saved.shelf { moves["saved-\(one.number)"] = .go(Go(set: ["name": one.number])) }
        return [Section(nil, [.scene(PageSceneBlock(scene, actions: doing, acts: moves, inlays: inlays))], wide: true),
                Section(nil, [.action(copy(name))], wide: true)]
    }

    private struct SavedList {
        let all: [NameEntry]
        let shelf: [NameEntry]
        let start: Int
    }

    private static func savedList(_ ctx: Context) -> SavedList {
        let query = (ctx.state.string("sq") ?? "").trimmingCharacters(in: .whitespaces).lowercased()
        let all = ctx.model.names.sorted { $0.number < $1.number }.filter { ctx.model.bookmarks.contains($0.number) && matches($0, query) }
        let wanted = ctx.state.int("sshelf") ?? 0
        let start = wanted < all.count ? max(0, wanted) : 0
        return SavedList(all: all, shelf: Array(all[start..<min(start + shelfSize, all.count)]), start: start)
    }

    private static func sidePanelHeight(_ ctx: Context, r: Ruler, wide: Bool) -> Double {
        ctx.model.bookmarks.isEmpty ? r.u(560) : r.u(162) + r.u(105) * 5 + r.u(70)
    }

    /// The Name large in its arch, the way on either side, and what saving it did.
    private static func reading(_ ctx: Context, _ name: NameEntry, w: Double, h: Double, r: Ruler) -> Node {
        let saved = ctx.model.bookmarks.contains(name.number)
        let cx = w / 2, inner = w - r.u(130), archH = r.u(569)
        let chipH = r.u(36), lower = r.u(569)
        let (before, after) = neighbours(ctx, name, list: [])
        return Node.group {
            Node.lattice(w, h, corner: r.u(16))
            Node.image("art/names-arch-l.jpg", dark: "art/names-arch-d.jpg", fit: "fill").size(w, archH).corner(r.u(16)).clip()
            Node.rect(fill: Noor.surface, stroke: Noor.hairline, lineWidth: 1, corner: r.u(10)).size(w - r.u(12), h - lower - r.u(10)).at(r.u(6), lower)
            Node.rect(stroke: Noor.inlay, lineWidth: 1.2, corner: r.u(16)).size(w, h)
            Node.group {
                Node.capsule(fill: Noor.quiet, stroke: Noor.hairline, lineWidth: 1).size(r.u(160), chipH)
                Node.symbol("arrow.backward", color: Noor.text).size(r.f(15, min: 11), r.f(13, min: 10)).at(r.u(14), (chipH - r.f(13, min: 10)) / 2)
                Node.say(L("Back to names"), r.u(40), 0, r.u(114), chipH, size: r.f(15.5, min: 11.5))
            }
            .size(r.u(160), chipH).at(r.u(16), r.u(16)).area("back", label: L("Back to names"), hover: .init(scale: 1.02))
            Node.group {
                Node.capsule(fill: Noor.quiet, stroke: Noor.hairline, lineWidth: 1).size(r.u(132), chipH)
                Node.say(L("Name {number} of 99", ["number": Format.integer(name.number)]), 4, 0, r.u(124), chipH, size: r.f(15.5, min: 11.5), align: "center")
            }
            .size(r.u(132), chipH).at(w - r.u(148), r.u(16))
            Node.gilded(name.arabic, (w - inner) / 2, r.u(128), inner, r.u(190), size: r.f(fitted(arabic: name.arabic, inner * 0.92 / r.s, 112), min: 30), weight: "medium").leftToRight()
            Node.say(name.transliteration, (w - inner) / 2, r.u(310), inner, r.u(62), size: r.f(fitted(name.transliteration, inner / r.s, 46, 0.54), min: 18), weight: "semibold", align: "center")
            Node.say(name.meaning, (w - inner) / 2, r.u(368), inner, r.u(46), size: r.f(fitted(name.meaning, inner / r.s, 32, 0.47), min: 14), color: Self.lilac, align: "center")
            Node.ornament(cx: cx, cy: r.u(441), rule: r.u(88), rosette: r.u(26), color: Noor.warm)
            sourceRow(name, cx: cx, y: r.u(466), r: r)
            step("previous", heading: L("Previous"), under: before?.transliteration ?? L("(no previous)"), symbol: "chevron.backward", x: r.u(16), y: lower + r.u(13), w: r.u(170), r: r, disabled: before == nil)
            Node.group {
                Node.capsule(fill: Noor.quiet, stroke: Noor.hairline, lineWidth: 1).size(r.u(106), r.u(36))
                Node.say(L("{number} of 99", ["number": Format.integer(name.number)]), 4, 0, r.u(98), r.u(36), size: r.f(16.5, min: 11.5), align: "center")
            }
            .size(r.u(106), r.u(36)).at(cx - r.u(53), lower + r.u(29))
            step("following", heading: L("Next"), under: after?.transliteration ?? L("(no next)"), symbol: "chevron.forward", x: w - r.u(181), y: lower + r.u(13), w: r.u(165), r: r, disabled: after == nil)
            saveStrip(ctx, name, saved: saved, w: w - r.u(36), r: r).at(r.u(18), lower + r.u(107))
        }
        .size(w, h)
    }

    private static func arabicLine(_ name: NameEntry, _ x: Double, _ w: Double, _ h: Double, size: Double) -> Node {
        Node.say(name.arabic, x, 0, w, h, size: size, align: "center").leftToRight()
    }

    private static let lilac = Color.adaptive(light: "#5A44A8", dark: "#B8B0F2")

    private static func sourceRow(_ name: NameEntry, cx: Double, y: Double, r: Ruler) -> Node {
        let h = r.u(56), meaningW = r.u(204)
        let long = name.meaning.count > 22
        return Node.group {
            Node.symbol("book", color: Noor.text).size(r.f(27, min: 17), r.f(24, min: 15)).at(r.u(0), r.u(12))
            Node.say(L("Source"), r.u(42), 0, r.u(100), h / 2, size: r.f(17.5, min: 11.5), color: Noor.muted)
            Node.say("AlAdhan", r.u(42), h / 2, r.u(100), h / 2, size: r.f(19, min: 12))
            Node.rect(fill: Noor.inlay).size(1, r.u(44)).at(r.u(152), r.u(6))
            Node.say(L("English meaning"), r.u(184), 0, meaningW, h / 2, size: r.f(17.5, min: 11.5), color: Noor.muted)
            // The long ones take two lines rather than run out onto the lattice.
            Node.say(name.meaning, r.u(184), h / 2, meaningW, long ? h * 0.82 : h / 2, size: r.f(long ? 15 : 19, min: 11), color: Noor.text, lines: long ? 2 : 1)
        }
        .size(r.u(424), h).at(cx - r.u(174), y)
    }

    private static func step(_ id: String, heading: String, under: String, symbol: String, x: Double, y: Double, w: Double, r: Ruler, disabled: Bool) -> Node {
        let h = r.u(71), glyph = r.f(15, min: 11)
        let forward = symbol == "chevron.forward"
        return Node.group {
            Node.rect(fill: Noor.quiet, stroke: Noor.edge, lineWidth: 1.1, corner: r.u(20)).size(w, h)
            // The chevron stays against its word, whichever word it is.
            let word = Double(heading.count) * r.f(19, min: 12.5) * 0.5, gap = r.u(12)
            let start = (w - word - gap - glyph * 0.62) / 2
            Node.say(heading, forward ? start : start + glyph * 0.62 + gap, r.u(8), word + r.u(6), r.u(32), size: r.f(19, min: 12.5), color: disabled ? Noor.muted : Noor.text, align: "center")
            Node.say(under, r.u(8), r.u(40), w - r.u(16), r.u(24), size: r.f(14, min: 11), color: Noor.muted, align: "center")
            Node.symbol(symbol, color: disabled ? Noor.muted : Noor.text).size(glyph * 0.62, glyph).at(forward ? start + word + gap : start, r.u(16))
        }
        .size(w, h).at(x, y).area(id, label: heading + ", " + under, disabled: disabled)
    }

    /// Save it, or the gold strip that says it is: Undo really takes it out again, and the cross only closes the strip.
    private static func saveStrip(_ ctx: Context, _ name: NameEntry, saved: Bool, w: Double, r: Ruler) -> Node {
        let h = r.u(88), size = r.f(19, min: 12.5)
        return Node.group {
            if saved && ctx.state.int("noted") != name.number {
                Node.rect(stroke: .adaptive(light: "#B48A3E", dark: "#EFC77E"), lineWidth: 1.8, corner: r.u(20)).gradient([.adaptive(light: "#F8EEDC", dark: "#2B2348"), .adaptive(light: "#FBF9FD", dark: "#191D4C")], from: (0, 0.5), to: (1, 0.5)).size(w, h).shadow(.hex("#EFC77E44"), radius: r.u(10), dx: 0, dy: 0)
                Node.symbol("bookmark.fill", color: .adaptive(light: "#B48A3E", dark: "#F3C877")).size(r.f(22, min: 15), r.f(28, min: 18)).at(r.u(30), (h - r.f(28, min: 18)) / 2)
                Node.say(L("Saved to your names"), r.u(78), 0, w - r.u(250), h, size: size)
                Node.pill("save", label: L("Undo"), spoken: L("Remove {name} from saved names", ["name": name.transliteration]), x: w - r.u(157), y: (h - r.u(44)) / 2, w: r.u(97), h: r.u(44), size: r.f(18, min: 12.5))
                Node.group { Node.symbol("xmark", color: Noor.text).size(r.f(13, min: 10), r.f(13, min: 10)).at(r.u(12), r.u(12)) }
                    .size(r.u(38), r.u(38)).at(w - r.u(50), (h - r.u(38)) / 2).area("note-away", label: L("Close"))
            } else {
                savePill(saved: saved, name: name, x: (w - r.u(240)) / 2, y: (h - r.u(58)) / 2, w: r.u(240), h: r.u(58), size: size)
            }
        }
        .size(w, h)
    }

    private static func savedPanel(_ ctx: Context, _ saved: SavedList, w: Double, h: Double, r: Ruler) -> Node {
        let nothingSaved = ctx.model.bookmarks.isEmpty
        let rowsY = r.u(162), footH = r.u(60), glyph = r.f(20, min: 14), rowsH = h - rowsY - footH - r.u(10)
        let count = ctx.model.bookmarks.count
        return Node.group {
            Node.panel(w, h, corner: r.u(18))
            Node.group { Node.spandrel(r.u(110), r.u(110)).at(w - r.u(110), 0) }.size(w, h).corner(r.u(18)).clip()
            Node.say(L("Saved names"), r.u(21), r.u(14), w - r.u(140), r.u(42), size: r.f(30, min: 18), weight: "semibold")
            Node.say(L("Your saved names from the 99 Names"), r.u(21), r.u(50), w - r.u(120), r.u(30), size: r.f(19, min: 12), color: Noor.muted)
            if nothingSaved {
                emptyPanel(symbol: "book", title: L("No saved names yet"), detail: L("Save names as you explore the 99 Names. They stay on this Mac."), button: ("browse", L("Browse names")), w: w - r.u(34), h: rowsH + rowsY - r.u(100), r: r).at(r.u(17), r.u(100))
            } else {
                Node.rect(fill: Noor.well.tuned(alpha: 0.45), stroke: Noor.hairline, lineWidth: 1, corner: r.u(14)).size(w - r.u(34), r.u(48)).at(r.u(17), r.u(97))
                Node.symbol("magnifyingglass", color: Noor.text).size(glyph, glyph).at(r.u(34), r.u(97) + (r.u(48) - glyph) / 2)
                if saved.all.isEmpty {
                    let query = ctx.state.string("sq") ?? ""
                    emptyPanel(symbol: "magnifyingglass", title: L("No results for “{query}”", ["query": query]), detail: L("Try a different spelling or name."), button: ("saved-clear", L("Clear search")), w: w - r.u(34), h: rowsH, r: r).at(r.u(17), rowsY)
                } else {
                    Node.scroll(contentHeight: Double(saved.shelf.count) * r.u(105)) {
                        for (i, one) in saved.shelf.enumerated() {
                            savedRow(one, w: w - r.u(34), r: r).at(0, Double(i) * r.u(105))
                        }
                    }
                    .size(w - r.u(34), rowsH).at(r.u(17), rowsY).id("saved-list")
                }
            }
            Node.rect(fill: Noor.hairline).size(w - r.u(36), 1).at(r.u(18), h - footH)
            Node.symbol("laptopcomputer", color: Noor.text).size(r.f(28, min: 18), r.f(20, min: 13)).at(r.u(22), h - footH + (footH - r.f(20, min: 13)) / 2)
            Node.say(L("Saved on this Mac · {count}", ["count": countWords(count)]), r.u(64), h - footH, w * 0.6, footH, size: r.f(16, min: 11), color: Noor.muted)
            if saved.all.count > shelfSize {
                Node.pill("saved-back", label: "", spoken: L("Earlier"), x: w - r.u(112), y: h - footH + r.u(12), w: r.u(44), h: r.u(36), symbol: "chevron.backward", disabled: saved.start == 0, size: r.f(13, min: 10))
                Node.pill("saved-on", label: "", spoken: L("Later"), x: w - r.u(60), y: h - footH + r.u(12), w: r.u(44), h: r.u(36), symbol: "chevron.forward", disabled: saved.start + shelfSize >= saved.all.count, size: r.f(13, min: 10))
            }
        }
        .size(w, h)
    }

    private static func savedRow(_ name: NameEntry, w: Double, r: Ruler) -> Node {
        let h = r.u(92), medal = r.u(34)
        let arabicX = r.u(62), arabicW = r.u(136), textX = r.u(214), removeW = r.u(140), textW = w - textX - removeW - r.u(24)
        return Node.group {
            Node.group {
                Node.rect(fill: Noor.quiet, stroke: Noor.hairline, lineWidth: 1, corner: r.u(14)).size(w, h)
                Node.ellipse(fill: .adaptive(light: "#EEE8F5", dark: "#232A66"), stroke: .adaptive(light: "#C9BFE0", dark: "#3D4390"), lineWidth: 1).size(medal, medal).at(r.u(18), (h - medal) / 2)
                Node.say(Format.integer(name.number), r.u(18), (h - medal) / 2, medal, medal, size: r.f(16, min: 11), align: "center", tabular: true)
                arabicLine(name, arabicX, arabicW, h, size: r.f(fitted(arabic: name.arabic, arabicW / r.s, 38), min: 14))
                Node.say(name.transliteration, textX, h * 0.14, textW, h * 0.42, size: r.f(fitted(name.transliteration, textW / r.s, 22, 0.53), min: 12))
                Node.say(name.meaning, textX, h * 0.52, textW, h * 0.34, size: r.f(fitted(name.meaning, textW / r.s, 18, 0.47), min: 11), color: Noor.muted)
            }
            .size(w, h)
            .area("saved-\(name.number)", label: L("Open {name}", ["name": name.transliteration]), hover: nil, press: nil)
            Node.pill("remove-\(name.number)", label: L("Remove"), spoken: L("Remove {name} from saved names", ["name": name.transliteration]), x: w - removeW - r.u(18), y: (h - r.u(46)) / 2, w: removeW, h: r.u(46), symbol: "bookmark", size: r.f(17, min: 12))
        }
        .size(w, h)
    }

    private static func savedInlays(_ ctx: Context, _ saved: SavedList, x: Double, y: Double, w: Double, r: Ruler) -> [PageInlay] {
        guard !ctx.model.bookmarks.isEmpty else { return [] }
        let query = ctx.state.string("sq") ?? "", glyph = r.f(20, min: 14)
        return [PageInlay(x: x + r.u(34) + glyph + r.u(10), y: y + r.u(97), w: w - r.u(68) - glyph - r.u(10), h: r.u(48),
                          .draftField(L("Search saved names"), placeholder: L("Search saved names…"), button: L("Clear"), key: "sq", value: query.isEmpty ? nil : query, live: true, set: ["sshelf": NSNull()]))]
    }

    // MARK: What they do

    private static func copy(_ name: NameEntry) -> Action {
        Action(L("Copy"), act: .copy("\(name.arabic) · \(name.transliteration) · \(name.meaning)"), symbol: "doc.on.doc")
    }

    private static func tools(_ ctx: Context, _ name: NameEntry) -> [String: (tool: String, input: [String: Any])] {
        ["save": ("save_name", ["number": name.number, "saved": !ctx.model.bookmarks.contains(name.number)])]
    }

    static let shelfSize = 20

    /// Where in the list the shelf starts: where they turned to, or wherever the Name being read is.
    private static func shelf(_ ctx: Context, _ list: [NameEntry], selected: NameEntry?) -> Int {
        if let wanted = ctx.state.int("shelf"), wanted >= 0, wanted < list.count { return wanted }
        guard let selected, let i = list.firstIndex(of: selected) else { return 0 }
        return i / shelfSize * shelfSize
    }

    private static func acts(_ ctx: Context, _ selected: NameEntry, list: [NameEntry], start: Int, pushes: Bool) -> [String: PageAct] {
        let isSaved = ctx.state.string("filter") == "saved"
        var out: [String: PageAct] = [
            "saved-filter": .go(Go(set: ["filter": isSaved ? NSNull() : "saved", "shelf": NSNull(), "name": NSNull()])),
            "browse": .go(Go(set: ["filter": NSNull(), "shelf": NSNull()])),
            "clear": .go(Go(set: ["q": NSNull(), "shelf": NSNull()])),
            "read": .go(Go(set: ["name": selected.number, "sheet": "name"], push: true)),
        ]
        if start > 0 { out["shelf-back"] = .go(Go(set: ["shelf": max(0, start - shelfSize)])) }
        if start + shelfSize < list.count { out["shelf-on"] = .go(Go(set: ["shelf": start + shelfSize])) }
        for name in list[min(start, list.count)..<min(start + shelfSize, list.count)] {
            out["name-\(name.number)"] = pushes ? .go(Go(set: ["name": name.number, "sheet": "name"], push: true)) : .go(Go(set: ["name": name.number]))
            out["open-\(name.number)"] = .go(Go(set: ["name": name.number, "sheet": "name"], push: true))
        }
        let beside = neighbours(ctx, selected, list: list)
        if let before = beside.before { out["previous"] = .go(Go(set: ["name": before.number, "shelf": NSNull()])) }
        if let after = beside.after { out["following"] = .go(Go(set: ["name": after.number, "shelf": NSNull()])) }
        return out
    }

    /// Next and Previous walk what's shown: all 99, or the search's or the saved ones.
    private static func neighbours(_ ctx: Context, _ name: NameEntry, list: [NameEntry]) -> (before: NameEntry?, after: NameEntry?) {
        let walk = list.contains(name) ? list : ctx.model.names.sorted { $0.number < $1.number }
        guard let i = walk.firstIndex(of: name) else { return (nil, nil) }
        return (i > 0 ? walk[i - 1] : nil, i + 1 < walk.count ? walk[i + 1] : nil)
    }

    /// A size that fits a box: `em` is a line's width per character, in ems, for the text and weight it is. Names run from a word to a phrase.
    private static func fitted(_ words: String, _ box: Double, _ size: Double, _ em: Double) -> Double {
        min(size, box / (Double(words.count) * em))
    }

    /// The same for Arabic, whose marks take no width of their own.
    private static func fitted(arabic: String, _ box: Double, _ size: Double) -> Double {
        min(size, box / (Double(bare(arabic).count) * 0.47))
    }
}
