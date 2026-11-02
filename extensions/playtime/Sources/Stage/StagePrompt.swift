import SidefolkExtensionKit

// The companion in the game's scene, saying the board's prompt in a speech bubble (GameStage): its bubble, the round's chip,
// its pose from the board's cue, a hop when the board changes, and the companion as a button.
extension BoardDrawing {
    /// Standing on a table that follows, rather than small at the side.
    private var peeking: Bool { board.resultPart == nil && (board.hasCups || board.hasPads || board.hasSticks || board.hasReflex) }
    private var side: Double { board.hasPuzzle || board.hasKeys || board.hasLetters || board.answersPart != nil ? 56 : 70 }

    /// The pose for the board's cue: a mood from the fixed list read as one of the states every companion is drawn in.
    var pose: String {
        if playing { return "thinking" }
        if board.over, let result = board.resultPart {
            switch Verdict(tone: result.tone) {
            case .loss: return "celebrating"
            case .win: return "waiting"
            case .draw: return "idle"
            }
        }
        switch board.companion?.move {
        case "think", "shuffle": return "thinking"
        case "cheer", "celebrate", "giggle", "dance", "hop", "spin", "tease", "accent:hop", "accent:spin": return "celebrating"
        case "gasp", "wince", "sweat", "dizzy": return "alert"
        case "nod", "bow", "wave", "accent:wave", "accent:bow": return "success"
        case "ready": return "listening"
        case "sulk", "shrug": return "waiting"
        default: return "idle"
        }
    }

    func stage(text: String?, eyebrow: String?, chip: String?) -> PartBlock {
        let inner = Self.inner
        var y = 0.0
        var nodes: [Node] = []
        if let eyebrow, !ended {
            let row = eyebrowRow(eyebrow)
            nodes.append(row.node)
            y += row.height + 6
        }
        let figureSize = peeking ? (w: 104.0, h: 100.0) : (w: side, h: side)
        let words = stageWords(prompt: text)
        let bubbleWidth = inner - figureSize.w - 6
        let bubbled = words.map { speechBubble($0, chip: chip, width: bubbleWidth) }
        // Over a table the feet sink a little past the stage's edge, onto the table's top.
        let sink = peeking ? 12.0 : 0
        let height = max(figureSize.h - sink, bubbled?.height ?? 0)
        let figureY = peeking ? y : y + height - figureSize.h
        let figure = companionFigure(w: figureSize.w, h: figureSize.h, y: figureY)
        nodes.append(figure)
        if let bubbled {
            nodes.append(bubbled.node.at(figureSize.w + 6, peeking ? y : y + height - bubbled.height))
        }
        return PartBlock(Node.box("stage", w: inner, h: y + height) { nodes }.z(1), height: y + height)
    }

    /// While Sidefolk's old panel played its own part the bubble said so; now the part that plays says it (`stageWordsWhile…`).
    private func stageWords(prompt: String?) -> String? { partsStageWords ?? prompt ?? board.resultPart?.line }

    /// The companion, whole, standing on the bottom edge of its box, with a soft shadow under it. Still art only, never a live
    /// render: a new board makes it hop once, 300 ms, with cheap transforms; nothing loops, so an idle game draws nothing.
    private func companionFigure(w: Double, h: Double, y: Double) -> Node {
        let shadowH = max(8, h * 0.1)
        let figure = Node.companion(pose: pose).figure(bottom: true).id("companion.figure").size(w, h).anchor(0.5, 1)
        var group = Node.box("companion", y: y, w: w, h: h) {
            Node.ellipse(fill: Paint.clear("#000000", 0.16)).id("companion.shadow").at(w * 0.05, h - shadowH / 2 + max(4, h * 0.05) - shadowH / 2).size(w * 0.9, shadowH)
                .shadow(Paint.clear("#000000", 0.14), radius: 3, dx: 0, dy: 0)
            figure
            if let button = board.companionButton {
                // A small badge with the button's symbol on its shoulder says it can be clicked.
                Node.ellipse(fill: .surface, stroke: Color.accent.tuned(alpha: 0.5), lineWidth: 1).id("companion.badge").at(w - 24, 0).size(24, 24)
                    .shadow(Paint.black15, radius: 2, dx: 0, dy: 1)
                Node.symbol(button.symbol ?? "hand.tap.fill", color: .accent).symbolLook(weight: "bold").at(w - 19, 5).size(14, 14)
            }
        }
        if ctx.fresh {
            anims.append(.keys("companion.figure", [["t": 0, "y": 0, "sx": 1, "sy": 1], ["t": 0.47, "y": -6, "sx": 0.97, "sy": 1.04], ["t": 1, "y": 0, "sx": 1, "sy": 1]], ms: 300, ease: "in_out"))
        }
        if let button = board.companionButton {
            group = group.area("button", value: button.move, label: button.label, hover: AreaLook(scale: 1.02), press: AreaLook(scale: 0.95), always: true, sound: "sounds/tap.wav")
            if let key = button.key { keys.append(StageKey(key: key, id: "companion_key", area: "button", value: button.move, always: true)) }
        }
        return group
    }

    /// "Round 2 of 5 · Fair": its first part bold, the level on a chip in the game's colour (never red), centred; a puzzle's clock
    /// and Sudoku's notes switch share the row.
    private func eyebrowRow(_ eyebrow: String) -> PartBlock {
        let chipped = roundChip(eyebrow)
        if let extras = puzzleEyebrowExtras {
            return extras(chipped)
        }
        let x = max((Self.inner - chipped.width) / 2, 0)
        return PartBlock(chipped.node.at(x, 0), height: chipped.height)
    }

    /// The pill alone, sized to its words.
    func roundChip(_ text: String, room: Double = BoardDrawing.inner) -> (node: Node, width: Double, height: Double) {
        let parts = text.components(separatedBy: " · ")
        let first = parts[0], rest = parts.dropFirst().joined(separator: " · ")
        let firstW = TextFit.width(first, size: 13, weight: "heavy")
        let restW = parts.count > 1 ? TextFit.width(rest, size: 12, weight: "heavy") : 0
        let chipW = parts.count > 1 ? restW + 16 : 0
        let width = min(12 + firstW + (parts.count > 1 ? 6 + chipW + 4 : 12), room)
        let height = parts.count > 1 ? 27.0 : 25.0
        let firstRoom = width - 12 - (parts.count > 1 ? 6 + chipW + 4 : 12)
        let node = Node.box("round", w: width, h: height) {
            Node.capsule(fill: Paint.card(0.96), stroke: Paint.edge, lineWidth: 1).id("round.pill").size(width, height).shadow(Paint.black8, radius: 3, dx: 0, dy: 1)
            Node.words(first, size: 13, weight: "heavy", minScale: 0.75, x: 12, w: max(firstRoom, 1), h: height)
            if parts.count > 1 {
                Node.capsule(fill: look.levelChip).id("round.chip").at(width - 4 - chipW, 4).size(chipW, 19)
                Node.words(rest, size: 12, weight: "heavy", color: look.onColor, align: "center", minScale: 0.75, x: width - 4 - chipW, y: 4, w: chipW, h: 19)
            }
        }
        return (node, width, height)
    }

    /// A rounded bubble with a tail toward whoever speaks: the prompt, a topic chip, the time left.
    func speechBubble(_ text: String, chip: String?, width: Double) -> PartBlock {
        let room = width - 28
        var y = 10.0
        var inside: [Node] = []
        if let chip {
            let w = min(TextFit.width(chip, size: 11, weight: "heavy") + 16, room)
            inside.append(Node.capsule(fill: .accentSoft).id("bubble.chip").at(14, y).size(w, 18))
            inside.append(Node.words(chip, size: 11, weight: "heavy", align: "center", x: 14, y: y, w: w, h: 18))
            y += 18 + 6
        }
        let textHeight = TextFit.height(text, size: 17, weight: "heavy", width: room, lines: 5) + 2
        inside.append(Node.words(text, size: 17, weight: "heavy", valign: "top", lines: 5, minScale: 0.8, x: 14, y: y, w: room, h: textHeight).id("bubble.text"))
        y += textHeight
        if let clock = board.timerPart {
            y += 6
            startClock(id: clock.id, seconds: clock.seconds)
            inside.append(timerBar(id: clock.id, seconds: clock.seconds, width: room).at(14, y))
            y += 5
        }
        let height = y + 10
        let shape = ShapePath.rounded(x: 0, y: 0, w: width, h: height, r: 18)
            + "M 1 \(height - 26) Q -4 \(height - 16) -10 \(height - 10) Q -3 \(height - 10) 1 \(height - 12) Z"
        return PartBlock(.box("bubble", w: width, h: height) {
            Node.path(shape, fill: Paint.card, stroke: Paint.edge, lineWidth: 1).id("bubble.shape").size(width, height).shadow(Paint.clear("#000000", 0.1), radius: 6, dx: 0, dy: 3)
            inside
        }, height: height)
    }
}
