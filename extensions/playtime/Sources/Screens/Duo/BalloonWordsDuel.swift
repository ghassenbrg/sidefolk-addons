import Foundation
import SidefolkExtensionKit

/// Balloon Words between two people (D96): each sets the other a word in turn. The setter types it while the other
/// looks away, a cover passes the Mac over (the word is gone from the screen), and the other guesses it a letter at a
/// time with the seven balloons. After both rounds, the one who kept more balloons wins (an unsolved word keeps none).
struct BalloonWordsDuel: Codable, Equatable {
    enum Stage: String, Codable { case toSetter, setting, toGuesser, guessing, solved }

    var setter = Games.Side.you
    var stage = Stage.toSetter
    var game: Games.BalloonWords?
    /// Balloons each guesser kept: the first player's, then the second's.
    var kept: [Int?] = [nil, nil]

    var guesser: Games.Side { setter.other }
    var over: Bool { kept.allSatisfy { $0 != nil } }
    var winner: Games.Side? {
        guard let a = kept[0], let b = kept[1], a != b else { return nil }
        return a > b ? .you : .companion
    }

    /// A word a person may set: two to fourteen letters of the game's own keyboard (in Chinese, the pinyin), nothing
    /// else but spaces and hyphens.
    static func entry(_ typed: String, _ language: Games.Language) -> Games.BalloonWords.Entry? {
        let word = typed.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        let units = Games.WordScript.units(word, language, for: .balloon)
        let letters = units.filter { !$0.key.isEmpty }
        guard (2...14).contains(letters.count), letters.allSatisfy({ Games.WordScript.isKey($0.key, language, .balloon) }) else { return nil }
        return Games.BalloonWords.Entry(word: word, spelling: word, category: "")
    }

    typealias Engine = BalloonWordsEngine

    static func play(_ action: Engine.Action, on s: inout Engine.State, random: inout Games.Random) throws -> [Games.Event] {
        switch action {
        case .duo(let setup):
            guard s.duel == nil || s.duel?.stage == .toSetter && s.duel?.setter == .you || s.duel?.over == true else { throw Games.Refusal("not_now") }
            _ = TwoPlayers.apply(setup, to: &s.duo)
            s.duel = s.duo.on ? BalloonWordsDuel() : nil
            return [.turn(.you)]
        case .ready:
            guard s.duo.playing, var duel = s.duel else { throw Games.Refusal("not_now") }
            switch duel.stage {
            case .toSetter: duel.stage = .setting
            case .toGuesser: duel.stage = .guessing
            default: throw Games.Refusal("not_now")
            }
            s.duel = duel
            return [.turn(duel.stage == .setting ? duel.setter : duel.guesser)]
        case .word(let typed):
            guard var duel = s.duel, duel.stage == .setting else { throw Games.Refusal("not_now") }
            guard let entry = entry(typed, s.game.language) else { throw Games.Refusal("not_letters") }
            duel.game = Games.BalloonWords(language: s.game.language, entry: entry)
            duel.stage = .toGuesser
            s.duel = duel
            return [.sealed]
        case .letter(let l):
            guard var duel = s.duel, duel.stage == .guessing, var game = duel.game else { throw Games.Refusal("not_now") }
            var events = try game.guess(l)
            duel.game = game
            if game.over {
                duel.kept[duel.guesser == .you ? 0 : 1] = game.won ? game.left : 0
                duel.stage = .solved
                if duel.over {
                    TwoPlayers.record(BalloonWordsScreen.id, s.duo, winner: duel.winner)
                    events.append(.matchOver(winner: duel.winner))
                }
            }
            s.duel = duel
            return events
        case .next:
            guard var duel = s.duel, duel.stage == .solved, !duel.over else { throw Games.Refusal("not_now") }
            duel.setter = .companion
            duel.stage = .toSetter
            duel.game = nil
            s.duel = duel
            return [.turn(.companion)]
        case .again:
            s.duel = BalloonWordsDuel()
            return [.turn(.you)]
        default:
            throw Games.Refusal("not_now")
        }
    }

    static func board(_ s: Engine.State, events: [Games.Event], options o: GameOptions) -> Board {
        let d = s.duo
        if d.naming != nil { return TwoPlayers.namesBoard(d, companion: o.companion, title: L("Balloon Words")) }
        let duel = s.duel ?? BalloonWordsDuel()
        let round = L("Round {n} of 2", ["n": duel.setter == .you ? 1 : 2])
        var parts: [BoardPart] = [TwoPlayers.score(d, duel.kept[0] ?? 0, duel.kept[1] ?? 0)]
        var cue = TwoPlayers.cue(events)
        switch duel.stage {
        case .toSetter:
            parts += TwoPlayers.cover(d, to: duel.setter, eyebrow: round)
            parts.append(.note(L("{name} sets a word; {other} guesses it. More balloons kept wins.",
                                 ["name": d.name(duel.setter), "other": d.name(duel.guesser)])))
        case .setting:
            parts.append(.prompt(L("{name}, type a word for {other}.", ["name": d.name(duel.setter), "other": d.name(duel.guesser)]),
                                 eyebrow: round + " · " + L("{name}, look away!", ["name": d.name(duel.guesser)])))
            parts.append(.play(.entry(name: "word", label: s.game.language == .zh ? L("A word in pinyin, 2 to 14 letters") : L("A word of 2 to 14 letters"),
                                      button: L("Hide it"), max: 20)))
        case .toGuesser:
            parts += TwoPlayers.cover(d, to: duel.guesser, eyebrow: round)
            cue = Cue(move: "tease", prop: "sealed_card", look: "panel")
        case .guessing, .solved:
            let g = duel.game!
            let text: String = if g.won { L("{name} saved the balloons!", ["name": d.name(duel.guesser)]) }
                else if g.lost { L("The word was {word}.", ["word": g.entry.word]) }
                else { L("{name}, guess {other}'s word.", ["name": d.name(duel.guesser), "other": d.name(duel.setter)]) }
            parts.append(.play(.lives(total: Games.BalloonWords.balloons, left: g.left, symbol: "balloon")))
            parts.append(.prompt(text, eyebrow: round))
            let tiles = BalloonWordsScreen.tiles(g)
            parts.append(.play(.letters(rows: [tiles], length: tiles.count, style: "slots", script: Keyboards.script(g.language))))
            if let keys = BalloonWordsScreen.keyboard(g) { parts.append(keys) }
            if duel.over {
                var facts: [(String, String)] = []
                if let tally = TwoPlayers.tally(BalloonWordsScreen.id, d) { facts.append(tally) }
                parts.append(TwoPlayers.result(d, winner: duel.winner, figure: "\(Format.integer(duel.kept[0] ?? 0)) – \(Format.integer(duel.kept[1] ?? 0))",
                                               facts: facts))
            } else if g.over {
                parts.append(.button(GameButton(L("Next round"), move: "next_round", style: .primary, symbol: "arrow.right")))
            }
        }
        if let note = ScreenKit.refusal(events) { parts.append(note) }
        return Board(parts, companion: cue, over: duel.over)
    }
}
