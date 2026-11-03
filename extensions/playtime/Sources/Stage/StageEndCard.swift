import SidefolkExtensionKit

// The end card (GameResultView): the result as one unit (an award mark beside the score, who won in words, the game's line), a
// small new-best chip, facts, what to do next with "Back to games" beside it, and the level for the next game. Calm and flat:
// the mark is the only picture, and it appears once.
extension BoardDrawing {
    func endCard(figure: String, line: String?, ribbon: String?, tone: Tone, facts: [(String, String)], actions: [GameButton]) -> PartBlock {
        let width = Self.inner, verdict = Verdict(tone: tone)
        let title: String? = switch verdict {
        case .win: ctx.entry.solo ? L("Solved!") : L("You win!")
        case .loss: L("{name} wins!", ["name": "{companion}"])
        case .draw: L("A draw")
        }
        let room = width - 56
        let said = board.promptPart?.text
        let shownLine = line == said ? nil : line
        let fact = facts.map { "\($0.0) \($0.1)" }.joined(separator: " · ")
        let lineH = shownLine.map { TextFit.height($0, size: 14, weight: "bold", width: room, lines: 2) } ?? 0
        // Companion and award stand on the card's top edge.
        let figureRow = 92.0
        var cy = 14.0
        var inCard: [Node] = []
        if let title {
            inCard.append(Node.words(title, size: 30, weight: "black", align: "center", minScale: 0.6, x: 20, y: cy, w: width - 40, h: 38).id("end.title"))
            cy += 40
        }
        let figureW = Swift.min(TextFit.width(figure, size: 21, weight: "black") + 36, room)
        inCard.append(Node.capsule(fill: chipFill(verdict)).id("end.chip").at((width - figureW) / 2, cy).size(figureW, 32))
        inCard.append(Node.words(Self.isolated(figure, rtl: ctx.rtl), size: 21, weight: "black", color: chipInk(verdict), align: "center", minScale: 0.6, x: (width - figureW) / 2 + 8, y: cy, w: figureW - 16, h: 32).textLook(tabular: true).id("end.figure"))
        cy += 38
        if let ribbon {
            let w = TextFit.width(ribbon, size: 12, weight: "bold") + 24
            inCard.append(Node.capsule(fill: Paint.lilac).id("end.ribbon").at((width - w) / 2, cy).size(w, 22))
            inCard.append(Node.words(ribbon, size: 12, weight: "bold", align: "center", x: (width - w) / 2, y: cy, w: w, h: 22))
            cy += 26
            appear("end.ribbon")
        }
        if let shownLine {
            inCard.append(Node.words(shownLine, size: 14, weight: "bold", align: "center", lines: 2, x: 28, y: cy, w: room, h: lineH))
            cy += lineH + 4
        }
        if !fact.isEmpty {
            inCard.append(Node.words(fact, size: 12, weight: "semibold", color: Paint.inkSoft, align: "center", minScale: 0.65, x: 20, y: cy, w: width - 40, h: 18))
            cy += 20
        }
        let cardH = cy + 12
        var nodes: [Node] = [
            Node.felt("end.mat", x: -6, y: figureRow + 24, w: width + 12, h: cardH - 10, corner: 26, stitch: false),
            Node.rect(fill: Paint.card, stroke: Paint.edge, lineWidth: 1, corner: 22).id("end.card").at(14, figureRow).size(width - 28, cardH).shadow(Paint.black8, radius: 6, dx: 0, dy: 3),
            Node.rect(stroke: Paint.clear("#8E72B5", 0.5), lineWidth: 1.25, corner: 18, dash: [5, 4]).id("end.stitch").at(19, figureRow + 5).size(width - 38, cardH - 10),
            Node.companion(pose: pose).figure(bottom: true).id("end.companion").at(12, 0).size(96, figureRow + 6),
            markArt(verdict: verdict, tone: tone).at((width - 80) / 2 + 8, figureRow - 78),
        ]
        nodes.append(.box("end.words", y: figureRow, w: width, h: cardH) { inCard })
        var y = figureRow + cardH + 12
        // The small choices an end card offers (the level for the next game), first.
        for case .choice(let name, let label, .segmented, let options, let selected) in board.parts {
            let row = choice(name: name, label: label, style: .segmented, options: options, selected: selected, compact: true, width: width - 80)
            nodes.append(row.node.at(40, y))
            y += row.height + 10
        }
        for (i, action) in actions.enumerated() {
            let block = buttonRow([action], id: "end.action.\(i)", width: width - 40, flat: i > 0)
            nodes.append(block.node.at(20, y))
            y += block.height + 8
        }
        nodes.append(backLink(y: y, width: width))
        y += 24
        appear("end.words")
        popMark()
        return PartBlock(.box("end", w: width, h: y) { nodes }, height: y)
    }

    /// What the frame's Back does, as a link under the actions.
    static let backMove = "__back"

    private func backLink(y: Double, width: Double) -> Node {
        let words = L("Back to games"), w = TextFit.width(words, size: 13, weight: "bold") + 8
        return Node.box("end.back", x: (width - w) / 2, y: y, w: w, h: 22) {
            Node.words(words, size: 13, weight: "bold", align: "center", w: w, h: 20)
            Node.rect(fill: Paint.ink).at(4, 19).size(w - 8, 1)
        }.area("button", value: Self.backMove, label: words, hover: nil, press: AreaLook(opacity: 0.6), sound: "sounds/tap.wav")
    }

    private func chipFill(_ verdict: Verdict) -> Color {
        switch verdict {
        case .win: .win
        case .loss: Paint.lostSoft
        case .draw: Paint.inset
        }
    }

    private func chipInk(_ verdict: Verdict) -> Color { verdict == .win ? Paint.white : Paint.ink }

    /// The award on the card's edge: quiet, and true of what happened. Two people: a winner is named in neutral, so no picture says whose loss it was.
    private func markArt(verdict: Verdict, tone: Tone) -> Node {
        let art: String = switch verdict {
        case .win: ctx.entry.solo ? "art/result-solved.webp" : "art/result-win.webp"
        case .loss: "art/result-loss.webp"
        case .draw: "art/result-draw.webp"
        }
        return Node.box("end.mark", w: 80, h: 80) {
            if tone == .info { Node.art("art/result-draw.webp", w: 80, h: 80) } else { Node.art(art, w: 80, h: 80) }
        }
    }

    private func appear(_ id: String) {
        guard ctx.fresh, !wasEnded else { return }
        anims.append(.keys(id, [["t": 0, "opacity": 0], ["t": 1, "opacity": 1]], ms: 400, ease: "spring"))
    }

    private func popMark() {
        guard ctx.fresh, !wasEnded else { return }
        anims.append(.keys("end.mark", [["t": 0, "scale": 0.6], ["t": 1, "scale": 1]], ms: 400, ease: "spring"))
    }

    private var wasEnded: Bool { ctx.previous?.resultPart != nil }

    /// The figure in a fixed order. "7 / 10" reads left to right in every language. "3 – 2" (the person's, then the companion's) follows
    /// the "You vs" bar's sides, which follow the layout, so the text's own direction never puts a number on the wrong side.
    static func isolated(_ figure: String, rtl: Bool) -> String {
        if figure.contains("/") { return "\u{2066}\(figure)\u{2069}" }
        guard figure.contains(" – ") else { return figure }
        return (rtl ? "\u{2067}" : "\u{2066}") + figure + "\u{2069}"
    }
}
