import Foundation
import SidefolkExtensionKit

/// What the companion drew, in the air above it (TossStage): a coin with the companion's own face flicked high and wobbling to a stop, dice thrown onto a tray, or two hands
/// that clash. Fixed before it plays; the objects are the heroes, and the result is a chip under them. The words stay in this frame: the companion says nothing on the desktop
/// (D98). One scene while it flies, asked for again when it has landed; with Reduce Motion nothing spins and the result shows at once.
@MainActor
enum TossSurface {
    /// When the objects leave the companion's paws (for hands, when the fists start pumping), how long they fly, and how long a coin wobbles or dice slide after.
    struct Timing {
        var launch: Double
        var flight: Double
        let settle = 600.0

        init(_ toss: Toss) {
            switch toss {
            case .coins: (launch, flight) = (320, 1200)
            case .dice: (launch, flight) = (960, 900)
            case .hands: (launch, flight) = (0, 1120)
            }
        }

        var totalMs: Int { Int(launch + flight + settle) }
    }

    /// What is on the overlay now: enough to draw it again and to throw again.
    private static var shown: [String: Toss] = [:]
    /// Calls the person got right in a row, for the streak's sparkles.
    private static var calledRight = 0
    static let pad = 10.0

    static func install(on ext: Extension) {
        ext.surface("toss", open: { request in
            var random = Games.Random.fresh()
            // Opened with nothing said (the AI's own road, `surfaces.open`): a real coin, as a person asking for one would get.
            let toss = Toss(arguments: request.arguments) ?? Toss.coins([random.below(2) == 1])
            let session = UUID().uuidString
            shown[session] = toss
            return SurfaceReply(session: session, scene: flying(toss))
        }, move: { request in
            guard let toss = shown[request.session] else { return Scene(width: 200, height: 120).closing() }
            switch request.move {
            case .next: return landed(toss)
            case .click(area: "again", _, _):
                let next = again(toss)
                shown[request.session] = next
                return flying(next)
            default: return landed(toss)
            }
        }, close: { request in
            shown[request.session] = nil
        })
    }

    /// The same coin or dice once more: a fresh draw, and its row in History, as a tool call has.
    private static func again(_ toss: Toss) -> Toss {
        var random = Games.Random.fresh()
        switch toss {
        case .coins(let flips, _):
            Activity.add(flips.count == 1 ? L("Flip a coin") : L("Flip {n} coins", ["n": flips.count]), key: "toss")
            return .coins(flips.map { _ in random.below(2) == 1 })
        case .dice(let sides, let rolls, let modifier):
            Activity.add(title(toss), key: "toss")
            return .dice(sides: sides, rolls: rolls.map { _ in random.between(1, sides) }, modifier: modifier)
        case .hands: return toss
        }
    }

    static func title(_ toss: Toss) -> String {
        switch toss {
        case .coins(let flips, _): flips.count > 1 ? L("Flip {n} coins", ["n": flips.count]) : L("Flip a coin")
        case .dice(let sides, let rolls, let modifier):
            rolls.count == 1 && sides == 6 && modifier == 0 ? L("Roll a die") : L("Roll {dice}", ["dice": Toss.notation(count: rolls.count, sides: sides, modifier: modifier)])
        case .hands: L("Rock, paper, scissors")
        }
    }

    // MARK: Flying

    static func flying(_ toss: Toss) -> Scene {
        let time = Timing(toss)
        let waiting = switch toss {
        case .coins: L("Heads or tails…")
        case .dice: L("Rolling…")
        case .hands: L("Rock… paper… scissors…")
        }
        let (move, sound): (String, String) = switch toss {
        case .coins: ("flick", "flip")
        case .dice: ("roll", "rattle")
        case .hands: ("pump", "whoosh")
        }
        let whisper = TossParts.whisper(waiting)
        let objects = TossParts.objects(toss, time: time, playing: true)
        let width = max(max(objects.width, whisper.width), 170) + 2 * pad
        let height = pad + whisper.height + 6 + objects.height + pad
        var anims = objects.anims
        anims.append(.sequence([.react(Reaction(move: move)), .sound("sounds/\(sound).wav")]))
        return Scene(width: width, height: height) {
            whisper.node.at((width - whisper.width) / 2, pad)
            objects.node.at((width - objects.width) / 2, pad + whisper.height + 6)
        }
        .animating(anims)
        .after(ms: time.totalMs)
        .afterStill(ms: 200)
    }

    // MARK: Landed

    static func landed(_ toss: Toss) -> Scene {
        let (move, effect, line) = reaction(toss)
        let whisper = line.map { TossParts.whisper($0) }
        let objects = TossParts.objects(toss, time: Timing(toss), playing: false)
        let chip = TossParts.chip(toss)
        let pill = TossParts.againPill(toss)
        let rows = [whisper?.width, objects.width, chip.width, pill?.width].compactMap { $0 }
        let width = max(rows.max() ?? 170, 170) + 2 * pad
        var y = pad
        var nodes: [Node] = []
        func add(_ node: Node, _ w: Double, _ h: Double) {
            nodes.append(node.at((width - w) / 2, y))
            y += h + 6
        }
        if let whisper { add(whisper.node, whisper.width, whisper.height) }
        add(objects.node, objects.width, objects.height)
        add(chip.node, chip.width, chip.height)
        if let pill { add(pill.node, pill.width, pill.height) }
        let height = y - 6 + pad
        var scene = Scene(width: width, height: height) { nodes }
            .announcing([toss.result, line].compactMap { $0 }.joined(separator: " "))
            .animating([.from("toss.chip", [["t": 0, "scale": 0.85, "opacity": 0], ["t": 1, "scale": 1, "opacity": 1]], ms: 220, ease: "spring")])
            .closing(afterMs: 5000)
        if move != nil || effect != nil { scene = scene.react(Reaction(move: move, effect: effect)) }
        return scene
    }

    /// How the companion takes what came up: a call right or wrong, a natural 20 or a 1, doubles, a hand won or lost.
    private static func reaction(_ toss: Toss) -> (move: String?, effect: String?, line: String?) {
        switch toss {
        case .coins:
            guard let right = toss.called else { return ("nod", nil, nil) }
            calledRight = right ? calledRight + 1 : 0
            if right, calledRight >= 3, calledRight % 3 == 0 { return ("cheer", "sparkles", L("{n} in a row!", ["n": calledRight])) }
            return right ? ("cheer", nil, L("You called it!")) : ("giggle", nil, L("Next one's yours."))
        case .dice(let sides, let rolls, _):
            if sides == 20, rolls == [20] { return ("cheer", "sparkles", L("Natural 20!")) }
            if sides == 20, rolls == [1] { return ("gasp", nil, L("Oof.")) }
            if sides == 6, rolls == [1, 1] { return ("giggle", nil, L("Snake eyes!")) }
            if rolls.count == 2, rolls[0] == rolls[1] { return ("cheer", nil, L("Doubles!")) }
            return ("nod", nil, nil)
        case .hands(let person, let mine):
            // A good sport: a bow when the person wins, a cheer when it does, a nod for a draw.
            return (person == mine ? "nod" : person.beats == mine ? "bow" : "cheer", nil, nil)
        }
    }
}

/// The parts of the overlay, each with the room it takes.
@MainActor
enum TossParts {
    struct Part {
        var node: Node
        var width: Double
        var height: Double
        var anims: [Anim] = []
    }

    /// A word beside the objects, in a small card of the overlay's own.
    static func whisper(_ words: String) -> Part {
        let inner = min(TextFit.width(words, size: 14, weight: "medium"), 280)
        let h = TextFit.height(words, size: 14, weight: "medium", width: inner, lines: 2) + 16
        let w = inner + 28
        return Part(node: .box("toss.whisper", w: w, h: h) {
            Node.rect(fill: .surface, stroke: .line, lineWidth: 1, corner: min(h / 2, 20)).size(w, h).shadow(Paint.clear("#000000", 0.14), radius: 4, dx: 0, dy: 2)
            Node.text(words, size: 14, weight: "medium", color: .ink, align: "center", valign: "center", lines: 2).at(14, 8).size(inner, h - 16)
        }, width: w, height: h)
    }

    static func objects(_ toss: Toss, time: TossSurface.Timing, playing: Bool) -> Part {
        switch toss {
        case .coins(let flips, _): coins(flips, time: time, playing: playing)
        case .dice(let sides, let rolls, _): dice(sides, rolls, time: time, playing: playing)
        case .hands(let person, let companion): hands(person, companion, time: time, playing: playing)
        }
    }

    // MARK: Coins

    /// Each lands 120 ms after the one before and turns a different number of times, so several fan out. Touching down: a real coin's wobble, quick then slower, then still.
    private static func coins(_ flips: [Bool], time: TossSurface.Timing, playing: Bool) -> Part {
        let side = 48.0, gap = 14.0, air = 196.0
        let width = Double(flips.count) * side + Double(flips.count - 1) * gap
        let height = playing ? air : 52.0
        let ground = height - side
        var anims: [Anim] = []
        var nodes: [Node] = []
        for (i, heads) in flips.enumerated() {
            let id = "toss.coin.\(i)", x = Double(i) * (side + gap)
            let lag = Double(i) * 120
            let turns = Double(5 + i % 3) * 2 + (heads ? 0 : 1)
            if playing {
                let start = time.launch + lag
                let flight = time.flight
                // The lift: up 150 pt and down, over its whole flight.
                let lift = (0...16).map { n -> [String: Double] in
                    let p = Double(n) / 16
                    return ["t": p, "y": ground - 4 * p * (1 - p) * 150]
                }
                anims.append(.fade(id, 1, ms: 1, ease: "linear").delay(ms: start))
                anims.append(.keys(id, lift, ms: flight).delay(ms: start))
                anims.append(Anim.flip(id + ".face", turns, ms: flight, ease: "out").delay(ms: start))
                let wobble = (0...12).map { n -> [String: Double] in
                    let a = Double(n) / 12
                    return ["t": a, "sy": 1 - 0.28 * exp(-a * 4) * abs(sin(a * 7 * .pi))]
                }
                anims.append(.keys(id, wobble, ms: time.settle).delay(ms: start + flight))
            }
            var coin = Node.box(id, x: x, y: ground, w: side, h: side) {
                Node.flip(front: TossArt.coin(heads: true, side: side), back: TossArt.coin(heads: false, side: side), showing: !playing && !heads ? "back" : "front", axis: "x").id(id + ".face").size(side, side)
            }
            if playing { coin = coin.opacity(0) }
            nodes.append(coin)
        }
        return Part(node: .box("toss.coins", w: width, h: height) { nodes }.leftToRight().label(flips.count == 1 ? L("A coin") : L("{n} coins", ["n": flips.count])), width: width, height: height, anims: anims)
    }

    // MARK: Dice

    /// Two bounces on the felt, then a slide to rest; each die's face changes about every 70 ms, the same on every redraw. A flat tumble: a scene's turn is 2D (D99).
    private static func dice(_ sides: Int, _ rolls: [Int], time: TossSurface.Timing, playing: Bool) -> Part {
        let size = rolls.count > 5 ? 30.0 : 36.0, gap = 12.0
        let rows = stride(from: 0, to: rolls.count, by: 5).map { Array(rolls.indices)[$0..<min($0 + 5, rolls.count)] }
        let trayW = max(200, Double(min(rolls.count, 5)) * (size + 12) + 40)
        let trayH = Double(rows.count) * (size + 8) + 26
        let width = trayW + 130
        let height = playing ? trayH + 84 : trayH + 4
        let trayY = height - trayH
        var anims: [Anim] = []
        var nodes: [Node] = [TossArt.tray(w: trayW, h: trayH).at(65, trayY)]
        if playing { anims.append(.from("toss.tray", [["t": 0, "opacity": 0], ["t": 0.3, "opacity": 0], ["t": 1, "opacity": 1]], ms: time.launch)) }
        // Bottom-up, as the rows are stacked over the tray's lower edge.
        let total = Double(rows.count) * size + Double(rows.count - 1) * 8
        let firstY = height - 13 - total
        for (r, row) in rows.enumerated() {
            let rowW = Double(row.count) * size + Double(row.count - 1) * gap
            var x = (width - rowW) / 2
            for i in row {
                let id = "toss.die.\(i)", y = firstY + Double(r) * (size + 8)
                if playing {
                    let sign = i % 2 == 0 ? -1.0 : 1.0
                    let keys = (0...24).map { n -> [String: Double] in
                        let p = Double(n) / 24
                        let eased = 1 - pow(1 - p, 3), first = p / 0.55, second = (p - 0.55) / 0.25
                        let bounce = p < 0.55 ? 4 * first * (1 - first) * 70 : p < 0.8 ? 4 * second * (1 - second) * 16 : 0
                        return ["t": p, "x": x + (1 - eased) * 60 * sign, "y": y - bounce, "rotate": (1 - eased) * 720 * sign]
                    }
                    anims.append(.fade(id, 1, ms: 1, ease: "linear").delay(ms: time.launch))
                    anims.append(.keys(id, keys, ms: time.flight).delay(ms: time.launch))
                }
                var die = TossParts.die(i, sides: sides, roll: rolls[i], size: size, id: id, time: time, playing: playing, anims: &anims)
                if playing { die = die.opacity(0) }
                nodes.append(die.at(x, y))
                x += size + gap
            }
        }
        // A natural 20 glints gold.
        if !playing, sides == 20, rolls.count == 1, rolls[0] == 20 {
            nodes.append(Node.symbol("sparkle", color: Paint.sun).symbolLook(weight: "bold").at((width + size) / 2 - 7, firstY - 7).size(16, 16))
        }
        return Part(node: .box("toss.dice", w: width, h: height) { nodes }.leftToRight().label(L("{n} dice", ["n": rolls.count])), width: width, height: height, anims: anims)
    }

    /// While it tumbles a d6 swaps its pictures; any other die shows a turn of numbers, none of them the result unless chance says so, the last one what it landed on.
    private static func die(_ i: Int, sides: Int, roll: Int, size: Double, id: String, time: TossSurface.Timing, playing: Bool, anims: inout [Anim]) -> Node {
        let step = 70.0, count = Int(time.flight / step)
        func tumbling(_ frame: Int) -> Int { (frame &* 7919 &+ i &* 104_729) % sides + 1 }
        if sides == 6 {
            let picture = id + ".picture"
            if playing {
                let faces = (0..<count).map { "art/die-\(tumbling($0)).png" } + ["art/die-\(roll).png"]
                anims.append(Anim.frames(picture, faces, stepMs: step).delay(ms: time.launch))
            }
            let k = (44.0 + 8) / 44, full = size * k, margin = (full - size) / 2
            return .box(id, w: size, h: size) {
                Node.image("art/die-\(roll).png").id(picture).at(-margin, -margin).size(full, full)
            }
        }
        var numbers: [Node] = []
        if playing {
            // Five faces in turn, then the one it landed on: a number can't swap as a picture can.
            for n in 0..<5 {
                let number = "\(id).n\(n)"
                let on = stride(from: n, to: count, by: 5).flatMap { frame -> [[String: Double]] in
                    let t = Double(frame) / Double(count), end = min(Double(frame + 1) / Double(count), 1)
                    return [["t": t, "opacity": 1], ["t": end - 0.0001, "opacity": 1], ["t": end, "opacity": 0]]
                }
                anims.append(.from(number, [["t": 0, "opacity": 0]] + on + [["t": 1, "opacity": 0]], ms: time.flight, ease: "linear").delay(ms: time.launch))
                numbers.append(TossArt.dieNumber(tumbling(n), sides: sides, side: size).id(number).opacity(0))
            }
            anims.append(.from("\(id).final", [["t": 0, "opacity": 0], ["t": 0.999, "opacity": 0], ["t": 1, "opacity": 1]], ms: time.launch + time.flight, ease: "linear"))
        }
        return .box(id, w: size, h: size) {
            TossArt.padded("art/poly-\(TossArt.polyhedron(sides)).png", side: size, exported: 44)
            numbers
            TossArt.dieNumber(roll, sides: sides, side: size).id("\(id).final")
        }
    }

    // MARK: Hands

    /// The clash the panel plays (StageReveal), with the desktop's timing: the pumping and flying in take the flight, the outcome the settling after it.
    private static func hands(_ person: Toss.Hand, _ companion: Toss.Hand, time: TossSurface.Timing, playing: Bool) -> Part {
        let drawing = BoardDrawing(Board([]), StageContext(entry: GameEntry(id: "", title: "", tagline: "", symbol: "", look: .hands), fresh: false))
        let width = 260.0, height = 118.0
        let total = time.flight + time.settle
        let beat = BoardDrawing.RevealBeat(ms: total, opens: 0.45 / 0.62 * time.flight / total, acts: time.flight / total)
        let nodes = drawing.hands(you: person.rawValue, companion: companion.rawValue, width: width, playing: playing, prefix: "toss", beat: beat)
        return Part(node: .box("toss.hands", w: width, h: height) { nodes }, width: width, height: height, anims: drawing.anims)
    }

    // MARK: The result

    /// The result under the objects, large: "Heads!", or a dice total with its sum beside it. A hand or a call says how it went by a symbol as well as its colour.
    static func chip(_ toss: Toss) -> Part {
        let verdict = toss.verdict
        let (words, size, weight): (String, Double, String)
        var beside: String?
        switch toss {
        case .dice(_, let rolls, let modifier) where rolls.count > 1 || modifier != 0:
            (words, size, weight) = (Toss.number(rolls.reduce(0, +) + modifier), 26, "heavy")
            beside = toss.parts
        case .hands: (words, size, weight) = (toss.result, 15, "bold")
        default: (words, size, weight) = (toss.result, 22, "heavy")
        }
        let wordsW = min(TextFit.width(words, size: size, weight: weight), 300)
        let besideW = beside.map { TextFit.width($0, size: 11.5, weight: "semibold") } ?? 0
        let symbolW = verdict == nil ? 0 : 22.0 + 8
        let inner = symbolW + wordsW + (beside == nil ? 0 : besideW + 8)
        let h = TextFit.lineHeight(size, weight) + 12, w = inner + 32
        let x = 16 + symbolW
        return Part(node: .box("toss.chip", w: w, h: h) {
            Node.rect(fill: .surface, stroke: verdict.map { $0.color.tuned(alpha: 0.7) } ?? .line, lineWidth: verdict == nil ? 1 : 2, corner: 14).size(w, h)
            if let verdict {
                Node.symbol(verdict.symbol, color: .surface).symbolLook(weight: "bold", secondary: verdict.color).at(16, (h - 20) / 2).size(20, 20)
            }
            Node.words(words, size: size, weight: weight, align: "center", x: x, w: wordsW, h: h).leftToRight()
            if let beside {
                Node.words(beside, size: 11.5, weight: "semibold", color: .inkMuted, design: "default", x: x + wordsW + 8, w: besideW, h: h).leftToRight()
            }
        }, width: w, height: h)
    }

    /// The Again pill under a coin or dice: flip or roll once more.
    static func againPill(_ toss: Toss) -> Part? {
        if case .hands = toss { return nil }
        let words = L("Again"), textW = TextFit.width(words, size: 11.5, weight: "semibold")
        let w = textW + 14 + 6 + 24, h = 26.0
        return Part(node: .box("toss.again", w: w, h: h) {
            Node.capsule(fill: .accent).size(w, h)
            Node.symbol("arrow.clockwise", color: .onAccent).symbolLook(weight: "semibold").at(12, 6).size(14, 14)
            Node.words(words, size: 11.5, weight: "semibold", color: .onAccent, design: "default", x: 32, w: textW, h: h)
        }.area("again", label: words, hover: AreaLook(scale: 1.03), press: AreaLook(scale: 0.97), sound: "sounds/tap.wav"), width: w, height: h)
    }
}
