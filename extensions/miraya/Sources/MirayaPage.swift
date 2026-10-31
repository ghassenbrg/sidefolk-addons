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
    static var areas: [(name: String, label: String)] { [("left", L("Left half")), ("right", L("Right half")), ("center", L("Middle, 16:9"))] }

    /// "the left half of the built-in display", for answers and the hero: a whole phrase per area, so each language
    /// words it its own way.
    static func areaName(_ area: String, of display: String) -> String {
        // English writes a display's name in a sentence in lower case ("the built-in display"); other languages keep it.
        let d = Language.code == "en" ? display.lowercased() : display
        switch area {
        case "left": return L("the left half of the {display}", ["display": d])
        case "right": return L("the right half of the {display}", ["display": d])
        case "top": return L("the top half of the {display}", ["display": d])
        case "bottom": return L("the bottom half of the {display}", ["display": d])
        default: return L("the middle of the {display}", ["display": d])
        }
    }

    /// "the built-in display", or "your screen" when it's the only one.
    static func displayPhrase(_ name: String, only: Bool) -> String {
        only ? L("your screen") : L("the {display}", ["display": Language.code == "en" ? name.lowercased() : name])
    }

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
        /// Pictures by what they show (`display:1`), in the data folder.
        var shots: [String: String] = [:]

        var busy: Bool { phase != .idle }
        var tvName: String { tv?.name ?? L("the TV") }
    }

    static func now(_ s: Session, windows: [Screens.Window]?, shots: [String: String], canRecord: Bool) -> Now {
        let rows = s.tvs.map { row in
            Now.TV(id: row.receiver?.id ?? row.saved?.id ?? "", name: row.receiver?.name ?? row.saved?.name ?? L("TV"), online: row.online, paired: row.saved != nil)
        }
        let current = s.receiver.map { r in rows.first { $0.id == r.id } ?? Now.TV(id: r.id, name: r.name, online: true, paired: false) }
        let chosen = s.tv(named: nil).flatMap { r in rows.first { $0.id == r.id } }
        return Now(phase: s.phase, mode: s.mode, tv: s.busy ? current : chosen, tvs: rows, pairingCode: s.pairingCode, problem: s.problem,
                   note: s.note, discoveryProblem: s.discovery.problem, target: s.target, startedAt: s.startedAt, fps: s.tvFPS, rttMs: s.rttMs,
                   picture: s.picture, bitrate: s.bitrate, drops: s.tvDrops, mediaTitle: s.media?.title ?? "", mediaState: s.mediaState,
                   position: s.mediaPosition, duration: s.mediaDuration, seekable: s.mediaSeekable, choices: s.choices,
                   displays: Screens.displays(), windows: windows, canRecord: canRecord, shots: shots)
    }

    static func make(_ n: Now) -> Page {
        let top = Section(nil, [.hero(hero(n))])
        switch n.phase {
        case .pairing, .connecting, .reconnecting, .authorizing, .starting:
            // One thing at a time: the code to compare, or what the TV is doing.
            return Page(summary: summary(n), sections: [top])
        case .sharing, .pausing, .paused:
            if n.mode == .media { return Page(summary: summary(n), sections: [top, Section(nil, [.transport(transport(n))]), tvs(n)]) }
            return Page(summary: summary(n), sections: [top, tvs(n), picture(n, live: true), more(n), connection(n)])
        case .idle:
            return Page(summary: summary(n), sections: [top, tvs(n), what(n), picture(n, live: false), more(n), play(n)])
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
            return (["area": area.name, "display": Int(display.id)], "area:\(area.name)", areaName(area.name, of: displayName(display)))
        default:
            guard let display else { return nil }
            return (["display": Int(display.id)], "display:\(display.id)", displayPhrase(displayName(display), only: n.displays.count <= 1))
        }
    }

    static func start(_ n: Now) -> Action? {
        guard let source = source(n) else { return nil }
        return Action(L("Start sharing"), tool: "share_screen", input: source.input, style: .primary, symbol: "play.fill")
    }

    // MARK: The line on the Today tile and beside the sidebar row, with the main button

    static func summary(_ n: Now) -> Summary {
        let tv = n.tvName
        switch n.phase {
        case .idle:
            guard let chosen = n.tv else {
                return Summary(L("Miraya found no TV"), detail: L("Open Miraya on your Android TV, on the same network as this Mac."), tone: .neutral, symbol: "tv")
            }
            guard chosen.online else { return Summary(L("{tv} isn't on", ["tv": tv]), detail: L("Open Miraya on the TV to share to it."), tone: .neutral, symbol: "tv") }
            let on = n.tvs.filter(\.online)
            return Summary(L("Ready to share to {tv}", ["tv": tv]),
                           detail: on.count > 1 ? L("{count} TVs on: {tvs}", ["count": on.count, "tvs": Format.list(on.map(\.name))]) : L("{tv} is on", ["tv": tv]),
                           tone: .neutral, symbol: "tv", control: start(n).map { .action($0) })
        case .connecting: return Summary(L("Connecting to {tv}…", ["tv": tv]), tone: .info, symbol: "tv", control: .action(cancel))
        case .reconnecting:
            return Summary(L("Reconnecting to {tv}…", ["tv": tv]), detail: n.note ?? "", tone: .warn, symbol: "arrow.clockwise", control: .action(cancel))
        case .pairing:
            return Summary(L("Pairing code {code}", ["code": spaced(n.pairingCode)]), detail: L("Check {tv} shows the same six digits.", ["tv": tv]),
                           tone: .warn, symbol: "lock.shield")
        case .authorizing:
            return Summary(L("Choose Allow on {tv}", ["tv": tv]), detail: L("Miraya is waiting for the TV's remote."), tone: .warn, symbol: "hand.raised")
        case .starting:
            return Summary(n.mode == .media ? L("Starting the video on {tv}…", ["tv": tv]) : L("Starting to share to {tv}…", ["tv": tv]),
                           tone: .info, symbol: "tv", control: .action(cancel))
        case .sharing:
            if n.mode == .media {
                return Summary(L("Playing on {tv}", ["tv": tv]),
                               detail: n.mediaTitle + " · " + L("{position} of {duration}", ["position": clock(n.position), "duration": clock(n.duration)]),
                               tone: .good, symbol: "play.tv", control: .action(stop(L("Stop"))))
            }
            return Summary(L("Sharing {what} to {tv}", ["what": sharedName(n), "tv": tv]), detail: n.picture, tone: .good, symbol: "rectangle.on.rectangle",
                           control: .action(stop(L("Stop sharing"))))
        case .pausing, .paused:
            if n.mode == .media && n.mediaState == "ended" {
                return Summary(L("The video finished on {tv}", ["tv": tv]), detail: n.mediaTitle, tone: .neutral, symbol: "checkmark.circle",
                               control: .action(stop(L("Done"))))
            }
            return Summary(n.mode == .media ? L("Paused on {tv}", ["tv": tv]) : L("Sharing to {tv} is paused", ["tv": tv]), detail: n.mode == .media ? n.mediaTitle : "",
                           tone: .warn, symbol: "pause.circle", control: .action(stop(n.mode == .media ? L("Stop") : L("Stop sharing"))))
        }
    }

    static var cancel: Action { Action(L("Cancel"), tool: "stop", symbol: "xmark") }
    static func stop(_ label: String) -> Action { Action(label, tool: "stop", style: .destructive, symbol: "stop.fill") }

    // MARK: What is happening now

    static func hero(_ n: Now) -> Hero {
        let tv = n.tvName
        switch n.phase {
        case .idle:
            guard let chosen = n.tv else {
                return Hero(L("No TV found yet"), eyebrow: L("Looking for TVs"), detail: n.discoveryProblem
                                ?? L("Open Miraya on your Android TV, on the same network as this Mac. It shows up here by its room name."),
                            tone: n.discoveryProblem == nil ? .neutral : .warn, symbol: "tv", busy: n.discoveryProblem == nil,
                            actions: [Action(L("Look again"), tool: "find_tvs", style: .primary, symbol: "arrow.clockwise")])
            }
            let source = source(n)
            let what = source?.label ?? L("a window")
            var detail = "\(qualityName(n.choices.preset)), \(n.choices.preset.label) · " + (n.choices.sound ? L("sound on the TV too") : L("sound stays on this Mac"))
            var eyebrow = L("Ready"), tone = Tone.good
            if !chosen.online { eyebrow = L("{tv} isn't on now", ["tv": tv]); tone = .warn; detail = L("Open Miraya on the TV, then share.") + " " + detail }
            else if !chosen.paired { eyebrow = L("New TV"); tone = .info; detail += ". " + L("The first time, you compare a six-digit code with the TV.") }
            var start = start(n) ?? Action(L("Start sharing"), tool: "share_screen", style: .primary, symbol: "play.fill",
                                           detail: L("Choose a window to share first."), disabled: true)
            if let problem = n.problem {
                eyebrow = L("Couldn't share"); tone = .bad; detail = problem
                start.label = L("Try again")
            }
            return Hero(L("Share {what} to {tv}", ["what": what, "tv": tv]), eyebrow: eyebrow, detail: detail, tone: tone, symbol: "tv",
                        image: source.flatMap { n.shots[$0.key] }, actions: [start])
        case .pairing:
            return Hero(L("Compare with {tv}", ["tv": tv]), eyebrow: L("Verify the TV"),
                        detail: L("Make sure these six digits match the ones on the TV. If they don't, cancel: something else may be answering for your TV."),
                        tone: .warn, symbol: "lock.shield", code: n.pairingCode.isEmpty ? nil : spaced(n.pairingCode),
                        actions: n.pairingCode.isEmpty ? [cancel]
                            : [Action(L("Codes match · Pair"), tool: "confirm_pairing", style: .primary, symbol: "checkmark.shield"), cancel])
        case .authorizing:
            return Hero(L("Choose Allow on {tv}", ["tv": tv]), eyebrow: L("Waiting for the TV"), detail: L("Use the TV's remote. Next time this Mac connects without a code."),
                        tone: .info, symbol: "hand.raised", busy: true, actions: [cancel])
        case .connecting, .reconnecting, .starting:
            let title = n.phase == .connecting ? L("Connecting to {tv}…", ["tv": tv]) : n.phase == .reconnecting ? L("Reconnecting to {tv}…", ["tv": tv])
                : n.mode == .media ? L("Opening the video on {tv}…", ["tv": tv]) : L("Starting to share to {tv}…", ["tv": tv])
            return Hero(title, eyebrow: n.phase == .reconnecting ? L("Reconnecting") : L("Connecting"),
                        detail: n.note ?? (n.mode == .media ? L("The TV is opening the video.") : L("Getting the TV and a direct video connection ready.")),
                        tone: n.phase == .reconnecting ? .warn : .info, symbol: "tv", busy: true, actions: [cancel])
        case .sharing, .pausing, .paused:
            let paused = n.phase != .sharing
            if n.mode == .media {
                let ended = n.mediaState == "ended"
                return Hero(n.mediaTitle.isEmpty ? L("A video") : n.mediaTitle,
                            eyebrow: ended ? L("Finished") : paused ? L("Paused on the TV") : L("Playing on the TV"),
                            detail: L("On {tv}", ["tv": tv]) + (n.picture.isEmpty ? "" : " · \(n.picture)") + ". " + L("The TV plays the original file; nothing is recorded."),
                            tone: ended ? .neutral : paused ? .warn : .good, symbol: "play.tv", actions: [stop(ended ? L("Done") : L("Stop"))])
            }
            var facts: [(String, String)] = []
            if n.fps > 0 { facts.append((L("On the TV"), "\(Format.integer(Int(n.fps.rounded()))) fps")) }
            if n.rttMs > 0 { facts.append((L("Delay"), "\(Format.integer(Int(n.rttMs.rounded()))) ms")) }
            if !n.picture.isEmpty { facts.append((L("Picture"), n.picture)) }
            facts.append((L("Sound"), n.choices.sound ? L("On the TV") : L("This Mac only")))
            let since = n.startedAt.map { " " + L("Since {time}.", ["time": Format.time($0)]) } ?? ""
            return Hero(paused ? L("Sharing to {tv} is paused", ["tv": tv]) : L("Sharing {what} to {tv}", ["what": sharedName(n), "tv": tv]),
                        eyebrow: paused ? L("Paused") : L("Sharing · live"),
                        detail: paused ? L("The TV may keep showing the last picture. Nothing new reaches it until you resume.")
                            : L("Change the picture or sound below while you watch.") + since,
                        tone: paused ? .warn : .good, symbol: paused ? "pause.circle" : "rectangle.on.rectangle",
                        image: n.target.flatMap(targetKey).flatMap { n.shots[$0] }, facts: paused ? [] : facts,
                        actions: paused ? [Action(L("Resume"), tool: "resume", style: .primary, symbol: "play.fill"), stop(L("Stop sharing"))]
                            : [Action(L("Pause"), tool: "pause", symbol: "pause.fill"), stop(L("Stop sharing"))])
        }
    }

    static func targetKey(_ t: Session.Target) -> String? {
        switch t.kind {
        case .display: return "display:\(t.displayID)"
        case .window: return t.windowID.map { "window:\($0)" }
        case .area: return nil
        }
    }

    static func sharedName(_ n: Now) -> String {
        guard let t = n.target else { return L("your screen") }
        switch t.kind {
        case .display: return displayPhrase(t.label, only: n.displays.count <= 1)
        case .window: return t.label.components(separatedBy: " · ")[0]
        case .area: return t.label
        }
    }

    // MARK: Playing a video

    static func transport(_ n: Now) -> Transport {
        let paused = n.phase != .sharing || n.mediaState == "paused"
        var buttons: [Action] = []
        if n.seekable { buttons.append(Action(L("Back 30 seconds"), tool: "seek", input: ["seconds": -30], symbol: "gobackward.30")) }
        buttons.append(paused ? Action(L("Play"), tool: "resume", style: .primary, symbol: "play.fill") : Action(L("Pause"), tool: "pause", style: .primary, symbol: "pause.fill"))
        if n.seekable { buttons.append(Action(L("Forward 30 seconds"), tool: "seek", input: ["seconds": 30], symbol: "goforward.30")) }
        let state: Transport.State = n.mediaState == "ended" ? .stopped : ["buffering", "preparing", "loading"].contains(n.mediaState) ? .buffering
            : paused ? .paused : .playing
        return Transport(title: nil, detail: n.mediaState.isEmpty ? nil : mediaWord(n.mediaState), position: n.position,
                         duration: n.duration > 0 ? n.duration : nil, state: state, buttons: buttons)
    }

    static func play(_ n: Now) -> Section {
        Section(L("Play a video on the TV"), [
            .field(L("Play a link"), detail: L("An https link to the video file or stream itself, not a web page. The TV plays the original."),
                   placeholder: "https://example.com/film.mp4", button: L("Play on TV"), tool: "play_on_tv", key: "url"),
            // What to say stays English: Sidefolk understands typed requests in English (its GLOSSARY, rule 1).
            .note(L("A file on this Mac: drop it on your companion and say “play this on the TV”, or say “play ~/Movies/film.mp4 on the TV”. Subtitles: an .srt or .vtt file beside it.")),
        ], collapsed: true)
    }

    // MARK: TVs

    static func tvs(_ n: Now) -> Section {
        var blocks: [Block] = []
        // Without a TV the hero says how to find one and looks again; here, only the address.
        if !n.tvs.isEmpty {
            let options = n.tvs.map { tv in
                Option(tv.id, tv.name, detail: tv.online ? (tv.paired ? L("Paired · on now") : L("On now · not paired yet")) : L("Paired · not seen now"),
                       symbol: "tv", badge: tv.online ? (tv.paired ? Badge(L("Paired"), tone: .good) : Badge(L("New"), tone: .info)) : Badge(L("Off")),
                       action: tv.paired && !n.busy ? Action(L("Forget"), tool: "forget_tv", input: ["tv": tv.id], style: .plain,
                                                             detail: L("Forget this TV on this Mac; pairing again needs a new code.")) : nil)
            }
            blocks.append(.picker(L("Share to"), detail: n.busy ? L("Stop first to change the TV.") : nil, style: .rows, options, selected: n.tv?.id ?? "",
                                  tool: "choose_tv", key: "tv", disabled: n.busy))
        }
        if let problem = n.discoveryProblem, n.tv != nil { blocks.append(.note(problem, tone: .warn)) }
        if !n.busy {
            if !n.tvs.isEmpty { blocks.append(.action(Action(L("Look again"), tool: "find_tvs", style: .plain, symbol: "arrow.clockwise"))) }
            blocks.append(.field(L("Not in the list?"), detail: L("Type the address Miraya shows on the TV."), placeholder: "192.168.1.20",
                                 button: L("Pair"), tool: "pair_tv", key: "tv"))
        }
        return Section(L("TVs"), blocks, place: .side)
    }

    // MARK: What to share

    static func what(_ n: Now) -> Section {
        let kind = n.choices.kind ?? "display"
        var blocks: [Block] = [.picker(L("Share"), style: .segmented,
                                       [Option("display", L("A screen")), Option("window", L("A window")), Option("area", L("Part of a screen"))],
                                       selected: kind, tool: "set_option", input: ["option": "kind"])]
        let picked = source(n).map { String($0.key.split(separator: ":")[1]) } ?? ""
        switch kind {
        case "window":
            if let windows = n.windows, !windows.isEmpty {
                let options = windows.prefix(maxWindows).map { w in
                    Option("\(w.id)", w.app, detail: w.title.isEmpty ? nil : w.title, image: n.shots["window:\(w.id)"], symbol: "macwindow")
                }
                blocks.append(.picker(L("Window"), detail: L("Only this window goes to the TV, even while you use other apps. Its app's sound goes too."),
                                      style: .tiles, Array(options), selected: picked, tool: "set_option", input: ["option": "window"]))
            } else if n.windows != nil {
                blocks.append(.note(L("No window to share is open.")))
            } else {
                blocks.append(.note(L("To list the windows, macOS needs to let Sidefolk record the screen (Miraya runs inside Sidefolk)."), tone: .info))
                blocks.append(.action(Action(L("Show windows"), tool: "list_windows", style: .secondary, symbol: "macwindow.on.rectangle")))
            }
        case "area":
            let main = n.displays.first { $0.id == CGMainDisplayID() } ?? n.displays.first
            let display = n.displays.first { $0.id == n.choices.display } ?? main
            let options = areas.map { a in
                Option(a.name, a.label, detail: display.map(displayName), image: n.shots["area:\(a.name)"], symbol: "rectangle.dashed")
            }
            blocks.append(.picker(L("Part"), detail: L("Handy for one app beside another, or a video playing in the middle."), style: .tiles, options,
                                  selected: picked, tool: "set_option", input: ["option": "area"]))
        default:
            let options = n.displays.map { d in
                Option("\(d.id)", displayName(d), detail: d.name.components(separatedBy: " · ").dropFirst().first, image: n.shots["display:\(d.id)"], symbol: "display")
            }
            if !options.isEmpty {
                blocks.append(.picker(L("Screen"), style: .tiles, options, selected: picked, tool: "set_option", input: ["option": "display"]))
            }
        }
        if !n.canRecord && kind != "window" {
            blocks.append(.note(L("Pictures of your screens show here once macOS lets Sidefolk record the screen: System Settings › Privacy & Security › Screen & System Audio Recording. Sharing the first time asks."), tone: .info))
        }
        return Section(L("What to share"), blocks)
    }

    static func displayName(_ d: Screens.Display) -> String { d.name.components(separatedBy: " · ")[0] }

    // MARK: Picture and sound

    static var presets: [(CaptureQuality, String)] {
        [(.lowBandwidth, L("Slow network")), (.efficient, L("Efficient")), (.efficientMotion, L("Efficient motion")), (.balanced, L("Balanced")),
         (.motion, L("Smooth motion"))]
    }
    static func qualityName(_ q: CaptureQuality) -> String { presets.first { $0.0 == q }?.1 ?? q.label }

    static func picture(_ n: Now, live: Bool) -> Section {
        Section(L("Picture & sound"), [
            .picker(L("Quality"), detail: live ? L("Changes while you share: the TV shows the new picture in a moment.") : L("The most the TV gets; the TV's own size can lower it."),
                    style: .cards, presets.map { Option($0.0.rawValue, $0.1, detail: $0.0.label) }, selected: n.choices.quality,
                    tool: "set_option", input: ["option": "quality"]),
            .toggle(L("Play the Mac's sound on the TV"), detail: L("Only what this Mac plays, never the microphone. It keeps playing here too."),
                    on: n.choices.sound, tool: "set_option", input: ["option": "sound"]),
        ])
    }

    static func more(_ n: Now) -> Section {
        Section(L("More picture settings"), [
            .toggle(L("Picture detail first"), detail: L("Off: smoother motion, softer picture when the network is busy."),
                    on: n.choices.detail, tool: "set_option", input: ["option": "detail"]),
            .toggle(L("No bigger than the TV's own size"), detail: L("Saves the network when the TV's app shows less than 1080p."),
                    on: n.choices.followTV, tool: "set_option", input: ["option": "follow_tv"]),
        ], collapsed: true)
    }

    static func connection(_ n: Now) -> Section {
        var facts: [(String, String)] = [(L("TV"), n.tvName), (L("Sharing"), n.target?.label ?? L("Your screen"))]
        if n.bitrate > 0 { facts.append((L("Sending"), Format.number(n.bitrate / 1_000_000) + " Mb/s")) }
        if n.rttMs > 0 { facts.append((L("Network round trip"), "\(Format.integer(Int(n.rttMs.rounded()))) ms")) }
        facts.append((L("Frames dropped on the TV"), Format.integer(n.drops)))
        facts.append((L("Connection"), L("Direct and encrypted, on your network")))
        return Section(L("Connection details"), [.facts(nil, facts)], collapsed: true)
    }

    // MARK: Words

    /// The TV's word for what the video is doing, in the person's language.
    static func mediaWord(_ state: String) -> String {
        switch state {
        case "playing": L("Playing")
        case "paused": L("Paused")
        case "buffering", "loading", "preparing": L("Loading")
        case "ended": L("Finished")
        default: state.capitalized
        }
    }

    static func spaced(_ code: String) -> String { code.count == 6 ? "\(code.prefix(3)) \(code.suffix(3))" : code }

    static func clock(_ seconds: Double) -> String {
        let t = Int(max(0, seconds))
        return t >= 3600 ? String(format: "%d:%02d:%02d", t / 3600, t / 60 % 60, t % 60) : String(format: "%d:%02d", t / 60, t % 60)
    }

    /// For a tool's answer: what is happening, in one sentence.
    static func sentence(_ s: Session) -> String {
        let line = summary(now(s, windows: nil, shots: [:], canRecord: false))
        return line.detail.isEmpty ? line.title + "." : L("{title}: {detail}.", ["title": line.title, "detail": line.detail])
    }
}
