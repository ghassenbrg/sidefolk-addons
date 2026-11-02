import SidefolkExtensionKit

// A logic puzzle's grid (PuzzleView). Not moved yet: its group fills this in from the panel's PuzzleView.swift.
extension BoardDrawing {
    func puzzlePart(rows: Int, columns: Int, cells: [PuzzleCell], input: String, digits: Int?, box: (rows: Int, columns: Int)?, edges: [PuzzleEdge], plots: [PuzzlePlot],
                    seconds: Double?, running: Bool, locked: Bool) -> PartBlock { unmoved("puzzle") }
    var puzzleFooter: String? { nil }
    var puzzleEyebrow: (((node: Node, width: Double, height: Double)) -> PartBlock)? { nil }
    static func puzzleMove(_ move: SurfaceMove, board: Board, local: inout LocalParts) -> StageAction? { nil }
}

extension BoardDrawing {
    /// A part whose group hasn't moved it: says so on a plain card rather than drawing nothing. Goes when the last part has moved.
    func unmoved(_ name: String) -> PartBlock {
        PartBlock(.box("unmoved.\(name)", w: Self.inner, h: 60) {
            Node.gameCard(w: Self.inner, h: 60)
            Node.words(name, size: 13, align: "center", w: Self.inner, h: 60)
        }, height: 60)
    }
}
