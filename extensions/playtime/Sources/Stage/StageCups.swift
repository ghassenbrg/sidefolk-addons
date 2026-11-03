import Foundation
import SidefolkExtensionKit

// Which Cup?'s table: upside-down paper tumblers on a felt mat, their numbers on plates under them, and the cups themselves are what you click. The gem is shown under its cup, the cup
// comes down, the cups swap in turn with a breath between swaps, one passing in front and the other behind, never through. A pick presses, then the picked cup lifts slowly; if the gem
// isn't there, the cup that hides it lifts next. Only then the words, the score and the reaction (D75). The shuffle is essential, so it moves under Reduce Motion: it is the game.
// The table reads the same in every language.
extension BoardDrawing {
    /// A cup's place on the mat, for a mat this wide.
    private struct CupTable {
        let count: Int
        let room: Double
        var matH: Double { 148 }
        var matY: Double { room - BoardDrawing.slotHeight - 12 - matH }
        var slot: Double { (BoardDrawing.inner - 12) / Double(count) }
        var cupW: Double { count <= 3 ? 96 : count == 4 ? 80 : 66 }
        var cupH: Double { (cupW * 457 / 360).rounded() }
        /// Where a cup's rim stands on the mat.
        var floor: Double { matY + matH - 50 }
        var restY: Double { floor - cupH }
        var lift: Double { cupH * 0.78 }
        func centre(_ at: Double) -> Double { 6 + slot * (at + 0.5) }
        func cupX(_ at: Double) -> Double { centre(at) - cupW / 2 }
        var shadowW: Double { cupW * 0.86 }
        func shadowX(_ at: Double) -> Double { centre(at) - shadowW / 2 }
    }

    /// The gem's moment before a shuffle: the cups settle, one lifts to show the gem, it stays a moment, it comes down.
    private static let settleMs = 300.0, showLiftMs = 350.0, showMs = 850.0, lowerMs = 400.0
    static let cupsOpenMs = Int(settleMs + showLiftMs + showMs + lowerMs)
    /// A breath between two swaps, so each one reads as its own.
    static let swapRestMs = 80
    private static let swapSamples = 8

    /// How long a pick's lift plays: the press, the picked cup rising, and when the gem wasn't under it, a look at the empty mat and the other lift.
    private static let pressMs = 220.0, liftMs = 480.0, holdEmptyMs = 380.0, holdGemMs = 520.0
    static func cupsLiftMs(_ next: Board) -> Int {
        let found = next.play { part -> Bool? in
            if case .cups(_, _, _, _, let picked, _, let gem, _) = part { picked == nil || picked == gem } else { nil }
        } ?? true
        return Int(pressMs + liftMs + holdGemMs + (found ? 0 : holdEmptyMs + liftMs))
    }

    /// Which cups stand lifted once a round is shown: the pick and the gem's, or all of them when the gem was in no cup.
    private static func lifted(count: Int, picked: Int?, gem: Int?) -> [Int] {
        guard let gem else { return Array(0..<count) }
        return picked == nil || picked == gem ? [gem] : [picked!, gem]
    }

    func cupsPart(count: Int, hide: Int?, swaps: [[Int]], swapMs: Int, picked: Int?, revealed: Bool, gem: Int?, locked: Bool) -> PartBlock {
        let table = CupTable(count: count, room: playRoom)
        let shuffling = playing
        // The build-up lifts them: its board knows where the gem is, and says nothing yet.
        let lifting = ctx.buildUp && locked && !revealed
        let shows = revealed || lifting
        // Where each cup ends: a node is named by that place, so it lies where it did on the scene after, and starts where the cup starts.
        var ends = Array(0..<count)
        if shuffling {
            for swap in swaps {
                guard let a = ends.firstIndex(of: swap[0]), let b = ends.firstIndex(of: swap[1]) else { continue }
                (ends[a], ends[b]) = (swap[1], swap[0])
            }
        }
        let open = !locked && !revealed && !shuffling
        // A round shown is named apart: the next shuffle's cups start from a different place, and must not glide there.
        let cupId = { (place: Int) in shows ? "cup.up.\(place)" : "cup.\(place)" }
        let up = revealed ? Self.lifted(count: count, picked: picked, gem: gem) : []
        // The cups the last round left up: a new shuffle starts by settling them.
        let before = shuffling ? ctx.previous?.play { part -> [Int]? in
            if case .cups(_, _, _, _, let picked, true, let gem, _) = part { Self.lifted(count: count, picked: picked, gem: gem) } else { nil }
        } ?? [] : []
        var nodes: [Node] = [Node.felt("cups.mat", y: table.matY, w: Self.inner, h: table.matH)]
        for cup in 0..<count {
            // Each cup's shadow on the mat under it: smaller and lighter as it rises.
            let raised = up.contains(cup) || before.contains(cup)
            nodes.append(Node.ellipse(fill: Paint.clear("#2A1A40", 0.28)).id(cupId(ends[cup]) + ".shadow").at(table.shadowX(Double(cup)), table.floor - 7).size(table.shadowW, 14)
                .scale(x: raised ? 0.7 : 1, y: 1).opacity(raised ? 0.4 : 1))
        }
        // The pick or the arrow keys' pointer: the navy outline round that cup and its plate.
        if let spot = picked ?? (open ? ctx.local.cursor : nil), spot < count {
            let w = table.cupW + 10, top = table.restY - 6
            nodes.append(Node.rect(stroke: Paint.action, lineWidth: 2.5, corner: 14).id("cups.ring").at(table.centre(Double(spot)) - w / 2, top).size(w, table.floor + 6 + 28 + 5 - top))
        }
        for place in 0..<count { nodes.append(cupPlate(place, table: table, picked: picked == place)) }
        // The gem on the mat: under the cup that shows it first, or where the round left it.
        if let at = shows ? gem : shuffling ? hide : nil {
            let hidden = !revealed
            nodes.append(Node.image("art/game-gem.png").id("cups.gem").at(table.centre(Double(at)) - 24, table.floor - 40).size(48, 45)
                .shadow(Paint.clear("#FFC93C", 0.75), radius: 10, dx: 0, dy: 0).opacity(hidden ? 0 : 1))
        }
        // In a group of their own, so a cup passing behind another goes behind it alone, not behind the table's shadows.
        nodes.append(.box("cups.row", w: Self.inner, h: playRoom) {
            for cup in 0..<count {
                let place = ends[cup]
                let raised = up.contains(cup) || before.contains(cup)
                let node = Node.box(cupId(place), x: table.cupX(Double(cup)), y: table.restY - (raised ? table.lift : 0), w: table.cupW, h: table.cupH) {
                    Node.image("art/game-cup.png").id(cupId(place) + ".art").size(table.cupW, table.cupH).shadow(Paint.clear("#000000", 0.14), radius: 2, dx: 0, dy: 2)
                }.anchor(0.5, 1)
                if open {
                    node.area("cell", value: "0,\(place)", label: L("Cup {n}", ["n": place + 1]), hover: AreaLook(dy: -8), press: AreaLook(dy: 3), sound: "sounds/tap.wav")
                } else {
                    node
                }
            }
        })
        if lifting { nodes += cupsLiftRun(count: count, picked: picked, gem: gem, table: table) }
        if shuffling {
            anims.append(cupsShuffle(count: count, hide: hide, swaps: swaps, swapMs: swapMs, ends: ends, table: table))
            untilPlayed()
        }
        if open {
            for n in 1...count { keys.append(StageKey(key: "\(n)", id: "cup_\(n)", area: "cell", value: "0,\(n - 1)")) }
            arrowKeys()
            if ctx.local.cursor != nil {
                keys.append(StageKey(key: "return", id: "cursor_return"))
                keys.append(StageKey(key: "space", id: "cursor_space"))
            }
        }
        // The next round's button comes when the verdict has been said, not with the cups.
        if revealed, ctx.fresh, ctx.previous?.cupsRevealed == false, board.primary != nil {
            anims.append(.keys("dock.0", [["t": 0, "opacity": 0], ["t": 0.35, "opacity": 0], ["t": 1, "opacity": 1]], ms: 520, ease: "out"))
        }
        let slot = slotRow(y: playRoom - Self.slotHeight)
        return PartBlock(Node.box("cups.part", w: Self.inner, h: playRoom) {
            Node.box("cups", w: Self.inner, h: playRoom) { nodes }.leftToRight()
            slot
        }, height: playRoom)
    }

    /// The number under a cup: a cream plate, the navy one once it is the pick.
    private func cupPlate(_ place: Int, table: CupTable, picked: Bool) -> Node {
        let w = 36.0, h = 26.0
        return .box("cup.\(place).plate", x: table.centre(Double(place)) - w / 2, y: table.floor + 6, w: w, h: h) {
            Node.rect(fill: picked ? Paint.action : Paint.card, corner: 9).size(w, h).shadow(Paint.clear("#3A2A55", 0.3), radius: 1, dx: 0, dy: 2)
            Node.words(Format.integer(place + 1), size: 15, weight: "heavy", color: picked ? Paint.onAction : Paint.ink, align: "center", w: w, h: h)
        }
    }

    /// The press, then the pick rising; the gem shows as its cup clears it, with a small sparkle. The gem's cup follows when it is another one. Essential only in that its end shows.
    private func cupsLiftRun(count: Int, picked: Int?, gem: Int?, table: CupTable) -> [Node] {
        func rise(_ cups: [Int], ms: Double) -> Anim {
            .together(cups.flatMap { cup -> [Anim] in
                [.to("cup.up.\(cup)", ["y": table.restY - table.lift], ms: ms, ease: "out"),
                 .to("cup.up.\(cup).shadow", ["sx": 0.7, "opacity": 0.4], ms: ms, ease: "out")]
            })
        }
        let gemShows: [Anim] = gem == nil ? [] : [
            .keys("cups.gem", [["t": 0, "opacity": 0, "scale": 0.7], ["t": 0.5, "opacity": 1, "scale": 1.14], ["t": 1, "opacity": 1, "scale": 1]], ms: 420, ease: "out").delay(ms: 160),
            .stagger(["cups.spark.0", "cups.spark.1", "cups.spark.2"], stepMs: 70, ["opacity": 1], ms: 160, ease: "out").delay(ms: 260),
            .stagger(["cups.spark.0", "cups.spark.1", "cups.spark.2"], stepMs: 70, ["opacity": 0], ms: 260, ease: "in").delay(ms: 620),
        ]
        // The pick stays pressed a moment first.
        var steps: [Anim] = [picked.map { .keys("cup.up.\($0)", [["t": 0, "y": table.restY + 3], ["t": 1, "y": table.restY]], ms: Self.pressMs, ease: "in") } ?? .wait(ms: Self.pressMs)]
        let all = Array(0..<count)
        let first = picked.map { [$0] } ?? (gem.map { [$0] } ?? all)
        let second = gem == nil ? all.filter { !first.contains($0) } : gem.map { first.contains($0) ? [] : [$0] } ?? []
        if second.isEmpty {
            steps.append(.together([rise(first, ms: Self.liftMs)] + gemShows))
            steps.append(.wait(ms: Self.holdGemMs))
        } else {
            steps.append(rise(first, ms: Self.liftMs))
            steps.append(.wait(ms: Self.holdEmptyMs))
            steps.append(.together([rise(second, ms: Self.liftMs)] + gemShows))
            steps.append(.wait(ms: Self.holdGemMs))
        }
        anims.append(.sequence(steps))
        partAfterStillMs = 900
        guard let gem else { return [] }
        let c = table.centre(Double(gem)), y = table.floor - 22
        let places: [(Double, Double, Double)] = [(-34, -26, 16), (32, -32, 12), (36, 6, 10)]
        return places.enumerated().map { i, p in
            Node.symbol("sparkle", color: Paint.sun).symbolLook(mono: true).id("cups.spark.\(i)").at(c + p.0 - p.2 / 2, y + p.1 - p.2 / 2).size(p.2, p.2).opacity(0)
        }
    }

    /// The cups settle, the gem a moment under its lifted cup, the cup eased onto the mat, then each swap: the two cups slide along the mat, one passing in front (lower
    /// and a little larger, as nearer), the other behind, never through. The steps don't depend on the last round, so the same run carries on if the scene is sent again.
    private func cupsShuffle(count: Int, hide: Int?, swaps: [[Int]], swapMs: Int, ends: [Int], table: CupTable) -> Anim {
        var steps: [Anim] = [.sound("sounds/shuffle.wav")]
        steps.append(.together((0..<count).flatMap { cup -> [Anim] in
            [.to("cup.\(ends[cup])", ["y": table.restY], ms: Self.settleMs), .to("cup.\(ends[cup]).shadow", ["sx": 1, "opacity": 1], ms: Self.settleMs)]
        }))
        if let hide {
            steps.append(.together([.to("cup.\(ends[hide])", ["y": table.restY - table.lift], ms: Self.showLiftMs, ease: "out"),
                                    .to("cup.\(ends[hide]).shadow", ["sx": 0.7, "opacity": 0.4], ms: Self.showLiftMs, ease: "out"),
                                    .to("cups.gem", ["opacity": 1], ms: 180, ease: "out").delay(ms: 120)]))
            steps.append(.wait(ms: Self.showMs))
            steps.append(.together([.to("cup.\(ends[hide])", ["y": table.restY], ms: Self.lowerMs), .to("cup.\(ends[hide]).shadow", ["sx": 1, "opacity": 1], ms: Self.lowerMs)]))
            steps.append(.to("cups.gem", ["opacity": 0], ms: 1, ease: "linear"))
        } else {
            steps.append(.wait(ms: Self.showLiftMs + Self.showMs + Self.lowerMs))
        }
        var at = Array(0..<count)
        for swap in swaps {
            guard let a = at.firstIndex(of: swap[0]), let b = at.firstIndex(of: swap[1]) else { continue }
            func pass(_ cup: Int, from: Double, to: Double, toward: Double) -> [Anim] {
                let samples = (0...Self.swapSamples).map { Double($0) / Double(Self.swapSamples) }
                func x(_ p: Double) -> Double { from + (to - from) * (1 - cos(p * .pi)) / 2 }
                func depth(_ p: Double) -> Double { toward * sin(p * .pi) }
                // Whole tenths: a reply has 64 KB, and a long shuffle is mostly these numbers.
                func tenth(_ v: Double) -> Double { (v * 10).rounded() / 10 }
                return [
                    .keys("cup.\(ends[cup])", samples.map { ["t": $0, "x": tenth(table.cupX(x($0))), "y": tenth(table.restY + depth($0) * 16), "scale": (1000 + (depth($0) * 70).rounded()) / 1000] }, ms: Double(swapMs)),
                    // Set just after it starts: a first key at 0 says where a step starts from, not a change.
                    .keys("cup.\(ends[cup])", [["t": 0.001, "z": toward], ["t": 1, "z": 0]], ms: Double(swapMs)),
                    .keys("cup.\(ends[cup]).shadow", samples.map { ["t": $0, "x": tenth(table.shadowX(x($0))), "y": tenth(table.floor - 7 + depth($0) * 16), "sx": (1000 + (depth($0) * 70).rounded()) / 1000] }, ms: Double(swapMs)),
                ]
            }
            steps.append(.together(pass(a, from: Double(swap[0]), to: Double(swap[1]), toward: 1) + pass(b, from: Double(swap[1]), to: Double(swap[0]), toward: -1)))
            steps.append(.wait(ms: Double(Self.swapRestMs)))
            (at[a], at[b]) = (swap[1], swap[0])
        }
        return Anim.sequence(steps).essential().blocksInput().named("cups_shuffle")
    }

    var cupsStageWords: String? { board.hasCups && playing ? L("Keep your eye on the gem…") : nil }

    var cupsFooter: String? {
        guard !playing else { return nil }
        return board.play { part -> String? in
            if case .cups(let count, _, _, _, _, let revealed, _, let locked) = part, !locked, !revealed { L("1–{n} to pick", ["n": count]) } else { nil }
        }
    }

    /// The arrows move a pointer over the cups as they point, the cups lying the same in every language; Return or Space picks.
    static func cupsMove(_ move: SurfaceMove, board: Board, local: inout LocalParts) -> StageAction? {
        guard let count = board.play({ part -> Int? in if case .cups(let count, _, _, _, _, false, _, false) = part { count } else { nil } }) else { return nil }
        if let played = Playback.next(move, board: board, local: &local) { return played }
        guard case .key(let id, _, _) = move else { return nil }
        switch id {
        case "arrow_left", "arrow_right", "arrow_up", "arrow_down":
            local.cursor = StageMoves.move(id, cursor: local.cursor, columns: count, count: count, rtl: false)
            return .redraw
        case "cursor_return", "cursor_space":
            return local.cursor.map { .play(.cell(row: 0, column: $0)) } ?? .ignore
        default: return nil
        }
    }
}
