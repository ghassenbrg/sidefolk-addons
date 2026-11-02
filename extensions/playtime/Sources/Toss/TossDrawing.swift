import Foundation
import SidefolkExtensionKit

/// The objects themselves (TossStage): a gold coin, a die, the felt tray. Pictures from the pack carry 4 pt of room for their shadow.
enum TossArt {
    /// The pictures were exported at a side with 4 pt round it (`surfaceExportArt`): `side` is what the object itself takes.
    static func padded(_ path: String, side: Double, exported: Double, x: Double = 0, y: Double = 0) -> Node {
        let k = (exported + 8) / exported, full = side * k, margin = (full - side) / 2
        return Node.image(path).at(x - margin, y - margin).size(full, full)
    }

    static let gold = Color.hex("#FFC93C"), rim = Color.hex("#E0A21E"), ink = Color.hex("#8A5A00")

    /// A coin's face: heads is the companion's own face embossed in gold, tails its folk mark, a star. Nothing on it reads as a letter or a number.
    static func coin(heads: Bool, side s: Double) -> Node {
        .box(w: s, h: s) {
            Node.ellipse(fill: ink.tuned(alpha: 0.85)).at(0, 1).size(s, s)
            Node.ellipse().gradient([gold, rim], from: (0, 0), to: (1, 1)).size(s, s)
            Node.ellipse(stroke: rim, lineWidth: 3).at(1.5, 1.5).size(s - 3, s - 3)
            Node.ellipse(stroke: ink.tuned(alpha: 0.28), lineWidth: 1).at(6.5, 6.5).size(s - 13, s - 13)
            if heads {
                Node.companion().figure(face: true, duotone: gold).at(8, 8).size(s - 16, s - 16).corner((s - 16) / 2).clip()
                Node.ellipse(stroke: ink.tuned(alpha: 0.4), lineWidth: 1).at(8.5, 8.5).size(s - 17, s - 17)
            } else {
                Node.path(star(s), fill: ink).size(s, s)
            }
            // The shine: a plain gradient across the face (D99, as amended).
            Node.ellipse().gradient([Paint.clear("#FFFFFF", 0), Paint.clear("#FFFFFF", 0.5), Paint.clear("#FFFFFF", 0)], from: (0, 0), to: (0.4, 1)).size(s, s)
        }.shadow(Paint.clear("#000000", 0.22), radius: 3, dx: 0, dy: 2)
    }

    private static func star(_ s: Double) -> String {
        var path = ""
        for i in 0..<10 {
            let a = Double(i) * .pi / 5 - .pi / 2, r = s * (i % 2 == 0 ? 0.24 : 0.1)
            path += "\(i == 0 ? "M" : "L") \(s / 2 + r * cos(a)) \(s * 0.52 + r * sin(a)) "
        }
        return path + "Z"
    }

    /// The felt tray dice land on, a little deeper on a dark desktop.
    static func tray(w: Double, h: Double) -> Node {
        let felt = Color.adaptive(light: "#2F8F5B", dark: "#23704A"), soft = Color.adaptive(light: "#2F8F5BD9", dark: "#23704AD9")
        return .box("toss.tray", w: w, h: h) {
            Node.rect(corner: 16).gradient([soft, felt]).size(w, h)
            Node.rect(stroke: .hex("#6B4A2B"), lineWidth: 5, corner: 16).at(2.5, 2.5).size(w - 5, h - 5)
            Node.rect(stroke: Paint.clear("#FFFFFF", 0.18), lineWidth: 1, corner: 12).at(5.5, 5.5).size(w - 11, h - 11)
        }.shadow(Paint.clear("#000000", 0.25), radius: 6, dx: 0, dy: 3)
    }

    /// A die's face: a d6 by its pips, any other by its silhouette with the number on top. A number's box: 9 pt in on a d4's triangle, whose middle is lower, 6 elsewhere.
    static func die(sides: Int, value: Int, side: Double) -> Node {
        if sides == 6 { return padded("art/die-\(value).png", side: side, exported: 44) }
        return .box(w: side, h: side) {
            padded("art/poly-\(polyhedron(sides)).png", side: side, exported: 44)
            dieNumber(value, sides: sides, side: side)
        }
    }

    static func dieNumber(_ value: Int, sides: Int, side: Double) -> Node {
        let k = side / 44, inset = (sides == 4 ? 9.0 : 6.0) * k
        return Node.words(Toss.number(value), size: 14 * k, weight: "heavy", color: Paint.white, align: "center", minScale: 0.5, x: inset, y: (sides == 4 ? 4 : 0) * k, w: side - 2 * inset, h: side)
    }

    /// The silhouettes in the pack: anything else is drawn as the gem.
    static func polyhedron(_ sides: Int) -> Int { [4, 8, 10, 12, 20].contains(sides) ? sides : 100 }
}
