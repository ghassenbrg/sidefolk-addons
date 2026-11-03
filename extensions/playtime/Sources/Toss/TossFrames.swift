import SidefolkExtensionKit

/// The pictures the toss's toys are made of, rendered from clay models in Blender (art source: the design hand-off's toss-source). Each is one real rotation of the toy under a fixed
/// camera and fixed lights, with a cream die-cut edge cut to its own outline; only the scene's keys move it about. All are square, with the toy turning about the picture's middle.
///
/// A loop closes on itself, and always leaves at its first frame into a settle that ends on the true face, so a die can start anywhere in its loop, and what the last picture shows
/// is fixed by the result alone: `dieFinal`, `coinFinal`. A d6 tumbling shows its other faces as a real die does; a polyhedron's are blank, and its number is live text laid on at the end.
enum TossFrames {
    /// How much of its picture a toy takes when it lies still, measured from the renders, so a toy's size means what it takes on the desktop whatever its shape.
    static let coinFill = 0.82
    static func fill(_ shape: String) -> Double {
        switch shape {
        case "d6": 0.66
        case "d4": 0.77
        case "d8": 0.69
        case "d10": 0.78
        case "d12": 0.81
        case "d20": 0.85
        default: 0.78
        }
    }
    static let coinLoop = 16, d6Loop = 14, polyLoop = 6, coinSettle = 10, d6Settle = 10, polySettle = 8

    static func path(_ name: String) -> String { "art/toss-\(name).webp" }

    /// The shape a die of this many sides is drawn as: the gem for anything without its own.
    static func shape(_ sides: Int) -> String {
        switch sides {
        case 6: "d6"
        case 4, 8, 10, 12, 20: "d\(sides)"
        default: "gem"
        }
    }

    /// The picture a landed die shows: for a d6, the one with this value on top.
    static func dieFinal(sides: Int, value: Int) -> String {
        sides == 6 ? path("d6-\(value)-\(d6Settle - 1)") : path("\(shape(sides))-s\(polySettle - 1)")
    }

    static func coinFinal(heads: Bool) -> String { path("coin-\(heads ? "h" : "t")\(coinSettle - 1)") }

    static func coinLoopName(_ i: Int) -> String { "l" + String(format: "%02d", ((i % coinLoop) + coinLoop) % coinLoop) }

    /// A die's whole flight, picture by picture: `count` steps of its loop, then its settle. Whatever else, it reaches the loop's first frame when the settle starts; a die with a livelier
    /// `fast` first few steps skips every other picture through them, which puts it somewhere else in the turn, so no two tumble in step.
    static func dieFrames(sides: Int, value: Int, loopSteps count: Int, fast: Int = 0) -> [String] {
        let shape = shape(sides), period = sides == 6 ? d6Loop : polyLoop
        var turn = 0, loop: [Int] = []
        for step in stride(from: count - 1, through: 0, by: -1) {
            loop.insert(((turn % period) + period) % period, at: 0)
            turn -= step < fast ? 2 : 1
        }
        if sides == 6 { return loop.map { path("d6-l" + String(format: "%02d", $0)) } + (0..<d6Settle).map { path("d6-\(value)-\($0)") } }
        return loop.map { path("\(shape)-l\($0)") } + (0..<polySettle).map { path("\(shape)-s\($0)") }
    }

    /// Where the disc of the companion's face stands on a coin in this frame, as fractions of the picture; the disc's two axes, along the turn's axis and across it.
    struct CoinFace {
        var front: Bool
        var x, y, w, h: Double
    }

    /// The disc's width when it looks straight at you, as a fraction of the picture: `CoinFace`'s w and h are this at their largest.
    static let faceSide = 0.576
    /// The axis a coin turns about, off the horizontal.
    static let coinAxis = 16.0

    static let coinFace: [String: CoinFace] = [
        "l00": CoinFace(front: true, x: 0.5, y: 0.4875, w: 0.581, h: 0.551),
        "l01": CoinFace(front: true, x: 0.5076, y: 0.5013, w: 0.5728, h: 0.582),
        "l02": CoinFace(front: true, x: 0.511, y: 0.5149, w: 0.5666, h: 0.5196),
        "l03": CoinFace(front: true, x: 0.5107, y: 0.5259, w: 0.5701, h: 0.384),
        "l04": CoinFace(front: true, x: 0.51, y: 0.5327, w: 0.5761, h: 0.1932),
        "l05": CoinFace(front: false, x: 0.5106, y: 0.5344, w: 0.5758, h: 0.0241),
        "l06": CoinFace(front: false, x: 0.5109, y: 0.531, w: 0.5723, h: 0.2369),
        "l07": CoinFace(front: false, x: 0.5074, y: 0.5234, w: 0.5702, h: 0.4201),
        "l08": CoinFace(front: false, x: 0.5, y: 0.5122, w: 0.5662, h: 0.5386),
        "l09": CoinFace(front: false, x: 0.4926, y: 0.4987, w: 0.558, h: 0.5666),
        "l10": CoinFace(front: false, x: 0.4892, y: 0.4854, w: 0.5539, h: 0.5104),
        "l11": CoinFace(front: false, x: 0.4895, y: 0.4745, w: 0.5606, h: 0.3858),
        "l12": CoinFace(front: false, x: 0.4901, y: 0.4676, w: 0.571, h: 0.205),
        "l13": CoinFace(front: false, x: 0.4894, y: 0.4656, w: 0.5762, h: 0.0085),
        "l14": CoinFace(front: true, x: 0.489, y: 0.4686, w: 0.5785, h: 0.2261),
        "l15": CoinFace(front: true, x: 0.4925, y: 0.4762, w: 0.5819, h: 0.4211),
        "h0": CoinFace(front: true, x: 0.4962, y: 0.4759, w: 0.5794, h: 0.4344),
        "h1": CoinFace(front: true, x: 0.493, y: 0.4795, w: 0.5825, h: 0.4672),
        "h2": CoinFace(front: true, x: 0.491, y: 0.4852, w: 0.5799, h: 0.5163),
        "h3": CoinFace(front: true, x: 0.4932, y: 0.4907, w: 0.5808, h: 0.5567),
        "h4": CoinFace(front: true, x: 0.4984, y: 0.4927, w: 0.5839, h: 0.5715),
        "h5": CoinFace(front: true, x: 0.5024, y: 0.4905, w: 0.5787, h: 0.5676),
        "h6": CoinFace(front: true, x: 0.5025, y: 0.4873, w: 0.5763, h: 0.5532),
        "h7": CoinFace(front: true, x: 0.5005, y: 0.4864, w: 0.5797, h: 0.5454),
        "h8": CoinFace(front: true, x: 0.4997, y: 0.4872, w: 0.5812, h: 0.549),
        "h9": CoinFace(front: true, x: 0.5, y: 0.4875, w: 0.581, h: 0.551),
        "t0": CoinFace(front: false, x: 0.5038, y: 0.5236, w: 0.5677, h: 0.4323),
        "t1": CoinFace(front: false, x: 0.5069, y: 0.5201, w: 0.5692, h: 0.4631),
        "t2": CoinFace(front: false, x: 0.5088, y: 0.5145, w: 0.562, h: 0.5117),
        "t3": CoinFace(front: false, x: 0.5066, y: 0.5091, w: 0.5623, h: 0.5474),
        "t4": CoinFace(front: false, x: 0.5016, y: 0.5071, w: 0.5679, h: 0.5571),
        "t5": CoinFace(front: false, x: 0.4977, y: 0.5092, w: 0.5676, h: 0.5494),
        "t6": CoinFace(front: false, x: 0.4976, y: 0.5124, w: 0.5684, h: 0.5338),
        "t7": CoinFace(front: false, x: 0.4995, y: 0.5132, w: 0.5682, h: 0.5302),
        "t8": CoinFace(front: false, x: 0.5003, y: 0.5124, w: 0.5668, h: 0.5364),
        "t9": CoinFace(front: false, x: 0.5, y: 0.5122, w: 0.5662, h: 0.5386),
    ]
    static let numberPlace: [String: (x: Double, y: Double)] = [
        "d4": (0.5, 0.5233),
        "d8": (0.5, 0.5391),
        "d10": (0.5, 0.6251),
        "d12": (0.5, 0.5515),
        "d20": (0.5, 0.5532),
        "gem": (0.5, 0.5381),
    ]
}
