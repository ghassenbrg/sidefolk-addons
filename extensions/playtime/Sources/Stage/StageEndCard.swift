import SidefolkExtensionKit

// The end card (GameResultView): the result as one unit (an award mark beside the score, who won in words, the game's line), a
// small new-best chip, facts, what to do next with "Back to games" beside it, and the level for the next game. Calm and flat:
// the mark is the only picture, and it appears once.
extension BoardDrawing {
    func endCard(figure: String, line: String?, ribbon: String?, tone: Tone, facts: [(String, String)], actions: [GameButton]) -> PartBlock {
        if board.puzzleDrawing != nil { return puzzleSheet(time: figure, ribbon: ribbon, facts: facts, actions: actions) }
        let width = Self.inner, verdict = Verdict(tone: tone), friendly = board.endFriendly
        // Two people: the line names the winner, so it is the title. Played alone, nobody beat anyone: the companion only watched.
        let two = tone == .info
        let earned: String = switch verdict {
        case .win: ctx.entry.solo ? L("Solved!") : L("You win!")
        case .loss: board.scorePart == nil ? L("Not this time") : L("{name} wins!", ["name": "{companion}"])
        case .draw: L("A draw")
        }
        let title = board.endTitle ?? (two ? line ?? earned : earned)
        let room = width - 56
        let said = line?.isEmpty == true || two ? nil : line
        let shownLine = said == title ? nil : said
        // A number the board kept (a best time) belongs with the card's facts, not floating over it.
        let kept = board.parts.flatMap { part -> [(String, String)] in if case .facts(let items) = part { items } else { [] } }
        let fact = (facts + kept).map { "\($0.0) \($0.1)" }.joined(separator: " · ")
        let lineH = shownLine.map { TextFit.height($0, size: 15, weight: "bold", width: room, lines: 2) } ?? 0
        var cy = 14.0
        var inCard: [Node] = []
        inCard.append(Node.words(title, size: 38, weight: "black", align: "center", minScale: 0.5, x: 20, y: cy, w: width - 40, h: 46).id("end.title"))
        cy += 48
        if !figure.isEmpty {
            let figureW = Swift.min(TextFit.width(figure, size: 22, weight: "black") + 40, room)
            inCard.append(Node.capsule(fill: chipFill(verdict, friendly: friendly)).id("end.chip").at((width - figureW) / 2, cy).size(figureW, 34))
            inCard.append(Node.words(Self.isolated(figure, rtl: ctx.rtl), size: 22, weight: "black", color: chipInk(verdict, friendly: friendly), align: "center", minScale: 0.6, x: (width - figureW) / 2 + 8, y: cy, w: figureW - 16, h: 34).textLook(tabular: true).id("end.figure"))
            cy += 40
        }
        if let ribbon {
            let w = TextFit.width(ribbon, size: 12, weight: "bold") + 24
            inCard.append(Node.capsule(fill: Paint.lilac).id("end.ribbon").at((width - w) / 2, cy).size(w, 22))
            inCard.append(Node.words(ribbon, size: 12, weight: "bold", align: "center", x: (width - w) / 2, y: cy, w: w, h: 22))
            cy += 26
            appear("end.ribbon")
        }
        if let shownLine {
            inCard.append(Node.words(shownLine, size: 15, weight: "bold", align: "center", lines: 2, x: 28, y: cy, w: room, h: lineH))
            cy += lineH + 4
        }
        if !fact.isEmpty {
            inCard.append(Node.words(fact, size: 12, weight: "semibold", color: Paint.inkSoft, align: "center", minScale: 0.6, x: 24, y: cy, w: width - 48, h: 18))
            cy += 20
        }
        let cardH = cy + 12
        // What comes next, first: the card takes its size, and the companion what is left, so nothing is cut at any length.
        var next: [Node] = []
        var y = 0.0
        // The small choices an end card offers (the level for the next game), first: three pills say what they are.
        for case .choice(let name, _, .segmented, let options, let selected) in board.parts {
            let row = choice(name: name, label: nil, style: .segmented, options: options, selected: selected, compact: true, width: width - 120)
            next.append(row.node.at(60, y))
            y += row.height + 10
        }
        for (i, action) in actions.enumerated() {
            let block = buttonRow([action], id: "end.action.\(i)", width: width - 40, flat: i > 0)
            next.append(block.node.at(20, y))
            y += block.height + 8
        }
        next.append(backLink(y: y, width: width))
        y += 24
        // Companion and award stand on the card's top edge, as 19 draws them: as large as the room lets them be.
        let figureRow = Swift.min(Swift.max(playRoom - endNotesHeight - cardH - 14 - y, 56), 148)
        let figureH = figureRow + 10, figureW2 = Swift.min(figureH * 0.86, 138)
        let markSide = Swift.min(84, figureRow - 2)
        endFigure("end.companion", x: 8, y: 0, verdict: verdict, friendly: friendly)
        var nodes: [Node] = [
            Node.felt("end.mat", x: -6, y: figureRow + 30, w: width + 12, h: cardH - 14, corner: 26, stitch: false),
            Node.rect(fill: Paint.card, stroke: Paint.edge, lineWidth: 1, corner: 22).id("end.card").at(14, figureRow).size(width - 28, cardH).shadow(Paint.black8, radius: 6, dx: 0, dy: 3),
            Node.rect(stroke: Paint.clear("#8E72B5", 0.5), lineWidth: 1.25, corner: 18, dash: [5, 4]).id("end.stitch").at(19, figureRow + 5).size(width - 38, cardH - 10),
            Node.companion(pose: friendly ? "success" : pose).figure(bottom: true).id("end.companion").anchor(0.5, 1).at(8, 0).size(figureW2, figureH),
        ]
        if !board.plainCard { nodes.insert(markArt(verdict: verdict, tone: tone, friendly: friendly, side: markSide).at((width - markSide) / 2 + 14, figureRow - markSide + 4), at: nodes.count - 1) }
        nodes.append(.box("end.words", y: figureRow, w: width, h: cardH) { inCard })
        let top = figureRow + cardH + 14
        nodes.append(.box("end.next", y: top, w: width, h: y) { next })
        y += top
        appear("end.words")
        if !board.plainCard { popMark() }
        return PartBlock(.box("end", w: width, h: y) { nodes }, height: y)
    }

    /// What else stands above an end card: a note the game has left.
    private var endNotesHeight: Double {
        board.parts.reduce(0.0) { sum, part in
            if case .note(let text, let title, let tone) = part { return sum + note(text, title: title, tone: tone).height + 8 }
            return sum
        }
    }

    /// A puzzle solved: a sheet from the notebook, with the companion delighted beside the time, how it went, the board as it was finished, and what next. Nothing but the true numbers.
    private func puzzleSheet(time: String, ribbon: String?, facts: [(String, String)], actions: [GameButton]) -> PartBlock {
        let width = Self.inner, height = playRoom, pad = 22.0
        let right = 126.0, room = width - right - 16
        // The time is the headline, so the rest of what's known goes in one line under it.
        let how = facts.dropFirst().map { "\($0.0) \($0.1)" }.joined(separator: " · ")
        let timeW = Swift.min(TextFit.width(time, size: 36, weight: "black") + 4, room)
        // What next is pinned to the foot of the sheet, and the board takes what's left between.
        let footH = 42.0 + 12 + 34
        let foot = height - pad + 4 - footH
        let top = 176.0
        let mini = solvedBoard(room: foot - top - 8)
        var chips: [Node] = []
        // Three pills say what they are, as 24 draws them.
        for case .choice(let name, _, .segmented, let options, let selected) in board.parts {
            chips.append(choice(name: name, label: nil, style: .segmented, options: options, selected: selected, compact: true, width: width - 140).node.at(70, foot))
        }
        let primary = actions.first
        let back = GameButton(L("Back to games"), move: Self.backMove, style: .secondary)
        endFigure("end.companion", x: 6, y: 20, verdict: .win, friendly: false)
        appear("end.words")
        popMark()
        return PartBlock(.box("end", w: width, h: height) {
            Node.rect(fill: Paint.lilacDeep, corner: 26).id("sheet.edge").size(width, height).shadow(Paint.clear("#3A2A55", 0.2), radius: 6, dx: 0, dy: 3)
            Node.rect(fill: Paint.card, corner: 22).id("sheet.paper").at(5, 5).size(width - 10, height - 10)
            for i in 0..<11 {
                Node.ellipse(fill: Paint.inset, stroke: Paint.edge, lineWidth: 1).at(26 + Double(i) * 30.5, 12).size(9, 9)
            }
            Node.companion(pose: pose).figure(bottom: true).id("end.companion").anchor(0.5, 1).at(6, 20).size(124, 130)
            Node.box("end.words", w: width, h: 170) {
                Node.words(L("Solved!"), size: 38, weight: "black", minScale: 0.6, x: right, y: 22, w: room - 56, h: 48).id("end.title")
                Node.words(Self.isolated(time, rtl: ctx.rtl), size: 36, weight: "black", minScale: 0.6, x: right, y: 68, w: timeW, h: 44).textLook(tabular: true).id("end.figure")
                if let ribbon {
                    let w = Swift.min(TextFit.width(ribbon, size: 12, weight: "bold") + 20, room - timeW - 6)
                    Node.capsule(fill: Color.win.tuned(alpha: 0.2)).id("end.ribbon").at(right + timeW + 6, 78).size(w, 24)
                    Node.words(ribbon, size: 12, weight: "bold", align: "center", minScale: 0.7, x: right + timeW + 6, y: 78, w: w, h: 24)
                }
                if let eyebrow = board.promptPart?.eyebrow {
                    Node.words(eyebrow, size: 13, weight: "bold", minScale: 0.7, x: right, y: 112, w: room, h: 20)
                }
                Node.rect(fill: Paint.edge).at(pad, 152).size(width - 2 * pad, 1)
                if !how.isEmpty {
                    let w = Swift.min(TextFit.width(how, size: 13, weight: "bold") + 20, width - 2 * pad)
                    Node.rect(fill: Paint.card).at((width - w) / 2, 142).size(w, 20)
                    Node.words(how, size: 13, weight: "bold", align: "center", minScale: 0.7, x: (width - w) / 2, y: 142, w: w, h: 20)
                }
            }
            Node.art("art/result-solved.webp", x: width - 80, y: 14, w: 66, h: 66).id("end.mark")
            // The clip that holds the sheet, as 24 draws it.
            Node.box("sheet.clip", x: width / 2 - 20, y: -14, w: 40, h: 34) {
                Node.ellipse(stroke: Paint.clear("#C49A6C", 0.95), lineWidth: 2.5).at(9, 0).size(22, 24)
                Node.rect(fill: Paint.lilacDeep, corner: 5).at(0, 13).size(40, 20).shadow(Paint.clear("#3A2A55", 0.25), radius: 2, dx: 0, dy: 1)
            }
            if let mini { mini.node.at(((width - mini.width) / 2).rounded(), (top + (foot - top - mini.height) / 2).rounded()) }
            chips
            if let primary { buttonRow([primary], id: "end.action.0", width: (width - 2 * pad - 10) * 0.54).node.at(pad, height - pad + 4 - 44) }
            buttonRow([back], id: "end.back.row", width: (width - 2 * pad - 10) * 0.46, flat: true).node.at(pad + (width - 2 * pad - 10) * 0.54 + 10, height - pad + 4 - 43)
        }, height: height)
    }

    /// What the frame's Back does, as a link under the actions.
    static let backMove = "__back"

    private func backLink(y: Double, width: Double) -> Node {
        let words = L("Back to games"), w = TextFit.width(words, size: 13, weight: "bold") + 8
        return Node.box("end.back", x: (width - w) / 2, y: y, w: w, h: 22) {
            // It may stand on any scene, so it brings its own ground.
            Node.capsule(fill: Paint.card(0.82)).id("end.back.ground").at(-8, -2).size(w + 16, 25)
            Node.words(words, size: 13, weight: "bold", align: "center", w: w, h: 20)
            Node.rect(fill: Paint.ink).at(4, 19).size(w - 8, 1)
        }.area("button", value: Self.backMove, label: words, hover: nil, press: AreaLook(opacity: 0.6), sound: "sounds/tap.wav")
    }

    private func chipFill(_ verdict: Verdict, friendly: Bool) -> Color {
        if friendly { return Paint.lilac }
        return switch verdict {
        case .win: .win
        case .loss: Paint.lostSoft
        case .draw: Paint.inset
        }
    }

    private func chipInk(_ verdict: Verdict, friendly: Bool) -> Color { verdict == .win && !friendly ? Paint.white : Paint.ink }

    /// The award on the card's edge: quiet, and true of what happened. Two people: a winner is named in neutral, so no picture says whose loss it was. A friendly fact gets the paw: it was nobody's loss.
    private func markArt(verdict: Verdict, tone: Tone, friendly: Bool, side: Double) -> Node {
        let art: String = if friendly { "art/result-loss.webp" } else if tone == .info { "art/result-draw.webp" } else {
            switch verdict {
            case .win: ctx.entry.solo ? "art/result-solved.webp" : "art/result-win.webp"
            case .loss: "art/result-loss.webp"
            case .draw: "art/result-draw.webp"
            }
        }
        return Node.box("end.mark", w: side, h: side) { Node.art(art, w: side, h: side) }.anchor(0.5, 0.5)
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
