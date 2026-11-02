import Foundation
import SidefolkExtensionKit

/// First run: no place exists until one is chosen. Two ways there, by hand or with Sidefolk's place if the person agrees; then which timetable; reminders stay off until asked for.
@MainActor
enum SetupPage {
    static func sections(_ ctx: Context) -> [Section] {
        let step = ctx.state.string("setup") ?? (ctx.snapshot.place == nil ? "welcome" : "source")
        switch step {
        case "place": return place(ctx)
        case "source": return source(ctx)
        default: return welcome(ctx)
        }
    }

    private static func welcome(_ ctx: Context) -> [Section] {
        let w = ctx.width, h = 560.0
        let archW = min(w - 32, 640)
        let items: [(String, String, String)] = [
            ("building.columns", L("Prayer"), L("Times for your place, or your mosque's own timetable.")),
            ("calendar", L("Calendar"), L("Hijri and Gregorian dates, with the method always named.")),
            ("safari", L("Qibla"), L("The bearing from your place, clockwise from true north.")),
            ("book", L("Names"), L("The 99 Names, with their supplied English meanings.")),
        ]
        let scene = Scene(width: w, height: h) {
            Node.patternPanel(w, h)
            Node.arch(archW, h - 20, lift: 90).at((w - archW) / 2, 20)
            Node.inlay(w, h)
            let x = (w - archW) / 2
            Node.image("art/rosette-l.png", dark: "art/rosette-d.png").size(84, 84).at(w / 2 - 42, 56).leftToRight()
            Node.say(L("Your day, with Noor"), x + 30, 144, archW - 60, 44, size: 30, weight: "bold", align: "center")
            Node.say(L("Noor brings together prayer times, a calendar, Qibla and the Names, for your own place."), x + 40, 188, archW - 80, 50, size: 15, color: Noor.muted, align: "center", lines: 2)
            for (i, item) in items.enumerated() {
                let y = 248 + Double(i) * 56
                Node.ellipse(fill: Noor.well, stroke: Noor.inlay, lineWidth: 1).size(42, 42).at(x + 50, y)
                Node.symbol(item.0, color: Noor.text).size(20, 20).at(x + 61, y + 11)
                Node.say(item.1, x + 104, y, archW - 170, 22, size: 15, weight: "semibold")
                Node.say(item.2, x + 104, y + 21, archW - 170, 22, size: 13, color: Noor.muted)
            }
            Node.pill("place", label: L("Choose a place"), x: w / 2 - 150, y: h - 80, w: 300, h: 44, symbol: "arrow.forward", filled: true)
            Node.say(L("Reminders start off."), x + 30, h - 32, archW - 60, 20, size: 12, color: Noor.muted, align: "center")
        }
        return [Section(nil, [.scene(PageSceneBlock(scene, acts: ["place": .go(Go(set: ["setup": "place"], push: true))]))], wide: true)]
    }

    private static func place(_ ctx: Context) -> [Section] {
        let query = ctx.state.string("place_q") ?? ""
        let picked = ctx.state.string("place_pick")
        var out: [Section] = [Section(L("Set your place"), PlaceParts.search(ctx, query: query, picked: picked), detail: L("Prayer times, the calendar and Qibla are based on it. It stays until you change it, also when you travel."), wide: true)]
        out.append(Section(L("Enter coordinates instead"), PlaceParts.coordinates(ctx), collapsed: true, wide: true))
        out.append(Section(L("Use Sidefolk's place"), PlaceParts.shared(ctx), wide: true))
        if let picked, let found = ctx.model.placeResults.first(where: { $0.id == picked }) {
            out.append(Section(nil, [.note(L("Chosen: {place} ({zone}), {lat}, {lon}. Saving sends these coordinates to AlAdhan to calculate times and the bearing.", ["place": PlaceParts.title(found), "zone": found.zoneID, "lat": String(format: "%.2f", found.latitude), "lon": String(format: "%.2f", found.longitude)]), tone: .info),
                                    .action(Action(L("Continue"), tool: "choose_place", input: PlaceParts.input(found), style: .primary, symbol: "arrow.forward"))], wide: true))
        }
        return out
    }

    /// Calculated, or a mosque's timetable by hand or from a file. No directory of mosques: nothing here pretends to one.
    private static func source(_ ctx: Context) -> [Section] {
        let method = ctx.state.string("d_method") ?? ""
        var out = [Section(L("Choose your timetable"), [
            .note(L("There is no one right method: pick what your community follows. You can change it at any time."), tone: .info),
        ] + PreferencesPage.methodChoice(ctx, selected: method, list: true) + [
            .action(Action(L("Use calculated times"), tool: "use_calculated", input: ["method": Int(method) ?? -1], style: .primary, symbol: "arrow.forward", detail: method.isEmpty ? L("Choose a method first.") : nil, disabled: method.isEmpty)),
        ], wide: true)]
        out.append(Section(L("Or my mosque's timetable"), SourcePage.addButtons(ctx), detail: L("Enter it by hand or import a CSV file. Noor doesn't search for mosques and never guesses an iqamah."), wide: true))
        return out
    }
}

/// Finding a place, here and in Preferences.
@MainActor
enum PlaceParts {
    static func title(_ place: Place) -> String { [place.label, place.region, place.country].compactMap { $0 }.joined(separator: ", ") }

    static func input(_ place: Place) -> [String: Any] {
        var out: [String: Any] = ["label": place.label, "latitude": place.latitude, "longitude": place.longitude, "zone": place.zoneID]
        if let region = place.region { out["region"] = region }
        if let country = place.country { out["country"] = country }
        return out
    }

    static func search(_ ctx: Context, query: String, picked: String?) -> [Block] {
        var blocks: [Block] = [.field(L("Search for a city or place"), detail: L("Your words go to Sidefolk's place search and nothing else does."), placeholder: L("Search for a city or place"), button: L("Search"), tool: "search_places", key: "query")]
        if let problem = ctx.model.placeProblem { blocks.append(.note(problem, tone: .warn)) }
        if !ctx.model.placeResults.isEmpty {
            blocks.append(.draftChoice(L("Results"), options: ctx.model.placeResults.prefix(10).map { Option($0.id, title($0), detail: $0.zoneID, symbol: "mappin") }, selected: picked ?? "", key: "place_pick", style: .rows))
        }
        return blocks
    }

    static func coordinates(_ ctx: Context) -> [Block] {
        let lat = ctx.state.string("c_lat") ?? "", lon = ctx.state.string("c_lon") ?? "", zone = ctx.state.string("c_zone") ?? "", label = ctx.state.string("c_label") ?? ""
        // "nan" and "inf" read as numbers, and aren't coordinates.
        let number = { (t: String) in Double(t).flatMap { $0.isFinite ? $0 : nil } }
        let ready = number(lat) != nil && number(lon) != nil && IANAZone.zone(zone) != nil && !label.isEmpty
        return [
            .draftField(L("Name"), placeholder: L("Home"), button: L("Clear"), key: "c_label", value: label.isEmpty ? nil : label),
            .draftField(L("Latitude"), placeholder: "35.6762", button: L("Clear"), key: "c_lat", value: lat.isEmpty ? nil : lat),
            .draftField(L("Longitude"), placeholder: "139.6503", button: L("Clear"), key: "c_lon", value: lon.isEmpty ? nil : lon),
            .draftField(L("Time zone"), detail: L("A zone name, like Asia/Tokyo."), placeholder: "Asia/Tokyo", button: L("Clear"), key: "c_zone", value: zone.isEmpty ? nil : zone),
            .action(Action(L("Use these coordinates"), tool: "choose_place", input: ["label": label, "latitude": number(lat) ?? 999, "longitude": number(lon) ?? 999, "zone": zone], symbol: "mappin", detail: ready ? nil : L("Fill in all four, with a real time zone."), disabled: !ready)),
        ]
    }

    /// Sidefolk's own place, off until the person agrees. Agreeing and using it are separate: a place chosen by hand stays until they switch.
    static func shared(_ ctx: Context) -> [Block] {
        guard SharedPlace.shared else {
            return [.note(L("Optional. Sidefolk asks you first, then shares your town and its zone with Noor. Noor sends the coordinates to AlAdhan."), tone: .neutral),
                    .action(Action(L("Share Sidefolk's place"), act: .allow("place"), symbol: "location"))]
        }
        guard let shared = SharedPlace.current else {
            return [.note(L("Sidefolk doesn't know your place yet. Choose one by hand here, or set it in Sidefolk's settings."), tone: .warn),
                    .action(Action(L("Open Sidefolk's place settings"), act: .settings("place"), symbol: "gearshape"))]
        }
        guard shared.timeZone != nil else {
            return [.note(L("Sidefolk knows {place} but not its time zone, so Noor can't use it. Choose a place by hand.", ["place": shared.city]), tone: .warn)]
        }
        let using = ctx.model.prefs.place?.origin == .shared
        return [.note(using ? L("Following Sidefolk's place: {place}. When it moves, Noor moves with it.", ["place": shared.city]) : L("Sidefolk's place is {place}. Your chosen place stays until you switch.", ["place": shared.city]), tone: using ? .good : .info),
                using ? .action(Action(L("Keep {place} as a fixed place", ["place": shared.city]), tool: "follow_shared_place", input: ["on": false], symbol: "pin")) : .action(Action(L("Use {place}", ["place": shared.city]), tool: "follow_shared_place", input: ["on": true], style: .primary, symbol: "location"))]
    }
}
