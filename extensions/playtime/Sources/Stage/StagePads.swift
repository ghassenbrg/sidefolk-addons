import Foundation
import SidefolkExtensionKit

// Copy Me's pads: large painted tiles on a felt mat, each with its picture, its name and its key. While the companion demonstrates they stand back, faded and not pressable, the state
// pill says to watch and each pad comes forward alone, lit, with its note and the companion's move, and a dot for each step. Then they all come up to the person's hand, the pill says it
// is your turn, and each right press fills a dot.
extension BoardDrawing {
    /// A pad's painted clay: by day, by night, and its thicker edge. Never a verdict.
    private static func hues(_ color: String) -> (light: String, dark: String, lipLight: String, lipDark: String) {
        switch color {
        case "green": ("#A9DBBA", "#83B595", "#86BD98", "#638F74")
        case "yellow": ("#F8D779", "#D9B65A", "#E0BC55", "#B19244")
        case "red": ("#F8A98A", "#DE8B6E", "#E48C6B", "#B56E55")
        case "purple": ("#BFA8E4", "#A08BC8", "#A08ACB", "#7E6BA6")
        default: ("#AFD0EF", "#8BADCF", "#8FB4DA", "#6C8CAD")
        }
    }

    private static func picture(_ art: String?) -> String? {
        art.map { "art/game-pad-\($0.replacingOccurrences(of: "_", with: "-")).webp" }
    }

    /// The pause before a dance's first step: the last press's light has gone, and the state has been read.
    static let padsLeadMs = 900
    /// How far a pad stands back while it can't be pressed.
    private static let standBack = 0.55
    /// A wrong press's moment: the shake, a look at the pad that was right, a breath before the card.
    static let padMissMs = 1700

    func padsPart(_ pads: [Pad], play: [Int], stepMs: Int, locked: Bool, length: Int?, done: Int) -> PartBlock {
        let showing = playing
        let open = !locked && !showing
        // A wrong press: the one pressed and the one that was right stay forward, and everything else steps back.
        let right = ctx.buildUp ? board.padMissed : nil, pressed = right == nil ? nil : ctx.local.lit
        let statusH = 30.0, gap = 10.0, pad = 12.0, depth = 5.0
        let slotH = 38.0, matY = statusH + 6, matH = playRoom - matY - slotH - 6
        let columns = pads.count > 4 ? 3 : 2
        let rows = (pads.count + columns - 1) / columns
        let tileW = (Self.inner - 2 * pad - gap * Double(columns - 1)) / Double(columns)
        let tileH = (matH - 2 * pad - depth - gap * Double(rows - 1)) / Double(rows)

        func light(_ i: Int, on: Bool, ms: Double, rest: Double = 1) -> Anim {
            let id = "pad.\(i)"
            return .together([
                .to(id, ["opacity": on ? 1 : rest], ms: ms, ease: "out"),
                .to(id + ".face", ["scale": on ? 1.04 : 1], ms: ms, ease: on ? "spring" : "out"),
                .stagger([id + ".glow", id + ".edge"], stepMs: 0, ["opacity": on ? 1 : 0], ms: ms, ease: "out"),
            ])
        }

        if showing {
            var steps: [Anim] = [.wait(ms: Double(Self.padsLeadMs))]
            // One at a time: most of a step lit, and always a gap, so the same pad twice reads as twice.
            let step = Double(stepMs), on = Swift.min(160, step * 0.3), off = Swift.min(120, step * 0.22), hold = step - on - off - 40
            for (n, i) in play.enumerated() where pads.indices.contains(i) {
                steps.append(.sound("sounds/note-\(i).wav"))
                if let move = pads[i].move { steps.append(.react(Reaction(move: move))) }
                steps.append(.to("pads.dot.\(n)", ["opacity": 1], ms: 90, ease: "out"))
                steps += [light(i, on: true, ms: on), .wait(ms: Swift.max(hold, 0)), light(i, on: false, ms: off, rest: Self.standBack), .wait(ms: 40)]
            }
            anims.append(Anim.sequence(steps).essential().blocksInput().named("pads_play"))
            untilPlayed()
        } else if let right, pads.indices.contains(right) {
            if ctx.fresh, let pressed, pads.indices.contains(pressed) {
                // A little calm shake, nothing more: no red, no flash.
                let frames = (0...12).map { n -> [String: Double] in
                    let a = Double(n) / 12
                    return ["t": a, "x": 4 * sin(a * .pi * 6) * (1 - a)]
                }
                anims.append(.keys("pad.\(pressed).face", frames, ms: 460))
            }
            anims.append(.sequence([.wait(ms: 420), .sound("sounds/note-\(right).wav"), light(right, on: true, ms: 160)]))
        } else if ctx.fresh, !locked || ctx.buildUp, let i = ctx.local.lit, pads.indices.contains(i) {
            // A press lights it a moment; its note came with the press.
            anims.append(.sequence([light(i, on: true, ms: 90, rest: locked ? Self.standBack : 1), light(i, on: false, ms: 140, rest: locked ? Self.standBack : 1)]))
        }
        if showing, ctx.fresh, let i = ctx.local.lit, pads.indices.contains(i) {
            // The press that finished the last round: seen, before the pads stand back for the next.
            anims.append(.sequence([.to("pad.\(i).glow", ["opacity": 1], ms: 60, ease: "out"), .to("pad.\(i).glow", ["opacity": 0], ms: 240, ease: "in")]))
        }
        // The dance just ended: it is the person's turn now, and the moment says so. (The pads themselves ease forward with the scene's transition.)
        let turnBegins = open && !ctx.fresh && !play.isEmpty && ctx.local.playback?.done == true
        if turnBegins {
            anims.append(.keys("pads.state.turn", [["t": 0, "scale": 0.7], ["t": 1, "scale": 1]], ms: 340, ease: "spring"))
            anims.append(.keys("bubble.text", [["t": 0, "opacity": 0], ["t": 1, "opacity": 1]], ms: 180, ease: "out"))
        }
        if open {
            for i in pads.indices { keys.append(StageKey(key: "\(i + 1)", id: "pad_\(i + 1)", area: "pad", value: "\(i)")) }
        }
        let tiles = pads.enumerated().map { i, one -> Node in
            let row = i / columns, inRow = row == rows - 1 ? pads.count - row * columns : columns
            // A short last row stands in the middle.
            let startX = (Self.inner - Double(inRow) * tileW - Double(inRow - 1) * gap) / 2
            return padTile(i, one, x: startX + Double(i - row * columns) * (tileW + gap), y: matY + pad + Double(row) * (tileH + gap), w: tileW, h: tileH, depth: depth, open: open, faded: !open && i != right && i != pressed)
        }
        return PartBlock(.box("pads", w: Self.inner, h: playRoom) {
            padsStatus(width: Self.inner, height: statusH, showing: showing, open: open, length: length ?? play.count, done: done)
            Node.felt("pads.mat", y: matY, w: Self.inner, h: matH)
            tiles
            slotRow(y: playRoom - slotH, height: slotH)
        }.leftToRight(), height: playRoom)
    }

    private func padTile(_ i: Int, _ pad: Pad, x: Double, y: Double, w: Double, h: Double, depth: Double, open: Bool, faded: Bool) -> Node {
        let id = "pad.\(i)", hue = Self.hues(pad.color), corner = 20.0
        let small = w < 130
        let labelH = small ? 22.0 : 26, labelSize = small ? 15.0 : 18, disc = small ? 22.0 : 26
        let artRoom = h - labelH - 14
        var face = Node.box(id + ".face", w: w, h: h) {
            Node.rect(fill: .adaptive(light: hue.light, dark: hue.dark), corner: corner).size(w, h)
            Node.rect(corner: corner).gradient([Paint.clear("#FFFFFF", 0.22), Paint.clear("#FFFFFF", 0)], from: (0.5, 0), to: (0.5, 0.5)).size(w, h)
            if let art = Self.picture(pad.art) {
                Node.art(art, x: 24, y: 14, w: w - 48, h: artRoom - 10).id(id + ".art").shadow(Paint.clear("#3A2A55", 0.25), radius: 1.5, dx: 0, dy: 1.5)
            }
            Node.words(pad.label, size: labelSize, weight: "heavy", color: Paint.navy, align: "center", minScale: 0.6, x: 8, y: h - labelH - 7, w: w - 16, h: labelH)
            Node.ellipse(fill: .hex("#FFF6E8")).at(9, 9).size(disc, disc).shadow(Paint.clear("#3A2A55", 0.25), radius: 1, dx: 0, dy: 1)
            Node.words("\(i + 1)", size: labelSize * 0.85, weight: "heavy", color: Paint.navy, align: "center", x: 9, y: 9, w: disc, h: disc)
            // Lit: the warm edge of the concept, by day and by night.
            Node.rect(stroke: Paint.sun, lineWidth: 4, corner: corner).id(id + ".edge").size(w, h).opacity(0)
        }.anchor(0.5, 0.5)
        if open {
            face = face.area("pad", value: "\(i)", label: "\(i + 1), \(pad.label)", hover: AreaLook(dy: -2), press: AreaLook(dy: depth - 1), sound: "sounds/note-\(i).wav")
        }
        return Node.box(id, x: x, y: y, w: w, h: h + depth) {
            Node.rect(fill: Paint.sun, corner: corner).id(id + ".glow").size(w, h).shadow(Paint.clear("#FFC93C", 0.9), radius: 16, dx: 0, dy: 0).opacity(0)
            Node.rect(fill: .adaptive(light: hue.lipLight, dark: hue.lipDark), corner: corner).id(id + ".lip").at(0, depth).size(w, h)
            face
        }.opacity(faded ? Self.standBack : 1)
    }

    /// Whose turn it is, in words, and the dance as dots in their own room: a dot a move up to 24, then the count.
    private func padsStatus(width: Double, height: Double, showing: Bool, open: Bool, length: Int, done: Int) -> Node {
        let pillW = 136.0, dotsX = pillW + 14, dotsW = width - dotsX
        let d = length <= 11 ? 13.0 : 7.5, step = d + (length <= 11 ? 6.5 : 1.3)
        let dots = length <= 24
        return .box("pads.status", w: width, h: height) {
            if showing {
                padsPill("pads.state.watch", symbol: "eye.fill", words: L("Watch first"), fill: Paint.card(0.94), ink: Paint.ink, w: pillW, h: height)
            } else if open {
                padsPill("pads.state.turn", symbol: "hand.tap.fill", words: L("Your turn"), fill: Paint.action, ink: Paint.onAction, w: pillW, h: height)
            }
            if dots {
                // From the left, so a move added to the dance adds a dot and moves none.
                let x = dotsX
                for n in 0..<length {
                    Node.ellipse(fill: Paint.card(0.9), stroke: Paint.ink, lineWidth: 1.5).at(x + Double(n) * step, (height - d) / 2).size(d, d)
                    Node.ellipse(fill: Paint.ink).id("pads.dot.\(n)").at(x + Double(n) * step, (height - d) / 2).size(d, d).opacity(!showing && n < done ? 1 : 0)
                }
            } else {
                Node.words("\(Format.integer(done)) / \(Format.integer(length))", size: 15, weight: "heavy", align: "center", x: dotsX, w: dotsW, h: height).textLook(tabular: true)
            }
        }
    }

    private func padsPill(_ id: String, symbol: String, words: String, fill: Color, ink: Color, w: Double, h: Double) -> Node {
        .box(id, w: w, h: h) {
            Node.capsule(fill: fill).size(w, h).shadow(Paint.black8, radius: 3, dx: 0, dy: 1)
            Node.symbol(symbol, color: ink).symbolLook(weight: "bold").at(11, (h - 15) / 2).size(15, 15)
            Node.words(words, size: 14, weight: "heavy", color: ink, align: "center", minScale: 0.6, x: 30, w: w - 40, h: h)
        }
    }

    /// What the bubble says once the dance has played: the board's own words still say to watch until the first press.
    var padsStageWords: String? {
        if ctx.buildUp, let right = board.padMissed, let pads = board.play({ part -> [Pad]? in if case .pads(let pads, _, _, _, _, _) = part { pads } else { nil } }), pads.indices.contains(right) {
            return L("Oops! It was {pad}.", ["pad": pads[right].label])
        }
        guard !playing, let open = board.play({ part -> Bool? in if case .pads(_, _, _, let locked, _, _) = part { !locked } else { nil } }), open else { return nil }
        return L("Your turn: copy it.")
    }

    var padsFooter: String? {
        board.play { part -> String? in
            if case .pads(let pads, _, _, _, _, _) = part { L("1–{n} to copy", ["n": pads.count]) } else { nil }
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
