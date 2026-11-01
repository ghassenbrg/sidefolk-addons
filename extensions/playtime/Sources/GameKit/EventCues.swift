import Foundation
import SidefolkExtensionKit

/// The one table from what happened in a game (`Games.Event`) to how the companion takes it (a Sidefolk `Cue`: a move,
/// an effect, a line key, a sound, where to look) and how a cell arrives on the board. Every game uses it, so a point
/// scored or a match lost looks and sounds the same everywhere; a screen only adds what is its own (balloons held, a
/// magnifier, frost when a guess is far).
enum EventCues {
    /// The reaction to the weightiest thing that happened: an ended match before a point, a point before a turn.
    static func cue(_ events: [Games.Event]) -> Cue? {
        events.sorted { weight($0) > weight($1) }.lazy.compactMap(cue(for:)).first
    }

    static func cue(for event: Games.Event) -> Cue? {
        switch event {
        case .matchOver(let winner): ended(winner, match: true)
        case .roundOver(let winner): ended(winner, match: false)
        case .newBest: Cue(move: "cheer", effect: "sparkles", line: "record", sound: "fanfare")
        case .caught: Cue(move: "wince", effect: "sweat", line: "caught_cheating", sound: "cork", look: "you")
        case .confess: Cue(move: "giggle", line: "caught_cheating", sound: "cork")
        case .innocent: Cue(move: "shrug", effect: "hearts", look: "you")
        case .mistake: Cue(move: "dizzy", effect: "stars", sound: "trombone")
        case .tooSoon: Cue(move: "giggle", line: "tease", sound: "boop", look: "you")
        case .tooSlow: Cue(move: "shrug", sound: "boop")
        case .streak(let n): Cue(move: "cheer", effect: n >= 10 ? "confetti" : "sparkles", line: "streak", sound: "ding")
        case .unbeatable: Cue(move: "shrug", line: "hint_intro", look: "you")
        case .offerSecret: Cue(move: "wave", line: "hint_intro", look: "you")
        case .lifeline(let sure):
            sure ? Cue(move: "tease", line: "hint_intro", sound: "whoosh", look: "panel")
                : Cue(move: "sweat", effect: "sweat", line: "hint_intro", sound: "whoosh", look: "panel")
        case .hint: Cue(move: "nod", line: "hint_intro", sound: "whoosh", look: "panel")
        case .contradiction: Cue(move: "gasp", effect: "exclaim", look: "you")
        case .fork(.you), .threat(.you): Cue(move: "sweat", effect: "sweat", line: "close_one")
        case .fork, .threat: Cue(move: "tease", look: "panel")
        case .pair(let side): side == .you ? Cue(move: "wince", sound: "ding", look: "panel") : Cue(move: "cheer", sound: "ding", look: "panel")
        case .noPair(let side): side == .companion ? Cue(move: "wince", effect: "stars", sound: "boop") : Cue(sound: "flip")
        case .point(let side): side == .you ? Cue(move: "wince", sound: "ding", look: "you") : Cue(move: "giggle", sound: "boop", look: "panel")
        case .learned, .forgot: Cue(move: "celebrate", effect: "hearts", line: "encourage", sound: "ding")
        case .recalls: Cue(move: "think", effect: "question", look: "panel")
        case .think: Cue(move: "think", line: "thinking", look: "panel")
        case .sealed: Cue(move: "think", effect: "question", look: "panel")
        case .grew: Cue(move: "nod", sound: "ding", look: "panel")
        case .hit(let n): Cue(move: n >= 2 ? "cheer" : "nod", sound: "ding", look: "panel")
        case .miss: Cue(move: "wince", sound: "pop")
        case .higher, .lower: Cue(sound: "tick", look: "panel")
        case .found: Cue(move: "gasp", effect: "exclaim")
        case .reveal: Cue(sound: "whoosh", look: "panel")
        case .opened: Cue(move: "ready", line: "hello", look: "panel")
        case .refused: Cue(move: "shrug")
        case .turn(let side): side == .you ? Cue(look: "panel") : Cue(move: "think", look: "panel")
        }
    }

    /// The end of a round or of the match: the person's win (the companion bows, or sulks for a round), its win
    /// (cheers, or celebrates the match), or a draw (a shrug together).
    private static func ended(_ winner: Games.Side?, match: Bool) -> Cue {
        switch winner {
        case .you?: match ? Cue(move: "bow", effect: "confetti", line: "you_win", sound: "fanfare", look: "you")
            : Cue(move: "sulk", line: "you_win", sound: "ding", look: "you")
        case .companion?: match ? Cue(move: "celebrate", line: "i_win", sound: "trombone") : Cue(move: "cheer", line: "i_win", sound: "boop")
        case nil: Cue(move: "shrug", line: "draw", sound: "boop")
        }
    }

    /// Which reaction wins when a move did several things.
    static func weight(_ e: Games.Event) -> Int {
        switch e {
        case .matchOver: 100
        case .roundOver: 90
        case .caught, .confess: 85
        case .newBest: 80
        case .mistake, .tooSoon, .tooSlow: 75
        case .streak: 70
        case .unbeatable, .offerSecret: 65
        case .learned, .forgot: 62
        case .lifeline, .hint, .contradiction: 60
        case .fork: 55
        case .pair, .noPair: 50
        case .point: 45
        case .threat: 40
        case .innocent: 38
        case .hit, .miss, .grew: 30
        case .found: 28
        case .recalls: 26
        case .think, .sealed: 20
        case .higher, .lower: 15
        case .reveal: 10
        case .refused: 8
        case .opened: 5
        case .turn: 1
        }
    }

    /// How a cell arrives after an event: a mark stamped, a card flipped.
    static func animate(_ events: [Games.Event]) -> String? {
        for e in events {
            switch e {
            case .pair, .noPair, .recalls: return "flip"
            case .turn, .think, .threat, .fork, .roundOver: return "stamp"
            default: continue
            }
        }
        return nil
    }
}

/// Pieces every screen draws the same way: the level's name, the end card with Play again and a level choice, the
/// note for a refused move.
enum ScreenKit {
    static func level(_ l: GameLevel) -> String {
        switch l {
        case .easy: L("Easy")
        case .fair: L("Fair")
        case .hard: L("Hard")
        }
    }

    /// The levels as segments, picked one marked.
    static func levels(_ selected: GameLevel) -> BoardPart {
        .choice(name: "level", label: L("Level"), style: .segmented, options: GameLevel.allCases.map { ChoiceOption($0.rawValue, level($0)) },
                selected: selected.rawValue)
    }

    /// The end card's usual button.
    static var playAgain: GameButton { GameButton(L("Play again"), move: "again", style: .primary, symbol: "arrow.clockwise") }

    /// The end card: the outcome's words (the person's win, the companion's, a draw), a figure, facts, and its buttons
    /// (Play again unless a game gives its own).
    static func result(_ outcome: GameOutcome, figure: String, line: String? = nil, ribbon: String? = nil, facts: [(String, String)] = [],
                       companion: String, actions: [GameButton]? = nil) -> BoardPart {
        let words = line ?? {
            switch outcome {
            case .won: L("You beat {name}!", ["name": companion])
            case .lost: L("{name} wins this one.", ["name": companion])
            case .draw: L("A draw!")
            }
        }()
        return .result(figure: figure, line: words, ribbon: ribbon, tone: outcome == .won ? .good : outcome == .lost ? .bad : .neutral,
                       facts: facts, actions: actions ?? [playAgain])
    }

    /// A move the rules refused, in the person's words; nil when nothing was refused.
    static func refusal(_ events: [Games.Event]) -> BoardPart? {
        for case .refused(let reason) in events {
            let text: String? = switch reason {
            case "taken": L("That one's taken.")
            case "not_your_turn": L("Not your turn yet.")
            case "wrong_length": L("That word isn't the right length.")
            case "not_letters": L("Use the game's letters.")
            case "not_a_word": L("That's not in the word list.")
            case "already_guessed": L("You tried that one already.")
            case "out_of_range": L("Pick a number from 1 to 100.")
            case "hint_used": L("The hint is used up.")
            case "same_animal": L("That's the animal I guessed.")
            case "empty": L("Please write both.")
            case "too_long": L("That's a bit long.")
            case "bad_take": L("Take 1, 2 or 3 sticks.")
            default: nil
            }
            if let text { return .note(text, tone: .warn) }
        }
        return nil
    }

    static func score(_ s: Games.Score, rounds: Int? = nil, best: Int? = nil) -> BoardPart {
        .score(you: s.you, companion: s.companion, best: best, rounds: rounds)
    }
}
