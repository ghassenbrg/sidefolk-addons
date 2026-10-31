import Darwin
import Foundation
import IOKit
import SidefolkExtensionKit

/// Everything Your Mac reads, straight from macOS: Mach host statistics, sysctl, the I/O Registry and each
/// process's own counters. No program runs and nothing leaves the Mac, so the sandbox needs nothing beyond its
/// defaults. Rates (CPU, per app, network) are differences between two readings: the extension keeps the last one,
/// and takes a second a moment later when it has none recent.
@MainActor
enum Probe {
    // MARK: Processor

    struct Ticks {
        var user: Double, system: Double, idle: Double, nice: Double
        var busy: Double { user + system + nice }
        var total: Double { busy + idle }
    }

    struct CPU {
        /// 0–1 of all cores together.
        var load: Double
        var user: Double
        var system: Double
        /// Each core's load, 0–1, in the system's order (performance cores first on Apple silicon).
        var cores: [Double]
        var loadAverage: [Double]
    }

    private static var lastTicks: (at: Date, cores: [Ticks])?

    static func ticks() -> [Ticks] {
        var count: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        guard host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &count, &info, &infoCount) == KERN_SUCCESS,
              let info else { return [] }
        defer { vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), vm_size_t(infoCount) * vm_size_t(MemoryLayout<integer_t>.stride)) }
        return (0..<Int(count)).map { core in
            let base = core * Int(CPU_STATE_MAX)
            func at(_ state: Int32) -> Double { Double(UInt32(bitPattern: info[base + Int(state)])) }
            return Ticks(user: at(CPU_STATE_USER), system: at(CPU_STATE_SYSTEM), idle: at(CPU_STATE_IDLE), nice: at(CPU_STATE_NICE))
        }
    }

    static func cpu() async -> CPU {
        if lastTicks == nil || Date().timeIntervalSince(lastTicks!.at) > 30 {
            lastTicks = (Date(), ticks())
            try? await Task.sleep(for: .milliseconds(400))
        }
        let now = ticks()
        let before = lastTicks?.cores ?? []
        lastTicks = (Date(), now)
        return cpu(before: before, after: now)
    }

    static func cpu(before: [Ticks], after: [Ticks]) -> CPU {
        var user = 0.0, system = 0.0, total = 0.0
        var cores: [Double] = []
        for (a, b) in zip(before, after) {
            let dTotal = max(0, b.total - a.total)
            let dBusy = max(0, b.busy - a.busy)
            cores.append(dTotal > 0 ? min(1, dBusy / dTotal) : 0)
            user += max(0, b.user + b.nice - a.user - a.nice)
            system += max(0, b.system - a.system)
            total += dTotal
        }
        var load = [Double](repeating: 0, count: 3)
        getloadavg(&load, 3)
        return CPU(load: total > 0 ? min(1, (user + system) / total) : 0, user: total > 0 ? user / total : 0,
                   system: total > 0 ? system / total : 0, cores: cores, loadAverage: load)
    }

    /// The graphics processor's own figure for how busy it is, 0–1; nil when it doesn't say.
    static func gpu() -> Double? {
        var best: Double?
        forEach("IOAccelerator") { props in
            if let stats = props["PerformanceStatistics"] as? [String: Any], let used = stats["Device Utilization %"] as? NSNumber {
                best = max(best ?? 0, min(1, used.doubleValue / 100))
            }
        }
        return best
    }

    // MARK: Memory

    struct Memory {
        var total: Double
        var app: Double
        var wired: Double
        var compressed: Double
        /// Files kept in memory to be quick next time, given back as soon as anything needs it.
        var cached: Double
        var free: Double
        var swapUsed: Double
        /// 1 normal, 2 warning, 4 critical: the kernel's own judgement.
        var pressure: Int
        /// Activity Monitor's "Memory Used".
        var used: Double { app + wired + compressed }
    }

    static func memory() -> Memory? {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let status = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count) }
        }
        guard status == KERN_SUCCESS, let total: UInt64 = sysctl("hw.memsize") else { return nil }
        let page = Double(sysctl("hw.pagesize") as Int? ?? 16_384)
        var swap = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        let swapUsed = sysctlbyname("vm.swapusage", &swap, &size, nil, 0) == 0 ? Double(swap.xsu_used) : 0
        let app = max(0, Double(stats.internal_page_count) - Double(stats.purgeable_count)) * page
        return Memory(total: Double(total), app: app, wired: Double(stats.wire_count) * page,
                      compressed: Double(stats.compressor_page_count) * page,
                      cached: (Double(stats.external_page_count) + Double(stats.purgeable_count)) * page,
                      free: Double(stats.free_count) * page, swapUsed: swapUsed,
                      pressure: Int(sysctl("kern.memorystatus_vm_pressure_level") as Int32? ?? 1))
    }

    // MARK: Apps

    struct App: Equatable {
        var name: String
        /// Share of one core: 1.5 is a core and a half.
        var cpu: Double
        /// Memory it holds, as Activity Monitor's "Memory" column counts it.
        var memory: Double
        var processes: Int
    }

    private static var lastTimes: (at: Date, ns: [pid_t: Double])?

    /// Every process this user can see, gathered by the app it belongs to: a browser's dozen helpers are one line.
    static func apps() async -> [App] {
        if lastTimes == nil || Date().timeIntervalSince(lastTimes!.at) > 30 {
            lastTimes = (Date(), processes().mapValues(\.ns))
            try? await Task.sleep(for: .milliseconds(400))
        }
        let now = processes()
        let elapsed = max(0.05, Date().timeIntervalSince(lastTimes?.at ?? .distantPast)) * 1e9
        let before = lastTimes?.ns ?? [:]
        lastTimes = (Date(), now.mapValues(\.ns))
        var apps: [String: App] = [:]
        for (pid, p) in now {
            let cpu = before[pid].map { max(0, p.ns - $0) / elapsed } ?? 0
            var app = apps[p.app] ?? App(name: p.app, cpu: 0, memory: 0, processes: 0)
            app.cpu += cpu
            app.memory += p.footprint
            app.processes += 1
            apps[p.app] = app
        }
        return Array(apps.values)
    }

    private static let timebase: Double = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return info.denom == 0 ? 1 : Double(info.numer) / Double(info.denom)
    }()

    private static func processes() -> [pid_t: (app: String, ns: Double, footprint: Double)] {
        var pids = [pid_t](repeating: 0, count: 8192)
        let n = Int(proc_listallpids(&pids, Int32(pids.count * MemoryLayout<pid_t>.size)))
        var out: [pid_t: (String, Double, Double)] = [:]
        var path = [CChar](repeating: 0, count: Int(MAXPATHLEN) * 4)
        let me = getpid()
        for pid in pids.prefix(max(0, n)) where pid > 0 && pid != me {
            var usage = rusage_info_v4()
            let ok = withUnsafeMutablePointer(to: &usage) {
                $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { proc_pid_rusage(pid, RUSAGE_INFO_V4, $0) }
            }
            guard ok == 0 else { continue }
            let length = proc_pidpath(pid, &path, UInt32(path.count))
            var name = length > 0 ? appName(String(decoding: path.prefix(Int(length)).map { UInt8(bitPattern: $0) }, as: UTF8.self)) : ""
            if name.isEmpty {
                var short = [CChar](repeating: 0, count: 256)
                name = proc_name(pid, &short, 256) > 0 ? String(decoding: short.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self) : L("Process {pid}", ["pid": String(pid)])
            }
            let ns = Double(usage.ri_user_time + usage.ri_system_time) * timebase
            out[pid] = (name, ns, Double(usage.ri_phys_footprint))
        }
        return out
    }

    /// "/Applications/Google Chrome.app/…/Google Chrome Helper (Renderer).app/…" → "Google Chrome"; a program that
    /// isn't in an app keeps its own name ("WindowServer").
    nonisolated static func appName(_ path: String) -> String {
        // A program replaced while it runs (an update) reports "… (deleted)".
        let path = path.hasSuffix(" (deleted)") ? String(path.dropLast(10)) : path
        let parts = path.split(separator: "/")
        if let app = parts.first(where: { $0.hasSuffix(".app") }) { return String(app.dropLast(4)) }
        return parts.last.map(String.init) ?? path
    }

    // MARK: Battery and power

    struct Battery {
        var percent: Int
        var charging: Bool
        var pluggedIn: Bool
        var full: Bool
        /// Minutes to empty or to full, as the battery works them out; nil while it is still working it out.
        var minutesLeft: Int?
        var cycles: Int?
        /// What it holds now against what it held new, 0–1.
        var health: Double?
        var celsius: Double?
        var adapterWatts: Int?
        var failure: Bool
    }

    static func battery() -> Battery? {
        guard let p = properties("AppleSmartBattery"), (p["BatteryInstalled"] as? Bool) ?? true,
              let current = (p["CurrentCapacity"] as? NSNumber)?.doubleValue else { return nil }
        let max = (p["MaxCapacity"] as? NSNumber)?.doubleValue ?? 100
        let data = p["BatteryData"] as? [String: Any]
        let design = ((data?["DesignCapacity"] ?? p["DesignCapacity"]) as? NSNumber)?.doubleValue
        let holds = ((data?["NominalChargeCapacity"] ?? p["AppleRawMaxCapacity"] ?? p["NominalChargeCapacity"]) as? NSNumber)?.doubleValue
        let remaining = (p["TimeRemaining"] as? NSNumber)?.intValue
        let temperature = (p["Temperature"] as? NSNumber)?.doubleValue
        return Battery(percent: Int((max > 100 ? current / max * 100 : current).rounded()),
                       charging: (p["IsCharging"] as? Bool) ?? false, pluggedIn: (p["ExternalConnected"] as? Bool) ?? false,
                       full: (p["FullyCharged"] as? Bool) ?? false,
                       minutesLeft: remaining.flatMap { $0 > 0 && $0 < 65535 ? $0 : nil },
                       cycles: (p["CycleCount"] as? NSNumber)?.intValue,
                       health: design.flatMap { d in holds.map { min(1, $0 / d) } }.flatMap { $0 > 0 ? $0 : nil },
                       celsius: temperature.flatMap { $0 > 0 ? $0 / 100 : nil },
                       adapterWatts: ((p["AdapterDetails"] as? [String: Any])?["Watts"] as? NSNumber)?.intValue,
                       failure: ((p["PermanentFailureStatus"] as? NSNumber)?.intValue ?? 0) != 0)
    }

    /// nominal, fair, serious or critical: how hard macOS is working to keep the Mac cool.
    static func thermal() -> ProcessInfo.ThermalState { ProcessInfo.processInfo.thermalState }

    // MARK: Network

    struct Network {
        /// Bytes a second, in and out, over every interface but the loopback.
        var down: Double
        var up: Double
        var received: Double
        var sent: Double
        var address: String?
        var interface: String?
    }

    private static var lastBytes: (at: Date, down: Double, up: Double)?

    static func network() async -> Network {
        if lastBytes == nil || Date().timeIntervalSince(lastBytes!.at) > 30 {
            let first = counters()
            lastBytes = (Date(), first.down, first.up)
            try? await Task.sleep(for: .milliseconds(400))
        }
        let now = counters()
        let elapsed = max(0.05, Date().timeIntervalSince(lastBytes?.at ?? .distantPast))
        let rate = (down: max(0, now.down - (lastBytes?.down ?? now.down)) / elapsed, up: max(0, now.up - (lastBytes?.up ?? now.up)) / elapsed)
        lastBytes = (Date(), now.down, now.up)
        let address = localAddress()
        return Network(down: rate.down, up: rate.up, received: now.down, sent: now.up, address: address?.ip, interface: address?.interface)
    }

    /// The routing table's 64-bit byte counters (`NET_RT_IFLIST2`); `getifaddrs` gives 32-bit ones that wrap at 4 GB.
    static func counters() -> (down: Double, up: Double) {
        var mib: [Int32] = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
        var length = 0
        guard Darwin.sysctl(&mib, 6, nil, &length, nil, 0) == 0, length > 0 else { return (0, 0) }
        var buffer = [UInt8](repeating: 0, count: length)
        guard Darwin.sysctl(&mib, 6, &buffer, &length, nil, 0) == 0 else { return (0, 0) }
        var down = 0.0, up = 0.0
        var offset = 0
        buffer.withUnsafeBytes { raw in
            while offset + MemoryLayout<if_msghdr>.size <= length {
                let header = raw.load(fromByteOffset: offset, as: if_msghdr.self)
                guard header.ifm_msglen > 0 else { break }
                if Int32(header.ifm_type) == RTM_IFINFO2, offset + MemoryLayout<if_msghdr2>.size <= length {
                    let info = raw.loadUnaligned(fromByteOffset: offset, as: if_msghdr2.self)
                    if info.ifm_flags & IFF_LOOPBACK == 0 {
                        down += Double(info.ifm_data.ifi_ibytes)
                        up += Double(info.ifm_data.ifi_obytes)
                    }
                }
                offset += Int(header.ifm_msglen)
            }
        }
        return (down, up)
    }

    static func localAddress() -> (ip: String, interface: String)? {
        var list: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&list) == 0, let first = list else { return nil }
        defer { freeifaddrs(list) }
        var found: (String, String)?
        for entry in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let a = entry.pointee
            guard let addr = a.ifa_addr, addr.pointee.sa_family == UInt8(AF_INET),
                  a.ifa_flags & UInt32(IFF_UP) != 0, a.ifa_flags & UInt32(IFF_LOOPBACK) == 0 else { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard getnameinfo(addr, socklen_t(addr.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 else { continue }
            let name = String(cString: a.ifa_name)
            // en0 is the built-in Wi-Fi or Ethernet: the one people mean.
            if found == nil || name == "en0" {
                found = (String(decoding: host.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self), name)
            }
        }
        return found
    }

    // MARK: Storage

    struct Volume {
        var name: String
        var free: Double
        var total: Double
        var external: Bool
        var used: Double { max(0, total - free) }
    }

    /// The startup disk, then every other disk that shows in Finder.
    static func volumes() -> [Volume] {
        var mounts: UnsafeMutablePointer<statfs>?
        let n = Int(getmntinfo(&mounts, MNT_NOWAIT))
        guard let mounts else { return [] }
        var out: [Volume] = []
        for i in 0..<n {
            var m = mounts[i]
            guard m.f_flags & UInt32(MNT_DONTBROWSE) == 0, m.f_flags & UInt32(MNT_LOCAL) != 0, m.f_blocks > 0 else { continue }
            let path = withUnsafeBytes(of: &m.f_mntonname) { String(cString: $0.bindMemory(to: CChar.self).baseAddress!) }
            let size = Double(m.f_bsize)
            let url = URL(fileURLWithPath: path)
            let values = try? url.resourceValues(forKeys: [.volumeLocalizedNameKey, .volumeAvailableCapacityForImportantUsageKey])
            // Finder's figure, as System Settings shows it, also counts what macOS frees by itself (caches, old
            // snapshots). Sidefolk's sandbox opens the service behind it; the file system's own count is the floor.
            let free = max(Double(m.f_bavail) * size, values?.volumeAvailableCapacityForImportantUsage.map(Double.init) ?? 0)
            out.append(Volume(name: values?.volumeLocalizedName ?? (path == "/" ? "Macintosh HD" : url.lastPathComponent),
                              free: free, total: Double(m.f_blocks) * size, external: path != "/"))
        }
        return out.sorted { !$0.external && $1.external }
    }

    // MARK: This Mac

    struct Specs {
        var chip: String
        var model: String?
        var performanceCores: Int?
        var efficiencyCores: Int?
        var cores: Int
        var gpuCores: Int?
        var memory: Double
        var macOS: String
        var booted: Date?
    }

    static func specs() -> Specs {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        let build = sysctlString("kern.osversion").map { " (\($0))" } ?? ""
        var boot = timeval()
        var size = MemoryLayout<timeval>.size
        let booted = sysctlbyname("kern.boottime", &boot, &size, nil, 0) == 0 ? Date(timeIntervalSince1970: Double(boot.tv_sec)) : nil
        var gpuCores: Int?
        forEach("IOAccelerator") { gpuCores = gpuCores ?? ($0["gpu-core-count"] as? NSNumber)?.intValue }
        let patch = version.patchVersion > 0 ? ".\(version.patchVersion)" : ""
        return Specs(chip: sysctlString("machdep.cpu.brand_string") ?? L("Unknown processor"), model: sysctlString("hw.model"),
                     performanceCores: (sysctl("hw.perflevel0.physicalcpu") as Int32?).map(Int.init),
                     efficiencyCores: (sysctl("hw.perflevel1.physicalcpu") as Int32?).map(Int.init),
                     cores: (sysctl("hw.physicalcpu") as Int32?).map(Int.init) ?? ProcessInfo.processInfo.processorCount, gpuCores: gpuCores,
                     memory: Double(sysctl("hw.memsize") as UInt64? ?? 0),
                     macOS: "macOS \(version.majorVersion).\(version.minorVersion)\(patch)\(build)", booted: booted)
    }

    // MARK: Helpers

    static func properties(_ cls: String) -> [String: Any]? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching(cls))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        var props: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS else { return nil }
        return props?.takeRetainedValue() as? [String: Any]
    }

    static func forEach(_ cls: String, _ body: ([String: Any]) -> Void) {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching(cls), &iterator) == KERN_SUCCESS else { return }
        defer { IOObjectRelease(iterator) }
        var entry = IOIteratorNext(iterator)
        while entry != 0 {
            var props: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(entry, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
               let dict = props?.takeRetainedValue() as? [String: Any] { body(dict) }
            IOObjectRelease(entry)
            entry = IOIteratorNext(iterator)
        }
    }

    static func sysctl<T>(_ name: String) -> T? {
        let value = UnsafeMutablePointer<T>.allocate(capacity: 1)
        defer { value.deallocate() }
        var size = MemoryLayout<T>.size
        return sysctlbyname(name, value, &size, nil, 0) == 0 ? value.pointee : nil
    }

    static func sysctlString(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var bytes = [UInt8](repeating: 0, count: size)
        guard sysctlbyname(name, &bytes, &size, nil, 0) == 0 else { return nil }
        return String(decoding: bytes.prefix { $0 != 0 }, as: UTF8.self).trimmingCharacters(in: .whitespaces)
    }
}
