import Foundation
import SidefolkExtensionKit

/// The one surface all the games and the menu live in (D101): a session holds the menu's state and the game on the table, with what the
/// Play panel used to keep for a board. Saved to the data folder at every move, so it survives Playtime stopping while idle. A person's move
/// reaches the game only through what the scene on screen offered; the game itself is `GameTable.Driver` over the same engines and screens.
@MainActor
enum PlayTable {
    struct Session: Codable {
        var menu = true
        var selected = 0
        /// The game on the table, and its state as `GameTable.Driver` keeps it.
        var game: String?
        var state: Data?
        var options = GameOptions()
        var level: GameLevel?
        var local = LocalParts()
        /// What happened in a move whose verdict is held back during its build-up.
        var held: [Games.Event]?
        var pick: Int?
        var played = false
        var recorded = false
        var over = false
        /// When it was put away.
        var keptAt = Date()
    }

    static var folder: String { Paths.data + "/sessions" }
    private static var keptFile: String { folder + "/kept.json" }
    /// What is on screen for each open session: it needn't be read back from the state at every key.
    private static var shown: [String: Board] = [:]
    /// How long a game put away is kept, as the frame keeps a surface.
    static let keptFor: TimeInterval = 600

    // MARK: The surface

    static func open(_ request: SurfaceRequest) -> SurfaceReply {
        let id = UUID().uuidString
        let args = request.arguments
        var session = takeKept() ?? Session()
        session.menu = true
        if let game = args.string("game"), GameTable.drivers[game] != nil {
            let slots = args.string("topic") != nil || args.int("count") != nil || args.int("min") != nil || args.int("max") != nil || args.string("mode") != nil || args.int("players") != nil
            // What the person said about it asks for a new game rather than the one put away.
            if session.game == game, args.bool("fresh") != true, !slots, session.state != nil, !session.over {
                session.menu = false
            } else {
                finishRow(&session)
                begin(game, level: args.string("level").flatMap(GameLevel.init(rawValue:)), args: args, session: &session, id: id)
            }
        }
        let scene = current(&session, id: id, fresh: true)
        save(session, id)
        return SurfaceReply(session: id, scene: scene)
    }

    static func move(_ request: SurfaceRequest) -> Scene {
        let id = request.session
        guard var session = load(id), let move = request.move else {
            return PlayMenu.scene(selected: 0, kept: nil)
        }
        let scene = session.menu ? menuMove(move, session: &session, id: id) : gameMove(move, session: &session, id: id)
        save(session, id)
        return scene
    }

    /// A game left unfinished is kept to come back to: Sidefolk ends the session when another is opening, or the panel was left too long.
    static func close(_ request: SurfaceRequest) {
        let id = request.session
        shown[id] = nil
        guard var session = load(id) else { return }
        try? FileManager.default.removeItem(atPath: path(id))
        if request.reason == "closed", session.game != nil, !session.over {
            session.keptAt = Date()
            if let data = try? JSONEncoder().encode(session) { FileManager.default.createFile(atPath: keptFile, contents: data) }
        } else {
            finishRow(&session)
        }
    }

    /// Whether a game is waiting: Home's Continue.
    static var keptGame: String? {
        guard let data = FileManager.default.contents(atPath: keptFile), let session = try? JSONDecoder().decode(Session.self, from: data),
              Date().timeIntervalSince(session.keptAt) < keptFor else { return nil }
        return session.game
    }

    private static func takeKept() -> Session? {
        defer { try? FileManager.default.removeItem(atPath: keptFile) }
        guard let data = FileManager.default.contents(atPath: keptFile), let session = try? JSONDecoder().decode(Session.self, from: data),
              Date().timeIntervalSince(session.keptAt) < keptFor else { return nil }
        return session
    }

    // MARK: Moves

    private static func menuMove(_ move: SurfaceMove, session: inout Session, id: String) -> Scene {
        let order = PlayMenu.order
        switch move {
        case .click("open", let game?, _):
            return openFromMenu(game, session: &session, id: id)
        case .key(let key, _, _) where key.hasPrefix("arrow_"):
            session.selected = PlayMenu.step(key, from: session.selected, count: order.count, rtl: Language.code == "ar")
        case .key("menu_return", _, _), .key("menu_space", _, _):
            if order.indices.contains(session.selected) { return openFromMenu(order[session.selected].id, session: &session, id: id) }
        default: break
        }
        return PlayMenu.scene(selected: session.selected, kept: session.game)
    }

    /// From the menu: the one put away where it was, or a new one, which ends what was kept.
    private static func openFromMenu(_ game: String, session: inout Session, id: String) -> Scene {
        if session.game == game, session.state != nil, !session.over {
            session.menu = false
            return current(&session, id: id, fresh: true)
        }
        finishRow(&session)
        begin(game, level: nil, args: Arguments([:]), session: &session, id: id)
        return current(&session, id: id, fresh: true)
    }

    private static func gameMove(_ move: SurfaceMove, session: inout Session, id: String) -> Scene {
        guard let entry = session.game.flatMap(GameCatalog.entry), let driver = session.game.flatMap({ GameTable.drivers[$0] }), let data = session.state,
              let board = shown[id] ?? driver.board(data, [], session.options) else {
            session.menu = true
            return PlayMenu.scene(selected: session.selected, kept: nil)
        }
        switch StageMoves.action(move, board: board, local: &session.local) {
        case .back:
            session.menu = true
            return PlayMenu.scene(selected: PlayMenu.index(of: entry.id).map { session.selected = $0; return $0 } ?? session.selected, kept: session.game)
        case .redraw, .ignore:
            return draw(board, entry: entry, session: session, previous: board, fresh: false, id: id)
        case .play(let m):
            // The build-up's moment is over: the verdict the move already holds.
            if m == .next, let held = session.held {
                session.held = nil
                session.pick = nil
                let next = driver.board(data, held, session.options) ?? board
                return verdict(next, previous: board, entry: entry, session: &session, id: id)
            }
            guard session.held == nil, let result = driver.move(m, data, session.options) else {
                return draw(board, entry: entry, session: session, previous: board, fresh: false, id: id)
            }
            session.state = result.state
            if m != .next, m != .timeout { session.played = true }
            var picked: Int?
            if case .answer(let i) = m { picked = i }
            if let (build, ms) = Suspense.buildUp(from: board, to: result.board, picked: picked) {
                session.held = result.events
                session.pick = picked
                session.local.playback = nil
                var ctx = context(entry, session: session, previous: board, fresh: true)
                ctx.buildUp = true
                ctx.pendingAnswer = picked
                ctx.afterMs = ms
                // The board this was built from stays what the build-up's verdict compares against.
                shown[id] = board
                var scene = BoardDrawing(build, ctx).scene()
                if result.board.revealPart != nil { scene = scene.afterStill(ms: 100) }
                return scene
            }
            return verdict(result.board, previous: board, entry: entry, session: &session, id: id)
        }
    }

    /// A board with its result in it, at its moment.
    private static func verdict(_ next: Board, previous: Board?, entry: GameEntry, session: inout Session, id: String) -> Scene {
        StageMoves.settle(next, local: &session.local)
        session.over = next.over
        if next.over {
            if !session.recorded { record(next, entry: entry, session: &session) }
        } else {
            session.recorded = false
        }
        return draw(next, entry: entry, session: session, previous: previous, fresh: true, id: id)
    }

    private static func draw(_ board: Board, entry: GameEntry, session: Session, previous: Board?, fresh: Bool, id: String) -> Scene {
        shown[id] = board
        var scene = BoardDrawing(board, context(entry, session: session, previous: previous, fresh: fresh)).scene()
        if !board.typesWithDelete { scene = scene.key("delete", id: "back_delete", always: true) }
        return scene
    }

    private static func context(_ entry: GameEntry, session: Session, previous: Board?, fresh: Bool) -> StageContext {
        StageContext(entry: entry, previous: previous, fresh: fresh, local: session.local)
    }

    /// What is on the table: the menu, the game as it stands (its verdict, if the build-up was left), or nothing.
    private static func current(_ session: inout Session, id: String, fresh: Bool) -> Scene {
        guard !session.menu, let game = session.game, let entry = GameCatalog.entry(game), let driver = GameTable.drivers[game], let data = session.state else {
            session.menu = true
            return PlayMenu.scene(selected: session.selected, kept: session.game)
        }
        let held = session.held ?? []
        session.held = nil
        session.pick = nil
        let board = shown[id] ?? driver.board(data, held, session.options) ?? Board([])
        Playback.cameBack(board, local: &session.local)
        return draw(board, entry: entry, session: session, previous: nil, fresh: fresh, id: id)
    }

    // MARK: Starting

    private static func begin(_ game: String, level: GameLevel?, args: Arguments, session: inout Session, id: String) {
        guard let driver = GameTable.drivers[game] else { return }
        var options = PlayOptions.make(args)
        let chosen = level ?? PlayOptions.chosenLevel(game)
        options.asked = chosen
        PlaytimeRecords.update { $0.lastOpened = PlaytimeRecords.Opened(game: game, level: chosen?.rawValue) }
        let started = driver.start(options, chosen ?? .fair)
        session.game = game
        session.state = started.state
        session.options = options
        session.level = chosen
        session.local = LocalParts()
        session.held = nil
        session.pick = nil
        session.played = false
        session.recorded = false
        session.over = false
        session.menu = false
        StageMoves.settle(started.board, local: &session.local)
        shown[id] = started.board
    }

    // MARK: One row in History

    /// The one row a game leaves, when it ends rather than a row a move, in Playtime's words: "Played Trivia with Playtime · You 7 · Mochi 6".
    private static func record(_ board: Board, entry: GameEntry, session: inout Session) {
        session.recorded = true
        let result = board.resultPart.map { Verdict(tone: $0.tone).rawValue }
        var text = L("Played {title} with {with}", ["title": entry.title, "with": L("Playtime")])
        let score = board.scorePart
        if let score, let names = score.players {
            // Two people played each other: their names and points, and no result, so the person's record against the companion stays theirs alone.
            text = L("Played {title}: {first} {x} · {second} {y}", ["title": entry.title, "first": names[0], "x": score.you, "second": names[1], "y": score.companion])
            Activity.add(text, key: entry.id)
            PlaytimeRecords.update { $0.addPlay(entry.id, result: nil) }
            return
        }
        if let score { text += " · " + L("You {x} · {name} {y}", ["x": score.you, "name": "{companion}", "y": score.companion]) }
        Activity.add(text, key: entry.id, result: result)
        PlaytimeRecords.update { $0.addPlay(entry.id, result: result) }
    }

    /// A game that was played and never said it was over still gets its row when it goes.
    private static func finishRow(_ session: inout Session) {
        guard session.played, !session.recorded, let game = session.game, let entry = GameCatalog.entry(game) else { return }
        session.recorded = true
        Activity.add(L("Played {title} with {with}", ["title": entry.title, "with": L("Playtime")]), key: game)
    }

    // MARK: Files

    private static func path(_ session: String) -> String {
        // Only names Playtime made: a UUID's letters, digits and dashes.
        let safe = session.filter { $0.isLetter || $0.isNumber || $0 == "-" }
        return folder + "/\(safe.isEmpty ? "none" : safe).json"
    }

    private static func save(_ session: Session, _ id: String) {
        try? FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(session) { FileManager.default.createFile(atPath: path(id), contents: data) }
        tidy()
    }

    private static func load(_ id: String) -> Session? {
        FileManager.default.contents(atPath: path(id)).flatMap { try? JSONDecoder().decode(Session.self, from: $0) }
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

/// Sidefolk's options for every game (D93), now the program's: from the settings it declares and what was said about the game.
@MainActor
enum PlayOptions {
    static func make(_ args: Arguments) -> GameOptions {
        var o = GameOptions()
        o.language = Localized.normalized(Language.code)
        o.tone = ExtensionSettings.string("tone") ?? "cheeky"
        o.sneaky = ExtensionSettings.bool("sneaky") ?? false
        o.twoPlayers = args.int("players") == 2
        o.min = args.int("min")
        o.max = args.int("max")
        o.mode = args.string("mode")
        o.topic = args.string("topic")
        o.count = args.int("count")
        // Which AI makes new trivia questions while the person allows it: its name only, for the board's label.
        o.aiTrivia = AI.available
        return o
    }

    /// The level a game opens at, when the person chose one.
    static func chosenLevel(_ game: String) -> GameLevel? {
        ExtensionSettings.string(GameSoundSetting.levelKey(game)).flatMap(GameLevel.init(rawValue:))
    }
}

/// The switches and choices Playtime declares per game.
enum GameSoundSetting {
    /// The frame's speaker in that game: each game's own, as the panel's was.
    static func key(_ game: String) -> String { "sound_" + game }
    static func levelKey(_ game: String) -> String { "level_" + game }
}
