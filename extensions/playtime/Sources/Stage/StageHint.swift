import SidefolkExtensionKit

// The line of keys under the board, on a card with a lightbulb (HintRow): what to press first in ink, the rest quieter.
extension BoardDrawing {
    /// In Playtime's words now, as they were in the panel's.
    var footer: String {
        var parts: [String] = []
        if let a = board.answersPart, !a.locked {
            let caps = Self.keyCaps(a.tiles)
            parts.append(a.tiles.contains(where: { $0.key != nil })
                ? L("{keys} to play", ["keys": caps.joined(separator: " ")])
                : L("1–{n} to answer", ["n": a.tiles.count]))
        }
        if let hint = partsFooter { parts.append(hint) }
        if let primary = board.primary { parts.append(L("Return: {label}", ["label": primary.label])) }
        // A puzzle's line stays one length as Undo comes and goes: its button says what it is.
        for b in board.buttons where b.key != nil && !b.disabled && !(board.hasPuzzle && b.move == "undo") { parts.append("\(b.key!.uppercased()): \(b.label)") }
        if ctx.local.dragFrom == nil { parts.append(L("Esc to close")) }
        return parts.joined(separator: " · ")
    }

    /// The keys a part takes.
    private var partsFooter: String? {
        if let own = padsFooter ?? cupsFooter ?? reflexFooter ?? sticksFooter ?? puzzleFooter { return own }
        if let g = board.gridPart, !g.locked { return g.numpad ? L("1–9 to play") : L("Arrows and Return to pick") }
        if let n = board.numberPart, !n.locked { return L("Type a number, Return to guess") }
        if let k = board.keysPart, !k.locked { return k.mode == "spell" ? L("Type a word, Return to try") : L("Type a letter") }
        return nil
    }

    func hintRow() -> PartBlock { Self.hintCard(footer, width: Self.inner) }

    /// One quiet line, always one line, in one place at the foot of the panel.
    static func hintCard(_ text: String, width: Double) -> PartBlock {
        let w = Swift.min(TextFit.width(text, size: 11.5, weight: "semibold") + 24, width)
        return PartBlock(.box("hint", w: width, h: 20) {
            Node.capsule(fill: Paint.card(0.72)).id("hint.back").at((width - w) / 2, 0).size(w, 20)
            Node.words(text, size: 11.5, weight: "semibold", color: Paint.inkSoft, align: "center", minScale: 0.62, design: "rounded", x: (width - w) / 2 + 8, w: w - 16, h: 20).id("hint.words")
        }, height: 20)
    }
}
