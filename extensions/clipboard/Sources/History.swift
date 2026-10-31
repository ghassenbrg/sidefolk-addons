import Foundation

/// The history in the extension's data folder: `history.json` (the list and the choices), and beside it what is big,
/// one file per copy: `images/` (pictures as copied), `thumbs/` (their small copies, which Sidefolk draws, D68) and
/// `rich/` (formatting). Newest copy first.
@MainActor
final class History {
    private(set) var entries: [Entry] = []
    private(set) var options = Options()
    let folder: URL
    let searcher = Searcher()
    private var saveTask: Task<Void, Never>?
    static let secretLife: TimeInterval = 120
    /// Pictures kept, pinned ones aside: at most this many, and this many bytes together.
    static let maxImages = 300
    static let imageBudget = 750 * 1024 * 1024

    init(folder: URL) {
        self.folder = folder
        for sub in ["images", "thumbs", "rich"] {
            try? FileManager.default.createDirectory(at: folder.appendingPathComponent(sub, isDirectory: true), withIntermediateDirectories: true)
        }
        guard let data = try? Data(contentsOf: file), let stored = try? JSONDecoder.history.decode(Stored.self, from: data) else { return }
        entries = stored.entries
        options = stored.options
        if migrate(data) { saveNow() }
    }

    private struct Stored: Codable {
        var entries: [Entry]
        var options: Options
    }

    var file: URL { folder.appendingPathComponent("history.json") }
    func url(_ name: String) -> URL { folder.appendingPathComponent(name) }
    func data(_ name: String?) -> Data? { name.flatMap { try? Data(contentsOf: url($0)) } }

    func isKeeping(now: Date = Date()) -> Bool {
        guard options.keeping else { return false }
        if let until = options.pausedUntil, until > now { return false }
        return true
    }

    /// A new copy on top, with its files (by name in the data folder), or the same copy as before moved up, counted once
    /// more: its files are already there, so the new ones aren't written.
    func add(_ entry: Entry, files: [String: Data] = [:]) {
        if let i = entries.firstIndex(where: { $0.isSame(as: entry) }) {
            var old = entries.remove(at: i)
            old.copied = entry.copied
            old.times += 1
            old.source = entry.source ?? old.source
            old.app = entry.app ?? old.app
            entries.insert(old, at: 0)
        } else {
            var kept = entry
            for (name, data) in files where (try? data.write(to: url(name), options: .atomic)) == nil {
                // A file that couldn't be written isn't named: the copy is kept without it.
                for path in [\Entry.image, \.thumb, \.rtfFile, \.htmlFile] where kept[keyPath: path] == name { kept[keyPath: path] = nil }
            }
            if kept.kind == .image && kept.image == nil { return }
            entries.insert(kept, at: 0)
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
        removeFiles(entries.remove(at: i))
        save()
    }

    /// Empties the history; pinned copies stay unless `everything`.
    func clear(everything: Bool = false) {
        let gone = entries.filter { everything || !$0.pinned }
        entries.removeAll { everything || !$0.pinned }
        gone.forEach(removeFiles)
        save()
    }

    /// Forgets secrets older than their two minutes. Returns whether anything went.
    @discardableResult
    func expireSecrets(now: Date = Date()) -> Bool {
        let gone = entries.filter { $0.secret && !$0.pinned && now.timeIntervalSince($0.copied) > Self.secretLife }
        guard !gone.isEmpty else { return false }
        entries.removeAll { e in gone.contains { $0.id == e.id } }
        gone.forEach(removeFiles)
        save()
        return true
    }

    func set(_ change: (inout Options) -> Void) {
        let before = options.limit
        change(&options)
        if options.limit != before { trim() }
        save()
    }

    /// As the person chose to see them: by when last copied, first copied or how often, pins on top or at the bottom.
    func ordered() -> [Entry] {
        var list = entries
        switch options.sort {
        case .recent: break
        case .first: list.sort { $0.firstCopied > $1.firstCopied }
        case .count: list.sort { $0.times != $1.times ? $0.times > $1.times : $0.copied > $1.copied }
        }
        let pinned = list.filter(\.pinned), rest = list.filter { !$0.pinned }
        return options.pins == .top ? pinned + rest : rest + pinned
    }

    /// For the palette: the person's order and way of searching. Nil when their regular expression isn't one.
    func find(_ query: String) -> [Entry]? { searcher.filter(ordered(), query, mode: options.search) }

    /// For answers and commands: pinned first, then newest; every word of `query` in the copy, its files or its app.
    func search(_ query: String) -> [Entry] {
        let found = searcher.filter(entries, query, mode: .words) ?? []
        return found.filter(\.pinned) + found.filter { !$0.pinned }
    }

    private func removeFiles(_ e: Entry) {
        searcher.forget(e.id)
        for name in e.stored where !entries.contains(where: { $0.stored.contains(name) }) {
            try? FileManager.default.removeItem(at: url(name))
        }
    }

    /// The oldest copies past the limit go, and the oldest pictures past theirs; pinned copies always stay.
    private func trim() {
        var kept = 0, pictures = 0, bytes = 0
        var gone: [Entry] = []
        entries = entries.filter { e in
            if e.pinned { return true }
            kept += 1
            if e.image != nil {
                pictures += 1
                bytes += e.bytes ?? 0
            }
            let keep = kept <= options.limit && (e.image == nil || (pictures <= Self.maxImages && bytes <= Self.imageBudget))
            if !keep { gone.append(e) }
            return keep
        }
        gone.forEach(removeFiles)
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

    /// A history saved by the first version: its pictures named without their folder, its formatting inside the list,
    /// no thumbnails. Returns whether anything changed.
    private func migrate(_ data: Data) -> Bool {
        struct Old: Decodable { var id: String; var rtf: Data? }
        struct OldStored: Decodable { var entries: [Old] }
        let old = Dictionary(((try? JSONDecoder.history.decode(OldStored.self, from: data))?.entries ?? []).map { ($0.id, $0.rtf) },
                             uniquingKeysWith: { a, _ in a })
        var changed = false
        for i in entries.indices {
            if let image = entries[i].image, !image.contains("/") {
                entries[i].image = "images/" + image
                changed = true
            }
            if let rtf = old[entries[i].id] ?? nil, entries[i].rtfFile == nil {
                let name = "rich/\(entries[i].id).rtf"
                if (try? rtf.write(to: url(name))) != nil { entries[i].rtfFile = name }
                changed = true
            }
            if entries[i].kind == .image, entries[i].thumb == nil, let png = self.data(entries[i].image), let thumb = Pictures.thumbnail(png) {
                let name = "thumbs/\(entries[i].id).png"
                if (try? thumb.write(to: url(name))) != nil { entries[i].thumb = name }
                entries[i].bytes = png.count
                entries[i].digest = Pictures.digest(png)
                changed = true
            }
        }
        return changed
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
