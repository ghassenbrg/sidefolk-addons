import SidefolkExtensionKit

// Last Stick's row (SticksView): candy sticks standing on the table, hovering one shows which would go (it and the ones after it), a click takes them; the
// takes as big buttons too, each showing its sticks. The row reads the same in every language.
extension BoardDrawing {
    func sticksPart(total: Int, left: Int, take: Int, groups: [[Int]], hint: [Int], taken: Int, takenBy: String?, locked: Bool) -> PartBlock {
        let gap = 5.0, cellH = 104.0, stickW = 11.0, stickH = 70.0
        let cell = (Self.inner - gap * Double(total - 1)) / Double(total)
        let before = ctx.fresh ? ctx.previous?.play { part -> Int? in if case .sticks(_, let left, _, _, _, _, _, _) = part { left } else { nil } } : nil
        var tints: [Int: Int] = [:]
        for (g, members) in groups.enumerated() { for m in members where tints[m] == nil { tints[m] = g } }
        var nodes: [Node] = []
        for i in 0..<total {
            let gone = i >= left
            // The sticks just taken rise and stay faint, to show the move; once none is left (the game decided), they go entirely, so the end leaves an empty row.
            let lifting = gone && i < left + taken && left > 0
            let takes = left - i
            let color: Color = hint.contains(i) ? Paint.sun : tints[i].map { $0.isMultiple(of: 2) ? Color.accent : Paint.purple } ?? Paint.coral
            var stick = candyStick(color: color, x: (cell - stickW) / 2, y: cellH - stickH, w: stickW, h: stickH).id("stick.\(i).art")
            if lifting, (before ?? left) > i {
                // Just taken: it starts where it stood, for its rise.
                anims.append(.to("stick.\(i).art", ["y": cellH - stickH - 30, "opacity": 0.25], ms: 450, ease: "out"))
            } else if gone {
                stick = stick.at((cell - stickW) / 2, cellH - stickH - (lifting ? 30 : 0)).opacity(lifting ? 0.25 : 0)
            }
            var node = Node.box("stick.\(i)", x: Double(i) * (cell + gap), w: cell, h: cellH) { stick }
            if !gone, !locked, (1...take).contains(takes) {
                let looks = Dictionary(uniqueKeysWithValues: (i..<left).map { ("stick.\($0).art", AreaLook(dy: -10)) })
                node = node.area("stick", value: "\(takes)", label: L("Take {n}", ["n": takes]), hover: nil, press: nil, looks: looks, sound: "sounds/tap.wav")
            }
            nodes.append(node)
        }
        let row = Node.box("sticks", w: Self.inner, h: cellH) { nodes }.leftToRight()
        guard !locked else { return PartBlock(row, height: cellH) }
        // The takes as big buttons too: the same moves as clicking the row.
        let buttons = Swift.max(1, Swift.min(take, left)), bGap = 8.0
        let w = (Self.inner - bGap * Double(buttons - 1)) / Double(buttons)
        let height = cellH + 4 + 6 + 50
        return PartBlock(.box("sticks.part", w: Self.inner, h: height) {
            row
            for n in 1...buttons {
                takeButton(n, x: Double(n - 1) * (w + bGap), y: cellH + 10, w: w)
            }
        }, height: height)
    }

    /// A secondary game button with the sticks it takes above its words.
    private func takeButton(_ n: Int, x: Double, y: Double, w: Double) -> Node {
        let id = "take.\(n)", h = 46.0
        let words = L("Take {n}", ["n": n])
        let stickRow = Double(n) * 6 + Double(n - 1) * 3
        keys.append(StageKey(key: "\(n)", id: "take_\(n)", area: "take", value: "\(n)"))
        let face = Node.box(id + ".top", w: w, h: h) {
            Node.rect(fill: Paint.card, stroke: Paint.edge, lineWidth: 1, corner: 16).size(w, h)
            for s in 0..<n { candyStick(color: Paint.coral, x: (w - stickRow) / 2 + Double(s) * 9, y: 3, w: 6, h: 18) }
            Node.words(words, size: 16, weight: "heavy", align: "center", minScale: 0.65, x: 8, y: 23, w: w - 16, h: 20)
        }.area("take", value: "\(n)", label: words, hover: nil, press: AreaLook(dy: 3), sound: "sounds/tap.wav")
        return Node.box(id, x: x, y: y, w: w, h: h + 4) {
            Node.rect(fill: Paint.lip, corner: 16).at(0, 4).size(w, h)
            face
        }
    }

    var sticksFooter: String? {
        board.play { part -> String? in
            if case .sticks(_, let left, let take, _, _, _, _, false) = part { L("1–{n} to take", ["n": Swift.min(take, left)]) } else { nil }
        }
    }

    static func sticksMove(_ move: SurfaceMove, board: Board, local: inout LocalParts) -> StageAction? {
        guard board.hasSticks, case .click(let area, let value?, _) = move, area == "stick" || area == "take", let n = Int(value) else { return nil }
        return .play(.number(n))
    }
}
