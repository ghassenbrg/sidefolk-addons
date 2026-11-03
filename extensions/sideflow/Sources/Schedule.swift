import Foundation

/// When a trigger next fires, and what a gap in time means. Pure: the engine owns the clock.
enum Schedule {
    /// Later than this is late, not on time: a Mac that woke a minute after 8:30 just ran at 8:31.
    static let onTime: TimeInterval = 5 * 60

    static func next(_ trigger: Trigger, after: Date, calendar: Calendar = .autoupdatingCurrent) -> Date? {
        switch trigger {
        case .manual, .watch, .event:
            return nil
        case .every(let minutes, _):
            return after.addingTimeInterval(Double(minutes) * 60)
        case .days(let days, let hour, let minute, _):
            var parts = DateComponents()
            parts.hour = hour
            parts.minute = minute
            var day = calendar.startOfDay(for: after)
            // Eight days always reach every weekday again.
            for _ in 0...8 {
                if let at = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day), at > after, days.contains(isoWeekday(at, calendar)) { return at }
                guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: day) else { return nil }
                day = tomorrow
            }
            return nil
        }
    }

    /// 1 is Monday, whatever the calendar's first day.
    static func isoWeekday(_ date: Date, _ calendar: Calendar) -> Int {
        let w = calendar.component(.weekday, from: date)
        return w == 1 ? 7 : w - 1
    }

    /// What the clock says at `now`, counting from `last`: the latest time due (nil: none), and how many were due in all.
    static func due(_ trigger: Trigger, last: Date, now: Date, calendar: Calendar = .autoupdatingCurrent) -> (latest: Date, count: Int)? {
        var latest: Date?, count = 0, from = last
        // Bounded: a Mac off for a year doesn't walk a year of quarter hours.
        while count < 2000, let at = next(trigger, after: from, calendar: calendar), at <= now {
            latest = at
            count += 1
            from = at
        }
        if count == 2000, case .every(let minutes, _) = trigger {
            let step = Double(minutes) * 60, skipped = (now.timeIntervalSince(from) / step).rounded(.down)
            latest = from.addingTimeInterval(skipped * step)
            count += Int(skipped)
        }
        return latest.map { ($0, count) }
    }

    static func catchesUp(_ trigger: Trigger) -> Bool {
        switch trigger {
        case .days(_, _, _, let c), .every(_, let c): c
        default: false
        }
    }
}
