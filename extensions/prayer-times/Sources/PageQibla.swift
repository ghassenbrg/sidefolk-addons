import Foundation
import SidefolkExtensionKit

/// Qibla: the bearing from the chosen place, clockwise from true north. A Mac has no compass, so nothing here says it is pointing anywhere.
@MainActor
enum QiblaPage {
    static func sections(_ ctx: Context) -> [Section] {
        guard let place = ctx.snapshot.place else { return [NoorPage.unavailable(ctx)].compactMap { $0 } }
        guard let bearing = ctx.snapshot.qibla else {
            return [NoorPage.status(ctx, symbol: "safari", title: ctx.model.load == .loading ? L("Finding the bearing…") : L("No bearing for this place yet"), detail: ctx.model.load == .loading ? place.label : L("It needs one connection, then it is saved. {why}", ["why": Words.problem(ctx.model.problem)]),
                                    buttons: ctx.model.load == .loading ? [] : [("retry", L("Try again"), true, .tool("refresh")), ("place", L("Choose another place"), false, .go(Go(set: ["sheet": "prefs", "section": "place"], push: true)))])]
        }
        var out: [Section] = []
        if let note = NoorPage.offlineNote(ctx) { out.append(Section(nil, [note], wide: true)) }
        let scene = ctx.narrow ? narrow(ctx, bearing, place) : wide(ctx, bearing, place)
        out.append(Section(nil, [.scene(PageSceneBlock(scene, actions: ["refresh": ("refresh", [:])], acts: ["place": .go(Go(set: ["sheet": "prefs", "section": "place"], push: true))]))], wide: true))
        // What is copied hangs on a button of Sidefolk's own, which says so (D105): a scene's area can't copy, so this one stands under the composition.
        out.append(Section(nil, [.action(Action(L("Copy bearing"), act: .copy(L("Qibla from {place}: {degrees}° clockwise from true north", ["place": place.label, "degrees": "\(bearing.rounded)"])), symbol: "doc.on.doc"))], wide: true))
        return out
    }

    /// Places in P05's own numbers: a board's x less 245, its y less 175.
    private static func wide(_ ctx: Context, _ bearing: QiblaBearing, _ place: Place) -> Scene {
        let r = ctx.ruler, w = ctx.width
        let rightX = r.u(686), rightW = w - rightX - r.u(21)
        return Scene(width: w, height: r.u(796)) {
            framed(bearing, place, w: r.u(650)).at(r.u(25), r.u(6))
            panel(ctx, bearing, place, w: rightW, r: r).at(rightX, r.u(15))
            coordinates(place, w: rightW, r: r).at(rightX, r.u(670))
        }
    }

    /// One column in the same materials, each part at its own proportions for the width there is.
    private static func narrow(_ ctx: Context, _ bearing: QiblaBearing, _ place: Place) -> Scene {
        let margin = 16.0, inner = ctx.width - margin * 2
        let r = Ruler(width: inner / 585 * 1290)
        let frameH = inner * 776 / 650
        let panelH = r.u(630), cardH = r.u(115), gap = 12.0
        return Scene(width: ctx.width, height: frameH + panelH + cardH + gap * 2 + 8) {
            framed(bearing, place, w: inner).at(margin, 4)
            panel(ctx, bearing, place, w: inner, r: r).at(margin, frameH + gap)
            coordinates(place, w: inner, r: r).at(margin, frameH + gap * 2 + panelH)
        }
    }

    /// The compass in the square arch, in the page's one big panel, with the strip of quiet lattice below it. Its height follows its width.
    private static func framed(_ bearing: QiblaBearing, _ place: Place, w: Double) -> Node {
        let k = w / 650, h = 776 * k
        let frameW = 635 * k, frameH = 654 * k, frameX = 8 * k, frameY = 10 * k
        let side = frameW * 0.905
        return Node.group {
            Node.rect(fill: Noor.surface, stroke: Noor.inlay, lineWidth: 1, corner: 18 * k).size(w, h)
            // Below the arch the lattice only whispers, and comes in from the corner.
            Node.group {
                Node.lattice(w, 122 * k, corner: 0).opacity(0.1)
                Node.latticeEdge(h: 122 * k, strip: 58 * k, curve: 58 * k, drop: 100 * k, flipped: true).at(0, 0)
            }
            .size(w - 2, 122 * k).at(1, h - 123 * k).corner(17 * k).clip()
            Node.frame(.square, frameW, frameH, corner: 12 * k).at(frameX, frameY)
            Node.rect(stroke: Noor.inlay, lineWidth: 1.4, corner: 12 * k).size(frameW, frameH).at(frameX, frameY)
            // The arch's crown stands up through the panel's edge.
            Node.path("M \(n(w * 0.5 - 30 * k)) \(n(frameY + 1)) C \(n(w * 0.5 - 14 * k)) \(n(frameY - 3 * k)) \(n(w * 0.5 - 6 * k)) \(n(frameY - 8 * k)) \(n(w * 0.5)) \(n(-5 * k)) C \(n(w * 0.5 + 6 * k)) \(n(frameY - 8 * k)) \(n(w * 0.5 + 14 * k)) \(n(frameY - 3 * k)) \(n(w * 0.5 + 30 * k)) \(n(frameY + 1)) Z", fill: Noor.surface, stroke: Noor.inlay, lineWidth: 1.2).size(w, h).at(0, 0)
            CompassScene.large(bearing.degrees, side: side).at(frameX + (frameW - side) / 2, frameY + frameH * 0.535 - side / 2).leftToRight()
                .label(L("{degrees} degrees clockwise from true north, from {place}.", ["degrees": "\(bearing.rounded)", "place": place.label]))
        }
        .size(w, h)
    }

    private static func panel(_ ctx: Context, _ bearing: QiblaBearing, _ place: Place, w: Double, r: Ruler) -> Node {
        let h = r.u(630), pad = r.u(28)
        let placeW = r.u(216), placeX = w - r.u(22) - placeW
        let blockW = r.u(290), ruleX = r.u(297), noteX = r.u(328), noteW = w - noteX - r.u(22)
        return Node.group {
            Node.panel(w, h, corner: r.u(20))
            Node.say(L("Qibla"), pad, r.u(26), placeX - pad, r.u(50), size: r.f(38, min: 20), weight: "semibold")
            Node.say(L("Direction from your location"), pad, r.u(74), placeX - pad - 6, r.u(32), size: r.f(21, min: 12.5), color: Noor.muted)
            // Where it is from. No menu here: the one way to change a place is the button under it.
            pin(size: r.f(24, min: 15)).at(placeX + r.u(8), r.u(34))
            Node.say(placeLine(place), placeX + r.u(38), r.u(30), placeW - r.u(38), r.u(34), size: r.f(19.5, min: 12.5))
            Node.pill("place", label: L("Choose another place"), x: placeX, y: r.u(74), w: placeW, h: r.u(42), size: r.f(16, min: 11.5))
            Node.rect(fill: Noor.hairline).size(w - r.u(44), 1).at(r.u(22), r.u(135))

            Node.gilded("\(bearing.rounded)°", 0, r.u(156), blockW, r.u(128), size: r.f(100, min: 54), weight: "semibold", tabular: true).leftToRight()
            Node.say(L("From true north"), 0, r.u(272), blockW, r.u(38), size: r.f(25, min: 14), color: Noor.warm, align: "center")
            Node.pill("refresh", label: L("Check again"), x: r.u(27), y: r.u(332), w: r.u(238), h: r.u(42), symbol: "arrow.clockwise", size: r.f(17, min: 12))
            Node.rect(fill: Noor.hairline).size(1, r.u(154)).at(ruleX, r.u(175))
            Node.say(L("North-up direction"), noteX, r.u(172), noteW, r.u(30), size: r.f(21, min: 13), weight: "semibold")
            Node.say(L("The diagram shows a bearing from your selected place."), noteX, r.u(204), noteW, r.u(54), size: r.f(17.5, min: 11.5), color: Noor.muted, lines: 2)
            Node.say(L("This Mac view does not sense which way you are facing."), noteX, r.u(266), noteW, r.u(50), size: r.f(16, min: 11), color: Noor.muted, lines: 2)

            placeCard(ctx, bearing, place, w: w - r.u(22), r: r).at(r.u(11), r.u(397))
        }
        .size(w, h)
    }

    private static func placeCard(_ ctx: Context, _ bearing: QiblaBearing, _ place: Place, w: Double, r: Ruler) -> Node {
        let h = r.u(221), textX = r.u(94), textW = w - textX - r.u(146)
        return Node.group {
            Node.rect(fill: Noor.quiet).size(w, h).corner(r.u(18))
            Node.group { Node.latticeEdge(h: h, strip: r.u(48), curve: r.u(90), drop: r.u(92)).at(w - r.u(138), 0) }
                .size(w, h).corner(r.u(18)).clip().opacity(0.9)
            Node.rect(stroke: Noor.inlay, lineWidth: 1.2, corner: r.u(18)).size(w, h)
            pin(size: r.f(32, min: 18), filled: true).at(r.u(32), r.u(28))
            Node.say(placeLine(place), textX, r.u(18), textW, r.u(34), size: r.f(20, min: 13), weight: "medium")
            Node.say(String(format: "%.4f, %.4f", place.latitude, place.longitude), textX, r.u(52), textW, r.u(30), size: r.f(19, min: 12), color: Noor.muted, tabular: true)
            Node.say(L("Source: AlAdhan. Fetched {when}.", ["when": Format.dateTime(bearing.fetched, timeZone: ctx.zone)]), textX, r.u(84), textW, r.u(30), size: r.f(16, min: 11), color: Noor.muted)
            Node.rect(fill: Noor.hairline).size(w - r.u(40), 1).at(0, r.u(129))
            Node.symbol("info.circle", color: Noor.text).size(r.f(30, min: 17), r.f(30, min: 17)).at(r.u(30), r.u(160))
            Node.say(L("Qibla bearings are calculated from your selected place using AlAdhan. To use one, line up a real compass with true north."), textX, r.u(136), w - textX - r.u(62), r.u(76), size: r.f(16, min: 11), color: Noor.muted, lines: 3)
        }
        .size(w, h)
    }

    private static func coordinates(_ place: Place, w: Double, r: Ruler) -> Node {
        let h = r.u(115), x = r.u(82), size = r.f(16, min: 11), lineW = w - x - r.u(16)
        return Node.group {
            Node.panel(w, h, corner: r.u(18))
            Node.symbol("globe", color: Noor.text).size(r.f(28, min: 16), r.f(28, min: 16)).at(r.u(28), r.u(14))
            Node.runs([(L("Geographic coordinates"), Noor.text, "semibold"), (" " + L("(shared with source)"), Noor.muted, nil)], size: size, color: Noor.text, align: "leading").size(lineW, r.u(28)).at(x, r.u(13))
            Node.runs([(L("Latitude") + "  ", Noor.muted, nil), (hemisphere(place.latitude, positive: L("N", context: "compass"), negative: L("S", context: "compass")), Noor.text, nil), ("   |   ", Noor.hairline, nil),
                       (L("Longitude") + "  ", Noor.muted, nil), (hemisphere(place.longitude, positive: L("E", context: "compass"), negative: L("W", context: "compass")), Noor.text, nil)], size: size, color: Noor.text, align: "leading").size(lineW, r.u(28)).at(x, r.u(46))
            Node.runs([(L("Source") + "  ", Noor.muted, nil), ("AlAdhan (aladhan.com)", Noor.text, nil)], size: size, color: Noor.text, align: "leading").size(lineW, r.u(28)).at(x, r.u(75))
        }
        .size(w, h)
    }

    private static func placeLine(_ place: Place) -> String { place.label + (place.country.map { ", \($0)" } ?? "") }

    private static func hemisphere(_ value: Double, positive: String, negative: String) -> String {
        String(format: "%.4f° ", abs(value)) + (value < 0 ? negative : positive)
    }

    /// The board's pin: a drop with a hole, or its outline.
    private static func pin(size: Double, filled: Bool = false) -> Node {
        let w = size * 0.74, ink = filled ? Color.adaptive(light: "#7354B8", dark: "#B8B0F2") : Noor.text
        let drop = "M \(n(w / 2)) \(n(size)) C \(n(w * 0.2)) \(n(size * 0.72)) 0 \(n(size * 0.52)) 0 \(n(w / 2)) C 0 \(n(w * 0.22)) \(n(w * 0.22)) 0 \(n(w / 2)) 0 C \(n(w * 0.78)) 0 \(n(w)) \(n(w * 0.22)) \(n(w)) \(n(w / 2)) C \(n(w)) \(n(size * 0.52)) \(n(w * 0.8)) \(n(size * 0.72)) \(n(w / 2)) \(n(size)) Z"
        let hole = w * 0.36
        return Node.group {
            if filled {
                Node.path(drop, fill: ink).size(w, size).at(0, 0)
                Node.ellipse(fill: Noor.quiet).size(hole, hole).at((w - hole) / 2, w / 2 - hole / 2)
            } else {
                Node.path(drop, stroke: ink, lineWidth: 1.5).size(w, size).at(0, 0)
                Node.ellipse(stroke: ink, lineWidth: 1.5).size(hole, hole).at((w - hole) / 2, w / 2 - hole / 2)
            }
        }
        .size(w, size)
    }
}

extension Node {
    /// Words painted in gold, lightest at their top. A scene's words take one colour, so this is the same words in slices, each its own shade.
    static func gilded(_ words: String, _ x: Double, _ y: Double, _ w: Double, _ h: Double, size: Double, weight: String = "semibold", tabular: Bool = false, bands: Int = 9) -> Node {
        let top = (light: (0xA8, 0x74, 0x2A), dark: (0xFF, 0xF4, 0xDF)), foot = (light: (0x7A, 0x4C, 0x10), dark: (0xEA, 0xB0, 0x6C))
        func mix(_ a: (Int, Int, Int), _ b: (Int, Int, Int), _ t: Double) -> String {
            func one(_ p: Int, _ q: Int) -> Int { Int((Double(p) + (Double(q) - Double(p)) * t).rounded()) }
            return String(format: "#%02X%02X%02X", one(a.0, b.0), one(a.1, b.1), one(a.2, b.2))
        }
        let slice = h / Double(bands)
        return Node.group {
            for i in 0..<bands {
                // The ink sits in the middle of its box: the shade changes across that and holds beyond it.
                let t = max(0, min(1, (Double(i) / Double(bands - 1) - 0.18) / 0.64))
                Node.group {
                    Node.say(words, 0, -slice * Double(i), w, h, size: size, weight: weight, color: .adaptive(light: mix(top.light, foot.light, t), dark: mix(top.dark, foot.dark, t)), align: "center", tabular: tabular)
                }
                .size(w, slice + 0.5).at(0, slice * Double(i)).clip()
            }
        }
        .size(w, h).at(x, y)
    }

    /// The lattice corner of a panel: top right, or flipped for the top left. `h` lets it run on down a side. A scene mirrors its places in Arabic and not its pictures, so this turns with the side it lands on.
    static func spandrel(_ w: Double, _ h: Double, flipped: Bool = false) -> Node {
        let art = Node.image("art/spandrel-l.png", dark: "art/spandrel-d.png", fit: "fill").size(w, h)
        return flipped != Language.rightToLeft ? art.scale(x: -1, y: 1) : art
    }

    /// The lattice coming in over a corner and running on down the edge: a piece of the same painted frame, with its inlay where the curve lands. Top right, or flipped for the left.
    static func latticeEdge(h: Double, strip: Double, curve: Double, drop: Double, flipped: Bool = false) -> Node {
        Node.group {
            Node.spandrel(curve, drop, flipped: flipped).at(flipped ? strip : 0, 0)
            Node.group { Node.image("art/frame-square-l.jpg", dark: "art/frame-square-d.jpg", fit: "fill").size(h * 3.4, h * 3.4).at(-h * 0.1, -h * 0.1) }
                .size(strip, h).at(flipped ? 0 : curve, 0).clip()
            Node.rect(fill: Noor.inlay).size(1.2, h - drop).at(flipped ? strip : curve, drop)
        }
        .size(curve + strip, h)
    }

    /// Small rule, rosette, small rule: the ornament under a Name.
    static func ornament(cx: Double, cy: Double, rule: Double, rosette: Double, color: Color) -> Node {
        let w = rule * 2 + rosette * 2, x = w / 2
        return Node.group {
            Node.rect(fill: color).size(rule, 1).at(0, rosette / 2)
            Node.rect(fill: color).size(rule, 1).at(w - rule, rosette / 2)
            Node.path("M \(n(rule)) \(n(rosette / 2 - 3)) L \(n(rule + 5)) \(n(rosette / 2 + 0.5)) L \(n(rule)) \(n(rosette / 2 + 4)) Z M \(n(w - rule)) \(n(rosette / 2 - 3)) L \(n(w - rule - 5)) \(n(rosette / 2 + 0.5)) L \(n(w - rule)) \(n(rosette / 2 + 4)) Z", fill: color).size(w, rosette).at(0, 0)
            Node.image("art/rosette-l.png", dark: "art/rosette-d.png").size(rosette, rosette).at(x - rosette / 2, 0).leftToRight()
        }
        .size(w, rosette).at(cx - x, cy - rosette / 2)
    }
}
