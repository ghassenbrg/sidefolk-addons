import Foundation
import SidefolkExtensionKit

// A result drawn as it happens (RevealView), fixed before it plays. It plays during the build-up; the verdict's board shows where it landed and never plays it twice.
// With Reduce Motion a step isn't played and its end shows at once. Only the hands are played on a board; coins and dice are the desktop's (Sources/Toss).
extension BoardDrawing {
    /// When the hands open and when the winner acts on the loser, as parts of the whole reveal.
    struct RevealBeat {
        var ms = 1500.0
        var opens = 0.45
        var acts = 0.62
    }

    func revealCard(_ reveal: Reveal) -> PartBlock {
        let width = Self.inner, height = 118.0
        return PartBlock(.box("reveal", w: width, h: height) {
            Node.gameCard(corner: 18, alpha: 0.92, w: width, h: height).id("reveal.card")
            if case .hands(let you, let companion) = reveal {
                hands(you: you, companion: companion, width: width, playing: ctx.buildUp, prefix: "reveal", beat: RevealBeat())
            }
        }, height: height)
    }

    /// Both hands pump sealed three times ("Rock… paper… scissors…"), fly to the middle and open on "shoot!", each on its own throw, then the winner acts on the loser: rock
    /// cracks scissors (the blades drop), paper covers rock (the rock sinks under it), scissors snip paper in two, and a draw bonks both back. The winner's glow and crown take
    /// the verdict's colour, when the reveal has ended, never during it.
    func hands(you: String, companion: String, width: Double, playing: Bool, prefix: String, beat: RevealBeat) -> [Node] {
        let mid = width / 2, home = min(width * 0.3, 92.0)
        let verdict = handsVerdict(you, companion)
        let samples = 36
        func act(_ p: Double) -> Double { min(max((p - beat.acts) / (1 - beat.acts), 0), 1) }

        /// They meet in the middle, then spring back a little: further for a draw, which bonks both.
        func gap(_ p: Double) -> Double {
            let fly = min(max((p - beat.opens) / (beat.acts - beat.opens), 0), 1)
            return home - fly * (home - 30) + sin(act(p) * .pi / 2) * (verdict == .draw ? 26 : 12)
        }

        func side(_ name: String, hand: String, sign: Double, won: Bool, lost: Bool, mirrored: Bool) -> Node {
            let id = "\(prefix).\(name)", box = 58.0
            let restX = mid + sign * gap(1) - box / 2, y = 56 - box / 2
            if playing {
                let flying = (0...samples).map { n -> [String: Double] in
                    let p = Double(n) / Double(samples)
                    let pump = min(p / beat.opens, 1)
                    return ["t": p, "x": mid + sign * gap(p) - box / 2, "y": y - (p < beat.opens ? abs(sin(pump * 3 * .pi)) * 14 : 0)]
                }
                anims.append(.keys(id, flying, ms: beat.ms))
                anims.append(.keys(id + ".sealed", [["t": 0, "opacity": 1], ["t": beat.opens - 0.001, "opacity": 1], ["t": beat.opens, "opacity": 0], ["t": 1, "opacity": 0]], ms: beat.ms))
                anims.append(.keys(id + ".throw", [["t": 0, "opacity": 0], ["t": beat.opens - 0.001, "opacity": 0], ["t": beat.opens, "opacity": 1], ["t": 1, "opacity": 1]], ms: beat.ms))
                if won {
                    anims.append(.keys(id + ".throw", [["t": 0, "scale": 1], ["t": beat.acts, "scale": 1], ["t": 1, "scale": 1.18]], ms: beat.ms))
                }
                if lost { defeat(hand, id: id, beat: beat) }
            }
            var thrown = defeated(hand, id: id, lost: lost, box: box)
            if mirrored { thrown = Node.box(w: box, h: box) { thrown }.scale(x: -1, y: 1) }
            return Node.box(id, x: restX, y: y, w: box, h: box) {
                if won, !playing {
                    // The person's win in success green; the companion's win is the person's loss, in the calm tone.
                    Node.ellipse(fill: (sign < 0 ? Color.win : Color.loss).tuned(alpha: 0.2)).at(-13, -13).size(84, 84)
                }
                Node.box(id + ".throw", w: box, h: box) { thrown }.scale(won ? 1.18 : 1)
                if playing {
                    // A hand not shown yet: a closed token with a "?", neither rock, paper nor scissors.
                    Node.box(id + ".sealed", x: 3, y: 3, w: 52, h: 52) {
                        Node.rect(fill: .surfaceSunken, stroke: .line, lineWidth: 1, corner: 14).size(52, 52).shadow(Paint.clear("#000000", 0.12), radius: 2, dx: 0, dy: 1)
                        Node.symbol("questionmark", color: .inkMuted).symbolLook(weight: "heavy").at(13, 13).size(26, 26)
                    }.opacity(0)
                }
            }
        }

        func label(_ words: String, sign: Double, crown: Color?) -> Node {
            let room = 110.0, text = min(TextFit.width(words, size: 11.5, weight: "semibold"), room - (crown == nil ? 16 : 31))
            let w = text + 16 + (crown == nil ? 0 : 15), h = 18.0
            return .box(x: mid + sign * home - w / 2, y: 106 - h / 2, w: w, h: h) {
                Node.capsule(fill: Color.surface.tuned(alpha: 0.9)).size(w, h)
                if let crown { Node.symbol("crown.fill", color: crown).symbolLook().at(8, 3).size(12, 12) }
                Node.words(words, size: 11.5, weight: "semibold", color: crown == nil ? .inkMuted : .ink, align: "center", design: "default", x: crown == nil ? 8 : 23, w: text, h: h)
            }
        }

        var words: [Node] = []
        var burst: [Node] = []
        if playing {
            // The count, a beat a word, then "Shoot!" fading as the outcome plays. A step: nothing here eases.
            for (i, word) in [L("Rock…"), L("Paper…"), L("Scissors…")].enumerated() {
                let id = "\(prefix).count.\(i)", from = beat.opens * Double(i) / 3, to = beat.opens * Double(i + 1) / 3
                var keys: [[String: Double]] = [["t": 0, "opacity": i == 0 ? 1 : 0]]
                if i > 0 { keys += [["t": from - 0.001, "opacity": 0], ["t": from, "opacity": 1]] }
                keys += [["t": to - 0.001, "opacity": 1], ["t": to, "opacity": 0], ["t": 1, "opacity": 0]]
                anims.append(.keys(id, keys, ms: beat.ms))
                words.append(Node.words(word, size: 16, weight: "heavy", color: .inkMuted, align: "center", x: 0, y: 2, w: width, h: 20).id(id).opacity(0))
            }
            let shoot = "\(prefix).shoot"
            let done = beat.acts + (1 - beat.acts) * 0.9
            anims.append(.keys(shoot, [["t": 0, "opacity": 0], ["t": beat.opens - 0.001, "opacity": 0], ["t": beat.opens, "opacity": 1], ["t": beat.acts, "opacity": 1], ["t": done, "opacity": 0.1], ["t": done + 0.001, "opacity": 0], ["t": 1, "opacity": 0]], ms: beat.ms))
            words.append(Node.words(L("Shoot!"), size: 16, weight: "heavy", color: .ink, align: "center", x: 0, y: 2, w: width, h: 20).id(shoot).opacity(0))
            // The clash itself: a burst, or an equals sign for a draw.
            let mark = "\(prefix).burst", side = verdict == .draw ? 22.0 : 30.0, fade = beat.acts + (1 - beat.acts) * 0.7
            anims.append(.keys(mark, [["t": 0, "opacity": 0, "scale": 0.6], ["t": beat.acts, "opacity": 0, "scale": 0.6], ["t": beat.acts + 0.001, "opacity": 1, "scale": 0.6], ["t": fade, "opacity": 0, "scale": 1.3], ["t": 1, "opacity": 0, "scale": 1.3]], ms: beat.ms))
            burst.append(Node.symbol(verdict == .draw ? "equal" : "burst.fill", color: Color.inkMuted.tuned(alpha: 0.8)).symbolLook(weight: "bold").id(mark).at(mid - side / 2, 52 - side / 2).size(side, side).opacity(0))
        }
        return words + [
            side("you", hand: you, sign: -1, won: verdict == .win, lost: verdict == .loss, mirrored: false),
            side("them", hand: companion, sign: 1, won: verdict == .loss, lost: verdict == .win, mirrored: true),
        ] + burst + [
            label(L("You"), sign: -1, crown: verdict == .win && !playing ? .win : nil),
            label("{companion}", sign: 1, crown: verdict == .loss && !playing ? .loss : nil),
        ]
    }

    /// A thrown hand's picture, where it ends: the hand that lost stays its own shape and takes the winner's effect. Scissors bend and drop, paper is cut in two, rock sinks and
    /// fades under the paper that covered it.
    private func defeated(_ hand: String, id: String, lost: Bool, box: Double) -> Node {
        let picture = "art/hand-\(hand).png"
        guard lost else { return TossArt.padded(picture, side: box, exported: 58).id(id + ".defeat") }
        switch hand {
        case "paper":
            return .box(id + ".defeat", w: box, h: box) {
                Node.box(id + ".half.a", x: -9, y: 6, w: 29, h: box) { TossArt.padded(picture, side: box, exported: 58) }.clip().anchor(1, 0.5).rotate(-14)
                Node.box(id + ".half.b", x: 38, y: 6, w: 29, h: box) { TossArt.padded(picture, side: box, exported: 58, x: -29) }.clip().anchor(0, 0.5).rotate(14)
            }.opacity(0.6)
        case "scissors":
            return Node.box(id + ".defeat", y: 24, w: box, h: box) { TossArt.padded(picture, side: box, exported: 58) }.rotate(70).opacity(0.5)
        default:
            return Node.box(id + ".defeat", y: 10, w: box, h: box) { TossArt.padded(picture, side: box, exported: 58) }.scale(0.8).opacity(0.5)
        }
    }

    private func defeat(_ hand: String, id: String, beat: RevealBeat) {
        func run(_ target: String, _ start: [String: Double], _ end: [String: Double]) {
            anims.append(.keys(target, [start.merging(["t": 0]) { a, _ in a }, start.merging(["t": beat.acts]) { a, _ in a }, end.merging(["t": 1]) { a, _ in a }], ms: beat.ms))
        }
        switch hand {
        case "paper":
            run(id + ".defeat", ["opacity": 1], ["opacity": 0.6])
            run(id + ".half.a", ["rotate": 0, "x": 0, "y": 0], ["rotate": -14, "x": -9, "y": 6])
            run(id + ".half.b", ["rotate": 0, "x": 29, "y": 0], ["rotate": 14, "x": 38, "y": 6])
        case "scissors": run(id + ".defeat", ["rotate": 0, "y": 0, "opacity": 1], ["rotate": 70, "y": 24, "opacity": 0.5])
        default: run(id + ".defeat", ["scale": 1, "y": 0, "opacity": 1], ["scale": 0.8, "y": 10, "opacity": 0.5])
        }
    }

    func handsVerdict(_ you: String, _ companion: String) -> Verdict {
        if you == companion { return .draw }
        let beats = ["rock": "scissors", "paper": "rock", "scissors": "paper"]
        return beats[you] == companion ? .win : .loss
    }
}
