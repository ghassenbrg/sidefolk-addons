import SidefolkExtensionKit

// Last Stick's tray: twenty-one rods, individually countable, three rows of seven in felt grooves in a wooden frame, each rod's place still marked when it has gone. Hovering a rod shows which
// would go (it and the ones after it), and a click takes them; the takes are also three navy buttons that keep their places when fewer are possible, disabled rather than removed. Taken rods
// leave one by one from the right, toward whoever took them, so the companion's take can be followed too. The tray reads the same in every language.
extension BoardDrawing {
    private struct Tray {
        let room: Double
        static let takeH = 60.0, rows = 3, perRow = 7, frame = 10.0, groove = 4.0, rodW = 15.0, slotH = 36.0
        var height: Double { room - Self.takeH - 6 - Self.slotH - 6 }
        var rowH: Double { (height - 2 * Self.frame - 2 * Self.groove) / Double(Self.rows) }
        var cellW: Double { (BoardDrawing.inner - 2 * Self.frame) / Double(Self.perRow) }
        var rodH: Double { rowH - 12 }
        func rodX(_ i: Int) -> Double { Self.frame + cellW * (Double(i % Self.perRow) + 0.5) - Self.rodW / 2 }
        func rodY(_ i: Int) -> Double { Self.frame + Double(i / Self.perRow) * (rowH + Self.groove) + 6 }
    }

    func sticksPart(total: Int, left: Int, take: Int, groups: [[Int]], hint: [Int], taken: Int, takenBy: String?, locked: Bool) -> PartBlock {
        let tray = Tray(room: playRoom)
        let before = ctx.fresh ? ctx.previous?.play { part -> Int? in if case .sticks(_, let left, _, _, _, _, _, _) = part { left } else { nil } } : nil
        var tints: [Int: Int] = [:]
        for (g, members) in groups.enumerated() { for m in members where tints[m] == nil { tints[m] = g } }
        let arriving = ctx.fresh && left == total && before != total
        let leaving = before.map { Array((left..<Swift.max($0, left)).reversed()) } ?? []
        var nodes: [Node] = [Node.woodFrame("sticks.frame", w: Self.inner, h: tray.height, inset: Tray.frame, inner: Paint.both("#7C62A3", "#262039"))]
        for r in 0..<Tray.rows {
            nodes.append(Node.felt("sticks.row.\(r)", x: Tray.frame, y: Tray.frame + Double(r) * (tray.rowH + Tray.groove), w: Self.inner - 2 * Tray.frame, h: tray.rowH, corner: 12, stitch: false))
        }
        for i in 0..<total {
            // Each place keeps its mark: what has gone can be counted too.
            nodes.append(Node.capsule(fill: Paint.clear("#2A1A40", 0.14)).id("stick.\(i).place").at(tray.rodX(i), tray.rodY(i)).size(Tray.rodW, tray.rodH))
            // The trick's groups of four and the take it advises, when the companion teaches it.
            let tint: Color? = hint.contains(i) ? Paint.clear("#FFC93C", 0.85) : tints[i].map { $0.isMultiple(of: 2) ? Paint.clear("#FFF4E6", 0.5) : Paint.clear("#BFDCF2", 0.6) }
            if let tint, i < left {
                nodes.append(Node.rect(fill: tint, corner: 9).id("stick.\(i).tint").at(tray.rodX(i) - 7, tray.rodY(i) - 3).size(Tray.rodW + 14, tray.rodH + 6))
            }
        }
        for i in 0..<total where i < left || leaving.contains(i) {
            let rod = Node.image("art/rod.webp", fit: "fill").id("stick.\(i).art").at(0, 0).size(Tray.rodW, tray.rodH).shadow(Paint.clear("#2A1A40", 0.3), radius: 1.5, dx: 1, dy: 2).rotate(3).opacity(arriving ? 0 : 1)
            var node = Node.box("stick.\(i)", x: tray.rodX(i), y: tray.rodY(i), w: Tray.rodW, h: tray.rodH) { rod }
            let takes = left - i
            if i < left, !locked, (1...take).contains(takes) {
                let looks = Dictionary(uniqueKeysWithValues: (i..<left).map { ("stick.\($0).art", AreaLook(dy: -7)) })
                node = node.area("stick", value: "\(takes)", label: L("Take {n}", ["n": takes]), hover: nil, press: nil, looks: looks, sound: "sounds/tap.wav")
            }
            nodes.append(node)
        }
        if arriving {
            anims.append(.stagger((0..<total).map { "stick.\($0).art" }, stepMs: 16, ["opacity": 1], ms: 140, ease: "out"))
        }
        if !leaving.isEmpty { rodsLeave(leaving, by: takenBy, tray: tray) }
        let takeY = playRoom - Tray.takeH, w = (Self.inner - 2 * 8) / 3
        let part = Node.box("sticks.part", w: Self.inner, h: playRoom) {
            Node.box("sticks", w: Self.inner, h: tray.height) { nodes }.leftToRight()
            slotRow(y: tray.height + 6, height: Tray.slotH)
            for n in 1...3 {
                takeButton(n, x: Double(n - 1) * (w + 8), y: takeY, w: w, h: Tray.takeH, open: !locked && n <= take, waiting: locked && n <= take)
            }
        }
        return PartBlock(part, height: playRoom)
    }

    /// One by one from the right: each lifts, then goes to whoever took it. The companion's go up into its arms; they hold moves until they have gone, so its take can't be missed.
    private func rodsLeave(_ rods: [Int], by: String?, tray: Tray) {
        let theirs = by == "companion" && board.scorePart?.players == nil
        let stepMs = 190.0, ms = 620.0
        // In the rod's own box: where the companion's paws are (its stage is over the board), or off the tray's lower edge toward the person.
        let steps: [Anim] = rods.enumerated().map { n, i in
            let toX = theirs ? 38 - tray.rodX(i) : Self.inner / 2 - tray.rodX(i) + (Double(n) - 1) * 18
            let toY = theirs ? -34 - tray.rodY(i) : tray.height + 40 - tray.rodY(i)
            return Anim.keys("stick.\(i).art", [
                ["t": 0, "x": 0, "y": 0, "scale": 1, "opacity": 1, "rotate": 3],
                ["t": 0.3, "x": 0, "y": -16, "scale": 1.1, "opacity": 1, "rotate": 3],
                ["t": 0.85, "x": toX * 0.85, "y": toY * 0.85, "scale": 0.92, "opacity": 1, "rotate": theirs ? -28 : 16],
                ["t": 1, "x": toX, "y": toY, "scale": 0.8, "opacity": 0, "rotate": theirs ? -36 : 20],
            ], ms: ms, ease: "in_out").delay(ms: Double(n) * stepMs)
        }
        let run = Anim.sequence([.sound("sounds/pop.wav"), .together(steps)])
        anims.append(theirs ? run.blocksInput() : run)
    }

    /// A navy button with the rods it takes above its words. It keeps its place when fewer can be taken: faded, not pressable, no key.
    private func takeButton(_ n: Int, x: Double, y: Double, w: Double, h: Double, open: Bool, waiting: Bool) -> Node {
        let id = "take.\(n)", depth = 3.0, faceH = h - depth, corner = 16.0
        let words = L("Take {n}", ["n": n])
        let rodW = 7.0, rodH = 24.0, step = 12.0
        let whole = Double(n - 1) * step + rodW
        var face = Node.box(id + ".top", w: w, h: faceH) {
            Node.rect(fill: Paint.action, corner: corner).size(w, faceH)
            for s in 0..<n {
                Node.image("art/rod.webp", fit: "fill").at((w - whole) / 2 + Double(s) * step, 5).size(rodW, rodH).opacity(waiting ? 0.6 : 1)
            }
            Node.words(words, size: 16.5, weight: "heavy", color: Paint.onAction, align: "center", minScale: 0.6, x: 6, y: 30, w: w - 12, h: 24).opacity(waiting ? 0.6 : 1)
        }
        if open {
            keys.append(StageKey(key: "\(n)", id: "take_\(n)", area: "take", value: "\(n)"))
            face = face.area("take", value: "\(n)", label: words, hover: AreaLook(dy: -1), press: AreaLook(dy: depth), sound: "sounds/tap.wav")
        }
        return Node.box(id, x: x, y: y, w: w, h: h) {
            Node.rect(fill: Paint.actionLip, corner: corner).at(0, depth).size(w, faceH)
            face
            // Waiting for the other side, it stays solid navy with its words quieter: the scene through it read as a muddy button every turn.
        }.opacity(open || waiting ? 1 : 0.38)
    }

    var sticksFooter: String? {
        board.play { part -> String? in
            if case .sticks(_, let left, let take, _, _, _, _, _) = part { Swift.min(take, left) == 1 ? L("1 to take") : L("1–{n} to take", ["n": Swift.min(take, left)]) } else { nil }
        }
    }

    static func sticksMove(_ move: SurfaceMove, board: Board, local: inout LocalParts) -> StageAction? {
        guard board.hasSticks, case .click(let area, let value?, _) = move, area == "stick" || area == "take", let n = Int(value) else { return nil }
        return .play(.number(n))
    }
}
