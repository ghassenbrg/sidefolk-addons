import Foundation
import SidefolkExtensionKit

/// Noor's one Home entry. Where it is lives in the page's state (host D105): `tab` is one of five places, `sheet` what stands over it for a while (Ramadan, Preferences, a conversion). Only
/// what shows is drawn, and reading it never changes anything or schedules anything: what acts is a tool.
@MainActor
enum NoorPage {
    static func render(_ args: Arguments) async -> Page {
        let model = NoorModel.shared
        let state = args.pageState
        let summary = summary(model.snapshot())
        // Nobody is looking: Today's tile needs its summary and no more.
        guard !args.pageIsBackground else {
            model.freshen()
            return Page(summary: summary, sections: [])
        }
        model.freshen(extra: wanted(state, model: model))
        await model.settle()
        let snapshot = model.snapshot()
        let width = min(args.pageWidth ?? 980, 1080)
        let ctx = Context(state: state, snapshot: snapshot, model: model, width: width)

        var sections: [Section] = []
        let setup = !model.isSetUp
        if setup {
            sections = SetupPage.sections(ctx)
            return page(summary, [head(ctx, subtitle: L("Choose a place to get started"))] + sections, back: nil)
        }
        let back: String?
        switch state.string("sheet") {
        case "ramadan":
            sections = RamadanPage.sections(ctx)
            back = L("Back")
        case "prefs":
            sections = PreferencesPage.sections(ctx)
            back = L("Back")
        case "convert":
            sections = CalendarPage.convert(ctx)
            back = L("Back to Calendar")
        case "occasions":
            sections = CalendarPage.occasions(ctx)
            back = L("Back to Calendar")
        case "import":
            sections = SourcePage.review(ctx)
            back = L("Back")
        case "manual":
            sections = SourcePage.manual(ctx)
            back = L("Back")
        case "name":
            sections = NamesPage.detailOnly(ctx)
            back = L("Back to Names")
        default:
            back = nil
            switch ctx.tab {
            case .overview: sections = OverviewPage.sections(ctx)
            case .prayer: sections = PrayerPage.sections(ctx)
            case .calendar: sections = CalendarPage.sections(ctx)
            case .qibla: sections = QiblaPage.sections(ctx)
            case .names: sections = NamesPage.sections(ctx)
            }
        }
        let tabs = NoorTab.allCases.map { PageTab($0.rawValue, Words.tab($0), symbol: $0.symbol, go: Go(set: ["tab": $0.rawValue, "sheet": NSNull()])) }
        let body = Block.goTabs(selected: ctx.tab.rawValue, tabs, tint: Noor.tabTint, sections: sections)
        return page(summary, [head(ctx, subtitle: Words.provenance(snapshot)), Section(nil, [body], wide: true)], back: back)
    }

    private static func page(_ summary: Summary, _ sections: [Section], back: String?) -> Page {
        Page(summary: summary, sections: sections, back: back, bare: true, dress: Noor.dress, maxWidth: 1080)
    }

    private static func head(_ ctx: Context, subtitle: String) -> Section {
        Section(nil, [HeadScene.block(width: ctx.width, snapshot: ctx.snapshot, subtitle: subtitle, remindersOn: ctx.snapshot.reminderStatus != .off)], wide: true)
    }

    /// What this view needs that the provider wasn't already asked for.
    private static func wanted(_ state: Arguments, model: NoorModel) -> [String] {
        var out: [String] = []
        let tab = state.string("tab") ?? "overview", sheet = state.string("sheet")
        if tab == "calendar" || sheet == "occasions" || sheet == "convert" { out += CalendarPage.wanted(state, model: model) }
        if sheet == "ramadan" || sheet == "prefs" {
            if let year = RamadanPage.year(state, model: model) { out += ["r:\(year)"] }
        }
        if tab == "prayer", let day = state.string("day"), CivilDate(iso: day) != nil { out.append("d:\(day)") }
        return out
    }

    /// The page in a line: the next event, as Today's tile and the sidebar show it. Read from the same snapshot as the page.
    static func summary(_ snapshot: NoorSnapshot) -> Summary {
        let where_ = Words.provenance(snapshot)
        switch snapshot.validity {
        case .noPlace, .noSource:
            return Summary(L("Choose a place"), detail: L("Noor needs a place to show prayer times."), tone: .info, symbol: "location")
        case .expired:
            return Summary(L("Timetable ended"), detail: where_, tone: .warn, symbol: "calendar.badge.exclamationmark")
        case .loading:
            return Summary(L("Loading timetable"), detail: where_, tone: .neutral, symbol: "hourglass")
        case .error:
            return Summary(L("No time available"), detail: where_, tone: .warn, symbol: "exclamationmark.triangle")
        case .ready, .offlineValid:
            break
        }
        guard let focus = DialScene.focus(snapshot) else {
            return Summary(L("No time available"), detail: L("Tomorrow's times aren't here yet."), tone: .warn, symbol: "exclamationmark.triangle")
        }
        var detail = "\(focus.countdown) · \(where_)"
        if case .paused(let until) = snapshot.reminderStatus {
            detail += " · " + L("Reminders paused until {time}", ["time": Words.time(until, zone: snapshot.source?.zone ?? .current)])
        }
        return Summary("\(focus.title) \(focus.time)", detail: detail, tone: snapshot.validity == .offlineValid ? .warn : .good, symbol: "moon.stars")
    }

    /// A status panel in Noor's frame, for what stands in place of a tab's content: no place, loading, ended, unreachable. It never shows a time it doesn't have.
    static func status(_ ctx: Context, symbol: String, title: String, detail: String, tint: Color = Noor.warm, buttons: [(id: String, label: String, filled: Bool, act: Act)] = []) -> Section {
        let w = ctx.width
        let h = 380.0 + (ctx.narrow ? 40 : 0)
        var tools: [String: (tool: String, input: [String: Any])] = [:]
        var acts: [String: PageAct] = [:]
        let scene = Scene(width: w, height: h) {
            Node.patternPanel(w, h, corner: 18)
            let archW = min(w - 40, 620.0)
            Node.arch(archW, h - 20, lift: 110).at((w - archW) / 2, 20)
            Node.ellipse(fill: Noor.surface, stroke: Noor.inlay, lineWidth: 1.5).size(64, 64).at(w / 2 - 32, 62)
            Node.symbol(symbol, color: tint).size(30, 30).at(w / 2 - 15, 79)
            Node.say(title, (w - archW) / 2 + 30, 136, archW - 60, 34, size: 22, weight: "semibold", align: "center", lines: 1)
            Node.say(detail, (w - archW) / 2 + 40, 172, archW - 80, 62, size: 14, color: Noor.muted, align: "center", lines: 3)
            let bw = min(280.0, archW - 80)
            for (i, b) in buttons.enumerated() {
                Node.pill(b.id, label: b.label, x: (w - bw) / 2, y: 244 + Double(i) * 46, w: bw, h: 38, filled: b.filled)
            }
        }
        for b in buttons {
            switch b.act {
            case .tool(let name, let input): tools[b.id] = (name, input)
            case .go(let go): acts[b.id] = .go(go)
            }
        }
        return Section(nil, [.scene(PageSceneBlock(scene, actions: tools, acts: acts))], wide: true)
    }

    enum Act {
        case tool(String, [String: Any] = [:])
        case go(Go)
    }

    /// What every tab says the same way when it has no times to show. Nil when it does.
    static func unavailable(_ ctx: Context) -> Section? {
        let s = ctx.snapshot
        switch s.validity {
        case .ready, .offlineValid:
            return nil
        case .noPlace, .noSource:
            return status(ctx, symbol: "mappin.and.ellipse", title: L("Choose a place"), detail: L("Set your city to show prayer times, the calendar and Qibla direction."),
                          buttons: [("place", L("Choose a place"), true, .go(Go(set: ["sheet": "prefs", "section": "place"], push: true)))])
        case .loading:
            return status(ctx, symbol: "hourglass", title: L("Loading timetable"), detail: s.place.map { L("Fetching prayer times for {place}…", ["place": $0.label]) } ?? "", tint: Noor.muted)
        case .expired:
            let end = s.coverage.map { Words.date($0.upperBound, weekday: false) } ?? ""
            return status(ctx, symbol: "exclamationmark.circle", title: L("This timetable has ended"), detail: L("The saved timetable finished on {date}. Nothing new is reminded from it until you update it.", ["date": end]),
                          buttons: [("update", L("Update timetable"), true, .go(Go(set: ["sheet": "prefs", "section": "sources"], push: true))),
                                    ("calculated", L("Choose calculated times"), false, .tool("use_calculated"))])
        case .error:
            return status(ctx, symbol: "wifi.exclamationmark", title: L("Couldn't get this timetable"), detail: Words.problem(ctx.model.problem).isEmpty ? L("The provider didn't answer.") : Words.problem(ctx.model.problem),
                          buttons: [("retry", L("Try again"), true, .tool("refresh"))])
        }
    }

    /// A strip that says the times shown were saved earlier: an older copy still answers for today, so it isn't an error, only worth knowing.
    static func offlineNote(_ ctx: Context) -> Block? {
        guard ctx.snapshot.validity == .offlineValid || ctx.model.load == .failed || ctx.model.load == .offline else { return nil }
        let saved = ctx.model.fetchedAt.map { Format.dateTime($0, timeZone: ctx.zone) }
        let text = saved.map { L("Offline. Showing times saved {when}.", ["when": $0]) } ?? L("Offline. Showing saved times.")
        return .note(ctx.model.problem == .offline || ctx.model.load == .offline ? text : (Words.problem(ctx.model.problem).isEmpty ? text : Words.problem(ctx.model.problem)), tone: .warn)
    }
}

/// What one reading has to work with.
@MainActor
struct Context {
    let state: Arguments
    let snapshot: NoorSnapshot
    let model: NoorModel
    let width: Double

    var tab: NoorTab { NoorTab(rawValue: state.string("tab") ?? "") ?? .overview }
    /// One column, as the C04 board has it. Everything still reads; it only stacks.
    var narrow: Bool { width < 760 }
    var zone: TimeZone { snapshot.source?.zone ?? snapshot.place?.zone ?? .current }
    func t(_ date: Date) -> String { Words.time(date, zone: zone) }
}
