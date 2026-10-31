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
    let top = s.byCPU.first.map { ", mostly \($0.name)" } ?? ""
    return Check(triggered: busy && state["busy"] as? Bool != true, state: ["busy": busy],
                 summary: busy ? "Your Mac is working hard: the processor is \(Words.percent(s.cpu.load)) busy\(top)."
                     : "The processor is \(Words.percent(s.cpu.load)) busy.")
}
ext.watcher("app_hog") { settings, state in
    let s = await Snapshot.take()
    let cpuLine = Double(settings.int("cpu_percent") ?? 40) / 100
    let memoryLine = (settings.double("memory_gb") ?? 8) * 1e9
    let hogs = s.apps.filter { s.share($0) >= cpuLine || $0.memory >= memoryLine }.sorted { s.share($0) > s.share($1) }
    let before = Set(state["hogs"] as? [String] ?? [])
    let new = hogs.first { !before.contains($0.name) }
    let summary = new.map { "\($0.name) is using \(Words.percent(s.share($0))) of the processor and \(Words.memory($0.memory)) of memory." }
        ?? "No app is using an unusual share of the Mac."
    return Check(triggered: new != nil, state: ["hogs": hogs.map(\.name)], summary: summary)
}
ext.watcher("memory_pressure") { _, state in
    guard let m = Probe.memory() else { throw Problem("The Mac didn't report its memory.") }
    let tight = m.pressure >= 2
    let top = (await Probe.apps()).max { $0.memory < $1.memory }.map { " \($0.name) holds the most (\(Words.memory($0.memory)))." } ?? ""
    return Check(triggered: tight && state["tight"] as? Bool != true, state: ["tight": tight],
                 summary: tight ? "Memory is getting tight, so apps may slow down.\(top)" : "Memory pressure is normal.")
}
ext.watcher("hot") { _, state in
    let t = Probe.thermal()
    let hot = t == .serious || t == .critical
    return Check(triggered: hot && state["hot"] as? Bool != true, state: ["hot": hot],
                 summary: hot ? "Your Mac is \(Words.thermalWord(t).0.lowercased()) and may slow down to cool off." : "Your Mac's temperature is normal.")
}
ext.watcher("disk_low") { settings, state in
    guard let d = Probe.volumes().first else { throw Problem("The startup disk didn't report its space.") }
    let low = d.free / 1e9 < (settings.double("below_gb") ?? 15)
    return Check(triggered: low && state["low"] as? Bool != true, state: ["low": low],
                 summary: "\(Words.bytes(d.free)) free on \(d.name).")
}
ext.watcher("battery_low") { settings, state in
    guard let b = Probe.battery() else { throw Problem("This Mac has no battery.") }
    let low = !b.pluggedIn && b.percent < (settings.int("below_percent") ?? 20)
    return Check(triggered: low && state["low"] as? Bool != true, state: ["low": low],
                 summary: "Battery at \(b.percent)%, \(Words.batteryState(b).lowercased()).")
}
ext.watcher("battery_health") { settings, state in
    guard let b = Probe.battery() else { throw Problem("This Mac has no battery.") }
    let worn = b.failure || (b.health ?? 1) * 100 < Double(settings.int("below_percent") ?? 80)
    return Check(triggered: worn && state["worn"] as? Bool != true, state: ["worn": worn],
                 summary: "Battery health: \(Words.healthWord(b) ?? "unknown").")
}

await ext.serve()
