import Foundation

/// One thing the person copied.
struct Entry: Codable, Equatable, Identifiable {
    enum Kind: String, Codable { case text, link, image, file, color, code }

    var id: String
    var kind: Kind
    /// The plain text, a link, or the files' paths one per line.
    var text: String?
    /// The formatting it had (RTF), pasted back unless the person asks for plain text.
    var rtf: Data?
    /// A picture's file in the data folder, and its size in pixels.
    var image: String?
    var width: Int?
    var height: Int?
    var files: [String]?
    /// The app it was copied in.
    var source: String?
    var copied: Date
    var times: Int = 1
    var pinned = false
    /// Looks like a password, a key or a card number: masked, and forgotten after a couple of minutes.
    var secret = false

    /// What makes two copies the same copy.
    var fingerprint: String { "\(kind.rawValue)|\(text ?? "")|\(files?.joined(separator: "\n") ?? "")|\(image.map { _ in "\(width ?? 0)x\(height ?? 0)" } ?? "")" }
}

/// The person's choices for the history, kept with it.
struct Options: Codable, Equatable {
    var keeping = true
    /// Paused until then; nil when keeping.
    var pausedUntil: Date?
    var hideSecrets = true
    /// The most it keeps, pinned ones aside.
    var limit = 500
}

/// The history in the extension's data folder: `history.json` and `images/`. Newest first.
@MainActor
final class History {
    private(set) var entries: [Entry] = []
    private(set) var options = Options()
    let folder: URL
    private var saveTask: Task<Void, Never>?
    static let secretLife: TimeInterval = 120
    static let maxImages = 60

    init(folder: URL) {
        self.folder = folder
        try? FileManager.default.createDirectory(at: images, withIntermediateDirectories: true)
        if let data = try? Data(contentsOf: file), let stored = try? JSONDecoder.history.decode(Stored.self, from: data) {
            entries = stored.entries
            options = stored.options
        }
    }

    private struct Stored: Codable {
        var entries: [Entry]
        var options: Options
    }

    var file: URL { folder.appendingPathComponent("history.json") }
    var images: URL { folder.appendingPathComponent("images", isDirectory: true) }

    func isKeeping(now: Date = Date()) -> Bool {
        guard options.keeping else { return false }
        if let until = options.pausedUntil, until > now { return false }
        return true
    }

    /// A new copy: on top, or the same copy moved up.
    func add(_ entry: Entry) {
        if let i = entries.firstIndex(where: { $0.fingerprint == entry.fingerprint }) {
            var old = entries.remove(at: i)
            old.copied = entry.copied
            old.times += 1
            old.source = entry.source ?? old.source
            if entry.image != nil, entry.image != old.image { removeImage(entry.image) }
            entries.insert(old, at: 0)
        } else {
            entries.insert(entry, at: 0)
        }
        trim()
        save()
    }

    /// Chosen again: it goes back on top.
    func raise(_ id: String, now: Date = Date()) {
        guard let i = entries.firstIndex(where: { $0.id == id }) else { return }
        var e = entries.remove(at: i)
        e.copied = now
        e.times += 1
        entries.insert(e, at: 0)
        save()
    }

    func togglePin(_ id: String) {
        guard let i = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[i].pinned.toggle()
        save()
    }

    func delete(_ id: String) {
        guard let i = entries.firstIndex(where: { $0.id == id }) else { return }
        removeImage(entries.remove(at: i).image)
        save()
    }

    /// Empties the history; pinned copies stay unless `everything`.
    func clear(everything: Bool = false) {
        let gone = entries.filter { everything || !$0.pinned }
        entries.removeAll { everything || !$0.pinned }
        for e in gone { removeImage(e.image) }
        save()
    }

    /// Forgets secrets older than their two minutes. Returns whether anything went.
    @discardableResult
    func expireSecrets(now: Date = Date()) -> Bool {
        let gone = entries.filter { $0.secret && !$0.pinned && now.timeIntervalSince($0.copied) > Self.secretLife }
        guard !gone.isEmpty else { return false }
        entries.removeAll { e in gone.contains { $0.id == e.id } }
        save()
        return true
    }

    func set(_ change: (inout Options) -> Void) {
        change(&options)
        save()
    }

    /// Pinned first, then newest; every word of `query` somewhere in the copy, its files or the app it came from.
    func search(_ query: String) -> [Entry] {
        let words = query.lowercased().folding(options: .diacriticInsensitive, locale: nil).split(separator: " ").map(String.init)
        let found = words.isEmpty ? entries : entries.filter { e in
            let hay = [e.secret ? "" : (e.text ?? ""), e.files?.joined(separator: " ") ?? "", e.source ?? "", e.kind.rawValue]
                .joined(separator: " ").lowercased().folding(options: .diacriticInsensitive, locale: nil)
            return words.allSatisfy(hay.contains)
        }
        return found.filter(\.pinned) + found.filter { !$0.pinned }
    }

    func imageData(_ e: Entry) -> Data? { e.image.flatMap { try? Data(contentsOf: images.appendingPathComponent($0)) } }

    func storeImage(_ png: Data) -> String? {
        let name = UUID().uuidString + ".png"
        do { try png.write(to: images.appendingPathComponent(name)) } catch { return nil }
        return name
    }

    private func removeImage(_ name: String?) {
        guard let name, !entries.contains(where: { $0.image == name }) else { return }
        try? FileManager.default.removeItem(at: images.appendingPathComponent(name))
    }

    private func trim() {
        var kept = 0, pictures = 0
        var gone: [Entry] = []
        entries = entries.filter { e in
            if e.pinned { return true }
            kept += 1
            if e.image != nil { pictures += 1 }
            let keep = kept <= options.limit && (e.image == nil || pictures <= Self.maxImages)
            if !keep { gone.append(e) }
            return keep
        }
        for e in gone { removeImage(e.image) }
    }

    /// Written a moment later, once, however many copies came in between.
    func save() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            saveNow()
        }
    }

    func saveNow() {
        // Secrets live in memory only: their two minutes never reach the disk.
        guard let data = try? JSONEncoder.history.encode(Stored(entries: entries.filter { !$0.secret }, options: options)) else { return }
        try? data.write(to: file, options: [.atomic])
    }
}

extension JSONEncoder {
    static var history: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }
}

extension JSONDecoder {
    static var history: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}
