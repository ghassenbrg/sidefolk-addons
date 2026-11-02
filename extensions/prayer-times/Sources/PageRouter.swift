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
        let width = min(args.pageWidth ?? 880, 1320)
        let ctx = Context(state: state, snapshot: snapshot, model: model, width: width)

        var sections: [Section] = []
        let setup = !model.isSetUp
        if setup {
            // A mosque's timetable can be the first thing someone sets up, by file or by hand.
            switch state.string("sheet") {
            case "import": sections = SourcePage.review(ctx)
            case "manual": sections = SourcePage.manual(ctx)
            case "prefs": sections = PreferencesPage.sections(ctx)
            default: sections = setupTab(ctx)
            }
            return page(summary, [head(ctx, subtitle: snapshot.place == nil ? L("Choose a place to get started") : L("Choose your timetable"))] + sections, back: state.string("sheet") == nil ? nil : L("Back"))
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
        return page(summary, [head(ctx, subtitle: NoorPage.headLine(ctx) ?? Words.provenance(snapshot))] + sections, back: back)
    }

    private static func page(_ summary: Summary, _ sections: [Section], back: String?) -> Page {
        Page(summary: summary, sections: sections, back: back, bleed: true, dress: Noor.dress, maxWidth: 1320)
    }

    private static func head(_ ctx: Context, subtitle: String) -> Section {
        Section(nil, [HeadScene.block(ctx, subtitle: subtitle, reminders: ctx.snapshot.reminderStatus)], wide: true)
    }

    /// Before set-up the tabs still lead somewhere: Overview is the welcome, Names need no place, and the rest say what they are waiting for.
    private static func setupTab(_ ctx: Context) -> [Section] {
        if ctx.state.string("setup") != nil || ctx.tab == .overview { return SetupPage.sections(ctx) }
        if ctx.tab == .names { return NamesPage.sections(ctx) }
        switch ctx.snapshot.validity {
        case .noPlace, .noSource: return [NoorPage.unavailable(ctx)].compactMap { $0 }
        default: return SetupPage.sections(ctx)
        }
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
        case .notStarted:
            return Summary(L("Timetable hasn't started"), detail: where_, tone: .info, symbol: "calendar")
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
            let zone = snapshot.source?.zone ?? snapshot.place?.zone ?? .current
            detail += " · " + L("Reminders paused until {time}", ["time": "\(Words.date(CivilDate(until, in: zone), weekday: false, year: false)) \(Words.time(until, zone: zone))"])
        }
        return Summary("\(focus.title) \(focus.time)", detail: detail, tone: snapshot.validity == .offlineValid ? .warn : .good, symbol: "moon.stars")
    }

    enum Act {
        case tool(String, [String: Any] = [:])
        case go(Go)
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
    var narrow: Bool { width < 680 }
    var ruler: Ruler { Ruler(width: width) }
    var zone: TimeZone { snapshot.source?.zone ?? snapshot.place?.zone ?? .current }
    func t(_ date: Date) -> String { Words.time(date, zone: zone) }
}
