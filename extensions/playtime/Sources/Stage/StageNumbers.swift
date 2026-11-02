import Foundation
import SidefolkExtensionKit

// The number games' parts: a thermometer, a number field with its digit pad, and lives.
extension BoardDrawing {
    private static let cold = "#5AA9FF"

    private static func tint(_ v: Double) -> Color { .hex(v < 0.5 ? cold : v < 0.8 ? "#FFC46B" : "#FF8A3D") }
    private static func tintHex(_ v: Double) -> String { v < 0.5 ? cold : v < 0.8 ? "#FFC46B" : "#FF8A3D" }

    /// Cold to warm, with its words: a thermometer lying down, its bulb in the reading's colour, the tube filling toward Hot, ticks along it.
    /// Blue to orange, never a verdict's colours.
    func meter(_ value: Double, label: String?, low: String?, high: String?) -> PartBlock {
        let width = Self.inner, room = width - 20
        let labelH = TextFit.lineHeight(13, "semibold")
        let height = 10 + 26 + 4 + labelH + 10
        let tube = room - 20
        let fill = max(14, tube * min(max(value, 0), 1))
        let tint = Self.tint(value)
        // It rises from where it was, then rests at its true width.
        var before: Double?
        for case .play(.meter(let old, _, _, _)) in ctx.previous?.parts ?? [] { before = old }
        if ctx.fresh, let before, before != value {
            let from = max(14, tube * min(max(before, 0), 1)) / fill
            anims.append(.from("meter.fill", [["t": 0, "sx": from], ["t": 1, "sx": 1]], ms: 500, ease: "spring"))
        }
        return PartBlock(.box("meter", w: width, h: height) {
            Node.gameCard(corner: 16, alpha: 0.94, w: width, h: height).id("meter.card")
            Node.box("meter.tube", x: 10 + 20, y: 10 + 6, w: tube, h: 14) {
                Node.capsule().gradient([.hex(Self.cold), .hex("#B8D8FF"), .hex("#FFC46B"), .hex("#FF8A3D")], from: (0, 0.5), to: (1, 0.5)).id("meter.range").size(tube, 14).opacity(0.3)
                Node.box("meter.fill", w: fill, h: 14) {
                    Node.capsule().gradient([.hex(Self.cold), tint], from: (0, 0.5), to: (1, 0.5)).size(fill, 14)
                    Node.capsule(fill: Paint.clear("#FFFFFF", 0.35)).at(6, 2).size(max(fill - 12, 1), 3)
                }.anchor(0, 0.5)
                for i in 1..<10 { Node.rect(fill: Paint.clear("#FFFFFF", 0.6)).at(tube * Double(i) / 10, 4).size(1, 6) }
                Node.capsule(stroke: Paint.clear("#FFFFFF", 0.8), lineWidth: 1.5).at(0.75, 0.75).size(tube - 1.5, 12.5)
            }
            // The bulb, lit from its top corner: a plain gradient, as the frame's shine (D99).
            Node.ellipse(stroke: Paint.white, lineWidth: 2).gradient([Paint.clear("#FFFFFF", 0.7), tint], from: (0.3, 0.2), to: (0.7, 0.8)).id("meter.bulb").at(11, 11).size(24, 24)
                .shadow(Paint.clear(Self.tintHex(value), 0.5), radius: 4, dx: 0, dy: 0)
            Node.box("meter.words", x: 10, y: 10 + 26 + 4, w: room, h: labelH) {
                if let low {
                    Node.symbol("snowflake", color: .inkMuted).symbolLook(weight: "regular").at(0, (labelH - 12) / 2).size(12, 12)
                    Node.words(low, size: 11.5, weight: "regular", color: .inkMuted, design: "default", x: 16, w: room / 3 - 16, h: labelH)
                }
                if let label { Node.words(label, size: 13, weight: "semibold", align: "center", design: "default", x: room / 3, w: room / 3, h: labelH) }
                if let high {
                    Node.words(high, size: 11.5, weight: "regular", color: .inkMuted, align: "trailing", design: "default", x: room * 2 / 3, w: room / 3 - 16, h: labelH)
                    Node.symbol("flame.fill", color: .inkMuted).symbolLook(weight: "regular").at(room - 12, (labelH - 12) / 2).size(12, 12)
                }
            }
        }.label(label ?? "\(Int(value * 100))%"), height: height)
    }

    /// A number as the person's language groups it ("1,000,000", "1 000 000"), in its digits.
    static func grouped(_ n: Int) -> String { Format.integer(n) }

    /// A big number with a digit pad, and the guesses so far with where the answer lies (↑ higher, ↓ lower, ✓).
    func numberField(min: Int, max: Int, label: String?, history: [(Int, String)], locked: Bool) -> PartBlock {
        let width = Self.inner, room = width - 20
        var y = 10.0
        var nodes: [Node] = []
        if !history.isEmpty {
            // Fewer of them on a wide range (up to a million), so the row stays one line.
            let shown = Array(history.suffix(max >= 100_000 ? 4 : max >= 1000 ? 6 : 8))
            let chips = shown.map { guessChip($0.0, mark: $0.1) }
            let total = chips.reduce(-5.0) { $0 + $1.width + 5 }
            var x = (room - total) / 2 + 10
            for (i, chip) in chips.enumerated() {
                nodes.append(chip.node.id("guess.\(history.count - shown.count + i)").at(x, y))
                x += chip.width + 5
            }
            y += 20 + 10
        }
        // The field and its pad: left to right in every language, as a phone's pad is.
        let padW = 3 * 44 + 2 * 4.0, padH = 4 * 26 + 3 * 4.0
        let draft = ctx.local.draft
        let words = draft.isEmpty ? "?" : Int(draft).map(Self.grouped) ?? draft
        let wanted = TextFit.width(words, size: 40, weight: "heavy") + 16
        let fieldW = Swift.min(Swift.max(110, wanted), room - padW - 12)
        let startX = (room - fieldW - 12 - padW) / 2 + 10
        nodes.append(.box("number", x: startX, y: y, w: fieldW + 12 + padW, h: padH) {
            Node.rect(fill: .surfaceSunken, corner: 14).id("number.well").at(0, (padH - 64) / 2).size(fieldW, 64)
            Node.words(words, size: 40, weight: "heavy", color: draft.isEmpty ? .inkFaint : .ink, align: "center", minScale: 0.5, x: 8, y: (padH - 64) / 2, w: fieldW - 16, h: 64)
                .textLook(tabular: true).label(label ?? L("Your guess"))
            digitPad(locked: locked).at(fieldW + 12, 0)
        }.leftToRight())
        y += padH + 10
        if let label {
            let h = TextFit.lineHeight(11.5)
            nodes.append(Node.words(label, size: 11.5, weight: "regular", color: .inkMuted, align: "center", design: "default", x: 10, y: y, w: room, h: h))
            y += h + 10
        }
        if !locked {
            keys.append(StageKey(key: "digit", id: "digit"))
            keys.append(StageKey(key: "delete", id: "draft_delete"))
            keys.append(StageKey(key: "return", id: "draft_return"))
        }
        return PartBlock(.box("field", w: width, h: y) {
            Node.gameCard(corner: 16, alpha: 0.92, w: width, h: y).id("field.card")
            nodes
        }, height: y)
    }

    private func guessChip(_ value: Int, mark: String) -> (node: Node, width: Double) {
        let right = mark == "right"
        let words = Self.grouped(value)
        let w = TextFit.width(words, size: 11.5, weight: "semibold") + 2 + 12 + 14
        let symbol = mark == "higher" ? "arrow.up" : mark == "lower" ? "arrow.down" : "checkmark"
        let ink: Color = right ? Paint.white : .ink
        return (Node.box(w: w, h: 20) {
            Node.capsule(fill: right ? .win : .surfaceSunken).size(w, 20)
            Node.words(words, size: 11.5, weight: "semibold", color: ink, align: "trailing", design: "default", x: 7, w: w - 14 - 14, h: 20).textLook(tabular: true)
            Node.symbol(symbol, color: ink).symbolLook().at(w - 7 - 12, 4).size(12, 12)
        }.leftToRight(), w)
    }

    /// 1–9, then ⌫ 0 ↵.
    private func digitPad(locked: Bool) -> Node {
        let rows = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], ["delete", "0", "return"]]
        return Node.box("pad", w: 3 * 44 + 2 * 4.0, h: 4 * 26 + 3 * 4.0) {
            for (r, row) in rows.enumerated() {
                for (c, k) in row.enumerated() {
                    Node.box("pad.\(k)", x: Double(c) * 48, y: Double(r) * 30, w: 44, h: 26) {
                        Node.rect(fill: k == "return" ? .accent : .surfaceSunken, corner: 6).size(44, 26)
                        if k == "delete" { Node.symbol("delete.left", color: .ink).symbolLook().at(13, 4).size(18, 18) }
                        else if k == "return" { Node.symbol("return", color: .onAccent).symbolLook().at(13, 4).size(18, 18) }
                        else { Node.words(k, size: 14, weight: "semibold", align: "center", w: 44, h: 26) }
                    }
                    .area("digit", value: k, label: k == "delete" ? L("Delete") : k == "return" ? L("Your guess") : k, disabled: locked, hover: nil, press: AreaLook(scale: 0.95), sound: "sounds/tap.wav")
                    .opacity(locked ? 0.5 : 1)
                }
            }
        }
    }

    /// Balloons or hearts left: balloons are the pack's picture tinted one colour each; the ones lost shrink to faint grey (a heart's
    /// outline). `tint` is a stencil, so a balloon's own light and shade go with it: drawn with its highlight on top, the plain gradient shine (D99).
    func lives(total: Int, left: Int, symbol: String) -> PartBlock {
        let balloon = symbol == "balloon"
        let hue = [Paint.coral, Paint.sun, Paint.blue, Paint.green, Paint.purple]
        let side = balloon ? 30.0 : 22.0, gap = balloon ? 2.0 : 4.0
        return PartBlock(.box("lives", w: Self.inner, h: side) {
            for i in 0..<total {
                let kept = i < left
                if balloon {
                    Node.image("art/game-balloon.png", tint: kept ? hue[i % 5] : .inkFaint).id("life.\(i)").at(Double(i) * (side + gap), 0).size(side, side)
                        .anchor(0.5, 1).scale(kept ? 1 : 0.6).rotate(kept ? Double(i % 3 - 1) * 5 : 0).opacity(kept ? 1 : 0.3)
                } else {
                    Node.symbol(kept ? "heart.fill" : "heart", color: kept ? hue[i % 5] : Color.inkFaint.tuned(alpha: 0.5)).symbolLook(weight: "regular")
                        .id("life.\(i)").at(Double(i) * (side + gap), 0).size(side, side).scale(kept ? 1 : 0.8)
                }
            }
        }.label(L("{left} of {total} left", ["left": left, "total": total])), height: side)
    }
}
