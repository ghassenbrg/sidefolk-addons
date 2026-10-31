import Foundation

/// How the person likes to share, kept between runs as the Mac app keeps them: the quality preset, whether the Mac's
/// sound goes to the TV, detail before smoothness, the TV's own size as a ceiling, and the last TV used.
struct Choices: Codable, Equatable {
    var quality = CaptureQuality.balanced.rawValue
    var sound = true
    var detail = true
    var followTV = true
    var volume = 1.0
    var lastTV: String?

    var preset: CaptureQuality { CaptureQuality(rawValue: quality) ?? .balanced }

    static func load(_ folder: URL) -> Choices {
        guard let data = try? Data(contentsOf: folder.appendingPathComponent("choices.json")),
              let choices = try? JSONDecoder().decode(Choices.self, from: data) else { return Choices() }
        return choices
    }

    func save(_ folder: URL) {
        try? JSONEncoder().encode(self).write(to: folder.appendingPathComponent("choices.json"), options: .atomic)
    }
}
