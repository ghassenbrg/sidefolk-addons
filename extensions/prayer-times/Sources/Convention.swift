import Foundation

/// How prayer times are calculated. The calendar method is deliberately not in here: changing a school must not change
/// anyone's Hijri dates, and the other way round.
struct PrayerConvention: Hashable, Sendable, Codable {
    enum Problem: Error, Equatable, Sendable { case badMethod, badSchool, badLatitudeAdjustment, tuneOutOfBounds }

    static let tuneBounds = -30...30

    /// The provider's method id. 99 is its CUSTOM, which needs angles Noor doesn't offer.
    let method: Int
    /// 0 Standard (Shafi, Maliki, Hanbali), 1 Hanafi: only Asr differs.
    let school: Int
    /// 1 middle of the night, 2 one seventh, 3 angle-based; nil leaves it to the provider.
    let latitudeAdjustment: Int?
    /// Minutes added to a prayer's calculated start. Only non-zero entries are kept, so equal conventions compare equal.
    let tune: [PrayerID: Int]

    init(method: Int, school: Int = 0, latitudeAdjustment: Int? = nil, tune: [PrayerID: Int] = [:]) throws(Problem) {
        guard (0..<99).contains(method) else { throw .badMethod }
        guard school == 0 || school == 1 else { throw .badSchool }
        if let latitudeAdjustment, !(1...3).contains(latitudeAdjustment) { throw .badLatitudeAdjustment }
        guard tune.values.allSatisfy(Self.tuneBounds.contains) else { throw .tuneOutOfBounds }
        (self.method, self.school, self.latitudeAdjustment) = (method, school, latitudeAdjustment)
        self.tune = tune.filter { $0.value != 0 }
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(method: c.decode(Int.self, forKey: .method), school: c.decode(Int.self, forKey: .school),
                      latitudeAdjustment: c.decodeIfPresent(Int.self, forKey: .latitudeAdjustment),
                      tune: c.decode([PrayerID: Int].self, forKey: .tune))
    }
}

/// The Hijri calendar a view follows. An open set because the provider's list is what defines it (`/islamicCalendar/methods`);
/// the constants are the methods in the saved list.
struct CalendarMethod: RawRepresentable, Hashable, Sendable, Codable, CustomStringConvertible {
    let rawValue: String

    init?(rawValue: String) {
        guard rawValue.wholeMatch(of: /[A-Za-z][A-Za-z0-9_]{1,31}/) != nil else { return nil }
        self.rawValue = rawValue
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        guard let method = CalendarMethod(rawValue: try container.decode(String.self)) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Not a calendar method")
        }
        self = method
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    var description: String { rawValue }

    static let uaq = CalendarMethod(rawValue: "UAQ")!
    static let hjcosa = CalendarMethod(rawValue: "HJCoSA")!
    static let diyanet = CalendarMethod(rawValue: "DIYANET")!
    static let mathematical = CalendarMethod(rawValue: "MATHEMATICAL")!
}

/// A calendar method as the provider lists it; its text is data to show, never instructions.
struct CalendarMethodInfo: Hashable, Sendable, Codable {
    let method: CalendarMethod
    let name: String
    let description: String
    let validity: String
}

/// A calculation method as the provider lists it. `key` is the provider's short name, `parameters` its angles as text
/// ("18", "90 min").
struct PrayerMethodInfo: Hashable, Sendable, Codable {
    let id: Int
    let key: String
    let name: String
    let parameters: [String: String]
}
