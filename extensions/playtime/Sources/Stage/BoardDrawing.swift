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
    /// The dome was pressed in time: it stays down until the verdict's moment.
    var boopPressed = false
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
    /// The canvas: the same for every board, so the panel never changes size.
    static let width = 400.0, pad = 14.0, inner = 372.0, canvas = 620.0, footerRoom = 26.0

    /// What the board has to itself, once the header, the stage and the controls have their places. A part sizes itself to this.
    var playRoom = 400.0

    let board: Board
    let ctx: StageContext
    var anims: [Anim] = []
    var keys: [StageKey] = []
    var timers: [(id: String, ms: Double)] = []
    /// A part asks for the next scene by itself (`untilPlayed`).
    var partAfterMs: Int?
    /// That, under Reduce Motion, when what it waits for doesn't play.
    var partAfterStillMs: Int?
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

    /// Every game's layout, top to bottom, in places that never move while it is played: the title, the score, the round; the companion and its bubble (one
    /// size, however many lines it says); the board, centred in what is left; the controls; the line of keys. The panel is one height for every game, the menu and
    /// the end card, so nothing shifts under the pointer. Whatever comes and goes during a game has its room kept.
    func scene() -> Scene {
        let head = header()
        // The controls first: the board's room is what they and the stage leave.
        let controls = dock()
        let bottom = Self.canvas - Self.footerRoom - (controls.map { $0.height + 8 } ?? 0)
        let said = ended ? nil : stage(text: board.promptPart?.text, chip: board.promptPart?.chip)
        let top = 4 + head.height + (said.map { $0.height + 6 } ?? 0)
        playRoom = bottom - top - 6
        let parts = playBlocks()
        let height = parts.reduce(-8.0) { $0 + $1.height + 8 }
        var offset = height <= playRoom ? ((playRoom - height) / 2).rounded() : 0
        let stacked = parts.map { block -> Node in
            defer { offset += block.height + 8 }
            return block.node.at(Self.pad, offset)
        }
        var content: [Node] = [head.node.at(Self.pad, 4)]
        if height > playRoom {
            content.append(Node.scroll(contentHeight: height) { stacked }.id("board").at(0, top).size(Self.width, playRoom))
        } else {
            // The end card has its own room: a game starting after it arrives in place, rather than gliding from where the card stood.
            content.append(Node.box(ended ? "board.end" : "board", y: top, w: Self.width, h: playRoom) { stacked })
        }
        // Over the board: the companion may lean on what it plays on.
        if let said { content.append(said.node.at(Self.pad, 4 + head.height).z(1)) }
        if let controls { content.append(controls.node.at(Self.pad, bottom)) }
        content.append(hintRow().node.at(Self.pad, Self.canvas - Self.footerRoom))

        var scene = Scene(width: Self.width, height: Self.canvas) {
            SceneBackdrop.nodes(look, width: Self.width, height: Self.canvas)
            content.map(\.rounded)
        }
        .title(L("A little break, together."))
        .withBack()
        .speaker(GameSoundSetting.key(ctx.entry.id))
        .transition(ms: 220)
        .animating(anims)
        if ctx.fresh { scene = cued(scene) }
        for (id, ms) in timers { scene = scene.timer(id, ms: ms) }
        for (name, values) in styles { scene = scene.style(name, values) }
        for k in keys { scene = scene.key(k.key, id: k.id, area: k.area, value: k.value, seat: k.seat, timedFromMs: k.timedFromMs, always: k.always) }
        if let after = partAfterMs ?? board.afterMs ?? ctx.afterMs { scene = scene.after(ms: after) }
        if let still = partAfterStillMs { scene = scene.afterStill(ms: still) }
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
        // A puzzle's last beat is on its board, and has its own sound (solveMoment).
        if ctx.buildUp, board.hasPuzzle { return out }
        if ctx.buildUp { return out.react(Reaction(effect: "question")).animating(.sequence([.sound("sounds/tick.wav")])) }
        // A game just come to the table starts with nothing of the last one's above the companion, however it got here.
        let opening = ctx.fresh && ctx.previous == nil
        guard let cue = board.companion else { return opening ? out.react(Reaction(prop: "none")) : out }
        let look: String? = (cue.look as? String) ?? (cue.look == nil ? nil : "panel")
        out = out.react(Reaction(move: cue.move, effect: cue.effect, prop: cue.prop ?? (opening ? "none" : nil), look: look))
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

    /// The buttons a game offers during play, at their place under the board. On an end card they are the card's.
    private func dock() -> PartBlock? {
        guard !ended, !partHoldsRoom else { return nil }
        let row = board.parts.compactMap { part -> GameButton? in if case .button(let b) = part, !b.companion { b } else { nil } }
        guard !row.isEmpty || dockExtra != nil else { return nil }
        return buttonRow(row, id: "dock", leading: dockExtra)
    }

    /// What is played, in the board's order.
    private func playBlocks() -> [PartBlock] {
        var out: [PartBlock] = []
        for part in board.parts {
            if ended, isPlay(part) { continue }
            if ended, case .choice(_, _, .segmented, _, _) = part { continue }
            if partHoldsRoom, !isPlay(part) { continue }
            switch part {
            case .score, .prompt, .button: continue
            default:
                if let block = block(part) { out.append(block) }
            }
        }
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
            // On the bubble when there is a prompt.
            startClock(id: id, seconds: seconds)
            guard board.promptPart == nil else { return nil }
            return PartBlock(timerBar(id: id, seconds: seconds, width: Self.inner), height: 5)
        case .play(let play): return playBlock(play)
        case .prompt, .score, .button: return nil
        }
    }

    private func playBlock(_ part: PlayPart) -> PartBlock {
        switch part {
        case .pads(let pads, let play, let stepMs, let locked, let length, let done):
            return onTable(padsPart(pads, play: play, stepMs: stepMs, locked: locked, length: length, done: done))
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

    /// A prop stands on the table its scene already paints.
    private func onTable(_ inner: PartBlock) -> PartBlock { inner }
}

/// The scene behind a game: its illustration filling the canvas, by day in light mode and the same place at night in dark mode. Never anything a game's data sent.
enum SceneBackdrop {
    static func nodes(_ look: Look, width: Double, height: Double) -> [Node] {
        [Node.rect(fill: Paint.paper).id("bg.base").size(width, height),
         Node.image(look.scene, dark: look.sceneAtNight, fit: "fill").id("bg.scene").size(width, height)]
    }
}
