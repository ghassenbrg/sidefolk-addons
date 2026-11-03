import Foundation
import SidefolkExtensionKit

/// What a reminder says, in the person's language at the moment it was planned. Short, plain and respectful: it reminds; it doesn't instruct.
@MainActor
enum PlanWords {
    static func title(_ occurrence: PlannedOccurrence, model: NoorModel) -> String {
        guard let intent = occurrence.intents.first else { return "" }
        switch intent.kind {
        case .prayerBefore: return L("{prayer} in {minutes} min", ["prayer": occurrence.prayer.map(Words.prayer) ?? "", "minutes": Format.integer(intent.minutesBefore ?? 0)])
        case .prayerStart: return occurrence.prayer.map(Words.prayer) ?? ""
        case .iqamah: return (intent.minutesBefore ?? 0) > 0 ? L("{prayer} iqamah in {minutes} min", ["prayer": occurrence.prayer.map(Words.prayer) ?? "", "minutes": Format.integer(intent.minutesBefore ?? 0)]) : L("{prayer} iqamah", ["prayer": occurrence.prayer.map(Words.prayer) ?? ""])
        case .suhoor: return (intent.minutesBefore ?? 0) > 0 ? L("Suhoor: Fajr in {minutes} min", ["minutes": Format.integer(intent.minutesBefore ?? 0)]) : L("Fajr: Suhoor reminder")
        case .iftar: return L("Iftar: Maghrib")
        case .occasion: return intent.occasion.flatMap { id in model.occasions.values.flatMap { $0 }.first { $0.identity == id }?.title } ?? L("A listed occasion")
        case .nameOfDay: return L("A Name for today")
        }
    }

    static func body(_ occurrence: PlannedOccurrence, model: NoorModel) -> String? {
        let zone = model.source?.zone ?? model.prefs.place?.zone ?? .current
        guard let intent = occurrence.intents.first else { return nil }
        switch intent.kind {
        case .prayerBefore, .prayerStart, .iqamah, .suhoor, .iftar:
            let day = occurrence.prayer.flatMap { prayer in model.day(occurrence.date).map { (prayer, $0) } }
            var parts: [String] = []
            if let (prayer, day) = day {
                parts.append(L("Starts {time}", ["time": Words.time(day.starts[prayer]!, zone: zone)]))
                if let iqamah = day.iqamah[prayer] { parts.append(L("Iqamah {time}", ["time": Words.time(iqamah, zone: zone)])) }
            }
            parts.append(Words.provenance(model.snapshot()))
            return parts.joined(separator: " · ")
        case .occasion:
            return L("{date}. Listed by the provider; local observance may differ.", ["date": Words.date(occurrence.date, weekday: false)])
        case .nameOfDay:
            guard let name = intent.nameNumber.flatMap({ n in model.names.first { $0.number == n } }) else { return nil }
            return "\(name.transliteration) · \(name.meaning) (\(L("English meaning")))"
        }
    }

    /// The times a prayer's reminder names, in the timetable's zone. Nothing for one that isn't about a prayer, and no iqamah where the source gives none.
    static func times(_ occurrence: PlannedOccurrence, model: NoorModel) -> (start: String?, iqamah: String?) {
        let zone = model.source?.zone ?? model.prefs.place?.zone ?? .current
        guard let prayer = occurrence.prayer, let day = model.day(occurrence.date) else { return (nil, nil) }
        return (day.starts[prayer].map { Words.time($0, zone: zone) }, day.iqamah[prayer].map { Words.time($0, zone: zone) })
    }

    /// The plan the host's scheduler holds, whole. Reading a page never reaches this: only Sidefolk's asking, or something that was just saved.
    static func plan(model: NoorModel) -> OccurrencePlan {
        let occurrences = model.planned().map { o -> Occurrence in
            var state: [String: Any] = ["tab": "prayer"]
            switch o.kind {
            case .nameOfDay: state = ["tab": "names"]
            case .occasion: state = ["tab": "calendar"]
            default: break
            }
            return Occurrence(id: o.id, at: o.at, expiresAt: o.expiresAt, title: title(o, model: model), body: body(o, model: model), group: o.group, systemFallback: o.systemFallback, openPage: "noor", openState: state)
        }
        return OccurrencePlan(revision: Occurrences.revision + 1, occurrences: occurrences)
    }
}
