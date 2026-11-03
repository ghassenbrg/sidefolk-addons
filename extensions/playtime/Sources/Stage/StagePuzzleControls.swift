import Foundation
import SidefolkExtensionKit

// What goes with a puzzle's grid: Sudoku's digit pad and notes switch, the clock beside the eyebrow, the line of keys, the solved board on the end card, and what the panel
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

    /// The numbers under a Sudoku and a key to clear the cell: navy keys on a lip (ivory at night), the eraser outlined beside them, narrow enough for ten in a row.
    func digitPad(digits: Int, locked: Bool) -> Node {
        let gap = 5.0, height = PuzzleSkin.padHeight, count = Double(digits + 1)
        let w = (Self.inner - gap * (count - 1)) / count
        let off = locked || ctx.local.cursor == nil
        // Over a given nothing can be typed: its number can't change, so the keys say so.
        let given = ctx.local.cursor.flatMap { board.puzzlePart?.cells[safe: $0]?.given } ?? false
        return Node.box("pad", w: Self.inner, h: height + 3) {
            for d in 1...digits { digitKey("\(d)", value: d, x: Double(d - 1) * (w + gap), w: w, h: height, off: off, given: given) }
            digitKey(nil, value: 0, x: Double(digits) * (w + gap), w: w, h: height, off: off, given: given)
        }.leftToRight()
    }

    private func digitKey(_ text: String?, value: Int, x: Double, w: Double, h: Double, off: Bool, given: Bool) -> Node {
        let id = "pad.\(value)"
        let face = Node.box(id + ".top", w: w, h: h) {
            if let text {
                Node.rect(fill: Paint.action, corner: 11).size(w, h)
                Node.words(text, size: 19, weight: "heavy", color: Paint.onAction, align: "center", w: w, h: h)
            } else {
                Node.rect(fill: Paint.card, stroke: Paint.ink, lineWidth: 1.5, corner: 10.25).at(0.75, 0.75).size(w - 1.5, h - 1.5)
                Node.symbol("eraser", color: Paint.ink).symbolLook(weight: "semibold").at((w - 22) / 2, (h - 22) / 2).size(22, 22)
            }
        }
        .area("pad", value: "\(value)", label: text ?? L("Clear the cell"), disabled: off || given, hover: AreaLook(scale: 1.03), press: AreaLook(dy: 2), sound: given ? nil : "sounds/tap.wav")
        var key = Node.box(id, x: x, w: w, h: h + 3) {
            Node.rect(fill: text == nil ? Paint.lip : Paint.actionLip, corner: 11).id(id + ".lip").at(0, 3).size(w, h)
            face
        }
        if off || given { key = key.opacity(0.45) }
        return key
    }

    // MARK: Beside the round

    /// A puzzle's clock, at the head of the round's line.
    func puzzleClockPill() -> (node: Node, width: Double)? {
        guard let p = board.puzzlePart, let seconds = p.seconds else { return nil }
        let clock = puzzleClock(seconds, running: p.running)
        return (clock.node, clock.width)
    }

    /// Notes stands first among Sudoku's controls, in its place through the last beat too.
    var puzzleDockExtra: (node: Node, width: Double)? {
        guard let p = board.puzzlePart, p.input == "digits" else { return nil }
        let notes = notesSwitch(locked: p.locked)
        return (notes.node, notes.width)
    }

    /// The time so far, counting on once a second while the puzzle is being played. Sidefolk counts it, so it wakes nothing of Playtime's.
    private func puzzleClock(_ seconds: Double, running: Bool) -> (node: Node, width: Double, height: Double) {
        // Any digit takes the room of any other: it stays the same size until it needs another place.
        let shape = PuzzleParts.clock(Int(seconds)).map { $0.isNumber ? "0" : String($0) }.joined()
        let wordsW = TextFit.width(shape, size: 13, weight: "heavy") + 2
        let textH = TextFit.lineHeight(13, "heavy")
        let w = 10 + 13 + 5 + wordsW + 10, h = 20.0
        return (.box("clock", w: w, h: h) {
            Node.capsule(fill: Paint.card(0.96), stroke: Paint.edge, lineWidth: 1).id("clock.pill").size(w, h).shadow(Paint.black8, radius: 3, dx: 0, dy: 1)
            Node.symbol("clock", color: .ink).symbolLook(weight: "bold").at(10, (h - 13) / 2).size(13, 13)
            Node.clock(seconds: seconds, running: running, size: 13, weight: "heavy", align: "leading").id("clock.time").at(10 + 13 + 5, (h - textH) / 2).size(wordsW, textH)
        }, w, h)
    }

    /// A real switch, for Sudoku: its thumb crosses as N or a click turns it, and the cell's outline goes dashed.
    private func notesSwitch(locked: Bool) -> (node: Node, width: Double, height: Double) {
        let on = ctx.local.notes
        let words = L("Notes")
        let wordsW = Swift.min(TextFit.width(words, size: 12.5, weight: "heavy") + 1, 62)
        let trackW = 30.0, trackH = 18.0, thumb = 14.0
        let w = 9 + wordsW + 5 + trackW + 7, h = 28.0
        var node = Node.box("notes", w: w, h: h) {
            Node.capsule(fill: Paint.card(0.96), stroke: Paint.edge, lineWidth: 1).id("notes.pill").size(w, h)
            Node.words(words, size: 12.5, weight: "heavy", minScale: 0.75, x: 9, w: wordsW, h: h)
            Node.capsule(fill: on ? Paint.lilacDeep : Paint.inkFaint).id("notes.track").at(9 + wordsW + 5, (h - trackH) / 2).size(trackW, trackH)
            Node.ellipse(fill: Paint.both("#FFFFFF", "#F8EFDF")).id("notes.thumb").at(9 + wordsW + 5 + (on ? trackW - thumb - 2 : 2), (h - thumb) / 2).size(thumb, thumb).shadow(Paint.black15, radius: 1, dx: 0, dy: 1)
        }
        if locked { node = node.opacity(0.45) } else { node = node.area("notes", label: on ? L("Notes on") : L("Notes off"), hover: AreaLook(scale: 1.02), press: AreaLook(scale: 0.97), selected: on, sound: "sounds/tap.wav") }
        return (node, w, h)
    }

    // MARK: The line of keys

    /// One short line, the same through the last beat: what stays out of it (the keyboard's whole path) is in the area's label.
    var puzzleFooter: String? {
        guard let p = board.puzzlePart else { return nil }
        switch p.input {
        case "tap": return look.name == Look.blossoms.name ? L("Click: mark or plant") : L("Click a cell to change it")
        case "drag":
            return ctx.local.dragFrom != nil ? L("Arrows stretch the plot · Return plants it · Esc lets it go") : L("Drag a rectangle, or Space and arrows")
        default: return L("Pick a cell, then a number · N: Notes")
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
        // Clicking through a cell's marks is one thought, not several moves: what the mark on the way breaks waits until the cell has rested (`holdingConflicts`).
        case .click("cell", let value?, _) where p.input == "tap":
            let at = value.split(separator: ",").compactMap { Int($0) }
            guard at.count == 2 else { return nil }
            let cell = at[0] * w + at[1]
            local.settledConflicts = p.cells.indices.filter { p.cells[$0].state == "conflict" && $0 != cell }
            local.settling = cell
            return nil
        case .click("button", _, _):
            local.settling = nil
            return nil
        case .next where local.settling != nil:
            return .settled
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

// MARK: The solved board on the end card

extension BoardDrawing {
    /// The largest the card's picture of the board gets, however much room there is.
    private static let miniLargest = 190.0

    /// The board just solved, small: its frame, its lines and its marks, nothing to press. Sized to `room`, what the card leaves of the zone, or left out when that is too little to read.
    func solvedBoard(room: Double) -> (node: Node, width: Double, height: Double)? {
        guard let p = board.puzzleDrawing, room >= 76 else { return nil }
        let skin = PuzzleSkin(look.name), frame = 5.0
        let side = floor((Swift.min(room, Self.miniLargest) - 2 * frame) / Double(Swift.max(p.rows, p.columns)))
        let w = side * Double(p.columns), h = side * Double(p.rows)
        let art = side * 0.8, text = Node.words("", size: side * 0.56, weight: "heavy", align: "center", minScale: 0.5, w: side, h: side)
        styles["mt"] = text.json
        var inGrid: [Node] = []
        if p.input == "drag" {
            inGrid += p.plots.map { plot in
                let color = PuzzleColors.plot(plot.tint ?? 0)
                return Node.rect(fill: Paint.clear(color, 0.26), stroke: .hex(color), lineWidth: 1.5, corner: 3).at(Double(plot.column) * side + 1.5, Double(plot.row) * side + 1.5)
                    .size(Double(plot.width) * side - 3, Double(plot.height) * side - 3)
            }
        }
        for (i, cell) in p.cells.enumerated() {
            let x = Double(i % p.columns) * side, y = Double(i / p.columns) * side
            if let region = cell.region { inGrid.append(Node.rect(fill: Paint.region(region)).at(x, y).size(side, side)) }
            if let text = cell.text { inGrid.append(Node(["style": "mt", "text": text]).at(x, y)) }
            if let file = cell.symbol.flatMap({ ["crescent": "crescent", "sun": "sun", "blossom": "flower"][$0] }) {
                inGrid.append(Node.art("art/game-face-\(file).webp", x: x + (side - art) / 2, y: y + (side - art) / 2, w: art, h: art))
            }
        }
        // Garden Plots' own borders say it all at this size.
        if p.input != "drag" { inGrid += puzzleLines(rows: p.rows, columns: p.columns, cells: p.cells, box: p.box, side: side, w: w, h: h, skin: skin, heavyWidth: 1.8) }
        let whole = (w + 2 * frame, h + 2 * frame)
        if ctx.fresh, ctx.previous?.resultPart == nil {
            anims.append(.keys("mini", [["t": 0, "opacity": 0, "scale": 0.94], ["t": 1, "opacity": 1, "scale": 1]], ms: 360, ease: "out").delay(ms: 120))
        }
        let node = Node.box("mini", w: whole.0, h: whole.1) {
            skin.material("mini.material", w: whole.0, h: whole.1, inset: frame, corner: 11)
            Node.box("mini.grid", x: frame, y: frame, w: w, h: h) { inGrid }.corner(6).clip()
        }.leftToRight().label(L("The solved board"))
        return (node, whole.0, whole.1)
    }
}

extension Board {
    /// What a puzzle's board shows, for what is drawn from it besides the part itself.
    var puzzleDrawing: (rows: Int, columns: Int, cells: [PuzzleCell], input: String, box: (rows: Int, columns: Int)?, plots: [PuzzlePlot])? {
        play { if case .puzzle(let rows, let columns, let cells, let input, _, let box, _, let plots, _, _, _) = $0 { (rows, columns, cells, input, box, plots) } else { nil } }
    }

    /// How long a click-through cell rests before what it breaks is said: long enough to click again, not so long that a mistake seems missed.
    static let settleMs = 1000

    /// This board with what the cell just clicked breaks held back, and nothing said about it yet; nil when nothing is. A rule that was already showing stays, and one mended goes at
    /// once, since only a new complaint can be premature. Each further click starts the wait again; a click elsewhere means the last cell was meant, and it is said then.
    func holdingConflicts(_ local: LocalParts) -> Board? {
        guard local.settling != nil, !over, let p = puzzlePart, p.input == "tap", !p.locked else { return nil }
        let shown = Set(local.settledConflicts ?? [])
        guard p.cells.indices.contains(where: { p.cells[$0].state == "conflict" && !shown.contains($0) }) else { return nil }
        var out = self
        out.parts = parts.map { part in
            switch part {
            case .play(.puzzle(let rows, let columns, let cells, let input, let digits, let box, let edges, let plots, let seconds, let running, let locked)):
                var held = cells
                for i in held.indices where held[i].state == "conflict" && !shown.contains(i) { held[i].state = nil }
                return .play(.puzzle(rows: rows, columns: columns, cells: held, input: input, digits: digits, box: box, edges: edges, plots: plots, seconds: seconds, running: running, locked: locked))
            case .prompt(_, let eyebrow, let chip):
                return .prompt(calm ?? promptPart?.text ?? "", eyebrow: eyebrow, chip: chip)
            default: return part
            }
        }
        out.companion = nil
        out.afterMs = Self.settleMs
        return out
    }

    /// The board again with no mark settling in: it landed already, and only what it broke arrives now.
    var withoutFreshMarks: Board {
        var out = self
        out.parts = parts.map { part in
            guard case .play(.puzzle(let rows, let columns, let cells, let input, let digits, let box, let edges, let plots, let seconds, let running, let locked)) = part else { return part }
            return .play(.puzzle(rows: rows, columns: columns, cells: cells.map { var c = $0; c.fresh = false; return c }, input: input, digits: digits, box: box, edges: edges, plots: plots, seconds: seconds, running: running, locked: locked))
        }
        return out
    }

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
