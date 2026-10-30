import Foundation

/// What each tool says: plain sentences with the numbers in them, for the person (a command's card, read aloud) and
/// for the AI, which answers follow-up questions from them.
enum Answers {
    static let w = Words.self

    static func health(_ s: Snapshot) -> String {
        let concerns = Words.concerns(s)
        var lines = [concerns.contains { $0.tone != .info } ? "Your Mac needs a look." : "Your Mac is doing fine.", Words.glance(s) + "."]
        lines += concerns.map { "\($0.title): \($0.advice)" }
        if let m = s.memory { lines.append("Memory pressure is \(w.pressureWord(m.pressure)).") }
        lines.append("Temperature: \(w.thermalWord(s.thermal).0.lowercased()).")
        if let up = s.uptime { lines.append("On for \(w.duration(up)).") }
        return lines.joined(separator: " ")
    }

    static func cpu(_ s: Snapshot) -> String {
        var text = "The processor is \(w.percent(s.cpu.load)) busy (\(w.percent(s.cpu.user)) apps, \(w.percent(s.cpu.system)) macOS) "
            + "across \(w.cores(s.specs))."
        let l = s.cpu.loadAverage
        if l.count == 3 { text += String(format: " Load average %.1f, %.1f and %.1f over 1, 5 and 15 minutes.", l[0], l[1], l[2]) }
        if let g = s.gpu { text += " Graphics \(w.percent(g)) busy." }
        let busy = s.byCPU.prefix(5).map { "\($0.name) \(w.percent(s.share($0)))" }
        text += busy.isEmpty ? " No app is busy." : " Busiest: " + busy.joined(separator: ", ") + " (share of the whole processor)."
        return text
    }

    static func memory(_ s: Snapshot) -> String {
        guard let m = s.memory else { return "The Mac didn't report its memory." }
        var text = "\(w.memory(m.used)) of \(w.memory(m.total)) in use; memory pressure is \(w.pressureWord(m.pressure)). "
            + "Apps \(w.memory(m.app)), kept by macOS \(w.memory(m.wired)), compressed \(w.memory(m.compressed)), "
            + "cached files \(w.memory(m.cached)) (free to reuse), swap \(m.swapUsed > 0 ? w.memory(m.swapUsed) : "none")."
        let top = s.byMemory.prefix(5).map { "\($0.name) \(w.memory($0.memory))" }
        if !top.isEmpty { text += " Most memory: " + top.joined(separator: ", ") + "." }
        return text
    }

    static func storage(_ s: Snapshot) -> String {
        guard !s.volumes.isEmpty else { return "No disk reported its space." }
        return s.volumes.map { v in
            "\(v.name): \(w.bytes(v.free)) free of \(w.bytes(v.total)) (\(w.percent(v.total > 0 ? v.used / v.total : 0)) used)."
        }.joined(separator: " ") + " Free space includes what macOS clears by itself when it needs room."
    }

    static func battery(_ s: Snapshot) -> String {
        guard let b = s.battery else { return "This Mac has no battery; it runs on power from the wall." }
        var parts = ["Battery at \(b.percent)%, \(w.batteryState(b).lowercased())."]
        if let h = w.healthWord(b) { parts.append("Health: \(h).") }
        if let c = b.cycles { parts.append("\(c) charge cycles.") }
        if let t = b.celsius { parts.append(String(format: "%.0f °C.", t)) }
        if let watts = b.adapterWatts, b.pluggedIn { parts.append("Charger: \(watts) W.") }
        if let h = b.health { parts.append(h >= 0.8 ? "That's normal wear (Apple counts 80% and above as normal)." : "That's below the 80% Apple counts as normal.") }
        return parts.joined(separator: " ")
    }

    static func network(_ s: Snapshot) -> String {
        let n = s.network
        var text = "Downloading \(w.rate(n.down)), uploading \(w.rate(n.up)). Since start-up: \(w.bytes(n.received)) received, \(w.bytes(n.sent)) sent."
        if let a = n.address { text = "This Mac's address on the network is \(a)" + (n.interface.map { " (\($0))" } ?? "") + ". " + text }
        return text
    }

    static func topApps(_ s: Snapshot) -> String {
        let cpu = s.byCPU.prefix(5).map { "\($0.name) \(w.percent(s.share($0)))" }
        let memory = s.byMemory.prefix(5).map { "\($0.name) \(w.memory($0.memory))" }
        var text = "Processor \(w.percent(s.cpu.load)) busy" + (cpu.isEmpty ? ", no app busy." : ": " + cpu.joined(separator: ", ") + ".")
        text += " Memory: " + memory.joined(separator: ", ") + "."
        let concerns = Words.concerns(s).filter { $0.tone != .info }
        if !concerns.isEmpty { text += " " + concerns.map { "\($0.title): \($0.advice)" }.joined(separator: " ") }
        else { text += " Nothing is straining the Mac." }
        return text
    }

    static func specs(_ s: Snapshot) -> String {
        var parts = ["This Mac: \(s.specs.chip)", w.cores(s.specs)]
        if let g = s.specs.gpuCores { parts.append("\(g)-core GPU") }
        parts.append("\(w.memory(s.specs.memory)) of memory")
        parts.append(s.specs.macOS)
        if let m = s.specs.model { parts.append("model \(m)") }
        return parts.joined(separator: ", ") + (s.uptime.map { "; on for \(w.duration($0))." } ?? ".")
    }
}
