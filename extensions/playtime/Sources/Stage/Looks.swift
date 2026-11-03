import SidefolkExtensionKit

/// How a game is dressed (D79 amended): its colour for its icon tile and the menu card, the chip that names a level, the
/// scene behind the board by day and by night, and its icon. All of it lives here and in the pack, so a new look ships with
/// Playtime alone.
struct Look {
    var name: String
    var top: Color
    var bottom: Color
    var onColor: Color = Paint.white
    /// The level chip ("Fair"): the game's colour, or a neighbour of it where that colour is red or pink (D78).
    var chip: Color?
    /// The scene is dark in both appearances (the arcade): no night version.
    var night = false
    /// The scene's picture when another look's room is borrowed.
    var room: String?
    /// The soft tile its icon stands on in the menu and on the page.
    var tile: Color {
        // By day each has its soft colour; at night they all stand on the same slate, and the art carries the colour.
        let day = switch name {
        case "grid", "arcade", "words", "sudoku": "#F8DE94"
        case "cups", "numbers", "seesaw", "hands": "#FBD9B8"
        case "animals", "balloons", "blossoms": "#BFDCF2"
        case "sticks": "#F6CFCB"
        default: "#E6DAF1"
        }
        return Paint.both(day, "#2C3556")
    }

    var levelChip: Color { chip ?? bottom }
    var scene: String { "art/game-bg-\(room ?? name).heic" }
    var sceneAtNight: String? { night ? nil : "art/game-bg-\(room ?? name)-night.heic" }
    var icon: String { "art/game-icon-\(name).webp" }

    static let plain = dance

    static let quiz = Look(name: "quiz", top: .hex("#6B7BFF"), bottom: .hex("#4A55D9"))
    static let grid = Look(name: "grid", top: .hex("#22C2B0"), bottom: .hex("#0E9384"))
    static let dance = Look(name: "dance", top: .hex("#3FCB74"), bottom: .hex("#1F9E52"))
    static let arcade = Look(name: "arcade", top: .hex("#3A2380"), bottom: .hex("#1D1450"), chip: .hex("#3E6FE8"))
    static let cups = Look(name: "cups", top: .hex("#F4626A"), bottom: .hex("#D6404B"), chip: .hex("#3E6FE8"))
    static let numbers = Look(name: "numbers", top: .hex("#FF9447"), bottom: .hex("#E8691C"), chip: .hex("#2C8BD6"))
    static let animals = Look(name: "animals", top: .hex("#7DBD45"), bottom: .hex("#4F9128"))
    static let balloons = Look(name: "balloons", top: .hex("#45B4F5"), bottom: .hex("#1D8AD8"))
    static let sticks = Look(name: "sticks", top: .hex("#9B6BFA"), bottom: .hex("#7342E0"))
    static let cards = Look(name: "cards", top: .hex("#F0619D"), bottom: .hex("#CC3A7A"), chip: .hex("#7A55D6"))
    static let words = Look(name: "words", top: .hex("#FFD25C"), bottom: .hex("#F2B21B"), onColor: .hex("#3B2A05"))
    static let plots = Look(name: "plots", top: .hex("#B98455"), bottom: .hex("#92603A"))
    static let seesaw = Look(name: "seesaw", top: .hex("#B06AB3"), bottom: .hex("#8A4590"))
    static let sudoku = Look(name: "sudoku", top: .hex("#6F8BAB"), bottom: .hex("#4A6585"))
    static let blossoms = Look(name: "blossoms", top: .hex("#FF9580"), bottom: .hex("#EC6A55"), chip: .hex("#3E9A5A"))
    static let hands = Look(name: "hands", top: .hex("#FFAE48"), bottom: .hex("#EE8A1E"), room: "cups")
}

/// Every game Playtime offers, in the menu's order: what the manifest's `games` used to say, now the program's own. A game
/// is added here (GameCatalog.Entry), to `GameTable.drivers`, and to the commands in the manifest and `strings/`.
struct GameEntry {
    var id: String
    var title: String
    var tagline: String
    var symbol: String
    var look: Look
    /// Played alone, a puzzle (the menu's "Puzzles"), rather than against the companion.
    var solo = false
    var levels = true
}

enum GameCatalog {
    nonisolated(unsafe) private static var made: [String: [GameEntry]] = [:]

    /// The menu's order: games against the companion by their looks' order, then the puzzles. Made once per language: a board asks often.
    static var all: [GameEntry] {
        if let known = made[Language.code] { return known }
        let list = catalog
        made[Language.code] = list
        return list
    }

    private static var catalog: [GameEntry] {
        [GameEntry(id: WhichCupScreen.id, title: L("Which Cup?"), tagline: L("Keep your eye on the gem"), symbol: "cup.and.saucer.fill", look: .cups),
         GameEntry(id: CopyMeScreen.id, title: L("Copy Me"), tagline: L("Watch the moves, then copy them"), symbol: "figure.dance", look: .dance),
         GameEntry(id: QuickPawsScreen.id, title: L("Quick Paws"), tagline: L("Boop the moment it says Boop!"), symbol: "bolt.fill", look: .arcade),
         GameEntry(id: LastStickScreen.id, title: L("Last Stick"), tagline: L("Don’t take the last stick!"), symbol: "line.3.horizontal", look: .sticks),
         GameEntry(id: TriviaScreen.id, title: L("Trivia"), tagline: L("Questions on every topic"), symbol: "questionmark.bubble.fill", look: .quiz),
         GameEntry(id: TicTacToeScreen.id, title: L("Tic-tac-toe"), tagline: L("Three in a row wins"), symbol: "number", look: .grid),
         GameEntry(id: HigherLowerScreen.id, title: L("Higher or Lower"), tagline: L("Hot or cold? Find the number"), symbol: "arrow.up.arrow.down", look: .numbers, levels: false),
         GameEntry(id: GuessAnimalScreen.id, title: L("Guess My Animal"), tagline: L("Yes or no, until one guesses"), symbol: "pawprint.fill", look: .animals, levels: false),
         GameEntry(id: BalloonWordsScreen.id, title: L("Balloon Words"), tagline: L("Find the word before the balloons go"), symbol: "balloon.2.fill", look: .balloons),
         GameEntry(id: MemoryPairsScreen.id, title: L("Memory Pairs"), tagline: L("Turn two cards, find the pairs"), symbol: "square.grid.2x2.fill", look: .cards),
         GameEntry(id: RockPaperScissorsScreen.id, title: L("Rock, Paper, Scissors"), tagline: L("Best of three, no peeking"), symbol: "hand.raised.fill", look: .hands, levels: false),
         GameEntry(id: DailyWordScreen.id, title: L("Daily Word"), tagline: L("One new word to find every day"), symbol: "textformat.abc", look: .words, solo: true, levels: false),
         GameEntry(id: GardenPlotsKind.id, title: L("Garden Plots"), tagline: L("Split the garden into plots by their numbers"), symbol: "square.split.2x2.fill", look: .plots, solo: true),
         GameEntry(id: SeesawKind.id, title: L("Seesaw"), tagline: L("Balance crescents and suns in every line"), symbol: "moon.fill", look: .seesaw, solo: true),
         GameEntry(id: SudokuKind.id, title: L("Sudoku"), tagline: L("Each number once in every row, column and box"), symbol: "square.grid.3x3.fill", look: .sudoku, solo: true),
         GameEntry(id: BlossomsKind.id, title: L("Blossoms"), tagline: L("One flower in every row, column and bed"), symbol: "camera.macro", look: .blossoms, solo: true)]
    }

    static func entry(_ id: String) -> GameEntry? { all.first { $0.id == id } }
}
