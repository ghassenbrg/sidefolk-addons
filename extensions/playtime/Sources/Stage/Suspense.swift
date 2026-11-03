import Foundation
import SidefolkExtensionKit

/// The order every result is shown in (D75, the founder's rule): the build-up first (the hands pumping, the coin spinning, the person's
/// pick pressed beside the companion's sealed card), then the reveal, then the verdict a beat after: colours, the score, words, the
/// companion's reaction, sounds and what VoiceOver hears. A screen sends its next board with the verdict in it; this is what shows until the
/// verdict's moment comes.
enum Suspense {
    static let revealMs = 3400
    static let beatMs = 800
    static let endHoldMs = 700

    /// The board to show first, and for how long, or nil when `next` gives nothing away.
    static func buildUp(from previous: Board?, to next: Board, picked: Int?) -> (board: Board, ms: Int)? {
        if next.revealPart != nil {
            var parts: [BoardPart] = []
            if let score = previous?.parts.first(where: isScore) { parts.append(score) }
            for part in next.parts {
                switch part {
                case .reveal: parts.append(part)
                case .answers(let tiles, let layout, _): parts.append(.answers(pending(tiles, picked), layout: layout, locked: true))
                default: break
                }
            }
            if let prompt = previous?.parts.first(where: isPrompt) {
                parts.insert(prompt, at: min(parts.count, parts.firstIndex { if case .answers = $0 { true } else { false } } ?? parts.count))
            }
            // The last throw stands a moment before the end card takes the table.
            return (Board(parts), next.over ? revealMs + endHoldMs : revealMs)
        }
        if let answers = next.answersPart, answers.locked, answers.tiles.contains(where: { $0.state == .right || $0.state == .wrong }),
           let previous, let before = previous.answersPart, !before.locked {
            let parts = previous.parts.compactMap { part -> BoardPart? in
                switch part {
                // A tile the help took away stays away.
                case .answers(let tiles, let layout, _): .answers(pending(tiles, picked, keepFaded: true), layout: layout, locked: true)
                case .button, .timer, .choice: nil
                default: part
                }
            }
            return (Board(parts), beatMs)
        }
        guard let previous else { return nil }
        // A row of letters just played: its tiles flip one by one (the reveal), and what it means waits until they have.
        if let letters = next.lettersPart, let flip = letters.flip, letters.rows.count > (previous.lettersPart?.rows.count ?? 0), letters.rows.indices.contains(flip) {
            // A row all right takes a little longer: its tiles hop once they have all turned.
            let solved = letters.rows[flip].allSatisfy { $0.mark == "right" }
            return (withheld(next, previous), 350 + letters.rows[flip].count * 220 + (solved ? 520 : 0))
        }
        // The cups lift in the build-up, slowly: that is the payoff, and the words, the score and the reaction wait for it.
        if next.cupsRevealed, !previous.cupsRevealed { return (withheld(next, previous), BoardDrawing.cupsLiftMs(next)) }
        // A wrong press reads at once: the pad shakes, the right one lights, the bubble says so, a beat, then the card.
        if next.padMissed != nil, previous.hasPads { return (withheld(next, previous), BoardDrawing.padMissMs) }
        return decides(next, after: previous) ? (withheld(next, previous), beatMs) : nil
    }

    private static func isScore(_ part: BoardPart) -> Bool { if case .score = part { true } else { false } }
    private static func isPrompt(_ part: BoardPart) -> Bool { if case .prompt = part { true } else { false } }

    /// Whether `next` settles something `previous` left open: a point scored, a line won, the cups lifted, a reflex timed, a guess judged, a
    /// card turned with the companion's reaction, the end card.
    static func decides(_ next: Board, after previous: Board) -> Bool {
        // A last line or pair already shown, score and all, was the build-up to the end card.
        if next.resultPart != nil, previous.resultPart == nil, previous.gridPart?.cells.contains(where: { $0.state == "win" }) != true { return true }
        if let s = next.scorePart, let p = previous.scorePart, s.you > p.you || s.companion > p.companion { return true }
        if let g = next.gridPart, g.cells.contains(where: { $0.state == "win" }), previous.gridPart?.cells.contains(where: { $0.state == "win" }) != true { return true }
        if let g = next.gridPart, next.companion != nil, g.cells.contains(where: { $0.animate == "flip" }) { return true }
        if next.cupsRevealed, !previous.cupsRevealed { return true }
        if next.reflexShows, previous.reflexArmed { return true }
        if let n = next.numberPart, n.history.count > (previous.numberPart?.history.count ?? 0) { return true }
        return false
    }

    /// `next` with what it decides held back: the previous score, words, keys, guesses and lives, no win drawn, the cups lifting on their own
    /// run, the reflex waiting, nothing to press, no end card, notes or cue.
    static func withheld(_ next: Board, _ previous: Board) -> Board {
        let before = previous.parts.first(where: isPrompt)
        var parts = next.parts.compactMap { part -> BoardPart? in
            switch part {
            case .score: return previous.parts.first(where: isScore)
            // The game's words may say what happened ("You win this game!"): the previous ones stay meanwhile.
            case .prompt: return before
            case .result, .note, .facts, .button, .timer, .choice: return nil
            case .board(let rows, let columns, var cells, _, let numpad):
                for i in cells.indices where cells[i].state == "win" { cells[i].state = nil }
                return .board(rows: rows, columns: columns, cells: cells, locked: true, numpad: numpad)
            case .play(let play): return withheld(play, next: next, previous: previous).map(BoardPart.play)
            default: return part
            }
        }
        if let before, !parts.contains(where: isPrompt) {
            parts.insert(before, at: parts.firstIndex { !isScore($0) } ?? parts.count)
        }
        // A puzzle's dock stays through its last beat, nothing to press, so the board above it doesn't move as it is solved.
        if next.hasPuzzle {
            parts += previous.parts.compactMap { part -> BoardPart? in
                guard case .button(var button) = part else { return nil }
                button.disabled = true
                return .button(button)
            }
        }
        return Board(parts, turn: previous.turn)
    }

    private static func withheld(_ part: PlayPart, next: Board, previous: Board) -> PlayPart? {
        switch part {
        case .keys:
            guard let k = previous.keysPart else { return nil }
            return .keys(pages: k.pages, mode: k.mode, length: k.length, script: k.script, locked: true)
        // The last balloon pops in the build-up: that is what the end card follows, and its word stays hidden until then.
        case .letters where next.play({ if case .lives(_, let left, _) = $0 { left } else { nil } }) == 0:
            return previous.play { if case .letters = $0 { $0 } else { nil } } ?? part
        case .entry(let name, let kind, let label, let placeholder, let button, let max, _):
            return .entry(name: name, kind: kind, label: label, placeholder: placeholder, button: button, max: max, locked: true)
        case .cups(let count, let hide, _, let ms, let picked, _, let gem, _):
            return .cups(count: count, hide: hide, swaps: [], swapMs: ms, picked: picked, revealed: false, gem: gem, locked: true)
        case .reflex(_, let window, let wait, let go, let early, _, let keys):
            return .reflex(afterMs: nil, windowMs: window, wait: wait, go: go, early: early, shows: nil, keys: keys)
        case .meter:
            return previous.play { if case .meter = $0 { $0 } else { nil } } ?? part
        case .number(let min, let max, let label, _, _):
            return .number(min: min, max: max, label: previous.numberPart?.label ?? label, history: previous.numberPart?.history ?? [], locked: true)
        case .sticks(let total, let left, let take, let groups, let hint, let taken, let by, _):
            return .sticks(total: total, left: left, take: take, groups: groups, hint: hint, taken: taken, takenBy: by, locked: true)
        case .pads(let pads, let steps, let ms, let locked, let length, let done): return .pads(pads, play: locked ? steps : [], stepMs: ms, locked: true, length: length, done: done)
        case .puzzle(let rows, let columns, let cells, let input, let digits, let box, let edges, let plots, let seconds, _, _):
            // The last mark settles on a still board: the clock stopped, nothing to press yet.
            return .puzzle(rows: rows, columns: columns, cells: cells, input: input, digits: digits, box: box, edges: edges, plots: plots, seconds: seconds, running: false, locked: true)
        default: return part
        }
    }

    /// The tiles while the verdict waits: the person's pick pressed, nothing judged, the companion's pick still hidden.
    static func pending(_ tiles: [Tile], _ picked: Int?, keepFaded: Bool = false) -> [Tile] {
        tiles.enumerated().map { i, tile in
            var t = tile
            t.state = i == picked ? .picked : keepFaded && tile.state == .faded ? .faded : .none
            t.companion = false
            return t
        }
    }

    /// Whether a board gives a result away: a judged tile, the companion's revealed pick, an end card, a fact, a cue, or words of its own. A
    /// build-up board must have none of these.
    static func showsVerdict(_ board: Board) -> Bool {
        if board.companion != nil || board.over { return true }
        for part in board.parts {
            switch part {
            case .answers(let tiles, _, _) where tiles.contains(where: { $0.state == .right || $0.state == .wrong || $0.companion }): return true
            case .result, .note: return true
            case .board(_, _, let cells, _, _) where cells.contains(where: { $0.state == "win" }): return true
            default: continue
            }
        }
        return board.cupsRevealed || board.reflexShows
    }
}

extension Board {
    var cupsRevealed: Bool { play { if case .cups(_, _, _, _, _, let revealed, _, _) = $0 { revealed } else { nil } } ?? false }
    /// The pad that was right, on a board a wrong press ended.
    var padMissed: Int? { play { if case .pads(_, let steps, _, true, _, _) = $0 { steps.first } else { nil } } }
    var reflexShows: Bool { play { if case .reflex(_, _, _, _, _, let shows, _) = $0 { shows != nil } else { nil } } ?? false }
    var reflexArmed: Bool { play { if case .reflex(let after, _, _, _, _, let shows, _) = $0 { after != nil && shows == nil } else { nil } } ?? false }
}
