import SidefolkExtensionKit

// Copy Me's pads (PadsView): clay tiles on the table, each picturing its move, on a cream base with its name and key cap. During the playback they light
// one by one (pressed down, glowing, the picture popping) with their notes, the companion doing each move, and take no presses.
extension BoardDrawing {
    /// A pad's soft clay, so red reads as a colour of the game, not an alarm: by day, by night.
    private static func hues(_ color: String) -> (light: String, dark: String) {
        switch color {
        case "green": ("#56B58A", "#5FC496")
        case "yellow": ("#F0B43C", "#F5C255")
        case "red": ("#F07A68", "#F4897A")
        case "purple": ("#9A7BE8", "#A98BF2")
        default: ("#5A8DF0", "#6B9BFF")
        }
    }

    /// `.brightness(-0.16)`, the bevel's lip.
    private static func darker(_ hex: String) -> String {
        let channels = stride(from: 1, to: 7, by: 2).map { i -> Int in
            let start = hex.index(hex.startIndex, offsetBy: i)
            return Int(hex[start..<hex.index(start, offsetBy: 2)], radix: 16) ?? 0
        }
        return "#" + channels.map { String(format: "%02X", max($0 - 41, 0)) }.joined()
    }

    private static func picture(_ art: String?) -> String? {
        art.map { "art/game-pad-\($0.replacingOccurrences(of: "_", with: "-")).webp" }
    }

    func padsPart(_ pads: [Pad], play: [Int], stepMs: Int, locked: Bool) -> PartBlock {
        let many = pads.count > 4
        let gap = many ? 6.0 : 9.0, tileH = many ? 60.0 : 66, artSide = many ? 40.0 : 46
        let cell = (Self.inner - gap * Double(pads.count - 1)) / Double(pads.count)
        let tileW = cell - 12, depth = 4.0, corner = 14.0
        let labelH = TextFit.lineHeight(12, "heavy")
        let baseH = 6 + tileH + depth + 5 + labelH + 6
        let artY = (tileH - artSide) / 2
        let height = baseH + 12

        func tile(_ i: Int, _ pad: Pad) -> Node {
            let id = "pad.\(i)", hue = Self.hues(pad.color)
            let fill = Color.adaptive(light: hue.light, dark: hue.dark)
            let lip = Color.adaptive(light: Self.darker(hue.light), dark: Self.darker(hue.dark))
            return Node.box(id + ".tile", x: 6, y: 6, w: tileW, h: tileH) {
                Node.rect(fill: fill, corner: corner).id(id + ".halo").size(tileW, tileH).shadow(.adaptive(light: hue.light + "2E", dark: hue.dark + "2E"), radius: 3, dx: 0, dy: 3)
                Node.rect(fill: fill, corner: corner).id(id + ".glow").size(tileW, tileH).shadow(.adaptive(light: hue.light + "B3", dark: hue.dark + "B3"), radius: 14, dx: 0, dy: 0).opacity(0)
                Node.rect(fill: lip, corner: corner).id(id + ".lip").at(0, depth).size(tileW, tileH)
                Node.box(id + ".face", w: tileW, h: tileH) {
                    Node.rect(fill: fill, corner: corner).size(tileW, tileH)
                    Node.rect(corner: corner).gradient([Paint.clear("#FFFFFF", 0.22), Paint.clear("#FFFFFF", 0)], from: (0.5, 0), to: (0.5, 0.5)).size(tileW, tileH)
                    Node.rect(corner: corner).gradient([Paint.clear("#FFFFFF", 0.45), Paint.clear("#FFFFFF", 0)], from: (0.5, 0), to: (0.5, 0.5)).id(id + ".gloss").size(tileW, tileH).opacity(0)
                    Node.capsule(fill: Paint.clear("#FFFFFF", 0.14)).at(corner * 1.2, 3).size(tileW - corner * 2.4, 4)
                    Node.rect(stroke: Paint.clear("#FFFFFF", 0.12), lineWidth: 1, corner: corner).size(tileW, tileH)
                    Node.rect(stroke: Paint.clear("#FFFFFF", 0.9), lineWidth: 3, corner: corner).id(id + ".edge").size(tileW, tileH).opacity(0)
                }
                if let art = Self.picture(pad.art) {
                    Node.art(art, x: (tileW - artSide) / 2, y: artY, w: artSide, h: artSide).id(id + ".art").shadow(Paint.clear("#000000", 0.18), radius: 1, dx: 0, dy: 1)
                }
                keyCap("\(i + 1)", light: true).at(tileW - 21, 5)
            }
        }

        /// A pad's moment, on or off, from the panel's spring.
        func light(_ i: Int, on: Bool, ms: Double) -> Anim {
            let id = "pad.\(i)"
            return .together([
                .to(id + ".face", ["y": on ? depth - 1 : 0], ms: ms, ease: "spring"),
                .to(id + ".art", ["scale": on ? 1.18 : 1, "y": artY + (on ? 3 : 0)], ms: ms, ease: "spring"),
                .stagger([id + ".glow", id + ".gloss", id + ".edge"], stepMs: 0, ["opacity": on ? 1 : 0], ms: ms, ease: "out"),
            ])
        }

        if playing {
            var steps: [Anim] = [.wait(ms: 600)]
            let lit = Double(stepMs) * 0.7, dark = Double(stepMs) * 0.3
            for i in play where pads.indices.contains(i) {
                steps.append(.sound("sounds/note-\(i).wav"))
                if let move = pads[i].move { steps.append(.react(Reaction(move: move))) }
                let off = Swift.min(180, dark)
                steps += [light(i, on: true, ms: 180), .wait(ms: Swift.max(lit - 180, 0)), light(i, on: false, ms: off), .wait(ms: dark - off)]
            }
            anims.append(Anim.sequence(steps).essential().blocksInput().named("pads_play"))
            untilPlayed()
        } else if ctx.fresh, !locked || ctx.buildUp, let i = ctx.local.lit, pads.indices.contains(i) {
            // A press lights it a moment; its note came with the press.
            anims.append(.sequence([light(i, on: true, ms: 90), light(i, on: false, ms: 90)]))
        }
        if !locked {
            for i in pads.indices { keys.append(StageKey(key: "\(i + 1)", id: "pad_\(i + 1)", area: "pad", value: "\(i)")) }
        }
        var row = Node.box("pads", w: Self.inner, h: height) {
            for (i, pad) in pads.enumerated() {
                let node = Node.box("pad.\(i)", x: Double(i) * (cell + gap), y: 6, w: cell, h: baseH) {
                    // The cream clay base each tile sits in.
                    Node.rect(fill: .hex("#F6EBDD"), corner: 18).size(cell, baseH).shadow(Paint.black15, radius: 4, dx: 0, dy: 3)
                    Node.rect(fill: .hex("#F6EBDD"), corner: 18).size(cell, baseH).shadow(Paint.clear("#6B4A2B", 0.35), radius: 0, dx: 0, dy: 3)
                    tile(i, pad)
                    // The name has the base's whole width (the key cap sits on the tile), so a long one fits.
                    Node.words(pad.label, size: 12, weight: "heavy", color: .hex("#4A3B2E"), align: "center", x: 6, y: 6 + tileH + depth + 5, w: tileW, h: labelH)
                }
                if locked { node } else {
                    node.area("pad", value: "\(i)", label: "\(i + 1), \(pad.label)", hover: nil, press: AreaLook(scale: 0.95), sound: "sounds/note-\(i).wav")
                }
            }
        }
        if locked { row = row.opacity(0.7) }
        return PartBlock(row, height: height)
    }

    var padsStageWords: String? { board.hasPads && playing ? L("Watch…") : nil }

    var padsFooter: String? {
        board.play { part -> String? in
            if case .pads(let pads, _, _, false) = part { L("1–{n} to copy", ["n": pads.count]) } else { nil }
        }
    }

    /// A press is remembered for the next scene to light it.
    static func padsMove(_ move: SurfaceMove, board: Board, local: inout LocalParts) -> StageAction? {
        guard board.hasPads else { return nil }
        local.lit = nil
        if let played = Playback.next(move, board: board, local: &local) { return played }
        guard case .click("pad", let value?, _) = move, let i = Int(value) else { return nil }
        local.lit = i
        return .play(.pad(i))
    }
}
