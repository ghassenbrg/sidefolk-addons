import Foundation
import SidefolkExtensionKit

// "You vs <companion>" (ScoreBar): both faces and names, the score large or round pips for a match, a streak, and the
// companion's sealed pick, on one card over the scene. It mirrors in right-to-left languages like everything else.
extension BoardDrawing {
    func scoreBar() -> PartBlock {
        let score = board.scorePart
        let width = Self.inner, gap = 4.0
        let hasPoints = score != nil
        let sideH = hasPoints ? (score?.rounds != nil ? 6 + 16 + 19.0 : 6 + 16 + 27.0) : 44.0
        let height = max(sideH, 44) + 8
        let markW = 42.0 + TextFit.width(L("VS"), size: 16, weight: "black") - 22
        let sideW = (width - 8 - markW - 2 * gap) / 2
        let two = score?.players
        return PartBlock(.box("score", w: width, h: height) {
            Node.gameCard(corner: 19, w: width, h: height).id("score.card")
            if let two {
                side("score.you", x: 4, w: sideW, h: height - 8, name: two[0], points: score?.you, rounds: score?.rounds, tint: Paint.players[0], face: initial(two[0], Paint.players[0]))
            } else {
                side("score.you", x: 4, w: sideW, h: height - 8, name: L("You"), points: score?.you, rounds: score?.rounds, tint: .win,
                     face: .box(w: 36, h: 36) {
                         Node.person().size(36, 36).corner(18).clip()
                         Node.ellipse(stroke: Paint.white, lineWidth: 2).at(1, 1).size(34, 34)
                     }, streak: score?.streak)
            }
            versus(x: 4 + sideW + gap, y: 4, w: markW, h: height - 8)
            if let two {
                side("score.other", x: 4 + sideW + gap + markW + gap, w: sideW, h: height - 8, name: two[1], points: score?.companion, rounds: score?.rounds, tint: Paint.players[1],
                     face: initial(two[1], Paint.players[1]))
            } else {
                side("score.other", x: 4 + sideW + gap + markW + gap, w: sideW, h: height - 8, name: "{companion}", points: score?.companion, rounds: score?.rounds, tint: .loss,
                     face: .faceDisc(x: 0, y: 0, side: 36).shadow(Paint.black15, radius: 2, dx: 0, dy: 1), sealed: score?.picked == true)
            }
        }, height: height)
    }

    private func side(_ id: String, x: Double, w: Double, h: Double, name: String, points: Int?, rounds: Int?, tint: Color, face: Node, streak: Int? = nil, sealed: Bool = false) -> Node {
        let nameX = 7 + 36 + 8.0
        var trailing = 7.0
        var extras: [Node] = []
        if let streak, streak >= 2 {
            // A streak is the person's winning run: success, with its flame.
            let words = Format.integer(streak), pill = TextFit.width(words, size: 12, weight: "heavy") + 14 + 14
            extras.append(.box(id + ".streak", x: w - 7 - pill, y: (h - 22) / 2, w: pill, h: 22) {
                Node.capsule(fill: .successSoft).size(pill, 22)
                Node.symbol("flame.fill", color: .win).symbolLook(weight: "heavy").at(6, 5).size(12, 12)
                Node.words(words, size: 12, weight: "heavy", x: 20, w: pill - 24, h: 22).textLook(tabular: true)
            }.label(L("{n} in a row", ["n": streak])))
            trailing += pill + 4
        }
        if sealed {
            extras.append(sealedCard(x: w - 7 - 22, y: (h - 30) / 2).label(L("{name} has picked", ["name": "{companion}"])))
            trailing += 26
        }
        let room = w - nameX - trailing
        return Node.box(id, x: x, y: 4, w: w, h: h) {
            Node.rect(fill: Paint.inset, corner: 15).id(id + ".inset").size(w, h)
            face.at(7, (h - 36) / 2)
            Node.words(name, size: 13, weight: "heavy", x: nameX, y: points == nil ? 0 : 3, w: room, h: points == nil ? h : 16)
            if let points {
                if let rounds {
                    Node.box(id + ".pips", x: nameX, y: 23, w: room, h: 11) {
                        for i in 0..<rounds {
                            Node.ellipse(fill: i < points ? tint : .line, stroke: i < points ? Paint.clear("#FFFFFF", 0.6) : nil, lineWidth: 1.5).at(Double(i) * 15, 0).size(11, 11)
                        }
                    }.label(Format.integer(points))
                } else {
                    Node.words(Format.integer(points), size: 22, weight: "black", x: nameX, y: 19, w: room, h: 27).textLook(tabular: true).id(id + ".points")
                }
            }
            extras
        }
    }

    /// A player's first letter on a disc of their colour, for two people playing each other (no picture of either).
    private func initial(_ name: String, _ color: Color) -> Node {
        .box(w: 36, h: 36) {
            Node.ellipse(fill: color).size(36, 36)
            Node.ellipse(stroke: Paint.white, lineWidth: 2).at(1, 1).size(34, 34)
            Node.words(name.first.map { String($0).uppercased() } ?? "?", size: 17.3, weight: "heavy", color: Paint.white, align: "center", w: 36, h: 36)
        }
    }

    /// "VS" between the two sides, with a few still sparks either side: the bar's one flourish.
    private func versus(x: Double, y: Double, w: Double, h: Double) -> Node {
        let sparks = { (side: Double, flip: Bool) -> Node in
            // Three short strokes fanning out from the trailing side, drawn once and still.
            let reach = 11.0, from = (x: 10.0, y: 12.0)
            var path = ""
            for angle in [-0.85, 0.0, 0.85] {
                path += "M \(from.x - cos(angle) * reach * 0.5) \(from.y + sin(angle) * reach * 0.5) L \(from.x - cos(angle) * reach) \(from.y + sin(angle) * reach) "
            }
            let node = Node.path(path, stroke: Paint.sun, lineWidth: 2).at(side, (h - 24) / 2).size(10, 24)
            return flip ? node.scale(x: -1, y: 1) : node
        }
        return Node.box("score.vs", x: x, y: y, w: w, h: h) {
            sparks(0, false)
            Node.words(L("VS"), size: 16, weight: "black", color: look.levelChip, align: "center", x: 11, w: w - 22, h: h).textLook(italic: true)
            sparks(w - 10, true)
        }
    }

    /// A small card face down with the companion's face on it: it has picked and isn't telling.
    private func sealedCard(x: Double, y: Double) -> Node {
        Node.box("score.sealed", x: x, y: y, w: 22, h: 30) {
            Node.rect(corner: 5).gradient([Paint.navy, Paint.clear("#0F2D5B", 0.75)], from: (0, 0), to: (1, 1)).size(22, 30)
            Node.rect(stroke: Paint.clear("#FFFFFF", 0.7), lineWidth: 1.5, corner: 4).at(2, 2).size(18, 26)
            Node.companion().figure(face: true).at(4, 8).size(14, 14).corner(7).clip()
        }.rotate(-8).shadow(Paint.black15, radius: 2, dx: 0, dy: 1)
    }
}
