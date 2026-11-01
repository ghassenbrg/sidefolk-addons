import Foundation
import SidefolkExtensionKit

/// Two people playing each other on one Mac (Sidefolk D96), the same way in every game that offers it: the first board
/// offers "vs <companion>" or "2 players"; two players type their names (or keep the last ones); the score shows both
/// names; a secret is passed with a cover ("Pass the Mac to Sam. Ana, look away!"); the companion referees, cheering
/// both and never saying it won; the end card names the winner in a neutral colour; and the head-to-head is kept apart
/// from the games against the companion. `Side.you` is the first player and `Side.companion` the second throughout.
enum TwoPlayers {
    /// The games two people can play: everything played against the companion except Guess My Animal, where the
    /// companion is the one guessing and learning, so it has no second player to be.
    static let games: Set<String> = [TicTacToeScreen.id, LastStickScreen.id, MemoryPairsScreen.id, CopyMeScreen.id, TriviaScreen.id,
                                     QuickPawsScreen.id, WhichCupScreen.id, HigherLowerScreen.id, BalloonWordsScreen.id]
    static let longestName = 24

    /// Who plays: the companion (`on` false), or two people under `names`.
    struct Duo: Codable, Equatable {
        var names: [String]
        var on = false
        /// Whose name is being typed (0 or 1) before the game; nil once it is under way.
        var naming: Int?

        /// Two people, past their names.
        var playing: Bool { on && naming == nil }
        func name(_ side: Games.Side) -> String { names[side == .you ? 0 : 1] }
    }

    /// What the set-up boards send.
    enum Setup: Equatable {
        case opponent(two: Bool)
        case name(Int, String)
        case begin
    }

    static func setup(_ move: Move) -> Setup? {
        switch move {
        case .choice("opponent", let who): .opponent(two: who == "two")
        case .text("player1", let name): .name(0, name)
        case .text("player2", let name): .name(1, name)
        case .button("players_ready"): .begin
        default: nil
        }
    }

    /// Who plays a game just opened: two people when it was opened for two (`players` 2), names first.
    static func start(_ o: GameOptions) -> Duo { Duo(names: names(o), on: o.twoPlayers, naming: o.twoPlayers ? 0 : nil) }

    /// The names Sidefolk passed, else the last ones here, else "Player 1" (the Mac account's first name when there is
    /// one) and "Player 2".
    static func names(_ o: GameOptions) -> [String] {
        if let given = o.names?.compactMap(clean), given.count == 2 { return given }
        if let kept = PlaytimeRecords.load().players, kept.count == 2 { return kept }
        let first = NSFullUserName().split(separator: " ").first.map(String.init).flatMap(clean)
        return [first ?? L("Player 1"), L("Player 2")]
    }

    static func clean(_ raw: String) -> String? {
        let line = raw.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).joined(separator: " ")
        return line.isEmpty ? nil : String(line.prefix(longestName))
    }

    /// Applies a set-up move.
    /// - Returns: true when a fresh game should begin now: the companion chosen, or the names done.
    static func apply(_ setup: Setup, to d: inout Duo) -> Bool {
        switch setup {
        case .opponent(let two):
            d.on = two
            d.naming = two ? 0 : nil
            return !two
        case .name(let i, let typed):
            guard d.on, d.naming == i else { return false }
            d.names[i] = clean(typed) ?? d.names[i]
            d.naming = i == 0 ? 1 : nil
            if d.naming == nil { PlaytimeRecords.update { [names = d.names] in $0.players = names } }
            return d.naming == nil
        case .begin:
            guard d.on, d.naming != nil else { return false }
            d.naming = nil
            PlaytimeRecords.update { [names = d.names] in $0.players = names }
            return true
        }
    }

    /// "vs Mochi" or "2 players", for a game's first board.
    static func opponent(two: Bool, companion: String) -> BoardPart {
        .choice(name: "opponent", style: .segmented, options: [ChoiceOption("companion", L("vs {name}", ["name": companion])),
                                                               ChoiceOption("two", L("2 players"), symbol: "person.2.fill")],
                selected: two ? "two" : "companion")
    }

    /// The names board: who's playing, one name typed at a time, and Start to keep them.
    static func namesBoard(_ d: Duo, companion: String, title: String) -> Board {
        let i = d.naming ?? 0
        return Board([
            score(d, 0, 0),
            .prompt(L("Who's playing?"), eyebrow: title + " · " + L("2 players")),
            .facts([(L("Player 1"), d.names[0]), (L("Player 2"), d.names[1])]),
            .play(.entry(name: "player\(i + 1)", label: i == 0 ? L("Player 1's name") : L("Player 2's name"), placeholder: d.names[i],
                         button: i == 0 ? L("Next") : L("Start"), max: longestName)),
            .button(GameButton(L("Start"), move: "players_ready", style: .primary, symbol: "play.fill")),
            opponent(two: true, companion: companion),
        ], companion: Cue(move: "ready", line: "hello", look: "panel"))
    }

    static func score(_ d: Duo, _ first: Int, _ second: Int, rounds: Int? = nil) -> BoardPart {
        .score(you: first, companion: second, rounds: rounds, players: d.names)
    }

    /// "Ana's turn" with whose mark or role it is.
    static func turn(_ d: Duo, _ side: Games.Side) -> String { L("{name}'s turn", ["name": d.name(side)]) }

    /// The cover that passes the Mac over before a secret: nothing on it says what the other chose.
    static func cover(_ d: Duo, to side: Games.Side, eyebrow: String) -> [BoardPart] {
        [.prompt(L("Pass the Mac to {name}.", ["name": d.name(side)]), eyebrow: eyebrow + " · " + L("{name}, look away!", ["name": d.name(side.other)])),
         .button(GameButton(L("I'm {name}: ready", ["name": d.name(side)]), move: "ready", style: .primary, symbol: "eye.slash"))]
    }

    /// The end card: the winner named in neutral ink with a trophy (`info`: it says who, never how it went for "you"), or a
    /// draw; Play again.
    static func result(_ d: Duo, winner: Games.Side?, figure: String, facts: [(String, String)] = []) -> BoardPart {
        .result(figure: figure, line: winner.map { L("{name} wins!", ["name": d.name($0)]) } ?? L("A draw!"), tone: winner == nil ? .neutral : .info, facts: facts,
                actions: [ScreenKit.playAgain])
    }

    /// The companion refereeing what happened: a nod for a point, a cheer for a round, confetti for the match, a shrug
    /// for a draw; never "I win" or "you win", which would take a side.
    static func cue(_ events: [Games.Event]) -> Cue? {
        for e in events.sorted(by: { EventCues.weight($0) > EventCues.weight($1) }) {
            switch e {
            case .matchOver(let w): return w == nil ? Cue(move: "shrug", line: "draw", sound: "boop") : Cue(move: "celebrate", effect: "confetti", sound: "fanfare")
            case .roundOver(let w): return w == nil ? Cue(move: "shrug", line: "draw", sound: "boop") : Cue(move: "cheer", sound: "ding")
            case .point, .pair, .hit, .grew: return Cue(move: "nod", sound: "ding", look: "panel")
            case .mistake: return Cue(move: "gasp", sound: "boop")
            case .miss, .noPair: return Cue(move: "wince", sound: "pop")
            case .tooSoon: return Cue(move: "gasp", effect: "exclaim", sound: "boop")
            case .fork, .threat: return Cue(move: "gasp", look: "panel")
            case .turn: return Cue(move: "ready", look: "panel")
            case .opened: return Cue(move: "ready", line: "hello", look: "panel")
            default: continue
            }
        }
        return nil
    }

    /// The match ended: one more for the winner (or a draw) in this pair's head-to-head for the game.
    static func record(_ game: String, _ d: Duo, winner: Games.Side?, at date: Date = Date()) {
        PlaytimeRecords.update { r in
            var all = r.duels ?? [:]
            let pair = d.names.sorted().joined(separator: " · ")
            var duel = all[game]?[pair] ?? PlaytimeRecords.Duel()
            if let winner { duel.wins[d.name(winner), default: 0] += 1 } else { duel.draws += 1 }
            duel.last = date
            all[game, default: [:]][pair] = duel
            r.duels = all
        }
    }

    /// The head-to-head so far for the game, as end-card facts ("Ana 3 · Sam 2").
    static func tally(_ game: String, _ d: Duo) -> (String, String)? {
        guard let duel = PlaytimeRecords.load().duels?[game]?[d.names.sorted().joined(separator: " · ")] else { return nil }
        return (L("Head to head"), "\(d.names[0]) \(Format.integer(duel.wins[d.names[0]] ?? 0)) · \(d.names[1]) \(Format.integer(duel.wins[d.names[1]] ?? 0))")
    }
}
