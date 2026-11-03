import Foundation
import SidefolkExtensionKit

// A logic puzzle's board: a frame of the game's own material round a well of cells, the marks (the pack's crescent, sun and blossom pictures, numbers, pencil notes, dots), Blossoms'
// beds in soft pastels with heavy lines between them, Sudoku's boxes, `=` and `×` on the lines between cells, plots dragged corner to corner, where a rule breaks (the calm loss tone
// with a !, never red) and what a hint points at. The part takes all of `playRoom` and keeps everything in one place, whatever is played, so the board never shifts under the pointer.
// A puzzle is the same picture in every language, so it is left to right even in Arabic.
//
// How things come and go: a mark settles in (300 ms); a mark or plot taken away fades (200 ms); a plot planted fades up (220 ms); a hint's tint and a broken rule's mark fade in (260 ms);
// the cursor glides by its own id (the scene's 220 ms). The last move ripples corner to corner before the end card (`solveMoment`). Reduce Motion shows each one's end.
extension BoardDrawing {
    private var skin: PuzzleSkin { PuzzleSkin(look.name) }

    /// Keeps the key under the bubble from taking the board's height, and the pad from touching it.
    private static let frame = 10.0, keyRoom = 18.0, padRoom = PuzzleSkin.padHeight + 3 + 8

    func puzzlePart(rows: Int, columns: Int, cells: [PuzzleCell], input: String, digits: Int?, box: (rows: Int, columns: Int)?, edges: [PuzzleEdge], plots: [PuzzlePlot],
                    seconds: Double?, running: Bool, locked: Bool) -> PartBlock {
        let skin = self.skin, frame = Self.frame
        let above = skin.kind == .seesaw ? Self.keyRoom : 0, below = input == "digits" ? Self.padRoom : 0
        let side = floor(min((Self.inner - 2 * frame) / Double(columns), (playRoom - above - below - 2 * frame) / Double(rows)))
        let w = side * Double(columns), h = side * Double(rows)
        addPuzzleStyles(side: side, digits: digits, skin: skin)

        var cellNodes: [Node] = []
        for r in 0..<rows {
            for c in 0..<columns {
                let i = r * columns + c
                guard i < cells.count else { continue }
                cellNodes.append(puzzleCell(cells[i], index: i, row: r, column: c, columns: columns, box: box, input: input, side: side, locked: locked).at(Double(c) * side, Double(r) * side))
            }
        }
        var inGrid: [Node] = []
        if input == "drag" {
            // A plot's soft fill lies on the well, under the lines and its number.
            inGrid += plotsGone(plots, side: side) + plots.map { plotShape($0, side: side) }
            inGrid += puzzleLines(rows: rows, columns: columns, cells: cells, box: box, side: side, w: w, h: h, skin: skin)
            inGrid += cellNodes
        } else {
            inGrid += cellNodes
            inGrid += puzzleLines(rows: rows, columns: columns, cells: cells, box: box, side: side, w: w, h: h, skin: skin)
        }
        inGrid += plots.compactMap { plotBadge($0, side: side) }
        // The dashed preview of a plot: the keyboard's, drawn here; the pointer's is the ghost Sidefolk stretches, so a drag never waits on the program.
        if input == "drag", !locked {
            if let from = ctx.local.dragFrom, let to = ctx.local.cursor {
                let (a, b) = (from, to)
                let plot = PuzzlePlot(row: min(a / columns, b / columns), column: min(a % columns, b % columns), height: abs(a / columns - b / columns) + 1, width: abs(a % columns - b % columns) + 1)
                inGrid.append(plotShape(plot, side: side, dragging: true))
            }
            inGrid.append(plotShape(PuzzlePlot(row: 0, column: 0, height: 1, width: 1), side: side, dragging: true, id: Self.plotGhost).opacity(0))
        }
        inGrid += edges.map { edgeClue($0, columns: columns, side: side) }
        if !locked, let cursor = puzzleCursor(columns: columns, side: side, input: input, skin: skin) { inGrid.append(cursor) }
        inGrid += solveMoment(rows: rows, columns: columns, cells: cells, side: side)

        var grid = Node.box("puzzle.grid", x: frame, y: frame, w: w, h: h) { inGrid }.corner(9).clip()
        if input == "drag", !locked {
            grid = grid.area("plots", label: L("Drag corner to corner, or Space and the arrows · Click a plot to clear it"), hover: nil, press: nil,
                             drag: .cells(rows: rows, columns: columns, ghost: Self.plotGhost, inset: Self.plotInset))
        }
        let frameW = w + 2 * frame, frameH = h + 2 * frame
        // The frame sits on the stage's feet; Sudoku's stands midway between the bubble and its pad, which keeps its place whatever the board's size.
        let spare = playRoom - above - below - frameH
        let top = above + (input == "digits" ? (spare / 2).rounded() : Swift.min(2, spare))
        let framed = Node.box("puzzle.frame", x: ((Self.inner - frameW) / 2).rounded(), y: top, w: frameW, h: frameH) {
            skin.material("puzzle.material", w: frameW, h: frameH, inset: frame, corner: 18)
            grid
        }.leftToRight()

        var nodes = [framed]
        if !edges.isEmpty, skin.kind == .seesaw { nodes.append(clueKey()) }
        if input == "digits", let digits { nodes.append(digitPad(digits: digits, locked: locked).at(0, playRoom - PuzzleSkin.padHeight - 3)) }
        if !locked { puzzleKeys(input: input, digits: digits, cells: cells) }
        // A plot planted is heard when it lands, not when the pointer went down.
        if ctx.fresh, ctx.local.plantSound, ctx.previous != nil { anims.append(.sequence([.sound("sounds/tap.wav")])) }
        return PartBlock(.box("puzzle", w: Self.inner, h: playRoom) { nodes }, height: playRoom)
    }

    /// "= same · × different", a little key under the bubble.
    private func clueKey() -> Node {
        let words = L("= same · × different")
        let bubbleX = 66.0, room = Self.inner - bubbleX
        let w = Swift.min(TextFit.width(words, size: 11.5, weight: "heavy") + 22, room)
        return Node.box("puzzle.key", x: bubbleX + (room - w) / 2, y: -5, w: w, h: 20) {
            Node.capsule(fill: Paint.lilac, stroke: Paint.card, lineWidth: 1).id("puzzle.key.back").size(w, 20)
            Node.words(words, size: 11.5, weight: "heavy", align: "center", minScale: 0.7, x: 8, w: w - 16, h: 20)
        }
    }

    /// The last correct move: its mark settles, then a soft sun runs corner to corner over the board, lifting each mark a little as it passes. The board stays where it is, nothing can be
    /// pressed, and the end card comes when it has passed. Under Reduce Motion the board simply rests for the same beat.
    private func solveMoment(rows: Int, columns: Int, cells: [PuzzleCell], side: Double) -> [Node] {
        guard ctx.buildUp, ctx.fresh else { return [] }
        styles["pw"] = Node.rect(fill: Paint.clear("#FFC93C", 0.42)).size(side, side).opacity(0).json
        let settle = 280.0, across = 520.0, each = 460.0
        let stride = across / Double(max(rows + columns - 2, 1))
        var out: [Node] = []
        for r in 0..<rows {
            for c in 0..<columns {
                let i = r * columns + c, delay = settle + Double(r + c) * stride
                out.append(Node(["style": "pw", "id": "w\(i)"]).at(Double(c) * side, Double(r) * side))
                anims.append(.keys("w\(i)", [["t": 0, "opacity": 0], ["t": 0.35, "opacity": 1], ["t": 1, "opacity": 0]], ms: each, ease: "in_out").delay(ms: delay))
                if cells.indices.contains(i), cells[i].symbol != nil || cells[i].text != nil {
                    anims.append(.keys("c\(i).m", [["t": 0, "scale": 1], ["t": 0.4, "scale": 1.14], ["t": 1, "scale": 1]], ms: 420, ease: "in_out").delay(ms: delay))
                }
            }
        }
        anims.append(.sequence([.wait(ms: settle), .sound("sounds/ding.wav")]))
        partAfterMs = Int(settle + across + each + 120)
        return out
    }

    /// The arrows' place, gliding from cell to cell: the navy outline, dashed while Sudoku's numbers go in as notes; Garden Plots' corner brackets, which leave its numbers clear.
    private func puzzleCursor(columns: Int, side: Double, input: String, skin: PuzzleSkin) -> Node? {
        guard let c = ctx.local.cursor, c >= 0 else { return nil }
        let x = Double(c % columns) * side, y = Double(c / columns) * side
        if input == "drag" {
            let a = 3.0, b = side - 3, arm = side * 0.22
            let path = "M \(a) \(a + arm) L \(a) \(a) L \(a + arm) \(a) M \(b - arm) \(a) L \(b) \(a) L \(b) \(a + arm) "
                + "M \(b) \(b - arm) L \(b) \(b) L \(b - arm) \(b) M \(a + arm) \(b) L \(a) \(b) L \(a) \(b - arm)"
            return Node.path(path, stroke: Paint.lilacDeep, lineWidth: 2.5).id("puzzle.cursor").at(x, y).size(side, side)
        }
        let dash: [Double] = input == "digits" && ctx.local.notes ? [4, 3] : []
        return Node.rect(stroke: skin.selectedEdge, lineWidth: 2.5, corner: 5, dash: dash).id("puzzle.cursor").at(x + 2.25, y + 2.25).size(side - 4.5, side - 4.5)
    }

    // MARK: One cell

    private func addPuzzleStyles(side: Double, digits: Int?, skin: PuzzleSkin) {
        // Short names for what repeats, so 9 × 9 with pencil notes stays well under a scene's 64 KB.
        styles["pc"] = Node(["type": "group"]).size(side, side).json
        styles["pb"] = Node.rect(fill: skin.cell).size(side, side).json
        styles["pv"] = Node.rect(fill: skin.givenCell).size(side, side).json
        styles["pe"] = Node.rect(fill: skin.peer).size(side, side).json
        styles["pl"] = Node.rect(fill: skin.selected).size(side, side).json
        styles["po"] = Node.rect(fill: skin.hover).size(side, side).opacity(0).json
        styles["pg"] = Node.words("", size: side * 0.52, weight: "black", color: Paint.ink, align: "center", minScale: 0.5, w: side, h: side).json
        styles["pu"] = Node.words("", size: side * 0.52, weight: "semibold", color: skin.entered, align: "center", minScale: 0.5, w: side, h: side).json
        // A mark and the disc on the line beside it never meet: the disc reaches half its width into a cell, and every mark leaves that much and a little.
        let art = skin.kind == .seesaw ? side - Self.discSide(side) - 2 : side * 0.72, dot = side * 0.16
        for (name, file) in [("ph", "crescent"), ("ps", "sun"), ("pf", "blossom")] {
            styles[name] = Node.art("art/game-face-\(file).webp", x: (side - art) / 2, y: (side - art) / 2, w: art, h: art).json
        }
        styles["pd"] = Node.ellipse(fill: Paint.ink).at((side - dot) / 2, (side - dot) / 2).size(dot, dot).opacity(0.5).json
        // Pencil notes, each number in its own place, three to a row: readable at 9 × 9's size, never crowding 6 × 6's.
        guard let digits else { return }
        let inset = side * 0.06, across = 3, rows = (digits + across - 1) / across
        let w = (side - 2 * inset) / Double(across), h = (side - 2 * inset) / Double(rows)
        for n in 1...digits {
            let r = (n - 1) / across, c = (n - 1) % across
            styles["pn\(n)"] = Node.words("\(n)", size: Swift.min(12, Swift.max(9, side * 0.25)), weight: "semibold", color: Paint.inkSoft, align: "center", minScale: 1, x: inset + Double(c) * w, y: inset + Double(r) * h, w: w, h: h).json
        }
    }

    /// The same row, column or box as the cell picked.
    private func isPeer(_ index: Int, of cursor: Int?, columns: Int, box: (rows: Int, columns: Int)?) -> Bool {
        guard let box, let cursor, cursor != index else { return false }
        let (r, c, pr, pc) = (index / columns, index % columns, cursor / columns, cursor % columns)
        return r == pr || c == pc || (r / box.rows == pr / box.rows && c / box.columns == pc / box.columns)
    }

    private func puzzleCell(_ cell: PuzzleCell, index: Int, row: Int, column: Int, columns: Int, box: (rows: Int, columns: Int)?, input: String, side: Double, locked: Bool) -> Node {
        let selected = ctx.local.cursor == index && !locked
        let filled = selected && input == "digits"
        let before = ctx.previous?.puzzlePart?.cells[safe: index]
        var inside: [Node] = []
        // Garden Plots' well shows through: its plots lie under the numbers.
        if input != "drag" {
            if filled { inside.append(Node(["style": "pl"])) }
            else if let region = cell.region { inside.append(Node(["style": regionStyle(region, side: side)])) }
            else if !locked, isPeer(index, of: ctx.local.cursor, columns: columns, box: box) { inside.append(Node(["style": "pe"])) }
            else { inside.append(Node(["style": cell.given ? "pv" : "pb"])) }
        }
        if cell.state == "conflict" {
            inside.append(fadesIn(Node.rect(fill: Color.loss.tuned(alpha: 0.2)).size(side, side), id: "c\(index).t", was: before?.state == "conflict"))
        }
        if cell.state == "hint" || cell.state == "target" {
            inside.append(fadesIn(Node.rect(fill: Paint.clear("#FFC93C", 0.34)).size(side, side), id: "c\(index).t", was: before?.state == "hint" || before?.state == "target"))
        }
        let open = !locked && !cell.given && input != "drag"
        // Under the pointer an open cell warms, beneath its mark: a mark just placed stays whole while the pointer rests on it. A given stays as it is.
        if open { inside.append(Node(["style": "po", "id": "c\(index).h"])) }
        if let gone = markGone(cell, before: before, index: index) { inside.append(gone) }
        if let mark = puzzleMark(cell, index: index, onSelected: filled) { inside.append(mark) }
        if cell.text == nil, cell.symbol == nil {
            inside += cell.notes.map { filled ? Node(["style": "pn\($0)", "color": skin.selectedInk.json]) : Node(["style": "pn\($0)"]) }
        }
        if cell.state == "target" {
            inside.append(Node.rect(stroke: skin.selectedEdge, lineWidth: 2.5, corner: 5).at(2.25, 2.25).size(side - 4.5, side - 4.5))
        }
        if cell.state == "conflict" {
            let badge = Swift.max(11, side * 0.28)
            inside.append(conflictBadge(badge, id: "c\(index).x", was: before?.state == "conflict", x: side - badge - 2, y: 2))
        }
        var node = Node(["style": "pc", "id": "c\(index)", "children": inside.map(\.json)])
        let label = cell.label ?? "\(row + 1), \(column + 1)"
        if open {
            let warm = ["c\(index).h": AreaLook(opacity: 1)]
            // Picking Sudoku's cell sends nothing, so nothing sounds.
            node = input == "digits"
                ? node.area("puzzle_pick", value: "\(index)", label: label, hover: nil, press: AreaLook(opacity: 0.75), looks: warm, selected: selected)
                : node.area("cell", value: "\(row),\(column)", label: label, hover: nil, press: AreaLook(opacity: 0.75), looks: warm, sound: "sounds/tap.wav")
        } else {
            node = node.label(label)
        }
        return node
    }

    /// A bed's colour once, however many cells it has.
    private func regionStyle(_ region: Int, side: Double) -> String {
        let name = "pr\(region % 12)"
        if styles[name] == nil { styles[name] = Node.rect(fill: Paint.region(region)).size(side, side).json }
        return name
    }

    /// Fades up as it appears on a new board, not on one drawn again.
    private func fadesIn(_ node: Node, id: String, was: Bool) -> Node {
        if ctx.fresh, !was, ctx.previous != nil { anims.append(.keys(id, [["t": 0, "opacity": 0], ["t": 1, "opacity": 1]], ms: 260, ease: "out")) }
        return node.id(id)
    }

    private func markStyle(_ cell: PuzzleCell) -> String? {
        switch (cell.symbol, cell.text) {
        case ("crescent"?, _): "ph"
        case ("sun"?, _): "ps"
        case ("blossom"?, _): "pf"
        case ("dot"?, _): "pd"
        case (_, _?): cell.given ? "pg" : "pu"
        default: nil
        }
    }

    /// A mark just taken away goes with a short fade rather than vanishing.
    private func markGone(_ cell: PuzzleCell, before: PuzzleCell?, index: Int) -> Node? {
        guard ctx.fresh, let before, cell.symbol == nil, cell.text == nil, before.state != "target", let style = markStyle(before) else { return nil }
        var values: [String: Any] = ["id": "c\(index).g", "style": style, "opacity": 0.0]
        if let text = before.text { values["text"] = text }
        anims.append(.keys("c\(index).g", [["t": 0, "opacity": 1, "scale": 1], ["t": 1, "opacity": 0, "scale": 0.82]], ms: 200, ease: "out"))
        return Node(values)
    }

    /// Its mark, settling in once as it is played (not on every board).
    private func puzzleMark(_ cell: PuzzleCell, index: Int, onSelected: Bool) -> Node? {
        guard let style = markStyle(cell) else { return nil }
        var values: [String: Any] = ["id": "c\(index).m", "style": style]
        if let text = cell.text { values["text"] = text }
        if onSelected { values["color"] = (cell.given ? skin.selectedInk : skin.selectedEntered).json }
        if cell.state == "target" { values["opacity"] = 0.45 }
        if cell.fresh, ctx.fresh {
            let rest = cell.state == "target" ? 0.45 : style == "pd" ? 0.5 : 1
            anims.append(.keys("c\(index).m", [["t": 0, "scale": 0.6, "opacity": 0.3], ["t": 1, "scale": 1, "opacity": rest]], ms: 300, ease: "spring"))
        }
        return Node(values)
    }

    /// The calm loss tone with a "!": a rule broken here, never the danger red (D78).
    private func conflictBadge(_ size: Double, id: String, was: Bool, x: Double, y: Double) -> Node {
        if ctx.fresh, !was, ctx.previous != nil { anims.append(.keys(id, [["t": 0, "scale": 0.6, "opacity": 0], ["t": 1, "scale": 1, "opacity": 1]], ms: 260, ease: "out")) }
        return .box(id, x: x, y: y, w: size, h: size) {
            Node.ellipse(fill: .loss).size(size, size)
            Node.symbol("exclamationmark", color: Paint.white).symbolLook(weight: "heavy").at(size * 0.2, size * 0.2).size(size * 0.6, size * 0.6)
        }
    }

    // MARK: What is drawn over the cells

    /// The grid's lines: thin between cells, heavy round Sudoku's boxes and between Blossoms' beds.
    func puzzleLines(rows: Int, columns: Int, cells: [PuzzleCell], box: (rows: Int, columns: Int)?, side: Double, w: Double, h: Double, skin: PuzzleSkin, heavyWidth: Double = 2.6) -> [Node] {
        var thin = "", heavy = ""
        let beds = cells.contains { $0.region != nil }
        for c in 1..<max(columns, 1) {
            let line = "M \(Double(c) * side) 0 L \(Double(c) * side) \(h) "
            if box.map({ c % $0.columns == 0 }) ?? false { heavy += line } else { thin += line }
        }
        for r in 1..<max(rows, 1) {
            let line = "M 0 \(Double(r) * side) L \(w) \(Double(r) * side) "
            if box.map({ r % $0.rows == 0 }) ?? false { heavy += line } else { thin += line }
        }
        if beds { heavy = Self.bedLines(rows: rows, columns: columns, cells: cells, side: side, gap: 0) }
        var out = [Node.path(thin, stroke: skin.thin, lineWidth: 1).id("puzzle.thin").size(w, h)]
        if !heavy.isEmpty { out.append(Node.path(heavy, stroke: skin.heavy, lineWidth: heavyWidth).id("puzzle.heavy").size(w, h)) }
        return out
    }

    /// Where two beds meet: a stretch of one bed's edge as one line, and each end reaches a line's half width past its corner, so corners stay closed.
    static func bedLines(rows: Int, columns: Int, cells: [PuzzleCell], side: Double, gap: Double) -> String {
        func region(_ r: Int, _ c: Int) -> Int? { cells[r * columns + c].region }
        let stride = side + gap, half = gap / 2, reach = 1.0
        var path = ""
        for c in 0..<(columns - 1) {
            let x = Double(c) * stride + side + half
            var start: Int?
            for r in 0...rows {
                let differs = r < rows && region(r, c) != region(r, c + 1)
                if differs, start == nil { start = r }
                if !differs, let s = start {
                    path += "M \(x) \(Double(s) * stride - half - reach) L \(x) \(Double(r - 1) * stride + side + half + reach) "
                    start = nil
                }
            }
        }
        for r in 0..<(rows - 1) {
            let y = Double(r) * stride + side + half
            var start: Int?
            for c in 0...columns {
                let differs = c < columns && region(r, c) != region(r + 1, c)
                if differs, start == nil { start = c }
                if !differs, let s = start {
                    path += "M \(Double(s) * stride - half - reach) \(y) L \(Double(c - 1) * stride + side + half + reach) \(y) "
                    start = nil
                }
            }
        }
        return path
    }

    /// A plot: a soft fill and a firm border, dashed navy while being dragged; a broken one in the calm loss tone, a hint's dashed in the sun's colour.
    /// Its id says where it stands: a plot appears where it is planted, rather than gliding from where another was.
    private func plotShape(_ plot: PuzzlePlot, side: Double, dragging: Bool = false, id: String? = nil, keep: Bool = false) -> Node {
        let alpha = dragging ? 0.14 : 0.26
        let (tint, soft): (Color, Color) = switch plot.state {
        case "conflict": (.loss, Color.loss.tuned(alpha: alpha))
        case "hint": (Paint.sunLip, Paint.clear("#FFC93C", alpha))
        default: dragging ? (Paint.action, Paint.clear("#8E72B5", alpha))
            : (.hex(PuzzleColors.plot(plot.tint ?? 0)), Paint.clear(PuzzleColors.plot(plot.tint ?? 0), alpha))
        }
        let x = Double(plot.column) * side, y = Double(plot.row) * side, w = Double(plot.width) * side, h = Double(plot.height) * side
        let inset = Self.plotInset
        let name = id ?? Self.plotId(plot) + (dragging ? ".k" : "")
        if ctx.fresh, !dragging, !keep, ctx.previous != nil, !plotsBefore.contains(where: { Self.plotId($0) == name }) {
            anims.append(.keys(name, [["t": 0, "opacity": 0, "scale": 0.97], ["t": 1, "opacity": 1, "scale": 1]], ms: 220, ease: "out"))
        }
        return Node.rect(fill: soft, stroke: tint, lineWidth: 2.5, corner: 6.75, dash: dragging || plot.state == "hint" ? [6, 4] : []).id(name).at(x + inset, y + inset).size(w - 2 * inset, h - 2 * inset)
    }

    /// A broken plot's "!", over its number's cell if need be.
    private func plotBadge(_ plot: PuzzlePlot, side: Double) -> Node? {
        guard plot.state == "conflict" else { return nil }
        // On the plot's corner, clear of a number in its corner cell.
        let badge = Swift.max(11, side * 0.24)
        let id = Self.plotId(plot) + ".x"
        let was = plotsBefore.contains { Self.plotId($0) == Self.plotId(plot) && $0.state == "conflict" }
        return conflictBadge(badge, id: id, was: was, x: Double(plot.column + plot.width) * side - badge - 1, y: Double(plot.row) * side + 1)
    }

    /// Plots just taken away fade out where they stood.
    private func plotsGone(_ plots: [PuzzlePlot], side: Double) -> [Node] {
        guard ctx.fresh else { return [] }
        let now = Set(plots.map(Self.plotId))
        return plotsBefore.filter { !now.contains(Self.plotId($0)) }.map { plot in
            let id = Self.plotId(plot) + ".g"
            anims.append(.keys(id, [["t": 0, "opacity": 1], ["t": 1, "opacity": 0]], ms: 200, ease: "out"))
            return plotShape(plot, side: side, id: id, keep: true).opacity(0)
        }
    }

    private var plotsBefore: [PuzzlePlot] { ctx.previous?.puzzleDrawing?.plots ?? [] }
    private static func plotId(_ plot: PuzzlePlot) -> String { "plot.\(plot.row).\(plot.column).\(plot.height).\(plot.width)" }

    private static let plotGhost = "plot.ghost"
    /// A plot stands inside its cells, so two side by side keep their own borders; a shape's line is centred on its edge.
    private static let plotInset = 4.25

    /// How wide `=` or `×` is on a line between cells of this size.
    static func discSide(_ side: Double) -> Double { Swift.max(15, side * 0.3) }

    /// `=` or `×` on the line between two cells, in a small disc that keeps clear of the marks either side.
    private func edgeClue(_ edge: PuzzleEdge, columns: Int, side: Double) -> Node {
        let r = Double(edge.cell / columns), c = Double(edge.cell % columns)
        let cx = edge.down ? (c + 0.5) * side : (c + 1) * side, cy = edge.down ? (r + 1) * side : (r + 0.5) * side
        let d = Self.discSide(side)
        return .box("e\(edge.cell)\(edge.down ? "d" : "r")", x: cx - d / 2, y: cy - d / 2, w: d, h: d) {
            Node.ellipse(fill: Paint.both("#FFF9F0", "#FFF9F0"), stroke: Paint.navy, lineWidth: 1.5).at(0.75, 0.75).size(d - 1.5, d - 1.5)
            Node.words(edge.clue == "same" ? "=" : "×", size: d * 0.78, weight: "black", color: Paint.navy, align: "center", minScale: 0.5, w: d, h: d)
        }
    }
}

/// How a puzzle's board is dressed, per concept: Garden Plots' cream cells in a wooden frame, Seesaw's in dark navy, Sudoku's in lilac felt with a heavy box grid, Blossoms' pastel beds in
/// terracotta with heavy navy lines. Playtime's own colours, by day and at night.
struct PuzzleSkin {
    enum Kind { case plots, seesaw, sudoku, blossoms }
    var kind: Kind

    /// A digit's key.
    static let padHeight = 38.0

    init(_ look: String) {
        kind = switch look {
        case Look.plots.name: .plots
        case Look.seesaw.name: .seesaw
        case Look.blossoms.name: .blossoms
        default: .sudoku
        }
    }

    /// Behind the cells. Seesaw's stays a lit parchment at night: its crescent is navy clay, which a dark cell would swallow.
    var cell: Color {
        switch kind {
        case .plots: Paint.card
        case .seesaw: Paint.both("#FFF9F0", "#E4DBCB")
        case .sudoku: Paint.both("#FFF9F0", "#1E2744")
        case .blossoms: Paint.card
        }
    }

    /// A mark that came with the puzzle stands on a slightly deeper cell, where the only sign of it would otherwise be that it doesn't answer.
    var givenCell: Color { kind == .seesaw ? Paint.both("#F6EADA", "#D3C9B6") : cell }
    var thin: Color {
        switch kind {
        case .plots: Paint.both("#DDBC96", "#47517C")
        case .seesaw: Paint.both("#2B336899", "#2B336899")
        case .sudoku: Paint.both("#E6D8C6", "#3B4468")
        case .blossoms: Paint.both("#14275A22", "#FFFFFF22")
        }
    }

    /// Sudoku's boxes, Blossoms' beds.
    var heavy: Color { kind == .sudoku ? Paint.both("#6E57A6", "#A58CDC") : Paint.ink }
    /// A number the person wrote: never the given's navy.
    var entered: Color { Paint.both("#6A4FB0", "#C4AEF5") }
    /// The cell picked: soft lilac by day, the concept's bright lilac at night, with a firm outline and navy words on it.
    var selected: Color { Paint.both("#E3D6F7", "#B394E0") }
    var selectedEdge: Color { kind == .sudoku ? Paint.both("#14275A", "#14275A") : kind == .seesaw ? Paint.navy : Paint.action }
    var selectedInk: Color { Paint.both("#14275A", "#14275A") }
    var selectedEntered: Color { Paint.both("#6A4FB0", "#3A2A78") }
    /// An open cell under the pointer.
    var hover: Color { Paint.clear("#8E72B5", 0.2) }
    /// The same row, column or box as the cell picked.
    var peer: Color { Paint.both("#F7F0F8", "#262F52") }

    /// The frame and the well inside it.
    func material(_ id: String, w: Double, h: Double, inset: Double, corner: Double) -> Node {
        let well = Swift.max(corner - inset, 4)
        switch kind {
        case .plots:
            return Node.woodFrame(id, w: w, h: h, inset: inset, corner: corner, inner: cell)
        case .sudoku:
            return .box(id, w: w, h: h) {
                Node.felt(id + ".felt", w: w, h: h, corner: corner, stitch: false)
                Node.rect(fill: cell, corner: well).id(id + ".well").at(inset, inset).size(w - 2 * inset, h - 2 * inset)
            }
        case .seesaw, .blossoms:
            let body = kind == .seesaw ? Paint.both("#2B3368", "#59659F") : Paint.both("#E8956F", "#A8644C")
            return .box(id, w: w, h: h) {
                Node.rect(fill: body, corner: corner).id(id + ".base").size(w, h).shadow(Paint.clear("#1A1633", 0.22), radius: 5, dx: 0, dy: 3)
                Node.rect(fill: cell, corner: well).id(id + ".well").at(inset, inset).size(w - 2 * inset, h - 2 * inset)
            }
        }
    }
}

/// The plots' colours: never a red or the loss tone, which would read as a mistake.
enum PuzzleColors {
    static let plots = ["#2FA36B", "#3E7BFA", "#8B5CF6", "#E8691C", "#0E9384", "#5AC8D8", "#7342E0", "#4F9128", "#1D8AD8", "#F2B21B", "#6B7BFF", "#9C45AC"]
    static func plot(_ i: Int) -> String { plots[i % plots.count] }
}
