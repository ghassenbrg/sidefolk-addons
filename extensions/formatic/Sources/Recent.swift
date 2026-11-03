import Foundation
import ImageIO
import SidefolkExtensionKit
import UniformTypeIdentifiers

/// What Formatic made lately, for its page. Kept in its own data folder, with a small picture of each, until the person clears it.
struct RecentFile: Codable {
    var name: String
    var change: String
    var result: String
    var at: Date
    var picture: String?
}

enum Recent {
    static var file: String { Paths.data + "/recent.json" }
    static var pictures: String { Paths.data + "/thumbs" }
    static let limit = 20

    static func all() -> [RecentFile] {
        guard let data = FileManager.default.contents(atPath: file) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([RecentFile].self, from: data)) ?? []
    }

    static func add(_ entry: RecentFile, from source: String? = nil) {
        var entry = entry
        if let source, let name = thumbnail(of: source) { entry.picture = "thumbs/" + name }
        let kept = ([entry] + all()).prefix(limit)
        let keptPictures = Set(kept.compactMap(\.picture))
        for name in (try? FileManager.default.contentsOfDirectory(atPath: pictures)) ?? [] where !keptPictures.contains("thumbs/" + name) {
            try? FileManager.default.removeItem(atPath: pictures + "/" + name)
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(Array(kept)) { try? data.write(to: URL(fileURLWithPath: file), options: .atomic) }
    }

    static func clear() {
        try? FileManager.default.removeItem(atPath: file)
        try? FileManager.default.removeItem(atPath: pictures)
    }

    private static func thumbnail(of source: String) -> String? {
        guard Convert.kind(of: source) == .picture, let input = CGImageSourceCreateWithURL(URL(fileURLWithPath: source) as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: 128]
        guard let image = CGImageSourceCreateThumbnailAtIndex(input, 0, options as CFDictionary) else { return nil }
        try? FileManager.default.createDirectory(atPath: pictures, withIntermediateDirectories: true)
        let name = UUID().uuidString + ".jpg"
        guard let output = CGImageDestinationCreateWithURL(URL(fileURLWithPath: pictures + "/" + name) as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(output, image, [kCGImageDestinationLossyCompressionQuality: 0.7] as CFDictionary)
        return CGImageDestinationFinalize(output) ? name : nil
    }
}
