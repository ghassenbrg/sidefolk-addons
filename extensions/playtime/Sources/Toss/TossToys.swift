import Foundation
import SidefolkExtensionKit

/// Direction C, Loose Toys: big clay coins and dice cut out like stickers, thrown from the companion's paws, tumbling for real in rendered pictures, with no ground under them
/// and nothing round them but the felt tag. The two scenes are the same picture: the landed one only drops the air over the toys, and the host keeps the overlay's bottom edge, so
/// nothing moves when the result shows. With Reduce Motion the keys and pictures don't play, and each node already stands where it ends.
@MainActor
enum TossToys {
    /// A toy, wherever it stands, as both scenes draw it: by its middle in the landed scene's coordinates.
    struct Toy {
        var id: String
        var x, y: Double
        /// Its picture's side.
        var side: Double
        /// What it takes on the desktop when still.
        var body: Double
        var restRotate: Double
        var final: String
        var mirrored = false
        /// Laid on the picture: the coin's face, a die's number.
        var overlay: [Node] = []
    }

    struct Stage {
        var width: Double
        /// The toys' block, under the air.
        var toysH: Double
        var tag: Tag
        var again = true
        var air: Double
        static let pad = 8.0, gap = 8.0, againH = 30.0
        var landedH: Double { Stage.pad + toysH + Stage.gap + tag.h + Stage.gap + Stage.againH + Stage.pad }
        var flyingH: Double { air + landedH }
        /// Where the tag stands in the landed scene.
        var tagY: Double { Stage.pad + toysH + Stage.gap }
        var againY: Double { tagY + tag.h + Stage.gap }
    }

    // MARK: The felt tag

    struct Tag {
        var w, h: Double
        var words: String
        var size: Double
        var weight: String
        var beside: String?
        var line: String?
        var verdict: Verdict?

        static let most = 330.0
        static let besideSize = 12.0, lineSize = 12.5

        /// A big result; its sum beside it if there's room, under it if not; and the companion's line under that. It can take two lines, for ten d100s and a modifier.
        init(_ toss: Toss, line: String?) {
            switch toss {
            case .dice(_, let rolls, let modifier) where rolls.count > 1 || modifier != 0:
                (words, size, weight) = (Toss.number(rolls.reduce(0, +) + modifier), 30, "black")
                beside = toss.parts
            case .coins(let flips, _) where flips.count > 1: (words, size, weight) = (toss.result, 19, "heavy")
            case .hands: (words, size, weight) = (toss.result, 16, "heavy")
            default: (words, size, weight) = (toss.result, 28, "black")
            }
            self.line = line
            verdict = toss.verdict
            let symbol = verdict == nil ? 0.0 : 28
            var wordsW = TextFit.width(words, size: size, weight: weight)
            if symbol + wordsW > Self.most - 40 {
                size *= (Self.most - 40 - symbol) / wordsW
                wordsW = Self.most - 40 - symbol
            }
            let besideW = beside.map { TextFit.width($0, size: Self.besideSize, weight: "semibold") } ?? 0
            let lineW = line.map { TextFit.width($0, size: Self.lineSize, weight: "semibold") } ?? 0
            let inline = symbol + wordsW + (beside == nil ? 0 : besideW + 10)
            let stacked = inline + 40 > Self.most
            let first = TextFit.lineHeight(size, weight)
            let rows = stacked ? TextFit.height(beside ?? "", size: Self.besideSize, weight: "semibold", width: Self.most - 40, lines: 2) : 0
            h = first + (rows > 0 ? rows : 0) + (line == nil ? 0 : TextFit.lineHeight(Self.lineSize, "semibold")) + 14
            w = Swift.min(Swift.max(stacked ? Self.most : inline + 40, lineW + 40, 92), Self.most)
        }

        /// The tag while it flies: the waiting words, in the same place, as tall as the result will be.
        init(waiting: String, like result: Tag) {
            words = waiting
            size = 15
            weight = "heavy"
            h = result.h
            w = Swift.min(TextFit.width(waiting, size: 15, weight: "heavy") + 40, Self.most)
        }

        var node: Node {
            let symbol = verdict == nil ? 0.0 : 28
            let wordsH = TextFit.lineHeight(size, weight), lineH = line == nil ? 0 : TextFit.lineHeight(Self.lineSize, "semibold")
            let wordsW = Swift.min(TextFit.width(words, size: size, weight: weight), w - 40 - symbol)
            let besideW = beside.map { TextFit.width($0, size: Self.besideSize, weight: "semibold") } ?? 0
            let stacked = beside != nil && symbol + wordsW + besideW + 10 + 40 > w
            let rowW = symbol + wordsW + (beside != nil && !stacked ? besideW + 10 : 0)
            let left = (w - rowW) / 2
            let besideRows = stacked ? h - 14 - wordsH - lineH : 0
            let top = (h - wordsH - besideRows - lineH) / 2
            return .box("toss.tag", w: w, h: h) {
                Node.rect(fill: Paint.cream, corner: Swift.min(h / 2, 22)).size(w, h).shadow(Paint.clear("#14183A", 0.3), radius: 6, dx: 0, dy: 3)
                Node.rect(stroke: Paint.clear("#C9B58F", 0.95), lineWidth: 1, corner: Swift.max(Swift.min(h / 2, 22) - 3, 2), dash: [4, 3]).at(3, 3).size(w - 6, h - 6)
                if let verdict {
                    Node.symbol(verdict.symbol, color: Paint.cream).symbolLook(weight: "bold", secondary: verdict.color).at(left, top + (wordsH - 22) / 2).size(22, 22)
                }
                Node.words(words, size: size, weight: weight, color: Paint.onCream, align: "center", x: left + symbol, y: top, w: wordsW, h: wordsH)
                if let beside {
                    if stacked {
                        Node.words(beside, size: Self.besideSize, weight: "semibold", color: Paint.lilacDeepFixed, align: "center", lines: 2, x: 20, y: top + wordsH, w: w - 40, h: besideRows).leftToRight()
                    } else {
                        Node.words(beside, size: Self.besideSize, weight: "semibold", color: Paint.lilacDeepFixed, x: left + symbol + wordsW + 10, y: top, w: besideW, h: wordsH).leftToRight()
                    }
                }
                if let line {
                    Node.words(line, size: Self.lineSize, weight: "semibold", color: Paint.lilacDeepFixed, align: "center", x: 16, y: top + wordsH + besideRows, w: w - 32, h: lineH)
                }
            }
        }
    }

    /// The navy Again, the same by day and by night.
    private static func again(width: Double, y: Double) -> Node {
        let words = L("Again"), textW = TextFit.width(words, size: 13, weight: "bold")
        let w = textW + 18 + 6 + 30, h = Stage.againH
        return Node.box("toss.again", x: (width - w) / 2, y: y, w: w, h: h) {
            Node.capsule(fill: Paint.navy2).size(w, h).shadow(Paint.clear("#14183A", 0.3), radius: 5, dx: 0, dy: 2)
            Node.symbol("arrow.clockwise", color: Paint.cream).symbolLook(weight: "bold").at(14, 8).size(14, 14)
            Node.words(words, size: 13, weight: "bold", color: Paint.cream, x: 34, w: textW, h: h)
        }.area("again", label: words, hover: AreaLook(scale: 1.04), press: AreaLook(scale: 0.95))
    }

    /// The toy, nested so its keys don't fight: where it is, how it's bent, the picture. The contact shadow goes under all the toys.
    private static func drawn(_ toy: Toy, offsetY: Double) -> Node {
        var image = Node.image(toy.final).id(toy.id + ".f").size(toy.side, toy.side)
        if toy.mirrored { image = image.scale(x: -1, y: 1) }
        return Node.box(toy.id, x: toy.x - toy.side / 2, y: toy.y + offsetY - toy.side / 2, w: toy.side, h: toy.side) {
            Node.box(toy.id + ".p", w: toy.side, h: toy.side) {
                image
                toy.overlay
            }.anchor(0.5, 0.72).rotate(toy.restRotate)
        }
    }

    private static func shadow(_ toy: Toy, offsetY: Double) -> Node {
        let w = toy.body * 1.1, h = toy.body * 0.34
        return Node.image("art/toss-shadow.webp").id(toy.id + ".s").at(toy.x - w / 2, toy.y + offsetY + toy.body * 0.5 - h * 0.55).size(w, h).opacity(0.62)
    }

    // MARK: The two scenes

    /// Where a throw starts: at the bottom of the scene, by the companion's paws.
    static func launchPoint(_ stage: Stage, offsetY: Double, index i: Int) -> (x: Double, y: Double) {
        (stage.width / 2 + Double((i * 37) % 21) - 10, offsetY + stage.landedH - Stage.pad - 8)
    }

    /// The scene while it flies: the toys over the tag; below them the room Again will take.
    static func flying(_ stage: Stage, toys: [Toy], anims: [Anim], tagWords: String, move: String, totalMs: Int, label: String) -> Scene {
        let tag = Tag(waiting: tagWords, like: stage.tag)
        let air = stage.air
        var nodes: [Node] = toys.map { shadow($0, offsetY: air) }
        nodes.append(tag.node.at((stage.width - tag.w) / 2, air + stage.tagY))
        nodes += toys.sorted { $0.y < $1.y }.map { drawn($0, offsetY: air) }
        var all = anims
        all.append(.sequence([.react(Reaction(move: move, look: "panel"))]))
        return Scene(width: stage.width, height: stage.flyingH) {
            Node.box("toss.toys", w: stage.width, h: stage.flyingH) { nodes }.leftToRight().label(label)
        }
        .animating(all)
        .after(ms: totalMs)
        .afterStill(ms: 200)
    }

    /// The scene when it has landed: the same, without the air, the bottom edge where it was, with its words and Again.
    static func landed(_ placed: Stage, toys placedToys: [Toy], extras: [Node], result: String, line: String?, reaction: Reaction?, label: String) -> Scene {
        // A companion's line longer than the room it was given (a long language): wider, from the middle, which the host keeps still as it keeps the bottom.
        var stage = placed, toys = placedToys
        let wider = Swift.max(stage.tag.w + 12 - stage.width, 0)
        stage.width += wider
        for i in toys.indices { toys[i].x += wider / 2 }
        var nodes: [Node] = toys.map { shadow($0, offsetY: 0) }
        nodes.append(stage.tag.node.at((stage.width - stage.tag.w) / 2, stage.tagY))
        nodes += toys.sorted { $0.y < $1.y }.map { drawn($0, offsetY: 0) }
        nodes += extras
        nodes.append(again(width: stage.width, y: stage.againY))
        var scene = Scene(width: stage.width, height: stage.landedH) {
            Node.box("toss.toys", w: stage.width, h: stage.landedH) { nodes }.leftToRight().label(label)
        }
        .announcing([result, line].compactMap { $0 }.joined(separator: " "))
        .animating([
            .keys("toss.tag", [["t": 0, "scale": 0.92], ["t": 1, "scale": 1]], ms: 240, ease: "spring"),
            .keys("toss.again", [["t": 0, "opacity": 0, "scale": 0.86], ["t": 1, "opacity": 1, "scale": 1]], ms: 220, ease: "out").delay(ms: 60),
        ])
        .closing(afterMs: 5000)
        if let reaction { scene = scene.react(reaction) }
        return scene
    }

    /// Whether what came up comes with a line of the companion's, so the tag has room for it from the start. Asked before it lands, and without counting a streak.
    static func hasLine(_ toss: Toss) -> Bool {
        switch toss {
        case .coins: toss.called != nil
        case .dice(let sides, let rolls, _): (sides == 20 && (rolls == [20] || rolls == [1])) || (rolls.count == 2 && rolls[0] == rolls[1])
        case .hands: false
        }
    }

    /// A small scatter that belongs to a place in the layout, the same in both scenes and through Again.
    static func wobble(_ i: Int, _ salt: Int) -> Double {
        let n = (i &* 2_654_435_761 &+ salt &* 40503) & 0xFFFF
        return Double(n) / 65535 * 2 - 1
    }
}
