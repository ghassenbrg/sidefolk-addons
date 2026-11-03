import SidefolkExtensionKit

/// The companion's place in a game's scene, as that game's concept draws it: feet on the arch, at the table, on the mat. All of it fixed, in canvas points, for the whole game. A figure is a
/// still of any shape with its feet at the bottom of its box, so a wide one stands as firmly as a tall one, only smaller in its box.
struct FigurePlace {
    /// The box the figure stands in: its left edge, where its feet land, its size.
    var x: Double, feet: Double, w: Double, h: Double
    /// The bubble, one size for the whole game.
    var bubble: (x: Double, y: Double, w: Double, h: Double)
    var tail: BubbleTail = .left
    var lines = 3
    /// Where the board starts, when the scene needs more or less room than the usual stage leaves.
    var boardTop: Double?
    /// At a table: what's on it stands in front.
    var behindBoard = false
    /// A soft shadow on what it stands on; none where its feet are out of sight.
    var contact = true
    /// A part of the scene in canvas points, in front of its feet: the pocket it peeks from.
    var front: Node?
}

extension BoardDrawing {
    var figurePlace: FigurePlace? {
        guard !ended, !isStall, !board.hasCover else { return nil }
        // A setting-up board (names, a cover) has no toy to stand by.
        if board.gridPart == nil, !board.hasCups, !board.hasPads, !board.hasReflex, !board.hasSticks, !board.hasPuzzle, !board.hasLetters, gameTable == nil { return nil }
        switch ctx.entry.id {
        // 03: perched on the arch, the bubble beside its head.
        case TicTacToeScreen.id:
            return FigurePlace(x: 18, feet: 197, w: 96, h: 116, bubble: (116, 116, 270, 54))
        // 07: sits at the table, large, behind the cups, with the wall behind it.
        case WhichCupScreen.id:
            return FigurePlace(x: 12, feet: 346, w: 134, h: 180, bubble: (148, 172, 238, 56), behindBoard: true)
        // 05: stands on the mat beside the machine, its bubble above it.
        case QuickPawsScreen.id:
            return FigurePlace(x: 6, feet: 492, w: 122, h: 156, bubble: (8, 238, 128, 90), tail: .down(x: 62), lines: 4, boardTop: 102)
        // 04: stands on the floor before the felt wall, between metronome and drum.
        case CopyMeScreen.id:
            // The scene doesn't mirror, so in a right-to-left language the figure and bubble make room to stay clear of the drum.
            return Language.rightToLeft
                ? FigurePlace(x: 92, feet: 244, w: 106, h: 150, bubble: (192, 112, 194, 56), boardTop: 252)
                : FigurePlace(x: 62, feet: 244, w: 106, h: 150, bubble: (172, 112, 214, 56), boardTop: 252)
        // 06, 12: on the rim of the tray, the top of the mat.
        case LastStickScreen.id, MemoryPairsScreen.id:
            return FigurePlace(x: 12, feet: 190, w: 92, h: 112, bubble: (108, 116, 278, 56))
        // 08: on the plaque's frame, before the arch.
        case TriviaScreen.id where gameTable == .triviaQuestion:
            return FigurePlace(x: 10, feet: 208, w: 96, h: 120, bubble: (108, 118, 206, 56))
        // 09: on the desk behind the range's plate, the counter beside it.
        case HigherLowerScreen.id where gameTable == .numbersGuess:
            return FigurePlace(x: 12, feet: 204, w: 96, h: 132, bubble: (108, 104, 104, 72), behindBoard: true, contact: false)
        // 22: on the mat at the counter's foot, its question above it.
        case HigherLowerScreen.id where gameTable == .numbersAsked:
            return FigurePlace(x: 2, feet: 452, w: 118, h: 168, bubble: (10, 196, 120, 66), tail: .down(x: 62), lines: 2)
        // 10: peeks from a pocket in the animal notebook.
        case GuessAnimalScreen.id where gameTable == .animalAsks:
            return FigurePlace(x: 32, feet: 180, w: 106, h: 132, bubble: (138, 100, 242, 62), contact: false, front: notebookPocket)
        // 14: on the top edge of the tray.
        case DailyWordScreen.id:
            return FigurePlace(x: 8, feet: 138, w: 68, h: 88, bubble: (78, 72, 308, 52), contact: false)
        // 15, 16, 17, 18: on the frame's top edge.
        case GardenPlotsKind.id, SudokuKind.id, BlossomsKind.id:
            return FigurePlace(x: 8, feet: 140, w: 68, h: 90, bubble: (78, 72, 308, 54), contact: false)
        case SeesawKind.id:
            return FigurePlace(x: 8, feet: 158, w: 68, h: 90, bubble: (78, 72, 308, 54), contact: false)
        default:
            return nil
        }
    }

    /// A torn strip of the same page as the question, tucked over the companion's feet: it peeks out of the notebook, whatever shape its feet are.
    private var notebookPocket: Node {
        Node.box("animal.pocket", w: Self.width, h: Self.canvas) {
            tornPaper("animal.pocket.paper", w: 118, h: 30).at(26, 160)
        }
    }
}
