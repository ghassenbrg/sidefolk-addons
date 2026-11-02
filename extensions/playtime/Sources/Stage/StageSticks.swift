import SidefolkExtensionKit

// Last Stick's row (SticksView). Not moved yet: its group fills this in from the panel's NumberSticksViews.swift (`candyStick` is in StageGrid).
extension BoardDrawing {
    func sticksPart(total: Int, left: Int, take: Int, groups: [[Int]], hint: [Int], taken: Int, takenBy: String?, locked: Bool) -> PartBlock { unmoved("sticks") }
    var sticksFooter: String? { nil }
    static func sticksMove(_ move: SurfaceMove, board: Board, local: inout LocalParts) -> StageAction? { nil }
}
