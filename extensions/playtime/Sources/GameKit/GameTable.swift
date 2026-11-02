import Foundation
import SidefolkExtensionKit

/// Plays a screen's game: its state as data the surface's session keeps in the data folder (`PlayTable`), so a game survives Playtime
/// stopping while idle.
enum GameTable {
    static var folder: String { Paths.data + "/sessions" }

    /// One screen's game with its state as data, so one surface can hold any of them (`PlayTable`).
    struct Driver {
        let id: String
        let start: (_ options: GameOptions, _ level: GameLevel) -> (state: Data, board: Board)
        let move: (_ move: Move, _ state: Data, _ options: GameOptions) -> (state: Data, events: [Games.Event], board: Board)?
        /// The board for a state, with what just happened: a verdict held back during its build-up, or a game coming back.
        let board: (_ state: Data, _ events: [Games.Event], _ options: GameOptions) -> Board?
    }

    static func driver<S: GameScreen>(_ screen: S.Type) -> Driver {
        func read(_ data: Data) -> S.Engine.State? { try? JSONDecoder().decode(S.Engine.State.self, from: data) }
        func write(_ state: S.Engine.State) -> Data { (try? JSONEncoder().encode(state)) ?? Data() }
        return Driver(id: S.id, start: { options, level in
            // Real chance from the Mac's generator for every game; tests seed their own.
            var random = Games.Random.fresh()
            let state = S.Engine.start(level: level, options: options, random: &random)
            return (write(state), S.board(state, events: [.opened] + S.Engine.opening(state), options: options))
        }, move: { move, data, options in
            guard var state = read(data) else { return nil }
            var random = Games.Random.fresh()
            let events = play(S.self, move, on: &state, random: &random)
            return (write(state), events, S.board(state, events: events, options: options))
        }, board: { data, events, options in
            read(data).map { S.board($0, events: events, options: options) }
        })
    }

    /// Every game, by the id its menu card and commands name.
    nonisolated(unsafe) static let drivers: [String: Driver] = Dictionary(uniqueKeysWithValues: [
        driver(TriviaScreen.self), driver(TicTacToeScreen.self), driver(CopyMeScreen.self), driver(QuickPawsScreen.self), driver(WhichCupScreen.self),
        driver(HigherLowerScreen.self), driver(GuessAnimalScreen.self), driver(BalloonWordsScreen.self), driver(LastStickScreen.self), driver(MemoryPairsScreen.self),
        driver(DailyWordScreen.self), driver(PuzzleScreen<GardenPlotsKind>.self), driver(PuzzleScreen<SeesawKind>.self), driver(PuzzleScreen<SudokuKind>.self),
        driver(PuzzleScreen<BlossomsKind>.self),
    ].map { ($0.id, $0) })

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
}
