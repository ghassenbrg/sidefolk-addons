import SidefolkExtensionKit

/// What the pause card's buttons send, and the moves a game takes from it.
enum PauseMoves {
    static let pause = "__pause"
    static let resume = "__resume"
    static let newGame = "__new_game"
    static let today = "__today"
    static let stopClock = "__clock_stop"
    static let startClock = "__clock_start"
    /// A choice: a new board or word at this level, leaving the day's as it is.
    static let fresh = "__fresh"
}

/// The pause card: keep playing, start again, another level, or leave. A game stays exactly as it was behind it, and leaving keeps it to come back to. Nothing here touches a record: only
/// an end does. In a puzzle or Daily Word, a new one is practice, so today's stays as far as it was played.
enum PauseCard {
    static func board(entry: GameEntry, board game: Board, level: GameLevel?, away: Bool) -> Board {
        let daily = game.hasPuzzle || entry.id == DailyWordScreen.id
        let fresh = entry.id == DailyWordScreen.id ? L("New word") : game.hasPuzzle ? L("New board") : L("New game")
        var actions = [GameButton(L("Keep playing"), move: PauseMoves.resume, style: .primary, symbol: "play.fill"),
                       GameButton(fresh, move: PauseMoves.newGame, style: .secondary, symbol: "arrow.clockwise")]
        if daily, away {
            actions.append(GameButton(entry.id == DailyWordScreen.id ? L("Back to today's word") : L("Back to today's puzzle"), move: PauseMoves.today, style: .secondary))
        }
        let score = game.scorePart.map { "\($0.you) – \($0.companion)" } ?? ""
        var parts: [BoardPart] = [.result(figure: score, line: game.promptPart?.eyebrow, ribbon: nil, tone: .neutral, facts: [], actions: actions)]
        if let level { parts.append(ScreenKit.levels(level)) }
        var card = Board(parts, over: true)
        card.endTitle = L("Paused")
        card.plainCard = true
        return card
    }
}
