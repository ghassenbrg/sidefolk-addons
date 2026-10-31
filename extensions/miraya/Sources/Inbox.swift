import Foundation

/// How a file the person names reaches the TV. Sidefolk opens a named file only to a process started for that one call
/// (D39), which ends with it; playing takes as long as the film. So that process makes a copy-on-write clone of the file
/// in the extension's own folder (no extra space on the same disk) and hands it to the main process through this
/// folder; the clone is deleted when playback stops. A file on another disk can't be cloned, and is said so.
struct Inbox {
    struct Request: Codable, Equatable {
        var id: String
        var file: String?
        var subtitle: String?
        var url: String?
        var tv: String?
        var title: String
    }

    let dir: URL

    init(folder: URL) { dir = folder.appendingPathComponent("inbox", isDirectory: true) }

    static let playable: Set<String> = ["mp4", "m4v", "mov", "mkv", "webm", "ts", "avi", "mp3", "m4a", "aac", "flac", "wav", "ogg", "opus"]

    // MARK: In the process started for the call

    /// Clones the file (and subtitles) into the inbox; throws a Problem-worthy message when it can't.
    func lend(file: String, subtitle: String?, url: String?, tv: String?) throws -> Request {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let id = UUID().uuidString.lowercased()
        let source = URL(fileURLWithPath: file)
        guard Self.playable.contains(source.pathExtension.lowercased()) else {
            throw ConnectionFailure(message: "\(source.lastPathComponent) isn't a video or audio file the TV can play.", retryable: false)
        }
        let video = try clone(source, as: "\(id).\(source.pathExtension.lowercased())")
        var subs: String?
        if let subtitle {
            let s = URL(fileURLWithPath: subtitle)
            guard ["srt", "vtt"].contains(s.pathExtension.lowercased()) else {
                try? FileManager.default.removeItem(atPath: video)
                throw ConnectionFailure(message: "Subtitles must be an .srt or .vtt file.", retryable: false)
            }
            subs = try clone(s, as: "\(id)-subtitles.\(s.pathExtension.lowercased())")
        }
        return Request(id: id, file: video, subtitle: subs, url: url, tv: tv, title: source.lastPathComponent)
    }

    private func clone(_ source: URL, as name: String) throws -> String {
        var st = stat()
        guard lstat(source.path, &st) == 0, st.st_mode & S_IFMT == S_IFREG, st.st_size > 0 else {
            throw ConnectionFailure(message: "\(source.lastPathComponent) isn't a file Miraya can read.", retryable: false)
        }
        let target = dir.appendingPathComponent(name).path
        guard clonefile(source.path, target, UInt32(CLONE_NOFOLLOW)) == 0 else {
            let why = errno
            if why == EXDEV || why == ENOTSUP {
                throw ConnectionFailure(message: "\(source.lastPathComponent) is on another disk. Copy it to your Mac's own disk first: Sidefolk lends Miraya "
                    + "a copy-on-write copy, which only works on the same disk.", retryable: false)
            }
            throw ConnectionFailure(message: "Couldn't open \(source.lastPathComponent): \(String(cString: strerror(why))).", retryable: false)
        }
        return target
    }

    func post(_ request: Request) throws {
        try JSONEncoder().encode(request).write(to: dir.appendingPathComponent("\(request.id).json"), options: .atomic)
    }

    /// The main process's answer, waited for at most `seconds`.
    func answer(_ id: String, within seconds: Double) async -> String? {
        let file = dir.appendingPathComponent("\(id).answer")
        let end = Date().addingTimeInterval(seconds)
        while Date() < end {
            if let text = try? String(contentsOf: file, encoding: .utf8) {
                try? FileManager.default.removeItem(at: file)
                return text
            }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        // Nobody picked it up: take it back, so it doesn't start later by surprise.
        try? FileManager.default.removeItem(at: dir.appendingPathComponent("\(id).json"))
        return nil
    }

    // MARK: In the main process

    /// Requests waiting, oldest first; each is taken out of the inbox as it's read.
    func take() -> [Request] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
        var out: [Request] = []
        for name in names.sorted() where name.hasSuffix(".json") {
            let url = dir.appendingPathComponent(name)
            if let data = try? Data(contentsOf: url), let request = try? JSONDecoder().decode(Request.self, from: data) { out.append(request) }
            try? FileManager.default.removeItem(at: url)
        }
        return out
    }

    func reply(_ id: String, _ text: String) {
        try? text.write(to: dir.appendingPathComponent("\(id).answer"), atomically: true, encoding: .utf8)
    }

    /// Deletes these lent copies (playback ended), or every one left from an earlier run.
    func remove(_ paths: [String]) {
        for path in paths where path.hasPrefix(dir.path + "/") { try? FileManager.default.removeItem(atPath: path) }
    }

    func clearAll() { try? FileManager.default.removeItem(at: dir) }
}
