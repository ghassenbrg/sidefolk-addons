import SidefolkExtensionKit

// The companion in the game's scene, saying the board's prompt in a speech bubble (GameStage): its bubble, the round's chip,
// its pose from the board's cue, a hop when the board changes, and the companion as a button.
extension BoardDrawing {
    /// A dense board keeps a smaller companion, for every board of that game alike.
    private var compact: Bool { board.hasPuzzle || board.hasKeys || board.hasLetters }
    /// The stage's one height, whatever is said: one line or three, the board below stays where it is.
    private var stageHeight: Double {
        if let top = figurePlace?.boardTop { return Swift.max(top - stageTop - 6, 0) }
        return stageTall ?? (isStall ? 44 : compact ? 60 : 78)
    }

    /// The founder's rule: the companion earns its place by reacting. It thinks while it plays or while something is playing, leans in when it's the person's turn, reacts to
    /// what just happened, and shows how the game went. It changes only with the game: no idle movement, and it is always a still of the person's real companion.
    var pose: String {
        if playing { return "thinking" }
        if board.over, let result = board.resultPart {
            switch Verdict(tone: result.tone) {
            case .loss: return "celebrating"
            case .win: return "success"
            case .draw: return "idle"
            }
        }
        // What it played is over and the person's turn has come: the cue of the shuffle or the dance doesn't carry over.
        if board.plays != nil { return "listening" }
        // A moment that came with a reaction wins over whose turn it is.
        switch board.companion?.move {
        case "think": return "thinking"
        case "cheer", "celebrate", "giggle", "dance", "hop", "spin", "tease", "accent:hop", "accent:spin": return "celebrating"
        case "gasp", "wince", "sweat", "dizzy": return "alert"
        case "nod", "bow", "wave", "accent:wave", "accent:bow": return "success"
        case "sulk", "shrug": return "waiting"
        case "ready": return "listening"
        default: break
        }
        // A build-up is held breath; a board that answers by itself is the companion's own turn; otherwise it watches the person.
        if ctx.buildUp { return "alert" }
        if board.afterMs != nil { return "thinking" }
        return "listening"
    }

    /// The pose the last board had, to see whether this one is a change worth a move. A verdict follows its build-up, which held its breath on the same board.
    private var posed: String? {
        if ctx.local.builtUp { return "alert" }
        return ctx.previous.map { BoardDrawing($0, StageContext(entry: ctx.entry, fresh: false, local: ctx.local)).pose }
    }

    func stage(text: String?, chip: String?) -> PartBlock {
        let inner = Self.inner, h = stageHeight, side = stageTall ?? (compact ? 58.0 : 80.0)
        let words = stageWords(prompt: text)
        if isStall {
            // In the stall the companion stands on the counter, with its bubble up beside it over the word's sign.
            let figureH = 100.0, bubbleX = 96.0
            return PartBlock(Node.box("stage", w: inner, h: h) {
                companionFigure(w: 92, h: figureH, y: Self.counterY - Self.stallStageY - figureH).at(2, Self.counterY - Self.stallStageY - figureH)
                if let words { speechBubble(words, width: inner - bubbleX - 8, height: h - 4).node.at(bubbleX, 0) }
            }, height: h)
        }
        if gameTable == .hands {
            // Above its own score: the score line has the companion on the right, so here it stands there too, its bubble to its left (approved for this game).
            let bubbleH = Swift.min(h - 8, 56), bubbleW = inner - side - 2
            return PartBlock(Node.box("stage", w: inner, h: h) {
                companionFigure(w: side, h: h + 22, y: -14).at(inner - side + 4, -14)
                if let words { speechBubble(words, width: bubbleW, height: bubbleH, tail: .right).node.at(0, 6) }
            }, height: h)
        }
        if let place = figurePlace {
            // In canvas points, so what the header holds doesn't move it. Its feet stand on something real in the scene.
            let top = stageTop, b = place.bubble
            return PartBlock(Node.box("stage", w: inner, h: h) {
                companionFigure(w: place.w, h: place.h, y: 0, contact: place.contact).at(place.x - Self.pad, place.feet - place.h - top)
                if let front = place.front { front.at(-Self.pad, -top) }
                if let words { speechBubble(words, width: b.w, height: b.h, tail: place.tail, lines: place.lines).node.at(b.x - Self.pad, b.y - top) }
            }, height: h)
        }
        let bubbleW = stageBubbleWidth ?? inner - side - 8
        return PartBlock(Node.box("stage", w: inner, h: h) {
            // Larger than its row, as the concepts draw it: its ears rise past the round's line and its feet stand on what it plays on.
            companionFigure(w: side, h: h + 22, y: -14)
            if let words { speechBubble(words, width: bubbleW, height: Swift.min(h - 8, 56)).node.at(side + 8, (h - Swift.min(h - 8, 56)) / 2) }
        }, height: h)
    }

    /// The top of the stall's counter, in its scene.
    private static let counterY = 342.0

    /// While a part plays by itself it says so; a part may carry the words elsewhere (a question on a plaque).
    private func stageWords(prompt: String?) -> String? { partsStageWords ?? stageWordsOverride ?? prompt ?? board.resultPart?.line }

    /// The companion, whole, standing on the bottom edge of its box, with a soft shadow where its feet touch. Still art only, never a live
    /// render: it moves by the vocabulary below, on a change, with cheap transforms; nothing loops, so an idle game draws nothing.
    private func companionFigure(w: Double, h: Double, y: Double, contact: Bool = true) -> Node {
        // Under the figure rather than its box: a figure is drawn at about three quarters as wide as it is tall.
        let shadowH = max(7, h * 0.07), shadowW = min(w, h) * 0.62
        let rest = FigureRest(pose: pose, toward: figureToward)
        let figure = Node.companion(pose: pose).figure(bottom: true).id("companion.figure").size(w, h).anchor(0.5, 1).rotate(rest.rotate).scale(x: rest.sx, y: rest.sy)
        var group = Node.box("companion", y: y, w: w, h: h) {
            if contact { Node.image("art/game-figure-shadow.webp", fit: "fill").id("companion.shadow").at((w - shadowW) / 2, h - shadowH * 0.55).size(shadowW, shadowH) }
            figure
            if let button = board.companionButton {
                // A small badge with the button's symbol on its shoulder says it can be clicked.
                Node.ellipse(fill: .surface, stroke: Color.accent.tuned(alpha: 0.5), lineWidth: 1).id("companion.badge").at(w - 24, 0).size(24, 24)
                    .shadow(Paint.black15, radius: 2, dx: 0, dy: 1)
                Node.symbol(button.symbol ?? "hand.tap.fill", color: .accent).symbolLook(weight: "bold").at(w - 19, 5).size(14, 14)
            }
        }
        // It moves when it reacts or its pose changes; a board redrawn for a key, or nothing new, leaves it still. A throw has its own dips and flinches (`companionThrough`) on `y`, so during one only its lean plays.
        if let move = stageFigureMove {
            let before = posed.map { FigureRest(pose: $0, toward: figureToward) } ?? rest
            anims.append(move.anim("companion.figure", from: before, to: rest, toward: figureToward, leanOnly: gameTable == .hands && ctx.buildUp))
        }
        if let button = board.companionButton {
            group = group.area("button", value: button.move, label: button.label, hover: AreaLook(scale: 1.02), press: AreaLook(scale: 0.95), always: true, sound: "sounds/tap.wav")
            if let key = button.key { keys.append(StageKey(key: key, id: "companion_key", area: "button", value: button.move, always: true)) }
        }
        return group
    }

    /// A bubble of one size with a tail toward whoever speaks. Its words shrink to fit rather than its edge growing, and only they change, with a short fade.
    func speechBubble(_ text: String, width: Double, height: Double, tail side: BubbleTail = .left, lines: Int = 3) -> PartBlock {
        let clock = board.timerPart
        let room = width - 28, wordsH = height - 10 - (clock == nil ? 0 : 7)
        if ctx.fresh, let before = ctx.previous?.said ?? ctx.previous?.promptPart?.text, before != text {
            anims.append(.keys("bubble.text", [["t": 0, "opacity": 0], ["t": 1, "opacity": 1]], ms: 180, ease: "out"))
        }
        let tail = switch side {
        case .left: "M 1 \(height - 26) Q -4 \(height - 16) -10 \(height - 10) Q -3 \(height - 10) 1 \(height - 12) Z"
        case .right: "M \(width - 1) \(height - 26) Q \(width + 4) \(height - 16) \(width + 10) \(height - 10) Q \(width + 3) \(height - 10) \(width - 1) \(height - 12) Z"
        case .down(let x): "M \(x - 13) \(height - 1) Q \(x - 6) \(height + 4) \(x - 4) \(height + 11) Q \(x + 3) \(height + 6) \(x + 9) \(height - 1) Z"
        }
        let shape = ShapePath.rounded(x: 0, y: 0, w: width, h: height, r: 18) + tail
        return PartBlock(.box("bubble", w: width, h: height) {
            Node.path(shape, fill: Paint.card, stroke: Paint.edge, lineWidth: 1).id("bubble.shape").size(width, height).shadow(Paint.clear("#000000", 0.1), radius: 6, dx: 0, dy: 3)
            Node.words(text, size: 15, weight: "heavy", valign: "center", lines: lines, minScale: 0.68, x: 14, y: 5, w: room, h: wordsH).id("bubble.text")
            if let clock {
                let _ = startClock(id: clock.id, seconds: clock.seconds)
                timerBar(id: clock.id, seconds: clock.seconds, width: room).at(14, height - 10)
            }
        }, height: height)
    }
}

// MARK: How the figure moves

/// Which way a bubble's tail points: at whoever speaks.
enum BubbleTail {
    case left, right
    case down(x: Double)
}

/// How the figure stands at rest for a pose: the same still, leaning. Its own transform, so a board redrawn for a key leaves it where it is, and every companion gets it, 3D or 2D.
struct FigureRest: Equatable {
    var rotate = 0.0, sx = 1.0, sy = 1.0

    init(pose: String, toward: Double) {
        switch pose {
        // Its head tipped back, about its feet: held while it thinks.
        case "thinking": rotate = -5 * toward
        // A little toward the board: it's the person's turn, and it watches.
        case "listening": rotate = 3 * toward
        // Shoulders down.
        case "waiting": (rotate, sx, sy) = (-3 * toward, 1.02, 0.97)
        default: break
        }
    }
}

/// The one small vocabulary of what a companion does, every game alike: a still that leans, hops and flinches. One-shots, each short and readable, each ending where the node rests.
/// Each is one animation with one track per value (Sidefolk cuts a second one on the same value of a node, and takes 32 points a track).
enum FigureMove {
    case lean, cheer, jumpBack, slump, nod

    /// What the board's cue says, nil when it says nothing a figure shows.
    init?(cue: String?) {
        switch cue {
        case "cheer", "celebrate", "giggle", "dance", "hop", "spin", "tease", "accent:hop", "accent:spin": self = .cheer
        case "gasp", "wince", "sweat", "dizzy": self = .jumpBack
        case "sulk", "shrug": self = .slump
        case "nod", "bow", "wave", "accent:wave", "accent:bow": self = .nod
        default: return nil
        }
    }

    /// `x` and `y` are where the node rests in its parent; `toward` is +1 when the board is on its right.
    func anim(_ id: String, x: Double = 0, y: Double = 0, from a: FigureRest, to b: FigureRest, toward: Double, leanOnly: Bool = false) -> Anim {
        func frame(_ t: Double, dx: Double = 0, dy: Double = 0, rotate: Double, sx: Double = 1, sy: Double = 1) -> [String: Double] {
            leanOnly ? ["t": t, "rotate": rotate] : ["t": t, "x": x + dx, "y": y + dy, "rotate": rotate, "sx": sx, "sy": sy]
        }
        let start = frame(0, rotate: a.rotate, sx: a.sx, sy: a.sy), end = frame(1, rotate: b.rotate, sx: b.sx, sy: b.sy)
        switch self {
        case .lean:
            // Past where it is going, and back: a lean with some weight in it.
            let past = b.rotate + (b.rotate - a.rotate) * 0.25
            return .keys(id, [start, frame(0.6, rotate: past, sx: b.sx, sy: b.sy), end], ms: 340, ease: "in_out")
        case .cheer:
            // A crouch, two hops, each landing soft: squash and stretch.
            let r = b.rotate
            return .keys(id, [start, frame(0.1, rotate: r, sx: 1.07, sy: 0.9), frame(0.28, dy: -16, rotate: r, sx: 0.95, sy: 1.08), frame(0.46, rotate: r, sx: 1.08, sy: 0.9),
                              frame(0.64, dy: -10, rotate: r, sx: 0.97, sy: 1.05), frame(0.82, rotate: r, sx: 1.05, sy: 0.94), end], ms: 680, ease: "in_out")
        case .jumpBack:
            // Up and away from what startled it, tipped back, a moment there, then home.
            return .keys(id, [start, frame(0.2, dx: -7 * toward, dy: -11, rotate: -8 * toward, sx: 0.97, sy: 1.05), frame(0.42, dx: -9 * toward, rotate: -6 * toward, sx: 1.05, sy: 0.94),
                              frame(0.7, dx: -9 * toward, rotate: -6 * toward), end], ms: 560, ease: "in_out")
        case .slump:
            // A breath in, and everything goes down.
            let down = -6 * toward
            return .keys(id, [start, frame(0.25, rotate: a.rotate, sx: 0.98, sy: 1.03), frame(0.65, rotate: down, sx: 1.05, sy: 0.92), end], ms: 620, ease: "in_out")
        case .nod:
            // Forward and back about its feet, twice, the second smaller.
            let r = b.rotate
            return .keys(id, [start, frame(0.3, rotate: r + 8 * toward, sx: 1.01, sy: 0.97), frame(0.55, rotate: r), frame(0.75, rotate: r + 5 * toward, sy: 0.98), end], ms: 460, ease: "in_out")
        }
    }
}

extension BoardDrawing {
    /// Which side the board is on: the companion stands left of it, and in Rock, Paper, Scissors right of it. Right to left, Sidefolk mirrors the turn with the place.
    var figureToward: Double { gameTable == .hands ? -1 : 1 }

    /// What the figure does on the stage as this scene comes, if anything: only a new board, never the first (a game come back to doesn't replay what it last did).
    private var stageFigureMove: FigureMove? {
        guard ctx.fresh, ctx.previous != nil else { return nil }
        if !(gameTable == .hands && ctx.buildUp), !playing, let move = FigureMove(cue: board.companion?.move) { return move }
        return posed != pose ? .lean : nil
    }

    /// The figure's big moment on an end card: how the game went, once, as the card comes.
    func endFigure(_ id: String, x: Double, y: Double, verdict: Verdict, friendly: Bool) {
        guard ctx.fresh, ctx.previous?.resultPart == nil else { return }
        let move: FigureMove = friendly || verdict == .draw ? .nod : .cheer
        anims.append(move.anim(id, x: x, y: y, from: FigureRest(pose: "idle", toward: 1), to: FigureRest(pose: "idle", toward: 1), toward: 1).delay(ms: 220))
    }
}
