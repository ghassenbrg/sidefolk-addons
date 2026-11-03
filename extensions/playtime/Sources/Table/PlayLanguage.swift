import Foundation
import SidefolkExtensionKit

/// The language Playtime itself plays in, when the person wants another than Sidefolk's: an English Mac and the word of the day in Arabic. Everything Playtime draws follows it
/// (`Language`, for the request being answered), and what stands outside its own surface and page stays in the app's: the frame, the sidebar, what Ask says.
@MainActor
enum PlayLanguage {
    static let key = "game_language"
    static let auto = "auto"
    /// Each in its own script, so it can be found by someone who reads it, whatever the screen is in now.
    static let names: [(code: String, name: String)] = [
        ("en", "English"), ("fr", "Français"), ("es", "Español"), ("de", "Deutsch"), ("it", "Italiano"), ("pt-BR", "Português (Brasil)"),
        ("ja", "日本語"), ("ko", "한국어"), ("zh-Hans", "简体中文"), ("ar", "العربية"),
    ]
    private static var app = "en"

    /// What the person chose, or nil for the app's.
    static var chosen: String? {
        ExtensionSettings.string(key).flatMap { Localized.languages.contains($0) ? $0 : nil }
    }

    /// Answers this request in the chosen language. `language` is the app's, as the request said it.
    static func enter(_ language: String) {
        app = Localized.normalized(language)
        if let chosen { Language.use(chosen) }
    }

    /// The person has just picked: the settings say so from the next request, and this one's answer shows it already.
    static func picked(_ code: String) {
        ExtensionSettings.set(key, code)
        Language.use(code == auto ? app : code)
    }

    /// A scene reads in its words' direction, said only when that isn't the app's: a copy of Sidefolk draws what it already would.
    static func stamped(_ scene: Scene) -> Scene {
        let rtl = Language.rightToLeft
        return rtl == Locale.Language(identifier: app).isRightToLeft ? scene : scene.direction(rightToLeft: rtl)
    }
}

private extension Locale.Language {
    var isRightToLeft: Bool { characterDirection == .rightToLeft }
}
