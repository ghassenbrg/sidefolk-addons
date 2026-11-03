import Foundation
import SidefolkExtensionKit

/// Preferences' Reminders, the F05 sheet: a pearl sheet in both appearances, the sections on the left over their arch, each prayer's choices, how they reach you, and what a reminder would say. All of it a draft until Save.
@MainActor
enum RemindersSheet {
    /// The sheet is pearl whatever the appearance, so its words are too. The picture's own words are light, on its night sky.
    private enum Pearl {
        static let ink = Color.hex("#15182F"), muted = Color.hex("#4A4668"), faint = Color.hex("#6A6688")
        static let sheet = Color.hex("#F5F1FA"), card = Color.hex("#FBF9FE"), band = Color.hex("#F2EEF8"), lilac = Color.hex("#EBE5F4")
        static let line = Color.hex("#DAD5EA"), edge = Color.hex("#BDB3DA"), purple = Color.hex("#6B4BB4"), link = Color.hex("#3F5BC4")
        static let good = Color.hex("#1E6B45"), warn = Color.hex("#8A5A16"), warnSoft = Color.hex("#FBF1DD")
    }

    /// What the page holds over what is saved, until Save or Cancel.
    private struct Draft {
        struct Line {
            let id: PrayerID
            let before: String
            let at: Bool
            let iqamah: String
        }

        let saved: Reminders
        var draft: Reminders
        var lines: [Line] = []
        var input: [String: Any] = [:]
        let hasIqamah: Bool
        /// Against what the page starts from: with reminders off the companion route is only ticked for them, and looking changes nothing.
        var changed: Bool {
            var start = saved
            start.route.companion = saved.route.companion || !saved.master
            return draft != start
        }
        @MainActor var allowed: Bool { Occurrences.allowed }
    }

    private static func read(_ ctx: Context) -> Draft {
        let saved = ctx.model.prefs.reminders
        let state = ctx.state
        var draft = saved
        draft.master = state.bool("rm_master") ?? saved.master
        draft.route.companion = state.bool("rm_companion") ?? (saved.route.companion || !saved.master)
        draft.route.systemFallback = state.bool("rm_system") ?? saved.route.systemFallback
        draft.nameOfDay.enabled = state.bool("rm_name") ?? saved.nameOfDay.enabled
        var out = Draft(saved: saved, draft: draft, hasIqamah: ctx.snapshot.today.map { !$0.iqamah.isEmpty } ?? false)
        for id in PrayerID.allCases {
            let was = saved.prayers[id]
            let before = state.string("rm_\(id.rawValue)_before") ?? was?.beforeMinutes.map { "\($0)" } ?? "off"
            let at = state.bool("rm_\(id.rawValue)_at") ?? was?.atStart ?? false
            // The switch says whether, and the menu beside it how long before: on brings back what was saved, or the iqamah itself.
            let iqamahKey = "rm_\(id.rawValue)_iq"
            let iqamah = state.string(iqamahKey) ?? state.bool(iqamahKey).map { $0 ? (was?.iqamahMinutes.map { "\($0)" } ?? "0") : "off" } ?? was?.iqamahMinutes.map { "\($0)" } ?? "off"
            var choice = Reminders.Prayer(beforeMinutes: Int(before), atStart: at, iqamahMinutes: Int(iqamah))
            if !out.hasIqamah { choice.iqamahMinutes = was?.iqamahMinutes }
            out.draft.prayers[id] = choice
            out.input[id.rawValue] = ["before": Int(before) ?? -1, "at": at, "iqamah": choice.iqamahMinutes ?? -1]
            out.lines.append(Draft.Line(id: id, before: before, at: at, iqamah: iqamah))
        }
        return out
    }

    /// One reminder to show: what the draft would send next, whether or not the master is on yet; with nothing chosen, what the next prayer's would say, and the sheet says which it is.
    private static func sample(_ ctx: Context, _ d: Draft) -> (occurrence: PlannedOccurrence?, chosen: Bool) {
        var trial = ctx.model.prefs
        trial.reminders = d.draft
        trial.reminders.master = true
        trial.reminders.pausedUntil = nil
        if !trial.reminders.route.companion && !trial.reminders.route.systemFallback { trial.reminders.route.companion = true }
        if let first = ctx.model.planned(trial).first { return (first, true) }
        for id in PrayerID.allCases { trial.reminders.prayers[id] = Reminders.Prayer(atStart: true) }
        return (ctx.model.planned(trial).first, false)
    }

    /// Exactly what Sidefolk would be told next by these settings, master and all.
    private static func previewLine(_ ctx: Context, _ d: Draft) -> String {
        var trial = ctx.model.prefs
        trial.reminders = d.draft
        let zone = ctx.zone
        guard let next = ctx.model.planned(trial).first else { return L("Nothing would come with these settings.") }
        return L("Next: {what} on {date} at {time} ({zone}). This is a preview: nothing is scheduled by looking.", ["what": PlanWords.title(next, model: ctx.model), "date": Words.date(CivilDate(next.at, in: zone), weekday: true, year: false), "time": Words.time(next.at, zone: zone), "zone": zone.identifier])
    }

    private static func status(_ ctx: Context) -> (words: String, color: Color) {
        let zone = ctx.zone
        switch ctx.snapshot.reminderStatus {
        case .off: return (L("Reminders are off. All of this is a draft until you save."), Pearl.muted)
        case .on: return (L("Reminders are on, with {count} planned.", ["count": Format.integer(Occurrences.pending)]), Pearl.good)
        case .paused(let until): return (L("Paused until {time}.", ["time": "\(Words.date(CivilDate(until, in: zone), weekday: false, year: false)) \(Words.time(until, zone: zone))"]), Pearl.warn)
        }
    }

    static func sections(_ ctx: Context) -> [Section] {
        [Section(nil, ctx.width < 780 ? stacked(ctx) : [wide(ctx)], wide: true)]
    }

    // MARK: The two layouts

    /// Places in the board's own numbers (F05): a board's x less 245, its y less 175.
    private static func wide(_ ctx: Context) -> Block {
        let r = ctx.ruler, w = ctx.width
        let d = read(ctx)
        let sheetX = r.u(15), sheetW = w - sheetX * 2, sheetY = r.u(2)
        let bodyY = r.u(65), cardX = r.u(44), cardW = r.u(848)
        let x = r.u(236), width = r.u(641)
        // The choices flow down from the board's places, and only grow where type stops shrinking at a small window.
        var body = Sketch()
        let tight = width < 470
        let hasPills = d.saved.master || d.saved.ramadan.enabled
        heading(&body, ctx, d, x: x, w: width, y: r.u(72), r: r, stack: tight)
        var y = max(r.u(134), r.u(72) + (tight && hasPills ? 94 : 58))
        y += table(&body, ctx, d, x: x, y: y, w: width, r: r, stack: false, menusOnly: tight) + r.u(12)
        y += delivery(&body, d, x: x, y: y, w: width, r: r, stack: false) + r.u(7)
        if deniedRow(d) {
            let h = max(r.u(38), tight ? 46 : 36)
            deniedStrip(&body, x: x, y: y, w: width, h: h, r: r)
            y += h + r.u(8)
        }
        let focusH = focusHeight(w: width, r: r)
        focusRow(&body, x: x, y: y, w: width, h: focusH, r: r)
        y += focusH + r.u(8)
        y += others(&body, ctx, d, x: x, y: y, w: width, r: r) + r.u(12)
        let previewX = r.u(900), previewW = w - previewX - r.u(25)
        var column = Sketch()
        let needed = preview(&column, ctx, d, x: previewX, y: bodyY, w: previewW, h: nil, r: r)
        let bodyBottom = max(y, bodyY + needed), sheetH = bodyBottom + r.u(12) - sheetY

        var s = Sketch()
        sheet(&s, x: sheetX, y: sheetY, w: sheetW, h: sheetH, r: r)
        let subtitleX = r.u(48) + max(r.u(217), 160)
        s.add(Node.say(L("Noor Preferences"), r.u(48), r.u(18), r.u(214), r.u(36), size: r.f(25, min: 17), weight: "semibold", color: Pearl.ink))
        s.add(Node.say(L("Customise reminders, calculations and display to suit your practice."), subtitleX, r.u(22), w - subtitleX - r.u(30), r.u(28), size: r.f(15, min: 11.5), color: Pearl.muted))

        // The left list and the choices are one card; the list keeps its arch at its foot.
        s.add(Node.rect(fill: Pearl.card, stroke: Pearl.line, lineWidth: 1, corner: r.u(14)).size(cardW, bodyBottom - bodyY).at(cardX, bodyY))
        let paneW = r.u(174)
        s.add(Node.group {
            Node.rect(fill: .hex("#E5DCF0")).size(paneW, bodyBottom - bodyY)
            Node.image("art/prefs-pane.jpg", fit: "fill").size(paneW, paneW * 1164 / 500).at(0, bodyBottom - bodyY - paneW * 1164 / 500)
        }
        .size(paneW, bodyBottom - bodyY).at(cardX, bodyY).corner(r.u(14)).clip())
        for (i, tab) in PreferencesPage.tabs.enumerated() {
            sectionRow(&s, tab, x: cardX + r.u(1), y: r.u(89) + Double(i) * r.u(55), w: paneW - r.u(5), h: r.u(49), r: r)
        }
        s.take(body)
        preview(&s, ctx, d, x: previewX, y: bodyY, w: previewW, h: bodyBottom - bodyY, r: r)
        return s.block(w, sheetH + sheetY + r.u(6))
    }

    /// One column in the same materials, the sections as a small grid at its head and the preview on a sheet of its own: a scene has a tallest size, and this would pass it.
    private static func stacked(_ ctx: Context) -> [Block] {
        let w = ctx.width, r = Ruler(width: 1150)
        let d = read(ctx)
        var s = Sketch()
        let sheetX = 8.0, x = 20.0, width = w - x * 2
        var y = 12.0
        var body = Sketch()
        body.add(Node.say(L("Noor Preferences"), x, y, width, 32, size: 22, weight: "semibold", color: Pearl.ink))
        y += 32
        body.add(Node.say(L("Customise reminders, calculations and display to suit your practice."), x, y, width, 36, size: 13, color: Pearl.muted, lines: 2))
        y += 44
        let cell = (width - 8 * 2) / 3
        for (i, tab) in PreferencesPage.tabs.enumerated() {
            sectionRow(&body, tab, x: x + Double(i % 3) * (cell + 8), y: y + Double(i / 3) * 44, w: cell, h: 38, r: r, compact: true)
        }
        y += 96
        heading(&body, ctx, d, x: x, w: width, y: y, r: r, stack: true)
        y += d.saved.master || d.saved.ramadan.enabled ? 106 : 66
        y += table(&body, ctx, d, x: x, y: y, w: width, r: r, stack: true, menusOnly: true) + 14
        y += delivery(&body, d, x: x, y: y, w: width, r: r, stack: true) + 10
        if deniedRow(d) {
            deniedStrip(&body, x: x, y: y, w: width, h: 58, r: r)
            y += 66
        }
        let focusH = focusHeight(w: width, r: r) + 26
        focusRow(&body, x: x, y: y, w: width, h: focusH, r: r)
        y += focusH + 8
        y += others(&body, ctx, d, x: x, y: y, w: width, r: r) + 12
        sheet(&s, x: sheetX, y: 2, w: w - sheetX * 2, h: y, r: r)
        s.take(body)
        var lower = Sketch()
        var column = Sketch()
        let tall = preview(&column, ctx, d, x: x, y: 12, w: width, h: nil, r: r) + 24
        sheet(&lower, x: sheetX, y: 0, w: w - sheetX * 2, h: tall, r: r)
        lower.take(column)
        return [s.block(w, y + 8), lower.block(w, tall + 8)]
    }

    // MARK: Parts

    private static func sheet(_ s: inout Sketch, x: Double, y: Double, w: Double, h: Double, r: Ruler) {
        s.add(Node.group {
            Node.rect(fill: Pearl.sheet).size(w, h)
            Node.image("art/ground-l.jpg", fit: "cover").size(w, h).opacity(0.75)
        }
        .size(w, h).at(x, y).corner(r.u(16)).clip())
        s.add(Node.rect(stroke: Pearl.line, lineWidth: 1, corner: r.u(16)).size(w, h).at(x, y))
    }

    /// What a native switch stands on. The sheet stays pearl in the dark, where the system's own off track is a veil of white and wouldn't show.
    private static func track(_ s: inout Sketch, cx: Double, cy: Double, on: Bool) {
        s.add(Node.capsule(fill: on ? Pearl.purple : .hex("#C4BDDA"), stroke: on ? Pearl.purple : .hex("#AAA2C6"), lineWidth: 0.5).size(38, 22).at(cx - 19, cy - 11))
    }

    private static func sectionRow(_ s: inout Sketch, _ tab: (id: String, word: String, symbol: String), x: Double, y: Double, w: Double, h: Double, r: Ruler, compact: Bool = false) {
        let on = tab.id == "reminders"
        let glyph = compact ? 15 : r.f(22, min: 16), ink = on ? Pearl.card : Pearl.ink
        let inset = compact ? 8 : r.u(16), gap = compact ? 6 : r.u(14)
        s.acts["s\(tab.id)"] = .go(Go(set: ["section": tab.id]))
        s.add(Node.group {
            if on { Node.rect(stroke: .hex("#A58DE6"), lineWidth: 1, corner: r.u(12)).gradient([.hex("#8467C8"), .hex("#6B4BB4")]).size(w, h) }
            if tab.id == "place" {
                Node.pin(x: inset + glyph * 0.1, y: (h - glyph) / 2, w: glyph * 0.8, h: glyph, color: ink, lineWidth: 1.4)
            } else {
                Node.symbol(tab.symbol, color: ink).size(glyph, glyph).at(inset, (h - glyph) / 2)
            }
            Node.say(tab.word, inset + glyph + gap, 0, w - inset * 1.5 - glyph - gap, h, size: compact ? 12.5 : r.f(16, min: 12.5), weight: on ? "semibold" : "regular", color: ink)
        }
        .size(w, h).at(x, y)
        .area("s\(tab.id)", label: on ? L("{tab}, selected", ["tab": tab.word]) : tab.word, hover: .init(scale: 1.0), selected: on))
    }

    /// The title, what it means right now, the pause, and the master switch.
    private static func heading(_ s: inout Sketch, _ ctx: Context, _ d: Draft, x: Double, w: Double, y: Double, r: Ruler, stack: Bool) {
        let switchW = max(r.u(58), 42), switchH = 30.0
        s.add(Node.say(L("Prayer reminders"), x + r.u(2), y, w * 0.7, max(r.u(34), 28), size: r.f(22, min: 18), weight: "semibold", color: Pearl.ink))
        track(&s, cx: x + w - switchW / 2 - r.u(4), cy: y + r.u(4) + switchH / 2, on: d.draft.master)
        s.inlay(x + w - switchW - r.u(4), y + r.u(4), switchW, switchH, .draftToggle(L("Prayer reminders"), on: d.draft.master, key: "rm_master"))
        s.add(Node.say(d.draft.master ? L("Get notified before prayer times, at the start time, and for Iqamah.") : L("Off until you turn this on and save."), x + r.u(2), y + max(r.u(32), 28), stack ? w - 2 : w - r.u(90), stack ? 30 : max(r.u(24), 20), size: r.f(15, min: 12), color: Pearl.muted, lines: stack ? 2 : 1))
        let pillH = max(r.u(28), 24), size = r.f(12.5, min: 11)
        var pillX = stack ? x : x + w - switchW - r.u(16)
        let pillY = stack ? y + 58 : y + r.u(3)
        func add(_ id: String, _ word: String, _ symbol: String, _ width: Double, _ s: inout Sketch) {
            let at = stack ? pillX : pillX - width
            s.add(Node.group {
                Node.capsule(fill: Pearl.card, stroke: Pearl.edge, lineWidth: 1).size(width, pillH)
                Node.symbol(symbol, color: Pearl.ink).size(size, size).at(pillH * 0.4, (pillH - size) / 2)
                Node.say(word, pillH * 0.4 + size + 6, 0, width - pillH * 0.7 - size - 6, pillH, size: size, color: Pearl.ink)
            }
            .size(width, pillH).at(at, pillY).area(id, label: word))
            pillX = stack ? pillX + width + 8 : pillX - width - 8
        }
        if case .paused = ctx.snapshot.reminderStatus {
            s.tools["resume"] = ("resume_reminders", [:])
            add("resume", L("Resume reminders"), "play", max(r.u(150), 124), &s)
        } else if d.saved.master {
            s.tools["pause"] = ("pause_reminders", ["until": "tomorrow"])
            add("pause", L("Pause until tomorrow"), "pause", max(r.u(168), 136), &s)
        }
        if d.saved.master || d.saved.ramadan.enabled {
            s.tools["alloff"] = ("reminders_off", [:])
            add("alloff", L("Turn off all reminders"), "bell.slash", max(r.u(176), 142), &s)
        }
    }

    /// Each prayer: a menu, a switch and a switch, native over the scene's own card. Returns its height.
    @discardableResult
    private static func table(_ s: inout Sketch, _ ctx: Context, _ d: Draft, x: Double, y: Double, w: Double, r: Ruler, stack: Bool, menusOnly: Bool) -> Double {
        let head = stack ? r.u(64) : max(r.u(64), 50), band = max(r.u(38), 26)
        let step = max(d.hasIqamah ? r.u(39.6) : r.u(36), 31)
        let noteLines = menusOnly ? (w < 460 ? 3 : 2) : 1
        let foot = d.hasIqamah ? r.u(6) : max(r.u(26), Double(noteLines) * 14 + 6)
        let h = head + band + step * 5 + foot
        s.add(Node.rect(fill: Pearl.card, stroke: Pearl.line, lineWidth: 1, corner: r.u(12)).size(w, h).at(x, y))
        s.add(Node.say(L("Each prayer"), x + r.u(16), y + r.u(6), r.u(300), 20, size: r.f(15, min: 13), weight: "semibold", color: Pearl.ink))
        let state = status(ctx)
        s.add(Node.say(state.words, x + r.u(16), y + r.u(6) + 19, w * (stack ? 0.56 : 0.54), head - r.u(6) - 21, size: r.f(13, min: 11), color: state.color, lines: stack || w < 470 ? 2 : 1))
        // Which timetable these come from, and the way to change it.
        let chipW = min(r.u(240), w * 0.40), chipH = max(r.u(36), 28)
        let source = ctx.model.source
        s.acts["chip"] = .go(Go(set: ["section": "sources"]))
        let chipWords = [source?.name, Words.sourceKind(source)].compactMap { $0 }.reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }.joined(separator: " · ")
        s.add(Node.group {
            Node.rect(fill: Pearl.band, stroke: Pearl.edge, lineWidth: 1, corner: r.u(10)).size(chipW, chipH)
            Node.icon(source?.kind == .manual ? Node.Glyph.arch : "function", color: Pearl.purple, side: r.f(18, min: 13)).at(r.u(10), (chipH - r.f(18, min: 13)) / 2)
            Node.say(chipWords, r.u(36), 0, chipW - r.u(58), chipH, size: r.f(12.5, min: 11), weight: "medium", color: Pearl.ink)
            Node.symbol("chevron.forward", color: Pearl.ink).size(r.u(7), r.u(12)).at(chipW - r.u(16), (chipH - r.u(12)) / 2)
        }
        .size(chipW, chipH).at(x + w - chipW - r.u(14), y + (head - chipH) / 2)
        .area("chip", label: L("Where the times come from: {source}. Open.", ["source": chipWords]), hover: .init(scale: 1.01)))

        let bandY = y + head
        s.add(Node.rect(fill: Pearl.band).size(w - 2, band).at(x + 1, bandY))
        let firstX = x + r.u(16), beforeX = x + w * 0.2153, beforeW = stack ? w * 0.25 : r.u(128)
        let atX = stack ? x + w * 0.50 : x + r.u(354), iqX = stack ? x + w * 0.70 : x + r.u(500)
        let pill = max(r.u(30), 24)
        let caption = r.f(13.5, min: 11.5)
        s.add(Node.say(L("Prayer"), firstX, bandY, beforeX - firstX, band, size: caption, color: Pearl.muted))
        s.add(Node.say(L("Before start"), beforeX, bandY, beforeW + r.u(40), band, size: caption, color: Pearl.muted))
        s.add(Node.say(L("At start"), atX, bandY, r.u(120), band, size: caption, color: Pearl.muted))
        s.add(Node.say(L("Iqamah"), iqX, bandY, r.u(120), band, size: caption, color: Pearl.muted))
        var rowY = bandY + band
        for (i, line) in d.lines.enumerated() {
            let cy = rowY + step / 2, name = Words.prayer(line.id)
            if i > 0 { s.add(Node.rect(fill: Pearl.line).size(w - r.u(32), 1).at(firstX, rowY)) }
            s.add(Node.say(name, firstX, rowY, beforeX - firstX - 4, step, size: r.f(15, min: 13), weight: "medium", color: Pearl.ink))
            // Before start
            let minutes = { (n: String) in Option(n, L("{minutes} min", ["minutes": n])) }
            var beforeOptions = [Option("off", L("Off")), minutes("5"), minutes("10"), minutes("15"), minutes("30")]
            if !["off", "5", "10", "15", "30"].contains(line.before) { beforeOptions.append(minutes(line.before)) }
            let pillH = min(step - 6, pill)
            s.add(Node.menuPill(line.before == "off" ? L("Off") : L("{minutes} min", ["minutes": line.before]), x: beforeX, y: cy - pillH / 2, w: beforeW, h: pillH, size: r.f(13.5, min: 12), fill: Pearl.card, line: Pearl.edge, ink: Pearl.ink, corner: r.u(8)))
            s.inlay(beforeX, cy - pillH / 2, beforeW, pillH, .draftChoice(L("{prayer}, before start", ["prayer": name]), options: beforeOptions, selected: line.before, key: "rm_\(line.id.rawValue)_before"))
            // At start
            track(&s, cx: atX + r.u(23), cy: cy, on: line.at)
            s.inlay(atX - r.u(2), cy - r.u(15), r.u(50), r.u(30), .draftToggle(L("{prayer}, at start", ["prayer": name]), on: line.at, key: "rm_\(line.id.rawValue)_at"))
            // Iqamah, only where the source has one: where it doesn't, the column says so instead of offering a switch that does nothing.
            if d.hasIqamah {
                var options = [Option("0", L("At iqamah")), minutes("5"), minutes("10")]
                let word = { (v: String) in v == "off" ? L("Off") : v == "0" ? L("At iqamah") : L("{minutes} min", ["minutes": v]) }
                if !["off", "0", "5", "10"].contains(line.iqamah) { options.append(minutes(line.iqamah)) }
                if menusOnly {
                    s.add(Node.menuPill(word(line.iqamah), x: iqX, y: cy - pillH / 2, w: x + w - iqX - 8, h: pillH, size: 12, fill: Pearl.card, line: Pearl.edge, ink: Pearl.ink, corner: 8))
                    s.inlay(iqX, cy - pillH / 2, x + w - iqX - 8, pillH, .draftChoice(L("{prayer}, iqamah", ["prayer": name]), options: [Option("off", L("Off"))] + options, selected: line.iqamah, key: "rm_\(line.id.rawValue)_iq"))
                } else {
                    let on = line.iqamah != "off"
                    track(&s, cx: iqX + r.u(23), cy: cy, on: on)
                    s.inlay(iqX - r.u(2), cy - r.u(15), r.u(50), r.u(30), .draftToggle(L("{prayer}, iqamah", ["prayer": name]), on: on, key: "rm_\(line.id.rawValue)_iq"))
                    if on {
                        let menuX = iqX + r.u(52), menuW = x + w - menuX - r.u(6)
                        s.add(Node.menuPill(word(line.iqamah), x: menuX, y: cy - pillH / 2, w: menuW, h: pillH, size: r.f(11.5, min: 10.5), fill: Pearl.card, line: Pearl.edge, ink: Pearl.ink, corner: r.u(8)))
                        s.inlay(menuX, cy - pillH / 2, menuW, pillH, .draftChoice(L("{prayer}, iqamah", ["prayer": name]), options: options, selected: line.iqamah, key: "rm_\(line.id.rawValue)_iq"))
                    }
                }
            } else {
                s.add(Node.say("—", iqX, rowY, r.u(50), step, size: r.f(15), color: Pearl.faint, align: "center").label(L("Not provided")))
            }
            rowY += step
        }
        if !d.hasIqamah {
            s.add(Node.rect(fill: Pearl.line).size(w - r.u(32), 1).at(firstX, rowY))
            s.add(Node.say(L("This source has no iqamah times, so there's nothing to remind you of. Add a mosque's timetable to set those."), firstX, rowY + 1, w - r.u(32), foot - 1, size: r.f(12, min: 10.5), color: Pearl.muted, lines: noteLines))
        }
        return h
    }

    /// The two routes. Each is on or off by itself, so each is a box to tick, not one of a pair. Returns its height.
    @discardableResult
    private static func delivery(_ s: inout Sketch, _ d: Draft, x: Double, y: Double, w: Double, r: Ruler, stack: Bool) -> Double {
        s.add(Node.say(L("Notification delivery"), x + r.u(2), y, r.u(400), r.u(24), size: r.f(17, min: 14), weight: "semibold", color: Pearl.ink))
        s.add(Node.say(L("How would you like to be notified?"), x + r.u(2), y + r.u(23), r.u(400), r.u(20), size: r.f(14, min: 12), color: Pearl.muted))
        let cardY = y + max(r.u(47), 38), gap = r.u(8)
        let cardW = stack ? w : (w - gap) / 2
        let box = r.f(19, min: 16), glyph = r.f(24, min: 18), textX = r.u(14) + box + r.u(8) + glyph + r.u(10)
        let small = r.f(11.5, min: 10.5)
        let room = cardW - textX - r.u(8)
        let longest = lineCount(L("While you are away from the Mac, and at a normal quit for up to 20 reminders in the next 7 days. Never during Quiet."), width: room, size: small)
        // Its title may need two lines too where the window is small.
        let titleLines = room < 165 ? 2 : 1, titleH = Double(titleLines) * max(r.u(19), 15) + 3
        let cardH = max(r.u(74), r.u(6) + titleH + Double(longest) * small * 1.27 + 6)
        func card(_ id: String, title: String, detail: String, symbol: String, on: Bool, key: String, at: (Double, Double), _ s: inout Sketch) {
            s.acts[id] = .go(Go(set: [key: !on]))
            s.add(Node.group {
                Node.rect(fill: on ? Color.hex("#FDFCFF") : Pearl.card, stroke: on ? Pearl.purple : Pearl.line, lineWidth: on ? 1.5 : 1, corner: r.u(10)).size(cardW, cardH)
                if on {
                    Node.rect(fill: Pearl.purple, corner: 5).size(box, box).at(r.u(14), r.u(13))
                    Node.symbol("checkmark", color: .hex("#FFFFFF")).symbolLook(weight: "bold").size(box * 0.6, box * 0.6).at(r.u(14) + box * 0.2, r.u(13) + box * 0.2)
                } else {
                    Node.rect(fill: .hex("#FFFFFF"), stroke: Pearl.edge, lineWidth: 1.2, corner: 5).size(box, box).at(r.u(14), r.u(13))
                }
                Node.symbol(symbol, color: on ? Pearl.purple : Pearl.muted).size(glyph, glyph).at(r.u(14) + box + r.u(8), r.u(11))
                Node.say(title, textX, r.u(6), room, titleH, size: r.f(14, min: 12), weight: "semibold", color: Pearl.ink, lines: titleLines)
                Node.text(detail, size: small, color: Pearl.muted, align: "leading", valign: "top", lines: longest, minScale: 0.9).size(room, cardH - r.u(6) - titleH).at(textX, r.u(6) + titleH)
            }
            .size(cardW, cardH).at(at.0, at.1)
            .area(id, label: "\(title). \(detail)", hover: .init(scale: 1.0), selected: on))
        }
        card("companion", title: L("Remind me through the companion"), detail: L("Through your Attention settings: Focus and Quiet apply, and there is no adhan audio."), symbol: "bell", on: d.draft.route.companion, key: "rm_companion", at: (x, cardY), &s)
        card("system", title: L("Also ask macOS to notify me"), detail: L("While you are away from the Mac, and at a normal quit for up to 20 reminders in the next 7 days. Never during Quiet."), symbol: "macwindow", on: d.draft.route.systemFallback, key: "rm_system", at: stack ? (x, cardY + cardH + gap) : (x + cardW + gap, cardY), &s)
        return cardY - y + (stack ? cardH * 2 + gap : cardH)
    }

    private static func deniedRow(_ d: Draft) -> Bool { d.draft.route.systemFallback && Occurrences.notifications == .denied }

    /// macOS has said no: what that leaves, and the way to its settings.
    private static func deniedStrip(_ s: inout Sketch, x: Double, y: Double, w: Double, h: Double, r: Ruler) {
        let buttonW = min(r.u(214), w * 0.46)
        s.acts["notifications"] = .settings("notifications")
        s.add(Node.rect(fill: Pearl.warnSoft, stroke: .hex("#D9B878"), lineWidth: 1, corner: r.u(9)).size(w, h).at(x, y))
        s.add(Node.symbol("exclamationmark.triangle", color: Pearl.warn).size(r.f(16, min: 13), r.f(16, min: 13)).at(x + r.u(12), y + (h - r.f(16, min: 13)) / 2))
        s.add(Node.say(L("macOS isn't allowing Sidefolk's notifications, so only the companion can remind you."), x + r.u(36), y, w - buttonW - r.u(52), h, size: r.f(12.5, min: 11), color: Pearl.warn, lines: 2))
        s.add(Node.group {
            Node.capsule(fill: Pearl.card, stroke: Pearl.warn, lineWidth: 1).size(buttonW, h - r.u(10))
            Node.say(L("Open notification settings"), 8, 0, buttonW - 16, h - r.u(10), size: r.f(12.5, min: 11), weight: "medium", color: Pearl.ink, align: "center")
        }
        .size(buttonW, h - r.u(10)).at(x + w - buttonW - r.u(6), y + r.u(5))
        .area("notifications", label: L("Open notification settings")))
    }

    private static var limits: String { L("Sidefolk can't remind you while it is quit or the Mac is asleep, unless macOS was asked to. A reminder up to two minutes late still comes; older ones are skipped.") }

    private static func focusHeight(w: Double, r: Ruler) -> Double {
        let size = r.f(11.5, min: 10.5)
        return max(r.u(58), max(r.u(27), 24) + Double(lineCount(limits, width: w - r.u(72), size: size)) * size * 1.27 + 6)
    }

    /// What the host holds to: Focus, Quiet and what can't be promised. Its way to Attention settings.
    private static func focusRow(_ s: inout Sketch, x: Double, y: Double, w: Double, h: Double, r: Ruler) {
        s.acts["attention"] = .settings("attention")
        let linkW = max(r.u(150), 124), stack = w < 460
        s.add(Node.rect(fill: Pearl.band, stroke: Pearl.line, lineWidth: 1, corner: r.u(11)).size(w, h).at(x, y))
        s.add(Node.symbol("moon.fill", color: Pearl.purple).size(r.f(26, min: 20), r.f(26, min: 20)).at(x + r.u(18), y + (stack ? r.u(12) : (h - r.f(26, min: 20)) / 2)))
        s.add(Node.say(L("Follows Focus and Quiet"), x + r.u(58), y + r.u(4), w - r.u(58) - linkW, max(r.u(22), 20), size: r.f(14.5, min: 13), weight: "semibold", color: Pearl.ink))
        s.add(Node.text(limits, size: r.f(11.5, min: 10.5), color: Pearl.muted, align: "leading", valign: "top", lines: 6, minScale: 0.9).size(w - r.u(72), h - max(r.u(27), 24)).at(x + r.u(58), y + max(r.u(27), 24)))
        s.add(Node.group {
            Node.say(L("Attention settings"), 0, 0, linkW - 16, 22, size: r.f(13, min: 11.5), color: Pearl.link, align: "trailing")
            Node.symbol("arrow.up.right", color: Pearl.link).size(9, 9).at(linkW - 12, 6.5)
        }
        .size(linkW, 22).at(x + w - linkW - r.u(12), stack ? y + h - 26 : y + r.u(3))
        .area("attention", label: L("Attention settings"), hover: .init(scale: 1.0)))
    }

    /// Ramadan and occasions each have their own place with their own choices, so these open them and say how they stand. The Name's switch is real and a draft here.
    @discardableResult
    private static func others(_ s: inout Sketch, _ ctx: Context, _ d: Draft, x: Double, y: Double, w: Double, r: Ruler) -> Double {
        let h = max(r.u(44), 38), gap = r.u(4)
        let picked = d.saved.occasions.selected.count
        let rows: [(id: String, symbol: String, title: String, detail: String, state: String?, sheet: String?)] = [
            ("ramadan", "moon", L("Ramadan reminders"), L("Set in the Ramadan planner."), d.saved.ramadan.enabled ? L("On") : L("Off"), "ramadan"),
            ("occasions", "calendar", L("Calendar occasions"), L("Set in Calendar's listed occasions."), picked > 0 ? L("{count} chosen", ["count": Format.integer(picked)]) : L("Off"), "occasions"),
            ("name", "star", L("Name of the day"), L("At {time}, with its supplied English meaning.", ["time": "09:00"]), nil, nil),
        ]
        for (i, row) in rows.enumerated() {
            let rowY = y + Double(i) * (h + gap)
            let glyph = r.f(21, min: 16)
            var node = Node.group {
                Node.rect(fill: Pearl.card, stroke: Pearl.line, lineWidth: 1, corner: r.u(10)).size(w, h)
                Node.symbol(row.symbol, color: Pearl.ink).size(glyph, glyph).at(r.u(16), (h - glyph) / 2)
                Node.say(row.title, r.u(56), h * 0.07, w - r.u(190), h * 0.48, size: r.f(14, min: 12.5), weight: "medium", color: Pearl.ink)
                Node.say(row.detail, r.u(56), h * 0.5, w - r.u(190), h * 0.42, size: r.f(12, min: 10.5), color: Pearl.muted)
                if let state = row.state {
                    Node.say(state, w - r.u(130), 0, r.u(90), h, size: r.f(13, min: 11.5), color: Pearl.muted, align: "trailing")
                    Node.symbol("chevron.forward", color: Pearl.ink).size(r.u(8), r.u(13)).at(w - r.u(28), (h - r.u(13)) / 2)
                }
            }
            .size(w, h).at(x, rowY)
            if let sheet = row.sheet {
                s.acts[row.id] = .go(Go(set: ["sheet": sheet], push: true))
                node = node.area(row.id, label: "\(row.title): \(row.state ?? ""). \(row.detail)", hover: .init(scale: 1.0))
            }
            s.add(node)
            if row.id == "name" {
                track(&s, cx: x + w - r.u(54), cy: rowY + h / 2, on: d.draft.nameOfDay.enabled)
                s.inlay(x + w - r.u(84), rowY + (h - r.u(30)) / 2, r.u(60), r.u(30), .draftToggle(L("Name of the day"), on: d.draft.nameOfDay.enabled, key: "rm_name"))
            }
        }
        return h * 3 + gap * 2
    }

    /// The right column: a reminder in its arch, what it is, and Save. Returns its height. `h` nil: as tall as it needs, one column.
    @discardableResult
    private static func preview(_ s: inout Sketch, _ ctx: Context, _ d: Draft, x: Double, y: Double, w: Double, h: Double?, r: Ruler) -> Double {
        let inset = r.u(17), artW = w - inset * 2
        let shownArtW = min(artW, 319 * max(r.s, 1)), artH = shownArtW * 1075 / 800, artX = x + (w - shownArtW) / 2
        let tightWords = w < 280, artY = y + max(r.u(79), tightWords ? 82 : 66)
        let sampled = sample(ctx, d)
        let infoY = artY + artH + r.u(15), infoH = max(r.u(92), w < 280 ? 106 : 84)
        let buttonsY = infoY + infoH + r.u(12), buttonH = max(r.u(43), 32)
        let foot = buttonsY + buttonH + r.u(6)
        let line = previewLine(ctx, d)
        let needsYes = !d.allowed && d.draft.master
        let height = h ?? (foot - y + max(r.u(needsYes ? 70 : 28), needsYes ? 62 : 24))
        s.add(Node.rect(fill: Pearl.card, stroke: Pearl.line, lineWidth: 1, corner: r.u(14)).size(w, height).at(x, y))
        s.add(Node.say(L("Preview"), x + inset, y + r.u(12), w - inset * 2, max(r.u(32), 24), size: r.f(22, min: 18), weight: "semibold", color: Pearl.ink))
        s.add(Node.say(L("Sample notification using your current settings."), x + inset, y + max(r.u(43), 36), w - inset * 2, tightWords ? 36 : max(r.u(24), 20), size: r.f(14, min: 12), color: Pearl.muted, lines: tightWords ? 2 : 1))
        s.add(notice(ctx, sampled.occurrence, w: shownArtW, h: artH, r: r).at(artX, artY))

        s.add(Node.rect(fill: Pearl.band, stroke: Pearl.line, lineWidth: 1, corner: r.u(10)).size(artW, infoH).at(x + inset, infoY))
        s.add(Node.symbol("info.circle", color: Pearl.ink).size(r.f(19, min: 15), r.f(19, min: 15)).at(x + inset + r.u(13), infoY + r.u(9)))
        s.add(Node.say(L("This is a preview only."), x + inset + r.u(44), infoY + r.u(5), artW - r.u(52), max(r.u(22), 18), size: r.f(14, min: 12), weight: "semibold", color: Pearl.ink))
        // The picture is the same either way, so the words say what it stands for: what would come first, or only what the next prayer's would say.
        let detail = !sampled.chosen ? line + " " + L("This shows what the next prayer's reminder would say.") : d.draft.master ? line : line + " " + L("Turn reminders on and save, and this would come first.")
        s.add(Node.text(detail, size: r.f(11.5, min: 10.5), color: Pearl.muted, align: "leading", valign: "top", lines: 6, minScale: 0.85).size(artW - r.u(52), infoH - max(r.u(27), 22) - 2).at(x + inset + r.u(44), infoY + max(r.u(27), 22)))

        // The main action is always the next step: asking first where Sidefolk hasn't been told yes yet, and saving after that.
        let cancelW = artW * 0.41, saveW = artW - cancelW - r.u(13)
        let cancelKeys = ctx.state.values.keys.filter { $0.hasPrefix("rm_") }.reduce(into: [String: Any]()) { $0[$1] = NSNull() }
        s.acts["cancel"] = .go(Go(set: cancelKeys))
        s.add(Node.group {
            Node.capsule(fill: Pearl.card, stroke: Pearl.edge, lineWidth: 1.2).size(cancelW, buttonH)
            Node.say(L("Cancel"), 8, 0, cancelW - 16, buttonH, size: r.f(15, min: 13), weight: "medium", color: Pearl.ink, align: "center")
        }
        .size(cancelW, buttonH).at(x + inset, buttonsY).opacity(d.changed ? 1 : 0.5)
        .area("cancel", label: L("Cancel"), disabled: !d.changed))
        let saveWord = needsYes ? L("Allow Noor's reminders") : L("Save reminders")
        if needsYes {
            s.acts["save"] = .allow("schedule")
        } else {
            s.tools["save"] = ("save_reminders", ["master": d.draft.master, "companion": d.draft.route.companion, "system": d.draft.route.systemFallback, "prayers": d.input, "name": d.draft.nameOfDay.enabled])
        }
        let disabled = !needsYes && !d.changed
        s.add(Node.group {
            Node.capsule(stroke: .hex("#A58DE6"), lineWidth: 1).gradient([.hex("#7D5CCC"), .hex("#5B3FA6")]).size(saveW, buttonH)
            Node.say(saveWord, 8, 0, saveW - 16, buttonH, size: r.f(15, min: 13), weight: "medium", color: .hex("#FFFFFF"), align: "center")
        }
        .size(saveW, buttonH).at(x + inset + cancelW + r.u(13), buttonsY).opacity(disabled ? 0.5 : 1)
        .area("save", label: saveWord, disabled: disabled))
        s.add(Node.say(d.changed ? L("Changes not saved.") : L("Saved."), x + inset, foot, artW, max(r.u(20), 16), size: r.f(13, min: 11.5), color: d.changed ? Pearl.warn : Pearl.good, align: "center"))
        if needsYes {
            s.add(Node.text(L("Sidefolk needs your yes before it sends Noor's reminders. It asks you first; nothing is saved by that."), size: r.f(11.5, min: 10.5), color: Pearl.muted, align: "center", valign: "top", lines: 3, minScale: 0.9).size(artW, max(r.u(42), 44)).at(x + inset, foot + max(r.u(20), 17)))
        }
        return height
    }

    /// A reminder as it would read, on its picture: its words come from `PlanWords`, the same ones Sidefolk would be given.
    private static func notice(_ ctx: Context, _ occurrence: PlannedOccurrence?, w: Double, h: Double, r: Ruler) -> Node {
        let k = w / r.u(319)
        let light = Color.hex("#F5F0ED"), rose = Color.hex("#E79AE0"), gold = Color.hex("#EFCF8E")
        let title = occurrence.map { PlanWords.title($0, model: ctx.model) } ?? L("No time available")
        let name = occurrence?.prayer.map(Words.prayer) ?? ""
        let times = occurrence.map { PlanWords.times($0, model: ctx.model) }
        let titleSize = r.f(30, min: 20) * k
        return Node.group {
            Node.image("art/preview.jpg", fit: "fill").size(w, h)
            Node.symbol("bell", color: gold).size(r.f(36, min: 26) * k, r.f(40, min: 28) * k).at(w / 2 - r.f(36, min: 26) * k / 2, r.u(60) * k)
            // The prayer's name in its colour, wherever its language puts it in the sentence.
            if !name.isEmpty, let found = title.range(of: name) {
                Node.runs([(String(title[..<found.lowerBound]), light, "medium"), (name, rose, "medium"), (String(title[found.upperBound...]), light, "medium")], size: titleSize, weight: "medium", color: light, align: "center").size(w - r.u(40) * k, r.u(44) * k).at(r.u(20) * k, r.u(130) * k)
            } else {
                Node.say(title, r.u(20) * k, r.u(130) * k, w - r.u(40) * k, r.u(44) * k, size: titleSize, weight: "medium", color: rose, align: "center")
            }
            Node.rect(fill: Color.hex("#F5F0ED55")).size(w * 0.72, 1).at(w * 0.14, r.u(182) * k)
            if let times, times.start != nil {
                row("clock", L("Starts"), times.start ?? "", y: r.u(204) * k, w: w, r: r, k: k, light: light)
                if let iqamah = times.iqamah { row(Node.Glyph.arch, L("Iqamah"), iqamah, y: r.u(241) * k, w: w, r: r, k: k, light: light) }
            } else if let occurrence, let body = PlanWords.body(occurrence, model: ctx.model) {
                Node.text(body, size: r.f(14, min: 12) * k, color: light, align: "center", valign: "top", lines: 4).size(w - r.u(70) * k, r.u(90) * k).at(r.u(35) * k, r.u(196) * k)
            }
        }
        .size(w, h).corner(r.u(14)).clip().label(L("A preview of a reminder: {what}", ["what": title]))
    }

    private static func row(_ symbol: String, _ word: String, _ time: String, y: Double, w: Double, r: Ruler, k: Double, light: Color) -> Node {
        let glyph = r.f(22, min: 16) * k, h = r.u(32) * k
        return Node.group {
            Node.icon(symbol, color: light, side: glyph).at(r.u(49) * k, (h - glyph) / 2)
            Node.say(word, r.u(86) * k, 0, r.u(120) * k, h, size: r.f(16, min: 13) * k, color: light)
            Node.say(time, w - r.u(180) * k, 0, r.u(130) * k, h, size: r.f(19, min: 14) * k, color: light, align: "trailing", tabular: true)
        }
        .size(w, h).at(0, y)
    }
}
