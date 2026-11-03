import SidefolkExtensionKit

// Letter tiles (LettersView): Daily Word's rows, Balloon Words' slots. The newest row turns over tile by tile during its build-up, and
// what the person types shows in the next row, grouped as it will be. The keyboard is StageKeyboard.
extension BoardDrawing {
    /// The space between Korean tiles, the same inside a syllable and between syllables.
    private static let hangulGap = 7.0

    func lettersPart(rows: [[LetterTile]], length: Int, tries: Int?, style: String, draft: Bool, flip: Int?, script: String) -> PartBlock {
        let slot = style == "slots", hangul = script == "hangul"
        // Smaller beside a tall keyboard (kana, hangul), so the board fits the panel; otherwise as large as the row allows.
        let largest: Double = (board.keysPart?.pages.map(\.rows.count).max() ?? 0) > 3 ? 24 : 37
        let widest = max(length, rows.map(\.count).max() ?? 0)
        let room = Self.inner - 16 - Double(max(0, widest - 1)) * (hangul ? Self.hangulGap : 5)
        let side = min(largest, slot ? 34 : 37, room / Double(max(widest, 1)))
        let count = slot ? 1 : tries ?? rows.count
        let height = 12 + Double(count) * side + Double(max(count - 1, 0)) * 6
        return PartBlock(.box("letters", w: Self.inner, h: height) {
            // A card behind the tiles, so they read on any scene.
            Node.gameCard(corner: 16, alpha: 0.9, w: Self.inner, h: height).id("letters.card")
            for r in 0..<count {
                let row = letterRow(r, rows: rows, length: length, draft: draft, script: script)
                self.letterRowNode(row.tiles, id: "letters.\(r)", y: 6 + Double(r) * (side + 6), side: side, slot: slot, hangul: hangul, draft: row.typed,
                                   flipping: ctx.buildUp && ctx.fresh && flip == r)
            }
        }, height: height)
    }

    /// A played row, the row being typed, or an empty one.
    private func letterRow(_ r: Int, rows: [[LetterTile]], length: Int, draft: Bool, script: String) -> (tiles: [LetterTile], typed: Bool) {
        if rows.indices.contains(r) { return (rows[r], false) }
        guard draft, r == rows.count else { return ((0..<length).map { LetterTile("", group: $0) }, false) }
        let typed = Hangul.split(ctx.local.draft, script: script)
        return ((0..<length).map { i in
            i < typed.count ? LetterTile(typed[i].text, group: typed[i].group) : LetterTile("", group: typed.last.map { $0.group + 1 + i - typed.count } ?? i)
        }, true)
    }

    /// One row, letters of one group close together (a pinyin syllable, a word), centred even if it runs over. Korean rows keep every tile in
    /// its column instead, the jamo of a syllable joined by a pad drawn behind them, so a played, typed or empty row is always the same width.
    private func letterRowNode(_ row: [LetterTile], id: String, y: Double, side: Double, slot: Bool, hangul: Bool, draft: Bool, flipping: Bool) -> Node {
        let groups = Dictionary(grouping: row.indices, by: { row[$0].group }).sorted { $0.key < $1.key }.map(\.value)
        let outer = hangul ? Self.hangulGap : slot ? 10.0 : 5
        let inner = hangul ? Self.hangulGap : slot ? 2.0 : 5
        let widths = groups.map { Double($0.count) * side + Double($0.count - 1) * inner }
        var x = (Self.inner - widths.reduce(0, +) - Double(max(groups.count - 1, 0)) * outer) / 2
        var nodes: [Node] = []
        for (g, members) in groups.enumerated() {
            // The pad reaches into the gaps around its syllable: two pads stay apart by a hair.
            if hangul, members.count > 1 {
                nodes.append(Node.rect(fill: Paint.inset.tuned(alpha: 0.7), corner: 9).id("\(id).pad.\(g)")
                    .at(x - (Self.hangulGap / 2 - 1), -(Self.hangulGap / 2 - 1)).size(widths[g] + Self.hangulGap - 2, side + Self.hangulGap - 2))
            }
            for (m, i) in members.enumerated() {
                nodes.append(letterTile(row[i], id: "\(id).\(i)", side: side, slot: slot, draft: draft, delayMs: flipping ? Double(i) * 220 : nil)
                    .at(x + Double(m) * (side + inner), 0))
            }
            x += widths[g] + outer
        }
        return .box(id, y: y, w: Self.inner, h: side) { nodes }
    }

    /// A letter in its place: its mark's colour with a symbol (● right, ◐ elsewhere), never colour alone. A played letter stands up as a tile on
    /// its lip. Turning over is drawn flat: the tile lies shut until its moment, then opens out of the sunken colour.
    private func letterTile(_ tile: LetterTile, id: String, side: Double, slot: Bool, draft: Bool, delayMs: Double?) -> Node {
        let right = tile.mark == "right"
        let colors: (face: Color, lip: Color, glow: Color)? = switch tile.mark {
        case "right": (.win, Color.win.tuned(brightness: -0.16), Color.win.tuned(alpha: 0.18))
        case "elsewhere": (Paint.sun, Paint.sunLip, Paint.clear("#FFC93C", 0.18))
        case "absent": (Paint.inkFaint.tuned(alpha: 0.35), Paint.inkFaint.tuned(alpha: 0.35, brightness: -0.16), Paint.inkFaint.tuned(alpha: 0.06))
        default: nil
        }
        let ink: Color = right ? Paint.white : .ink
        let typed = draft && !tile.text.isEmpty
        var inner: [Node] = []
        if let colors, !slot {
            inner.append(styled("tlip" + tile.mark, Node.rect(fill: colors.lip, corner: 8).at(0, 3).size(side, side - 3).shadow(colors.glow, radius: 3, dx: 0, dy: 3)))
            inner.append(styled("tface" + tile.mark, .rect(fill: colors.face, stroke: Paint.clear("#FFFFFF", 0.12), lineWidth: 1, corner: 8).size(side, side - 3)))
            inner.append(styled("tgloss", Node.rect(corner: 8).gradient([Paint.clear("#FFFFFF", 0.22), Paint.clear("#FFFFFF", 0)], from: (0.5, 0), to: (0.5, 0.5)).size(side, side - 3)))
            inner.append(styled("tshine", Node.capsule(fill: Paint.clear("#FFFFFF", 0.14)).at(9.6, 3).size(side - 19.2, 4)))
        } else if slot {
            if let colors { inner.append(Node.rect(fill: colors.face, corner: 4).size(side, side)) }
            inner.append(Node.rect(fill: Color.ink.tuned(alpha: 0.6)).at(0, side - 2.5).size(side, 2.5))
        } else {
            inner.append(styled(typed ? "ttyped" : "tblank", .rect(fill: .surfaceSunken, stroke: typed ? .inkMuted : .line, lineWidth: typed ? 2 : 1, corner: 8).size(side, side)))
        }
        if let delayMs {
            inner.append(Node.rect(fill: .surfaceSunken, corner: 8).id(id + ".shut").size(side, side).opacity(0))
            anims.append(Self.opening(id + ".shut", "opacity", from: 1, to: 0, delayMs: delayMs))
            anims.append(Self.opening(id, "sy", from: 0.02, to: 1, delayMs: delayMs))
        }
        if tile.mark != "hidden", !tile.text.isEmpty {
            let look = styled("tword", .words("", size: side * 0.52, weight: "bold", align: "center", minScale: 0.6, w: side, h: side))
            inner.append(Node(look.json.merging(["text": tile.text, "color": ink.json]) { $1 }))
        }
        if let symbol = right ? "●" : tile.mark == "elsewhere" ? "◐" : nil {
            let size = max(7, side * 0.2), w = size * 1.4, h = size * 1.3
            let look = styled("tmark", .text("", size: size, align: "trailing", valign: "top").at(side - 3 - w, 3).size(w, h))
            inner.append(Node(look.json.merging(["text": symbol, "color": ink.json]) { $1 }))
        }
        var words = tile.text.isEmpty ? L("blank") : tile.text
        switch tile.mark {
        case "right": words += ", " + L("right place")
        case "elsewhere": words += ", " + L("in the word, elsewhere")
        case "absent": words += ", " + L("not in the word")
        default: break
        }
        return Node.box(id, w: side, h: side) { inner }.label(words)
    }

    /// Held shut until its moment, then a quarter of a second easing out. One path from the start, so nothing shows open before it.
    private static func opening(_ target: String, _ property: String, from: Double, to: Double, delayMs: Double) -> Anim {
        let ms = delayMs + 250
        let held: [[String: Double]] = delayMs > 0 ? [["t": delayMs / ms, property: from]] : []
        return .keys(target, [["t": 0, property: from]] + held + [["t": 1, property: to]], ms: ms, ease: "out")
    }
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
