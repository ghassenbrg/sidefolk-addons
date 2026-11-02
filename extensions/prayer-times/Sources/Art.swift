import Foundation
import SidefolkExtensionKit

/// Noor's materials (its design system's tokens) and the pieces its scenes are made of. Light is pearl and lilac with rich lapis frames,
/// dark is luminous indigo. Nothing here is a word, a date or a time: those come from what is true now.
enum Noor {
    static let ink = "#15182F", lapis = "#293C86", amethyst = "#7354B8", plum = "#31203F", pearl = "#F5F0ED", lilac = "#EEE8F5", rose = "#BD7AA8", gold = "#C9AB72"

    // What the scenes write and fill with, for both appearances.
    static let text = Color.adaptive(light: "#15182F", dark: "#F5F0ED")
    static let muted = Color.adaptive(light: "#4A4668", dark: "#B9B5D6")
    static let faint = Color.adaptive(light: "#6A6688", dark: "#8F8BB0")
    /// Words that stand out: the event in focus, the Hijri month.
    static let accent = Color.adaptive(light: "#6A3CA8", dark: "#E79AE0")
    static let warm = Color.adaptive(light: "#8A5A16", dark: "#EFCF8E")
    static let inlay = Color.adaptive(light: "#C9AB72", dark: "#D9A36E")
    static let hairline = Color.adaptive(light: "#D9D1EA", dark: "#343A70")
    static let surface = Color.adaptive(light: "#FFFFFF", dark: "#191D3E")
    static let quiet = Color.adaptive(light: "#FBF9FD", dark: "#14183A")
    static let well = Color.adaptive(light: "#EEE8F5", dark: "#20254F")
    static let chosen = Color.hex("#7354B8")
    static let onChosen = Color.hex("#FFFFFF")

    /// The page's own ground and cards (host D108).
    static var dress: PageDress { PageDress(ground: PagePair(light: "#F5F0ED", dark: "#10132C"), card: PagePair(light: "#FFFFFF", dark: "#191D3E"), line: PagePair(light: "#D9D1EA", dark: "#343A70"), accent: PagePair(light: "#6243AD", dark: "#7354B8")) }
    static var tabTint: PagePair { PagePair(light: "#7354B8", dark: "#7354B8") }
}

extension Node {
    /// `w × h` of the repeat with its corners rounded: the pattern frames what matters, and is never behind a word.
    static func patternPanel(_ w: Double, _ h: Double, corner: Double = 18, id: String? = nil) -> Node {
        Node.group {
            Node.image("art/pattern-light.jpg", dark: "art/pattern-dark.jpg", fit: "cover").size(max(w, 900), max(h, 700)).at(0, 0)
        }
        .size(w, h).corner(corner).clip()
    }

    /// A gold hairline around a box.
    static func inlay(_ w: Double, _ h: Double, corner: Double = 18, width: Double = 1.5) -> Node {
        Node.rect(stroke: Noor.inlay, lineWidth: width, corner: corner).size(w, h)
    }

    /// A pointed arch filling `w × h`: its head an ogee like the page's own frame, its feet on the box's foot. `lift` is how tall its head is.
    static func archPath(_ w: Double, _ h: Double, lift: Double) -> String {
        let s = w * 0.5
        let shoulder = lift * 0.46
        return "M 0 \(n(h)) L 0 \(n(lift)) C 0 \(n(lift * 0.54)) \(n(w * 0.20)) \(n(lift * 0.42)) \(n(w * 0.34)) \(n(shoulder)) C \(n(w * 0.42)) \(n(lift * 0.32)) \(n(w * 0.47)) \(n(lift * 0.12)) \(n(s)) 0 "
            + "C \(n(w * 0.53)) \(n(lift * 0.12)) \(n(w * 0.58)) \(n(lift * 0.32)) \(n(w * 0.66)) \(n(shoulder)) C \(n(w * 0.80)) \(n(lift * 0.42)) \(n(w)) \(n(lift * 0.54)) \(n(w)) \(n(lift)) L \(n(w)) \(n(h)) Z"
    }

    /// The arch window: its quiet inside and, along its edge, the inlay. Sits on a pattern panel.
    static func arch(_ w: Double, _ h: Double, lift: Double, fill: Color = Noor.quiet) -> Node {
        Node.group {
            Node.path(archPath(w, h, lift: lift), fill: fill).size(w, h).at(0, 0)
            Node.path(archPath(w, h, lift: lift), stroke: Noor.inlay, lineWidth: 2).size(w, h).at(0, 0)
        }
        .size(w, h)
    }

    /// A word on one line in a box: the same call everywhere, so type stays Noor's. Text that doesn't fit shrinks a little, then ends in dots.
    static func say(_ words: String, _ x: Double, _ y: Double, _ w: Double, _ h: Double, size: Double = 14, weight: String = "regular", color: Color = Noor.text,
                    align: String = "leading", lines: Int = 1, tabular: Bool = false) -> Node {
        var node = Node.text(words, size: size, weight: weight, color: color, align: align, lines: lines).size(w, h).at(x, y)
        if tabular { node = node.textLook(tabular: true) }
        return node
    }

    /// A capsule button in a scene, its area named `id`. `filled` is the page's one main action.
    static func pill(_ id: String, label: String, spoken: String? = nil, x: Double, y: Double, w: Double, h: Double = 36, symbol: String? = nil, filled: Bool = false, value: String? = nil, disabled: Bool = false) -> Node {
        let ink = filled ? Noor.onChosen : Noor.text
        return Node.group {
            if filled {
                Node.capsule(fill: Noor.chosen).size(w, h).at(0, 0)
            } else {
                Node.capsule(fill: Noor.quiet, stroke: Noor.inlay, lineWidth: 1.2).size(w, h).at(0, 0)
            }
            if symbol == "chevron.forward" {
                // Where it leads comes after the words, and turns with them in Arabic.
                Node.say(label, 14, 0, w - 42, h, size: 13.5, weight: "medium", color: ink, align: "center")
                Node.symbol("chevron.forward", color: ink).size(10, 14).at(w - 24, (h - 14) / 2)
            } else if let symbol {
                Node.symbol(symbol, color: ink).size(16, 16).at(14, (h - 16) / 2)
                Node.say(label, 36, 0, w - 48, h, size: 13.5, weight: "medium", color: ink, align: "leading")
            } else {
                Node.say(label, 12, 0, w - 24, h, size: 13.5, weight: "medium", color: ink, align: "center")
            }
        }
        .size(w, h).at(x, y).opacity(disabled ? 0.45 : 1)
        .area(id, value: value, label: spoken ?? label, disabled: disabled)
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
