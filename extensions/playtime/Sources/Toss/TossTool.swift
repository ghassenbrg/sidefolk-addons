import Foundation
import SidefolkExtensionKit

/// `toss`: the companion flips coins, rolls dice or plays a hand on the desktop. The draw happens here, as a tool like every action, so the AI, the person's own
/// words and the menu reach the same real chance; the reply opens the overlay that shows it, and keeps the AI's words back until it has landed.
@MainActor
enum TossTool {
    static func install(on ext: Extension) {
        ext.tool("toss", "Flip a coin, roll dice or play a hand",
                 """
                 Your companion flips coins, rolls dice or plays rock, paper, scissors on the user's desktop, where they watch it happen. The result is truly random and comes \
                 back to you: say it as it came, never make one up. Use it whenever the user wants a coin flip, a dice roll (count, sides and modifier, as in 2d6+1 or d20) or a \
                 round of rock, paper, scissors (pass the user's hand; if they didn't say it, ask for it first).
                 """,
                 input: Schema.object([
                     "kind": Schema.string("What to do.", oneOf: ["coin", "dice", "rock_paper_scissors"]),
                     "count": Schema.integer("coin: how many coins (1 to 5). dice: how many dice (1 to 10). 1 if not given.", minimum: 1, maximum: 10),
                     "sides": Schema.integer("dice: sides on each die; 6 if not given, 20 for a d20.", minimum: 2, maximum: 100),
                     "modifier": Schema.integer("dice: added to the sum, like the +1 of 2d6+1.", minimum: -100, maximum: 100),
                     "hand": Schema.string("rock_paper_scissors: the user's hand.", oneOf: Games.Hand.allCases.map(\.rawValue)),
                     "call": Schema.string("coin: what the user called for one coin, if they did.", oneOf: ["heads", "tails"]),
                     "many": Schema.string("Leave this out.", maxLength: 3),
                     "minus": Schema.integer("Leave this out.", minimum: 1, maximum: 100),
                 ], required: ["kind"])) { args in try run(args) }
    }

    private static func run(_ a: Arguments) throws -> ToolReply {
        var random = Games.Random.fresh()
        let toss = try draw(a, random: &random)
        let text: String
        switch toss {
        case .coins: text = "Flipped on the user's desktop, where they saw it: \(toss.forModel). Say it in a few words."
        case .dice: text = "Rolled on the user's desktop, where they saw it: \(toss.forModel). Say it in a few words."
        case .hands(let person, let companion):
            let s = PlaytimeRecords.addThrow(person: person, companion: companion)
            text = "Played on the user's desktop, where they saw it: \(toss.forModel). Score this far: the user \(s.person), you \(s.companion), draws \(s.draws). Say it in a few words."
        }
        return ToolReply(text).opening(surface: "toss", arguments: toss.arguments).holdingAnswer(ms: TossSurface.Timing(toss).totalMs)
    }

    /// What the words asked for, with the same limits a person's and the AI's words meet.
    static func draw(_ a: Arguments, random: inout Games.Random) throws -> Toss {
        let count = a.string("many").flatMap { Int($0.dropFirst()) } ?? a.int("count") ?? 1
        switch a.string("kind") {
        case "coin":
            guard (1...Toss.maxCoins).contains(count) else { throw Problem(L("Flip between 1 and {n} coins at a time.", ["n": Toss.maxCoins])) }
            let call = count == 1 ? a.string("call").flatMap { ["heads": true, "tails": false][$0.lowercased()] } : nil
            return .coins((0..<count).map { _ in random.below(2) == 1 }, call: call)
        case "dice":
            let sides = a.int("sides") ?? 6, modifier = a.int("minus").map { -$0 } ?? a.int("modifier") ?? 0
            guard (1...Toss.maxDice).contains(count) else { throw Problem(L("Roll between 1 and {n} dice at a time.", ["n": Toss.maxDice])) }
            guard Toss.sidesRange.contains(sides), Toss.modifierRange.contains(modifier) else { throw Problem(L("Dice have 2 to 100 sides, and the number added is at most 100.")) }
            return .dice(sides: sides, rolls: (0..<count).map { _ in random.between(1, sides) }, modifier: modifier)
        case "rock_paper_scissors":
            guard let hand = a.string("hand").flatMap({ Games.Hand(rawValue: $0.lowercased()) }) else { throw Problem(L("Tell me the user's hand: rock, paper or scissors.")) }
            return .hands(person: hand, companion: Games.Hand.allCases[random.below(3)])
        default:
            throw Problem(L("“kind” must be coin, dice or rock_paper_scissors."))
        }
    }
}
