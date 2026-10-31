import Foundation
import SidefolkExtensionKit

/// The Keep Awake page: one line on what is happening, the ways to start or stop, and the choices that shape it.
@MainActor
enum AwakePage {
    static func make(_ k: Keeper, now: Date = Date()) -> Page {
        let s = k.session
        // The main switch, on the page's summary, its Today tile and its row in Home's sidebar: on keeps the Mac awake
        // until stopped, with the choices below; off lets it sleep.
        let main = Block.toggle(L("Keep awake"), on: s != nil, tool: "keep_awake")
        let summary: Summary
        switch (s, k.hold) {
        case (let s?, .holding):
            summary = Summary(headline(s, now: now), detail: detail(s, nudges: k.nudges, now: now), tone: .good, symbol: "cup.and.saucer.fill",
                              control: main)
        case (_?, .waiting(let why)):
            summary = Summary(L("Waiting"), detail: Rules.shown(why), tone: .warn, symbol: "pause.circle.fill", control: main)
        default:
            let last = k.lastEnd.map { L("Last time: {why} ({time})", ["why": Rules.shown($0.why), "time": Format.time($0.at)]) } ?? ""
            summary = Summary(L("Your Mac sleeps as usual"), detail: last, tone: .neutral, symbol: "moon.zzz.fill", control: main)
        }

        var start: [Block]
        if s == nil {
            start = [
                .button(Format.duration(1800), tool: "keep_awake", input: ["minutes": 30], symbol: "cup.and.saucer"),
                .button(L("1 hour"), tool: "keep_awake", input: ["minutes": 60]),
                .button(L("2 hours"), tool: "keep_awake", input: ["minutes": 120]),
            ]
        } else {
            start = [.button(L("Stop"), tool: "stop_keeping_awake", style: .destructive, symbol: "stop.fill")]
            if s?.until != nil { start.insert(.button(L("30 min more"), tool: "extend", input: ["minutes": 30], symbol: "plus"), at: 0) }
        }

        let d = k.defaults
        let choices: [Block] = [
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
        return Page(summary: summary, sections: [
            Section(nil, start),
            Section(L("How"), choices),
            Section(L("Ask for more"), [
                // What is asked stays English: Sidefolk understands typed commands in English (its GLOSSARY, rule 1).
                .ask(L("While Zoom is open"), "Keep my Mac awake while Zoom is open"),
                .ask(L("Until {time}", ["time": Format.time(Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: now) ?? now)]),
                     "Keep my Mac awake until 6pm"),
                .ask(L("Keep me active for an hour"), "Keep me active for an hour"),
            ]),
        ])
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
