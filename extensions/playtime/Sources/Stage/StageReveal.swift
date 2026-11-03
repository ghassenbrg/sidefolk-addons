import Foundation
import SidefolkExtensionKit

// A result drawn as it happens (RevealView), fixed before it plays. It plays during the build-up; the verdict's board shows where it landed and never plays it twice.
// With Reduce Motion a step isn't played and its end shows at once. Only the hands are played on a board; coins and dice are the desktop's (Sources/Toss).
extension BoardDrawing {
    /// When the hands open and when the winner acts on the loser, as parts of the whole reveal; and how large it is drawn in the room it has.
    struct RevealBeat {
        var ms = Double(Suspense.revealMs)
        var opens = 0.45
        var acts = 0.62
        /// A hand's box, how far the two start from the middle and where they meet, the middle's height, and the height of the count and the names.
        var box = 76.0
        var home = 92.0
        var meet = 36.0
        var middleY = 54.0
        var wordsY = 0.0
        var labelY = 106.0
        /// Two people's names, for the two hands: then nobody's win is the person's or their loss, so the glow and the crown are neutral.
        var names: [String]?
    }

    func revealCard(_ reveal: Reveal) -> PartBlock {
        let width = Self.inner, height = 118.0
        // It comes in with the board easing round it, as the panel's did.
        if ctx.buildUp { anims.append(.keys("reveal", [["t": 0, "opacity": 0], ["t": 1, "opacity": 1]], ms: 300)) }
        return PartBlock(.box("reveal", w: width, h: height) {
            Node.gameCard(corner: 18, alpha: 0.92, w: width, h: height).id("reveal.card")
            if case .hands(let you, let companion) = reveal {
                hands(you: you, companion: companion, width: width, playing: ctx.buildUp, prefix: "reveal", beat: RevealBeat())
            }
        }, height: height)
    }

    // MARK: Rock, Paper, Scissors on its arena

    /// The arena (concept 13): three large felt hands standing on felt, each with its number and name on a plate, and a sealed sign for the hand the companion already holds. On a
    /// throw the three fade, the plates stay where they are with the marks, and the two thrown hands play out over them.
    func handsTable() -> Node {
        let width = Self.inner, room = playRoom
        let a = board.answersPart
        let tiles = a?.tiles ?? Games.Hand.allCases.map { Tile(RockPaperScissorsScreen.title($0), art: $0.rawValue) }
        let locked = a?.locked ?? true
        answerKeys(tiles, locked: locked)
        let dockH = 46.0, dockY = room - dockH
        let arenaY = 8.0, arenaH = dockY - 8 - arenaY
        let plateH = 38.0, plateY = arenaY + arenaH - plateH - 14
        let handY = arenaY + 20, handH = plateY - 4 - handY
        let columnW = (width - 16) / 3
        let throwing = board.revealPart
        var nodes: [Node] = [Node.felt("arena", x: -6, y: arenaY, w: width + 12, h: arenaH, corner: 30)]
        for (i, tile) in tiles.enumerated() {
            nodes.append(standingHand(tile, index: i, cap: Self.keyCaps(tiles)[i], locked: locked, thrown: throwing != nil, dim: a == nil, x: 8 + Double(i) * columnW, y: handY, w: columnW, h: plateY + plateH - handY, handH: handH))
        }
        if case .hands(let you, let companion) = throwing {
            let box = Swift.min(handH - 20, 146), middle = handY + (handH + 8) / 2
            let beat = RevealBeat(box: box, home: width * 0.3, meet: box * 0.56, middleY: middle, wordsY: arenaY + 8, labelY: plateY - 16, names: board.scorePart?.players)
            if ctx.buildUp { anims.append(.keys("reveal", [["t": 0, "opacity": 0], ["t": 1, "opacity": 1]], ms: 260)) }
            nodes.append(.box("reveal", w: width, h: room) {
                hands(you: you, companion: companion, width: width, playing: ctx.buildUp, prefix: "reveal", beat: beat)
            })
        }
        // The companion's hand is drawn before you pick, and stays sealed until both show.
        if board.scorePart?.picked == true {
            nodes.append(sealedSign(x: width - 92, y: arenaY - 30))
            // It goes the moment the hands open: there is nothing left to seal.
            if ctx.buildUp {
                let at = RevealBeat().opens
                anims.append(.keys("sealed.sign", [["t": 0, "opacity": 1], ["t": at, "opacity": 1], ["t": at + 0.08, "opacity": 0], ["t": 1, "opacity": 0]], ms: RevealBeat().ms))
            }
        }
        let buttons = tableButtons
        if !buttons.isEmpty { nodes.append(buttonRow(buttons, id: "dock", width: width).node.at(0, dockY)) }
        return .box("arena.table", w: width, h: room) { nodes }
    }

    /// A folded card with a question mark, standing on the arena's back edge.
    private func sealedSign(x: Double, y: Double) -> Node {
        let w = 62.0, h = 50.0
        let words = L("{name} has picked", ["name": "{companion}"])
        if ctx.fresh, ctx.previous?.scorePart?.picked != true {
            anims.append(Anim.keys("sealed.sign", [["t": 0, "y": y - 10, "opacity": 0], ["t": 1, "y": y, "opacity": 1]], ms: 260, ease: "spring").delay(ms: 200))
        }
        return Node.box("sealed.sign", x: x, y: y, w: w, h: h) {
            Node.path("M \(w - 12) 3 L \(w - 1) \(h - 2) L \(w - 16) \(h - 2) Z", fill: Paint.clear("#C9B99F", 1)).size(w, h)
            Node.rect(fill: Paint.cream, stroke: Paint.clear("#C9B99F", 1), lineWidth: 1, corner: 4).id("sealed.face").at(1, 2).size(w - 13, h - 4).shadow(Paint.clear("#3A2A55", 0.24), radius: 3, dx: 0, dy: 2)
            Node.words("?", size: 26, weight: "black", color: Paint.lilacDeepFixed, align: "center", x: 1, y: 2, w: w - 13, h: h - 4)
        }.rotate(-5).label(words)
    }

    /// One column: the hand on its peg, standing on the plate, the two pressed as one. After a throw the hand has faded and the plate says how it went.
    private func standingHand(_ tile: Tile, index i: Int, cap: String, locked: Bool, thrown: Bool, dim: Bool, x: Double, y: Double, w: Double, h: Double, handH: Double) -> Node {
        let id = "tile.\(i)"
        let pending = ctx.pendingAnswer == i
        let verdict = pending ? nil : Verdict(tile: tile.state, locked: locked)
        let open = !locked && tile.state != .faded
        let plateH = h - handH - 4, plateW = w - 6
        let ink = verdict == .win ? Paint.white : Paint.ink
        // As tall as the others: the open palm is wider than its column, and may be.
        let handW = Swift.max(w - 8, handH * 337 / 480)
        var hand = Node.art("art/hand-\(tile.art ?? "rock").png", x: (w - handW) / 2, w: handW, h: handH).id(id + ".hand")
        if thrown { hand = hand.opacity(0) } else if dim { hand = hand.opacity(0.35) }
        var plate = Node.box(id + ".plate", x: 3, y: h - plateH, w: plateW, h: plateH) {
            Node.capsule(fill: verdict.map(\.tileFill) ?? Paint.card, stroke: pending || tile.state == .picked ? Paint.action : Paint.edge, lineWidth: pending || tile.state == .picked ? 2.5 : 1).id(id + ".back").size(plateW, plateH).shadow(Paint.clear("#3A2A55", 0.2), radius: 2, dx: 0, dy: 2)
            if let verdict, verdict != .draw {
                Node.symbol(verdict == .win ? "checkmark" : "xmark", color: ink).symbolLook(weight: "heavy").at(9, (plateH - 16) / 2).size(16, 16)
            } else {
                Node.words(Format.integer(i + 1), size: 20, weight: "black", color: ink, align: "center", x: 6, w: 22, h: plateH)
            }
            Node.words(tile.label, size: 14, weight: "heavy", color: ink, align: "center", minScale: 0.6, x: 28, w: plateW - 34 - (tile.companion ? 24 : 0), h: plateH).id(id + ".words")
            if tile.companion { Node.faceDisc(id: id + ".face", x: plateW - 28, y: (plateH - 24) / 2, side: 24, ring: 1.5) }
        }
        if tile.state == .faded || dim { plate = plate.opacity(0.4) }
        if ctx.fresh, tile.companion, ctx.previous?.answersPart?.tiles[safe: i]?.companion != true {
            anims.append(.keys(id + ".face", [["t": 0, "scale": 0.2, "opacity": 0], ["t": 1, "scale": 1, "opacity": 1]], ms: 280, ease: "spring"))
        }
        var words = "\(Format.integer(i + 1)), \(tile.label)"
        switch tile.state {
        case .right: words += ", " + L("right")
        case .wrong: words += ", " + L("wrong")
        case .picked: words += ", " + L("your pick")
        default: break
        }
        if tile.companion { words += ", " + L("{name}'s pick", ["name": "{companion}"]) }
        return Node.box(id, x: x, y: y, w: w, h: h) {
            hand
            plate
        }.area("answer", value: "\(i)", label: words, disabled: !open, hover: AreaLook(scale: 1.03, dy: -2), press: AreaLook(scale: 0.97, dy: 1), sound: "sounds/tap.wav")
    }

    /// Both hands pump sealed three times ("Rock… paper… scissors…"), fly to the middle and open on "shoot!", each on its own throw, turned to face each other, then the winner acts on
    /// the loser: rock cracks scissors (the blades drop), paper covers rock (the rock sinks under it), scissors snip paper in two, and a draw bonks both back. The winner's glow and
    /// crown take the verdict's colour, when the reveal has ended, never during it.
    func hands(you: String, companion: String, width: Double, playing: Bool, prefix: String, beat: RevealBeat) -> [Node] {
        let mid = width / 2, home = min(width * 0.3, beat.home), k = beat.box / 58
        let verdict = handsVerdict(you, companion)
        let samples = 36
        func act(_ p: Double) -> Double { min(max((p - beat.acts) / (1 - beat.acts), 0), 1) }

        /// They meet in the middle, then spring back a little: further for a draw, which bonks both.
        func gap(_ p: Double) -> Double {
            let fly = min(max((p - beat.opens) / (beat.acts - beat.opens), 0), 1)
            return home - fly * (home - beat.meet) + sin(act(p) * .pi / 2) * (verdict == .draw ? 26 : 12) * min(k, 1.5)
        }

        func side(_ name: String, hand: String, sign: Double, won: Bool, lost: Bool, mirrored: Bool) -> Node {
            let id = "\(prefix).\(name)", box = beat.box
            let restX = mid + sign * gap(1) - box / 2, y = beat.middleY - box / 2
            if playing {
                let flying = (0...samples).map { n -> [String: Double] in
                    let p = Double(n) / Double(samples)
                    let pump = min(p / beat.opens, 1)
                    return ["t": p, "x": mid + sign * gap(p) - box / 2, "y": y - (p < beat.opens ? abs(sin(pump * 3 * .pi)) * 14 * min(k, 1.6) : 0)]
                }
                anims.append(.keys(id, flying, ms: beat.ms))
                anims.append(.keys(id + ".sealed", [["t": 0, "opacity": 1], ["t": beat.opens - 0.001, "opacity": 1], ["t": beat.opens, "opacity": 0], ["t": 1, "opacity": 0]], ms: beat.ms))
                anims.append(.keys(id + ".throw", [["t": 0, "opacity": 0], ["t": beat.opens - 0.001, "opacity": 0], ["t": beat.opens, "opacity": 1], ["t": 1, "opacity": 1]], ms: beat.ms))
                if won {
                    anims.append(.keys(id + ".throw", [["t": 0, "scale": 1], ["t": beat.acts, "scale": 1], ["t": 1, "scale": 1.12]], ms: beat.ms))
                }
                if lost { defeat(hand, id: id, beat: beat) }
            }
            let thrown = defeated(hand, id: id, lost: lost, mirrored: mirrored, box: box)
            let tokenSide = box * 0.72
            return Node.box(id, x: restX, y: y, w: box, h: box) {
                if won, !playing {
                    // The person's win in success green; the companion's win is the person's loss, in the calm tone.
                    Node.ellipse(fill: (beat.names != nil ? Color.inkMuted : sign < 0 ? Color.win : Color.loss).tuned(alpha: 0.2)).at(-box * 0.16, -box * 0.16).size(box * 1.32, box * 1.32)
                }
                Node.box(id + ".throw", w: box, h: box) { thrown }.scale(won ? 1.12 : 1)
                if playing {
                    // A hand not shown yet: a closed token with a "?", neither rock, paper nor scissors.
                    Node.box(id + ".sealed", x: (box - tokenSide) / 2, y: (box - tokenSide) / 2, w: tokenSide, h: tokenSide) {
                        Node.rect(fill: Paint.cream, stroke: Paint.clear("#C9B99F", 1), lineWidth: 1, corner: tokenSide * 0.22).size(tokenSide, tokenSide).shadow(Paint.clear("#000000", 0.18), radius: 3, dx: 0, dy: 2)
                        Node.words("?", size: tokenSide * 0.56, weight: "black", color: Paint.lilacDeepFixed, align: "center", w: tokenSide, h: tokenSide)
                    }.opacity(0)
                }
            }
        }

        func label(_ words: String, sign: Double, crown: Color?) -> Node {
            let room = 110.0, text = min(TextFit.width(words, size: 12.5, weight: "bold"), room - (crown == nil ? 16 : 31))
            let w = text + 16 + (crown == nil ? 0 : 15), h = 20.0
            return .box(x: mid + sign * home - w / 2, y: beat.labelY - h / 2, w: w, h: h) {
                Node.capsule(fill: Paint.card(0.94)).size(w, h)
                if let crown { Node.symbol("crown.fill", color: crown).symbolLook().at(8, 4).size(12, 12) }
                Node.words(words, size: 12.5, weight: "bold", color: crown == nil ? Paint.inkSoft : Paint.ink, align: "center", x: crown == nil ? 8 : 23, w: text, h: h)
            }
        }

        var words: [Node] = []
        var burst: [Node] = []
        if playing {
            // The count, a beat a word, then "Shoot!" fading as the outcome plays. A step: nothing here eases. On the arena, each on a capsule of its own, so it reads over the felt.
            let wordSize = k > 1.5 ? 20.0 : 16.0, wordH = k > 1.5 ? 28.0 : 20.0, wordW = min(width, 150)
            func said(_ word: String, id: String, color: Color) -> Node {
                Node.box(id, x: (width - wordW) / 2, y: beat.wordsY, w: wordW, h: wordH) {
                    if k > 1.5 { Node.capsule(fill: Paint.card(0.94)).size(wordW, wordH) }
                    Node.words(word, size: wordSize, weight: "heavy", color: color, align: "center", minScale: 0.6, w: wordW, h: wordH)
                }.opacity(0)
            }
            for (i, word) in [L("Rock…"), L("Paper…"), L("Scissors…")].enumerated() {
                let id = "\(prefix).count.\(i)", from = beat.opens * Double(i) / 3, to = beat.opens * Double(i + 1) / 3
                var keys: [[String: Double]] = [["t": 0, "opacity": i == 0 ? 1 : 0]]
                if i > 0 { keys += [["t": from - 0.001, "opacity": 0], ["t": from, "opacity": 1]] }
                keys += [["t": to - 0.001, "opacity": 1], ["t": to, "opacity": 0], ["t": 1, "opacity": 0]]
                anims.append(.keys(id, keys, ms: beat.ms))
                words.append(said(word, id: id, color: Paint.inkSoft))
            }
            let shoot = "\(prefix).shoot"
            let done = beat.acts + (1 - beat.acts) * 0.9
            anims.append(.keys(shoot, [["t": 0, "opacity": 0], ["t": beat.opens - 0.001, "opacity": 0], ["t": beat.opens, "opacity": 1], ["t": beat.acts, "opacity": 1], ["t": done, "opacity": 0.1], ["t": done + 0.001, "opacity": 0], ["t": 1, "opacity": 0]], ms: beat.ms))
            words.append(said(L("Shoot!"), id: shoot, color: Paint.ink))
            // The clash itself: a burst, or an equals sign for a draw.
            let mark = "\(prefix).burst", side = (verdict == .draw ? 22.0 : 30.0) * min(k, 1.7), fade = beat.acts + (1 - beat.acts) * 0.7
            anims.append(.keys(mark, [["t": 0, "opacity": 0, "scale": 0.6], ["t": beat.acts, "opacity": 0, "scale": 0.6], ["t": beat.acts + 0.001, "opacity": 1, "scale": 0.6], ["t": fade, "opacity": 0, "scale": 1.3], ["t": 1, "opacity": 0, "scale": 1.3]], ms: beat.ms))
            burst.append(Node.symbol(verdict == .draw ? "equal" : "burst.fill", color: Paint.inkSoft.tuned(alpha: 0.8)).symbolLook(weight: "bold").id(mark).at(mid - side / 2, beat.middleY - side / 2).size(side, side).opacity(0))
        }
        return words + [
            side("you", hand: you, sign: -1, won: verdict == .win, lost: verdict == .loss, mirrored: false),
            side("them", hand: companion, sign: 1, won: verdict == .loss, lost: verdict == .win, mirrored: true),
        ] + burst + [
            label(beat.names?[0] ?? L("You"), sign: -1, crown: verdict == .win && !playing ? (beat.names == nil ? .win : Paint.ink) : nil),
            label(beat.names?[1] ?? "{companion}", sign: 1, crown: verdict == .loss && !playing ? (beat.names == nil ? .loss : Paint.ink) : nil),
        ]
    }

    /// A thrown hand's picture, where it ends: the hand that lost stays its own shape and takes the winner's effect. Scissors bend and drop, paper is cut in two, rock sinks and
    /// fades under the paper that covered it. The pictures stand upright on their pegs, so a thrown hand is laid over to point at the other, the right one mirrored first.
    private func defeated(_ hand: String, id: String, lost: Bool, mirrored: Bool, box: Double) -> Node {
        let k = box / 58
        // Turned to face the other way first, so what happens to it happens the same way on both sides.
        func picture(x: Double = 0) -> Node {
            Node.box(x: x, w: box, h: box) {
                Node.box(w: box, h: box) {
                    Node.box(w: box, h: box) { Node.art("art/hand-\(hand).png", w: box, h: box) }.scale(x: mirrored ? -1 : 1, y: 1)
                }.rotate(mirrored ? -82 : 82)
            }
        }
        guard lost else { return Node.box(id + ".defeat", w: box, h: box) { picture() } }
        switch hand {
        case "paper":
            return .box(id + ".defeat", w: box, h: box) {
                Node.box(id + ".half.a", x: -9 * k, y: 6 * k, w: box / 2, h: box) { picture() }.clip().anchor(1, 0.5).rotate(-14)
                Node.box(id + ".half.b", x: box / 2 + 9 * k, y: 6 * k, w: box / 2, h: box) { picture(x: -box / 2) }.clip().anchor(0, 0.5).rotate(14)
            }.opacity(0.6)
        case "scissors":
            return Node.box(id + ".defeat", y: 24 * k, w: box, h: box) { picture() }.rotate(70).opacity(0.5)
        default:
            return Node.box(id + ".defeat", y: 10 * k, w: box, h: box) { picture() }.scale(0.8).opacity(0.5)
        }
    }

    private func defeat(_ hand: String, id: String, beat: RevealBeat) {
        let k = beat.box / 58
        func run(_ target: String, _ start: [String: Double], _ end: [String: Double]) {
            anims.append(.keys(target, [start.merging(["t": 0]) { a, _ in a }, start.merging(["t": beat.acts]) { a, _ in a }, end.merging(["t": 1]) { a, _ in a }], ms: beat.ms))
        }
        switch hand {
        case "paper":
            run(id + ".defeat", ["opacity": 1], ["opacity": 0.6])
            run(id + ".half.a", ["rotate": 0, "x": 0, "y": 0], ["rotate": -14, "x": -9 * k, "y": 6 * k])
            run(id + ".half.b", ["rotate": 0, "x": beat.box / 2, "y": 0], ["rotate": 14, "x": beat.box / 2 + 9 * k, "y": 6 * k])
        case "scissors": run(id + ".defeat", ["rotate": 0, "y": 0, "opacity": 1], ["rotate": 70, "y": 24 * k, "opacity": 0.5])
        default: run(id + ".defeat", ["scale": 1, "y": 0, "opacity": 1], ["scale": 0.8, "y": 10 * k, "opacity": 0.5])
        }
    }

    func handsVerdict(_ you: String, _ companion: String) -> Verdict {
        if you == companion { return .draw }
        let beats = ["rock": "scissors", "paper": "rock", "scissors": "paper"]
        return beats[you] == companion ? .win : .loss
    }
}
