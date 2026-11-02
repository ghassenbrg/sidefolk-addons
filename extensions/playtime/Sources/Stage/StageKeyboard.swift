import SidefolkExtensionKit

// An on-screen keyboard (KeyboardView) and a text field for what only the person's input method types (GameEntryView). One move
// a key: `letter` keys go at once to the game, `spell` keys add to the word kept in `LocalParts.draft`.
extension BoardDrawing {
    /// A used key: right (success, as on the tiles), elsewhere (the tiles' yellow), absent or missed (faded and struck through, never red).
    private func keyColors(_ mark: String) -> (fill: Color, ink: Color) {
        switch mark {
        case "right", "hit": (.win, Paint.white)
        case "elsewhere": (Paint.sun, .ink)
        case "absent": (Color.inkFaint.tuned(alpha: 0.3), .inkMuted)
        case "miss": (Paint.lostSoft, .inkMuted)
        default: (.surfaceSunken, .ink)
        }
    }

    func keyboard(pages: [KeyPage], mode: String, length: Int?, script: String, locked: Bool) -> PartBlock {
        // A keyboard of many rows (kana, hangul) has slimmer keys, so the board fits the panel.
        let keyH = (pages.map(\.rows.count).max() ?? 0) > 3 ? 26.0 : 30.0
        let page = max(min(ctx.local.page, pages.count - 1), 0)
        let width = Self.inner
        var y = 0.0
        var nodes: [Node] = []
        if pages.count > 1 {
            let segW = (width - 6 - 4 * Double(pages.count - 1)) / Double(pages.count), segH = TextFit.lineHeight(11.5, "semibold") + 8, h = segH + 6
            nodes.append(Node.capsule(fill: .surfaceSunken).id("keys.tabs").size(width, h))
            for (i, p) in pages.enumerated() {
                nodes.append(.box("keys.tab.\(i)", x: 3 + Double(i) * (segW + 4), y: 3, w: segW, h: segH) {
                    Node.capsule(fill: i == page ? Color.accent : Color.clear).size(segW, segH)
                    Node.words(p.label, size: 11.5, weight: "semibold", color: i == page ? .onAccent : .ink, align: "center", design: "default", w: segW, h: segH)
                }.area("keys_page", value: "\(i)", label: p.label, hover: nil, press: AreaLook(scale: 0.97), selected: i == page))
            }
            y += h + 5
        }
        let shown = pages[page]
        for (r, row) in shown.rows.enumerated() {
            let specials = mode == "spell" && r == shown.rows.count - 1
            // The keys share what the row leaves, however few: a row always runs the keyboard's width.
            let extra = specials ? 2.0 : 0
            let keyW = (width - 4 * (Double(row.count - 1) + extra) - extra * 40) / Double(max(row.count, 1))
            var x = 0.0
            if specials {
                nodes.append(special("return", symbol: "return", label: L("Try this word"), x: x, y: y, h: keyH, locked: locked))
                x += 44
            }
            for k in row {
                nodes.append(keyCapButton(k.key, mark: k.mark, script: script, mode: mode, x: x, y: y, w: keyW, h: keyH, locked: locked))
                x += keyW + 4
            }
            if specials { nodes.append(special("delete", symbol: "delete.left", label: L("Delete"), x: x, y: y, h: keyH, locked: locked)) }
            y += keyH + 5
        }
        let height = y - 5
        if !locked {
            keys.append(StageKey(key: "letter", id: "letter"))
            if mode == "spell" {
                keys.append(StageKey(key: "delete", id: "draft_delete"))
                keys.append(StageKey(key: "return", id: "draft_return"))
            }
        }
        var group = Node.box("keys", w: width, h: height) { nodes }
        if locked { group = group.opacity(0.55) }
        return PartBlock(group, height: height)
    }

    /// A key: its fill on a slightly darker lip, an outline while unused. A word's letters only join what is typed, so they make no sound;
    /// a letter that is a move does, as any move.
    private func keyCapButton(_ key: String, mark: String, script: String, mode: String, x: Double, y: Double, w: Double, h: Double, locked: Bool) -> Node {
        let (fill, ink) = keyColors(mark)
        let plain = mark == "none"
        let used = mode == "letter" && !plain
        let id = "key.\(key)"
        let label = Node.words(script == "latin" ? key.uppercased() : key, size: 14, weight: "semibold", color: ink, align: "center", minScale: 0.6, w: w, h: h).id(id + ".text")
        return Node.box(id, x: x, y: y, w: w, h: h) {
            Node.rect(fill: plain ? .line : lip(mark), corner: 6).id(id + ".lip").at(0, 2).size(w, h - 2)
            Node.rect(fill: fill, stroke: plain ? Color.line : nil, lineWidth: 1, corner: 6).id(id + ".face").size(w, h - 2)
            Node.rect(corner: 6).gradient([Paint.clear("#FFFFFF", 0.18), Paint.clear("#FFFFFF", 0)], from: (0.5, 0), to: (0.5, 0.5)).size(w, h - 2)
            mark == "miss" || mark == "absent" ? label.textLook(strike: true) : label
        }.area("key", value: key, label: key, disabled: locked || used, hover: nil, press: AreaLook(scale: 0.95), sound: mode == "letter" ? "sounds/tap.wav" : nil)
    }

    private func lip(_ mark: String) -> Color {
        switch mark {
        case "right", "hit": Color.win.tuned(brightness: -0.14)
        case "elsewhere": .hex("#DBAD33")
        case "miss": .adaptive(light: "#D1C4B8", dark: "#3F3128")
        default: Color.inkFaint.tuned(alpha: 0.3, brightness: -0.14)
        }
    }

    private func special(_ name: String, symbol: String, label: String, x: Double, y: Double, h: Double, locked: Bool) -> Node {
        Node.box("key.\(name)", x: x, y: y, w: 40, h: h) {
            Node.rect(fill: .line, corner: 6).at(0, 2).size(40, h - 2)
            Node.rect(fill: .surfaceRaised, stroke: .line, lineWidth: 1, corner: 6).size(40, h - 2)
            // Sized by height: a wide symbol would shrink to fit a square box.
            Node.symbol(symbol, color: .ink).symbolLook().at(9, (h - 16) / 2 - 1).size(22, 16)
        }.area("draft", value: name, label: label, disabled: locked, hover: nil, press: AreaLook(scale: 0.95), sound: name == "return" ? "sounds/tap.wav" : nil)
    }

    /// A text field: `word` sends `.word`, `text` sends `.text`; Return or its button sends it, and the app's field takes the input method.
    func entry(name: String, kind: String, label: String?, placeholder: String?, button: String?, max: Int, locked: Bool) -> PartBlock {
        let width = Self.inner, room = width - 20
        var y = 10.0
        var nodes: [Node] = []
        if let label {
            let h = TextFit.lineHeight(11.5, "semibold")
            nodes.append(Node.words(label, size: 11.5, weight: "semibold", color: .inkMuted, design: "default", x: 10, y: y, w: room, h: h))
            y += h + 6
        }
        let words = button ?? L("OK")
        let buttonW = TextFit.width(words, size: 16, weight: "heavy") + 32
        let fieldW = room - buttonW - 8, fieldH = 40.0
        nodes.append(Node.rect(fill: .surfaceSunken, stroke: .line, lineWidth: 1, corner: 10).id("entry.well").at(10, y).size(fieldW, fieldH))
        nodes.append(Node.entry(name: name, placeholder: placeholder, max: max, locked: locked, size: 17).fieldLook(focus: true, plain: true, weight: "semibold", design: "rounded")
            .id("entry.\(name)").at(10 + 12, y + 8).size(fieldW - 24, fieldH - 16))
        nodes.append(.box("entry.send", x: 10 + fieldW + 8, y: y - 3, w: buttonW, h: 46 + 4) {
            Node.rect(fill: Color.accent.tuned(brightness: -0.14), corner: 16).at(0, 4).size(buttonW, 46)
            Node.box("entry.send.face", w: buttonW, h: 46) {
                Node.rect(fill: .accent, corner: 16).size(buttonW, 46)
                Node.rect(corner: 16).gradient([Paint.clear("#FFFFFF", 0.25), Paint.clear("#FFFFFF", 0)], from: (0.5, 0), to: (0.5, 0.5)).size(buttonW, 46)
                Node.words(words, size: 16, weight: "heavy", color: .onAccent, align: "center", minScale: 0.65, x: 8, w: buttonW - 16, h: 46)
            }.area("entry_send", label: words, disabled: locked, hover: nil, press: AreaLook(dy: 3), submits: name, sound: "sounds/tap.wav")
        })
        y += 46 + 10
        return PartBlock(.box("entrycard.\(name)", w: width, h: y) {
            Node.gameCard(corner: 16, alpha: 0.95, w: width, h: y).id("entry.card")
            nodes
        }, height: y)
    }
}
