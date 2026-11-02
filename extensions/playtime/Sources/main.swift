import SidefolkExtensionKit

// Playtime: games beside the companion, all of it in this pack (Sidefolk D101): every game's screens, words, art and sounds, a menu,
// and the Game Center as its page. Ten played against the companion (trivia, tic-tac-toe, Copy Me, Quick Paws, Which Cup?, Higher or Lower,
// Guess My Animal, Balloon Words, Last Stick and Memory Pairs) and five puzzles played alone (Daily Word, Garden Plots, Seesaw, Sudoku and
// Blossoms); and random picks for a break. Scores stay in its own folder. Its words come in Sidefolk's ten languages (strings/, the Kit's L),
// chosen by the `language` Sidefolk passes.
let ext = Extension(name: "playtime", version: "1.0.0")

ext.tool("pick", "Random picks",
         "Truly random: pick a number in a range, or pick from a list of choices (one, or several in order). Use it whenever "
         + "the user wants chance to choose.",
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

ext.surface("play", open: { request in PlayTable.open(request) }, move: { request in PlayTable.move(request) }, close: { request in PlayTable.close(request) })
// Trivia packs made by the person's AI (D95): through the one narrow road any extension has (D100), and checked here.
TriviaAI.send = { id, prompt, label in
    Task { @MainActor in
        switch await AI.ask(prompt, label: label, seconds: 120) {
        case .answer(let text, let madeBy): TriviaAI.answered(id, text: text, madeBy: madeBy)
        case .refused(let reason): TriviaAI.refused(id, reason: reason)
        }
    }
}
PlaytimeTools.install(on: ext)
PlaytimeCarry.install(on: ext)

ext.page("playtime") { _ in PlaytimePage.render() }

await ext.serve()
