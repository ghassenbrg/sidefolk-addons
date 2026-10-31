import Foundation
import SidefolkExtensionKit

/// What the person asked for: how long, what to keep, and when to let go by itself.
struct Session: Codable, Equatable {
    var started: Date
    /// Nil: until they stop it.
    var until: Date?
    /// The screen stays on; without it only the Mac stays awake and the screen may dim and sleep.
    var screen = true
    /// Chat and meeting apps keep seeing them as active (a pointer move of nothing now and then while idle).
    var active = false
    /// Lets go on battery.
    var pluggedOnly = false
    /// Lets go when the battery falls below this, in percent.
    var batteryFloor: Int? = 15
    /// Only while this app is open ("Zoom"), and ends when it quits.
    var whileApp: String?
}

/// Whether a session holds right now, and if not, why it ended or waits.
enum Hold: Equatable {
    case holding
    /// Over: its time came, or the app it waited on quit.
    case ended(String)
    /// Still on, but waiting: on battery when it should only run plugged in, or the battery is low.
    case waiting(String)
}

/// The rules, with no clocks or batteries of their own, so they can be checked with made-up ones.
enum Rules {
    static func hold(_ s: Session, now: Date, plugged: Bool?, battery: Int?, appOpen: Bool?) -> Hold {
        if let until = s.until, now >= until { return .ended("Its time is up.") }
        if let app = s.whileApp, appOpen == false { return .ended("\(app) quit.") }
        if s.pluggedOnly, plugged == false { return .waiting("Waiting to be plugged in.") }
        if let floor = s.batteryFloor, plugged == false, let level = battery, level < floor {
            return .waiting("The battery is below \(floor)%, so it's letting the Mac rest.")
        }
        return .holding
    }

    /// Nudge when idle for 45 s and nothing was sent for a minute or so; the gap wanders so it reads as a person.
    static func shouldNudge(idle: TimeInterval, sinceLast: TimeInterval, jitter: Double) -> Bool {
        idle >= 45 && sinceLast >= 50 + jitter * 20
    }

    /// "until 6pm", "18:30", "until 9" → the next such time from `now`.
    static func time(_ text: String, now: Date, calendar: Calendar = .current) -> Date? {
        var t = text.lowercased().trimmingCharacters(in: .whitespaces)
        if t.hasPrefix("until ") { t.removeFirst(6) }
        guard let m = t.firstMatch(of: /^(\d{1,2})(?::(\d{2}))?\s*(am|pm)?$/) else { return nil }
        var hour = Int(m.1) ?? 0
        let minute = m.2.flatMap { Int($0) } ?? 0
        if let half = m.3 {
            guard (1...12).contains(hour) else { return nil }
            hour = hour % 12 + (half == "pm" ? 12 : 0)
        }
        guard (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        guard let today = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: now) else { return nil }
        return today > now ? today : calendar.date(byAdding: .day, value: 1, to: today)
    }

    /// "1 h 30 min", "25 min" in the person's language: whole minutes, at least one.
    static func left(_ until: Date, now: Date) -> String {
        let minutes = max(1, Int(ceil(until.timeIntervalSince(now) / 60)))
        return Format.duration(Double(minutes) * 60, units: [.hours, .minutes])
    }

    /// A reason it ended or waits, in the person's language. Reasons are kept in English: one is saved with the last
    /// session and "You stopped it." is told apart from the others.
    static func shown(_ why: String) -> String {
        switch why {
        case "You stopped it.": return L("You stopped it.")
        case "Its time is up.": return L("Its time is up.")
        case "Waiting to be plugged in.": return L("Waiting to be plugged in.")
        default:
            if let m = why.wholeMatch(of: /The battery is below (\d+)%, so it's letting the Mac rest\./), let floor = Double(m.1) {
                return L("The battery is below {percent}, so it's letting the Mac rest.", ["percent": Format.percent(points: floor)])
            }
            if why.hasSuffix(" quit.") { return L("{app} quit.", ["app": String(why.dropLast(6))]) }
            return why
        }
    }
}
