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

ext.background {
    Inbox(folder: data).clearAll()
    session.discovery.start()
    // Videos lent by the process Sidefolk starts for "play this file" (Inbox) are picked up here.
    while true {
        for request in Inbox(folder: data).take() { await Tools.handOff(request) }
        try? await Task.sleep(nanoseconds: 500_000_000)
    }
}

ext.page("miraya") { _ in MirayaPage.make(session, windows: windows) }

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
    guard session.busy else { return "Nothing is on the TV from this Mac." }
    session.stop("You stopped it.")
    return "Stopped."
}

ext.tool("pause", "Pause sharing", "Pauses mirroring (the TV may keep the last picture) or the video playing on the TV.") { _ in
    try Tools.run { try session.pause() }
    return session.mode == .media ? "Paused the video." : "Paused. Nothing new reaches the TV until you resume."
}

ext.tool("resume", "Resume sharing", "Resumes paused mirroring or the paused video on the TV.") { _ in
    try Tools.run { try session.resume() }
    return "Resuming."
}

ext.tool("seek", "Skip in the video", "Jumps ahead or back in the video playing on the TV.",
         input: Schema.object(["seconds": Schema.integer("Seconds: positive ahead, negative back.", minimum: -3600, maximum: 3600)], required: ["seconds"])) { args in
    let seconds = Double(args.int("seconds") ?? 30)
    try Tools.run { try session.seek(by: seconds) }
    return seconds >= 0 ? "Skipped ahead \(Int(seconds)) seconds." : "Went back \(Int(-seconds)) seconds."
}

ext.tool("tv_volume", "TV volume", "Sets how loud Miraya plays on the TV, from 0 to 100 (the TV's own volume stays as it is).",
         input: Schema.object(["percent": Schema.integer("0 to 100.", minimum: 0, maximum: 100)], required: ["percent"])) { args in
    try Tools.run { try session.setVolume(Double(args.int("percent") ?? 100) / 100) }
    return "Miraya's volume on the TV is \(args.int("percent") ?? 100)%."
}

ext.tool("pair_tv", "Pair with a TV", "Pairs this Mac with a TV running Miraya, by its name or by the address it shows "
    + "(192.168.1.20 or 192.168.1.20:7421): a six-digit code appears on Miraya's page to compare with the TV's.",
    input: Schema.object(["tv": Schema.string("The TV's name or address.")], required: ["tv"])) { args in try await Tools.pair(args) }

ext.tool("confirm_pairing", "Codes match · Pair", "The person saw the same six digits on the Mac and the TV.") { _ in
    try Tools.run { try session.confirmPairing() }
    return "Now choose Allow on the TV with its remote."
}

ext.tool("forget_tv", "Forget a TV", "Forgets a paired TV on this Mac; it needs a new code next time.",
         input: Schema.object(["tv": Schema.string("The TV's id or name.")], required: ["tv"])) { args in
    let words = try args.required("tv")
    guard let tv = session.saved.first(where: { $0.id == words || $0.name.caseInsensitiveCompare(words) == .orderedSame }) else {
        throw Problem("No paired TV is called “\(words)”.")
    }
    try Tools.run { try session.forget(tv.id) }
    return "Forgot \(tv.name). Pairing again needs a new code."
}

ext.tool("choose_tv", "Choose a TV", "Chooses the TV that sharing goes to when none is named.",
         input: Schema.object(["tv": Schema.string("The TV's id or name.")], required: ["tv"])) { args in
    let words = try args.required("tv")
    guard let tv = session.tvs.compactMap(\.receiver).first(where: { $0.id == words }) ?? session.tv(named: words) else {
        throw Problem("No TV is called “\(words)”.")
    }
    session.choices.lastTV = tv.id
    return "Sharing goes to \(tv.name)."
}

ext.tool("list_windows", "Windows to share", "Lists the open windows on Miraya's page, to share one.") { _ in
    do { windows = try await Screens.windows() } catch {
        throw Problem("macOS hasn't allowed Sidefolk to record the screen yet, so windows can't be listed. Allow it in System Settings › "
            + "Privacy & Security › Screen & System Audio Recording.")
    }
    return windows!.isEmpty ? "No window to share is open." : "\(windows!.count) windows are on Miraya's page."
}

ext.tool("set_option", "Miraya setting", "Changes a sharing choice: quality (a preset), sound, detail or follow_tv.",
         input: Schema.object(["option": Schema.string("Which.", oneOf: ["quality", "sound", "detail", "follow_tv"]),
                               "value": Schema.string("The preset, for quality.", oneOf: CaptureQuality.allCases.map(\.rawValue)),
                               "on": Schema.boolean("On or off, for the others.")], required: ["option"])) { args in
    switch try args.required("option") {
    case "quality":
        guard let q = args.string("value").flatMap(CaptureQuality.init(rawValue:)) else { throw Problem("Which quality?") }
        session.choices.quality = q.rawValue
    case "sound": session.choices.sound = args.bool("on") ?? !session.choices.sound
    case "detail": session.choices.detail = args.bool("on") ?? !session.choices.detail
    case "follow_tv": session.choices.followTV = args.bool("on") ?? !session.choices.followTV
    default: throw Problem("There's no such setting.")
    }
    session.applyChoices()
    return "Done."
}

ext.tool("tv_status", "What's on the TV", "Says what Miraya is sharing or playing on the TV now, if anything.") { _ in MirayaPage.sentence(session) }

// A paired TV that turned on: Miraya on the TV opened, so it's ready for "mirror my screen".
ext.watcher("tv_on") { _, state in
    let on = Set(session.found.map(\.id)).intersection(session.saved.map(\.id))
    let before = Set(state["on"] as? [String] ?? [])
    let new = session.saved.filter { on.contains($0.id) && !before.contains($0.id) }
    let summary = new.isEmpty ? "No paired TV turned on." : "\(new.map(\.name).joined(separator: " and ")) is on: say “mirror my screen” to share."
    return Check(triggered: !new.isEmpty && state["on"] != nil, state: ["on": Array(on).sorted()], summary: summary)
}

// Sharing that ended without the person stopping it: the TV's Back button, the network, the TV turned off.
ext.watcher("ended") { _, state in
    guard let end = session.lastEnd else { return Check(triggered: false, state: [:], summary: "Nothing ended yet.") }
    let stamp = end.at.timeIntervalSince1970
    let new = (state["last"] as? Double).map { stamp > $0 } ?? false
    return Check(triggered: new && end.why != "You stopped it.", state: ["last": stamp], summary: "Sharing to the TV ended: \(end.why)")
}

await ext.serve()
