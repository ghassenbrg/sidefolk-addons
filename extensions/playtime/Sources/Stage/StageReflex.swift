import SidefolkExtensionKit

// Quick Paws' big button (ReflexView): the glossy Boop button with its paw, calm and dimmed while it waits, lit with rings of light at the signal, "Too soon!"
// at once for an early press, and the game's words on a plate under it. The signal is an animation delayed to one moment of the scene, and presses are timed
// from that moment by Sidefolk, from the input event's own time. A press on a key seat is the two players' (D96).
extension BoardDrawing {
    private static let reflexZone = 190.0

    func reflexPart(afterMs: Int?, windowMs: Int, wait: String, go: String, early: String, shows: String?, keys seats: [String]?) -> PartBlock {
        let armed = afterMs != nil && shows == nil
        let tooSoon = ctx.local.early
        let words = tooSoon ? early : shows ?? (armed ? wait : "…")
        let plate = reflexPlate(words, early: tooSoon, small: shows != nil && !tooSoon, caps: armed && !tooSoon ? (seats?.map { $0.uppercased() } ?? ["Space"]) : [])
        let height = Self.reflexZone + 10 + plate.height
        // Named by what it is: what the signal would have brought goes at once with an early press.
        let state = armed ? "armed" : "still"
        // A press ended the signal: it goes as it came.
        let went = !armed && ctx.buildUp && !tooSoon && ctx.previous?.reflexArmed == true
        if went { anims.append(.to("reflex.went", ["opacity": 0], ms: 180, ease: "out")) }
        var part = Node.box("reflex", w: Self.inner, h: height) {
            Node.box("reflex.zone.\(state)", w: Self.inner, h: Self.reflexZone) {
                Node.art("art/game-boop-\(armed ? "wait" : "rest").webp", x: (Self.inner - 170) / 2, y: 10, w: 170, h: 170)
                    .shadow(Paint.clear("#000000", 0.25), radius: 6, dx: 0, dy: 4)
                if armed { signal(go, id: "reflex.go", opacity: 0) }
                if went { signal(go, id: "reflex.went", opacity: 1) }
            }
            plate.node.at(0, Self.reflexZone + 10).id("reflex.plate.\(state)")
        }
        if let afterMs, armed {
            let moment = Double(afterMs)
            // The signal at its moment: essential (its fade is the game, with its sound), its small pop only for those who keep motion.
            anims.append(Anim.sequence([.wait(ms: moment), .sound("sounds/boop.wav"), .together([.to("reflex.go", ["opacity": 1], ms: 120, ease: "out"), .to("reflex.plate.armed", ["opacity": 0], ms: 120, ease: "out")])]).essential().named("reflex_signal"))
            anims.append(.sequence([.wait(ms: moment), .to("reflex.zone.armed", ["scale": 1.06], ms: 180, ease: "spring")]))
            timers.append(("reflex", moment + Double(windowMs)))
            if let seats {
                for key in seats { keys.append(StageKey(key: key, id: "seat_\(key)", seat: true, timedFromMs: moment)) }
            } else if !tooSoon {
                part = part.area("boop", label: words, hover: nil, press: nil, sound: "sounds/tap.wav", timedFromMs: moment)
                keys.append(StageKey(key: "space", id: "boop_space", area: "boop", timedFromMs: moment))
                keys.append(StageKey(key: "return", id: "boop_return", area: "boop", timedFromMs: moment))
            }
        }
        return PartBlock(part, height: height)
    }

    /// The lit button, its rings and the word: over the calm one, reading the same in every language.
    private func signal(_ go: String, id: String, opacity: Double) -> Node {
        let c = (x: Self.inner / 2, y: Self.reflexZone / 2)
        return Node.box(id, w: Self.inner, h: Self.reflexZone) {
            Node.ellipse(stroke: Paint.clear("#FF5FC8", 0.2), lineWidth: 6).at(c.x - 110, c.y - 110).size(220, 220)
            Node.ellipse(stroke: Paint.clear("#FF5FC8", 0.45), lineWidth: 7).at(c.x - 94.5, c.y - 94.5).size(189, 189)
            Node.art("art/game-boop-go.webp", x: c.x - 85, y: c.y - 85, w: 170, h: 170).shadow(Paint.clear("#FF5FC8", 0.8), radius: 22, dx: 0, dy: 0)
            Node.words(go, size: 34, weight: "black", color: Paint.white, align: "center", minScale: 0.5, y: c.y - 78 - 24, w: Self.inner, h: 48)
                .id(id + ".word").rotate(-6).shadow(.hex("#9A1F6E"), radius: 0, dx: 0, dy: 3)
        }.leftToRight().opacity(opacity)
    }

    /// What it says now, on a dark plate: steady with its keys, too soon with its mark, or the times once played.
    private func reflexPlate(_ words: String, early: Bool, small: Bool, caps: [String]) -> PartBlock {
        let size = small ? 16.0 : 20
        let capWidths = caps.map(Self.keyCapWidth)
        let extras = (early ? size * 1.25 + 6 : 0) + capWidths.reduce(0) { $0 + $1 + 6 }
        let room = Self.inner - 32 - extras
        let textW = Swift.min(TextFit.width(words, size: size, weight: "heavy"), room)
        let textH = TextFit.height(words, size: size, weight: "heavy", width: room)
        let height = Swift.max(textH, 16) + 18
        var x = (Self.inner - textW - extras) / 2
        var nodes: [Node] = [Node.rect(fill: Paint.clear("#15103A", 0.88), stroke: Paint.clear("#7A5CFF", 0.5), lineWidth: 1, corner: 16).size(Self.inner, height)]
        if early {
            let side = size * 1.25
            nodes.append(Node.symbol(Verdict.loss.symbol, color: .loss).symbolLook().at(x, (height - side) / 2).size(side, side))
            x += side + 6
        }
        nodes.append(Node.words(words, size: size, weight: "heavy", color: Paint.white, align: "center", lines: 4, minScale: 0.6, x: x, y: 9, w: textW, h: height - 18))
        x += textW + 6
        for (i, cap) in caps.enumerated() {
            nodes.append(keyCap(cap, light: true).at(x, (height - 16) / 2))
            x += capWidths[i] + 6
        }
        return PartBlock(.box(w: Self.inner, h: height) { nodes }, height: height)
    }

    var reflexFooter: String? {
        board.play { part -> String? in
            guard case .reflex(let after, _, _, let go, _, let shows, let seats) = part, after != nil, shows == nil else { return nil }
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
            return nil
        case .click("boop", _, let ms?):
            if ms < 0 {
                local.early = true
                return .play(.early)
            }
            return .play(.press(milliseconds: ms))
        case .key(let id, _, let ms?) where id.hasPrefix("seat_"):
            let key = String(id.dropFirst(5))
            if ms < 0 {
                local.early = true
                return .play(.earlyKey(key))
            }
            return .play(.pressKey(milliseconds: ms, key: key))
        default: return nil
        }
    }
}
