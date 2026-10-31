import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Pictures for the history: a copied picture kept as PNG, and its thumbnail made once, at copy time, so the palette
/// never decodes a 5K screenshot to draw a row. Sidefolk reads both from the data folder (D68); it takes a picture up to
/// 25 MB for the preview and a thumbnail up to 4 MB, so these stay well under.
enum Pictures {
    /// A copied picture bigger than this isn't kept (a screenshot of a 6K display is about 15 MB).
    static let maxBytes = 20 * 1024 * 1024
    /// The longest side of a thumbnail, in pixels: rows draw them about 50 points wide on a Retina screen.
    static let thumbSide = 256

    struct Picture {
        var png: Data
        var width: Int
        var height: Int
        var digest: String
    }

    /// `data` (PNG, TIFF, JPEG, HEIC: whatever the app put on the clipboard) as a PNG with its size, or nil when it isn't
    /// a picture or is too big to keep. A PNG is kept as it came.
    static func picture(_ data: Data, isPNG: Bool) -> Picture? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil), CGImageSourceGetCount(source) > 0,
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = props[kCGImagePropertyPixelWidth] as? Int, let height = props[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0 else { return nil }
        var png = data
        if !isPNG {
            guard let image = CGImageSourceCreateImageAtIndex(source, 0, nil), let made = encode(image, as: .png) else { return nil }
            png = made
        }
        guard png.count <= maxBytes else { return nil }
        return Picture(png: png, width: width, height: height, digest: digest(png))
    }

    /// A small PNG of `data`: its longest side `thumbSide` pixels at most, turned as the picture says.
    static func thumbnail(_ data: Data, side: Int = thumbSide) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true,
                                        kCGImageSourceThumbnailMaxPixelSize: side]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return encode(image, as: .png)
    }

    static func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }

    private static func encode(_ image: CGImage, as type: UTType) -> Data? {
        let out = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(out, type.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination) ? out as Data : nil
    }
}
