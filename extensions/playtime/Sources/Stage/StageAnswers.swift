import Foundation
import SidefolkExtensionKit

// Big answers (AnswerTile): a key cap, its words, and once answered ✓ or ✕ and whose pick it was. A pick is `.answer(i)`; its key cap's letter or 1–4 press it. A tile stays one
// size and in one place whatever it says: longer words shrink.
extension BoardDrawing {
    /// The letter on each tile's key cap: R, P and S for hands, A to D otherwise.
    static func keyCaps(_ tiles: [Tile]) -> [String] {
        tiles.enumerated().map { i, tile in
            if let key = tile.key { return key.uppercased() }
            switch tile.art {
            case "rock": return "R"
            case "paper": return "P"
            case "scissors": return "S"
            default: return ["A", "B", "C", "D"][min(i, 3)]
            }
        }
    }

    /// The keys that press the tiles, while they can be pressed.
    func answerKeys(_ tiles: [Tile], locked: Bool) {
        guard !locked else { return }
        for (i, cap) in Self.keyCaps(tiles).enumerated() where tiles[i].state != .faded {
            keys.append(StageKey(key: cap == "?" ? "?" : cap.lowercased(), id: "answer_\(i)", area: "answer", value: "\(i)"))
            keys.append(StageKey(key: "\(i + 1)", id: "answer_d\(i)", area: "answer", value: "\(i)"))
        }
    }

    func answers(_ tiles: [Tile], layout: TileLayout, locked: Bool) -> PartBlock {
        let caps = Self.keyCaps(tiles)
        let columns = layout == .grid ? 2 : layout == .row ? max(tiles.count, 1) : 1
        let gap = 10.0, h = 88.0, w = (Self.inner - gap * Double(columns - 1)) / Double(columns)
        let rows = (tiles.count + columns - 1) / max(columns, 1)
        answerKeys(tiles, locked: locked)
        return PartBlock(.box("answers", w: Self.inner, h: Double(rows) * (h + gap) - gap) {
            for (i, tile) in tiles.enumerated() {
                answerCard(tile, index: i, cap: caps[i], locked: locked, w: w, h: h).at(Double(i % columns) * (w + gap), Double(i / columns) * (h + gap))
            }
        }, height: Double(rows) * (h + gap) - gap)
    }

    /// One large answer: its key cap on top, a symbol beside it if it has one, its words under them. `primary` is the navy one, for the answer that ends things.
    func answerCard(_ tile: Tile, index i: Int, cap: String, locked: Bool, w: Double, h: Double, symbol: String? = nil, primary: Bool = false) -> Node {
        let pending = ctx.pendingAnswer == i
        let open = !locked && tile.state != .faded
        let solid = primary && tile.state != .faded
        let id = "tile.\(i)"
        let ink = solid ? Paint.onAction : Paint.ink
        let capW = 26.0, whole = symbol == nil ? capW : capW + 8 + 20, top = (h - 26 - 6 - 24) / 2
        var body = Node.box(id + ".body", w: w, h: h) {
            Node.rect(fill: solid ? Paint.action : Paint.card, corner: 16).id(id + ".face").size(w, h).shadow(Paint.clear("#4A2E12", 0.16), radius: 4, dx: 0, dy: 2)
            Node.rect(stroke: pending ? Paint.action : solid ? Paint.action : Paint.edge, lineWidth: pending ? 3 : 1, corner: 16).id(id + ".edge").size(w, h)
            Node.rect(fill: solid ? Paint.onAction : Paint.lilac, corner: 7).id(id + ".cap").at((w - whole) / 2, top).size(capW, 26)
            Node.words(cap, size: 14, weight: "black", color: solid ? Paint.action : Paint.ink, align: "center", x: (w - whole) / 2, y: top, w: capW, h: 26)
            if let symbol { Node.symbol(symbol, color: ink).symbolLook(weight: "bold").at((w - whole) / 2 + capW + 8, top + 3).size(20, 20) }
            Node.words(tile.label, size: 17, weight: "heavy", color: ink, align: "center", minScale: 0.55, x: 8, y: top + 26 + 6, w: w - 16, h: 24).id(id + ".words")
        }.scale(pending ? 0.97 : 1)
        if !open { body = body.opacity(tile.state == .faded ? 0.35 : locked && !pending ? 0.5 : 1) }
        return Node.box(id, w: w, h: h) { body }.area("answer", value: "\(i)", label: "\(cap), \(tile.label)", disabled: !open, hover: AreaLook(scale: 1.025), press: AreaLook(scale: 0.97, dy: 1), sound: "sounds/tap.wav")
    }
}
