import Foundation
import SidefolkExtensionKit

/// Tic-tac-toe between two people (D96): the first is X, the second O, turns taken on the same board, a series to three
/// with who starts alternating; the companion watches and referees.
extension TicTacToeScreen {
    static func duoBoard(_ s: TicTacToeEngine.State, events: [Games.Event], options o: GameOptions) -> Board {
        let d = s.duo
        if d.naming != nil { return TwoPlayers.namesBoard(d, companion: o.companion, title: L("Tic-tac-toe")) }
        let g = s.game
        let line = Set(g.winningLine ?? [])
        let winner = g.winningLine.flatMap { g.cells[$0[0]] }
        let cells = (0..<9).map { i -> Cell in
            let side = g.cells[i]
            let label = L("Row {row}, column {column}", ["row": i / 3 + 1, "column": i % 3 + 1])
            return Cell(side == .you ? "x" : side == .companion ? "o" : "empty", state: line.contains(i) ? "win" : nil,
                        label: side.map { label + ", " + d.name($0) } ?? label, animate: s.fresh.contains(i) ? "stamp" : nil)
        }
        let status: String = if g.gameOver {
            winner.map { L("{name} wins this game!", ["name": d.name($0)]) } ?? L("Cat's game: a draw.")
        } else {
            TwoPlayers.turn(d, g.turn) + " · " + (g.turn == .you ? "X" : "O")
        }
        var parts: [BoardPart] = [
            TwoPlayers.score(d, g.series.you, g.series.companion, rounds: Games.TicTacToe.seriesTarget),
            .prompt(status, eyebrow: L("Game {n}", ["n": s.number])),
            .board(rows: 3, columns: 3, cells: cells, locked: g.gameOver, numpad: true),
        ]
        if let note = ScreenKit.refusal(events) { parts.append(note) }
        if g.seriesOver {
            var facts: [(String, String)] = []
            if let tally = TwoPlayers.tally(id, d) { facts.append(tally) }
            parts.append(TwoPlayers.result(d, winner: g.series.leader, figure: "\(Format.integer(g.series.you)) – \(Format.integer(g.series.companion))",
                                           facts: facts))
        } else if g.gameOver {
            parts.append(.button(GameButton(L("Next game"), move: "again", style: .primary, symbol: "arrow.right")))
        }
        var cue = TwoPlayers.cue(events)
        if let at = s.fresh.first, !g.gameOver { cue?.look = [at / 3, at % 3] }
        return Board(parts, companion: cue, over: g.seriesOver)
    }
}
