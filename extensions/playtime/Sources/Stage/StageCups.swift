import SidefolkExtensionKit

// Which Cup?'s cups (CupsView). Not moved yet: its group fills this in from the panel's PadsCupsReflexViews.swift.
extension BoardDrawing {
    func cupsPart(count: Int, hide: Int?, swaps: [[Int]], swapMs: Int, picked: Int?, revealed: Bool, gem: Int?, locked: Bool) -> PartBlock { unmoved("cups") }
    var cupsFooter: String? { nil }
    var cupsStageWords: String? { nil }
    static func cupsMove(_ move: SurfaceMove, board: Board, local: inout LocalParts) -> StageAction? { nil }
}
