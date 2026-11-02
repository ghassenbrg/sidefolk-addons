import Foundation
import SidefolkExtensionKit

// A logic puzzle's grid (PuzzleView): a board in its frame with the game's marks (the pack's heart, star and blossom pictures, numbers,
// pencil notes, dots), Blossoms' coloured beds as rounded tiles with a gutter and heavier lines between them, Sudoku's boxes, `=` and `×`
// between cells, plots dragged corner to corner, and where a rule breaks (the calm loss tone with a !, never red) or what a hint points at.
// The clock counts on above it; Sudoku's digit pad sits under it. A puzzle is the same picture in every language, so it is left to right even in Arabic.
extension BoardDrawing {
    private var skin: PuzzleSkin { PuzzleSkin(soil: look.name == Look.plots.name) }

    func puzzlePart(rows: Int, columns: Int, cells: [PuzzleCell], input: String, digits: Int?, box: (rows: Int, columns: Int)?, edges: [PuzzleEdge], plots: [PuzzlePlot],
                    seconds: Double?, running: Bool, locked: Bool) -> PartBlock {
        let gap = cells.contains { $0.region != nil } ? 3.0 : 0
        let across = gap * Double(columns - 1), down = gap * Double(rows - 1)
        // Room for the grid, so a 9 × 9 Sudoku with its pad keeps the panel under 720 pt.
        let side = floor(min(54, (Self.inner - 16 - across) / Double(columns), ((input == "digits" ? 300 : 324) - down) / Double(rows)))
        let w = side * Double(columns) + across, h = side * Double(rows) + down
        addPuzzleStyles(side: side, digits: digits)

        var inGrid: [Node] = []
        for r in 0..<rows {
            for c in 0..<columns {
                let i = r * columns + c
                guard i < cells.count else { continue }
                inGrid.append(puzzleCell(cells[i], index: i, row: r, column: c, side: side, input: input, locked: locked).at(Double(c) * (side + gap), Double(r) * (side + gap)))
            }
        }
        inGrid += puzzleLines(rows: rows, columns: columns, cells: cells, box: box, side: side, gap: gap, w: w, h: h)
        inGrid += plots.map { plotShape($0, side: side) }
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

        var grid = Node.box("puzzle.grid", x: 5, y: 5, w: w, h: h) { inGrid }.corner(10).clip()
        if input == "drag", !locked {
            grid = grid.area("plots", label: L("Drag corner to corner, or Space and the arrows · Click a plot to clear it"), hover: nil, press: nil,
                             drag: .cells(rows: rows, columns: columns, ghost: Self.plotGhost, inset: Self.plotInset))
        }
        let skin = self.skin
        let framed = Node.box("puzzle.frame", x: (Self.inner - w - 10) / 2, w: w + 10, h: h + 10) {
            Node.rect(fill: skin.board, corner: 17).id("puzzle.board").size(w + 10, h + 10).shadow(Paint.clear("#000000", 0.14), radius: 6, dx: 0, dy: 3)
            grid
            // Inside its own edge, as the panel's border was.
            Node.rect(stroke: skin.frame, lineWidth: 3.5, corner: 15.25).id("puzzle.edge").at(1.75, 1.75).size(w + 6.5, h + 6.5)
        }.leftToRight()

        var height = h + 10
        var nodes = [framed]
        if input == "digits", let digits {
            nodes.append(digitPad(digits: digits, locked: locked).at(0, height + 8))
            height += 8 + 34
        }
        if !locked { puzzleKeys(input: input, digits: digits, cells: cells) }
        // A plot planted is heard when it lands, not when the pointer went down.
        if ctx.fresh, ctx.local.plantSound, ctx.previous != nil { anims.append(.sequence([.sound("sounds/tap.wav")])) }
        return PartBlock(.box("puzzle", w: Self.inner, h: height) { nodes }, height: height)
    }

    // MARK: One cell

    private func addPuzzleStyles(side: Double, digits: Int?) {
        // Short names for what repeats, so 9 × 9 with pencil notes stays well under a scene's 64 KB.
        styles["pc"] = Node(["type": "group"]).size(side, side).json
        styles["pb"] = Node.rect(fill: skin.cell).size(side, side).json
        styles["pg"] = puzzleText(side: side, weight: "heavy", color: skin.given).json
        styles["pu"] = puzzleText(side: side, weight: "semibold", color: .accent).json
        let art = side * 0.7, dot = side * 0.16
        for (name, file) in [("ph", "heart"), ("ps", "star"), ("pf", "flower")] {
            styles[name] = Node.art("art/game-face-\(file).webp", x: (side - art) / 2, y: (side - art) / 2, w: art, h: art).json
        }
        styles["pd"] = Node.ellipse(fill: Color.inkMuted.tuned(alpha: 0.55)).at((side - dot) / 2, (side - dot) / 2).size(dot, dot).json
        // Pencil notes, each number in its own place, three to a row.
        guard let digits else { return }
        let inset = side * 0.06, across = 3, rows = (digits + across - 1) / across
        let w = (side - 2 * inset) / Double(across), h = (side - 2 * inset) / Double(rows)
        for n in 1...digits {
            let r = (n - 1) / across, c = (n - 1) % across
            styles["pn\(n)"] = Node.words("\(n)", size: max(7, side * 0.22), color: .inkMuted, align: "center", minScale: 1, x: inset + Double(c) * w, y: inset + Double(r) * h, w: w, h: h).json
        }
    }

    private func puzzleText(side: Double, weight: String, color: Color) -> Node {
        var text = Node.words("", size: side * 0.52, weight: weight, color: color, align: "center", minScale: 0.5, w: side, h: side)
        if skin.soil { text = text.shadow(Paint.clear("#000000", 0.35), radius: 0, dx: 0, dy: 1.5) }
        return text
    }

    private func puzzleCell(_ cell: PuzzleCell, index: Int, row: Int, column: Int, side: Double, input: String, locked: Bool) -> Node {
        let corner = cell.region != nil ? 6.0 : 0
        let selected = ctx.local.cursor == index && !locked
        var inside: [Node] = []
        if cell.state == "conflict" {
            inside.append(Node.rect(fill: Paint.lostSoft, corner: corner).size(side, side))
        } else if let region = cell.region {
            inside.append(Node.rect(fill: Paint.region(region), corner: corner).size(side, side))
        } else {
            inside.append(Node(["style": "pb"]))
        }
        if cell.region != nil { inside.append(Node.rect(stroke: Paint.clear("#FFFFFF", 0.35), lineWidth: 1, corner: corner - 0.5).at(0.5, 0.5).size(side - 1, side - 1)) }
        if cell.state == "hint" || cell.state == "target" { inside.append(Node.rect(fill: Paint.clear("#FFC93C", 0.3), corner: corner).size(side, side)) }
        if selected { inside.append(Node.rect(fill: Color.accent.tuned(alpha: 0.14), corner: corner).size(side, side)) }
        if let mark = puzzleMark(cell, index: index) { inside.append(mark) }
        if cell.text == nil, cell.symbol == nil { inside += cell.notes.map { Node(["style": "pn\($0)"]) } }
        if cell.state == "target" || selected {
            inside.append(Node.rect(stroke: .accent, lineWidth: 2.5, corner: 4.75).at(3.25, 3.25).size(side - 6.5, side - 6.5))
        }
        if cell.state == "conflict" {
            let badge = max(11, side * 0.3)
            inside.append(conflictBadge(badge, x: side - badge - 2, y: 2))
        }
        var node = Node(["style": "pc", "id": "c\(index)", "children": inside.map(\.json)])
        let open = !locked && !cell.given && input != "drag"
        let label = cell.label ?? "\(row + 1), \(column + 1)"
        if open {
            // A plain button dims as it is pressed. Picking Sudoku's cell sends nothing, so nothing sounds.
            node = input == "digits"
                ? node.area("puzzle_pick", value: "\(index)", label: label, hover: nil, press: AreaLook(opacity: 0.75), selected: selected)
                : node.area("cell", value: "\(row),\(column)", label: label, hover: nil, press: AreaLook(opacity: 0.75), sound: "sounds/tap.wav")
        } else {
            node = node.label(label)
        }
        return node
    }

    /// Its mark, settling in once as it is played (not on every board).
    private func puzzleMark(_ cell: PuzzleCell, index: Int) -> Node? {
        let style: String
        var values: [String: Any] = ["id": "c\(index).m"]
        switch (cell.symbol, cell.text) {
        case ("heart"?, _): style = "ph"
        case ("star"?, _): style = "ps"
        case ("blossom"?, _): style = "pf"
        case ("dot"?, _): style = "pd"
        case (_, let text?):
            style = cell.given ? "pg" : "pu"
            values["text"] = text
        default: return nil
        }
        values["style"] = style
        if cell.state == "target" { values["opacity"] = 0.45 }
        if cell.fresh, ctx.fresh {
            anims.append(.keys("c\(index).m", [["t": 0, "scale": 0.6, "opacity": 0.3], ["t": 1, "scale": 1, "opacity": cell.state == "target" ? 0.45 : 1]], ms: 300, ease: "spring"))
        }
        return Node(values)
    }

    /// The calm loss tone with a "!": a rule broken here, never the danger red (D78).
    private func conflictBadge(_ size: Double, x: Double, y: Double) -> Node {
        .box(x: x, y: y, w: size, h: size) {
            Node.ellipse(fill: .loss).size(size, size)
            Node.symbol("exclamationmark", color: Paint.white).symbolLook(weight: "heavy").at(size * 0.2, size * 0.2).size(size * 0.6, size * 0.6)
        }
    }

    // MARK: What is drawn over the cells

    /// The grid's lines: thin between cells, heavier between beds and around Sudoku's boxes, a frame around it all.
    private func puzzleLines(rows: Int, columns: Int, cells: [PuzzleCell], box: (rows: Int, columns: Int)?, side: Double, gap: Double, w: Double, h: Double) -> [Node] {
        let skin = self.skin
        if gap > 0 {
            return [Node.path(Self.bedLines(rows: rows, columns: columns, cells: cells, side: side, gap: gap), stroke: Color.ink.tuned(alpha: 0.5), lineWidth: 2).id("puzzle.beds").size(w, h)]
        }
        var thin = "", heavy = ""
        for c in 1..<max(columns, 1) {
            let line = "M \(Double(c) * side) 0 L \(Double(c) * side) \(h) "
            if box.map({ c % $0.columns == 0 }) ?? false { heavy += line } else { thin += line }
        }
        for r in 1..<max(rows, 1) {
            let line = "M 0 \(Double(r) * side) L \(w) \(Double(r) * side) "
            if box.map({ r % $0.rows == 0 }) ?? false { heavy += line } else { thin += line }
        }
        var out = [Node.path(thin, stroke: skin.thin, lineWidth: 1).id("puzzle.thin").size(w, h)]
        if !heavy.isEmpty { out.append(Node.path(heavy, stroke: skin.heavy, lineWidth: 2.2).id("puzzle.heavy").size(w, h)) }
        out.append(Node.rect(stroke: skin.edge, lineWidth: 2, corner: 9).id("puzzle.line").at(1, 1).size(w - 2, h - 2))
        return out
    }

    /// Bed tiles with a gutter: only where two beds meet, a line runs down the gutter, a stretch of one bed's edge as one line. Each end
    /// reaches a line's half width past its corner, as the panel's round caps did, so corners stay closed.
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

    /// A plot: a soft tinted rectangle with a rounded border, dashed while being dragged; a broken one in the calm loss tone with a !, a hint's in the sun's colour.
    /// Its id says where it stands: a plot appears where it is planted, rather than gliding from where another was.
    private func plotShape(_ plot: PuzzlePlot, side: Double, dragging: Bool = false, id: String? = nil) -> Node {
        let alpha = dragging ? 0.12 : 0.24
        let (tint, soft): (Color, Color) = switch plot.state {
        case "conflict": (.loss, Color.loss.tuned(alpha: alpha))
        case "hint": (Paint.sun, Paint.clear("#FFC93C", alpha))
        default: dragging ? (.accent, Color.accent.tuned(alpha: alpha))
            : (.hex(PuzzleColors.plot(plot.tint ?? 0)), Paint.clear(PuzzleColors.plot(plot.tint ?? 0), alpha))
        }
        let x = Double(plot.column) * side, y = Double(plot.row) * side, w = Double(plot.width) * side, h = Double(plot.height) * side
        let inset = Self.plotInset
        let name = id ?? "plot.\(plot.row).\(plot.column).\(plot.height).\(plot.width)\(dragging ? ".k" : "")"
        let shape = Node.rect(fill: soft, stroke: tint, lineWidth: 2.5, corner: 6.75, dash: dragging || plot.state == "hint" ? [6, 4] : [])
        guard plot.state == "conflict" else { return shape.id(name).at(x + inset, y + inset).size(w - 2 * inset, h - 2 * inset) }
        let badge = max(11, side * 0.3)
        return .box(name, x: x, y: y, w: w, h: h) {
            shape.at(inset, inset).size(w - 2 * inset, h - 2 * inset)
            conflictBadge(badge, x: w - 3 - 3 - badge, y: 3 + 3)
        }
    }

    private static let plotGhost = "plot.ghost"
    /// The panel's plot stood 3 pt inside its cells with its border drawn inside that; a shape's line is centred on its edge.
    private static let plotInset = 4.25

    /// `=` or `×` on the line between two cells, in a small white disc.
    private func edgeClue(_ edge: PuzzleEdge, columns: Int, side: Double) -> Node {
        let r = Double(edge.cell / columns), c = Double(edge.cell % columns)
        let cx = edge.down ? (c + 0.5) * side : (c + 1) * side, cy = edge.down ? (r + 1) * side : (r + 0.5) * side
        let d = max(17, side * 0.42)
        return .box(x: cx - d / 2, y: cy - d / 2, w: d, h: d) {
            Node.ellipse(fill: Paint.card, stroke: Color.ink.tuned(alpha: 0.45), lineWidth: 1.5).at(0.75, 0.75).size(d - 1.5, d - 1.5).shadow(Paint.clear("#000000", 0.12), radius: 1, dx: 0, dy: 1)
            Node.words(edge.clue == "same" ? "=" : "×", size: d * 0.78, weight: "black", color: .ink, align: "center", minScale: 0.5, w: d, h: d)
        }
    }
}

/// How a puzzle's board is dressed: a card in a pale blue frame, its boxes in the frame's blue; Garden Plots is soil in a wooden frame
/// with its numbers in white, as in a vegetable patch.
struct PuzzleSkin {
    var soil = false

    /// Behind the cells, inside the frame.
    var board: Color { soil ? .adaptive(light: "#7A4E31", dark: "#4E321F") : Paint.card }
    var cell: Color { soil ? .adaptive(light: "#8A5A3A", dark: "#5A3A25") : Paint.card }
    var frame: Color { soil ? .adaptive(light: "#D39A5C", dark: "#9C6A3C") : .adaptive(light: "#BFD3EE", dark: "#3B5994") }
    var thin: Color { soil ? Paint.clear("#FFFFFF", 0.16) : .line }
    /// Sudoku's boxes.
    var heavy: Color { soil ? .adaptive(light: "#D39A5C", dark: "#9C6A3C") : .adaptive(light: "#5D86C6", dark: "#6F95DA") }
    /// The board's edge inside its frame: `heavy`, see-through.
    var edge: Color { soil ? .adaptive(light: "#D39A5C99", dark: "#9C6A3C99") : .adaptive(light: "#5D86C699", dark: "#6F95DA99") }
    /// A given number.
    var given: Color { soil ? Paint.white : .ink }
}

/// The plots' colours: never a red or the loss tone, which would read as a mistake.
enum PuzzleColors {
    static let plots = ["#2FA36B", "#3E7BFA", "#8B5CF6", "#E8691C", "#0E9384", "#5AC8D8", "#7342E0", "#4F9128", "#1D8AD8", "#F2B21B", "#6B7BFF", "#9C45AC"]
    static func plot(_ i: Int) -> String { plots[i % plots.count] }
}

extension BoardDrawing {
    /// A part whose group hasn't moved it: says so on a plain card rather than drawing nothing. Goes when the last part has moved.
    func unmoved(_ name: String) -> PartBlock {
        PartBlock(.box("unmoved.\(name)", w: Self.inner, h: 60) {
            Node.gameCard(w: Self.inner, h: 60)
            Node.words(name, size: 13, align: "center", w: Self.inner, h: 60)
        }, height: 60)
    }
}
