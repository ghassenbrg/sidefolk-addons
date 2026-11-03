import Foundation
import SidefolkExtensionKit

// A board of cells, in two kinds. Marks (Tic-tac-toe): large porcelain cells on a navy plate standing in the scene, the digit that plays each one in its corner. Cards
// (Memory Pairs): a felt tray filling the board's room, each card turning over where it lies. Everything has its place for the whole game: the part is as tall as the board's
// room, and what comes later (a line, a badge, a button) has its room kept.
extension BoardDrawing {
    func grid(rows: Int, columns: Int, cells: [Cell], locked: Bool, numpad: Bool) -> PartBlock {
        if !locked {
            if numpad {
                for n in 1...9 {
                    let at = n - 1
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
        let cards = cells.contains { $0.mark == "card_back" || $0.mark == "symbol" }
        return cards ? cardTray(rows: rows, columns: columns, cells: cells, locked: locked) : marksBoard(rows: rows, columns: columns, cells: cells, locked: locked, numpad: numpad)
    }

    func arrowKeys() {
        for arrow in ["left", "right", "up", "down"] { keys.append(StageKey(key: arrow, id: "arrow_\(arrow)")) }
    }

    /// A step held at its first values until its moment, then played. One path from the start, so nothing shows its end early.
    func heldKeys(_ target: String, _ frames: [[String: Double]], delayMs: Double, ms: Double, ease: String = "out") {
        guard delayMs > 0, let first = frames.first else {
            anims.append(.keys(target, frames, ms: ms, ease: ease))
            return
        }
        let total = delayMs + ms
        var keys = [first.merging(["t": 0]) { $1 }, first.merging(["t": delayMs / total]) { $1 }]
        for frame in frames.dropFirst() { keys.append(frame.merging(["t": (delayMs + (frame["t"] ?? 1) * ms) / total]) { $1 }) }
        anims.append(.keys(target, keys, ms: total, ease: ease))
    }

    // MARK: Marks

    /// The plate round the cells, and the groove between them. Its bottom edge stands on the alcove's floor, whatever the room above it.
    private static let plateEdge = 5.0, cellGap = 4.0, largestCell = 80.0

    private func marksBoard(rows: Int, columns: Int, cells: [Cell], locked: Bool, numpad: Bool) -> PartBlock {
        let gap = Self.cellGap, edge = Self.plateEdge
        let side = min(Self.largestCell, (playRoom - 2 * edge - Double(rows - 1) * gap) / Double(rows))
        let w = Double(columns) * side + Double(columns - 1) * gap
        let h = Double(rows) * side + Double(rows - 1) * gap
        let x = (Self.inner - w) / 2, y = playRoom - h - edge - 8
        let filled = !cells.contains { $0.mark == "empty" }
        let line = cells.indices.filter { cells[$0].state == "win" }
        func at(_ i: Int) -> (x: Double, y: Double) { (x + Double(i % columns) * (side + gap), y + Double(i / columns) * (side + gap)) }
        // The game is settled, on the board that says so rather than in its build-up: what didn't decide it steps back.
        let settled = !ctx.buildUp && (!line.isEmpty || (filled && locked))
        // A new game after the last: its pieces go, one after another, and nothing can be pressed until they have.
        let previous = ctx.previous?.gridPart?.cells
        let leaving = ctx.fresh ? cells.indices.filter { cells[$0].mark == "empty" && Self.pieceArt(previous?[safe: $0]?.mark) != nil } : []
        if !leaving.isEmpty { anims.append(Anim.sequence([.wait(ms: Double(leaving.count) * Self.leavingStep + 320)]).blocksInput()) }
        return PartBlock(.box("grid", w: Self.inner, h: playRoom) {
            Node.rect(fill: Paint.plate, corner: 18).id("grid.plate").at(x - edge, y - edge).size(w + 2 * edge, h + 2 * edge).shadow(Paint.clear("#3A2A55", 0.28), radius: 7, dx: 0, dy: 4)
            for i in cells.indices {
                self.markCell(cells[i], index: i, columns: columns, side: side, locked: locked, numpad: numpad, stepsBack: settled && cells[i].state != "win",
                              leavingAfter: leaving.firstIndex(of: i).map { Double($0) * Self.leavingStep + 80 }, was: previous?[safe: i]?.mark).at(at(i).x, at(i).y)
            }
            if let first = line.first, let last = line.last, line.count > 1, !ctx.buildUp {
                self.winLine(from: (at(first).x + side / 2, at(first).y + side / 2), to: (at(last).x + side / 2, at(last).y + side / 2), side: side, companion: cells[first].companion)
            }
        }, height: playRoom)
    }

    private static let leavingStep = 70.0

    /// A line through three in a row, drawn from end to end as the verdict shows, the pieces on it hopping after: the person's win or loss, by whose pieces it holds.
    private func winLine(from: (Double, Double), to: (Double, Double), side: Double, companion: Bool) -> Node {
        let dx = to.0 - from.0, dy = to.1 - from.1, length = (dx * dx + dy * dy).squareRoot()
        let over = side * 0.34, ux = dx / length, uy = dy / length, thick = 9.0
        if ctx.fresh { heldKeys("grid.line", [["t": 0, "sx": 0.01], ["t": 1, "sx": 1]], delayMs: 60, ms: 340, ease: "in_out") }
        return Node.capsule(fill: companion ? Color.loss : Color.win, stroke: Paint.white, lineWidth: 1.5).id("grid.line")
            .at(from.0 - ux * over, from.1 - uy * over - thick / 2).size(length + 2 * over, thick).anchor(0, 0.5).rotate(atan2(dy, dx) * 180 / .pi)
            .shadow(Paint.clear("#000000", 0.2), radius: 2, dx: 0, dy: 1)
    }

    private func markCell(_ cell: Cell, index: Int, columns: Int, side: Double, locked: Bool, numpad: Bool, stepsBack: Bool, leavingAfter: Double?, was: String?) -> Node {
        let r = index / columns, c = index % columns, id = "cell.\(r).\(c)"
        let open = !locked && cell.state != "disabled" && cell.mark == "empty"
        let piece = Self.pieceArt(cell.mark), s = side * 0.72, inset = (side - s) / 2
        let faceH = side - 2.5
        // What would land here, shown faintly on hover: whose turn it is decides, on a board of two people.
        let next = Self.pieceArt(board.turn == "companion" ? "o" : "x")
        var inner: [Node] = [
            Node.rect(fill: Paint.lip, corner: 14).id(id + ".lip").at(0, 2.5).size(side, faceH),
            Node.rect(fill: Paint.card, stroke: Paint.edge, lineWidth: 1, corner: 14).id(id + ".face").size(side, faceH),
            // The cell of a line and the cell a hint points to: each has its layer, so a colour comes and goes rather than appears.
            Node.rect(fill: cell.companion ? Paint.lostSoft : Color.win.tuned(alpha: 0.3), corner: 14).id(id + ".won").size(side, faceH).opacity(cell.state == "win" && !ctx.buildUp ? 1 : 0),
            Node.rect(fill: Paint.clear("#FFC93C", 0.4), corner: 14).id(id + ".hint").size(side, faceH).opacity(cell.state == "hint" ? 1 : 0),
            // An empty cell rests while nothing can be played: whose turn it is shows on the board too.
            Node.rect(fill: Paint.inset, corner: 14).id(id + ".rest").size(side, faceH).opacity(cell.mark == "empty" && locked ? 0.75 : 0),
        ]
        if numpad {
            // The digit that plays here, as on a number pad (7 8 9 on top): quiet, in the corner, and only on a cell that can be played now.
            inner.append(Node.words("\(r * 3 + c + 1)", size: 12, weight: "bold", color: Paint.inkSoft, align: "center", x: side - 23, y: 5, w: 18, h: 18).id(id + ".digit").opacity(open ? 1 : 0))
        }
        if open, let next { inner.append(Node.image(next).id(id + ".ghost").at(inset, inset).size(s, s).opacity(0)) }
        if let piece {
            inner.append(Node.image(piece).id(Self.markId(id, cell)).at(inset, inset).size(s, s).opacity(stepsBack ? 0.38 : 1))
        } else if let leavingAfter, let was, let gone = Self.pieceArt(was) {
            // The piece of the last game, going.
            let target = id + ".mark." + was
            inner.append(Node.image(gone).id(target).at(inset, inset).size(s, s).opacity(0))
            heldKeys(target, [["t": 0, "scale": 1, "opacity": 1], ["t": 0.3, "scale": 1.08, "opacity": 1], ["t": 1, "scale": 0.5, "opacity": 0]], delayMs: leavingAfter, ms: 240, ease: "in")
        }
        if ctx.local.cursor == index, !locked {
            // Inside the cell: its plate is navy too.
            inner.append(Node.rect(stroke: Paint.action, lineWidth: 3, corner: 11).id(id + ".cursor").at(3, 3).size(side - 6, faceH - 6))
        }
        markArrives(cell, id: id, index: index, restsAt: inset)
        if cell.state == "win", ctx.fresh, !ctx.buildUp {
            heldKeys(Self.markId(id, cell), [["t": 0, "scale": 1], ["t": 0.45, "scale": 1.16], ["t": 1, "scale": 1]], delayMs: 200 + Double(index) * 40, ms: 320, ease: "in_out")
        }
        if cell.state == "hint", ctx.fresh {
            anims.append(Anim.keys(id + ".hint", [["t": 0, "opacity": 1], ["t": 0.5, "opacity": 0.35], ["t": 1, "opacity": 1]], ms: 700, ease: "in_out").repeating(2))
        }
        return Node.box(id, w: side, h: side) { inner }
            .area("cell", value: "\(r),\(c)", label: cell.label ?? "\(r + 1), \(c + 1)", disabled: !open, hover: open ? AreaLook(scale: 1.02) : nil, press: AreaLook(scale: 0.97),
                  looks: open && next != nil ? [id + ".ghost": AreaLook(opacity: 0.32)] : [:], sound: "sounds/tap.wav")
    }

    /// A piece played: the person's is pressed in at once; the companion's comes down from over the board, after its beat of thought, and lands with a small sound. Once: a
    /// piece that landed in a verdict's build-up is at rest in the verdict.
    private func markArrives(_ cell: Cell, id: String, index: Int, restsAt y: Double) {
        guard ctx.fresh, !ctx.local.builtUp, cell.animate != nil, Self.pieceArt(cell.mark) != nil, ctx.previous?.gridPart?.cells[safe: index]?.mark != cell.mark else { return }
        let target = Self.markId(id, cell)
        if cell.companion {
            anims.append(.keys(target, [["t": 0, "y": y - 26, "scale": 1.25, "opacity": 0], ["t": 0.35, "opacity": 1], ["t": 0.72, "y": y, "scale": 1], ["t": 0.86, "y": y - 3, "scale": 1.02], ["t": 1, "y": y, "scale": 1]], ms: 420, ease: "in"))
            anims.append(.sequence([.wait(ms: 300), .sound("sounds/stamp.wav")]))
        } else {
            anims.append(.keys(target, [["t": 0, "scale": 1.4, "opacity": 0.2], ["t": 1, "scale": 1, "opacity": 1]], ms: 240, ease: "out"))
        }
    }

    private static func pieceArt(_ mark: String?) -> String? {
        switch mark {
        case "x": "art/piece-x.webp"
        case "o": "art/piece-o.webp"
        default: nil
        }
    }

    /// By what it shows: a card turned over is another kind of node, and a layer doesn't change kind under one id.
    private static func markId(_ id: String, _ cell: Cell) -> String { id + ".mark." + cell.mark }

    // MARK: Cards

    /// The back is a little taller than it is wide.
    private static let trayPad = 12.0, cardGap = 8.0, cardRatio = 0.975

    /// A felt tray filling the board's room. Face down, face up, and two kinds of pair: the person's
    /// and the other side's, each with a colour and a face of its own, so they read apart at a glance.
    private func cardTray(rows: Int, columns: Int, cells: [Cell], locked: Bool) -> PartBlock {
        let trayH = playRoom, trayW = Self.inner
        let h = (trayH - 2 * Self.trayPad - Double(rows - 1) * Self.cardGap) / Double(rows)
        let w = min(h * Self.cardRatio, (trayW - 2 * Self.trayPad - Double(columns - 1) * Self.cardGap) / Double(columns))
        let gapX = columns > 1 ? min(12, (trayW - 2 * Self.trayPad - Double(columns) * w) / Double(columns - 1)) : 0
        let x = (trayW - Double(columns) * w - Double(columns - 1) * gapX) / 2
        return PartBlock(.box("grid", w: Self.inner, h: playRoom) {
            Node.felt("grid.tray", w: trayW, h: trayH)
            for i in cells.indices {
                self.card(cells[i], index: i, columns: columns, w: w, h: h, locked: locked, cells: cells)
                    .at(x + Double(i % columns) * (w + gapX), Self.trayPad + Double(i / columns) * (h + Self.cardGap))
            }
        }, height: playRoom)
    }

    private func card(_ cell: Cell, index: Int, columns: Int, w: Double, h: Double, locked: Bool, cells: [Cell]) -> Node {
        let r = index / columns, c = index % columns, id = "cell.\(r).\(c)"
        let open = !locked && cell.state != "disabled" && cell.mark == "card_back"
        let owned = cell.state == "win" || cell.state == "pair"
        let before = ctx.previous?.gridPart?.cells[safe: index]
        let backId = id + ".mark.card_back", faceId = id + ".mark.symbol"
        let turningUp = ctx.fresh && !ctx.local.builtUp && cell.mark == "symbol" && before?.mark == "card_back"
        let turningBack = ctx.fresh && cell.mark == "card_back" && before?.mark == "symbol"
        // The other side's card: it reaches for it first, so you see which, and then it turns.
        let reaches = turningUp && cell.companion && board.scorePart?.players == nil
        let delay = turningBack ? Double(index % 2) * 60 : reaches ? 300 : 0
        var inner: [Node] = []
        if cell.mark == "card_back" || turningUp {
            // Face down and out of reach: it rests while the other side plays.
            let resting = locked && (ctx.buildUp ? ctx.previous?.turn : board.turn) == "companion"
            inner.append(Node.image("art/game-card-back.webp", fit: "fill").id(backId).size(w, h).anchor(0.5, 0.5).shadow(Paint.clear("#3A2A55", 0.22), radius: 2, dx: 0, dy: 2).opacity(turningUp ? 0 : resting ? 0.8 : 1))
        }
        if cell.mark == "symbol" || turningBack {
            inner.append(cardFace(cell.mark == "symbol" ? cell : before ?? cell, id: faceId, owned: owned, w: w, h: h).opacity(turningBack ? 0 : 1))
        }
        if turningUp { turnOver(hide: backId, show: faceId, delayMs: delay, sound: true) }
        if turningBack { turnOver(hide: faceId, show: backId, delayMs: delay, sound: index % 8 == 0) }
        if reaches {
            inner.append(Node.rect(stroke: Paint.action, lineWidth: 3, corner: 12).id(id + ".reach").size(w, h).opacity(0))
            anims.append(.keys(id + ".reach", [["t": 0, "opacity": 0], ["t": 0.3, "opacity": 1], ["t": 0.72, "opacity": 1], ["t": 1, "opacity": 0]], ms: delay + 200, ease: "in_out"))
        }
        if ctx.local.cursor == index, !locked {
            inner.append(Node.rect(stroke: Paint.action, lineWidth: 3, corner: 12).id(id + ".cursor").size(w, h))
        }
        let rest = owned ? 0.97 : 1.0
        if cell.state == "win", ctx.fresh, !ctx.buildUp {
            // A pair found stands up, its finder's face arrives, and it lies a little lower for the rest of the game.
            anims.append(.keys(id, [["t": 0, "scale": 1], ["t": 0.4, "scale": 1.13], ["t": 1, "scale": rest]], ms: 420, ease: "in_out"))
            heldKeys(faceId + ".badge", [["t": 0, "scale": 0.1, "opacity": 0], ["t": 1, "scale": 1, "opacity": 1]], delayMs: 160, ms: 260, ease: "spring")
        } else if turningUp || turningBack {
            // Lifted as it turns, set down after.
            heldKeys(id, [["t": 0, "scale": rest], ["t": 0.5, "scale": 1.07], ["t": 1, "scale": rest]], delayMs: delay, ms: 340, ease: "in_out")
        }
        // Two that don't match: a small shake of the head, once they are both up and the verdict has come.
        if !ctx.buildUp, ctx.fresh, cell.mark == "symbol", !owned, cells.filter({ $0.mark == "symbol" && $0.state != "win" && $0.state != "pair" }).count == 2 {
            anims.append(.keys(id, [["t": 0, "rotate": 0], ["t": 0.25, "rotate": -3], ["t": 0.6, "rotate": 3], ["t": 1, "rotate": 0]], ms: 340, ease: "in_out"))
        }
        return Node.box(id, w: w, h: h) { inner }.anchor(0.5, 0.5).scale(rest)
            .area("cell", value: "\(r),\(c)", label: cell.label ?? "\(r + 1), \(c + 1)", disabled: !open, hover: open ? AreaLook(scale: 1.04) : nil, press: AreaLook(scale: 0.96))
    }

    /// A card turning over: one face narrows to nothing, the other opens from nothing. Held until its moment, a third of a second in all.
    private func turnOver(hide: String, show: String, delayMs: Double, sound: Bool) {
        let half = 160.0
        heldKeys(hide, [["t": 0, "sx": 1, "opacity": 1], ["t": 0.97, "sx": 0.03, "opacity": 1], ["t": 1, "sx": 0.03, "opacity": 0]], delayMs: delayMs, ms: half, ease: "in")
        heldKeys(show, [["t": 0, "sx": 0.03, "opacity": 0], ["t": 0.03, "sx": 0.03, "opacity": 1], ["t": 1, "sx": 1, "opacity": 1]], delayMs: delayMs + half, ms: half + 20, ease: "out")
        if sound { anims.append(.sequence([.wait(ms: delayMs), .sound("sounds/flip.wav")])) }
    }

    /// A card face up: the thing itself on porcelain. A pair found wears its finder's colour and its finder's face; a card the other side has just turned, its face.
    private func cardFace(_ cell: Cell, id: String, owned: Bool, w: Double, h: Double) -> Node {
        let fill: Color = !owned ? Paint.card : cell.companion ? Paint.pairTheirs : Paint.pairYours
        let edge: Color = !owned ? Paint.edge : cell.companion ? Paint.blue : Paint.sunLip
        let s = min(w, h) * 0.66, badge = 24.0
        let two = board.scorePart?.players
        return Node.box(id, w: w, h: h) {
            Node.rect(fill: Paint.lip, corner: 12).at(0, 2.5).size(w, h - 2.5)
            Node.rect(fill: fill, stroke: edge, lineWidth: owned ? 2 : 1, corner: 12).size(w, h - 2.5)
            if let face = Self.faceArt(cell.value) {
                Node.art(face, x: (w - s) / 2, y: (h - s) / 2 - 2, w: s, h: s)
            } else {
                Node.symbol(cell.value ?? "questionmark", color: Paint.ink).symbolLook().at((w - s) / 2, (h - s) / 2).size(s, s)
            }
            if owned || cell.companion {
                Node.box(id + ".badge", x: w - badge - 3, y: h - badge - 5, w: badge, h: badge) {
                    if let two {
                        self.initial(two[cell.companion ? 1 : 0], Paint.players[cell.companion ? 1 : 0]).at(-2, -2).scale(badge / 28)
                    } else if cell.companion {
                        Node.faceDisc(x: 0, y: 0, side: badge, ring: 1.5)
                    } else {
                        Node.person().size(badge, badge).corner(badge / 2).clip()
                        Node.ellipse(stroke: Paint.white, lineWidth: 1.5).at(0.75, 0.75).size(badge - 1.5, badge - 1.5)
                    }
                }
            }
        }.anchor(0.5, 0.5)
    }

    /// Who plays: at the start of a game only, in a place kept for it.
    static func keyCapWidth(_ text: String) -> Double { max(16, TextFit.width(text, size: 10, weight: "bold")) + 4 }

    /// A key's letter in a small outlined cap.
    func keyCap(_ text: String, light: Bool = false) -> Node {
        let w = Self.keyCapWidth(text)
        return Node.box(w: w, h: 16) {
            Node.rect(stroke: light ? Paint.clear("#FFFFFF", 0.6) : .line, lineWidth: 1, corner: 4).size(w, 16)
            Node.words(text, size: 10, weight: "bold", color: light ? Paint.clear("#FFFFFF", 0.9) : .inkMuted, align: "center", w: w, h: 16)
        }
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
