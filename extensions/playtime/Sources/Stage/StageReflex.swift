import SidefolkExtensionKit

// Quick Paws' machine: the painted body on its felt mat, its lamp on top, the words live on its plate, and the coral dome that sinks when pressed. Three looks that can't be mistaken: waiting
// (lamp dull, dome dimmed, "Wait for it…"), the signal (lamp lit, the dome bright in a ring of light, "Boop!" large on the plate), the result (lamp dull, the times on the plate, nothing to
// press). An early press says so at once. The signal is an animation delayed to one moment of the scene, and presses are timed from that moment by Sidefolk, from the input event's own
// time. A press on a key seat is the two players' (D96).
extension BoardDrawing {
    /// The machine's pieces, read off its art at this size.
    private enum Machine {
        static let bodyW = 264.0, bodyH = 300.0, lampW = 50.0, lampH = 44.0, top = 58.0
        /// To the right of the mat, as 05 draws it: the companion stands beside it.
        static let bodyX = 116.0
        static let plate = (x: bodyX + 48, y: top + 32, w: 174.0, h: 67.0)
        static let dome = (x: bodyX + 134, y: top + 178, side: 149.0)
        static let lampX = bodyX + (bodyW - lampW) / 2
        /// The mat, wider and deeper than the machine's foot.
        static let matY = 270.0, matH = 158.0
    }
    private static let domeDim = 0.82, domeSink = 7.0

    func reflexPart(afterMs: Int?, windowMs: Int, wait: String, go: String, early: String, shows: String?, keys seats: [String]?) -> PartBlock {
        let armed = afterMs != nil && shows == nil
        let tooSoon = ctx.local.early
        let words = tooSoon ? early : shows ?? (armed ? wait : "…")
        // A press ended the signal: its light goes as it came, and the dome stays down until the verdict.
        let went = !armed && ctx.buildUp && !tooSoon && ctx.previous?.reflexArmed == true
        if went { anims.append(.stagger(["reflex.went.under", "reflex.went.over"], stepMs: 0, ["opacity": 0], ms: 200, ease: "out")) }
        // Only a press sinks it: a round that ran out of time leaves it where it was.
        let sunk = ctx.local.boopPressed || tooSoon
        let c = (x: Machine.dome.x, y: Machine.dome.y), hit = 178.0
        var press = Node.box("reflex.press", x: c.x - hit / 2, y: c.y - hit / 2, w: hit, h: hit) {
            Node.art("art/boop-dome.webp", x: (hit - Machine.dome.side) / 2, y: (hit - Machine.dome.side) / 2 + (sunk ? Self.domeSink : 0), w: Machine.dome.side, h: Machine.dome.side)
                .id("reflex.dome").anchor(0.5, 0.5).scale(sunk ? 0.97 : 1).opacity(sunk && !tooSoon ? 1 : Self.domeDim)
        }
        if let afterMs, armed {
            let moment = Double(afterMs)
            // The signal at its moment: essential (its fade is the game, with its sound), its small pop only for those who keep motion.
            anims.append(Anim.sequence([.wait(ms: moment), .sound("sounds/boop.wav"), .together([
                .to("reflex.go.under", ["opacity": 1], ms: 90, ease: "out"), .to("reflex.go.over", ["opacity": 1], ms: 90, ease: "out"),
                .to("reflex.dome", ["opacity": 1], ms: 90, ease: "out"), .to("reflex.waiting", ["opacity": 0], ms: 90, ease: "out"),
            ])]).essential().named("reflex_signal"))
            anims.append(.sequence([.wait(ms: moment), .keys("reflex.go.word", [["t": 0, "scale": 0.7], ["t": 1, "scale": 1]], ms: 220, ease: "spring")]))
            timers.append(("reflex", moment + Double(windowMs)))
            if let seats {
                for key in seats { keys.append(StageKey(key: key, id: "seat_\(key)", seat: true, timedFromMs: moment)) }
            } else if !tooSoon {
                press = press.area("boop", label: wait, hover: AreaLook(scale: 1.012), press: AreaLook(scale: 0.97, dy: Self.domeSink), sound: "sounds/tap.wav", timedFromMs: moment)
                keys.append(StageKey(key: "space", id: "boop_space", area: "boop", timedFromMs: moment))
                keys.append(StageKey(key: "return", id: "boop_return", area: "boop", timedFromMs: moment))
            }
        }
        let part = Node.box("reflex", w: Self.inner, h: playRoom) {
            Node.felt("reflex.mat", x: -6, y: Machine.matY, w: Self.inner + 12, h: Machine.matH)
            Node.art("art/boop-body.webp", x: Machine.bodyX, y: Machine.top, w: Machine.bodyW, h: Machine.bodyH).id("reflex.body")
                .shadow(Paint.clear("#3A2A55", 0.25), radius: 6, dx: 0, dy: 4)
            Node.art("art/boop-lamp-off.webp", x: Machine.lampX, y: Machine.top - 36, w: Machine.lampW, h: Machine.lampH).id("reflex.lamp")
            reflexPlateWords(words, early: tooSoon, small: shows != nil && !tooSoon).id(armed ? "reflex.waiting" : "reflex.said")
            if armed { signalUnder(id: "reflex.go.under", opacity: 0) }
            if went { signalUnder(id: "reflex.went.under", opacity: 1) }
            press
            if armed { signalOver(go, id: "reflex.go.over", opacity: 0) }
            if went { signalOver(go, id: "reflex.went.over", opacity: 1) }
            if let seats, armed { seatCaps(seats) }
            slotRow(y: playRoom - 38, height: 38)
        }
        return PartBlock(part, height: playRoom)
    }

    /// A ring of light round the dome, in the socket's place: under the dome, over the body.
    private func signalUnder(id: String, opacity: Double) -> Node {
        let c = (x: Machine.dome.x, y: Machine.dome.y)
        return Node.box(id, w: Self.inner, h: playRoom) {
            Node.ellipse(fill: Paint.clear("#FFD65C", 0.82)).at(c.x - 89, c.y - 89).size(178, 178).shadow(Paint.clear("#FFC93C", 0.9), radius: 24, dx: 0, dy: 0)
            Node.ellipse(stroke: Paint.clear("#FFF4C2", 0.9), lineWidth: 4).at(c.x - 104, c.y - 104).size(208, 208)
            Node.ellipse(stroke: Paint.clear("#FFC93C", 0.55), lineWidth: 5).at(c.x - 119, c.y - 119).size(238, 238)
        }.opacity(opacity)
    }

    /// The lamp lit, and the word painted large on a plate glowing warm: navy on butter by day and by night, because the plate itself is the same.
    private func signalOver(_ go: String, id: String, opacity: Double) -> Node {
        let p = Machine.plate
        return Node.box(id, w: Self.inner, h: playRoom) {
            Node.art("art/boop-lamp-on.webp", x: Machine.lampX, y: Machine.top - 36, w: Machine.lampW, h: Machine.lampH).shadow(Paint.clear("#FFB020", 0.95), radius: 16, dx: 0, dy: 0)
            Node.capsule(fill: Paint.clear("#FFD65C", 0.72)).at(p.x + 9, p.y + 12).size(p.w - 18, p.h - 22).shadow(Paint.clear("#FFC93C", 0.8), radius: 10, dx: 0, dy: 0)
            Node.words(go, size: 38, weight: "black", color: Paint.navy, align: "center", minScale: 0.5, x: p.x + 12, y: p.y + 8, w: p.w - 24, h: p.h - 14).id("reflex.go.word").anchor(0.5, 0.5)
        }.opacity(opacity)
    }

    /// What it says now, on the plate: wait, too soon with its mark, or the times once played.
    private func reflexPlateWords(_ words: String, early: Bool, small: Bool) -> Node {
        let p = Machine.plate
        let size = small ? 16.0 : early ? 22 : 20
        let mark = early ? size * 1.1 + 5 : 0
        let room = p.w - 28 - mark
        let textW = Swift.min(TextFit.width(words, size: size, weight: "heavy"), room)
        let x = p.x + (p.w - textW - mark) / 2
        return .box(x: 0, y: 0, w: Self.inner, h: Machine.top + 110) {
            if early {
                Node.symbol(Verdict.loss.symbol, color: .loss).symbolLook().at(x, p.y + (p.h - size * 1.1) / 2 - 2).size(size * 1.1, size * 1.1)
            }
            Node.words(words, size: size, weight: "heavy", color: Paint.navy, align: "center", lines: small ? 2 : 1, minScale: 0.55, x: x + mark, y: p.y + 10, w: textW, h: p.h - 22)
        }
    }

    /// Two people: their keys, each on their side of the machine, on the mat.
    private func seatCaps(_ seats: [String]) -> Node {
        let side = 32.0, y = Machine.matY + Machine.matH - 44
        // Each key on its own side of the keyboard, in any language.
        return Node.box("reflex.seats", w: Self.inner, h: playRoom) {
            for (i, seat) in seats.enumerated() {
                Node.box("reflex.seat.\(i)", x: i == 0 ? 6 : Self.inner - side - 6, y: y, w: side, h: side) {
                    Node.rect(fill: Paint.card, stroke: Paint.players[i], lineWidth: 2, corner: 8).size(side, side)
                    Node.words(seat.uppercased(), size: 15, weight: "heavy", align: "center", w: side, h: side)
                }
            }
        }.leftToRight()
    }

    var reflexFooter: String? {
        board.play { part -> String? in
            guard case .reflex(_, _, _, let go, _, _, let seats) = part else { return nil }
            if let seats, let names = board.scorePart?.players {
                return L("{a}: {ka} · {b}: {kb}", ["a": names[0], "ka": seats[0].uppercased(), "b": names[1], "kb": seats[1].uppercased()])
            }
            return L("Space: {go}", ["go": go])
        }
    }

    /// A press before its moment comes with `ms` below 0: too soon, said at once. The build-up's moment ends it.
    static func reflexMove(_ move: SurfaceMove, board: Board, local: inout LocalParts) -> StageAction? {
        guard board.hasReflex else { return nil }
        switch move {
        case .next:
            local.early = false
            local.boopPressed = false
            return nil
        case .click("boop", _, let ms?):
            if ms < 0 {
                local.early = true
                return .play(.early)
            }
            local.boopPressed = true
            return .play(.press(milliseconds: ms))
        case .key(let id, _, let ms?) where id.hasPrefix("seat_"):
            let key = String(id.dropFirst(5))
            if ms < 0 {
                local.early = true
                return .play(.earlyKey(key))
            }
            local.boopPressed = true
            return .play(.pressKey(milliseconds: ms, key: key))
        default: return nil
        }
    }
}
