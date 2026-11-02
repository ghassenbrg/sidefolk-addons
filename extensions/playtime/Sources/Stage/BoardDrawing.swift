import Foundation
import SidefolkExtensionKit

/// What Sidefolk used to keep for a board while it showed (PartsState), now the program's, one move a key: what is typed,
/// where the arrows point, Sudoku's notes switch, a keyboard's page. Saved with the session.
struct LocalParts: Codable, Equatable {
    /// Letters or digits typed, until Return sends them.
    var draft = ""
    /// The cell or cup the arrow keys point at.
    var cursor: Int?
    /// Sudoku: numbers go in as pencil notes.
    var notes = false
    /// The page of a keyboard with several.
    var page = 0
    /// A plot stretched with the arrow keys: the cell it started on.
    var dragFrom: Int?
    /// A plot was just planted: heard as the board comes back.
    var plantSound = false
    /// Rows and guesses on the last board, so a new one (a word or number accepted) clears the draft.
    var rowsSeen = 0
    var guessesSeen: Int?
    /// What is playing by itself (Stage/Playback.swift).
    var playback: Playback?
    /// The pad just pressed, lit once by the next scene.
    var lit: Int?
    /// The reflex was pressed before its signal: "Too soon!" at once, until the verdict's moment.
    var early = false
}

/// What a board needs from the game round it.
struct StageContext {
    var entry: GameEntry
    /// The last board shown, to see what changed: what shakes, what is stamped, what eases.
    var previous: Board?
    /// A new board, rather than the same one drawn again after a key: only a new one reacts, sounds and arrives.
    var fresh = true
    /// The answer pressed and waiting for its verdict: drawn pressed during the build-up.
    var pendingAnswer: Int?
    /// A build-up: the beat before a verdict.
    var buildUp = false
    /// How long this scene shows before Sidefolk asks for the next (a build-up's moment).
    var afterMs: Int?
    var local = LocalParts()
    var rtl: Bool { Language.code == "ar" }
}

/// A key the scene takes; `area` presses that area with its look, otherwise the move is `.key(id:)`.
struct StageKey {
    var key: String
    var id: String
    var area: String?
    var value: String?
    var seat = false
    var timedFromMs: Double?
    var always = false
}

/// A board as a scene: the Play panel's layout (PlayView, BoardView) in boxes. Every value here was read from the panel's
/// SwiftUI and carried over; the frame's 44 pt header replaces the game's own (D99, as amended). One object per scene, which
/// each part adds its animations and keys to.
final class BoardDrawing {
    static let width = 400.0, pad = 14.0, inner = 372.0, boardRoom = 540.0, maxHeight = 676.0

    let board: Board
    let ctx: StageContext
    var anims: [Anim] = []
    var keys: [StageKey] = []
    var timers: [(id: String, ms: Double)] = []
    /// A part asks for the next scene by itself (`untilPlayed`).
    var partAfterMs: Int?
    /// What many nodes share, said once: a 9 × 9 board or a played-out word on a kana keyboard runs past the 64 KB a scene may be otherwise.
    var styles: [String: [String: Any]] = [:]
    var look: Look { ctx.entry.look }

    init(_ board: Board, _ ctx: StageContext) {
        self.board = board
        self.ctx = ctx
    }

    /// The end card stands in for the play area: the last move was seen in its build-up, and the board under the card would
    /// push the panel past a small screen. What isn't play (notes, facts, a level to pick, buttons) stays.
    var ended: Bool { board.over && board.resultPart != nil }

    /// A node every use of `name` starts from; the first use says what it is.
    func styled(_ name: String, _ node: @autoclosure () -> Node) -> Node {
        if styles[name] == nil { styles[name] = node().json }
        return Node(["style": name])
    }

    private func isPlay(_ part: BoardPart) -> Bool {
        switch part {
        case .answers, .board, .timer, .play: true
        default: false
        }
    }

    func scene() -> Scene {
        var y = 7.0
        var content: [Node] = []
        // A puzzle is played alone against the clock: no "You vs" bar, so a 9 × 9 Sudoku keeps its room.
        if !board.hasPuzzle {
            let bar = scoreBar()
            content.append(bar.node.at(Self.pad, y))
            y += bar.height + 8
        }
        let parts = boardBlocks()
        let boardHeight = parts.reduce(-8.0) { $0 + $1.height + 8 } + 4
        let room = min(Self.boardRoom, boardHeight)
        var offset = 2.0
        var stacked = parts.map { block -> Node in
            defer { offset += block.height + 8 }
            return block.node.at(Self.pad, offset)
        }
        // What stands over what follows (the companion's feet on its table) comes last, so it reads the same wherever the scene is drawn.
        stacked = stacked.filter { $0.json["z"] == nil } + stacked.filter { $0.json["z"] != nil }
        if boardHeight > Self.boardRoom {
            content.append(Node.scroll(contentHeight: boardHeight) { stacked }.id("board").at(0, y).size(Self.width, room))
        } else {
            content.append(Node.box("board", y: y, w: Self.width, h: room) { stacked })
        }
        y += room + 8
        let hint = hintRow()
        content.append(hint.node.at(Self.pad, y))
        y += hint.height + 10
        let height = min(y, Self.maxHeight)

        var scene = Scene(width: Self.width, height: height) {
            SceneBackdrop.nodes(look, width: Self.width, height: height)
            content.map(\.rounded)
        }
        .title(ctx.entry.title)
        .withBack()
        .speaker(GameSoundSetting.key(ctx.entry.id))
        .transition(ms: 350)
        .animating(anims)
        if ctx.fresh { scene = cued(scene) }
        for (id, ms) in timers { scene = scene.timer(id, ms: ms) }
        for (name, values) in styles { scene = scene.style(name, values) }
        for k in keys { scene = scene.key(k.key, id: k.id, area: k.area, value: k.value, seat: k.seat, timedFromMs: k.timedFromMs, always: k.always) }
        if let after = partAfterMs ?? board.afterMs ?? ctx.afterMs { scene = scene.after(ms: after) }
        if ctx.fresh, let words = spoken { scene = scene.announcing(words) }
        if board.over, let result = board.resultPart {
            let two = board.scorePart?.players != nil
            scene = scene.over(outcome: two ? nil : Verdict(tone: result.tone).rawValue)
        }
        return scene
    }

    /// The companion's reaction and the board's sound, from the fixed lists. The cue's line has no form: an extension's words
    /// stay inside its surface (D98), so the companion says nothing on the desktop or aloud.
    private func cued(_ scene: Scene) -> Scene {
        var out = scene
        if let reveal = board.revealPart, ctx.buildUp {
            let move = switch reveal { case .hands: "pump"; case .coin: "flick"; case .dice: "roll" }
            let sound = switch reveal { case .hands: "whoosh"; case .coin: "flip"; case .dice: "rattle" }
            return out.react(Reaction(move: move)).animating(.sequence([.sound("sounds/\(sound).wav")]))
        }
        if ctx.buildUp { return out.react(Reaction(effect: "question")).animating(.sequence([.sound("sounds/tick.wav")])) }
        guard let cue = board.companion else { return out }
        let look: String? = (cue.look as? String) ?? (cue.look == nil ? nil : "panel")
        out = out.react(Reaction(move: cue.move, effect: cue.effect, prop: cue.prop, look: look))
        if let sound = cue.sound { out = out.animating(.sequence([.sound("sounds/\(sound).wav")])) }
        return out
    }

    /// VoiceOver hears the verdict when it shows.
    private var spoken: String? {
        guard !ctx.buildUp, let a = board.answersPart, a.locked else { return nil }
        if a.tiles.contains(where: { $0.state == .wrong }) { return L("wrong") }
        if a.tiles.contains(where: { $0.state == .right }) { return L("right") }
        return nil
    }

    /// The parts with neighbouring buttons gathered into one row, and the prompt as the companion's stage.
    private func boardBlocks() -> [PartBlock] {
        var out: [PartBlock] = []
        var row: [GameButton] = []
        var stageDone = false
        func flush() {
            if !row.isEmpty { out.append(buttonRow(row, id: "buttons.\(out.count)")) }
            row = []
        }
        for part in board.parts {
            if ended, isPlay(part) { continue }
            if ended, case .choice(_, _, .segmented, _, _) = part { continue }
            if case .button(let b) = part {
                if !b.companion { row.append(b) }
                continue
            }
            flush()
            switch part {
            case .score: continue
            case .prompt(let text, let eyebrow, let chip):
                out.append(stage(text: text, eyebrow: eyebrow, chip: chip))
                stageDone = true
            default:
                if let block = block(part) { out.append(block) }
            }
        }
        flush()
        // A board without words still has the companion in its scene, unless it is the end card alone.
        if !stageDone, board.resultPart == nil { out.insert(stage(text: nil, eyebrow: nil, chip: nil), at: 0) }
        return out
    }

    private func block(_ part: BoardPart) -> PartBlock? {
        switch part {
        case .answers(let tiles, let layout, let locked): return answers(tiles, layout: layout, locked: locked)
        case .board(let rows, let columns, let cells, let locked, let numpad): return grid(rows: rows, columns: columns, cells: cells, locked: locked, numpad: numpad)
        case .result(let figure, let line, let ribbon, let tone, let facts, let actions):
            return endCard(figure: figure, line: line, ribbon: ribbon, tone: tone, facts: facts, actions: actions)
        case .reveal(let reveal): return revealCard(reveal)
        case .note(let text, let title, let tone): return note(text, title: title, tone: tone)
        case .facts(let items): return factsRow(items)
        case .choice(let name, let label, let style, let options, let selected):
            return choice(name: name, label: label, style: style, options: options, selected: selected, compact: false)
        case .timer(let id, let seconds):
            // Inside the bubble when there is a prompt.
            startClock(id: id, seconds: seconds)
            guard board.promptPart == nil else { return nil }
            return PartBlock(timerBar(id: id, seconds: seconds, width: Self.inner), height: 5)
        case .play(let play): return playBlock(play)
        case .prompt, .score, .button: return nil
        }
    }

    private func playBlock(_ part: PlayPart) -> PartBlock {
        switch part {
        case .pads(let pads, let play, let stepMs, let locked): return onTable(padsPart(pads, play: play, stepMs: stepMs, locked: locked))
        case .cups(let count, let hide, let swaps, let swapMs, let picked, let revealed, let gem, let locked):
            return onTable(cupsPart(count: count, hide: hide, swaps: swaps, swapMs: swapMs, picked: picked, revealed: revealed, gem: gem, locked: locked))
        case .reflex(let after, let window, let wait, let go, let early, let shows, let keys):
            return onTable(reflexPart(afterMs: after, windowMs: window, wait: wait, go: go, early: early, shows: shows, keys: keys))
        case .meter(let value, let label, let low, let high): return meter(value, label: label, low: low, high: high)
        case .number(let min, let max, let label, let history, let locked): return numberField(min: min, max: max, label: label, history: history, locked: locked)
        case .letters(let rows, let length, let tries, let style, let draft, let flip, let script):
            return lettersPart(rows: rows, length: length, tries: tries, style: style, draft: draft, flip: flip, script: script)
        case .keys(let pages, let mode, let length, let script, let locked): return keyboard(pages: pages, mode: mode, length: length, script: script, locked: locked)
        case .entry(let name, let kind, let label, let placeholder, let button, let max, let locked):
            return entry(name: name, kind: kind, label: label, placeholder: placeholder, button: button, max: max, locked: locked)
        case .sticks(let total, let left, let take, let groups, let hint, let taken, let takenBy, let locked):
            return onTable(sticksPart(total: total, left: left, take: take, groups: groups, hint: hint, taken: taken, takenBy: takenBy, locked: locked))
        case .lives(let total, let left, let symbol): return lives(total: total, left: left, symbol: symbol)
        case .puzzle(let rows, let columns, let cells, let input, let digits, let box, let edges, let plots, let seconds, let running, let locked):
            return puzzlePart(rows: rows, columns: columns, cells: cells, input: input, digits: digits, box: box, edges: edges, plots: plots, seconds: seconds, running: running, locked: locked)
        }
    }

    /// A prop standing on the scene's table: the table runs the panel's full width behind it and up over the companion's lower
    /// half, so the companion peeks over it.
    private func onTable(_ inner: PartBlock) -> PartBlock {
        let height = inner.height + 10
        return PartBlock(.box("table", w: Self.inner, h: height) {
            SceneBackdrop.table(look, x: -Self.pad, y: -6, width: Self.width, height: height + 14)
            inner.node.at(0, 6)
        }, height: height)
    }
}

/// The scene behind a game: its illustration filling the panel, by day in light mode and the same place at night in dark mode
/// (its own painting, not the day dimmed), standing on the panel's bottom edge. Never anything a game's data sent.
enum SceneBackdrop {
    /// Every painting is 768 × 1024.
    static let aspect = 1024.0 / 768.0

    static func nodes(_ look: Look, width: Double, height: Double) -> [Node] {
        let tall = max(width * aspect, height)
        let wide = tall / aspect
        var out: [Node] = [
            Node.rect(fill: .surface).id("bg.base").size(width, height),
            // Named by the panel's height: it stands on the bottom edge at once when the panel grows, rather than easing up from under it.
            Node.image(look.scene, dark: look.sceneAtNight, fit: "fill").id("bg.scene.\(Int(height))").at((width - wide) / 2, height - tall).size(wide, tall),
        ]
        // A night painting is already calm: a touch darker in dark mode, as the panel drew it.
        if !look.night { out.append(Node.rect(fill: .adaptive(light: "#00000000", dark: "#00000029")).id("bg.dim").size(width, height)) }
        // The top softened: the frame's header stands on the panel's own surface.
        out.append(Node.rect().gradient([Color.surface.tuned(alpha: 0.6), Color.surface.tuned(alpha: 0)]).id("bg.veil").size(width, 90))
        return out
    }

    /// The wooden table at the bottom of a game's scene: the same picture's last part, stretched as the panel stretched it.
    static func table(_ look: Look, x: Double, y: Double, width: Double, height: Double) -> Node {
        let whole = height / 0.28
        return Node.box("table.strip", x: x, y: y, w: width, h: height) {
            Node.image(look.scene, dark: look.sceneAtNight, fit: "fill").at(0, height - whole).size(width, whole)
            Node.rect(fill: .adaptive(light: "#00000000", dark: "#0000001F")).size(width, height)
            // Its back edge softened, so the companion behind it sinks into the table rather than being cut.
            Node.rect().gradient([Paint.clear("#000000", 0.12), Paint.clear("#000000", 0)], from: (0.5, 0), to: (0.5, 0.25)).size(width, height)
        }.clip()
    }
}
