import Foundation

extension Games {
    /// A hand in rock, paper, scissors.
    enum Hand: String, Codable, CaseIterable, Sendable {
        case rock, paper, scissors

        /// The hand this one beats.
        var beats: Hand {
            switch self {
            case .rock: .scissors
            case .paper: .rock
            case .scissors: .paper
            }
        }

        /// The companion's hand for a round: from the generator it is given, never looking at the person's, and drawn before they pick. Any of the three, except
        /// that after two of a kind it picks between the other two, as people do.
        static func draw(after thrown: [Hand], using rng: inout Random) -> Hand {
            guard thrown.count >= 2, thrown[thrown.count - 1] == thrown[thrown.count - 2] else { return allCases[rng.below(3)] }
            let others = allCases.filter { $0 != thrown.last }
            return others[rng.below(2)]
        }
    }
}
