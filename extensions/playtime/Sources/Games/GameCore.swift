import Foundation

/// Playtime's game engines: small deterministic state machines that a thin adapter drives from the Play panel's game
/// channel. They do no I/O, keep no clock and draw nothing. A delay (the companion thinking, a reflex wait, a shuffle's
/// speed) is a number the adapter schedules; chance comes from a `Games.Random` the adapter seeds (from the system in
/// play, a fixed number in tests); what a game keeps between rounds is a plain Codable value the adapter saves in
/// Playtime's data folder. Each engine is a value: `play(...)` changes it and returns what happened as `Event`s.
enum Games {
    /// The two players: the person, and the companion beside the board.
    enum Side: String, Codable, Sendable, CaseIterable {
        case you, companion
        var other: Side { self == .you ? .companion : .you }
    }

    /// How hard the companion plays. Every game reads the same three, so the panel has one level picker.
    enum Level: String, Codable, Sendable, CaseIterable {
        case easy, fair, hard
    }

    struct Score: Codable, Equatable, Sendable {
        var you = 0
        var companion = 0
        subscript(side: Side) -> Int {
            get { side == .you ? you : companion }
            set { if side == .you { you = newValue } else { companion = newValue } }
        }
        /// Who is ahead, or nil when level.
        var leader: Side? { you == companion ? nil : (you > companion ? .you : .companion) }
    }

    /// A move the engine refuses. `reason` is a short key the adapter can show through `Phrases`
    /// (`refusal.<reason>`); the state is unchanged.
    struct Refusal: Error, Equatable, Sendable {
        let reason: String
        init(_ reason: String) { self.reason = reason }
    }

    /// What a move caused, for the adapter to turn into the companion's cues, sounds and board animations. Engines only
    /// report; whether the companion sulks or cheers for each is the platform's mapping (its keyed lines and moves).
    enum Event: Equatable, Codable, Sendable {
        /// It is this side's turn now.
        case turn(Side)
        /// The companion is deciding: show `think` for this long, then ask the engine for its move.
        case think(ms: Int)
        /// The companion has made a hidden choice (trivia's sealed card, Higher or Lower's number).
        case sealed
        /// Something hidden is shown: the sealed pick, the gem's cup, the companion's number, the word.
        case reveal
        /// A side got a point (a right answer, a quicker boop, a pair, a found cup).
        case point(Side)
        /// A round or game ended; nil is a draw.
        case roundOver(winner: Side?)
        /// The match or series ended; nil is a draw.
        case matchOver(winner: Side?)
        case streak(Int)
        case newBest(Int)
        /// A side can win with its next move (tic-tac-toe): the companion grins, or sweats when it's you.
        case threat(Side)
        /// A side made two threats at once (tic-tac-toe's fork): "Wait… wait…"
        case fork(Side)
        /// Hard tic-tac-toe after three draws in a row: the companion admits it can't lose.
        case unbeatable
        case hint
        /// A press before the signal (Quick Paws) and no press in time.
        case tooSoon
        case tooSlow
        /// Copy Me: a wrong pad; the sequence grew to this length.
        case mistake
        case grew(Int)
        /// Which Cup? on Sneaky: caught palming the gem, accused while innocent, or confessing after a pick.
        case caught
        case innocent
        case confess
        /// Higher or Lower: the number is higher or lower than the guess, the answers contradict, it's found.
        case higher
        case lower
        case contradiction
        case found(guesses: Int)
        /// A letter guess: how many places it filled, or a miss with the balloons left.
        case hit(Int)
        case miss(left: Int)
        /// Memory Pairs: a side turned a pair, or two that don't match.
        case pair(Side)
        case noPair(Side)
        /// The companion uses something it remembered ("I saw a moon… around here?").
        case recalls
        /// Guess My Animal learned a new animal; its memory was full and it forgot the oldest one it was taught.
        case learned
        case forgot
        /// Last Stick: after three losses the companion offers to teach its trick.
        case offerSecret
        /// Trivia's "Ask Mochi": whether the companion is sure of its whisper (unsure means a sweat drop).
        case lifeline(sure: Bool)
        /// The adapter's own (GameKit): the game just opened, for the companion's hello; a move the engine refused,
        /// its `Refusal` reason, shown as a note in the person's words.
        case opened
        case refused(String)
    }
}

extension Games {
    /// A small seedable generator (SplitMix64) with its own draws, so the same seed gives the same game on every Mac and
    /// every Swift version: the standard library's `random(in:using:)` and `shuffled(using:)` don't promise their
    /// algorithm, and Daily Word must be the same for everyone on a date.
    struct Random: RandomNumberGenerator, Codable, Equatable, Sendable {
        private(set) var state: UInt64

        init(seed: UInt64) { state = seed }

        /// A generator seeded from the system, for real play.
        static func fresh() -> Random { Random(seed: UInt64.random(in: .min ... .max)) }

        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }

        /// 0 ..< n. The modulo bias is below one in 2^50 for the small n games use.
        mutating func below(_ n: Int) -> Int {
            precondition(n > 0)
            return Int(next() % UInt64(n))
        }

        /// lo ... hi, inclusive.
        mutating func between(_ lo: Int, _ hi: Int) -> Int { lo + below(hi - lo + 1) }

        /// True with probability p.
        mutating func chance(_ p: Double) -> Bool { unit() < p }

        /// 0 ..< 1, evenly.
        mutating func unit() -> Double { Double(next() >> 11) / Double(1 << 53) }

        /// A bell curve's draw (Box–Muller): mostly near `mean`, two in three within one `spread`.
        mutating func normal(_ mean: Double, _ spread: Double) -> Double {
            let u = max(unit(), 1e-12), v = unit()
            return mean + spread * (-2 * log(u)).squareRoot() * cos(2 * .pi * v)
        }

        /// One index of `weights`, each as likely as its weight.
        mutating func weighted(_ weights: [Double]) -> Int {
            var left = unit() * weights.reduce(0, +)
            for (i, w) in weights.enumerated() {
                left -= w
                if left < 0 { return i }
            }
            return weights.count - 1
        }

        /// One of `items`, each as likely as its weight.
        mutating func pickWeighted<T>(_ items: [T], weight: (T) -> Double) -> T { items[weighted(items.map(weight))] }

        mutating func pick<T>(_ items: [T]) -> T { items[below(items.count)] }

        mutating func shuffled<T>(_ items: [T]) -> [T] {
            var a = items
            if a.count < 2 { return a }
            for i in stride(from: a.count - 1, to: 0, by: -1) { a.swapAt(i, below(i + 1)) }
            return a
        }
    }

    /// FNV-1a: a stable number for a string (a companion's id, a date), the same in every process. Swift's own
    /// `hashValue` changes on every launch.
    static func stableHash(_ text: String) -> UInt64 {
        var h: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in text.utf8 { h = (h ^ UInt64(byte)) &* 0x0100_0000_01B3 }
        return h
    }

    /// How long the companion thinks before a move: `base` ms give or take up to `spread`, drawn from the position
    /// (`seed`, its board), so no two moves take one fixed time and a replay of the same position looks the same.
    static func pause(_ base: Int, spread: Int, seed: UInt64) -> Int {
        var r = Random(seed: seed)
        return max(150, base + r.between(-spread, spread))
    }
}

extension Games {
    /// The ten languages Sidefolk speaks (its AppLanguage codes). Every game's words exist in all of them.
    enum Language: String, Codable, Sendable, CaseIterable {
        case en, fr, es, de, it, pt = "pt-BR", ja, ko, zh = "zh-Hans", ar

        /// The language for a code Sidefolk passes ("fr", "pt-BR", "zh-Hans"), or a near one ("pt", "zh-CN",
        /// "en-GB"); English only for a language Sidefolk doesn't speak.
        init(code: String) {
            let base = code.lowercased().split(whereSeparator: { $0 == "-" || $0 == "_" }).first.map(String.init) ?? ""
            self = Language.allCases.first { $0.key == base } ?? .en
        }

        /// The short key the content files use (`pt`, `zh`).
        var key: String { String(rawValue.prefix(2)) }

        var rightToLeft: Bool { self == .ar }
    }

    /// One piece of text in every language, under one id.
    struct Text: Codable, Equatable, Hashable, Sendable {
        /// By `Language.key`.
        var byKey: [String: String]

        subscript(language: Language) -> String { byKey[language.key] ?? byKey["en"] ?? "" }

        /// The languages missing, for the content checks.
        var missing: [Language] { Language.allCases.filter { (byKey[$0.key] ?? "").isEmpty } }
    }
}
