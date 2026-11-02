import Foundation
import SidefolkExtensionKit

/// Overview: the dial, today's two dates, the bearing, the night's times, a Name and the way to Ramadan, each opening its own place.
@MainActor
enum OverviewPage {
    static func sections(_ ctx: Context) -> [Section] {
        if ctx.snapshot.validity == .noPlace || ctx.snapshot.validity == .noSource || ctx.snapshot.validity == .expired || ctx.snapshot.validity == .error || ctx.snapshot.validity == .loading,
           let status = NoorPage.unavailable(ctx) {
            return [status]
        }
        var out: [Section] = []
        if let note = NoorPage.offlineNote(ctx) { out.append(Section(nil, [note], wide: true)) }
        out.append(Section(nil, [ctx.narrow ? narrow(ctx) : wide(ctx)], wide: true))
        return out
    }

    private static let acts: [String: PageAct] = [
        "dial": .go(Go(set: ["tab": "prayer"])),
        "calendar": .go(Go(set: ["tab": "calendar"])),
        "qibla": .go(Go(set: ["tab": "qibla"])),
        "names": .go(Go(set: ["tab": "names"])),
        "ramadan": .go(Go(set: ["sheet": "ramadan"], push: true)),
        "reminders": .go(Go(set: ["sheet": "prefs", "section": "reminders"], push: true)),
    ]

    private static func wide(_ ctx: Context) -> Block {
        let w = ctx.width
        let gap = 16.0
        let leftW = (w - gap) * 0.54, rightW = w - gap - leftW
        let dialH = 500.0, todayH = 234.0
        let nightY = dialH + gap, nightH = 112.0
        let rowY = nightY + nightH + gap, rowH = 116.0
        let name = ctx.snapshot.name
        let scene = Scene(width: w, height: rowY + rowH) {
            dialPanel(ctx, w: leftW, h: dialH)
            today(ctx, w: rightW, h: todayH).at(leftW + gap, 0)
            qibla(ctx, w: rightW, h: dialH - todayH - gap).at(leftW + gap, todayH + gap)
            night(ctx, w: w, h: nightH).at(0, nightY)
            nameCard(ctx, name, w: (w - gap) * 0.70, h: rowH).at(0, rowY)
            ramadanCard(ctx, w: (w - gap) * 0.30, h: rowH).at((w - gap) * 0.70 + gap, rowY)
        }
        return .scene(PageSceneBlock(scene, actions: nameActions(name, ctx), acts: acts))
    }

    private static func narrow(_ ctx: Context) -> Block {
        let w = ctx.width
        let gap = 14.0
        let dialH = min(w * 1.1, 470)
        let name = ctx.snapshot.name
        let heights = [dialH, 214, 214, 112, 128, 104]
        var y = 0.0
        var at: [Double] = []
        for h in heights { at.append(y); y += h + gap }
        let scene = Scene(width: w, height: y - gap) {
            dialPanel(ctx, w: w, h: dialH)
            today(ctx, w: w, h: heights[1]).at(0, at[1])
            qibla(ctx, w: w, h: heights[2]).at(0, at[2])
            night(ctx, w: w, h: heights[3]).at(0, at[3])
            nameCard(ctx, name, w: w, h: heights[4]).at(0, at[4])
            ramadanCard(ctx, w: w, h: heights[5]).at(0, at[5])
        }
        return .scene(PageSceneBlock(scene, actions: nameActions(name, ctx), acts: acts))
    }

    private static func nameActions(_ name: NameEntry?, _ ctx: Context) -> [String: (tool: String, input: [String: Any])] {
        guard let name else { return [:] }
        return ["save": ("save_name", ["number": name.number, "saved": !ctx.model.bookmarks.contains(name.number)])]
    }

    static func dialPanel(_ ctx: Context, w: Double, h: Double) -> Node {
        let s = ctx.snapshot
        let focus = DialScene.focus(s)
        let archInset = 26.0
        let archW = w - archInset * 2
        let focusAt: Date? = {
            switch s.next {
            case .prayerStart(_, let at, _), .iqamah(_, let at, _): at
            default: nil
            }
        }()
        // Room above for the highest label under the arch's head, and below for the button.
        let radius = min(archW / 2 - 66, (h - 190) / 2)
        let cx = w / 2, cy = radius + 122
        return Node.group {
            Node.patternPanel(w, h)
            Node.arch(archW, h - 22, lift: 56).at(archInset, 22)
            Node.inlay(w, h)
            Node.group {
                if let day = s.today {
                    Node.ellipse(fill: Noor.surface).size((radius - radius * 0.13) * 2, (radius - radius * 0.13) * 2).at(cx - radius * 0.87, cy - radius * 0.87)
                    Node.group { DialScene.nodes(cx: cx, cy: cy, radius: radius, labelRadius: radius + 44, snapshot: s, day: day, focusAt: focusAt, big: true) }.size(w, h)
                }
                Node.group { DialScene.middle(cx: cx, cy: cy, radius: radius * 0.87, focus: focus) }.size(w, h)
            }
            .size(w, h).leftToRight().label(DialScene.spoken(s, focus: focus))
            Node.pill("dial", label: L("View today's prayer times"), x: w / 2 - 130, y: h - 52, w: 260)
        }
        .size(w, h)
    }

    static func today(_ ctx: Context, w: Double, h: Double) -> Node {
        let s = ctx.snapshot
        let paired = s.calendar
        let method = Words.calendarMethodName(s.calendarMethod)
        return Node.group {
            card(w, h)
            Node.say(L("Today"), 20, 14, w * 0.4, 28, size: 21, weight: "bold")
            Node.group {
                Node.rect(fill: Noor.well, corner: 8).size(min(w * 0.46, 200), 26)
                Node.say(L("{method} calendar", ["method": method]), 8, 0, min(w * 0.46, 200) - 16, 26, size: 12, color: Noor.muted, align: "center")
            }
            .size(min(w * 0.46, 200), 26).at(w - min(w * 0.46, 200) - 16, 15)
            Node.group {
                Node.rect(fill: Noor.quiet, stroke: Noor.hairline, lineWidth: 1, corner: 14).size(w - 32, h - 118)
                if let hijri = paired?.hijri, let date = s.localDate {
                    Node.say("\(hijri.day)", 18, 0, 90, h - 118, size: 56, weight: "bold", align: "center", tabular: true)
                    Node.say("\(Words.hijriMonth(hijri)) \(hijri.year)", 112, (h - 118) / 2 - 30, w - 160, 32, size: 21, weight: "semibold", color: Noor.accent)
                    Node.say(Words.date(date), 112, (h - 118) / 2 + 4, w - 160, 24, size: 14, color: Noor.muted)
                } else {
                    Node.say(s.localDate.map { Words.date($0) } ?? "", 18, 0, w - 68, h - 118, size: 16, color: Noor.muted)
                }
            }
            .size(w - 32, h - 118).at(16, 50)
            Node.symbol("calendar", color: Noor.text).size(20, 20).at(20, h - 50)
            Node.say(nextOccasion(ctx) ?? L("Paired dates follow the calendar method"), 50, h - 58, w - 210, 40, size: 12.5, color: Noor.muted, lines: 2)
            Node.pill("calendar", label: L("Open calendar"), x: w - 152, y: h - 56, w: 136, h: 36, symbol: "chevron.forward")
        }
        .size(w, h)
    }

    /// The next listed occasion, with its method: calculated, and local observance may differ.
    private static func nextOccasion(_ ctx: Context) -> String? {
        guard let today = ctx.snapshot.localDate, ctx.model.prefs.showOccasions else { return nil }
        let coming = ctx.model.occasions.values.flatMap { $0 }.filter { $0.gregorian >= today && $0.method == ctx.model.prefs.calendarMethod }.min { $0.gregorian < $1.gregorian }
        return coming.map { L("{occasion}, {date}. Listed by {method}; local observance may differ.", ["occasion": $0.title, "date": Words.date($0.gregorian, weekday: false, year: false), "method": Words.calendarMethodName($0.method)]) }
    }

    static func qibla(_ ctx: Context, w: Double, h: Double) -> Node {
        let s = ctx.snapshot
        let side = min(h - 56, w * 0.46)
        let textX = side + 44
        return Node.group {
            card(w, h)
            Node.say(L("Qibla"), 20, 12, w * 0.4, 28, size: 21, weight: "bold")
            Node.say(L("From {place}", ["place": s.place?.label ?? ""]), w * 0.4, 14, w * 0.6 - 18, 24, size: 12.5, color: Noor.muted, align: "trailing")
            if let bearing = s.qibla {
                CompassScene.small(bearing.degrees, side: side).at(20, 44)
                Node.say(L("Qibla · {degrees}°", ["degrees": "\(bearing.rounded)"]), textX, h * 0.28, w - textX - 14, 34, size: 23, weight: "semibold", color: Noor.accent)
                Node.say(L("Clockwise from true north"), textX, h * 0.28 + 34, w - textX - 14, 22, size: 13, color: Noor.muted)
                Node.pill("qibla", label: L("Open direction"), x: textX, y: h * 0.28 + 66, w: min(160, w - textX - 14), symbol: "chevron.forward")
            } else {
                Node.say(ctx.model.load == .loading ? L("Finding the bearing…") : L("No saved bearing for this place."), 20, h * 0.4, w - 40, 24, size: 14, color: Noor.muted, align: "center")
            }
        }
        .size(w, h)
    }

    static func night(_ ctx: Context, w: Double, h: Double) -> Node {
        let s = ctx.snapshot
        let solar = s.today?.solar ?? [:]
        let items: [(SolarEvent, String)] = [(.sunset, "sun.horizon.fill"), (.midnight, "moon.fill"), (.lastThird, "moon.stars.fill")]
        let shown = items.filter { solar[$0.0] != nil }
        let span = min(w * 0.56, 560)
        return Node.group {
            Node.rect(fill: Noor.quiet, stroke: Noor.hairline, lineWidth: 1, corner: 16).size(w, h)
            Node.image("art/skyline-light.png", dark: "art/skyline-dark.png", fit: "cover").size(w, h).corner(16).clip().opacity(0.9)
            Node.say(L("Tonight"), 20, 8, 160, 24, size: 16, weight: "semibold")
            Node.group {
                Node.symbol("bell", color: Noor.muted).size(14, 14).at(0, 7)
                Node.say(L("Set a reminder"), 20, 0, 130, 28, size: 12.5, color: Noor.muted)
            }
            .size(150, 28).at(w - 170, 6)
            .area("reminders", label: L("Set a reminder"))
            for (i, item) in shown.enumerated() {
                let x = 36 + span * (shown.count > 1 ? Double(i) / Double(shown.count - 1) : 0) * 0.9
                Node.symbol(item.1, color: .hex(i == 0 ? "#F1B44C" : "#B8A9F0")).size(22, 22).at(x + 34, 34)
                Node.say(Words.solar(item.0), x, 56, 90, 20, size: 12.5, color: Noor.muted, align: "center")
                Node.say(ctx.t(solar[item.0]!), x, 74, 90, 26, size: 16, weight: "semibold", align: "center", tabular: true)
            }
        }
        .size(w, h)
    }

    static func nameCard(_ ctx: Context, _ name: NameEntry?, w: Double, h: Double) -> Node {
        Node.group {
            Node.patternPanel(44, h, corner: 16)
            Node.rect(fill: Noor.surface, stroke: Noor.hairline, lineWidth: 1, corner: 16).size(w - 26, h).at(26, 0)
            Node.say(L("A name to explore"), 48, 10, w * 0.5, 20, size: 13, color: Noor.muted)
            if let name {
                let saved = ctx.model.bookmarks.contains(name.number)
                let narrow = w < 720
                Node.say(name.transliteration, 48, 34, narrow ? w * 0.42 : w * 0.28, 44, size: narrow ? 21 : 27, weight: "semibold")
                Node.say(name.arabic, narrow ? w * 0.44 : w * 0.30 + 40, 26, w * 0.28, 58, size: narrow ? 28 : 34, align: "center").leftToRight()
                if !narrow {
                    Node.say(name.meaning, w * 0.62, 34, w * 0.22, 26, size: 14, lines: 2)
                    Node.say(L("English meaning"), w * 0.62, 62, w * 0.22, 20, size: 11.5, color: Noor.faint)
                } else {
                    Node.say(name.meaning, 48, 84, w * 0.5, 22, size: 13, color: Noor.muted)
                }
                Node.say(L("Name {number} of 99", ["number": Format.integer(name.number)]), w - 118, 18, 106, 20, size: 11.5, color: Noor.muted, align: "center")
                Node.pill("save", label: saved ? L("Saved") : L("Save"), spoken: saved ? L("Remove {name} from saved names", ["name": name.transliteration]) : L("Save {name}", ["name": name.transliteration]), x: w - 112, y: 44, w: 96, h: 34, symbol: saved ? "bookmark.fill" : "bookmark")
                Node.rect(fill: .hex("#00000000"), corner: 12).size(narrow ? w - 130 : w * 0.82, h - 8).at(30, 4).z(-1).area("names", label: L("Open {name} in Names", ["name": name.transliteration]), hover: .init(scale: 1.0))
            } else {
                Node.say(ctx.model.load == .loading ? L("Loading the Names…") : L("The Names aren't here yet. They need one connection."), 48, 40, w - 80, 40, size: 14, color: Noor.muted, lines: 2)
            }
        }
        .size(w, h)
    }

    static func ramadanCard(_ ctx: Context, w: Double, h: Double) -> Node {
        Node.group {
            Node.rect(fill: Noor.surface, stroke: Noor.hairline, lineWidth: 1, corner: 16).size(w, h)
            Node.group {
                Node.rect(fill: .hex("#2A2358"), corner: 12).size(92, h - 16)
                Node.image("art/skyline-dark.png", fit: "cover").size(92, h - 16).corner(12).clip().opacity(0.9)
                Node.symbol("moon.fill", color: .hex("#F4D48E")).size(24, 24).at(34, 16)
            }
            .size(92, h - 16).at(8, 8)
            Node.say(L("Plan Ramadan"), 112, h / 2 - 28, w - 142, 26, size: 16, weight: "semibold")
            Node.say(L("Suhoor, Fajr and iftar times"), 112, h / 2, w - 142, 34, size: 12, color: Noor.muted, lines: 2)
            Node.symbol("chevron.forward", color: Noor.muted).size(12, 12).at(w - 24, h / 2 - 6)
        }
        .size(w, h)
        .area("ramadan", label: L("Plan Ramadan"), hover: .init(scale: 1.01))
    }

    /// A card's ground: the theme-free surface every module stands on.
    static func card(_ w: Double, _ h: Double) -> Node {
        Node.rect(fill: Noor.surface, stroke: Noor.hairline, lineWidth: 1, corner: 16).size(w, h)
    }
}
