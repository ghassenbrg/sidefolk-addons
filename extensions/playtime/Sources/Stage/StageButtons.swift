import SidefolkExtensionKit

// A game's button as a toy (ChunkyButtonStyle): a raised face on a darker lip that sinks when pressed. The primary is the
// app's accent (a game's colour is decoration, never what a button means), the secondary the games' card on its blue lip, the
// plain one a soft pill. Flat on the end card, where the result is the one thing that stands up.
extension BoardDrawing {
    private func metrics(_ b: GameButton, flat: Bool) -> (size: Double, weight: String, height: Double) {
        b.style == .plain ? (13, "bold", 36) : (flat ? (15, "bold", 42) : (16, "heavy", 46))
    }

    /// The room a button's words want.
    func buttonWidth(_ b: GameButton, flat: Bool) -> Double {
        let m = metrics(b, flat: flat)
        return TextFit.width(b.label, size: m.size, weight: m.weight) + (b.symbol == nil ? 0 : 6 + m.size * 1.2) + 32
    }

    /// Buttons share the row equally, so one changing its words ("Hint", "Do it") moves nothing; words shrink to fit (German's Undo and Start over). A disabled one keeps its place.
    func buttonRow(_ buttons: [GameButton], id: String, width: Double = BoardDrawing.inner, flat: Bool = false, leading: (node: Node, width: Double)? = nil) -> PartBlock {
        let gap = 8.0, used = leading.map { $0.width + gap } ?? 0
        // A lone quiet button keeps to its words, in the middle of its row.
        let lone = quietHints && leading == nil && buttons.count == 1 && buttons[0].style == .plain
        let w = lone ? Swift.min(buttonWidth(buttons[0], flat: flat), width) : buttons.isEmpty ? 0 : (width - used - gap * Double(buttons.count - 1)) / Double(buttons.count)
        let height = buttons.map { metrics($0, flat: flat).height }.max() ?? 36
        var x = lone ? (width - w) / 2 : used
        var nodes: [Node] = []
        if let leading { nodes.append(leading.node.at(0, (height - 28) / 2)) }
        for (i, b) in buttons.enumerated() {
            nodes.append(button(b, id: "\(id).\(i)", x: x, y: (height - metrics(b, flat: flat).height) / 2, w: w, flat: flat))
            x += w + gap
            // Return presses the main button; a letter its own. A key's id is a plain token.
            let keyId = "\(id)_\(i)".replacingOccurrences(of: ".", with: "_")
            if !b.disabled {
                if b.style == .primary {
                    keys.append(StageKey(key: "return", id: keyId + "_return", area: "button", value: b.move))
                    keys.append(StageKey(key: "space", id: keyId + "_space", area: "button", value: b.move))
                }
                if let key = b.key { keys.append(StageKey(key: key, id: keyId + "_key", area: "button", value: b.move)) }
            }
        }
        return PartBlock(.box(id, w: width, h: height) { nodes }, height: height)
    }

    /// A capsule: filled navy for the one thing to do, outlined otherwise. Pressing it sinks it a little.
    func button(_ b: GameButton, id: String, x: Double, y: Double = 0, w: Double, flat: Bool) -> Node {
        let m = metrics(b, flat: flat)
        let filled = b.style == .primary || (!quietHints && (b.move == "hint" || b.move == "do_hint"))
        let ink: Color = filled ? Paint.onAction : Paint.ink
        // Words first: a narrow button lets its symbol go rather than cut its label.
        let wanted = TextFit.width(b.label, size: m.size, weight: m.weight) + 2
        let symbol = wanted + 24 + 6 + m.size * 1.2 <= w ? b.symbol : nil
        let symbolW = symbol == nil ? 0 : m.size * (symbol == "eye.slash" ? 1.45 : 1.2)
        let textW = Swift.min(wanted, Swift.max(w - 16 - (symbol == nil ? 0 : 6 + symbolW), 10))
        let startX = (w - textW - (symbol == nil ? 0 : 6 + symbolW)) / 2
        var group = Node.box(id, x: x, y: y, w: w, h: m.height) {
            if filled {
                Node.capsule(fill: Paint.action).id(id + ".fill").size(w, m.height).shadow(Paint.clear("#14275A", 0.22), radius: 4, dx: 0, dy: 2)
            } else {
                Node.capsule(fill: Paint.card, stroke: Paint.ink, lineWidth: 1.5).id(id + ".fill").at(0.75, 0.75).size(w - 1.5, m.height - 1.5)
            }
            Node.words(b.label, size: m.size, weight: m.weight, color: ink, align: "center", minScale: 0.65, x: startX, w: textW, h: m.height)
            if let symbol {
                Node.symbol(symbol, color: ink).symbolLook(weight: m.weight).at(startX + textW + 6, (m.height - m.size * 1.2) / 2).size(symbolW, m.size * 1.2)
            }
        }
        .area("button", value: b.move, label: b.label, disabled: b.disabled, hover: AreaLook(scale: 1.015), press: AreaLook(scale: 0.97, dy: 1), sound: "sounds/tap.wav")
        if b.disabled { group = group.opacity(0.45) }
        return group
    }

    /// A lightbulb, a seal or a mark, the words on the sun's tint.
    func note(_ text: String, title: String?, tone: Tone) -> PartBlock {
        let room = Self.inner - 24 - 25
        let symbol = tone == .info || tone == .neutral ? "lightbulb.fill" : tone == .good ? "checkmark.seal.fill" : "exclamationmark.circle.fill"
        let titleH = title == nil ? 0 : TextFit.lineHeight(11.5, "semibold") + 2
        let textH = TextFit.height(text, size: 14, width: room)
        let height = 24 + titleH + textH
        return PartBlock(.box("note", w: Self.inner, h: height) {
            Node.rect(fill: Paint.card(0.96), stroke: Paint.edge, lineWidth: 1, corner: 14).id("note.card").size(Self.inner, height)
            Node.rect(fill: Paint.clear("#FFC93C", 0.14), corner: 14).id("note.tint").size(Self.inner, height)
            // Two-coloured, as the panel's: its mark in the card's colour, cut out of the sun's.
            Node.symbol(symbol, color: symbol.hasSuffix("circle.fill") ? Paint.card : Paint.sun).symbolLook(secondary: symbol.hasSuffix("circle.fill") ? Paint.sun : nil).at(12, 12).size(17, 17)
            if let title { Node.words(title, size: 11.5, weight: "semibold", design: "default", x: 37, y: 12, w: room, h: titleH) }
            Node.words(text, size: 14, weight: "regular", valign: "top", lines: 40, design: "default", x: 37, y: 12 + titleH, w: room, h: textH)
        }, height: height)
    }

    /// Small numbers side by side on their insets.
    func factsRow(_ facts: [(String, String)], width: Double = BoardDrawing.inner, id: String = "facts") -> PartBlock {
        let gap = 8.0, w = (width - gap * Double(max(facts.count - 1, 0))) / Double(max(facts.count, 1))
        let labelH = facts.map { TextFit.height($0.0, size: 11.5, width: w - 8, lines: 2) }.max() ?? 14
        let height = 8 + 21 + 2 + labelH + 8
        return PartBlock(.box(id, w: width, h: height) {
            for (i, f) in facts.enumerated() {
                Node.box("\(id).\(i)", x: Double(i) * (w + gap), w: w, h: height) {
                    Node.rect(fill: Paint.inset, corner: 12).size(w, height)
                    Node.words(f.1, size: 17, weight: "bold", align: "center", x: 4, y: 8, w: w - 8, h: 21)
                    Node.words(f.0, size: 11.5, weight: "regular", color: .inkMuted, align: "center", lines: 2, design: "default", x: 4, y: 31, w: w - 8, h: labelH)
                }
            }
        }, height: height)
    }

    /// One of a few options, as cards or as segments on a lilac track: picked is navy. `labelWidth` lines a column of them up under each other.
    func choice(name: String, label: String?, style: ChoiceStyle, options: [ChoiceOption], selected: String?, compact: Bool, width: Double = BoardDrawing.inner, labelWidth: Double? = nil, disabled: Bool = false) -> PartBlock {
        let id = "choice.\(name)"
        var y = 0.0
        var nodes: [Node] = []
        if let label, !compact {
            let w = min(TextFit.width(label, size: 11.5, weight: "semibold") + 16, width)
            nodes.append(Node.capsule(fill: Paint.card(0.94)).id(id + ".pill").size(w, 18))
            nodes.append(Node.words(label, size: 11.5, weight: "semibold", color: Paint.inkSoft, align: "center", design: "default", w: w, h: 18))
            y += 18 + 8
        }
        switch style {
        case .cards:
            let (block, height) = choiceCards(name: name, options: options, selected: selected, width: width)
            nodes.append(block.at(0, y))
            y += height
        case .segmented:
            var x = 0.0
            if compact, let label {
                let w = labelWidth ?? TextFit.width(label, size: 12.5, weight: "heavy")
                nodes.append(Node.capsule(fill: Paint.card(0.72)).id(id + ".name").at(0, y + 3).size(w - 6, 24))
                nodes.append(Node.words(label, size: 12.5, weight: "heavy", align: "center", minScale: 0.7, x: 3, y: y, w: w - 12, h: 30))
                x = w
            }
            let rowW = width - x, h = 30.0
            let segW = (rowW - 6 - 2 * Double(options.count - 1)) / Double(max(options.count, 1))
            nodes.append(Node.capsule(fill: Paint.lilac, stroke: Paint.clear("#8E72B5", 0.25), lineWidth: 1).id(id + ".track").at(x, y).size(rowW, h))
            for (i, o) in options.enumerated() {
                let on = selected == o.value
                let segId = "\(id).\(o.value)"
                nodes.append(Node.box(segId, x: x + 3 + Double(i) * (segW + 2), y: y + 3, w: segW, h: h - 6) {
                    Node.capsule(fill: on ? Paint.action : Paint.clear("#FFFFFF", 0)).id(segId + ".fill").size(segW, h - 6)
                    Node.words(o.label, size: 12.5, weight: "bold", color: on ? Paint.onAction : Paint.ink, align: "center", minScale: 0.6, x: 4, w: segW - 8, h: h - 6)
                }.area("choice", value: "\(name)|\(o.value)", label: o.label, disabled: disabled, hover: AreaLook(opacity: 0.8), press: AreaLook(scale: 0.97), selected: on, always: playing, sound: "sounds/tap.wav"))
            }
            y += h
        }
        var group = Node.box(id, w: width, h: y) { nodes }
        if disabled { group = group.opacity(0.5) }
        return PartBlock(group, height: y)
    }

    private func choiceCards(name: String, options: [ChoiceOption], selected: String?, width: Double) -> (Node, Double) {
        // Three or fewer share the row, rather than sitting in the left half of a grid laid out for four.
        let gap = 8.0
        let columns = options.count < 4 ? max(options.count, 1) : max(Int((width + gap) / (72 + gap)), 1)
        let w = (width - gap * Double(columns - 1)) / Double(columns), h = 80.0
        var nodes: [Node] = []
        var y = 0.0
        for start in stride(from: 0, to: options.count, by: columns) {
            for (c, o) in options[start..<min(start + columns, options.count)].enumerated() {
                let id = "choice.\(name).\(o.value)", on = selected == o.value
                nodes.append(Node.box(id, x: Double(c) * (w + gap), y: y, w: w, h: h) {
                    Node.rect(fill: Paint.card, stroke: on ? Paint.action : Paint.edge, lineWidth: on ? 2.5 : 1, corner: 14).id(id + ".base").size(w, h).shadow(Paint.black8, radius: 2, dx: 0, dy: 2)
                    if let art = Self.topicArt(o.symbol) { Node.art(art, x: (w - 32) / 2, y: 8, w: 32, h: 32) }
                    Node.words(o.label, size: 11.5, weight: "heavy", align: "center", lines: 2, minScale: 0.7, x: 4, y: 42, w: w - 8, h: 32)
                }.area("choice", value: "\(name)|\(o.value)", label: o.label, hover: AreaLook(scale: 1.02), press: AreaLook(scale: 0.98), selected: on, always: playing, sound: "sounds/tap.wav"))
            }
            y += h + gap
        }
        return (Node.box("choice.\(name).cards", w: width, h: y - gap) { nodes }, y - gap)
    }

    /// A choice card's picture for its SF Symbol (trivia's topics, Higher or Lower's two ways).
    static func topicArt(_ symbol: String?) -> String? {
        switch symbol {
        case "shuffle": "art/game-topic-mix.webp"
        case "atom": "art/game-topic-science.webp"
        case "moon.stars.fill": "art/game-topic-space.webp"
        case "globe.europe.africa.fill", "globe": "art/game-topic-geography.webp"
        case "building.columns.fill": "art/game-topic-history.webp"
        case "leaf.fill": "art/game-topic-nature.webp"
        case "fork.knife": "art/game-topic-food.webp"
        case "paintpalette.fill": "art/game-topic-arts.webp"
        case "cpu": "art/game-topic-tech.webp"
        case "figure.run", "sportscourt.fill": "art/game-topic-sports.webp"
        case "sun.max.fill": "art/game-topic-mediterranean.webp"
        case "questionmark.square.fill", "questionmark": "art/game-icon-quiz.webp"
        case "brain.head.profile", "lightbulb", "lightbulb.fill": "art/game-bulb.webp"
        default: nil
        }
    }
}

extension Node {
    /// The same shape under this one (a gradient's solid base), both as children of the caller's group: returned as this node with a backing.
    func background(_ fill: Color, corner: Double, id: String, w: Double, h: Double) -> [Node] {
        [Node.rect(fill: fill, corner: corner).id(id).size(w, h), self]
    }
}
