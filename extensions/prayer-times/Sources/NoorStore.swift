import CryptoKit
import Foundation

/// A cached answer with when it was fetched, which is separate from what dates it covers.
struct CacheEntry<Value: Codable & Sendable>: Codable, Sendable {
    let value: Value
    let fetchedAt: Date
}

/// A document on disk. `unreadable` is a file that is there but can't be used: it isn't the same as nothing saved, and
/// saving over it needs the person to say so (`NoorStore.setAside`).
enum Loaded<Value: Sendable>: Sendable {
    case absent
    case ok(Value)
    case unreadable(String)

    var value: Value? {
        if case .ok(let value) = self { return value }
        return nil
    }
}

extension Loaded: Equatable where Value: Equatable {}

enum NoorDocument: Hashable, Sendable {
    case preferences, sources, bookmarks
    case timetable(sourceID: String)

    var path: String {
        switch self {
        case .preferences: "preferences.json"
        case .sources: "sources.json"
        case .bookmarks: "bookmarks.json"
        case .timetable(let id): "timetables/\(id).json"
        }
    }
}

enum NoorStoreError: Error, Equatable, Sendable {
    /// Saving would destroy a file that couldn't be read.
    case unreadable(String)
    case badIdentifier(String)
    case badBookmark(Int)
}

/// Steps from one shape of a document to the next: `steps[n]` turns version n's payload into version n + 1's. Explicit, so
/// an older file is either carried forward by code someone wrote or left alone, never reinterpreted.
struct Migrations: Sendable {
    typealias Step = @Sendable (_ document: String, _ payload: Any) throws -> Any

    let current: Int
    let steps: [Int: Step]

    static let shipped = Migrations(current: Preferences.schemaVersion, steps: [:])
}

/// Noor's files under one injected folder, each a versioned JSON envelope written atomically. It only ever touches the
/// names below: the folder may hold other things.
struct NoorStore: Sendable {
    enum Scope: String, Sendable { case cache, all }

    private static let cacheFolder = "cache"
    private static let timetableFolder = "timetables"
    private static let setAsideFolder = "set-aside"

    private struct Unusable: Error, CustomStringConvertible {
        let reason: String
        var description: String { reason }
    }

    private struct Header: Decodable { let version: Int }
    private struct Envelope<T: Codable>: Codable {
        let version: Int
        let data: T
    }

    let folder: URL
    let migrations: Migrations

    init(folder: URL, migrations: Migrations = .shipped) {
        self.folder = folder
        self.migrations = migrations
    }

    // MARK: - Documents

    func preferences() -> Loaded<Preferences> { read(.preferences) }
    func save(_ preferences: Preferences) throws { try write(preferences, .preferences) }

    func sources() -> Loaded<[TimetableSource]> { read(.sources) }
    func save(sources: [TimetableSource]) throws { try write(sources, .sources) }

    func timetable(sourceID: String) -> Loaded<ManualTimetable> {
        LocalID.isValid(sourceID) ? read(.timetable(sourceID: sourceID)) : .absent
    }

    func save(_ timetable: ManualTimetable) throws {
        guard LocalID.isValid(timetable.source.id) else { throw NoorStoreError.badIdentifier(timetable.source.id) }
        try write(timetable, .timetable(sourceID: timetable.source.id))
    }

    func deleteTimetable(sourceID: String) throws {
        guard LocalID.isValid(sourceID) else { throw NoorStoreError.badIdentifier(sourceID) }
        try remove(NoorDocument.timetable(sourceID: sourceID).path)
    }

    /// Bookmarks are Name numbers and nothing else.
    func bookmarks() -> Loaded<Set<Int>> {
        switch read(.bookmarks) as Loaded<Set<Int>> {
        case .ok(let numbers) where !numbers.allSatisfy((1...99).contains): .unreadable("not name numbers")
        case let other: other
        }
    }

    func save(bookmarks: Set<Int>) throws {
        if let bad = bookmarks.first(where: { !(1...99).contains($0) }) { throw NoorStoreError.badBookmark(bad) }
        try write(bookmarks, .bookmarks)
    }

    /// Switches source in the one order a crash can't hurt: the new timetable, the list, and last the preferences, whose
    /// `sourceID` is what makes it current. Stopping part way leaves the old source in force and an unused file at worst.
    func commitSource(preferences: Preferences, sources: [TimetableSource], timetable: ManualTimetable? = nil) throws {
        if let timetable { try save(timetable) }
        try save(sources: sources)
        try save(preferences)
    }

    /// Moves an unreadable file out of the way, kept, for when the person has chosen to start over.
    @discardableResult
    func setAside(_ document: NoorDocument) throws -> URL? {
        try keepCopy(of: document.path, suffix: "unreadable", move: true)
    }

    private func read<T: Codable & Sendable>(_ document: NoorDocument) -> Loaded<T> {
        let url = folder.appending(path: document.path)
        guard FileManager.default.fileExists(atPath: url.path) else { return .absent }
        do {
            return .ok(try open(try Data(contentsOf: url), document: document))
        } catch {
            return .unreadable(String(describing: error))
        }
    }

    private func open<T: Codable>(_ data: Data, document: NoorDocument) throws -> T {
        let version = try Self.decoder.decode(Header.self, from: data).version
        if version == migrations.current { return try Self.decoder.decode(Envelope<T>.self, from: data).data }
        guard version < migrations.current else { throw Unusable(reason: "written by a newer Noor (version \(version))") }
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any], var payload = object["data"] else {
            throw Unusable(reason: "no data")
        }
        for step in version..<migrations.current {
            guard let migrate = migrations.steps[step] else { throw Unusable(reason: "no migration from version \(step)") }
            payload = try migrate(document.path, payload)
        }
        let migrated = try JSONSerialization.data(withJSONObject: ["version": migrations.current, "data": payload])
        let value = try Self.decoder.decode(Envelope<T>.self, from: migrated).data
        // Only a migration that produced a readable result replaces the file, with the old one kept. If that can't be
        // written, the answer is still good and the next read tries again.
        if (try? keepCopy(of: document.path, suffix: "v\(version)", move: false)) != nil {
            try? writeFile(migrated, to: folder.appending(path: document.path))
        }
        return value
    }

    private func write<T: Codable & Sendable>(_ value: T, _ document: NoorDocument) throws {
        if case .unreadable(let why) = read(document) as Loaded<T> {
            throw NoorStoreError.unreadable("\(document.path): \(why)")
        }
        let data = try Self.encoder.encode(Envelope(version: migrations.current, data: value))
        try writeFile(data, to: folder.appending(path: document.path))
    }

    private func writeFile(_ data: Data, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }

    private func keepCopy(of path: String, suffix: String, move: Bool) throws -> URL? {
        let source = folder.appending(path: path)
        guard FileManager.default.fileExists(atPath: source.path) else { return nil }
        let shelf = folder.appending(path: Self.setAsideFolder)
        try FileManager.default.createDirectory(at: shelf, withIntermediateDirectories: true)
        let name = path.replacingOccurrences(of: "/", with: "-")
        var target = shelf.appending(path: "\(name).\(suffix)")
        var attempt = 1
        while FileManager.default.fileExists(atPath: target.path) {
            attempt += 1
            target = shelf.appending(path: "\(name).\(suffix).\(attempt)")
        }
        if move { try FileManager.default.moveItem(at: source, to: target) } else { try FileManager.default.copyItem(at: source, to: target) }
        return target
    }

    private func remove(_ path: String) throws {
        let url = folder.appending(path: path)
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }

    // MARK: - Cache

    /// A bad cache file is just a missing one: it can always be fetched again, so unlike a document it may be replaced.
    func cached<Value: Codable & Sendable>(key: String) -> CacheEntry<Value>? {
        guard let data = try? Data(contentsOf: cacheURL(key)) else { return nil }
        return try? (Self.decoder.decode(Envelope<CacheEntry<Value>>.self, from: data)).data
    }

    func cache<Value: Codable & Sendable>(_ value: Value, key: String, fetchedAt: Date) throws {
        let data = try Self.encoder.encode(Envelope(version: migrations.current, data: CacheEntry(value: value, fetchedAt: fetchedAt)))
        try writeFile(data, to: cacheURL(key))
    }

    /// Keys hold coordinates and such, and file names shouldn't.
    private func cacheURL(_ key: String) -> URL {
        let name = SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
        return folder.appending(path: Self.cacheFolder).appending(path: "\(name).json")
    }

    func pruneCache(olderThan cutoff: Date) {
        struct Age: Decodable {
            struct Fetched: Decodable { let fetchedAt: Date }
            let data: Fetched
        }
        let shelf = folder.appending(path: Self.cacheFolder)
        for file in (try? FileManager.default.contentsOfDirectory(at: shelf, includingPropertiesForKeys: nil)) ?? [] {
            let age = (try? Data(contentsOf: file)).flatMap { try? Self.decoder.decode(Age.self, from: $0) }
            if age.map({ $0.data.fetchedAt < cutoff }) ?? true { try? FileManager.default.removeItem(at: file) }
        }
    }

    // MARK: - Export and clear

    /// One JSON document of a scope's files. A file that isn't JSON is named, not carried.
    func export(_ scope: Scope) throws -> Data {
        var files: [String: Any] = [:]
        var unreadable: [String] = []
        for path in filePaths(scope) {
            if let data = try? Data(contentsOf: folder.appending(path: path)), let object = try? JSONSerialization.jsonObject(with: data) {
                files[path] = object
            } else {
                unreadable.append(path)
            }
        }
        return try JSONSerialization.data(withJSONObject: ["version": migrations.current, "scope": scope.rawValue, "files": files, "unreadable": unreadable.sorted()],
                                          options: [.prettyPrinted, .sortedKeys])
    }

    /// Deletes a scope and nothing else in the folder. Cancelling reminder jobs on `.all` is the caller's half of it.
    func clear(_ scope: Scope) throws {
        try remove(Self.cacheFolder)
        guard scope == .all else { return }
        for path in [NoorDocument.preferences.path, NoorDocument.sources.path, NoorDocument.bookmarks.path, Self.timetableFolder, Self.setAsideFolder] {
            try remove(path)
        }
    }

    private func filePaths(_ scope: Scope) -> [String] {
        func inside(_ name: String) -> [String] {
            ((try? FileManager.default.contentsOfDirectory(atPath: folder.appending(path: name).path)) ?? []).map { "\(name)/\($0)" }
        }
        let documents = [NoorDocument.preferences.path, NoorDocument.sources.path, NoorDocument.bookmarks.path]
            .filter { FileManager.default.fileExists(atPath: folder.appending(path: $0).path) }
        return inside(Self.cacheFolder) + (scope == .all ? documents + inside(Self.timetableFolder) : [])
    }

    // Seconds, not ISO strings, so a stored instant reads back exactly.
    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }
}
