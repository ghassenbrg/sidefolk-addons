import Foundation
import SidefolkExtensionKit

/// Copy Me between two people (D96): the same dance for both, copied in turn. The first copies until a mistake, the Mac
/// passes over, and the second gets the very same moves; the longer copy wins. The companion dances for both.
struct CopyMeDuel: Codable, Equatable {
    /// The dance both copy: its seed, so the second gets the same moves.
    let seed: UInt64
    let level: GameLevel
    var turn = Games.Side.you
    /// Waiting for whoever's turn it is to say they're ready (nothing plays before).
    var waiting = true
    /// How far each copied: the first player's, then the second's.
    var copied: [Int?] = [nil, nil]

    init(level: GameLevel, using rng: inout Games.Random) {
        seed = rng.next()
        self.level = level
    }

    var over: Bool { copied.allSatisfy { $0 != nil } }
    var winner: Games.Side? {
        guard let a = copied[0], let b = copied[1], a != b else { return nil }
        return a > b ? .you : .companion
    }

    func game() -> Games.CopyMe {
        var rng = Games.Random(seed: seed)
        return Games.CopyMe(level: level, using: &rng)
    }

    typealias Engine = CopyMeEngine

    static func play(_ action: Engine.Action, on s: inout Engine.State, random: inout Games.Random) throws -> [Games.Event] {
        switch action {
        case .duo(let setup):
            guard s.duel?.copied.allSatisfy({ $0 == nil }) ?? true || s.duel?.over == true else { throw Games.Refusal("not_now") }
            let begin = TwoPlayers.apply(setup, to: &s.duo)
            let duel = CopyMeDuel(level: s.game.level, using: &random)
            s = Engine.State(game: s.duo.on ? duel.game() : Games.CopyMe(level: s.game.level, using: &random), duo: s.duo,
                             duel: s.duo.on ? duel : nil)
            return begin ? [.turn(.you)] : []
        case .ready:
            guard var duel = s.duel, duel.waiting, s.duo.playing else { throw Games.Refusal("not_now") }
            duel.waiting = false
            s.duel = duel
            s.game = duel.game()
            return [.turn(.companion)]
        case .pad(let i):
            guard var duel = s.duel, !duel.waiting, s.duo.playing else { throw Games.Refusal("not_now") }
            let pads = s.game.pads
            guard pads.indices.contains(i) else { throw Games.Refusal("not_now") }
            if s.game.phase == .watching { _ = try s.game.watched() }
            var events = try s.game.press(pads[i]).filter { if case .newBest = $0 { false } else { true } }
            s.pressed = i
            guard s.game.phase == .over else { return events }
            duel.copied[duel.turn == .you ? 0 : 1] = s.game.copied
            if duel.turn == .you {
                duel.turn = .companion
                duel.waiting = true
                events = events.filter { if case .matchOver = $0 { false } else { true } } + [.roundOver(winner: .you)]
            } else {
                TwoPlayers.record(CopyMeScreen.id, s.duo, winner: duel.winner)
                events = events.filter { if case .matchOver = $0 { false } else { true } } + [.matchOver(winner: duel.winner)]
            }
            s.duel = duel
            return events
        case .again, .level:
            let level: GameLevel = if case .level(let l) = action { l } else { s.game.level }
            let duel = CopyMeDuel(level: level, using: &random)
            s = Engine.State(game: duel.game(), duo: s.duo, duel: duel)
            return [.turn(.you)]
        }
    }

    static func board(_ s: Engine.State, events: [Games.Event], options o: GameOptions) -> Board {
        let d = s.duo
        if d.naming != nil { return TwoPlayers.namesBoard(d, companion: o.companion, title: L("Copy Me")) }
        guard let duel = s.duel else { return Board([]) }
        let g = s.game
        var parts: [BoardPart] = [TwoPlayers.score(d, duel.copied[0] ?? 0, duel.copied[1] ?? 0)]
        if duel.over {
            parts.append(.prompt(L("Both danced!"), eyebrow: L("2 players")))
            var facts: [(String, String)] = []
            if let tally = TwoPlayers.tally(CopyMeScreen.id, d) { facts.append(tally) }
            parts.append(TwoPlayers.result(d, winner: duel.winner,
                                           figure: "\(Format.integer(duel.copied[0] ?? 0)) – \(Format.integer(duel.copied[1] ?? 0))", facts: facts))
            parts.append(ScreenKit.levels(duel.level))
        } else if duel.waiting {
            let first = duel.turn == .you
            parts.append(.prompt(first ? L("{name} copies first.", ["name": d.name(.you)])
                                     : L("{name} copied {n}. {other}'s turn: the same dance.", ["name": d.name(.you), "n": duel.copied[0] ?? 0, "other": d.name(.companion)]),
                                 eyebrow: L("2 players")))
            parts.append(.button(GameButton(L("I'm {name}: ready", ["name": d.name(duel.turn)]), move: "ready", style: .primary, symbol: "play.fill")))
        } else {
            let pads = g.pads.map { p in
                Pad(CopyMeScreen.name(p), shape: CopyMeScreen.looks[p]!.shape, color: CopyMeScreen.looks[p]!.color,
                    move: CopyMeScreen.looks[p]!.move, art: CopyMeScreen.looks[p]!.art)
            }
            let replay = g.phase == .watching
            parts.append(.prompt(replay ? L("Watch {name}, then copy.", ["name": o.companion]) : L("{name}'s turn: copy it.", ["name": d.name(duel.turn)]),
                                 eyebrow: L(one: "{count} move", other: "{count} moves", count: g.length)))
            parts.append(.play(.pads(pads, play: replay ? g.sequence.map { m in g.pads.firstIndex(of: m)! } : [], stepMs: g.stepMs,
                                     locked: g.phase == .over)))
        }
        return Board(parts, companion: TwoPlayers.cue(events), over: duel.over)
    }
}
