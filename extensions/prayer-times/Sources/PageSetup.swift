import Foundation
import SidefolkExtensionKit

/// First run, as F01 has it: no place exists until one is chosen. Welcome and Set your place stand side by side where they fit, one at a time where they don't; the next step is which timetable. Reminders stay off until asked for.
@MainActor
enum SetupPage {
    /// Under this the two arches would stop reading.
    private static let bothFrom = 780.0

    static func sections(_ ctx: Context) -> [Section] {
        let step = ctx.state.string("setup") ?? (ctx.snapshot.place == nil ? "welcome" : "source")
        if step == "source" { return SourcePage.sections(ctx) }
        if ctx.width >= bothFrom { return both(ctx, step: step) }
        return step == "place" ? one(ctx, place: true, step: step) : one(ctx, place: false, step: step)
    }

    /// F01's two arches, with the same units as the board's.
    private static func both(_ ctx: Context, step: String) -> [Section] {
        let r = ctx.ruler, w = ctx.width
        let margin = r.u(23), gap = r.u(20)
        let leftW = (w - margin * 2 - gap) * 0.477, rightW = w - margin * 2 - gap - leftW, rightX = margin + leftW + gap
        let h = placeHeight(ctx, r: r)
        var wiring = SceneWiring()
        let left = welcomePanel(ctx, w: leftW, h: h, r: r, handedOver: step == "place", wiring: &wiring)
        let right = placePanel(ctx, w: rightW, h: h, ox: rightX, oy: 0, r: r, step: step, wiring: &wiring)
        let scene = Scene(width: w, height: h + r.u(16)) {
            left.at(margin, 0)
            right.at(rightX, 0)
        }
        return wrap(ctx, scene, wiring)
    }

    private static func one(_ ctx: Context, place: Bool, step: String) -> [Section] {
        let w = ctx.width, margin = 16.0, inner = w - margin * 2
        // The whole arch scales with the column, so every panel's places hold.
        let r = Ruler(width: inner / (place ? 642 : 586) * 1290)
        let h = place ? placeHeight(ctx, r: r) : r.u(798)
        var wiring = SceneWiring()
        let panel = place ? placePanel(ctx, w: inner, h: h, ox: margin, oy: 0, r: r, step: step, wiring: &wiring) : welcomePanel(ctx, w: inner, h: h, r: r, wiring: &wiring)
        let scene = Scene(width: w, height: h + 12) { panel.at(margin, 0) }
        return wrap(ctx, scene, wiring)
    }

    private static func wrap(_ ctx: Context, _ scene: Scene, _ wiring: SceneWiring) -> [Section] {
        [Section(nil, [.scene(PageSceneBlock(scene, actions: wiring.tools, acts: wiring.acts, inlays: wiring.inlays))], wide: true)]
    }

    // MARK: Welcome

    /// `handedOver`: the two arches stand side by side and Choose a place has been pressed. The button then says where the work went, as what lights up beside it does.
    private static func welcomePanel(_ ctx: Context, w: Double, h: Double, r: Ruler, handedOver: Bool = false, wiring: inout SceneWiring) -> Node {
        let items: [(String, String, String, Double)] = [
            (Node.Glyph.arch, L("Prayer"), L("Times for your place, or your mosque's own timetable."), 400),
            ("calendar", L("Calendar"), L("Hijri and Gregorian dates, with the method always named."), 476),
            ("safari", L("Qibla"), L("The bearing from your place, clockwise from true north."), 550),
            ("book", L("Names"), L("The 99 Names, with their supplied English meanings."), 626),
        ]
        wiring.acts["place"] = .go(Go(set: ["setup": "place"], push: true))
        let cx = w / 2, textW = w - r.u(170)
        // The names' column is as wide as its longest word in this language, and what they mean starts after it.
        let nameSize = r.f(20.5, min: 12.5), nameW = max(r.u(94), (items.map { wordsWidth($0.1, size: nameSize, em: 0.58) }.max() ?? 0) + 2)
        let meaningX = r.u(148) + nameW + r.u(4)
        let stars: [(Double, Double, Double)] = [(143, 126, 7), (109, 160, 5), (188, 97, 4), (166, 156, 4), (443, 125, 7), (408, 96, 4), (483, 168, 5), (419, 174, 4), (70, 236, 4), (517, 212, 4), (228, 66, 4), (360, 64, 3.5), (92, 200, 3), (500, 150, 3)]
        return Node.group {
            Node.archPanel(w, h, r: r, dusk: true)
            Node.sparkles(stars.map { ($0.0 * (w / r.u(586)), $0.1, $0.2) }, w: w, h: h, r: r)
            Node.image("art/rosette-l.png", dark: "art/rosette-d.png").size(r.u(122), r.u(122)).at(cx - r.u(61), r.u(62)).leftToRight()
            Node.say(L("Your day, with Noor"), r.u(40), r.u(192), w - r.u(80), r.u(60), size: r.f(40, min: 22), weight: "semibold", align: "center")
            Node.say(L("Prayer times and more, for the place you choose."), r.u(50), r.u(250), w - r.u(100), r.u(30), size: r.f(18.5, min: 12), color: Noor.muted, align: "center")
            Node.say(L("Noor brings together prayer times, a calendar, Qibla and the Beautiful Names, designed for everyday life."), (w - textW) / 2, r.u(280), textW, r.u(84), size: r.f(18.5, min: 12), color: Noor.muted, align: "center", lines: 3)
            for item in items {
                Node.medallion(item.0, cx: r.u(103), cy: r.u(item.3), d: r.u(54), ink: Noor.text)
                Node.say(item.1, r.u(148), r.u(item.3 - 26), nameW, r.u(52), size: nameSize, weight: "semibold")
                Node.say(item.2, meaningX, r.u(item.3 - 30), w - meaningX - r.u(40), r.u(60), size: r.f(15.5, min: 11), color: Noor.muted, lines: 3)
            }
            Node.ctaPill("place", label: handedOver ? L("Now set your place") : L("Choose a place"), x: cx - r.u(214), y: h - r.u(114), w: r.u(428), h: r.u(54), filled: !handedOver, size: r.f(19.5, min: 13.5))
            Node.group {
                Node.symbol("bell", color: Noor.muted).size(r.f(17, min: 12), r.f(17, min: 12)).at(0, (r.u(28) - r.f(17, min: 12)) / 2)
                Node.say(L("Reminders start off."), r.f(17, min: 12) + r.u(10), 0, r.u(240), r.u(28), size: r.f(15.5, min: 11), color: Noor.muted)
            }
            .size(r.u(270), r.u(28)).at(cx - r.u(84), h - r.u(46))
        }
        .size(w, h)
    }

    // MARK: Set your place

    /// Results that fit the board's arch: three at most, or two and the rest in a menu, so Continue stays in sight.
    private static func rowsShown(_ ctx: Context) -> Int { ctx.model.placeResults.count == 3 ? 3 : 2 }

    private static func placeHeight(_ ctx: Context, r: Ruler) -> Double {
        let shared = ctx.state.string("place_mode") == "shared"
        let more = ctx.model.placeResults.count > 3 ? 54.0 : 0
        let extra = shared ? 0 : Double(rowsShown(ctx) - 2) * 70 + more + (ctx.state.bool("place_adv") == true ? 186 : 0) + (sidefolkKnowsNoPlace ? settingsRoom : 0)
        return r.u(798 + extra)
    }

    /// Shared, and Sidefolk has no place to share: the way to its settings stands in the consent row.
    private static var sidefolkKnowsNoPlace: Bool { SharedPlace.shared && SharedPlace.current == nil }
    private static let settingsRoom = 46.0

    /// The results to draw, the picked one always among them.
    private static func visibleResults(_ ctx: Context, picked: String?) -> [Place] {
        var rows = Array(ctx.model.placeResults.prefix(rowsShown(ctx)))
        if let picked, !rows.contains(where: { $0.id == picked }), let found = ctx.model.placeResults.first(where: { $0.id == picked }), !rows.isEmpty { rows[rows.count - 1] = found }
        return rows
    }

    static func zoneLine(_ zoneID: String, now: Date) -> String {
        guard let zone = TimeZone(identifier: zoneID) else { return zoneID }
        let minutes = zone.secondsFromGMT(for: now) / 60, hours = abs(minutes) / 60, rest = abs(minutes) % 60
        let offset = (minutes < 0 ? "-" : "+") + "\(hours)" + (rest == 0 ? "" : ":" + String(format: "%02d", rest))
        return "\(zoneID) (UTC\(offset))"
    }

    private static func placePanel(_ ctx: Context, w: Double, h: Double, ox: Double, oy: Double, r: Ruler, step: String, wiring: inout SceneWiring) -> Node {
        let picked = ctx.state.string("place_pick")
        let shared = ctx.state.string("place_mode") == "shared"
        let found = picked.flatMap { id in ctx.model.placeResults.first { $0.id == id } }
        let x = r.u(40), inner = w - x * 2
        let segY = r.u(139), segH = r.u(51), half = inner / 2
        wiring.acts["mode-choose"] = .go(Go(set: ["place_mode": NSNull()]))
        wiring.acts["mode-shared"] = .go(Go(set: ["place_mode": "shared"]))
        // Back leaves nothing half chosen. A column of one arch goes back to the welcome.
        let draft = ctx.state.string("setup") != nil || picked != nil
        wiring.acts["back"] = .go(Go(set: ["setup": ctx.model.prefs.place == nil ? "welcome" : NSNull(), "place_pick": NSNull(), "place_mode": NSNull(), "place_adv": NSNull()]))
        if let found {
            wiring.tools["continue"] = ("choose_place", PlaceParts.input(found))
        } else {
            wiring.acts["continue"] = .go(Go(set: ["setup": "source"]))
        }
        let canContinue = found != nil || ctx.model.prefs.place != nil
        let lower = h - r.u(109)
        return Node.group {
            Node.archPanel(w, h, r: r)
            Node.say(L("Set your place"), r.u(60), r.u(52), w - r.u(120), r.u(48), size: r.f(33, min: 19), weight: "semibold", align: "center")
            Node.say(L("Prayer times, calendar and Qibla are based on your place."), r.u(40), r.u(96), w - r.u(80), r.u(28), size: r.f(16.5, min: 11.5), color: Noor.muted, align: "center")
            segment(ctx, shared: shared, x: x, y: segY, half: half, h: segH, r: r)
            if shared {
                sharedCard(ctx, x: x, y: r.u(208), w: inner, h: r.u(466), ox: ox, oy: oy, r: r, wiring: &wiring)
            } else {
                searchPart(ctx, picked: picked, found: found, x: x, w: inner, ox: ox, oy: oy, r: r, bottom: lower, wiring: &wiring)
            }
            Node.ctaPill("back", label: L("Back"), x: x, y: lower + r.u(0), w: r.u(186), h: r.u(47), symbol: nil, leading: "arrow.backward", filled: false, disabled: !draft, size: r.f(17, min: 12.5))
            Node.ctaPill("continue", label: L("Continue"), x: x + r.u(201), y: lower, w: inner - r.u(201), h: r.u(47), disabled: !canContinue, size: r.f(17.5, min: 13))
            Node.say(L("It stays until you change it, also when you travel."), x, h - r.u(52), inner, r.u(24), size: r.f(13.5, min: 11), color: Noor.muted, align: "center")
        }
        .size(w, h)
    }

    private static func segment(_ ctx: Context, shared: Bool, x: Double, y: Double, half: Double, h: Double, r: Ruler) -> [Node] {
        let parts: [(String, String, String, Bool)] = [
            ("mode-choose", Node.Glyph.pin, L("A place I choose"), !shared),
            ("mode-shared", "location", L("Use Sidefolk's place"), shared),
        ]
        let size = r.f(16.5, min: 11.5), glyph = r.f(20, min: 13)
        var out = [Node.well(half * 2, h, corner: r.u(14)).at(x, y)]
        for (i, part) in parts.enumerated() {
            let ink = part.3 ? Color.hex("#FFFFFF") : Noor.text
            out.append(Node.group {
                if part.3 { Node.rect(stroke: NoorLine.chosen, lineWidth: 1, corner: r.u(12)).gradient([.adaptive(light: "#7354B8", dark: "#553DA6"), .adaptive(light: "#6242A8", dark: "#46348C")]).size(half, h).at(0, 0) }
                Node.symbol(part.1, color: ink).size(glyph, glyph).at(r.u(30), (h - glyph) / 2)
                Node.say(part.2, r.u(30) + glyph + r.u(14), 0, half - r.u(30) - glyph - r.u(20), h, size: size, weight: "medium", color: ink)
            }
            .size(half, h).at(x + half * Double(i), y)
            .area(part.0, label: part.2, hover: .init(scale: 1.01), selected: part.3))
        }
        return out
    }

    private static func searchPart(_ ctx: Context, picked: String?, found: Place?, x: Double, w: Double, ox: Double, oy: Double, r: Ruler, bottom: Double, wiring: inout SceneWiring) -> [Node] {
        var out: [Node] = []
        out.append(Node.say(L("Search for a city or place"), x, r.u(205), w, r.u(26), size: r.f(16, min: 11.5)))
        let wellY = r.u(236), wellH = r.u(43), glyph = r.f(19, min: 13)
        // Choose a place has just been pressed: this is where to go, so it lights up.
        let waiting = ctx.state.string("setup") == "place" && ctx.model.placeResults.isEmpty && ctx.model.placeProblem == nil
        out.append(Node.well(w, wellH, corner: r.u(10), line: ctx.state.string("setup") == "place" && ctx.model.placeResults.isEmpty ? NoorLine.chosen : NoorLine.soft).at(x, wellY))
        if waiting { out.append(Node.rect(stroke: NoorLine.chosen, lineWidth: 2.2, corner: r.u(10)).size(w, wellH).at(x, wellY)) }
        out.append(Node.symbol("magnifyingglass", color: Noor.muted).size(glyph, glyph).at(x + r.u(18), wellY + (wellH - glyph) / 2))
        out.append(Node.symbol("return", color: Noor.faint).size(glyph * 0.8, glyph * 0.8).at(x + w - r.u(34), wellY + (wellH - glyph * 0.8) / 2))
        wiring.inlays.append(PageInlay(x: ox + x + r.u(52), y: oy + wellY, w: w - r.u(96), h: wellH,
                                       .field(L("Search for a city or place"), placeholder: L("Search for a city or place"), button: L("Search"), tool: "search_places", key: "query")))
        // The results, or what stands for them: two rows' room either way, so nothing below jumps.
        let results = visibleResults(ctx, picked: picked)
        let rowH = r.u(63), step = r.u(70)
        var y = r.u(291)
        if results.isEmpty {
            let problem = ctx.model.placeProblem
            let boxH = r.u(133)
            out.append(Node.rect(fill: Noor.quiet, stroke: NoorLine.soft, lineWidth: 1, corner: r.u(12), dash: [3, 4]).size(w, boxH).at(x, y))
            out.append(Node.medallion(problem == nil ? Node.Glyph.pin : "magnifyingglass", cx: x + r.u(46), cy: y + boxH / 2, d: r.u(50), ink: problem == nil ? Noor.text : NoorLine.caution, ring: problem == nil ? NoorLine.soft : NoorLine.caution))
            let title = problem != nil ? L("Nothing to choose from") : waiting ? L("Type a city and press Return") : L("No place chosen yet")
            out.append(Node.say(title, x + r.u(86), y + boxH / 2 - r.u(38), w - r.u(104), r.u(28), size: r.f(17, min: 12.5), weight: "medium", color: waiting ? Noor.accent : Noor.text))
            out.append(Node.say(problem ?? (waiting ? L("Then pick it from the list, and Continue.") : L("Type a city and press Return. Your words go to Sidefolk's place search and nothing else does.")), x + r.u(86), y + boxH / 2 - r.u(10), w - r.u(104), r.u(58), size: r.f(14.5, min: 11), color: Noor.muted, valign: "top", lines: 3))
            y += step * 2
        } else {
            for (i, place) in results.enumerated() {
                let on = place.id == picked
                let title = PlaceParts.parts(place).joined(separator: " · ")
                wiring.acts["pick-\(i)"] = .go(Go(set: ["place_pick": place.id]))
                out.append(Node.group {
                    if on {
                        Node.rect(stroke: NoorLine.chosen, lineWidth: 1.4, corner: r.u(12)).gradient([.adaptive(light: "#7354B8", dark: "#4E389E"), .adaptive(light: "#6242A8", dark: "#3C2C84")], from: (0, 0.5), to: (1, 0.5)).size(w, rowH).at(0, 0)
                    } else {
                        Node.well(w, rowH, corner: r.u(12))
                    }
                    Node.radio(cx: r.u(34), cy: rowH / 2, d: r.u(27), on: on)
                    Node.say(title, r.u(79), r.u(7), w - r.u(92), r.u(28), size: r.f(17, min: 12.5), color: on ? Color.hex("#FFFFFF") : Noor.text)
                    Node.say(zoneLine(place.zoneID, now: ctx.snapshot.now), r.u(79), r.u(33), w - r.u(92), r.u(24), size: r.f(14.5, min: 11), color: on ? Color.adaptive(light: "#EEE8F5", dark: "#C9C2E2") : Noor.muted)
                }
                .size(w, rowH).at(x, y)
                .area("pick-\(i)", label: "\(title), \(place.zoneID)", hover: .init(scale: 1.005), selected: on))
                y += step
            }
            if results.count < 2 { y += step }
            let rest = ctx.model.placeResults.filter { place in !results.contains { $0.id == place.id } }
            if !rest.isEmpty {
                // The rest of what the search found, in the system's own menu over a drawn row.
                let moreH = r.u(44)
                let words = L("More places ({count})", ["count": Format.integer(rest.count)])
                out.append(Node.well(w, moreH, corner: r.u(10)).at(x, y))
                out.append(Node.say(words, x + r.u(24), y, w - r.u(80), moreH, size: r.f(15, min: 11.5)))
                out.append(Node.symbol("chevron.up.chevron.down", color: Noor.muted).size(r.f(14), r.f(14)).at(x + w - r.u(34), y + (moreH - r.f(14)) / 2))
                wiring.inlays.append(PageInlay(x: ox + x, y: oy + y, w: w, h: moreH, .draftChoice(words, options: rest.map { Option($0.id, PlaceParts.title($0), detail: $0.zoneID) }, selected: picked ?? "", key: "place_pick", style: .rows)))
                y += moreH + r.u(10)
            }
        }
        out += advanced(ctx, found: found, x: x, y: y, w: w, ox: ox, oy: oy, r: r, wiring: &wiring)
        return out
    }

    private static func advanced(_ ctx: Context, found: Place?, x: Double, y: Double, w: Double, ox: Double, oy: Double, r: Ruler, wiring: inout SceneWiring) -> [Node] {
        let open = ctx.state.bool("place_adv") == true
        let shown = found ?? ctx.model.prefs.place
        wiring.acts["advanced"] = .go(Go(set: ["place_adv": open ? NSNull() : true]))
        var out: [Node] = []
        let boxH = r.u(open ? 289 : 103), headH = r.u(38)
        out.append(Node.well(w, boxH, corner: r.u(12)).at(x, y))
        out.append(Node.group {
            Node.say(L("Advanced"), r.u(18), 0, w - r.u(60), headH, size: r.f(16, min: 11.5), weight: "medium")
            Node.symbol(open ? "chevron.up" : "chevron.down", color: Noor.text).size(r.f(13, min: 11), r.f(13, min: 11)).at(w - r.u(32), (headH - r.f(13, min: 11)) / 2)
        }
        .size(w, headH).at(x, y)
        .area("advanced", label: open ? L("Hide coordinates") : L("Enter coordinates instead"), hover: .init(scale: 1.0)))
        out.append(Node.rect(fill: NoorLine.soft).size(w - r.u(36), 1).at(x + r.u(18), y + headH))
        let coordinates = shown.map { String(format: "%.4f°, %.4f°", $0.latitude, $0.longitude) } ?? "—"
        let zone = shown.map { zoneLine($0.zoneID, now: ctx.snapshot.now) } ?? "—"
        let col = w * 0.495
        out.append(Node.say(L("Coordinates"), x + r.u(18), y + r.u(44), col - r.u(24), r.u(24), size: r.f(14.5, min: 11), color: Noor.muted))
        out.append(Node.say(coordinates, x + r.u(18), y + r.u(67), col - r.u(24), r.u(26), size: r.f(15.5, min: 11.5), tabular: true).leftToRight())
        out.append(Node.say(L("Time zone"), x + col, y + r.u(44), w - col - r.u(18), r.u(24), size: r.f(14.5, min: 11), color: Noor.muted))
        out.append(Node.say(zone, x + col, y + r.u(67), w - col - r.u(18), r.u(26), size: r.f(15.5, min: 11.5)))
        if open { out += coordinateForm(ctx, x: x, y: y + r.u(103), w: w, ox: ox, oy: oy, r: r, wiring: &wiring) }
        // What goes where, at the moment it is true.
        let iy = y + boxH + r.u(10), glyph = r.f(16, min: 12)
        out.append(Node.symbol("info.circle", color: Noor.muted).size(glyph, glyph).at(x + r.u(4), iy + (r.u(26) - glyph) / 2))
        let line = found == nil ? L("Your words go to Sidefolk's place search and nothing else does.") : L("Saving sends these coordinates to AlAdhan to calculate times and the bearing.")
        out.append(Node.say(line, x + r.u(4) + glyph + r.u(10), iy - r.u(4), w - r.u(40), r.u(34), size: r.f(14, min: 11), color: Noor.muted, lines: 2))
        out += consentRow(ctx, x: x, y: iy + r.u(34), w: w, ox: ox, oy: oy, r: r, wiring: &wiring)
        return out
    }

    /// Four wells and the one thing that uses them. A name, because a place needs one; a real zone, because times depend on it.
    private static func coordinateForm(_ ctx: Context, x: Double, y: Double, w: Double, ox: Double, oy: Double, r: Ruler, wiring: inout SceneWiring) -> [Node] {
        let lat = ctx.state.string("c_lat") ?? "", lon = ctx.state.string("c_lon") ?? "", zone = ctx.state.string("c_zone") ?? "", label = ctx.state.string("c_label") ?? ""
        let number = { (t: String) in Double(t).flatMap { $0.isFinite ? $0 : nil } }
        let ready = number(lat) != nil && number(lon) != nil && IANAZone.zone(zone) != nil && !label.isEmpty
        wiring.tools["use-coordinates"] = ("choose_place", ["label": label, "latitude": number(lat) ?? 999, "longitude": number(lon) ?? 999, "zone": zone])
        let fields: [(String, String, String, String)] = [
            (L("Name"), L("Home"), "c_label", label), (L("Time zone"), "Asia/Tokyo", "c_zone", zone),
            (L("Latitude"), "35.6762", "c_lat", lat), (L("Longitude"), "139.6503", "c_lon", lon),
        ]
        let pad = r.u(18), cellW = (w - pad * 3) / 2, wellH = r.u(36), cellH = r.u(62)
        var out: [Node] = [Node.rect(fill: NoorLine.soft).size(w - r.u(36), 1).at(x + r.u(18), y)]
        for (i, field) in fields.enumerated() {
            let cx = x + pad + Double(i % 2) * (cellW + pad), cy = y + r.u(8) + Double(i / 2) * cellH
            out.append(Node.say(field.0, cx, cy, cellW, r.u(22), size: r.f(13.5, min: 11), color: Noor.muted))
            out.append(Node.well(cellW, wellH, corner: r.u(8), fill: Noor.quiet).at(cx, cy + r.u(22)))
            wiring.inlays.append(PageInlay(x: ox + cx + r.u(10), y: oy + cy + r.u(22), w: cellW - r.u(16), h: wellH,
                                           .draftField(field.0, placeholder: field.1, button: L("Clear"), key: field.2, value: field.3.isEmpty ? nil : field.3, live: true)))
        }
        out.append(Node.pill("use-coordinates", label: L("Use these coordinates"), x: x + pad, y: y + r.u(136), w: w - pad * 2, h: r.u(40), symbol: Node.Glyph.pin, disabled: !ready, size: r.f(15, min: 11.5)))
        return out
    }

    /// What this switch means changes as the person answers, so it says so each time. It only asks: Sidefolk's own question is the consent.
    private static func consentRow(_ ctx: Context, x: Double, y: Double, w: Double, ox: Double, oy: Double, r: Ruler, wiring: inout SceneWiring) -> [Node] {
        let h = consentHeight(r), control = consentControl(ctx)
        let words = consentWords(ctx)
        var out: [Node] = [
            Node.well(w, h, corner: r.u(12)).at(x, y),
            Node.medallion("location", cx: x + r.u(37), cy: y + r.u(43), d: r.u(40), ink: Noor.text),
            Node.say(L("Use Sidefolk's place (optional)"), x + r.u(75), y + r.u(8), w - r.u(160), r.u(26), size: r.f(16, min: 11.5), weight: "medium"),
            Node.say(words, x + r.u(75), y + r.u(33), w - (control == nil ? r.u(90) : r.u(160)), h - r.u(35) - (sidefolkKnowsNoPlace ? r.u(settingsRoom) : 0), size: r.f(13.5, min: 11), color: Noor.muted, valign: "top", lines: 3),
        ]
        if let control {
            wiring.inlays.append(PageInlay(x: ox + x + w - r.u(72), y: oy + y + (h - r.u(32)) / 2, w: r.u(56), h: r.u(32), control))
        }
        if sidefolkKnowsNoPlace {
            // Opening Sidefolk's settings is a button that says so, over this pill: a scene's area can't (host D105, D109).
            let buttonX = x + r.u(75), buttonY = y + r.u(86), buttonW = w - r.u(91), buttonH = r.u(36)
            out.append(Node.capsule(fill: Noor.quiet, stroke: Noor.edge, lineWidth: 1.2).size(buttonW, buttonH).at(buttonX, buttonY))
            wiring.inlays.append(PageInlay(x: ox + buttonX, y: oy + buttonY, w: buttonW, h: buttonH, .action(Action(L("Open Sidefolk's place settings"), act: .settings("place"), symbol: "gearshape"))))
        }
        return out
    }

    private static func consentHeight(_ r: Ruler) -> Double { r.u(86 + (sidefolkKnowsNoPlace ? settingsRoom : 0)) }

    private static func consentWords(_ ctx: Context) -> String {
        guard SharedPlace.shared else { return L("Optional. Sidefolk asks you first, then shares your town and its zone with Noor. Noor sends the coordinates to AlAdhan.") }
        guard let shared = SharedPlace.current else { return L("Sidefolk doesn't know your place yet. Choose one by hand here, or set it in Sidefolk's settings.") }
        guard shared.timeZone != nil else { return L("Sidefolk knows {place} but not its time zone, so Noor can't use it. Choose a place by hand.", ["place": shared.city]) }
        return ctx.model.prefs.place?.origin == .shared ? L("Following Sidefolk's place: {place}. When it moves, Noor moves with it.", ["place": shared.city]) : L("Sidefolk's place is {place}. Your chosen place stays until you switch.", ["place": shared.city])
    }

    private static func consentControl(_ ctx: Context) -> Block? {
        guard SharedPlace.shared else { return .actToggle(L("Share Sidefolk's place"), on: false, act: .allow("place")) }
        guard let shared = SharedPlace.current, shared.timeZone != nil else { return nil }
        return .toggle(L("Follow Sidefolk's place"), on: ctx.model.prefs.place?.origin == .shared, tool: "follow_shared_place")
    }

    /// The second way to a place: the same consent, taking the room the search has.
    private static func sharedCard(_ ctx: Context, x: Double, y: Double, w: Double, h: Double, ox: Double, oy: Double, r: Ruler, wiring: inout SceneWiring) -> [Node] {
        var out = consentRow(ctx, x: x, y: y, w: w, ox: ox, oy: oy, r: r, wiring: &wiring)
        let points: [(String, String)] = [
            ("hand.raised", L("Sidefolk asks you first. Saying no changes nothing here.")),
            ("building.2", L("Only your town and its zone reach Noor.")),
            ("paperplane", L("Noor sends the coordinates to AlAdhan for times and the bearing.")),
            ("pin", L("You can keep a place you choose instead, also when you travel.")),
        ]
        var py = y + consentHeight(r) + r.u(20)
        for point in points {
            out.append(Node.medallion(point.0, cx: x + r.u(37), cy: py + r.u(26), d: r.u(40), ink: Noor.text, ring: NoorLine.soft))
            out.append(Node.say(point.1, x + r.u(75), py, w - r.u(90), r.u(52), size: r.f(15, min: 11.5), color: Noor.muted, lines: 2))
            py += r.u(62)
        }
        if let place = ctx.model.prefs.place {
            out.append(Node.say(L("Noor's place is now {place}", ["place": place.label]), x, py + r.u(4), w, r.u(28), size: r.f(15.5, min: 11.5), weight: "medium", color: Noor.warm, align: "center"))
        }
        return out
    }
}

/// Finding a place, here and in Preferences.
@MainActor
enum PlaceParts {
    /// A place's name, region and country, each once: for many cities the region has the city's own name.
    static func parts(_ place: Place) -> [String] {
        var out: [String] = []
        for part in [place.label, place.region, place.country].compactMap({ $0 }) where !out.contains(where: { $0.caseInsensitiveCompare(part) == .orderedSame }) { out.append(part) }
        return out
    }

    static func title(_ place: Place) -> String { parts(place).joined(separator: ", ") }

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
