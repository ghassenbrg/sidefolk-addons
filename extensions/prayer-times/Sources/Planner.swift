import Foundation

enum ReminderKind: String, Hashable, Sendable, Codable {
    case prayerBefore, prayerStart, iqamah, suhoor, iftar, occasion, nameOfDay
}

/// One thing a person asked to be reminded of. Words are the pages' job; this says only what it was.
struct ReminderIntent: Hashable, Sendable, Codable {
    let kind: ReminderKind
    let prayer: PrayerID?
    let minutesBefore: Int?
    /// `Occasion.identity`
    let occasion: String?
    let daysBefore: Int?
    let nameNumber: Int?

    init(kind: ReminderKind, prayer: PrayerID? = nil, minutesBefore: Int? = nil, occasion: String? = nil, daysBefore: Int? = nil, nameNumber: Int? = nil) {
        (self.kind, self.prayer, self.minutesBefore, self.occasion, self.daysBefore, self.nameNumber) = (kind, prayer, minutesBefore, occasion, daysBefore, nameNumber)
    }
}

/// A future moment to remind at, on an absolute instant. The id has no fetch time or revision in it, so a refetch or a new
/// revision replaces the pending job instead of adding one.
struct PlannedOccurrence: Hashable, Sendable, Codable, Identifiable {
    let id: String
    let at: Date
    /// Past this, a late delivery would mislead more than help; a Suhoor notice after Fajr, say.
    let expiresAt: Date
    /// The first intent's, as `intents` may hold more than one.
    let kind: ReminderKind
    let prayer: PrayerID?
    let minutesBefore: Int?
    let sourceID: String
    /// The civil date it belongs to: the prayer's or occasion's, even when the reminder comes earlier.
    let date: CivilDate
    let group: String
    let systemFallback: Bool
    let intents: [ReminderIntent]
}

/// Turns preferences and validated data into the reminders that should exist, and only that: pages use it for previews and
/// the host's scheduler is what schedules, so calling it has no effect anywhere.
enum Planner {
    static let horizonDays = 35
    static let maximumOccurrences = 256
    /// How long a reminder right at an event stays worth delivering, matching the host's proposed wake grace.
    static let atEventGrace: TimeInterval = 120
    /// A start or Iftar reminder is still useful a while after the moment.
    static let afterStartGrace: TimeInterval = 30 * 60

    /// Every instant comes from the day it is listed under, or from a date the person chose: no day's data stands in for
    /// another's, so a date without data gets no reminders. Days from any source but `prefs.sourceID` are ignored.
    static func plan(now: Date, prefs: Preferences, days: [PrayerDay], ramadan: RamadanMonth?, occasions: [Occasion], names: [NameEntry]) -> [PlannedOccurrence] {
        let reminders = prefs.reminders
        // Ramadan's have a switch of their own: turning them on doesn't start what was left off, and the other way round.
        guard reminders.master || reminders.ramadan.enabled, reminders.route.companion || reminders.route.systemFallback else { return [] }
        let fallback = reminders.route.systemFallback
        let sourceDays = days.filter { $0.sourceID == prefs.sourceID }
        var planned: [(occurrence: PlannedOccurrence, zone: TimeZone)] = []

        func add(_ intent: ReminderIntent, id: String, at: Date, expiresAt: Date, sourceID: String, date: CivilDate, group: String, zone: TimeZone) {
            planned.append((PlannedOccurrence(id: id, at: at, expiresAt: expiresAt, kind: intent.kind, prayer: intent.prayer, minutesBefore: intent.minutesBefore,
                                              sourceID: sourceID, date: date, group: group, systemFallback: fallback, intents: [intent]), zone))
        }

        for day in reminders.master ? sourceDays : [] {
            for prayer in PrayerID.allCases {
                guard let choice = reminders.prayers[prayer], let start = day.starts[prayer] else { continue }
                let suffix = "\(day.date.iso).\(day.sourceID)"
                if let minutes = choice.beforeMinutes, Reminders.beforeBounds.contains(minutes) {
                    add(ReminderIntent(kind: .prayerBefore, prayer: prayer, minutesBefore: minutes), id: "prayer.\(prayer.rawValue).before\(minutes).\(suffix)",
                        at: start.addingTimeInterval(TimeInterval(-minutes * 60)), expiresAt: start, sourceID: day.sourceID, date: day.date, group: "prayer.\(prayer.rawValue)", zone: day.zone)
                }
                if choice.atStart {
                    add(ReminderIntent(kind: .prayerStart, prayer: prayer), id: "prayer.\(prayer.rawValue).start.\(suffix)",
                        at: start, expiresAt: start.addingTimeInterval(afterStartGrace), sourceID: day.sourceID, date: day.date, group: "prayer.\(prayer.rawValue)", zone: day.zone)
                }
                if let minutes = choice.iqamahMinutes, Reminders.iqamahBounds.contains(minutes), let iqamah = day.iqamah[prayer] {
                    add(ReminderIntent(kind: .iqamah, prayer: prayer, minutesBefore: minutes), id: "prayer.\(prayer.rawValue).iqamah\(minutes).\(suffix)",
                        at: iqamah.addingTimeInterval(TimeInterval(-minutes * 60)), expiresAt: minutes > 0 ? iqamah : iqamah.addingTimeInterval(atEventGrace),
                        sourceID: day.sourceID, date: day.date, group: "prayer.\(prayer.rawValue)", zone: day.zone)
                }
            }
        }

        if reminders.ramadan.enabled, let ramadan, ramadan.sourceID == prefs.sourceID, let zone = IANAZone.zone(ramadan.zoneID) {
            for day in ramadan.days where reminders.ramadan.days.contains(day.number) {
                let suffix = "\(day.date.iso).\(ramadan.sourceID)"
                if let minutes = reminders.ramadan.suhoorMinutesBeforeFajr, Reminders.suhoorBounds.contains(minutes) {
                    add(ReminderIntent(kind: .suhoor, prayer: .fajr, minutesBefore: minutes), id: "ramadan.suhoor\(minutes).\(suffix)",
                        at: day.fajr.addingTimeInterval(TimeInterval(-minutes * 60)), expiresAt: minutes > 0 ? day.fajr : day.fajr.addingTimeInterval(atEventGrace),
                        sourceID: ramadan.sourceID, date: day.date, group: "ramadan", zone: zone)
                }
                if reminders.ramadan.iftar {
                    add(ReminderIntent(kind: .iftar, prayer: .maghrib), id: "ramadan.iftar.\(suffix)",
                        at: day.maghrib, expiresAt: day.maghrib.addingTimeInterval(afterStartGrace), sourceID: ramadan.sourceID, date: day.date, group: "ramadan", zone: zone)
                }
            }
        }

        // Dates and Names belong to no timetable; only the place's zone says when their day is.
        if reminders.master, let zone = prefs.place?.zone ?? sourceDays.first?.zone {
            let choice = reminders.occasions
            if Reminders.daysBeforeBounds.contains(choice.daysBefore) {
                for occasion in Occasion.dedupe(occasions) where occasion.method == prefs.calendarMethod && choice.selected.contains(occasion.identity) {
                    let at = CivilClock.resolve(occasion.gregorian.adding(days: -choice.daysBefore), choice.time, in: zone).settled
                    add(ReminderIntent(kind: .occasion, occasion: occasion.identity, daysBefore: choice.daysBefore),
                        // The scheduler's ids are lower case and bounded; the date keeps a shortened one apart.
                        id: "occasion.\(occasion.identity.prefix(60)).before\(choice.daysBefore).\(occasion.gregorian.iso).\(occasion.method.rawValue.lowercased())",
                        at: at, expiresAt: CivilClock.startOfDay(occasion.gregorian.next, in: zone), sourceID: occasion.method.rawValue,
                        date: occasion.gregorian, group: "occasion", zone: zone)
                }
            }
            if reminders.nameOfDay.enabled, let time = LocalTime(hour: reminders.nameOfDay.hour, minute: reminders.nameOfDay.minute) {
                let today = CivilDate(now, in: zone)
                for offset in 0..<horizonDays {
                    let date = today.adding(days: offset)
                    let number = NoorSnapshot.nameOfTheDay(date)
                    guard names.contains(where: { $0.number == number }) else { continue }
                    add(ReminderIntent(kind: .nameOfDay, nameNumber: number), id: "name.\(date.iso)", at: CivilClock.resolve(date, time, in: zone).settled,
                        expiresAt: CivilClock.startOfDay(date.next, in: zone), sourceID: "names", date: date, group: "name", zone: zone)
                }
            }
        }

        let due = planned.filter { item in
            item.occurrence.at > now && item.occurrence.at >= (reminders.pausedUntil ?? item.occurrence.at)
                && item.occurrence.at < CivilClock.startOfDay(CivilDate(now, in: item.zone).adding(days: horizonDays), in: item.zone)
        }.map(\.occurrence)
        return Array(merge(due).sorted { ($0.at, $0.id) < ($1.at, $1.id) }.prefix(maximumOccurrences))
    }

    /// Two reminders for one prayer at one instant are one notice: Iftar on a Maghrib reminder, Suhoor on a Fajr one. The
    /// prayer's reminder stays first and keeps its id, and both intents stay. It ends at the earlier expiry, as a stale
    /// Suhoor notice is worse than a missed Fajr one.
    private static func merge(_ occurrences: [PlannedOccurrence]) -> [PlannedOccurrence] {
        struct Key: Hashable {
            let at: Date
            let prayer: PrayerID
        }
        var merged: [PlannedOccurrence] = []
        var positions: [Key: Int] = [:]
        for occurrence in occurrences {
            guard let prayer = occurrence.prayer else {
                merged.append(occurrence)
                continue
            }
            let key = Key(at: occurrence.at, prayer: prayer)
            guard let position = positions[key] else {
                positions[key] = merged.count
                merged.append(occurrence)
                continue
            }
            let first = merged[position]
            merged[position] = PlannedOccurrence(id: first.id, at: first.at, expiresAt: min(first.expiresAt, occurrence.expiresAt), kind: first.kind, prayer: first.prayer,
                                                 minutesBefore: first.minutesBefore, sourceID: first.sourceID, date: first.date, group: first.group,
                                                 systemFallback: first.systemFallback, intents: first.intents + occurrence.intents)
        }
        return merged
    }
}
