import Foundation

/// The direction of the Kaaba from a place: degrees clockwise from true north. It says nothing of how the Mac is facing.
struct QiblaBearing: Hashable, Sendable, Codable {
    let latitude: Double
    let longitude: Double
    let degrees: Double
    let fetched: Date

    init?(latitude: Double, longitude: Double, degrees: Double, fetched: Date) {
        guard latitude.isFinite, longitude.isFinite, degrees.isFinite, (-90...90).contains(latitude), (-180...180).contains(longitude),
              degrees >= 0, degrees < 360 else { return nil }
        (self.latitude, self.longitude, self.degrees, self.fetched) = (latitude, longitude, degrees, fetched)
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let bearing = QiblaBearing(latitude: try c.decode(Double.self, forKey: .latitude), longitude: try c.decode(Double.self, forKey: .longitude),
                                   degrees: try c.decode(Double.self, forKey: .degrees), fetched: try c.decode(Date.self, forKey: .fetched))
        guard let bearing else { throw DecodingError.dataCorruptedError(forKey: .degrees, in: c, debugDescription: "Not a bearing") }
        self = bearing
    }

    var rounded: Int { Int(degrees.rounded()) % 360 }

    /// Whether this was fetched for that place. A bearing from elsewhere is no bearing at all.
    func isFor(_ place: Place) -> Bool {
        AlAdhan.coordinate(latitude) == AlAdhan.coordinate(place.latitude) && AlAdhan.coordinate(longitude) == AlAdhan.coordinate(place.longitude)
    }
}

/// One of the 99 Names, as supplied. `number` is the stable identity a bookmark stores; `meaning` is the provider's English.
struct NameEntry: Hashable, Sendable, Codable, Identifiable {
    let number: Int
    let arabic: String
    let transliteration: String
    let meaning: String

    var id: Int { number }
}
