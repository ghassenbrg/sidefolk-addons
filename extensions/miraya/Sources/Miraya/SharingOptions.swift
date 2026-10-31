// Copied from Miraya (macos/Sources/MirayaCore/SharingOptions.swift and the quality presets in
// macos/Sources/Miraya/H264Encoder.swift), MIT License, Copyright (c) 2026 Ghassen Bargougui: licenses/Miraya-LICENSE.txt.
// The presets, area check and media URL rules are the Mac app's, so the TV gets what it was built for. Only the words
// people read are Sidefolk's.
import Foundation

enum CaptureQuality: String, CaseIterable, Identifiable {
    case balanced, motion, efficient, efficientMotion, lowBandwidth
    var id: String { rawValue }
    var label: String {
        switch self {
        case .balanced: return "1080p · 30 fps"
        case .motion: return "1080p · 60 fps"
        case .efficient: return "720p · 30 fps"
        case .efficientMotion: return "720p · 60 fps"
        case .lowBandwidth: return "480p · 15 fps"
        }
    }
    var maxWidth: Int { self == .lowBandwidth ? 854 : (self == .efficient || self == .efficientMotion ? 1280 : 1920) }
    var maxHeight: Int { self == .lowBandwidth ? 480 : (self == .efficient || self == .efficientMotion ? 720 : 1080) }
    var fps: Int { self == .motion || self == .efficientMotion ? 60 : (self == .lowBandwidth ? 15 : 30) }
    var bitrate: Int { self == .motion ? 10_000_000 : (self == .lowBandwidth ? 1_000_000 : (self == .efficient ? 3_000_000 : 6_000_000)) }
}

enum CaptureSourceKind: String, CaseIterable, Sendable {
    case display, window, area
}

/// A part of a display, in its points (top left is 0, 0).
struct CaptureRegion: Equatable, Codable, Sendable {
    let x: Double, y: Double, width: Double, height: Double
    init(x: Double, y: Double, width: Double, height: Double) { self.x = x; self.y = y; self.width = width; self.height = height }
    func validated(displayWidth: Double, displayHeight: Double) -> Bool {
        [x, y, width, height, displayWidth, displayHeight].allSatisfy(\.isFinite) && x >= 0 && y >= 0 && width >= 32 && height >= 32 && x + width <= displayWidth + 0.5 && y + height <= displayHeight + 0.5
    }
}

enum DirectMedia {
    static let maximumChunk = 32_768
    static func validRemoteURL(_ text: String) -> Bool {
        guard text.count <= 8192, let parts = URLComponents(string: text), parts.scheme?.lowercased() == "https",
              let host = parts.host, !host.isEmpty, parts.user == nil, parts.password == nil else { return false }
        return true
    }
    static func validRead(offset: Int64, count: Int, size: Int64) -> Bool {
        offset >= 0 && offset <= size && count > 0 && count <= maximumChunk && size > 0
    }
}

enum CaptureFailure: LocalizedError {
    case displayUnavailable
    case audioFormat(String)

    var errorDescription: String? {
        switch self {
        case .displayUnavailable: return "That screen or window isn't available any more. Choose another and share again."
        case .audioFormat(let detail): return "The Mac's sound couldn't be captured: \(detail). Try sharing without sound."
        }
    }
}

struct ConnectionFailure: Error, LocalizedError {
    let message: String
    var retryable = true
    var errorDescription: String? { message }
}
