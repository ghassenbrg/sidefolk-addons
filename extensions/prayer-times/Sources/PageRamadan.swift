import Foundation
import SidefolkExtensionKit

/// The seasonal planner: month 9 as the provider returned it, 29 or 30 days, with Fajr, Maghrib and the provider's own Imsak kept apart. Nothing turns on when the month begins.
@MainActor
enum RamadanPage {
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
        let w = ctx.width
        let gap = 14.0
        let archH = 230.0
        let rowH = 38.0
        let tableH = 52 + 38 + rowH * 8
        let panelW = w
        var acts: [String: PageAct] = [:]
        for day in month.days { acts["day\(day.number)"] = .go(Go(set: ["ramadan_day": day.number])) }
        let scene = Scene(width: panelW, height: archH + gap + tableH) {
            fast(ctx, picked, month: month, w: panelW, h: archH)
            table(ctx, month, picked: picked, w: panelW, h: tableH, rowH: rowH).at(0, archH + gap)
        }
        var out: [Section] = [
            Section(nil, [
                .draftChoice(L("Year"), detail: L("Ramadan {year} has {days} days under {method}, starting {date}. Calculated; local announcements may differ.", ["year": "\(year)", "days": "\(month.dayCount)", "method": Words.calendarMethodName(ctx.model.prefs.calendarMethod), "date": month.days.first.map { Words.date($0.date, weekday: false) } ?? ""]),
                             options: [Option("\(year - 1)", "\(year - 1)"), Option("\(year)", "\(year)"), Option("\(year + 1)", "\(year + 1)")], selected: "\(year)", key: "ramadan_year_text"),
            ], wide: true),
            Section(nil, [.scene(PageSceneBlock(scene, acts: acts))], wide: true),
        ]
        // More times stay folded: they aren't what a fast is planned by, and they aren't five more prayers.
        out.append(Section(L("More times (optional)"), [.facts(nil, moreTimes(ctx, year: year, day: picked))], collapsed: true, detail: L("Imsak here is the provider's calculated value. It is not Fajr, and not a universal cutoff."), wide: true))
        out.append(Section(L("Reminders"), reminders(ctx, month: month), wide: true))
        return out
    }

    private static func moreTimes(_ ctx: Context, year: Int, day: RamadanDay) -> [(String, String)] {
        var out: [(String, String)] = []
        if let imsak = day.imsak { out.append((L("Imsak (calculated)"), ctx.t(imsak))) }
        if let known = ctx.model.day(day.date) {
            if let sunrise = known.solar[.sunrise] { out.append((Words.solar(.sunrise), ctx.t(sunrise))) }
            for id in [PrayerID.dhuhr, .asr, .isha] { out.append((Words.prayer(id), ctx.t(known.starts[id]!))) }
        }
        return out.isEmpty ? [(L("Fajr"), ctx.t(day.fajr))] : out
    }

    private static func fast(_ ctx: Context, _ day: RamadanDay, month: RamadanMonth, w: Double, h: Double) -> Node {
        let zone = IANAZone.zone(month.zoneID) ?? ctx.zone
        let t = { Words.time($0, zone: zone) }
        let length = day.maghrib.timeIntervalSince(day.fajr)
        let hours = Int(length / 3600), minutes = Int(length / 60) % 60
        let x0 = w * 0.14, x1 = w * 0.86, base = h - 76.0, top = 78.0
        let arc = "M \(x0) \(base) Q \(w / 2) \(top - 40) \(x1) \(base)"
        return Node.group {
            Node.patternPanel(w, h)
            Node.rect(fill: .adaptive(light: "#EFE8F7", dark: "#191D3E"), corner: 14).size(w - 16, h - 16).at(8, 8)
            Node.image("art/skyline-light.png", dark: "art/skyline-dark.png", fit: "cover").size(w - 16, h - 16).at(8, 8).corner(14).clip()
            Node.inlay(w, h)
            Node.say(L("Selected day · {number} Ramadan", ["number": "\(day.number)"]), 28, 18, w - 56, 28, size: 18, weight: "semibold")
            Node.say(L("Daily times, {date}", ["date": Words.date(day.date, weekday: true, year: true)]), 28, 44, w - 56, 22, size: 13, color: Noor.muted)
            Node.path(arc, stroke: .hex("#F1B44C"), lineWidth: 2, dash: [5, 4]).size(w, h).at(0, 0)
            Node.symbol("sun.max.fill", color: .hex("#F1B44C")).size(30, 30).at(w / 2 - 15, top - 8)
            Node.say(L("Day length"), w / 2 - 70, top + 28, 140, 20, size: 12.5, color: Noor.muted, align: "center")
            Node.say(L("{hours} h {minutes} min", ["hours": "\(hours)", "minutes": "\(minutes)"]), w / 2 - 80, top + 46, 160, 26, size: 18, weight: "semibold", align: "center")
            Node.ellipse(fill: .hex("#F1B44C")).size(14, 14).at(x0 - 7, base - 7)
            Node.ellipse(fill: .hex("#E46CB2")).size(14, 14).at(x1 - 7, base - 7)
            Node.say(Words.prayer(.fajr), x0 - 60, base + 6, 120, 22, size: 13, align: "center")
            Node.say(t(day.fajr), x0 - 60, base + 26, 120, 28, size: 19, weight: "semibold", align: "center", tabular: true)
            Node.say(Words.prayer(.maghrib), x1 - 60, base + 6, 120, 22, size: 13, color: Noor.accent, align: "center")
            Node.say(t(day.maghrib), x1 - 60, base + 26, 120, 28, size: 19, weight: "semibold", align: "center", tabular: true)
        }
        .size(w, h)
    }

    private static func table(_ ctx: Context, _ month: RamadanMonth, picked: RamadanDay, w: Double, h: Double, rowH: Double) -> Node {
        let zone = IANAZone.zone(month.zoneID) ?? ctx.zone
        let c1 = 20.0, c2 = w * 0.34, c3 = w * 0.52, c4 = w * 0.70
        let chosen = ctx.model.prefs.reminders.ramadan
        return Node.group {
            OverviewPage.card(w, h)
            Node.say(L("Ramadan {year}: daily times", ["year": "\(month.hijriYear)"]), 20, 12, w * 0.6, 28, size: 16, weight: "semibold")
            Node.say(L("Planning dates may differ from local announcements."), w * 0.42, 12, w * 0.58 - 18, 28, size: 11.5, color: Noor.muted, align: "trailing")
            Node.rect(fill: Noor.well, corner: 8).size(w - 24, 34).at(12, 46)
            Node.say(L("Day"), c1, 46, c2 - c1, 34, size: 12, weight: "medium", color: Noor.muted)
            Node.say(Words.prayer(.fajr), c2, 46, c3 - c2, 34, size: 12, weight: "medium", color: Noor.muted)
            Node.say(Words.prayer(.maghrib), c3, 46, c4 - c3, 34, size: 12, weight: "medium", color: Noor.muted)
            Node.say(L("Reminder"), c4, 46, w - c4 - 12, 34, size: 12, weight: "medium", color: Noor.muted)
            Node.scroll(contentHeight: Double(month.dayCount) * rowH, scrollTo: "day\(picked.number)") {
                for (i, day) in month.days.enumerated() {
                    let isPicked = day.number == picked.number
                    let on = chosen.enabled && chosen.days.contains(day.number)
                    Node.group {
                        if isPicked { Node.rect(fill: .adaptive(light: "#EDE4F7", dark: "#2F2558"), stroke: Noor.accent, lineWidth: 1, corner: 8).size(w - 24, rowH - 3) }
                        Node.say(L("{number} · {date}", ["number": "\(day.number)", "date": Words.date(day.date, weekday: false, year: false)]), c1 - 12, 0, c2 - c1, rowH, size: 13.5)
                        Node.say(Words.time(day.fajr, zone: zone), c2 - 12, 0, c3 - c2, rowH, size: 14, tabular: true)
                        Node.say(Words.time(day.maghrib, zone: zone), c3 - 12, 0, c4 - c3, rowH, size: 14, tabular: true)
                        Node.say(on ? L("On") : L("Off"), c4 - 12, 0, w - c4 - 12, rowH, size: 12.5, color: on ? Noor.accent : Noor.faint)
                    }
                    .size(w - 24, rowH).at(0, Double(i) * rowH).id("day\(day.number)")
                    .area("day\(day.number)", label: L("Ramadan {number}, {date}, Fajr {fajr}, Maghrib {maghrib}", ["number": "\(day.number)", "date": Words.date(day.date), "fajr": Words.time(day.fajr, zone: zone), "maghrib": Words.time(day.maghrib, zone: zone)]), hover: .init(scale: 1.0), selected: isPicked)
                }
            }
            .size(w - 24, h - 90).at(12, 84).id("ramadan-table")
        }
        .size(w, h)
    }

    /// A draft until Enable: nothing starts because the month began or because someone looked at this. The same Fajr or Maghrib moment as a prayer reminder comes as one notice.
    private static func reminders(_ ctx: Context, month: RamadanMonth) -> [Block] {
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
        let preview = Planner.plan(now: ctx.snapshot.now, prefs: trial, days: [], ramadan: month, occasions: [], names: []).first
        let zone = IANAZone.zone(month.zoneID) ?? ctx.zone
        var previewLine = L("Choose Suhoor or Iftar to see the next reminder.")
        if let preview {
            let what = preview.kind == .suhoor ? L("Suhoor") : L("Iftar")
            previewLine = L("Next would be {what} on {date} at {time} ({zone}). It's far off? It comes when its day is within 35 days.", ["what": what, "date": Words.date(CivilDate(preview.at, in: zone), weekday: false), "time": Words.time(preview.at, zone: zone), "zone": month.zoneID])
        } else if suhoor != "off" || iftar {
            previewLine = L("Those days have already passed.")
        }
        // Planner drops what is too far ahead for the host's horizon, so a future Ramadan's preview comes from the month itself.
        if preview == nil, suhoor != "off" || iftar, let first = month.days.first(where: { choice.contains($0.number) && $0.fajr > ctx.snapshot.now }) {
            let at = suhoor != "off" ? first.fajr.addingTimeInterval(-Double(Int(suhoor) ?? 0) * 60) : first.maghrib
            previewLine = L("First would be {what} on {date} at {time} ({zone}). Sidefolk schedules it once it's within 35 days.", ["what": suhoor != "off" ? L("Suhoor") : L("Iftar"), "date": Words.date(first.date, weekday: false), "time": Words.time(at, zone: zone), "zone": month.zoneID])
        }
        let canEnable = suhoor != "off" || iftar
        return [
            .draftChoice(L("Suhoor reminder"), detail: L("Before Fajr. Not a ruling on when a fast begins."), options: [Option("off", L("Off")), Option("10", L("{minutes} min", ["minutes": "10"])), Option("20", L("{minutes} min", ["minutes": "20"])), Option("30", L("{minutes} min", ["minutes": "30"])), Option("45", L("{minutes} min", ["minutes": "45"]))], selected: suhoor, key: "r_suhoor"),
            .draftToggle(L("Iftar reminder"), detail: L("At Maghrib."), on: iftar, key: "r_iftar"),
            .draftChoice(L("Days"), options: [Option("all", L("All {count} days", ["count": "\(month.dayCount)"])), Option("picked", L("Only the selected day"))], selected: days, key: "r_days"),
            .note(previewLine, tone: .info),
            .note(saved.enabled ? L("Ramadan reminders are on.") : L("Ramadan reminders are not enabled. Nothing starts by itself when the month begins."), tone: saved.enabled ? .good : .neutral),
            .action(Action(saved.enabled ? L("Save changes") : L("Enable reminders"), tool: "save_ramadan", input: ["enabled": true, "suhoor": suhoor == "off" ? -1 : (Int(suhoor) ?? -1), "iftar": iftar, "days": Array(choice).sorted()], style: .primary, symbol: "bell", disabled: !canEnable)),
            saved.enabled ? .action(Action(L("Turn off Ramadan reminders"), tool: "save_ramadan", input: ["enabled": false], style: .plain)) : .note(L("They follow your Focus, Quiet and Attention settings."), tone: .neutral),
        ]
    }
}
