import SidefolkExtensionKit

// The companion in the game's scene, saying the board's prompt in a speech bubble (GameStage): its bubble, the round's chip,
// its pose from the board's cue, a hop when the board changes, and the companion as a button.
extension BoardDrawing {
    /// A dense board keeps a smaller companion, for every board of that game alike.
    private var compact: Bool { board.hasPuzzle || board.hasKeys || board.hasLetters }
    /// The stage's one height, whatever is said: one line or three, the board below stays where it is.
    private var stageHeight: Double { stageTall ?? (isStall ? 44 : compact ? 60 : 78) }

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
        // A moment that came with a reaction wins over whose turn it is.
        switch board.companion?.move {
        case "think", "shuffle": return "thinking"
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

    /// The pose the last board had, to see whether this one is a change worth a little hop.
    private var posed: String? { ctx.previous.map { BoardDrawing($0, StageContext(entry: ctx.entry, fresh: false, local: ctx.local)).pose } }

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

    /// The companion, whole, standing on the bottom edge of its box, with a soft shadow under it. Still art only, never a live
    /// render: a new board makes it hop once, 300 ms, with cheap transforms; nothing loops, so an idle game draws nothing.
    private func companionFigure(w: Double, h: Double, y: Double) -> Node {
        // Under the figure rather than its box: a figure is drawn at about three quarters as wide as it is tall.
        let shadowH = max(8, h * 0.1), shadowW = min(w, h) * 0.68
        let figure = Node.companion(pose: pose).figure(bottom: true).id("companion.figure").size(w, h).anchor(0.5, 1)
        var group = Node.box("companion", y: y, w: w, h: h) {
            Node.image("art/game-figure-shadow.webp", fit: "fill").id("companion.shadow").at((w - shadowW) / 2, h - shadowH + max(4, h * 0.05)).size(shadowW, shadowH)
            figure
            if let button = board.companionButton {
                // A small badge with the button's symbol on its shoulder says it can be clicked.
                Node.ellipse(fill: .surface, stroke: Color.accent.tuned(alpha: 0.5), lineWidth: 1).id("companion.badge").at(w - 24, 0).size(24, 24)
                    .shadow(Paint.black15, radius: 2, dx: 0, dy: 1)
                Node.symbol(button.symbol ?? "hand.tap.fill", color: .accent).symbolLook(weight: "bold").at(w - 19, 5).size(14, 14)
            }
        }
        // A little hop when it reacts or its pose changes; a board redrawn for a key, or nothing new, leaves it still.
        if ctx.fresh, board.companion != nil || (posed != nil && posed != pose) {
            anims.append(.keys("companion.figure", [["t": 0, "y": 0, "sx": 1, "sy": 1], ["t": 0.47, "y": -6, "sx": 0.97, "sy": 1.04], ["t": 1, "y": 0, "sx": 1, "sy": 1]], ms: 300, ease: "in_out"))
        }
        if let button = board.companionButton {
            group = group.area("button", value: button.move, label: button.label, hover: AreaLook(scale: 1.02), press: AreaLook(scale: 0.95), always: true, sound: "sounds/tap.wav")
            if let key = button.key { keys.append(StageKey(key: key, id: "companion_key", area: "button", value: button.move, always: true)) }
        }
        return group
    }

    /// A bubble of one size with a tail toward whoever speaks. Its words shrink to fit rather than its edge growing, and only they change, with a short fade.
    func speechBubble(_ text: String, width: Double, height: Double) -> PartBlock {
        let clock = board.timerPart
        let room = width - 28, wordsH = height - 10 - (clock == nil ? 0 : 7)
        if ctx.fresh, let before = ctx.previous?.said ?? ctx.previous?.promptPart?.text, before != text {
            anims.append(.keys("bubble.text", [["t": 0, "opacity": 0], ["t": 1, "opacity": 1]], ms: 180, ease: "out"))
        }
        let shape = ShapePath.rounded(x: 0, y: 0, w: width, h: height, r: 18)
            + "M 1 \(height - 26) Q -4 \(height - 16) -10 \(height - 10) Q -3 \(height - 10) 1 \(height - 12) Z"
        return PartBlock(.box("bubble", w: width, h: height) {
            Node.path(shape, fill: Paint.card, stroke: Paint.edge, lineWidth: 1).id("bubble.shape").size(width, height).shadow(Paint.clear("#000000", 0.1), radius: 6, dx: 0, dy: 3)
            Node.words(text, size: 15, weight: "heavy", valign: "center", lines: 3, minScale: 0.68, x: 14, y: 5, w: room, h: wordsH).id("bubble.text")
            if let clock {
                let _ = startClock(id: clock.id, seconds: clock.seconds)
                timerBar(id: clock.id, seconds: clock.seconds, width: room).at(14, height - 10)
            }
        }, height: height)
    }
}
