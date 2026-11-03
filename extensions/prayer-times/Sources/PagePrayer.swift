import Foundation
import SidefolkExtensionKit

/// Prayer: the dial and the exact ledger, on any date. Looking at another date changes nothing: not the reminders, not what is next.
/// Its first composition is P02's, the arch beside the ledger over Tonight. While a mosque's timetable has an iqamah still to come, or its day is over, P03's stands in for it (`MosqueFocus`).
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
        if ctx.state.bool("full") != true, selected(ctx) == nil, date == today, let day, let hold = MosqueFocus.hold(ctx.snapshot, day: day) {
            out.append(Section(nil, [MosqueFocus.block(ctx, hold, day: day)], wide: true))
            return out
        }
        out.append(Section(nil, [main(ctx, date: date, today: today, day: day)], wide: true))
        if let selected = selected(ctx), let day { out.append(Section(nil, [detail(ctx, selected, day)], wide: true)) }
        out.append(Section(L("Go to a date"), [.draftField(L("Date"), detail: L("Any date, written like {example}. Looking at another date changes nothing.", ["example": today.iso]), placeholder: today.iso, button: L("Go"), key: "day", set: ["select": NSNull()])],
                           collapsed: true, wide: true))
        return out
    }

    private static func selected(_ ctx: Context) -> PrayerID? { ctx.state.string("select").flatMap(PrayerID.init(rawValue:)) }

    /// Places in P02's own numbers: a board's x less the sidebar's 245, its y less the 174 above the page.
    private static func main(_ ctx: Context, date: CivilDate, today: CivilDate, day: PrayerDay?) -> Block {
        let w = ctx.width
        var acts: [String: PageAct] = [
            "prev": .go(Go(set: ["day": date.previous.iso, "select": NSNull()])),
            "next": .go(Go(set: ["day": date.next.iso, "select": NSNull()])),
            "today": .go(Go(set: ["day": NSNull(), "select": NSNull()])),
            "tomorrow": .go(Go(set: ["day": today.next.iso, "select": NSNull()])),
            "reminders": .go(Go(set: ["sheet": "prefs", "section": "reminders"], push: true)),
            "details": .go(Go(set: ["sheet": "prefs", "section": "calculation"], push: true)),
            "source": .go(Go(set: ["sheet": "prefs", "section": "sources"], push: true)),
            "place": .go(Go(set: ["sheet": "prefs", "section": "place"], push: true)),
            "focus": .go(Go(set: ["full": NSNull(), "day": NSNull(), "select": NSNull()])),
        ]
        for prayer in PrayerID.allCases {
            acts["row-\(prayer.rawValue)"] = .go(Go(set: ["select": prayer.rawValue]))
            acts["bell-\(prayer.rawValue)"] = .go(Go(set: ["sheet": "prefs", "section": "reminders", "focus_prayer": prayer.rawValue], push: true))
        }
        if ctx.narrow {
            let margin = 16.0, inner = w - margin * 2, gap = 12.0
            let dialH = inner * 545 / 634, ledgerH = inner * 543 / 587, nightH = 300.0
            let tip = inner * 0.02
            let scene = Scene(width: w, height: tip + dialH + ledgerH + nightH + gap * 3) {
                dial(ctx, w: inner, h: dialH, date: date, today: today, day: day).at(margin, tip)
                ledger(ctx, w: inner, h: ledgerH, date: date, today: today, day: day).at(margin, tip + dialH + gap)
                tonightNarrow(ctx, w: inner, h: nightH, day: day).at(margin, tip + dialH + ledgerH + gap * 2)
            }
            return .scene(PageSceneBlock(scene, acts: acts))
        }
        let k = w / 1290
        let frameX = 30 * k, frameY = 14 * k, frameW = 634 * k, frameH = 545 * k
        let ledgerX = 679 * k, ledgerW = w - ledgerX - 24 * k
        let nightX = 20 * k, nightY = 574 * k, nightW = w - nightX - 22 * k, nightH = 190 * k
        let scene = Scene(width: w, height: nightY + nightH + 14 * k) {
            dial(ctx, w: frameW, h: frameH, date: date, today: today, day: day).at(frameX, frameY)
            ledger(ctx, w: ledgerW, h: 543 * k, date: date, today: today, day: day).at(ledgerX, frameY)
            tonight(ctx, w: nightW, h: nightH, day: day).at(nightX, nightY)
        }
        return .scene(PageSceneBlock(scene, acts: acts))
    }

    /// A date as the small line under Now: "Tue 3 Nov 2026", in the language's own order.
    static func shortDate(_ date: CivilDate) -> String {
        let f = DateFormatter()
        f.locale = Language.locale
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.setLocalizedDateFormatFromTemplate("EEEdMMMy")
        return f.string(from: date.anchor)
    }

    /// The arch cut out of the lattice, drawn so its proportions are the boards' at any size: its double line, its calm window, and the lattice left showing as spandrels at its feet. It may rise over the panel's top edge.
    static func archWindow(w: Double, h: Double, lift: Double, spandrel: Double) -> Node {
        // P02's own curve: a long shoulder rising from the sides into a slim tip.
        func head(_ w: Double, _ lift: Double) -> String {
            let y = lift / 190
            return "L 0 \(n(190 * y)) C 0 \(n(112 * y)) \(n(w * 0.13)) \(n(76 * y)) \(n(w * 0.34)) \(n(42 * y)) C \(n(w * 0.41)) \(n(30 * y)) \(n(w * 0.47)) \(n(14 * y)) \(n(w * 0.5)) 0 "
                + "C \(n(w * 0.53)) \(n(14 * y)) \(n(w * 0.59)) \(n(30 * y)) \(n(w * 0.66)) \(n(42 * y)) C \(n(w * 0.87)) \(n(76 * y)) \(n(w)) \(n(112 * y)) \(n(w)) \(n(190 * y)) "
        }
        let s = spandrel, k = s * 0.45
        let window = "M \(n(s)) \(n(h)) C \(n(s)) \(n(h - k)) \(n(k)) \(n(h - s)) 0 \(n(h - s)) " + head(w, lift) + "L \(n(w)) \(n(h - s)) C \(n(w - k)) \(n(h - s)) \(n(w - s)) \(n(h - k)) \(n(w - s)) \(n(h)) Z"
        let line = "M 0 \(n(h)) " + head(w, lift) + "L \(n(w)) \(n(h))"
        let inner = "M 0 \(n(h - 8)) " + head(w - 10, lift - 2) + "L \(n(w - 10)) \(n(h - 8))"
        return Node.group {
            Node.path(window, fill: .adaptive(light: "#FBF9FD", dark: "#0C0F2C")).size(w, h).at(0, 0)
            Node.path(line, stroke: Noor.inlay, lineWidth: 2.2).size(w, h).at(0, 0)
            Node.path(inner, stroke: Noor.inlay, lineWidth: 0.8).size(w - 10, h - 8).at(5, 8).opacity(0.7)
            Node.path("M \(n(s)) \(n(h)) C \(n(s)) \(n(h - k)) \(n(k)) \(n(h - s)) 0 \(n(h - s)) M \(n(w - s)) \(n(h)) C \(n(w - s)) \(n(h - k)) \(n(w - k)) \(n(h - s)) \(n(w)) \(n(h - s))", stroke: Noor.inlay, lineWidth: 1.6).size(w, h).at(0, 0)
        }
        .size(w, h)
    }

    /// The lattice with nothing on it, its cells the boards' size.
    static func latticeField(w: Double, h: Double, corner: Double) -> Node {
        Node.group {
            Node.image("art/prayer-lattice-l.jpg", dark: "art/prayer-lattice-d.jpg", fit: "cover").size(max(w, h * 3.75), h)
        }
        .size(w, h).corner(corner).clip()
    }

    private static func dial(_ ctx: Context, w: Double, h: Double, date: CivilDate, today: CivilDate, day: PrayerDay?) -> Node {
        // Only today's dial has a now and a next; another date's shows when things were or will be.
        let s = ctx.snapshot
        let r = Ruler(width: w * 1290 / 634)
        let isToday = date == today
        let focus = isToday ? DialScene.focus(s) : nil
        let focusAt = isToday ? OverviewPage.focusAt(s) : nil
        let radius = r.u(188)
        let cx = w / 2, cy = r.u(297)
        let ground = Color.adaptive(light: "#FBF9FD", dark: "#0C0F2C")
        let place = s.place?.label ?? s.source?.name ?? ""
        let pillSize = r.f(15), pillW = min(r.u(190), Double(place.count) * pillSize * 0.58 + pillSize * 3.6)
        // A mosque's focus can always be come back to, from where its pill led.
        let canFocus = ctx.state.bool("full") == true && isToday && day.flatMap { MosqueFocus.hold(s, day: $0) } != nil
        return Node.group {
            Node.frame(.dial, w, h, corner: r.u(16))
            Node.rect(stroke: Noor.inlay, lineWidth: 1.2, corner: r.u(16)).size(w, h)
            archWindow(w: w * 0.88, h: h + r.u(14) - 1, lift: r.u(190), spandrel: r.u(92)).at(w * 0.06, -r.u(14))
            // Now gets quiet ground of its own: words never stand on the lattice.
            Node.group {
                Node.glow(ground, cx: r.u(82), cy: r.u(92), r: r.u(150), opacity: 1)
                Node.glow(ground, cx: r.u(82), cy: r.u(92), r: r.u(120), opacity: 1)
                Node.glow(ground, cx: r.u(92), cy: r.u(72), r: r.u(104), opacity: 1)
                Node.glow(ground, cx: r.u(92), cy: r.u(116), r: r.u(104), opacity: 1)
                Node.say(L("Now"), r.u(33), r.u(36), r.u(150), r.u(24), size: r.f(16.5))
                Node.say(ctx.t(s.now), r.u(33), r.u(56), r.u(160), r.u(40), size: r.f(31, min: 17), weight: "medium", tabular: true)
                Node.say(shortDate(today), r.u(33), r.u(93), r.u(170), r.u(24), size: r.f(16.5))
                Node.pill("place", label: place, spoken: L("Place: {place}. Open.", ["place": place]), x: r.u(31), y: r.u(122), w: pillW, h: r.u(36), symbol: Node.Glyph.pin, size: pillSize)
            }
            .size(w, h).leftToRight()
            if let day {
                Node.group {
                    Node.group { DialScene.nodes(cx: cx, cy: cy, radius: radius, labelRadius: radius + r.f(18, min: 13) * 2.05, snapshot: s, day: day, focusAt: focusAt, big: w > 420, label: r.f(18, min: 12.5)) }.size(w, h)
                    Node.group {
                        if isToday {
                            DialScene.middle(cx: cx, cy: cy, radius: radius * 0.97, focus: focus)
                        } else {
                            Node.say(Words.date(date, weekday: true, year: false), cx - radius * 0.72, cy - r.u(30), radius * 1.44, r.u(60), size: r.f(22, min: 14), weight: "medium", align: "center", lines: 2)
                        }
                    }
                    .size(w, h)
                }
                .size(w, h).leftToRight().label(isToday ? DialScene.spoken(s, focus: focus) : L("Prayer dial for {date}.", ["date": Words.date(date)]))
            } else {
                Node.say(ctx.model.load == .loading ? L("Loading timetable") : L("No times for this date."), w * 0.15, h / 2 - 24, w * 0.7, 48, size: 16, color: Noor.muted, align: "center", lines: 2)
            }
            if canFocus {
                Node.pill("focus", label: L("Back to what's next"), x: w / 2 - r.u(120), y: h - r.u(52), w: r.u(240), h: r.u(40), symbol: "chevron.backward", size: r.f(15))
            }
        }
        .size(w, h)
    }

    private static func ledger(_ ctx: Context, w: Double, h: Double, date: CivilDate, today: CivilDate, day: PrayerDay?) -> Node {
        let s = ctx.snapshot
        let r = Ruler(width: w * 1290 / 587)
        let headTitle = date == today ? L("Today") : date == today.next ? L("Tomorrow") : L("Selected date")
        let segW = r.u(228), segX = w - r.u(46) - segW, split = segW * 0.43
        let lineX = w - r.u(246), bellLineX = w - r.u(73)
        let calculated = s.source?.kind != .manual
        return Node.group {
            Node.panel(w, h, corner: r.u(18))
            Node.say(headTitle, r.u(22), r.u(16), segX - r.u(66), r.u(44), size: r.f(34, min: 20), weight: "semibold")
            Node.say(Words.date(date), r.u(22), r.u(62), w * 0.6, r.u(28), size: r.f(20, min: 12.5), color: Noor.muted)
            Node.group { Node.symbol("chevron.backward", color: Noor.text).size(r.u(11), r.u(17)).at(r.u(14), r.u(12)) }.size(r.u(40), r.u(42)).at(segX - r.u(40), r.u(21)).area("prev", label: L("Previous day"))
            Node.rect(fill: Noor.quiet, stroke: Noor.hairline, lineWidth: 1, corner: r.u(10)).size(segW, r.u(42)).at(segX, r.u(21))
            Node.group {
                if date == today { Node.rect(fill: Noor.picked, stroke: Noor.pickedEdge, lineWidth: 1, corner: r.u(10)).size(split, r.u(42)) }
                Node.say(L("Today"), 2, 0, split - 4, r.u(42), size: r.f(17, min: 11.5), weight: date == today ? "medium" : "regular", color: date == today ? Noor.onChosen : Noor.muted, align: "center")
            }
            .size(split, r.u(42)).at(segX, r.u(21)).area("today", label: L("Today"), selected: date == today)
            Node.group {
                if date == today.next { Node.rect(fill: Noor.picked, stroke: Noor.pickedEdge, lineWidth: 1, corner: r.u(10)).size(segW - split, r.u(42)) }
                Node.say(L("Tomorrow"), 2, 0, segW - split - 4, r.u(42), size: r.f(17, min: 11.5), weight: date == today.next ? "medium" : "regular", color: date == today.next ? Noor.onChosen : Noor.muted, align: "center")
            }
            .size(segW - split, r.u(42)).at(segX + split, r.u(21)).area("tomorrow", label: L("Tomorrow"), selected: date == today.next)
            Node.group { Node.symbol("chevron.forward", color: Noor.text).size(r.u(11), r.u(17)).at(r.u(14), r.u(12)) }.size(r.u(40), r.u(42)).at(w - r.u(44), r.u(21)).area("next", label: L("Next day"))
            Node.rect(fill: .clear, stroke: Noor.hairline, lineWidth: 1, corner: r.u(12)).size(w - r.u(24), r.u(62)).at(r.u(12), r.u(101))
            Node.say(L("Prayer"), r.u(30), r.u(101), r.u(150), r.u(62), size: r.f(17.5, min: 12), weight: "medium")
            Node.say(L("Starts"), r.u(203), r.u(101), r.u(130), r.u(62), size: r.f(17.5, min: 12), weight: "medium")
            Node.rect(fill: Noor.hairline).size(1, r.u(44)).at(lineX, r.u(110))
            Node.group {
                Node.say(L("Iqamah"), 0, 0, r.u(70), r.u(24), size: r.f(17.5, min: 12), weight: "medium")
                Node.symbol("info.circle", color: Noor.text).size(r.f(17, min: 12), r.f(17, min: 12)).at(r.u(76), r.u(3))
                Node.say(calculated ? L("Not supplied by calculated times") : L("From this timetable"), 0, r.u(25), w - lineX - r.u(30), r.u(22), size: r.f(13.5, min: 10.5), color: Noor.muted)
            }
            .size(w - lineX - r.u(22), r.u(48)).at(lineX + r.u(16), r.u(108))
            .area("source", label: calculated ? L("Iqamah is not supplied by calculated times. Open sources.") : L("Iqamah comes from this timetable. Open sources."), hover: .init(scale: 1.0))
            ledgerRows(ctx, w: w, y: r.u(167), r: r, lineX: lineX, bellLineX: bellLineX, date: date, today: today, day: day, snapshot: s)
        }
        .size(w, h)
    }

    private static func ledgerRows(_ ctx: Context, w: Double, y: Double, r: Ruler, lineX: Double, bellLineX: Double, date: CivilDate, today: CivilDate, day: PrayerDay?, snapshot s: NoorSnapshot) -> Node {
        var rows: [(key: String, prayer: PrayerID?, symbol: (String, Color), name: String, start: Date?, iqamah: Date?)] = []
        for id in PrayerID.allCases {
            rows.append((id.rawValue, id, symbol(id), Words.prayer(id), day?.starts[id], day?.iqamah[id]))
            if id == .fajr { rows.append(("sunrise", nil, ("sunrise.fill", .hex("#F1D27A")), Words.solar(.sunrise), day?.solar[.sunrise], nil)) }
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
        let rowH = r.u(61), glyph = r.f(30, min: 18), bell = r.f(25, min: 16)
        return Node.group {
            for (i, row) in rows.enumerated() {
                let rowY = Double(i) * rowH
                let next = row.prayer != nil && row.prayer == focusPrayer
                let past = date == today && (row.start.map { $0 <= s.now } ?? false) && !next
                let picked = row.prayer != nil && row.prayer == selected
                let ink = next ? Noor.accent : Noor.text
                Node.group {
                    if next {
                        Node.rect(stroke: Noor.accent, lineWidth: 1, corner: r.u(12)).gradient([.adaptive(light: "#F3EAFA", dark: "#46306F"), .adaptive(light: "#EADFF6", dark: "#2E2352")], from: (0, 0.5), to: (1, 0.5)).size(w - r.u(24), rowH + 1).at(r.u(12), 0)
                    } else if picked {
                        Node.rect(fill: Noor.well, stroke: Noor.pickedEdge, lineWidth: 1, corner: r.u(12)).size(w - r.u(24), rowH + 1).at(r.u(12), 0)
                    } else if i > 0, !(i - 1 < rows.count && rows[i - 1].prayer != nil && rows[i - 1].prayer == focusPrayer) {
                        Node.rect(fill: Noor.hairline).size(w - r.u(46), 1).at(r.u(23), 0)
                    }
                    Node.symbol(row.symbol.0, color: row.symbol.1).size(glyph, glyph).at(r.u(41) - glyph / 2, (rowH - glyph) / 2)
                    Node.say(row.name, r.u(76), 0, r.u(118), rowH, size: r.f(20, min: 13), weight: next ? "semibold" : "regular", color: ink)
                    Node.say(row.start.map(ctx.t) ?? "—", r.u(200), 0, r.u(120), rowH, size: r.f(22, min: 14), weight: next ? "semibold" : "regular", color: ink, tabular: true)
                    Node.rect(fill: Noor.hairline).size(1, r.u(34)).at(lineX, (rowH - r.u(34)) / 2)
                    // A missing iqamah is a dash: nothing is worked out from the start.
                    Node.say(row.iqamah.map(ctx.t) ?? "—", lineX + r.u(19), 0, bellLineX - lineX - r.u(24), rowH, size: r.f(21, min: 13.5), color: row.iqamah == nil ? Noor.muted : ink, tabular: true)
                    Node.rect(fill: Noor.hairline).size(1, r.u(34)).at(bellLineX, (rowH - r.u(34)) / 2)
                    if row.prayer == nil {
                        // Sunrise isn't a prayer: it has no bell to offer.
                        Node.say("—", bellLineX + 1, 0, w - bellLineX - r.u(12), rowH, size: r.f(21, min: 13.5), color: Noor.muted, align: "center")
                    }
                }
                .size(w, rowH).at(0, rowY)
                .area(row.prayer.map { "row-\($0.rawValue)" } ?? "row-sunrise", label: rowSpoken(ctx, row.name, row.start, row.iqamah, next: next, past: past), disabled: row.prayer == nil, hover: .init(scale: 1.0), selected: picked)
                if let prayer = row.prayer {
                    let choice = reminders.prayers[prayer]
                    let on = reminders.master && choice.map { $0.atStart || $0.beforeMinutes != nil || $0.iqamahMinutes != nil } ?? false
                    let box = bell + r.u(14)
                    Node.group {
                        Node.symbol(on ? "bell.fill" : "bell", color: next || on ? Noor.accent : Noor.text).size(bell, bell).at(r.u(7), r.u(7))
                    }
                    .size(box, box).at((bellLineX + w - r.u(12)) / 2 - box / 2, rowY + (rowH - box) / 2)
                    .area("bell-\(prayer.rawValue)", label: on ? L("{prayer} reminder is on. Change it.", ["prayer": row.name]) : L("{prayer} reminder is off. Set it.", ["prayer": row.name]))
                }
            }
        }
        .size(w, rowH * 6).at(0, y)
    }

    private static func rowSpoken(_ ctx: Context, _ name: String, _ start: Date?, _ iqamah: Date?, next: Bool, past: Bool) -> String {
        var parts = [name, start.map { L("starts {time}", ["time": ctx.t($0)]) } ?? L("no time")]
        parts.append(iqamah.map { L("iqamah {time}", ["time": ctx.t($0)]) } ?? L("iqamah not provided"))
        if next { parts.append(L("next")) } else if past { parts.append(L("passed")) }
        return parts.joined(separator: ", ")
    }

    /// Each prayer's sign in the ledger, in the colours of its hour.
    static func symbol(_ id: PrayerID) -> (String, Color) {
        switch id {
        case .fajr: ("sun.max", Noor.text)
        case .dhuhr: ("sun.max.fill", .hex("#F1C25B"))
        case .asr: ("sun.horizon", Noor.text)
        case .maghrib: ("sunset.fill", .hex("#F1B44C"))
        case .isha: ("moon", Noor.text)
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

    /// What Tonight names: only what the source gave, and a time after midnight says so.
    private static func nightTimes(_ ctx: Context, day: PrayerDay?) -> [(event: SolarEvent, symbol: String, name: String, at: Date)] {
        guard let day else { return [] }
        let shown: [(SolarEvent, String)] = [(.imsak, "sun.horizon.fill"), (.midnight, "moon.fill"), (.lastThird, "moon.fill")]
        return shown.compactMap { event, symbol in
            guard let at = day.solar[event] else { return nil }
            let later = CivilDate(at, in: day.zone) > day.date
            return (event, symbol, later ? L("{event} (next day)", ["event": Words.solar(event)]) : Words.solar(event), at)
        }
    }

    /// A time's gold on the night's pale hills, in the light: the page's own warm is a shade too thin there.
    static let nightWarm = Color.adaptive(light: "#6F4509", dark: "#EFCF8E")

    /// The night picture placed so its mosque stands at `mosqueAt` of a strip and its foot at `footY`. The picture is hills from edge to edge, its sky and foot already the strip's own ground (`scripts/noor-night-art.py`): nothing to fade out, and what is below the foot is quiet enough for words.
    static func nightArt(w: Double, h: Double, mosqueAt: Double, footY: Double, across: Double, corner: Double) -> Node {
        let artW = across, artH = artW / 6
        return Node.group {
            Node.image("art/prayer-night-l.jpg", dark: "art/prayer-night-d.jpg", fit: "fill").size(artW, artH).at(w * mosqueAt - artW * 0.6, footY - artH * 0.68)
        }
        .size(w, h).corner(corner).clip()
    }

    /// The strip's night inside its lattice rim, as P02: lobes down its left, a scalloped side down its right, each as tall as the strip. Where the strip is too tall for those (`corners`), a lattice corner at each end instead.
    static func nightGround(w: Double, h: Double, corner: Double, mosqueAt: Double = 0.58, footY: Double? = nil, corners: Double? = nil) -> [Node] {
        [
            Node.panel(w, h, corner: corner, fill: .adaptive(light: "#F7F3FB", dark: "#0E1234")),
            nightArt(w: w, h: h, mosqueAt: mosqueAt, footY: footY ?? h * 0.62, across: max(w * 1.05, h * 6), corner: corner),
            Node.group {
                if let corners {
                    Node.image("art/corner-l.png", dark: "art/corner-d.png", fit: "contain").size(corners, corners).at(w - corners, 0).turnsWithWords()
                    Node.image("art/corner-l.png", dark: "art/corner-d.png", fit: "contain").size(corners * 0.7, corners * 0.7).at(0, h - corners * 0.7).turned(180)
                } else {
                    Node.image("art/prayer-rim-left-l.png", dark: "art/prayer-rim-left-d.png", fit: "fill").size(h * 0.3, h).at(0, 0).turnsWithWords()
                    Node.image("art/prayer-rim-right-l.png", dark: "art/prayer-rim-right-d.png", fit: "fill").size(h * 0.73, h).at(w - h * 0.73, 0).turnsWithWords()
                }
            }
            .size(w, h).corner(corner).clip(),
            Node.rect(stroke: Noor.inlay, lineWidth: 1.2, corner: corner).size(w, h),
        ]
    }

    private static func tonight(_ ctx: Context, w: Double, h: Double, day: PrayerDay?) -> Node {
        let r = Ruler(width: w * 1290 / 1248)
        let times = nightTimes(ctx, day: day)
        let places = [127.0, 329.0, 556.0].map { r.u($0) }
        let manual = ctx.snapshot.source?.kind == .manual
        let arc = "M \(n(places[0] + r.u(8))) \(n(r.u(64))) C \(n(places[0] + r.u(120))) \(n(r.u(24))) \(n(places[2] - r.u(150))) \(n(r.u(14))) \(n(places[2] - r.u(16))) \(n(r.u(64)))"
        let glyph = r.f(29, min: 18)
        let lineX = w - r.u(326), noteX = r.u(720), pillX = w - r.u(306)
        return Node.group {
            nightGround(w: w, h: h, corner: r.u(18), footY: r.u(102))
            Node.say(L("Tonight"), r.u(25), r.u(12), r.u(200), r.u(34), size: r.f(23, min: 15), weight: "semibold")
            if times.count == 3 {
                Node.path(arc, stroke: .adaptive(light: "#7A5AB8", dark: "#D6C6F2"), lineWidth: 1.3, dash: [1.5, 5]).size(w, h).at(0, 0)
            }
            for (i, item) in times.enumerated() {
                let x = places[i]
                let sun = item.event == .imsak
                Node.glow(sun ? .hex("#F6B45C") : .hex("#8C7AE6"), cx: x, cy: r.u(77), r: glyph * 1.1)
                Node.symbol(sun ? "sun.max.fill" : "moon.fill", color: sun ? .hex("#F6C04C") : .adaptive(light: "#7A5AB8", dark: "#D6C6F2")).size(glyph, glyph).at(x - glyph / 2, r.u(77) - glyph / 2)
                Node.say(item.name, x - r.u(100), r.u(102), r.u(200), r.u(26), size: r.f(18, min: 12), color: sun ? nightWarm : Noor.text, align: "center")
                Node.say(ctx.t(item.at), x - r.u(100), r.u(127), r.u(200), r.u(30), size: r.f(21, min: 13), color: sun ? nightWarm : Noor.text, align: "center", tabular: true)
            }
            if times.isEmpty {
                Node.say(manual ? L("This timetable lists prayers only, so it has no night times.") : L("No night times for this date."), r.u(66), r.u(104), r.u(600), r.u(56), size: r.f(17, min: 12), color: Noor.muted, lines: 2)
            }
            Node.rect(fill: Noor.faint).size(1, r.u(50)).at(noteX - r.u(26), r.u(118))
            if manual {
                MosqueFocus.sourceWords(ctx, x: noteX, y: r.u(112), w: lineX - noteX - r.u(16), h: r.u(60), size: r.f(16, min: 11.5))
            } else {
                Node.say(L("Night times follow your selected convention."), noteX, r.u(112), lineX - noteX - r.u(16), r.u(60), size: r.f(16, min: 11.5), color: Noor.muted, lines: 2)
            }
            Node.rect(fill: Noor.faint).size(1, r.u(80)).at(lineX, r.u(77))
            Node.pill("reminders", label: L("Set reminders"), x: pillX, y: r.u(53), w: r.u(244), h: r.u(47), symbol: "bell", filled: true, size: r.f(19, min: 13))
            if manual {
                Node.pill("source", label: L("Source details"), x: pillX, y: r.u(114), w: r.u(244), h: r.u(47), symbol: "slider.horizontal.3", size: r.f(19, min: 13))
            } else {
                Node.pill("details", label: L("Calculation details"), x: pillX, y: r.u(114), w: r.u(244), h: r.u(47), symbol: "slider.horizontal.3", size: r.f(19, min: 13))
            }
        }
        .size(w, h)
    }

    /// One column: Tonight's three times on their arc, its note, then the two buttons.
    private static func tonightNarrow(_ ctx: Context, w: Double, h: Double, day: PrayerDay?) -> Node {
        let times = nightTimes(ctx, day: day)
        let manual = ctx.snapshot.source?.kind == .manual
        let step = w / 3
        return Node.group {
            nightGround(w: w, h: h, corner: 16, mosqueAt: 0.7, footY: 74, corners: 64)
            Node.say(L("Tonight"), 18, 10, 200, 28, size: 18, weight: "semibold")
            for (i, item) in times.enumerated() {
                let x = step * (Double(i) + 0.5)
                let sun = item.event == .imsak
                Node.glow(sun ? .hex("#F6B45C") : .hex("#8C7AE6"), cx: x, cy: 58, r: 22)
                Node.symbol(sun ? "sun.max.fill" : "moon.fill", color: sun ? .hex("#F6C04C") : .adaptive(light: "#7A5AB8", dark: "#D6C6F2")).size(22, 22).at(x - 11, 47)
                Node.say(item.name, x - step / 2 + 4, 76, step - 8, 36, size: 13, color: sun ? nightWarm : Noor.text, align: "center", lines: 2)
                Node.say(ctx.t(item.at), x - step / 2 + 4, 112, step - 8, 26, size: 16, color: sun ? nightWarm : Noor.text, align: "center", tabular: true)
            }
            if manual {
                MosqueFocus.sourceWords(ctx, x: 18, y: 146, w: w - 36, h: 42, size: 12.5)
            } else {
                Node.say(L("Night times follow your selected convention."), 18, 146, w - 36, 40, size: 12.5, color: Noor.muted, lines: 2)
            }
            Node.pill("reminders", label: L("Set reminders"), x: 18, y: 192, w: w - 36, h: 42, symbol: "bell", filled: true, size: 15)
            if manual {
                Node.pill("source", label: L("Source details"), x: 18, y: 244, w: w - 36, h: 42, symbol: "slider.horizontal.3", size: 15)
            } else {
                Node.pill("details", label: L("Calculation details"), x: 18, y: 244, w: w - 36, h: 42, symbol: "slider.horizontal.3", size: 15)
            }
        }
        .size(w, h)
    }
}

extension Node {
    /// The host moves a picture to the other side in a language that reads right to left, but draws it as it is: lattice cut to fit one corner needs turning to fit the other.
    func turnsWithWords() -> Node { Language.rightToLeft ? scale(x: -1, y: 1) : self }
    /// The same for a piece already turned to fit another corner. The host turns a rotation the other way itself, and its flip comes after the rotation, so this one is sent backwards.
    func turned(_ degrees: Double) -> Node { Language.rightToLeft ? rotate(-degrees).scale(x: -1, y: 1) : rotate(degrees) }
}

/// P03: a mosque's timetable while the moment isn't simply "the next start": between a start and its iqamah, and once the day's last prayer has begun. Start and congregation stay separate, nothing is inferred, and tomorrow is named only if the timetable has it.
@MainActor
enum MosqueFocus {
    enum Hold {
        /// A start has passed and its iqamah hasn't.
        case between(PrayerID)
        /// The last start of the day has passed.
        case night(last: PrayerID)
    }

    static func hold(_ s: NoorSnapshot, day: PrayerDay) -> Hold? {
        guard s.source?.kind == .manual, let last = day.ordered.last?.id else { return nil }
        switch s.next {
        case .iqamah(let id, _, _): return id == last ? .night(last: last) : .between(id)
        case .prayerStart(_, _, let on) where on != s.localDate: return .night(last: last)
        case .unavailable(.noTomorrow): return .night(last: last)
        default: return nil
        }
    }

    /// "Source: Entered by you · Valid through 30 Nov", as a way to the source's own place.
    static func sourceLine(_ ctx: Context) -> (kind: String, valid: String?) {
        let valid = ctx.snapshot.coverage.map { L("Valid through {date}", ["date": Words.date($0.upperBound, weekday: false, year: false)]) }
        return (L("Source: Entered by you"), valid)
    }

    static func sourceWords(_ ctx: Context, x: Double, y: Double, w: Double, h: Double, size: Double) -> Node {
        let line = sourceLine(ctx)
        return Node.say([line.kind, line.valid].compactMap { $0 }.joined(separator: " · "), x, y, w, h, size: size, color: Noor.muted, lines: 2)
    }

    static func block(_ ctx: Context, _ hold: Hold, day: PrayerDay) -> Block {
        var acts: [String: PageAct] = [
            "full": .go(Go(set: ["full": true])),
            "source": .go(Go(set: ["sheet": "prefs", "section": "sources"], push: true)),
        ]
        for prayer in PrayerID.allCases { acts["col-\(prayer.rawValue)"] = .go(Go(set: ["full": true, "select": prayer.rawValue])) }
        let scene = ctx.narrow ? narrow(ctx, hold, day: day) : wide(ctx, hold, day: day)
        return .scene(PageSceneBlock(scene, acts: acts))
    }

    private static func title(_ hold: Hold) -> String {
        switch hold {
        case .between: L("Between start and iqamah")
        case .night(let last): L("After {prayer} starts", ["prayer": Words.prayer(last)])
        }
    }

    /// The next thing after what the dial holds: a start today, or tomorrow's first.
    private static func coming(_ s: NoorSnapshot, day: PrayerDay, hold: Hold) -> (id: PrayerID, at: Date, iqamah: Date?, tomorrow: Bool)? {
        switch hold {
        case .between:
            guard let next = day.ordered.first(where: { $0.at > s.now }) else { return nil }
            return (next.id, next.at, day.iqamah[next.id], false)
        case .night:
            guard let tomorrow = s.tomorrow, tomorrow.date == day.date.next, tomorrow.sourceID == day.sourceID, let fajr = tomorrow.starts[.fajr] else { return nil }
            return (.fajr, fajr, tomorrow.iqamah[.fajr], true)
        }
    }

    private static func wide(_ ctx: Context, _ hold: Hold, day: PrayerDay) -> Scene {
        let w = ctx.width, s = ctx.snapshot
        let margin = max(12, w * 0.018), outer = w - margin * 2
        let v = outer >= 702 ? min(max(1, outer / 1020), 1.3) : outer / 702
        let u: (Double) -> Double = { $0 * v }
        let f: (Double, Double) -> Double = { max($0 * v, $1) }
        let headH = u(60), frameH = u(390), stripH = u(196)
        let frameW = outer - u(12)
        let total = headH + frameH + stripH + u(8)
        let panel = coming(s, day: day, hold: hold)
        return Scene(width: w, height: total + u(22)) {
            Node.group {
                Node.panel(outer, total, corner: u(18))
                Node.rect(stroke: Noor.inlay, lineWidth: 1, corner: u(18)).size(outer, total).opacity(0.7)
                head(ctx, hold, w: outer, h: headH, u: u, f: f)
                dialPanel(ctx, hold, day: day, coming: panel, w: frameW, h: frameH, u: u, f: f).at(u(6), headH)
                switch hold {
                case .between(let id): timesStrip(ctx, id, day: day, w: outer - u(12), h: stripH, u: u, f: f).at(u(6), headH + frameH - u(4))
                case .night(let last): nightStrip(ctx, last, day: day, coming: panel, w: outer - u(12), h: stripH, u: u, f: f).at(u(6), headH + frameH - u(4))
                }
            }
            .size(outer, total).at(margin, u(10))
        }
    }

    private static func narrow(_ ctx: Context, _ hold: Hold, day: PrayerDay) -> Scene {
        let w = ctx.width, s = ctx.snapshot
        let margin = 16.0, inner = w - margin * 2
        let v = min(inner / 702 * 1.3, 1)
        let u: (Double) -> Double = { $0 * v }
        let f: (Double, Double) -> Double = { max($0 * v, $1) }
        let headH = 92.0, frameH = inner * 0.86, cardH = 208.0, pillH = 44.0, stripH = 176.0, gap = 12.0
        let panel = coming(s, day: day, hold: hold)
        return Scene(width: w, height: headH + frameH + cardH + pillH + stripH + gap * 4) {
            head(ctx, hold, w: inner, h: headH, u: u, f: f, stacked: true).at(margin, 0)
            Node.group {
                Node.frame(.dial, inner, frameH)
                PrayerPage.archWindow(w: inner * 0.88, h: frameH, lift: frameH * 0.32, spandrel: frameH * 0.16).at(inner * 0.06, 0)
                dialMarks(ctx, day: day, cx: inner / 2, cy: frameH * 0.54, radius: min(inner * 0.33, frameH * 0.36), w: inner, h: frameH, f: f, u: u)
            }
            .size(inner, frameH).at(margin, headH)
            card(ctx, hold, coming: panel, w: inner, h: cardH, u: { $0 * 0.82 }, f: { max($0 * 0.82, $1) }).at(margin, headH + frameH + gap)
            Node.pill("full", label: L("View full prayer times"), x: margin, y: headH + frameH + cardH + gap * 2, w: inner, h: pillH, symbol: "chevron.forward", size: 15)
            switch hold {
            case .between(let id): timesStrip(ctx, id, day: day, w: inner, h: stripH, u: { $0 * 0.82 }, f: { max($0 * 0.82, $1) }, stacked: true).at(margin, headH + frameH + cardH + pillH + gap * 3)
            case .night(let last): nightStrip(ctx, last, day: day, coming: panel, w: inner, h: stripH, u: { $0 * 0.82 }, f: { max($0 * 0.82, $1) }).at(margin, headH + frameH + cardH + pillH + gap * 3)
            }
        }
    }

    private static func head(_ ctx: Context, _ hold: Hold, w: Double, h: Double, u: (Double) -> Double, f: (Double, Double) -> Double, stacked: Bool = false) -> Node {
        let s = ctx.snapshot
        let date = s.localDate.map { Words.date($0) } ?? ""
        let now = Node.runs([(L("Now") + "  ", Noor.text, "regular"), (ctx.t(s.now), Noor.text, "medium")], size: f(20, 15), color: Noor.text, align: stacked ? "leading" : "trailing").textLook(tabular: true)
        return Node.group {
            if stacked {
                Node.say(title(hold), 2, 4, w - 4, 34, size: 20, weight: "semibold")
                Node.symbol("clock", color: Noor.text).size(16, 16).at(2, 42)
                now.size(w - 30, 24).at(26, 38)
                Node.say(date, 2, 62, w - 4, 22, size: 13, color: Noor.muted)
            } else {
                Node.say(title(hold), u(27), u(10), w * 0.6, u(44), size: f(28, 18), weight: "semibold")
                Node.symbol("clock", color: Noor.text).size(f(20, 14), f(20, 14)).at(w - u(27) - u(134), u(12))
                now.size(u(124), u(26)).at(w - u(27) - u(124), u(9))
                Node.say(date, w * 0.5, u(34), w * 0.5 - u(27), u(24), size: f(15, 11.5), color: Noor.muted, align: "trailing")
            }
        }
        .size(w, h)
    }

    /// The ring and the moment in its middle. The middle says what P03 does: its title, not the eyebrow over it, and when the prayer began under two lines.
    private static func dialMarks(_ ctx: Context, day: PrayerDay, cx: Double, cy: Double, radius: Double, w: Double, h: Double, f: (Double, Double) -> Double, u: (Double) -> Double) -> Node {
        let s = ctx.snapshot
        let focus = DialScene.focus(s)
        let scale = radius / 150
        return Node.group {
            Node.image("art/glow.png", tint: .adaptive(light: "#FBF9FD", dark: "#0C0F2C")).size(radius * 3.2, radius * 3.2).at(cx - radius * 1.6, cy - radius * 1.6)
            Node.group {
                Node.group { DialScene.nodes(cx: cx, cy: cy, radius: radius, labelRadius: radius + f(15.5, 11.5) * 2.0, snapshot: s, day: day, focusAt: OverviewPage.focusAt(s), big: radius > 110, label: f(15.5, 11.5)) }.size(w, h)
                Node.group {
                    if let focus {
                        let hasBelow = focus.below != nil
                        let top = cy - (hasBelow ? 66 : 56) * scale
                        if !hasBelow { Node.say(focus.eyebrow, cx - radius * 0.78, top - 16 * scale, radius * 1.56, 20 * scale, size: 14 * scale, align: "center") }
                        Node.say(focus.title, cx - radius * 0.78, top, radius * 1.56, 34 * scale, size: 24 * scale, weight: "medium", color: Noor.accent, align: "center")
                        Node.say(focus.time, cx - radius * 0.78, top + 30 * scale, radius * 1.56, 62 * scale, size: 49 * scale, align: "center", tabular: true)
                        Node.say(focus.countdown, cx - radius * 0.78, top + 86 * scale, radius * 1.56, 32 * scale, size: 25 * scale, color: Noor.warm, align: "center")
                        if let below = focus.below {
                            Node.say(below, cx - radius * 0.34, top + 118 * scale, radius * 0.68, 42 * scale, size: 15 * scale, color: Noor.text, align: "center", lines: 2)
                        }
                    } else {
                        DialScene.middle(cx: cx, cy: cy, radius: radius * 0.84, focus: nil)
                    }
                }
                .size(w, h)
            }
            .size(w, h).leftToRight().label(DialScene.spoken(s, focus: focus))
        }
        .size(w, h)
    }

    /// The panel: lattice all across, one arch cut out of it at any proportion, the card and the way to the whole ledger on its right.
    private static func dialPanel(_ ctx: Context, _ hold: Hold, day: PrayerDay, coming: (id: PrayerID, at: Date, iqamah: Date?, tomorrow: Bool)?, w: Double, h: Double, u: (Double) -> Double, f: (Double, Double) -> Double) -> Node {
        // Two thirds of the panel, as P03: the ring fills the arch's height and what comes next stands beside it, over the lattice.
        let archW = w * 0.655, archH = h + u(10), archX = u(14), radius = h * 0.41, cy = h * 0.56
        let cardX = w * 0.715, cardW = w - cardX - u(8), cardY = h * 0.13, cardH = h * 0.62
        let pillX = w * 0.68, pillW = w - pillX - u(8)
        let side = h * 0.2
        return Node.group {
            PrayerPage.latticeField(w: w, h: h, corner: u(12))
            PrayerPage.archWindow(w: archW, h: archH, lift: archH * 0.36, spandrel: side).at(archX, h - archH)
            Node.rect(stroke: Noor.inlay, lineWidth: 1, corner: u(12)).size(w, h).opacity(0.6)
            // A box the arch's width, so in Arabic the place moves with the arch while the ring stays as it is.
            dialMarks(ctx, day: day, cx: archW / 2, cy: cy, radius: radius, w: archW, h: h, f: f, u: u).at(archX, 0)
            card(ctx, hold, coming: coming, w: cardW, h: cardH, u: u, f: f).at(cardX, cardY)
            Node.pill("full", label: L("View full prayer times"), x: pillX, y: cardY + cardH + u(14), w: pillW, h: u(50), symbol: "chevron.forward", size: f(16, 12.5))
        }
        .size(w, h)
    }

    /// What comes after: the next start today, or tomorrow's Fajr if the timetable has it, and says so if it doesn't.
    private static func card(_ ctx: Context, _ hold: Hold, coming: (id: PrayerID, at: Date, iqamah: Date?, tomorrow: Bool)?, w: Double, h: Double, u: (Double) -> Double, f: (Double, Double) -> Double) -> Node {
        let s = ctx.snapshot
        let heading: String
        switch hold {
        case .between: heading = L("Next prayer start")
        case .night: heading = L("Tomorrow's Fajr starts")
        }
        let bodyY = u(56), inset = u(24)
        return Node.group {
            Node.panel(w, h, corner: u(16), fill: Noor.surface, line: Noor.edge)
            Node.group {
                Node.image("art/corner-l.png", dark: "art/corner-d.png", fit: "contain").size(h - bodyY, h - bodyY).at(w - h + bodyY, bodyY + 1).opacity(0.9).turnsWithWords()
            }
            .size(w, h).corner(u(16)).clip()
            Node.say(heading, inset, 0, w - inset * 2, bodyY - 2, size: f(18, 13.5), weight: "medium")
            Node.rect(fill: Noor.edge).size(w - inset * 2, 1).at(inset, bodyY)
            if let coming {
                let glyph = f(26, 18)
                let sign = PrayerPage.symbol(coming.id)
                Node.glow(.hex("#8C7AE6"), cx: inset + glyph / 2, cy: bodyY + u(32), r: glyph)
                Node.symbol(coming.tomorrow ? "sunrise.fill" : sign.0, color: coming.tomorrow ? .hex("#F6C04C") : .adaptive(light: "#7A5AB8", dark: "#D6C6F2")).size(glyph, glyph).at(inset, bodyY + u(32) - glyph / 2)
                Node.say(Words.prayer(coming.id), inset, bodyY + u(54), w - inset - u(72), u(34), size: f(23, 15))
                Node.say(ctx.t(coming.at), inset, bodyY + u(86), w - inset - u(72), u(48), size: f(36, 22), tabular: true)
                Node.say(Words.countdown(to: coming.at, from: s.now), inset, bodyY + u(134), w - inset - u(72), u(24), size: f(17, 12.5), color: coming.tomorrow ? Noor.muted : Noor.warm)
                if let iqamah = coming.iqamah, h > bodyY + u(170) {
                    Node.say(L("Iqamah {time}", ["time": ctx.t(iqamah)]), inset, bodyY + u(156), w - inset - u(72), u(22), size: f(15, 11.5), color: Noor.muted)
                }
            } else {
                Node.say(L("Tomorrow's times aren't in this timetable."), inset, bodyY + u(30), w - inset - u(60), u(90), size: f(17, 13), color: Noor.muted, lines: 4)
            }
        }
        .size(w, h)
    }

    /// P03's first strip: the day's five starts, the one being held opened up to its start and iqamah.
    private static func timesStrip(_ ctx: Context, _ held: PrayerID, day: PrayerDay, w: Double, h: Double, u: (Double) -> Double, f: (Double, Double) -> Double, stacked: Bool = false) -> Node {
        let line = sourceLine(ctx)
        let rowX = u(10), rowW = w - rowX * 2, rowY = u(56), rowH = h - rowY - u(8)
        let heldW = rowW * (stacked ? 0.34 : 0.31), otherW = (rowW - heldW) / 4
        var x = 0.0
        let places: [(PrayerID, Double, Double)] = PrayerID.allCases.map { id in
            let width = id == held ? heldW : otherW
            defer { x += width }
            return (id, x, width)
        }
        return Node.group {
            Node.panel(w, h, corner: u(16))
            Node.rect(stroke: Noor.inlay, lineWidth: 1, corner: u(16)).size(w, h).opacity(0.75)
            Node.say(L("Today's prayer times"), u(24), u(4), w * 0.42, u(46), size: f(21, 14), weight: "semibold")
            Node.group {
                Node.symbol("calendar", color: Noor.text).size(f(19, 14), f(19, 14)).at(0, u(6))
                Node.say(line.kind, u(28), 0, w * 0.46 - u(58), u(24), size: f(15, 11.5))
                Node.symbol("info.circle", color: Noor.text).size(f(15, 11.5), f(15, 11.5)).at(min(u(28) + Double(line.kind.count) * f(15, 11.5) * 0.5 + u(8), w * 0.46 - u(22)), u(5))
                if let valid = line.valid { Node.say(valid, u(28), u(22), w * 0.46 - u(58), u(22), size: f(15, 11.5), color: Noor.muted) }
            }
            .size(w * 0.46, u(46)).at(w - u(250), u(6))
            .area("source", label: [line.kind, line.valid].compactMap { $0 }.joined(separator: ", "), hover: .init(scale: 1.0))
            Node.rect(fill: Noor.quiet, stroke: Noor.hairline, lineWidth: 1, corner: u(14)).size(rowW, rowH).at(rowX, rowY)
            for (id, cx, cw) in places {
                column(ctx, id, held: id == held, day: day, w: cw, h: rowH, u: u, f: f).at(rowX + cx, rowY)
            }
        }
        .size(w, h)
    }

    private static func column(_ ctx: Context, _ id: PrayerID, held: Bool, day: PrayerDay, w: Double, h: Double, u: (Double) -> Double, f: (Double, Double) -> Double) -> Node {
        let start = day.starts[id]!, iqamah = day.iqamah[id]
        let dot = f(14, 11)
        let color: Color = switch id {
        case .fajr, .asr: .hex("#3C9BEB")
        case .dhuhr: .hex("#F1D27A")
        case .maghrib: .hex("#E46CB2")
        case .isha: .hex("#7354E0")
        }
        let spoken = L("{prayer}, starts {time}", ["prayer": Words.prayer(id), "time": ctx.t(start)]) + (iqamah.map { ", " + L("iqamah {time}", ["time": ctx.t($0)]) } ?? "")
        return Node.group {
            if held {
                // One plate: the bright part names it, the quiet part under it spells out its two times.
                Node.rect(fill: Noor.quiet, stroke: Noor.pickedEdge, lineWidth: 1, corner: u(12)).size(w, h - u(6)).at(0, u(3))
                Node.rect(stroke: Noor.pickedEdge, lineWidth: 1, corner: u(12)).gradient([.adaptive(light: "#EDE4F7", dark: "#4A347F"), .adaptive(light: "#E2D5F2", dark: "#2F2558")]).size(w, u(90)).at(0, u(3))
            }
            Node.glow(color, cx: w / 2, cy: u(26), r: dot * 1.2)
            Node.ellipse(fill: color, stroke: .hex("#FFFFFF"), lineWidth: 2).size(dot, dot).at(w / 2 - dot / 2, u(26) - dot / 2)
            Node.say(Words.prayer(id), 2, u(40), w - 4, u(26), size: f(16, 12), color: held ? Noor.accent : Noor.text, align: "center")
            Node.say(held ? "\(ctx.t(start)) / \(iqamah.map(ctx.t) ?? "—")" : ctx.t(start), 2, u(62), w - 4, u(28), size: f(18, 12.5), color: held ? Noor.warm : Noor.text, align: "center", tabular: true)
            if held {
                Node.say(L("Starts {time}", ["time": ctx.t(start)]), 4, u(93), w * 0.48 - 4, h - u(96) - u(3), size: f(14, 11), color: Noor.muted, align: "center")
                if let iqamah { Node.say(L("Iqamah {time}", ["time": ctx.t(iqamah)]), w * 0.5, u(93), w * 0.5 - 4, h - u(96) - u(3), size: f(14, 11), color: Noor.muted, align: "center") }
            }
        }
        .size(w, h)
        .area("col-\(id.rawValue)", label: spoken, hover: .init(scale: 1.0))
    }

    /// P03's second strip: the last prayer's start and iqamah, then the night, then tomorrow's Fajr if there is one.
    private static func nightStrip(_ ctx: Context, _ last: PrayerID, day: PrayerDay, coming: (id: PrayerID, at: Date, iqamah: Date?, tomorrow: Bool)?, w: Double, h: Double, u: (Double) -> Double, f: (Double, Double) -> Double) -> Node {
        let line = sourceLine(ctx)
        let y = u(72), x0 = w * 0.07, x1 = w * 0.27, end = w - u(70)
        let start = day.starts[last]!, iqamah = day.iqamah[last]
        let solidTo = iqamah == nil ? x0 : x1
        return Node.group {
            Node.panel(w, h, corner: u(16))
            // The hills end at the line, so every word below it stands on quiet ground.
            PrayerPage.nightArt(w: w, h: h, mosqueAt: 0.8, footY: y + u(4), across: w * 1.34, corner: u(16))
            Node.rect(stroke: Noor.inlay, lineWidth: 1, corner: u(16)).size(w, h).opacity(0.75)
            Node.say(L("Tonight and tomorrow"), u(26), u(2), w * 0.5, u(38), size: f(21, 14), weight: "semibold")
            Node.group {
                Node.glow(.hex("#F1D27A"), cx: end + u(30), cy: u(26), r: u(30), opacity: 0.35)
                Node.symbol("moon.fill", color: .adaptive(light: "#7A5AB8", dark: "#F1E2C0")).size(f(24, 16), f(24, 16)).at(end + u(18), u(14))
            }
            .size(w, h)
            Node.rect().gradient([.hex("#6B4BD8"), .hex("#9E86F2")], from: (0, 0.5), to: (1, 0.5)).size(solidTo - x0, 3).at(x0, y - 1.5)
            if coming != nil {
                Node.path("M \(n(solidTo)) \(n(y)) L \(n(end)) \(n(y))", stroke: .adaptive(light: "#7A5AB8", dark: "#E4DAF8"), lineWidth: 1.6, dash: [1.5, 5]).size(w, h).at(0, 0)
            }
            stop(L("Start"), Words.prayer(last), ctx.t(start), x: x0, y: y, u: u, f: f)
            if let iqamah { stop(L("Iqamah"), Words.prayer(last), ctx.t(iqamah), x: x1, y: y, u: u, f: f) }
            if let coming {
                let glyph = f(32, 20)
                Node.glow(.hex("#F6B45C"), cx: end, cy: y - u(4), r: glyph)
                Node.symbol("sunrise.fill", color: .hex("#F6C04C")).size(glyph, glyph).at(end - glyph / 2, y - glyph / 2 - u(4))
                Node.group {
                    Node.say(L("Tomorrow"), 0, 0, u(190), u(22), size: f(16, 12), weight: "medium", color: Noor.warm, align: "trailing")
                    Node.say(L("{prayer} starts", ["prayer": Words.prayer(coming.id)]), 0, u(20), u(190), u(20), size: f(14.5, 11), align: "trailing")
                    Node.say(ctx.t(coming.at), 0, u(38), u(190), u(24), size: f(16.5, 12), align: "trailing", tabular: true)
                }
                .size(u(190), u(64)).at(w - u(20) - u(190), y + u(12))
            }
            Node.group {
                Node.rect(fill: Noor.quiet, stroke: Noor.edge, lineWidth: 1, corner: u(12)).size(w - u(40), u(36))
                Node.symbol("info.circle", color: Noor.text).size(f(17, 13), f(17, 13)).at(u(18), (u(36) - f(17, 13)) / 2)
                Node.say([line.kind, line.valid].compactMap { $0 }.joined(separator: " · "), u(50), 0, w - u(100), u(36), size: f(15, 11.5), color: Noor.muted)
            }
            .size(w - u(40), u(36)).at(u(20), h - u(44))
            .area("source", label: [line.kind, line.valid].compactMap { $0 }.joined(separator: ", "), hover: .init(scale: 1.0))
        }
        .size(w, h)
    }

    private static func stop(_ kind: String, _ name: String, _ time: String, x: Double, y: Double, u: (Double) -> Double, f: (Double, Double) -> Double) -> Node {
        let dot = f(15, 11)
        let box = u(120)
        return Node.group {
            Node.glow(.hex("#8C7AE6"), cx: box / 2, cy: dot, r: dot * 1.2)
            Node.ellipse(fill: .hex("#7354E0"), stroke: .hex("#FFFFFF"), lineWidth: 2).size(dot, dot).at(box / 2 - dot / 2, dot / 2)
            Node.say(name, 0, dot * 1.7, box, u(22), size: f(15.5, 11.5), align: "center")
            Node.say(kind, 0, dot * 1.7 + u(19), box, u(20), size: f(14, 10.5), color: Noor.muted, align: "center")
            Node.say(time, 0, dot * 1.7 + u(37), box, u(22), size: f(16, 12), align: "center", tabular: true)
        }
        .size(box, u(84)).at(x - box / 2, y - dot)
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
