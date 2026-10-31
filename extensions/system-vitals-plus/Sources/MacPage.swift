import Foundation
import SidefolkExtensionKit

/// The "Your Mac" page: the verdict, the four numbers that matter, what changed over time, what is using the Mac,
/// and every detail below, each with a line saying what it means. In the person's language (Sidefolk D76).
enum MacPage {
    static func make(_ s: Snapshot) -> Page {
        let w = Words.self
        var now: [Block] = [.gauge(L("CPU"), w.percent(s.cpu.load), fraction: s.cpu.load, tone: w.cpuTone(s.cpu.load),
                                   caption: s.byCPU.first.map { L("Most: {app}", ["app": $0.name]) } ?? L("Mostly idle"))]
        if let m = s.memory {
            now.append(.gauge(L("Memory"), w.memory(m.used), fraction: m.used / m.total, tone: w.pressureTone(m.pressure),
                              caption: L("of {total}", ["total": w.memory(m.total)])))
        }
        if let d = s.startup {
            now.append(.gauge(L("Disk"), L("{size} free", ["size": w.bytes(d.free)]), fraction: d.total > 0 ? d.used / d.total : 0, tone: w.diskTone(d),
                              caption: L("of {total}", ["total": w.bytes(d.total)])))
        }
        if let b = s.battery {
            now.append(.gauge(L("Battery"), w.charge(b.percent), fraction: Double(b.percent) / 100, tone: w.batteryTone(b), caption: w.batteryState(b)))
        } else if let g = s.gpu {
            now.append(.gauge(L("Graphics"), w.percent(g), fraction: g, tone: w.cpuTone(g), caption: L("GPU")))
        }
        let (heat, heatTone) = w.thermalWord(s.thermal)
        now.append(.stat(L("Temperature"), heat, tone: heatTone, caption: heatTone == .good ? L("No slowing down") : L("Slowing down to cool off")))
        if s.battery != nil, let g = s.gpu { now.append(.stat(L("Graphics"), w.percent(g), tone: w.cpuTone(g), caption: L("GPU busy"))) }
        now.append(.stat(L("Network"), "↓ \(w.rate(s.network.down))", caption: "↑ \(w.rate(s.network.up))"))
        if let up = s.uptime { now.append(.stat(L("On for"), w.duration(up), tone: up > 14 * 86_400 ? .info : .neutral)) }

        var sections = [Section(L("Right now"), now)]
        let concerns = Words.concerns(s)
        if !concerns.isEmpty {
            sections.append(Section(L("Worth a look"), concerns.map { .note(L("{title}. {advice}", ["title": $0.title, "advice": $0.advice]), tone: $0.tone) }))
        }
        sections.append(Section(L("Over time"), charts(s)))
        sections.append(Section(L("What's using your Mac"), using(s)))
        if let m = s.memory { sections.append(Section(L("Memory"), memory(m, s))) }
        sections.append(Section(L("Storage"), storage(s)))
        if let b = s.battery { sections.append(Section(L("Battery"), battery(b))) }
        sections.append(Section(L("Network"), network(s.network)))
        sections.append(Section(L("This Mac"), specs(s)))
        // What is asked stays English: Sidefolk understands typed requests in English (its GLOSSARY, rule 1); the AI
        // answers in the person's language.
        var asks: [Block] = [.ask(L("What's slowing my Mac?"), "What's slowing my Mac?"), .ask(L("Should I restart?"), "Should I restart my Mac?"),
                             .ask(L("How do I free up space?"), "How do I free up space on my Mac?")]
        if s.battery != nil { asks.append(.ask(L("Is my battery healthy?"), "Is my battery healthy?")) }
        sections.append(Section(L("Ask about it"), asks))
        return Page(summary: Words.summary(s), sections: sections)
    }

    static func charts(_ s: Snapshot) -> [Block] {
        let w = Words.self
        var cpu = [Series("total", L("CPU"), s.cpu.load * 100, display: w.percent(s.cpu.load))]
        if let g = s.gpu { cpu.append(Series("gpu", L("Graphics"), g * 100, display: w.percent(g))) }
        var out: [Block] = [.chart(id: "cpu", L("Processor and graphics"), unit: "%", max: 100,
                                   caption: L("How busy they were. Short peaks are normal; a long plateau means something is working hard."), series: cpu)]
        if let m = s.memory {
            out.append(.chart(id: "memory", L("Memory used"), unit: "GB", max: m.total / 1_073_741_824,
                              caption: L("Cached files aren't counted: macOS gives that space back the moment an app needs it."),
                              series: [Series("used", L("Used"), m.used / 1_073_741_824, display: w.memory(m.used))]))
        }
        out.append(.chart(id: "network", L("Network"), unit: "MB/s", caption: L("Everything this Mac downloads and uploads, every app together."),
                          series: [Series("down", L("Download"), s.network.down / 1e6, display: w.rate(s.network.down)),
                                   Series("up", L("Upload"), s.network.up / 1e6, display: w.rate(s.network.up))]))
        if let b = s.battery {
            out.append(.chart(id: "battery", L("Battery charge"), unit: "%", max: 100,
                              series: [Series("charge", L("Charge"), Double(b.percent), display: w.charge(b.percent))]))
        }
        return out
    }

    static func using(_ s: Snapshot) -> [Block] {
        let w = Words.self
        let busy = Array(s.byCPU.prefix(6))
        let top = max(busy.first.map(s.share) ?? 0, 0.01)
        var out: [Block] = []
        out.append(.bars(L("Processor"), caption: busy.isEmpty ? L("Nothing is busy right now.") : L("Share of the whole processor, by app."),
                         busy.map { Bar($0.name, w.percent(s.share($0)), fraction: s.share($0) / top, tone: w.cpuTone(s.share($0))) }))
        if let m = s.memory {
            out.append(.bars(L("Memory"), caption: L("How much each app holds. Helpers and background parts count as their app."),
                             s.byMemory.prefix(6).map { Bar($0.name, w.memory($0.memory), fraction: $0.memory / m.total) }))
        }
        return out
    }

    static func memory(_ m: Probe.Memory, _ s: Snapshot) -> [Block] {
        let w = Words.self
        return [
            .facts(nil, [(L("Apps"), w.memory(m.app)), (L("Kept by macOS"), w.memory(m.wired)), (L("Compressed"), w.memory(m.compressed)),
                         (L("Cached files"), L("{size}, free to reuse", ["size": w.memory(m.cached)])),
                         (L("Swap"), m.swapUsed > 0 ? w.memory(m.swapUsed) : L("None")),
                         (L("Pressure"), w.pressureWord(m.pressure).capitalizedFirst)]),
            .note(m.pressure >= 2
                ? L("Memory pressure is high: macOS is compressing memory and moving some to the disk (swap), which is slower. Quitting an app you don't need helps most.")
                : L("A Mac uses spare memory to keep things quick, so it often looks nearly full. Memory pressure is what matters, and it's normal."),
                  tone: w.pressureTone(m.pressure)),
        ]
    }

    static func storage(_ s: Snapshot) -> [Block] {
        let w = Words.self
        let bars = s.volumes.prefix(8).map { v in
            Bar(v.name, L("{free} free of {total}", ["free": w.bytes(v.free), "total": w.bytes(v.total)]),
                fraction: v.total > 0 ? v.used / v.total : 0, tone: w.diskTone(v))
        }
        return [.bars(L("Disks"), caption: L("Free space counts what macOS clears by itself when it needs room (caches, old snapshots)."), Array(bars))]
    }

    static func battery(_ b: Probe.Battery) -> [Block] {
        let w = Words.self
        var facts = [(L("Charge"), w.charge(b.percent)), (L("State"), w.batteryState(b))]
        if let h = w.healthWord(b) { facts.append((L("Health"), h)) }
        if let c = b.cycles { facts.append((L("Charge cycles"), Format.integer(c))) }
        if let t = b.celsius { facts.append((L("Temperature"), Format.number(t, digits: 0) + " °C")) }
        if let watts = b.adapterWatts, b.pluggedIn { facts.append((L("Charger"), "\(watts) W")) }
        var out: [Block] = [.facts(nil, facts)]
        if let h = b.health {
            let values = ["percent": w.percent(h), "normal": Format.percent(0.8)]
            out.append(.note(h >= 0.8
                ? L("The battery holds {percent} of what it held new. Apple counts {normal} and above as normal.", values)
                : L("The battery holds {percent} of what it held new, below the {normal} Apple counts as normal, so it runs out sooner.", values),
                tone: h >= 0.8 ? .good : .warn))
        }
        return out
    }

    static func network(_ n: Probe.Network) -> [Block] {
        let w = Words.self
        var facts: [(String, String)] = []
        if let a = n.address { facts.append((L("Address on this network"), a + (n.interface.map { " (\($0))" } ?? ""))) }
        facts += [(L("Downloading"), w.rate(n.down)), (L("Uploading"), w.rate(n.up)),
                  (L("Received since start-up"), w.bytes(n.received)), (L("Sent since start-up"), w.bytes(n.sent))]
        return [.facts(nil, facts)]
    }

    static func specs(_ s: Snapshot) -> [Block] {
        let w = Words.self
        var facts = [(L("Chip"), s.specs.chip), (L("Cores"), w.cores(s.specs))]
        if let g = s.specs.gpuCores { facts.append((L("Graphics"), L("{count}-core GPU", ["count": g]))) }
        facts.append((L("Memory"), w.memory(s.specs.memory)))
        facts.append((L("System"), s.specs.macOS))
        if let m = s.specs.model { facts.append((L("Model"), m)) }
        if let up = s.uptime { facts.append((L("On for"), w.duration(up))) }
        return [.facts(nil, facts)]
    }
}

extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
