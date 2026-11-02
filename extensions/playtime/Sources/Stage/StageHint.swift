import SidefolkExtensionKit

// The line of keys under the board, on a card with a lightbulb (HintRow): what to press first in ink, the rest quieter.
extension BoardDrawing {
    /// In Playtime's words now, as they were in the panel's.
    var footer: String {
        var parts: [String] = []
        if let a = board.answersPart, !a.locked {
            let caps = Self.keyCaps(a.tiles)
            parts.append(a.tiles.contains(where: { $0.art != nil || $0.key != nil })
                ? L("{keys} to play", ["keys": caps.joined(separator: " ")])
                : L("1–{n} to answer", ["n": a.tiles.count]))
        }
        if let hint = partsFooter { parts.append(hint) }
        if let primary = board.primary { parts.append(L("Return: {label}", ["label": primary.label])) }
        for b in board.buttons where b.key != nil && !b.disabled { parts.append("\(b.key!.uppercased()): \(b.label)") }
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

    static func hintCard(_ text: String, width: Double) -> PartBlock {
        let parts = text.components(separatedBy: " · ")
        let room = width - 24 - 20 - 8
        let whole = TextFit.height(text, size: 12, weight: "semibold", width: room, lines: 2)
        let wide = Swift.min(TextFit.width(text, size: 12, weight: "semibold"), room)
        let height = Swift.max(whole, 20) + 12
        let x = (width - wide - 28) / 2
        let rest = parts.count > 1 ? " · " + parts.dropFirst().joined(separator: " · ") : ""
        return PartBlock(.box("hint", w: width, h: height) {
            Node.gameCard(corner: 15, alpha: 0.94, w: width, h: height).id("hint.card")
            Node.art("art/game-bulb.webp", x: x, y: (height - 20) / 2, w: 20, h: 20)
            Node.runs([(parts[0], Color.ink, nil), (rest, Color.inkMuted, nil)], size: 12, weight: "semibold", design: "rounded", align: "leading", lines: 2)
                .id("hint.words").at(x + 28, 6).size(wide + 1, height - 12)
        }, height: height)
    }
}
