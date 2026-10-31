import Foundation
import CoreGraphics
import SidefolkExtensionKit

/// Miraya's page, laid out like Miraya's own Mac app: what is happening now on top with the one thing to do (Start
/// sharing, the code to compare, Stop sharing), the TVs beside it with their state and the one chosen, what to share
/// as pictures of the displays and windows, and the picture and sound as cards and switches. Each state has its own
/// page: no TV, ready, pairing, waiting for the TV, sharing, paused, a video playing. It says only what is true: a TV
/// is "on" when it answers on the network now, sharing is "live" once the TV reported a picture.
@MainActor
enum MirayaPage {
    static let maxWindows = 12
    static let areas: [(name: String, label: String)] = [("left", "Left half"), ("right", "Right half"), ("center", "Middle, 16:9")]

    /// Everything the page shows, read from the session at one moment, so each state can be drawn (and tested) alone.
    struct Now {
        struct TV { var id: String; var name: String; var online: Bool; var paired: Bool }

        var phase = Session.Phase.idle
        var mode = Session.Mode.mirror
        /// The TV in use, or the one sharing would go to.
        var tv: TV?
        var tvs: [TV] = []
        var pairingCode = ""
        var problem: String?
        var note: String?
        var discoveryProblem: String?
        var target: Session.Target?
        var startedAt: Date?
        var fps = 0.0
        var rttMs = 0.0
        var picture = ""
        var bitrate = 0.0
        var drops = 0
        var mediaTitle = ""
        var mediaState = ""
        var position = 0.0
        var duration = 0.0
        var seekable = false
        var choices = Choices()
        var displays: [Screens.Display] = []
        /// nil: not listed yet (macOS hasn't let Sidefolk record, or nobody picked Window).
        var windows: [Screens.Window]?
        var canRecord = false
        var audioConfirmed = false
        var audioPending = false
        /// Pictures by what they show (`display:1`), in the data folder.
        var shots: [String: String] = [:]

        var busy: Bool { phase != .idle }
        var tvName: String { tv?.name ?? "the TV" }
    }

    static func now(_ s: Session, windows: [Screens.Window]?, shots: [String: String], canRecord: Bool) -> Now {
        let rows = s.tvs.map { row in
            Now.TV(id: row.receiver?.id ?? row.saved?.id ?? "", name: row.receiver?.name ?? row.saved?.name ?? "TV", online: row.online, paired: row.saved != nil)
        }
        let current = s.receiver.map { r in rows.first { $0.id == r.id } ?? Now.TV(id: r.id, name: r.name, online: true, paired: false) }
        let chosen = s.tv(named: nil).flatMap { r in rows.first { $0.id == r.id } }
        return Now(phase: s.phase, mode: s.mode, tv: s.busy ? current : chosen, tvs: rows, pairingCode: s.pairingCode, problem: s.problem,
                   note: s.note, discoveryProblem: s.discovery.problem, target: s.target, startedAt: s.startedAt, fps: s.tvFPS, rttMs: s.rttMs,
                   picture: s.picture, bitrate: s.bitrate, drops: s.tvDrops, mediaTitle: s.media?.title ?? "", mediaState: s.mediaState,
                   position: s.mediaPosition, duration: s.mediaDuration, seekable: s.mediaSeekable, choices: s.choices,
                   displays: Screens.displays(), windows: windows, canRecord: canRecord,
                   audioConfirmed: s.audioRouting.confirmed, audioPending: s.audioRouting.pending, shots: shots)
    }

    static func make(_ n: Now) -> Page {
        let top = Section(nil, [.hero(hero(n))])
        switch n.phase {
        case .pairing, .connecting, .reconnecting, .authorizing, .starting:
            // One thing at a time: the code to compare, or what the TV is doing.
            return Page(summary: summary(n), sections: [top])
        case .sharing, .pausing, .paused:
            if n.mode == .media { return Page(summary: summary(n), sections: [top, Section(nil, [.transport(transport(n))])]) }
            return Page(summary: summary(n), sections: [top, picture(n, live: true), more(n), connection(n)])
        case .idle:
            if n.tv == nil { return Page(summary: summary(n), sections: [top, tvs(n)]) }
            return Page(summary: summary(n), sections: [top, tvs(n), what(n), picture(n, live: false), more(n), play(n), address()])
        }
    }

    // MARK: What sharing would take, and the tool that starts it

    /// What the page has picked to share, as `share_screen` takes it, its key among the pictures, and its name.
    static func source(_ n: Now) -> (input: [String: Any], key: String, label: String)? {
        let main = n.displays.first { $0.id == CGMainDisplayID() } ?? n.displays.first
        let display = n.displays.first { $0.id == n.choices.display } ?? main
        switch n.choices.kind ?? "display" {
        case "window":
            guard let windows = n.windows, let w = windows.first(where: { $0.id == n.choices.window }) ?? windows.first else { return nil }
            return (["window_id": Int(w.id)], "window:\(w.id)", w.app)
        case "area":
            guard let display else { return nil }
            let area = areas.first { $0.name == n.choices.area } ?? areas[2]
            let part = area.name == "center" ? "middle" : area.label.lowercased()
            return (["area": area.name, "display": Int(display.id)], "area:\(area.name)", "the \(part) of the \(displayName(display).lowercased())")
        default:
            guard let display else { return nil }
            return (["display": Int(display.id)], "display:\(display.id)", n.displays.count > 1 ? "the " + displayName(display).lowercased() : "your screen")
        }
    }

    static func start(_ n: Now) -> Action? {
        guard let source = source(n) else { return nil }
        return Action("Start sharing", tool: "share_screen", input: source.input, style: .primary, symbol: "play.fill")
    }

    // MARK: The line on the Today tile and beside the sidebar row, with the main button

    static func summary(_ n: Now) -> Summary {
        let tv = n.tvName
        switch n.phase {
        case .idle:
            guard let chosen = n.tv else {
                return Summary("Miraya found no TV", detail: "Open Miraya on your Android TV, on the same network as this Mac.", tone: .neutral, symbol: "tv")
            }
            guard chosen.online else { return Summary("\(tv) isn't on", detail: "Open Miraya on the TV to share to it.", tone: .neutral, symbol: "tv") }
            let on = n.tvs.filter(\.online)
            return Summary("Ready to share to \(tv)", detail: on.count > 1 ? "\(on.count) TVs on: \(on.map(\.name).joined(separator: ", "))" : "\(tv) is on",
                           tone: .neutral, symbol: "tv", control: start(n).map { .action($0) })
        case .connecting: return Summary("Connecting to \(tv)…", tone: .info, symbol: "tv", control: .action(cancel))
        case .reconnecting: return Summary("Reconnecting to \(tv)…", detail: n.note ?? "", tone: .warn, symbol: "arrow.clockwise", control: .action(cancel))
        case .pairing: return Summary("Pairing code \(spaced(n.pairingCode))", detail: "Check \(tv) shows the same six digits.", tone: .warn, symbol: "lock.shield")
        case .authorizing: return Summary("Choose Allow on \(tv)", detail: "Miraya is waiting for the TV's remote.", tone: .warn, symbol: "hand.raised")
        case .starting:
            return Summary(n.mode == .media ? "Starting the video on \(tv)…" : "Starting to share to \(tv)…", tone: .info, symbol: "tv", control: .action(cancel))
        case .sharing:
            if n.mode == .media {
                return Summary("Playing on \(tv)", detail: "\(n.mediaTitle) · \(clock(n.position)) of \(clock(n.duration))", tone: .good, symbol: "play.tv",
                               control: .action(stop("Stop")))
            }
            return Summary("Sharing \(sharedName(n)) to \(tv)", detail: n.picture, tone: .good, symbol: "rectangle.on.rectangle",
                           control: .action(stop("Stop sharing")))
        case .pausing, .paused:
            if n.mode == .media && n.mediaState == "ended" {
                return Summary("The video finished on \(tv)", detail: n.mediaTitle, tone: .neutral, symbol: "checkmark.circle", control: .action(stop("Done")))
            }
            return Summary(n.mode == .media ? "Paused on \(tv)" : "Sharing to \(tv) is paused", detail: n.mode == .media ? n.mediaTitle : "",
                           tone: .warn, symbol: "pause.circle", control: .action(stop(n.mode == .media ? "Stop" : "Stop sharing")))
        }
    }

    static let cancel = Action("Cancel", tool: "stop", symbol: "xmark")
    static func stop(_ label: String) -> Action { Action(label, tool: "stop", style: .destructive, symbol: "stop.fill") }

    // MARK: What is happening now

    static func hero(_ n: Now) -> Hero {
        let tv = n.tvName
        switch n.phase {
        case .idle:
            guard let chosen = n.tv else {
                return Hero("No TV found yet", eyebrow: "Looking for TVs", detail: n.discoveryProblem
                                ?? "Open Miraya on your Android TV, on the same network as this Mac. It shows up here by its room name.",
                            tone: n.discoveryProblem == nil ? .neutral : .warn, symbol: "tv", busy: n.discoveryProblem == nil,
                            actions: [Action("Look again", tool: "find_tvs", style: .primary, symbol: "arrow.clockwise")])
            }
            let source = source(n)
            let what = source?.label ?? "a window"
            var detail = "\(qualityName(n.choices.preset)), \(n.choices.preset.label) · "
                + (n.audioPending ? "Updating sound…" : "Sound: \(n.choices.audio.label)")
            var eyebrow = "Ready", tone = Tone.good
            if !chosen.online { eyebrow = "\(tv) isn't on now"; tone = .warn; detail = "Open Miraya on the TV, then share. " + detail }
            else if !chosen.paired { eyebrow = "New TV"; tone = .info; detail += ". The first time, you compare a six-digit code with the TV." }
            var start = start(n) ?? Action("Start sharing", tool: "share_screen", style: .primary, symbol: "play.fill",
                                           detail: "Choose a window to share first.", disabled: true)
            if !chosen.online { start.disabled = true; start.detail = "Open Miraya on the TV first." }
            if let problem = n.problem {
                eyebrow = "Couldn't share"; tone = .bad; detail = problem
                start.label = "Try again"
            }
            return Hero("Share \(what) to \(tv)", eyebrow: eyebrow, detail: detail, tone: tone, symbol: "tv", actions: [start])
        case .pairing:
            return Hero("Compare with \(tv)", eyebrow: "Verify the TV", detail: "Make sure these six digits match the ones on the TV. "
                            + "If they don't, cancel: something else may be answering for your TV.",
                        tone: .warn, symbol: "lock.shield", code: n.pairingCode.isEmpty ? nil : spaced(n.pairingCode),
                        actions: n.pairingCode.isEmpty ? [cancel]
                            : [Action("Codes match · Pair", tool: "confirm_pairing", style: .primary, symbol: "checkmark.shield"), cancel])
        case .authorizing:
            return Hero("Choose Allow on \(tv)", eyebrow: "Waiting for the TV", detail: "Use the TV's remote. Next time this Mac connects without a code.",
                        tone: .info, symbol: "hand.raised", busy: true, actions: [cancel])
        case .connecting, .reconnecting, .starting:
            let title = n.phase == .connecting ? "Connecting to \(tv)…" : n.phase == .reconnecting ? "Reconnecting to \(tv)…"
                : n.mode == .media ? "Opening the video on \(tv)…" : "Starting to share to \(tv)…"
            return Hero(title, eyebrow: n.phase == .reconnecting ? "Reconnecting" : "Connecting",
                        detail: n.note ?? (n.mode == .media ? "The TV is opening the video." : "Getting the TV and a direct video connection ready."),
                        tone: n.phase == .reconnecting ? .warn : .info, symbol: "tv", busy: true, actions: [cancel])
        case .sharing, .pausing, .paused:
            let paused = n.phase != .sharing
            if n.mode == .media {
                let ended = n.mediaState == "ended"
                return Hero(n.mediaTitle.isEmpty ? "A video" : n.mediaTitle, eyebrow: ended ? "Finished" : paused ? "Paused on the TV" : "Playing on the TV",
                            detail: "On \(tv)" + (n.picture.isEmpty ? "" : " · \(n.picture)") + ". The TV plays the original file; nothing is recorded.",
                            tone: ended ? .neutral : paused ? .warn : .good, symbol: "play.tv", actions: [stop(ended ? "Done" : "Stop")])
            }
            var facts: [(String, String)] = []
            if n.fps > 0 { facts.append(("On the TV", "\(Int(n.fps.rounded())) fps")) }
            if n.rttMs > 0 { facts.append(("Network round trip", "\(Int(n.rttMs.rounded())) ms")) }
            if !n.picture.isEmpty { facts.append(("Picture", n.picture)) }
            let sound = n.audioPending || (n.choices.audio == .tv && !n.audioConfirmed) ? "Routing…" : n.choices.audio.label
            facts.append(("Sound", sound))
            let since = n.startedAt.map { " Since \($0.formatted(date: .omitted, time: .shortened))." } ?? ""
            return Hero(paused ? "Sharing to \(tv) is paused" : "Sharing \(sharedName(n)) to \(tv)",
                        eyebrow: paused ? "Paused" : "Sharing · live",
                        detail: paused ? "The TV may keep showing the last picture. Nothing new reaches it until you resume."
                            : (n.note ?? "Change the picture or sound below while you watch.") + since,
                        tone: paused ? .warn : .good, symbol: paused ? "pause.circle" : "rectangle.on.rectangle",
                        facts: paused ? [] : facts,
                        actions: paused ? [Action("Resume", tool: "resume", style: .primary, symbol: "play.fill"), stop("Stop sharing")]
                            : [Action("Pause", tool: "pause", symbol: "pause.fill"), stop("Stop sharing")])
        }
    }

    static func sharedName(_ n: Now) -> String {
        guard let t = n.target else { return "your screen" }
        switch t.kind {
        case .display: return n.displays.count > 1 ? "the " + t.label.lowercased() : "your screen"
        case .window: return t.label.components(separatedBy: " · ")[0]
        case .area: return t.label
        }
    }

    // MARK: Playing a video

    static func transport(_ n: Now) -> Transport {
        let paused = n.phase != .sharing || n.mediaState == "paused"
        var buttons: [Action] = []
        if n.seekable { buttons.append(Action("Back 30 seconds", tool: "seek", input: ["seconds": -30], symbol: "gobackward.30")) }
        buttons.append(paused ? Action("Play", tool: "resume", style: .primary, symbol: "play.fill") : Action("Pause", tool: "pause", style: .primary, symbol: "pause.fill"))
        if n.seekable { buttons.append(Action("Forward 30 seconds", tool: "seek", input: ["seconds": 30], symbol: "goforward.30")) }
        let state: Transport.State = n.mediaState == "ended" ? .stopped : ["buffering", "preparing", "loading"].contains(n.mediaState) ? .buffering
            : paused ? .paused : .playing
        return Transport(title: nil, detail: n.mediaState.isEmpty ? nil : n.mediaState.capitalized, position: n.position,
                         duration: n.duration > 0 ? n.duration : nil, state: state, buttons: buttons)
    }

    static func play(_ n: Now) -> Section {
        Section("Play a video on the TV", [
            .field("Play a link", detail: "An https link to the video file or stream itself, not a web page. The TV plays the original.",
                   placeholder: "https://example.com/film.mp4", button: "Play on TV", tool: "play_on_tv", key: "url"),
            .note("A file on this Mac: drop it on your companion and say “play this on the TV”, or say “play ~/Movies/film.mp4 on the TV”. "
                + "Subtitles: an .srt or .vtt file beside it."),
        ], collapsed: true)
    }

    // MARK: TVs

    static func tvs(_ n: Now) -> Section {
        var blocks: [Block] = []
        // Without a TV the hero says how to find one and looks again; here, only the address.
        if !n.tvs.isEmpty {
            let options = n.tvs.map { tv in
                Option(tv.id, tv.name, detail: tv.online ? (tv.paired ? "Paired · on now" : "On now · not paired yet") : "Paired · not seen now",
                       symbol: "tv", badge: tv.online ? (tv.paired ? Badge("Paired", tone: .good) : Badge("New", tone: .info)) : Badge("Off"),
                       action: tv.paired && !n.busy ? Action("Forget", tool: "forget_tv", input: ["tv": tv.id], style: .plain,
                                                             detail: "Forget this TV on this Mac; pairing again needs a new code.") : nil)
            }
            blocks.append(.picker("Share to", detail: n.busy ? "Stop first to change the TV." : nil, style: .rows, options, selected: n.tv?.id ?? "",
                                  tool: "choose_tv", key: "tv", disabled: n.busy))
        }
        if let problem = n.discoveryProblem, n.tv != nil { blocks.append(.note(problem, tone: .warn)) }
        if !n.busy {
            if !n.tvs.isEmpty { blocks.append(.action(Action("Look again", tool: "find_tvs", style: .plain, symbol: "arrow.clockwise"))) }
            if n.tv == nil { blocks.append(addressField) }
        }
        return Section("TVs", blocks, place: n.tv == nil ? .main : .side)
    }

    static var addressField: Block {
        .field("TV address", detail: "Type the address Miraya shows on the TV.", placeholder: "192.168.1.20",
               button: "Pair", tool: "pair_tv", key: "tv")
    }

    static func address() -> Section {
        Section("Connect by address", [addressField], place: .bottom, collapsed: true)
    }

    // MARK: What to share

    static func what(_ n: Now) -> Section {
        let kind = n.choices.kind ?? "display"
        var blocks: [Block] = [.picker("Share", style: .segmented, [Option("display", "A screen"), Option("window", "A window"), Option("area", "Part of a screen")],
                                       selected: kind, tool: "set_option", input: ["option": "kind"])]
        let picked = source(n).map { String($0.key.split(separator: ":")[1]) } ?? ""
        switch kind {
        case "window":
            if let windows = n.windows, !windows.isEmpty {
                let options = windows.prefix(maxWindows).map { w in
                    Option("\(w.id)", w.app, detail: w.title.isEmpty ? nil : w.title, image: n.shots["window:\(w.id)"], symbol: "macwindow")
                }
                blocks.append(.picker("Window", detail: "Only this window goes to the TV, even while you use other apps. Its app's sound goes too.",
                                      style: .tiles, Array(options), selected: picked, tool: "set_option", input: ["option": "window"]))
            } else if n.windows != nil {
                blocks.append(.note("No window to share is open."))
            } else {
                blocks.append(.note("To list the windows, macOS needs to let Sidefolk record the screen (Miraya runs inside Sidefolk).", tone: .info))
                blocks.append(.action(Action("Show windows", tool: "list_windows", style: .secondary, symbol: "macwindow.on.rectangle")))
            }
        case "area":
            let main = n.displays.first { $0.id == CGMainDisplayID() } ?? n.displays.first
            let display = n.displays.first { $0.id == n.choices.display } ?? main
            if n.displays.count > 1 {
                let displays = n.displays.map { Option("\($0.id)", displayName($0), detail: $0.name.components(separatedBy: " · ").dropFirst().first) }
                blocks.append(.picker("Screen", style: .rows, displays, selected: display.map { "\($0.id)" } ?? "",
                                      tool: "set_option", input: ["option": "display"]))
            }
            let options = areas.map { a in
                Option(a.name, a.label, detail: display.map { "of the \(displayName($0).lowercased())" }, image: n.shots["area:\(a.name)"], symbol: "rectangle.dashed")
            }
            blocks.append(.picker("Part", detail: "Handy for one app beside another, or a video playing in the middle.", style: .tiles, options,
                                  selected: picked, tool: "set_option", input: ["option": "area"]))
        default:
            let options = n.displays.map { d in
                Option("\(d.id)", displayName(d), detail: d.name.components(separatedBy: " · ").dropFirst().first, image: n.shots["display:\(d.id)"], symbol: "display")
            }
            if !options.isEmpty {
                blocks.append(.picker("Screen", style: .tiles, options, selected: picked, tool: "set_option", input: ["option": "display"]))
            }
        }
        if !n.canRecord && kind != "window" {
            blocks.append(.note("Pictures of your screens show here once macOS lets Sidefolk record the screen: System Settings › Privacy & Security › "
                + "Screen & System Audio Recording. Sharing the first time asks.", tone: .info))
        }
        return Section("What to share", blocks)
    }

    static func displayName(_ d: Screens.Display) -> String { d.name.components(separatedBy: " · ")[0] }

    // MARK: Picture and sound

    static let presets: [(CaptureQuality, String)] = [(.lowBandwidth, "Slow network"), (.efficient, "Efficient"), (.efficientMotion, "Efficient motion"),
                                                       (.balanced, "Balanced"), (.motion, "Smooth motion")]
    static func qualityName(_ q: CaptureQuality) -> String { presets.first { $0.0 == q }?.1 ?? q.label }

    static func picture(_ n: Now, live: Bool) -> Section {
        Section("Picture & sound", [
            .picker("Quality", detail: live ? "Changes while you share: the TV shows the new picture in a moment." : "The most the TV gets; the TV's own size can lower it.",
                    style: .cards, presets.map { Option($0.0.rawValue, $0.1, detail: $0.0.label) }, selected: n.choices.quality,
                    tool: "set_option", input: ["option": "quality"]),
            .picker("Play system audio on", detail: "System audio only; the microphone is never shared. TV only temporarily mutes this Mac's entire output, including other apps.",
                    style: .cards, [Option("mac", "Mac only"), Option("tv", "TV only"), Option("both", "Mac and TV")],
                    selected: n.choices.audio.rawValue, tool: "set_option", input: ["option": "audio_destination"]),
        ], place: .bottom, collapsed: true,
           detail: "\(qualityName(n.choices.preset)) · \(n.choices.preset.label) · "
               + (n.audioPending ? "Updating sound…" : "Sound: \(n.choices.audio.label)"))
    }

    static func more(_ n: Now) -> Section {
        Section("More picture settings", [
            .toggle("Picture detail first", detail: "Off: smoother motion, softer picture when the network is busy.",
                    on: n.choices.detail, tool: "set_option", input: ["option": "detail"]),
            .toggle("No bigger than the TV's own size", detail: "Saves the network when the TV's app shows less than 1080p.",
                    on: n.choices.followTV, tool: "set_option", input: ["option": "follow_tv"]),
        ], place: .bottom, collapsed: true)
    }

    static func connection(_ n: Now) -> Section {
        var facts: [(String, String)] = [("TV", n.tvName), ("Sharing", n.target?.label ?? "Your screen")]
        if n.bitrate > 0 { facts.append(("Sending", String(format: "%.1f Mb/s", n.bitrate / 1_000_000))) }
        if n.rttMs > 0 { facts.append(("Network round trip", "\(Int(n.rttMs.rounded())) ms")) }
        facts.append(("Frames dropped on the TV", "\(n.drops)"))
        facts.append(("Connection", "Direct and encrypted, on your network"))
        return Section("Connection details", [.facts(nil, facts)], place: .bottom, collapsed: true)
    }

    // MARK: Words

    static func spaced(_ code: String) -> String { code.count == 6 ? "\(code.prefix(3)) \(code.suffix(3))" : code }

    static func clock(_ seconds: Double) -> String {
        let t = Int(max(0, seconds))
        return t >= 3600 ? String(format: "%d:%02d:%02d", t / 3600, t / 60 % 60, t % 60) : String(format: "%d:%02d", t / 60, t % 60)
    }

    /// For a tool's answer: what is happening, in one sentence.
    static func sentence(_ s: Session) -> String {
        let line = summary(now(s, windows: nil, shots: [:], canRecord: false))
        return line.detail.isEmpty ? line.title + "." : "\(line.title): \(line.detail)."
    }
}
