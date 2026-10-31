import Foundation
import SidefolkExtensionKit

/// Miraya's page: what is happening now with its controls, the TVs around, what to share and how, and playing videos.
/// It says only what is true: a TV is "on" when it answers on the network now, sharing is "on the TV" once the TV
/// reported a picture.
@MainActor
enum MirayaPage {
    static func make(_ s: Session, windows: [Screens.Window]?) -> Page {
        var sections: [Section] = []
        if let problem = s.problem, !s.busy { sections.append(Section(nil, [.note(problem, tone: .bad)])) }
        if s.busy { sections.append(now(s)) }
        sections.append(tvs(s))
        if s.mode == .mirror || !s.busy { sections += share(s, windows: windows) }
        sections.append(Section("Play a video on the TV", [
            .note("Drop a video on Sidefolk and say “play this on the TV”, or say “play ~/Movies/film.mp4 on the TV”. "
                + "An HTTPS link to the video itself works too. Subtitles: an .srt or .vtt file beside it. "
                + "The TV plays the original file; nothing is recorded or converted."),
        ]))
        return Page(summary: summary(s), sections: sections)
    }

    // MARK: The line on top, and the Today tile

    static func summary(_ s: Session) -> Summary {
        let tv = s.receiver?.name ?? "the TV"
        switch s.phase {
        case .idle:
            let on = s.found.count
            if on == 0 { return Summary("Miraya found no TV", detail: "Open Miraya on your Android TV, on the same network as this Mac.", tone: .neutral, symbol: "tv") }
            let names = s.found.map(\.name)
            return Summary("Miraya is ready", detail: on == 1 ? "\(names[0]) is on" : "\(on) TVs on: \(names.joined(separator: ", "))", tone: .neutral, symbol: "tv")
        case .connecting: return Summary("Miraya is connecting to \(tv)…", tone: .info, symbol: "tv")
        case .reconnecting: return Summary("Miraya is reconnecting to \(tv)…", detail: s.note ?? "", tone: .warn, symbol: "arrow.clockwise")
        case .pairing: return Summary("Miraya's pairing code: \(spaced(s.pairingCode))", detail: "Check \(tv) shows the same six digits.", tone: .warn, symbol: "lock.shield")
        case .authorizing: return Summary("Choose Allow on \(tv)", detail: "Miraya is waiting for the TV's remote.", tone: .warn, symbol: "hand.raised")
        case .starting:
            return Summary(s.mode == .media ? "Miraya is starting the video on \(tv)…" : "Miraya is starting to share to \(tv)…", tone: .info, symbol: "tv")
        case .sharing:
            if s.mode == .media {
                return Summary("Miraya is playing on \(tv)", detail: "\(s.media?.title ?? "A video") · \(clock(s.mediaPosition)) of \(clock(s.mediaDuration))",
                               tone: .good, symbol: "play.tv")
            }
            return Summary("Miraya is sharing \(s.target?.kind == .display ? "your screen" : (s.target?.label ?? "your screen")) to \(tv)",
                           detail: [s.target?.kind == .display ? s.target?.label : nil, s.picture.isEmpty ? nil : s.picture].compactMap { $0 }.joined(separator: " · "),
                           tone: .good, symbol: "rectangle.on.rectangle")
        case .pausing, .paused:
            if s.mode == .media && s.mediaState == "ended" {
                return Summary("The video finished on \(tv)", detail: s.media?.title ?? "", tone: .neutral, symbol: "checkmark.circle")
            }
            return Summary(s.mode == .media ? "Miraya paused the video on \(tv)" : "Miraya paused sharing to \(tv)",
                           detail: s.mode == .media ? (s.media?.title ?? "") : "The TV may still show the last picture.", tone: .warn, symbol: "pause.circle")
        }
    }

    // MARK: Now

    static func now(_ s: Session) -> Section {
        let tv = s.receiver?.name ?? "the TV"
        switch s.phase {
        case .pairing:
            return Section("Pair with \(tv)", [
                .stat("Code on this Mac", spaced(s.pairingCode), tone: .warn, caption: "The same on the TV?"),
                .note("If \(tv) shows the same six digits, they match. If not, cancel: something else may be answering for your TV."),
                .button("Codes match · Pair", tool: "confirm_pairing", style: .primary, symbol: "checkmark.shield"),
                .button("Cancel", tool: "stop", style: .secondary),
            ])
        case .authorizing:
            return Section("Pair with \(tv)", [
                .note("Choose Allow on the TV with its remote. Next time it connects without a code."),
                .button("Cancel", tool: "stop"),
            ])
        case .connecting, .reconnecting, .starting:
            var blocks: [Block] = [.note(s.note ?? (s.mode == .media ? "The TV is opening the video." : "Getting the TV and the video connection ready."))]
            blocks.append(.button("Cancel", tool: "stop"))
            return Section("Now", blocks)
        case .sharing, .pausing, .paused:
            if s.mode == .media { return playing(s) }
            var facts: [(String, String)] = [("TV", tv), ("Sharing", s.target?.label ?? "Your screen")]
            if !s.picture.isEmpty { facts.append(("Picture", s.picture)) }
            if s.tvFPS > 0 { facts.append(("On the TV", "\(Int(s.tvFPS.rounded())) frames a second")) }
            if s.rttMs > 0 { facts.append(("Network delay", "\(Int(s.rttMs.rounded())) ms there and back")) }
            facts.append(("Sound", s.choices.sound ? "On the TV and this Mac" : "This Mac only"))
            if let since = s.startedAt { facts.append(("Since", since.formatted(date: .omitted, time: .shortened))) }
            return Section("Now", [
                .facts(nil, facts),
                s.phase == .paused ? .button("Resume", tool: "resume", style: .primary, symbol: "play.fill")
                    : .button("Pause", tool: "pause", symbol: "pause.fill"),
                .button("Stop sharing", tool: "stop", style: .destructive, symbol: "stop.fill"),
            ])
        case .idle:
            return Section(nil, [])
        }
    }

    static func playing(_ s: Session) -> Section {
        var facts: [(String, String)] = [("TV", s.receiver?.name ?? "the TV"), ("Video", s.media?.title ?? "")]
        facts.append(("Where", s.mediaDuration > 0 ? "\(clock(s.mediaPosition)) of \(clock(s.mediaDuration))" : clock(s.mediaPosition)))
        if !s.picture.isEmpty { facts.append(("Picture", s.picture)) }
        if !s.mediaState.isEmpty { facts.append(("Player", s.mediaState)) }
        var blocks: [Block] = [.facts(nil, facts)]
        if s.mediaSeekable { blocks.append(.button("Back 30 s", tool: "seek", input: ["seconds": -30], symbol: "gobackward.30")) }
        blocks.append(s.phase == .paused ? .button("Play", tool: "resume", style: .primary, symbol: "play.fill")
                                         : .button("Pause", tool: "pause", symbol: "pause.fill"))
        if s.mediaSeekable { blocks.append(.button("Forward 30 s", tool: "seek", input: ["seconds": 30], symbol: "goforward.30")) }
        blocks.append(.button("Stop", tool: "stop", style: .destructive, symbol: "stop.fill"))
        return Section("Now", blocks)
    }

    // MARK: TVs

    static func tvs(_ s: Session) -> Section {
        let rows = s.tvs
        var blocks: [Block] = []
        if rows.isEmpty {
            blocks.append(.note("No TV yet. Open Miraya on the TV and keep it open; it appears here by its room name. "
                + "Not showing up? Say “connect to the TV at 192.168.1.20” with the address the TV shows."))
        } else {
            blocks.append(.facts(nil, rows.map { row in
                let name = row.receiver?.name ?? row.saved?.name ?? "TV"
                let state = (row.online ? "On" : "Not seen now") + (row.saved != nil ? " · paired" : " · new: compare a code to pair")
                return (name, state + (row.receiver?.id == s.choices.lastTV ? " · chosen" : ""))
            }))
            for row in rows {
                guard let r = row.receiver else { continue }
                if !s.busy && rows.count > 1 && r.id != s.choices.lastTV {
                    blocks.append(.button("Use \(r.name)", tool: "choose_tv", input: ["tv": r.id], symbol: "tv"))
                }
                if row.saved != nil && !(s.busy && s.receiver?.id == r.id) {
                    blocks.append(.button("Forget \(r.name)", tool: "forget_tv", input: ["tv": r.id], style: .secondary))
                }
            }
        }
        blocks.append(.button("Look again", tool: "find_tvs", symbol: "arrow.clockwise"))
        if let problem = s.discovery.problem { blocks.append(.note(problem, tone: .warn)) }
        return Section("TVs", blocks)
    }

    // MARK: What to share, and how

    static func share(_ s: Session, windows: [Screens.Window]?) -> [Section] {
        let tv = s.tv(named: nil)
        var what: [Block] = []
        if tv == nil { what.append(.note("Choose a TV first: none is on or paired yet.")) }
        let idle = !s.busy && tv != nil
        for d in Screens.displays() {
            what.append(.button("Share \(d.name)", tool: "share_screen", input: ["display": Int(d.id)], style: idle ? .primary : .secondary, symbol: "display"))
        }
        if let windows {
            if windows.isEmpty { what.append(.note("No window to share is open.")) }
            for w in windows.prefix(10) { what.append(.button(w.name, tool: "share_screen", input: ["window_id": Int(w.id)], symbol: "macwindow")) }
        } else {
            what.append(.button("Show windows to share", tool: "list_windows", symbol: "macwindow.on.rectangle"))
        }
        for (name, label) in [("left", "Left half"), ("right", "Right half"), ("center", "Middle (16:9)")] {
            what.append(.button(label, tool: "share_screen", input: ["area": name], symbol: "rectangle.dashed"))
        }
        if let tv { what.insert(.note("To \(tv.name). Sidefolk asks macOS for screen recording the first time."), at: 0) }

        let current = s.choices.preset
        var how: [Block] = CaptureQuality.allCases.map { q in
            .button(q.label, tool: "set_option", input: ["option": "quality", "value": q.rawValue], style: q == current ? .primary : .secondary)
        }
        how.append(.toggle("The Mac's sound on the TV", detail: "Captured from this Mac, never the microphone. It keeps playing here too.",
                           on: s.choices.sound, tool: "set_option", input: ["option": "sound"]))
        how.append(.toggle("Picture detail first", detail: "Off: smoother motion, softer picture when the network is busy.",
                           on: s.choices.detail, tool: "set_option", input: ["option": "detail"]))
        how.append(.toggle("No bigger than the TV's own size", detail: "Saves the network when the TV's app shows less than 1080p.",
                           on: s.choices.followTV, tool: "set_option", input: ["option": "follow_tv"]))
        return [Section("Share", what), Section("Quality", how)]
    }

    // MARK: Words

    static func spaced(_ code: String) -> String { code.count == 6 ? "\(code.prefix(3)) \(code.suffix(3))" : code }

    static func clock(_ seconds: Double) -> String {
        let t = Int(max(0, seconds))
        return t >= 3600 ? String(format: "%d:%02d:%02d", t / 3600, t / 60 % 60, t % 60) : String(format: "%d:%02d", t / 60, t % 60)
    }

    /// For a tool's answer: what is happening, in one sentence.
    static func sentence(_ s: Session) -> String {
        let line = summary(s)
        return line.detail.isEmpty ? line.title + "." : "\(line.title): \(line.detail)."
    }
}
