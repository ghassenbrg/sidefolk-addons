import Foundation
import SidefolkExtensionKit

// A result drawn as it happens (RevealView), fixed before it plays: two hands that meet in the middle, a coin that turns, dice that
// tumble flat (a scene's flip is 2D, D99). It plays during the build-up; the verdict's board shows where it landed and never plays it twice.
// With Reduce Motion a step isn't played and its end shows at once.
extension BoardDrawing {
    static let revealMs = 1500.0

    func revealCard(_ reveal: Reveal) -> PartBlock {
        let width = Self.inner, height = 118.0
        return PartBlock(.box("reveal", w: width, h: height) {
            Node.gameCard(corner: 18, alpha: 0.92, w: width, h: height).id("reveal.card")
            revealInside(reveal, width: width, height: height, playing: ctx.buildUp, prefix: "reveal")
        }, height: height)
    }

    /// The reveal itself, also what a desktop overlay shows.
    func revealInside(_ reveal: Reveal, width: Double, height: Double, playing: Bool, prefix: String) -> [Node] {
        switch reveal {
        case .coin(let heads): coin(heads: heads, width: width, height: height, playing: playing, prefix: prefix)
        case .dice(let sides, let values): dice(sides: sides, values: values, width: width, height: height, playing: playing, prefix: prefix)
        case .hands(let you, let companion): hands(you: you, companion: companion, width: width, playing: playing, prefix: prefix)
        }
    }

    private func coin(heads: Bool, width: Double, height: Double, playing: Bool, prefix: String) -> [Node] {
        let id = prefix + ".coin", side = 64.0
        // Fourteen half turns land on heads, fifteen on tails.
        let turns = heads ? 14.0 : 15.0
        if playing { anims.append(Anim.flip(id, turns, ms: Self.revealMs, ease: "linear").named(id)) }
        return [Node.flip(front: Node.image("art/coin-heads.png").size(side, side), back: Node.image("art/coin-tails.png").size(side, side),
                          showing: !playing && !heads ? "back" : "front", axis: "x").id(id).at((width - side) / 2, (height - side) / 2).size(side, side)]
    }

    private func dice(sides: Int, values: [Int], width: Double, height: Double, playing: Bool, prefix: String) -> [Node] {
        let side = 44.0, gap = 10.0
        let total = Double(values.count) * side + Double(max(values.count - 1, 0)) * gap
        var x = (width - total) / 2
        var out: [Node] = []
        for (i, value) in values.enumerated() {
            let id = "\(prefix).die.\(i)"
            if sides == 6 {
                if playing {
                    let faces = (0..<18).map { f in "art/die-\((f * 7 + i * 3) % 6 + 1).png" } + ["art/die-\(value).png"]
                    anims.append(Anim.frames(id, faces, stepMs: Self.revealMs / 19).named(id + ".f"))
                }
                out.append(Node.image("art/die-\(playing ? 1 : value).png").id(id).at(x, (height - side) / 2).size(side, side))
            } else {
                out.append(Node.box(id, x: x, y: (height - side) / 2, w: side, h: side) {
                    Node.image("art/poly-\(sides).png").size(side, side)
                    Node.words(Format.integer(value), size: 14, weight: "heavy", color: Paint.white, align: "center", minScale: 0.5, x: 6, y: sides == 4 ? 4 : 0, w: side - 12, h: side)
                })
            }
            if playing {
                anims.append(.keys(id, [["t": 0, "rotate": 400 * (i % 2 == 0 ? 1 : -1)], ["t": 1, "rotate": 0]], ms: Self.revealMs, ease: "linear"))
            }
            x += side + gap
        }
        return out
    }

    /// Both hands pump sealed three times, fly to the middle and open on "shoot!", each on its own throw, then the winner acts on the
    /// loser: rock cracks scissors, paper covers rock, scissors snip paper in two, a draw bonks both back.
    private func hands(you: String, companion: String, width: Double, playing: Bool, prefix: String) -> [Node] {
        let mid = width / 2, home = min(width * 0.3, 92.0), meet = 30.0
        let verdict = handsVerdict(you, companion)
        let spring = verdict == .draw ? 26.0 : 12.0
        let opens = 0.45, acts = 0.62
        func side(_ name: String, hand: String, sign: Double, won: Bool, lost: Bool, mirrored: Bool) -> Node {
            let id = "\(prefix).\(name)", box = 58.0
            let restX = mid + sign * (meet + spring) - box / 2
            let homeX = mid + sign * home - box / 2
            let y = 56 - box / 2
            if playing {
                let pump: [[String: Double]] = stride(from: 0.0, through: opens, by: opens / 12).map { t in
                    ["t": t, "x": homeX, "y": y - abs(sin(t / opens * 3 * .pi)) * 14]
                }
                let fly: [[String: Double]] = [["t": acts, "x": mid + sign * meet - box / 2, "y": y], ["t": 0.78, "x": restX, "y": y], ["t": 1, "x": restX, "y": y]]
                anims.append(.keys(id, pump + fly, ms: Self.revealMs))
                anims.append(.keys(id + ".sealed", [["t": 0, "opacity": 1], ["t": opens - 0.001, "opacity": 1], ["t": opens, "opacity": 0], ["t": 1, "opacity": 0]], ms: Self.revealMs))
                anims.append(.keys(id + ".throw", [["t": 0, "opacity": 0], ["t": opens - 0.001, "opacity": 0], ["t": opens, "opacity": 1], ["t": 1, "opacity": 1]], ms: Self.revealMs))
                if won {
                    anims.append(.keys(id + ".throw", [["t": 0, "scale": 1], ["t": acts, "scale": 1], ["t": 1, "scale": 1.18]], ms: Self.revealMs))
                }
                if lost, hand != "paper" {
                    let end: [String: Double] = hand == "scissors" ? ["rotate": 70, "y": 24, "opacity": 0.5] : ["scale": 0.8, "y": 10, "opacity": 0.5]
                    let start: [String: Double] = hand == "scissors" ? ["rotate": 0, "y": 0, "opacity": 1] : ["scale": 1, "y": 0, "opacity": 1]
                    anims.append(.keys(id + ".defeat", [start.merging(["t": 0]) { a, _ in a }, start.merging(["t": acts]) { a, _ in a }, end.merging(["t": 1]) { a, _ in a }], ms: Self.revealMs))
                }
                if lost, hand == "paper" {
                    for (half, s) in [("a", -1.0), ("b", 1.0)] {
                        anims.append(.keys(id + ".half." + half, [["t": 0, "rotate": 0, "x": s < 0 ? 0 : 29, "y": 0], ["t": acts, "rotate": 0, "x": s < 0 ? 0 : 29, "y": 0],
                                                                  ["t": 1, "rotate": s * 14, "x": (s < 0 ? 0 : 29) + s * 9, "y": 6]], ms: Self.revealMs))
                    }
                }
            }
            let picture = "art/hand-\(hand).png"
            let shrink = lost && hand == "rock", turn = lost && hand == "scissors"
            var thrown: Node
            if lost, hand == "paper" {
                thrown = .box(id + ".defeat", w: box, h: box) {
                    Node.box(id + ".half.a", x: -9, y: 6, w: 29, h: box) { Node.image(picture).size(box, box) }.clip().rotate(-14)
                    Node.box(id + ".half.b", x: 38, y: 6, w: 29, h: box) { Node.image(picture).at(-29, 0).size(box, box) }.clip().rotate(14)
                }.opacity(0.6)
            } else {
                thrown = Node.image(picture).id(id + ".defeat").size(box, box)
                if shrink { thrown = thrown.scale(0.8).at(0, 10).opacity(0.5) }
                if turn { thrown = thrown.rotate(70).at(0, 24).opacity(0.5) }
            }
            if mirrored { thrown = Node.box(w: box, h: box) { thrown }.scale(x: -1, y: 1) }
            return Node.box(id, x: restX, y: y, w: box, h: box) {
                if won, !playing {
                    // The glow is the verdict: it comes when the reveal has ended, in the person's green or the calm tone.
                    Node.ellipse(fill: (sign < 0 ? Color.win : Color.loss).tuned(alpha: 0.2)).at(-13, -13).size(84, 84)
                }
                Node.box(id + ".throw", w: box, h: box) { thrown }.scale(won ? 1.18 : 1).opacity(playing ? 1 : 1)
                if playing {
                    Node.box(id + ".sealed", x: 3, y: 3, w: 52, h: 52) {
                        Node.rect(fill: .surfaceSunken, stroke: .line, lineWidth: 1, corner: 14).size(52, 52)
                        Node.symbol("questionmark", color: .inkMuted).symbolLook(weight: "heavy").at(13, 13).size(26, 26)
                    }.opacity(0)
                }
            }
        }
        func label(_ words: String, sign: Double, crown: Color?) -> Node {
            let w = 110.0
            return .box(x: mid + sign * home - w / 2, y: 95, w: w, h: 20) {
                Node.capsule(fill: Color.surface.tuned(alpha: 0.9)).size(w, 20)
                if let crown { Node.symbol("crown.fill", color: crown).symbolLook().at(6, 4).size(12, 12) }
                Node.words(words, size: 11.5, weight: "semibold", color: crown == nil ? .inkMuted : .ink, align: "center", design: "default", x: crown == nil ? 4 : 20, w: crown == nil ? w - 8 : w - 28, h: 20)
            }
        }
        return [
            side("you", hand: you, sign: -1, won: verdict == .win, lost: verdict == .loss, mirrored: false),
            side("them", hand: companion, sign: 1, won: verdict == .loss, lost: verdict == .win, mirrored: true),
            label(L("You"), sign: -1, crown: verdict == .win && !playing ? .win : nil),
            label("{companion}", sign: 1, crown: verdict == .loss && !playing ? .loss : nil),
        ]
    }

    func handsVerdict(_ you: String, _ companion: String) -> Verdict {
        if you == companion { return .draw }
        let beats = ["rock": "scissors", "paper": "rock", "scissors": "paper"]
        return beats[you] == companion ? .win : .loss
    }
}
