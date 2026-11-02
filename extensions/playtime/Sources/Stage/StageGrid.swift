import Foundation
import SidefolkExtensionKit

// Cells up to 8 × 8 (GameGridView): an X, an O, a disc, a letter or a symbol; the winning line highlighted. Marks played on a
// board sit in the cells of one card; cards that are their own pictures lie straight on the scene.
extension BoardDrawing {
    func grid(rows: Int, columns: Int, cells: [Cell], locked: Bool, numpad: Bool) -> PartBlock {
        let onBoard = !cells.contains { $0.mark == "card_back" || $0.mark == "symbol" }
        let gap = 8.0, frame = onBoard ? 10.0 : 0
        let side = min(76, (Self.inner - 2 * frame - Double(columns - 1) * gap) / Double(columns))
        let w = Double(columns) * side + Double(columns - 1) * gap + 2 * frame
        let h = Double(rows) * side + Double(rows - 1) * gap + 2 * frame
        let x = (Self.inner - w) / 2
        var nodes: [Node] = []
        if onBoard { nodes.append(Node.gameCard(corner: 20, x: x, w: w, h: h).id("grid.card")) }
        for r in 0..<rows {
            for c in 0..<columns {
                let i = r * columns + c
                guard i < cells.count else { continue }
                nodes.append(cell(cells[i], r: r, c: c, index: i, side: side, locked: locked, numpad: numpad, columns: columns)
                    .at(x + frame + Double(c) * (side + gap), frame + Double(r) * (side + gap)))
            }
        }
        if !locked {
            if numpad {
                for n in 1...9 {
                    let at = (2 - (n - 1) / 3) * 3 + (n - 1) % 3
                    guard at < cells.count, cells[at].state != "disabled" else { continue }
                    // A digit on a taken cell still goes to the game, which says it's taken.
                    let open = cells[at].mark == "empty"
                    keys.append(StageKey(key: "\(n)", id: "numpad_\(n)", area: open ? "cell" : nil, value: open ? "\(at / 3),\(at % 3)" : nil))
                }
            }
            arrowKeys()
            if ctx.local.cursor != nil {
                keys.append(StageKey(key: "return", id: "cursor_return"))
                keys.append(StageKey(key: "space", id: "cursor_space"))
            }
        }
        return PartBlock(.box("grid", w: Self.inner, h: h) { nodes }, height: h)
    }

    func arrowKeys() {
        for arrow in ["left", "right", "up", "down"] { keys.append(StageKey(key: arrow, id: "arrow_\(arrow)")) }
    }

    private func cell(_ cell: Cell, r: Int, c: Int, index: Int, side: Double, locked: Bool, numpad: Bool, columns: Int) -> Node {
        let id = "cell.\(r).\(c)"
        let open = !locked && cell.state != "disabled" && (cell.mark == "empty" || cell.mark == "card_back")
        var inner: [Node] = []
        // A white tile raised on its lip; a card face down is its own picture, so it gets no tile.
        if cell.mark != "card_back" {
            // A winning line is the person's win or loss by whose marks it holds.
            let fill: Color = cell.state == "win" ? (cell.companion ? Paint.lostSoft : Color.win.tuned(alpha: 0.35))
                : cell.state == "hint" ? Paint.clear("#FFC93C", 0.35) : Paint.inset
            inner.append(Node.rect(fill: Paint.lip, corner: 12).id(id + ".lip").at(0, 3).size(side, side))
            inner.append(Node.rect(fill: Paint.inset, corner: 12).id(id + ".base").size(side, side))
            inner.append(Node.rect(fill: fill, stroke: Paint.edge, lineWidth: 1, corner: 12).id(id + ".face").size(side, side))
        }
        inner.append(mark(cell, id: id, side: side))
        if numpad, open {
            // The digit that plays here, as on a number pad (7 8 9 on top).
            inner.append(keyCap("\((2 - r) * 3 + c + 1)").at(5, 5))
        }
        if ctx.local.cursor == index, !locked {
            inner.append(Node.rect(stroke: .accent, lineWidth: 2.5, corner: 12).id(id + ".cursor").size(side, side))
        }
        arrival(cell, r: r, c: c, target: Self.markId(id, cell), index: index)
        var node = Node.box(id, w: side, h: side) { inner }
            .area("cell", value: "\(r),\(c)", label: cell.label ?? "\(r + 1), \(c + 1)", disabled: !open, hover: nil, press: AreaLook(scale: 0.97), sound: "sounds/tap.wav")
        if cell.state == "disabled" { node = node.opacity(0.4) }
        return node
    }

    static func keyCapWidth(_ text: String) -> Double { max(16, TextFit.width(text, size: 10, weight: "bold")) + 4 }

    /// A key's letter in a small outlined cap.
    func keyCap(_ text: String, light: Bool = false) -> Node {
        let w = Self.keyCapWidth(text)
        return Node.box(w: w, h: 16) {
            Node.rect(stroke: light ? Paint.clear("#FFFFFF", 0.6) : .line, lineWidth: 1, corner: 4).size(w, 16)
            Node.words(text, size: 10, weight: "bold", color: light ? Paint.clear("#FFFFFF", 0.9) : .inkMuted, align: "center", w: w, h: 16)
        }
    }

    /// By what it shows: a card turned over is another kind of node, and a layer doesn't change kind under one id.
    private static func markId(_ id: String, _ cell: Cell) -> String { id + ".mark." + cell.mark }

    private func mark(_ cell: Cell, id: String, side: Double) -> Node {
        let color: Color = cell.companion ? .accent : .ink
        let target = Self.markId(id, cell)
        switch cell.mark {
        // Chunky marks lit from above, with a small drop shadow: pieces on a board rather than strokes.
        case "x":
            return Node.path(Self.crossPath(side), fill: color).gradient([lit(color, 0.75), color]).id(target).size(side, side).shadow(shade(color), radius: 0, dx: 0, dy: 3)
        case "o":
            return Node.path(Self.ringPath(side), fill: color).gradient([lit(color, 0.7), color]).id(target).size(side, side).shadow(shade(color), radius: 0, dx: 0, dy: 3)
        case "disc":
            let inset = side * 0.14
            return Node.ellipse(fill: cell.value.map(Color.hex) ?? color).id(target).at(inset, inset).size(side - 2 * inset, side - 2 * inset)
        case "letter":
            return Node.words(cell.value ?? "", size: side * 0.45, weight: "bold", color: color, align: "center", w: side, h: side).id(target)
        case "symbol":
            if let face = Self.faceArt(cell.value) {
                // The thing itself, in its own colours; a pair the companion found wears its face.
                let s = side * 0.66
                return Node.box(target, x: (side - s) / 2, y: (side - s) / 2, w: s, h: s) {
                    Node.art(face, w: s, h: s)
                    if cell.companion { Node.faceDisc(x: s - side * 0.12, y: s - side * 0.14, side: side * 0.26, ring: 1.5) }
                }
            }
            let s = side * 0.4 * 1.3
            return Node.symbol(cell.value ?? "questionmark", color: color).symbolLook().id(target).at((side - s) / 2, (side - s) / 2).size(s, s)
        case "card_back":
            let s = side * 0.98
            return Node.image("art/game-card-back.webp").id(target).at((side - s) / 2, (side - s) / 2).size(s, s).shadow(Paint.clear("#000000", 0.18), radius: 2, dx: 0, dy: 2)
        case "stick":
            return Node.box(target, w: side, h: side) { candyStick(color: Paint.coral, x: (side - side * 0.16) / 2, y: side * 0.12, w: side * 0.16, h: side * 0.76) }
        case "cup":
            let h = side * 0.62
            return Node.image("art/game-cup.png").id(target).at((side - h) / 2, (side - h) / 2).size(h, h)
        default:
            return Node.box(target, w: 1, h: 1) {}
        }
    }

    private func shade(_ color: Color) -> Color { lit(color, 0.35) }
    private func lit(_ color: Color, _ alpha: Double) -> Color { (color.json as? String) == "accent" ? Color.accent.tuned(alpha: alpha) : Color.ink.tuned(alpha: alpha) }

    /// The X as the panel's heaviest xmark drew it: two round-ended bars, 0.38 of the cell across and a tenth of it thick. A path, so it can be lit from above.
    static func crossPath(_ side: Double) -> String {
        let c = side / 2, r = side * 0.049, l = (side * 0.19 - r) * 2.0.squareRoot(), k = r * 0.5523, turn = 0.5.squareRoot()
        func bar(_ sign: Double) -> String {
            // A capsule along the bar (u) and across it (v), turned 45° one way or the other.
            func p(_ u: Double, _ v: Double) -> String { "\(c + (u - sign * v) * turn) \(c + (sign * u + v) * turn)" }
            return "M \(p(-l, -r)) L \(p(l, -r)) C \(p(l + k, -r)) \(p(l + r, -k)) \(p(l + r, 0)) C \(p(l + r, k)) \(p(l + k, r)) \(p(l, r)) "
                + "L \(p(-l, r)) C \(p(-l - k, r)) \(p(-l - r, k)) \(p(-l - r, 0)) C \(p(-l - r, -k)) \(p(-l - k, -r)) \(p(-l, -r)) Z "
        }
        return bar(1) + bar(-1)
    }

    /// The O: a ring whose outer edge stands 0.22 of the cell in, 0.11 of it thick, the inner circle wound the other way so it stays a hole.
    static func ringPath(_ side: Double) -> String {
        let c = side / 2, outer = side * 0.28, inner = outer - side * 0.11
        func circle(_ r: Double, clockwise: Bool) -> String {
            let k = r * 0.5523, s = clockwise ? 1.0 : -1.0
            return "M \(c) \(c - r) C \(c + s * k) \(c - r) \(c + s * r) \(c - k) \(c + s * r) \(c) C \(c + s * r) \(c + k) \(c + s * k) \(c + r) \(c) \(c + r) "
                + "C \(c - s * k) \(c + r) \(c - s * r) \(c + k) \(c - s * r) \(c) C \(c - s * r) \(c - k) \(c - s * k) \(c - r) \(c) \(c - r) Z "
        }
        return circle(outer, clockwise: true) + circle(inner, clockwise: false)
    }

    /// How a mark arrives, when what the cell shows changes: stamped, flipped, dropped or popped in. Spring, 320 ms.
    private func arrival(_ cell: Cell, r: Int, c: Int, target: String, index: Int) {
        guard ctx.fresh, let how = cell.animate else { return }
        let before = ctx.previous?.gridPart?.cells[safe: index]
        guard before?.mark != cell.mark || before?.value != cell.value else { return }
        let frames: [[String: Double]]
        switch how {
        case "stamp": frames = [["t": 0, "scale": 1.5, "opacity": 0.2], ["t": 1, "scale": 1, "opacity": 1]]
        case "pop": frames = [["t": 0, "scale": 0.4, "opacity": 0.2], ["t": 1, "scale": 1, "opacity": 1]]
        case "flip": frames = [["t": 0, "sx": 0.02, "opacity": 0.2], ["t": 1, "sx": 1, "opacity": 1]]
        default: frames = [["t": 0, "opacity": 0.2], ["t": 1, "opacity": 1]]
        }
        anims.append(.keys(target, frames, ms: 320, ease: "spring"))
    }

    /// A card's face for the SF Symbol a board names: the object itself, in colour.
    static func faceArt(_ symbol: String?) -> String? {
        switch symbol {
        case "moon.fill", "moon": "art/game-face-moon.webp"
        case "leaf.fill", "leaf": "art/game-face-leaf.webp"
        case "anchor": "art/game-face-anchor.webp"
        case "star.fill", "star": "art/game-face-star.webp"
        case "heart.fill", "heart": "art/game-face-heart.webp"
        case "sun.max.fill", "sun.max": "art/game-face-sun.webp"
        case "cloud.fill", "cloud": "art/game-face-cloud.webp"
        case "camera.macro": "art/game-face-flower.webp"
        case "fish.fill", "fish": "art/game-face-fish.webp"
        case "bell.fill", "bell": "art/game-face-bell.webp"
        case "key.fill", "key": "art/game-face-key.webp"
        case "drop.fill", "drop": "art/game-face-drop.webp"
        default: nil
        }
    }

    /// A candy stick: its colour with white stripes across, lit from the left, a small shadow.
    func candyStick(color: Color, x: Double, y: Double, w: Double, h: Double) -> Node {
        var stripes = ""
        var at = -w
        while at < h {
            stripes += "M 0 \(at + w) L \(w) \(at) L \(w) \(at + 3.5) L 0 \(at + w + 3.5) Z "
            at += 9
        }
        return Node.box(x: x, y: y, w: w, h: h) {
            Node.box(w: w, h: h) {
                Node.rect(fill: color).size(w, h)
                Node.path(stripes, fill: Paint.clear("#FFFFFF", 0.55)).size(w, h)
                Node.rect().gradient([Paint.clear("#FFFFFF", 0.45), Paint.clear("#FFFFFF", 0), Paint.clear("#000000", 0.15)], from: (0, 0.5), to: (1, 0.5)).size(w, h)
            }.corner(w / 2).clip()
        }.shadow(Paint.clear("#000000", 0.18), radius: 1.5, dx: 1, dy: 2)
    }
}

extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}
