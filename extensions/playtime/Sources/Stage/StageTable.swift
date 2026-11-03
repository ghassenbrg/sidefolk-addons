import Foundation
import SidefolkExtensionKit

/// A board laid out as one piece rather than stacked: every part has its place from the first move to the last, whatever it says and whatever has come or gone, and what
/// isn't there yet has its room kept. Only for play: an end card, a name to type or a cover stack as usual.
enum TableLayout {
    case triviaSetup, triviaQuestion, numbersSetup, numbersGuess, numbersAsked, animalAsks, animalTeach, hands
}

extension BoardDrawing {
    var gameTable: TableLayout? {
        guard !ended else { return nil }
        switch ctx.entry.id {
        case TriviaScreen.id:
            if board.answersPart != nil { return .triviaQuestion }
            if board.parts.contains(where: { if case .choice("topic", _, _, _, _) = $0 { true } else { false } }) { return .triviaSetup }
        case HigherLowerScreen.id:
            if board.numberPart != nil { return .numbersGuess }
            if board.answersPart != nil, board.counterPart != nil { return .numbersAsked }
            if board.parts.contains(where: { if case .choice("mode", _, _, _, _) = $0 { true } else { false } }) { return .numbersSetup }
        case GuessAnimalScreen.id:
            if board.teaches || (ctx.buildUp && ctx.previous?.teaches == true) { return .animalTeach }
            if board.answersPart != nil { return .animalAsks }
        case RockPaperScissorsScreen.id:
            if board.answersPart != nil || board.revealPart != nil || board.hasCover { return .hands }
        default: break
        }
        return nil
    }

    /// A stage of its own height for a whole game, set by the scene it stands in.
    var stageTall: Double? {
        switch gameTable {
        case .triviaQuestion: 90
        case .numbersGuess, .numbersAsked: 100
        case .animalAsks, .animalTeach: 118
        case .hands: 100
        default: nil
        }
    }

    /// A bubble that leaves room beside it: the counter of "you guess" stands in the same row.
    var stageBubbleWidth: Double? {
        switch gameTable {
        case .triviaQuestion: 206
        case .numbersGuess: 104
        default: nil
        }
    }

    func tableBlock() -> PartBlock? {
        guard let table = gameTable else { return nil }
        let node: Node = switch table {
        case .triviaSetup: triviaSetupTable()
        case .triviaQuestion: triviaTable()
        case .numbersSetup: numbersSetupTable()
        case .numbersGuess: numbersGuessTable()
        case .numbersAsked: numbersAskedTable()
        case .animalAsks: animalTable()
        case .animalTeach: animalTeachTable()
        case .hands: handsTable()
        }
        return PartBlock(.box("table", w: Self.inner, h: playRoom) { node }, height: playRoom)
    }

    /// The board's buttons, wherever its table puts them. During a build-up the ones it had stay in their places, faded, rather than going and coming back.
    var tableButtons: [GameButton] {
        func own(_ b: Board) -> [GameButton] { b.parts.compactMap { part in if case .button(let button) = part, !button.companion { button } else { nil } } }
        let now = own(board)
        guard ctx.buildUp, now.isEmpty, let before = ctx.previous else { return now }
        return own(before).map { var b = $0; b.disabled = true; return b }
    }

    /// A quiet link with a line under it, for the way out that isn't the game's point.
    func quietLink(_ b: GameButton, id: String, y: Double, width: Double = BoardDrawing.inner) -> Node {
        let w = Swift.min(TextFit.width(b.label, size: 13, weight: "bold") + 8, width), h = 24.0
        if !b.disabled, let key = b.key { keys.append(StageKey(key: key, id: id.replacingOccurrences(of: ".", with: "_") + "_key", area: "button", value: b.move)) }
        var link = Node.box(id, x: (width - w) / 2, y: y, w: w, h: h) {
            Node.words(b.label, size: 13, weight: "bold", align: "center", minScale: 0.7, w: w, h: h - 3)
            Node.rect(fill: Paint.ink).id(id + ".line").at(4, h - 4).size(w - 8, 1)
        }.area("button", value: b.move, label: b.label, disabled: b.disabled, hover: AreaLook(opacity: 0.75), press: AreaLook(opacity: 0.55), sound: "sounds/tap.wav")
        if b.disabled { link = link.opacity(0.45) }
        return link
    }

    /// Arrow keys step a picked choice: what is picked is what the navy outline shows, so the keyboard needs no ring of its own. `columns` for a grid.
    func choiceArrows(name: String, options: [ChoiceOption], selected: String?, columns: Int) {
        guard let at = options.firstIndex(where: { $0.value == selected }) else { return }
        var steps: [(String, Int)] = [("right", ctx.rtl ? -1 : 1), ("left", ctx.rtl ? 1 : -1)]
        if columns < options.count { steps += [("down", columns), ("up", -columns)] }
        for (key, step) in steps where options.indices.contains(at + step) {
            keys.append(StageKey(key: key, id: "\(name)_\(key)", area: "choice", value: "\(name)|\(options[at + step].value)"))
        }
    }

    /// A part coming to its place when the board that holds it is new: a short rise, so it reads as arriving rather than blinking on.
    func arrive(_ id: String, from: Double = 8, delay: Double = 0, ms: Double = 220) {
        anims.append(Anim.keys(id, [["t": 0, "y": from, "opacity": 0], ["t": 1, "y": 0, "opacity": 1]], ms: ms, ease: "out").delay(ms: delay))
    }

    /// Words that were refused shake the thing they were typed in.
    func shake(_ id: String, x: Double = 0) {
        let frames = (0...12).map { n -> [String: Double] in
            let a = Double(n) / 12
            return ["t": a, "x": x + 6 * sin(a * .pi * 6) * (1 - a)]
        }
        anims.append(.keys(id, frames, ms: 360))
    }
}

extension Board {
    var counterPart: (words: String?, caption: String?, range: String?)? {
        play { if case .counter(let words, let caption, let range) = $0 { (words, caption, range) } else { nil } }
    }
    var meterPart: (value: Double, label: String?)? {
        play { if case .meter(let value, let label, _, _) = $0 { (value, label) } else { nil } }
    }
    /// Guess My Animal's page for a new animal.
    var teaches: Bool { play { if case .entry("animal", _, _, _, _, _, _) = $0 { true } else { nil } } ?? false }
    /// The cover that passes the Mac over: a ready button, nothing else to do.
    var hasCover: Bool { buttons.contains { $0.move == "ready" } }
    func entryPart(_ wanted: String) -> (label: String?, placeholder: String?, locked: Bool, max: Int)? {
        play { if case .entry(wanted, _, let label, let placeholder, _, let max, let locked) = $0 { (label, placeholder, locked, max) } else { nil } }
    }
    func choicePart(_ wanted: String) -> (label: String?, options: [ChoiceOption], selected: String?)? {
        for case .choice(wanted, let label, _, let options, let selected) in parts { return (label, options, selected) }
        return nil
    }
}
