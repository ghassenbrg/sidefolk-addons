import SidefolkExtensionKit

// The end card (GameResultView): the result as one unit (an award mark beside the score, who won in words, the game's line), a
// small new-best chip, facts, what to do next with "Back to games" beside it, and the level for the next game. Calm and flat:
// the mark is the only picture, and it appears once.
extension BoardDrawing {
    func endCard(figure: String, line: String?, ribbon: String?, tone: Tone, facts: [(String, String)], actions: [GameButton]) -> PartBlock {
        let width = Self.inner, room = width - 24
        let verdict = Verdict(tone: tone)
        var y = 12.0
        var nodes: [Node] = []
        if let ribbon {
            // A new best: a small chip in the sun's colour, above the result it crowns.
            let w = TextFit.width(ribbon, size: 11.5, weight: "semibold") + 24 + 16
            nodes.append(.box("end.ribbon", x: (width - w) / 2, y: y, w: w, h: 24) {
                Node.capsule(fill: Paint.clear("#FFC93C", 0.18), stroke: Paint.clear("#FFC93C", 0.45), lineWidth: 1).size(w, 24)
                Node.symbol("star.fill", color: Paint.sun).symbolLook(mono: true).at(12, 6).size(12, 12)
                Node.words(ribbon, size: 11.5, weight: "semibold", design: "default", x: 28, w: w - 40, h: 24)
            })
            y += 24 + 8
            appear("end.ribbon")
        }
        let hero = endHero(figure: figure, line: line, verdict: verdict, tone: tone, width: room)
        nodes.append(hero.node.at(12, y))
        y += hero.height + 8
        if !facts.isEmpty {
            let row = factsRow(facts, width: room, id: "end.facts")
            nodes.append(row.node.at(12, y))
            y += row.height + 8
        }
        // What to do next in one row; when its words don't fit there, the first action takes its own row, never cut.
        let back = GameButton(L("Back to games"), move: Self.backMove, style: .secondary, symbol: "square.grid.2x2.fill")
        let backW = 54.0
        let wanted = actions.reduce(0) { $0 + buttonWidth($1, flat: true) + 8 }
        if wanted + backW <= room {
            nodes.append(buttonRow(actions, id: "end.actions", width: room - backW - 8, flat: true).node.at(12, y))
            nodes.append(backSquare(back, x: 12 + room - backW, y: y, w: backW))
            y += 42 + 8
        } else {
            nodes.append(buttonRow(Array(actions.prefix(1)), id: "end.first", width: room, flat: true).node.at(12, y))
            y += 42 + 6
            let rest = Array(actions.dropFirst())
            if !rest.isEmpty { nodes.append(buttonRow(rest, id: "end.rest", width: room - backW - 8, flat: true).node.at(12, y)) }
            nodes.append(backSquare(back, x: 12 + room - backW, y: y, w: backW))
            y += 42 + 8
        }
        // The small choices an end card offers (the level for the next game), at its foot.
        for case .choice(let name, let label, .segmented, let options, let selected) in board.parts {
            let row = choice(name: name, label: label, style: .segmented, options: options, selected: selected, compact: true, width: room)
            nodes.append(row.node.at(12, y))
            y += row.height + 8
        }
        let height = y - 8 + 12
        return PartBlock(.box("end", w: width, h: height) {
            Node.gameCard(corner: 22, alpha: 0.98, w: width, h: height).id("end.card")
            nodes
        }, height: height)
    }

    /// What the frame's Back does, as a square on the card.
    static let backMove = "__back"

    private func backSquare(_ back: GameButton, x: Double, y: Double, w: Double) -> Node {
        let s = 22.0
        return Node.box("end.back", x: x, y: y, w: w, h: 42) {
            Node.rect(fill: Paint.card, stroke: Paint.edge, lineWidth: 1, corner: 14).size(w, 42)
            Node.symbol(back.symbol ?? "", color: .ink).symbolLook(weight: "bold", mono: true).at((w - s) / 2, (42 - s) / 2).size(s, s)
        }.area("button", value: back.move, label: back.label, hover: nil, press: AreaLook(scale: 0.97), sound: "sounds/tap.wav")
    }

    private func endHero(figure: String, line: String?, verdict: Verdict, tone: Tone, width: Double) -> PartBlock {
        let textRoom = width - 20 - 58 - 12
        // Who won, in Playtime's words: said only for a win or a loss (a draw's card speaks for itself). A puzzle is solved, not won.
        let title: String? = switch verdict {
        case .win: ctx.entry.solo ? L("Solved!") : L("You win!")
        case .loss: L("{name} wins!", ["name": "{companion}"])
        case .draw: nil
        }
        let said = board.promptPart?.text
        let shownLine = line == said ? nil : line
        let titleH = title.map { TextFit.height($0, size: 18, weight: "heavy", width: textRoom, lines: 2) } ?? 0
        let lineH = shownLine.map { TextFit.height($0, size: 12, weight: "semibold", width: textRoom, lines: 3) } ?? 0
        let texts = 36 + (title == nil ? 0 : 2 + titleH) + (shownLine == nil ? 0 : 2 + lineH)
        let height = max(58, texts) + 20
        var y = (height - texts) / 2
        let inner = Node.box("end.hero.words", x: 10 + 58 + 12, w: textRoom, h: height) {
            Node.words(Self.isolated(figure, rtl: ctx.rtl), size: 30, weight: "black", color: verdict == .draw ? .ink : verdict.color, minScale: 0.6, y: y, w: textRoom, h: 36)
            if let title { Node.words(title, size: 18, weight: "heavy", lines: 2, minScale: 0.8, y: y + 38, w: textRoom, h: titleH) }
            if let shownLine {
                Node.words(shownLine, size: 12, weight: "semibold", color: .inkMuted, valign: "top", lines: 3, y: y + 38 + (title == nil ? 0 : titleH + 2), w: textRoom, h: lineH)
            }
        }
        y = 0
        appear("end.hero.words")
        popMark()
        return PartBlock(.box("end.hero", w: width, h: height) {
            Node.rect(fill: Paint.inset, corner: 16).size(width, height)
            markTile(verdict: verdict, tone: tone).at(10, (height - 58) / 2)
            inner
        }, height: height)
    }

    /// The award mark: Playtime's trophy for the person's win (with the crown that goes with the colour), else the verdict's symbol, on a
    /// soft tile of its colour. Two people: a winner is named with a trophy in neutral ink, so no colour says whose loss it was.
    private func markTile(verdict: Verdict, tone: Tone) -> Node {
        let tint: Color = switch verdict {
        case .win: Paint.clear("#FFC93C", 0.18)
        case .loss: .adaptive(light: "#B07A522E", dark: "#D9A9822E")
        case .draw: Color.inkMuted.tuned(alpha: 0.18)
        }
        let symbol = verdict == .loss ? "hand.thumbsup.fill" : "equal.circle.fill"
        return Node.box("end.mark", w: 58, h: 58) {
            Node.rect(fill: tint, corner: 15).size(58, 58)
            if verdict == .win {
                Node.art("art/game-trophy.png", x: 8, y: 8, w: 42, h: 42)
                Node.ellipse(fill: Paint.card).at(38, 3).size(16, 16)
                Node.symbol("crown.fill", color: .win).symbolLook(weight: "bold", mono: true).at(40.5, 5.5).size(11, 11)
            } else if tone == .info {
                Node.symbol("trophy.fill", color: .ink).symbolLook(weight: "bold", mono: true).at(14, 14).size(30, 30)
            } else {
                Node.symbol(symbol, color: verdict.color).symbolLook(weight: "bold", mono: true).at(14, 14).size(30, 30)
            }
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
