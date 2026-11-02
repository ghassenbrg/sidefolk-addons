import Foundation
import SidefolkExtensionKit

/// The first-run, status and source boards' shared materials. Their arch is drawn rather than painted: its head stays wide enough for a title, and it holds at any height, where results and problems make a panel grow.
extension Node {
    /// The lattice at the boards' small scale. Each neighbour is a mirror of the last, so the picture's edges meet.
    static func latticeField(_ w: Double, _ h: Double, tile: Double, corner: Double) -> Node {
        let th = tile * 788 / 1400
        return Node.group {
            for row in 0..<Int((h / th).rounded(.up)) {
                for col in 0..<Int((w / tile).rounded(.up)) {
                    Node.image("art/lattice-l.jpg", dark: "art/lattice-d.jpg", fit: "fill").size(tile + 0.5, th + 0.5).at(Double(col) * tile, Double(row) * th)
                        .scale(x: col % 2 == 0 ? 1 : -1, y: row % 2 == 0 ? 1 : -1)
                }
            }
        }
        .size(w, h).corner(corner).clip()
    }

    /// The boards' head: wide and shallow, an ogee only at its peak, so a title stands inside it.
    static func wideArchPath(_ w: Double, _ h: Double) -> String {
        "M 0 \(n(h)) L 0 \(n(w * 0.34)) C 0 \(n(w * 0.22)) \(n(w * 0.055)) \(n(w * 0.125)) \(n(w * 0.15)) \(n(w * 0.095)) C \(n(w * 0.27)) \(n(w * 0.058)) \(n(w * 0.44)) \(n(w * 0.05)) \(n(w * 0.5)) 0 "
            + "C \(n(w * 0.56)) \(n(w * 0.05)) \(n(w * 0.73)) \(n(w * 0.058)) \(n(w * 0.85)) \(n(w * 0.095)) C \(n(w * 0.945)) \(n(w * 0.125)) \(n(w)) \(n(w * 0.22)) \(n(w)) \(n(w * 0.34)) L \(n(w)) \(n(h)) Z"
    }

    /// The plain window's colour, the same from top to foot so what stands in it can fade into it.
    static var windowFill: Color { Color.adaptive(light: "#FBF8FC", dark: "#0A1538") }

    /// A panel with an arch: lattice round it, a quiet window for what it holds, a gold double line between them. `dusk` warms the window's foot and lays hills along it; `feet` closes the window with small spandrels, otherwise it runs out at the bottom, as C03's do.
    static func archPanel(_ w: Double, _ h: Double, r: Ruler, dusk: Bool = false, feet: Bool = true, skyline: Double = 0) -> Node {
        let side = r.u(14), inner = r.u(6)
        let archW = w - side * 2
        let foot = feet ? h - side : h
        let archH = foot - r.u(4)
        let top = dusk ? Color.adaptive(light: "#FFFDFC", dark: "#0B1B57") : windowFill
        let low = dusk ? Color.adaptive(light: "#E6DAF5", dark: "#33237A") : windowFill
        let middle = dusk ? Color.adaptive(light: "#FBF7FC", dark: "#091442") : windowFill
        let path = Node.wideArchPath(archW, archH)
        return Node.group {
            // The square frame's fine copper-on-lapis lattice: what shows of it is only what lies outside this arch.
            Node.image("art/frame-square-l.jpg", dark: "art/frame-square-d.jpg", fit: "fill").size(w, h).corner(r.u(18)).clip()
            Node.path(path).gradient([top, middle, low]).size(archW, archH).at(side, r.u(4))
            if skyline > 0 {
                // The night along its foot, fading up into the plain window.
                Node.group {
                    Node.image("art/tonight-l.jpg", dark: "art/tonight-d.jpg", fit: "cover").size(archW, skyline).at(0, 0)
                    Node.rect().gradient([.adaptive(light: "#FBF8FCFF", dark: "#0A1538FF"), .adaptive(light: "#FBF8FC00", dark: "#0A153800")]).size(archW, skyline * 0.62).at(0, 0)
                }
                .size(archW, skyline).at(side, h - skyline).clip()
            }
            if dusk { hills(w: archW, y: archH - r.u(118), h: r.u(118)).at(side, r.u(4)) }
            Node.path(Node.wideArchPath(archW - inner * 2, archH - inner), stroke: Color.adaptive(light: "#BD7AA8AA", dark: "#BD7AA8AA"), lineWidth: 1).size(archW - inner * 2, archH - inner).at(side + inner, r.u(4) + inner)
            Node.path(path, stroke: Noor.inlay, lineWidth: 1.6).size(archW, archH).at(side, r.u(4))
            if feet {
                // The flourish turned into the two lower corners, over the window's feet.
                let c = r.u(96)
                Node.image("art/corner-l.png", dark: "art/corner-d.png", fit: "contain").size(c, c).at(w - c - side * 0.3, h - c - side * 0.3).rotate(90)
                Node.image("art/corner-l.png", dark: "art/corner-d.png", fit: "contain").size(c, c).at(side * 0.3, h - c - side * 0.3).rotate(180)
            }
            Node.rect(stroke: Color.adaptive(light: "#C9AB72", dark: "#C47F6A"), lineWidth: 1.2, corner: r.u(18)).size(w, h)
        }
        .size(w, h)
    }

    /// Far hills, the same two ridges in both appearances' own hazes.
    private static func hills(w: Double, y: Double, h: Double) -> Node {
        func p(_ x: Double, _ d: Double) -> String { "\(n(w * x)) \(n(y + h * d))" }
        let far = "M \(p(0, 0.62)) C \(p(0.12, 0.42)) \(p(0.2, 0.3)) \(p(0.3, 0.42)) C \(p(0.42, 0.58)) \(p(0.5, 0.5)) \(p(0.62, 0.34)) C \(p(0.74, 0.2)) \(p(0.86, 0.46)) \(p(1, 0.5)) L \(p(1, 1)) L \(p(0, 1)) Z"
        let near = "M \(p(0, 0.82)) C \(p(0.16, 0.6)) \(p(0.3, 0.72)) \(p(0.44, 0.8)) C \(p(0.6, 0.9)) \(p(0.78, 0.6)) \(p(1, 0.74)) L \(p(1, 1)) L \(p(0, 1)) Z"
        return Node.group {
            Node.path(far, fill: Color.adaptive(light: "#D6C8EC", dark: "#2F2270")).size(w, y + h).at(0, 0)
            Node.path(near, fill: Color.adaptive(light: "#C9B9E4", dark: "#241B5C")).size(w, y + h).at(0, 0)
        }
        .size(w, y + h)
    }

    /// Small four-point stars, all in one path, at places given in the panel's own units.
    static func sparkles(_ places: [(Double, Double, Double)], w: Double, h: Double, r: Ruler) -> Node {
        var path = ""
        for (x, y, size) in places {
            let px = r.u(x), py = r.u(y), s = r.u(size)
            path += "M \(n(px)) \(n(py - s)) C \(n(px)) \(n(py)) \(n(px)) \(n(py)) \(n(px + s)) \(n(py)) C \(n(px)) \(n(py)) \(n(px)) \(n(py)) \(n(px)) \(n(py + s)) C \(n(px)) \(n(py)) \(n(px)) \(n(py)) \(n(px - s)) \(n(py)) C \(n(px)) \(n(py)) \(n(px)) \(n(py)) \(n(px)) \(n(py - s)) Z "
        }
        return Node.path(path, fill: Color.adaptive(light: "#C9AB72", dark: "#EFCF8E")).size(w, h).at(0, 0)
    }

    /// An icon in a round well: the boards' way of saying what a thing is, and what state it is in.
    static func medallion(_ symbol: String, cx: Double, cy: Double, d: Double, ink: Color = Noor.text, ring: Color = Color.adaptive(light: "#7354B8", dark: "#8F93E8"), glyph: Double = 0.48) -> Node {
        Node.group {
            Node.ellipse(fill: Color.adaptive(light: "#EEE8F5", dark: "#20266E"), stroke: ring, lineWidth: 1.4).size(d, d).at(0, 0)
            Node.symbol(symbol, color: ink).size(d * glyph, d * glyph).at(d * (1 - glyph) / 2, d * (1 - glyph) / 2)
        }
        .size(d, d).at(cx - d / 2, cy - d / 2)
    }

    /// A radio's look. The row around it is what is clicked.
    static func radio(cx: Double, cy: Double, d: Double, on: Bool) -> Node {
        Node.group {
            if on {
                Node.ellipse(fill: Noor.chosen, stroke: Color.hex("#FFFFFF"), lineWidth: 1.6).size(d, d).at(0, 0)
                Node.ellipse(fill: Color.hex("#FFFFFF")).size(d * 0.36, d * 0.36).at(d * 0.32, d * 0.32)
            } else {
                Node.ellipse(fill: Color.hex("#00000000"), stroke: Noor.muted, lineWidth: 1.2).size(d, d).at(0, 0)
            }
        }
        .size(d, d).at(cx - d / 2, cy - d / 2)
    }

    /// A well for a native field or menu to sit in, or a row's bed.
    static func well(_ w: Double, _ h: Double, corner: Double, fill: Color = Noor.surface, line: Color = NoorLine.soft) -> Node {
        Node.rect(fill: fill, stroke: line, lineWidth: 1, corner: corner).size(w, h)
    }

    /// A capsule whose words are centred with their sign just after them, as the boards' Continue is.
    static func ctaPill(_ id: String, label: String, x: Double, y: Double, w: Double, h: Double, symbol: String? = "arrow.forward", leading: String? = nil, filled: Bool = true, disabled: Bool = false, size: Double) -> Node {
        let ink = filled ? Noor.onChosen : Noor.text
        let glyph = size * 1.05
        let words = Double(label.count) * size * 0.5
        let lead = leading == nil ? 0 : glyph + size * 0.6, trail = symbol == nil ? 0 : glyph + size * 0.7
        let start = max(h * 0.3, (w - words - lead - trail) / 2)
        return Node.group {
            if filled {
                Node.capsule(stroke: .hex("#A58DE6"), lineWidth: 1).gradient([.hex("#7D5CCC"), .hex("#5B3FA6")]).size(w, h).at(0, 0)
            } else {
                Node.capsule(fill: Noor.quiet, stroke: Noor.edge, lineWidth: 1.2).size(w, h).at(0, 0)
            }
            if let leading { Node.symbol(leading, color: ink).size(glyph, glyph).at(start, (h - glyph) / 2) }
            Node.say(label, start + lead, 0, max(words + size, w - start - lead - trail - h * 0.2), h, size: size, weight: "medium", color: ink)
            if let symbol { Node.symbol(symbol, color: ink).size(glyph, glyph).at(min(start + lead + words + size * 0.7, w - glyph - h * 0.3), (h - glyph) / 2) }
        }
        .size(w, h).at(x, y).opacity(disabled ? 0.45 : 1)
        .area(id, label: label, disabled: disabled)
    }

    /// A chip for what a thing is, in a small outline.
    static func chip(_ words: String, symbol: String? = nil, x: Double, y: Double, w: Double, h: Double, size: Double) -> Node {
        Node.group {
            Node.capsule(fill: Noor.quiet, stroke: NoorLine.soft, lineWidth: 1).size(w, h).at(0, 0)
            if let symbol { Node.symbol(symbol, color: Noor.muted).size(size, size).at(h * 0.4, (h - size) / 2) }
            Node.say(words, symbol == nil ? 8 : h * 0.4 + size + 6, 0, w - (symbol == nil ? 16 : h * 0.4 + size + 12), h, size: size, color: Noor.muted, align: symbol == nil ? "center" : "leading")
        }
        .size(w, h).at(x, y)
    }
}

enum NoorLine {
    /// The boards' row and well outline, a touch stronger than a panel's hairline.
    static let soft = Color.adaptive(light: "#C9C2E2", dark: "#3B4190")
    /// What goes round a chosen row.
    static let chosen = Color.adaptive(light: "#7354B8", dark: "#A58DE6")
    static let danger = Color.adaptive(light: "#B23A48", dark: "#F0707C")
    static let caution = Color.adaptive(light: "#A5620F", dark: "#F0B05A")
}

/// What a scene's part holds besides its nodes, to be gathered for its block.
struct SceneWiring {
    var tools: [String: (tool: String, input: [String: Any])] = [:]
    var acts: [String: PageAct] = [:]
    var inlays: [PageInlay] = []

    mutating func take(_ other: SceneWiring) {
        tools.merge(other.tools) { _, new in new }
        acts.merge(other.acts) { _, new in new }
        inlays += other.inlays
    }
}
