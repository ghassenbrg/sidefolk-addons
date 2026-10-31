import Foundation

/// How the person likes to share, kept between runs as the Mac app keeps them: the quality preset, whether the Mac's
/// sound goes to the TV, detail before smoothness, the TV's own size as a ceiling, the last TV used, and what the page
/// has picked to share (a whole display, a window or a part of a display; each remembered for when it's picked again).
struct Choices: Codable, Equatable {
    enum AudioDestination: String, CaseIterable {
        case mac, tv, both
        var label: String { switch self { case .mac: "Mac only"; case .tv: "TV only"; case .both: "Mac and TV" } }
    }
    var quality = CaptureQuality.balanced.rawValue
    var sound = true
    var detail = true
    var followTV = true
    var volume = 1.0
    var lastTV: String?
    // Optional, so a file saved before them still reads.
    var kind: String?
    var display: UInt32?
    var window: UInt32?
    var area: String?
    /// Optional so choices saved by earlier releases retain their existing sound switch.
    var audioDestination: String?

    var preset: CaptureQuality { CaptureQuality(rawValue: quality) ?? .balanced }
    var audio: AudioDestination { audioDestination.flatMap(AudioDestination.init(rawValue:)) ?? (sound ? .both : .mac) }

    mutating func setAudio(_ destination: AudioDestination) {
        audioDestination = destination.rawValue
        sound = destination != .mac
    }

    static func load(_ folder: URL) -> Choices {
        guard let data = try? Data(contentsOf: folder.appendingPathComponent("choices.json")),
              let choices = try? JSONDecoder().decode(Choices.self, from: data) else { return Choices() }
        return choices
    }

    func save(_ folder: URL) {
        try? JSONEncoder().encode(self).write(to: folder.appendingPathComponent("choices.json"), options: .atomic)
    }
}
