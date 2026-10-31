import Foundation

/// One thing the person copied. What is big (formatting, pictures) lives in files beside the history, so the history
/// itself stays a small list that loads and saves quickly with thousands of copies.
struct Entry: Codable, Equatable, Identifiable, Sendable {
    enum Kind: String, Codable, Sendable { case text, link, image, file, color, code }

    var id: String
    var kind: Kind
    /// The plain text, a link, or the files' paths one per line.
    var text: String?
    /// The formatting it had, in files of the data folder (`rich/<id>.rtf`, `rich/<id>.html`): pasted back unless the
    /// person asks for plain text.
    var rtfFile: String?
    var htmlFile: String?
    /// A picture as copied, in the data folder (`images/<id>.png`), with its size in pixels and bytes.
    var image: String?
    var width: Int?
    var height: Int?
    var bytes: Int?
    /// A small copy of the picture, or the icon a copied file came with (`thumbs/<id>.png`): made once, at copy time.
    var thumb: String?
    /// The picture's SHA-256, so the same picture copied twice is one copy and two pictures of one size are two.
    var digest: String?
    var files: [String]?
    /// The app it was copied in: its name, and its bundle id when Sidefolk said (for ignoring it).
    var source: String?
    var app: String?
    var copied: Date
    var first: Date?
    var times: Int = 1
    var pinned = false
    /// Looks like a password, a key or a card number: masked, and forgotten after a couple of minutes.
    var secret = false

    /// When it was first copied (copies kept before this was recorded count from their latest).
    var firstCopied: Date { first ?? copied }

    /// The same copy again: the same text, files or picture (by its digest). Compared field by field, cheapest first,
    /// since every new copy is checked against the whole history.
    func isSame(as other: Entry) -> Bool {
        kind == other.kind && digest == other.digest && text == other.text && files == other.files
            && (digest != nil || image == nil || (width == other.width && height == other.height))
    }

    /// Every file this copy keeps in the data folder.
    var stored: [String] { [rtfFile, htmlFile, image, thumb].compactMap { $0 } }
}

/// The person's choices for the history, kept with it. Each has a default, so a history saved by an older version (or
/// missing a setting) reads as it was.
struct Options: Codable, Equatable, Sendable {
    enum Sort: String, Codable, CaseIterable, Sendable { case recent, first, count }
    enum Pins: String, Codable, CaseIterable, Sendable { case top, bottom }
    enum Search: String, Codable, CaseIterable, Sendable { case words, exact, fuzzy, regex }

    var keeping = true
    /// Paused until then; nil when keeping.
    var pausedUntil: Date?
    var hideSecrets = true
    /// The most it keeps, pinned ones aside.
    var limit = 500
    /// Choosing a copy pastes it into the app in front; otherwise it is only put on the clipboard. ⌥ does the other.
    var paste = true
    /// Choosing a copy pastes it without its formatting.
    var plain = false
    var sort = Sort.recent
    var pins = Pins.top
    var search = Search.words
    var keepImages = true
    var keepFiles = true
    var keepFormatting = true
    /// Apps whose copies aren't kept: bundle ids (`com.apple.Safari`) or names, as the person gave them.
    var ignoredApps: [String] = []
    /// Copies whose text matches one of these (regular expressions) aren't kept.
    var ignoredPatterns: [String] = []
    /// Pasteboard types that mark a copy not to keep, besides the ones always left out (`Watch.skipped`).
    var ignoredTypes: [String] = []
    /// The next copy isn't kept ("I'm about to copy a password").
    var skipNext = false

    static let limits = [100, 200, 500, 1000, 2000, 5000]

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Options()
        keeping = try c.decodeIfPresent(Bool.self, forKey: .keeping) ?? d.keeping
        pausedUntil = try c.decodeIfPresent(Date.self, forKey: .pausedUntil)
        hideSecrets = try c.decodeIfPresent(Bool.self, forKey: .hideSecrets) ?? d.hideSecrets
        limit = try c.decodeIfPresent(Int.self, forKey: .limit) ?? d.limit
        paste = try c.decodeIfPresent(Bool.self, forKey: .paste) ?? d.paste
        plain = try c.decodeIfPresent(Bool.self, forKey: .plain) ?? d.plain
        sort = (try? c.decodeIfPresent(Sort.self, forKey: .sort)) ?? d.sort
        pins = (try? c.decodeIfPresent(Pins.self, forKey: .pins)) ?? d.pins
        search = (try? c.decodeIfPresent(Search.self, forKey: .search)) ?? d.search
        keepImages = try c.decodeIfPresent(Bool.self, forKey: .keepImages) ?? d.keepImages
        keepFiles = try c.decodeIfPresent(Bool.self, forKey: .keepFiles) ?? d.keepFiles
        keepFormatting = try c.decodeIfPresent(Bool.self, forKey: .keepFormatting) ?? d.keepFormatting
        ignoredApps = try c.decodeIfPresent([String].self, forKey: .ignoredApps) ?? []
        ignoredPatterns = try c.decodeIfPresent([String].self, forKey: .ignoredPatterns) ?? []
        ignoredTypes = try c.decodeIfPresent([String].self, forKey: .ignoredTypes) ?? []
        skipNext = try c.decodeIfPresent(Bool.self, forKey: .skipNext) ?? false
    }

    /// Whether a copy from this app is to be left out: the person named its bundle id or its name.
    func ignores(app: String?, name: String?) -> Bool {
        let given = [app, name].compactMap { $0?.lowercased() }
        return ignoredApps.contains { given.contains($0.lowercased()) }
    }

    /// Whether this text is to be left out: one of the person's patterns matches it.
    func ignores(text: String) -> Bool {
        ignoredPatterns.contains { pattern in
            (try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]))?
                .firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
        }
    }
}
