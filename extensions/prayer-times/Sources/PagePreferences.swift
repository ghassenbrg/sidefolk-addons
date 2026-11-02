import Foundation
import SidefolkExtensionKit

/// Preferences: six plain native sections. Every change is a draft in the page's state until Save; a preview says what it would do, and Cancel leaves everything as it was.
@MainActor
enum PreferencesPage {
    static func sections(_ ctx: Context) -> [Section] {
        let section = ctx.state.string("section") ?? "place"
        let tabs: [(String, String, String)] = [("place", L("Place"), "mappin"), ("sources", L("Sources"), "tray.full"), ("calculation", L("Calculation"), "function"), ("calendar", L("Calendar"), "calendar"), ("reminders", L("Reminders"), "bell"), ("data", L("Data"), "externaldrive")]
        var out: [Section] = [Section(nil, [strip(ctx, tabs, section: section)], wide: true)]
        switch section {
        case "sources": out += sources(ctx)
        case "calculation": out += calculation(ctx)
        case "calendar": out += calendar(ctx)
        case "reminders": out += reminders(ctx)
        case "data": out += data(ctx)
        default: out += place(ctx)
        }
        return out
    }

    /// Its six sections side by side, wrapping onto a second line where the window is narrow.
    private static func strip(_ ctx: Context, _ tabs: [(String, String, String)], section: String) -> Block {
        let w = ctx.width
        let perRow = ctx.narrow ? 3 : 6
        let cell = (w - Double(perRow - 1) * 8) / Double(perRow), h = 40.0
        let rows = Int(ceil(Double(tabs.count) / Double(perRow)))
        var acts: [String: PageAct] = [:]
        for tab in tabs { acts["s\(tab.0)"] = .go(Go(set: ["section": tab.0])) }
        let scene = Scene(width: w, height: Double(rows) * h + Double(rows - 1) * 8) {
            for (i, tab) in tabs.enumerated() {
                let on = tab.0 == section
                Node.group {
                    Node.rect(fill: on ? Noor.chosen : Noor.surface, stroke: on ? Noor.chosen : Noor.hairline, lineWidth: 1, corner: 10).size(cell, h)
                    Node.symbol(tab.2, color: on ? Noor.onChosen : Noor.text).size(16, 16).at(12, 12)
                    Node.say(tab.1, 34, 0, cell - 40, h, size: 13, weight: on ? "semibold" : "medium", color: on ? Noor.onChosen : Noor.text)
                }
                .size(cell, h).at(Double(i % perRow) * (cell + 8), Double(i / perRow) * (h + 8))
                .area("s\(tab.0)", label: tab.1, hover: .init(scale: 1.0), selected: on)
            }
        }
        return .scene(PageSceneBlock(scene, acts: acts))
    }

    // MARK: Place

    private static func place(_ ctx: Context) -> [Section] {
        let current = ctx.model.prefs.place
        let query = ctx.state.string("place_q") ?? ""
        let picked = ctx.state.string("place_pick")
        var out = [Section(L("Your place"), [
            .facts(nil, [(L("Place"), current.map(PlaceParts.title) ?? L("None chosen")), (L("Time zone"), current?.zoneID ?? "—"), (L("How it's set"), current?.origin == .shared ? L("Following Sidefolk's place") : L("Chosen by you. It stays while you travel."))]),
        ], wide: true)]
        out.append(Section(L("Change place"), PlaceParts.search(ctx, query: query, picked: picked), wide: true))
        if let picked, let found = ctx.model.placeResults.first(where: { $0.id == picked }) {
            out.append(Section(L("Preview"), [.note(placePreview(ctx, found), tone: .info),
                                              .action(Action(L("Save place"), tool: "choose_place", input: PlaceParts.input(found), style: .primary, symbol: "checkmark")),
                                              .action(Action(L("Cancel"), act: .go(Go(set: ["place_pick": NSNull()]))))], wide: true))
        }
        out.append(Section(L("Enter coordinates instead"), PlaceParts.coordinates(ctx), collapsed: true, wide: true))
        out.append(Section(L("Sidefolk's place"), PlaceParts.shared(ctx), wide: true))
        return out
    }

    private static func placePreview(_ ctx: Context, _ place: Place) -> String {
        let reminders = ctx.model.planned().count
        let base = L("{place} is at {zone}. Saving sends its coordinates to AlAdhan, and times, the bearing and any reminders move to it.", ["place": place.label, "zone": place.zoneID])
        return reminders > 0 ? base + " " + L(one: "{count} planned reminder is replaced.", other: "{count} planned reminders are replaced.", count: reminders) : base
    }

    // MARK: Sources

    private static func sources(_ ctx: Context) -> [Section] {
        var rows: [Row] = ctx.model.sources.map { source in
            let current = source.id == ctx.model.prefs.sourceID
            var detail = [Words.sourceKind(source), source.zoneID]
            if let coverage = source.coverage { detail.append(L("{from} to {to}", ["from": coverage.lowerBound.iso, "to": coverage.upperBound.iso])) }
            if let fetched = source.lastFetch { detail.append(L("Fetched {when}", ["when": Format.dateTime(fetched, timeZone: source.zone)])) }
            return Row(source.name + (current ? " ✓" : ""), detail: detail.joined(separator: " · "), symbol: source.kind == .manual ? "pencil" : "function",
                       action: current ? nil : Action(L("Preview"), act: .go(Go(set: ["compare": source.id]))))
        }
        if rows.isEmpty { rows = [Row(L("No saved timetables"), symbol: "tray")] }
        var out = [Section(L("Saved timetables"), [.list(nil, rows)], wide: true)]
        if let id = ctx.state.string("compare"), let source = ctx.model.sources.first(where: { $0.id == id }) {
            out.append(Section(L("Source-change preview"), comparison(ctx, to: source), wide: true))
        }
        if ctx.model.prefs.sourceID != nil, let current = ctx.model.source, current.kind == .manual {
            out.append(Section(nil, [.action(Action(L("Remove {name}", ["name": current.name]), tool: "remove_source", input: ["id": current.id], style: .destructive, symbol: "trash", detail: L("Removes its saved times. Noor goes back to calculated times if a method is set.")))], wide: true))
        }
        out.append(Section(L("Add a mosque's timetable"), SourcePage.addButtons(ctx), detail: L("A source you enter is labelled Manual. An imported file is checked before anything is saved."), wide: true))
        out.append(Section(L("Supported feeds"), [.note(L("No validated feed is connected. Noor doesn't follow any mosque automatically, and doesn't use anyone's private API."), tone: .neutral)], wide: true))
        return out
    }

    /// The same date under both, each in its own zone. Reminders you chose stay chosen; a missing iqamah is called out rather than borrowed.
    private static func comparison(_ ctx: Context, to next: TimetableSource) -> [Block] {
        guard let today = ctx.snapshot.localDate, let current = ctx.model.source else { return [] }
        // The proposed source's own day. A calculated one isn't asked for until it is chosen, so it has none yet: better a dash than the current times under its name.
        var nextDay: PrayerDay?
        if case .ok(let table) = ctx.model.store.timetable(sourceID: next.id), case .success(let day) = table.day(on: CivilDate(ctx.snapshot.now, in: next.zone)) { nextDay = day }
        let old = ctx.model.day(today)
        var rows: [(String, String)] = []
        for id in PrayerID.allCases {
            let a = old?.starts[id].map { Words.time($0, zone: current.zone) } ?? "—", b = nextDay?.starts[id].map { Words.time($0, zone: next.zone) } ?? "—"
            rows.append((Words.prayer(id), "\(a) → \(b)"))
        }
        let missing = ctx.model.prefs.reminders.prayers.contains { $0.value.iqamahMinutes != nil } && (nextDay?.iqamah.isEmpty ?? true)
        var out: [Block] = [.facts(L("{old} → {new}", ["old": current.name, "new": next.name]), rows)]
        if next.kind == .calculated { out.append(.note(L("Calculated times come from the provider once you switch, then replace what is planned. Your reminder choices stay."), tone: .info)) }
        if missing { out.append(.note(L("This source has no iqamah times, so your iqamah reminders won't come from it. Your choices are kept."), tone: .warn)) }
        out.append(.action(Action(L("Use {name}", ["name": next.name]), tool: "choose_source", input: ["id": next.id], style: .primary, symbol: "checkmark")))
        out.append(.action(Action(L("Cancel"), act: .go(Go(set: ["compare": NSNull()])))))
        return out
    }

    // MARK: Calculation

    /// Methods as the provider lists them, in its order. None is marked as recommended, on purpose.
    static func methodChoice(_ ctx: Context, selected: String, list: Bool = false) -> [Block] {
        guard !ctx.model.prayerMethods.isEmpty else {
            return [.note(ctx.model.load == .loading ? L("Loading the methods…") : (Words.problem(ctx.model.problem).isEmpty ? L("The list of methods isn't here yet.") : Words.problem(ctx.model.problem)), tone: .neutral),
                    .action(Action(L("Try again"), tool: "refresh", symbol: "arrow.clockwise"))]
        }
        return [.draftChoice(L("Calculation method"), detail: L("From the provider's list, in its order."), options: ctx.model.prayerMethods.filter { $0.id != 99 }.prefix(24).map { Option("\($0.id)", $0.name) }, selected: selected, key: "d_method", style: list ? .rows : nil)]
    }

    private static func calculation(_ ctx: Context) -> [Section] {
        guard ctx.model.source?.kind != .manual else {
            return [Section(nil, [.note(L("A manual timetable has its own times. These settings apply to calculated times, and never edit a mosque's published timetable."), tone: .info)], wide: true)]
        }
        let saved = ctx.model.prefs.convention
        let state = ctx.state
        let method = state.string("d_method") ?? saved.map { "\($0.method)" } ?? ""
        let school = state.string("d_school") ?? saved.map { "\($0.school)" } ?? "0"
        let latitude = state.string("d_lat") ?? saved?.latitudeAdjustment.map { "\($0)" } ?? "auto"
        var tune: [String: Any] = [:]
        var tuneRows: [Block] = []
        for id in PrayerID.allCases {
            let key = "d_tune_\(id.rawValue)"
            let value = state.string(key) ?? "\(saved?.tune[id] ?? 0)"
            tune[id.rawValue] = Int(value) ?? 0
            tuneRows.append(.draftChoice(Words.prayer(id), options: stride(from: -30, through: 30, by: 5).map { Option("\($0)", $0 > 0 ? "+\($0)" : "\($0)") } + (Int(value).map { $0 % 5 != 0 ? [Option(value, value)] : [] } ?? []), selected: value, key: key))
        }
        let changed = method != saved.map({ "\($0.method)" }) || school != saved.map({ "\($0.school)" }) || latitude != (saved?.latitudeAdjustment.map { "\($0)" } ?? "auto")
            || PrayerID.allCases.contains { (tune[$0.rawValue] as? Int ?? 0) != (saved?.tune[$0] ?? 0) }
        let badTune = tune.values.contains { !PrayerConvention.tuneBounds.contains(($0 as? Int) ?? 0) }
        var main: [Block] = methodChoice(ctx, selected: method)
        main.append(.draftChoice(L("Asr method"), detail: L("Only Asr differs."), options: [Option("0", L("Standard (Shafi'i, Maliki, Hanbali)")), Option("1", L("Hanafi"))], selected: school, key: "d_school"))
        main.append(.draftChoice(L("High-latitude method"), options: [Option("auto", L("Provider's default")), Option("1", L("Middle of the night")), Option("2", L("One seventh")), Option("3", L("Angle-based"))], selected: latitude, key: "d_lat"))
        return [
            Section(L("Calculation"), main, wide: true),
            Section(L("Per-prayer minutes"), tuneRows + [.note(L("Added to a calculated start. They don't edit a mosque's timetable."), tone: .neutral)], collapsed: true, wide: true),
            Section(nil, [
                .note(changed ? L("Not saved. Saving recalculates times and replaces planned reminders.") : L("Saved."), tone: changed ? .info : .good),
                .action(Action(L("Save calculation"), tool: "save_calculation", input: ["method": Int(method) ?? -1, "school": Int(school) ?? 0, "latitude": Int(latitude) ?? 0, "tune": tune], style: .primary, symbol: "checkmark", detail: badTune ? L("Minutes must be from −30 to +30.") : nil, disabled: !changed || method.isEmpty || badTune)),
                .action(Action(L("Cancel"), act: .go(Go(set: state.values.keys.filter { $0.hasPrefix("d_") }.reduce(into: [String: Any]()) { $0[$1] = NSNull() })), disabled: !changed)),
            ], wide: true),
        ]
    }

    // MARK: Calendar and display

    private static func calendar(_ ctx: Context) -> [Section] {
        let p = ctx.model.prefs
        let methods = ctx.model.calendarMethods.isEmpty ? [CalendarMethodInfo(method: .uaq, name: "Umm al-Qura", description: "", validity: "")] : ctx.model.calendarMethods
        return [Section(L("Calendar"), [
            .choice(L("Calendar method"), detail: L("Separate from the prayer method. Dates are provided by this method, and local announcements may differ."), options: methods.map { ($0.method.rawValue, $0.name) }, selected: p.calendarMethod.rawValue, tool: "set_calendar_method"),
            .choice(L("Time format"), options: [("system", L("Follow the system")), ("hour24", L("24-hour")), ("hour12", L("12-hour"))], selected: p.timeFormat.rawValue, tool: "set_display", input: ["what": "time"]),
            .toggle(L("Show API-listed occasions"), detail: L("Marks dates the provider lists. Reminders for them are separate."), on: p.showOccasions, tool: "set_display", input: ["what": "occasions"]),
            .toggle(L("Show a Name on Overview"), detail: L("It changes each place-local day, with no meaning in the order."), on: p.showNameOfTheDay, tool: "set_display", input: ["what": "name"]),
        ], wide: true)]
    }

    // MARK: Reminders

    private static func reminders(_ ctx: Context) -> [Section] {
        let saved = ctx.model.prefs.reminders
        let state = ctx.state
        var draft = saved
        // What the page holds overrides what is saved until Save or Cancel.
        draft.master = state.bool("rm_master") ?? saved.master
        draft.route.companion = state.bool("rm_companion") ?? (saved.route.companion || !saved.master)
        draft.route.systemFallback = state.bool("rm_system") ?? saved.route.systemFallback
        var input: [String: Any] = [:]
        var rows: [TableRow] = []
        let hasIqamah = ctx.snapshot.today.map { !$0.iqamah.isEmpty } ?? false
        for id in PrayerID.allCases {
            let was = saved.prayers[id]
            let before = state.string("rm_\(id.rawValue)_before") ?? was?.beforeMinutes.map { "\($0)" } ?? "off"
            let at = state.bool("rm_\(id.rawValue)_at") ?? was?.atStart ?? false
            let iq = state.string("rm_\(id.rawValue)_iq") ?? was?.iqamahMinutes.map { "\($0)" } ?? "off"
            var choice = Reminders.Prayer(beforeMinutes: Int(before), atStart: at, iqamahMinutes: Int(iq))
            if !hasIqamah { choice.iqamahMinutes = was?.iqamahMinutes }
            draft.prayers[id] = choice
            input[id.rawValue] = ["before": Int(before) ?? -1, "at": at, "iqamah": choice.iqamahMinutes ?? -1]
            let minutes = { (n: String) in Option(n, L("{minutes} min", ["minutes": n])) }
            var cells: [TableRow.Cell] = [
                .control(.draftChoice(L("Before start"), options: [Option("off", L("Off")), minutes("5"), minutes("10"), minutes("15"), minutes("30")], selected: before, key: "rm_\(id.rawValue)_before")),
                .control(.draftToggle(L("At start"), on: at, key: "rm_\(id.rawValue)_at")),
            ]
            if hasIqamah {
                cells.append(.control(.draftChoice(L("Iqamah"), options: [Option("off", L("Off")), Option("0", L("At iqamah")), minutes("5"), minutes("10")], selected: iq, key: "rm_\(id.rawValue)_iq")))
            } else {
                // Where the source gives none, the column says so instead of offering a switch that does nothing.
                cells.append(.text("—"))
            }
            rows.append(TableRow(Words.prayer(id), cells: cells))
        }
        draft.nameOfDay.enabled = state.bool("rm_name") ?? saved.nameOfDay.enabled
        let allowed = Occurrences.allowed
        var trial = ctx.model.prefs
        trial.reminders = draft
        let next = ctx.model.planned(trial).first
        let changed = draft != saved
        let zone = ctx.zone
        var previewLine = L("Nothing would come with these settings.")
        if let next { previewLine = L("Next: {what} on {date} at {time} ({zone}). This is a preview: nothing is scheduled by looking.", ["what": PlanWords.title(next, model: ctx.model), "date": Words.date(CivilDate(next.at, in: zone), weekday: true, year: false), "time": Words.time(next.at, zone: zone), "zone": zone.identifier]) }
        var status: [Block] = []
        switch ctx.snapshot.reminderStatus {
        case .off: status.append(.note(L("Reminders are off. All of this is a draft until you save."), tone: .neutral))
        case .on: status.append(.note(L("Reminders are on, with {count} planned.", ["count": Format.integer(Occurrences.pending)]), tone: .good))
        case .paused(let until): status.append(.note(L("Paused until {time}.", ["time": "\(Words.date(CivilDate(until, in: zone), weekday: false, year: false)) \(Words.time(until, zone: zone))"]), tone: .warn))
        }
        if !allowed, draft.master { status.append(.note(L("Sidefolk needs your yes before it sends Noor's reminders. It asks you first; nothing is saved by that."), tone: .info)) }
        if case .paused = ctx.snapshot.reminderStatus { status.append(.action(Action(L("Resume reminders"), tool: "resume_reminders", symbol: "play"))) } else if saved.master {
            status.append(.action(Action(L("Pause until tomorrow"), tool: "pause_reminders", input: ["until": "tomorrow"], symbol: "pause")))
        }
        if saved.master || saved.ramadan.enabled { status.append(.action(Action(L("Turn off all reminders"), tool: "reminders_off", style: .plain, symbol: "bell.slash"))) }
        var delivery: [Block] = [
            .draftToggle(L("Remind me through the companion"), detail: L("Through your Attention settings: Focus and Quiet apply, and there is no adhan audio."), on: draft.route.companion, key: "rm_companion"),
            .draftToggle(L("Also ask macOS to notify me"), detail: L("While you are away from the Mac, and at a normal quit for up to 20 reminders in the next 7 days. Never during Quiet."), on: draft.route.systemFallback, key: "rm_system"),
        ]
        if draft.route.systemFallback, Occurrences.notifications == .denied {
            delivery.append(.note(L("macOS isn't allowing Sidefolk's notifications, so only the companion can remind you."), tone: .warn))
            delivery.append(.action(Action(L("Open notification settings"), act: .settings("notifications"), symbol: "gearshape")))
        }
        delivery.append(.note(L("Sidefolk can't remind you while it is quit or the Mac is asleep, unless macOS was asked to. A reminder up to two minutes late still comes; older ones are skipped."), tone: .neutral))
        delivery.append(.action(Action(L("Attention settings"), act: .settings("attention"), symbol: "bell.badge")))

        let save: Block
        if !allowed && draft.master {
            save = .action(Action(L("Allow Noor's reminders"), act: .allow("schedule"), style: .primary, symbol: "bell"))
        } else {
            save = .action(Action(L("Save reminders"), tool: "save_reminders", input: ["master": draft.master, "companion": draft.route.companion, "system": draft.route.systemFallback, "prayers": input, "name": draft.nameOfDay.enabled], style: .primary, symbol: "checkmark", disabled: !changed))
        }
        let cancelKeys = state.values.keys.filter { $0.hasPrefix("rm_") }.reduce(into: [String: Any]()) { $0[$1] = NSNull() }
        return [
            Section(L("Reminders"), status + [.draftToggle(L("Prayer reminders"), detail: L("Off until you turn this on and save."), on: draft.master, key: "rm_master")], wide: true),
            Section(L("Each prayer"), [.table(first: L("Prayer"), columns: [L("Before start"), L("At start"), L("Iqamah")], rows: rows)] + (hasIqamah ? [] : [.note(L("This source has no iqamah times, so there's nothing to remind you of. Add a mosque's timetable to set those."), tone: .neutral)]), wide: true),
            Section(L("How they reach you"), delivery, wide: true),
            Section(L("Others"), [
                .draftToggle(L("A Name each day"), detail: L("At {time}, with its supplied English meaning.", ["time": "09:00"]), on: draft.nameOfDay.enabled, key: "rm_name"),
                .note(L("Ramadan reminders are set in the Ramadan planner, and occasion reminders in Calendar's listed occasions."), tone: .neutral),
            ], wide: true),
            Section(L("Preview"), [.note(previewLine, tone: .info), .note(changed ? L("Changes not saved.") : L("Saved."), tone: changed ? .warn : .good), save, .action(Action(L("Cancel"), act: .go(Go(set: cancelKeys)), disabled: !changed))], wide: true),
        ]
    }

    // MARK: Data

    private static func data(_ ctx: Context) -> [Section] {
        let exported = (try? ctx.model.store.export(.all)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
        let settings = exported.count <= 2000 ? exported : nil
        var blocks: [Block] = [
            .facts(L("What is kept on this Mac"), [
                (L("Provider"), "AlAdhan (api.aladhan.com)"),
                (L("Last successful fetch"), ctx.model.fetchedAt.map { Format.dateTime($0, timeZone: ctx.zone) } ?? "—"),
                (L("Saved names"), Format.integer(ctx.model.bookmarks.count)),
                (L("Saved timetables"), Format.integer(ctx.model.sources.filter { $0.kind == .manual }.count)),
            ]),
            .note(L("Your choices stay here. AlAdhan receives the coordinates, date and conventions needed for an answer; Sidefolk's place search receives what you type. Noor's internet access isn't limited to these by the sandbox: it can reach any address, the local network too."), tone: .neutral),
            .action(Action(L("Check for new times"), tool: "refresh", symbol: "arrow.clockwise")),
            .action(Action(L("Clear downloaded data"), tool: "clear_data", input: ["scope": "cache"], symbol: "trash", detail: L("Removes saved answers. They come back when next needed."))),
        ]
        if let settings { blocks.append(.action(Action(L("Copy my settings"), act: .copy(settings), symbol: "doc.on.doc"))) }
        let confirm = ctx.state.bool("confirm_clear") ?? false
        if confirm {
            blocks.append(.note(L("This removes your place, timetables, saved names and settings from Noor, and cancels its reminders. Sidefolk's own place isn't touched."), tone: .bad))
            blocks.append(.action(Action(L("Delete Noor's data"), tool: "clear_data", input: ["scope": "all"], style: .destructive, symbol: "trash")))
            blocks.append(.action(Action(L("Cancel"), act: .go(Go(set: ["confirm_clear": NSNull()])))))
        } else {
            blocks.append(.action(Action(L("Delete Noor's data…"), act: .go(Go(set: ["confirm_clear": true])), style: .plain, symbol: "trash")))
        }
        if ctx.model.unreadable != nil { blocks.insert(.note(L("A saved file couldn't be read, so Noor is using its defaults and has left the file in place."), tone: .warn), at: 0) }
        return [Section(L("Data and privacy"), blocks, wide: true)]
    }
}
