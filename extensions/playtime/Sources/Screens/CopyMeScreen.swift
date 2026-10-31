import Foundation
import SidefolkExtensionKit

/// Copy Me: the companion dances a sequence on four pads (five on Hard), Sidefolk plays it, and the person copies it.
/// Each round adds a move and the tempo rises; a wrong pad ends it, dizzy. The score is the longest sequence copied.
enum CopyMeEngine: GameEngine {
    struct State: Codable, Equatable {
        var game: Games.CopyMe
        /// The pad just pressed, and whether it was right, for the board.
        var pressed: Int?
        var record = false
    }

    enum Action: Equatable { case pad(Int), again, level(GameLevel) }

    static func start(level: GameLevel, options: GameOptions, random: inout Games.Random) -> State {
        State(game: Games.CopyMe(level: level, best: PlaytimeRecords.load().games[CopyMeScreen.id]?.best ?? 0, using: &random))
    }

    static func play(_ action: Action, on s: inout State, random: inout Games.Random) throws -> [Games.Event] {
        switch action {
        case .pad(let i):
            let pads = s.game.pads
            guard pads.indices.contains(i) else { throw Games.Refusal("not_now") }
            // Sidefolk took the press only after showing the whole sequence: the watching is done.
            if s.game.phase == .watching { _ = try s.game.watched() }
            let events = try s.game.press(pads[i])
            s.pressed = i
            if s.game.phase == .over {
                s.record = events.contains { if case .newBest = $0 { true } else { false } }
                PlaytimeRecords.finish(CopyMeScreen.id, s.record ? .won : .draw, you: s.game.copied, companion: 0, best: s.game.copied)
            }
            return events
        case .again, .level:
            let level: GameLevel = if case .level(let l) = action { l } else { s.game.level }
            s = start(level: level, options: GameOptions(), random: &random)
            return [.turn(.companion)]
        }
    }

    static func outcome(of s: State) -> GameOutcome? { s.game.phase == .over ? (s.record ? .won : .draw) : nil }
}

enum CopyMeScreen: GameScreen {
    typealias Engine = CopyMeEngine
    static let id = "copy_me"

    static func action(for move: Move, in s: CopyMeEngine.State) -> CopyMeEngine.Action? {
        switch move {
        case .pad(let i): .pad(i)
        case .button("again"): .again
        case .choice("level", let l): GameLevel(rawValue: l).map { .level($0) }
        default: nil
        }
    }

    /// Each pad's shape and colour, the companion's move, and Sidefolk's picture of that move (a waving hand, a hopping
    /// bunny…), drawn instead of the shape where Sidefolk has it.
    static let looks: [Games.CopyMe.Pad: (shape: String, color: String, move: String, art: String)] = [
        .wave: ("circle", "blue", "accent:wave", "wave"), .hop: ("triangle", "green", "accent:hop", "hop"),
        .spin: ("star", "yellow", "accent:spin", "spin"), .bow: ("square", "red", "accent:bow", "bow"),
        .otherWave: ("diamond", "purple", "accent:wave", "wave_both"),
    ]

    static func name(_ pad: Games.CopyMe.Pad) -> String {
        switch pad {
        case .wave: L("Wave")
        case .hop: L("Hop")
        case .spin: L("Spin")
        case .bow: L("Bow")
        case .otherWave: L("Other wave")
        }
    }

    static func board(_ s: CopyMeEngine.State, events: [Games.Event], options o: GameOptions) -> Board {
        let g = s.game
        let pads = g.pads.map { p in Pad(name(p), shape: looks[p]!.shape, color: looks[p]!.color, move: looks[p]!.move, art: looks[p]!.art) }
        // A new sequence plays when the round starts or grows; mid-copy, the pads just take presses.
        let replay = g.phase == .watching
        let best = max(g.best, g.copied)
        // No score pills: the companion only dances, it doesn't play against you here.
        var parts: [BoardPart] = [
            .prompt(g.phase == .over ? L("Oops, that one was wrong!") : replay ? L("Watch {name}, then copy.", ["name": o.companion]) : L("Your turn: copy it."),
                    eyebrow: L(one: "{count} move · {level}", other: "{count} moves · {level}", count: g.length, ["level": ScreenKit.level(g.level)])),
            .play(.pads(pads, play: replay ? g.sequence.map { s in g.pads.firstIndex(of: s)! } : [], stepMs: g.stepMs, locked: g.phase == .over)),
        ]
        if g.phase == .over {
            parts.append(ScreenKit.result(s.record ? .won : .draw, figure: Format.integer(g.copied),
                                          line: s.record ? L(one: "A new best: {count} move!", other: "A new best: {count} moves!", count: g.copied) : L(one: "You copied {count} move.", other: "You copied {count} moves.", count: g.copied),
                                          ribbon: s.record ? L("New best!") : nil, facts: [(L("Best"), Format.integer(best))], companion: o.companion))
            parts.append(ScreenKit.levels(g.level))
        }
        var cue = EventCues.cue(events)
        if events.contains(.opened) { cue = Cue(move: "ready", line: "hello", look: "panel") }
        // A mistake ends it: the companion turned too far and is dizzy, or cheers a new best.
        if events.contains(.mistake) { cue = s.record ? EventCues.cue(for: .newBest(g.copied)) : EventCues.cue(for: .mistake) }
        return Board(parts, companion: cue, over: g.phase == .over)
    }
}
