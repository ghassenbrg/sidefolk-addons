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
            // Real chance from the Mac's generator for every game; tests seed their own.
            var random = Games.Random.fresh()
            let options = GameOptions(request.options, language: request.language)
            let state = S.Engine.start(level: GameLevel(rawValue: request.level ?? "") ?? .fair, options: options, random: &random)
            let session = UUID().uuidString
            save(Saved(state: state, options: options, language: options.language), session)
            // The words are in the request's language, which the Kit keeps for it (D76).
            return GameReply(session: session, board: S.board(state, events: [.opened] + S.Engine.opening(state), options: options))
        }, move: { request in
            guard var saved: Saved<S.Engine.State> = load(request.session) else {
                return Board([.note(L("This game has ended. Open it again to play."), tone: .warn)], over: true)
            }
            var random = Games.Random.fresh()
            let events = play(S.self, request.move, on: &saved.state, random: &random)
            save(saved, request.session)
            return S.board(saved.state, events: events, options: saved.options)
        }, end: { request in
            try? FileManager.default.removeItem(atPath: path(request.session))
        })
    }

    /// One move on a state: the engine's events, or the reason it refused the move (the state unchanged).
    static func play<S: GameScreen>(_ screen: S.Type, _ move: Move?, on state: inout S.Engine.State,
                                    random: inout Games.Random) -> [Games.Event] {
        guard let move, let action = S.action(for: move, in: state) else { return [] }
        var next = state
        do {
            let events = try S.Engine.play(action, on: &next, random: &random)
            state = next
            return events
        } catch let refusal as Games.Refusal {
            return [.refused(refusal.reason)]
        } catch {
            return []
        }
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
