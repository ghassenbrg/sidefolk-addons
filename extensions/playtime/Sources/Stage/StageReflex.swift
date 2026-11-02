import SidefolkExtensionKit

// Quick Paws' reflex button (ReflexView). Not moved yet: its group fills this in from the panel's PadsCupsReflexViews.swift.
extension BoardDrawing {
    func reflexPart(afterMs: Int?, windowMs: Int, wait: String, go: String, early: String, shows: String?, keys: [String]?) -> PartBlock { unmoved("reflex") }
    var reflexFooter: String? { nil }
    static func reflexMove(_ move: SurfaceMove, board: Board, local: inout LocalParts) -> StageAction? { nil }
}
