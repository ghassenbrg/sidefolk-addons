import SidefolkExtensionKit

// Copy Me's pads (PadsView). Not moved yet: its group fills this in from the panel's PadsCupsReflexViews.swift.
extension BoardDrawing {
    func padsPart(_ pads: [Pad], play: [Int], stepMs: Int, locked: Bool) -> PartBlock { unmoved("pads") }
    var padsFooter: String? { nil }
    var padsStageWords: String? { nil }
    static func padsMove(_ move: SurfaceMove, board: Board, local: inout LocalParts) -> StageAction? { nil }
}
