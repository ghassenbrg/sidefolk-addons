import SidefolkExtensionKit

/// One finished part of a board: its node, placed by whoever stacks it, and how tall it came out.
struct PartBlock {
    var node: Node
    var height: Double
    /// How far it reaches past its top and bottom without taking room (a table under the companion's feet): nothing yet needs more.
    init(_ node: Node, height: Double) {
        self.node = node
        self.height = height
    }
}

extension Node {
    /// A sized, placed group: everything on a board is one of these, so its boxes never depend on what it holds.
    static func box(_ id: String? = nil, x: Double = 0, y: Double = 0, w: Double, h: Double, @SceneBuilder _ children: () -> [Node]) -> Node {
        var node = Node(["type": "group", "children": children().map(\.json)]).at(x, y).size(w, h)
        if let id { node = node.id(id) }
        return node
    }

    /// Words in the games' rounded face, sized to a box.
    static func words(_ words: String, size: Double, weight: String = "semibold", color: Color = .ink, align: String = "leading", valign: String = "center",
                      lines: Int = 1, minScale: Double = 0.7, design: String = "rounded", x: Double = 0, y: Double = 0, w: Double, h: Double) -> Node {
        Node.text(words, size: size, weight: weight, design: design, color: color, align: align, valign: valign, lines: lines, minScale: minScale).at(x, y).size(w, h)
    }

    /// A game's card over its scene: the surface, its hairline and a soft shadow.
    static func gameCard(corner: Double = 18, alpha: Double = 0.96, x: Double = 0, y: Double = 0, w: Double, h: Double) -> Node {
        Node.rect(fill: Paint.card(alpha), stroke: Paint.edge, lineWidth: 1, corner: corner).at(x, y).size(w, h).shadow(Paint.black8, radius: 6, dx: 0, dy: 3)
    }

    /// A picture from the pack, fitted in a box.
    static func art(_ path: String, x: Double = 0, y: Double = 0, w: Double, h: Double) -> Node { Node.image(path).at(x, y).size(w, h) }

    /// An SF Symbol in a box the size of its point size, centred at (cx, cy) of its parent.
    static func glyph(_ name: String, size: Double, color: Color = .ink, weight: String = "semibold", x: Double, y: Double) -> Node {
        Node.symbol(name, color: color).symbolLook(weight: weight).at(x, y).size(size * 1.25, size * 1.25)
    }

    /// A raised tile: its lip, its face. The face is the part that sinks when pressed, so the lip stays out of its area.
    static func lipped(_ id: String, corner: Double, depth: Double, w: Double, h: Double, lip: Color) -> Node {
        Node.rect(fill: lip, corner: corner).id(id + ".lip").at(0, depth).size(w, h)
    }

    /// The person's companion's profile picture, in a round frame with a white ring.
    static func faceDisc(id: String? = nil, x: Double, y: Double, side: Double, ring: Double = 2) -> Node {
        .box(id, x: x, y: y, w: side, h: side) {
            Node.companion().figure(face: true).size(side, side).corner(side / 2).clip()
            if ring > 0 { Node.ellipse(stroke: Paint.white, lineWidth: ring).at(ring / 2, ring / 2).size(side - ring, side - ring) }
        }
    }
}

extension Anim {
    /// Keys that really start at their first value. A Sidefolk from before snapshot B starts a run from a node's resting value and skips a key at t 0, so anything that doesn't
    /// start where it rests (a mark stamped in, a hand hidden until it opens) says its first value again at once, and starts there on any Sidefolk.
    static func from(_ target: String, _ frames: [[String: Double]], ms: Double, ease: String = "linear") -> Anim {
        guard let first = frames.first, first["t"] == 0 else { return .keys(target, frames, ms: ms, ease: ease) }
        return .keys(target, [first, first.merging(["t": 0.0001]) { _, new in new }] + frames.dropFirst(), ms: ms, ease: ease)
    }
}

/// `M`/`Q`/`C` paths the board's shapes need. A rounded rectangle keeps to the same radius as a `rect`.
enum ShapePath {
    static func rounded(x: Double, y: Double, w: Double, h: Double, r: Double) -> String {
        let k = r * 0.45
        return "M \(x + r) \(y) L \(x + w - r) \(y) C \(x + w - k) \(y) \(x + w) \(y + k) \(x + w) \(y + r) L \(x + w) \(y + h - r) "
            + "C \(x + w) \(y + h - k) \(x + w - k) \(y + h) \(x + w - r) \(y + h) L \(x + r) \(y + h) C \(x + k) \(y + h) \(x) \(y + h - k) \(x) \(y + h - r) "
            + "L \(x) \(y + r) C \(x) \(y + k) \(x + k) \(y) \(x + r) \(y) Z "
    }
}
