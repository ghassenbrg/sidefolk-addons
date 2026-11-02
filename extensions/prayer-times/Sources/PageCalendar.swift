import Foundation
import SidefolkExtensionKit

/// Calendar: a month as the provider returned it, under a method it always names. It adds nothing to Sidefolk's own Calendar. Dates are calculated: a future one is no promise of a moon sighting.
@MainActor
enum CalendarPage {
    /// `h` a Hijri month, `g` a Gregorian one, as `axis:year:month`.
    private static func where_(_ state: Arguments, model: NoorModel) -> (axis: String, year: Int, month: Int)? {
        if let text = state.string("month") {
            let p = text.split(separator: ":").map(String.init)
            if p.count == 3, let y = Int(p[1]), let m = Int(p[2]) { return (p[0], y, m) }
        }
        guard let hijri = model.snapshot().calendar?.hijri else {
            let today = model.snapshot().localDate
            return today.map { ("g", $0.year, $0.month) }
        }
        return ("h", hijri.year, hijri.month)
    }

    static func wanted(_ state: Arguments, model: NoorModel) -> [String] {
        guard let at = where_(state, model: model) else { return [] }
        let year = at.axis == "h" ? at.year : (model.snapshot().calendar?.hijri.year ?? 0)
        return ["\(at.axis):\(at.year):\(at.month)"] + (year > 0 ? ["o:\(year)"] : [])
    }

    private static func month(_ ctx: Context) -> (axis: String, year: Int, month: Int, data: CalendarMonth?)? {
        guard let at = where_(ctx.state, model: ctx.model) else { return nil }
        return (at.axis, at.year, at.month, at.axis == "h" ? ctx.model.hijriMonth(at.year, at.month) : ctx.model.gregorianMonth(at.year, at.month))
    }

    static func sections(_ ctx: Context) -> [Section] {
        guard ctx.snapshot.localDate != nil, let m = month(ctx) else { return [NoorPage.unavailable(ctx)].compactMap { $0 } }
        guard let data = m.data else {
            let busy = ctx.model.load == .loading
            return [NoorPage.status(ctx, symbol: "calendar", title: busy ? L("Loading the month…") : L("This month isn't here yet"), detail: busy ? "" : Words.problem(ctx.model.problem), buttons: busy ? [] : [("retry", L("Try again"), true, .tool("refresh"))])]
        }
        let selected = ctx.state.string("sel").flatMap(CivilDate.init(iso:)) ?? ctx.snapshot.localDate ?? data.days[0].gregorian
        let paired = data.days.first { $0.gregorian == selected } ?? ctx.model.pairedDay(selected)
        var acts: [String: PageAct] = [
            "prev": .go(Go(set: ["month": neighbour(m, by: -1)])), "next": .go(Go(set: ["month": neighbour(m, by: 1)])),
            "today": .go(Go(set: ["month": NSNull(), "sel": NSNull()])),
            "hijri": .go(Go(set: ["month": axisSwitch(m, to: "h", data: data)])), "gregorian": .go(Go(set: ["month": axisSwitch(m, to: "g", data: data)])),
            "convert": .go(Go(set: ["sheet": "convert"], push: true)),
            "occasions": .go(Go(set: ["sheet": "occasions"], push: true)),
            "ramadan": .go(Go(set: ["sheet": "ramadan"], push: true)),
        ]
        // Each day's area says which day, as its own: an area's value would arrive under `value`, and a page's state is named.
        for day in data.days { acts["d\(day.gregorian.iso)"] = .go(Go(set: ["sel": day.gregorian.iso])) }
        let scene: Scene, inlay: PageInlay
        if ctx.narrow {
            let margin = 12.0, inner = 10.0, cardW = ctx.width - (margin + inner) * 2
            let cardR = Ruler(width: min(cardW, 805) / 805 * 1290)
            let cardH = monthHeight(cardW, r: cardR), sideH = 610.0, sideR = Ruler(width: 1290 * 0.82)
            let latticeH = cardH + sideH + inner * 3
            let sideW = ctx.width - (margin + inner) * 2
            scene = Scene(width: ctx.width, height: latticeH + 8) {
                latticePlate(ctx.width - margin * 2, latticeH, corner: 16, r: sideR).at(margin, 0)
                monthCard(ctx, m: m, data: data, w: cardW, h: cardH, r: cardR, selected: selected).at(margin + inner, inner)
                dayPanel(ctx, paired: paired, date: selected, w: sideW, h: sideH, r: sideR).at(margin + inner, cardH + inner * 2)
            }
            inlay = methodInlay(ctx, at: monthMethodRect(cardW, r: cardR), dx: margin + inner, dy: inner)
        } else {
            // Places in the board's own numbers (P04), from the top left of the page below the tabs.
            let r = ctx.ruler, w = ctx.width
            let x = r.u(25), y = r.u(7), latticeW = w - x - r.u(19), latticeH = r.u(766)
            let cardW = r.u(805), cardH = r.u(717), cardX = x + r.u(22), cardY = y + r.u(23)
            let sideX = x + r.u(834), sideY = y + r.u(21), sideW = latticeW - r.u(834) - r.u(14), sideH = latticeH - r.u(21)
            scene = Scene(width: w, height: y + latticeH + r.u(24)) {
                latticePlate(latticeW, latticeH, corner: r.u(16), r: r).at(x, y)
                Node.rect(stroke: Noor.pickedEdge, lineWidth: 1, corner: r.u(16)).size(latticeW, latticeH).at(x, y)
                monthCard(ctx, m: m, data: data, w: cardW, h: cardH, r: r, selected: selected).at(cardX, cardY)
                dayPanel(ctx, paired: paired, date: selected, w: sideW, h: sideH, r: r).at(sideX, sideY)
            }
            inlay = methodInlay(ctx, at: monthMethodRect(cardW, r: r), dx: cardX, dy: cardY)
        }
        return [Section(nil, [.scene(PageSceneBlock(scene, acts: acts, inlays: [inlay]))], wide: true)]
    }

    static var firstWeekday: Int { Calendar.current.firstWeekday }

    private static func neighbour(_ m: (axis: String, year: Int, month: Int, data: CalendarMonth?), by delta: Int) -> String {
        let moved = delta > 0 ? NoorModel.monthAfter(m.year, m.month) : NoorModel.monthBefore(m.year, m.month)
        return "\(m.axis):\(moved.0):\(moved.1)"
    }

    /// The other axis at the same place in time: its first shown day's month there.
    private static func axisSwitch(_ m: (axis: String, year: Int, month: Int, data: CalendarMonth?), to axis: String, data: CalendarMonth) -> String {
        guard axis != m.axis, let middle = data.days.dropFirst(data.days.count / 2).first else { return "\(m.axis):\(m.year):\(m.month)" }
        return axis == "h" ? "h:\(middle.hijri.year):\(middle.hijri.month)" : "g:\(middle.gregorian.year):\(middle.gregorian.month)"
    }

    // MARK: The month, on its pearl card

    // Pearl in both appearances, a page of paper set in the frame: its ink is its own, so it reads on either.
    private static let pearl = Color.hex("#F2ECF6"), pearlDeep = Color.hex("#E5DDEC"), pearlLine = Color.hex("#D3CAE0")
    private static let ink = Color.hex("#14143F"), inkSoft = Color.hex("#3F3B66"), inkQuiet = Color.hex("#6C678E")
    private static let peach = Color.adaptive(light: "#C9AB72", dark: "#E9A77C")

    /// Under this the title and its controls take a line each.
    private static func stacked(_ w: Double) -> Bool { w < 460 }

    private static func monthHeight(_ w: Double, r: Ruler) -> Double {
        stacked(w) ? 118 + 44 + 50 * 6 + 24 : r.u(717)
    }

    private static func monthMethodRect(_ w: Double, r: Ruler) -> (x: Double, y: Double, w: Double, h: Double) {
        if stacked(w) { let mw = (w - 40) * 0.5; return (w - 16 - mw, 64, mw, 36) }
        return (r.u(620), r.u(93), r.u(154), r.u(42))
    }

    /// The month's method, a real menu over the pill the card draws.
    private static func methodInlay(_ ctx: Context, at rect: (x: Double, y: Double, w: Double, h: Double), dx: Double, dy: Double) -> PageInlay {
        PageInlay(x: dx + rect.x, y: dy + rect.y, w: rect.w, h: rect.h, methodChoice(ctx))
    }

    /// One choice of method for every date Noor shows; the prayer method is separate, and not touched by this.
    private static func methodChoice(_ ctx: Context) -> Block {
        let methods = ctx.model.calendarMethods.isEmpty ? [CalendarMethodInfo(method: .uaq, name: "Umm al-Qura", description: "", validity: "")] : ctx.model.calendarMethods
        return .choice(L("Calendar method"), detail: L("Used on Overview, Calendar, Ramadan, conversions and occasions."), options: methods.map { ($0.method.rawValue, $0.name) },
                       selected: ctx.model.prefs.calendarMethod.rawValue, tool: "set_calendar_method")
    }

    /// The boards' quiet lattice behind these panels, its pattern one size on every plate: thin copper lines on lapis.
    private static func latticePlate(_ w: Double, _ h: Double, corner: Double, r: Ruler) -> Node {
        let side = max(r.u(1150), w, h)
        return Node.group { Node.image("art/lattice-l.jpg", dark: "art/calendar-lattice-d.jpg", fit: "cover").size(side, side) }.size(w, h).corner(corner).clip()
    }

    /// A card whose corners step in, each an ear: out, a hollow, and out again.
    private static func earPath(_ w: Double, _ h: Double, ear c: Double) -> String {
        let a = c * 0.28, b = c * 0.72
        return "M \(n(c + a)) 0 L \(n(w - c - a)) 0 C \(n(w - c)) 0 \(n(w - b)) \(n(a * 0.4)) \(n(w - b)) \(n(a)) C \(n(w - b)) \(n(b)) \(n(w - a)) \(n(b)) \(n(w - a * 0.7)) \(n(b)) C \(n(w - a * 0.3)) \(n(b)) \(n(w)) \(n(c)) \(n(w)) \(n(c + a)) "
            + "L \(n(w)) \(n(h - c - a)) C \(n(w)) \(n(h - c)) \(n(w - a * 0.3)) \(n(h - b)) \(n(w - a * 0.7)) \(n(h - b)) C \(n(w - a)) \(n(h - b)) \(n(w - b)) \(n(h - b)) \(n(w - b)) \(n(h - a)) C \(n(w - b)) \(n(h - a * 0.4)) \(n(w - c)) \(n(h)) \(n(w - c - a)) \(n(h)) "
            + "L \(n(c + a)) \(n(h)) C \(n(c)) \(n(h)) \(n(b)) \(n(h - a * 0.4)) \(n(b)) \(n(h - a)) C \(n(b)) \(n(h - b)) \(n(a)) \(n(h - b)) \(n(a * 0.7)) \(n(h - b)) C \(n(a * 0.3)) \(n(h - b)) 0 \(n(h - c)) 0 \(n(h - c - a)) "
            + "L 0 \(n(c + a)) C 0 \(n(c)) \(n(a * 0.3)) \(n(b)) \(n(a * 0.7)) \(n(b)) C \(n(a)) \(n(b)) \(n(b)) \(n(b)) \(n(b)) \(n(a)) C \(n(b)) \(n(a * 0.4)) \(n(c)) 0 \(n(c + a)) 0 Z"
    }

    /// A faint rosette for a cell with no day in it: two stars, one path.
    private static func rosette(_ cx: Double, _ cy: Double, _ r: Double) -> String {
        func star(_ outer: Double, _ inner: Double, turn: Double) -> String {
            var out = ""
            for i in 0..<16 {
                let p = clockPoint(cx, cy, i % 2 == 0 ? outer : inner, turn + Double(i) * 22.5)
                out += (i == 0 ? "M " : "L ") + "\(n(p.x)) \(n(p.y)) "
            }
            return out + "Z "
        }
        return star(r, r * 0.7, turn: 0) + star(r * 0.62, r * 0.42, turn: 22.5)
    }

    private static func monthCard(_ ctx: Context, m: (axis: String, year: Int, month: Int, data: CalendarMonth?), data: CalendarMonth, w: Double, h: Double, r: Ruler, selected: CivilDate) -> Node {
        let isHijri = m.axis == "h", tight = stacked(w)
        let title = isHijri ? (data.days.first.map { "\(Words.hijriMonth($0.hijri)) \($0.hijri.year)" } ?? "") : Words.gregorianMonth(m.year, m.month)
        let today = ctx.snapshot.localDate
        let lead = data.leadingBlanks(firstWeekday: firstWeekday)
        let weeks = Int(ceil(Double(lead + data.dayCount) / 7))
        let gridX = tight ? 12 : r.u(27), gridY = tight ? 118 : r.u(155), gridW = w - gridX * 2, headH = tight ? 32 : r.u(43)
        let gridH = h - gridY - (tight ? 16 : r.u(39)), cell = gridW / 7, rowH = (gridH - headH) / Double(max(weeks, 1))
        let numberSize = tight ? max(r.f(27), 15) : r.f(27, min: 15)
        let quietSize = tight ? 10.5 : r.f(13, min: 10.5)
        let segment = tight ? (x: 16.0, y: 64.0, w: (w - 40) * 0.5, h: 36.0) : (x: r.u(407), y: r.u(93), w: r.u(196), h: r.u(42))
        let method = monthMethodRect(w, r: r)
        let nav = tight ? 36.0 : r.u(46), todayW = tight ? 64.0 : r.u(91), navY = tight ? 16.0 : r.u(25), navGap = tight ? 6.0 : r.u(14)
        let nextX = w - (tight ? 16 : r.u(35)) - nav, todayX = nextX - navGap - todayW, prevX = todayX - navGap - nav
        var lines = ""
        for i in 1..<7 { lines += "M \(n(gridX + cell * Double(i))) \(n(gridY)) L \(n(gridX + cell * Double(i))) \(n(gridY + gridH)) " }
        for i in 0..<weeks { lines += "M \(n(gridX)) \(n(gridY + headH + rowH * Double(i))) L \(n(gridX + gridW)) \(n(gridY + headH + rowH * Double(i))) " }
        var blanks = ""
        for slot in (Array(0..<lead) + Array((lead + data.dayCount)..<(weeks * 7))) {
            blanks += rosette(gridX + cell * (Double(slot % 7) + 0.5), gridY + headH + rowH * (Double(slot / 7) + 0.5), min(cell, rowH) * 0.21)
        }
        func button(_ id: String, _ spoken: String, x: Double, width: Double, symbol: String? = nil, word: String? = nil) -> Node {
            Node.group {
                Node.rect(fill: pearlDeep, stroke: Color.hex("#C8BEDA"), lineWidth: 1, corner: nav * 0.24).size(width, nav)
                if let symbol { Node.symbol(symbol, color: ink).size(nav * 0.26, nav * 0.36).at((width - nav * 0.26) / 2, nav * 0.32) }
                if let word { Node.say(word, 4, 0, width - 8, nav, size: tight ? 13 : r.f(16.5, min: 12.5), weight: "medium", color: ink, align: "center") }
            }
            .size(width, nav).at(x, navY).area(id, label: spoken)
        }
        func side(_ id: String, _ word: String, x: Double, width: Double, on: Bool) -> Node {
            Node.group {
                if on { Node.rect(corner: segment.h * 0.24).gradient([.hex("#7557C2"), .hex("#5A3EA4")]).size(width, segment.h - 8).at(0, 4) }
                Node.say(word, 2, 0, width - 4, segment.h, size: tight ? 12.5 : r.f(15.5, min: 12), weight: "medium", color: on ? Noor.onChosen : inkSoft, align: "center")
            }
            .size(width, segment.h).at(x, segment.y).area(id, label: word, selected: on)
        }
        let earSize = tight ? 18 : r.u(32)
        return Node.group {
            Node.path(earPath(w, h, ear: earSize)).gradient([.hex("#F6F0F9"), pearl, .hex("#EDE5F2")]).size(w, h).at(0, 0).shadow(.hex("#0A0B2A66"), radius: 14, dx: 0, dy: 5)
            Node.path(earPath(w, h, ear: earSize), stroke: peach, lineWidth: tight ? 1.5 : r.u(2.4)).size(w, h).at(0, 0)
            Node.say(title, tight ? 16 : r.u(38), tight ? 12 : r.u(28), tight ? prevX - 24 : prevX - r.u(48), tight ? 44 : r.u(66), size: tight ? 22 : r.f(42, min: 20), weight: "semibold", color: ink)
            button("prev", L("Previous month"), x: prevX, width: nav, symbol: "chevron.backward")
            button("today", L("Today"), x: todayX, width: todayW, word: L("Today"))
            button("next", L("Next month"), x: nextX, width: nav, symbol: "chevron.forward")
            Node.rect(fill: pearlDeep, stroke: Color.hex("#D4CAE2"), lineWidth: 1, corner: segment.h * 0.3).size(segment.w, segment.h).at(segment.x, segment.y)
            side("hijri", L("Hijri"), x: segment.x + 4, width: segment.w * 0.42, on: isHijri)
            side("gregorian", L("Gregorian"), x: segment.x + 4 + segment.w * 0.42, width: segment.w * 0.58 - 8, on: !isHijri)
            Node.group {
                Node.rect(fill: pearlDeep, stroke: Color.hex("#C8BEDA"), lineWidth: 1, corner: method.h * 0.3).size(method.w, method.h)
                Node.say(Words.calendarMethodName(ctx.model.prefs.calendarMethod), method.h * 0.3, 0, method.w - method.h * 0.3 - method.h * 0.62, method.h, size: tight ? 12.5 : r.f(15.5, min: 12), weight: "medium", color: ink)
                Node.symbol("chevron.down", color: ink).size(method.h * 0.27, method.h * 0.27).at(method.w - method.h * 0.52, method.h * 0.365)
            }
            .size(method.w, method.h).at(method.x, method.y)
            // The grid: its ground, its header and its lines in one, then what each day says.
            Node.rect(fill: .hex("#F5F0F8"), stroke: pearlLine, lineWidth: 1, corner: r.u(10)).size(gridW, gridH).at(gridX, gridY)
            Node.group { Node.rect(fill: pearlDeep).size(gridW, headH) }.size(gridW, headH).corner(r.u(10)).clip().at(gridX, gridY)
            Node.path(lines, stroke: pearlLine, lineWidth: 1).size(w, h).at(0, 0)
            if !blanks.isEmpty { Node.path(blanks, stroke: Color.hex("#D6CCE3"), lineWidth: 1).size(w, h).at(0, 0) }
            for i in 0..<7 {
                Node.say(Words.weekdayShort((firstWeekday - 1 + i) % 7 + 1), gridX + Double(i) * cell, gridY, cell, headH, size: tight ? 11.5 : r.f(16, min: 11.5), color: inkSoft, align: "center")
            }
            for (i, day) in data.days.enumerated() {
                let slot = i + lead
                dayCell(ctx, day, isHijri: isHijri, isToday: day.gregorian == today, picked: day.gregorian == selected, cell: cell, rowH: rowH, r: r, tight: tight, number: numberSize, quiet: quietSize)
                    .at(gridX + Double(slot % 7) * cell, gridY + headH + Double(slot / 7) * rowH)
            }
        }
        .size(w, h)
    }

    private static func dayCell(_ ctx: Context, _ day: CalendarDay, isHijri: Bool, isToday: Bool, picked: Bool, cell: Double, rowH: Double, r: Ruler, tight: Bool, number: Double, quiet: Double) -> Node {
        let primary = isHijri ? day.hijri.day : day.gregorian.day, secondary = isHijri ? day.gregorian.day : day.hijri.day
        let occasions = ctx.model.prefs.showOccasions ? ctx.model.occasions(on: day.gregorian) : []
        let pad = tight ? 5 : r.u(18), mark = tight ? 7 : r.u(10)
        return Node.group {
            if picked {
                Node.group {
                    Node.rect().gradient([.hex("#6E4FB8"), .hex("#4E348F")]).size(cell, rowH)
                    Node.path(rosette(cell / 2, rowH / 2, min(cell, rowH) * 0.46), stroke: .hex("#FFFFFF20"), lineWidth: 1).size(cell, rowH).at(0, 0)
                }
                .size(cell, rowH).corner(r.u(5)).clip()
            } else if isToday {
                // Today when another day is chosen: a ring, so the chosen day stays the one filled.
                Node.rect(stroke: .hex("#6E4FB8"), lineWidth: 1.5, corner: r.u(5)).size(cell - 2, rowH - 2).at(1, 1)
            }
            Node.say("\(primary)", pad, tight ? 3 : r.u(14), cell - pad - 2, tight ? 22 : r.u(38), size: number, weight: "medium", color: picked ? Noor.onChosen : ink, tabular: true)
            // The other calendar's day, quiet in its corner.
            Node.say("\(secondary)", cell * 0.4, rowH - (tight ? 17 : r.u(30)), cell * 0.6 - (tight ? 5 : r.u(12)), tight ? 15 : r.u(24), size: quiet, color: picked ? .hex("#E3DAF4") : inkQuiet, align: "trailing", tabular: true)
            if !occasions.isEmpty {
                // Two marks for more than one: a shape, not a colour alone.
                Node.symbol(occasions.count > 1 ? "circle.grid.2x1.fill" : "circle.fill", color: picked ? .hex("#FFFFFF") : .hex("#7354B8")).size(occasions.count > 1 ? mark * 1.6 : mark, mark).at(cell - mark * 2.1, tight ? 6 : r.u(14))
            }
        }
        .size(cell, rowH)
        .area("d\(day.gregorian.iso)", label: spoken(day, today: isToday, occasions: occasions), hover: .init(scale: 1.0), selected: picked)
    }

    private static func spoken(_ day: CalendarDay, today: Bool, occasions: [Occasion]) -> String {
        var parts = [Words.hijri(day.hijri), Words.date(day.gregorian)]
        if today { parts.append(L("today")) }
        parts += occasions.map(\.title)
        return parts.joined(separator: ", ")
    }

    // MARK: The chosen day, in its arched panel

    /// The panel's two scalloped corners on the side away from the month, and the same two as lines alone to double them.
    private static func dayPanelPath(_ w: Double, _ h: Double, r: Ruler) -> (shape: String, lobes: String) {
        let a = r.u(14)
        func lobes(_ d: Double) -> (top: String, bottom: String) {
            let right = w - d
            let top = "C \(n(right - r.u(105))) \(n(d)) \(n(right - r.u(62))) \(n(r.u(28) + d)) \(n(right - r.u(55))) \(n(r.u(73) + d)) C \(n(right - r.u(22))) \(n(r.u(76) + d)) \(n(right)) \(n(r.u(112) + d)) \(n(right)) \(n(r.u(153) + d)) "
            let bottom = "C \(n(right)) \(n(h - r.u(85) - d)) \(n(right - r.u(55))) \(n(h - r.u(68) - d)) \(n(right - r.u(117))) \(n(h - r.u(62) - d)) C \(n(right - r.u(135))) \(n(h - r.u(20) - d)) \(n(right - r.u(175))) \(n(h - d)) \(n(right - r.u(212))) \(n(h - d)) "
            return (top, bottom)
        }
        let line = lobes(0), inner = lobes(r.u(7))
        let shape = "M \(n(a)) 0 L \(n(w - r.u(162))) 0 \(line.top)L \(n(w)) \(n(h - r.u(118))) \(line.bottom)L \(n(a)) \(n(h)) Q 0 \(n(h)) 0 \(n(h - a)) L 0 \(n(a)) Q 0 0 \(n(a)) 0 Z"
        let right = w - r.u(7), d = r.u(7)
        let doubled = "M \(n(right - r.u(162))) \(n(d)) \(inner.top)L \(n(right)) \(n(h - r.u(118) - d)) \(inner.bottom)"
        return (shape, doubled)
    }

    /// A wide button with the board's square shoulders: what the panel leads to, after a symbol of what it is.
    private static func slab(_ id: String, _ label: String, symbol: String, x: Double, y: Double, w: Double, h: Double, filled: Bool = false, r: Ruler) -> Node {
        let glyph = r.f(26, min: 17)
        return Node.group {
            if filled {
                Node.rect(stroke: .hex("#A58DE6"), lineWidth: 1, corner: r.u(12)).gradient([.hex("#7557C2"), .hex("#553A9E")]).size(w, h)
            } else {
                Node.rect(fill: Noor.quiet, stroke: Noor.edge, lineWidth: 1.2, corner: r.u(12)).size(w, h)
            }
            Node.symbol(symbol, color: filled ? Noor.onChosen : Noor.text).size(glyph, glyph).at(r.u(22), (h - glyph) / 2)
            Node.say(label, r.u(22) + glyph + r.u(20), 0, w - r.u(22) - glyph - r.u(20) - r.u(40), h, size: r.f(17.5, min: 13), weight: "medium", color: filled ? Noor.onChosen : Noor.text)
            Node.symbol("chevron.forward", color: filled ? Noor.onChosen : Noor.text).size(r.u(9), r.u(15)).at(w - r.u(30), (h - r.u(15)) / 2)
        }
        .size(w, h).at(x, y).area(id, label: label, hover: .init(scale: 1.015))
    }

    private static func dayPanel(_ ctx: Context, paired: CalendarDay?, date: CivilDate, w: Double, h: Double, r: Ruler) -> Node {
        let occasions = ctx.model.occasions(on: date)
        let path = dayPanelPath(w, h, r: r)
        let x = r.u(28), wordsW = w - x - r.u(30), rule = w - x * 2 - r.u(2)
        let glyph = r.f(30, min: 18), textX = r.u(83), textW = w - textX - r.u(26)
        return Node.group {
            Node.path(path.shape).gradient([.adaptive(light: "#FBF8FDF7", dark: "#0C1035EB"), .adaptive(light: "#F6F1FAF5", dark: "#0E1140E6")]).size(w, h).at(0, 0)
            Node.path(path.shape, stroke: Noor.pickedEdge, lineWidth: 1).size(w, h).at(0, 0)
            Node.path(path.lobes, stroke: Noor.inlay, lineWidth: r.u(2)).size(w, h).at(0, 0).opacity(0.9)
            if let paired {
                Node.say("\(paired.hijri.day)", x, r.u(14), wordsW - r.u(60), r.u(108), size: r.f(100, min: 56), weight: "bold", tabular: true)
                Node.say("\(Words.hijriMonth(paired.hijri)) \(paired.hijri.year)", x, r.u(118), wordsW, r.u(50), size: r.f(36, min: 19), weight: "medium", color: Noor.warm)
            } else {
                Node.say(L("Not in this month"), x, r.u(60), wordsW - r.u(40), r.u(50), size: r.f(26, min: 17), color: Noor.muted)
            }
            Node.say(Words.date(date), x, r.u(166), wordsW, r.u(38), size: r.f(22, min: 13), color: Noor.muted)
            Node.rect(fill: Noor.hairline).size(rule, 1).at(x, r.u(222))
            Node.symbol("calendar", color: Noor.text).size(glyph, glyph).at(x + r.u(4), r.u(258))
            Node.say(occasions.isEmpty ? L("No listed occasion for this date.") : occasions.prefix(3).map(\.title).joined(separator: " · "), textX, r.u(232), textW, r.u(82), size: r.f(17, min: 13), lines: 3)
            Node.rect(fill: Noor.hairline).size(rule, 1).at(x, r.u(320))
            Node.symbol("gearshape", color: Noor.text).size(glyph, glyph).at(x + r.u(4), r.u(349))
            Node.say(L("Calendar method"), textX, r.u(339), textW, r.u(28), size: r.f(15.5, min: 12), color: Noor.muted)
            Node.say(Words.calendarMethodName(ctx.model.prefs.calendarMethod), textX, r.u(363), textW, r.u(28), size: r.f(17, min: 13))
            slab("convert", L("Convert a date"), symbol: "arrow.triangle.2.circlepath", x: r.u(27), y: r.u(416), w: w - r.u(27) - r.u(29), h: r.u(56), filled: true, r: r)
            slab("occasions", L("Browse listed occasions"), symbol: "book", x: r.u(27), y: r.u(482), w: w - r.u(27) - r.u(29), h: r.u(50), r: r)
            slab("ramadan", L("Plan Ramadan"), symbol: "moon", x: r.u(27), y: r.u(542), w: w - r.u(27) - r.u(29), h: r.u(50), r: r)
            Node.symbol("info.circle", color: Noor.muted).size(r.f(22, min: 15), r.f(22, min: 15)).at(r.u(32), r.u(612))
            Node.say(L("Dates follow the selected calendar method. Local announcements may differ."), r.u(62), r.u(603), w - r.u(62) - r.u(44), r.u(50), size: r.f(14.5, min: 11.5), color: Noor.muted, lines: 2)
        }
        .size(w, h)
    }

    // MARK: Convert a date and listed occasions

    /// F03: the two side by side, as the board has them; on a narrow page the one that was asked for. Copy stays a host button under the panels: an area may not copy (D105).
    static func convert(_ ctx: Context) -> [Section] { flows(ctx, asked: .convert) }
    static func occasions(_ ctx: Context) -> [Section] { flows(ctx, asked: .occasions) }

    private enum Flow { case convert, occasions }

    private static func flows(_ ctx: Context, asked: Flow) -> [Section] {
        let w = ctx.width
        let conversion = Conversion(ctx)
        var acts: [String: PageAct] = ["calendar": .go(Go(set: ["sheet": NSNull(), "tab": "calendar"]))]
        var tools: [String: (tool: String, input: [String: Any])] = [:]
        var inlays: [PageInlay] = []
        var list = OccasionList(ctx)
        list.acts(&acts)
        conversion.acts(&acts, &tools)
        let scene: Scene
        if ctx.narrow {
            let margin = 12.0, panelW = w - margin * 2, r = Ruler(width: 1290 * max(0.62, panelW / 642))
            let h = r.u(791) + (panelW < 420 ? 70 : 0)
            scene = Scene(width: w, height: h + 12) {
                if asked == .convert {
                    convertPanel(ctx, conversion, w: panelW, h: h, r: r).at(margin, 0)
                } else {
                    occasionsPanel(ctx, list, w: panelW, h: h, r: r).at(margin, 0)
                }
            }
            inlays = asked == .convert ? conversion.inlays(ctx, w: panelW, r: r, dx: margin) : list.inlays(ctx, w: panelW, h: h, r: r, dx: margin)
        } else {
            let r = ctx.ruler
            let x = r.u(26), leftW = r.u(582), gap = r.u(20), rightX = x + leftW + gap, rightW = w - rightX - r.u(20), h = r.u(791)
            scene = Scene(width: w, height: h + r.u(14)) {
                convertPanel(ctx, conversion, w: leftW, h: h, r: r).at(x, r.u(2))
                occasionsPanel(ctx, list, w: rightW, h: h, r: r).at(rightX, r.u(2))
            }
            // What types comes first, so a change in the switches beside it never moves it.
            inlays = list.inlays(ctx, w: rightW, h: h, r: r, dx: rightX, dy: r.u(2)) + conversion.inlays(ctx, w: leftW, r: r, dx: x, dy: r.u(2))
        }
        var out = [Section(nil, [.scene(PageSceneBlock(scene, actions: tools, acts: acts, inlays: inlays))], wide: true)]
        if let words = conversion.copyWords, !ctx.narrow || asked == .convert {
            out.append(Section(nil, [.action(Action(L("Copy result"), act: .copy(words), style: .primary, symbol: "doc.on.doc"))], wide: true))
        }
        return out
    }

    /// One of F03's two panels: the lattice above an arch, the title under its peak.
    private static func archPanel(_ w: Double, _ h: Double, title: String, words: String, r: Ruler) -> [Node] {
        let lift = r.u(110), corner = r.u(18)
        return [
            Node.group {
                latticePlate(w, lift + r.u(10), corner: 0, r: r)
                Node.rect().gradient([.adaptive(light: "#7354B800", dark: "#6A2FA060"), .adaptive(light: "#7354B810", dark: "#3A1E8030")], from: (1, 0), to: (0, 1)).size(w, lift + r.u(10))
                Node.path(Node.archPath(w, h, lift: lift)).gradient([.adaptive(light: "#FBF8FD", dark: "#0C1035"), .adaptive(light: "#F6F1FA", dark: "#0B0E30")]).size(w, h).at(0, 0)
                Node.path(Node.archPath(w, h, lift: lift), stroke: Noor.inlay, lineWidth: r.u(1.6)).size(w, h).at(0, 0)
                Node.path(Node.archPath(w, h, lift: lift), stroke: Noor.rosy, lineWidth: 1).size(w, h).at(0, r.u(6)).opacity(0.6)
            }
            .size(w, h).corner(corner).clip(),
            Node.rect(stroke: Noor.rosy, lineWidth: 1.2, corner: corner).size(w, h),
            Node.say(title, w * 0.12, r.u(49), w * 0.76, r.u(44), size: r.f(34, min: 20), weight: "semibold", align: "center"),
            Node.say(words, r.u(60), r.u(90), w - r.u(120), r.u(54), size: r.f(17.5, min: 12.5), color: Noor.muted, align: "center", lines: 2),
        ]
    }

    /// A pill on an F03 panel, with its words and an arrow down, under the real menu.
    private static func methodPill(_ ctx: Context, x: Double, y: Double, w: Double, h: Double, r: Ruler) -> Node {
        Node.group {
            Node.rect(fill: Noor.well, stroke: Noor.pickedEdge.tuned(alpha: 0.6), lineWidth: 1, corner: r.u(10)).size(w, h)
            Node.say(L("{method} calendar", ["method": Words.calendarMethodName(ctx.model.prefs.calendarMethod)]), r.u(14), 0, w - r.u(44), h, size: r.f(15.5, min: 12))
            Node.symbol("chevron.down", color: Noor.text).size(r.u(12), r.u(12)).at(w - r.u(30), (h - r.u(12)) / 2)
        }
        .size(w, h).at(x, y)
    }

    // MARK: Conversion

    /// What the conversion panel knows. A result stands only beside the date it answers, under the method now chosen: anything else asks to be converted again.
    @MainActor
    private struct Conversion {
        let toHijri: Bool
        let input: String
        let result: CalendarDay?
        let problem: String?

        init(_ ctx: Context) {
            toHijri = (ctx.state.string("direction") ?? "g2h") == "g2h"
            let today = ctx.snapshot.calendar
            // Untouched, the field holds today: the snapshot has its pair already, from the same provider and method, with no call.
            input = ctx.state.string("convert_date") ?? (toHijri ? today?.gregorian.iso : today.map { Conversion.iso($0.hijri) }) ?? ""
            let method = ctx.model.prefs.calendarMethod, typed = input, forward = toHijri
            result = [ctx.model.conversion, today].compactMap { $0 }.first { day in
                guard day.method == method else { return false }
                return forward ? day.gregorian.iso == typed : Conversion.iso(day.hijri) == Conversion.tidy(typed)
            }
            problem = result == nil ? ctx.model.conversionProblem : nil
        }

        static func iso(_ hijri: HijriDate) -> String { String(format: "%04d-%02d-%02d", hijri.year, hijri.month, hijri.day) }
        /// `1448-5-2` and `1448-05-02` are the same day to the tool.
        static func tidy(_ text: String) -> String {
            let p = text.split(separator: "-").compactMap { Int($0) }
            return p.count == 3 ? String(format: "%04d-%02d-%02d", p[0], p[1], p[2]) : text
        }

        var copyWords: String? {
            result.map { "\(Words.hijri($0.hijri)) = \(Words.date($0.gregorian)) (\(Words.calendarMethodName($0.method)))" }
        }

        func acts(_ acts: inout [String: PageAct], _ tools: inout [String: (tool: String, input: [String: Any])]) {
            let flip = toHijri ? "h2g" : "g2h"
            let other = result.map { toHijri ? Conversion.iso($0.hijri) : $0.gregorian.iso } ?? ""
            acts["swap"] = .go(Go(set: ["direction": flip, "convert_date": other]))
            acts["clear"] = .go(Go(set: ["convert_date": ""]))
            if let day = result {
                acts["open"] = .go(Go(set: ["sheet": NSNull(), "tab": "calendar", "month": "g:\(day.gregorian.year):\(day.gregorian.month)", "sel": day.gregorian.iso]))
            }
            if !input.isEmpty { tools["run"] = ("convert_date", ["direction": toHijri ? "g2h" : "h2g", "date": input]) }
        }

        /// The field while there's a date to type, and the panel's method. With a result the From well is words on pearl, and pressing it clears them to type another: a field's words are the theme's and wouldn't read on pearl in dark.
        func inlays(_ ctx: Context, w: Double, r: Ruler, dx: Double, dy: Double = 0) -> [PageInlay] {
            let m = Places(w: w, r: r)
            var out = [PageInlay(x: dx + m.dropX, y: dy + m.dropY, w: m.dropW, h: m.dropH, CalendarPage.methodChoice(ctx))]
            if result == nil {
                let example = toHijri ? "2026-11-02" : "1448-05-22"
                out.append(PageInlay(x: dx + m.wellX + r.u(58), y: dy + m.fromY + r.u(10), w: m.wellW - r.u(70), h: m.wellH - r.u(20),
                                     .draftField(toHijri ? L("Gregorian date") : L("Hijri date"), placeholder: example, button: L("Clear"), key: "convert_date", value: input.isEmpty ? nil : input, live: true)))
            }
            return out
        }

        /// Places on the panel, in the board's numbers.
        struct Places {
            let wellX: Double, wellW: Double, wellH: Double, fromY: Double, toY: Double, dropX: Double, dropY: Double, dropW: Double, dropH: Double
            init(w: Double, r: Ruler) {
                wellX = r.u(25); wellW = w - wellX * 2; wellH = r.u(52)
                fromY = r.u(173); toY = r.u(315)
                dropX = min(r.u(187), w * 0.4); dropY = r.u(386); dropW = w - dropX - wellX; dropH = r.u(46)
            }
        }
    }

    private static func convertPanel(_ ctx: Context, _ c: Conversion, w: Double, h: Double, r: Ruler) -> Node {
        let m = Conversion.Places(w: w, r: r)
        let result = c.result, toHijri = c.toHijri
        let fromWords = result.map { toHijri ? Words.date($0.gregorian, weekday: false) : Words.hijri($0.hijri) }
        let toWords = result.map { toHijri ? Words.hijri($0.hijri) : Words.date($0.gregorian, weekday: false) }
        let cy = r.u(263), bx = w / 2 - r.u(29)
        let resultY = r.u(450), resultH = r.u(151), buttonsY = r.u(619), buttonsH = r.u(53), mainW = (w - r.u(40)) * 0.59
        return Node.group {
            archPanel(w, h, title: L("Convert a date"), words: L("Convert between Gregorian and Hijri dates using your selected calendar method."), r: r)
            // Back to the month, on its own chip above the lattice.
            Node.group {
                Node.rect(fill: Noor.quiet, stroke: Noor.edge, lineWidth: 1, corner: r.u(10)).size(r.u(116), r.u(34))
                Node.symbol("chevron.backward", color: Noor.text).size(r.u(8), r.u(13)).at(r.u(11), r.u(10.5))
                Node.say(Words.tab(.calendar), r.u(26), 0, r.u(86), r.u(34), size: r.f(14, min: 11.5))
            }
            .size(r.u(116), r.u(34)).at(r.u(14), r.u(12))
            .area("calendar", label: L("Back to Calendar"))
            Node.say(toHijri ? L("From Gregorian date") : L("From Hijri date"), r.u(26), r.u(143), w - r.u(52), r.u(28), size: r.f(16.5, min: 12))
            dateWell(fromWords, x: m.wellX, y: m.fromY, w: m.wellW, h: m.wellH, r: r, clearable: true)
            Node.rect(fill: Noor.hairline).size(bx - r.u(50) - r.u(26), 1).at(r.u(26), cy)
            Node.rect(fill: Noor.hairline).size(w - r.u(26) - bx - r.u(58) - r.u(50), 1).at(bx + r.u(58) + r.u(50), cy)
            Node.group {
                Node.ellipse(fill: Noor.quiet, stroke: Noor.pickedEdge, lineWidth: 1.2).size(r.u(58), r.u(58))
                Node.symbol("arrow.up.arrow.down", color: Noor.text).size(r.u(32), r.u(32)).at(r.u(13), r.u(13))
            }
            .size(r.u(58), r.u(58)).at(bx, cy - r.u(29))
            .area("swap", label: toHijri ? L("Convert from Hijri instead") : L("Convert from Gregorian instead"))
            Node.say(toHijri ? L("To Hijri date") : L("To Gregorian date"), r.u(26), r.u(285), w - r.u(52), r.u(28), size: r.f(16.5, min: 12))
            dateWell(toWords, x: m.wellX, y: m.toY, w: m.wellW, h: m.wellH, r: r, clearable: false, waiting: c.input.isEmpty ? L("Enter a date first.") : L("Press Convert to see this date."))
            Node.say(L("Calendar method"), r.u(26), m.dropY, m.dropX - r.u(30), m.dropH, size: r.f(16.5, min: 12))
            methodPill(ctx, x: m.dropX, y: m.dropY, w: m.dropW, h: m.dropH, r: r)
            resultPlate(c, x: r.u(19), y: resultY, w: w - r.u(38), h: resultH, r: r)
            panelButton("run", L("Convert"), x: r.u(20), y: buttonsY, w: mainW, h: buttonsH, filled: true, disabled: c.input.isEmpty, r: r)
            panelButton("open", L("Open in calendar"), symbol: "calendar", x: r.u(20) + mainW + r.u(11), y: buttonsY, w: w - r.u(40) - mainW - r.u(11), h: buttonsH, disabled: result == nil, r: r)
            if let problem = c.problem {
                Node.group {
                    Node.rect(fill: .adaptive(light: "#FBECEA", dark: "#2A1329"), stroke: .adaptive(light: "#C2392B", dark: "#E25A4A"), lineWidth: 1.2, corner: r.u(12)).size(w - r.u(40), r.u(90))
                    Node.symbol("exclamationmark.circle", color: .adaptive(light: "#B3261E", dark: "#F0705F")).size(r.f(30, min: 18), r.f(30, min: 18)).at(r.u(22), r.u(30))
                    Node.say(L("That date didn't convert"), r.u(76), r.u(10), w - r.u(116) - r.u(20), r.u(30), size: r.f(18.5, min: 13.5), weight: "medium", color: .adaptive(light: "#B3261E", dark: "#F0705F"))
                    Node.say(problem, r.u(76), r.u(38), w - r.u(116) - r.u(20), r.u(46), size: r.f(15.5, min: 12), lines: 2)
                }
                .size(w - r.u(40), r.u(90)).at(r.u(20), r.u(687))
            } else {
                Node.group {
                    Node.rect(stroke: Noor.hairline, lineWidth: 1, corner: r.u(12)).size(w - r.u(40), r.u(70))
                    Node.symbol("info.circle", color: Noor.muted).size(r.f(22, min: 15), r.f(22, min: 15)).at(r.u(22), r.u(24))
                    Node.say(L("Calculated. Local announcements may differ."), r.u(62), 0, w - r.u(100) - r.u(20), r.u(70), size: r.f(15.5, min: 12), color: Noor.muted, lines: 2)
                }
                .size(w - r.u(40), r.u(70)).at(r.u(20), r.u(697))
            }
        }
        .size(w, h)
    }

    /// F03's two buttons, with its square shoulders. `filled` is the panel's one main action.
    private static func panelButton(_ id: String, _ label: String, symbol: String? = nil, x: Double, y: Double, w: Double, h: Double, filled: Bool = false, disabled: Bool = false, r: Ruler) -> Node {
        let glyph = r.f(22, min: 15), ink = filled ? Noor.onChosen : Noor.text
        return Node.group {
            if filled {
                Node.rect(stroke: .hex("#9A85E8"), lineWidth: 1, corner: r.u(14)).gradient([.hex("#6E4FDC"), .hex("#5439BE")], from: (0, 0.5), to: (1, 0.5)).size(w, h)
            } else {
                Node.rect(fill: Noor.quiet, stroke: Noor.edge, lineWidth: 1.2, corner: r.u(14)).size(w, h)
            }
            if let symbol {
                Node.symbol(symbol, color: ink).size(glyph, glyph).at(r.u(18), (h - glyph) / 2)
                Node.say(label, r.u(18) + glyph + r.u(10), 0, w - r.u(30) - glyph - r.u(10), h, size: r.f(17, min: 12.5), color: ink)
            } else {
                Node.say(label, r.u(10), 0, w - r.u(20), h, size: r.f(20, min: 14), weight: "medium", color: ink, align: "center")
            }
        }
        .size(w, h).at(x, y).opacity(disabled ? 0.45 : 1).area(id, label: label, disabled: disabled, hover: .init(scale: 1.015))
    }

    /// A pearl well with a date in it, in the card's own ink. With no date, only what it's waiting for.
    private static func dateWell(_ words: String?, x: Double, y: Double, w: Double, h: Double, r: Ruler, clearable: Bool, waiting: String? = nil) -> Node {
        let glyph = r.f(24, min: 16)
        let filled = words != nil || waiting != nil
        let well = Node.group {
            if filled {
                Node.rect(stroke: .hex("#FFFFFF"), lineWidth: 1, corner: r.u(12)).gradient([.hex("#F1E9FB"), .hex("#E2D5F6")]).size(w, h)
            } else {
                // The field stands on the theme's own well: its words are the theme's.
                Node.rect(fill: Noor.well, stroke: Noor.pickedEdge, lineWidth: 1.2, corner: r.u(12)).size(w, h)
            }
            Node.symbol("calendar", color: filled ? ink : Noor.text).size(glyph, glyph).at(r.u(20), (h - glyph) / 2)
            if let words {
                Node.say(words, r.u(60), 0, w - r.u(110), h, size: r.f(20, min: 14), weight: "medium", color: ink)
                if clearable { Node.symbol("xmark", color: ink).size(r.u(13), r.u(13)).at(w - r.u(34), (h - r.u(13)) / 2) }
            } else if let waiting {
                Node.say(waiting, r.u(60), 0, w - r.u(80), h, size: r.f(16, min: 12.5), color: inkQuiet)
            }
        }
        .size(w, h).at(x, y)
        return words != nil && clearable ? well.area("clear", label: L("Clear this date and type another"), hover: .init(scale: 1.0)) : well
    }

    /// The two dates face to face, the method's lattice at the plate's corners.
    private static func resultPlate(_ c: Conversion, x: Double, y: Double, w: Double, h: Double, r: Ruler) -> Node {
        let colW = (w - r.u(70)) / 2, ear = r.u(30), glyph = r.f(22, min: 15)
        return Node.group {
            latticePlate(w, h, corner: r.u(14), r: r)
            Node.path(earPath(w - r.u(8), h - r.u(8), ear: ear), fill: .adaptive(light: "#FBF8FD", dark: "#0C1035")).size(w - r.u(8), h - r.u(8)).at(r.u(4), r.u(4))
            Node.rect(stroke: Noor.rosy, lineWidth: 1.2, corner: r.u(14)).size(w, h)
            if let day = c.result {
                let colY = r.u(62)
                Node.symbol("calendar", color: Noor.text).size(glyph, glyph).at(colW * 0.5 - r.u(64), r.u(25))
                Node.say(L("Gregorian date"), colW * 0.5 - r.u(34), r.u(22), colW * 0.5 + r.u(30), r.u(28), size: r.f(15.5, min: 12))
                Node.say(weekday(day.gregorian), 0, colY, colW, r.u(34), size: r.f(22, min: 14), align: "center")
                Node.say(Words.date(day.gregorian, weekday: false), r.u(6), colY + r.u(30), colW - r.u(6), r.u(34), size: r.f(22, min: 14), align: "center")
                Node.symbol("arrow.left.and.right", color: Noor.text).size(r.u(36), r.u(26)).at(w / 2 - r.u(18), h / 2 - r.u(10))
                Node.symbol("moon.fill", color: Noor.warm).size(glyph, glyph).at(w - colW + colW * 0.5 - r.u(60), r.u(25))
                Node.say(L("Hijri date"), w - colW + colW * 0.5 - r.u(30), r.u(22), colW * 0.5 + r.u(26), r.u(28), size: r.f(15.5, min: 12))
                Node.say("\(day.hijri.day) \(Words.hijriMonth(day.hijri))", w - colW, colY, colW - r.u(6), r.u(34), size: r.f(22, min: 14), align: "center")
                Node.say("\(day.hijri.year)", w - colW, colY + r.u(30), colW - r.u(6), r.u(34), size: r.f(22, min: 14), align: "center", tabular: true)
            } else {
                Node.say(L("The two dates show here, side by side."), r.u(40), 0, w - r.u(80), h, size: r.f(16, min: 12.5), color: Noor.muted, align: "center", lines: 2)
            }
        }
        .size(w, h).at(x, y)
    }

    private static func weekday(_ date: CivilDate) -> String {
        let f = DateFormatter()
        f.locale = Language.locale
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.setLocalizedDateFormatFromTemplate("EEEE")
        return f.string(from: date.anchor)
    }

    // MARK: Occasions

    /// What the occasions panel shows: the year's list a few at a time, so it keeps the board's one composition, and one of them open at the foot.
    @MainActor
    private struct OccasionList {
        static let perPage = 5
        let year: Int
        let all: [Occasion]
        let shown: [Occasion]
        let page: Int
        let open: Occasion?
        let typed: String
        var pages: Int { max(1, (shown.count + Self.perPage - 1) / Self.perPage) }
        var rows: [Occasion] { Array(shown.dropFirst(page * Self.perPage).prefix(Self.perPage)) }

        init(_ ctx: Context) {
            year = ctx.snapshot.calendar?.hijri.year ?? 0
            all = (ctx.model.occasions[year] ?? []).sorted { $0.gregorian < $1.gregorian }
            typed = ctx.state.string("occ_q") ?? ""
            let query = typed.lowercased()
            let shown = query.isEmpty ? all : all.filter { $0.title.lowercased().contains(query) }
            self.shown = shown
            // Unasked, it opens on what comes next.
            let today = ctx.snapshot.localDate
            let wanted = ctx.state.string("occ")
            let open = shown.first { $0.identity == wanted } ?? today.flatMap { day in shown.first { $0.gregorian >= day } } ?? shown.first
            self.open = open
            let last = max(0, (shown.count - 1) / Self.perPage)
            let home = open.flatMap { o in shown.firstIndex(of: o) }.map { $0 / Self.perPage } ?? 0
            page = min(max(0, ctx.state.int("occ_page") ?? home), last)
        }

        func acts(_ acts: inout [String: PageAct]) {
            for occasion in rows { acts["o-\(occasion.identity)"] = .go(Go(set: ["occ": occasion.identity, "occ_page": page])) }
            acts["occ-prev"] = .go(Go(set: ["occ_page": max(0, page - 1)]))
            acts["occ-next"] = .go(Go(set: ["occ_page": min(pages - 1, page + 1)]))
        }

        /// The search and the method always first, in the same places, so typing keeps the field; then this page's switches.
        func inlays(_ ctx: Context, w: Double, h: Double, r: Ruler, dx: Double, dy: Double = 0) -> [PageInlay] {
            let m = Places(w: w, r: r)
            var out = [
                PageInlay(x: dx + m.searchX + r.u(46), y: dy + m.barY + r.u(6), w: m.searchW - r.u(54), h: m.barH - r.u(12),
                          .draftField(L("Search occasions"), placeholder: L("Search occasions…"), button: L("Clear"), key: "occ_q", value: typed.isEmpty ? nil : typed, live: true, set: ["occ_page": NSNull()])),
                PageInlay(x: dx + m.dropX, y: dy + m.barY, w: m.dropW, h: m.barH, CalendarPage.methodChoice(ctx)),
            ]
            let chosen = ctx.model.prefs.reminders.occasions.selected
            for (i, occasion) in rows.enumerated() {
                out.append(PageInlay(x: dx + m.toggleX, y: dy + m.rowY(i) + (m.rowH - r.u(30)) / 2, w: r.u(52), h: r.u(30),
                                     .toggle(L("Remind me of {occasion}", ["occasion": occasion.title]), on: chosen.contains(occasion.identity), tool: "select_occasion", input: ["occasion": occasion.identity])))
            }
            return out
        }

        struct Places {
            let w: Double, r: Ruler
            let searchX: Double, searchW: Double, barY: Double, barH: Double, dropX: Double, dropW: Double, rowX: Double, rowW: Double, rowH: Double, toggleX: Double
            init(w: Double, r: Ruler) {
                self.w = w; self.r = r
                searchX = r.u(17); barY = r.u(155); barH = r.u(42)
                rowX = r.u(17); rowW = w - rowX * 2; rowH = r.u(62)
                dropW = min(r.u(179), w * 0.36); dropX = w - rowX - dropW
                searchW = w - rowX * 2 - dropW - r.u(150)
                toggleX = w - r.u(137)
            }
            func rowY(_ i: Int) -> Double { r.u(214) + Double(i) * r.u(62) }
        }
    }

    private static func occasionsPanel(_ ctx: Context, _ list: OccasionList, w: Double, h: Double, r: Ruler) -> Node {
        let m = OccasionList.Places(w: w, r: r)
        let method = Words.calendarMethodName(ctx.model.prefs.calendarMethod)
        let footY = m.rowY(OccasionList.perPage) + r.u(6)
        return Node.group {
            archPanel(w, h, title: L("Occasions ({year})", ["year": "\(list.year)"]), words: L("Dates listed by the provider for the Hijri year {year}. Dates and observances follow the selected source.", ["year": "\(list.year)"]), r: r)
            Node.rect(fill: Noor.well, stroke: Noor.pickedEdge.tuned(alpha: 0.5), lineWidth: 1, corner: r.u(10)).size(m.searchW, m.barH).at(m.searchX, m.barY)
            Node.symbol("magnifyingglass", color: Noor.muted).size(r.u(19), r.u(19)).at(m.searchX + r.u(18), m.barY + (m.barH - r.u(19)) / 2)
            Node.say(L("Calendar method"), m.searchX + m.searchW + r.u(16), m.barY, m.dropX - m.searchX - m.searchW - r.u(24), m.barH, size: r.f(14.5, min: 11.5))
            methodPill(ctx, x: m.dropX, y: m.barY, w: m.dropW, h: m.barH, r: r)
            for (i, occasion) in list.rows.enumerated() {
                occasionRow(occasion, open: occasion == list.open, w: m.rowW, h: m.rowH - r.u(3), toggleX: m.toggleX - m.rowX, r: r).at(m.rowX, m.rowY(i))
            }
            if list.all.isEmpty {
                Node.say(ctx.model.load == .loading ? L("Loading the occasions…") : (Words.problem(ctx.model.problem).isEmpty ? L("No occasions are listed for this year.") : Words.problem(ctx.model.problem)), m.rowX, m.rowY(1), m.rowW, r.u(62), size: r.f(16), color: Noor.muted, align: "center", lines: 2)
            } else if list.shown.isEmpty {
                Node.say(L("No occasion matches “{query}”.", ["query": list.typed]), m.rowX, m.rowY(1), m.rowW, r.u(62), size: r.f(16), color: Noor.muted, align: "center", lines: 2)
            }
            // What a switch does, and the rest of the list.
            Node.say(L("A switch asks for a reminder. Reminders still need turning on in Preferences."), m.rowX + r.u(6), footY, m.rowW - r.u(150), r.u(46), size: r.f(13.5, min: 11), color: Noor.muted, lines: 2)
            if list.pages > 1 {
                let bx = w - m.rowX - r.u(138)
                arrow("occ-prev", "chevron.backward", L("Earlier occasions"), x: bx, y: footY + r.u(5), disabled: list.page == 0, r: r)
                Node.say(L("{page} of {pages}", ["page": "\(list.page + 1)", "pages": "\(list.pages)"]), bx + r.u(36), footY + r.u(5), r.u(66), r.u(34), size: r.f(14, min: 11), color: Noor.muted, align: "center", tabular: true)
                arrow("occ-next", "chevron.forward", L("Later occasions"), x: bx + r.u(102), y: footY + r.u(5), disabled: list.page >= list.pages - 1, r: r)
            }
            if let open = list.open { occasionDetail(open, method: method, x: r.u(14), y: r.u(601), w: w - r.u(28), h: r.u(176), r: r) }
        }
        .size(w, h)
    }

    private static func arrow(_ id: String, _ symbol: String, _ spoken: String, x: Double, y: Double, disabled: Bool, r: Ruler) -> Node {
        Node.group {
            Node.rect(fill: Noor.well, stroke: Noor.pickedEdge.tuned(alpha: 0.5), lineWidth: 1, corner: r.u(9)).size(r.u(34), r.u(34))
            Node.symbol(symbol, color: Noor.text).size(r.u(9), r.u(14)).at(r.u(12.5), r.u(10))
        }
        .size(r.u(34), r.u(34)).at(x, y).opacity(disabled ? 0.4 : 1).area(id, label: spoken, disabled: disabled)
    }

    private static func occasionRow(_ occasion: Occasion, open: Bool, w: Double, h: Double, toggleX: Double, r: Ruler) -> Node {
        let glyph = r.u(36)
        return Node.group {
            if open {
                Node.rect(stroke: .adaptive(light: "#7354B8", dark: "#D9A8EC"), lineWidth: 1.4, corner: r.u(12)).gradient([.adaptive(light: "#EEE8F5", dark: "#3A2478"), .adaptive(light: "#F8F3FB", dark: "#1A1B52")], from: (0, 0.5), to: (1, 0.5)).size(w, h)
            } else {
                Node.rect(fill: Noor.quiet, stroke: Noor.hairline, lineWidth: 1, corner: r.u(12)).size(w, h)
            }
            if open {
                Node.symbol("moon.fill", color: Noor.warm).size(glyph * 0.84, glyph * 0.84).at(r.u(32), (h - glyph * 0.84) / 2)
            } else {
                Node.image("art/rosette-l.png", dark: "art/rosette-d.png").size(glyph, glyph).at(r.u(32), (h - glyph) / 2).leftToRight()
            }
            Node.say(occasion.title, r.u(96), r.u(7), toggleX - r.u(192), r.u(28), size: r.f(17.5, min: 13))
            Node.say("\(Words.hijri(occasion.hijri)) · \(Words.date(occasion.gregorian, weekday: false))", r.u(96), r.u(31), toggleX - r.u(192), r.u(24), size: r.f(14.5, min: 11.5), color: Noor.muted)
            Node.say(L("Reminder"), toggleX - r.u(90), 0, r.u(82), h, size: r.f(14, min: 11), color: Noor.muted, align: "trailing")
            Node.symbol("chevron.forward", color: Noor.muted).size(r.u(8), r.u(13)).at(w - r.u(32), (h - r.u(13)) / 2)
        }
        .size(w, h)
        .area("o-\(occasion.identity)", label: L("Open {occasion}, {date}", ["occasion": occasion.title, "date": Words.date(occasion.gregorian)]), hover: .init(scale: 1.0), selected: open)
    }

    /// The occasion that is open, on a plate like the conversion's: what it is, when, and whose word that is.
    private static func occasionDetail(_ occasion: Occasion, method: String, x: Double, y: Double, w: Double, h: Double, r: Ruler) -> Node {
        let ear = r.u(30), textX = r.u(94), textW = w - textX - r.u(68), glyph = r.u(36)
        return Node.group {
            latticePlate(w, h, corner: r.u(14), r: r)
            Node.path(earPath(w - r.u(8), h - r.u(8), ear: ear), fill: .adaptive(light: "#FBF8FD", dark: "#0C1035")).size(w - r.u(8), h - r.u(8)).at(r.u(4), r.u(4))
            Node.rect(stroke: Noor.rosy, lineWidth: 1.2, corner: r.u(14)).size(w, h)
            Node.symbol("moon.fill", color: Noor.warm).size(glyph, glyph).at(r.u(36), r.u(26))
            Node.say(occasion.title, textX, r.u(16), textW, r.u(34), size: r.f(20.5, min: 14.5), weight: "medium")
            Node.say("\(Words.hijri(occasion.hijri)) · \(Words.date(occasion.gregorian, weekday: false))", textX, r.u(46), textW, r.u(26), size: r.f(15.5, min: 12), color: Noor.muted)
            Node.rect(fill: Noor.hairline).size(textW, 1).at(textX, r.u(78))
            Node.say(L("Source"), textX, r.u(90), textW * 0.3, r.u(28), size: r.f(15.5, min: 12))
            Node.say(L("{method} · Calculated date", ["method": method]), textX + textW * 0.3, r.u(90), textW * 0.7, r.u(28), size: r.f(15.5, min: 12), align: "trailing")
            Node.say(L("Calculated and listed by the provider under {method}. Local observance may differ, and traditions differ on what is kept.", ["method": method]), textX, r.u(116), textW, r.u(46), size: r.f(13.5, min: 11), color: Noor.muted, lines: 2)
        }
        .size(w, h).at(x, y)
    }
}
