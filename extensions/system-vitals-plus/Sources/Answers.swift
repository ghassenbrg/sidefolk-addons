import Foundation
import SidefolkExtensionKit

/// What each tool says: plain sentences with the numbers in them, for the person (a command's card, read aloud) and
/// for the AI, which answers follow-up questions from them. In the person's language (Sidefolk D76).
enum Answers {
    static let w = Words.self

    /// "Xcode 60%, Safari 15%" in the language's own way of listing.
    static func list(_ items: [String]) -> String { items.joined(separator: L(", ")) }

    static func health(_ s: Snapshot) -> String {
        let concerns = Words.concerns(s)
        var lines = [concerns.contains { $0.tone != .info } ? L("Your Mac needs a look.") : L("Your Mac is doing fine."), Words.glance(s) + "."]
        lines += concerns.map { L("{title}: {advice}", ["title": $0.title, "advice": $0.advice]) }
        if let m = s.memory { lines.append(L("Memory pressure is {pressure}.", ["pressure": w.pressureWord(m.pressure)])) }
        lines.append(L("Temperature: {heat}.", ["heat": w.thermalWord(s.thermal).0.lowercased(with: Language.locale)]))
        if let up = s.uptime { lines.append(L("On for {time}.", ["time": w.duration(up)])) }
        return lines.joined(separator: " ")
    }

    static func cpu(_ s: Snapshot) -> String {
        var text = L("The processor is {percent} busy ({apps} apps, {system} macOS) across {cores}.", [
            "percent": w.percent(s.cpu.load), "apps": w.percent(s.cpu.user), "system": w.percent(s.cpu.system), "cores": w.cores(s.specs),
        ])
        let l = s.cpu.loadAverage
        if l.count == 3 {
            text += " " + L("Load average {one}, {five} and {fifteen} over 1, 5 and 15 minutes.",
                            ["one": Format.number(l[0]), "five": Format.number(l[1]), "fifteen": Format.number(l[2])])
        }
        if let g = s.gpu { text += " " + L("Graphics {percent} busy.", ["percent": w.percent(g)]) }
        let busy = s.byCPU.prefix(5).map { "\($0.name) \(w.percent(s.share($0)))" }
        text += " " + (busy.isEmpty ? L("No app is busy.") : L("Busiest: {apps} (share of the whole processor).", ["apps": list(busy)]))
        return text
    }

    static func memory(_ s: Snapshot) -> String {
        guard let m = s.memory else { return L("The Mac didn't report its memory.") }
        var text = L("{used} of {total} in use; memory pressure is {pressure}.",
                     ["used": w.memory(m.used), "total": w.memory(m.total), "pressure": w.pressureWord(m.pressure)])
        text += " " + L("Apps {apps}, kept by macOS {wired}, compressed {compressed}, cached files {cached} (free to reuse), swap {swap}.", [
            "apps": w.memory(m.app), "wired": w.memory(m.wired), "compressed": w.memory(m.compressed), "cached": w.memory(m.cached),
            "swap": m.swapUsed > 0 ? w.memory(m.swapUsed) : L("none"),
        ])
        let top = s.byMemory.prefix(5).map { "\($0.name) \(w.memory($0.memory))" }
        if !top.isEmpty { text += " " + L("Most memory: {apps}.", ["apps": list(top)]) }
        return text
    }

    static func storage(_ s: Snapshot) -> String {
        guard !s.volumes.isEmpty else { return L("No disk reported its space.") }
        return s.volumes.map { v in
            L("{disk}: {free} free of {total} ({percent} used).",
              ["disk": v.name, "free": w.bytes(v.free), "total": w.bytes(v.total), "percent": w.percent(v.total > 0 ? v.used / v.total : 0)])
        }.joined(separator: " ") + " " + L("Free space includes what macOS clears by itself when it needs room.")
    }

    static func battery(_ s: Snapshot) -> String {
        guard let b = s.battery else { return L("This Mac has no battery; it runs on power from the wall.") }
        var parts = [L("Battery at {percent}, {state}.", ["percent": w.charge(b.percent), "state": w.batteryState(b).lowercased(with: Language.locale)])]
        if let h = w.healthWord(b) { parts.append(L("Health: {health}.", ["health": h])) }
        if let c = b.cycles { parts.append(L(one: "{count} charge cycle.", other: "{count} charge cycles.", count: c)) }
        if let t = b.celsius { parts.append(L("Temperature: {temperature}.", ["temperature": Format.number(t, digits: 0) + " °C"])) }
        if let watts = b.adapterWatts, b.pluggedIn { parts.append(L("Charger: {watts}.", ["watts": "\(watts) W"])) }
        if let h = b.health {
            parts.append(h >= 0.8 ? L("That's normal wear (Apple counts {percent} and above as normal).", ["percent": Format.percent(0.8)])
                : L("That's below the {percent} Apple counts as normal.", ["percent": Format.percent(0.8)]))
        }
        return parts.joined(separator: " ")
    }

    static func network(_ s: Snapshot) -> String {
        let n = s.network
        var text = L("Downloading {down}, uploading {up}. Since start-up: {received} received, {sent} sent.",
                     ["down": w.rate(n.down), "up": w.rate(n.up), "received": w.bytes(n.received), "sent": w.bytes(n.sent)])
        if let a = n.address {
            let address = a + (n.interface.map { " (\($0))" } ?? "")
            text = L("This Mac's address on the network is {address}.", ["address": address]) + " " + text
        }
        return text
    }

    static func topApps(_ s: Snapshot) -> String {
        let cpu = s.byCPU.prefix(5).map { "\($0.name) \(w.percent(s.share($0)))" }
        let memory = s.byMemory.prefix(5).map { "\($0.name) \(w.memory($0.memory))" }
        var text = cpu.isEmpty ? L("Processor {percent} busy, no app busy.", ["percent": w.percent(s.cpu.load)])
            : L("Processor {percent} busy: {apps}.", ["percent": w.percent(s.cpu.load), "apps": list(cpu)])
        text += " " + L("Memory: {apps}.", ["apps": list(memory)])
        let concerns = Words.concerns(s).filter { $0.tone != .info }
        if !concerns.isEmpty { text += " " + concerns.map { L("{title}: {advice}", ["title": $0.title, "advice": $0.advice]) }.joined(separator: " ") }
        else { text += " " + L("Nothing is straining the Mac.") }
        return text
    }

    static func specs(_ s: Snapshot) -> String {
        var parts = [L("This Mac: {chip}", ["chip": s.specs.chip]), w.cores(s.specs)]
        if let g = s.specs.gpuCores { parts.append(L("{count}-core GPU", ["count": g])) }
        parts.append(L("{memory} of memory", ["memory": w.memory(s.specs.memory)]))
        parts.append(s.specs.macOS)
        if let m = s.specs.model { parts.append(L("model {model}", ["model": m])) }
        let about = list(parts)
        return s.uptime.map { L("{about}; on for {time}.", ["about": about, "time": w.duration($0)]) } ?? about + "."
    }
}
