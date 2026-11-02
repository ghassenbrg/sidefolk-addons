import Foundation
import SidefolkExtensionKit

/// Noor's materials (its design system's tokens) and the pieces its scenes are made of. Light is pearl and lilac with rich lapis frames,
/// dark is luminous indigo. Nothing here is a word, a date or a time: those come from what is true now.
enum Noor {
    static let ink = "#15182F", lapis = "#293C86", amethyst = "#7354B8", plum = "#31203F", pearl = "#F5F0ED", lilac = "#EEE8F5", rose = "#BD7AA8", gold = "#C9AB72"

    // What the scenes write and fill with, for both appearances: the boards' own values.
    static let text = Color.adaptive(light: "#15182F", dark: "#F5F0ED")
    static let muted = Color.adaptive(light: "#4A4668", dark: "#B9B5D6")
    static let faint = Color.adaptive(light: "#6A6688", dark: "#8F8BB0")
    /// Words that stand out: the event in focus, the Hijri month.
    static let accent = Color.adaptive(light: "#6A2FB0", dark: "#E79AE0")
    static let warm = Color.adaptive(light: "#8A5A16", dark: "#EFCF8E")
    static let inlay = Color.adaptive(light: "#C9AB72", dark: "#D9A36E")
    static let hairline = Color.adaptive(light: "#DAD5EA", dark: "#2B3070")
    static let surface = Color.adaptive(light: "#FFFFFF", dark: "#11153A")
    static let quiet = Color.adaptive(light: "#FBF9FD", dark: "#14183F")
    static let well = Color.adaptive(light: "#EEE8F5", dark: "#1B2050")
    static let chosen = Color.hex("#7354B8")
    static let onChosen = Color.hex("#FFFFFF")
    /// A secondary button's outline.
    static let edge = Color.adaptive(light: "#4A3F8F", dark: "#6468BA")
    /// A selected tab or row.
    static let picked = Color.adaptive(light: "#6B4BB4", dark: "#46348C")
    static let pickedEdge = Color.adaptive(light: "#6B4BB4", dark: "#8C76D8")

    /// The page's own ground, its one picture out to the window's edges, and its cards (host D108).
    static var dress: PageDress { PageDress(ground: PagePair(light: "#F3EFF8", dark: "#0E1130"), card: PagePair(light: "#FFFFFF", dark: "#11153A"), line: PagePair(light: "#DAD5EA", dark: "#2B3070"), accent: PagePair(light: "#7354B8", dark: "#7354B8"), picture: .pack("art/ground-l.jpg", dark: "art/ground-d.jpg")) }
    static var tabTint: PagePair { PagePair(light: "#7354B8", dark: "#7354B8") }
}

/// The boards are drawn on a 1290-wide page. Every place and size on a page comes from them through this, so a composition keeps its proportions at any column; type only stops shrinking where it would stop being read.
struct Ruler {
    let s: Double
    init(width: Double) { s = max(0.56, min(width / 1290, 1.03)) }
    func u(_ x: Double) -> Double { x * s }
    func f(_ size: Double, min least: Double = 11) -> Double { max(size * s, least) }
}

extension Node {
    enum Frame: String { case dial = "frame-dial", square = "frame-square", portrait = "frame-portrait" }

    /// One of the painted arch panels: lattice around, a quiet window inside, which what matters stands in. Decoration, so VoiceOver passes it by.
    static func frame(_ kind: Frame, _ w: Double, _ h: Double, corner: Double = 16) -> Node {
        Node.image("art/\(kind.rawValue)-l.jpg", dark: "art/\(kind.rawValue)-d.jpg", fit: "cover").size(w, h).corner(corner).clip()
    }

    /// The lattice with nothing on it, cut to `w × h`.
    static func lattice(_ w: Double, _ h: Double, corner: Double = 16) -> Node {
        Node.image("art/lattice-l.jpg", dark: "art/lattice-d.jpg", fit: "cover").size(w, h).corner(corner).clip()
    }

    /// A panel that stands on the page: its fill, its line, its corners.
    static func panel(_ w: Double, _ h: Double, corner: Double = 16, fill: Color = Noor.surface, line: Color = Noor.hairline) -> Node {
        Node.rect(fill: fill, stroke: line, lineWidth: 1, corner: corner).size(w, h)
    }

    /// The lattice flourish in a card's top right corner, `side` across, cut by the card's own corner. A group the card's size holds it.
    static func flourish(_ w: Double, _ h: Double, side: Double, corner: Double = 16) -> Node {
        Node.group {
            Node.image("art/corner-l.png", dark: "art/corner-d.png", fit: "contain").size(side, side).at(w - side, 0)
        }
        .size(w, h).corner(corner).clip()
    }

    /// The soft light behind a mark.
    static func glow(_ color: Color, cx: Double, cy: Double, r: Double, opacity: Double = 0.9) -> Node {
        Node.image("art/glow.png", tint: color).size(r * 2, r * 2).at(cx - r, cy - r).opacity(opacity)
    }

    /// A pointed arch filling `w × h`: its head an ogee like the painted frames, its feet on the box's foot. `lift` is how tall its head is.
    static func archPath(_ w: Double, _ h: Double, lift: Double) -> String {
        let s = w * 0.5
        let shoulder = lift * 0.46
        return "M 0 \(n(h)) L 0 \(n(lift)) C 0 \(n(lift * 0.54)) \(n(w * 0.20)) \(n(lift * 0.42)) \(n(w * 0.34)) \(n(shoulder)) C \(n(w * 0.42)) \(n(lift * 0.32)) \(n(w * 0.47)) \(n(lift * 0.12)) \(n(s)) 0 "
            + "C \(n(w * 0.53)) \(n(lift * 0.12)) \(n(w * 0.58)) \(n(lift * 0.32)) \(n(w * 0.66)) \(n(shoulder)) C \(n(w * 0.80)) \(n(lift * 0.42)) \(n(w)) \(n(lift * 0.54)) \(n(w)) \(n(lift)) L \(n(w)) \(n(h)) Z"
    }

    /// A word on one line in a box: the same call everywhere, so type stays Noor's. Text that doesn't fit shrinks a little, then ends in dots.
    static func say(_ words: String, _ x: Double, _ y: Double, _ w: Double, _ h: Double, size: Double = 14, weight: String = "regular", color: Color = Noor.text,
                    align: String = "leading", lines: Int = 1, tabular: Bool = false) -> Node {
        var node = Node.text(words, size: size, weight: weight, color: color, align: align, lines: lines).size(w, h).at(x, y)
        if tabular { node = node.textLook(tabular: true) }
        return node
    }

    /// A capsule button in a scene, its area named `id`. `filled` is the page's one main action; the other is an outline on its panel.
    static func pill(_ id: String, label: String, spoken: String? = nil, x: Double, y: Double, w: Double, h: Double = 36, symbol: String? = nil, filled: Bool = false, value: String? = nil, disabled: Bool = false, size: Double = 13.5) -> Node {
        let ink = filled ? Noor.onChosen : Noor.text
        let glyph = size * 1.15
        return Node.group {
            if filled {
                Node.capsule(stroke: .hex("#A58DE6"), lineWidth: 1).gradient([.hex("#7D5CCC"), .hex("#5B3FA6")]).size(w, h).at(0, 0)
            } else {
                Node.capsule(fill: Noor.quiet, stroke: Noor.edge, lineWidth: 1.2).size(w, h).at(0, 0)
            }
            if symbol == "chevron.forward" {
                // Where it leads comes after the words, and turns with them in Arabic.
                Node.say(label, h * 0.4, 0, w - h * 1.2, h, size: size, weight: "medium", color: ink, align: "center")
                Node.symbol("chevron.forward", color: ink).size(glyph * 0.62, glyph).at(w - h * 0.66, (h - glyph) / 2)
            } else if let symbol {
                Node.symbol(symbol, color: ink).size(glyph, glyph).at(h * 0.42, (h - glyph) / 2)
                Node.say(label, h * 0.42 + glyph + 8, 0, w - h * 0.84 - glyph - 8, h, size: size, weight: "medium", color: ink, align: "leading")
            } else {
                Node.say(label, 12, 0, w - 24, h, size: size, weight: "medium", color: ink, align: "center")
            }
        }
        .size(w, h).at(x, y).opacity(disabled ? 0.45 : 1)
        .area(id, value: value, label: spoken ?? label, disabled: disabled)
    }
}

extension Node {
    // The old panel's names, until its last page is redrawn on the painted frames.
    static func patternPanel(_ w: Double, _ h: Double, corner: Double = 16, id: String? = nil) -> Node { lattice(w, h, corner: corner) }
    static func inlay(_ w: Double, _ h: Double, corner: Double = 16, width: Double = 1.5) -> Node { Node.rect(stroke: Noor.inlay, lineWidth: width, corner: corner).size(w, h) }
    static func arch(_ w: Double, _ h: Double, lift: Double, fill: Color = Noor.quiet) -> Node {
        Node.group {
            Node.path(archPath(w, h, lift: lift), fill: fill).size(w, h).at(0, 0)
            Node.path(archPath(w, h, lift: lift), stroke: Noor.inlay, lineWidth: 2).size(w, h).at(0, 0)
        }
        .size(w, h)
    }
}

/// A coordinate to a tenth of a point: a scene is sent as words, and fifteen digits of a curve are a lot of words for nothing to see.
func n(_ value: Double) -> String { String(format: "%.1f", value) }

/// A point on a circle by clock angle: degrees clockwise from the top. Never mirrored: geography and time read the same in every language.
func clockPoint(_ cx: Double, _ cy: Double, _ r: Double, _ degrees: Double) -> (x: Double, y: Double) {
    let a = (degrees - 90) * .pi / 180
    return (cx + r * cos(a), cy + r * sin(a))
}

/// An arc of a ring between two clock angles, as a filled path: cubic pieces so it stays round at any size.
func ringPath(_ cx: Double, _ cy: Double, inner: Double, outer: Double, from: Double, to: Double) -> String {
    func arc(_ r: Double, _ a0: Double, _ a1: Double, move: Bool) -> String {
        let pieces = max(1, Int(ceil(abs(a1 - a0) / 45)))
        let step = (a1 - a0) / Double(pieces)
        let k = 4.0 / 3.0 * tan(step * .pi / 180 / 4)
        var out = ""
        var at = a0
        let start = clockPoint(cx, cy, r, a0)
        out += (move ? "M " : "L ") + "\(n(start.x)) \(n(start.y)) "
        for _ in 0..<pieces {
            let p0 = clockPoint(cx, cy, r, at), p3 = clockPoint(cx, cy, r, at + step)
            let t0 = (at - 90) * .pi / 180, t3 = (at + step - 90) * .pi / 180
            let c1 = (p0.x - k * r * sin(t0), p0.y + k * r * cos(t0))
            let c2 = (p3.x + k * r * sin(t3), p3.y - k * r * cos(t3))
            out += "C \(n(c1.0)) \(n(c1.1)) \(n(c2.0)) \(n(c2.1)) \(n(p3.x)) \(n(p3.y)) "
            at += step
        }
        return out
    }
    return arc(outer, from, to, move: true) + arc(inner, to, from, move: false) + "Z"
}
