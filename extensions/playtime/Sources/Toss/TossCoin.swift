import Foundation
import SidefolkExtensionKit

/// The coin: rendered turning end over end, with its edge and its thickness. Heads' dish is blank in the pictures, since the companion varies: its real face is laid on it, following
/// the disc frame by frame, there whenever heads looks your way. Tails has a star stamped in the clay. Coins go up one after another and come down an arm's reach apart.
@MainActor
enum TossCoin {
    static let stepMs = 30.0
    static let crouch = 120.0, arc = 1200.0, lag = 110.0
    static let hops: [(ms: Double, height: Double)] = [(190, 26), (130, 9)]
    static let after = 280.0
    /// Its loop's pictures per flight, its settle's, each held twice.
    static var loopSteps: Int { Int(arc / stepMs) }

    static func totalMs(_ count: Int) -> Int { Int(crouch + arc + hops.reduce(0) { $0 + $1.ms } + after + Double(count - 1) * lag) }

    private static func label(_ count: Int) -> String { count == 1 ? L("A coin") : L("{n} coins", ["n": count]) }

    private static func width(_ count: Int) -> Double {
        switch count {
        case 1: 116
        case 2: 100
        case 3: 88
        default: 84
        }
    }

    private static func rows(_ count: Int) -> [Int] {
        switch count {
        case 4: [2, 2]
        case 5: [3, 2]
        default: [count]
        }
    }

    /// Where each coin stands, and the block they make.
    private static func placed(_ flips: [Bool]) -> (toys: [TossToys.Toy], w: Double, h: Double) {
        let d = width(flips.count), side = d / TossFrames.coinFill, gap = d * 0.08
        let rows = rows(flips.count)
        var toys: [TossToys.Toy] = []
        let w = Double(rows.max() ?? 1) * d + Double((rows.max() ?? 1) - 1) * gap
        var y = d / 2, i = 0
        for count in rows {
            let rowW = Double(count) * d + Double(count - 1) * gap
            for c in 0..<count {
                let x = (w - rowW) / 2 + d / 2 + Double(c) * (d + gap)
                let jitterY = flips.count > 1 ? TossToys.wobble(i, 3) * 6 : 0
                toys.append(TossToys.Toy(id: "toss.coin.\(i)", x: x, y: y + jitterY, side: side, body: d, restRotate: flips.count > 1 ? TossToys.wobble(i, 5) * 7 : 0,
                                         final: TossFrames.coinFinal(heads: flips[i])))
                i += 1
            }
            y += d * 0.94
        }
        return (toys, w, y - d * 0.94 + d / 2 + 6)
    }

    static func stage(_ toss: Toss, flips: [Bool]) -> (stage: TossToys.Stage, toys: [TossToys.Toy]) {
        let tag = TossToys.Tag(toss, line: TossToys.hasLine(toss) ? " " : nil)
        var (toys, w, h) = placed(flips)
        let width = Swift.max(Swift.max(w + 60, tag.w + 12), 230)
        for i in toys.indices { toys[i].x += (width - w) / 2; toys[i].y += TossToys.Stage.pad }
        let side = toys.first?.side ?? 140
        // Up to the air's top with its whole picture in the window.
        let apex = flips.count == 1 ? 150.0 : 120.0
        let air = Swift.max(apex + side * 0.57 * 1.14 - (toys.map(\.y).min() ?? 0), 0)
        return (TossToys.Stage(width: width, toysH: h, tag: tag, air: air), toys)
    }

    /// The companion's real face over the dish, its keys following the pictures': hidden while tails is showing.
    private static func face(_ toy: TossToys.Toy, heads: Bool) -> Node {
        let side = toy.side, disc = side * TossFrames.faceSide, id = toy.id + ".face"
        let rest = TossFrames.coinFace[(heads ? "h" : "t") + "\(TossFrames.coinSettle - 1)"]!
        return Node.box(id, x: rest.x * side - disc / 2, y: rest.y * side - disc / 2, w: disc, h: disc) {
            Node.box(w: disc, h: disc) {
                Node.box(id + ".q", w: disc, h: disc) {
                    Node.companion().figure(face: true).size(disc, disc).corner(disc / 2).clip().rotate(TossFrames.coinAxis)
                }.scale(x: rest.w / TossFrames.faceSide, y: rest.h / TossFrames.faceSide)
            }.rotate(-TossFrames.coinAxis)
        }.opacity(heads ? 1 : 0)
    }

    /// The pictures of a whole flight, one entry per step, each with its name: the crouch held, the turning, then the settle, each of its pictures for two steps.
    private static func entries(heads: Bool, from previous: String?) -> [(path: String, name: String)] {
        let end = heads ? TossFrames.coinLoop - 1 : TossFrames.coinLoop / 2 - 1
        let count = loopSteps
        let first = end - count + 1
        var out: [(String, String)] = []
        let held = TossFrames.coinLoopName(first)
        for _ in 0..<4 { out.append((previous ?? TossFrames.path("coin-" + held), previous == nil ? held : "")) }
        for step in 0..<count {
            let name = TossFrames.coinLoopName(first + step)
            out.append((TossFrames.path("coin-" + name), name))
        }
        for i in 0..<TossFrames.coinSettle {
            let name = (heads ? "h" : "t") + "\(i)"
            for _ in 0..<2 { out.append((TossFrames.path("coin-" + name), name)) }
        }
        return out
    }

    static func flying(_ toss: Toss, flips: [Bool], previous: [Bool]?, words: String) -> Scene {
        let (stage, placed) = stage(toss, flips: flips)
        var toys = placed
        var anims: [Anim] = []
        for i in toys.indices {
            let heads = flips[i]
            var toy = toys[i]
            let delay = Double(i) * lag
            let from: (x: Double, y: Double) = previous == nil ? TossToys.launchPoint(stage, offsetY: stage.air, index: i) : (toy.x, toy.y + stage.air)
            let apex = flips.count == 1 ? 150.0 : 120.0
            let path = TossThrow(start: from, rest: (toy.x, toy.y + stage.air), apex: apex, crouch: crouch, arc: arc, hops: hops, after: after,
                                 spin: Double(i % 2 == 0 ? 1 : -1) * 16, restRotate: toy.restRotate, from: previous == nil ? 0.55 : 1, near: 0.16)
            anims += path.anims(id: toy.id, inner: toy.id + ".p", shadow: toy.id + ".s", shadowW: toy.body * 1.1, side: toy.side, delay: delay, hidden: previous == nil, arcKeys: flips.count > 2 ? 8 : 12, hopKeys: 3)
            let list = entries(heads: heads, from: previous.map { TossFrames.coinFinal(heads: $0[i]) })
            anims.append(Anim.frames(toy.id + ".f", list.map(\.path), stepMs: stepMs).delay(ms: delay))
            toy.overlay = [face(toy, heads: heads)]
            anims += faceKeys(toy, list: list.map(\.name), delay: delay, wasHeads: previous?[i], sparse: flips.count > 2)
            toys[i] = toy
        }
        return TossToys.flying(stage, toys: toys, anims: anims, tagWords: words, move: "flick", totalMs: totalMs(flips.count), label: label(flips.count))
    }

    /// Steps of the face's place and shape, a key at each picture, split into the 32 a step may hold.
    private static func faceKeys(_ toy: TossToys.Toy, list: [String], delay: Double, wasHeads: Bool?, sparse: Bool) -> [Anim] {
        let side = toy.side, disc = side * TossFrames.faceSide, id = toy.id + ".face"
        var place: [[String: Double]] = [], shape: [[String: Double]] = []
        let total = Double(list.count) * stepMs
        // Held for as long as its picture is, so the disc never leads or lags the coin under it. Several small coins make do with half the keys.
        var runs: [(n: Int, name: String)] = []
        for (n, name) in list.enumerated() where n == 0 || name != list[n - 1] { runs.append((n, name)) }
        for (r, run) in runs.enumerated() {
            let name = run.name
            if sparse, name.hasPrefix("l"), r % 2 == 1 { continue }
            let f = TossFrames.coinFace[name] ?? TossFrames.coinFace["t\(TossFrames.coinSettle - 1)"]!
            let from = Double(run.n) * stepMs, to = (r + 1 < runs.count ? Double(runs[r + 1].n) : Double(list.count)) * stepMs - 1
            for t in sparse ? [from] : [from, Swift.max(from, to)] {
                place.append(["t": (t / total).t4, "x": (f.x * side - disc / 2).t2, "y": (f.y * side - disc / 2).t2, "opacity": name.isEmpty ? (wasHeads == true ? 1 : 0) : f.front && f.h > 0.14 ? 1 : 0])
                shape.append(["t": (t / total).t4, "sx": (f.w / TossFrames.faceSide).t2, "sy": (Swift.max(f.h, 0.01) / TossFrames.faceSide).t2])
            }
        }
        // A node waiting for its step stands where it will end, and the face on a coin not yet in the air mustn't: these keys start with the scene.
        if delay > 0, let first = place.first, let firstShape = shape.first {
            place.insert(first.merging(["t": -delay / total]) { $1 }, at: 0)
            shape.insert(firstShape.merging(["t": -delay / total]) { $1 }, at: 0)
        }
        func split(_ target: String, _ keys: [[String: Double]]) -> [Anim] {
            stride(from: 0, to: keys.count - 1, by: 31).map { from in
                let part = Array(keys[from..<Swift.min(from + 32, keys.count)])
                let a = part.first!["t"]!, b = part.last!["t"]!
                let span = Swift.max(b - a, 1e-4)
                let rebased = part.map { key -> [String: Double] in
                    key.merging(["t": ((key["t"]! - a) / span).t4]) { $1 }
                }
                return Anim.keys(target, rebased, ms: (span * total).t2).delay(ms: (delay + a * total).t2)
            }
        }
        return split(id, place) + split(id + ".q", shape)
    }

    static func landed(_ toss: Toss, flips: [Bool], line: String?, reaction: Reaction?) -> Scene {
        var (stage, toys) = stage(toss, flips: flips)
        stage.tag = TossToys.Tag(toss, line: line ?? (TossToys.hasLine(toss) ? " " : nil))
        for i in toys.indices where flips[i] { toys[i].overlay = [face(toys[i], heads: true)] }
        return TossToys.landed(stage, toys: toys, extras: [], result: toss.result, line: line, reaction: reaction, label: label(flips.count))
    }
}

private extension Double {
    var t2: Double { (self * 100).rounded() / 100 }
    var t4: Double { (self * 10000).rounded() / 10000 }
}
