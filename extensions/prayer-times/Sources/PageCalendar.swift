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
        let w = ctx.width
        let gap = 16.0
        let gridW = ctx.narrow ? w : (w - gap) * 0.64
        let weeks = Int(ceil(Double(data.leadingBlanks(firstWeekday: firstWeekday) + data.dayCount) / 7))
        let cell = min((gridW - 40) / 7, ctx.narrow ? 54 : 88)
        let rowH = ctx.narrow ? 54.0 : 84.0
        let gridH = 150 + 34 + Double(weeks) * rowH + 18
        let sideW = ctx.narrow ? w : w - gridW - gap
        let sideH = ctx.narrow ? 330.0 : gridH
        let selected = ctx.state.string("sel").flatMap(CivilDate.init(iso:)) ?? ctx.snapshot.localDate ?? data.days[0].gregorian
        let pairedSelected = data.days.first { $0.gregorian == selected } ?? ctx.model.pairedDay(selected)
        let acts: [String: PageAct] = [
            "prev": .go(Go(set: ["month": neighbour(m, by: -1)])), "next": .go(Go(set: ["month": neighbour(m, by: 1)])),
            "today": .go(Go(set: ["month": NSNull(), "sel": NSNull()])),
            "hijri": .go(Go(set: ["month": axisSwitch(m, to: "h", ctx: ctx, data: data)])), "gregorian": .go(Go(set: ["month": axisSwitch(m, to: "g", ctx: ctx, data: data)])),
            "convert": .go(Go(set: ["sheet": "convert"], push: true)),
            "occasions": .go(Go(set: ["sheet": "occasions"], push: true)),
            "ramadan": .go(Go(set: ["sheet": "ramadan"], push: true)),
        ]
        let scene = Scene(width: w, height: ctx.narrow ? gridH + gap + sideH : max(gridH, sideH)) {
            grid(ctx, m: m, data: data, w: gridW, h: gridH, cell: cell, rowH: rowH, selected: selected)
            side(ctx, paired: pairedSelected, date: selected, w: sideW, h: sideH).at(ctx.narrow ? 0 : gridW + gap, ctx.narrow ? gridH + gap : 0)
        }
        var out = [Section(nil, [.scene(PageSceneBlock(scene, acts: dayActs(data, acts)))], wide: true)]
        out.append(Section(nil, [methodChoice(ctx)], wide: true))
        return out
    }

    /// Each day's area says which day, as its own: an area's value would arrive under `value`, and a page's state is named.
    private static func dayActs(_ data: CalendarMonth, _ base: [String: PageAct]) -> [String: PageAct] {
        var acts = base
        for day in data.days { acts["d\(day.gregorian.iso)"] = .go(Go(set: ["sel": day.gregorian.iso])) }
        return acts
    }

    static var firstWeekday: Int { Calendar.current.firstWeekday }

    private static func neighbour(_ m: (axis: String, year: Int, month: Int, data: CalendarMonth?), by delta: Int) -> String {
        let moved = delta > 0 ? NoorModel.monthAfter(m.year, m.month) : NoorModel.monthBefore(m.year, m.month)
        return "\(m.axis):\(moved.0):\(moved.1)"
    }

    /// The other axis at the same place in time: its first shown day's month there.
    private static func axisSwitch(_ m: (axis: String, year: Int, month: Int, data: CalendarMonth?), to axis: String, ctx: Context, data: CalendarMonth) -> String {
        guard axis != m.axis, let middle = data.days.dropFirst(data.days.count / 2).first else { return "\(m.axis):\(m.year):\(m.month)" }
        return axis == "h" ? "h:\(middle.hijri.year):\(middle.hijri.month)" : "g:\(middle.gregorian.year):\(middle.gregorian.month)"
    }

    private static func grid(_ ctx: Context, m: (axis: String, year: Int, month: Int, data: CalendarMonth?), data: CalendarMonth, w: Double, h: Double, cell: Double, rowH: Double, selected: CivilDate) -> Node {
        // Pearl in both appearances, as a page of paper set in the frame: the board's look, and its ink is its own, so it reads on either.
        let paper = Color.hex("#F2ECF6"), ink = Color.hex("#15182F"), soft = Color.hex("#57527A")
        let isHijri = m.axis == "h"
        let title = isHijri ? (data.days.first.map { "\(Words.hijriMonth($0.hijri)) \($0.hijri.year)" } ?? "") : Words.gregorianMonth(m.year, m.month)
        let today = ctx.snapshot.localDate
        let lead = data.leadingBlanks(firstWeekday: firstWeekday)
        let gridX = (w - cell * 7) / 2
        let topY = 150.0
        func pill(_ id: String, _ label: String, x: Double, _ w: Double, on: Bool = false) -> Node {
            Node.group {
                Node.rect(fill: on ? Noor.chosen : .hex("#FFFFFF"), stroke: .hex("#CFC6E2"), lineWidth: 1, corner: 9).size(w, 34)
                Node.say(label, 4, 0, w - 8, 34, size: 12.5, weight: "medium", color: on ? Noor.onChosen : ink, align: "center")
            }
            .size(w, 34).at(x, 66).area(id, label: label, selected: on)
        }
        func arrow(_ id: String, _ symbol: String, _ spoken: String, x: Double) -> Node {
            Node.group {
                Node.rect(fill: .hex("#FFFFFF"), stroke: .hex("#CFC6E2"), lineWidth: 1, corner: 9).size(38, 34)
                Node.symbol(symbol, color: ink).size(12, 16).at(13, 9)
            }
            .size(38, 34).at(x, 20).area(id, label: spoken)
        }
        return Node.group {
            Node.patternPanel(w, h)
            Node.rect(fill: paper, stroke: Noor.inlay, lineWidth: 1.5, corner: 16).size(w - 20, h - 20).at(10, 10)
            Node.say(title, 28, 18, w - 240, 42, size: ctx.narrow ? 22 : 29, weight: "bold", color: ink)
            arrow("prev", "chevron.backward", L("Previous month"), x: w - 182)
            Node.group {
                Node.rect(fill: .hex("#FFFFFF"), stroke: .hex("#CFC6E2"), lineWidth: 1, corner: 9).size(70, 34)
                Node.say(L("Today"), 2, 0, 66, 34, size: 12.5, weight: "medium", color: ink, align: "center")
            }
            .size(70, 34).at(w - 140, 20).area("today", label: L("Today"))
            arrow("next", "chevron.forward", L("Next month"), x: w - 66)
            pill("hijri", L("Hijri"), x: 28, 80, on: isHijri)
            pill("gregorian", L("Gregorian"), x: 112, 90, on: !isHijri)
            Node.say(L("Method: {method}", ["method": Words.calendarMethodName(data.method)]), 28, 106, w - 56, 26, size: 12.5, color: soft)
            for i in 0..<7 {
                Node.say(Words.weekdayShort((firstWeekday - 1 + i) % 7 + 1), gridX + Double(i) * cell, topY - 12, cell, 30, size: 12.5, weight: "medium", color: soft, align: "center")
            }
            for (i, day) in data.days.enumerated() {
                let slot = i + lead
                let x = gridX + Double(slot % 7) * cell, y = topY + 20 + Double(slot / 7) * rowH
                let primary = isHijri ? day.hijri.day : day.gregorian.day
                let secondary = isHijri ? day.gregorian.day : day.hijri.day
                let isToday = day.gregorian == today, picked = day.gregorian == selected
                let occasions = ctx.model.prefs.showOccasions ? ctx.model.occasions(on: day.gregorian) : []
                let inkHere = isToday ? Color.hex("#FFFFFF") : ink
                Node.group {
                    Node.rect(fill: isToday ? Noor.chosen : .hex("#FFFFFF"), stroke: picked ? Noor.chosen : .hex("#DED6EC"), lineWidth: picked ? 2.4 : 1, corner: 8).size(cell - 3, rowH - 3)
                    Node.say("\(primary)", 8, 4, cell - 18, 26, size: ctx.narrow ? 15 : 19, weight: "semibold", color: inkHere, tabular: true)
                    Node.say("\(secondary)", 8, rowH - 26, cell - 18, 20, size: 11.5, color: isToday ? .hex("#E9E0F6") : soft, tabular: true)
                    if !occasions.isEmpty {
                        // Two marks for more than one: a shape, not a colour alone.
                        Node.symbol(occasions.count > 1 ? "circle.grid.2x1.fill" : "circle.fill", color: isToday ? .hex("#FFFFFF") : .hex("#7354B8")).size(10, 10).at(cell - 18, 8)
                    }
                }
                .size(cell - 3, rowH - 3).at(x, y)
                .area("d\(day.gregorian.iso)", label: spoken(day, today: isToday, occasions: occasions), hover: .init(scale: 1.0), selected: picked)
            }
        }
        .size(w, h)
    }

    private static func spoken(_ day: CalendarDay, today: Bool, occasions: [Occasion]) -> String {
        var parts = [Words.hijri(day.hijri), Words.date(day.gregorian)]
        if today { parts.append(L("today")) }
        parts += occasions.map(\.title)
        return parts.joined(separator: ", ")
    }

    private static func side(_ ctx: Context, paired: CalendarDay?, date: CivilDate, w: Double, h: Double) -> Node {
        let occasions = ctx.model.occasions(on: date)
        return Node.group {
            OverviewPage.card(w, h)
            if let paired {
                Node.say("\(paired.hijri.day)", 20, 14, w - 40, 70, size: 58, weight: "bold", tabular: true)
                Node.say("\(Words.hijriMonth(paired.hijri)) \(paired.hijri.year)", 20, 84, w - 40, 32, size: 21, weight: "semibold", color: Noor.warm)
            } else {
                Node.say(L("Not in this month"), 20, 40, w - 40, 32, size: 18, color: Noor.muted)
            }
            Node.say(Words.date(date), 20, 116, w - 40, 26, size: 14, color: Noor.muted)
            Node.rect(fill: Noor.hairline).size(w - 40, 1).at(20, 150)
            Node.symbol("calendar", color: Noor.muted).size(18, 18).at(20, 166)
            Node.say(occasions.isEmpty ? L("No listed occasion for this date.") : occasions.prefix(3).map(\.title).joined(separator: " · "), 48, 158, w - 66, 58, size: 13, lines: 3)
            Node.rect(fill: Noor.hairline).size(w - 40, 1).at(20, 224)
            Node.say(L("Calendar method"), 20, 230, w - 40, 22, size: 12, color: Noor.muted)
            Node.say(Words.calendarMethodName(ctx.model.prefs.calendarMethod), 20, 250, w - 40, 22, size: 14)
            if h > 340 {
                Node.pill("convert", label: L("Convert a date"), x: 20, y: 286, w: w - 40, h: 40, symbol: "arrow.triangle.2.circlepath", filled: true)
                Node.pill("occasions", label: L("Browse listed occasions"), x: 20, y: 334, w: w - 40, h: 40, symbol: "book")
                Node.pill("ramadan", label: L("Plan Ramadan"), x: 20, y: 382, w: w - 40, h: 40, symbol: "moon")
                Node.say(L("Dates follow the selected calendar method. Local announcements may differ."), 20, 430, w - 40, 54, size: 12, color: Noor.faint, lines: 3)
            } else {
                Node.pill("convert", label: L("Convert a date"), x: 16, y: 282, w: (w - 40) / 2, h: 38, filled: true)
                Node.pill("occasions", label: L("Listed occasions"), x: 24 + (w - 40) / 2, y: 282, w: (w - 40) / 2, h: 38)
            }
        }
        .size(w, h)
    }

    /// One choice of method for every date Noor shows; the prayer method is separate, and not touched by this.
    private static func methodChoice(_ ctx: Context) -> Block {
        let methods = ctx.model.calendarMethods.isEmpty ? [CalendarMethodInfo(method: .uaq, name: "Umm al-Qura", description: "", validity: "")] : ctx.model.calendarMethods
        return .choice(L("Calendar method"), detail: L("Used on Overview, Calendar, Ramadan, conversions and occasions."), options: methods.map { ($0.method.rawValue, $0.name) },
                       selected: ctx.model.prefs.calendarMethod.rawValue, tool: "set_calendar_method")
    }

    // MARK: Conversion

    static func convert(_ ctx: Context) -> [Section] {
        let state = ctx.state
        let toHijri = (state.string("direction") ?? "g2h") == "g2h"
        let input = state.string("convert_date") ?? ""
        var result: [Block] = []
        if let problem = ctx.model.conversionProblem {
            result.append(.note(problem, tone: .bad))
        } else if let day = ctx.model.conversion {
            let words = "\(Words.hijri(day.hijri)) = \(Words.date(day.gregorian)) (\(Words.calendarMethodName(day.method)))"
            result.append(.facts(L("Result"), [(L("Gregorian"), Words.date(day.gregorian)), (L("Hijri"), Words.hijri(day.hijri)), (L("Method"), Words.calendarMethodName(day.method)), (L("Note"), L("Calculated. Local announcements may differ."))]))
            result.append(.action(Action(L("Copy result"), act: .copy(words), style: .primary, symbol: "doc.on.doc")))
            result.append(.action(Action(L("Open in calendar"), act: .go(Go(set: ["sheet": NSNull(), "tab": "calendar", "month": "g:\(day.gregorian.year):\(day.gregorian.month)", "sel": day.gregorian.iso])), symbol: "calendar")))
        }
        return [
            Section(L("Convert a date"), [
                .draftChoice(L("Direction"), options: [Option("g2h", L("Gregorian to Hijri")), Option("h2g", L("Hijri to Gregorian"))], selected: toHijri ? "g2h" : "h2g", key: "direction"),
                .draftField(toHijri ? L("Gregorian date") : L("Hijri date"), detail: toHijri ? L("Written like {example}.", ["example": "2026-11-02"]) : L("Year-month-day, like {example}.", ["example": "1448-05-22"]),
                            placeholder: toHijri ? "2026-11-02" : "1448-05-22", button: L("Use"), key: "convert_date", value: input.isEmpty ? nil : input),
                .action(Action(L("Convert"), tool: "convert_date", input: ["direction": toHijri ? "g2h" : "h2g", "date": input], style: .primary, symbol: "arrow.triangle.2.circlepath", detail: input.isEmpty ? L("Enter a date first.") : nil, disabled: input.isEmpty)),
                .note(L("Using {method}. Change it on the Calendar tab.", ["method": Words.calendarMethodName(ctx.model.prefs.calendarMethod)]), tone: .info),
            ], wide: true),
            Section(nil, result, wide: true),
        ]
    }

    // MARK: Occasions

    static func occasions(_ ctx: Context) -> [Section] {
        let year = ctx.snapshot.calendar?.hijri.year ?? 0
        let list = (ctx.model.occasions[year] ?? []).sorted { $0.gregorian < $1.gregorian }
        let query = (ctx.state.string("occ_q") ?? "").lowercased()
        let shown = query.isEmpty ? list : list.filter { $0.title.lowercased().contains(query) }
        let chosen = ctx.model.prefs.reminders.occasions.selected
        var blocks: [Block] = [
            .draftField(L("Search occasions"), placeholder: L("Search occasions…"), button: L("Clear"), key: "occ_q", value: query.isEmpty ? nil : query, live: true),
            .note(L("Calculated and listed by the provider under {method}. Local observance may differ, and traditions differ on what is kept.", ["method": Words.calendarMethodName(ctx.model.prefs.calendarMethod)]), tone: .info),
        ]
        if list.isEmpty {
            blocks.append(.note(ctx.model.load == .loading ? L("Loading the occasions…") : (Words.problem(ctx.model.problem).isEmpty ? L("No occasions are listed for this year.") : Words.problem(ctx.model.problem)), tone: .neutral))
        } else if shown.isEmpty {
            blocks.append(.note(L("No occasion matches “{query}”.", ["query": query]), tone: .neutral))
        }
        for occasion in shown.prefix(22) {
            blocks.append(.toggle(occasion.title, detail: "\(Words.hijri(occasion.hijri)) · \(Words.date(occasion.gregorian, weekday: false))", on: chosen.contains(occasion.identity), tool: "select_occasion", input: ["occasion": occasion.identity]))
        }
        return [Section(L("Occasions ({year})", ["year": "\(year)"]), blocks, detail: L("A switch asks for a reminder. Reminders still need turning on in Preferences."), wide: true)]
    }
}
