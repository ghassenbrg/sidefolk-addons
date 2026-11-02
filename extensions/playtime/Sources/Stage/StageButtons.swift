import SidefolkExtensionKit

// A game's button as a toy (ChunkyButtonStyle): a raised face on a darker lip that sinks when pressed. The primary is the
// app's accent (a game's colour is decoration, never what a button means), the secondary the games' card on its blue lip, the
// plain one a soft pill. Flat on the end card, where the result is the one thing that stands up.
extension BoardDrawing {
    private func metrics(_ b: GameButton, flat: Bool) -> (size: Double, weight: String, corner: Double, depth: Double, height: Double, hPad: Double) {
        let plain = b.style == .plain
        return (plain ? 13 : flat ? 15 : 16, flat ? "bold" : "heavy", plain ? 20 : flat ? 14 : 16, flat ? 0 : plain ? 2 : 4, plain ? 34 : flat ? 42 : 46, plain ? 14 : 16)
    }

    /// The room a button's words want.
    func buttonWidth(_ b: GameButton, flat: Bool) -> Double {
        let m = metrics(b, flat: flat)
        return TextFit.width(b.label, size: m.size, weight: m.weight) + (b.symbol == nil ? 0 : 6 + m.size * 1.2) + m.hPad * 2
    }

    func buttonRow(_ buttons: [GameButton], id: String, width: Double = BoardDrawing.inner, flat: Bool = false) -> PartBlock {
        let gap = 8.0
        // A plain button's words are measured first; the wide buttons beside it take the room left.
        let fixed = buttons.filter { $0.style == .plain }.reduce(0) { $0 + buttonWidth($1, flat: flat) }
        let wide = buttons.filter { $0.style != .plain }.count
        let share = wide > 0 ? max((width - fixed - gap * Double(buttons.count - 1)) / Double(wide), 40) : 0
        // Long words beside each other (German's Undo and Start over) share the row rather than run past the panel's edge; their words shrink to fit.
        let fits = fixed > 0 ? min(1, (width - gap * Double(buttons.count - 1) - 40 * Double(wide)) / fixed) : 1
        var x = 0.0
        var nodes: [Node] = []
        var height = 0.0
        for (i, b) in buttons.enumerated() {
            let w = b.style == .plain ? min(buttonWidth(b, flat: flat) * fits, width) : share
            let m = metrics(b, flat: flat)
            nodes.append(button(b, id: "\(id).\(i)", x: x, w: w, flat: flat))
            height = max(height, m.height + m.depth)
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

    func button(_ b: GameButton, id: String, x: Double, w: Double, flat: Bool) -> Node {
        let m = metrics(b, flat: flat)
        let primary = b.style == .primary
        let fill: Color = primary ? .accent : Paint.card
        let ink: Color = primary ? .onAccent : .ink
        let symbolW = b.symbol == nil ? 0 : m.size * 1.2
        let textRoom = w - m.hPad * 2 - (b.symbol == nil ? 0 : 6 + symbolW)
        let textW = min(TextFit.width(b.label, size: m.size, weight: m.weight), max(textRoom, 10))
        let startX = (w - textW - (b.symbol == nil ? 0 : 6 + symbolW)) / 2
        var face = Node.box(id + ".top", w: w, h: m.height) {
            if primary && !flat {
                Node.rect(corner: m.corner).gradient([Paint.clear("#FFFFFF", 0.25), Paint.clear("#FFFFFF", 0)], from: (0.5, 0), to: (0.5, 0.5)).id(id + ".fill").size(w, m.height)
                    .background(fill, corner: m.corner, id: id + ".base", w: w, h: m.height)
            } else {
                Node.rect(fill: fill, stroke: primary ? nil : Paint.edge, lineWidth: 1, corner: m.corner).id(id + ".fill").size(w, m.height)
            }
            Node.words(b.label, size: m.size, weight: m.weight, color: ink, align: "center", minScale: 0.65, x: startX, w: textW, h: m.height)
            if let symbol = b.symbol {
                Node.symbol(symbol, color: ink).symbolLook(weight: m.weight).at(startX + textW + 6, (m.height - symbolW) / 2).size(symbolW, symbolW)
            }
        }
        face = face.area("button", value: b.move, label: b.label, disabled: b.disabled, hover: nil, press: AreaLook(scale: flat ? 0.97 : 1, dy: flat ? 0 : m.depth - 1), sound: "sounds/tap.wav")
        var group = Node.box(id, x: x, w: w, h: m.height + m.depth) {
            if m.depth > 0 { Node.rect(fill: primary ? Color.accent.tuned(brightness: -0.14) : Paint.lip, corner: m.corner).id(id + ".lip").at(0, m.depth).size(w, m.height) }
            face
        }
        if b.disabled { group = group.opacity(0.5) }
        return group
    }

    /// A lightbulb, a seal or a mark, the words on the sun's tint.
    func note(_ text: String, title: String?, tone: Tone) -> PartBlock {
        let room = Self.inner - 24 - 28
        let symbol = tone == .info || tone == .neutral ? "lightbulb.fill" : tone == .good ? "checkmark.seal.fill" : "exclamationmark.circle.fill"
        let titleH = title == nil ? 0 : TextFit.lineHeight(11.5, "semibold") + 2
        let textH = TextFit.height(text, size: 13, width: room)
        let height = 24 + titleH + textH
        return PartBlock(.box("note", w: Self.inner, h: height) {
            Node.rect(fill: Paint.card(0.96), stroke: Paint.edge, lineWidth: 1, corner: 14).id("note.card").size(Self.inner, height)
            Node.rect(fill: Paint.clear("#FFC93C", 0.14), corner: 14).id("note.tint").size(Self.inner, height)
            Node.symbol(symbol, color: Paint.sun).symbolLook().at(12, 12).size(18, 18)
            if let title { Node.words(title, size: 11.5, weight: "semibold", design: "default", x: 40, y: 12, w: room, h: titleH) }
            Node.words(text, size: 13, weight: "regular", valign: "top", lines: 0, design: "default", x: 40, y: 12 + titleH, w: room, h: textH)
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

    /// One of a few options, as cards (each in its own soft pastel, with its picture) or segments.
    func choice(name: String, label: String?, style: ChoiceStyle, options: [ChoiceOption], selected: String?, compact: Bool, width: Double = BoardDrawing.inner) -> PartBlock {
        let id = "choice.\(name)"
        var y = 0.0
        var nodes: [Node] = []
        if let label, !compact {
            let w = min(TextFit.width(label, size: 11.5, weight: "semibold") + 16, width)
            nodes.append(Node.capsule(fill: Paint.card(0.94)).id(id + ".pill").size(w, 18))
            nodes.append(Node.words(label, size: 11.5, weight: "semibold", color: .inkMuted, align: "center", design: "default", w: w, h: 18))
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
                let w = TextFit.width(label, size: 11.5, weight: "semibold")
                nodes.append(Node.words(label, size: 11.5, weight: "semibold", color: .inkMuted, design: "default", y: y, w: w, h: 32))
                x = w + 6
            }
            let rowW = width - x, h = 32.0
            let segW = (rowW - 6 - 4 * Double(options.count - 1)) / Double(max(options.count, 1))
            nodes.append(Node.capsule(fill: compact ? Paint.inset : Paint.card(0.96), stroke: compact ? nil : Paint.edge, lineWidth: 1).id(id + ".track").at(x, y).size(rowW, h))
            for (i, o) in options.enumerated() {
                let on = selected == o.value
                let segId = "\(id).\(o.value)"
                nodes.append(Node.box(segId, x: x + 3 + Double(i) * (segW + 4), y: y + 3, w: segW, h: h - 6) {
                    Node.capsule(fill: on ? Color.accent : Color.clear).size(segW, h - 6)
                    Node.words(o.label, size: 11.5, weight: "semibold", color: on ? .onAccent : .ink, align: "center", design: "default", x: 3, w: segW - 6, h: h - 6)
                }.area("choice", value: "\(name)|\(o.value)", label: o.label, hover: nil, press: AreaLook(scale: 0.97), selected: on, sound: "sounds/tap.wav"))
            }
            y += h
        }
        return PartBlock(.box(id, w: width, h: y) { nodes }, height: y)
    }

    private func choiceCards(name: String, options: [ChoiceOption], selected: String?, width: Double) -> (Node, Double) {
        // Three or fewer share the row, rather than sitting in the left half of a grid laid out for four.
        let gap = 8.0
        let columns = options.count < 4 ? max(options.count, 1) : max(Int((width + gap) / (72 + gap)), 1)
        let w = (width - gap * Double(columns - 1)) / Double(columns)
        func heightOf(_ o: ChoiceOption) -> Double {
            let art = o.symbol == nil ? 0.0 : Self.topicArt(o.symbol) != nil ? 32 + 4 : 38 + 4
            let label = TextFit.height(o.label, size: 11.5, weight: "semibold", width: w - 8, lines: 3)
            let detail = o.detail.map { TextFit.height($0, size: 11.5, width: w - 8, lines: 2) + 4 } ?? 0
            return max(60, 12 + art + label + detail)
        }
        var nodes: [Node] = []
        var y = 0.0
        for start in stride(from: 0, to: options.count, by: columns) {
            let row = options[start..<min(start + columns, options.count)]
            let h = row.map(heightOf).max() ?? 60
            for (c, o) in row.enumerated() {
                nodes.append(choiceCard(o, name: name, tint: start + c, selected: selected == o.value, x: Double(c) * (w + gap), y: y, w: w, h: h))
            }
            y += h + gap
        }
        return (Node.box("choice.\(name).cards", w: width, h: y - gap) { nodes }, y - gap)
    }

    private func choiceCard(_ o: ChoiceOption, name: String, tint: Int, selected: Bool, x: Double, y: Double, w: Double, h: Double) -> Node {
        let id = "choice.\(name).\(o.value)"
        var inner: [Node] = []
        let art = Self.topicArt(o.symbol)
        let label = TextFit.height(o.label, size: 11.5, weight: "semibold", width: w - 8, lines: 3)
        let detail = o.detail.map { TextFit.height($0, size: 11.5, width: w - 8, lines: 2) } ?? 0
        let top = o.symbol == nil ? 0.0 : art != nil ? 36 : 42
        var cursor = (h - top - label - (o.detail == nil ? 0 : detail + 4)) / 2
        if let art {
            inner.append(Node.art(art, x: (w - 32) / 2, y: cursor, w: 32, h: 32))
            cursor += 36
        } else if let symbol = o.symbol {
            inner.append(Node.ellipse(fill: selected ? .accent : .accentSoft).at((w - 38) / 2, cursor).size(38, 38))
            inner.append(Node.symbol(symbol, color: selected ? .onAccent : .ink).symbolLook().at((w - 24) / 2, cursor + 7).size(24, 24))
            cursor += 42
        }
        // A long name wraps a little smaller rather than being cut mid-word.
        let longest = o.label.split(separator: " ").map { TextFit.width(String($0), size: 11.5, weight: "semibold") }.max() ?? 0
        let fitted = max(11.5 * min(1, (w - 8) / max(longest, 1)), 9.2)
        inner.append(Node.words(o.label, size: fitted, weight: "semibold", align: "center", lines: 3, minScale: 0.8, design: "default", x: 4, y: cursor, w: w - 8, h: label))
        cursor += label + 4
        if let d = o.detail {
            inner.append(Node.words(d, size: 11.5, weight: "regular", color: .inkMuted, align: "center", lines: 2, design: "default", x: 4, y: cursor, w: w - 8, h: detail))
        }
        return Node.box(id, x: x, y: y, w: w, h: h) {
            Node.rect(fill: selected ? .accentSoft : Paint.card, corner: 14).id(id + ".base").size(w, h).shadow(Paint.black8, radius: 2, dx: 0, dy: 2)
            if !selected { Node.rect(fill: Paint.region(tint, alpha: "66"), corner: 14).id(id + ".tint").size(w, h) }
            // A choice is a selection, not a result: the app's accent, as everywhere else.
            Node.rect(stroke: selected ? .accent : Paint.edge, lineWidth: selected ? 2.5 : 1, corner: 14).id(id + ".edge").size(w, h)
            inner
        }.area("choice", value: "\(name)|\(o.value)", label: o.label, hover: nil, press: AreaLook(scale: 0.98), selected: selected, sound: "sounds/tap.wav")
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
        case "sun.max.fill": "art/game-face-sun.webp"
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
