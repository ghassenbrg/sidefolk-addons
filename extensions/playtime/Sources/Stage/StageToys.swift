import Foundation
import SidefolkExtensionKit

// Rock, Paper, Scissors as pop-up toys (the founder's choice): a pebble, a sheet of paper and a pair of scissors, your pick shut in your box and the companion's box sealed since the
// round began, so the choice being fixed first is something you can see. A throw is one scene: everything in it rests where the verdict will find it and the animations play from the
// press to there, so Reduce Motion shows the end at once and the verdict's board draws the same picture without playing it. The desktop overlay draws the same throw, smaller.
extension BoardDrawing {
    /// A throw's times, in ms from the press. The pick is in its box at `shut`, the boxes come forward and thump three times from `thumps`, both lids go at `opens`, the toys stand
    /// still from `hold`, and `clash` starts the gag.
    enum ToyTime {
        static let total = Double(Suspense.revealMs)
        static let shut = 400.0, thumps = 580.0, thump = 413.0, opens = 1820.0, hold = 2200.0, clash = 2500.0
    }

    /// Where a throw is drawn: the panel's arena, or the overlay's small row. Everything is sized from `scale`, the art's frames at their drawn size.
    struct ToyStage {
        var width: Double
        var scale = 1.0
        /// The two boxes' middles, the first player's first.
        var youX: Double
        var themX: Double
        /// A box frame's top, and where it stood before it stepped forward, if it did.
        var boxY: Double
        var fromY: Double?
        var wordsY: Double?
        /// Two people's names for the two boxes: then nobody's win is the person's or their loss, so what marks it is neutral.
        var names: [String]?
        /// Which toy hops into which box as it starts, from where; the box is then still at `fromY`.
        var hop: (hand: String, x: Double, y: Double, side: Double, into: String)?
        /// Two plates at the foot: whose box is whose, then how it went. Their words, their place and width.
        var plates: (y: Double, w: Double, h: Double, you: String, them: String)?
        var sealedYou = false
        var sealedThem = true
        /// A toy's frame, a little larger than the art's own size on the arena, as the picture has it.
        var toyGrowth = 1.0
        var box: Double { ToyArt.boxFrame * scale }
        var toy: Double { ToyArt.toyFrame * scale * toyGrowth }
        /// The floor of a box, where a toy stands inside it, and how far up its spring holds it.
        var mouthY: Double { boxY + box * ToyArt.mouth }
        var rise: Double { box * 0.36 }
        /// A toy's frame with its spring at this much of its stretch.
        func y(spring: Double) -> Double { mouthY - rise * spring - toy * ToyArt.toyFloor }
        var toyY: Double { y(spring: 1) }
        func x(_ side: String) -> Double { side == "you" ? youX : themX }
    }

    /// What a toy has turned into when it's over, and where.
    struct ToyRest {
        var x: Double
        var y: Double
        var spring = 1.0
        var picture = "toy"
        var front = false
    }

    // MARK: Building a timeline

    /// One thing's values at moments of the throw (ms), held before the first and after the last. Each thing has one track for each value, at most 32 points: a second on the same value
    /// would start from the first moment and cut the first off.
    func track(_ id: String, _ points: [(Double, [String: Double])], total: Double = ToyTime.total) {
        guard let first = points.first, let last = points.last else { return }
        var frames: [[String: Double]] = []
        if first.0 > 0 { frames.append(first.1.merging(["t": 0]) { a, _ in a }) }
        for (ms, values) in points { frames.append(values.merging(["t": (ms / total * 10000).rounded() / 10000]) { a, _ in a }) }
        if last.0 < total { frames.append(last.1.merging(["t": 1]) { a, _ in a }) }
        anims.append(.keys(id, frames, ms: total))
    }

    /// Off and on at a moment: a picture swapped, nothing easing.
    private func swap(_ id: String, at ms: Double, from: Double = 0, to: Double = 1, total: Double = ToyTime.total) {
        track(id, [(ms - 1, ["opacity": from]), (ms, ["opacity": to])], total: total)
    }

    /// Samples of a curve between two moments, for what no straight line would do: an arc, a spring, a wobble.
    private func curve(_ from: Double, _ to: Double, steps n: Int = 10, _ value: (Double) -> [String: Double]) -> [(Double, [String: Double])] {
        (0...n).map { i in
            let p = Double(i) / Double(n)
            return (from + (to - from) * p, value(p))
        }
    }

    private func r1(_ v: Double) -> Double { (v * 10).rounded() / 10 }
    private func r3(_ v: Double) -> Double { (v * 1000).rounded() / 1000 }
    /// A spring's stretch, from shut to full: quick out, past the end, settling.
    private static func spring(_ p: Double) -> Double { 1 - cos(p * .pi * 3.2) * exp(-4.2 * p) }

    // MARK: The boxes

    /// The back of a box: its open lid behind, then its body with the inside. Toys and their springs stand on this.
    func toyBoxBack(_ side: String, x: Double, y: Double, frame: Double, open: Bool) -> Node {
        let id = "box.\(side)"
        return Node.box(id, x: x - frame / 2, y: y, w: frame, h: frame) {
            Node.art(ToyArt.box(side, "lid-open"), w: frame, h: frame).id(id + ".lidopen").opacity(open ? 1 : 0).anchor(ToyArt.pivotX, ToyArt.pivotY)
            Node.art(ToyArt.box(side, "body"), w: frame, h: frame)
        }.anchor(0.5, ToyArt.boxFloor)
    }

    /// The front of a box: its front wall over the toy, then the shut lid and its seal.
    func toyBoxFront(_ side: String, x: Double, y: Double, frame: Double, open: Bool, sealed: Bool) -> Node {
        let id = "boxtop.\(side)", s = frame * ToyArt.sealSide
        return Node.box(id, x: x - frame / 2, y: y, w: frame, h: frame) {
            Node.art(ToyArt.box(side, "front"), w: frame, h: frame)
            Node.art(ToyArt.box(side, "lid-shut"), w: frame, h: frame).id(id + ".lidshut").opacity(open ? 0 : 1).anchor(ToyArt.pivotX, ToyArt.pivotY)
            Node.art(ToyArt.seal, x: frame * ToyArt.sealX - s / 2, y: frame * ToyArt.sealY - s / 2, w: s, h: s).id(id + ".seal").opacity(sealed ? 1 : 0)
        }.anchor(0.5, ToyArt.boxFloor)
    }

    /// Three thumps, each a hop and a slam harder than the last, the third held down, loaded, until the lids go; then it springs. The same for both boxes, frame for frame, so they
    /// give nothing away. A box that has just taken the pick gives under it first.
    private func thump(_ side: String, stage: ToyStage, takesPick: Bool, blows: [Double]) {
        var shape: [(Double, [String: Double])] = takesPick ? [(ToyTime.shut, ["sx": 1, "sy": 1]), (ToyTime.shut + 30, ["sx": 1.1, "sy": 0.88]), (ToyTime.shut + 110, ["sx": 0.98, "sy": 1.03]), (ToyTime.shut + 180, ["sx": 1, "sy": 1])] : [(ToyTime.thumps, ["sx": 1, "sy": 1])]
        // Where it stands: coming forward first if it does, then up before each slam.
        let from = stage.fromY ?? stage.boxY, y = stage.boxY
        var place: [(Double, [String: Double])] = [(ToyTime.shut, ["y": from])]
        place += curve(ToyTime.shut, ToyTime.thumps - 10, steps: 6) { p in ["y": self.r1(from + (y - from) * p * p * (3 - 2 * p))] }
        let hops = [stage.box * 0.05, stage.box * 0.08, stage.box * 0.12], squashes = [0.9, 0.85, 0.76]
        for i in 0..<3 {
            let at = ToyTime.thumps + Double(i) * ToyTime.thump, land = at + 240, s = squashes[i], wide = 1 + (1 - s) * 0.62
            place += [(at, ["y": y]), (at + 180, ["y": r1(y - hops[i])]), (land, ["y": y])]
            shape += [(at, ["sx": 1, "sy": 1]), (at + 90, ["sx": 0.96, "sy": 1.05]), (land - 1, ["sx": 0.98, "sy": 1.03]), (land + 30, ["sx": r3(wide), "sy": s])]
            if i < 2 { shape += [(land + 110, ["sx": 0.98, "sy": 1.03]), (at + ToyTime.thump - 1, ["sx": 1, "sy": 1])] }
        }
        shape += [(ToyTime.opens, ["sx": 1.15, "sy": 0.76]), (ToyTime.opens + 70, ["sx": 0.93, "sy": 1.12]), (ToyTime.opens + 170, ["sx": 1.03, "sy": 0.97]), (ToyTime.opens + 280, ["sx": 1, "sy": 1])]
        // Under a blow in the gag it gives a little.
        for ms in blows { shape += [(ms, ["sx": 1.05, "sy": 0.92]), (ms + 130, ["sx": 1, "sy": 1])] }
        for id in ["box.\(side)", "boxtop.\(side)"] {
            track(id, shape)
            track(id, place)
        }
    }

    // MARK: A throw

    /// Where each toy rests when it's over. The one that acted stands in front of what it beat.
    private func toyEnds(you: String, companion: String, stage: ToyStage) -> [String: ToyRest] {
        let verdict = handsVerdict(you, companion), toy = stage.toy, y = stage.toyY
        var out = ["you": ToyRest(x: stage.youX - toy / 2, y: y), "them": ToyRest(x: stage.themX - toy / 2, y: y)]
        guard verdict != .draw else { return out }
        let (winner, loser) = verdict == .win ? ("you", "them") : ("them", "you")
        let spot = stage.x(loser) - toy / 2
        switch verdict == .win ? companion : you {
        case "scissors":
            // The pebble sits on what it flattened; the spring under them has given way.
            let low = stage.y(spring: 0.4)
            out[loser] = ToyRest(x: spot, y: low, spring: 0.4, picture: "splayed")
            out[winner] = ToyRest(x: spot, y: low - toy * 0.2, spring: 0.08, front: true)
        case "paper":
            // The scissors stand where the sheet was, its two halves sunk either side.
            out[loser] = ToyRest(x: spot, y: stage.y(spring: 0.7), spring: 0.7, picture: "halves")
            out[winner] = ToyRest(x: spot, y: y - toy * 0.14, spring: 0.08, front: true)
        default:
            // Tucked in: the parcel is all there is, its pebble inside, in the pebble's own place.
            out[loser] = ToyRest(x: spot, y: y, picture: "gone")
            out[winner] = ToyRest(x: spot, y: y, spring: 0.08, picture: "parcel", front: true)
        }
        return out
    }

    /// The throw between two toys, in the three layers it needs: what is behind the toys, the toys, what is in front. `playing`: it plays from the press to where it rests; otherwise it
    /// just rests there, as the verdict's board does.
    func toyLayers(you: String, companion: String, stage: ToyStage, playing: Bool, prefix: String) -> (behind: [Node], toys: [Node], front: [Node]) {
        let verdict = handsVerdict(you, companion), toy = stage.toy
        let ends = toyEnds(you: you, companion: companion, stage: stage)
        var toys: [Node] = []
        // At the verdict, and not before: a soft round light behind who won. Whose loss it was is in its tone; two people's is neutral.
        if !playing, verdict != .draw, let rest = ends[verdict == .win ? "you" : "them"] {
            let glow = stage.names != nil ? Color.inkMuted : verdict == .win ? Color.win : Color.loss
            toys.append(Node.ellipse(fill: glow.tuned(alpha: 0.12)).id(prefix + ".glow").at(rest.x - toy * 0.06, rest.y).size(toy * 1.12, toy * 1.12))
        }
        for (side, hand) in [("you", you), ("them", companion)] {
            let id = "\(prefix).\(side)", rest = ends[side]!
            let springW = stage.box * ToyArt.springWide, springH = stage.rise
            func picture(_ path: String, _ name: String, shown: Bool) -> Node { Node.art(path, w: toy, h: toy).id("\(id).\(name)").opacity(shown ? 1 : 0).anchor(0.5, ToyArt.toyFloor) }
            toys.append(Node.art(ToyArt.spring, x: stage.x(side) - springW / 2, y: stage.mouthY - springH, w: springW, h: springH).id(id + ".spring").anchor(0.5, 1).scale(x: 1, y: rest.spring))
            var node = Node.box(id, x: rest.x, y: rest.y, w: toy, h: toy) {
                picture(ToyArt.toy(hand), "toy", shown: rest.picture == "toy")
                if hand == "scissors" {
                    picture("art/toy-scissors-closed.webp", "closed", shown: false)
                    picture("art/toy-scissors-splayed.webp", "splayed", shown: rest.picture == "splayed")
                }
                if hand == "paper" {
                    picture("art/toy-paper-draped.webp", "draped", shown: false)
                    picture("art/toy-paper-parcel.webp", "parcel", shown: rest.picture == "parcel")
                    Node.art("art/toy-paper-half-left.webp", x: -toy * 0.12, y: toy * 0.08, w: toy, h: toy).id(id + ".halfa").opacity(rest.picture == "halves" ? 1 : 0).rotate(-14).anchor(0.35, ToyArt.toyFloor)
                    Node.art("art/toy-paper-half-right.webp", x: toy * 0.12, y: toy * 0.08, w: toy, h: toy).id(id + ".halfb").opacity(rest.picture == "halves" ? 1 : 0).rotate(14).anchor(0.65, ToyArt.toyFloor)
                }
            }.anchor(0.5, ToyArt.toyFloor)
            if rest.front { node = node.z(5) }
            toys.append(node)
        }
        var front: [Node] = []
        if playing {
            let dustW = toy * 1.1
            if Set([you, companion]) == ["rock", "scissors"] || (you == companion && you == "rock") {
                front.append(Node.art(ToyArt.dust, w: dustW, h: dustW).id(prefix + ".dust").at(stage.x(verdict == .win ? "them" : "you") - dustW / 2, stage.y(spring: 0.4) + toy * 0.95 - dustW * 0.72).opacity(0).z(6))
            }
            if Set([you, companion]) == ["paper", "scissors"] {
                for i in 0..<3 { front.append(Node.art(ToyArt.scrap, w: toy * 0.2, h: toy * 0.2).id("\(prefix).scrap\(i)").at(0, 0).opacity(0).z(6)) }
            }
            if let wordsY = stage.wordsY {
                let wordW = Swift.min(stage.width * 0.42, 150.0), wordH = 28.0
                for (i, word) in [L("Rock…"), L("Paper…"), L("Scissors…"), L("Shoot!")].enumerated() {
                    let id = "\(prefix).count.\(i)"
                    front.append(Node.box(id, x: (stage.width - wordW) / 2, y: wordsY, w: wordW, h: wordH) {
                        Node.capsule(fill: Paint.card(0.95)).size(wordW, wordH)
                        Node.words(word, size: 19, weight: "heavy", color: i == 3 ? Paint.ink : Paint.inkSoft, align: "center", minScale: 0.6, x: 6, w: wordW - 12, h: wordH)
                    }.opacity(0).z(7))
                    let on = i == 3 ? ToyTime.opens : ToyTime.thumps + Double(i) * ToyTime.thump, off = i == 3 ? ToyTime.hold : ToyTime.thumps + Double(i + 1) * ToyTime.thump - 30
                    track(id, [(on - 1, ["opacity": 0]), (on, ["opacity": 1]), (off, ["opacity": 1]), (off + 1, ["opacity": 0])])
                }
            }
            playThrow(you: you, companion: companion, stage: stage, ends: ends, prefix: prefix)
        }
        if let plates = stage.plates {
            front.append(resultPlate("you", word: plates.you, stage: stage, verdict: playing ? nil : verdict, hand: you, playing: playing))
            front.append(resultPlate("them", word: plates.them, stage: stage, verdict: playing ? nil : verdict, hand: companion, playing: playing))
        }
        return (toyBackPair(stage), toys, toyFrontPair(stage) + front)
    }

    /// One plate under a box: whose it is while the throw plays. At the verdict, and not before, it says what it threw, how it went, and who won; two people's only who.
    func resultPlate(_ side: String, word: String, stage: ToyStage, verdict: Verdict?, hand: String, playing: Bool) -> Node {
        guard let plates = stage.plates else { return .box(w: 1, h: 1) {} }
        let id = "result.\(side)", w = plates.w, h = plates.h, neutral = stage.names != nil
        let won = verdict.map { side == "you" ? $0 == .win : $0 == .loss } ?? false
        let lost = verdict.map { side == "you" ? $0 == .loss : $0 == .win } ?? false
        let mine = side == "you" && !neutral
        let fill: Color = !mine ? Paint.card : won ? .win : lost ? Paint.lostSoft : Paint.card
        let ink: Color = mine && won ? .adaptive(light: "#FFFFFF", dark: "#14275A") : Paint.ink
        let title = verdict == nil ? word : word + " · " + RockPaperScissorsScreen.title(Games.Hand(rawValue: hand) ?? .rock)
        let mark: String? = verdict == nil ? nil : mine ? (won ? "checkmark" : lost ? "xmark" : "equal") : won ? "crown.fill" : verdict == .draw ? "equal" : nil
        let markColor: Color = mine ? ink : neutral || verdict == .draw ? Paint.ink : .loss
        if playing { track(id, [(ToyTime.shut + 80, ["opacity": 0, "scale": 0.8]), (ToyTime.thumps + 40, ["opacity": 1, "scale": 1])]) }
        // At its moment it comes up a little: the verdict arriving.
        if verdict != nil, ctx.fresh { anims.append(Anim.keys(id, [["t": 0, "scale": 0.86], ["t": 1, "scale": 1]], ms: 320, ease: "spring")) }
        let label = "\(title)" + (won ? ", " + L("right") : lost ? ", " + L("wrong") : "")
        return Node.box(id, x: stage.x(side) - w / 2, y: plates.y, w: w, h: h) {
            Node.capsule(fill: fill, stroke: Paint.edge, lineWidth: 1).id(id + ".back").size(w, h).shadow(Paint.clear("#3A2A55", 0.2), radius: 2, dx: 0, dy: 2)
            if let mark { Node.symbol(mark, color: markColor).symbolLook(weight: "heavy").at(11, (h - 15) / 2).size(15, 15) }
            Node.words(title, size: 13.5, weight: "heavy", color: ink, align: "center", minScale: 0.55, x: mark == nil ? 10 : 30, w: w - (mark == nil ? 20 : 42), h: h).id(id + ".words")
        }.label(label).z(5)
    }

    private func toyBackPair(_ s: ToyStage) -> [Node] {
        [toyBoxBack("you", x: s.youX, y: s.boxY, frame: s.box, open: true), toyBoxBack("them", x: s.themX, y: s.boxY, frame: s.box, open: true)]
    }

    private func toyFrontPair(_ s: ToyStage) -> [Node] {
        [toyBoxFront("you", x: s.youX, y: s.boxY, frame: s.box, open: true, sealed: false), toyBoxFront("them", x: s.themX, y: s.boxY, frame: s.box, open: true, sealed: false)]
    }

    /// The whole throw, moment by moment. A choice comes out only when the lids open.
    private func playThrow(you: String, companion: String, stage: ToyStage, ends: [String: ToyRest], prefix: String) {
        for side in ["you", "them"] {
            let sealed = side == "you" ? stage.sealedYou : stage.sealedThem
            let hops = stage.hop?.into == side
            thump(side, stage: stage, takesPick: hops, blows: blows(on: side, you: you, companion: companion))
            // Shut until the lids go; the box the pick went into shuts on it first. A lid is two pictures: one squashes on its hinge, the other grows out of it.
            let opening = ToyTime.opens + 30
            if hops {
                track("box.\(side).lidopen", [(ToyTime.shut - 50, ["sy": 1, "opacity": 1]), (ToyTime.shut - 1, ["sy": 0.1, "opacity": 1]), (ToyTime.shut, ["sy": 0.1, "opacity": 0]), (opening - 1, ["sy": 0.1, "opacity": 0]), (opening, ["sy": 0.1, "opacity": 1]), (opening + 80, ["sy": 1.14, "opacity": 1]), (opening + 180, ["sy": 0.96, "opacity": 1]), (opening + 270, ["sy": 1, "opacity": 1])])
                track("boxtop.\(side).lidshut", [(ToyTime.shut - 1, ["sy": 0.1, "opacity": 0]), (ToyTime.shut, ["sy": 0.1, "opacity": 1]), (ToyTime.shut + 50, ["sy": 1.08, "opacity": 1]), (ToyTime.shut + 100, ["sy": 1, "opacity": 1]), (ToyTime.opens, ["sy": 1, "opacity": 1]), (opening, ["sy": 0.1, "opacity": 1]), (opening + 1, ["sy": 0.1, "opacity": 0])])
            } else {
                track("box.\(side).lidopen", [(opening - 1, ["sy": 0.1, "opacity": 0]), (opening, ["sy": 0.1, "opacity": 1]), (opening + 80, ["sy": 1.14, "opacity": 1]), (opening + 180, ["sy": 0.96, "opacity": 1]), (opening + 270, ["sy": 1, "opacity": 1])])
                track("boxtop.\(side).lidshut", [(ToyTime.opens, ["sy": 1, "opacity": 1]), (opening, ["sy": 0.1, "opacity": 1]), (opening + 1, ["sy": 0.1, "opacity": 0])])
            }
            if sealed {
                let sign = side == "you" ? -1.0 : 1.0, s = stage.box * ToyArt.sealSide
                let x = stage.box * ToyArt.sealX - s / 2, y = stage.box * ToyArt.sealY - s / 2
                track("boxtop.\(side).seal", curve(ToyTime.opens, ToyTime.opens + 360, steps: 8) { p in
                    ["x": self.r1(x + sign * stage.box * 0.26 * p), "y": self.r1(y - stage.box * 0.5 * sin(p * .pi * 0.8)), "rotate": self.r1(sign * 170 * p), "opacity": p < 0.65 ? 1 : self.r3((1 - p) / 0.35)]
                })
            }
        }
        // The pick itself: it crouches on the spot, leaps in a high arc with a turn in the air, and drops into its box as the lid comes down.
        if let hop = stage.hop {
            let cy = (stage.fromY ?? stage.boxY) + stage.box * ToyArt.mouth - stage.toy * ToyArt.toyFloor, cx = stage.x(hop.into) - stage.toy / 2
            let leap = 70.0, dir = cx > hop.x ? 1.0 : -1.0
            track("toy.hop", [(0, ["x": hop.x, "y": hop.y]), (leap, ["x": hop.x, "y": hop.y])] + curve(leap, ToyTime.shut, steps: 10) { p in
                ["x": self.r1(hop.x + (cx - hop.x) * p), "y": self.r1(hop.y + (cy - hop.y) * p - stage.toy * 0.7 * 4 * p * (1 - p))]
            })
            track("toy.hop", [(0, ["sx": 1, "sy": 1]), (leap, ["sx": 1.12, "sy": 0.84]), (leap + 50, ["sx": 0.94, "sy": 1.1]), (ToyTime.shut - 60, ["sx": 0.85, "sy": 0.88]), (ToyTime.shut, ["sx": 0.8, "sy": 0.8])])
            track("toy.hop", [(leap, ["rotate": 0])] + curve(leap, ToyTime.shut, steps: 8) { p in ["rotate": self.r1(dir * 26 * sin(p * .pi))] })
            track("toy.hop", [(0, ["opacity": 1]), (ToyTime.shut - 1, ["opacity": 1]), (ToyTime.shut, ["opacity": 0])])
            track("toy.hop", [(0, ["z": 6]), (ToyTime.shut - 70, ["z": 6]), (ToyTime.shut - 69, ["z": 0])])
        }
        // On their springs: out in the same frame, past their height, wobbling, and still.
        let toy = stage.toy, y = stage.toyY, low = stage.y(spring: 0)
        for (side, hand) in [("you", you), ("them", companion)] {
            let id = "\(prefix).\(side)", here = stage.x(side) - toy / 2, sign = side == "you" ? 1.0 : -1.0
            track(id + ".spring", [(ToyTime.opens, ["opacity": 0]), (ToyTime.opens + 1, ["opacity": 1])])
            track(id + ".spring", curve(ToyTime.opens, ToyTime.hold, steps: 10) { p in ["sy": self.r3(Swift.max(Self.spring(p), 0.05))] } + springInGag(side: side, you: you, companion: companion))
            track(id, [(ToyTime.opens + 20, ["opacity": 0]), (ToyTime.opens + 21, ["opacity": 1])])
            track(id, [(ToyTime.opens, ["scale": 0.8]), (ToyTime.opens + 110, ["scale": 1])])
            var place: [(Double, [String: Double])] = [(ToyTime.opens, ["x": here, "y": r1(low)])]
            place += curve(ToyTime.opens, ToyTime.hold, steps: 10) { p in ["x": here, "y": self.r1(low + (y - low) * Self.spring(p))] }
            place += toyPath(side: side, hand: hand, you: you, companion: companion, stage: stage, ends: ends)
            track(id, place)
            track(id, curve(ToyTime.opens, ToyTime.hold, steps: 8) { p in ["rotate": self.r1(sign * 11 * sin(p * .pi * 3.5) * (1 - p))] } + toyTurn(side: side, hand: hand, you: you, companion: companion))
        }
        playGag(you: you, companion: companion, stage: stage, ends: ends, prefix: prefix)
    }

    /// When the box under the loser takes a blow.
    private func blows(on side: String, you: String, companion: String) -> [Double] {
        let verdict = handsVerdict(you, companion)
        guard verdict != .draw, (verdict == .win) == (side == "them") else { return [] }
        switch verdict == .win ? companion : you {
        case "scissors": return [2900]
        case "paper": return [3020]
        default: return [2850]
        }
    }

    /// A spring through the gag: the one whose toy leaves goes down after it; the one under the blow gives way.
    private func springInGag(side: String, you: String, companion: String) -> [(Double, [String: Double])] {
        let verdict = handsVerdict(you, companion)
        guard verdict != .draw else { return [] }
        if (verdict == .win) == (side == "you") {
            return [(ToyTime.clash + 200, ["sy": 1]), (ToyTime.clash + 290, ["sy": 0.05]), (ToyTime.clash + 380, ["sy": 0.14]), (ToyTime.clash + 450, ["sy": 0.08])]
        }
        switch verdict == .win ? companion : you {
        case "scissors": return [(2895, ["sy": 1]), (2945, ["sy": 0.4])]
        case "paper": return [(3020, ["sy": 1]), (3200, ["sy": 0.7])]
        default: return []
        }
    }

    /// A toy's place during the gag, ending at its rest. The one that acts moves; the other holds until it's hit.
    private func toyPath(side: String, hand: String, you: String, companion: String, stage: ToyStage, ends: [String: ToyRest]) -> [(Double, [String: Double])] {
        let toy = stage.toy, y = stage.toyY, here = stage.x(side) - toy / 2, rest = ends[side]!
        func arc(_ from: (Double, Double), _ to: (Double, Double), _ t0: Double, _ t1: Double, height: Double, steps: Int = 8) -> [(Double, [String: Double])] {
            curve(t0, t1, steps: steps) { p in ["x": self.r1(from.0 + (to.0 - from.0) * p), "y": self.r1(from.1 + (to.1 - from.1) * p - height * 4 * p * (1 - p))] }
        }
        let verdict = handsVerdict(you, companion)
        if verdict == .draw {
            let inward = side == "you" ? 1.0 : -1.0, gap = stage.themX - stage.youX
            switch hand {
            case "rock":
                // Clonk in the middle, and roll back apart.
                let meet = here + inward * (gap / 2 - toy * 0.33)
                return arc((here, y), (meet, y), 2520, 2850, height: toy * 0.25) + curve(2850, 3300, steps: 8) { p in ["x": self.r1(meet + (here - meet) * (1 - pow(1 - p, 2))), "y": y] }
            case "paper":
                // Close enough to bow.
                let close = here + inward * (gap / 2 - toy * 0.5)
                return [(2520, ["x": here, "y": y]), (2720, ["x": close, "y": y]), (3130, ["x": close, "y": y]), (3300, ["x": here, "y": y])]
            default:
                // Blades crossed, and sprung back.
                let meet = here + inward * (gap / 2 - toy * 0.3)
                return arc((here, y), (meet, y), 2520, 2840, height: toy * 0.2) + [(2960, ["x": meet, "y": y])] + curve(2960, 3280, steps: 6) { p in ["x": self.r1(meet + (here - meet) * Self.spring(p)), "y": y] }
            }
        }
        guard (verdict == .win) == (side == "you") else {
            let beaten = verdict == .win ? companion : you
            let hit = beaten == "scissors" ? 2900.0 : beaten == "paper" ? 3020.0 : 2850.0
            return [(hit, ["x": here, "y": y]), (hit + 60, ["x": rest.x, "y": rest.y])]
        }
        switch hand {
        case "rock":
            // Crouched, it leaps and lands; one bounce, and it stays sitting on them.
            return [(2700, ["x": here, "y": y])] + arc((here, y), (rest.x, rest.y), 2700, 2900, height: toy * 0.55) + arc((rest.x, rest.y), (rest.x, rest.y), 2900, 3120, height: toy * 0.16, steps: 6)
        case "scissors":
            // Over on its points in two hops, then three snips where it stands.
            let middle = (here + rest.x) / 2, up = (y + rest.y) / 2
            return arc((here, y), (middle, up), 2500, 2600, height: toy * 0.2, steps: 4) + arc((middle, up), (rest.x, rest.y), 2600, 2700, height: toy * 0.2, steps: 4)
        default:
            // Floats across, wavering, and drops.
            let high = y - toy * 0.3
            return curve(2500, 2780, steps: 10) { p in ["x": self.r1(here + (rest.x - here) * p + sin(p * .pi * 3) * toy * 0.07), "y": self.r1(y + (high - y) * sin(p * .pi / 2))] } + [(2850, ["x": rest.x, "y": rest.y])]
        }
    }

    /// A toy's lean during the gag.
    private func toyTurn(side: String, hand: String, you: String, companion: String) -> [(Double, [String: Double])] {
        let inward = side == "you" ? 1.0 : -1.0, verdict = handsVerdict(you, companion)
        if verdict == .draw {
            switch hand {
            case "rock": return curve(2850, 3300, steps: 8) { p in ["rotate": self.r1(-inward * 360 * (1 - pow(1 - p, 2)))] }
            case "paper": return [(2640, ["rotate": 0]), (2860, ["rotate": inward * 36]), (3060, ["rotate": inward * 36]), (3260, ["rotate": 0])]
            default: return [(2520, ["rotate": 0]), (2840, ["rotate": inward * 26]), (2960, ["rotate": inward * 26]), (3260, ["rotate": 0])]
            }
        }
        guard (verdict == .win) == (side == "you"), hand == "paper" else { return [] }
        return curve(2500, 2780, steps: 10) { p in ["rotate": self.r1(sin(p * .pi * 3) * 12)] } + [(2850, ["rotate": 0])]
    }

    /// What each toy turns into, and how it takes it.
    private func playGag(you: String, companion: String, stage: ToyStage, ends: [String: ToyRest], prefix: String) {
        let toy = stage.toy, verdict = handsVerdict(you, companion)
        if verdict == .draw {
            if you == "rock" {
                track(prefix + ".dust", [(2849, ["opacity": 0, "scale": 0.3, "x": stage.width / 2 - toy * 0.65]), (2850, ["opacity": 1, "scale": 0.4, "x": stage.width / 2 - toy * 0.65]), (3150, ["opacity": 0, "scale": 1, "x": stage.width / 2 - toy * 0.65])])
            }
            return
        }
        let (winner, loser) = verdict == .win ? ("you", "them") : ("them", "you")
        let w = "\(prefix).\(winner)", l = "\(prefix).\(loser)"
        // Whoever acts goes in front of the boxes from the moment it leaves its own.
        track(w, [(ToyTime.clash, ["z": 0]), (ToyTime.clash + 1, ["z": 5])])
        switch verdict == .win ? companion : you {
        case "scissors":
            // The pebble crouches, leaps, lands: the scissors go flat with a puff, the pebble bounces once and stays sitting on them.
            track(w, [(2500, ["sx": 1, "sy": 1]), (2680, ["sx": 1.16, "sy": 0.72]), (2740, ["sx": 0.92, "sy": 1.12]), (2880, ["sx": 1, "sy": 1]), (2905, ["sx": 1.18, "sy": 0.76]), (3020, ["sx": 1, "sy": 1])])
            swap(l + ".toy", at: 2900, from: 1, to: 0)
            swap(l + ".splayed", at: 2900)
            track(l, [(2900, ["sx": 1.28, "sy": 0.7]), (3050, ["sx": 1, "sy": 1])])
            track(prefix + ".dust", [(2899, ["opacity": 0, "scale": 0.4]), (2900, ["opacity": 0.95, "scale": 0.45]), (3010, ["opacity": 0.55, "scale": 0.95]), (3180, ["opacity": 0, "scale": 1.2])])
        case "paper":
            // Three snips, each a little deeper; on the last the sheet parts into two halves that sink, with scraps.
            let snips = [2700.0, 2860, 3020]
            track(w + ".closed", snips.flatMap { [($0 - 1, ["opacity": 0.0]), ($0, ["opacity": 1.0]), ($0 + 90, ["opacity": 1.0]), ($0 + 91, ["opacity": 0.0])] })
            track(w + ".toy", snips.flatMap { [($0 - 1, ["opacity": 1.0]), ($0, ["opacity": 0.0]), ($0 + 90, ["opacity": 0.0]), ($0 + 91, ["opacity": 1.0])] })
            swap(l + ".toy", at: 3020, from: 1, to: 0)
            let part = toy * 0.12, sink = toy * 0.08
            track(l + ".halfa", [(3019, ["opacity": 0, "x": 0, "y": 0, "rotate": 0]), (3020, ["opacity": 1, "x": 0, "y": 0, "rotate": 0]), (3300, ["opacity": 1, "x": -part, "y": sink, "rotate": -14])])
            track(l + ".halfb", [(3019, ["opacity": 0, "x": 0, "y": 0, "rotate": 0]), (3020, ["opacity": 1, "x": 0, "y": 0, "rotate": 0]), (3300, ["opacity": 1, "x": part, "y": sink, "rotate": 14])])
            for i in 0..<3 {
                let id = "\(prefix).scrap\(i)", at = snips[i], dx = [-0.5, 0.45, -0.14][i] * toy, x0 = stage.x(loser) - toy * 0.1, y0 = stage.toyY + toy * 0.2
                track(id, [(at - 1, ["x": x0, "y": y0, "rotate": 0, "opacity": 0])] + curve(at, at + 360, steps: 6) { p in ["x": self.r1(x0 + dx * p), "y": self.r1(y0 + toy * 0.8 * p * p - toy * 0.15 * sin(p * .pi)), "rotate": self.r1(220 * p), "opacity": p < 0.75 ? 1 : self.r3((1 - p) * 4)] })
            }
        default:
            // The sheet floats over and drops: flat, draped over the pebble, a parcel, which wiggles twice. The pebble has been tucked in.
            swap(w + ".toy", at: 2850, from: 1, to: 0)
            track(w + ".draped", [(2849, ["opacity": 0]), (2850, ["opacity": 1]), (3000, ["opacity": 1]), (3001, ["opacity": 0])])
            swap(w + ".parcel", at: 3000)
            swap(l + ".toy", at: 2850, from: 1, to: 0)
            track(w, [(3000, ["sx": 1.12, "sy": 0.9]), (3070, ["sx": 1, "sy": 1])])
            track(w + ".parcel", [(3090, ["rotate": 0]), (3120, ["rotate": 8]), (3155, ["rotate": -8]), (3190, ["rotate": 0]), (3225, ["rotate": 7]), (3260, ["rotate": -7]), (3295, ["rotate": 0])])
        }
    }

    /// The companion's figure through a throw: a dip with each thump, a flinch at the lids and at the impact, the same for every outcome, so it gives nothing away.
    func companionThrough(you: String, companion: String) {
        var points: [(Double, [String: Double])] = [(ToyTime.thumps, ["y": 0])]
        for i in 0..<3 {
            let at = ToyTime.thumps + Double(i) * ToyTime.thump
            points += [(at + 240, ["y": 0]), (at + 280, ["y": 4 + Double(i)]), (at + 390, ["y": 0])]
        }
        let impact = Self.toySounds(you: you, companion: companion).first?.0 ?? 2850
        points += [(ToyTime.opens, ["y": 0]), (ToyTime.opens + 50, ["y": -3]), (ToyTime.opens + 170, ["y": 0]), (impact, ["y": 0]), (impact + 50, ["y": -3]), (impact + 170, ["y": 0])]
        track("companion.figure", points)
    }

    /// The gag's sounds, first the one that lands.
    private static func toySounds(you: String, companion: String) -> [(Double, String)] {
        let pair = Set([you, companion])
        if pair.count == 1 { return [(2850, you == "paper" ? "flip" : "ding")] }
        if pair == ["rock", "scissors"] { return [(2900, "stamp")] }
        if pair == ["paper", "scissors"] { return [(2700, "snap"), (2860, "snap"), (3020, "snap")] }
        return [(2850, "flip")]
    }

    /// A throw's sounds, all of them from the pack: the lid on the pick, the thumps, the lids, the gag. The press itself sounds as any press.
    static func throwSounds(you: String, companion: String) -> Anim {
        var all: [(Double, String)] = [(ToyTime.shut, "cork"), (ToyTime.opens + 30, "cork")]
        for i in 0..<3 { all.append((ToyTime.thumps + 240 + Double(i) * ToyTime.thump, "tick")) }
        all += toySounds(you: you, companion: companion)
        var steps: [Anim] = []
        var at = 0.0
        for (ms, name) in all.sorted(by: { $0.0 < $1.0 }) {
            steps += [.wait(ms: ms - at), .sound("sounds/\(name).wav")]
            at = ms
        }
        return .sequence(steps)
    }

    // MARK: The arena

    /// The arena: two boxes at the back, the companion's already sealed, and the three toys in a row on their plates. On a pick that toy itself goes into its box, the other two bound
    /// off the table and the plates go, keeping their room; the boxes come forward and everything plays there, clear of the companion and its words. They come back for the next round.
    func handsTable() -> Node {
        let width = Self.inner, room = playRoom
        let a = board.answersPart
        let tiles = a?.tiles ?? Games.Hand.allCases.map { Tile(RockPaperScissorsScreen.title($0), art: $0.rawValue) }
        let locked = a?.locked ?? true
        answerKeys(tiles, locked: locked)
        let layout = arenaLayout(width: width, room: room)
        let duo = board.scorePart?.players != nil
        let away = board.revealPart != nil || a == nil
        var nodes: [Node] = [Node.felt("arena", x: -6, y: layout.arenaY, w: width + 12, h: layout.arenaH, corner: 30)]
        for (i, tile) in tiles.enumerated() {
            nodes.append(toySlot(tile, index: i, locked: locked, away: away, x: Double(i) * layout.columnW, y: layout.slotY, w: layout.columnW, toy: layout.slotToy, plateH: layout.plateH))
        }
        if case .hands(let you, let companion) = board.revealPart {
            nodes += throwNodes(you: you, companion: companion, layout: layout, duo: duo, tiles: tiles)
        } else {
            // Nothing thrown: who has shut what. Against the companion its box has been sealed since the round began; two people's stay shut until it's their turn.
            let first = board.sealedFirst, covering = board.hasCover
            let youOpen = duo ? !first : true, themOpen = duo ? first && !covering : false
            let sealedThem = !duo && board.scorePart?.picked == true
            nodes += [toyBoxBack("you", x: layout.youX, y: layout.backY, frame: layout.box, open: youOpen), toyBoxBack("them", x: layout.themX, y: layout.backY, frame: layout.box, open: themOpen),
                      toyBoxFront("you", x: layout.youX, y: layout.backY, frame: layout.box, open: youOpen, sealed: duo && first), toyBoxFront("them", x: layout.themX, y: layout.backY, frame: layout.box, open: themOpen, sealed: sealedThem)]
            if away {
                if ctx.fresh { toysLeave(tiles: tiles, picked: nil, layout: layout) }
            } else {
                roundMoments(layout: layout, tiles: tiles, duo: duo, nodes: &nodes)
            }
            if duo, first, ctx.fresh, ctx.previous?.sealedFirst != true {
                // The first pick is in: nothing says which. Its box shuts and takes its seal.
                track("box.you.lidopen", [(0, ["sy": 1, "opacity": 1]), (70, ["sy": 0.1, "opacity": 1]), (71, ["sy": 0.1, "opacity": 0])], total: 400)
                track("boxtop.you.lidshut", [(70, ["sy": 0.1, "opacity": 0]), (71, ["sy": 0.1, "opacity": 1]), (150, ["sy": 1, "opacity": 1])], total: 400)
                track("boxtop.you.seal", [(199, ["opacity": 0, "scale": 2]), (200, ["opacity": 1, "scale": 2]), (320, ["opacity": 1, "scale": 1])], total: 400)
            }
        }
        let buttons = tableButtons
        if !buttons.isEmpty { nodes.append(buttonRow(buttons, id: "dock", width: width).node.at(0, room - 46)) }
        return .box("arena.table", w: width, h: room) { nodes }
    }

    private struct ArenaLayout {
        var arenaY: Double, arenaH: Double, slotY: Double, slotToy: Double, plateY: Double, plateH: Double, columnW: Double
        var backY: Double, forwardY: Double, box: Double, youX: Double, themX: Double, scale: Double
    }

    private func arenaLayout(width: Double, room: Double) -> ArenaLayout {
        let arenaY = -4.0, arenaH = room - 46 - 8 - arenaY
        let plateH = 34.0, plateY = arenaY + arenaH - 14 - plateH
        let slotToy = ToyArt.toyFrame * 1.12
        let slotY = plateY - slotToy * ToyArt.toyFloor - 4
        let scale = 1.15, box = ToyArt.boxFrame * scale
        // At the back as the picture has them, the open lid over the felt's edge; forward, standing on the plates' row, with room over them to spring.
        let backY = arenaY - box * ToyArt.lidTop - 10
        let forwardY = plateY - 6 - box * ToyArt.boxFloor
        return ArenaLayout(arenaY: arenaY, arenaH: arenaH, slotY: slotY, slotToy: slotToy, plateY: plateY, plateH: plateH, columnW: width / 3, backY: backY, forwardY: forwardY, box: box,
                           youX: width / 2 - 86, themX: width / 2 + 86, scale: scale)
    }

    private func arenaStage(_ layout: ArenaLayout, duo: Bool) -> ToyStage {
        var stage = ToyStage(width: Self.inner, scale: layout.scale, youX: layout.youX, themX: layout.themX, boxY: layout.forwardY, wordsY: layout.arenaY + 8, names: board.scorePart?.players ?? ctx.previous?.scorePart?.players)
        stage.toyGrowth = layout.slotToy / (ToyArt.toyFrame * layout.scale)
        stage.plates = (layout.plateY, 164, layout.plateH, stage.names?[0] ?? L("You"), stage.names?[1] ?? "{companion}")
        stage.sealedYou = duo
        stage.sealedThem = !duo
        return stage
    }

    /// The throw on the arena.
    private func throwNodes(you: String, companion: String, layout: ArenaLayout, duo: Bool, tiles: [Tile]) -> [Node] {
        var stage = arenaStage(layout, duo: duo)
        var hopNode: [Node] = []
        if ctx.buildUp {
            stage.fromY = layout.backY
            let picked = ctx.pendingAnswer
            toysLeave(tiles: tiles, picked: picked, layout: layout)
            if let i = picked, let hand = tiles[safe: i]?.art {
                // The pick itself goes into its player's box: two people's second pick is the yellow one. Its picture on the plate is gone the moment this one takes off, so there is one toy.
                let into = duo ? "them" : "you", x = Double(i) * layout.columnW + (layout.columnW - stage.toy) / 2
                stage.hop = (hand, x, layout.slotY, stage.toy, into)
                hopNode = [Node.art(ToyArt.toy(hand), w: stage.toy, h: stage.toy).id("toy.hop").at(stage.x(into) - stage.toy / 2, layout.backY + stage.box * ToyArt.mouth - stage.toy * ToyArt.toyFloor).anchor(0.5, ToyArt.toyFloor).opacity(0)]
            }
            companionThrough(you: you, companion: companion)
        }
        let layers = toyLayers(you: you, companion: companion, stage: stage, playing: ctx.buildUp, prefix: "reveal")
        // Between the box's inside and its front: as it lands the front hides its base and the lid comes down on it.
        return layers.behind + hopNode + layers.toys + layers.front
    }

    /// The row leaves: the pick has gone into its box, and the others crouch and bound off the table, each out by its nearer side of the pick, the plates sinking after them. The pick's
    /// plate holds its ring until its toy is in. Their room stays theirs.
    private func toysLeave(tiles: [Tile], picked: Int?, layout: ArenaLayout) {
        let toy = layout.slotToy, restX = (layout.columnW - toy) / 2
        for i in tiles.indices {
            let id = "tile.\(i)"
            if i == picked {
                track(id + ".toy", [(0, ["opacity": 0])])
                track(id + ".plate", [(ToyTime.shut - 60, ["opacity": 1, "y": toy * ToyArt.toyFloor + 4]), (ToyTime.shut + 70, ["opacity": 0, "y": toy * ToyArt.toyFloor + 16])])
                continue
            }
            // Out the side away from the pick: with none, out the nearer side.
            let goesRight = picked.map { i > $0 } ?? (i >= tiles.count / 2 + (tiles.count % 2))
            let columnX = Double(i) * layout.columnW
            let endX = goesRight ? Self.inner + 44 - columnX : -columnX - toy - 44
            let start = 40 + (goesRight ? Double(tiles.count - 1 - i) : Double(i)) * 80, end = start + 340
            track(id + ".toy", [(start, ["x": restX, "y": 0])] + curve(start + 50, end, steps: 8) { p in
                ["x": self.r1(restX + (endX - restX) * p), "y": self.r1(-toy * 0.34 * 4 * p * (1 - p) + toy * 0.1 * p), "opacity": p < 1 ? 1 : 0]
            })
            track(id + ".toy", [(start, ["sx": 1, "sy": 1]), (start + 50, ["sx": 1.12, "sy": 0.84]), (start + 100, ["sx": 0.96, "sy": 1.06]), (end, ["sx": 1, "sy": 1])])
            track(id + ".toy", [(start + 50, ["rotate": 0]), (end, ["rotate": goesRight ? 160 : -160])])
            track(id + ".plate", [(start, ["opacity": 1, "y": toy * ToyArt.toyFloor + 4]), (start + 170, ["opacity": 0, "y": toy * ToyArt.toyFloor + 16])])
        }
    }

    /// The row comes back for a new round: the boxes go back, your toy hops home from where it ended, the companion's goes off the table, the other two bound in from where they left,
    /// the plates rise under them, and only then the companion's box shuts and a new seal stamps on, as its figure nods. Nothing can be pressed until it's done.
    private func roundMoments(layout: ArenaLayout, tiles: [Tile], duo: Bool, nodes: inout [Node]) {
        guard ctx.fresh, let before = ctx.previous, before.revealPart != nil || before.hasCover else { return }
        let total = 760.0, toy = layout.slotToy, restX = (layout.columnW - toy) / 2
        var home: Int?
        if case .hands(let you, let companion)? = before.revealPart, before.resultPart == nil {
            let stage = arenaStage(layout, duo: duo)
            let ends = toyEnds(you: you, companion: companion, stage: stage)
            // The plates under the boxes go first: what they said is over.
            nodes.append(resultPlate("you", word: stage.plates!.you, stage: stage, verdict: nil, hand: you, playing: false))
            nodes.append(resultPlate("them", word: stage.plates!.them, stage: stage, verdict: nil, hand: companion, playing: false))
            for side in ["you", "them"] { track("result.\(side)", [(0, ["opacity": 1]), (130, ["opacity": 0])], total: total) }
            // The springs go down into their boxes first: under the fronts.
            for side in ["you", "them"] {
                let id = "spring.home.\(side)", w = stage.box * ToyArt.springWide, rest = ends[side]?.spring ?? 1
                nodes.insert(Node.art(ToyArt.spring, x: stage.x(side) - w / 2, y: stage.mouthY - stage.rise, w: w, h: stage.rise).id(id).anchor(0.5, 1).opacity(0), at: nodes.count - 2)
                track(id, [(0, ["sy": rest]), (110, ["sy": 0.05])], total: total)
                track(id, [(0, ["opacity": 1]), (110, ["opacity": 1]), (111, ["opacity": 0])], total: total)
            }
            let steps = curve(40, 300, steps: 6) { p in ["y": self.r1(layout.forwardY + (layout.backY - layout.forwardY) * p * p * (3 - 2 * p))] }
            for side in ["you", "them"] {
                track("box.\(side)", steps, total: total)
                track("boxtop.\(side)", steps, total: total)
                if let rest = ends[side] {
                    let hand = side == "you" ? you : companion
                    let id = "toy.back.\(side)"
                    if side == "you", let i = tiles.firstIndex(where: { $0.art == hand }) {
                        home = i
                        // Home: a toy that was flattened or wrapped is itself again the moment it leaves.
                        let toX = Double(i) * layout.columnW + restX, toY = layout.slotY
                        nodes.append(Node.art(ToyArt.toy(hand), w: stage.toy, h: stage.toy).id(id).at(toX, toY).opacity(0).z(6).anchor(0.5, ToyArt.toyFloor))
                        track(id, curve(0, 340, steps: 10) { p in ["x": self.r1(rest.x + (toX - rest.x) * p), "y": self.r1(rest.y + (toY - rest.y) * p - toy * 0.3 * 4 * p * (1 - p))] }, total: total)
                        track(id, [(0, ["opacity": 1]), (339, ["opacity": 1]), (340, ["opacity": 0])], total: total)
                        track("tile.\(i).toy", [(339, ["opacity": 0]), (340, ["opacity": 1])], total: total)
                        track("tile.\(i).toy", [(340, ["sx": 1.1, "sy": 0.88]), (440, ["sx": 1, "sy": 1])], total: total)
                    } else {
                        // Off the table, the way the others left: its box will have another.
                        let toX = Self.inner + 40
                        nodes.append(Node.art(ToyArt.toy(hand), w: stage.toy, h: stage.toy).id(id).at(toX, rest.y).opacity(0).z(6))
                        track(id, curve(0, 300, steps: 8) { p in ["x": self.r1(rest.x + (toX - rest.x) * p), "y": self.r1(rest.y - toy * 0.3 * 4 * p * (1 - p) + toy * 0.2 * p), "opacity": p < 1 ? 1 : 0] }, total: total)
                    }
                }
            }
        }
        for i in tiles.indices where i != home {
            // In from the side it left by, landing with a little give.
            let goesRight = i >= tiles.count / 2 + (tiles.count % 2) || (home.map { i > $0 } ?? false)
            let columnX = Double(i) * layout.columnW
            let fromX = goesRight ? Self.inner + 44 - columnX : -columnX - toy - 44
            let start = 120 + Double(i) * 60, end = start + 300
            let id = "tile.\(i).toy"
            track(id, [(start, ["opacity": 0]), (start + 1, ["opacity": 1])], total: total)
            track(id, curve(start, end, steps: 8) { p in ["x": self.r1(fromX + (restX - fromX) * p), "y": self.r1(-toy * 0.3 * 4 * p * (1 - p))] }, total: total)
            track(id, [(end, ["sx": 1.1, "sy": 0.88]), (end + 110, ["sx": 1, "sy": 1])], total: total)
        }
        for i in tiles.indices {
            let id = "tile.\(i).plate", at = 200 + Double(i) * 50, y = toy * ToyArt.toyFloor + 4
            track(id, [(at, ["opacity": 0, "y": y + 14]), (at + 90, ["opacity": 1, "y": y - 3]), (at + 170, ["opacity": 1, "y": y])], total: total)
        }
        // Only with everything home: its box shuts, and it has picked. A bluff: then the sealed box gives a small wiggle, which says nothing.
        if before.revealPart != nil {
            track("box.them.lidopen", [(500, ["sy": 1, "opacity": 1]), (549, ["sy": 0.1, "opacity": 1]), (550, ["sy": 0.1, "opacity": 0])], total: total)
            track("boxtop.them.lidshut", [(549, ["sy": 0.1, "opacity": 0]), (550, ["sy": 0.1, "opacity": 1]), (600, ["sy": 1.06, "opacity": 1]), (640, ["sy": 1, "opacity": 1])], total: total)
            anims.append(.sequence([.wait(ms: 550), .sound("sounds/cork.wav")]))
        }
        if !duo, before.revealPart != nil {
            track("boxtop.them.seal", [(639, ["opacity": 0, "scale": 2]), (640, ["opacity": 1, "scale": 2]), (720, ["opacity": 1, "scale": 0.92]), (760, ["opacity": 1, "scale": 1])], total: total)
            track("companion.figure", [(600, ["y": 0]), (680, ["y": 5]), (760, ["y": 0])], total: total)
            anims.append(.sequence([.wait(ms: 640), .sound("sounds/stamp.wav")]))
            if board.companion?.move == "tease" {
                for id in ["box.them", "boxtop.them"] { track(id, [(800, ["rotate": 0]), (880, ["rotate": -3]), (970, ["rotate": 3]), (1060, ["rotate": -2]), (1140, ["rotate": 0])], total: 1140) }
            }
        }
        // The Mac has passed over: the second player's box opens for them.
        if duo, before.hasCover, board.sealedFirst {
            track("box.them.lidopen", [(300, ["sy": 0.1, "opacity": 0]), (301, ["sy": 0.1, "opacity": 1]), (380, ["sy": 1.12, "opacity": 1]), (470, ["sy": 1, "opacity": 1])], total: total)
            track("boxtop.them.lidshut", [(299, ["sy": 1, "opacity": 1]), (300, ["sy": 0.1, "opacity": 1]), (301, ["sy": 0.1, "opacity": 0])], total: total)
        }
        // Its own plain moment, for the moves it holds.
        anims.append(Anim.to("arena", ["opacity": 1], ms: total).blocksInput())
    }

    /// One toy on its plate, the two pressed as one. Once a pick is made it is gone from here, and the plate with it: its room is kept, and nothing stays behind faded.
    private func toySlot(_ tile: Tile, index i: Int, locked: Bool, away: Bool, x: Double, y: Double, w: Double, toy: Double, plateH: Double) -> Node {
        let id = "tile.\(i)"
        let pending = ctx.pendingAnswer == i
        let open = !locked && tile.state != .faded
        let plateW = w - 10, plateY = toy * ToyArt.toyFloor + 4
        return Node.box(id, x: x, y: y, w: w, h: plateY + plateH) {
            Node.art(ToyArt.toy(tile.art ?? "rock"), x: (w - toy) / 2, w: toy, h: toy).id(id + ".toy").anchor(0.5, ToyArt.toyFloor).opacity(away ? 0 : 1)
            Node.box(id + ".plate", x: 5, y: plateY, w: plateW, h: plateH) {
                Node.capsule(fill: Paint.card, stroke: pending ? Paint.action : Paint.edge, lineWidth: pending ? 2.5 : 1).id(id + ".back").size(plateW, plateH).shadow(Paint.clear("#3A2A55", 0.2), radius: 2, dx: 0, dy: 2)
                Node.words(Format.integer(i + 1), size: 20, weight: "black", align: "center", x: 6, w: 24, h: plateH)
                Node.words(tile.label, size: 14.5, weight: "heavy", align: "center", minScale: 0.55, x: 30, w: plateW - 36, h: plateH).id(id + ".words")
            }.opacity(away ? 0 : 1)
        }.area("answer", value: "\(i)", label: "\(Format.integer(i + 1)), \(tile.label)", disabled: !open, hover: AreaLook(scale: 1.03, dy: -2), press: AreaLook(scale: 0.97, dy: 1), sound: "sounds/tap.wav")
    }
}

/// The pack's toys: their names and how they line up. Toys share one frame with one floor line, boxes another, so any of them swap in place.
enum ToyArt {
    static let toyFrame = 120.0, boxFrame = 160.0
    /// As parts of a frame: a toy's floor; the open lid's top, the box's floor and the floor inside it; the lid's pivot; the seal's middle and size; a spring's width.
    static let toyFloor = 0.95, lidTop = 0.21, boxFloor = 0.969, mouth = 0.714, pivotX = 0.428, pivotY = 0.536, sealX = 0.572, sealY = 0.752, sealSide = 0.1875, springWide = 0.1875
    static func toy(_ hand: String) -> String { "art/toy-\(hand).webp" }
    static func box(_ side: String, _ part: String) -> String { "art/toy-box-\(side == "you" ? "blue" : "yellow")-\(part).webp" }
    static let seal = "art/toy-seal.webp", spring = "art/toy-spring.webp", dust = "art/toy-dust.webp", scrap = "art/toy-scrap.webp"
}
