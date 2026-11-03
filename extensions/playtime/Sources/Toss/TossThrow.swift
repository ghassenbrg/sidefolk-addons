import Foundation
import SidefolkExtensionKit

/// How a toy goes through the air (Rock, Paper, Scissors' spirit: anticipation, weight, follow-through), whatever it is: it crouches, leaves stretched, comes closer as it rises,
/// lands with a squash, and hops to a stop. All in the plane: the turning itself is in the pictures. Times are ms from the toy's own start.
struct TossThrow {
    var start: (x: Double, y: Double)
    var rest: (x: Double, y: Double)
    /// Over its resting place, at the top of the arc.
    var apex: Double
    var crouch = 120.0
    var arc: Double
    /// Each hop after landing.
    var hops: [(ms: Double, height: Double)]
    /// Lies still after the last hop.
    var after: Double
    /// Turning in the plane, degrees: where it starts, where it rests.
    var spin = 0.0
    var restRotate = 0.0
    /// How small it is when it leaves: thrown from the companion's paws, or 1 when it hops from where it lay.
    var from = 0.55
    /// How much closer it comes at the top.
    var near = 0.14
    /// How far short of its place it lands the first time, and slides on.
    var drift = 0.0

    var duration: Double { crouch + arc + hops.reduce(0) { $0 + $1.ms } + after }

    struct State {
        var x, y, scale, sx, sy, rotate: Double
        /// How high over the ground, 0 to 1.
        var height: Double
    }

    /// The arc's bend for its height: `y = s + d p − 4 H p (1 − p)` reaches `peak` at its highest.
    private var bend: Double {
        let s = start.y, d = rest.y - start.y, peak = rest.y - apex
        var low = 0.0, high = 4000.0
        for _ in 0..<40 {
            let h = (low + high) / 2, p = min(max((4 * h - d) / (8 * h), 0), 1)
            if s + d * p - 4 * h * p * (1 - p) > peak { low = h } else { high = h }
        }
        return (low + high) / 2
    }

    func state(_ t: Double) -> State {
        let lands = crouch + arc
        let allSpin = 1 - min(max(t / (lands + hops.reduce(0) { $0 + $1.ms }), 0), 1)
        let rotate = restRotate + spin * allSpin * allSpin
        if t < crouch {
            let p = crouch > 0 ? t / crouch : 1, e = 1 - (1 - p) * (1 - p)
            // It gathers itself: settles into a crouch while it grows into being.
            return State(x: start.x, y: start.y, scale: from + (from == 1 ? 0 : (1 - from) * 0.25 * e), sx: 1 + 0.2 * e, sy: 1 - 0.26 * e, rotate: rotate, height: 0)
        }
        let ground = rest.x - drift
        if t < lands {
            let p = (t - crouch) / arc
            let d = rest.y - start.y, h = bend
            let y = start.y + d * p - 4 * h * p * (1 - p)
            let lift = Swift.min(Swift.max((rest.y - y) / Swift.max(apex, 1), 0), 1)
            let grown = from + (1 - from) * Swift.min(p * 2.5 + 0.25, 1)
            // Stretched as it leaves and again as it falls; round at the top.
            let stretch = 0.2 * exp(-p * 9) + 0.07 * pow(p, 6)
            return State(x: start.x + (ground - start.x) * p, y: y, scale: grown + near * lift, sx: 1 - stretch * 0.7, sy: 1 + stretch, rotate: rotate, height: lift)
        }
        var at = lands, left = ground
        for (i, hop) in hops.enumerated() {
            let next = at + hop.ms
            let share = hops.count == 1 ? 1 : Double(i == 0 ? 2 : 1) / 3
            if t < next {
                let p = (t - at) / hop.ms
                let lift = 4 * p * (1 - p)
                // Squashed on the bounce and back within its first fifth.
                let hit = Swift.max(1 - p / 0.28, 0) * (i == 0 ? 0.2 : 0.12)
                return State(x: left + drift * share * p, y: rest.y - hop.height * lift, scale: 1 + near * 0.3 * hop.height / Swift.max(apex, 1) * lift, sx: 1 + hit * 0.8, sy: 1 - hit, rotate: rotate, height: hop.height * lift / Swift.max(apex, 1))
            }
            at = next
            left += drift * share
        }
        // A last small give.
        let p = after > 0 ? Swift.min((t - at) / after, 1) : 1
        let give = sin(p * .pi * 2) * exp(-p * 3) * 0.05
        return State(x: rest.x, y: rest.y, scale: 1, sx: 1 + give, sy: 1 - give, rotate: restRotate, height: 0)
    }

    /// The moments worth a key: dense over each bounce, thin in the air.
    func times(arcKeys: Int, hopKeys: Int) -> [Double] {
        var out = [0, crouch * 0.5, crouch]
        for i in 1...arcKeys { out.append(crouch + arc * Double(i) / Double(arcKeys)) }
        var at = crouch + arc
        for hop in hops {
            for i in 1...hopKeys {
                let p = Double(i) / Double(hopKeys)
                out.append(at + hop.ms * (i == 1 ? 0.2 : p))
            }
            at += hop.ms
        }
        if after > 0 { for p in [0.33, 0.66, 1.0] { out.append(at + after * p) } }
        return out
    }

    private static func tidy(_ v: Double) -> Double { (v * 100).rounded() / 100 }
    private static func tidyT(_ v: Double) -> Double { (v * 10000).rounded() / 10000 }

    /// The keys of where the toy is (its node at `side` across) and of how it's bent, in the 32 a step may hold.
    func anims(id: String, inner: String, shadow: String?, shadowW: Double, side: Double, delay: Double, hidden: Bool, arcKeys: Int = 12, hopKeys: Int = 4) -> [Anim] {
        let times = times(arcKeys: arcKeys, hopKeys: hopKeys), total = duration
        var place: [[String: Double]] = [], bent: [[String: Double]] = []
        for time in times {
            let s = state(time), t = Self.tidyT(time / total)
            place.append(["t": t, "x": Self.tidy(s.x - side / 2), "y": Self.tidy(s.y - side / 2), "scale": Self.tidy(s.scale)])
            bent.append(["t": t, "sx": Self.tidy(s.sx), "sy": Self.tidy(s.sy), "rotate": Self.tidy(s.rotate)])
        }
        var out: [Anim] = [
            Anim.keys(id, place, ms: total).delay(ms: delay),
            Anim.keys(inner, bent, ms: total).delay(ms: delay),
        ]
        if hidden {
            // Not there until its turn, then there at once.
            out.append(Anim.keys(id, [["t": 0, "opacity": 0], ["t": Self.tidyT(delay / (delay + 40)), "opacity": 0], ["t": 1, "opacity": 1]], ms: delay + 40))
        }
        if let shadow {
            // It only says where the toy will come down: it isn't there until the toy has left the floor behind, and it gathers as the toy falls. Its keys start at the scene's start,
            // since a node waiting for its step stands where it will end.
            let whole = delay + total
            var keys: [[String: Double]] = [["t": 0, "opacity": 0]]
            for p in stride(from: 0.0, through: 1.0, by: 1.0 / 8) {
                let time = total * (p == 1 ? 1 : p * (crouch + arc + 80) / total), s = state(time)
                let clear = Swift.min(Swift.max((start.y - s.y) / Swift.max(start.y - rest.y + 1, 1), 0), 1)
                let seen = (start.y <= rest.y || clear >= 1 ? 0.62 : 0) * (0.3 + 0.7 * (1 - s.height))
                keys.append(["t": Self.tidyT((delay + time) / whole), "x": Self.tidy(s.x - shadowW / 2), "scale": Self.tidy(0.55 + 0.45 * (1 - s.height)), "opacity": Self.tidy(seen)])
            }
            out.append(Anim.keys(shadow, keys, ms: whole))
        }
        return out
    }
}
