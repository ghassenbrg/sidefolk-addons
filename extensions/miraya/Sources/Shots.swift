import Foundation
import CoreGraphics
import ImageIO
@preconcurrency import ScreenCaptureKit

/// Small pictures of what can be shared, for the page's tiles: each display, each window, and the parts of a display,
/// as JPEGs in the data folder (`shots/`), which Sidefolk reads and draws (docs/EXTENSIONS.md › Pictures). Taken only
/// while the page is open and macOS already lets Sidefolk record the screen (never asking: picking Window, or sharing,
/// is what asks), at most every 20 seconds, never while sharing or playing. Sidefolk keeps a picture by its name, so
/// each round has new names and the round before last is deleted.
@MainActor
final class Shots {
    let folder: URL
    /// The picture of each thing that can be shared, by its key: `display:1`, `window:42`, `area:left`.
    private(set) var names: [String: String] = [:]
    private var lastRender = Date.distantPast
    private var taken = Date.distantPast
    private var round = 0
    private var working = false
    /// After a round: what the windows are now (they come with the pictures).
    var onWindows: (([Screens.Window]) -> Void)?

    init(folder: URL) {
        self.folder = folder.appendingPathComponent("shots", isDirectory: true)
    }

    /// The last run's pictures, when the long-running process starts (not a process started for one call, which would
    /// delete the pictures the running one shows).
    func clearAll() { try? FileManager.default.removeItem(at: folder) }

    /// Whether macOS lets Sidefolk record the screen, checked without asking.
    static var allowed: Bool { CGPreflightScreenCaptureAccess() }

    /// Called on every render of the page. Sidefolk reads an open page every few seconds and a closed one about once a
    /// minute (its tile), so two renders close together mean someone is looking.
    func rendered(busy: Bool, area: CGDirectDisplayID?) {
        let now = Date()
        defer { lastRender = now }
        guard now.timeIntervalSince(lastRender) < 8, !busy, !working, now.timeIntervalSince(taken) > 20, Self.allowed else { return }
        working = true
        Task {
            await take(areaDisplay: area)
            taken = Date()
            working = false
        }
    }

    private func take(areaDisplay: CGDirectDisplayID?) async {
        guard let content = try? await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true) else { return }
        round += 1
        let dir = folder.appendingPathComponent("\(round)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var made: [String: String] = [:]
        var displayPictures: [CGDirectDisplayID: CGImage] = [:]
        for display in content.displays {
            let filter = SCContentFilter(display: display, excludingWindows: [])
            guard let image = await Self.capture(filter, width: Double(display.width), height: Double(display.height)) else { continue }
            displayPictures[display.displayID] = image
            if let name = write(image, "display-\(display.displayID)", in: dir) { made["display:\(display.displayID)"] = name }
        }
        let windows = content.windows.filter { $0.windowLayer == 0 && $0.frame.width >= 32 && $0.frame.height >= 32 }
        for window in windows.prefix(MirayaPage.maxWindows) {
            let filter = SCContentFilter(desktopIndependentWindow: window)
            guard let image = await Self.capture(filter, width: window.frame.width, height: window.frame.height) else { continue }
            if let name = write(image, "window-\(window.windowID)", in: dir) { made["window:\(window.windowID)"] = name }
        }
        // The parts of a display: its picture with the rest dimmed, so the tile shows which part goes to the TV.
        if let id = areaDisplay ?? displayPictures.keys.first(where: { $0 == CGMainDisplayID() }) ?? displayPictures.keys.first,
           let picture = displayPictures[id], let display = Screens.displays().first(where: { $0.id == id }) {
            for area in MirayaPage.areas.map(\.name) {
                guard let region = Screens.region(area, of: display), let image = Self.highlight(region, of: display, in: picture) else { continue }
                if let name = write(image, "area-\(area)", in: dir) { made["area:\(area)"] = name }
            }
        }
        names = made
        onWindows?(windows.map { w in
            let app = w.owningApplication?.applicationName ?? ""
            return Screens.Window(id: w.windowID, name: Screens.name(app: app, title: w.title), app: app.isEmpty ? "App" : app, title: w.title ?? "")
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending })
        // The page may still show the round before; the one before that goes.
        try? FileManager.default.removeItem(at: folder.appendingPathComponent("\(round - 2)", isDirectory: true))
    }

    /// A still at most 480 × 300 pixels, the shape of what it shows.
    private static func capture(_ filter: SCContentFilter, width: Double, height: Double) async -> CGImage? {
        guard width > 0, height > 0 else { return nil }
        let scale = min(480 / width, 300 / height, 1)
        let config = SCStreamConfiguration()
        config.width = max(32, Int(width * scale))
        config.height = max(32, Int(height * scale))
        config.showsCursor = false
        return try? await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
    }

    static func highlight(_ region: CaptureRegion, of display: Screens.Display, in picture: CGImage) -> CGImage? {
        let w = picture.width, h = picture.height
        guard display.size.width > 0, display.size.height > 0,
              let context = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let full = CGRect(x: 0, y: 0, width: w, height: h)
        context.draw(picture, in: full)
        let sx = Double(w) / display.size.width, sy = Double(h) / display.size.height
        // The region is from the top left; the context draws from the bottom left.
        let part = CGRect(x: region.x * sx, y: Double(h) - (region.y + region.height) * sy, width: region.width * sx, height: region.height * sy)
        context.setFillColor(CGColor(gray: 0, alpha: 0.62))
        context.addRect(full)
        context.addRect(part)
        context.fillPath(using: .evenOdd)
        context.setStrokeColor(CGColor(gray: 1, alpha: 0.95))
        context.setLineWidth(3)
        context.stroke(part.insetBy(dx: 1.5, dy: 1.5))
        return context.makeImage()
    }

    private func write(_ image: CGImage, _ name: String, in dir: URL) -> String? {
        let file = dir.appendingPathComponent("\(name).jpg")
        guard let destination = CGImageDestinationCreateWithURL(file as CFURL, "public.jpeg" as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.75] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return "shots/\(round)/\(name).jpg"
    }
}
