import SidefolkExtensionKit

// Letter tiles (LettersView), in two places. Daily Word: rows of tiles on a felt tray with its legend, the row being typed with a focused cell, the newest row turning over tile by tile
// during its build-up. Balloon Words: the word's slots on a navy felt sign standing on the stall's counter, letters landing into them. Either part is exactly as tall as what the keyboard
// leaves it, so nothing on the board ever moves. The keyboard is StageKeyboard.
extension BoardDrawing {
    /// The space between Korean tiles, the same inside a syllable and between syllables.
    private static let hangulGap = 7.0

    func lettersPart(rows: [[LetterTile]], length: Int, tries: Int?, style: String, draft: Bool, flip: Int?, script: String) -> PartBlock {
        style == "slots" ? wordSign(rows: rows, length: length, script: script) : wordTray(rows: rows, length: length, tries: tries, draft: draft, flip: flip, script: script)
    }

    /// What the part below takes (the keyboard, or the field a language types into): the same all through a game, whichever page shows.
    private var inputHeight: Double {
        if let k = board.keysPart { return Self.keyboardHeight(pages: k.pages, stall: isStall) + 8 }
        for case .play(.entry(let name, let kind, let label, let placeholder, let button, let max, let locked)) in board.parts {
            return entry(name: name, kind: kind, label: label, placeholder: placeholder, button: button, max: max, locked: locked).height + 8
        }
        return 0
    }

    // MARK: Daily Word

    private static let trayPad = 14.0, rowGap = 5.0, legendRoom = 30.0

    private func wordTray(rows: [[LetterTile]], length: Int, tries: Int?, draft: Bool, flip: Int?, script: String) -> PartBlock {
        let hangul = script == "hangul", height = max(playRoom - inputHeight, 60), width = Self.inner
        let count = tries ?? rows.count
        let widest = max(length, rows.map(\.count).max() ?? 0)
        let across = width - 2 * Self.trayPad - Double(max(0, widest - 1)) * (hangul ? Self.hangulGap : Self.rowGap)
        let tileH = max((height - 2 * Self.trayPad - Self.legendRoom - 6 - Double(max(count - 1, 0)) * Self.rowGap) / Double(max(count, 1)), 14)
        let tileW = min(tileH * 1.16, across / Double(max(widest, 1)))
        let side = min(tileH, tileW)
        return PartBlock(.box("letters", w: width, h: height) {
            Node.felt("letters.tray", w: width, h: height, corner: 24)
            Self.pin("letters.pin.a", x: 12, y: 10)
            Self.pin("letters.pin.b", x: width - 28, y: 10)
            for r in 0..<count {
                let row = letterRow(r, rows: rows, length: length, draft: draft, script: script)
                self.letterRowNode(row.tiles, id: "letters.\(r)", y: Self.trayPad + Double(r) * (tileH + Self.rowGap), w: tileW, h: tileH, side: side, hangul: hangul, typing: row.typing,
                                   flipping: ctx.buildUp && ctx.fresh && flip == r, width: width)
            }
            legend(width: width, y: height - Self.trayPad - Self.legendRoom + 4)
        }, height: height)
    }

    /// A round wooden pin holding the felt, top corners.
    private static func pin(_ id: String, x: Double, y: Double) -> Node {
        Node.ellipse().gradient([.hex("#F3C98F"), .hex("#C98B4A")], from: (0.3, 0.2), to: (0.7, 0.9)).id(id).at(x, y).size(16, 16).shadow(Paint.clear("#000000", 0.22), radius: 1.5, dx: 0, dy: 1)
    }

    /// What the marks mean, in a place of its own whether or not any is showing yet, and beside it the quiet hint, faded while it can't be pressed.
    private func legend(width: Double, y: Double) -> Node {
        let right = L("Right place"), elsewhere = L("Elsewhere"), mark = 13.0, h = 26.0
        // It stays in its place while a row turns, faded.
        var hint = (ctx.buildUp ? ctx.previous ?? board : board).buttons.first { $0.move == "hint" }
        if ctx.buildUp { hint?.disabled = true }
        let hintW = hint.map { Swift.min(TextFit.width($0.label, size: 12, weight: "bold") + 34, 118) } ?? 0
        let room = width - 2 * Self.trayPad - (hint == nil ? 0 : hintW + 8)
        let rightW = TextFit.width(right, size: 12, weight: "semibold"), elseW = TextFit.width(elsewhere, size: 12, weight: "semibold")
        let wanted = 12 + mark + 5 + rightW + 12 + mark + 5 + elseW + 12
        let squeeze = Swift.min(1, (room - 54 - 2 * mark) / Swift.max(rightW + elseW, 1))
        let w = Swift.min(wanted, room), rw = rightW * squeeze, ew = elseW * squeeze
        return .box("legend", x: Self.trayPad, y: y, w: width - 2 * Self.trayPad, h: h) {
            Node.capsule(fill: Paint.card(0.94)).id("legend.back").size(w, h)
            Self.tileMark("right", size: mark, ink: Color.win, id: "legend.right").at(12, (h - mark) / 2)
            Node.words(right, size: 12, weight: "semibold", minScale: 0.6, x: 12 + mark + 5, w: rw, h: h).id("legend.right.words")
            Self.tileMark("elsewhere", size: mark, ink: Paint.sunLip, id: "legend.else").at(12 + mark + 5 + rw + 12, (h - mark) / 2)
            Node.words(elsewhere, size: 12, weight: "semibold", minScale: 0.6, x: 12 + mark + 5 + rw + 12 + mark + 5, w: ew, h: h).id("legend.else.words")
            if let hint { hintButton(hint, x: width - 2 * Self.trayPad - hintW, w: hintW, h: h) }
        }
    }

    private func hintButton(_ b: GameButton, x: Double, w: Double, h: Double) -> Node {
        var node = Node.box("legend.hint", x: x, w: w, h: h) {
            Node.capsule(fill: Paint.card, stroke: Paint.ink, lineWidth: 1.25).id("legend.hint.back").at(0.6, 0.6).size(w - 1.2, h - 1.2)
            Node.symbol(b.symbol ?? "lightbulb", color: Paint.ink).symbolLook(weight: "bold").at(9, (h - 14) / 2).size(14, 14)
            Node.words(b.label, size: 12, weight: "bold", minScale: 0.6, x: 26, w: w - 34, h: h)
        }.area("button", value: b.move, label: b.label, disabled: b.disabled, hover: AreaLook(scale: 1.03), press: AreaLook(scale: 0.97), sound: "sounds/tap.wav")
        if b.disabled { node = node.opacity(0.45) }
        return node
    }

    /// A played row, the row being typed, or an empty one.
    private func letterRow(_ r: Int, rows: [[LetterTile]], length: Int, draft: Bool, script: String) -> (tiles: [LetterTile], typing: Bool) {
        if rows.indices.contains(r) { return (rows[r], false) }
        // A word just played is its row now, turning: what was typed isn't in the next one any more.
        guard draft, r == rows.count, !ctx.buildUp else { return ((0..<length).map { LetterTile("", group: $0) }, false) }
        let typed = Hangul.split(ctx.local.draft, script: script)
        return ((0..<length).map { i in
            i < typed.count ? LetterTile(typed[i].text, group: typed[i].group) : LetterTile("", group: typed.last.map { $0.group + 1 + i - typed.count } ?? i)
        }, true)
    }

    /// One row, letters of one group close together (a pinyin syllable, a word), centred even if it runs over. Korean rows keep every tile in its column instead, the jamo of a
    /// syllable joined by a pad drawn behind them, so a played, typed or empty row is always the same width.
    private func letterRowNode(_ row: [LetterTile], id: String, y: Double, w: Double, h: Double, side: Double, hangul: Bool, typing: Bool, flipping: Bool, width: Double) -> Node {
        let groups = Dictionary(grouping: row.indices, by: { row[$0].group }).sorted { $0.key < $1.key }.map(\.value)
        let outer = hangul ? Self.hangulGap : Self.rowGap
        let inner = hangul ? Self.hangulGap : Self.rowGap
        let widths = groups.map { Double($0.count) * w + Double($0.count - 1) * inner }
        var x = (width - widths.reduce(0, +) - Double(max(groups.count - 1, 0)) * outer) / 2
        var nodes: [Node] = []
        let typedCount = Hangul.split(ctx.local.draft, script: "").count
        for (g, members) in groups.enumerated() {
            // The pad reaches into the gaps around its syllable: two pads stay apart by a hair.
            if hangul, members.count > 1 {
                nodes.append(Node.rect(fill: Paint.card(0.45), corner: 9).id("\(id).pad.\(g)")
                    .at(x - (Self.hangulGap / 2 - 1), -(Self.hangulGap / 2 - 1)).size(widths[g] + Self.hangulGap - 2, h + Self.hangulGap - 2))
            }
            for (m, i) in members.enumerated() {
                nodes.append(letterTile(row[i], id: "\(id).\(i)", w: w, h: h, side: side, focused: typing && i == typedCount, landed: typing && ctx.local.justTyped && !ctx.fresh && i == typedCount - 1,
                                        flipAt: flipping ? Double(i) * 220 : nil)
                    .at(x + Double(m) * (w + inner), 0))
            }
            x += widths[g] + outer
        }
        // A whole row all right, once its last tile has turned, stands up one tile after another.
        if flipping, row.allSatisfy({ $0.mark == "right" }) {
            for i in row.indices {
                heldKeys("\(id).\(i)", [["t": 0, "y": 0], ["t": 0.45, "y": -9], ["t": 1, "y": 0]], delayMs: Double(row.count) * 220 + 80 + Double(i) * 60, ms: 260, ease: "in_out")
            }
        }
        // A word refused gives a small shake: it stays typed, to be fixed.
        if typing, board.refused, ctx.fresh {
            anims.append(.keys(id, [["t": 0, "x": 0], ["t": 0.2, "x": -5], ["t": 0.45, "x": 5], ["t": 0.7, "x": -3], ["t": 1, "x": 0]], ms: 320, ease: "in_out"))
        }
        return .box(id, y: y, w: width, h: h) { nodes }
    }

    /// A letter in its place: colour and shape both: a dot (right place), half a dot (elsewhere), a cross (not in the word). A played letter stands up as a tile on its lip. It turns
    /// over from the typed tile it was: that narrows to nothing and the marked one opens, at its moment.
    private func letterTile(_ tile: LetterTile, id: String, w: Double, h: Double, side: Double, focused: Bool, landed: Bool, flipAt: Double?) -> Node {
        let right = tile.mark == "right"
        let faces: (face: Color, lip: Color)? = switch tile.mark {
        case "right": (.win, Color.win.tuned(brightness: -0.16))
        case "elsewhere": (Paint.sun, Paint.sunLip)
        case "absent": (Paint.tileAbsent, Paint.tileAbsentLip)
        default: nil
        }
        let ink: Color = right ? Paint.white : tile.mark == "elsewhere" ? Paint.navy : Paint.ink
        let typed = faces == nil && !tile.text.isEmpty
        var inner: [Node] = []
        if let faces {
            inner.append(styled("tlip" + tile.mark, Node.rect(fill: faces.lip, corner: 9).at(0, 3).size(w, h - 3)))
            inner.append(styled("tface" + tile.mark, Node.rect(fill: faces.face, corner: 9).size(w, h - 3)))
        } else {
            inner.append(styled("tblank", Node.rect(fill: Paint.lip, corner: 9).at(0, 1.5).size(w, h - 1.5)))
            inner.append(styled(typed ? "ttyped" : "tempty", Node.rect(fill: Paint.card, stroke: typed ? Paint.inkSoft : Paint.edge, lineWidth: typed ? 1.5 : 1, corner: 9).size(w, h - 1.5)))
        }
        if focused { inner.append(styled("tfocus", Node.rect(stroke: Paint.action, lineWidth: 2.5, corner: 9).at(-0.5, -0.5).size(w + 1, h + 1))) }
        if tile.mark != "hidden", !tile.text.isEmpty {
            let look = styled("tword", .words("", size: side * 0.56, weight: "heavy", align: "center", minScale: 0.6, w: w, h: faces == nil ? h : h - 3))
            inner.append(Node(look.json.merging(["text": shown(tile.text), "color": ink.json]) { $1 }))
        }
        if faces != nil {
            let size = max(7, side * 0.24)
            inner.append(Self.tileMark(tile.mark, size: size, ink: right ? Paint.white : Paint.navy, id: nil).at(w - size - 4, h - 3 - size - 3))
        }
        if let flipAt {
            // The tile as it was typed, until its moment. One path for each, from the start, so no colour shows before it.
            let shut = id + ".shut"
            inner.append(.box(shut, w: w, h: h) {
                Node.rect(fill: Paint.lip, corner: 9).at(0, 1.5).size(w, h - 1.5)
                Node.rect(fill: Paint.card, stroke: Paint.inkSoft, lineWidth: 1.5, corner: 9).size(w, h - 1.5)
                Node.words(shown(tile.text), size: side * 0.56, weight: "heavy", align: "center", minScale: 0.6, w: w, h: h)
            }.opacity(0))
            let half = 110.0, total = flipAt + 250
            var turn: [[String: Double]] = [["t": 0, "sy": 1]]
            if flipAt > 0 { turn.append(["t": flipAt / total, "sy": 1]) }
            anims.append(.keys(id, turn + [["t": (flipAt + half) / total, "sy": 0.02], ["t": 1, "sy": 1]], ms: total, ease: "in_out"))
            anims.append(.keys(shut, [["t": 0, "opacity": 1], ["t": (flipAt + half) / total, "opacity": 1], ["t": (flipAt + half + 1) / total, "opacity": 0], ["t": 1, "opacity": 0]], ms: total, ease: "linear"))
        }
        if landed { anims.append(.keys(id, [["t": 0, "scale": 1.2, "y": -4], ["t": 1, "scale": 1, "y": 0]], ms: 150, ease: "out")) }
        var words = tile.text.isEmpty ? L("blank") : tile.text
        switch tile.mark {
        case "right": words += ", " + L("right place")
        case "elsewhere": words += ", " + L("in the word, elsewhere")
        case "absent": words += ", " + L("not in the word")
        default: break
        }
        return Node.box(id, w: w, h: h) { inner }.anchor(0.5, 0.5).label(words)
    }

    /// A letter as the keyboard shows it: capitals in Latin letters, unless a capital would be two (ß).
    func shown(_ text: String) -> String {
        guard board.lettersPart?.script == "latin", text.uppercased().count == text.count else { return text }
        return text.uppercased()
    }

    /// The shape that goes with a mark's colour, on a tile, a key and the legend: a dot, half a dot under its outline, a cross.
    static func tileMark(_ mark: String, size s: Double, ink: Color, id: String?) -> Node {
        var node: Node
        switch mark {
        case "right":
            node = Node.ellipse(fill: ink).size(s, s)
        case "elsewhere":
            let k = s * 0.5, c = k * 0.5523
            let dome = "M 0 \(k * 1.5) C 0 \(k * 1.5 - c * 1.5) \(k - c) \(k * 0.25) \(k) \(k * 0.25) C \(k + c) \(k * 0.25) \(s) \(k * 1.5 - c * 1.5) \(s) \(k * 1.5) Z"
            node = Node.path(dome, fill: ink).size(s, s)
        default:
            let t = s * 0.14, a = s * 0.16, b = s * 0.84
            let cross = "M \(a - t) \(a + t) L \(a + t) \(a - t) L \(b + t) \(b - t) L \(b - t) \(b + t) Z M \(b - t) \(a - t) L \(b + t) \(a + t) L \(a + t) \(b + t) L \(a - t) \(b - t) Z"
            node = Node.path(cross, fill: ink).size(s, s)
        }
        if let id { node = node.id(id) }
        return node
    }

    // MARK: Balloon Words

    /// The sign's room: it stands on the stall's counter whatever the keyboard takes below it.
    private static let signX = 102.0, signY = 22.0, signW = 264.0, signH = 74.0

    private func wordSign(rows: [[LetterTile]], length: Int, script: String) -> PartBlock {
        let row = rows.first ?? []
        let height = max(playRoom - inputHeight, Self.signY + Self.signH)
        let room = Self.signW - 56
        let groups = Dictionary(grouping: row.indices, by: { row[$0].group }).sorted { $0.key < $1.key }.map(\.value)
        let inner = 4.0, outer = 12.0
        let across = room - Double(max(0, row.count - groups.count)) * inner - Double(max(0, groups.count - 1)) * outer
        let w = min(30, across / Double(max(row.count, 1)))
        let widths = groups.map { Double($0.count) * w + Double($0.count - 1) * inner }
        var x = (Self.signW - widths.reduce(0, +) - Double(max(groups.count - 1, 0)) * outer) / 2
        var slots: [Node] = []
        // The letters that have just come: one after another, into their slots.
        var landed = 0
        for (g, members) in groups.enumerated() {
            for (m, i) in members.enumerated() {
                let before = ctx.previous?.lettersPart?.rows.first?[safe: i]
                let lands = ctx.fresh && !ctx.local.builtUp && before?.text != row[i].text && !row[i].text.isEmpty && ctx.previous?.lettersPart != nil
                slots.append(slot(row[i], id: "letters.0.\(i)", x: x + Double(m) * (w + inner), w: w, landsAfter: lands ? Double(landed) * 90 : nil))
                if lands { landed += 1 }
            }
            x += widths[g] + outer
        }
        let id = "letters"
        return PartBlock(.box(id, w: Self.inner, h: height) {
            Node.box("letters.sign", x: Self.signX, y: Self.signY, w: Self.signW, h: Self.signH) {
                Node.woodFrame("sign.frame", w: Self.signW, h: Self.signH, inset: 5, corner: 16, inner: Paint.signFelt)
                Node.rect(stroke: Paint.clear("#FFF4E6", 0.7), lineWidth: 1.25, corner: 9, dash: [4, 3]).id("sign.stitch").at(9, 9).size(Self.signW - 18, Self.signH - 18)
                for (i, spot) in [(14.0, 14.0), (Self.signW - 22, 14.0), (14.0, Self.signH - 22), (Self.signW - 22, Self.signH - 22)].enumerated() {
                    Node.ellipse().gradient([.hex("#F3C98F"), .hex("#B9803F")], from: (0.3, 0.2), to: (0.7, 0.9)).id("sign.stud.\(i)").at(spot.0, spot.1).size(8, 8)
                }
                slots
            }
        }, height: height)
    }

    /// A place in the word: a line, and its letter once guessed, dropping onto it.
    private func slot(_ tile: LetterTile, id: String, x: Double, w: Double, landsAfter: Double?) -> Node {
        let h = Self.signH - 22, size = min(w * 0.95, 28)
        let words = tile.mark == "hidden" || tile.text.isEmpty ? nil : shown(tile.text)
        let target = id + ".letter"
        if let landsAfter {
            heldKeys(target, [["t": 0, "y": -16, "scale": 1.35, "opacity": 0], ["t": 0.2, "opacity": 1], ["t": 0.75, "y": 0, "scale": 1], ["t": 1, "y": 0, "scale": 1, "opacity": 1]], delayMs: landsAfter, ms: 300, ease: "out")
        }
        return Node.box(id, x: x, y: 11, w: w, h: h) {
            Node.capsule(fill: Paint.signInk).id(id + ".line").at(1, h - 7).size(w - 2, 3)
            if let words {
                Node.words(words, size: size, weight: "heavy", color: Paint.signInk, align: "center", minScale: 0.55, w: w, h: h - 7).id(target).opacity(tile.mark == "absent" ? 0.55 : 1)
            }
        }.label(words ?? L("blank"))
    }

    /// The stall: Balloon Words' scene is played in, its balloons on the rail painted in it, the companion on its counter.
    var isStall: Bool { look.name == "balloons" && board.hasLetters }
}

/// Korean jamo typed one by one, grouped into the syllables they make (ㅅ ㅏ ㄱ ㅗ ㅏ is 사 과), so a half-typed word is drawn as the blocks it
/// will be. Other scripts: one group per letter.
enum Hangul {
    static let leads: [Character] = Array("ㄱㄲㄴㄷㄸㄹㅁㅂㅃㅅㅆㅇㅈㅉㅊㅋㅌㅍㅎ")
    static let vowels: Set<Character> = Set("ㅏㅐㅑㅒㅓㅔㅕㅖㅗㅛㅜㅠㅡㅣ")
    /// Vowels that join into one (ㅗ ㅏ is ㅘ).
    static let compound: Set<String> = ["ㅗㅏ", "ㅗㅐ", "ㅗㅣ", "ㅜㅓ", "ㅜㅔ", "ㅜㅣ", "ㅡㅣ"]
    /// Final consonants that join (ㄹ ㄱ is ㄺ).
    static let tails: Set<String> = ["ㄱㅅ", "ㄴㅈ", "ㄴㅎ", "ㄹㄱ", "ㄹㅁ", "ㄹㅂ", "ㄹㅅ", "ㄹㅌ", "ㄹㅍ", "ㄹㅎ", "ㅂㅅ"]

    static func split(_ typed: String, script: String) -> [(text: String, group: Int)] {
        let jamo = Array(typed)
        guard script == "hangul" else { return jamo.enumerated().map { (String($1), $0) } }
        var out: [(String, Int)] = []
        var i = 0, group = 0
        func isVowel(_ k: Int) -> Bool { k < jamo.count && vowels.contains(jamo[k]) }
        func isLead(_ k: Int) -> Bool { k < jamo.count && leads.contains(jamo[k]) }
        while i < jamo.count {
            var end = i + 1
            if isLead(i), isVowel(i + 1) {
                end = i + 2
                if isVowel(end), compound.contains(String([jamo[end - 1], jamo[end]])) { end += 1 }
                // A consonant after the vowel closes the syllable unless a vowel follows it (then it starts the next).
                if isLead(end), !isVowel(end + 1) {
                    end += 1
                    if isLead(end), !isVowel(end + 1), tails.contains(String([jamo[end - 1], jamo[end]])) { end += 1 }
                }
            }
            for k in i..<end { out.append((String(jamo[k]), group)) }
            group += 1
            i = end
        }
        return out
    }
}
