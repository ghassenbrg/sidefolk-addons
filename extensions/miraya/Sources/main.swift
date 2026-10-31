import Foundation
import Network
import CoreGraphics
import SidefolkExtensionKit

// Miraya, Sidefolk's own: the Mac's screen, a window or a part of it, with its sound, on an Android TV running Miraya,
// over native WebRTC (encrypted UDP) after a six-digit pairing, or a video file or HTTPS link played by the TV itself.
// The sending side of Miraya's Mac app (github.com/ghassenbrg/miraya, MIT), inside Sidefolk's sandbox: the TV app is
// unchanged. Recording the screen is Sidefolk's permission in macOS, opened to this extension by permissions.screen.
let ext = Extension(name: "miraya")
let data = URL(fileURLWithPath: Paths.data, isDirectory: true)
let session = Session(folder: data)
var windows: [Screens.Window]?
// Pictures of the displays and windows for the page's tiles; a round of them also says which windows are open.
let shots = Shots(folder: data)
shots.onWindows = { windows = $0 }

ext.background {
    Inbox(folder: data).clearAll()
    shots.clearAll()
    session.discovery.start()
    // Videos lent by the process Sidefolk starts for "play this file" (Inbox) are picked up here.
    while true {
        for request in Inbox(folder: data).take() { await Tools.handOff(request) }
        try? await Task.sleep(nanoseconds: 500_000_000)
    }
}

ext.page("miraya") { _ in
    shots.rendered(busy: session.busy, area: session.choices.kind == "area" ? session.choices.display : nil)
    return MirayaPage.make(MirayaPage.now(session, windows: windows, shots: shots.names, canRecord: Shots.allowed))
}

// Which TV a call would reach, asked by Sidefolk before it decides whether to ask the person (D72).
ext.paired { tool, args in Tools.reach(tool, args, in: session) }

ext.tool("find_tvs", "TVs around", "Lists the TVs running Miraya on this network and the paired ones, and whether each is on now. "
    + "Looks again on the network.") { _ in
    session.discovery.refresh()
    try? await Task.sleep(nanoseconds: 2_500_000_000)
    return Tools.listing(in: session)
}

ext.tool("share_screen", "Share screen to TV", "Mirrors the Mac's screen, one window, or part of a screen to a TV running Miraya, with the "
    + "Mac's sound unless sound is false. A TV not paired yet first shows a six-digit code to compare on Miraya's page.",
    input: Schema.object([
        "tv": Schema.string("The TV's name as it's listed (\"Living Room TV\"), part of it (\"living room\"), or its address. Missing: the only or last TV."),
        "window": Schema.string("Share one window instead: its app or title, e.g. Safari or Keynote."),
        "window_id": Schema.integer("A window id from Miraya's page.", minimum: 1),
        "display": Schema.integer("A display id from Miraya's page.", minimum: 1),
        "area": Schema.string("Share part of the display.", oneOf: ["left", "right", "top", "bottom", "center"]),
        "quality": Schema.string("A quality preset.", oneOf: CaptureQuality.allCases.map(\.rawValue)),
        "sound": Schema.boolean("Send the Mac's sound to the TV too (the page's choice if missing)."),
    ])) { args in try await Tools.share(args) }

ext.tool("play_on_tv", "Play on TV", "Plays a video or audio file from this Mac, or an HTTPS link to the video itself (not a web page), "
    + "on a TV running Miraya; the TV plays the original, with optional .srt or .vtt subtitles.",
    input: Schema.object([
        "file": Schema.path("A video or audio file on this Mac."),
        "url": Schema.string("Or an https:// link to the video file or stream.", maxLength: 2000),
        "subtitles": Schema.path("An .srt or .vtt subtitles file."),
        "tv": Schema.string("The TV's name or address. Missing: the only or last TV."),
    ])) { args in try await Tools.play(args) }

ext.tool("stop", "Stop sharing", "Stops mirroring or the video on the TV, or a pairing that's under way.") { _ in
    guard session.busy else { return L("Nothing is on the TV from this Mac.") }
    session.stop("You stopped it.")
    return L("Stopped.")
}

ext.tool("pause", "Pause sharing", "Pauses mirroring (the TV may keep the last picture) or the video playing on the TV.") { _ in
    try Tools.run { try session.pause() }
    return session.mode == .media ? L("Paused the video.") : L("Paused. Nothing new reaches the TV until you resume.")
}

ext.tool("resume", "Resume sharing", "Resumes paused mirroring or the paused video on the TV.") { _ in
    try Tools.run { try session.resume() }
    return L("Resuming.")
}

ext.tool("seek", "Skip in the video", "Jumps ahead or back in the video playing on the TV.",
         input: Schema.object(["seconds": Schema.integer("Seconds: positive ahead, negative back.", minimum: -3600, maximum: 3600)], required: ["seconds"])) { args in
    let seconds = Double(args.int("seconds") ?? 30)
    try Tools.run { try session.seek(by: seconds) }
    return seconds >= 0 ? L(one: "Skipped ahead {count} second.", other: "Skipped ahead {count} seconds.", count: Int(seconds))
        : L(one: "Went back {count} second.", other: "Went back {count} seconds.", count: Int(-seconds))
}

ext.tool("tv_volume", "TV volume", "Sets how loud Miraya plays on the TV, from 0 to 100 (the TV's own volume stays as it is).",
         input: Schema.object(["percent": Schema.integer("0 to 100.", minimum: 0, maximum: 100)], required: ["percent"])) { args in
    try Tools.run { try session.setVolume(Double(args.int("percent") ?? 100) / 100) }
    return L("Miraya's volume on the TV is {percent}.", ["percent": Format.percent(points: Double(args.int("percent") ?? 100))])
}

ext.tool("pair_tv", "Pair with a TV", "Pairs this Mac with a TV running Miraya, by its name or by the address it shows "
    + "(192.168.1.20 or 192.168.1.20:7421): a six-digit code appears on Miraya's page to compare with the TV's.",
    input: Schema.object(["tv": Schema.string("The TV's name or address.")], required: ["tv"])) { args in try await Tools.pair(args) }

ext.tool("confirm_pairing", "Codes match · Pair", "The person saw the same six digits on the Mac and the TV.") { _ in
    try Tools.run { try session.confirmPairing() }
    return L("Now choose Allow on the TV with its remote.")
}

ext.tool("forget_tv", "Forget a TV", "Forgets a paired TV on this Mac; it needs a new code next time.",
         input: Schema.object(["tv": Schema.string("The TV's id or name.")], required: ["tv"])) { args in
    let words = try args.required("tv")
    guard let tv = session.saved.first(where: { $0.id == words || $0.name.caseInsensitiveCompare(words) == .orderedSame }) else {
        throw Problem(L("No paired TV is called “{tv}”.", ["tv": words]))
    }
    try Tools.run { try session.forget(tv.id) }
    return L("Forgot {tv}. Pairing again needs a new code.", ["tv": tv.name])
}

ext.tool("choose_tv", "Choose a TV", "Chooses the TV that sharing goes to when none is named.",
         input: Schema.object(["tv": Schema.string("The TV's id or name.")], required: ["tv"])) { args in
    let words = try args.required("tv")
    guard let tv = session.tvs.compactMap(\.receiver).first(where: { $0.id == words }) ?? session.tv(named: words) else {
        throw Problem(L("No TV is called “{tv}”.", ["tv": words]))
    }
    session.choices.lastTV = tv.id
    return L("Sharing goes to {tv}.", ["tv": tv.name])
}

ext.tool("list_windows", "Windows to share", "Lists the open windows on Miraya's page, to share one.") { _ in
    do { windows = try await Screens.windows() } catch {
        throw Problem(L("macOS hasn't allowed Sidefolk to record the screen yet, so windows can't be listed. Allow it in System Settings › Privacy & Security › Screen & System Audio Recording."))
    }
    return windows!.isEmpty ? L("No window to share is open.")
        : L(one: "{count} window is on Miraya's page.", other: "{count} windows are on Miraya's page.", count: windows!.count)
}

ext.tool("set_option", "Miraya setting", "Changes a sharing choice: quality (a preset), sound, detail or follow_tv; or what the page "
    + "shares: kind (display, window or area), and which display, window or area.",
         input: Schema.object(["option": Schema.string("Which.", oneOf: ["quality", "sound", "detail", "follow_tv", "kind", "display", "window", "area"]),
                               "value": Schema.string("The preset for quality; display, window or area for kind; an id from the page, or an area's name.",
                                                      maxLength: 40),
                               "on": Schema.boolean("On or off, for the others.")], required: ["option"])) { args in
    switch try args.required("option") {
    case "quality":
        guard let q = args.string("value").flatMap(CaptureQuality.init(rawValue:)) else { throw Problem(L("Which quality?")) }
        session.choices.quality = q.rawValue
    case "kind":
        guard let kind = args.string("value"), ["display", "window", "area"].contains(kind) else { throw Problem(L("Share a display, a window or an area?")) }
        session.choices.kind = kind
        // Picking Window is when macOS asks to let Sidefolk record the screen, as in Miraya's app.
        if kind == "window", windows == nil { windows = try? await Screens.windows() }
        return L("Done.")
    case "display", "window":
        guard let id = args.string("value").flatMap(UInt32.init) else { throw Problem(L("Which one?")) }
        if args.string("option") == "display" { session.choices.display = id } else { session.choices.window = id }
        return L("Done.")
    case "area":
        guard let area = args.string("value"), MirayaPage.areas.contains(where: { $0.name == area }) else { throw Problem(L("Which part of the screen?")) }
        session.choices.area = area
        return L("Done.")
    case "sound": session.choices.sound = args.bool("on") ?? !session.choices.sound
    case "detail": session.choices.detail = args.bool("on") ?? !session.choices.detail
    case "follow_tv": session.choices.followTV = args.bool("on") ?? !session.choices.followTV
    default: throw Problem(L("There's no such setting."))
    }
    session.applyChoices()
    return L("Done.")
}

ext.tool("tv_status", "What's on the TV", "Says what Miraya is sharing or playing on the TV now, if anything.") { _ in MirayaPage.sentence(session) }

// A paired TV that turned on: Miraya on the TV opened, so it's ready for "mirror my screen".
ext.watcher("tv_on") { _, state in
    let on = Set(session.found.map(\.id)).intersection(session.saved.map(\.id))
    let before = Set(state["on"] as? [String] ?? [])
    let new = session.saved.filter { on.contains($0.id) && !before.contains($0.id) }
    // What to say stays English: Sidefolk understands typed requests in English (its GLOSSARY, rule 1).
    let summary = new.isEmpty ? L("No paired TV turned on.") : L("{tv} is on: say “mirror my screen” to share.", ["tv": Format.list(new.map(\.name))])
    return Check(triggered: !new.isEmpty && state["on"] != nil, state: ["on": Array(on).sorted()], summary: summary)
}

// Sharing that ended without the person stopping it: the TV's Back button, the network, the TV turned off.
ext.watcher("ended") { _, state in
    guard let end = session.lastEnd else { return Check(triggered: false, state: [:], summary: L("Nothing ended yet.")) }
    let stamp = end.at.timeIntervalSince1970
    let new = (state["last"] as? Double).map { stamp > $0 } ?? false
    return Check(triggered: new && end.why != "You stopped it.", state: ["last": stamp], summary: L("Sharing to the TV ended: {why}", ["why": Said.shown(end.why)]))
}

await ext.serve()
