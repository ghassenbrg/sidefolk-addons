import Foundation
import SidefolkExtensionKit

// Trivia in its booth: the question on a plaque of one size, the companion's sealed pick on the counter beside it, the answers as tickets on the felt below. The bubble says
// something short, so it never holds the question: a question of one line or four moves nothing, its words only shrink. When it's answered: the pick pressed, the beat (Suspense),
// then right and wrong marked (never red), the envelope going to the ticket it held, and after a moment the plaque turns over to its fact.
extension BoardDrawing {
    private static let plaqueRatio = 371.0 / 760, ticketRatio = 205.0 / 520
    /// How long the verdict stands before the plaque turns over: long enough to see the marks.
    private static let factAfterMs = 1300.0

    func triviaTable() -> Node {
        let room = playRoom, width = Self.inner
        let a = board.answersPart!, tiles = a.tiles
        let judged = tiles.contains { $0.state == .right || $0.state == .wrong }
        let plaqueW = 298.0, plaqueH = plaqueW * Self.plaqueRatio
        let dockY = room - 46
        let ticketW = (width - 8) / 2, ticketH = ticketW * Self.ticketRatio, gap = 4.0
        let ticketsY = dockY - 8 - 2 * ticketH - gap
        let plaqueY = 6.0
        let question = board.promptPart?.text ?? ""
        let fact = board.parts.lazy.compactMap { part -> (String, String?)? in if case .note(let text, let title, .info) = part { (text, title) } else { nil } }.first
        let newQuestion = ctx.fresh && !a.locked && ctx.previous?.promptPart?.text != question
        answerKeys(tiles, locked: a.locked)

        var nodes: [Node] = []
        nodes.append(plaque(question, fact: fact, w: plaqueW, h: plaqueH, judged: judged, newQuestion: newQuestion).at(0, plaqueY))
        nodes.append(contentsOf: sealedPick(tiles: tiles, judged: judged, x: plaqueW + 2, bottom: ticketsY - 26, ticketsY: ticketsY, ticketW: ticketW, ticketH: ticketH, gap: gap))
        for (i, tile) in tiles.enumerated() {
            let x = Double(i % 2) * (ticketW + 8), y = ticketsY + Double(i / 2) * (ticketH + gap)
            nodes.append(ticket(tile, index: i, locked: a.locked, w: ticketW, h: ticketH).at(x, y))
            if newQuestion { arrive("tile.\(i).body", delay: 60 + Double(i) * 50) }
        }
        let buttons = tableButtons
        if !buttons.isEmpty {
            let w = Swift.min(buttons.map { buttonWidth($0, flat: false) + 24 }.reduce(0, +) + 8, width)
            let row = buttonRow(buttons, id: "dock", width: w)
            nodes.append(row.node.at((width - w) / 2, dockY + (46 - row.height) / 2))
        }
        return .box("trivia", w: width, h: room) { nodes }
    }

    /// The plaque: one size, the question's words shrinking to it. It turns over to the fact when there is one.
    private func plaque(_ question: String, fact: (String, String?)?, w: Double, h: Double, judged: Bool, newQuestion: Bool) -> Node {
        let insetX = w * 0.12, insetY = h * 0.17
        func face(_ inner: [Node]) -> Node {
            .box(w: w, h: h) {
                Node.art("art/plaque.webp", w: w, h: h)
                inner
            }
        }
        let front = face([Node.words(question, size: TextFit.wordSize(question, size: 20, weight: "heavy", width: w - 2 * insetX), weight: "heavy", color: Paint.onCream, align: "center", lines: 4, minScale: 0.5, x: insetX, y: insetY, w: w - 2 * insetX, h: h - 2 * insetY).id("plaque.words").label(question)])
        if newQuestion { anims.append(.keys("plaque.words", [["t": 0, "opacity": 0], ["t": 1, "opacity": 1]], ms: 240, ease: "out")) }
        guard let fact else { return Node.box("plaque", w: w, h: h) { front } }
        let titleH = fact.1 == nil ? 0.0 : 16
        let back = face([
            Node.words(fact.1 ?? "", size: 11.5, weight: "heavy", color: Paint.lilacDeepFixed, align: "center", minScale: 0.7, x: insetX, y: insetY - 2, w: w - 2 * insetX, h: titleH),
            Node.words(fact.0, size: 14, weight: "semibold", color: Paint.onCream, align: "center", lines: 5, minScale: 0.62, x: insetX, y: insetY - 2 + titleH, w: w - 2 * insetX, h: h - 2 * insetY + 4 - titleH).label(fact.0),
        ])
        let turning = ctx.fresh && ctx.previous?.answersPart?.tiles.contains(where: { $0.state == .right }) != true
        if turning { anims.append(Anim.flip("plaque", 1, ms: 520, ease: "in_out").delay(ms: Self.factAfterMs)) }
        return Node.flip(front: front, back: back, showing: turning ? "front" : "back", axis: "x").id("plaque").size(w, h)
    }

    /// The companion's sealed pick, saying so; when the answers are judged it goes to the ticket it held, and its face stays there.
    private func sealedPick(tiles: [Tile], judged: Bool, x: Double, bottom: Double, ticketsY: Double, ticketW: Double, ticketH: Double, gap: Double) -> [Node] {
        guard board.scorePart?.players == nil else { return [] }
        let w = Self.inner - x, h = w * 216 / 320, y = bottom - h + 2
        let words = L("{name} has picked", ["name": "{companion}"])
        var envelope = Node.art("art/envelope-sealed.webp", w: w, h: h).id("sealed.envelope").at(x, y).label(words)
        var caption = Node.box("sealed.caption", x: x - 2, y: y - 36, w: w + 4, h: 32) {
            Node.rect(fill: Paint.card(0.92), corner: 9).id("sealed.back").size(w + 4, 32)
            Node.words(words, size: 10.5, weight: "heavy", align: "center", lines: 2, minScale: 0.7, x: 3, y: 2, w: w - 2, h: 28)
        }
        if judged {
            envelope = envelope.opacity(0)
            caption = caption.opacity(0)
            if ctx.fresh, ctx.previous?.answersPart?.tiles.contains(where: { $0.state == .right }) != true, let pick = tiles.firstIndex(where: \.companion) {
                let toX = Double(pick % 2) * (ticketW + 8) + ticketW - 40, toY = ticketsY + Double(pick / 2) * (ticketH + gap) + 8
                anims.append(.keys("sealed.envelope", [["t": 0, "x": x, "y": y, "scale": 1, "opacity": 1], ["t": 0.8, "x": toX, "y": toY, "scale": 0.4, "opacity": 1], ["t": 1, "x": toX, "y": toY, "scale": 0.3, "opacity": 0]], ms: 420, ease: "in_out"))
            }
        } else if ctx.fresh, ctx.previous?.promptPart?.text != board.promptPart?.text {
            anims.append(Anim.keys("sealed.envelope", [["t": 0, "y": y - 10, "opacity": 0], ["t": 1, "y": y, "opacity": 1]], ms: 240, ease: "spring").delay(ms: 320))
        }
        return [caption, envelope]
    }

    /// A ticket from the pack: its number on a round cap, its words, and once judged the same shape in the verdict's colour. Picked is a navy edge in the ticket's own shape.
    private func ticket(_ tile: Tile, index i: Int, locked: Bool, w: Double, h: Double) -> Node {
        let id = "tile.\(i)"
        let pending = ctx.pendingAnswer == i
        let verdict = pending ? nil : Verdict(tile: tile.state, locked: locked)
        let open = !locked && tile.state != .faded
        let ink = verdict == .win ? Paint.white : Paint.onCream
        let capSide = 26.0, capX = 15.0
        // A wrong answer shakes its head, once, when it first shows wrong.
        if ctx.fresh, tile.state == .wrong, ctx.previous?.answersPart?.tiles[safe: i]?.state != .wrong { shake(id + ".body") }
        if ctx.fresh, tile.state == .right, ctx.previous?.answersPart?.tiles[safe: i]?.state != .right {
            anims.append(.keys(id + ".body", [["t": 0, "scale": 0.96], ["t": 1, "scale": 1.02]], ms: 280, ease: "spring"))
        }
        var body = Node.box(id + ".body", w: w, h: h) {
            if pending || tile.state == .picked { Node.image("art/ticket.webp", tint: Paint.action).id(id + ".edge").at(-3, -3).size(w + 6, h + 6) }
            Node.art("art/ticket.webp", w: w, h: h).id(id + ".paper")
            if let verdict, verdict != .draw { Node.image("art/ticket.webp", tint: verdict == .win ? Color.win : Paint.lostCream).id(id + ".mark").size(w, h).opacity(verdict == .win ? 0.94 : 0.8) }
            Node.ellipse(fill: verdict == .win ? Paint.clear("#FFFFFF", 0.28) : Paint.lilacFixed).id(id + ".cap").at(capX, (h - capSide) / 2).size(capSide, capSide)
            if let verdict, verdict != .draw {
                Node.symbol(verdict == .win ? "checkmark" : "xmark", color: ink).symbolLook(weight: "heavy").at(capX + 6, (h - 14) / 2).size(14, 14)
            } else {
                Node.words(Format.integer(i + 1), size: 14, weight: "black", color: Paint.onCream, align: "center", x: capX, y: (h - capSide) / 2, w: capSide, h: capSide)
            }
            Node.words(tile.label, size: TextFit.wordSize(tile.label, size: 15, weight: "heavy", width: w - capX - capSide - 7 - 38), weight: "heavy", color: ink, align: "leading", lines: 2, minScale: 0.6, x: capX + capSide + 7, y: 7, w: w - capX - capSide - 7 - (tile.companion ? 38 : 14), h: h - 14).id(id + ".words")
            if tile.companion {
                Node.faceDisc(id: id + ".face", x: w - 38, y: (h - 26) / 2, side: 26).shadow(Paint.clear("#000000", 0.2), radius: 2, dx: 0, dy: 1)
            }
        }.scale(pending ? 0.97 : tile.state == .right ? 1.02 : 1)
        // The companion's wrong pick steps back less than the others: it still says whose it was.
        if tile.state == .faded { body = body.opacity(tile.companion ? 0.7 : 0.35) }
        if ctx.fresh, tile.companion, ctx.previous?.answersPart?.tiles[safe: i]?.companion != true {
            anims.append(Anim.keys(id + ".face", [["t": 0, "scale": 0.2, "opacity": 0], ["t": 1, "scale": 1, "opacity": 1]], ms: 300, ease: "spring").delay(ms: 340))
        }
        var words = "\(Format.integer(i + 1)), \(tile.label)"
        switch tile.state {
        case .right: words += ", " + L("right")
        case .wrong: words += ", " + L("wrong")
        case .picked: words += ", " + L("your pick")
        default: break
        }
        if tile.companion { words += ", " + L("{name}'s pick", ["name": "{companion}"]) }
        return Node.box(id, w: w, h: h) { body }.area("answer", value: "\(i)", label: words, disabled: !open, hover: AreaLook(scale: 1.025), press: AreaLook(scale: 0.97, dy: 1), sound: "sounds/tap.wav")
    }

    /// The set-up (concept 20): miniatures on felt in a frame of wood, the segments under it with their names, one Start.
    func triviaSetupTable() -> Node {
        let width = Self.inner, room = playRoom
        let topics = board.choicePart("topic")!
        var y = 0.0
        var nodes: [Node] = []
        let trayH = room - 46 - 8 - 3 * (30 + 5)
        nodes.append(Node.woodFrame("topics.frame", w: width, h: trayH, inset: 8, corner: 20, inner: Paint.lilacDeep))
        nodes.append(Node.image("art/tex-felt-lilac.heic", dark: "art/tex-felt-lilac-night.heic", fit: "fill").id("topics.felt").at(8, 8).size(width - 16, trayH - 16).corner(12).clip())
        nodes.append(topicTiles(topics.options, selected: topics.selected, x: 15, y: 15, w: width - 30, h: trayH - 30))
        choiceArrows(name: "topic", options: topics.options, selected: topics.selected, columns: 4)
        y += trayH + 5
        for name in ["length", "pace", "level"] {
            if let c = board.choicePart(name) {
                nodes.append(choice(name: name, label: c.label ?? L("Play"), style: .segmented, options: c.options, selected: c.selected, compact: true, labelWidth: 78).node.at(0, y))
            }
            y += 30 + 5
        }
        nodes.append(buttonRow(tableButtons, id: "dock").node.at(0, y + 3))
        return .box("setup", w: width, h: room) { nodes }
    }

    /// Topics in rows of four; a last row of fewer shares the width, as in the concept.
    private func topicTiles(_ options: [ChoiceOption], selected: String?, x: Double, y: Double, w: Double, h: Double) -> Node {
        let columns = 4, gap = 6.0
        let rows = (options.count + columns - 1) / columns
        let tileH = (h - gap * Double(rows - 1)) / Double(max(rows, 1))
        return .box("topics", x: x, y: y, w: w, h: h) {
            for (r, start) in stride(from: 0, to: options.count, by: columns).enumerated() {
                let row = Array(options[start..<Swift.min(start + columns, options.count)])
                let tileW = (w - gap * Double(row.count - 1)) / Double(row.count)
                for (c, option) in row.enumerated() {
                    topicTile(option, on: selected == option.value, x: Double(c) * (tileW + gap), y: Double(r) * (tileH + gap), w: tileW, h: tileH)
                }
            }
        }
    }

    private func topicTile(_ o: ChoiceOption, on: Bool, x: Double, y: Double, w: Double, h: Double) -> Node {
        let id = "topic.\(o.value)", labelH = 24.0, art = Self.topicArt(o.symbol)
        return Node.box(id, x: x, y: y, w: w, h: h) {
            Node.rect(fill: Paint.card, corner: 12).id(id + ".face").size(w, h).shadow(Paint.clear("#3A2A55", 0.22), radius: 2, dx: 0, dy: 2)
            if let art {
                Node.art(art, x: 4, y: 3, w: w - 8, h: h - labelH - 4)
            } else if let symbol = o.symbol {
                Node.symbol(symbol, color: Paint.lilacDeep).symbolLook().at((w - 26) / 2, (h - labelH - 26) / 2).size(26, 26)
            }
            Node.words(o.label, size: TextFit.wordSize(o.label, size: 11.5, weight: "heavy", width: w - 6), weight: "heavy", align: "center", lines: 2, minScale: 0.7, x: 3, y: h - labelH - 1, w: w - 6, h: labelH)
            if on { Node.rect(stroke: Paint.action, lineWidth: 2.5, corner: 12).id(id + ".edge").at(-1, -1).size(w + 2, h + 2) }
        }.area("choice", value: "topic|\(o.value)", label: o.label, hover: AreaLook(scale: 1.03), press: AreaLook(scale: 0.97), selected: on, sound: "sounds/tap.wav")
    }
}
