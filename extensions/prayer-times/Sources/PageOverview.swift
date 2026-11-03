import Foundation
import SidefolkExtensionKit

/// Overview, the boards' one composition: the dial in its arch, today's two dates and the bearing beside it, the night's times along the skyline, a Name and the way to Ramadan. Each opens its own place.
@MainActor
enum OverviewPage {
    static func sections(_ ctx: Context) -> [Section] {
        if ctx.snapshot.validity == .noPlace || ctx.snapshot.validity == .noSource || ctx.snapshot.validity == .expired || ctx.snapshot.validity == .notStarted || ctx.snapshot.validity == .error || ctx.snapshot.validity == .loading,
           let status = NoorPage.unavailable(ctx) {
            return [status]
        }
        if let saved = NoorPage.savedTimes(ctx) { return [saved] }
        var out: [Section] = []
        if let note = NoorPage.offlineNote(ctx) { out.append(Section(nil, [note], wide: true)) }
        out.append(Section(nil, [ctx.narrow ? narrow(ctx) : wide(ctx)], wide: true))
        return out
    }

    private static func acts(_ ctx: Context) -> [String: PageAct] {
        // Open calendar says what it does: this month. The line beside it is next month's, and opens that.
        var next: [String: Any] = ["tab": "calendar", "month": NSNull(), "sel": NSNull()]
        if let coming = nextMonth(ctx) {
            next["month"] = "h:\(coming.year):\(coming.month)"
            if let first = coming.first { next["sel"] = first.gregorian.iso }
        }
        return [
            "dial": .go(Go(set: ["tab": "prayer"])),
            "calendar": .go(Go(set: ["tab": "calendar", "month": NSNull(), "sel": NSNull()])),
            "next-month": .go(Go(set: next)),
            "qibla": .go(Go(set: ["tab": "qibla"])),
            "names": .go(Go(set: ["tab": "names"])),
            "ramadan": .go(Go(set: ["sheet": "ramadan"], push: true)),
            "reminders": .go(Go(set: ["sheet": "prefs", "section": "reminders"], push: true)),
        ]
    }

    /// Places in the board's own numbers (P01 and R01), from the top left of the page below the tabs.
    private static func wide(_ ctx: Context) -> Block {
        let r = ctx.ruler, w = ctx.width
        let margin = r.u(28), full = w - margin * 2
        let leftW = full * 0.505, gap = r.u(22), rightX = margin + leftW + gap, rightW = w - margin - rightX
        let frameH = r.u(530), todayH = r.u(292), qiblaH = r.u(272)
        let nightY = r.u(517), nightH = r.u(134)
        let rowY = nightY + nightH + r.u(10), rowH = r.u(130)
        let name = ctx.snapshot.name
        let scene = Scene(width: w, height: rowY + rowH + r.u(14)) {
            dialPanel(ctx, w: leftW, h: frameH - r.u(14), r: r, rise: r.u(14)).at(margin, r.u(14))
            today(ctx, w: rightW, h: todayH, r: r).at(rightX, r.u(4))
            night(ctx, w: full + r.u(10), h: nightH, r: r).at(margin - r.u(10), nightY)
            qibla(ctx, w: rightW, h: qiblaH, r: r).at(rightX, r.u(312))
            nameCard(ctx, name, w: full * 0.665, h: rowH, r: r).at(margin - r.u(10), rowY)
            ramadanCard(ctx, w: full * 0.325, h: rowH, r: r).at(margin + full * 0.675, rowY)
        }
        return .scene(PageSceneBlock(scene, actions: nameActions(name, ctx), acts: acts(ctx)))
    }

    private static func narrow(_ ctx: Context) -> Block {
        let w = ctx.width, r = Ruler(width: 760)
        let margin = 16.0, inner = w - margin * 2, gap = 12.0
        let name = ctx.snapshot.name
        let heights = [inner * 0.84 + 30, 196, 196, 120, 88, 104]
        var y = 0.0
        var at: [Double] = []
        for h in heights { at.append(y); y += h + gap }
        let scene = Scene(width: w, height: y) {
            dialPanel(ctx, w: inner, h: heights[0] - r.u(14), r: r, rise: r.u(14)).at(margin, at[0] + r.u(14))
            today(ctx, w: inner, h: heights[1], r: r).at(margin, at[1])
            qibla(ctx, w: inner, h: heights[2], r: r).at(margin, at[2])
            night(ctx, w: inner, h: heights[3], r: r).at(margin, at[3])
            nameCard(ctx, name, w: inner, h: heights[4], r: r).at(margin, at[4])
            ramadanCard(ctx, w: inner, h: heights[5], r: r).at(margin, at[5])
        }
        return .scene(PageSceneBlock(scene, actions: nameActions(name, ctx), acts: acts(ctx)))
    }

    private static func nameActions(_ name: NameEntry?, _ ctx: Context) -> [String: (tool: String, input: [String: Any])] {
        guard let name else { return [:] }
        return ["save": ("save_name", ["number": name.number, "saved": !ctx.model.bookmarks.contains(name.number)])]
    }

    /// The old card's name, until its last page is redrawn.
    static func card(_ w: Double, _ h: Double) -> Node { Node.panel(w, h) }

    static func focusAt(_ s: NoorSnapshot) -> Date? {
        switch s.next {
        case .prayerStart(_, let at, _), .iqamah(_, let at, _): at
        default: nil
        }
    }

    /// The dial in its arch, its middle the same moment Today and Ask say. The window is drawn to the shape P02's is, wide in the shoulder: the dial's marks stand where their instants fall, so a name can come anywhere round the ring and must find quiet ground there. Its crown rises over the panel's top by `rise`.
    static func dialPanel(_ ctx: Context, w: Double, h: Double, r: Ruler, rise: Double = 0) -> Node {
        let s = ctx.snapshot
        let focus = DialScene.focus(s)
        let pillH = r.u(46), pillY = h - r.u(68)
        let size = r.f(15.5, min: 12.5), labelGap = r.f(15, min: 12) * 2.2, lift = max(h * 0.36, r.u(150))
        // A name over the ring must clear the crown's line where the name is widest, and a gap stays between the ring's foot and the pill.
        let top = lift * 0.16 - rise + 6 + labelGap + size * 1.35
        let radius = min(w * 0.44 - labelGap - size * 2.4, (pillY - r.u(14) - top) * 0.5)
        let cx = w / 2, cy = pillY - r.u(14) - radius
        return Node.group {
            Node.frame(.dial, w, h)
            Node.rect(stroke: Noor.inlay, lineWidth: 1.2, corner: 16).size(w, h)
            PrayerPage.archWindow(w: w * 0.88, h: h + rise - 1, lift: lift, spandrel: h * 0.17).at(w * 0.06, -rise)
            Node.group {
                if let day = s.today {
                    Node.group { DialScene.nodes(cx: cx, cy: cy, radius: radius, labelRadius: radius + labelGap, snapshot: s, day: day, focusAt: focusAt(s), big: true, label: size) }.size(w, h)
                }
                Node.group { DialScene.middle(cx: cx, cy: cy, radius: radius * 0.86, focus: focus) }.size(w, h)
            }
            .size(w, h).leftToRight().label(DialScene.spoken(s, focus: focus))
            Node.pill("dial", label: L("View today's prayer times"), x: w / 2 - r.u(150), y: pillY, w: r.u(300), h: pillH, symbol: "chevron.forward", size: r.f(16.5))
        }
        .size(w, h)
    }

    static func today(_ ctx: Context, w: Double, h: Double, r: Ruler) -> Node {
        let s = ctx.snapshot
        let method = Words.calendarMethodName(s.calendarMethod)
        let inX = r.u(18), inY = r.u(68), inW = w - inX * 2, inH = r.u(136)
        let chipW = min(w * 0.42, r.u(192))
        // The flourish keeps the top of the far corner; the words stop short of it, whichever side a language puts it on.
        let flourish = inH, wordsW = inW - r.u(152) - flourish * 0.52
        return Node.group {
            Node.panel(w, h, corner: r.u(18))
            Node.say(L("Today"), r.u(20), r.u(14), w * 0.4, r.u(38), size: r.f(28, min: 17), weight: "semibold")
            Node.group {
                Node.rect(fill: Noor.well, stroke: Noor.hairline, lineWidth: 1, corner: r.u(9)).size(chipW, r.u(34))
                Node.say(L("{method} calendar", ["method": method]), 6, 0, chipW - 12, r.u(34), size: r.f(14.5), color: Noor.muted, align: "center")
            }
            .size(chipW, r.u(34)).at(w - chipW - r.u(20), r.u(18))
            Node.group {
                Node.rect(fill: Noor.quiet, stroke: Noor.hairline, lineWidth: 1, corner: r.u(16)).size(inW, inH)
                Node.flourish(inW, inH, side: flourish, corner: r.u(16))
                if let hijri = s.calendar?.hijri, let date = s.localDate {
                    Node.say("\(hijri.day)", r.u(14), 0, r.u(124), inH, size: r.f(84, min: 44), weight: "bold", align: "center", tabular: true)
                    Node.say("\(Words.hijriMonth(hijri)) \(hijri.year)", r.u(152), inH * 0.20, wordsW, r.u(46), size: r.f(33, min: 18), weight: "medium", color: Noor.accent)
                    Node.say(Words.date(date), r.u(152), inH * 0.56, inW - r.u(170), r.u(32), size: r.f(21, min: 12.5), color: Noor.muted)
                } else {
                    Node.say(s.localDate.map { Words.date($0) } ?? "", r.u(20), 0, inW - r.u(80), inH, size: r.f(20), color: Noor.muted)
                }
            }
            .size(inW, inH).at(inX, inY)
            Node.symbol("calendar", color: Noor.text).size(r.f(28, min: 18), r.f(28, min: 18)).at(r.u(26), h - r.u(62))
            if let coming = nextMonth(ctx) {
                let name = coming.first.map { Words.hijriMonth($0.hijri) }
                Node.say(name.map { L("Next month · {month}", ["month": $0]) } ?? L("Next month"), r.u(76), h - r.u(76), w - r.u(290), r.u(28), size: r.f(16.5))
                Node.say(name == nil ? L("Not here yet. Opening Calendar asks for it.") : L("Preview using your calendar method"), r.u(76), h - r.u(48), w - r.u(290), r.u(28), size: r.f(14), color: Noor.muted)
            } else {
                Node.say(L("Paired dates follow the calendar method"), r.u(76), h - r.u(76), w - r.u(290), r.u(56), size: r.f(15.5), color: Noor.muted, lines: 2)
            }
            Node.rect(fill: .hex("#00000000"), corner: 10).size(w - r.u(232), r.u(66)).at(r.u(18), h - r.u(82)).area("next-month", label: L("Open next month in the calendar"), hover: .init(scale: 1.0))
            Node.pill("calendar", label: L("Open calendar"), x: w - r.u(202), y: h - r.u(70), w: r.u(182), h: r.u(46), symbol: "chevron.forward", size: r.f(16))
        }
        .size(w, h)
    }

    /// The Hijri month after today's, and its first day if the calendar has come as far as it. The two Gregorian months always loaded nearly always hold it; a month opened in Calendar counts too.
    private static func nextMonth(_ ctx: Context) -> (year: Int, month: Int, first: CalendarDay?)? {
        guard let hijri = ctx.snapshot.calendar?.hijri else { return nil }
        let (year, month) = NoorModel.monthAfter(hijri.year, hijri.month)
        let method = ctx.model.prefs.calendarMethod
        let days = ctx.model.calendar.values.filter { $0.method == method }.flatMap(\.days).filter { $0.hijri.year == year && $0.hijri.month == month }
        return (year, month, days.min { $0.gregorian < $1.gregorian })
    }

    static func qibla(_ ctx: Context, w: Double, h: Double, r: Ruler) -> Node {
        let s = ctx.snapshot
        let side = min(h - r.u(56), w * 0.37), compassX = r.u(34)
        let textX = compassX + side + r.u(28)
        // The lattice runs down the far edge from under where the place is named, and the words stop before it.
        let curve = r.u(52), strip = r.u(30), edgeY = r.u(58), textW = w - curve - strip - textX - r.u(6)
        return Node.group {
            Node.panel(w, h, corner: r.u(18))
            Node.group { Node.latticeEdge(h: h - edgeY, strip: strip, curve: curve, drop: r.u(70)).at(w - curve - strip, edgeY) }.size(w, h).corner(r.u(18)).clip()
            Node.say(L("Qibla"), r.u(20), r.u(14), w * 0.4, r.u(38), size: r.f(28, min: 17), weight: "semibold")
            Node.group {
                Node.pin(size: r.f(20, min: 14)).at(0, (r.u(30) - r.f(20, min: 14)) / 2)
                Node.say(L("From {place}", ["place": s.place?.label ?? ""]), r.u(30), 0, w * 0.32, r.u(30), size: r.f(16.5, min: 12))
            }
            .size(w * 0.38, r.u(30)).at(w * 0.70, r.u(18))
            if let bearing = s.qibla {
                CompassScene.small(bearing.degrees, side: side).at(compassX, (h - side) / 2 + r.u(4))
                // The degree sign goes in with its number, or in Arabic it lands on the number's far side.
                Node.say(L("Qibla · {degrees}°", ["degrees": "\(bearing.rounded)"]).replacingOccurrences(of: "\u{2069}°", with: "°\u{2069}"), textX, h * 0.30, textW, r.u(46), size: r.f(33, min: 18), weight: "medium", color: Noor.warm)
                Node.text(L("Clockwise from true north"), size: r.f(18, min: 12), color: Noor.muted, align: "leading", valign: "top", lines: 2).size(textW, r.u(46)).at(textX, h * 0.30 + r.u(46))
                Node.pill("qibla", label: L("Open direction"), x: textX, y: h * 0.30 + r.u(94), w: min(r.u(196), textW), h: r.u(46), symbol: "chevron.forward", size: r.f(16))
            } else {
                Node.say(ctx.model.load == .loading ? L("Finding the bearing…") : L("No saved bearing for this place."), r.u(20), h * 0.4, w - r.u(40), r.u(30), size: r.f(16), color: Noor.muted, align: "center")
            }
        }
        .size(w, h)
    }

    /// Tonight along the skyline: sunset, midnight and the last third, on one dotted arc.
    static func night(_ ctx: Context, w: Double, h: Double, r: Ruler) -> Node {
        let solar = ctx.snapshot.today?.solar ?? [:]
        let items: [SolarEvent] = [.sunset, .midnight, .lastThird].filter { solar[$0] != nil }
        let first = r.u(140), step = min(r.u(203), (w - r.u(180)) / 3)
        let arcY = r.u(62), lift = r.u(24)
        let last = first + step * Double(max(0, items.count - 1))
        let wordsW = max(r.u(112), 88.0, wordsWidth(L("Set a reminder"), size: r.f(14.5)) + 2)
        // One arc in two colours, as P01's: evening up to midnight, the night after it. In the dark it is one line.
        let topX = first + step, topY = arcY - lift * 0.82
        let dusk = "M \(n(first - r.u(58))) \(n(arcY + lift * 0.9)) C \(n(first + step * 0.1)) \(n(arcY - lift * 0.3)) \(n(topX - step * 0.45)) \(n(topY)) \(n(topX)) \(n(topY))"
        let night = "M \(n(topX)) \(n(topY)) C \(n(topX + step * 0.45)) \(n(topY)) \(n(last - step * 0.1)) \(n(arcY - lift * 0.3)) \(n(last + r.u(20))) \(n(arcY + lift * 0.3))"
        return Node.group {
            Node.panel(w, h, corner: r.u(16))
            // The night's hills along the strip's foot, with the mosque showing under Qibla's panel: P01's picture, with no words of its own.
            Node.image("art/overview-tonight-l.jpg", dark: "art/overview-tonight-d.jpg", fit: "cover").size(w, h).corner(r.u(16)).clip()
            Node.rect(stroke: Noor.hairline, lineWidth: 1, corner: r.u(16)).size(w, h)
            Node.say(L("Tonight"), r.u(22), r.u(10), r.u(200), r.u(32), size: r.f(20, min: 14), weight: "semibold")
            Node.group {
                Node.symbol("bell", color: Noor.text).size(r.f(18, min: 13), r.f(18, min: 13)).at(0, (r.u(30) - r.f(18, min: 13)) / 2)
                // The words never shrink past reading, in a small ruler: the chevron goes after whatever room they took.
                Node.say(L("Set a reminder"), r.u(30), 0, wordsW, r.u(30), size: r.f(14.5))
                Node.symbol("chevron.forward", color: Noor.text).size(r.u(8), r.u(13)).at(r.u(30) + wordsW + 6, r.u(9))
            }
            // Its far end stays where the board has it, short of Qibla's panel, however long the words.
            .size(r.u(46) + wordsW, r.u(30)).at(r.u(648) - r.u(46) - wordsW, r.u(10))
            .area("reminders", label: L("Set a reminder"))
            if items.isEmpty {
                // A mosque's timetable: Prayer says the same, so the strip isn't a blank to wonder about.
                Node.say(L("This timetable lists prayers only, so it has no night times."), r.u(22), r.u(46), min(w - r.u(44), r.u(620)), r.u(52), size: r.f(16, min: 12), color: Noor.muted, lines: 2)
            } else {
                Node.path(dusk, stroke: .adaptive(light: "#E8923A", dark: "#D6C6F2"), lineWidth: 1.5, dash: [1.5, 5]).size(w, h).at(0, 0)
                Node.path(night, stroke: .adaptive(light: "#4F3FA8", dark: "#D6C6F2"), lineWidth: 1.5, dash: [1.5, 5]).size(w, h).at(0, 0)
            }
            for (i, event) in items.enumerated() {
                let x = first + step * Double(i), glyph = r.f(30, min: 18)
                let sun = event == .sunset
                let y = arcY - lift * (i == 1 ? 0.55 : 0.05)
                Node.glow(sun ? .hex("#F6B45C") : .hex("#8C7AE6"), cx: x, cy: y, r: glyph * 0.9)
                // On pearl the moon stands on its own dark disc, as P01's; the night needs none.
                if !sun { Node.ellipse(fill: .adaptive(light: "#4A3C9E", dark: "#00000000")).size(glyph * 0.86, glyph * 0.86).at(x - glyph * 0.43, y - glyph * 0.43) }
                Node.symbol(sun ? "sun.max.fill" : "moon.fill", color: sun ? .adaptive(light: "#F59A1E", dark: "#F6B45C") : .adaptive(light: "#FFFFFF", dark: "#D6C6F2")).size(glyph * (sun ? 0.8 : 0.56), glyph * (sun ? 0.8 : 0.56)).at(x - glyph * (sun ? 0.4 : 0.28), y - glyph * (sun ? 0.4 : 0.28))
                // Quiet ground for the words, over the hills.
                Node.image("art/glow.png", fit: "fill", tint: .adaptive(light: "#EFE9FA", dark: "#0E1234")).size(r.u(176), r.u(70)).at(x - r.u(88), r.u(70)).opacity(0.75)
                Node.say(Words.solar(event), x - r.u(84), r.u(80), r.u(168), r.u(24), size: r.f(14.5), color: sun ? PrayerPage.nightWarm : Noor.text, align: "center")
                Node.say(ctx.t(solar[event]!), x - r.u(84), r.u(100), r.u(168), r.u(26), size: r.f(17, min: 12.5), weight: "medium", color: sun ? PrayerPage.nightWarm : Noor.text, align: "center", tabular: true)
            }
        }
        .size(w, h)
    }

    static func nameCard(_ ctx: Context, _ name: NameEntry?, w: Double, h: Double, r: Ruler) -> Node {
        let tab = r.u(52)
        return Node.group {
            Node.lattice(tab + r.u(40), h, corner: r.u(16))
            Node.rect(fill: Noor.surface, stroke: Noor.inlay, lineWidth: 1, corner: r.u(30)).size(w - tab, h).at(tab, 0)
            Node.rect(stroke: Noor.hairline, lineWidth: 1, corner: r.u(16)).size(w, h)
            Node.say(L("A name to explore"), tab + r.u(28), r.u(12), w * 0.5, r.u(24), size: r.f(16), color: Noor.muted)
            if let name {
                let saved = ctx.model.bookmarks.contains(name.number)
                let textW = w * 0.27
                let saveWords = saved ? L("Saved") : L("Save"), saveSize = r.f(15.5), saveH = r.u(44)
                let saveW = max(r.u(116), wordsWidth(saveWords, size: saveSize) + saveH * 0.84 + saveSize * 1.15 + 12), meaningX = tab + r.u(28) + textW + w * 0.20
                let meaningW = w - meaningX - max(r.u(150), saveW + r.u(30))
                Node.say(name.transliteration, tab + r.u(28), r.u(44), textW, r.u(58), size: r.f(33, min: 19), weight: "medium")
                Node.say(name.arabic, tab + r.u(28) + textW, r.u(34), w * 0.19, r.u(76), size: r.f(40, min: 24), weight: "medium", color: Noor.warm, align: "center").leftToRight()
                Node.say(name.meaning, meaningX, r.u(52), meaningW, r.u(26), size: r.f(18, min: 12.5))
                Node.say(L("English meaning"), meaningX, r.u(78), meaningW, r.u(24), size: r.f(14.5), color: Noor.muted)
                let countWords = L("Name {number} of 99", ["number": Format.integer(name.number)]), countW = max(saveW + r.u(4), wordsWidth(countWords, size: r.f(14)) + 4)
                Node.say(countWords, w - r.u(16) - countW, r.u(32), countW, r.u(22), size: r.f(14), color: Noor.muted, align: "center")
                Node.pill("save", label: saveWords, spoken: saved ? L("Remove {name} from saved names", ["name": name.transliteration]) : L("Save {name}", ["name": name.transliteration]), x: w - r.u(18) - saveW, y: r.u(62), w: saveW, h: saveH, symbol: saved ? "bookmark.fill" : "bookmark", size: saveSize)
                Node.rect(fill: .hex("#00000000"), corner: 12).size(w - r.u(160), h - 8).at(tab, 4).z(-1).area("names", label: L("Open {name} in Names", ["name": name.transliteration]), hover: .init(scale: 1.0))
            } else {
                Node.say(ctx.model.load == .loading ? L("Loading the Names…") : L("The Names aren't here yet. They need one connection."), tab + r.u(28), r.u(46), w - tab - r.u(60), r.u(60), size: r.f(16), color: Noor.muted, lines: 2)
            }
        }
        .size(w, h)
    }

    static func ramadanCard(_ ctx: Context, w: Double, h: Double, r: Ruler) -> Node {
        let art = min(h, r.u(130))
        return Node.group {
            Node.panel(w, h, corner: r.u(16))
            Node.image("art/ramadan-arch-l.jpg", dark: "art/ramadan-arch-d.jpg", fit: "cover").size(art, h).corner(r.u(16)).clip()
            Node.say(L("Plan Ramadan"), art + r.u(18), h / 2 - r.u(36), w - art - r.u(50), r.u(36), size: r.f(25, min: 15), weight: "medium")
            Node.say(L("Suhoor, Fajr and iftar times"), art + r.u(18), h / 2 + r.u(2), w - art - r.u(50), r.u(44), size: r.f(15.5), color: Noor.muted, lines: 2)
            Node.symbol("chevron.forward", color: Noor.text).size(r.u(10), r.u(16)).at(w - r.u(26), h / 2 - r.u(8))
        }
        .size(w, h)
        .area("ramadan", label: L("Plan Ramadan"), hover: .init(scale: 1.01))
    }
}
