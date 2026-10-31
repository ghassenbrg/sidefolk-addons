import Foundation
import SidefolkExtensionKit
import Testing
@testable import ext_system_vitals_plus

/// Your Mac's (system-vitals-plus) words with canned readings: what counts as a problem, what it says, and how the page is put
/// together. Its readings themselves run in Sidefolk's sandbox tests (ExtensionPageTests).
@MainActor
struct SystemVitalsPlusTests {
    static func snapshot(load: Double = 0.2, pressure: Int = 1, free: Double = 200e9, battery: Probe.Battery? = nil,
                         thermal: ProcessInfo.ThermalState = .nominal, days: Double = 2) -> Snapshot {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        return Snapshot(
            cpu: Probe.CPU(load: load, user: load * 0.7, system: load * 0.3, cores: [load, load], loadAverage: [2, 2, 2]), gpu: 0.1,
            memory: Probe.Memory(total: 24 * 1_073_741_824, app: 8e9, wired: 3e9, compressed: 2e9, cached: 5e9, free: 1e9, swapUsed: 0, pressure: pressure),
            apps: [Probe.App(name: "Xcode", cpu: 1.2, memory: 4e9, processes: 6), Probe.App(name: "Safari", cpu: 0.3, memory: 3e9, processes: 9),
                   Probe.App(name: "idle", cpu: 0.001, memory: 1e6, processes: 1)],
            battery: battery, thermal: thermal,
            network: Probe.Network(down: 1.5e6, up: 2e4, received: 3e9, sent: 1e9, address: "192.168.1.4", interface: "en0"),
            volumes: [Probe.Volume(name: "Macintosh HD", free: free, total: 500e9, external: false)],
            specs: Probe.Specs(chip: "Apple M4", model: "Mac16,1", performanceCores: 4, efficiencyCores: 6, cores: 10, gpuCores: 10,
                               memory: 24 * 1_073_741_824, macOS: "macOS 27.0", booted: now.addingTimeInterval(-days * 86_400)),
            now: now)
    }

    static func battery(_ percent: Int, plugged: Bool = false, health: Double? = 0.95) -> Probe.Battery {
        Probe.Battery(percent: percent, charging: plugged, pluggedIn: plugged, full: false, minutesLeft: 200, cycles: 300, health: health,
                      celsius: nil, adapterWatts: nil, failure: false)
    }

    @Test func aQuietMacIsFine() {
        let s = Self.snapshot(battery: Self.battery(80))
        #expect(Words.concerns(s).isEmpty)
        let summary = Words.summary(s)
        #expect(summary.title == "Your Mac is doing fine" && summary.tone == .good)
        #expect(summary.detail == "CPU 20% · Memory 50% · 200 GB free · Battery 80%")
    }

    @Test func problemsComeWorstFirstWithWhatToDo() {
        let s = Self.snapshot(load: 0.95, pressure: 4, free: 3e9, battery: Self.battery(15, health: 0.7), thermal: .serious, days: 20)
        let concerns = Words.concerns(s)
        #expect(concerns.map(\.title) == ["Memory is very tight", "Your disk is almost full", "Your Mac is hot", "Your Mac is working very hard",
                                          "The battery is low", "The battery has worn", "On for 20 days"])
        #expect(concerns[0].advice.contains("starting with Xcode (3.7 GB)"))
        #expect(Words.summary(s).title == "Memory is very tight" && Words.summary(s).tone == .bad)
        // Plugged in, a low battery is no problem.
        #expect(!Words.concerns(Self.snapshot(battery: Self.battery(5, plugged: true))).contains { $0.title.contains("battery") })
    }

    @Test func numbersReadAsPeopleExpect() {
        #expect(Words.memory(24 * 1_073_741_824) == "24 GB")
        #expect(Words.memory(15.6 * 1_073_741_824) == "15.6 GB")
        #expect(Words.bytes(494e9) == "494 GB" && Words.bytes(51e9) == "51 GB" && Words.bytes(51.26e9) == "51.3 GB" && Words.bytes(640e6) == "640 MB")
        #expect(Words.rate(1.45e6) == "1.5 MB/s" && Words.rate(300) == "under 1 kB/s" && Words.rate(0) == "0 bytes/s")
        #expect(Words.duration(3 * 86_400 + 4 * 3600) == "3 days, 4 hours" && Words.duration(3720) == "1 hour, 2 minutes")
        #expect(Words.cores(Self.snapshot().specs) == "10 cores (4 performance, 6 efficiency)")
        #expect(Probe.appName("/Applications/Google Chrome.app/Contents/Frameworks/Helpers/Google Chrome Helper (Renderer).app/Contents/MacOS/x") == "Google Chrome")
        #expect(Probe.appName("/System/Library/PrivateFrameworks/SkyLight.framework/Resources/WindowServer") == "WindowServer")
        #expect(Probe.appName("/Applications/Old.app/Contents/MacOS/Old (deleted)") == "Old")
    }

    @Test func theAnswersCarryTheNumbers() {
        let s = Self.snapshot(battery: Self.battery(64))
        #expect(Answers.cpu(s).contains("across 10 cores (4 performance, 6 efficiency)") && Answers.cpu(s).contains("Busiest: Xcode 60%, Safari 15%"))
        #expect(!Answers.cpu(s).contains("idle"), "an app using next to nothing isn't listed")
        #expect(Answers.memory(s).hasPrefix("12.1 GB of 24 GB in use; memory pressure is normal"))
        #expect(Answers.battery(s).hasPrefix("Battery at 64%, on battery, 3 hr, 20 min left. Health: 95% of new · Normal."))
        #expect(Answers.network(s).hasPrefix("This Mac's address on the network is 192.168.1.4 (en0)."))
        #expect(Answers.battery(Self.snapshot()) == "This Mac has no battery; it runs on power from the wall.")
    }

    @Test func thePageHasEverythingInOrder() {
        let page = MacPage.make(Self.snapshot(battery: Self.battery(64)))
        #expect(page.sections.compactMap(\.title) == ["Right now", "Over time", "What's using your Mac", "Memory", "Storage", "Battery", "Network",
                                                      "This Mac", "Ask about it"])
        // Without a battery, the fourth ring is the graphics and nobody is asked about a battery.
        let desktop = MacPage.make(Self.snapshot())
        #expect(!desktop.sections.compactMap(\.title).contains("Battery"))
        let asks: [String] = desktop.sections.last?.blocks.compactMap { b -> String? in if case .ask(let label, _) = b { label } else { nil } } ?? []
        #expect(!asks.contains { $0.contains("battery") })
    }
}
