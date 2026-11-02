import Foundation
import SidefolkExtensionKit

/// The Qibla diagram: north up, a bearing clockwise from true north. It is geography, so it never mirrors, and it doesn't claim to know which way the Mac faces.
@MainActor
enum CompassScene {
    static func dial(_ degrees: Double, side: Double, letters: Double, inner: Bool = true) -> Node {
        let c = side / 2
        let r = side / 2 - letters - 8
        return Node.group {
            Node.ellipse(fill: Noor.surface, stroke: Noor.inlay, lineWidth: 1.6).size(r * 2, r * 2).at(c - r, c - r)
            Node.ellipse(stroke: .adaptive(light: "#7354B8", dark: "#6E7BD8"), lineWidth: 1).size((r + 6) * 2, (r + 6) * 2).at(c - r - 6, c - r - 6).opacity(0.6)
            // Marks every thirty degrees, finer between when there is room.
            for step in stride(from: 0, to: 360, by: side > 280 ? 6 : 30) {
                let long = step % 30 == 0, major = step % 90 == 0
                let a = clockPoint(c, c, r - 2, Double(step)), b = clockPoint(c, c, r - (major ? 22 : long ? 12 : 6), Double(step))
                Node.path("M \(n(a.x)) \(n(a.y)) L \(n(b.x)) \(n(b.y))", stroke: major ? Noor.inlay : Noor.faint, lineWidth: major ? 2.2 : 1).size(side, side).at(0, 0)
            }
            for (i, letter) in [L("N", context: "compass"), L("E", context: "compass"), L("S", context: "compass"), L("W", context: "compass")].enumerated() {
                let p = clockPoint(c, c, r + letters * 0.72, Double(i) * 90)
                Node.say(letter, p.x - letters, p.y - letters * 0.8, letters * 2, letters * 1.6, size: letters, weight: "medium", align: "center")
            }
            // The arrow: a long tapered blade from the centre, along the bearing.
            arrow(degrees, c: c, length: r * 0.82, width: max(8, r * 0.09))
            Node.ellipse(fill: Noor.surface, stroke: Noor.inlay, lineWidth: 2).size(r * 0.14, r * 0.14).at(c - r * 0.07, c - r * 0.07)
        }
        .size(side, side)
    }

    private static func arrow(_ degrees: Double, c: Double, length: Double, width: Double) -> Node {
        let tip = clockPoint(c, c, length, degrees)
        let root = clockPoint(c, c, length * 0.72, degrees)
        let left = clockPoint(root.x, root.y, width * 1.5, degrees - 90), right = clockPoint(root.x, root.y, width * 1.5, degrees + 90)
        let l0 = clockPoint(c, c, width * 0.25, degrees - 90), r0 = clockPoint(c, c, width * 0.25, degrees + 90)
        let shaftL = clockPoint(root.x, root.y, width * 0.45, degrees - 90), shaftR = clockPoint(root.x, root.y, width * 0.45, degrees + 90)
        let blade = [l0, shaftL, left, tip, right, shaftR, r0].enumerated().map { "\($0.offset == 0 ? "M" : "L") \(n($0.element.x)) \(n($0.element.y))" }.joined(separator: " ") + " Z"
        return Node.path(blade, fill: .adaptive(light: "#B9862F", dark: "#EFCF8E"), stroke: .adaptive(light: "#7A5A1E", dark: "#FFF0CC"), lineWidth: 0.8).size(c * 2, c * 2).at(0, 0)
    }

    static func small(_ degrees: Double, side: Double) -> Node {
        dial(degrees, side: side, letters: 13).leftToRight().label(L("{degrees} degrees clockwise from true north", ["degrees": "\(Int(degrees.rounded()) % 360)"]))
    }
}
