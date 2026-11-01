import Foundation
import SidefolkExtensionKit

// Playtime's games are built in two halves (Sidefolk D75):
// - an engine: the rules as pure logic over a Codable state, no I/O and no words, its chance a `Games.Random` passed
//   in (fresh from the system in play, seeded in tests); the ten new games wrap the `Games.*` engines (Sources/Games/),
//   trivia is its own (Sources/Trivia/);
// - a screen: the engine's state as a Sidefolk board in the person's words (`L`, strings/), and the board's moves as
//   the engine's actions. `GameTable` joins them to the game channel and keeps each session's state in the data
//   folder, so a game left open survives Playtime being stopped while idle. What happened (`Games.Event`) becomes the
//   companion's reaction through one table (`EventCues`).

typealias GameLevel = Games.Level

/// How a game ended, for the score and the companion's reaction.
enum GameOutcome: String, Codable, Equatable {
    /// The person won.
    case won
    /// The companion won.
    case lost
    case draw
}

/// The rules of one game.
protocol GameEngine {
    associatedtype State: Codable
    associatedtype Action

    /// A new game at a level, with Sidefolk's options (`sneaky`, the language).
    static func start(level: GameLevel, options: GameOptions, random: inout Games.Random) -> State
    /// What the opening board reacts to besides the hello (trivia's companion thinking, a sealed card).
    static func opening(_ state: State) -> [Games.Event]
    /// One of the person's actions (or `next`, the companion's turn once it has thought). Throws `Games.Refusal` for a
    /// move the rules refuse; the state is then unchanged.
    static func play(_ action: Action, on state: inout State, random: inout Games.Random) throws -> [Games.Event]
    /// Set once the game is over.
    static func outcome(of state: State) -> GameOutcome?
}

extension GameEngine {
    static func opening(_ state: State) -> [Games.Event] { [] }
}

/// What Sidefolk passes every game besides the level.
struct GameOptions: Codable, Equatable {
    /// The companion may cheat for fun where a game offers it, always confessing when caught (off unless the person
    /// turned Sneaky on).
    var sneaky = false
    /// How the companion takes a win: gentle, cheeky, competitive.
    var tone = "cheeky"
    /// The companion's name, for the words that name it ("Ask Mochi").
    var companion = "Mochi"
    /// The person's language, for content that comes per language (questions, words, animals).
    var language = "en"
    /// The level the person asked for, nil when Sidefolk sent none (a game opened from the menu): a puzzle then opens
    /// at the level last picked.
    var asked: GameLevel?

    init() {}

    init(_ args: Arguments, language: String) {
        sneaky = args.bool("sneaky") ?? false
        tone = args.string("tone") ?? "cheeky"
        companion = args.string("companion") ?? "Mochi"
        self.language = Localized.normalized(language)
    }

    var gamesLanguage: Games.Language { Games.Language(code: language) }
}

/// One game's state as Sidefolk's board, and the board's moves as the engine's actions.
protocol GameScreen {
    associatedtype Engine: GameEngine

    /// Its name in the manifest (`games.<id>`).
    static var id: String { get }
    static func action(for move: Move, in state: Engine.State) -> Engine.Action?
    /// The board now, in the person's language (the request's, through `L`), and the companion's reaction to what
    /// just happened.
    static func board(_ state: Engine.State, events: [Games.Event], options: GameOptions) -> Board
}
