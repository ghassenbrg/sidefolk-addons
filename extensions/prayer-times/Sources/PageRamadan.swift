import Foundation
import SidefolkExtensionKit

/// The seasonal planner: month 9 as the provider returned it, 29 or 30 days, with Fajr, Maghrib and the provider's own Imsak kept apart. Nothing turns on when the month begins.
/// P07's one composition: its way back, its title and three pills, the selected day's arc over the skyline, More times, the daily table, and the reminders beside them.
@MainActor
enum RamadanPage {
    /// The board's quiet second line.
    private static let periwinkle = Color.adaptive(light: "#4F4A9A", dark: "#A6A8F2")

    /// To a tenth of a point: every digit of a month of rows is sent as words.
    private static func round10(_ x: Double) -> Double { (x * 10).rounded() / 10 }

    static func year(_ state: Arguments, model: NoorModel) -> Int? {
        state.string("ramadan_year_text").flatMap(Int.init) ?? model.snapshot().calendar.map { RamadanMonth.nextYear(from: $0.hijri) }
    }

    static func sections(_ ctx: Context) -> [Section] {
        guard let year = year(ctx.state, model: ctx.model) else {
            return [NoorPage.status(ctx, symbol: "moon", title: L("Loading Ramadan…"), detail: L("It needs today's Hijri date first."))]
        }
        guard ctx.snapshot.source?.kind != .manual else {
            return [NoorPage.status(ctx, symbol: "moon", title: L("Ramadan needs calculated times"), detail: L("The planner uses calculated times for your place, and your current timetable is a manual one. Reminders from it stay as they are."),
                                    buttons: [("sources", L("Open sources"), true, .go(Go(set: ["sheet": "prefs", "section": "sources"], push: true)))])]
        }
        guard let month = ctx.model.ramadan[year] else {
            let busy = ctx.model.load == .loading
            return [NoorPage.status(ctx, symbol: "moon", title: busy ? L("Loading Ramadan {year}…", ["year": "\(year)"]) : L("Ramadan {year} isn't here yet", ["year": "\(year)"]), detail: busy ? "" : Words.problem(ctx.model.problem), buttons: busy ? [] : [("retry", L("Try again"), true, .tool("refresh"))])]
        }
        let picked = ctx.state.int("ramadan_day").flatMap { n in month.days.first { $0.number == n } } ?? month.days[0]
        let draft = Draft(ctx, month: month)
        var acts: [String: PageAct] = [
            "back": .go(Go(set: ["sheet": NSNull()])),
            "place": .go(Go(set: ["sheet": "prefs", "section": "place"], push: true)),
            "method": .go(Go(set: ["sheet": "prefs", "section": "calendar"], push: true)),
            "more": .go(Go(set: ["r_more": ctx.state.bool("r_more") == true ? NSNull() : true])),
        ]
        for day in month.days { acts["day\(day.number)"] = .go(Go(set: ["ramadan_day": day.number])) }
        var tools: [String: (tool: String, input: [String: Any])] = ["enable": ("save_ramadan", draft.saving)]
        if draft.saved.enabled { tools["off"] = ("save_ramadan", ["enabled": false]) }
        let layout = ctx.narrow ? narrow(ctx, year: year, month: month, picked: picked, draft: draft) : wide(ctx, year: year, month: month, picked: picked, draft: draft)
        return [Section(nil, [.scene(PageSceneBlock(layout.scene, actions: tools, acts: acts, inlays: layout.inlays))], wide: true)]
    }

    /// What the reminder choices are right now: a draft until Enable. Nothing starts because the month began or because someone looked at this. The same Fajr or Maghrib moment as a prayer reminder comes as one notice.
    private struct Draft {
        let saved: Reminders.Ramadan
        let suhoor: String
        let iftar: Bool
        let days: String
        let choice: Set<Int>
        let preview: String
        let canEnable: Bool
        var saving: [String: Any] { ["enabled": true, "suhoor": suhoor == "off" ? -1 : (Int(suhoor) ?? -1), "iftar": iftar, "days": Array(choice).sorted()] }

        @MainActor init(_ ctx: Context, month: RamadanMonth) {
            let saved = ctx.model.prefs.reminders.ramadan
            let state = ctx.state
            let suhoor = state.string("r_suhoor") ?? saved.suhoorMinutesBeforeFajr.map { "\($0)" } ?? "off"
            let iftar = state.bool("r_iftar") ?? saved.iftar
            let days = state.string("r_days") ?? (saved.days.isEmpty || saved.days.count == month.dayCount ? "all" : "picked")
            let choice = days == "all" ? Set(1...month.dayCount) : [ctx.state.int("ramadan_day") ?? saved.days.min() ?? 1]
            var trial = ctx.model.prefs
            trial.reminders.master = true
            if !trial.reminders.route.companion && !trial.reminders.route.systemFallback { trial.reminders.route.companion = true }
            trial.reminders.prayers = [:]
            trial.reminders.nameOfDay.enabled = false
            trial.reminders.occasions.selected = []
            trial.reminders.pausedUntil = nil
            trial.reminders.ramadan = Reminders.Ramadan(enabled: true, days: choice, suhoorMinutesBeforeFajr: suhoor == "off" ? nil : Int(suhoor), iftar: iftar)
            let next = Planner.plan(now: ctx.snapshot.now, prefs: trial, days: [], ramadan: month, occasions: [], names: []).first
            let zone = IANAZone.zone(month.zoneID) ?? ctx.zone
            var line = L("Choose Suhoor or Iftar to see the next reminder.")
            if let next {
                let what = next.kind == .suhoor ? L("Suhoor") : L("Iftar")
                line = L("Next would be {what} on {date} at {time} ({zone}). It's far off? It comes when its day is within 35 days.", ["what": what, "date": Words.date(CivilDate(next.at, in: zone), weekday: false), "time": Words.time(next.at, zone: zone), "zone": month.zoneID])
            } else if suhoor != "off" || iftar {
                line = L("Those days have already passed.")
            }
            // Planner drops what is too far ahead for the host's horizon, so a future Ramadan's preview comes from the month itself.
            if next == nil, suhoor != "off" || iftar, let first = month.days.first(where: { choice.contains($0.number) && $0.fajr > ctx.snapshot.now }) {
                let at = suhoor != "off" ? first.fajr.addingTimeInterval(-Double(Int(suhoor) ?? 0) * 60) : first.maghrib
                line = L("First would be {what} on {date} at {time} ({zone}). Sidefolk schedules it once it's within 35 days.", ["what": suhoor != "off" ? L("Suhoor") : L("Iftar"), "date": Words.date(first.date, weekday: false), "time": Words.time(at, zone: zone), "zone": month.zoneID])
            }
            (self.saved, self.suhoor, self.iftar, self.days, self.choice, self.preview, self.canEnable) = (saved, suhoor, iftar, days, choice, line, suhoor != "off" || iftar)
        }
    }

    private static func yearChoice(_ year: Int) -> Block {
        .draftChoice(L("Year"), options: [Option("\(year - 1)", "\(year - 1)"), Option("\(year)", "\(year)"), Option("\(year + 1)", "\(year + 1)")], selected: "\(year)", key: "ramadan_year_text")
    }

    /// Places in P07's own numbers: a board's x less the sidebar's 245, its y less the 174 above the page.
    private static func wide(_ ctx: Context, year: Int, month: RamadanMonth, picked: RamadanDay, draft: Draft) -> (scene: Scene, inlays: [PageInlay]) {
        let w = ctx.width, k = w / 1290, r = ctx.ruler
        let open = ctx.state.bool("r_more") == true
        let outerX = 30 * k, outerY = 8 * k, outerW = w - outerX - 20 * k
        let leftX = 44 * k, leftW = 876 * k, rightX = 931 * k, rightW = w - rightX - 33 * k
        let heroY = 119 * k, heroH = 289 * k
        let moreY = 422 * k, moreH = (open ? 178 : 70) * k
        let tableY = moreY + moreH + 12 * k
        let rr = Ruler(width: rightW * 1290 / 326)
        let panelH = max(tableY + 283 * k - heroY, Metrics(draft, w: rightW, r: rr).needed)
        let tableH = heroY + panelH - tableY
        let bottom = heroY + panelH
        let outerH = bottom + 14 * k - outerY
        let pillY = 61 * k, pillH = 44 * k
        let yearX = 546 * k, yearW = 230 * k, placeX = 796 * k, placeW = 212 * k, chipX = 1019 * k, chipW = w - chipX - 35 * k
        let place = ctx.snapshot.place?.label ?? ""
        let scene = rowStyles(Scene(width: w, height: outerY + outerH + 10 * k) {
            Node.panel(outerW, outerH, corner: 18 * k, fill: .adaptive(light: "#FBF9FDC0", dark: "#11153AB0")).at(outerX, outerY)
            crumb(ctx, r: r).at(52 * k, 20 * k)
            Node.say(sentence(ctx, year: year, month: month), 420 * k, 20 * k, w - 420 * k - 50 * k, 26 * k, size: r.f(13, min: 10.5), color: Noor.muted, align: "trailing")
            Node.say(L("Ramadan planner"), 51 * k, 52 * k, yearX - 60 * k, 52 * k, size: r.f(40, min: 24), weight: "bold")
            dropdown("moon.fill", L("Ramadan {year}", ["year": "\(year)"]), w: yearW, h: pillH, r: r, tint: .hex("#F1C25B")).at(yearX, pillY)
            dropdown("mappin", place, w: placeW, h: pillH, r: r).at(placeX, pillY)
                .area("place", label: L("Place: {place}. Open.", ["place": place]), hover: .init(scale: 1.01))
            methodChip(ctx, month: month, w: chipW, h: pillH, r: r).at(chipX, pillY)
            hero(ctx, picked, month: month, w: leftW, h: heroH).at(leftX, heroY)
            more(ctx, year: year, day: picked, w: leftW, h: moreH, open: open, r: r).at(leftX, moreY)
            table(ctx, month, picked: picked, w: leftW, h: tableH, r: r).at(leftX, tableY)
            remindersPanel(ctx, month: month, draft: draft, w: rightW, h: panelH, r: rr).at(rightX, heroY)
        }, w: leftW, r: r)
        var inlays = [PageInlay(x: yearX, y: pillY, w: yearW, h: pillH, yearChoice(year))]
        inlays += reminderInlays(month: month, draft: draft, x: rightX, y: heroY, w: rightW, r: rr)
        return (scene, inlays)
    }

    private static func narrow(_ ctx: Context, year: Int, month: RamadanMonth, picked: RamadanDay, draft: Draft) -> (scene: Scene, inlays: [PageInlay]) {
        let w = ctx.width, margin = 16.0, inner = w - margin * 2, gap = 12.0
        let r = Ruler(width: 900)
        let open = ctx.state.bool("r_more") == true
        let pillH = 40.0, heroH = inner * 0.46, moreH = open ? 190.0 : 62.0, tableH = 300.0
        let halfW = (inner - gap) / 2
        let pillsY = 80.0, chipY = pillsY + pillH + 8, sentenceY = chipY + pillH + 6, sentenceH = 40.0
        let heroY = sentenceY + sentenceH + 6, moreY = heroY + heroH + gap, tableY = moreY + moreH + gap, panelY = tableY + tableH + gap
        let panelR = Ruler(width: 1290), panelH = Metrics(draft, w: inner, r: panelR).needed + 110
        let place = ctx.snapshot.place?.label ?? ""
        let scene = rowStyles(Scene(width: w, height: panelY + panelH + gap) {
            crumb(ctx, r: r).at(margin, 8)
            Node.say(L("Ramadan planner"), margin, 34, inner, 40, size: 26, weight: "bold")
            dropdown("moon.fill", L("Ramadan {year}", ["year": "\(year)"]), w: halfW, h: pillH, r: r, tint: .hex("#F1C25B")).at(margin, pillsY)
            dropdown("mappin", place, w: halfW, h: pillH, r: r).at(margin + halfW + gap, pillsY)
                .area("place", label: L("Place: {place}. Open.", ["place": place]), hover: .init(scale: 1.01))
            methodChip(ctx, month: month, w: inner, h: pillH, r: r).at(margin, chipY)
            Node.say(sentence(ctx, year: year, month: month), margin, sentenceY, inner, sentenceH, size: 12, color: Noor.muted, lines: 2)
            hero(ctx, picked, month: month, w: inner, h: heroH).at(margin, heroY)
            more(ctx, year: year, day: picked, w: inner, h: moreH, open: open, r: Ruler(width: 1000)).at(margin, moreY)
            table(ctx, month, picked: picked, w: inner, h: tableH, r: Ruler(width: 950)).at(margin, tableY)
            remindersPanel(ctx, month: month, draft: draft, w: inner, h: panelH, r: panelR).at(margin, panelY)
        }, w: inner, r: Ruler(width: 950))
        var inlays = [PageInlay(x: margin, y: pillsY, w: halfW, h: pillH, yearChoice(year))]
        inlays += reminderInlays(month: month, draft: draft, x: margin, y: panelY, w: inner, r: panelR)
        return (scene, inlays)
    }

    /// The way back, naming the tab it returns to.
    private static func crumb(_ ctx: Context, r: Ruler) -> Node {
        let size = r.f(16, min: 13)
        let parent = Words.tab(ctx.tab)
        let parentW = Double(parent.count) * size * 0.58 + 4
        return Node.group {
            Node.say(parent, 0, 0, parentW, r.u(26), size: size)
                .area("back", label: L("Back to {place}", ["place": parent]), hover: .init(scale: 1.02))
            Node.symbol("chevron.forward", color: Noor.muted).size(size * 0.5, size * 0.8).at(parentW + size * 0.5, (r.u(26) - size * 0.8) / 2)
            Node.say(L("Ramadan planner"), parentW + size * 1.5, 0, r.u(240), r.u(26), size: size)
        }
        .size(parentW + size * 1.5 + r.u(240), r.u(26))
    }

    private static func sentence(_ ctx: Context, year: Int, month: RamadanMonth) -> String {
        L("Ramadan {year} has {days} days under {method}, starting {date}. Calculated; local announcements may differ.", ["year": "\(year)", "days": "\(month.dayCount)", "method": Words.calendarMethodName(ctx.model.prefs.calendarMethod), "date": month.days.first.map { Words.date($0.date, weekday: false) } ?? ""])
    }

    /// The look of a pill that opens a choice; the choice itself lies over it, or an area on it goes somewhere.
    private static func dropdown(_ symbol: String, _ label: String, w: Double, h: Double, r: Ruler, tint: Color = Noor.text) -> Node {
        let glyph = r.f(22, min: 14), size = r.f(19, min: 12.5)
        return Node.group {
            Node.rect(fill: Noor.quiet, stroke: Noor.edge, lineWidth: 1.2, corner: h * 0.4).size(w, h)
            Node.symbol(symbol, color: tint).size(glyph, glyph).at(h * 0.4, (h - glyph) / 2)
            Node.say(label, h * 0.4 + glyph + r.u(14), 0, w - h * 0.8 - glyph - r.u(30), h, size: size)
            Node.symbol("chevron.down", color: Noor.text).size(r.f(13, min: 11), r.f(9, min: 7)).at(w - h * 0.4 - r.f(13, min: 11), (h - r.f(9, min: 7)) / 2)
        }
        .size(w, h)
    }

    private static func methodChip(_ ctx: Context, month: RamadanMonth, w: Double, h: Double, r: Ruler) -> Node {
        let words = "\(L("Calculated")) · \(Words.calendarMethodName(month.method ?? ctx.model.prefs.calendarMethod))"
        let size = r.f(15.5, min: 11.5), glyph = r.f(19, min: 14)
        return Node.group {
            Node.rect(fill: Noor.quiet, stroke: Noor.hairline, lineWidth: 1, corner: h * 0.3).size(w, h)
            Node.say(words, r.u(16), 0, w - r.u(48) - glyph, h, size: size, color: Noor.muted)
            Node.symbol("info.circle", color: Noor.text).size(glyph, glyph).at(w - glyph - r.u(14), (h - glyph) / 2)
        }
        .size(w, h)
        .area("method", label: L("{words}. Open calendar settings.", ["words": words]), hover: .init(scale: 1.01))
    }

    /// The selected day's arc over the skyline, in its lattice-cornered frame. The arc is the sun's and never mirrors: Fajr stays where the morning is.
    private static func hero(_ ctx: Context, _ day: RamadanDay, month: RamadanMonth, w: Double, h: Double) -> Node {
        let zone = IANAZone.zone(month.zoneID) ?? ctx.zone
        let t = { Words.time($0, zone: zone) }
        let length = day.maghrib.timeIntervalSince(day.fajr)
        let hours = Int(length / 3600), minutes = Int(length / 60) % 60
        let r = Ruler(width: w * 1290 / 876)
        let x = { w * $0 / 876 }, y = { h * $0 / 289 }
        let gold = Color.hex("#F6C04C"), rose = Color.hex("#E98CC0")
        let band = r.u(6), side = min(h * 0.34, r.u(92))
        let left = "M \(n(x(134))) \(n(y(182))) C \(n(x(250))) \(n(y(130))) \(n(x(360))) \(n(y(100))) \(n(x(462))) \(n(y(97)))"
        let right = "M \(n(x(462))) \(n(y(97))) C \(n(x(570))) \(n(y(96))) \(n(x(670))) \(n(y(125))) \(n(x(760))) \(n(y(177)))"
        let top = "M \(n(x(380))) \(n(y(104))) C \(n(x(410))) \(n(y(99))) \(n(x(436))) \(n(y(97))) \(n(x(462))) \(n(y(97))) C \(n(x(510))) \(n(y(97))) \(n(x(560))) \(n(y(102))) \(n(x(615))) \(n(y(119)))"
        let sun = r.f(44, min: 24), big = r.f(24, min: 15), small = r.f(17, min: 12)
        let place = ctx.snapshot.place?.label ?? ""
        return Node.group {
            PrayerPage.latticeField(w: w, h: h, corner: r.u(16))
            Node.group {
                Node.image("art/prayer-ramadan-sky-l.jpg", dark: "art/prayer-ramadan-sky-d.jpg", fit: "cover").size(w - band * 2, h - band * 2)
                // Quieter sky and ridges, so what the arc says stands on them.
                Node.rect().gradient([.adaptive(light: "#F7F3FBD0", dark: "#0C0F2CE0"), .adaptive(light: "#F7F3FB20", dark: "#0C0F2C50"), .adaptive(light: "#F7F3FB60", dark: "#0C0F2CB0")]).size(w - band * 2, h - band * 2)
            }
            .size(w - band * 2, h - band * 2).at(band, band).corner(r.u(12)).clip()
            Node.group {
                Node.image("art/corner-l.png", dark: "art/corner-d.png", fit: "contain").size(side, side).at(w - side, 0)
                Node.image("art/corner-l.png", dark: "art/corner-d.png", fit: "contain").size(side, side).at(w - side, h - side).rotate(90)
                Node.image("art/corner-l.png", dark: "art/corner-d.png", fit: "contain").size(side, side).at(0, h - side).rotate(180)
                Node.image("art/corner-l.png", dark: "art/corner-d.png", fit: "contain").size(side, side).at(0, 0).rotate(270)
            }
            .size(w, h).corner(r.u(16)).clip()
            Node.rect(stroke: Noor.inlay, lineWidth: 2, corner: r.u(16)).size(w, h)
            Node.group {
                Node.path(left, stroke: gold, lineWidth: 1.4, dash: [4, 4]).size(w, h).at(0, 0)
                Node.path(right, stroke: rose, lineWidth: 1.4, dash: [4, 4]).size(w, h).at(0, 0)
                Node.path(top, stroke: gold, lineWidth: 2).size(w, h).at(0, 0)
                Node.glow(gold, cx: x(462), cy: y(97), r: sun)
                Node.symbol("sun.max.fill", color: gold).size(sun, sun).at(x(462) - sun / 2, y(97) - sun / 2)
                Node.say(L("Day length"), x(462) - r.u(110), y(137), r.u(220), r.u(26), size: small, align: "center")
                Node.say(L("{hours} h {minutes} min", ["hours": "\(hours)", "minutes": "\(minutes)"]), x(462) - r.u(130), y(160), r.u(260), r.u(34), size: big, weight: "medium", align: "center", tabular: true)
                Node.glow(gold, cx: x(134), cy: y(170), r: sun * 0.9)
                Node.symbol("sun.max.fill", color: gold).size(sun * 0.95, sun * 0.95).at(x(134) - sun * 0.475, y(170) - sun * 0.5)
                Node.ellipse(fill: .hex("#FFFFFF")).size(r.u(10), r.u(10)).at(x(134) - r.u(5), y(196) - r.u(5))
                Node.say(Words.prayer(.fajr), x(134) - r.u(100), y(209), r.u(200), r.u(26), size: small, align: "center")
                Node.say(t(day.fajr), x(134) - r.u(100), y(233), r.u(200), r.u(34), size: big, align: "center", tabular: true)
                Node.glow(rose, cx: x(760), cy: y(168), r: sun * 0.9)
                // The sun going down: a disc with the haze across its foot.
                Node.ellipse().gradient([.hex("#F9C27A"), .hex("#F0648C")]).size(sun * 0.72, sun * 0.72).at(x(760) - sun * 0.36, y(168) - sun * 0.36)
                Node.rect(fill: .hex("#1A1440")).size(sun * 0.72, 1.5).at(x(760) - sun * 0.36, y(168) + sun * 0.1)
                Node.rect(fill: .hex("#1A1440")).size(sun * 0.72, 1.5).at(x(760) - sun * 0.36, y(168) + sun * 0.22)
                Node.ellipse(fill: .hex("#FFFFFF")).size(r.u(10), r.u(10)).at(x(760) - r.u(5), y(196) - r.u(5))
                Node.say(Words.prayer(.maghrib), x(760) - r.u(100), y(209), r.u(200), r.u(26), size: small, color: Noor.accent, align: "center")
                Node.say(t(day.maghrib), x(760) - r.u(100), y(233), r.u(200), r.u(34), size: big, align: "center", tabular: true)
            }
            .size(w, h).leftToRight()
            .label(L("Ramadan {number}: Fajr {fajr}, Maghrib {maghrib}, {hours} hours {minutes} minutes.", ["number": "\(day.number)", "fajr": t(day.fajr), "maghrib": t(day.maghrib), "hours": "\(hours)", "minutes": "\(minutes)"]))
            Node.say(L("Selected day · {number} Ramadan", ["number": "\(day.number)"]), r.u(65), r.u(28), w * 0.5, r.u(36), size: r.f(24, min: 15), weight: "semibold")
            Node.say(L("Daily fasting period ({place})", ["place": place]), r.u(65), r.u(62), x(400) - r.u(70), r.u(28), size: r.f(17.5, min: 12), color: Noor.muted)
            Node.say(Words.date(day.date, weekday: true), w * 0.55, r.u(30), w * 0.45 - side - r.u(6), r.u(32), size: r.f(16, min: 11.5), color: Noor.muted, align: "trailing")
        }
        .size(w, h)
    }

    /// Folded: they aren't what a fast is planned by, and they aren't five more prayers.
    private static func more(_ ctx: Context, year: Int, day: RamadanDay, w: Double, h: Double, open: Bool, r: Ruler) -> Node {
        let times = moreTimes(ctx, day: day)
        let headH = r.u(70), glyph = r.f(28, min: 18)
        let names = [L("Imsak"), Words.solar(.sunrise), Words.prayer(.dhuhr), Words.prayer(.asr), Words.prayer(.isha)]
        let step = (w - r.u(40)) / Double(max(times.count, 1))
        return Node.group {
            Node.panel(w, h, corner: r.u(14))
            Node.group {
                Node.symbol("clock", color: Noor.text).size(glyph, glyph).at(r.u(23), (headH - glyph) / 2)
                Node.say(L("More times (optional)"), r.u(74), r.u(12), w - r.u(150), r.u(26), size: r.f(19, min: 13.5))
                Node.say(names.joined(separator: ", "), r.u(74), r.u(38), w - r.u(150), r.u(22), size: r.f(15.5, min: 11.5), color: periwinkle)
                Node.symbol(open ? "chevron.up" : "chevron.down", color: Noor.text).size(r.f(16, min: 13), r.f(10, min: 8)).at(w - r.u(40), (headH - r.f(10, min: 8)) / 2)
            }
            .size(w, headH)
            .area("more", label: open ? L("Hide more times") : L("Show more times: Imsak, Sunrise, Dhuhr, Asr and Isha"), hover: .init(scale: 1.0), selected: open)
            if open {
                Node.rect(fill: Noor.hairline).size(w - r.u(40), 1).at(r.u(20), headH)
                for (i, item) in times.enumerated() {
                    Node.say(item.0, r.u(20) + step * Double(i), headH + r.u(10), step, r.u(26), size: r.f(14.5, min: 11), color: Noor.muted, align: "center", lines: 1)
                    Node.say(item.1, r.u(20) + step * Double(i), headH + r.u(36), step, r.u(30), size: r.f(19, min: 13.5), align: "center", tabular: true)
                }
                Node.say(L("Imsak here is the provider's calculated value. It is not Fajr, and not a universal cutoff."), r.u(22), headH + r.u(72), w - r.u(44), r.u(30), size: r.f(14, min: 11), color: Noor.muted, lines: 2)
            }
        }
        .size(w, h)
    }

    private static func moreTimes(_ ctx: Context, day: RamadanDay) -> [(String, String)] {
        var out: [(String, String)] = []
        if let imsak = day.imsak { out.append((L("Imsak (calculated)"), ctx.t(imsak))) }
        if let known = ctx.model.day(day.date) {
            if let sunrise = known.solar[.sunrise] { out.append((Words.solar(.sunrise), ctx.t(sunrise))) }
            for id in [PrayerID.dhuhr, .asr, .isha] { out.append((Words.prayer(id), ctx.t(known.starts[id]!))) }
        }
        return out.isEmpty ? [(L("Fajr"), ctx.t(day.fajr))] : out
    }

    private static func table(_ ctx: Context, _ month: RamadanMonth, picked: RamadanDay, w: Double, h: Double, r: Ruler) -> Node {
        let zone = IANAZone.zone(month.zoneID) ?? ctx.zone
        let c1 = r.u(30), c2 = w * 218 / 872, c3 = w * 350 / 872, c4 = w * 476 / 872
        let lines = [w * 170 / 872, w * 310 / 872, w * 451 / 872]
        let headY = r.u(55), headH = r.u(40), rowH = r.u(40), bodyY = headY + headH
        let chosen = ctx.model.prefs.reminders.ramadan
        let place = ctx.snapshot.place?.label ?? ""
        let suhoor = chosen.suhoorMinutesBeforeFajr
        let words = [suhoor.map { L("Fajr −{minutes} min", ["minutes": "\($0)"]) }, chosen.iftar ? L("At Maghrib") : nil].compactMap { $0 }.joined(separator: ", ")
        return Node.group {
            Node.panel(w, h, corner: r.u(14))
            Node.runs([(L("Ramadan {year}: daily times", ["year": "\(month.hijriYear)"]), Noor.text, "semibold"), (" (\(place))", Noor.muted, "regular")], size: r.f(20, min: 14), color: Noor.text, align: "leading").size(w - r.u(490), r.u(50)).at(r.u(20), r.u(4))
            let planning = L("Planning dates may differ from local announcements.")
            Node.symbol("info.circle", color: periwinkle).size(r.f(18, min: 13), r.f(18, min: 13)).at(w - r.u(14) - min(r.u(420), Double(planning.count) * r.f(13.5, min: 10.5) * 0.5) - r.u(28), (r.u(55) - r.f(18, min: 13)) / 2)
            Node.say(planning, w - r.u(434), r.u(4), r.u(420), r.u(50), size: r.f(13.5, min: 10.5), color: periwinkle, align: "trailing", lines: 2)
            Node.rect(fill: Noor.hairline).size(w, 1).at(0, headY)
            Node.rect(fill: Noor.hairline).size(w, 1).at(0, bodyY)
            for x in lines { Node.rect(fill: Noor.hairline).size(1, headH).at(x, headY) }
            Node.say(L("Ramadan day"), c1, headY, lines[0] - c1, headH, size: r.f(15.5, min: 11.5), color: Noor.muted)
            Node.say(Words.prayer(.fajr), c2, headY, c3 - c2, headH, size: r.f(15.5, min: 11.5), color: Noor.muted)
            Node.say(Words.prayer(.maghrib), c3, headY, c4 - c3, headH, size: r.f(15.5, min: 11.5), color: Noor.muted)
            Node.say(L("Reminders"), c4, headY, w - c4 - r.u(12), headH, size: r.f(15.5, min: 11.5), color: Noor.muted)
            Node.scroll(contentHeight: Double(month.dayCount) * rowH, scrollTo: "day\(picked.number)") {
                for (i, day) in month.days.enumerated() {
                    let isPicked = day.number == picked.number
                    let on = chosen.enabled && chosen.days.contains(day.number)
                    let cell: (String, String, Double, Double) -> Node = { style, text, x, width in Node(["style": style, "text": text, "x": round10(x), "w": round10(width)]) }
                    Node.group {
                        if isPicked {
                            Node.rect(stroke: Noor.accent, lineWidth: 1, corner: r.u(8)).gradient([.adaptive(light: "#EDE4F7", dark: "#46348C"), .adaptive(light: "#F3ECFA", dark: "#2F2558")], from: (0, 0.5), to: (1, 0.5)).size(w, rowH - 1)
                        } else if i > 0 {
                            Node(["style": "rule", "y": 0])
                        }
                        cell("cellNumber", "\(day.number)", c1, r.u(40))
                        cell("cellMuted", Words.date(day.date, weekday: false, year: false), c1 + r.u(36), lines[0] - c1 - r.u(40))
                        cell("cellTime", Words.time(day.fajr, zone: zone), c2, c3 - c2)
                        cell("cellTime", Words.time(day.maghrib, zone: zone), c3, c4 - c3)
                        cell(on ? "cellOn" : "cellOff", on && !words.isEmpty ? words : L("Off"), c4, w - c4 - r.u(12))
                    }
                    .size(round10(w), round10(rowH)).at(0, round10(Double(i) * rowH)).id("day\(day.number)")
                    .area("day\(day.number)", label: L("Ramadan {number}, {date}, Fajr {fajr}, Maghrib {maghrib}", ["number": "\(day.number)", "date": Words.date(day.date), "fajr": Words.time(day.fajr, zone: zone), "maghrib": Words.time(day.maghrib, zone: zone)]), hover: nil, press: nil, selected: isPicked)
                }
            }
            .size(w, h - bodyY - r.u(6)).at(0, bodyY).id("ramadan-table")
        }
        .size(w, h)
    }

    /// What a table row's words share, so a month of rows stays inside a scene's 64 KB.
    private static func rowStyles(_ scene: Scene, w: Double, r: Ruler) -> Scene {
        let rowH = round10(r.u(40))
        func words(size: Double, weight: String = "regular", color: Color, tabular: Bool = true) -> [String: Any] {
            var out: [String: Any] = ["type": "text", "size": round10(size), "weight": weight, "design": "default", "color": color.json, "align": "leading", "valign": "center", "lines": 1, "min_scale": 0.7, "y": 0, "h": rowH]
            if tabular { out["tabular"] = true }
            return out
        }
        return scene
            .style("cellNumber", words(size: r.f(16.5, min: 12.5), weight: "medium", color: Noor.text))
            .style("cellTime", words(size: r.f(16.5, min: 12.5), color: Noor.text))
            .style("cellMuted", words(size: r.f(14, min: 11), color: Noor.muted, tabular: false))
            .style("cellOn", words(size: r.f(15, min: 11.5), color: Noor.text, tabular: false))
            .style("cellOff", words(size: r.f(15, min: 11.5), color: Noor.faint, tabular: false))
            .style("rule", ["type": "shape", "shape": "rect", "fill": Noor.hairline.json, "line_width": 1, "x": 0, "w": round10(w), "h": 1])
    }

    /// Rows of the side panel, from its top, so the drawn pills and the real controls over them stay together.
    private static func rowY(_ i: Int, r: Ruler) -> Double { max(r.u(62), 44) + Double(i) * rowStep(r) }
    /// Where words stop shrinking a row can't keep shrinking with the board.
    private static func rowStep(_ r: Ruler) -> Double { max(r.u(62), 54) }

    /// Where the panel's lower parts go, and how tall it must be to hold every word of its note.
    private struct Metrics {
        let lineY, buttonY, buttonH, offY, noteY, noteH, statusH: Double
        var needed: Double { noteY + noteH + 14 }

        @MainActor init(_ draft: Draft, w: Double, r: Ruler) {
            lineY = rowY(4, r: r) + 2
            buttonY = lineY + r.u(14)
            buttonH = max(r.u(46), 32)
            offY = buttonY + buttonH + r.u(10)
            noteY = draft.saved.enabled ? offY + max(r.u(42), 30) + r.u(12) : buttonY + buttonH + r.u(14)
            let size = r.f(14.5, min: 11.5)
            let perLine = (w - r.u(94)) / (size * 0.5)
            let statusLines = ceil(Double(RamadanPage.status(draft).count) / perLine)
            statusH = (statusLines + 0.3) * size * 1.3
            noteH = statusH + (ceil(Double(draft.preview.count) / perLine) + 0.3) * size * 1.3 + r.u(32)
        }
    }

    private static func status(_ draft: Draft) -> String {
        draft.saved.enabled ? L("Ramadan reminders are on.") : L("Ramadan reminders are not enabled. Nothing starts by itself when the month begins.")
    }

    private static func remindersPanel(_ ctx: Context, month: RamadanMonth, draft: Draft, w: Double, h: Double, r: Ruler) -> Node {
        let side = r.u(92)
        let pillW = r.u(96), daysW = r.u(136), pillH = max(r.u(34), 24)
        let daysLabel = draft.days == "all" ? L("All {count} days", ["count": "\(month.dayCount)"]) : L("Only the selected day")
        let suhoorLabel = draft.suhoor == "off" ? L("Off") : L("{minutes} min", ["minutes": draft.suhoor])
        let m = Metrics(draft, w: w, r: r)
        let textW = w - r.u(66) - pillW - r.u(20)
        return Node.group {
            Node.panel(w, h, corner: r.u(16))
            Node.group {
                Node.image("art/corner-l.png", dark: "art/corner-d.png", fit: "contain").size(side, side).at(w - side, 0).opacity(0.9)
                Node.image("art/corner-l.png", dark: "art/corner-d.png", fit: "contain").size(side * 1.5, side * 1.5).at(w - side * 1.5, h - side * 1.5).rotate(90).opacity(0.9)
            }
            .size(w, h).corner(r.u(16)).clip()
            Node.rect(stroke: Noor.inlay, lineWidth: 1, corner: r.u(16)).size(w, h).opacity(0.7)
            Node.say(L("Reminders"), r.u(19), r.u(14), w - side - r.u(20), r.u(36), size: r.f(23, min: 15), weight: "semibold")
            row("bell", L("Before Fajr"), L("Suhoor. Not a ruling on when a fast begins."), y: rowY(0, r: r), w: textW, r: r)
            dropdownSmall(suhoorLabel, w: pillW, h: pillH, r: r).at(w - pillW - r.u(16), rowY(0, r: r) + r.u(6))
            row("bell", L("At Maghrib"), L("Iftar reminder."), y: rowY(1, r: r), w: textW, r: r)
            row("calendar", L("Days"), nil, y: rowY(2, r: r), w: textW - daysW + pillW, r: r)
            dropdownSmall(daysLabel, w: daysW, h: pillH, r: r).at(w - daysW - r.u(16), rowY(2, r: r) + r.u(6))
            row("moon", L("Respects Focus and Quiet"), L("They follow your Focus, Quiet and Attention settings."), y: rowY(3, r: r), w: w - r.u(66) - r.u(12), r: r)
            Node.rect(fill: Noor.hairline).size(w - r.u(36), 1).at(r.u(18), m.lineY)
            Node.pill("enable", label: draft.saved.enabled ? L("Save changes") : L("Enable reminders"), x: r.u(18), y: m.buttonY, w: w - r.u(36), h: m.buttonH, symbol: "bell", filled: true, disabled: !draft.canEnable, size: r.f(17.5, min: 13))
            if draft.saved.enabled {
                Node.pill("off", label: L("Turn off Ramadan reminders"), x: r.u(18), y: m.offY, w: w - r.u(36), h: max(r.u(42), 30), size: r.f(15, min: 12))
            }
            Node.group {
                Node.rect(fill: Noor.quiet, stroke: Noor.hairline, lineWidth: 1, corner: r.u(12)).size(w - r.u(36), m.noteH)
                Node.symbol("info.circle", color: Noor.text).size(r.f(19, min: 14), r.f(19, min: 14)).at(r.u(14), r.u(14))
                Node.say(status(draft), r.u(44), r.u(12), w - r.u(36) - r.u(58), m.statusH, size: r.f(14.5, min: 11.5), color: draft.saved.enabled ? Noor.text : Noor.muted, lines: 6)
                Node.say(draft.preview, r.u(44), r.u(18) + m.statusH, w - r.u(36) - r.u(58), m.noteH - m.statusH - r.u(24), size: r.f(14.5, min: 11.5), color: Noor.muted, lines: 10)
            }
            .size(w - r.u(36), m.noteH).at(r.u(18), m.noteY)
        }
        .size(w, h)
    }

    private static func row(_ symbol: String, _ title: String, _ detail: String?, y: Double, w: Double, r: Ruler) -> Node {
        let glyph = r.f(26, min: 18)
        return Node.group {
            Node.symbol(symbol, color: symbol == "bell" ? Noor.accent : Noor.text).size(glyph, glyph).at(r.u(20), r.u(8))
            Node.say(title, r.u(60), detail == nil ? r.u(6) : 0, w, max(r.u(26), 18), size: r.f(17, min: 12.5))
            if let detail { Node.say(detail, r.u(60), max(r.u(24), 17), w, rowStep(r) - max(r.u(24), 17), size: r.f(13.5, min: 11), color: periwinkle, lines: 3) }
        }
        .size(r.u(60) + w, rowStep(r)).at(0, y)
    }

    private static func dropdownSmall(_ label: String, w: Double, h: Double, r: Ruler) -> Node {
        Node.group {
            Node.rect(fill: Noor.quiet, stroke: Noor.edge, lineWidth: 1, corner: h * 0.4).size(w, h)
            Node.say(label, r.u(12), 0, w - r.u(34), h, size: r.f(15, min: 11.5))
            Node.symbol("chevron.down", color: Noor.text).size(r.f(11, min: 9), r.f(7, min: 6)).at(w - r.u(24), (h - r.f(7, min: 6)) / 2)
        }
        .size(w, h)
    }

    /// The real controls over what the panel draws: they keep the draft's own state keys.
    private static func reminderInlays(month: RamadanMonth, draft: Draft, x: Double, y: Double, w: Double, r: Ruler) -> [PageInlay] {
        let pillW = r.u(96), daysW = r.u(136), pillH = max(r.u(34), 24)
        let minutes: [String] = ["10", "20", "30", "45"]
        return [
            PageInlay(x: x + w - pillW - r.u(16), y: y + rowY(0, r: r) + r.u(6), w: pillW, h: pillH,
                      .draftChoice(L("Suhoor reminder"), options: [Option("off", L("Off"))] + minutes.map { Option($0, L("{minutes} min", ["minutes": $0])) }, selected: draft.suhoor, key: "r_suhoor")),
            PageInlay(x: x + w - r.u(70), y: y + rowY(1, r: r) + r.u(4), w: r.u(54), h: pillH,
                      .draftToggle(L("Iftar reminder"), on: draft.iftar, key: "r_iftar")),
            PageInlay(x: x + w - daysW - r.u(16), y: y + rowY(2, r: r) + r.u(6), w: daysW, h: pillH,
                      .draftChoice(L("Days"), options: [Option("all", L("All {count} days", ["count": "\(month.dayCount)"])), Option("picked", L("Only the selected day"))], selected: draft.days, key: "r_days")),
        ]
    }
}
