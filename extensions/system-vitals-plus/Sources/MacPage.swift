import Foundation
import SidefolkExtensionKit

/// The "Your Mac" page: the verdict, the four numbers that matter, what changed over time, what is using the Mac,
/// and every detail below, each with a line saying what it means.
enum MacPage {
    static func make(_ s: Snapshot) -> Page {
        let w = Words.self
        var now: [Block] = [.gauge("CPU", w.percent(s.cpu.load), fraction: s.cpu.load, tone: w.cpuTone(s.cpu.load),
                                   caption: s.byCPU.first.map { "Most: \($0.name)" } ?? "Mostly idle")]
        if let m = s.memory {
            now.append(.gauge("Memory", w.memory(m.used), fraction: m.used / m.total, tone: w.pressureTone(m.pressure),
                              caption: "of \(w.memory(m.total))"))
        }
        if let d = s.startup {
            now.append(.gauge("Disk", "\(w.bytes(d.free)) free", fraction: d.total > 0 ? d.used / d.total : 0, tone: w.diskTone(d),
                              caption: "of \(w.bytes(d.total))"))
        }
        if let b = s.battery {
            now.append(.gauge("Battery", "\(b.percent)%", fraction: Double(b.percent) / 100, tone: w.batteryTone(b), caption: w.batteryState(b)))
        } else if let g = s.gpu {
            now.append(.gauge("Graphics", w.percent(g), fraction: g, tone: w.cpuTone(g), caption: "GPU"))
        }
        let (heat, heatTone) = w.thermalWord(s.thermal)
        now.append(.stat("Temperature", heat, tone: heatTone, caption: heatTone == .good ? "No slowing down" : "Slowing down to cool off"))
        if s.battery != nil, let g = s.gpu { now.append(.stat("Graphics", w.percent(g), tone: w.cpuTone(g), caption: "GPU busy")) }
        now.append(.stat("Network", "↓ \(w.rate(s.network.down))", caption: "↑ \(w.rate(s.network.up))"))
        if let up = s.uptime { now.append(.stat("On for", w.duration(up), tone: up > 14 * 86_400 ? .info : .neutral)) }

        var sections = [Section("Right now", now)]
        let concerns = Words.concerns(s)
        if !concerns.isEmpty {
            sections.append(Section("Worth a look", concerns.map { .note("\($0.title). \($0.advice)", tone: $0.tone) }))
        }
        sections.append(Section("Over time", charts(s)))
        sections.append(Section("What's using your Mac", using(s)))
        if let m = s.memory { sections.append(Section("Memory", memory(m, s))) }
        sections.append(Section("Storage", storage(s)))
        if let b = s.battery { sections.append(Section("Battery", battery(b))) }
        sections.append(Section("Network", network(s.network)))
        sections.append(Section("This Mac", specs(s)))
        var asks: [Block] = [.ask("What's slowing my Mac?", "What's slowing my Mac?"), .ask("Should I restart?", "Should I restart my Mac?"),
                             .ask("How do I free up space?", "How do I free up space on my Mac?")]
        if s.battery != nil { asks.append(.ask("Is my battery healthy?", "Is my battery healthy?")) }
        sections.append(Section("Ask about it", asks))
        return Page(summary: Words.summary(s), sections: sections)
    }

    static func charts(_ s: Snapshot) -> [Block] {
        let w = Words.self
        var cpu = [Series("total", "CPU", s.cpu.load * 100, display: w.percent(s.cpu.load))]
        if let g = s.gpu { cpu.append(Series("gpu", "Graphics", g * 100, display: w.percent(g))) }
        var out: [Block] = [.chart(id: "cpu", "Processor and graphics", unit: "%", max: 100,
                                   caption: "How busy they were. Short peaks are normal; a long plateau means something is working hard.", series: cpu)]
        if let m = s.memory {
            out.append(.chart(id: "memory", "Memory used", unit: "GB", max: m.total / 1_073_741_824,
                              caption: "Cached files aren't counted: macOS gives that space back the moment an app needs it.",
                              series: [Series("used", "Used", m.used / 1_073_741_824, display: w.memory(m.used))]))
        }
        out.append(.chart(id: "network", "Network", unit: "MB/s", caption: "Everything this Mac downloads and uploads, every app together.",
                          series: [Series("down", "Download", s.network.down / 1e6, display: w.rate(s.network.down)),
                                   Series("up", "Upload", s.network.up / 1e6, display: w.rate(s.network.up))]))
        if let b = s.battery {
            out.append(.chart(id: "battery", "Battery charge", unit: "%", max: 100,
                              series: [Series("charge", "Charge", Double(b.percent), display: "\(b.percent)%")]))
        }
        return out
    }

    static func using(_ s: Snapshot) -> [Block] {
        let w = Words.self
        let busy = Array(s.byCPU.prefix(6))
        let top = max(busy.first.map(s.share) ?? 0, 0.01)
        var out: [Block] = []
        out.append(.bars("Processor", caption: busy.isEmpty ? "Nothing is busy right now." : "Share of the whole processor, by app.",
                         busy.map { Bar($0.name, w.percent(s.share($0)), fraction: s.share($0) / top, tone: w.cpuTone(s.share($0))) }))
        if let m = s.memory {
            out.append(.bars("Memory", caption: "How much each app holds. Helpers and background parts count as their app.",
                             s.byMemory.prefix(6).map { Bar($0.name, w.memory($0.memory), fraction: $0.memory / m.total) }))
        }
        return out
    }

    static func memory(_ m: Probe.Memory, _ s: Snapshot) -> [Block] {
        let w = Words.self
        return [
            .facts(nil, [("Apps", w.memory(m.app)), ("Kept by macOS", w.memory(m.wired)), ("Compressed", w.memory(m.compressed)),
                         ("Cached files", "\(w.memory(m.cached)), free to reuse"), ("Swap", m.swapUsed > 0 ? w.memory(m.swapUsed) : "None"),
                         ("Pressure", w.pressureWord(m.pressure).capitalizedFirst)]),
            .note(m.pressure >= 2
                ? "Memory pressure is high: macOS is compressing memory and moving some to the disk (swap), which is slower. Quitting an app you don't need helps most."
                : "A Mac uses spare memory to keep things quick, so it often looks nearly full. Memory pressure is what matters, and it's normal.",
                  tone: w.pressureTone(m.pressure)),
        ]
    }

    static func storage(_ s: Snapshot) -> [Block] {
        let w = Words.self
        let bars = s.volumes.prefix(8).map { v in
            Bar(v.name, "\(w.bytes(v.free)) free of \(w.bytes(v.total))", fraction: v.total > 0 ? v.used / v.total : 0, tone: w.diskTone(v))
        }
        return [.bars("Disks", caption: "Free space counts what macOS clears by itself when it needs room (caches, old snapshots).", Array(bars))]
    }

    static func battery(_ b: Probe.Battery) -> [Block] {
        let w = Words.self
        var facts = [("Charge", "\(b.percent)%"), ("State", w.batteryState(b))]
        if let h = w.healthWord(b) { facts.append(("Health", h)) }
        if let c = b.cycles { facts.append(("Charge cycles", "\(c)")) }
        if let t = b.celsius { facts.append(("Temperature", String(format: "%.0f °C", t))) }
        if let watts = b.adapterWatts, b.pluggedIn { facts.append(("Charger", "\(watts) W")) }
        var out: [Block] = [.facts(nil, facts)]
        if let h = b.health {
            out.append(.note(h >= 0.8
                ? "The battery holds \(w.percent(h)) of what it held new. Apple counts 80% and above as normal."
                : "The battery holds \(w.percent(h)) of what it held new, below the 80% Apple counts as normal, so it runs out sooner.",
                tone: h >= 0.8 ? .good : .warn))
        }
        return out
    }

    static func network(_ n: Probe.Network) -> [Block] {
        let w = Words.self
        var facts: [(String, String)] = []
        if let a = n.address { facts.append(("Address on this network", a + (n.interface.map { " (\($0))" } ?? ""))) }
        facts += [("Downloading", w.rate(n.down)), ("Uploading", w.rate(n.up)),
                  ("Received since start-up", w.bytes(n.received)), ("Sent since start-up", w.bytes(n.sent))]
        return [.facts(nil, facts)]
    }

    static func specs(_ s: Snapshot) -> [Block] {
        let w = Words.self
        var facts = [("Chip", s.specs.chip), ("Cores", w.cores(s.specs))]
        if let g = s.specs.gpuCores { facts.append(("Graphics", "\(g)-core GPU")) }
        facts.append(("Memory", w.memory(s.specs.memory)))
        facts.append(("System", s.specs.macOS))
        if let m = s.specs.model { facts.append(("Model", m)) }
        if let up = s.uptime { facts.append(("On for", w.duration(up))) }
        return [.facts(nil, facts)]
    }
}

extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
