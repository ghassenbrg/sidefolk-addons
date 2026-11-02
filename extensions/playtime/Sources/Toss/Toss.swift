import Foundation
import SidefolkExtensionKit

/// What came up when the companion flipped, rolled or played a hand (Sidefolk D44, amended; D101): drawn here with the system's generator, so the result is real and
/// the model can only repeat it. Fixed before anything plays: the overlay only shows it.
enum Toss: Equatable {
    typealias Hand = Games.Hand

    /// One entry per coin: true is heads. `call` is what the person called for a single coin, if they did.
    case coins([Bool], call: Bool? = nil)
    /// Each die's face, and what is added to their sum (the +1 of 2d6+1).
    case dice(sides: Int, rolls: [Int], modifier: Int)
    /// The person's hand, and the companion's.
    case hands(person: Hand, companion: Hand)

    static let maxCoins = 5
    static let maxDice = 10
    static let sidesRange = 2...100
    static let modifierRange = -100...100

    /// What the chip says: "Heads!", "It's 4!", "4 + 2 = 6", "Paper beats rock: you win!".
    var result: String {
        switch self {
        case .coins(let flips, _):
            guard flips.count > 1 else { return flips.first == true ? L("Heads!") : L("Tails!") }
            return Self.capitalizedFirst(Self.list(flips.map { $0 ? L("heads") : L("tails") }))
        case .dice(_, let rolls, let modifier):
            if rolls.count == 1, modifier == 0 { return L("It's {n}!", ["n": Self.number(rolls[0])]) }
            return Self.sum(rolls, modifier, Self.number)
        case .hands(let person, let companion):
            return TossWords.verdict(person: person, companion: companion)
        }
    }

    /// History's row: what was done and what came up, "Flip a coin — Heads!", "Roll 2d6+1 — 4 + 2 + 1 = 7".
    var row: String {
        let what: String
        switch self {
        case .coins(let flips, _): what = flips.count > 1 ? L("Flip {n} coins", ["n": flips.count]) : L("Flip a coin")
        case .dice(let sides, let rolls, let modifier):
            what = rolls.count == 1 && sides == 6 && modifier == 0 ? L("Roll a die") : L("Roll {dice}", ["dice": Self.notation(count: rolls.count, sides: sides, modifier: modifier)])
        case .hands: what = L("Rock, paper, scissors")
        }
        return what + " — " + result
    }

    /// Whether the person's call was right, when they called one coin.
    var called: Bool? {
        guard case .coins(let flips, let call?) = self, flips.count == 1 else { return nil }
        return call == flips[0]
    }

    /// A hand won or lost, a coin called right or wrong; dice and an uncalled coin mean nothing either way.
    var verdict: Verdict? {
        switch self {
        case .coins: called.map { $0 ? .win : .loss }
        case .dice: nil
        case .hands(let person, let companion): person == companion ? .draw : person.beats == companion ? .win : .loss
        }
    }

    /// "2d6+1", "d20": dice as players write them, in every language.
    static func notation(count: Int, sides: Int, modifier: Int) -> String {
        "\(count == 1 ? "" : String(count))d\(sides)" + (modifier == 0 ? "" : modifier > 0 ? "+\(modifier)" : "\(modifier)")
    }

    /// "4 + 2 + 1 = 7", "4 + 2 − 1 = 5".
    static func sum(_ rolls: [Int], _ modifier: Int, _ format: (Int) -> String) -> String {
        var parts = rolls.map(format).joined(separator: " + ")
        if modifier != 0 { parts += modifier > 0 ? " + \(format(modifier))" : " − \(format(-modifier))" }
        return parts + " = " + format(rolls.reduce(0, +) + modifier)
    }

    /// "5 + 3 + 1": the sum without its total.
    var parts: String {
        guard case .dice(_, let rolls, let modifier) = self else { return "" }
        let sum = Self.sum(rolls, modifier, Self.number)
        return String(sum[..<(sum.range(of: " = ")?.lowerBound ?? sum.endIndex)])
    }

    /// A die's face or a sum as the person's language writes numbers.
    static func number(_ n: Int) -> String { n.formatted(.number.grouping(.never).locale(Language.locale)) }

    /// "heads, tails and heads", as the person's language joins a list.
    private static func list(_ items: [String]) -> String { items.formatted(.list(type: .and, width: .narrow).locale(Language.locale)) }

    private static func capitalizedFirst(_ text: String) -> String { text.prefix(1).uppercased() + text.dropFirst() }

    // MARK: As a surface's arguments

    /// Small plain values: what the tool drew reaches the overlay in the reply that opens it.
    var arguments: [String: Any] {
        switch self {
        case .coins(let flips, let call):
            var out: [String: Any] = ["kind": "coin", "flips": flips.map { $0 ? "1" : "0" }.joined()]
            if let call { out["call"] = call ? "heads" : "tails" }
            return out
        case .dice(let sides, let rolls, let modifier):
            return ["kind": "dice", "sides": sides, "rolls": rolls.map(String.init).joined(separator: ","), "modifier": modifier]
        case .hands(let person, let companion):
            return ["kind": "hands", "person": person.rawValue, "companion": companion.rawValue]
        }
    }

    init?(arguments a: Arguments) {
        switch a.string("kind") {
        case "coin":
            guard let flips = a.string("flips"), !flips.isEmpty, flips.count <= Self.maxCoins else { return nil }
            self = .coins(flips.map { $0 == "1" }, call: a.string("call").map { $0 == "heads" })
        case "dice":
            let rolls = (a.string("rolls") ?? "").split(separator: ",").compactMap { Int($0) }
            guard !rolls.isEmpty, rolls.count <= Self.maxDice, let sides = a.int("sides"), Self.sidesRange.contains(sides) else { return nil }
            self = .dice(sides: sides, rolls: rolls, modifier: a.int("modifier") ?? 0)
        case "hands":
            guard let person = a.string("person").flatMap(Hand.init(rawValue:)), let companion = a.string("companion").flatMap(Hand.init(rawValue:)) else { return nil }
            self = .hands(person: person, companion: companion)
        default: return nil
        }
    }
}

enum TossWords {
    /// Each pair in a whole sentence of its own, so every language can say it its way.
    static func verdict(person: Toss.Hand, companion: Toss.Hand) -> String {
        switch (person, companion) {
        case (.rock, .scissors): L("Rock beats scissors: you win!")
        case (.scissors, .rock): L("Rock beats scissors: I win!")
        case (.paper, .rock): L("Paper beats rock: you win!")
        case (.rock, .paper): L("Paper beats rock: I win!")
        case (.scissors, .paper): L("Scissors beat paper: you win!")
        case (.paper, .scissors): L("Scissors beat paper: I win!")
        case (.rock, _): L("We both played rock: a draw!")
        case (.paper, _): L("We both played paper: a draw!")
        case (.scissors, _): L("We both played scissors: a draw!")
        }
    }
}
