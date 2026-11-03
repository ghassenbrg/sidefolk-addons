import Foundation

/// The five prayers, in their order. Sunrise is a `SolarEvent`, not one of these.
enum PrayerID: String, CaseIterable, Comparable, Hashable, Sendable, Codable, CodingKeyRepresentable {
    case fajr, dhuhr, asr, maghrib, isha

    static func < (a: PrayerID, b: PrayerID) -> Bool {
        allCases.firstIndex(of: a)! < allCases.firstIndex(of: b)!
    }
}

/// Solar and night markers: information, not prayers, with no reminders of their own.
enum SolarEvent: String, CaseIterable, Hashable, Sendable, Codable, CodingKeyRepresentable {
    case imsak, sunrise, sunset, midnight, firstThird, lastThird
}

/// A Friday session from an explicit source row, never inferred from Dhuhr. `id` is the row's name, like `friday-1`.
struct FridaySession: Hashable, Sendable, Codable {
    let id: String
    let start: Date
    let iqamah: Date?
}

/// What a calculated day says about how it was calculated, as the provider reported it.
struct MethodMetadata: Hashable, Sendable, Codable {
    let id: Int
    let name: String
    let school: String
    let latitudeAdjustment: String?
    let midnightMode: String?
}

/// One civil date of one source. Instants keep their own dates: a Last third can fall on the next day, an Isha too.
struct PrayerDay: Hashable, Sendable, Codable {
    let date: CivilDate
    let zoneID: String
    let sourceID: String
    let starts: [PrayerID: Date]
    /// Only what the source gave. A calculated day has none; nothing here is ever an offset from a start.
    let iqamah: [PrayerID: Date]
    /// A value the source didn't give is absent, not estimated.
    let solar: [SolarEvent: Date]
    let friday: [FridaySession]
    let method: MethodMetadata?
    let hijri: HijriDate?

    /// Refuses a day without all five starts, an unknown zone, or an iqamah before or without its start.
    init?(date: CivilDate, zoneID: String, sourceID: String, starts: [PrayerID: Date], iqamah: [PrayerID: Date] = [:],
          solar: [SolarEvent: Date] = [:], friday: [FridaySession] = [], method: MethodMetadata? = nil, hijri: HijriDate? = nil) {
        guard IANAZone.zone(zoneID) != nil, LocalID.isValid(sourceID), PrayerID.allCases.allSatisfy({ starts[$0] != nil }),
              iqamah.allSatisfy({ id, at in starts[id].map { at >= $0 } ?? false }) else { return nil }
        (self.date, self.zoneID, self.sourceID, self.starts, self.iqamah) = (date, zoneID, sourceID, starts, iqamah)
        (self.solar, self.friday, self.method, self.hijri) = (solar, friday, method, hijri)
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let day = PrayerDay(date: try c.decode(CivilDate.self, forKey: .date), zoneID: try c.decode(String.self, forKey: .zoneID),
                            sourceID: try c.decode(String.self, forKey: .sourceID), starts: try c.decode([PrayerID: Date].self, forKey: .starts),
                            iqamah: try c.decode([PrayerID: Date].self, forKey: .iqamah), solar: try c.decode([SolarEvent: Date].self, forKey: .solar),
                            friday: try c.decode([FridaySession].self, forKey: .friday), method: try c.decodeIfPresent(MethodMetadata.self, forKey: .method),
                            hijri: try c.decodeIfPresent(HijriDate.self, forKey: .hijri))
        guard let day else { throw DecodingError.dataCorruptedError(forKey: .starts, in: c, debugDescription: "Not a valid prayer day") }
        self = day
    }

    var zone: TimeZone { IANAZone.zone(zoneID)! }

    /// The prayers by their real instants, which is the order that counts when a far-north Isha crosses midnight.
    var ordered: [(id: PrayerID, at: Date)] {
        PrayerID.allCases.map { (id: $0, at: starts[$0]!) }.sorted { ($0.at, $0.id) < ($1.at, $1.id) }
    }
}

/// Where a timetable comes from. There are only these two kinds: a manual source is Manual, never Connected or Verified.
struct TimetableSource: Hashable, Sendable, Codable, Identifiable {
    enum Kind: String, CaseIterable, Hashable, Sendable, Codable { case calculated, manual }

    static let calculatedAttribution = "AlAdhan"

    let id: String
    let kind: Kind
    let name: String
    let zoneID: String
    /// Dates it can answer for; nil for a calculated source, which is open-ended.
    let coverage: ClosedRange<CivilDate>?
    /// Goes up when the data changes. Occurrence ids don't contain it, so a revision replaces pending jobs.
    let revision: Int
    let attribution: String
    let lastFetch: Date?

    init?(id: String, kind: Kind, name: String, zoneID: String, coverage: ClosedRange<CivilDate>? = nil, revision: Int = 1,
          attribution: String, lastFetch: Date? = nil) {
        guard LocalID.isValid(id), IANAZone.zone(zoneID) != nil, revision >= 0 else { return nil }
        (self.id, self.kind, self.name, self.zoneID, self.coverage) = (id, kind, name, zoneID, coverage)
        (self.revision, self.attribution, self.lastFetch) = (revision, attribution, lastFetch)
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let source = TimetableSource(id: try c.decode(String.self, forKey: .id), kind: try c.decode(Kind.self, forKey: .kind), name: try c.decode(String.self, forKey: .name),
                                     zoneID: try c.decode(String.self, forKey: .zoneID), coverage: try c.decodeIfPresent(ClosedRange<CivilDate>.self, forKey: .coverage),
                                     revision: try c.decode(Int.self, forKey: .revision), attribution: try c.decode(String.self, forKey: .attribution),
                                     lastFetch: try c.decodeIfPresent(Date.self, forKey: .lastFetch))
        guard let source else { throw DecodingError.dataCorruptedError(forKey: .id, in: c, debugDescription: "Not a valid source") }
        self = source
    }

    /// The calculated source for a place. Its id belongs to the place alone, so changing a method is a new revision of
    /// the same source and replaces pending reminders rather than adding to them.
    static func calculated(for place: Place, name: String = "AlAdhan", revision: Int = 1, lastFetch: Date? = nil) -> TimetableSource {
        TimetableSource(id: calculatedID(for: place), kind: .calculated, name: name, zoneID: place.zoneID, revision: revision,
                        attribution: calculatedAttribution, lastFetch: lastFetch)!
    }

    static func calculatedID(for place: Place) -> String { calculatedID(forPlaceID: place.id) }
    static func calculatedID(forPlaceID id: String) -> String { "calculated.\(id)" }

    var zone: TimeZone { IANAZone.zone(zoneID)! }
}
