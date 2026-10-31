import Foundation
import SidefolkExtensionKit

// Keep Awake, Sidefolk's own: the Mac stays awake, and chat apps keep seeing you as active, for as long as you say,
// while an app is open, or until you stop it. It lets go by itself on battery or when the battery runs low. Power
// assertions are macOS's own (what caffeinate uses); being active is a pointer move of nothing, made by Sidefolk.
let ext = Extension(name: "keep-awake")
let keeper = Keeper(folder: URL(fileURLWithPath: Paths.data, isDirectory: true))
keeper.nudge = { ext.send("sidefolk/nudge") }

ext.background { await keeper.run() }

ext.page("awake") { _ in AwakePage.make(keeper) }

ext.tool("keep_awake", "Keep the Mac awake", "Keeps the Mac (and by default its screen) awake for minutes, hours, until a time "
    + "(\"6pm\", \"18:30\"), while an app is open, or until stopped. active keeps chat apps from marking the person away.",
    input: Schema.object([
        "minutes": Schema.integer("For this many minutes.", minimum: 1, maximum: 1440),
        "hours": Schema.number("For this many hours.", minimum: 0.1, maximum: 72),
        "until": Schema.string("Until a time today or tomorrow: 6pm, 18:30."),
        "while_app": Schema.string("Only while this app is open, e.g. Zoom; ends when it quits."),
        "screen": Schema.boolean("Keep the screen on too (the page's choice if missing)."),
        "active": Schema.boolean("Keep chat and meeting apps seeing the person as active (the page's choice if missing)."),
        "on": Schema.boolean("The page's main switch: false lets the Mac sleep again, as stop_keeping_awake does."),
    ])) { args in
    // The main switch (Sidefolk D67) sends its new state here; off is the same as stop_keeping_awake.
    if args.bool("on") == false {
        keeper.stop()
        return L("Done: your Mac sleeps as usual again.")
    }
    let now = Date()
    var s = keeper.defaults
    s.started = now
    s.until = nil
    if let m = args.int("minutes") { s.until = now.addingTimeInterval(Double(m) * 60) }
    if let h = args.double("hours") { s.until = now.addingTimeInterval(h * 3600) }
    if let text = args.string("until") {
        guard let t = Rules.time(text, now: now) else { throw Problem(L("I couldn't read “{text}” as a time, like 6pm or 18:30.", ["text": text])) }
        s.until = t
    }
    if let app = args.string("while_app") {
        let open = Keeper.openApps()
        guard let name = open.first(where: { $0.caseInsensitiveCompare(app) == .orderedSame }) else {
            throw Problem(L("{app} isn't open. Open it first, or say how long instead.", ["app": app]))
        }
        s.whileApp = name
    }
    if let screen = args.bool("screen") { s.screen = screen }
    if let active = args.bool("active") { s.active = active }
    keeper.start(s)
    return AwakePage.sentence(keeper)
}
ext.tool("stop_keeping_awake", "Let the Mac sleep", "Ends keeping the Mac awake and the person active; it sleeps as usual again.") { _ in
    guard keeper.session != nil else { return L("Your Mac wasn't being kept awake.") }
    keeper.stop()
    return L("Done: your Mac sleeps as usual again.")
}
ext.tool("awake_status", "Keep Awake status", "Whether the Mac is being kept awake, until when, and how.") { _ in AwakePage.sentence(keeper) }
ext.tool("extend", "Keep awake longer", "Adds minutes to the time the Mac is kept awake.",
         input: Schema.object(["minutes": Schema.integer("How many more minutes.", minimum: 1, maximum: 720)], required: ["minutes"])) { args in
    guard keeper.session?.until != nil else { throw Problem(L("It isn't kept awake for a set time.")) }
    keeper.extend(minutes: args.int("minutes") ?? 30)
    return AwakePage.sentence(keeper)
}
ext.tool("set_option", "Keep Awake setting", "Turns a choice on or off: screen, active, plugged_only or battery_floor.",
         input: Schema.object(["option": Schema.string("Which.", oneOf: ["screen", "active", "plugged_only", "battery_floor"]),
                               "on": Schema.boolean("On or off.")], required: ["option", "on"])) { args in
    let on = args.bool("on") ?? true
    switch try args.required("option") {
    case "screen": keeper.set { $0.screen = on }
    case "active": keeper.set { $0.active = on }
    case "plugged_only": keeper.set { $0.pluggedOnly = on }
    case "battery_floor": keeper.set { $0.batteryFloor = on ? 15 : nil }
    default: throw Problem(L("There's no such setting."))
    }
    return on ? L("Turned on.") : L("Turned off.")
}

// Tells once when a session ends by itself (its time, the app quit), so nobody is surprised by a dark screen.
ext.watcher("ended") { _, state in
    guard let end = keeper.lastEnd else { return Check(triggered: false, state: [:], summary: L("Nothing ended yet.")) }
    let stamp = end.at.timeIntervalSince1970
    let new = (state["last"] as? Double).map { stamp > $0 } ?? false
    let byItself = end.why != "You stopped it."
    return Check(triggered: new && byItself, state: ["last": stamp], summary: L("Keep Awake ended: {why} Your Mac sleeps as usual again.", ["why": Rules.shown(end.why)]))
}

await ext.serve()
