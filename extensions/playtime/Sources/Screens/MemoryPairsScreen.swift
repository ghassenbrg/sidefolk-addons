import Foundation
import SidefolkExtensionKit

/// Memory Pairs against a companion with a goldfish's memory: a 4 × 4 grid, turns taken, a pair keeps the turn. Two
/// cards that don't match stay up a moment (Sidefolk's wait), then turn back; the companion's turn is one card after
/// another, each after it thinks.
enum MemoryPairsEngine: GameEngine {
    struct State: Codable, Equatable {
        var game: Games.MemoryPairs
        /// The card just turned, flipped in.
        var fresh: Int?
        var recalled = false
    }

    enum Action: Equatable { case flip(Int), next, again, level(GameLevel) }

    static func start(level: GameLevel, options: GameOptions, random: inout Games.Random) -> State {
        State(game: Games.MemoryPairs(level: level, first: .you, using: &random))
    }

    static func play(_ action: Action, on s: inout State, random: inout Games.Random) throws -> [Games.Event] {
        var events: [Games.Event]
        switch action {
        case .flip(let i):
            events = try s.game.flip(i, by: .you)
            (s.fresh, s.recalled) = (i, false)
        case .next:
            if s.game.waitingToCover {
                events = try s.game.cover()
                s.fresh = nil
            } else {
                guard s.game.turn == .companion, !s.game.over else { throw Games.Refusal("not_now") }
                let (cell, recalled) = s.game.companionFlip(using: &random)
                events = try s.game.flip(cell, by: .companion)
                (s.fresh, s.recalled) = (cell, recalled)
                if recalled { events.append(.recalls) }
                // Its second card comes after another moment's thought.
                if events.isEmpty || events == [.recalls] { events.append(.think(ms: 800)) }
            }
        case .again, .level:
            let level: GameLevel = if case .level(let l) = action { l } else { s.game.level }
            s = start(level: level, options: GameOptions(), random: &random)
            return [.turn(.you)]
        }
        if s.game.over, let outcome = outcome(of: s) {
            PlaytimeRecords.finish(MemoryPairsScreen.id, outcome, you: s.game.score.you, companion: s.game.score.companion, best: s.game.score.you)
        }
        return events
    }

    static func outcome(of s: State) -> GameOutcome? {
        guard s.game.over else { return nil }
        return switch s.game.score.leader { case .you?: .won; case .companion?: .lost; case nil: .draw }
    }
}

enum MemoryPairsScreen: GameScreen {
    typealias Engine = MemoryPairsEngine
    static let id = "memory_pairs"

    static let symbols = ["moon": "moon.fill", "leaf": "leaf.fill", "anchor": "anchor", "star": "star.fill", "heart": "heart.fill",
                          "sun": "sun.max.fill", "cloud": "cloud.fill", "flower": "camera.macro", "fish": "fish.fill", "bell": "bell.fill",
                          "key": "key.fill", "drop": "drop.fill"]

    static func name(_ id: String) -> String {
        switch id {
        case "moon": L("Moon")
        case "leaf": L("Leaf")
        case "anchor": L("Anchor")
        case "star": L("Star")
        case "heart": L("Heart")
        case "sun": L("Sun")
        case "cloud": L("Cloud")
        case "flower": L("Flower")
        case "fish": L("Fish")
        case "bell": L("Bell")
        case "key": L("Key")
        case "drop": L("Drop")
        default: id
        }
    }

    static func action(for move: Move, in s: MemoryPairsEngine.State) -> MemoryPairsEngine.Action? {
        switch move {
        case .cell(let r, let c): .flip(r * 4 + c)
        case .next: .next
        case .button("again"): .again
        case .choice("level", let l): GameLevel(rawValue: l).map { .level($0) }
        default: nil
        }
    }

    static func board(_ s: MemoryPairsEngine.State, events: [Games.Event], options o: GameOptions) -> Board {
        let g = s.game
        let cells = g.cards.indices.map { i -> Cell in
            let up = g.owner[i] != nil || g.faceUp.contains(i)
            let label = L("Card {n}", ["n": i + 1])
            return up ? Cell("symbol", value: symbols[g.cards[i]], companion: g.owner[i] == .companion || (g.owner[i] == nil && g.turn == .companion),
                             label: label + ", " + name(g.cards[i]), animate: s.fresh == i ? "flip" : nil)
                : Cell("card_back", label: label)
        }
        let thinking = events.compactMap { if case .think(let ms) = $0 { ms } else { nil } }.first
        let text: String = if g.over { L("All pairs found.") }
            else if g.waitingToCover { L("Not a pair.") }
            else if g.turn == .you { L("Your turn: turn two cards.") }
            else if s.recalled { L("{name}: “I saw one… around here?”", ["name": o.companion]) }
            else { L("{name}'s turn.", ["name": o.companion]) }
        var parts: [BoardPart] = [
            ScreenKit.score(g.score),
            .prompt(text, eyebrow: ScreenKit.level(g.level)),
            .board(rows: 4, columns: 4, cells: cells, locked: g.over || g.turn != .you || g.waitingToCover),
        ]
        if let outcome = MemoryPairsEngine.outcome(of: s) {
            parts.append(ScreenKit.result(outcome, figure: "\(Format.integer(g.score.you)) – \(Format.integer(g.score.companion))", companion: o.companion))
            parts.append(ScreenKit.levels(g.level))
        }
        var cue = EventCues.cue(events)
        if thinking != nil, cue?.move == nil || cue?.move == "think" { cue = Cue(move: "think", effect: s.recalled ? "question" : nil, look: "panel") }
        if let fresh = s.fresh, cue != nil, cue?.look as? String == "panel" { cue?.look = [fresh / 4, fresh % 4] }
        // Two cards that don't match stay up a moment; the companion's turn goes card by card.
        let after = g.over ? nil : g.waitingToCover ? 1200 : thinking ?? (g.turn == .companion ? 900 : nil)
        return Board(parts, companion: cue, over: g.over, afterMs: after)
    }
}
