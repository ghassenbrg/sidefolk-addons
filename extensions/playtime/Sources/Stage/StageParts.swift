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
    var dockExtra: (node: Node, width: Double)? { puzzleDockExtra }
}
