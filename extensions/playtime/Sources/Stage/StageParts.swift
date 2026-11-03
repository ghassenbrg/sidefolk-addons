import SidefolkExtensionKit

// What a part adds to the stage's words and the controls: the table props and puzzle fill these in their own files.
extension BoardDrawing {
    /// A part saying something in the companion's bubble instead of the board's prompt ("Shuffling…", "Watch…").
    var partsStageWords: String? { cupsStageWords ?? padsStageWords }
    /// Something of a part's that stands first among the controls: Sudoku's notes switch.
    /// A question stands on its own card in the board, so the bubble says something short instead.
    var stageWordsOverride: String? { nil }
    var dockExtra: (node: Node, width: Double)? { puzzleDockExtra }
    /// The toys lay out the whole room themselves: what comes and goes around one (who plays, the next round, a best time, a secret) has its place in it (`slotRow`), so it never
    /// pushes the toy or changes the room it has.
    var partHoldsRoom: Bool { !ended && (board.hasCups || board.hasPads || board.hasReflex || board.hasSticks) }
}
