import Foundation
import SidefolkExtensionKit

/// Tic-tac-toe, "Noughts with the companion": a series to three on a 3 × 3 board played with the number pad. After
/// the person's move the companion thinks (the engine's time, which Sidefolk keeps) and then plays its O.
enum TicTacToeEngine: GameEngine {
    struct State: Codable, Equatable {
        var game: Games.TicTacToe
        var hint: Int?
        /// The cells just played, stamped in.
        var fresh: [Int] = []
        /// Which game of the series this is.
        var number = 1
    }

    enum Action: Equatable { case cell(Int), next, hint, again, level(GameLevel) }

    static func start(level: GameLevel, options: GameOptions, random: inout Games.Random) -> State {
        State(game: Games.TicTacToe(level: level, first: .you))
    }

    static func play(_ action: Action, on s: inout State, random: inout Games.Random) throws -> [Games.Event] {
        var events: [Games.Event]
        switch action {
        case .cell(let i):
            events = try s.game.play(i, by: .you)
            s.fresh = [i]
            s.hint = nil
        case .next:
            guard s.game.turn == .companion, !s.game.gameOver else { throw Games.Refusal("not_now") }
            // Its move is chosen now, from the board as it stands: the person's next move isn't known to it.
            let i = s.game.companionMove(using: &random)
            events = try s.game.play(i, by: .companion)
            s.fresh = [i]
        case .hint:
            let (cell, e) = try s.game.hint()
            s.hint = cell
            events = e
        case .again:
            if s.game.seriesOver {
                s = State(game: Games.TicTacToe(level: s.game.level, first: .you))
                return [.turn(.you)]
            }
            events = try s.game.nextGame()
            s.number += 1
            s.fresh = []
            s.hint = nil
        case .level(let level):
            s = State(game: Games.TicTacToe(level: level, first: .you))
            return [.turn(.you)]
        }
        if events.contains(where: { if case .matchOver = $0 { true } else { false } }), let outcome = outcome(of: s) {
            PlaytimeRecords.finish(TicTacToeScreen.id, outcome, you: s.game.series.you, companion: s.game.series.companion)
        }
        return events
    }

    static func outcome(of s: State) -> GameOutcome? {
        guard s.game.seriesOver else { return nil }
        return s.game.series.leader == .you ? .won : .lost
    }
}

enum TicTacToeScreen: GameScreen {
    typealias Engine = TicTacToeEngine
    static let id = "tictactoe"

    static func action(for move: Move, in s: TicTacToeEngine.State) -> TicTacToeEngine.Action? {
        switch move {
        case .cell(let r, let c): .cell(r * 3 + c)
        case .next: .next
        case .button("hint"): .hint
        case .button("again"): .again
        case .choice("level", let l): GameLevel(rawValue: l).map { .level($0) }
        default: nil
        }
    }

    static func board(_ s: TicTacToeEngine.State, events: [Games.Event], options o: GameOptions) -> Board {
        let g = s.game
        let line = Set(g.winningLine ?? [])
        let winner = g.winningLine.flatMap { g.cells[$0[0]] }
        let cells = (0..<9).map { i -> Cell in
            let side = g.cells[i]
            let label = L("Row {row}, column {column}", ["row": i / 3 + 1, "column": i % 3 + 1])
            return Cell(side == .you ? "x" : side == .companion ? "o" : "empty", companion: side == .companion,
                        state: line.contains(i) ? "win" : s.hint == i ? "hint" : nil,
                        label: side.map { label + ", " + ($0 == .you ? "X" : "O") } ?? label,
                        animate: s.fresh.contains(i) ? "stamp" : nil)
        }
        let thinking = events.compactMap { if case .think(let ms) = $0 { ms } else { nil } }.first
        let status: String = if g.gameOver {
            winner == .you ? L("You win this game!") : winner == .companion ? L("{name} wins this game.", ["name": o.companion]) : L("Cat's game: a draw.")
        } else if g.turn == .you {
            L("Your turn: you're X.")
        } else {
            L("{name} is thinking…", ["name": o.companion])
        }
        var parts: [BoardPart] = [
            ScreenKit.score(g.series, rounds: Games.TicTacToe.seriesTarget),
            .prompt(status, eyebrow: L("Game {n} · {level}", ["n": s.number, "level": ScreenKit.level(g.level)])),
            .board(rows: 3, columns: 3, cells: cells, locked: g.gameOver || g.turn != .you, numpad: true),
        ]
        if let note = ScreenKit.refusal(events) { parts.append(note) }
        if let outcome = TicTacToeEngine.outcome(of: s) {
            parts.append(ScreenKit.result(outcome, figure: "\(Format.integer(g.series.you)) – \(Format.integer(g.series.companion))",
                                          companion: o.companion))
            parts.append(ScreenKit.levels(g.level))
        } else if g.gameOver {
            parts.append(.button(GameButton(L("Next game"), move: "again", style: .primary, symbol: "arrow.right")))
        } else if g.turn == .you, !g.hintUsed {
            parts.append(.button(GameButton(L("Hint"), move: "hint", style: .plain, symbol: "lightbulb", key: "h")))
        }
        var cue = EventCues.cue(events)
        if let hint = s.hint, events.contains(.hint) { cue?.look = [hint / 3, hint % 3] }
        if let at = s.fresh.first, thinking == nil, g.turn == .you, !g.gameOver, events.contains(.turn(.you)) { cue?.look = [at / 3, at % 3] }
        return Board(parts, companion: cue, over: TicTacToeEngine.outcome(of: s) != nil, afterMs: thinking)
    }
}
