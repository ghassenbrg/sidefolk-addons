import Foundation
import SidefolkExtensionKit

/// The Keep Awake page: one line on what is happening, the ways to start or stop, and the choices that shape it.
@MainActor
enum AwakePage {
    static func make(_ k: Keeper, now: Date = Date()) -> Page {
        let s = k.session
        let summary: Summary
        switch (s, k.hold) {
        case (let s?, .holding):
            summary = Summary(headline(s, now: now), detail: how(s, nudges: k.nudges), tone: .good, symbol: "cup.and.saucer.fill")
        case (_?, .waiting(let why)):
            summary = Summary("Waiting", detail: why, tone: .warn, symbol: "pause.circle.fill")
        default:
            let last = k.lastEnd.map { "Last time: \($0.why) (\($0.at.formatted(date: .omitted, time: .shortened)))" } ?? ""
            summary = Summary("Your Mac sleeps as usual", detail: last, tone: .neutral, symbol: "moon.zzz.fill")
        }

        var start: [Block]
        if s == nil {
            start = [
                .button("30 min", tool: "keep_awake", input: ["minutes": 30], symbol: "cup.and.saucer"),
                .button("1 hour", tool: "keep_awake", input: ["minutes": 60]),
                .button("2 hours", tool: "keep_awake", input: ["minutes": 120]),
                .button("Until I stop it", tool: "keep_awake", style: .primary),
            ]
        } else {
            start = [.button("Stop", tool: "stop_keeping_awake", style: .destructive, symbol: "stop.fill")]
            if s?.until != nil { start.insert(.button("30 min more", tool: "extend", input: ["minutes": 30], symbol: "plus"), at: 0) }
        }

        let d = k.defaults
        let choices: [Block] = [
            .toggle("Keep the screen on", detail: "Off: the Mac stays awake (downloads, builds) and the screen may sleep.", on: s?.screen ?? d.screen,
                    tool: "set_option", input: ["option": "screen"]),
            .toggle("Keep me active in chat apps", detail: "While you're away, Sidefolk moves the pointer by nothing about once a minute, so "
                + "Slack, Teams and Zoom don't mark you away. You won't see it move.", on: s?.active ?? d.active,
                tool: "set_option", input: ["option": "active"]),
            .toggle("Only while plugged in", detail: "On battery it waits, and holds again when you plug in.", on: s?.pluggedOnly ?? d.pluggedOnly,
                    tool: "set_option", input: ["option": "plugged_only"]),
            .toggle("Let go when the battery is under 15%", detail: "So keeping it awake never empties it.", on: (s ?? d).batteryFloor != nil,
                    tool: "set_option", input: ["option": "battery_floor"]),
        ]
        return Page(summary: summary, sections: [
            Section(nil, start),
            Section("How", choices),
            Section("Ask for more", [
                .ask("While Zoom is open", "Keep my Mac awake while Zoom is open"),
                .ask("Until 6 pm", "Keep my Mac awake until 6pm"),
                .ask("Keep me active for an hour", "Keep me active for an hour"),
            ]),
        ])
    }

    static func headline(_ s: Session, now: Date) -> String {
        if let app = s.whileApp { return "Awake while \(app) is open" }
        guard let until = s.until else { return "Awake until you stop it" }
        return "Awake until \(until.formatted(date: .omitted, time: .shortened))"
    }

    static func how(_ s: Session, nudges: Int) -> String {
        var parts = [s.screen ? "Screen on" : "Screen may sleep"]
        if s.active { parts.append(nudges > 0 ? "showing you active (\(nudges)× so far)" : "showing you active") }
        if s.pluggedOnly { parts.append("only plugged in") }
        return parts.joined(separator: " · ")
    }

    /// For a tool's answer.
    static func sentence(_ k: Keeper, now: Date = Date()) -> String {
        guard let s = k.session else { return "Your Mac isn't being kept awake; it sleeps as usual." }
        if case .waiting(let why) = k.hold { return "Keep Awake is on but waiting: \(why)" }
        var text = headline(s, now: now)
        if let until = s.until { text += " (\(Rules.left(until, now: now)) left)" }
        return text + ". " + how(s, nudges: k.nudges) + "."
    }
}
