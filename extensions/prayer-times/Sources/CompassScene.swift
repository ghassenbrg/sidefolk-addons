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

    static func small(_ degrees: Double, side: Double) -> Node {
        dial(degrees, side: side, letters: 13).leftToRight().label(L("{degrees} degrees clockwise from true north", ["degrees": "\(Int(degrees.rounded()) % 360)"]))
    }
}
