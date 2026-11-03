import CoreText
import Foundation
import SidefolkExtensionKit

/// How much room words take, so a part knows its height before Sidefolk draws it: a scene is boxes, and the panel's layout
/// used to be measured by SwiftUI. Core Text works inside the extension sandbox and takes a few microseconds a line. A name
/// `{companion}` is measured as a usual one; Sidefolk fills it in and shrinks what would overflow.
enum TextFit {
    nonisolated(unsafe) private static var fonts: [String: CTFont] = [:]

    private static func font(_ size: Double, _ weight: String) -> CTFont {
        let key = "\(size)/\(weight)"
        if let known = fonts[key] { return known }
        let traits: [CFString: Any] = [kCTFontWeightTrait: trait(weight)]
        // The face a scene's text draws with: the system's rounded one, a little narrower than the plain one, so a line that fits isn't counted as two.
        let rounded = CTFontDescriptorCreateWithAttributes([kCTFontFamilyNameAttribute: ".AppleSystemUIFontRounded", kCTFontTraitsAttribute: traits] as CFDictionary)
        var made = CTFontCreateWithFontDescriptor(rounded, size, nil)
        if !(CTFontCopyFamilyName(made) as String).contains("Rounded") {
            let base = CTFontCreateUIFontForLanguage(.system, size, nil) ?? CTFontCreateWithName("Helvetica" as CFString, size, nil)
            made = CTFontCreateWithFontDescriptor(CTFontDescriptorCreateCopyWithAttributes(CTFontCopyFontDescriptor(base), [kCTFontTraitsAttribute: traits] as CFDictionary), size, nil)
        }
        fonts[key] = made
        return made
    }

    private static func trait(_ weight: String) -> Double {
        switch weight {
        case "medium": 0.23
        case "semibold": 0.3
        case "bold": 0.4
        case "heavy": 0.56
        case "black": 0.62
        default: 0
        }
    }

    private static func framed(_ words: String, _ size: Double, _ weight: String, width: Double) -> CGSize {
        let text = words.replacingOccurrences(of: "{companion}", with: "Mochi")
        let attributes = [NSAttributedString.Key(kCTFontAttributeName as String): font(size, weight)]
        let setter = CTFramesetterCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
        return CTFramesetterSuggestFrameSizeWithConstraints(setter, CFRange(location: 0, length: 0), nil, CGSize(width: width, height: 100_000), nil)
    }

    /// One line's width, rounded up.
    static func width(_ words: String, size: Double, weight: String = "regular") -> Double {
        (framed(words, size, weight, width: 100_000).width).rounded(.up) + 1
    }

    /// The size at which the longest word of these fits `width`, so a line wraps between words rather than cutting one in two ("Wissenschaft"). Scripts that wrap anywhere keep their size.
    static func wordSize(_ words: String, size: Double, weight: String = "regular", width: Double, least: Double = 0.55) -> Double {
        guard !["ja", "ko", "zh-Hans"].contains(Language.code) else { return size }
        let longest = words.split(whereSeparator: \.isWhitespace).map { Self.width(String($0), size: size, weight: weight) }.max() ?? 0
        return longest <= width ? size : Swift.max(size * width / longest, size * least)
    }

    /// The height of the words wrapped to `width`, at most `lines` lines, rounded up.
    static func height(_ words: String, size: Double, weight: String = "regular", width: Double, lines: Int = 0) -> Double {
        let line = lineHeight(size, weight)
        let full = framed(words, size, weight, width: max(width - 1, 1)).height
        let most = lines > 0 ? line * Double(lines) : full
        return min(max(full, line), most).rounded(.up)
    }

    static func lineHeight(_ size: Double, _ weight: String = "regular") -> Double {
        let f = font(size, weight)
        return (CTFontGetAscent(f) + CTFontGetDescent(f) + CTFontGetLeading(f)).rounded(.up)
    }
}
