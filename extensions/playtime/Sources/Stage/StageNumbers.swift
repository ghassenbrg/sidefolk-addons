import Foundation
import SidefolkExtensionKit

// The number games' parts: the mechanical counter with numerals on cards, a warmth bar with its marker and word, a big field with a pad on felt, and lives. Higher or Lower's boards
// are here too, both ways round in one identity: a number from 1 to a top, never comparing next cards. A range up to a million shrinks its numerals, never the counter.
extension BoardDrawing {
    private static let counterRatio = 515.0 / 760
    /// Blue through lilac to orange, never a verdict's colours.
    private static let warmthColours = ["#8CC4F2", "#A6C8F0", "#BEC8EE", "#CFC6E6", "#E2CCD4", "#F0D0B4", "#F8D098", "#FBC481", "#FAB46C", "#F9A25C"]

    /// The bar: ten soft steps from cold to hot, a marker above where the last guess stands, its word beside it. It keeps its place before there is a reading: no marker, no word.
    func warmth(_ value: Double, label: String?, width: Double) -> Node {
        let wordW = 86.0, barW = width - wordW - 6, h = 30.0
        let step = (barW - 4) / 10
        let at = 2 + (barW - 4) * Swift.min(Swift.max(value, 0), 1) - 7
        var before: Double?
        for case .play(.meter(let old, let oldLabel, _, _)) in ctx.previous?.parts ?? [] where oldLabel != nil { before = old }
        if ctx.fresh, label != nil, let before, before != value {
            let from = 2 + (barW - 4) * Swift.min(Swift.max(before, 0), 1) - 7
            anims.append(.keys("meter.mark", [["t": 0, "x": from], ["t": 1, "x": at]], ms: 460, ease: "spring"))
        } else if ctx.fresh, label != nil, before == nil {
            anims.append(.keys("meter.mark", [["t": 0, "opacity": 0, "y": -6], ["t": 1, "opacity": 1, "y": 0]], ms: 260, ease: "out"))
        }
        return .box("meter", w: width, h: h) {
            Node.capsule(fill: Paint.card, stroke: Paint.card, lineWidth: 2).id("meter.bar").at(0, 12).size(barW, 16).shadow(Paint.black8, radius: 2, dx: 0, dy: 1)
            Node.box("meter.steps", x: 2, y: 14, w: barW - 4, h: 12) {
                for (i, hex) in Self.warmthColours.enumerated() {
                    Node.rect(fill: .hex(hex)).at(Double(i) * step, 0).size(step + 0.5, 12)
                }
            }.corner(6).clip()
            if label != nil {
                Node.path("M 0 0 L 14 0 L 7 9 Z", fill: Paint.ink).id("meter.mark").at(at, 0).size(14, 9)
            }
            if let label {
                Node.words(label, size: 14, weight: "black", align: "center", minScale: 0.6, x: barW + 6, y: 6, w: wordW, h: 22).id("meter.word")
            }
        }.label(label ?? L("No reading yet"))
    }

    /// A number as the person's language groups it ("1,000,000", "1 000 000"), in its digits.
    static func grouped(_ n: Int) -> String { Format.integer(n) }

    /// The counter as a part on its own.
    func counterBlock(_ words: String?, caption: String?) -> PartBlock {
        let w = 200.0
        return PartBlock(.box("counter.part", w: Self.inner, h: w * Self.counterRatio) { counter(words, caption: caption, w: w).at((Self.inner - w) / 2, 0) }, height: w * Self.counterRatio)
    }

    /// The counter from the pack, its window holding live cards: one for each digit, any other sign narrower and bare. A digit that changes turns over, one after another. With no
    /// number yet its cards show a question mark, and nodding while the companion thinks.
    func counter(_ words: String?, caption: String?, w: Double) -> Node {
        let h = w * Self.counterRatio
        let winX = w * 0.185, winY = h * 0.35, winW = w * 0.515, winH = h * 0.385
        let shown = Array(words ?? "??")
        func isCard(_ c: Character) -> Bool { c.wholeNumberValue != nil || c == "?" }
        let gap = Swift.max(winW * 0.012, 1)
        func share(_ c: Character) -> Double { isCard(c) ? 1 : c.isWhitespace ? 0.08 : 0.42 }
        let shares = shown.reduce(0) { $0 + share($1) }
        let cardW = Swift.min((winW - 6 - gap * Double(shown.count - 1)) / shares, winH * 0.72)
        let total = shares * cardW + gap * Double(shown.count - 1)
        let cardH = winH - 6, size = Swift.min(cardH * 0.86, cardW * 1.5)
        var before: [Character] = []
        if let old = ctx.previous?.counterPart?.words { before = Array(old) }
        let turning = ctx.fresh && words != nil && before != shown
        var x = winX + (winW - total) / 2
        var cards: [Node] = []
        for (i, c) in shown.enumerated() {
            let id = "counter.\(i)"
            if isCard(c) {
                let old: Character? = before.count == shown.count && before[i] != c ? before[i] : nil
                func numeral(_ n: Character, _ suffix: String, opacity: Double) -> Node {
                    Node.words(String(n), size: size, weight: "black", color: c == "?" ? Paint.lilacDeepFixed : Paint.onCream, align: "center", minScale: 0.5, w: cardW, h: cardH).id(id + suffix).opacity(opacity)
                }
                cards.append(Node.box(id, x: x, y: winY + 3, w: cardW, h: cardH) {
                    Node.rect(fill: Paint.cream, corner: Swift.min(cardW * 0.14, 6)).id(id + ".card").size(cardW, cardH).shadow(Paint.clear("#4A2E12", 0.28), radius: 1.5, dx: 0, dy: 1)
                    if let old, turning { numeral(old, ".old", opacity: 0) }
                    numeral(c, ".new", opacity: 1)
                    Node.rect(fill: Paint.clear("#14275A", 0.14)).id(id + ".seam").at(0, cardH / 2).size(cardW, 1)
                }.anchor(0.5, 0.5))
                let changes = before.count != shown.count || before[i] != c
                if turning, changes {
                    let delay = Double(i) * 45
                    anims.append(Anim.keys(id, [["t": 0, "sy": 1], ["t": 0.5, "sy": 0.06], ["t": 1, "sy": 1]], ms: 320, ease: "in_out").delay(ms: delay))
                    if old != nil {
                        anims.append(Anim.keys(id + ".old", [["t": 0, "opacity": 1], ["t": 0.5, "opacity": 1], ["t": 0.501, "opacity": 0], ["t": 1, "opacity": 0]], ms: 320).delay(ms: delay))
                        anims.append(Anim.keys(id + ".new", [["t": 0, "opacity": 0], ["t": 0.5, "opacity": 0], ["t": 0.501, "opacity": 1], ["t": 1, "opacity": 1]], ms: 320).delay(ms: delay))
                    }
                } else if words == nil {
                    anims.append(Anim.keys(id, [["t": 0, "sy": 1], ["t": 0.5, "sy": 0.55], ["t": 1, "sy": 1]], ms: 420, ease: "in_out").delay(ms: Double(i) * 90).repeating(3))
                }
                x += cardW + gap
            } else {
                cards.append(Node.words(String(c), size: size * 0.8, weight: "black", color: Paint.onCream, align: "center", minScale: 0.5, x: x, y: winY + 3, w: share(c) * cardW, h: cardH))
                x += share(c) * cardW + gap
            }
        }
        return .box("counter", w: w, h: h) {
            Node.art("art/counter-frame.webp", w: w, h: h).id("counter.frame")
            if let caption {
                Node.words(caption, size: Swift.max(w * 0.052, 8.5), weight: "heavy", color: Paint.onCream, align: "center", minScale: 0.6, x: w * 0.215, y: h * 0.055, w: w * 0.44, h: h * 0.16).id("counter.caption")
            }
            Node.box("counter.window", w: w, h: h) { cards }.leftToRight()
        }
    }

    /// The plate under the counter that says where the number still is: one capsule, its words shrinking.
    private func rangePlate(_ words: String, width: Double, h: Double = 34) -> Node {
        .box("range", w: width, h: h) {
            Node.capsule(fill: Paint.card).id("range.back").size(width, h).shadow(Paint.clear("#4A2E12", 0.14), radius: 3, dx: 0, dy: 2)
            Node.words(words, size: h * 0.56, weight: "black", align: "center", minScale: 0.55, x: 14, w: width - 28, h: h).id("range.words").textLook(tabular: true)
        }
    }

    /// The guesses so far, newest last, on a strip that keeps its room from the first move: as many as fit, each with where the answer lies. Direction, not a verdict: all in ink.
    private func historyRow(_ history: [(Int, String)], width: Double, h: Double = 26) -> Node {
        var chips: [(words: String, mark: String, w: Double)] = []
        var used = 0.0
        for (value, mark) in history.reversed() {
            let words = Self.grouped(value), w = TextFit.width(words, size: 13, weight: "heavy") + 2 + 16 + 14
            guard used + w <= width - 14 else { break }
            chips.insert((words, mark, w), at: 0)
            used += w
        }
        var x = (width - used) / 2
        return .box("history", w: width, h: h) {
            Node.capsule(fill: Paint.lilac).id("history.back").size(width, h)
            for (i, chip) in chips.enumerated() {
                let id = "guess.\(history.count - chips.count + i)"
                let symbol = chip.mark == "higher" ? "arrow.up" : chip.mark == "lower" ? "arrow.down" : "checkmark"
                Node.box(id, x: x, y: 0, w: chip.w, h: h) {
                    Node.words(chip.words, size: 13, weight: "heavy", align: "trailing", minScale: 0.7, x: 2, w: chip.w - 22, h: h).textLook(tabular: true)
                    Node.symbol(symbol, color: chip.mark == "right" ? Color.win : Paint.ink).symbolLook(weight: "heavy").at(chip.w - 18, (h - 12) / 2).size(12, 12)
                    if i > 0 { Node.rect(fill: Paint.clear("#8E72B5", 0.45)).at(0, 6).size(1, h - 12) }
                }
                let _ = (x += chip.w)
            }
        }.leftToRight().label(L("Your guesses"))
    }

    /// What is typed, large, in its field. Refused, it shakes.
    private func numberInput(draft: String, label: String?, y: Double, width: Double, h: Double) -> Node {
        let words = draft.isEmpty ? "?" : Int(draft).map(Self.grouped) ?? draft
        let refused = ctx.fresh && board.parts.contains { if case .note(_, _, .warn) = $0 { true } else { false } }
        if refused { shake("number.field", x: (Self.inner - width) / 2) }
        return .box("number.field", x: (Self.inner - width) / 2, y: y, w: width, h: h) {
            Node.capsule(fill: Paint.card, stroke: Paint.action, lineWidth: 2.5).id("number.well").at(1.25, 1.25).size(width - 2.5, h - 2.5).shadow(Paint.clear("#14275A", 0.14), radius: 3, dx: 0, dy: 2)
            Node.words(words, size: h * 0.68, weight: "black", color: draft.isEmpty ? Paint.inkFaint : Paint.ink, align: "center", minScale: 0.45, x: 20, w: width - 40, h: h)
                .id("number.words").textLook(tabular: true).label(label ?? L("Your guess"))
        }.leftToRight()
    }

    /// 1–9, then ⌫ 0 and Guess, on felt: left to right in every language, as a phone's pad is. Everything takes the same room whether it can be pressed or not.
    private func numberPad(locked: Bool, width: Double, height: Double, submit: String) -> Node {
        let inset = 14.0, gap = 7.0, topRoom = 18.0
        let keyW = (width - 2 * inset - 2 * gap) / 3, keyH = (height - topRoom - inset - 3 * gap) / 4
        let rows = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], ["delete", "0", "return"]]
        let ready = !ctx.local.draft.isEmpty && !locked
        func key(_ k: String, row: Int, column: Int) -> Node {
            let id = "pad.\(k)", isReturn = k == "return", isDelete = k == "delete"
            let node = Node.box(id, x: inset + Double(column) * (keyW + gap), y: topRoom + Double(row) * (keyH + gap), w: keyW, h: keyH) {
                Node.rect(fill: isReturn ? Paint.action : isDelete ? Paint.lilac : Paint.card, corner: 11).id(id + ".face").size(keyW, keyH).shadow(Paint.clear("#3A2A55", 0.24), radius: 2, dx: 0, dy: 2)
                if isDelete {
                    Node.symbol("delete.left", color: Paint.ink).symbolLook(weight: "bold").at((keyW - 24) / 2, (keyH - 20) / 2).size(24, 20)
                } else if isReturn {
                    Node.words(submit, size: 16, weight: "black", color: Paint.onAction, align: "center", minScale: 0.6, x: 4, w: keyW - 8, h: keyH)
                } else {
                    Node.words(Format.integer(Int(k) ?? 0), size: 20, weight: "black", align: "center", w: keyW, h: keyH)
                }
            }
            .area("digit", value: k, label: isDelete ? L("Delete") : isReturn ? submit : k, disabled: locked || (isReturn && !ready), hover: AreaLook(scale: 1.03), press: AreaLook(scale: 0.95, dy: 1), sound: isReturn ? "sounds/tap.wav" : nil)
            return locked ? node.opacity(0.55) : isReturn && !ready ? node.opacity(0.6) : node
        }
        return .box("pad.tray", w: width, h: height) {
            Node.felt("pad.felt", w: width, h: height, corner: 22)
            Node.box("pad", w: width, h: height) {
                for (r, row) in rows.enumerated() {
                    for (c, k) in row.enumerated() { key(k, row: r, column: c) }
                }
            }.leftToRight()
        }
    }

    /// A number field with its pad, standing alone (a number a person hides for another): the same parts as a guess.
    func numberField(min: Int, max: Int, label: String?, history: [(Int, String)], locked: Bool) -> PartBlock {
        if !locked { numberKeys() }
        let h = 42.0, pad = 220.0
        return PartBlock(.box("field", w: Self.inner, h: h + pad - 8) {
            numberPad(locked: locked, width: 340, height: pad, submit: L("Guess")).at(16, h - 8)
            numberInput(draft: ctx.local.draft, label: label, y: 0, width: 300, h: h)
        }, height: h + pad - 8)
    }

    private func numberKeys() {
        keys.append(StageKey(key: "digit", id: "digit"))
        keys.append(StageKey(key: "delete", id: "draft_delete"))
        keys.append(StageKey(key: "return", id: "draft_return"))
    }

    // MARK: Higher or Lower

    /// You guess (concept 09): the counter beside the bubble with your last guess, the range, the warmth, the guesses, what you're typing, the pad, and the quiet way to swap.
    func numbersGuessTable() -> Node {
        let n = board.numberPart!, room = playRoom, width = Self.inner
        let hiding = board.counterPart == nil
        if !n.locked { numberKeys() }
        let counterW = 166.0, counterH = counterW * Self.counterRatio
        let tail = 14.0
        let rangeY = counterH - stageRoomAboveBoard + tail
        let meterY = rangeY + 34 + 3, historyY = meterY + 30 + 4, inputY = historyY + 26 + 5
        let inputH = 44.0, linkH = 26.0
        let padY = inputY + inputH - 12, padH = room - linkH - 2 - padY
        let last = board.counterPart
        // A number being hidden has no counter to show it on, and shows on nothing else but its field.
        var nodes: [Node] = [rangePlate(n.label ?? " ", width: 300).at((width - 300) / 2, rangeY)]
        if let last { nodes.append(counter(last.words ?? "??", caption: last.caption, w: counterW).at(width - counterW + 10, -stageRoomAboveBoard + tail - 4)) }
        if let m = board.meterPart, !hiding {
            nodes.append(warmth(m.value, label: m.label, width: 340).at(16, meterY))
        }
        if !hiding {
            nodes.append(historyRow(n.history, width: 300).at((width - 300) / 2, historyY))
        }
        nodes.append(numberPad(locked: n.locked, width: 340, height: padH, submit: hiding ? L("Hide it") : L("Guess")).at(16, padY))
        nodes.append(numberInput(draft: ctx.buildUp ? "" : ctx.local.draft, label: n.label, y: inputY, width: 300, h: inputH))
        if let link = tableButtons.first { nodes.append(quietLink(link, id: "swap", y: room - linkH)) }
        return .box("guess", w: width, h: room) { nodes }
    }

    /// How far the stage stands above the board's top.
    private var stageRoomAboveBoard: Double { (stageTall ?? 78) + 6 }

    /// The companion guesses (concept 22): the big counter with its "Is it…?", where it stands, Higher, Lower and That's it! large with their key caps. Thinking, the cards nod and the answers wait.
    func numbersAskedTable() -> Node {
        let a = board.answersPart!, c = board.counterPart!, room = playRoom, width = Self.inner
        answerKeys(a.tiles, locked: a.locked)
        let linkH = 26.0, tileH = 86.0, gap = 8.0
        let tilesY = room - linkH - 8 - tileH
        let plateY = tilesY - 10 - 36
        let counterH = plateY - 4 + 16, counterW = counterH / Self.counterRatio
        let tileW = (width - 2 * gap) / 3
        var nodes: [Node] = [
            Node.felt("asked.mat", x: 4, y: counterH * 0.74, w: width - 8, h: plateY + 36 + 6 - counterH * 0.74, corner: 26),
            counter(c.words, caption: c.caption, w: counterW).at((width - counterW) / 2 + counterW * 0.03, -4),
            rangePlate(c.range ?? " ", width: 250, h: 36).at((width - 250) / 2, plateY),
        ]
        let symbols = ["arrow.up", "arrow.down", "checkmark"]
        let caps = Self.keyCaps(a.tiles)
        for (i, tile) in a.tiles.enumerated() {
            nodes.append(answerCard(tile, index: i, cap: caps[i], locked: a.locked, w: tileW, h: tileH, symbol: symbols[safe: i], primary: i == 2).at(Double(i) * (tileW + gap), tilesY))
        }
        if let link = tableButtons.first { nodes.append(quietLink(link, id: "swap", y: room - linkH)) }
        return .box("asked", w: width, h: room) { nodes }
    }

    /// The start (concept 21): the counter saying the range, two big ways to play, the range's segments, Start. "Other…" asks for its number in the counter's place, so nothing below it moves.
    func numbersSetupTable() -> Node {
        let width = Self.inner, room = playRoom
        let modes = board.choicePart("mode")!
        let counterW = 158.0, counterH = counterW * Self.counterRatio
        let segH = 30.0, gap = 6.0
        let startY = room - 46
        let opponentY = startY - gap - segH
        let topY = opponentY - gap - segH
        let cardsY = counterH + gap, cardsH = topY - gap - cardsY
        var nodes: [Node] = []
        if let e = board.entryPart("top") {
            nodes.append(entry(name: "top", kind: "text", label: e.label, placeholder: e.placeholder, button: L("Set"), max: e.max, locked: e.locked).node.at(0, Swift.max((counterH - 98) / 2, 0)))
        } else if let c = board.counterPart {
            nodes.append(Node.felt("setup.mat", x: 40, y: counterH * 0.66, w: width - 80, h: counterH * 0.34, corner: 20, stitch: false))
            nodes.append(counter(c.words, caption: c.caption, w: counterW).at((width - counterW) / 2 + 4, 0))
        }
        let w = (width - 10) / 2
        for (i, o) in modes.options.enumerated() {
            nodes.append(wayCard(o, on: modes.selected == o.value, w: w, h: cardsH).at(Double(i) * (w + 10), cardsY))
        }
        choiceArrows(name: "mode", options: modes.options, selected: modes.selected, columns: 2)
        if let t = board.choicePart("top") {
            nodes.append(choice(name: "top", label: t.label, style: .segmented, options: t.options, selected: t.selected, compact: true, labelWidth: 62).node.at(0, topY))
        }
        if let o = board.choicePart("opponent") {
            nodes.append(choice(name: "opponent", label: L("Play"), style: .segmented, options: o.options, selected: o.selected, compact: true, labelWidth: 62).node.at(0, opponentY))
        }
        nodes.append(buttonRow(tableButtons, id: "dock").node.at(0, startY))
        return .box("setup", w: width, h: room) { nodes }
    }

    /// One way to play: its name, its picture, a line. "Guess mine" is the sealed envelope; "I'll guess yours" is the person themselves with a number in a thought.
    private func wayCard(_ o: ChoiceOption, on: Bool, w: Double, h: Double) -> Node {
        let id = "way.\(o.value)", titleH = 28.0, lineH = 30.0, picH = h - titleH - lineH - 12
        let picture: Node
        if o.value == "mine" {
            let pw = Swift.min(w - 40, picH * 420 / 289), ph = pw * 289 / 420
            picture = Node.art("art/envelope-q.webp", w: pw, h: ph).id(id + ".art").at((w - pw) / 2, 8 + titleH + (picH - ph) / 2)
        } else {
            let side = Swift.min(picH * 0.74, w * 0.44), cloudW = side * 0.86, cloudH = cloudW * 247 / 300
            let x = (w - side - cloudW * 0.72) / 2, y = 8 + titleH + picH - side
            picture = Node.box(id + ".art", w: w, h: h) {
                Node.person().id(id + ".person").at(x, y).size(side, side).corner(side / 2).clip()
                Node.art("art/thought-cloud.webp", x: x + side * 0.74, y: 8 + titleH, w: cloudW, h: cloudH)
                Node.words(Format.integer(42), size: cloudH * 0.36, weight: "black", color: Paint.onCream, align: "center", x: x + side * 0.74, y: 8 + titleH, w: cloudW, h: cloudH * 0.92)
            }
        }
        return Node.box(id, w: w, h: h) {
            Node.rect(fill: o.value == "mine" ? Paint.card : Paint.lilac, corner: 16).id(id + ".face").size(w, h).shadow(Paint.clear("#4A2E12", 0.14), radius: 4, dx: 0, dy: 2)
            Node.rect(stroke: on ? Paint.action : Paint.edge, lineWidth: on ? 3 : 1, corner: 16).id(id + ".edge").size(w, h)
            Node.words(o.label, size: 18, weight: "black", align: "center", minScale: 0.6, x: 8, y: 8, w: w - 16, h: titleH)
            picture
            if let detail = o.detail { Node.words(detail, size: 12.5, weight: "semibold", align: "center", lines: 2, minScale: 0.7, x: 8, y: h - lineH - 4, w: w - 16, h: lineH) }
        }.area("choice", value: "mode|\(o.value)", label: o.label, hover: AreaLook(scale: 1.015), press: AreaLook(scale: 0.98), selected: on, sound: "sounds/tap.wav")
    }

    /// Balloons or hearts left. Seven balloons, each its own colour, hang from a rail and keep their places. A wrong letter pops the last of those left where it hangs: it swells, bursts
    /// into a few scraps of its colour, its neighbours sway, and only its string stays, on the rail, for the rest of the word. A heart keeps its outline.
    func lives(total: Int, left: Int, symbol: String) -> PartBlock {
        guard symbol == "balloon" else {
            let w = 22.0, gap = 4.0
            return PartBlock(.box("lives", w: Self.inner, h: w) {
                for i in 0..<total {
                    let kept = i < left
                    Node.symbol(kept ? "heart.fill" : "heart", color: kept ? [Paint.coral, Paint.sun, Paint.blue, Paint.green, Paint.purple][i % 5] : Paint.inkFaint)
                        .symbolLook(weight: "regular").id("life.\(i)").at(Double(i) * (w + gap), 0).size(w, w).scale(kept ? 1 : 0.8)
                }
            }.label(L("{left} of {total} left", ["left": left, "total": total])), height: w)
        }
        let h = Self.balloonH, w = h * 200 / 305
        let step = min(Self.balloonRailW / Double(max(total, 1)), w + 4)
        let startX = (Self.balloonRailW - step * Double(total)) / 2 + (step - w) / 2
        // A pop plays once: the verdict after a last balloon's build-up shows it gone.
        let before: Int? = ctx.fresh && !ctx.local.builtUp ? ctx.previous?.play { if case .lives(_, let left, _) = $0 { left } else { nil } } : nil
        let popping = before.map { $0 > left ? Array(left..<$0) : [] } ?? []
        var nodes: [Node] = []
        for i in 0..<total {
            let x = startX + Double(i) * step, id = "life.\(i)"
            if i >= left {
                // Its string, still tied to the rail.
                nodes.append(Node.capsule(fill: Paint.signInk).id(id + ".string").at(x + w / 2 - 0.75, 0).size(1.5, 11).anchor(0.5, 0).opacity(popping.contains(i) ? 0 : 0.9))
            }
            if i < left || popping.contains(i) {
                nodes.append(Node.image("art/game-balloon-\(i % 7).webp").id(id).at(x, 0).size(w, h).anchor(0.5, 0).rotate(0).opacity(i < left ? 1 : 0))
            }
            if popping.contains(i) { nodes += pop(id: id, index: i, x: x, w: w, h: h) }
            else if !popping.isEmpty, i < left, let first = popping.first {
                // The air moves: those beside it sway, a little less the further they are.
                let swing = 5.0 / Double(max(abs(first - i), 1))
                anims.append(.keys(id, [["t": 0, "rotate": 0], ["t": 0.25, "rotate": swing], ["t": 0.6, "rotate": -swing * 0.6], ["t": 1, "rotate": 0]], ms: 640, ease: "in_out"))
            }
        }
        return PartBlock(.box("lives", w: Self.balloonRailW, h: h) { nodes }.label(L("{left} of {total} left", ["left": left, "total": total])), height: h)
    }

    static let balloonH = 58.0, balloonRailW = 336.0

    /// The burst, about half a second: it swells and is gone, its scraps fly out and fall, and the string it hung by is what's left, swinging.
    private func pop(id: String, index: Int, x: Double, w: Double, h: Double) -> [Node] {
        let hue = [Color.hex("#E2574C"), Color.hex("#F4C63D"), Color.hex("#6FB2E8"), Color.hex("#A06BD6"), Color.hex("#F28A2E"), Color.hex("#EE86B4"), Color.hex("#E0A92E")][index % 7]
        anims.append(.keys(id, [["t": 0, "sx": 1, "sy": 1, "opacity": 1], ["t": 0.6, "sx": 1.28, "sy": 1.22, "opacity": 1], ["t": 1, "sx": 1.5, "sy": 1.45, "opacity": 0]], ms: 170, ease: "in"))
        let cx = x + w / 2, cy = h * 0.6
        var nodes: [Node] = []
        // A ring of air, for an instant.
        let ring = id + ".ring"
        nodes.append(Node.ellipse(stroke: Paint.white, lineWidth: 2.5).id(ring).at(cx - w / 2, cy - w / 2).size(w, w).anchor(0.5, 0.5).opacity(0))
        heldKeys(ring, [["t": 0, "scale": 0.5, "opacity": 0.9], ["t": 1, "scale": 1.5, "opacity": 0]], delayMs: 110, ms: 260, ease: "out")
        for k in 0..<10 {
            let angle = Double(k) / 10 * 2 * .pi + 0.3, reach = 30.0 + Double(k % 3) * 10, side = 7.0 + Double(k % 2) * 3
            let endX = cx + cos(angle) * reach - side / 2, endY = cy + sin(angle) * reach * 0.8 + 16 - side / 2
            let bit = "\(id).bit.\(k)"
            nodes.append(Node.rect(fill: hue, corner: 1.5).id(bit).at(endX, endY).size(side, side * 0.7).opacity(0))
            heldKeys(bit, [["t": 0, "x": cx - side / 2, "y": cy, "opacity": 1, "rotate": 0], ["t": 0.55, "opacity": 1], ["t": 1, "x": endX, "y": endY, "opacity": 0, "rotate": 150]], delayMs: 120, ms: 520, ease: "out")
        }
        heldKeys(id + ".string", [["t": 0, "opacity": 0, "rotate": 0], ["t": 0.05, "opacity": 0.9, "rotate": 14], ["t": 0.4, "opacity": 0.9, "rotate": -9], ["t": 0.7, "opacity": 0.9, "rotate": 5], ["t": 1, "opacity": 0.9, "rotate": 0]], delayMs: 130, ms: 700, ease: "in_out")
        return nodes
    }
}
