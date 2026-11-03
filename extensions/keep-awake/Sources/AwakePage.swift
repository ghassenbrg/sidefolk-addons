import Foundation
import SidefolkExtensionKit

/// The Keep Awake page: the session across the top with its time and what can be done about it, what shapes it on the left, and other ways to keep awake on the right. What
/// it says is always the session's own: a ring only where there's an end to count down to, "Waiting" whenever nothing is held.
@MainActor
enum AwakePage {
    static var dress: PageDress {
        PageDress(ground: PagePair(light: "#F8F4F0", dark: "#1C1A17"), card: PagePair(light: "#FFFDFA", dark: "#2A2622"), line: PagePair(light: "#E8E1D9", dark: "#3E3932"),
                                 accent: PagePair(light: "#AD5F14", dark: "#E2A04E"), selected: PagePair(light: "#AD5F14", dark: "#E2A04E"), well: PagePair(light: "#F2ECE4", dark: "#38322B"))
    }

    /// What the page shows, read from the keeper at one moment, so each state can be drawn (and tested) alone.
    struct Now {
        var session: Session?
        var hold: Hold = .ended("")
        var defaults = Session(started: .distantPast)
        var nudges = 0
        var lastEnd: (at: Date, why: String)?

        init(session: Session? = nil, hold: Hold = .ended(""), defaults: Session = Session(started: .distantPast), nudges: Int = 0, lastEnd: (at: Date, why: String)? = nil) {
            self.session = session
            self.hold = hold
            self.defaults = defaults
            self.nudges = nudges
            self.lastEnd = lastEnd
        }

        @MainActor init(_ k: Keeper) { self.init(session: k.session, hold: k.hold, defaults: k.defaults, nudges: k.nudges, lastEnd: k.lastEnd) }
    }

    static func make(_ k: Keeper, now: Date = Date()) -> Page { make(Now(k), now: now) }

    static func make(_ k: Now, now: Date = Date()) -> Page {
        let s = k.session
        let waiting: String? = if case .waiting(let why) = k.hold, s != nil { why } else { nil }
        var page = Page(summary: summary(k, now: now), sections: [head(s, waiting: waiting), Section(nil, [.hero(hero(k, waiting: waiting, now: now))], wide: true),
                                                                  how(k), more(now: now)], bare: true, dress: dress, maxWidth: 1180)
        if s != nil { page.sections.append(Section(nil, [.note(L("Your Mac will sleep normally when this session ends."), symbol: "info.circle", style: .plain)])) }
        page.sections.append(Section(L("Heads-ups"), [.headsUps()], collapsed: true))
        return page
    }

    /// On Today and in Home's sidebar: the main switch (D67) beside what is happening. On keeps the Mac awake until stopped; off lets it sleep.
    static func summary(_ k: Now, now: Date) -> Summary {
        let main = Block.toggle(L("Keep awake"), on: k.session != nil, tool: "keep_awake")
        switch (k.session, k.hold) {
        case (let s?, .holding):
            return Summary(headline(s, now: now), detail: detail(s, nudges: k.nudges, now: now), tone: .good, symbol: "cup.and.saucer.fill", control: main)
        case (_?, .waiting(let why)):
            return Summary(L("Waiting"), detail: Rules.shown(why), tone: .warn, symbol: "pause.circle.fill", control: main)
        default:
            return Summary(L("Your Mac sleeps as usual"), detail: lastTime(k), tone: .neutral, symbol: "moon.zzz.fill", control: main)
        }
    }

    static func lastTime(_ k: Now) -> String {
        k.lastEnd.map { L("Last time: {why} ({time})", ["why": Rules.shown($0.why), "time": Format.time($0.at)]) } ?? ""
    }

    static func head(_ s: Session?, waiting: String?) -> Section {
        let pill = s == nil ? Badge(L("Not active"), tone: .neutral) : waiting != nil ? Badge(L("Waiting"), tone: .warn) : Badge(L("Active session"), tone: .good)
        return Section(nil, [.bar(PageBar(L("Keep Awake"), pill: pill, detail: L("Choose when your Mac can rest."), brand: true))], wide: true)
    }

    static func hero(_ k: Now, waiting: String?, now: Date) -> Hero {
        guard let s = k.session else {
            let last = lastTime(k)
            var hero = Hero(L("Your Mac sleeps as usual"), detail: last.isEmpty ? L("Start a session and it stays awake until the time you pick.") : last, symbol: "moon.zzz",
                            actions: [Action(Format.duration(1800), tool: "keep_awake", input: ["minutes": 30], style: .primary, symbol: "cup.and.saucer"),
                                      Action(L("1 hour"), tool: "keep_awake", input: ["minutes": 60]), Action(L("2 hours"), tool: "keep_awake", input: ["minutes": 120])])
            hero.plain = true
            return hero
        }
        var actions = [Action(L("Stop keeping awake"), tool: "stop_keeping_awake", style: .primary, symbol: "stop.fill")]
        if s.until != nil { actions.insert(Action(L("30 min more"), tool: "extend", input: ["minutes": 30], symbol: "plus"), at: 0) }
        var hero = Hero(waiting == nil ? headline(s, now: now) : L("Waiting"), detail: waiting.map(Rules.shown) ?? line(s), tone: waiting == nil ? .neutral : .warn,
                        symbol: waiting == nil ? (s.whileApp == nil ? "cup.and.saucer" : "app.badge.checkmark") : "pause.circle", actions: actions)
        hero.plain = true
        hero.ring = ring(s, now: now)
        hero.chips = chips(s, nudges: k.nudges)
        return hero
    }

    /// Only with an end to count down to, measured from when this session really began.
    static func ring(_ s: Session, now: Date) -> (fraction: Double, value: String, caption: String?)? {
        guard let until = s.until else { return nil }
        let whole = until.timeIntervalSince(s.started)
        guard whole > 0 else { return nil }
        return (min(1, max(0, until.timeIntervalSince(now) / whole)), Rules.left(until, now: now), L("remaining"))
    }

    static func line(_ s: Session) -> String {
        if let app = s.whileApp { return L("Ends by itself when {app} quits.", ["app": app]) }
        return s.until == nil ? L("Your Mac stays awake until you stop this session.") : L("Your Mac stays awake until this session ends.")
    }

    static func chips(_ s: Session, nudges: Int) -> [(String, String?, Tone)] {
        var out: [(String, String?, Tone)] = [(s.screen ? L("Screen on") : L("Screen may sleep"), "display", s.screen ? .good : .neutral)]
        if s.active { out.append((nudges > 0 ? L("showing you active ({count}× so far)", ["count": nudges]).capitalizedFirst : L("showing you active").capitalizedFirst, "cursorarrow", .good)) }
        if s.pluggedOnly { out.append((L("only plugged in").capitalizedFirst, "powerplug", .neutral)) }
        return out
    }

    static func how(_ k: Now) -> Section {
        let s = k.session, d = k.defaults
        var blocks: [Block] = []
        // Off here, the switch that starts it stands with the choices: the same one as in the sidebar and on Today.
        if s == nil { blocks.append(.toggle(L("Keep awake"), detail: L("Until you stop it, with the choices below."), on: false, tool: "keep_awake")) }
        blocks += [
            .toggle(L("Keep the screen on"), detail: L("Off: the Mac stays awake (downloads, builds) and the screen may sleep."), on: s?.screen ?? d.screen,
                    tool: "set_option", input: ["option": "screen"]),
            .toggle(L("Keep me active in chat apps"),
                    detail: L("While you're away, Sidefolk moves the pointer by nothing about once a minute, so Slack, Teams and Zoom don't mark you away. You won't see it move."), on: s?.active ?? d.active,
                    tool: "set_option", input: ["option": "active"]),
            .toggle(L("Only while plugged in"), detail: L("On battery it waits, and holds again when you plug in."), on: s?.pluggedOnly ?? d.pluggedOnly,
                    tool: "set_option", input: ["option": "plugged_only"]),
            .toggle(L("Let go when the battery is under {percent}", ["percent": Format.percent(0.15)]), detail: L("So keeping it awake never empties it."), on: (s ?? d).batteryFloor != nil,
                    tool: "set_option", input: ["option": "battery_floor"]),
        ]
        return Section(s == nil ? L("When you start one") : L("During this session"), blocks).inCard(row: "more", weight: 56)
    }

    static func more(now: Date) -> Section {
        // What is asked stays English: Sidefolk understands typed commands in English (its GLOSSARY, rule 1).
        Section(L("More ways to keep awake"), [
            .askRow(L("While Zoom is open"), "Keep my Mac awake while Zoom is open", symbol: "video"),
            .askRow(L("Until {time}", ["time": Format.time(Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: now) ?? now)]), "Keep my Mac awake until 6pm", symbol: "clock"),
            .askRow(L("Keep me active for an hour"), "Keep me active for an hour", symbol: "bolt"),
            .note(L("These shortcuts open Ask."), symbol: "sparkles", style: .plain),
        ], detail: L("Set a different end time or keep awake while an app is open.")).inCard(row: "more", weight: 44)
    }

    static func headline(_ s: Session, now: Date) -> String {
        if let app = s.whileApp { return L("Awake while {app} is open", ["app": app]) }
        guard let until = s.until else { return L("Awake until you stop it") }
        return L("Awake until {time}", ["time": Format.time(until)])
    }

    /// Under the headline: the time left first, the one thing people glance at the tile for.
    static func detail(_ s: Session, nudges: Int, now: Date) -> String {
        let how = how(s, nudges: nudges)
        guard let until = s.until else { return how }
        return L("{time} left", ["time": Rules.left(until, now: now)]) + " · " + how
    }

    static func how(_ s: Session, nudges: Int) -> String {
        var parts = [s.screen ? L("Screen on") : L("Screen may sleep")]
        if s.active { parts.append(nudges > 0 ? L("showing you active ({count}× so far)", ["count": nudges]) : L("showing you active")) }
        if s.pluggedOnly { parts.append(L("only plugged in")) }
        return parts.joined(separator: " · ")
    }

    /// For a tool's answer.
    static func sentence(_ k: Keeper, now: Date = Date()) -> String {
        guard let s = k.session else { return L("Your Mac isn't being kept awake; it sleeps as usual.") }
        if case .waiting(let why) = k.hold { return L("Keep Awake is on but waiting: {why}", ["why": Rules.shown(why)]) }
        var text = headline(s, now: now)
        if let until = s.until { text += " (" + L("{time} left", ["time": Rules.left(until, now: now)]) + ")" }
        return text + ". " + how(s, nudges: k.nudges) + "."
    }
}

extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
