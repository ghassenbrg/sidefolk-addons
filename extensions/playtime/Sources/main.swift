import SidefolkExtensionKit

// Playtime, an extension that ships with Sidefolk: games played against the companion in Sidefolk's Play panel (D75),
// trivia first, and random picks for a break. Coins, dice and rock, paper, scissors are the companion's own
// (`companion.toss`), played on the desktop. No permissions; scores stay in its own folder. Its words come in
// Sidefolk's ten languages (Words/), chosen by the `language` Sidefolk passes.
let ext = Extension(name: "playtime", version: "2.0.0")

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

GameTable.register(TriviaScreen.self, on: ext)

ext.page("playtime") { args in PlaytimePage.render(language: args.string("language")) }

await ext.serve()
