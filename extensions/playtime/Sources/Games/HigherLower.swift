import Foundation

extension Games {
    /// Higher or Lower, both ways round, on 1–100.
    enum HigherLower {
        static let range = 1...100
        /// Halving 1–100 always finds a number in seven questions, so seven is par for you as well.
        static let par = 7

        /// "Guess mine": the companion holds a sealed number; each guess gets higher or lower, and a warmth for the
        /// thermometer (it shivers when you're far, fans itself when close). Events: `sealed` at the start, `higher`,
        /// `lower`, then `reveal`, `found(guesses:)` and `roundOver` (you win at par or better).
        struct GuessMine: Codable, Equatable, Sendable {
            private let secret: Int
            private(set) var guesses: [Int] = []
            private(set) var found = false
            /// The range your guesses still leave open, for the board.
            private(set) var low = range.lowerBound
            private(set) var high = range.upperBound

            init(using rng: inout Random) {
                secret = rng.between(range.lowerBound, range.upperBound)
            }

            static var opening: [Event] { [.sealed] }

            /// 0 (far) to 1 (right on it) for the last guess: the meter part.
            var warmth: Double {
                guard let last = guesses.last else { return 0 }
                return 1 - Double(abs(last - secret)) / Double(range.upperBound - range.lowerBound)
            }

            /// The number, once you have found it.
            var shown: Int? { found ? secret : nil }

            mutating func guess(_ n: Int) throws -> [Event] {
                guard !found else { throw Refusal("over") }
                guard range.contains(n) else { throw Refusal("out_of_range") }
                guesses.append(n)
                if n == secret {
                    found = true
                    return [.reveal, .found(guesses: guesses.count), .roundOver(winner: guesses.count <= par ? .you : .companion)]
                }
                if n < secret { low = max(low, n + 1) } else { high = min(high, n - 1) }
                return [n < secret ? .higher : .lower]
            }
        }

        /// "I'll guess yours": you think of a number, the companion halves the range ("Is it… 50?") and you answer
        /// higher, lower or yes. It always finds it within seven. An answer that contradicts an earlier one is refused
        /// with `.contradiction`, and the companion asks again (`contradicts` is the earlier guess, for "You said lower
        /// than 30 before…"). Events: `think`, `contradiction`, `found(guesses:)`, `roundOver(winner: .companion)`.
        struct GuessYours: Codable, Equatable, Sendable {
            enum Answer: String, Codable, Sendable { case higher, lower, yes }

            private(set) var low = range.lowerBound
            private(set) var high = range.upperBound
            private(set) var guess = (range.lowerBound + range.upperBound) / 2
            private(set) var asked = 1
            private(set) var found = false
            /// The earlier guesses that set the bounds now in force.
            private(set) var lowFrom: Int?
            private(set) var highFrom: Int?
            /// The guess an answer contradicted, until the next good answer.
            private(set) var contradicts: Int?

            init() {}

            mutating func answer(_ answer: Answer) throws -> [Event] {
                guard !found else { throw Refusal("over") }
                switch answer {
                case .yes:
                    found = true
                    return [.found(guesses: asked), .roundOver(winner: .companion)]
                case .higher:
                    guard guess + 1 <= high else { contradicts = highFrom ?? guess; return [.contradiction] }
                    low = guess + 1
                    lowFrom = guess
                case .lower:
                    guard guess - 1 >= low else { contradicts = lowFrom ?? guess; return [.contradiction] }
                    high = guess - 1
                    highFrom = guess
                }
                contradicts = nil
                guess = (low + high) / 2
                asked += 1
                return [.think(ms: 500 + 100 * asked)]
            }
        }
    }
}
