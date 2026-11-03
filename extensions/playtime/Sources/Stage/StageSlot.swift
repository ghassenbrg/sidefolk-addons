import SidefolkExtensionKit

// One place of one height under a toy, for what comes and goes during a game: the next round's button, who plays (until the first move), a secret, a best time. Drawn empty when
// there is nothing to say, so the toy above never moves.
extension BoardDrawing {
    static let slotHeight = 46.0

    /// A row of `height`, whatever it holds: a note if there is one, else the buttons of the moment beside who plays, else a quiet number.
    func slotRow(y: Double, height: Double = BoardDrawing.slotHeight) -> Node {
        let width = Self.inner
        return .box("slot", y: y, w: width, h: height) {
            if let note = board.parts.compactMap({ part -> String? in if case .note(let text, _, _) = part { text } else { nil } }).first {
                slotNote(note, width: width, height: height)
            } else {
                let row = board.parts.compactMap { part -> GameButton? in if case .button(let b) = part, !b.companion { b } else { nil } }
                let who = board.parts.compactMap { part -> (String, [ChoiceOption], String?)? in
                    if case .choice(let name, _, _, let options, let selected) = part, name == "opponent" { (name, options, selected) } else { nil }
                }.first
                let chooser = who.map { choice(name: $0.0, label: nil, style: .segmented, options: $0.1, selected: $0.2, compact: false, width: row.isEmpty ? 250 : 190) }
                if let chooser {
                    chooser.node.at(row.isEmpty ? (width - 250) / 2 : 0, (height - chooser.height) / 2)
                }
                if !row.isEmpty {
                    let used = chooser == nil ? 0 : 198.0
                    let buttons = buttonRow(row, id: "dock", width: width - used)
                    buttons.node.at(used, (height - buttons.height) / 2)
                } else if chooser == nil, let fact = board.parts.compactMap({ part -> (String, String)? in if case .facts(let items) = part { items.first } else { nil } }).first {
                    slotFact(fact, width: width, height: height)
                }
            }
        }
    }

    /// A few words on a small card with their bulb: they shrink rather than grow it.
    private func slotNote(_ text: String, width: Double, height: Double) -> Node {
        .box("slot.note", w: width, h: height) {
            Node.rect(fill: Paint.card(0.94), stroke: Paint.edge, lineWidth: 1, corner: 12).size(width, height)
            Node.symbol("lightbulb.fill", color: Paint.sun).symbolLook().at(10, (height - 16) / 2).size(16, 16)
            Node.words(text, size: 12.5, weight: "semibold", lines: 3, minScale: 0.62, design: "rounded", x: 32, y: 3, w: width - 42, h: height - 6)
        }
    }

    /// A number the board keeps (a best time): quiet, on a soft pill in the middle.
    private func slotFact(_ fact: (String, String), width: Double, height: Double) -> Node {
        let words = fact.0 + "  " + fact.1
        let w = Swift.min(TextFit.width(words, size: 13, weight: "bold") + 28, width)
        return Node.box("slot.fact", x: (width - w) / 2, y: (height - 26) / 2, w: w, h: 26) {
            Node.capsule(fill: Paint.card(0.82)).size(w, 26)
            Node.words(words, size: 13, weight: "bold", color: Paint.inkSoft, align: "center", minScale: 0.7, x: 10, w: w - 20, h: 26).textLook(tabular: true)
        }
    }
}
