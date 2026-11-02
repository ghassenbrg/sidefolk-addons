import SidefolkExtensionKit

/// A board read part by part. `Board` stays what a screen says about a game; these are what the stage asks of it.
extension Board {
    var promptPart: (text: String, eyebrow: String?, chip: String?)? {
        for case .prompt(let text, let eyebrow, let chip) in parts { return (text, eyebrow, chip) }
        return nil
    }
    var scorePart: (you: Int, companion: Int, streak: Int?, best: Int?, rounds: Int?, picked: Bool, players: [String]?)? {
        for case .score(let you, let companion, let streak, let best, let rounds, let picked, let players) in parts {
            return (you, companion, streak, best, rounds, picked, players)
        }
        return nil
    }
    var resultPart: (figure: String, line: String?, ribbon: String?, tone: Tone, facts: [(String, String)], actions: [GameButton])? {
        for case .result(let figure, let line, let ribbon, let tone, let facts, let actions) in parts { return (figure, line, ribbon, tone, facts, actions) }
        return nil
    }
    var answersPart: (tiles: [Tile], layout: TileLayout, locked: Bool)? {
        for case .answers(let tiles, let layout, let locked) in parts { return (tiles, layout, locked) }
        return nil
    }
    var gridPart: (rows: Int, columns: Int, cells: [Cell], locked: Bool, numpad: Bool)? {
        for case .board(let rows, let columns, let cells, let locked, let numpad) in parts { return (rows, columns, cells, locked, numpad) }
        return nil
    }
    var timerPart: (id: String, seconds: Double)? {
        for case .timer(let id, let seconds) in parts { return (id, seconds) }
        return nil
    }
    var revealPart: Reveal? {
        for case .reveal(let reveal) in parts { return reveal }
        return nil
    }
    var buttons: [GameButton] {
        var out: [GameButton] = []
        for part in parts {
            if case .button(let b) = part { out.append(b) }
            if case .result(_, _, _, _, _, let actions) = part { out += actions }
        }
        return out
    }
    var primary: GameButton? { buttons.first { $0.style == .primary && !$0.disabled } }
    var firstChoice: (name: String, options: [ChoiceOption])? {
        for case .choice(let name, _, _, let options, _) in parts { return (name, options) }
        return nil
    }
    var companionButton: GameButton? {
        for case .button(let b) in parts where b.companion && !b.disabled { return b }
        return nil
    }
    /// A part that isn't one of the first ones, by asking.
    func play<T>(_ pick: (PlayPart) -> T?) -> T? {
        for case .play(let part) in parts { if let found = pick(part) { return found } }
        return nil
    }
    var hasPads: Bool { play { if case .pads = $0 { true } else { nil } } ?? false }
    var hasCups: Bool { play { if case .cups = $0 { true } else { nil } } ?? false }
    var hasSticks: Bool { play { if case .sticks = $0 { true } else { nil } } ?? false }
    var hasReflex: Bool { play { if case .reflex = $0 { true } else { nil } } ?? false }
    var hasPuzzle: Bool { play { if case .puzzle = $0 { true } else { nil } } ?? false }
    var hasKeys: Bool { play { if case .keys = $0 { true } else { nil } } ?? false }
    var hasLetters: Bool { play { if case .letters = $0 { true } else { nil } } ?? false }
    var hasEntry: Bool { play { if case .entry = $0 { true } else { nil } } ?? false }
    var numberPart: (min: Int, max: Int, label: String?, history: [(Int, String)], locked: Bool)? {
        play { if case .number(let min, let max, let label, let history, let locked) = $0 { (min, max, label, history, locked) } else { nil } }
    }
    var keysPart: (pages: [KeyPage], mode: String, length: Int?, script: String, locked: Bool)? {
        play { if case .keys(let pages, let mode, let length, let script, let locked) = $0 { (pages, mode, length, script, locked) } else { nil } }
    }
    var lettersPart: (rows: [[LetterTile]], length: Int, tries: Int?, style: String, draft: Bool, flip: Int?, script: String)? {
        play { if case .letters(let rows, let length, let tries, let style, let draft, let flip, let script) = $0 { (rows, length, tries, style, draft, flip, script) } else { nil } }
    }
    /// A part on this board takes ⌫ for itself, so it doesn't go back to the menu.
    var typesWithDelete: Bool {
        (keysPart?.mode == "spell") || numberPart != nil || hasEntry || play { if case .puzzle(_, _, _, let input, _, _, _, _, _, _, _) = $0, input == "digits" { true } else { nil } } == true
    }
}
