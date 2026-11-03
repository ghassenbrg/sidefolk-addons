import Foundation

/// Zone identifiers come from people and providers, and Foundation also takes abbreviations like `EST` or `GMT+5`, whose
/// meaning isn't a place's rules. Only `Area/Location` names and `UTC` pass.
enum IANAZone {
    static func zone(_ id: String) -> TimeZone? {
        // Foundation reads UTC as GMT, so it passes on its own; any other name has to come back as itself.
        if id == "UTC" { return TimeZone(identifier: id) }
        guard id.wholeMatch(of: /[A-Z][A-Za-z_]*(\/[A-Za-z0-9_+\-]+)+/) != nil, let zone = TimeZone(identifier: id), zone.identifier == id else { return nil }
        return zone
    }
}

/// Local identifiers end up in file names and occurrence ids.
enum LocalID {
    static func isValid(_ id: String) -> Bool {
        id.count <= 128 && id.wholeMatch(of: /[A-Za-z0-9][A-Za-z0-9._\-]*/) != nil
    }
}

/// A chosen place. No place exists until the person picks one; a manual place stays authoritative while they travel.
struct Place: Hashable, Sendable, Codable {
    enum Origin: String, Codable, Sendable { case manual, shared }
    enum Problem: Error, Equatable, Sendable { case badID, emptyLabel, badLatitude, badLongitude, badZone }

    let id: String
    let label: String
    let region: String?
    let country: String?
    let latitude: Double
    let longitude: Double
    let zoneID: String
    let origin: Origin
    /// The host's consent revision for a shared place; nil for a manual one.
    let consentRevision: Int?

    init(id: String, label: String, region: String? = nil, country: String? = nil, latitude: Double, longitude: Double,
         zoneID: String, origin: Origin = .manual, consentRevision: Int? = nil) throws(Problem) {
        guard LocalID.isValid(id), LocalID.isValid(TimetableSource.calculatedID(forPlaceID: id)) else { throw .badID }
        guard !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw .emptyLabel }
        guard latitude.isFinite, (-90...90).contains(latitude) else { throw .badLatitude }
        guard longitude.isFinite, (-180...180).contains(longitude) else { throw .badLongitude }
        guard IANAZone.zone(zoneID) != nil else { throw .badZone }
        (self.id, self.label, self.region, self.country) = (id, label, region, country)
        (self.latitude, self.longitude, self.zoneID, self.origin, self.consentRevision) = (latitude, longitude, zoneID, origin, consentRevision)
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(id: c.decode(String.self, forKey: .id), label: c.decode(String.self, forKey: .label),
                      region: c.decodeIfPresent(String.self, forKey: .region), country: c.decodeIfPresent(String.self, forKey: .country),
                      latitude: c.decode(Double.self, forKey: .latitude), longitude: c.decode(Double.self, forKey: .longitude),
                      zoneID: c.decode(String.self, forKey: .zoneID), origin: c.decode(Origin.self, forKey: .origin),
                      consentRevision: c.decodeIfPresent(Int.self, forKey: .consentRevision))
    }

    var zone: TimeZone { IANAZone.zone(zoneID)! }
}
