import Foundation

/// What the person chose. Nothing here defaults to a location or a calculation method: there is no recommended one.
struct Preferences: Hashable, Sendable, Codable {
    enum TimeFormat: String, CaseIterable, Hashable, Sendable, Codable { case system, hour12, hour24 }

    /// The shape `NoorStore` keeps on disk; raising it needs a step in `Migrations.shipped`.
    static let schemaVersion = 1

    var place: Place?
    var sourceID: String?
    var convention: PrayerConvention?
    /// A visible, changeable label on every date, not a recommendation.
    var calendarMethod: CalendarMethod = .uaq
    var timeFormat: TimeFormat = .system
    var showOccasions = true
    var showNameOfTheDay = true
    var reminders = Reminders()

    init() {}
}

/// Every reminder choice. All of it starts off, and turning on a prayer does nothing until the master and a route are on.
struct Reminders: Hashable, Sendable, Codable {
    struct Prayer: Hashable, Sendable, Codable {
        /// Minutes before the start, within `Reminders.beforeBounds`.
        var beforeMinutes: Int?
        var atStart = false
        /// Minutes before the source's iqamah, within `Reminders.iqamahBounds`; nothing happens where the source has none.
        var iqamahMinutes: Int?

        init(beforeMinutes: Int? = nil, atStart: Bool = false, iqamahMinutes: Int? = nil) {
            (self.beforeMinutes, self.atStart, self.iqamahMinutes) = (beforeMinutes, atStart, iqamahMinutes)
        }
    }

    struct Route: Hashable, Sendable, Codable {
        var companion = false
        var systemFallback = false

        init(companion: Bool = false, systemFallback: Bool = false) {
            (self.companion, self.systemFallback) = (companion, systemFallback)
        }
    }

    struct Ramadan: Hashable, Sendable, Codable {
        var enabled = false
        /// Ramadan day numbers chosen, from 1.
        var days: Set<Int> = []
        var suhoorMinutesBeforeFajr: Int?
        var iftar = false

        init(enabled: Bool = false, days: Set<Int> = [], suhoorMinutesBeforeFajr: Int? = nil, iftar: Bool = false) {
            (self.enabled, self.days, self.suhoorMinutesBeforeFajr, self.iftar) = (enabled, days, suhoorMinutesBeforeFajr, iftar)
        }
    }

    struct Occasions: Hashable, Sendable, Codable {
        /// `Occasion.identity` values.
        var selected: Set<String> = []
        var daysBefore = 0
        /// The place-local time the reminder comes on its day.
        var time = LocalTime(hour: 9, minute: 0)!

        init(selected: Set<String> = [], daysBefore: Int = 0, time: LocalTime = LocalTime(hour: 9, minute: 0)!) {
            (self.selected, self.daysBefore, self.time) = (selected, daysBefore, time)
        }
    }

    struct NameOfDay: Hashable, Sendable, Codable {
        var enabled = false
        var hour = 9
        var minute = 0

        init(enabled: Bool = false, hour: Int = 9, minute: Int = 0) {
            (self.enabled, self.hour, self.minute) = (enabled, hour, minute)
        }
    }

    static let beforeBounds = 1...180
    static let iqamahBounds = 0...60
    static let suhoorBounds = 0...180
    static let daysBeforeBounds = 0...30

    var master = false
    var prayers: [PrayerID: Prayer] = [:]
    var route = Route()
    var pausedUntil: Date?
    var ramadan = Ramadan()
    var occasions = Occasions()
    var nameOfDay = NameOfDay()

    init() {}
}
