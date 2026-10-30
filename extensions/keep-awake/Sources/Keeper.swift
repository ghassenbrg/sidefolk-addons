import Darwin
import Foundation
import IOKit
import IOKit.pwr_mgt

/// Holds the Mac awake for the session, with macOS's own power assertions (what `caffeinate` uses), and asks
/// Sidefolk for a nudge while the person is idle and wants to stay active. Checks every five seconds.
@MainActor
final class Keeper {
    private(set) var session: Session?
    /// How the next session starts: the page's switches.
    private(set) var defaults = Session(started: .distantPast)
    private(set) var hold: Hold = .ended("")
    /// When the last session ended, and why: for the page and the heads-up.
    private(set) var lastEnd: (at: Date, why: String)?
    private(set) var nudges = 0
    private var assertion: IOPMAssertionID?
    private var assertionScreen: Bool?
    private var lastNudge = Date.distantPast
    private var jitter = Double.random(in: 0...1)
    private let file: URL
    var nudge: () -> Void = {}

    init(folder: URL) {
        file = folder.appendingPathComponent("session.json")
        if let data = try? Data(contentsOf: file), let saved = try? JSONDecoder.session.decode(Saved.self, from: data) {
            session = saved.session
            defaults = saved.defaults ?? defaults
            lastEnd = saved.endedAt.map { ($0, saved.endedWhy ?? "") }
        }
    }

    private struct Saved: Codable {
        var session: Session?
        var defaults: Session?
        var endedAt: Date?
        var endedWhy: String?
    }

    func start(_ s: Session) {
        session = s
        nudges = 0
        save()
        check()
    }

    /// A switch: for the session under way and the ones after.
    func set(_ change: (inout Session) -> Void) {
        change(&defaults)
        if var s = session {
            change(&s)
            session = s
        }
        save()
        check()
    }

    /// Longer by `minutes`; a session with no end keeps none.
    func extend(minutes: Int, now: Date = Date()) {
        guard var s = session, let until = s.until else { return }
        s.until = max(until, now).addingTimeInterval(Double(minutes) * 60)
        session = s
        save()
    }

    func stop(_ why: String = "You stopped it.") {
        guard session != nil else { return }
        session = nil
        lastEnd = (Date(), why)
        release()
        save()
    }

    func run() async {
        while !Task.isCancelled {
            check()
            try? await Task.sleep(for: .seconds(5))
        }
    }

    func check(now: Date = Date()) {
        guard let s = session else {
            release()
            return
        }
        let battery = Self.battery()
        hold = Rules.hold(s, now: now, plugged: battery?.plugged, battery: battery?.percent, appOpen: s.whileApp.map(Self.isOpen))
        switch hold {
        case .holding:
            take(screen: s.screen)
            if s.active, Rules.shouldNudge(idle: Self.idle(), sinceLast: now.timeIntervalSince(lastNudge), jitter: jitter) {
                lastNudge = now
                jitter = .random(in: 0...1)
                nudges += 1
                nudge()
            }
        case .waiting:
            release()
        case .ended(let why):
            stop(why)
        }
    }

    private func take(screen: Bool) {
        if assertion != nil, assertionScreen == screen { return }
        release()
        var id: IOPMAssertionID = 0
        let type = (screen ? kIOPMAssertionTypePreventUserIdleDisplaySleep : kIOPMAssertionTypePreventUserIdleSystemSleep) as CFString
        if IOPMAssertionCreateWithName(type, IOPMAssertionLevel(kIOPMAssertionLevelOn), "Sidefolk Keep Awake" as CFString, &id) == kIOReturnSuccess {
            assertion = id
            assertionScreen = screen
        }
    }

    private func release() {
        if let assertion { IOPMAssertionRelease(assertion) }
        assertion = nil
        assertionScreen = nil
    }

    var isHolding: Bool { assertion != nil }

    private func save() {
        let saved = Saved(session: session, defaults: defaults, endedAt: lastEnd?.at, endedWhy: lastEnd?.why)
        if let data = try? JSONEncoder.session.encode(saved) { try? data.write(to: file, options: [.atomic]) }
    }

    // MARK: Readings

    /// Seconds since the last key press or pointer move, as macOS counts it.
    static func idle() -> TimeInterval {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOHIDSystem"))
        guard service != 0 else { return 0 }
        defer { IOObjectRelease(service) }
        let value = IORegistryEntryCreateCFProperty(service, "HIDIdleTime" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
        return ((value as? NSNumber)?.doubleValue ?? 0) / 1e9
    }

    static func battery() -> (percent: Int, plugged: Bool)? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        var props: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let p = props?.takeRetainedValue() as? [String: Any], let current = (p["CurrentCapacity"] as? NSNumber)?.doubleValue else { return nil }
        let max = (p["MaxCapacity"] as? NSNumber)?.doubleValue ?? 100
        return (Int((max > 100 ? current / max * 100 : current).rounded()), (p["ExternalConnected"] as? Bool) ?? false)
    }

    /// Whether an app by that name is running: any process inside "<name>.app", read from the processes themselves
    /// (the sandbox keeps Launch Services closed).
    static func isOpen(_ name: String) -> Bool { openApps().contains { $0.caseInsensitiveCompare(name) == .orderedSame } }

    static func openApps() -> Set<String> {
        var pids = [pid_t](repeating: 0, count: 8192)
        let n = Int(proc_listallpids(&pids, Int32(pids.count * MemoryLayout<pid_t>.size)))
        var path = [CChar](repeating: 0, count: Int(MAXPATHLEN) * 4)
        var names: Set<String> = []
        for pid in pids.prefix(max(0, n)) where pid > 0 {
            let length = proc_pidpath(pid, &path, UInt32(path.count))
            guard length > 0 else { continue }
            let p = String(decoding: path.prefix(Int(length)).map { UInt8(bitPattern: $0) }, as: UTF8.self)
            if p.hasPrefix("/System/Library/") { continue }
            if let app = p.split(separator: "/").first(where: { $0.hasSuffix(".app") }) { names.insert(String(app.dropLast(4))) }
        }
        return names
    }
}

extension JSONEncoder {
    static var session: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }
}

extension JSONDecoder {
    static var session: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}
