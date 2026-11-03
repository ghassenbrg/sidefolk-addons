import Foundation
import SidefolkExtensionKit

/// The "Your Mac" page: the verdict and anything worth a look, the four numbers that matter, the processor over time beside what's using the Mac, the smaller readings, heads-ups
/// and questions, and every detail below, each with a line saying what it means. In the person's language (Sidefolk D76). A reading the Mac didn't give stays out.
enum MacPage {
    static var dress: PageDress {
        PageDress(ground: PagePair(light: "#F2F5FA", dark: "#0F141C"), card: PagePair(light: "#FFFFFF", dark: "#19212C"), line: PagePair(light: "#E2E8F0", dark: "#2E3846"),
                                 accent: PagePair(light: "#2A6FD0", dark: "#70B2F6"), selected: PagePair(light: "#2A6FD0", dark: "#70B2F6"), well: PagePair(light: "#E8EDF4", dark: "#2A3442"))
    }
    static var sage: PagePair { PagePair(light: "#4A9A68", dark: "#8ECBA2") }
    static var sky: PagePair { PagePair(light: "#2F7BE0", dark: "#70B2F6") }
    static var amber: PagePair { PagePair(light: "#E09A2B", dark: "#F0BE6A") }

    static func make(_ s: Snapshot, appsBy: String = "cpu") -> Page {
        var sections = [head]
        let concerns = Words.concerns(s)
        var verdict: [Block] = [.note(Words.summary(s).title, tone: Words.summary(s).tone, symbol: concerns.contains { $0.tone != .info } ? "exclamationmark.triangle.fill" : "checkmark", style: .verdict)]
        // A problem stays in sight, above the numbers, however clean the healthy page is.
        verdict += concerns.map { .note(L("{title}. {advice}", ["title": $0.title, "advice": $0.advice]), tone: $0.tone) }
        sections.append(Section(nil, verdict, wide: true))
        sections.append(Section(nil, numbers(s), wide: true))
        sections.append(processor(s).inCard(row: "now", weight: 63))
        sections.append(using(s, by: appsBy).inCard(row: "now", weight: 37, accessories: [.going(L("Top apps"), style: .pills, appChoices(s), selected: appsBy, key: "apps")]))
        sections.append(Section(nil, readings(s), wide: true))
        sections.append(Section(L("Heads-ups"), [.headsUps(show: ["cpu_busy", "memory_pressure"], more: L("Manage heads-ups"), less: L("Show fewer"))]).inCard(row: "more", weight: 49))
        sections.append(ask(s).inCard(row: "more", weight: 51))
        let over = overTime(s)
        if !over.isEmpty { sections.append(Section(L("Over time"), over).inCard()) }
        if let m = s.memory {
            sections.append(Section(L("Memory"), memory(m, s)).inCard(row: "detail", weight: 1))
        }
        sections.append(Section(L("Storage"), storage(s)).inCard(row: "detail", weight: 1))
        if let b = s.battery { sections.append(Section(L("Battery"), battery(b)).inCard(row: "power", weight: 1)) }
        sections.append(Section(L("Network"), network(s.network)).inCard(row: "power", weight: 1))
        sections.append(Section(L("This Mac"), specs(s)).inCard())
        return Page(summary: Words.summary(s), sections: sections, bare: true, dress: dress, maxWidth: 1180)
    }

    static var head: Section {
        Section(nil, [.bar(PageBar(L("Your Mac"), detail: L("A live overview of your system"), brand: true, updated: true))], wide: true)
    }

    static func numbers(_ s: Snapshot) -> [Block] {
        let w = Words.self
        var out: [Block] = [.metric(Metric(L("Processor"), w.percent(s.cpu.load), symbol: "cpu", tone: tone(w.cpuTone(s.cpu.load)), tint: sky,
                                           caption: s.byCPU.first.map { L("Most: {app}", ["app": $0.name]) } ?? L("Mostly idle"), spark: (chart: "cpu", series: "total")))]
        if let m = s.memory {
            out.append(.metric(Metric(L("Memory"), w.memory(m.used), symbol: "memorychip", tone: tone(w.pressureTone(m.pressure)), tint: sage,
                                      caption: L("of {total}", ["total": w.memory(m.total)]) + " · " + L("Pressure") + " " + w.pressureWord(m.pressure), fraction: m.used / m.total)))
        }
        if let d = s.startup {
            out.append(.metric(Metric(L("Storage"), L("{size} free", ["size": w.bytes(d.free)]), symbol: "internaldrive", tone: tone(w.diskTone(d)), tint: sky,
                                      caption: L("of {total}", ["total": w.bytes(d.total)]), fraction: d.total > 0 ? d.used / d.total : 0)))
        }
        if let b = s.battery {
            out.append(.metric(Metric(L("Battery"), w.charge(b.percent), symbol: b.charging ? "battery.100percent.bolt" : "battery.75percent", tone: tone(w.batteryTone(b)), tint: sage, caption: w.batteryState(b))))
        } else if let g = s.gpu {
            out.append(.metric(Metric(L("Graphics"), w.percent(g), symbol: "display", tone: tone(w.cpuTone(g)), tint: sage, caption: L("GPU busy"))))
        }
        return out
    }

    /// Only what's worth a look keeps its tone on a card: a healthy number wears the page's colours.
    static func tone(_ t: Tone) -> Tone { t == .warn || t == .bad ? t : .neutral }

    static func processor(_ s: Snapshot) -> Section {
        let w = Words.self
        var cpu = [Series("total", L("CPU"), s.cpu.load * 100, display: w.percent(s.cpu.load))]
        if let g = s.gpu { cpu.append(Series("gpu", L("Graphics"), g * 100, display: w.percent(g))) }
        return Section(L("Processor & graphics"), [.chart(id: "cpu", L("Processor and graphics"), unit: "%", max: 100,
                                                          caption: L("How busy they were. Short peaks are normal; a long plateau means something is working hard."),
                                                          height: 170, colors: [sky, sage], series: cpu)])
    }

    static func appChoices(_ s: Snapshot) -> [Option] {
        var out = [Option("cpu", L("Processor"))]
        if s.memory != nil { out.append(Option("memory", L("Memory"))) }
        return out
    }

    static func using(_ s: Snapshot, by: String) -> Section {
        let w = Words.self
        func bar(_ app: Probe.App, _ b: Bar) -> PicturedBar { PicturedBar(b, picture: app.path.map { .app($0) }, symbol: "app.dashed") }
        if by == "memory", let m = s.memory {
            let top = max(s.byMemory.first?.memory ?? 0, 1)
            return Section(L("Top apps"), [.bars(caption: L("How much each app holds. Helpers and background parts count as their app."),
                                                 pictured: s.byMemory.prefix(6).map { bar($0, Bar($0.name, w.memory($0.memory), fraction: $0.memory / max(top, m.total * 0.05))) })])
        }
        let busy = Array(s.byCPU.prefix(6))
        let top = max(busy.first.map(s.share) ?? 0, 0.01)
        return Section(L("Top apps"), [.bars(caption: busy.isEmpty ? L("Nothing is busy right now.") : L("Share of the whole processor, by app."),
                                             pictured: busy.map { bar($0, Bar($0.name, w.percent(s.share($0)), fraction: s.share($0) / top, tone: w.cpuTone(s.share($0)) == .good ? .neutral : w.cpuTone(s.share($0)))) })])
    }

    static func readings(_ s: Snapshot) -> [Block] {
        let w = Words.self
        let (heat, heatTone) = w.thermalWord(s.thermal)
        var out: [Block] = [.metric(Metric(L("Temperature"), heat, symbol: "thermometer.medium", tone: tone(heatTone), tint: sage, caption: heatTone == .good ? L("No slowing down") : L("Slowing down to cool off"), size: .small)),
                            .metric(Metric(L("Download"), w.rate(s.network.down), symbol: "arrow.down.to.line", tint: sky, size: .small)),
                            .metric(Metric(L("Upload"), w.rate(s.network.up), symbol: "arrow.up.to.line", tint: sky, size: .small))]
        if let up = s.uptime { out.append(.metric(Metric(L("Uptime"), w.duration(up), symbol: "clock", tone: up > 14 * 86_400 ? .info : .neutral, tint: up > 14 * 86_400 ? nil : PagePair(light: "#6B7280", dark: "#A8B3C2"), size: .small))) }
        return out
    }

    /// What is asked stays English: Sidefolk understands typed requests in English (its GLOSSARY, rule 1); the AI answers in the person's language.
    static func ask(_ s: Snapshot) -> Section {
        var asks: [Block] = [.askRow(L("What's slowing my Mac?"), "What's slowing my Mac?"), .askRow(L("Should I restart?"), "Should I restart my Mac?"),
                             .askRow(L("How do I free up space?"), "How do I free up space on my Mac?")]
        if s.battery != nil { asks.append(.askRow(L("Is my battery healthy?"), "Is my battery healthy?")) }
        return Section(L("Ask about this Mac"), asks)
    }

    static func overTime(_ s: Snapshot) -> [Block] {
        let w = Words.self
        var out: [Block] = []
        if let m = s.memory {
            out.append(.chart(id: "memory", L("Memory used"), unit: "GB", max: m.total / 1_073_741_824,
                              caption: L("Cached files aren't counted: macOS gives that space back the moment an app needs it."), height: 130, colors: [sage],
                              series: [Series("used", L("Used"), m.used / 1_073_741_824, display: w.memory(m.used))]))
        }
        out.append(.chart(id: "network", L("Network"), unit: "MB/s", caption: L("Everything this Mac downloads and uploads, every app together."), height: 130, colors: [sky, amber],
                          series: [Series("down", L("Download"), s.network.down / 1e6, display: w.rate(s.network.down)),
                                   Series("up", L("Upload"), s.network.up / 1e6, display: w.rate(s.network.up))]))
        if let b = s.battery {
            out.append(.chart(id: "battery", L("Battery charge"), unit: "%", max: 100, height: 130, colors: [sage],
                              series: [Series("charge", L("Charge"), Double(b.percent), display: w.charge(b.percent))]))
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
            PicturedBar(Bar(v.name, L("{free} free of {total}", ["free": w.bytes(v.free), "total": w.bytes(v.total)]),
                            fraction: v.total > 0 ? v.used / v.total : 0, tone: w.diskTone(v) == .good ? .neutral : w.diskTone(v)))
        }
        return [.bars(caption: L("Free space counts what macOS clears by itself when it needs room (caches, old snapshots)."), pictured: Array(bars))]
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
