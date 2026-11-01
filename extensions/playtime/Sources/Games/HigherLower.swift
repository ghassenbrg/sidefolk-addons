import Foundation

extension Games {
    /// Higher or Lower, both ways round, on 1 to a top the person picks: 100 unless they choose 10, 1,000, 1,000,000 or
    /// any number up to a million (or a range they name, "between 50 and 500", from Sidefolk's slots).
    enum HigherLower {
        static let defaultTop = 100
        /// The tops offered on the start board; any other from 2 to `largest` can be typed.
        static let tops = [10, 100, 1000, 1_000_000]
        static let largest = 1_000_000

        /// Halving finds any of `count` numbers in this many questions, so it is par for you as well: 7 for 1–100,
        /// 10 for 1–1,000, 20 for 1–a million.
        static func par(_ count: Int) -> Int { max(1, Int.bitWidth - max(count, 1).leadingZeroBitCount) }

        /// A range the person asked for, kept within 0…a million and at least two numbers wide.
        static func range(_ low: Int?, _ high: Int?) -> ClosedRange<Int> {
            let top = min(max(high ?? defaultTop, 1), largest)
            let bottom = min(max(low ?? 1, 0), top - 1)
            return bottom...top
        }

        /// "Guess mine": the companion holds a sealed number; each guess gets higher or lower, and a warmth for the
        /// thermometer (it shivers when you're far, fans itself when close). Events: `sealed` at the start, `higher`,
        /// `lower`, then `reveal`, `found(guesses:)` and `roundOver` (you win at par or better).
        struct GuessMine: Codable, Equatable, Sendable {
            let bottom: Int
            let top: Int
            private let secret: Int
            private(set) var guesses: [Int] = []
            private(set) var found = false
            /// The range your guesses still leave open, for the board.
            private(set) var low: Int
            private(set) var high: Int

            /// The number is drawn here, before any guess (D75).
            init(range: ClosedRange<Int> = 1...HigherLower.defaultTop, using rng: inout Random) {
                self.init(range: range, secret: rng.between(range.lowerBound, range.upperBound))
            }

            /// A number set by a person (two players: the one who hides it), within the range.
            init(range: ClosedRange<Int>, secret: Int) {
                bottom = range.lowerBound
                top = range.upperBound
                low = bottom
                high = top
                self.secret = Swift.min(Swift.max(secret, bottom), top)
            }

            static var opening: [Event] { [.sealed] }
            var par: Int { HigherLower.par(top - bottom + 1) }

            /// 0 (far) to 1 (right on it) for the last guess: the meter part. On a wide range the distance counts by
            /// its size rather than its share, so 1,000 off in a million still reads warm, as it is.
            var warmth: Double {
                guard let last = guesses.last else { return 0 }
                let width = Swift.max(top - bottom, 1)
                let share = Double(abs(last - secret)) / Double(width)
                let curve = width <= 100 ? 1 : 2 / log10(Double(width))
                return 1 - pow(share, curve)
            }

            /// The number, once you have found it.
            var shown: Int? { found ? secret : nil }

            mutating func guess(_ n: Int) throws -> [Event] {
                guard !found else { throw Refusal("over") }
                guard (bottom...top).contains(n) else { throw Refusal("out_of_range") }
                guesses.append(n)
                if n == secret {
                    found = true
                    return [.reveal, .found(guesses: guesses.count), .roundOver(winner: guesses.count <= par ? .you : .companion)]
                }
                if n < secret { low = max(low, n + 1) } else { high = min(high, n - 1) }
                return [n < secret ? .higher : .lower]
            }
        }

        /// "I'll guess yours": you think of a number and the companion asks "Is it…?" like a person would: near the
        /// middle of what's left but never the exact half every time, round numbers on a wide range, looser on Easy
        /// (`Guesser`). You answer higher, lower or yes. An answer that contradicts an earlier one is refused with
        /// `.contradiction`, and the companion asks again (`contradicts` is the earlier guess, for "You said lower
        /// than 30 before…"). Events: `think`, `contradiction`, `found(guesses:)`, `roundOver(winner: .companion)`.
        struct GuessYours: Codable, Equatable, Sendable {
            enum Answer: String, Codable, Sendable { case higher, lower, yes }

            let bottom: Int
            let top: Int
            let level: Level
            private(set) var low: Int
            private(set) var high: Int
            private(set) var guess: Int
            private(set) var asked = 1
            private(set) var found = false
            /// The earlier guesses that set the bounds now in force.
            private(set) var lowFrom: Int?
            private(set) var highFrom: Int?
            /// The guess an answer contradicted, until the next good answer.
            private(set) var contradicts: Int?

            init(range: ClosedRange<Int> = 1...HigherLower.defaultTop, level: Level = .fair, using rng: inout Random) {
                bottom = range.lowerBound
                top = range.upperBound
                self.level = level
                low = bottom
                high = top
                guess = Guesser.pick(low: bottom, high: top, level: level, after: nil, using: &rng)
            }

            mutating func answer(_ answer: Answer, using rng: inout Random) throws -> [Event] {
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
                guess = Guesser.pick(low: low, high: high, level: level, after: answer, using: &rng)
                asked += 1
                // Bigger numbers take a little longer to think through, and no two pauses are alike.
                return [.think(ms: 450 + 70 * String(high).count + 25 * min(asked, 10) + rng.between(0, 350))]
            }
        }

        /// How the companion picks its next guess between `low` and `high`.
        enum Guesser {
            /// Near the middle with a level's looseness (Hard within 9 % of the half, Fair 18 %, Easy 28 %), and on Easy now
            /// and then a timid step on from the last answer instead. On every level the guess is said as a person says
            /// it: always a round number while the numbers are big (above a thousand apart: "Is it 450,000?", never
            /// 349,909), often one on smaller ranges ("Is it 45?"). Always within the range.
            static func pick(low: Int, high: Int, level: Level, after: GuessYours.Answer?, using rng: inout Random) -> Int {
                let width = high - low
                guard width > 1 else { return width == 1 && rng.chance(0.5) ? high : low }
                if level == .easy, width > 8, let after, rng.chance(0.15) {
                    let step = max(1, width / rng.between(6, 10))
                    let timid = after == .higher ? low + step : high - step
                    return round(timid, width: width, within: low + 1...max(low + 1, high - 1), using: &rng)
                }
                let spread: Double = switch level { case .easy: 0.28; case .fair: 0.18; case .hard: 0.09 }
                let lo = low + Int((Double(width) * (0.5 - spread)).rounded(.up))
                let hi = max(lo, low + Int((Double(width) * (0.5 + spread)).rounded(.down)))
                let raw = min(max(low + Int((Double(width) * (0.5 + (rng.unit() * 2 - 1) * spread)).rounded()), lo), hi)
                guard width > 1000 || rng.chance(0.6) else { return raw }
                return round(raw, width: width, within: lo...hi, using: &rng)
            }

            /// `n` as a round number that stays `within`: a multiple of 5, 2 or 1 times a power of ten about a fortieth of
            /// the width, the roundest that fits more often; `n` itself when none does.
            static func round(_ n: Int, width: Int, within window: ClosedRange<Int>, using rng: inout Random) -> Int {
                let unit = Int(pow(10, floor(log10(max(Double(width) / 40, 1)))))
                let fits = [unit * 10, unit * 5, unit * 2, unit].map { step in (n + step / 2) / step * step }.filter(window.contains)
                guard !fits.isEmpty else { return n }
                return rng.chance(0.5) ? fits[0] : rng.pick(fits)
            }
        }
    }
}
