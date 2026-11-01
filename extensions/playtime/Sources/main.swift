import SidefolkExtensionKit

// Playtime, an extension that ships with Sidefolk: games in Sidefolk's Play panel (D75, D79): ten played against the
// companion (trivia, tic-tac-toe, Copy Me, Quick Paws, Which Cup?, Higher or Lower, Guess My Animal, Balloon Words, Last
// Stick and Memory Pairs) and five puzzles played alone (Daily Word, Garden Plots, Seesaw, Sudoku and Blossoms); and
// random picks for a break. Coins, dice and rock, paper, scissors are the
// companion's own (`companion.toss`). No permissions; scores stay in its own folder. Its words come in Sidefolk's ten
// languages (strings/, the Kit's L), chosen by the `language` Sidefolk passes.
let ext = Extension(name: "playtime", version: "1.0.0")

ext.tool("pick", "Random picks",
         "Truly random: pick a number in a range, or pick from a list of choices (one, or several in order). Use it whenever "
         + "the user wants chance to choose. Coins and dice are companion.toss.",
         input: Schema.object([
             "kind": Schema.string("What to pick.", oneOf: ["number", "choice"]),
             "min": Schema.integer("For number: the lowest (1 if not given)."),
             "max": Schema.integer("For number: the highest (100 if not given)."),
             "choices": Schema.array(of: Schema.string("One choice.", maxLength: 100), "For choice: the choices.", maxItems: 50),
             "count": Schema.integer("For choice: how many to pick (1 if not given).", minimum: 1, maximum: 20),
         ], required: ["kind"])) { args in
    switch args.string("kind") {
    case "number": return try Chance.number(args.int("min") ?? 1, args.int("max") ?? 100)
    default: return try Chance.pick(args.strings("choices"), count: args.int("count") ?? 1)
    }
}

ext.tool("trivia", "Trivia quiz",
         "A trivia quiz with a score that is kept between games. Call it without an answer for a question; call it with the "
         + "user's answer (A, B, C or D) to check it and get the next question. Show the question and choices as given.",
         input: Schema.object([
             "answer": Schema.string("The user's answer to the last question: A, B, C or D.", maxLength: 60),
             "category": Schema.string("For a new question: \(Trivia.categories.joined(separator: ", ")), or any.", maxLength: 20),
         ])) { args in
    try Trivia.play(answer: args.string("answer"), category: args.string("category"))
}

// Trivia packs made by the person's AI come through Sidefolk (D95): the request goes out, the pack comes back as data.
TriviaAI.send = { method, params in ext.send(method, params) }
ext.on("sidefolk/trivia.pack") { args in TriviaAI.receive(args) }

GameTable.register(TriviaScreen.self, on: ext)
GameTable.register(TicTacToeScreen.self, on: ext)
GameTable.register(CopyMeScreen.self, on: ext)
GameTable.register(QuickPawsScreen.self, on: ext)
GameTable.register(WhichCupScreen.self, on: ext)
GameTable.register(HigherLowerScreen.self, on: ext)
GameTable.register(GuessAnimalScreen.self, on: ext)
GameTable.register(BalloonWordsScreen.self, on: ext)
GameTable.register(LastStickScreen.self, on: ext)
GameTable.register(MemoryPairsScreen.self, on: ext)
GameTable.register(DailyWordScreen.self, on: ext)
GameTable.register(PuzzleScreen<GardenPlotsKind>.self, on: ext)
GameTable.register(PuzzleScreen<SeesawKind>.self, on: ext)
GameTable.register(PuzzleScreen<SudokuKind>.self, on: ext)
GameTable.register(PuzzleScreen<BlossomsKind>.self, on: ext)

ext.page("playtime") { _ in PlaytimePage.render() }

await ext.serve()
