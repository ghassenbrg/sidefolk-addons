import SidefolkExtensionKit

// An on-screen keyboard (KeyboardView) and a text field for what only the person's input method types (GameEntryView). One move
// a key: `letter` keys go at once to the game, `spell` keys add to the word kept in `LocalParts.draft`. Porcelain keys of one width, each row centred, Enter and delete in navy; used keys
// say so by colour and by shape, and only after a played row has finished turning.
extension BoardDrawing {
    /// A used key: right (success, as on the tiles), elsewhere (the tiles' yellow), absent or missed (faded, never red).
    private func keyColors(_ mark: String) -> (fill: Color, ink: Color, lip: Color) {
        switch mark {
        case "right", "hit": (.win, Paint.white, Color.win.tuned(brightness: -0.14))
        case "elsewhere": (Paint.sun, Paint.navy, Paint.sunLip)
        case "absent": (Paint.tileAbsent, Paint.ink, Paint.tileAbsentLip)
        case "miss": (Paint.lostSoft, Paint.inkSoft, Paint.lip)
        default: (Paint.card, Paint.ink, Paint.lip)
        }
    }

    /// A keyboard of many rows (kana, hangul) has slimmer keys, so the board fits the panel. By the tallest page, so a page never moves anything.
    private static func keyHeight(pages: [KeyPage], stall: Bool) -> Double { (pages.map(\.rows.count).max() ?? 0) > 3 ? 26 : 36 }
    private static let keyGap = 5.0, tabsHeight = 28.0

    static func keyboardHeight(pages: [KeyPage], stall: Bool) -> Double {
        let rows = Double(pages.map(\.rows.count).max() ?? 0), keyH = keyHeight(pages: pages, stall: stall)
        return rows * keyH + max(rows - 1, 0) * keyGap + (pages.count > 1 ? tabsHeight + keyGap : 0)
    }

    func keyboard(pages: [KeyPage], mode: String, length: Int?, script: String, locked: Bool) -> PartBlock {
        let stall = isStall
        let keyH = Self.keyHeight(pages: pages, stall: stall)
        let page = max(min(ctx.local.page, pages.count - 1), 0)
        // Between the stall's posts; the width of the board otherwise.
        let width = stall ? Self.inner - 20 : Self.inner, left = stall ? 10.0 : 0
        // Only a whole word is a move, and only a move sounds.
        let wordReady = mode == "spell" && ctx.local.draft.count == length
        var y = 0.0
        var nodes: [Node] = []
        if pages.count > 1 {
            let segH = Self.tabsHeight - 6, segW = (width - 6 - 4 * Double(pages.count - 1)) / Double(pages.count)
            nodes.append(Node.capsule(fill: Paint.card(0.9)).id("keys.tabs").size(width, Self.tabsHeight))
            for (i, p) in pages.enumerated() {
                nodes.append(.box("keys.tab.\(i)", x: 3 + Double(i) * (segW + 4), y: 3, w: segW, h: segH) {
                    Node.capsule(fill: i == page ? Paint.action : Paint.clear("#FFFFFF", 0)).id("keys.tab.\(i).back").size(segW, segH)
                    Node.words(p.label, size: 13, weight: "bold", color: i == page ? Paint.onAction : Paint.ink, align: "center", w: segW, h: segH)
                }.area("keys_page", value: "\(i)", label: p.label, hover: nil, press: AreaLook(scale: 0.97), selected: i == page))
            }
            y += Self.tabsHeight + Self.keyGap
        }
        let shown = pages[page]
        let gap = 4.0
        // One width for every key on a page, by its longest row; a short row stands in the middle. The last row of a typed word shares what is left with Enter and delete.
        let longest = shown.rows.enumerated().map { r, row in Double(row.count) + (mode == "spell" && r == shown.rows.count - 1 ? 2 * 1.4 : 0) }.max() ?? 1
        let unit = (width - gap * (longest.rounded(.up) - 1)) / longest
        for (r, row) in shown.rows.enumerated() {
            let specials = mode == "spell" && r == shown.rows.count - 1
            let count = Double(row.count)
            let keyW = min(unit, (width - gap * (count + (specials ? 1 : -1)) - (specials ? 76 : 0)) / max(count, 1))
            let keysW = count * keyW + max(count - 1, 0) * gap
            let specialW = specials ? (width - keysW - 2 * gap) / 2 : 0
            var x = specials ? 0 : (width - keysW) / 2
            if specials {
                nodes.append(special("return", word: L("Enter"), symbol: "return", label: L("Try this word"), x: x, y: y, w: specialW, h: keyH, locked: locked, ready: wordReady, sounds: wordReady))
                x += specialW + gap
            }
            for k in row {
                nodes.append(keyCapButton(k.key, mark: k.mark, script: script, mode: mode, x: x, y: y, w: keyW, h: keyH, locked: locked))
                x += keyW + gap
            }
            if specials { nodes.append(special("delete", word: nil, symbol: "delete.left", label: L("Delete"), x: x, y: y, w: specialW, h: keyH, locked: locked, ready: !ctx.local.draft.isEmpty, sounds: false)) }
            y += keyH + Self.keyGap
        }
        let height = Self.keyboardHeight(pages: pages, stall: stall)
        if !locked {
            // A letter pressed on the Mac's keyboard presses its key here. One already used, or on another page, still goes to the game, which says so.
            for (i, k) in shown.rows.joined().enumerated() where k.mark == "none" || mode == "spell" { keys.append(StageKey(key: k.key, id: "key_\(i)", area: "key", value: k.key)) }
            keys.append(StageKey(key: "letter", id: "letter"))
            if mode == "spell" {
                keys.append(StageKey(key: "delete", id: "draft_delete"))
                keys.append(wordReady ? StageKey(key: "return", id: "draft_return", area: "draft", value: "return") : StageKey(key: "return", id: "draft_return"))
            }
        }
        // While a row turns or a game settles it rests, in place.
        var group = Node.box("keys", x: left, w: width, h: height) { nodes }
        if locked { group = group.opacity(0.8) }
        return PartBlock(.box("keys.row", w: Self.inner, h: height) { group }, height: height)
    }

    /// A key: its fill on a slightly darker lip. A word's letters only join what is typed, so they make no sound; a letter that is a move does, as any move. Its mark is in its colour and
    /// in its shape as on the tiles, a missed letter struck through.
    private func keyCapButton(_ key: String, mark: String, script: String, mode: String, x: Double, y: Double, w: Double, h: Double, locked: Bool) -> Node {
        let (fill, ink, lipColor) = keyColors(mark)
        let plain = mark == "none"
        let used = mode == "letter" && !plain
        let look = styled("ktext", .words("", size: h > 30 ? 16 : 14, weight: "bold", align: "center", minScale: 0.6, w: 0, h: 0))
        let label = Node(look.json.merging(["text": script == "latin" ? key.uppercased() : key, "color": ink.json]) { $1 }).size(w, h - 2)
        let marker = max(6, h * 0.2)
        return Node.box("key.\(key)", x: x, y: y, w: w, h: h) {
            styled("klip" + mark, .rect(fill: lipColor, corner: 8).at(0, 2)).size(w, h - 2)
            styled("kface" + mark, .rect(fill: fill, stroke: plain ? Paint.edge : nil, lineWidth: 1, corner: 8)).size(w, h - 2)
            mark == "miss" ? label.textLook(strike: true) : label
            if ["right", "elsewhere", "absent"].contains(mark) {
                Self.tileMark(mark, size: marker, ink: mark == "right" ? Paint.white : mark == "elsewhere" ? Paint.navy : Paint.inkSoft, id: nil).at(w - marker - 2.5, h - 2 - marker - 2)
            }
        }.area("key", value: key, label: key, disabled: locked || used, hover: locked || used ? nil : AreaLook(scale: 1.04), press: AreaLook(scale: 0.94, dy: 1), sound: mode == "letter" ? "sounds/tap.wav" : nil)
    }

    /// Enter and delete, in navy. Waiting for a word, they rest; a whole word lights Enter. Words when they fit; its symbol when a long row leaves it little room.
    private func special(_ name: String, word: String?, symbol: String, label: String, x: Double, y: Double, w: Double, h: Double, locked: Bool, ready: Bool, sounds: Bool) -> Node {
        let wordFits = word.map { TextFit.width($0, size: 14, weight: "bold") * 0.7 + 6 <= w } ?? false
        var node = Node.box("key.\(name)", x: x, y: y, w: w, h: h) {
            Node.rect(fill: Paint.actionLip, corner: 8).at(0, 2).size(w, h - 2)
            Node.rect(fill: Paint.action, corner: 8).size(w, h - 2)
            if wordFits, let word {
                Node.words(word, size: 14, weight: "bold", color: Paint.onAction, align: "center", minScale: 0.7, x: 3, w: w - 6, h: h - 2)
            } else {
                // Sized by height: a wide symbol would shrink to fit a square box.
                Node.symbol(symbol, color: Paint.onAction).symbolLook().at((w - 22) / 2, (h - 16) / 2 - 1).size(22, 16)
            }
        }.area("draft", value: name, label: label, disabled: locked, hover: AreaLook(scale: 1.03), press: AreaLook(scale: 0.95, dy: 1), sound: sounds ? "sounds/tap.wav" : nil)
        if !ready || locked { node = node.opacity(0.8) }
        if ready, !locked, name == "return", ctx.local.justTyped, !ctx.fresh { anims.append(.keys("key.return", [["t": 0, "scale": 1], ["t": 0.5, "scale": 1.08], ["t": 1, "scale": 1]], ms: 260, ease: "in_out")) }
        return node
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
        let buttonW = TextFit.width(words, size: 16, weight: "heavy") + 28
        // The button sets the row's height, with the field in its middle; the panel's plain field stood 38.
        let fieldW = room - buttonW - 8, fieldH = 38.0, rowH = 50.0
        let fieldY = y + (rowH - fieldH) / 2
        nodes.append(Node.rect(fill: .surfaceSunken, stroke: .line, lineWidth: 1, corner: 10).id("entry.well").at(10, fieldY).size(fieldW, fieldH))
        // An AppKit field insets its words 2 more than the panel's did.
        nodes.append(Node.entry(name: name, placeholder: placeholder, max: max, locked: locked, size: 17).fieldLook(focus: true, plain: true, weight: "semibold", design: "rounded")
            .id("entry.\(name)").at(10 + 10, fieldY + 8).size(fieldW - 20, fieldH - 16))
        // The whole button is the area: Sidefolk dims it while the field is empty, lip and all.
        nodes.append(.box("entry.send", x: 10 + fieldW + 8, y: y, w: buttonW, h: rowH) {
            Node.rect(fill: Color.accent.tuned(brightness: -0.14), corner: 16).at(0, 4).size(buttonW, 46)
            Node.rect(fill: .accent, corner: 16).size(buttonW, 46)
            Node.rect(corner: 16).gradient([Paint.clear("#FFFFFF", 0.25), Paint.clear("#FFFFFF", 0)], from: (0.5, 0), to: (0.5, 0.5)).size(buttonW, 46)
            Node.words(words, size: 16, weight: "heavy", color: .onAccent, align: "center", minScale: 0.65, x: 8, w: buttonW - 16, h: 46)
        }.area("entry_send", label: words, disabled: locked, hover: nil, press: AreaLook(scale: 0.97), submits: name, sound: "sounds/tap.wav"))
        y += rowH + 10
        return PartBlock(.box("entrycard.\(name)", w: width, h: y) {
            Node.gameCard(corner: 16, alpha: 0.95, w: width, h: y).id("entry.card")
            nodes
        }, height: y)
    }
}
