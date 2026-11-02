import Foundation
import SidefolkExtensionKit

/// The Qibla diagram: north up, a bearing clockwise from true north. It is geography, so it never mirrors, and it doesn't claim to know which way the Mac faces.
@MainActor
enum CompassScene {
    /// North up, always: a bearing on the map, never this Mac's heading. `letters` is the size of N, E, S and W, set outside the rings.
    static func dial(_ degrees: Double, side: Double, letters: Double, inner: Bool = true) -> Node {
        let c = side / 2
        let r = side / 2 - letters * 1.7
        let large = side > 280
        let gold = Color.adaptive(light: "#7A3FA8", dark: "#EBC98A"), mark = Color.adaptive(light: "#B48A3E", dark: "#EFCF8E")
        var fine = "", long = "", major = ""
        for step in stride(from: 0, to: 360, by: large ? 3 : 15) {
            let a = clockPoint(c, c, r - 2, Double(step))
            let isMajor = step % 90 == 0, isLong = step % 30 == 0
            let b = clockPoint(c, c, r - (isMajor ? r * 0.15 : isLong ? r * 0.075 : r * 0.03), Double(step))
            let line = "M \(n(a.x)) \(n(a.y)) L \(n(b.x)) \(n(b.y)) "
            if isMajor { major += line } else if isLong { long += line } else { fine += line }
        }
        return Node.group {
            Node.image("art/dial-face-l.png", dark: "art/dial-face-d.png", fit: "fill").size(r * 2, r * 2).at(c - r, c - r)
            Node.path(ringPath(c, c, inner: r + letters * 0.45, outer: r + letters * 0.45, from: 0, to: 360), stroke: .adaptive(light: "#6B4BB4", dark: "#6E7BD8"), lineWidth: 1, dash: [1.5, 5]).size(side, side).at(0, 0)
            Node.ellipse(stroke: gold, lineWidth: large ? 2.4 : 1.4).size(r * 2, r * 2).at(c - r, c - r)
            Node.path(fine, stroke: Noor.faint, lineWidth: 0.9).size(side, side).at(0, 0)
            Node.path(long, stroke: mark, lineWidth: 1.3).size(side, side).at(0, 0)
            Node.path(major, stroke: mark, lineWidth: large ? 3 : 2).size(side, side).at(0, 0)
            for (i, letter) in [L("N", context: "compass"), L("E", context: "compass"), L("S", context: "compass"), L("W", context: "compass")].enumerated() {
                let dot = clockPoint(c, c, r, Double(i) * 90)
                Node.ellipse(fill: mark).size(letters * 0.42, letters * 0.42).at(dot.x - letters * 0.21, dot.y - letters * 0.21)
                let p = clockPoint(c, c, r + letters * 1.0, Double(i) * 90)
                Node.say(letter, p.x - letters, p.y - letters * 0.8, letters * 2, letters * 1.6, size: letters, weight: "medium", align: "center")
            }
            arrow(degrees, c: c, length: r * (large ? 0.86 : 0.62), width: max(5, r * 0.085))
            Node.ellipse(fill: .adaptive(light: "#FFFFFF", dark: "#14183F"), stroke: mark, lineWidth: large ? 3 : 1.6).size(r * 0.13, r * 0.13).at(c - r * 0.065, c - r * 0.065)
            if large { Node.ellipse(fill: mark).size(r * 0.05, r * 0.05).at(c - r * 0.025, c - r * 0.025) }
        }
        .size(side, side)
    }

    /// A tapered blade with a swept head, along the bearing.
    private static func arrow(_ degrees: Double, c: Double, length: Double, width: Double) -> Node {
        let tip = clockPoint(c, c, length, degrees)
        let root = clockPoint(c, c, length * 0.74, degrees)
        let notch = clockPoint(c, c, length * 0.80, degrees)
        let left = clockPoint(root.x, root.y, width * 1.3, degrees - 90), right = clockPoint(root.x, root.y, width * 1.3, degrees + 90)
        let l0 = clockPoint(c, c, width * 0.75, degrees - 90), r0 = clockPoint(c, c, width * 0.75, degrees + 90)
        let shaft = clockPoint(notch.x, notch.y, width * 0.34, degrees - 90), shaftR = clockPoint(notch.x, notch.y, width * 0.34, degrees + 90)
        let blade = [l0, shaft, left, tip, right, shaftR, r0].enumerated().map { "\($0.offset == 0 ? "M" : "L") \(n($0.element.x)) \(n($0.element.y))" }.joined(separator: " ") + " Z"
        return Node.path(blade, fill: .hex("#EFCF8E")).gradient([.adaptive(light: "#D8A24E", dark: "#FFF0CC"), .adaptive(light: "#8A5A16", dark: "#C98A3E")], from: (0, 0), to: (1, 1)).size(c * 2, c * 2).at(0, 0).shadow(.hex("#00000066"), radius: 3, dx: 0, dy: 2)
    }

    /// The Qibla tab's own, as its board has it: a dark rim round a gold ring, marks standing clear of the ring, cardinal posts on stems, and a faceted needle. `side` holds its letters too.
    static func large(_ degrees: Double, side: Double) -> Node {
        let c = side / 2, r = c / 1.27
        let letters = r * 0.118, rim = r * 1.062
        let gold = Color.adaptive(light: "#A67A2E", dark: "#F0CD8E"), mark = Color.adaptive(light: "#A67A2E", dark: "#EFCF8E")
        var dots = "", tens = "", thirties = "", stems = "", posts = ""
        func tick(_ from: Double, _ to: Double, _ at: Int) -> String {
            let a = clockPoint(c, c, r * from, Double(at)), b = clockPoint(c, c, r * to, Double(at))
            return "M \(n(a.x)) \(n(a.y)) L \(n(b.x)) \(n(b.y)) "
        }
        for at in stride(from: 0, to: 360, by: 5) {
            if at % 90 == 0 {
                stems += tick(1, 0.915, at)
                posts += tick(0.905, 0.79, at)
            } else if at % 30 == 0 {
                thirties += tick(0.925, 0.835, at)
            } else if at % 10 == 0 {
                tens += tick(0.925, 0.875, at)
            } else {
                dots += tick(0.925, 0.905, at)
            }
        }
        return Node.group {
            Node.ellipse(fill: .adaptive(light: "#F7F2FA", dark: "#0B0E2C"), stroke: .adaptive(light: "#C9BFE0", dark: "#2B3070"), lineWidth: 1).size(rim * 2, rim * 2).at(c - rim, c - rim).shadow(.hex("#00000080"), radius: r * 0.05, dx: 0, dy: r * 0.012)
            Node.path(ringPath(c, c, inner: rim, outer: rim, from: 0, to: 360), stroke: .adaptive(light: "#7A5AB8", dark: "#6E7BD8"), lineWidth: 0.8, dash: [1.2, 5]).size(side, side).at(0, 0)
            Node.image("art/dial-face-l.png", dark: "art/dial-face-d.png", fit: "fill").size(r * 2, r * 2).at(c - r, c - r)
            Node.ellipse(stroke: gold, lineWidth: max(1.6, r * 0.012)).size(r * 2, r * 2).at(c - r, c - r)
            Node.path(dots, stroke: mark, lineWidth: 1).size(side, side).at(0, 0).opacity(0.75)
            Node.path(tens, stroke: mark, lineWidth: 1.1).size(side, side).at(0, 0)
            Node.path(thirties, stroke: mark, lineWidth: 1.6).size(side, side).at(0, 0)
            Node.path(stems, stroke: mark, lineWidth: 1).size(side, side).at(0, 0)
            Node.path(posts, stroke: mark, lineWidth: max(2.4, r * 0.016)).size(side, side).at(0, 0)
            for (i, letter) in [L("N", context: "compass"), L("E", context: "compass"), L("S", context: "compass"), L("W", context: "compass")].enumerated() {
                let dot = clockPoint(c, c, r, Double(i) * 90), bead = r * 0.046
                Node.ellipse(fill: mark).size(bead, bead).at(dot.x - bead / 2, dot.y - bead / 2)
                // North and south have the arch's height to stand in; east and west sit close, where it is narrow. Each on its own bit of quiet, the lattice being close.
                let p = clockPoint(c, c, r * (i % 2 == 0 ? 1.175 : 1.115), Double(i) * 90)
                Node.glow(.adaptive(light: "#FBF9FD", dark: "#0C0F2C"), cx: p.x, cy: p.y, r: letters * 1.25)
                Node.say(letter, p.x - letters, p.y - letters * 0.8, letters * 2, letters * 1.6, size: letters, weight: "medium", align: "center")
            }
            needle(degrees, c: c, r: r)
            Node.ellipse(fill: .adaptive(light: "#FFFFFF", dark: "#0E1130"), stroke: gold, lineWidth: max(1.6, r * 0.012)).size(r * 0.17, r * 0.17).at(c - r * 0.085, c - r * 0.085).shadow(.hex("#00000080"), radius: r * 0.02, dx: 0, dy: 1)
            Node.ellipse(fill: gold).size(r * 0.07, r * 0.07).at(c - r * 0.035, c - r * 0.035)
        }
        .size(side, side)
    }

    /// Two facets either side of the bearing, lit on one side and falling into shadow by the hub on the other, the way the board paints it.
    private static func needle(_ degrees: Double, c: Double, r: Double) -> Node {
        let hub = (x: c, y: c), length = r * 0.765, half = r * 0.082
        let tip = clockPoint(c, c, length, degrees), notch = clockPoint(c, c, length - r * 0.15, degrees), root = clockPoint(c, c, length - r * 0.178, degrees)
        let barbL = clockPoint(root.x, root.y, r * 0.08, degrees - 90), barbR = clockPoint(root.x, root.y, r * 0.08, degrees + 90)
        let hubL = clockPoint(c, c, half, degrees - 90), hubR = clockPoint(c, c, half, degrees + 90)
        func path(_ points: [(x: Double, y: Double)]) -> String {
            points.enumerated().map { "\($0.offset == 0 ? "M" : "L") \(n($0.element.x)) \(n($0.element.y))" }.joined(separator: " ") + " Z"
        }
        let side = c * 2, from = (hub.x / side, hub.y / side), to = (tip.x / side, tip.y / side)
        return Node.group {
            Node.path(path([hub, hubL, notch, barbL, tip]), fill: .hex("#EFCF8E")).gradient([.adaptive(light: "#B98A3A", dark: "#E9B56C"), .adaptive(light: "#D8A24E", dark: "#FFE7B8")], from: from, to: to).size(side, side).at(0, 0)
            Node.path(path([hub, hubR, notch, barbR, tip]), fill: .hex("#C98A3E")).gradient([.adaptive(light: "#5C3A0C", dark: "#3A2A2A"), .adaptive(light: "#8A5A16", dark: "#D9A058"), .adaptive(light: "#A8742A", dark: "#F6C983")], from: from, to: to).size(side, side).at(0, 0)
        }
        .size(side, side).shadow(.hex("#00000080"), radius: r * 0.02, dx: 0, dy: r * 0.008)
    }

    static func small(_ degrees: Double, side: Double) -> Node {
        dial(degrees, side: side, letters: 13).leftToRight().label(L("{degrees} degrees clockwise from true north", ["degrees": "\(Int(degrees.rounded()) % 360)"]))
    }
}
