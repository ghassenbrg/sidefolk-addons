import SidefolkExtensionKit

// What a part adds to the stage's words and row: the table props and puzzle fill these in their own files.
extension BoardDrawing {
    /// A part saying something in the companion's bubble instead of the board's prompt ("Shuffling…", "Watch…").
    var partsStageWords: String? { cupsStageWords ?? padsStageWords }
    /// A puzzle's clock and Sudoku's notes switch beside the eyebrow.
    var puzzleEyebrowExtras: (((node: Node, width: Double, height: Double)) -> PartBlock)? { puzzleEyebrow }
}
