import Foundation
import SidefolkExtensionKit

// Guess My Animal, in its field journal: the photo of nothing yet, the question on a torn paper card of one size, Yes / No / Not sure as three large key-capped answers that keep
// their places whatever is asked. A wrong guess turns to the page for a new animal: the fields one under another, each opening as the one before it is filled.
extension BoardDrawing {
    /// A card with a soft torn edge, always the same one: nothing about it depends on what's written.
    private func tornPaper(_ id: String, w: Double, h: Double) -> Node {
        // A deckle: small steps along each side from a fixed list, so it's the same shape on every scene.
        let wob = [0.0, 1.6, -0.8, 1.2, -1.4, 0.6, 1.8, -1.0, 0.4, -1.6, 1.0, -0.4]
        var path = "M 8 \(wob[0] + 2) "
        let steps = 22
        for i in 1...steps { path += "L \(8 + (w - 16) * Double(i) / Double(steps)) \(2 + wob[i % 12]) " }
        for i in 1...6 { path += "L \(w - 2 + wob[(i + 3) % 12]) \(8 + (h - 16) * Double(i) / 6) " }
        for i in 1...steps { path += "L \(w - 8 - (w - 16) * Double(i) / Double(steps)) \(h - 2 + wob[(i + 5) % 12]) " }
        for i in 1...6 { path += "L \(2 + wob[(i + 7) % 12]) \(h - 8 - (h - 16) * Double(i) / 6) " }
        return Node.path(path + "Z", fill: Paint.card, stroke: Paint.clear("#A08A70", 0.3), lineWidth: 0.75).id(id).size(w, h).shadow(Paint.clear("#4A2E12", 0.16), radius: 4, dx: 0, dy: 2)
    }

    func animalTable() -> Node {
        let a = board.answersPart!, room = playRoom, width = Self.inner
        let thinking = board.afterMs != nil
        let question = thinking ? "…" : board.promptPart?.text ?? ""
        answerKeys(a.tiles, locked: a.locked)
        let photoH = 116.0, photoW = photoH * 420 / 486
        let photoY = 4.0, cardX = 26.0, cardW = width - 2 * cardX, cardY = photoY + photoH - 12, cardH = 96.0
        let tilesY = cardY + cardH + 8, tileH = 88.0, gap = 8.0, tileW = (cardW - 2 * gap) / 3
        let caps = Self.keyCaps(a.tiles)
        var nodes: [Node] = [
            Node.art("art/mystery-photo.webp", w: photoW, h: photoH).id("animal.photo").at((width - photoW) / 2, photoY).label(L("A mystery animal")),
            tornPaper("animal.card", w: cardW, h: cardH).at(cardX, cardY),
            Node.words(question, size: 19, weight: "heavy", align: "center", lines: 3, minScale: 0.55, x: cardX + 16, y: cardY + 8, w: cardW - 32, h: cardH - 16).id("animal.words").label(question),
        ]
        if ctx.fresh, ctx.previous?.promptPart?.text != board.promptPart?.text {
            anims.append(.keys("animal.words", [["t": 0, "opacity": 0], ["t": 1, "opacity": 1]], ms: 220, ease: "out"))
        }
        // A guess offers two answers: the third keeps its place, faded, so Yes and No are where they were.
        for i in 0..<3 {
            let tile = a.tiles[safe: i] ?? Tile(L("Not sure"), state: .faded, key: "?")
            nodes.append(answerCard(tile, index: i, cap: a.tiles[safe: i] == nil ? "?" : caps[i], locked: a.locked || a.tiles[safe: i] == nil, w: tileW, h: tileH).at(cardX + Double(i) * (tileW + gap), tilesY))
        }
        return .box("animal", w: width, h: room) { nodes }
    }

    /// The page for a new animal (concept 23). Sidefolk sends one field's words at a time, so each field opens when the one before is sent; a filled one shows its words where it stands.
    func animalTeachTable() -> Node {
        let width = Self.inner, room = playRoom
        let page = board.teaches ? board : ctx.previous ?? board
        let locked = ctx.buildUp
        let x = 26.0, w = width - 2 * x
        let labelH = 18.0, fieldH = 38.0, rowGap = 10.0
        var y = 4.0
        var nodes: [Node] = []
        let animal = page.entryPart("animal"), question = page.entryPart("question")
        let active = animal?.locked == false ? "animal" : question?.locked == false ? "question" : nil
        func field(_ name: String, symbol: String, part: (label: String?, placeholder: String?, locked: Bool, max: Int)?, done: Bool) {
            guard let part else { return }
            let labelW = w
            nodes.append(Node.symbol(symbol, color: Paint.coral).symbolLook(weight: "bold").at(x, y + 1).size(16, 16))
            nodes.append(Node.words(part.label ?? "", size: 13.5, weight: "heavy", minScale: 0.65, x: x + 21, y: y, w: labelW - 21, h: labelH))
            y += labelH + 3
            if done {
                nodes.append(.box("entry.\(name).box", x: x, y: y, w: w, h: fieldH) {
                    Node.rect(fill: Paint.card(0.6), stroke: Paint.edge, lineWidth: 1, corner: 10).id("entry.well.\(name)").size(w, fieldH)
                    Node.words(part.placeholder ?? "", size: 16, weight: "semibold", minScale: 0.6, x: 12, w: w - 24, h: fieldH).id("entry.\(name).done")
                })
            } else {
                var box = fieldBox(name, placeholder: part.placeholder, max: part.max, locked: part.locked || locked, focus: active == name, x: x, y: y, w: w, h: fieldH)
                if part.locked { box = box.opacity(0.55) }
                nodes.append(box)
            }
            y += fieldH + rowGap
        }
        field("animal", symbol: "pawprint.fill", part: animal, done: animal?.locked == true)
        field("question", symbol: "magnifyingglass", part: question, done: question?.locked == true && animal?.locked == true && active == nil)
        // The answer for the new animal: Yes or No, navy when picked.
        if let c = page.choicePart("new_answer") {
            nodes.append(Node.symbol("checkmark.circle.fill", color: Paint.coral).symbolLook(weight: "bold").at(x, y + 1).size(16, 16))
            nodes.append(Node.words(c.label ?? "", size: 13.5, weight: "heavy", minScale: 0.65, x: x + 21, y: y, w: w - 21, h: labelH))
            y += labelH + 3
            let open = active == nil && !locked, gap = 10.0, optionW = (w - gap) / 2, optionH = 42.0
            for (i, o) in c.options.enumerated() {
                let on = c.selected == o.value, id = "teach.\(o.value)"
                var option = Node.box(id, x: x + Double(i) * (optionW + gap), y: y, w: optionW, h: optionH) {
                    Node.capsule(fill: on ? Paint.action : Paint.card, stroke: on ? Paint.action : Paint.edge, lineWidth: 1.5).id(id + ".face").size(optionW, optionH)
                    Node.symbol(on ? "checkmark.circle.fill" : "circle", color: on ? Paint.onAction : Paint.inkSoft).symbolLook(weight: "semibold").at(optionW / 2 - 40, (optionH - 18) / 2).size(18, 18)
                    Node.words(o.label, size: 16, weight: "heavy", color: on ? Paint.onAction : Paint.ink, minScale: 0.6, x: optionW / 2 - 16, w: optionW / 2 + 8, h: optionH)
                }.area("choice", value: "new_answer|\(o.value)", label: o.label, disabled: !open, hover: AreaLook(scale: 1.015), press: AreaLook(scale: 0.97), selected: on, sound: "sounds/tap.wav")
                if !open { option = option.opacity(0.5) }
                nodes.append(option)
            }
            if open { choiceArrows(name: "new_answer", options: c.options, selected: c.selected, columns: 2) }
            if open, c.options.count == 2 {
                keys.append(StageKey(key: "y", id: "teach_y", area: "choice", value: "new_answer|\(c.options[0].value)"))
                keys.append(StageKey(key: "n", id: "teach_n", area: "choice", value: "new_answer|\(c.options[1].value)"))
            }
            y += optionH + rowGap + 2
        }
        let buttons = page.parts.compactMap { part -> GameButton? in if case .button(let b) = part { b } else { nil } }
        let skipW = 92.0, rememberW = w - skipW - 10, rowH = 46.0
        if let remember = buttons.first(where: { $0.style == .primary }) {
            if let active, !locked {
                // While a field is open, the button sends what is in it: Sidefolk dims it while the field is empty.
                nodes.append(.box("teach.send", x: x, y: y, w: rememberW, h: rowH) {
                    Node.capsule(fill: Paint.action).id("teach.send.fill").size(rememberW, rowH).shadow(Paint.clear("#14275A", 0.22), radius: 4, dx: 0, dy: 2)
                    Node.words(remember.label, size: 16, weight: "heavy", color: Paint.onAction, align: "center", minScale: 0.6, x: 8, w: rememberW - 16, h: rowH)
                }.area("entry_send", label: remember.label, hover: AreaLook(scale: 1.015), press: AreaLook(scale: 0.97, dy: 1), submits: active, sound: "sounds/tap.wav"))
            } else {
                var b = remember
                if locked { b.disabled = true }
                nodes.append(buttonRow([b], id: "teach.remember", width: rememberW).node.at(x, y))
            }
        }
        if var skip = buttons.first(where: { $0.style != .primary }) {
            if locked { skip.disabled = true }
            nodes.append(buttonRow([skip], id: "teach.skip", width: skipW).node.at(x + rememberW + 10, y + 5))
        }
        return .box("teach", w: width, h: room) { nodes }
    }
}
