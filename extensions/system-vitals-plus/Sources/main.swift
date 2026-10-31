import Foundation
import SidefolkExtensionKit

// Your Mac, Sidefolk's own (once System Vitals+: its id and folder keep that name, so installs carry on): the whole Mac
// in plain words, as a page in Home, a tile on Today, answers without the AI and heads-ups from the companion.
// Everything is read from macOS itself: no internet, no files, no programs.
let ext = Extension(name: "system-vitals-plus")

ext.page("mac") { _ in MacPage.make(await Snapshot.take()) }

ext.tool("health", "Mac health check", "Whether this Mac is doing fine, what needs a look (memory, heat, disk, battery, a busy "
    + "processor) and what to do about it, with the main numbers.") { _ in Answers.health(await Snapshot.take()) }
ext.tool("cpu", "Processor and graphics", "How busy the processor and the graphics are now, the load average, the cores, and the "
    + "apps using the processor most.") { _ in Answers.cpu(await Snapshot.take()) }
ext.tool("memory", "Memory in detail", "Memory in use and its pressure, what holds it (apps, macOS, compressed, cached files, swap), "
    + "and the apps holding the most.") { _ in Answers.memory(await Snapshot.take()) }
ext.tool("storage", "Storage", "Free and total space on every disk, the startup disk first.") { _ in Answers.storage(await Snapshot.take()) }
ext.tool("battery", "Battery in detail", "Charge, charging, time left, health against new, charge cycles, temperature and the "
    + "charger's power.") { _ in Answers.battery(await Snapshot.take()) }
ext.tool("network", "Network activity", "This Mac's address on the local network, what it downloads and uploads now, and in "
    + "total since start-up.") { _ in Answers.network(await Snapshot.take()) }
ext.tool("top_apps", "What's using the Mac", "The apps using the processor and memory most, grouped by app, and anything straining "
    + "the Mac. Use it for \"why is my Mac slow\".") { _ in Answers.topApps(await Snapshot.take()) }
ext.tool("specs", "This Mac's specs", "The chip, cores, graphics, memory, macOS version, model and how long the Mac has been on.") { _ in
    Answers.specs(await Snapshot.take())
}

// Each watcher tells once when its line is crossed, then again only after things went back to normal.
ext.watcher("cpu_busy") { settings, state in
    let s = await Snapshot.take()
    let busy = s.cpu.load * 100 >= Double(settings.int("above_percent") ?? 90)
    let load = ["percent": Words.percent(s.cpu.load)]
    let summary = !busy ? L("The processor is {percent} busy.", load)
        : s.byCPU.first.map { L("Your Mac is working hard: the processor is {percent} busy, mostly {app}.", load.merging(["app": $0.name]) { a, _ in a }) }
        ?? L("Your Mac is working hard: the processor is {percent} busy.", load)
    return Check(triggered: busy && state["busy"] as? Bool != true, state: ["busy": busy], summary: summary)
}
ext.watcher("app_hog") { settings, state in
    let s = await Snapshot.take()
    let cpuLine = Double(settings.int("cpu_percent") ?? 40) / 100
    let memoryLine = (settings.double("memory_gb") ?? 8) * 1e9
    let hogs = s.apps.filter { s.share($0) >= cpuLine || $0.memory >= memoryLine }.sorted { s.share($0) > s.share($1) }
    let before = Set(state["hogs"] as? [String] ?? [])
    let new = hogs.first { !before.contains($0.name) }
    let summary = new.map {
        L("{app} is using {percent} of the processor and {memory} of memory.", ["app": $0.name, "percent": Words.percent(s.share($0)), "memory": Words.memory($0.memory)])
    } ?? L("No app is using an unusual share of the Mac.")
    return Check(triggered: new != nil, state: ["hogs": hogs.map(\.name)], summary: summary)
}
ext.watcher("memory_pressure") { _, state in
    guard let m = Probe.memory() else { throw Problem(L("The Mac didn't report its memory.")) }
    let tight = m.pressure >= 2
    let top = (await Probe.apps()).max { $0.memory < $1.memory }.map { " " + L("{app} holds the most ({memory}).", ["app": $0.name, "memory": Words.memory($0.memory)]) } ?? ""
    return Check(triggered: tight && state["tight"] as? Bool != true, state: ["tight": tight],
                 summary: tight ? L("Memory is getting tight, so apps may slow down.") + top : L("Memory pressure is normal."))
}
ext.watcher("hot") { _, state in
    let t = Probe.thermal()
    let hot = t == .serious || t == .critical
    return Check(triggered: hot && state["hot"] as? Bool != true, state: ["hot": hot],
                 summary: hot ? (t == .critical ? L("Your Mac is very hot and may slow down to cool off.") : L("Your Mac is hot and may slow down to cool off."))
                     : L("Your Mac's temperature is normal."))
}
ext.watcher("disk_low") { settings, state in
    guard let d = Probe.volumes().first else { throw Problem(L("The startup disk didn't report its space.")) }
    let low = d.free / 1e9 < (settings.double("below_gb") ?? 15)
    return Check(triggered: low && state["low"] as? Bool != true, state: ["low": low],
                 summary: L("{size} free on {disk}.", ["size": Words.bytes(d.free), "disk": d.name]))
}
ext.watcher("battery_low") { settings, state in
    guard let b = Probe.battery() else { throw Problem(L("This Mac has no battery.")) }
    let low = !b.pluggedIn && b.percent < (settings.int("below_percent") ?? 20)
    return Check(triggered: low && state["low"] as? Bool != true, state: ["low": low],
                 summary: L("Battery at {percent}, {state}.", ["percent": Words.charge(b.percent), "state": Words.batteryState(b).lowercased(with: Language.locale)]))
}
ext.watcher("battery_health") { settings, state in
    guard let b = Probe.battery() else { throw Problem(L("This Mac has no battery.")) }
    let worn = b.failure || (b.health ?? 1) * 100 < Double(settings.int("below_percent") ?? 80)
    return Check(triggered: worn && state["worn"] as? Bool != true, state: ["worn": worn],
                 summary: L("Battery health: {health}.", ["health": Words.healthWord(b) ?? L("unknown")]))
}

await ext.serve()
