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

/// Plain words for every number: what the page, the tools and the watchers say, in the person's language.
enum Words {
    static func concerns(_ s: Snapshot) -> [Concern] {
        var out: [Concern] = []
        if let m = s.memory, m.pressure >= 2 {
            let top = s.byMemory.first.map { " " + L("Quit apps you aren't using, starting with {app} ({memory}).", ["app": $0.name, "memory": memory($0.memory)]) } ?? ""
            out.append(m.pressure >= 4
                ? Concern(tone: .bad, title: L("Memory is very tight"), advice: L("macOS is short of memory, so apps slow down or pause.") + top)
                : Concern(tone: .warn, title: L("Memory is getting tight"), advice: L("macOS is squeezing memory to make room.") + top))
        }
        switch s.thermal {
        case .critical:
            out.append(Concern(tone: .bad, title: L("Your Mac is very hot"), advice: L("It is slowing itself down to cool off. Give it air and quit heavy apps.")))
        case .serious:
            out.append(Concern(tone: .warn, title: L("Your Mac is hot"), advice: L("It may slow down to cool off. Check what's working hardest below.")))
        default: break
        }
        if s.cpu.load >= 0.9 {
            let advice = s.byCPU.first.map {
                L("The processor is {percent} busy, mostly {app}. It eases once that work finishes, or quit the app.", ["percent": percent(s.cpu.load), "app": $0.name])
            } ?? L("The processor is {percent} busy. It eases once that work finishes, or quit the app.", ["percent": percent(s.cpu.load)])
            out.append(Concern(tone: .warn, title: L("Your Mac is working very hard"), advice: advice))
        }
        if let d = s.startup {
            let share = d.total > 0 ? d.free / d.total : 1
            if d.free < 5e9 || share < 0.05 {
                out.append(Concern(tone: .bad, title: L("Your disk is almost full"),
                                   advice: L("Only {size} left. Empty the Trash and remove big files you don't need; System Settings › General › Storage shows what takes the space.", ["size": bytes(d.free)])))
            } else if d.free < 15e9 || share < 0.1 {
                out.append(Concern(tone: .warn, title: L("Disk space is getting low"),
                                   advice: L("{size} left. Empty the Trash, and look in Downloads for things you no longer need.", ["size": bytes(d.free)])))
            }
        }
        if let b = s.battery {
            let left = ["percent": charge(b.percent)]
            if !b.pluggedIn, b.percent <= 10 {
                out.append(Concern(tone: .bad, title: L("The battery is almost empty"), advice: L("{percent} left. Plug in now.", left)))
            } else if !b.pluggedIn, b.percent <= 20 {
                out.append(Concern(tone: .warn, title: L("The battery is low"), advice: L("{percent} left. Plug in soon.", left)))
            }
            if b.failure {
                out.append(Concern(tone: .warn, title: L("The battery needs service"), advice: L("The battery reports a fault. Apple can check and replace it.")))
            } else if let h = b.health, h < 0.8 {
                out.append(Concern(tone: .warn, title: L("The battery has worn"),
                                   advice: L("It holds {percent} of its charge when new, so it runs out sooner. Apple can replace it.", ["percent": percent(h)])))
            }
        }
        if let up = s.uptime, up > 14 * 86_400 {
            out.append(Concern(tone: .info, title: L("On for {time}", ["time": duration(up)]), advice: L("A restart clears out memory and finishes installing updates.")))
        }
        return out.sorted { $0.rank < $1.rank }
    }

    static func summary(_ s: Snapshot) -> Summary {
        let worst = concerns(s).first { $0.tone != .info }
        return Summary(worst?.title ?? L("Your Mac is doing fine"), detail: glance(s), tone: worst?.tone ?? .good,
                       symbol: worst == nil ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
    }

    /// "CPU 12% · Memory 61% · 214 GB free · Battery 84%"
    static func glance(_ s: Snapshot) -> String {
        var parts = [L("CPU {percent}", ["percent": percent(s.cpu.load)])]
        if let m = s.memory { parts.append(L("Memory {percent}", ["percent": percent(m.used / m.total)])) }
        if let d = s.startup { parts.append(L("{size} free", ["size": bytes(d.free)])) }
        if let b = s.battery { parts.append(L("Battery {percent}", ["percent": charge(b.percent)])) }
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
        case .nominal: (L("Cool"), .good)
        case .fair: (L("Warm"), .good)
        case .serious: (L("Hot"), .warn)
        case .critical: (L("Very hot"), .bad)
        @unknown default: (L("Unknown"), .neutral)
        }
    }

    static func pressureWord(_ p: Int) -> String {
        p >= 4 ? L("critical: apps are being slowed") : p >= 2 ? L("high: macOS is squeezing memory") : L("normal: no strain")
    }

    static func batteryState(_ b: Probe.Battery) -> String {
        if b.full || (b.pluggedIn && !b.charging && b.percent >= 95) { return L("Charged") }
        if b.charging { return b.minutesLeft.map { L("Charging, full in {time}", ["time": minutes($0)]) } ?? L("Charging") }
        if b.pluggedIn { return L("Plugged in, not charging") }
        return b.minutesLeft.map { L("On battery, {time} left", ["time": minutes($0)]) } ?? L("On battery")
    }

    static func healthWord(_ b: Probe.Battery) -> String? {
        if b.failure { return L("Needs service") }
        guard let h = b.health else { return nil }
        return L("{percent} of new", ["percent": percent(h)]) + " · " + (h >= 0.8 ? L("Normal") : L("Worn"))
    }

    static func cores(_ s: Probe.Specs) -> String {
        let all = L(one: "{count} core", other: "{count} cores", count: s.cores)
        guard let p = s.performanceCores, let e = s.efficiencyCores, p > 0, e > 0 else { return all }
        return L("{cores} ({performance} performance, {efficiency} efficiency)", ["cores": all, "performance": p, "efficiency": e])
    }

    // MARK: Numbers

    static func percent(_ fraction: Double) -> String { Format.percent(min(max(fraction, 0), 9.99)) }

    /// The battery's charge, a whole percent.
    static func charge(_ percent: Int) -> String { Format.percent(points: Double(percent)) }

    /// 1.2 GB, 340 MB, 12 KB: decimal, as Finder counts, in the person's language ("1,2 Go"). Rounded first to a
    /// tenth under 100 of a unit, a whole one above, so a size never shows more digits than it means.
    static func bytes(_ n: Double) -> String { Format.bytes(Int64(rounded(max(0, n), unit: 1000))) }

    /// Memory as macOS and Apple count it, in binary units: a 24 GB Mac shows 24 GB, not 25.8.
    static func memory(_ n: Double) -> String { Format.bytes(Int64(rounded(max(0, n), unit: 1024)), style: .memory) }

    /// `n` rounded in its own unit (KB, MB, GB, TB of `unit`): one decimal below 100 of it, none above.
    static func rounded(_ n: Double, unit: Double) -> Double {
        var scale = 1.0
        while n >= scale * unit, scale < pow(unit, 4) { scale *= unit }
        let value = n / scale
        return (value >= 100 ? value.rounded() : (value * 10).rounded() / 10) * scale
    }

    static func rate(_ bytesPerSecond: Double) -> String {
        guard bytesPerSecond > 0 else { return L("{size}/s", ["size": Format.bytes(0)]) }
        guard bytesPerSecond >= 1e3 else { return L("under {rate}", ["rate": L("{size}/s", ["size": Format.bytes(1000)])]) }
        return L("{size}/s", ["size": bytes(bytesPerSecond)])
    }

    static func minutes(_ m: Int) -> String { Format.duration(Double(m) * 60, units: [.hours, .minutes]) }

    static func duration(_ seconds: TimeInterval) -> String {
        Format.duration(seconds, units: seconds >= 86_400 ? [.days, .hours] : [.hours, .minutes], width: .wide)
    }
}
