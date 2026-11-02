import Foundation
import SidefolkExtensionKit

// Which Cup?'s cups (CupsView): the gem under its cup, the cups lowered and swapped at the game's pace, then picked; lifted once picked to show where
// the gem was. The shuffle is one essential run Sidefolk plays by itself, so the swaps keep moving under Reduce Motion: they are the game. The table
// reads the same in every language.
extension BoardDrawing {
    private static let floor = 124.0, cupHeight = 76.0, lift = 46.0, swapSamples = 8
    private static var restY: Double { floor - cupHeight + 2 }

    func cupsPart(count: Int, hide: Int?, swaps: [[Int]], swapMs: Int, picked: Int?, revealed: Bool, gem: Int?, locked: Bool) -> PartBlock {
        let slot = Self.inner / Double(count), height = 162.0
        let shuffling = playing
        // Where each cup ends: a node is named by that place, so it lies where it did on the scene after, and starts where the cup starts.
        var ends = Array(0..<count)
        if shuffling {
            for swap in swaps {
                guard let a = ends.firstIndex(of: swap[0]), let b = ends.firstIndex(of: swap[1]) else { continue }
                (ends[a], ends[b]) = (swap[1], swap[0])
            }
        }
        let open = !locked && !revealed
        // Lifting is a cut, as the verdict's board always was: named apart, so the cups don't ease up.
        let cupId = { (place: Int) in revealed ? "cup.up.\(place)" : "cup.\(place)" }
        func cupX(_ at: Double) -> Double { slot * (at + 0.5) - min(slot - 8, 72) / 2 }
        func shadowX(_ at: Double) -> Double { slot * (at + 0.5) - min(slot - 14, 58) / 2 }
        var nodes: [Node] = []
        if let spot = picked ?? (locked ? nil : ctx.local.cursor), spot < count {
            // The pick or the arrow keys' pointer: a ring on the table at that place, the app's accent.
            let w = min(slot - 10, 64)
            nodes.append(Node.ellipse(stroke: .accent, lineWidth: 3).id("cups.ring").at(slot * (Double(spot) + 0.5) - w / 2 + 1.5, Self.floor + 1 - 9 + 1.5).size(w - 3, 15))
        }
        for cup in 0..<count {
            // Each cup's shadow on the table under it: smaller and lighter as it rises.
            let up = revealed || (shuffling && cup == hide)
            nodes.append(Node.ellipse(fill: Paint.clear("#000000", 0.16)).id(cupId(ends[cup]) + ".shadow").at(shadowX(Double(cup)), Self.floor + 1 - 4.5).size(min(slot - 14, 58), 9)
                .scale(x: up ? 0.7 : 1, y: 1).opacity(up ? 0.4 : 1))
        }
        if let at = revealed ? gem : shuffling ? hide : nil {
            nodes.append(Node.image("art/game-gem.png").id("cups.gem").at(slot * (Double(at) + 0.5) - 20, Self.floor - 14 - 15).size(40, 30)
                .shadow(Paint.clear("#FFC93C", 0.7), radius: 8, dx: 0, dy: 0))
        }
        // In a group of their own, so a cup passing behind another goes behind it alone, not behind the table's shadows.
        nodes.append(.box("cups.row", w: Self.inner, h: height) {
            for cup in 0..<count {
                let place = ends[cup], w = min(slot - 8, 72)
                let up = revealed || (shuffling && cup == hide)
                let node = Node.box(cupId(place), x: cupX(Double(cup)), y: Self.restY - (up ? Self.lift : 0), w: w, h: Self.cupHeight) {
                    Node.image("art/game-cup.png").at(0, 4).size(w, Self.cupHeight - 4).shadow(Paint.clear("#000000", 0.12), radius: 2, dx: 0, dy: 2)
                }.anchor(0.5, 1).scale(picked == place ? 1.06 : 1)
                if open {
                    node.area("cell", value: "0,\(place)", label: L("Cup {n}", ["n": place + 1]), hover: nil, press: nil, sound: "sounds/tap.wav")
                } else {
                    node
                }
            }
        })
        for place in 0..<count {
            nodes.append(.box("cup.\(place).plate", x: slot * (Double(place) + 0.5) - 13, y: Self.floor + 26 - 11, w: 26, h: 22) {
                Node.rect(fill: .hex("#FFF6EA"), corner: 7).size(26, 22).shadow(Paint.clear("#6B4A2B", 0.35), radius: 0, dx: 0, dy: 2)
                Node.words(Format.integer(place + 1), size: 13, weight: "heavy", color: .hex("#6B4A2B"), align: "center", w: 26, h: 22)
            })
        }
        if shuffling {
            anims.append(cupsShuffle(count: count, hide: hide, swaps: swaps, swapMs: swapMs, ends: ends, cupX: cupX, shadowX: shadowX))
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
        return PartBlock(Node.box("cups", w: Self.inner, h: height) { nodes }.leftToRight(), height: height)
    }

    /// The gem a moment under its lifted cup, the cup eased onto the table, then each swap: the two cups slide along the table, one passing in front (lower
    /// and a little larger, as nearer), never through the other.
    private func cupsShuffle(count: Int, hide: Int?, swaps: [[Int]], swapMs: Int, ends: [Int], cupX: (Double) -> Double, shadowX: (Double) -> Double) -> Anim {
        var steps: [Anim] = [.sound("sounds/shuffle.wav"), .wait(ms: 1000)]
        if let hide {
            steps.append(.together([.to("cup.\(ends[hide])", ["y": Self.restY], ms: 400), .to("cup.\(ends[hide]).shadow", ["sx": 1, "opacity": 1], ms: 400)]))
        } else {
            steps.append(.wait(ms: 400))
        }
        steps.append(.to("cups.gem", ["opacity": 0], ms: 1, ease: "linear"))
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
                    .keys("cup.\(ends[cup])", samples.map { ["t": $0, "x": tenth(cupX(x($0))), "y": tenth(Self.restY + depth($0) * 9), "scale": (1000 + (depth($0) * 100).rounded()) / 1000] }, ms: Double(swapMs)),
                    // Set just after it starts: a first key at 0 says where a step starts from, not a change.
                    .keys("cup.\(ends[cup])", [["t": 0.001, "z": toward], ["t": 1, "z": 0]], ms: Double(swapMs)),
                    .keys("cup.\(ends[cup]).shadow", samples.map { ["t": $0, "x": tenth(shadowX(x($0))), "y": tenth(Self.floor + 1 - 4.5 + depth($0) * 9), "sx": (1000 + (depth($0) * 100).rounded()) / 1000] }, ms: Double(swapMs)),
                ]
            }
            steps.append(.together(pass(a, from: Double(swap[0]), to: Double(swap[1]), toward: 1) + pass(b, from: Double(swap[1]), to: Double(swap[0]), toward: -1)))
            (at[a], at[b]) = (swap[1], swap[0])
        }
        return Anim.sequence(steps).essential().blocksInput().named("cups_shuffle")
    }

    var cupsStageWords: String? { board.hasCups && playing ? L("Shuffling…") + " 👀" : nil }

    var cupsFooter: String? {
        board.play { part -> String? in
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
