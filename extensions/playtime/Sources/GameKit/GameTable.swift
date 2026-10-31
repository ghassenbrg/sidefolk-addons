import Foundation
import SidefolkExtensionKit

/// Plays a screen's game over the channel: a session per game opened, its state kept in the data folder as JSON so a
/// game survives Playtime stopping while idle, and forgotten when Sidefolk says it ended.
enum GameTable {
    static var folder: String { Paths.data + "/sessions" }

    struct Saved<State: Codable>: Codable {
        var state: State
        var options: GameOptions
        var language: String
    }

    @MainActor
    static func register<S: GameScreen>(_ screen: S.Type, on ext: Extension) {
        ext.game(S.id, start: { request in
            var random = SystemRandomNumberGenerator()
            let options = GameOptions(request.options, language: request.language)
            let state = S.Engine.start(level: GameLevel(rawValue: request.level ?? "") ?? .fair, options: options, random: &random)
            let session = UUID().uuidString
            save(Saved(state: state, options: options, language: request.language), session)
            return GameReply(session: session, board: S.board(state, events: [.other("opened")], words: Words.for(request.language), options: options))
        }, move: { request in
            guard var saved: Saved<S.Engine.State> = load(request.session) else {
                return Board([.note(Words.for(request.language)["session.gone"], tone: .warn)], over: true)
            }
            var random = SystemRandomNumberGenerator()
            var events: [GameEvent] = []
            if let move = request.move, let action = S.action(for: move, in: saved.state) {
                events = S.Engine.play(action, on: &saved.state, random: &random) ?? []
                save(saved, request.session)
            }
            return S.board(saved.state, events: events, words: Words.for(saved.language), options: saved.options)
        }, end: { request in
            try? FileManager.default.removeItem(atPath: path(request.session))
        })
    }

    static func path(_ session: String) -> String {
        // Only names Playtime made: a UUID's letters, digits and dashes.
        let safe = session.filter { $0.isLetter || $0.isNumber || $0 == "-" }
        return folder + "/\(safe.isEmpty ? "none" : safe).json"
    }

    static func save<T: Codable>(_ value: T, _ session: String) {
        try? FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(value) { FileManager.default.createFile(atPath: path(session), contents: data) }
        tidy()
    }

    static func load<T: Codable>(_ session: String) -> T? {
        FileManager.default.contents(atPath: path(session)).flatMap { try? JSONDecoder().decode(T.self, from: $0) }
    }

    /// Sessions Sidefolk never ended (it quit mid-game) go after a day.
    private static func tidy() {
        let fm = FileManager.default
        for name in (try? fm.contentsOfDirectory(atPath: folder)) ?? [] {
            let file = folder + "/" + name
            if let date = (try? fm.attributesOfItem(atPath: file))?[.modificationDate] as? Date, date < Date().addingTimeInterval(-86_400) {
                try? fm.removeItem(atPath: file)
            }
        }
    }
}
