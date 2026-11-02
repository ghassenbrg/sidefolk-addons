import Foundation
import SidefolkExtensionKit

// Big answers (AnswerTile): a key cap, words or a picture, and once answered, ✓ or ✕ and whose pick it was. A pick is
// `.answer(i)`; A–D or the tile's own key press it, and 1–4 too.
extension BoardDrawing {
    /// The letter on each tile's key cap: R, P and S for hands, A to D otherwise.
    static func keyCaps(_ tiles: [Tile]) -> [String] {
        tiles.enumerated().map { i, tile in
            if let key = tile.key { return key }
            switch tile.art {
            case "rock": return "R"
            case "paper": return "P"
            case "scissors": return "S"
            default: return ["A", "B", "C", "D"][min(i, 3)]
            }
        }
    }

    func answers(_ tiles: [Tile], layout: TileLayout, locked: Bool) -> PartBlock {
        let caps = Self.keyCaps(tiles)
        let columns = layout == .grid ? 2 : layout == .row ? max(tiles.count, 1) : 1
        let gapX = 10.0, gapY = layout == .column ? 8.0 : 10.0
        let w = (Self.inner - gapX * Double(columns - 1)) / Double(columns)
        // A row's tiles stand as tall as the tallest.
        func labelHeight(_ t: Tile) -> Double { TextFit.height(t.label, size: t.art == nil ? 15 : 13, weight: "semibold", width: w - 20, lines: 3) }
        var rowHeights: [Double] = []
        for start in stride(from: 0, to: tiles.count, by: columns) {
            let slice = tiles[start..<min(start + columns, tiles.count)]
            rowHeights.append(slice.map { t in max(t.art == nil ? 70 : 112, 20 + 20 + 6 + (t.art == nil ? 0 : 58) + labelHeight(t)) }.max() ?? 70)
        }
        var nodes: [Node] = []
        var y = 0.0
        for (r, h) in rowHeights.enumerated() {
            for c in 0..<columns where r * columns + c < tiles.count {
                let i = r * columns + c
                nodes.append(tile(tiles[i], index: i, cap: caps[i], locked: locked, w: w, h: h).at(Double(c) * (w + gapX), y))
            }
            y += h + 4 + gapY
        }
        let height = y - gapY
        if !locked {
            for (i, cap) in caps.enumerated() where tiles[i].state != .faded {
                keys.append(StageKey(key: cap.lowercased(), id: "answer_\(i)", area: "answer", value: "\(i)"))
                keys.append(StageKey(key: "\(i + 1)", id: "answer_d\(i)", area: "answer", value: "\(i)"))
            }
        }
        return PartBlock(.box("answers", w: Self.inner, h: height) { nodes }, height: height)
    }

    private func tile(_ tile: Tile, index i: Int, cap: String, locked: Bool, w: Double, h: Double) -> Node {
        let pending = ctx.pendingAnswer == i
        let verdict = pending ? nil : Verdict(tile: tile.state, locked: locked)
        let fill = verdict?.fill ?? Paint.card
        let ink = verdict?.ink ?? .ink
        let outlined = tile.state == .picked || pending
        let stroke = outlined ? Color.ink.tuned(alpha: 0.7) : verdict == .loss ? Paint.lostEdge : Paint.edge
        let scale = pending ? 0.96 : tile.state == .right ? 1.03 : 1
        let id = "tile.\(i)"
        let open = !locked && tile.state != .faded
        // A wrong answer shakes its head, when it first shows wrong.
        if ctx.fresh, tile.state == .wrong, ctx.previous?.answersPart?.tiles[safe: i]?.state != .wrong {
            let frames = (0...12).map { n -> [String: Double] in
                let a = Double(n) / 12
                return ["t": a, "x": 7 * sin(a * .pi * 6) * (1 - a)]
            }
            anims.append(.keys(id + ".body", frames, ms: 400))
        }
        let lipColor = verdict.map { v -> Color in
            switch v {
            case .win: Color.win.tuned(brightness: -0.1)
            case .loss: .adaptive(light: "#DBC2AC", dark: "#3A2C22")
            case .draw: Color.surfaceRaised.tuned(brightness: -0.1)
            }
        } ?? Paint.lip
        var body = Node.box(id + ".body", w: w, h: h) {
            Node.rect(fill: lipColor, corner: 16).id(id + ".lip").at(0, 4).size(w, h)
            Node.rect(fill: fill, stroke: stroke, lineWidth: outlined || verdict == .loss ? 2 : 1, corner: 16).id(id + ".face").size(w, h)
            // The key cap.
            Node.rect(stroke: tuned(ink, 0.35), lineWidth: 1, corner: 5).id(id + ".cap").at(10, 10).size(20, 20)
            Node.words(cap, size: 11, weight: "bold", color: tuned(ink, 0.8), align: "center", x: 10, y: 10, w: 20, h: 20)
            if let art = tile.art {
                TossArt.padded("art/hand-\(art).png", side: 52, exported: 58, x: (w - 52) / 2, y: 36)
            }
            Node.words(tile.label, size: tile.art == nil ? 15 : 13, weight: "semibold", color: ink, align: "center", lines: 3, minScale: 0.8,
                       x: 10, y: tile.art == nil ? 36 : 92, w: w - 20, h: h - (tile.art == nil ? 46 : 100))
            if tile.companion {
                Node.faceDisc(x: w - 10 - (verdict == nil ? 22 : 48), y: 10, side: 22).shadow(Paint.clear("#000000", 0.2), radius: 2, dx: 0, dy: 1)
            }
            if let verdict {
                Node.symbol(verdict.symbol, color: verdict == .win ? Paint.white : verdict.color).symbolLook(weight: "bold").at(w - 10 - 22, 10).size(22, 22)
            }
        }.scale(scale)
        if tile.state == .faded { body = body.opacity(0.35) }
        var words = "\(cap), \(tile.label)"
        switch tile.state {
        case .right: words += ", " + L("right")
        case .wrong: words += ", " + L("wrong")
        case .picked: words += ", " + L("your pick")
        default: break
        }
        if tile.companion { words += ", " + L("{name}'s pick", ["name": "{companion}"]) }
        return Node.box(id, w: w, h: h + 4) { body }.area("answer", value: "\(i)", label: words, disabled: !open, hover: AreaLook(scale: 1.02), press: AreaLook(scale: 0.98), sound: "sounds/tap.wav")
    }

    private func tuned(_ color: Color, _ alpha: Double) -> Color {
        (color.json as? String) == "ink" ? Color.ink.tuned(alpha: alpha) : Paint.clear("#FFFFFF", alpha)
    }
}
