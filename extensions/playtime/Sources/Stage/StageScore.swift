import Foundation
import SidefolkExtensionKit

// The top of every game, in the same places on every board: its icon and title, you against the companion, and the round between two hairlines. Quiet: the board is
// what matters. Mirrors in right-to-left languages like everything else.
extension BoardDrawing {
    func header() -> PartBlock {
        let width = Self.inner
        var y = 0.0
        var nodes: [Node] = [titleRow(ctx.entry.title, icon: look.icon, width: width)]
        y += 36
        if board.scorePart != nil {
            nodes.append(scoreRow(width: width).at(0, y))
            y += 34
        }
        if !ended, let meta = metaRow(width: width) {
            nodes.append(meta.at(0, y))
            y += 22
        }
        return PartBlock(.box("header", w: width, h: y) { nodes }, height: y)
    }

    /// The game's one icon beside its name, centred together.
    func titleRow(_ title: String, icon: String, width: Double) -> Node {
        let iconSide = 32.0, room = width - iconSide - 8
        let wordsW = Swift.min(TextFit.width(title, size: 21, weight: "black") + 2, room)
        let x = (width - iconSide - 8 - wordsW) / 2
        return .box("title", w: width, h: 34) {
            Node.art(icon, x: x, y: 1, w: iconSide, h: iconSide).id("title.icon")
            Node.words(title, size: 21, weight: "black", minScale: 0.7, x: x + iconSide + 8, w: wordsW, h: 34).id("title.words")
        }
    }

    /// "You 2 vs {companion} 1": faces, names and numbers, nothing behind them. Two people get their initials in their own colours.
    private func scoreRow(width: Double) -> Node {
        guard let score = board.scorePart else { return .box(w: 1, h: 1) {} }
        let vs = 34.0, side = (width - vs) / 2
        let two = score.players
        return .box("score", w: width, h: 32) {
            scoreSide("score.you", x: 0, w: side, name: two?[0] ?? L("You"), points: score.you, before: ctx.previous?.scorePart?.you, trailing: true,
                      face: two.map { initial($0[0], Paint.players[0]) } ?? Node.box(w: 28, h: 28) {
                          Node.person().size(28, 28).corner(14).clip()
                          Node.ellipse(stroke: Paint.card, lineWidth: 1.5).at(0.75, 0.75).size(26.5, 26.5)
                      })
            Node.capsule(fill: Paint.clear("#F2715F", 0.16)).id("score.vs").at(side + 3, 7).size(vs - 6, 18)
            Node.words(L("VS"), size: 10, weight: "black", color: Paint.coral, align: "center", x: side + 3, y: 7, w: vs - 6, h: 18)
            scoreSide("score.other", x: side + vs, w: side, name: two?[1] ?? "{companion}", points: score.companion, before: ctx.previous?.scorePart?.companion, trailing: false,
                      face: two.map { initial($0[1], Paint.players[1]) } ?? Node.faceDisc(x: 0, y: 0, side: 28, ring: 1.5), sealed: two == nil && score.picked && gameTable == nil)
        }
    }

    /// One side: `trailing` sits against the middle from the left, the other from the right, so the two read as a pair however long a name is.
    private func scoreSide(_ id: String, x: Double, w: Double, name: String, points: Int, before: Int?, trailing: Bool, face: Node, sealed: Bool = false) -> Node {
        let digits = Format.integer(points)
        let pointsW = Swift.max(TextFit.width(digits, size: 20, weight: "black") + 2, 16)
        let seal = sealed ? 24.0 : 0
        let nameW = Swift.min(TextFit.width(name, size: 13, weight: "heavy") + 2, w - 28 - 8 - 6 - pointsW - 4 - seal)
        let whole = 28 + 6 + nameW + 6 + pointsW + seal
        let start = trailing ? w - whole - 2 : 2
        if ctx.fresh, let before, before != points {
            anims.append(.keys(id + ".points", [["t": 0, "scale": 1.5], ["t": 1, "scale": 1]], ms: 360, ease: "spring"))
        }
        return .box(id, x: x, w: w, h: 32) {
            face.at(start, 2)
            Node.words(name, size: 13, weight: "heavy", minScale: 0.75, x: start + 34, w: nameW, h: 32)
            Node.words(digits, size: 20, weight: "black", align: "center", x: start + 34 + nameW + 6, w: pointsW, h: 32).textLook(tabular: true).id(id + ".points")
            if sealed { Node.art("art/envelope-sealed.webp", x: start + 34 + nameW + 6 + pointsW + 4, y: 7, w: 22, h: 18).id(id + ".sealed").label(L("{name} has picked", ["name": "{companion}"])) }
        }
    }

    private func initial(_ name: String, _ color: Color) -> Node {
        .box(w: 28, h: 28) {
            Node.ellipse(fill: color).size(28, 28)
            Node.words(name.first.map { String($0).uppercased() } ?? "?", size: 14, weight: "heavy", color: Paint.white, align: "center", w: 28, h: 28)
        }
    }

    /// "Round 1 of 5 · Fair" between two hairlines, a puzzle's clock first.
    private func metaRow(width: Double) -> Node? {
        var words = board.promptPart?.eyebrow ?? ""
        if let chip = board.promptPart?.chip { words += (words.isEmpty ? "" : " · ") + chip }
        if let rounds = board.scorePart?.rounds { words += (words.isEmpty ? "" : " · ") + L("First to {n}", ["n": rounds]) }
        let clock = puzzleClockPill()
        guard !words.isEmpty || clock != nil else { return nil }
        let textW = Swift.min(TextFit.width(words, size: 12.5, weight: "bold") + 2, width - 40 - (clock.map { $0.width + 8 } ?? 0))
        let whole = textW + (clock.map { $0.width + 8 } ?? 0)
        let x = (width - whole) / 2, line = Paint.clear("#A08A70", 0.35)
        return .box("meta", w: width, h: 20) {
            if x > 22 {
                Node.rect(fill: line).id("meta.line.a").at(6, 10).size(x - 16, 1)
                Node.rect(fill: line).id("meta.line.b").at(x + whole + 10, 10).size(x - 16, 1)
            }
            if let clock { clock.node.at(x, 0) }
            Node.words(words, size: 12.5, weight: "bold", align: "center", minScale: 0.7, x: x + (clock.map { $0.width + 8 } ?? 0), w: textW, h: 20).id("meta.words")
        }
    }
}
