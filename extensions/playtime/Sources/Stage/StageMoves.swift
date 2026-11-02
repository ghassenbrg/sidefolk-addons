import SidefolkExtensionKit

/// What a move on a scene comes to: a move for the game, the same board drawn again after a key of its own, or back to the menu.
enum StageAction {
    case play(Move)
    case redraw
    case back
    case ignore
}

/// The scene's typed moves as the board's: only ever what the scene on screen offered. What Sidefolk's panel used to keep for a board
/// (what is typed, the arrows' cursor) moved here, one move a key, and a drawn board's own areas name what they stand for.
enum StageMoves {
    static func action(_ move: SurfaceMove, board: Board, local: inout LocalParts) -> StageAction {
        if let own = BoardDrawing.padsMove(move, board: board, local: &local) ?? BoardDrawing.cupsMove(move, board: board, local: &local)
            ?? BoardDrawing.reflexMove(move, board: board, local: &local) ?? BoardDrawing.sticksMove(move, board: board, local: &local)
            ?? BoardDrawing.puzzleMove(move, board: board, local: &local) { return own }
        switch move {
        case .click(let area, let value, _): return click(area, value ?? "", board: board, local: &local)
        case .key(let id, let character, _): return key(id, character, board: board, local: &local)
        case .entry(let name, let text): return entry(name, text, board: board)
        case .timer: return .play(.timeout)
        case .next: return .play(.next)
        case .back: return .back
        default: return .ignore
        }
    }

    private static func click(_ area: String, _ value: String, board: Board, local: inout LocalParts) -> StageAction {
        switch area {
        case "answer": return Int(value).map { .play(.answer($0)) } ?? .ignore
        case "cell":
            let n = value.split(separator: ",").compactMap { Int($0) }
            return n.count == 2 ? .play(.cell(row: n[0], column: n[1])) : .ignore
        case "button": return value == BoardDrawing.backMove ? .back : .play(.button(value))
        case "choice":
            let bits = value.split(separator: "|", maxSplits: 1).map(String.init)
            return bits.count == 2 ? .play(.choice(name: bits[0], value: bits[1])) : .ignore
        case "digit":
            switch value {
            case "delete": return delete(&local)
            case "return": return submit(board: board, local: local)
            default: return typeDigit(value, board: board, local: &local)
            }
        case "draft": return value == "delete" ? delete(&local) : submit(board: board, local: local)
        case "key": return type(value, board: board, local: &local)
        case "keys_page":
            local.page = Int(value) ?? 0
            return .redraw
        default: return .ignore
        }
    }

    private static func key(_ id: String, _ character: String?, board: Board, local: inout LocalParts) -> StageAction {
        switch id {
        case "digit":
            guard let d = character?.first?.wholeNumberValue else { return .ignore }
            return typeDigit(String(d), board: board, local: &local)
        case "letter": return character.map { type($0, board: board, local: &local) } ?? .ignore
        case "draft_delete": return delete(&local)
        case "draft_return": return submit(board: board, local: local)
        case "back_delete": return .back
        case "arrow_left", "arrow_right", "arrow_up", "arrow_down": return arrow(id, board: board, local: &local)
        case "cursor_return", "cursor_space":
            guard let c = local.cursor, let g = board.gridPart else { return .ignore }
            return .play(.cell(row: c / g.columns, column: c % g.columns))
        default: return .ignore
        }
    }

    private static func entry(_ name: String, _ text: String, board: Board) -> StageAction {
        let kind = board.play { part -> String? in if case .entry(name, let kind, _, _, _, _, _) = part { kind } else { nil } }
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return .ignore }
        return kind == "word" ? .play(.word(value.lowercased())) : .play(.text(name: name, value: value))
    }

    /// The arrow keys move the pointer over cells, starting at the first. Left and right follow the reading direction.
    private static func arrow(_ id: String, board: Board, local: inout LocalParts) -> StageAction {
        guard let g = board.gridPart else { return .ignore }
        local.cursor = move(id, cursor: local.cursor, columns: g.columns, count: g.rows * g.columns, rtl: Language.code == "ar")
        return .redraw
    }

    static func move(_ id: String, cursor: Int?, columns: Int, count: Int, rtl: Bool) -> Int {
        let raw = switch id {
        case "arrow_left": -1
        case "arrow_right": 1
        case "arrow_up": -columns
        default: columns
        }
        let step = rtl && abs(raw) == 1 ? -raw : raw
        return min(max((cursor ?? -step) + step, 0), count - 1)
    }

    // MARK: Typing

    private static func typeDigit(_ d: String, board: Board, local: inout LocalParts) -> StageAction {
        guard let field = board.numberPart, !field.locked, local.draft.count < String(field.max).count else { return .ignore }
        local.draft = local.draft == "0" ? d : local.draft + d
        return .redraw
    }

    private static func delete(_ local: inout LocalParts) -> StageAction {
        guard !local.draft.isEmpty else { return .ignore }
        local.draft.removeLast()
        return .redraw
    }

    /// A letter on the keyboard part: sent at once, or added to the word being spelled.
    private static func type(_ letter: String, board: Board, local: inout LocalParts) -> StageAction {
        guard let keys = board.keysPart, !keys.locked else { return .ignore }
        if keys.mode == "letter" { return .play(.letter(letter)) }
        guard local.draft.count < (keys.length ?? 0) else { return .ignore }
        local.draft += letter
        return .redraw
    }

    /// Return on a word or a number being typed.
    private static func submit(board: Board, local: LocalParts) -> StageAction {
        if let keys = board.keysPart, keys.mode == "spell", local.draft.count == keys.length { return .play(.word(local.draft.lowercased())) }
        if let field = board.numberPart, let n = Int(local.draft), (field.min...field.max).contains(n) { return .play(.number(n)) }
        return .ignore
    }

    /// A new board shows: a word accepted (a new row) or a part gone clears what was typed; a refused one stays to be fixed.
    static func settle(_ board: Board, local: inout LocalParts) {
        if board.keysPart?.mode != "spell", board.numberPart == nil { local.draft = "" }
        if let letters = board.lettersPart, letters.rows.count != local.rowsSeen { local.draft = "" }
        local.rowsSeen = board.lettersPart?.rows.count ?? 0
        if board.numberPart?.history.count != local.guessesSeen { local.draft = "" }
        local.guessesSeen = board.numberPart?.history.count
        if let g = board.gridPart, let c = local.cursor, c >= g.rows * g.columns { local.cursor = nil }
        if board.gridPart == nil, !board.hasPuzzle, !board.hasCups { local.cursor = nil }
        BoardDrawing.puzzleSettle(board, local: &local)
        local.page = 0
    }
}
