import Foundation
import SidefolkExtensionKit

/// One look at the whole Mac, taken at once so every answer and the page agree with each other.
struct Snapshot {
    var cpu: Probe.CPU
    var gpu: Double?
    var memory: Probe.Memory?
    var apps: [Probe.App]
    var battery: Probe.Battery?
    var thermal: ProcessInfo.ThermalState
    var network: Probe.Network
    var volumes: [Probe.Volume]
    var specs: Probe.Specs
    var now: Date

    @MainActor static func take() async -> Snapshot {
        // The three rates each wait a moment for a second reading when they have none: together, not in turn.
        async let cpu = Probe.cpu()
        async let apps = Probe.apps()
        async let network = Probe.network()
        return Snapshot(cpu: await cpu, gpu: Probe.gpu(), memory: Probe.memory(), apps: await apps, battery: Probe.battery(),
                        thermal: Probe.thermal(), network: await network, volumes: Probe.volumes(), specs: Probe.specs(), now: Date())
    }

    var startup: Probe.Volume? { volumes.first }
    var uptime: TimeInterval? { specs.booted.map { now.timeIntervalSince($0) } }
    /// Apps using at least half a percent of the processor, busiest first.
    var byCPU: [Probe.App] { apps.filter { share($0) >= 0.005 }.sorted { $0.cpu > $1.cpu } }
    var byMemory: [Probe.App] { apps.sorted { $0.memory > $1.memory } }
    /// An app's share of the whole processor, the same scale as the CPU figure.
    func share(_ app: Probe.App) -> Double { app.cpu / Double(max(1, cpu.cores.count)) }
}

/// Something worth telling, worst first: what is wrong in a few words, and what to do about it.
struct Concern: Equatable {
    var tone: Tone
    var title: String
    var advice: String

    var rank: Int { tone == .bad ? 0 : tone == .warn ? 1 : 2 }
}

/// Plain words for every number: what the page, the tools and the watchers say.
enum Words {
    static func concerns(_ s: Snapshot) -> [Concern] {
        var out: [Concern] = []
        if let m = s.memory, m.pressure >= 2 {
            let top = s.byMemory.first.map { " Quit apps you aren't using, starting with \($0.name) (\(memory($0.memory)))." } ?? ""
            out.append(m.pressure >= 4
                ? Concern(tone: .bad, title: "Memory is very tight", advice: "macOS is short of memory, so apps slow down or pause.\(top)")
                : Concern(tone: .warn, title: "Memory is getting tight", advice: "macOS is squeezing memory to make room.\(top)"))
        }
        switch s.thermal {
        case .critical:
            out.append(Concern(tone: .bad, title: "Your Mac is very hot", advice: "It is slowing itself down to cool off. Give it air and quit heavy apps."))
        case .serious:
            out.append(Concern(tone: .warn, title: "Your Mac is hot", advice: "It may slow down to cool off. Check what's working hardest below."))
        default: break
        }
        if s.cpu.load >= 0.9 {
            let top = s.byCPU.first.map { ", mostly \($0.name)" } ?? ""
            out.append(Concern(tone: .warn, title: "Your Mac is working very hard",
                               advice: "The processor is \(percent(s.cpu.load)) busy\(top). It eases once that work finishes, or quit the app."))
        }
        if let d = s.startup {
            let share = d.total > 0 ? d.free / d.total : 1
            if d.free < 5e9 || share < 0.05 {
                out.append(Concern(tone: .bad, title: "Your disk is almost full",
                                   advice: "Only \(bytes(d.free)) left. Empty the Trash and remove big files you don't need; System Settings › General › Storage shows what takes the space."))
            } else if d.free < 15e9 || share < 0.1 {
                out.append(Concern(tone: .warn, title: "Disk space is getting low",
                                   advice: "\(bytes(d.free)) left. Empty the Trash, and look in Downloads for things you no longer need."))
            }
        }
        if let b = s.battery {
            if !b.pluggedIn, b.percent <= 10 {
                out.append(Concern(tone: .bad, title: "The battery is almost empty", advice: "\(b.percent)% left. Plug in now."))
            } else if !b.pluggedIn, b.percent <= 20 {
                out.append(Concern(tone: .warn, title: "The battery is low", advice: "\(b.percent)% left. Plug in soon."))
            }
            if b.failure {
                out.append(Concern(tone: .warn, title: "The battery needs service", advice: "The battery reports a fault. Apple can check and replace it."))
            } else if let h = b.health, h < 0.8 {
                out.append(Concern(tone: .warn, title: "The battery has worn",
                                   advice: "It holds \(percent(h)) of its charge when new, so it runs out sooner. Apple can replace it."))
            }
        }
        if let up = s.uptime, up > 14 * 86_400 {
            out.append(Concern(tone: .info, title: "On for \(duration(up))", advice: "A restart clears out memory and finishes installing updates."))
        }
        return out.sorted { $0.rank < $1.rank }
    }

    static func summary(_ s: Snapshot) -> Summary {
        let worst = concerns(s).first { $0.tone != .info }
        return Summary(worst?.title ?? "Your Mac is doing fine", detail: glance(s), tone: worst?.tone ?? .good,
                       symbol: worst == nil ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
    }

    /// "CPU 12% · Memory 61% · 214 GB free · Battery 84%"
    static func glance(_ s: Snapshot) -> String {
        var parts = ["CPU \(percent(s.cpu.load))"]
        if let m = s.memory { parts.append("Memory \(percent(m.used / m.total))") }
        if let d = s.startup { parts.append("\(bytes(d.free)) free") }
        if let b = s.battery { parts.append("Battery \(b.percent)%") }
        return parts.joined(separator: " · ")
    }

    // MARK: Tones

    static func cpuTone(_ load: Double) -> Tone { load >= 0.9 ? .bad : load >= 0.7 ? .warn : .good }
    static func pressureTone(_ p: Int) -> Tone { p >= 4 ? .bad : p >= 2 ? .warn : .good }

    static func diskTone(_ v: Probe.Volume) -> Tone {
        let share = v.total > 0 ? v.free / v.total : 1
        return v.free < 5e9 || share < 0.05 ? .bad : v.free < 15e9 || share < 0.1 ? .warn : .good
    }

    static func batteryTone(_ b: Probe.Battery) -> Tone {
        b.pluggedIn ? .good : b.percent <= 10 ? .bad : b.percent <= 20 ? .warn : .good
    }

    static func thermalWord(_ t: ProcessInfo.ThermalState) -> (String, Tone) {
        switch t {
        case .nominal: ("Cool", .good)
        case .fair: ("Warm", .good)
        case .serious: ("Hot", .warn)
        case .critical: ("Very hot", .bad)
        @unknown default: ("Unknown", .neutral)
        }
    }

    static func pressureWord(_ p: Int) -> String {
        p >= 4 ? "critical: apps are being slowed" : p >= 2 ? "high: macOS is squeezing memory" : "normal: no strain"
    }

    static func batteryState(_ b: Probe.Battery) -> String {
        if b.full || (b.pluggedIn && !b.charging && b.percent >= 95) { return "Charged" }
        if b.charging { return b.minutesLeft.map { "Charging, full in \(minutes($0))" } ?? "Charging" }
        if b.pluggedIn { return "Plugged in, not charging" }
        return b.minutesLeft.map { "On battery, \(minutes($0)) left" } ?? "On battery"
    }

    static func healthWord(_ b: Probe.Battery) -> String? {
        if b.failure { return "Needs service" }
        guard let h = b.health else { return nil }
        return "\(percent(h)) of new · \(h >= 0.8 ? "Normal" : "Worn")"
    }

    static func cores(_ s: Probe.Specs) -> String {
        guard let p = s.performanceCores, let e = s.efficiencyCores, p > 0, e > 0 else { return "\(s.cores) cores" }
        return "\(s.cores) cores (\(p) performance, \(e) efficiency)"
    }

    // MARK: Numbers

    static func percent(_ fraction: Double) -> String { "\(Int((min(max(fraction, 0), 9.99) * 100).rounded()))%" }

    /// 1.2 GB, 340 MB, 12 KB: decimal, as Finder counts.
    static func bytes(_ n: Double) -> String {
        if n >= 1e12 { return String(format: "%.1f TB", n / 1e12) }
        if n >= 1e9 { return String(format: n >= 1e11 ? "%.0f GB" : "%.1f GB", n / 1e9) }
        if n >= 1e6 { return String(format: "%.0f MB", n / 1e6) }
        return String(format: "%.0f KB", max(0, n) / 1e3)
    }

    /// Memory as macOS and Apple count it, in binary units: a 24 GB Mac shows 24 GB, not 25.8.
    static func memory(_ n: Double) -> String {
        let gib = n / 1_073_741_824
        if gib >= 1 { return String(format: gib >= 100 ? "%.0f GB" : "%.1f GB", gib).replacingOccurrences(of: ".0 GB", with: " GB") }
        return String(format: "%.0f MB", max(0, n) / 1_048_576)
    }

    static func rate(_ bytesPerSecond: Double) -> String {
        if bytesPerSecond >= 1e6 { return String(format: "%.1f MB/s", bytesPerSecond / 1e6) }
        if bytesPerSecond >= 1e3 { return String(format: "%.0f KB/s", bytesPerSecond / 1e3) }
        return bytesPerSecond > 0 ? "under 1 KB/s" : "0 KB/s"
    }

    static func minutes(_ m: Int) -> String { m >= 60 ? "\(m / 60) h \(m % 60) min" : "\(m) min" }

    static func duration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        let (days, hours, rest) = (minutes / 1440, minutes % 1440 / 60, minutes % 60)
        func unit(_ n: Int, _ word: String) -> String { "\(n) \(word)\(n == 1 ? "" : "s")" }
        if days > 0 { return unit(days, "day") + (hours > 0 ? " " + unit(hours, "hour") : "") }
        return hours > 0 ? unit(hours, "hour") + " " + unit(rest, "minute") : unit(rest, "minute")
    }
}
