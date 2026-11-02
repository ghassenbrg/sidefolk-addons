import Foundation
import SidefolkExtensionKit

// What goes with a puzzle's grid (PuzzleView, PlayModel+Parts): Sudoku's digit pad, the clock and notes switch beside the eyebrow, the line of keys, and what the panel
// did for a puzzle by itself: the arrows' cursor, the cell picked, pen or pencil, a plot stretched from the keyboard.
extension BoardDrawing {
    // MARK: Keys

    func puzzleKeys(input: String, digits: Int?, cells: [PuzzleCell]) {
        arrowKeys()
        if input == "digits" { keys.append(StageKey(key: "n", id: "pad_notes", area: "notes")) }
        switch input {
        case "digits":
            // A given's number can't change: nothing goes, nothing sounds.
            if let c = ctx.local.cursor, cells.indices.contains(c), cells[c].given { break }
            for d in 0...(digits ?? 0) { keys.append(StageKey(key: "\(d)", id: "pad_\(d)", area: "pad", value: "\(d)")) }
            // A digit in another script, after the ones above.
            keys.append(StageKey(key: "digit", id: "pad_any"))
            keys.append(StageKey(key: "delete", id: "pad_delete", area: "pad", value: "0"))
        case "drag":
            keys.append(StageKey(key: "return", id: "plot_return"))
            keys.append(StageKey(key: "space", id: "plot_space"))
            // While a plot is drawn from the keyboard, Esc lets the plot go, not the panel.
            if ctx.local.dragFrom != nil { keys.append(StageKey(key: "escape", id: "plot_letgo")) }
        default:
            guard let c = ctx.local.cursor, cells.indices.contains(c), !cells[c].given, let columns = board.puzzlePart?.columns else { return }
            for key in ["return", "space"] { keys.append(StageKey(key: key, id: "puzzle_\(key)", area: "cell", value: "\(c / columns),\(c % columns)")) }
        }
    }

    // MARK: Under the grid

    /// The numbers under a Sudoku, and a key to clear the cell: small toy keys on a lip, narrow enough for ten in a row.
    func digitPad(digits: Int, locked: Bool) -> Node {
        let gap = 4.0, height = 34.0, count = Double(digits + 1)
        let w = (Self.inner - gap * (count - 1)) / count
        let off = locked || ctx.local.cursor == nil
        // Over a given the keys look as they do, but press nothing: its number can't change.
        let given = ctx.local.cursor.flatMap { board.puzzlePart?.cells[safe: $0]?.given } ?? false
        return Node.box("pad", w: Self.inner, h: height) {
            for d in 1...digits { digitKey("\(d)", value: d, x: Double(d - 1) * (w + gap), w: w, h: height, off: off, given: given) }
            digitKey(nil, value: 0, x: Double(digits) * (w + gap), w: w, h: height, off: off, given: given)
        }.leftToRight()
    }

    private func digitKey(_ text: String?, value: Int, x: Double, w: Double, h: Double, off: Bool, given: Bool) -> Node {
        let id = "pad.\(value)"
        let face = Node.box(id + ".top", w: w, h: h) {
            Node.rect(fill: Paint.card, stroke: Paint.edge, lineWidth: 1, corner: 9.5).at(0.5, 0.5).size(w - 1, h - 1)
            if let text {
                Node.words(text, size: 17, weight: "heavy", color: .ink, align: "center", w: w, h: h)
            } else {
                // Left in every language: the pad is the same picture, and `delete.backward` would turn around in Arabic.
                Node.symbol("delete.left", color: .ink).symbolLook(weight: "heavy").at((w - 25) / 2, (h - 25) / 2).size(25, 25)
            }
        }
        .area("pad", value: "\(value)", label: text ?? L("Clear the cell"), disabled: off, hover: nil, press: AreaLook(dy: 2), sound: given ? nil : "sounds/tap.wav")
        var key = Node.box(id, x: x, w: w, h: h) {
            Node.rect(fill: Paint.lip, corner: 10).id(id + ".lip").at(0, 3).size(w, h)
            face
        }
        if off { key = key.opacity(0.5) }
        return key
    }

    // MARK: Beside the eyebrow

    /// A puzzle's clock and Sudoku's notes switch share the eyebrow's row, so a 9 × 9 board keeps its room; side by side, so a long German level never runs under the switch.
    var puzzleEyebrow: (((node: Node, width: Double, height: Double)) -> PartBlock)? {
        guard let p = board.puzzlePart, let seconds = p.seconds, let eyebrow = board.promptPart?.eyebrow else { return nil }
        return { [self] _ in
            let gap = 6.0
            let clock = puzzleClock(seconds, running: p.running)
            let notes = p.input == "digits" && !p.locked ? notesSwitch() : nil
            let room = Self.inner - clock.width - gap - (notes.map { $0.width + gap } ?? 0)
            let chip = roundChip(eyebrow, room: room)
            let height = max(clock.height, chip.height, notes?.height ?? 0)
            return PartBlock(.box("eyebrow", w: Self.inner, h: height) {
                clock.node.at(0, (height - clock.height) / 2)
                chip.node.at(clock.width + gap + (room - chip.width) / 2, (height - chip.height) / 2)
                if let notes { notes.node.at(Self.inner - notes.width, (height - notes.height) / 2) }
            }, height: height)
        }
    }

    /// The time so far, counting on once a second while the puzzle is being played. Sidefolk counts it, so it wakes nothing of Playtime's.
    private func puzzleClock(_ seconds: Double, running: Bool) -> (node: Node, width: Double, height: Double) {
        // Any digit takes the room of any other: it stays the same size until it needs another place.
        let shape = PuzzleParts.clock(Int(seconds)).map { $0.isNumber ? "0" : String($0) }.joined()
        let wordsW = TextFit.width(shape, size: 13, weight: "heavy") + 2
        let textH = TextFit.lineHeight(13, "heavy")
        let w = 10 + 13 + 5 + wordsW + 10, h = textH + 8
        return (.box("clock", w: w, h: h) {
            Node.capsule(fill: Paint.card(0.96), stroke: Paint.edge, lineWidth: 1).id("clock.pill").size(w, h).shadow(Paint.black8, radius: 3, dx: 0, dy: 1)
            Node.symbol("clock", color: .ink).symbolLook(weight: "bold").at(10, (h - 13) / 2).size(13, 13)
            Node.clock(seconds: seconds, running: running, size: 13, weight: "heavy", align: "leading").id("clock.time").at(10 + 13 + 5, 4).size(wordsW, textH)
        }, w, h)
    }

    /// Pencil or pen, for Sudoku: N switches.
    private func notesSwitch() -> (node: Node, width: Double, height: Double) {
        let on = ctx.local.notes
        let words = on ? L("Notes on") : L("Notes off")
        let wordsW = TextFit.width(words, size: 12, weight: "heavy")
        let textH = TextFit.lineHeight(12, "heavy")
        let w = 10 + 13 + 5 + wordsW + 10, h = textH + 8
        let ink: Color = on ? .onAccent : .ink
        return (Node.box("notes", w: w, h: h) {
            Node.capsule(fill: on ? .accent : Paint.card(0.96), stroke: on ? nil : Paint.edge, lineWidth: 1).id("notes.pill").size(w, h)
            Node.symbol(on ? "pencil" : "pencil.slash", color: ink).symbolLook(weight: "bold").at(10, (h - 13) / 2).size(13, 13)
            Node.words(words, size: 12, weight: "heavy", color: ink, minScale: 1, x: 10 + 13 + 5, y: 4, w: wordsW, h: textH)
        }.area("notes", label: words, hover: nil, press: AreaLook(scale: 0.95), selected: on), w, h)
    }

    // MARK: The line of keys

    var puzzleFooter: String? {
        guard let p = board.puzzlePart, !p.locked else { return nil }
        switch p.input {
        case "tap": return L("Click a cell to change it")
        case "drag":
            return ctx.local.dragFrom != nil ? L("Arrows stretch the plot · Return plants it · Esc lets it go")
                : L("Drag corner to corner, or Space and the arrows · Click a plot to clear it")
        default: return L("Pick a cell, then a number · N for notes")
        }
    }

    // MARK: Moves

    /// What the panel did for a puzzle by itself: the arrows' cursor, the cell picked, pen or pencil, a plot stretched from the keyboard.
    static func puzzleMove(_ move: SurfaceMove, board: Board, local: inout LocalParts) -> StageAction? {
        guard let p = board.puzzlePart, !p.locked else { return nil }
        local.plantSound = false
        let w = p.columns, count = p.rows * p.columns
        func stepped(_ id: String) { local.cursor = StageMoves.move(id, cursor: local.cursor, columns: w, count: count, rtl: false) }
        func plant(_ a: Int, _ b: Int) -> StageAction {
            local.plantSound = true
            return .play(a == b ? .cell(row: a / w, column: a % w) : .area(row: a / w, column: a % w, toRow: b / w, toColumn: b % w))
        }
        func place(_ value: Int) -> StageAction {
            guard let c = local.cursor, p.cells[safe: c]?.given == false else { return .ignore }
            return .play(.place(row: c / w, column: c % w, value: value, note: local.notes && value > 0))
        }
        switch move {
        // A puzzle is the same picture in every language: the arrows move as they point.
        case .key(let id, _, _) where id.hasPrefix("arrow_"):
            stepped(id)
            return .redraw
        case .click("puzzle_pick", let value?, _):
            local.cursor = Int(value)
            return .redraw
        case .click("notes", _, _):
            local.notes.toggle()
            return .redraw
        case .click("pad", let value?, _):
            return Int(value).map(place) ?? .ignore
        case .key("pad_any", let character, _):
            guard let d = character?.first?.wholeNumberValue, (0...(p.digits ?? 0)).contains(d) else { return .ignore }
            return place(d)
        case .key("plot_return", _, _), .key("plot_space", _, _):
            guard let from = local.dragFrom else {
                let c = local.cursor ?? 0
                local.cursor = c
                local.dragFrom = c
                return .redraw
            }
            local.dragFrom = nil
            return plant(from, local.cursor ?? from)
        case .key("plot_letgo", _, _):
            local.dragFrom = nil
            return .redraw
        case .dragCells("plots", _, let from, let to):
            guard from.count == 2, to.count == 2 else { return .ignore }
            local.dragFrom = nil
            return plant(from[0] * w + from[1], to[0] * w + to[1])
        default: return nil
        }
    }

    /// A new board shows: a plot being stretched goes, a cursor past a smaller board goes, and Sudoku's pad works at once, the first open cell picked until the person picks another.
    static func puzzleSettle(_ board: Board, local: inout LocalParts) {
        local.dragFrom = nil
        guard let p = board.puzzlePart else { return }
        if let c = local.cursor, c >= p.rows * p.columns { local.cursor = nil }
        if p.input == "digits", local.cursor == nil { local.cursor = p.cells.firstIndex { !$0.given } }
    }
}

extension Board {
    var puzzlePart: (rows: Int, columns: Int, cells: [PuzzleCell], input: String, digits: Int?, seconds: Double?, running: Bool, locked: Bool)? {
        play { if case .puzzle(let rows, let columns, let cells, let input, let digits, _, _, _, let seconds, let running, let locked) = $0 { (rows, columns, cells, input, digits, seconds, running, locked) } else { nil } }
    }

    /// This board with the time `now` says. A scene's clock counts from when the scene shows, so a board drawn again after a key (the
    /// cursor moved, the menu and back) has to say the time it is now, or the clock would jump back to the last move's.
    func clocked(from now: Board?) -> Board {
        guard let seconds = now?.puzzlePart?.seconds else { return self }
        var out = self
        out.parts = parts.map {
            guard case .play(.puzzle(let rows, let columns, let cells, let input, let digits, let box, let edges, let plots, _, true, let locked)) = $0 else { return $0 }
            return .play(.puzzle(rows: rows, columns: columns, cells: cells, input: input, digits: digits, box: box, edges: edges, plots: plots, seconds: seconds, running: true, locked: locked))
        }
        return out
    }
}
