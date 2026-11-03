import SidefolkExtensionKit

// What a part adds to the stage's words and the controls: the table props and puzzle fill these in their own files.
extension BoardDrawing {
    /// A part saying something in the companion's bubble instead of the board's prompt ("Shuffling…", "Watch…").
    var partsStageWords: String? { cupsStageWords ?? padsStageWords }
    /// Something of a part's that stands first among the controls: Sudoku's notes switch.
    /// A question stands on its own card in the board, so the bubble says something short instead. A refusal is the companion's to say too: the bubble is the one place it can't push anything.
    var stageWordsOverride: String? {
        guard let table = gameTable else { return nil }
        if let refusal = board.parts.lazy.compactMap({ part -> String? in if case .note(let text, _, .warn) = part { text } else { nil } }).first { return refusal }
        if ctx.buildUp, table != .hands { return L("Let's see…") }
        return board.said
    }
    var dockExtra: (node: Node, width: Double)? { puzzleDockExtra ?? opponentInDock }

    /// The controls' room, kept for a game whose buttons come and go, so its board never moves for one.
    var dockRoom: Double {
        if board.gridPart?.numpad == true || isStall { return 46 }
        return 0
    }

    /// A hint on these boards is the quiet button; it isn't the one thing to do.
    var quietHints: Bool { board.gridPart != nil || board.hasLetters }

    /// Who plays stands in the controls, where it costs the board nothing, on a game that keeps their room.
    private var opponentInDock: (node: Node, width: Double)? {
        guard board.gridPart?.numpad == true || isStall else { return nil }
        return opponentRow(width: 280).map { row in (Node.box(w: Self.inner, h: 32) { row.node.at((Self.inner - row.width) / 2, 0) }, Self.inner) }
    }

    /// A part drawn somewhere of its own rather than stacked on the board.
    func placedElsewhere(_ part: BoardPart) -> Bool {
        switch part {
        case .choice("opponent", _, _, _, _): return board.gridPart != nil || isStall
        case .play(.lives): return isStall
        default: return false
        }
    }

    /// Daily Word's hint stands beside its legend, on the tray.
    func buttonPlacedElsewhere(_ b: GameButton) -> Bool { b.move == "hint" && board.lettersPart?.style == "rows" }
    /// The toys lay out the whole room themselves: what comes and goes around one (who plays, the next round, a best time, a secret) has its place in it (`slotRow`), so it never
    /// pushes the toy or changes the room it has.
    var partHoldsRoom: Bool { !ended && (board.hasCups || board.hasPads || board.hasReflex || board.hasSticks) }
}
