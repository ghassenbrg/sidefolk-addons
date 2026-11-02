import Foundation
import SidefolkExtensionKit

/// Prayer: the dial and the exact ledger, on any date. Looking at another date changes nothing: not the reminders, not what is next.
@MainActor
enum PrayerPage {
    /// The date being looked at; today's unless the person went elsewhere.
    private static func looking(_ ctx: Context) -> CivilDate? {
        ctx.state.string("day").flatMap(CivilDate.init(iso:)) ?? ctx.snapshot.localDate
    }

    static func sections(_ ctx: Context) -> [Section] {
        if let status = NoorPage.unavailable(ctx), ctx.snapshot.validity != .loading { return [status] }
        guard let date = looking(ctx), let today = ctx.snapshot.localDate else { return [NoorPage.unavailable(ctx)].compactMap { $0 } }
        let day = ctx.model.day(date)
        var out: [Section] = []
        if let note = NoorPage.offlineNote(ctx) { out.append(Section(nil, [note], wide: true)) }
        out.append(Section(nil, [main(ctx, date: date, today: today, day: day)], wide: true))
        if let selected = selected(ctx), let day { out.append(Section(nil, [detail(ctx, selected, day)], wide: true)) }
        out.append(Section(L("Go to a date"), [.draftField(L("Date"), detail: L("Any date, written like {example}. Looking at another date changes nothing.", ["example": today.iso]), placeholder: today.iso, button: L("Go"), key: "day", set: ["select": NSNull()])],
                           collapsed: true, wide: true))
        return out
    }

    private static func selected(_ ctx: Context) -> PrayerID? { ctx.state.string("select").flatMap(PrayerID.init(rawValue:)) }

    private static func main(_ ctx: Context, date: CivilDate, today: CivilDate, day: PrayerDay?) -> Block {
        let w = ctx.width
        let gap = 16.0
        let leftW = ctx.narrow ? w : (w - gap) * 0.50, rightW = ctx.narrow ? w : w - gap - leftW
        let ledgerH = 112 + 6 * 52.0
        let dialH = ctx.narrow ? min(w * 1.1, 470) : ledgerH
        let rightX = ctx.narrow ? 0 : leftW + gap, rightY = ctx.narrow ? dialH + gap : 0
        let nightY = ctx.narrow ? rightY + ledgerH + gap : max(dialH, ledgerH) + gap
        let nightH = 120.0
        var acts: [String: PageAct] = [
            "prev": .go(Go(set: ["day": date.previous.iso, "select": NSNull()])),
            "next": .go(Go(set: ["day": date.next.iso, "select": NSNull()])),
            "today": .go(Go(set: ["day": NSNull(), "select": NSNull()])),
            "tomorrow": .go(Go(set: ["day": today.next.iso, "select": NSNull()])),
            "reminders": .go(Go(set: ["sheet": "prefs", "section": "reminders"], push: true)),
            "details": .go(Go(set: ["sheet": "prefs", "section": "calculation"], push: true)),
            "source": .go(Go(set: ["sheet": "prefs", "section": "sources"], push: true)),
        ]
        for prayer in PrayerID.allCases {
            acts["row.\(prayer.rawValue)"] = .go(Go(set: ["select": prayer.rawValue]))
            acts["bell.\(prayer.rawValue)"] = .go(Go(set: ["sheet": "prefs", "section": "reminders", "focus_prayer": prayer.rawValue], push: true))
        }
        let scene = Scene(width: w, height: nightY + nightH) {
            dial(ctx, w: leftW, h: dialH, date: date, today: today, day: day)
            ledger(ctx, w: rightW, h: ledgerH, date: date, today: today, day: day).at(rightX, rightY)
            tonight(ctx, w: w, h: nightH, day: day).at(0, nightY)
        }
        return .scene(PageSceneBlock(scene, acts: acts))
    }

    private static func dial(_ ctx: Context, w: Double, h: Double, date: CivilDate, today: CivilDate, day: PrayerDay?) -> Node {
        // Only today's dial has a now and a next; another date's shows when things were or will be.
        let s = ctx.snapshot
        let isToday = date == today
        let focus = isToday ? DialScene.focus(s) : nil
        let focusAt: Date? = {
            guard isToday else { return nil }
            switch s.next {
            case .prayerStart(_, let at, _), .iqamah(_, let at, _): return at
            default: return nil
            }
        }()
        let archInset = 22.0
        let radius = min((w - archInset * 2) / 2 - 64, (h - 150) / 2)
        let cx = w / 2, cy = radius + 112
        return Node.group {
            Node.patternPanel(w, h)
            Node.arch(w - archInset * 2, h - 20, lift: 52).at(archInset, 20)
            Node.inlay(w, h)
            if let day {
                Node.group {
                    Node.ellipse(fill: Noor.surface).size(radius * 1.74, radius * 1.74).at(cx - radius * 0.87, cy - radius * 0.87)
                    Node.group { DialScene.nodes(cx: cx, cy: cy, radius: radius, labelRadius: radius + 40, snapshot: s, day: day, focusAt: focusAt, big: w > 420) }.size(w, h)
                    Node.group {
                        if isToday {
                            DialScene.middle(cx: cx, cy: cy, radius: radius * 0.87, focus: focus)
                        } else {
                            Node.say(Words.date(date, weekday: true, year: false), cx - radius * 0.72, cy - 24, radius * 1.44, 48, size: 16, weight: "medium", align: "center", lines: 2)
                        }
                    }
                    .size(w, h)
                }
                .size(w, h).leftToRight().label(isToday ? DialScene.spoken(s, focus: focus) : L("Prayer dial for {date}.", ["date": Words.date(date)]))
            } else {
                Node.say(ctx.model.load == .loading ? L("Loading timetable") : L("No times for this date."), w * 0.15, h / 2 - 24, w * 0.7, 48, size: 16, color: Noor.muted, align: "center", lines: 2)
            }
        }
        .size(w, h)
    }

    private static func ledger(_ ctx: Context, w: Double, h: Double, date: CivilDate, today: CivilDate, day: PrayerDay?) -> Node {
        let s = ctx.snapshot
        let startX = w * 0.40, iqX = w * 0.60, bellX = w - 50
        let headTitle = date == today ? L("Today") : date == today.next ? L("Tomorrow") : L("Selected date")
        return Node.group {
            OverviewPage.card(w, h)
            Node.say(headTitle, 18, 12, w * 0.44, 30, size: 23, weight: "bold")
            Node.say(Words.date(date), 18, 42, w * 0.56, 22, size: 13, color: Noor.muted)
            Node.group { Node.symbol("chevron.backward", color: Noor.text).size(12, 14).at(10, 9) }.size(32, 32).at(w - 200, 14).area("prev", label: L("Previous day"))
            Node.group {
                Node.capsule(fill: date == today ? Noor.chosen : Noor.well).size(62, 30)
                Node.say(L("Today"), 2, 0, 58, 30, size: 12, weight: "medium", color: date == today ? Noor.onChosen : Noor.text, align: "center")
            }
            .size(62, 30).at(w - 168, 15).area("today", label: L("Today"), selected: date == today)
            Node.group {
                Node.capsule(fill: date == today.next ? Noor.chosen : Noor.well).size(76, 30)
                Node.say(L("Tomorrow"), 2, 0, 72, 30, size: 12, weight: "medium", color: date == today.next ? Noor.onChosen : Noor.text, align: "center")
            }
            .size(76, 30).at(w - 102, 15).area("tomorrow", label: L("Tomorrow"), selected: date == today.next)
            Node.group { Node.symbol("chevron.forward", color: Noor.text).size(12, 14).at(10, 9) }.size(32, 32).at(w - 30 + 0, 14).area("next", label: L("Next day"))
            Node.rect(fill: Noor.well, corner: 10).size(w - 24, 38).at(12, 70)
            Node.say(L("Prayer"), 22, 70, w * 0.3, 38, size: 12.5, weight: "medium", color: Noor.muted)
            Node.say(L("Starts"), startX, 70, w * 0.18, 38, size: 12.5, weight: "medium", color: Noor.muted)
            Node.say(L("Iqamah"), iqX, 70, w * 0.3, 38, size: 12.5, weight: "medium", color: Noor.muted)
            ledgerRows(ctx, w: w, y: 112, startX: startX, iqX: iqX, bellX: bellX, date: date, today: today, day: day, snapshot: s)
        }
        .size(w, h)
    }

    private static func ledgerRows(_ ctx: Context, w: Double, y: Double, startX: Double, iqX: Double, bellX: Double, date: CivilDate, today: CivilDate, day: PrayerDay?, snapshot s: NoorSnapshot) -> Node {
        var rows: [(key: String, prayer: PrayerID?, symbol: String, name: String, start: Date?, iqamah: Date?)] = []
        for id in PrayerID.allCases {
            rows.append((id.rawValue, id, symbol(id), Words.prayer(id), day?.starts[id], day?.iqamah[id]))
            if id == .fajr { rows.append(("sunrise", nil, "sun.horizon", Words.solar(.sunrise), day?.solar[.sunrise], nil)) }
        }
        let reminders = ctx.model.prefs.reminders
        var focusPrayer: PrayerID?
        if date == today {
            switch s.next {
            case .prayerStart(let id, _, let on) where on == today: focusPrayer = id
            case .iqamah(let id, _, _): focusPrayer = id
            default: break
            }
        }
        let selected = selected(ctx)
        return Node.group {
            for (i, row) in rows.enumerated() {
                let rowY = Double(i) * 52
                let next = row.prayer != nil && row.prayer == focusPrayer
                let past = date == today && (row.start.map { $0 <= s.now } ?? false) && !next
                let picked = row.prayer != nil && row.prayer == selected
                Node.group {
                    if next || picked {
                        Node.rect(fill: next ? .adaptive(light: "#F0E7F7", dark: "#3A2A5E") : Noor.well, stroke: next ? Noor.accent : Noor.hairline, lineWidth: 1, corner: 10).size(w - 20, 48).at(10, 2)
                    } else if i > 0 {
                        Node.rect(fill: Noor.hairline).size(w - 40, 1).at(20, 0)
                    }
                    Node.symbol(row.symbol, color: next ? Noor.accent : past ? Noor.faint : Noor.text).size(20, 20).at(22, 16)
                    Node.say(row.name, 52, 0, startX - 56, 52, size: 15, weight: next ? "semibold" : "regular", color: next ? Noor.accent : past ? Noor.muted : Noor.text)
                    Node.say(row.start.map(ctx.t) ?? "—", startX, 0, iqX - startX - 8, 52, size: 16, weight: next ? "semibold" : "regular", color: next ? Noor.accent : past ? Noor.muted : Noor.text, tabular: true)
                    // A missing iqamah is a dash: nothing is worked out from the start.
                    Node.say(row.iqamah.map(ctx.t) ?? "—", iqX, 0, bellX - iqX - 8, 52, size: 16, color: row.iqamah == nil ? Noor.faint : Noor.text, tabular: true)
                }
                .size(w, 52).at(0, rowY)
                .area(row.prayer.map { "row.\($0.rawValue)" } ?? "row.sunrise", label: rowSpoken(ctx, row.name, row.start, row.iqamah, next: next, past: past), disabled: row.prayer == nil, hover: .init(scale: 1.0), selected: picked)
                if let prayer = row.prayer {
                    let choice = reminders.prayers[prayer]
                    let on = reminders.master && choice.map { $0.atStart || $0.beforeMinutes != nil || $0.iqamahMinutes != nil } ?? false
                    Node.group {
                        Node.symbol(on ? "bell.fill" : "bell", color: on ? Noor.accent : Noor.muted).size(18, 18).at(9, 9)
                    }
                    .size(36, 36).at(bellX, rowY + 8)
                    .area("bell.\(prayer.rawValue)", label: on ? L("{prayer} reminder is on. Change it.", ["prayer": row.name]) : L("{prayer} reminder is off. Set it.", ["prayer": row.name]))
                }
            }
        }
        .size(w, 6 * 52).at(0, y)
    }

    private static func rowSpoken(_ ctx: Context, _ name: String, _ start: Date?, _ iqamah: Date?, next: Bool, past: Bool) -> String {
        var parts = [name, start.map { L("starts {time}", ["time": ctx.t($0)]) } ?? L("no time")]
        parts.append(iqamah.map { L("iqamah {time}", ["time": ctx.t($0)]) } ?? L("iqamah not provided"))
        if next { parts.append(L("next")) } else if past { parts.append(L("passed")) }
        return parts.joined(separator: ", ")
    }

    private static func symbol(_ id: PrayerID) -> String {
        switch id {
        case .fajr: "sun.haze"
        case .dhuhr: "sun.max"
        case .asr: "sun.min"
        case .maghrib: "sunset"
        case .isha: "moon"
        }
    }

    /// Why a row was picked: what it says in words, where the source came from, and how to change its bell.
    private static func detail(_ ctx: Context, _ prayer: PrayerID, _ day: PrayerDay) -> Block {
        let when = day.whenIs(prayer)
        let source = ctx.snapshot.source
        let reminder = ctx.model.prefs.reminders.prayers[prayer]
        return .facts(Words.prayer(prayer), [
            (L("Starts"), ctx.t(when.start)),
            (L("Iqamah"), when.iqamah.map(ctx.t) ?? L("Not provided")),
            (L("Date"), Words.date(day.date)),
            (L("Time zone"), day.zoneID),
            (L("Source"), "\(source?.name ?? "") · \(Words.sourceKind(source))"),
            (L("Reminder"), reminder.map { Reminder.words($0) } ?? L("Off")),
        ])
    }

    private static func tonight(_ ctx: Context, w: Double, h: Double, day: PrayerDay?) -> Node {
        let solar = day?.solar ?? [:]
        let shown: [(SolarEvent, String)] = [(.imsak, "sun.horizon.fill"), (.midnight, "moon.fill"), (.lastThird, "moon.stars.fill")].filter { solar[$0.0] != nil }
        let buttonW = ctx.narrow ? 0 : 200.0
        let span = w - buttonW - 240
        return Node.group {
            Node.patternPanel(w, h)
            Node.rect(fill: Noor.quiet, corner: 14).size(w - 16, h - 16).at(8, 8)
            Node.image("art/skyline-light.png", dark: "art/skyline-dark.png", fit: "cover").size(w - 16, h - 16).at(8, 8).corner(14).clip().opacity(0.85)
            Node.inlay(w, h)
            Node.say(L("Tonight"), 24, 14, 160, 24, size: 16, weight: "semibold")
            for (i, item) in shown.enumerated() {
                let x = 28 + max(span, 200) * (shown.count > 1 ? Double(i) / Double(shown.count) : 0)
                Node.symbol(item.1, color: .hex(i == 0 ? "#F1B44C" : "#B8A9F0")).size(20, 20).at(x + 46, 34)
                Node.say(Words.solar(item.0), x, 54, 112, 22, size: 12.5, color: Noor.muted, align: "center")
                Node.say(ctx.t(solar[item.0]!), x, 74, 112, 26, size: 16, weight: "semibold", align: "center", tabular: true)
            }
            if !ctx.narrow {
                Node.pill("reminders", label: L("Set reminders"), x: w - 214, y: 20, w: 194, h: 36, symbol: "bell", filled: true)
                Node.pill("details", label: L("Calculation details"), x: w - 214, y: 64, w: 194, h: 36, symbol: "slider.horizontal.3")
            }
        }
        .size(w, h)
    }
}

/// A prayer's reminder in a line of words.
enum Reminder {
    static func words(_ r: Reminders.Prayer) -> String {
        var parts: [String] = []
        if let m = r.beforeMinutes { parts.append(L("{minutes} min before", ["minutes": Format.integer(m)])) }
        if r.atStart { parts.append(L("at the start")) }
        if let m = r.iqamahMinutes { parts.append(m == 0 ? L("at iqamah") : L("{minutes} min before iqamah", ["minutes": Format.integer(m)])) }
        return parts.isEmpty ? L("Off") : Format.list(parts)
    }
}
