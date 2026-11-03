import Foundation
import SidefolkExtensionKit

/// The dice: thrown from the companion's paws, really tumbling in rendered pictures, two bounces and a roll to rest on the true face. Each starts at its own place in the turn and
/// its own moment, every other one mirrored, so ten aren't ten copies; they end in a loose handful, each at its own small angle. A d6's top is its pips; a polyhedron's faces are blank
/// and its number, in the person's own digits, is laid on as the face comes up, so nothing ever shows a number and changes its mind.
@MainActor
enum TossDice {
    static let stepMs = 40.0
    static let crouch = 120.0, arc = 680.0, lag = 42.0
    static let hops: [(ms: Double, height: Double)] = [(360, 34), (240, 10)]
    static let after = 200.0

    static func totalMs(_ count: Int) -> Int { Int(crouch + arc + hops.reduce(0) { $0 + $1.ms } + after + Double(count - 1) * lag) }

    private static func body(_ count: Int) -> Double {
        switch count {
        case 1: 104
        case 2: 94
        case 3: 82
        case 4: 76
        case 5: 72
        case 6: 66
        default: 60
        }
    }

    private static func rows(_ count: Int) -> [Int] {
        switch count {
        case 3: [2, 1]
        case 4: [2, 2]
        case 5: [3, 2]
        case 6: [3, 3]
        case 7: [3, 4]
        case 8: [4, 4]
        case 9: [3, 4, 2]
        case 10: [3, 4, 3]
        default: [count]
        }
    }

    /// A loose handful: rows that don't line up, each die a little off its place and turned its own way. The same for a count, so Again doesn't move it.
    private static func placed(_ sides: Int, _ rolls: [Int]) -> (toys: [TossToys.Toy], w: Double, h: Double) {
        let shape = TossFrames.shape(sides), d = body(rolls.count), side = d / TossFrames.fill(shape), gap = d * 0.1
        let rows = rows(rolls.count), widest = rows.max() ?? 1
        let w = Double(widest) * d + Double(widest - 1) * gap
        var toys: [TossToys.Toy] = []
        var y = d / 2, i = 0
        let loose = rolls.count > 1
        for count in rows {
            let rowW = Double(count) * d + Double(count - 1) * gap
            for c in 0..<count {
                let dx = loose ? TossToys.wobble(i, 7) * d * 0.09 : 0, dy = loose ? TossToys.wobble(i, 11) * d * 0.1 : 0
                let turn = (loose ? TossToys.wobble(i, 13) * 13 : -5)
                var toy = TossToys.Toy(id: "toss.die.\(i)", x: (w - rowW) / 2 + d / 2 + Double(c) * (d + gap) + dx, y: y + dy, side: side, body: d, restRotate: turn,
                                       final: TossFrames.dieFinal(sides: sides, value: rolls[i]), mirrored: i % 2 == 1)
                if sides != 6, let place = TossFrames.numberPlace[shape] {
                    toy.overlay = [number(rolls[i], shape: shape, place: place, side: side, mirrored: toy.mirrored).id(toy.id + ".n")]
                }
                toys.append(toy)
                i += 1
            }
            y += d * 0.98
        }
        return (toys, w, y - d * 0.98 + d / 2 + 8)
    }

    /// The face's own room, as a fraction of the picture: a d4's and a d8's triangle are small, a gem's table is wide.
    private static func numberRoom(_ shape: String) -> (w: Double, size: Double) {
        switch shape {
        case "d4": (0.3, 0.15)
        case "d8": (0.3, 0.15)
        case "d10": (0.3, 0.14)
        case "d12": (0.4, 0.2)
        case "d20": (0.36, 0.19)
        default: (0.5, 0.2)
        }
    }

    private static func number(_ value: Int, shape: String, place: (x: Double, y: Double), side: Double, mirrored: Bool) -> Node {
        let room = numberRoom(shape), w = side * room.w, h = side * room.size * 1.3
        let x = (mirrored ? 1 - place.x : place.x) * side - w / 2, y = place.y * side - h / 2
        let text = Toss.number(value)
        return Node.box(x: x, y: y, w: w, h: h) {
            Node.words(text, size: side * room.size, weight: "black", color: Paint.white.tuned(alpha: 0.55), align: "center", minScale: 0.5, y: 1, w: w, h: h)
            Node.words(text, size: side * room.size, weight: "black", color: Paint.onCream, align: "center", minScale: 0.5, w: w, h: h)
        }
    }

    static func stage(_ toss: Toss, sides: Int, rolls: [Int]) -> (stage: TossToys.Stage, toys: [TossToys.Toy]) {
        let tag = TossToys.Tag(toss, line: TossToys.hasLine(toss) ? " " : nil)
        var (toys, w, h) = placed(sides, rolls)
        let width = Swift.max(Swift.max(w + 64, tag.w + 12), 230)
        for i in toys.indices { toys[i].x += (width - w) / 2; toys[i].y += TossToys.Stage.pad }
        let side = toys.first?.side ?? 160
        let air = Swift.max(apex(rolls.count) + side * 0.46 * 1.14 - (toys.map(\.y).min() ?? 0), 0)
        return (TossToys.Stage(width: width, toysH: h, tag: tag, air: air), toys)
    }

    private static func apex(_ count: Int) -> Double { count == 1 ? 78 : count <= 4 ? 64 : 48 }

    private static var loopSteps: Int { Int((arc + hops[0].ms) / stepMs) - 1 }

    static func flying(_ toss: Toss, sides: Int, rolls: [Int], previous: [Int]?, words: String) -> Scene {
        let (stage, toys) = stage(toss, sides: sides, rolls: rolls)
        var anims: [Anim] = []
        let sparse = rolls.count > 4
        for (i, toy) in toys.enumerated() {
            let delay = Double(i) * lag
            let from: (x: Double, y: Double) = previous == nil ? TossToys.launchPoint(stage, offsetY: stage.air, index: i) : (toy.x, toy.y + stage.air)
            let spin = (i % 2 == 0 ? 1.0 : -1.0) * (70 + 50 * abs(TossToys.wobble(i, 17)))
            // It lands a little short of its place, on the side it came from, and rolls on to it.
            let path = TossThrow(start: from, rest: (toy.x, toy.y + stage.air), apex: apex(rolls.count) + TossToys.wobble(i, 19) * 8, crouch: crouch, arc: arc, hops: hops, after: after,
                                 spin: spin, restRotate: toy.restRotate, from: previous == nil ? 0.55 : 1, near: 0.12, drift: previous == nil ? (toy.x - from.x) * 0.16 : 0)
            anims += path.anims(id: toy.id, inner: toy.id + ".p", shadow: toy.id + ".s", shadowW: toy.body * 1.1, side: toy.side, delay: delay, hidden: previous == nil, arcKeys: sparse ? 7 : 11, hopKeys: 3)
            var list = TossFrames.dieFrames(sides: sides, value: rolls[i], loopSteps: loopSteps, fast: rolls.count == 1 ? 0 : Int((abs(TossToys.wobble(i, 23)) * 13).rounded()))
            let hold = previous.map { TossFrames.dieFinal(sides: sides, value: $0[i]) } ?? list[0]
            list = Array(repeating: hold, count: 3) + list
            anims.append(Anim.frames(toy.id + ".f", list, stepMs: stepMs).delay(ms: delay))
            if sides != 6 {
                // The number comes with the last turn up of its face, and stays. Thrown again, the last one goes at once: this node already holds the new one.
                let shows = delay + crouch + arc + hops[0].ms + stepMs * Double(TossFrames.polySettle - 3), rises = 90.0
                anims.append(.keys(toy.id + ".n", [["t": 0, "opacity": 0, "scale": 0.7], ["t": (shows / (shows + rises) * 10000).rounded() / 10000, "opacity": 0, "scale": 0.7], ["t": 1, "opacity": 1, "scale": 1]], ms: shows + rises))
            }
        }
        return TossToys.flying(stage, toys: toys, anims: anims, tagWords: words, move: "roll", totalMs: totalMs(rolls.count), label: L("{n} dice", ["n": rolls.count]))
    }

    static func landed(_ toss: Toss, sides: Int, rolls: [Int], line: String?, reaction: Reaction?) -> Scene {
        let placed = stage(toss, sides: sides, rolls: rolls)
        var stage = placed.stage
        let toys = placed.toys
        stage.tag = TossToys.Tag(toss, line: line ?? (TossToys.hasLine(toss) ? " " : nil))
        var extras: [Node] = []
        // A natural 20 glints gold.
        if sides == 20, rolls == [20], let toy = toys.first {
            extras.append(Node.symbol("sparkle", color: Paint.sun).symbolLook(weight: "bold").id("toss.glint").at(toy.x + toy.body * 0.42, toy.y - toy.body * 0.62).size(24, 24))
        }
        return TossToys.landed(stage, toys: toys, extras: extras, result: toss.result, line: line, reaction: reaction, label: L("{n} dice", ["n": rolls.count]))
    }
}
