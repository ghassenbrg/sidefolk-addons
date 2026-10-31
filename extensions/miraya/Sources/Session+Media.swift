import Foundation
import SidefolkExtensionKit

/// "Play video on TV", as in the Mac app: the TV plays the original file, reading it in pieces over the same pinned TLS
/// connection (no server on the Mac), or fetches an HTTPS address itself. Nothing is captured or re-encoded.
extension Session {
    func startMedia(session: TVConnection, receiver: Receiver, generation: UUID) {
        guard supportsDirectMedia else {
            failed(ConnectionFailure(message: L("Update Miraya on the TV to play videos on it."), retryable: false), receiver: receiver, generation: generation); return
        }
        guard let media else { return }
        files.close(); mediaLoadID = UUID().uuidString.lowercased()
        var message: [String: Any] = ["op": "mediaLoad", "loadId": mediaLoadID, "volume": choices.volume]
        var assets: [[String: Any]] = []
        do {
            if let file = media.file {
                let asset = try files.authorize(file); assets.append(asset)
                message["url"] = "miraya-file:///\(asset["id"]!)"
                if let mime = Self.mime(file.pathExtension) { message["mime"] = mime }
            } else {
                guard let url = media.url, DirectMedia.validRemoteURL(url) else { throw WireError.invalidControl }
                message["url"] = url
            }
            if let subtitle = media.subtitle {
                let ext = subtitle.pathExtension.lowercased()
                guard ["srt", "vtt"].contains(ext) else { throw WireError.invalidControl }
                let asset = try files.authorize(subtitle); assets.append(asset)
                message["subtitle"] = ["url": "miraya-file:///\(asset["id"]!)", "mime": ext == "srt" ? "application/x-subrip" : "text/vtt"]
            }
            message["assets"] = assets
            setPhase(.starting)
            session.sendControl(message)
            expire(after: 30, in: .starting, L("The TV didn't start playing within {seconds} seconds. Check the video's format and address.", ["seconds": 30]), retryable: false)
        } catch {
            failed(ConnectionFailure(message: L("Couldn't open that video. Choose the file or HTTPS address again."), retryable: false), receiver: receiver, generation: generation)
        }
    }

    /// Types the TV's player is told up front (it works the rest out itself).
    static func mime(_ ext: String) -> String? {
        ["mp4": "video/mp4", "m4v": "video/mp4", "mov": "video/quicktime", "mkv": "video/x-matroska", "webm": "video/webm",
         "mp3": "audio/mpeg", "m4a": "audio/mp4"][ext.lowercased()]
    }

    func mediaCommand(_ action: String, extra: [String: Any] = [:]) throws {
        guard mode == .media, !mediaLoadID.isEmpty, [.sharing, .paused].contains(phase) else { throw ConnectionFailure(message: L("Nothing is playing on the TV.")) }
        var message = extra; message["op"] = "mediaCommand"; message["loadId"] = mediaLoadID; message["action"] = action
        connection?.sendControl(message)
    }

    func seek(by seconds: Double) throws {
        guard mediaSeekable else { throw ConnectionFailure(message: L("This video can't jump ahead or back.")) }
        let target = max(0, min(mediaDuration, mediaPosition + seconds))
        try mediaCommand("seek", extra: ["positionMs": Int64(target * 1000)])
    }
}
