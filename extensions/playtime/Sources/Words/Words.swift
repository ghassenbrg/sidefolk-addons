import SidefolkExtensionKit

/// Playtime's words in the ten languages Sidefolk speaks (D75), one table per language beside this file, chosen by
/// the `language` Sidefolk passes. The questions themselves come per language from the trivia packs.
enum Words {
    static let tables: [String: [String: String]] = [
        "en": english, "fr": french, "es": spanish, "de": german, "it": italian, "pt-BR": portuguese,
        "ja": japanese, "ko": korean, "zh-Hans": chinese, "ar": arabic,
    ]

    static func `for`(_ language: String?) -> Localized { Localized(language, tables) }
}
