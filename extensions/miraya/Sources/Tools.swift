import Foundation
import CoreGraphics
import SidefolkExtensionKit

/// The tools' work: find the TV and what to share from what the person said, start it, and wait a moment to say how
/// it went (a code to compare, Allow on the TV, or a picture on it).
@MainActor
enum Tools {
    static func listing(in session: Session) -> String {
        let rows = session.tvs
        guard !rows.isEmpty else {
            return L("No TV running Miraya is on this network right now. Open Miraya on the TV; or pair by the address it shows.")
        }
        return rows.map { row in
            let name = row.receiver?.name ?? row.saved?.name ?? L("TV")
            switch (row.online, row.saved != nil) {
            case (true, true): return L("{tv}: on, paired", ["tv": name])
            case (true, false): return L("{tv}: on, not paired yet", ["tv": name])
            case (false, true): return L("{tv}: not seen now, paired", ["tv": name])
            case (false, false): return L("{tv}: not seen now, not paired yet", ["tv": name])
            }
        }.joined(separator: "\n")
    }

    static func tv(_ words: String?) throws -> Receiver { try tv(words, in: session) }

    /// The TV a call means: a paired TV's id (what Sidefolk binds a call it let through to, D72), an address, or a name.
    static func tv(_ words: String?, in session: Session) throws -> Receiver {
        if let words, let paired = session.saved.first(where: { $0.id == words.lowercased() }) {
            guard let tv = paired.receiver(found: session.found) else { throw Problem(L("{tv} isn't on now. Open Miraya on it.", ["tv": paired.name])) }
            return tv
        }
        if let words, let address = address(words, in: session) { return address }
        if let tv = session.tv(named: words) { return tv }
        if let words { throw Problem(L("No TV called “{tv}” is on. These are around:", ["tv": words]) + "\n" + listing(in: session)) }
        throw Problem(L("No TV running Miraya is on this network. Open Miraya on the TV, or pair by the address it shows."))
    }

    /// Which TV a call would reach, for Sidefolk to decide whether to ask the person (`sidefolk/paired.check`, D72):
    /// found exactly as the call finds it, and named only when it's one the person paired, whose pinned key the
    /// connection then demands. Sharing and playing reach the TV the call names; the rest act on what's on the TV now,
    /// which shares or plays only once the TV proved its key (or the person compared the code). Stopping gives a TV
    /// nothing, so it reaches no device in that sense.
    static func reach(_ tool: String, _ args: Arguments, in session: Session) -> Paired {
        switch tool {
        case "share_screen", "play_on_tv":
            guard let tv = try? tv(args.string("tv"), in: session), session.saved.contains(where: { $0.id == tv.id }) else { return .unpaired }
            return .device(tv.id)
        case "stop", "pause", "resume", "seek", "tv_volume":
            guard session.busy, let current = session.receiver else { return .nothing }
            if session.saved.contains(where: { $0.id == current.id }) { return .device(current.id) }
            return tool == "stop" ? .nothing : .unpaired
        default:
            return .unpaired
        }
    }

    /// "192.168.1.20" or "192.168.1.20:7421", or a host name with a dot or a port.
    static func address(_ words: String, in session: Session) -> Receiver? {
        let text = words.trimmingCharacters(in: .whitespaces)
        guard !text.contains(" "), !text.contains("/") else { return nil }
        let parts = text.split(separator: ":", maxSplits: 1).map(String.init)
        guard let host = parts.first, host.contains(".") || parts.count == 2, host.range(of: #"^[A-Za-z0-9.\-]+$"#, options: .regularExpression) != nil else { return nil }
        let port = parts.count == 2 ? UInt16(parts[1]) : 7421
        guard let port, port > 0 else { return nil }
        let known = session.saved.first { $0.host == host && ($0.port ?? 7421) == port }
        return known?.receiver(found: session.found) ?? Receiver.manual(host: host, port: port)
    }

    static func share(_ args: Arguments) async throws -> String {
        let tv = try tv(args.string("tv"))
        if let q = args.string("quality").flatMap(CaptureQuality.init(rawValue:)) { session.choices.quality = q.rawValue }
        if let sound = args.bool("sound") { session.choices.sound = sound }
        let target = try await target(args)
        try run { try session.share(target, to: tv) }
        return await outcome(of: .sharing(target.label))
    }

    static func target(_ args: Arguments) async throws -> Session.Target {
        let displays = Screens.displays()
        let display = args.int("display").flatMap { id in displays.first { Int($0.id) == id } }
            ?? displays.first { $0.id == CGMainDisplayID() } ?? displays.first
        guard let display else { throw Problem(L("No display is connected.")) }
        if args.int("window_id") != nil || args.string("window") != nil {
            let list: [Screens.Window]
            do { list = try await Screens.windows() } catch {
                throw Problem(L("macOS hasn't allowed Sidefolk to record the screen yet. Allow it in System Settings › Privacy & Security › Screen & System Audio Recording, then try again."))
            }
            windows = list
            let wanted = args.string("window")?.lowercased()
            guard let window = list.first(where: { Int($0.id) == args.int("window_id") })
                    ?? wanted.flatMap({ w in list.first { $0.name.lowercased().hasPrefix(w) } ?? list.first { $0.name.lowercased().contains(w) } }) else {
                throw Problem(L("No open window matches “{window}”. Open it, or choose one on Miraya's page.", ["window": args.string("window") ?? ""]))
            }
            return Session.Target(kind: .window, displayID: display.id, windowID: window.id, label: window.name)
        }
        if let area = args.string("area") {
            guard let region = Screens.region(area, of: display) else { throw Problem(L("Areas are left, right, top, bottom or center.")) }
            return Session.Target(kind: .area, displayID: display.id, region: region,
                                  label: MirayaPage.areaName(area, of: display.name.components(separatedBy: " · ")[0]))
        }
        return Session.Target(kind: .display, displayID: display.id, label: display.name.components(separatedBy: " · ")[0])
    }

    static func play(_ args: Arguments) async throws -> String {
        if let file = args.string("file") {
            // Here Sidefolk started a process for this call, with this file open to it: lend it to the main process.
            let inbox = Inbox(folder: data)
            let request: Inbox.Request
            do { request = try inbox.lend(file: try Paths.full(file), subtitle: try args.string("subtitles").map(Paths.full), url: nil, tv: args.string("tv")) }
            catch let failure as ConnectionFailure { throw Problem(Said.shown(failure.message)) }
            try inbox.post(request)
            guard let answer = await inbox.answer(request.id, within: 25) else {
                inbox.remove([request.file, request.subtitle].compactMap { $0 })
                throw Problem(L("Miraya isn't running. Turn it on in Settings › Extensions, then try again."))
            }
            return answer
        }
        guard let url = args.string("url") else { throw Problem(L("Say which file or HTTPS link to play.")) }
        guard DirectMedia.validRemoteURL(url) else {
            throw Problem(L("That isn't an https:// link to a video. Links to web pages (YouTube, Netflix) don't work: the TV needs the video file or stream itself."))
        }
        let tv = try tv(args.string("tv"))
        if session.busy { session.stop("Replaced by a new video.") }
        let name = URL(string: url)?.lastPathComponent.removingPercentEncoding ?? ""
        let title = name.isEmpty ? L("A video") : name
        try run { try session.play(Session.Media(url: url, title: title), on: tv) }
        return await outcome(of: .playing(title))
    }

    /// A video lent by a call's own process: play it here, and answer that process.
    static func handOff(_ request: Inbox.Request) async {
        let inbox = Inbox(folder: data)
        do {
            let tv = try tv(request.tv)
            if session.busy { session.stop("Replaced by a new video.") }
            try run {
                try session.play(Session.Media(file: request.file.map { URL(fileURLWithPath: $0) }, subtitle: request.subtitle.map { URL(fileURLWithPath: $0) },
                                               title: request.title), on: tv)
            }
            inbox.reply(request.id, await outcome(of: .playing(request.title)))
        } catch {
            inbox.remove([request.file, request.subtitle].compactMap { $0 })
            inbox.reply(request.id, L("Couldn't play it: {error}", ["error": (error as? Problem)?.message ?? error.localizedDescription]))
        }
    }

    static func pair(_ args: Arguments) async throws -> String {
        let tv = try tv(try args.required("tv"))
        if session.saved.contains(where: { $0.id == tv.id }) { return L("{tv} is already paired.", ["tv": tv.name]) }
        try run { try session.pair(with: tv) }
        return await outcome(of: .paired(tv.name))
    }

    /// What a call started, to say how it went.
    enum Doing {
        case sharing(String)
        case playing(String)
        case paired(String)
    }

    /// Waits up to 12 seconds for what happened next, and says it.
    static func outcome(of doing: Doing) async -> String {
        for _ in 0..<60 {
            let tv = session.receiver?.name ?? L("the TV")
            switch session.phase {
            case .pairing:
                return L("Compare the code {code} with the one on {tv}. If they match, choose Codes match · Pair on Miraya's page in Home; then Allow on the TV.",
                         ["code": MirayaPage.spaced(session.pairingCode), "tv": tv])
            case .authorizing: return L("Choose Allow on {tv} with its remote.", ["tv": tv])
            case .sharing:
                switch doing {
                case .sharing(let what): return L("Sharing {what} on {tv}.", ["what": what, "tv": tv])
                case .playing(let title): return L("Playing {title} on {tv}.", ["title": title, "tv": tv])
                case .paired(let name): return L("Paired with {tv}.", ["tv": name])
                }
            case .idle:
                if let problem = session.problem { return problem }
                if case .paired(let name) = doing, session.saved.contains(where: { $0.id == session.receiver?.id }) { return L("Paired with {tv}.", ["tv": name]) }
            default: break
            }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        return MirayaPage.sentence(session)
    }

    /// A session's refusals become the person's words.
    static func run(_ work: () throws -> Void) throws {
        do { try work() } catch let failure as ConnectionFailure { throw Problem(Said.shown(failure.message)) }
    }
}
