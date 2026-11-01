import Foundation
import Testing
@testable import ext_playtime

/// The companion plays like a person of each level (Sidefolk D96): Hard is genuinely strong where the game allows it,
/// Easy can be beaten, and nothing it does is a fixed sequence. Every draw is seeded, so these are the same everywhere.
struct PlaytimeNaturalPlayTests {
    typealias G = Games

    // MARK: Tic-tac-toe

    /// A player who takes a win, blocks a threat, and otherwise picks at random: a decent human.
    static func decent(_ game: G.TicTacToe, _ rng: inout G.Random) -> Int {
        if let win = game.threats(for: .you).first { return win }
        if let block = game.threats(for: .companion).first { return block }
        return rng.pick(game.legalMoves)
    }

    @Test func hardTicTacToeNeverLosesInAThousandGames() throws {
        var losses = 0
        for seed in 0..<1000 {
            var rng = G.Random(seed: UInt64(seed))
            var game = G.TicTacToe(level: .hard, first: seed.isMultiple(of: 2) ? .you : .companion)
            while !game.gameOver {
                let cell: Int
                if game.turn == .companion { cell = game.companionMove(using: &rng) }
                else if seed % 3 == 0 { cell = G.TicTacToe.bestMoves(game.cells, for: .you).randomElement(using: &rng)! }
                else if seed % 3 == 1 { cell = Self.decent(game, &rng) }
                else { cell = rng.pick(game.legalMoves) }
                _ = try game.play(cell, by: game.turn)
            }
            losses += game.series.you
        }
        #expect(losses == 0)
    }

    @Test func easyTicTacToeCanBeBeatenAndFairLessOften() throws {
        func wins(_ level: G.Level) throws -> Int {
            var won = 0
            for seed in 0..<300 {
                var rng = G.Random(seed: UInt64(seed + 7))
                var game = G.TicTacToe(level: level, first: seed.isMultiple(of: 2) ? .you : .companion)
                while !game.gameOver {
                    let cell = game.turn == .companion ? game.companionMove(using: &rng)
                        : G.TicTacToe.bestMoves(game.cells, for: .you).randomElement(using: &rng)!
                    _ = try game.play(cell, by: game.turn)
                }
                won += game.series.you
            }
            return won
        }
        let easy = try wins(.easy), fair = try wins(.fair), hard = try wins(.hard)
        #expect(easy >= 90 && fair < easy && hard == 0, "easy \(easy), fair \(fair), hard \(hard) of 300")
    }

    @Test func ticTacToeOpeningsVaryLikeAPersons() {
        var counts: [Int: Int] = [:]
        for seed in 0..<1000 {
            var rng = G.Random(seed: UInt64(seed))
            counts[G.TicTacToe(level: .hard, first: .companion).companionMove(using: &rng), default: 0] += 1
        }
        #expect(counts.count >= 5 && counts.values.max()! < 400, "\(counts)")
        #expect(counts[4, default: 0] > counts[1, default: 0], "the centre more often than an edge, as people play")
    }

    // MARK: Last Stick

    @Test func hardLastStickWinsEveryWinningPosition() throws {
        for left in 2...21 where G.LastStick.winningTake(left) != nil {
            for seed in 0..<20 {
                var rng = G.Random(seed: UInt64(seed * 31 + left))
                var game = G.LastStick(level: .hard, first: .companion, sticks: left)
                while !game.over {
                    let n = game.turn == .companion ? game.companionTake(using: &rng)
                        : seed.isMultiple(of: 2) ? (G.LastStick.winningTake(game.left) ?? 1) : rng.pick(game.legalTakes)
                    _ = try game.take(n, by: game.turn)
                }
                #expect(game.winner == .companion, "\(left) sticks, seed \(seed)")
            }
        }
    }

    @Test func easyLastStickLosesToTheTrickAndNobodyTakesTheLastStickByChoice() throws {
        var won = 0
        for seed in 0..<300 {
            var rng = G.Random(seed: UInt64(seed))
            var game = G.LastStick(level: .easy, first: .companion)
            while !game.over {
                let n = game.turn == .companion ? game.companionTake(using: &rng) : (G.LastStick.winningTake(game.left) ?? 1)
                _ = try game.take(n, by: game.turn)
            }
            if game.winner == .you { won += 1 }
        }
        #expect(won >= 210, "\(won) of 300")
        for level in G.Level.allCases {
            for left in 2...4 {
                for seed in 0..<50 {
                    var rng = G.Random(seed: UInt64(seed))
                    #expect(G.LastStick(level: level, first: .companion, sticks: left).companionTake(using: &rng) < left)
                }
            }
        }
    }

    // MARK: Higher or Lower

    @Test func theCompanionsGuessesAreNeverOneFixedSequence() throws {
        var first: [Int: Int] = [:]
        var seconds = Set<Int>()
        for seed in 0..<1000 {
            var rng = G.Random(seed: UInt64(seed))
            var game = G.HigherLower.GuessYours(level: .fair, using: &rng)
            first[game.guess, default: 0] += 1
            _ = try game.answer(.higher, using: &rng)
            seconds.insert(game.guess)
        }
        #expect(first.count >= 12 && first.values.max()! < 250, "first guesses \(first)")
        #expect(seconds.count >= 10 && !(first.count == 1 && first[50] != nil))
    }

    @Test func hardFindsAnyNumberAboutAsFastAsHalving() throws {
        for (range, worst, mean) in [(1...100, 9, 7.0), (1...1000, 13, 10.3), (1...10, 5, 3.5)] {
            var total = 0, most = 0
            for secret in range {
                var rng = G.Random(seed: UInt64(secret))
                var game = G.HigherLower.GuessYours(range: range, level: .hard, using: &rng)
                while !game.found {
                    _ = try game.answer(game.guess == secret ? .yes : secret > game.guess ? .higher : .lower, using: &rng)
                }
                total += game.asked
                most = max(most, game.asked)
            }
            let average = Double(total) / Double(range.count)
            #expect(most <= worst && average <= mean, "\(range): worst \(most), mean \(average)")
        }
        // A million: found, and its guesses read as a person's round numbers more often than not.
        var rng = G.Random(seed: 4)
        var game = G.HigherLower.GuessYours(range: 1...1_000_000, level: .hard, using: &rng)
        var round = 0
        let secret = 637_281
        while !game.found {
            if game.guess % 1000 == 0 { round += 1 }
            _ = try game.answer(game.guess == secret ? .yes : secret > game.guess ? .higher : .lower, using: &rng)
        }
        #expect(game.asked <= 26 && round >= 3, "\(game.asked) questions, \(round) round")
        // Every level says big numbers round: while the numbers left are over a thousand apart, each guess ends in zeros.
        for level in G.Level.allCases {
            for seed in 0..<40 {
                var r = G.Random(seed: UInt64(seed))
                var g = G.HigherLower.GuessYours(range: 1...1_000_000, level: level, using: &r)
                let secret = r.between(1, 1_000_000)
                while !g.found {
                    if g.high - g.low > 1000 { #expect(g.guess % 10 == 0, "\(level) said \(g.guess) on \(g.low)…\(g.high)") }
                    _ = try g.answer(g.guess == secret ? .yes : secret > g.guess ? .higher : .lower, using: &r)
                }
            }
        }
    }

    @Test func eachRangeHasItsParAndWarmth() {
        #expect(G.HigherLower.par(100) == 7 && G.HigherLower.par(10) == 4 && G.HigherLower.par(1000) == 10 && G.HigherLower.par(1_000_000) == 20)
        #expect(G.HigherLower.range(nil, 5_000_000) == 1...1_000_000 && G.HigherLower.range(50, 500) == 50...500 && G.HigherLower.range(nil, 1) == 0...1)
        var big = G.HigherLower.GuessMine(range: 1...1_000_000, secret: 500_000)
        _ = try? big.guess(501_000)
        #expect(big.warmth > 0.85 && big.warmth < 0.95, "\(big.warmth)")
        var small = G.HigherLower.GuessMine(range: 1...100, secret: 50)
        _ = try? small.guess(60)
        #expect(abs(small.warmth - (1 - 10.0 / 99)) < 1e-9, "1 to 100 feels as it always did")
        #expect(throws: G.Refusal("out_of_range")) { var g = G.HigherLower.GuessMine(range: 50...500, secret: 70); _ = try g.guess(20) }
        #expect(HigherLowerEngine.typedTop("1 000") == 1000 && HigherLowerEngine.typedTop("١٠٠٠") == 1000 && HigherLowerEngine.typedTop("１０００") == 1000)
        #expect(HigherLowerEngine.typedTop("lots") == nil && HigherLowerEngine.typedTop("1") == nil && HigherLowerEngine.typedTop("9999999") == nil)
    }

    // MARK: Memory Pairs

    @Test func memoryFadesLikeAPersonsAndHardRemembersBest() throws {
        func companionPairs(_ level: G.Level) throws -> Int {
            var total = 0
            for seed in 0..<60 {
                var rng = G.Random(seed: UInt64(seed)), person = G.Random(seed: UInt64(seed + 1000))
                var game = G.MemoryPairs(level: level, using: &rng)
                while !game.over {
                    if game.waitingToCover { _ = try game.cover(); continue }
                    let cell = game.turn == .companion ? game.companionFlip(using: &rng).cell
                        : person.pick(game.cards.indices.filter { game.owner[$0] == nil && !game.faceUp.contains($0) })
                    _ = try game.flip(cell, by: game.turn)
                }
                total += game.score.companion
            }
            return total
        }
        let easy = try companionPairs(.easy), fair = try companionPairs(.fair), hard = try companionPairs(.hard)
        #expect(easy < fair && fair < hard, "easy \(easy), fair \(fair), hard \(hard)")
        let game = { () -> G.MemoryPairs in var r = G.Random(seed: 1); return G.MemoryPairs(level: .fair, using: &r) }()
        #expect(game.recall(age: 1) > game.recall(age: 10) && game.recall(age: 10) > game.recall(age: 30), "recent cards are remembered best")
        #expect(G.MemoryPairs.adjacent(5, 6) && G.MemoryPairs.adjacent(5, 1) && !G.MemoryPairs.adjacent(3, 4) && !G.MemoryPairs.adjacent(0, 5))
    }

    // MARK: Quick Paws, Copy Me, Which Cup?

    @Test func reflexesLeanLateAndNeverRepeat() {
        let game = G.QuickPaws(level: .fair)
        var rng = G.Random(seed: 11)
        let times = (0..<2000).map { _ in game.companionReaction(using: &rng) }
        let mean = Double(times.reduce(0, +)) / Double(times.count)
        #expect(abs(mean - 320) < 30 && times.min()! >= 150, "mean \(mean)")
        #expect(times.filter { $0 > 470 }.count > 20 && times.filter { $0 < 260 }.count > 100, "a tail of slow ones, quick ones too")
        #expect(Set(times).count > 150)
    }

    @Test func copyMeNeverRepeatsAMoveThreeTimes() {
        for seed in 0..<80 {
            var rng = G.Random(seed: UInt64(seed))
            var game = G.CopyMe(level: seed.isMultiple(of: 2) ? .hard : .fair, using: &rng)
            var all: [G.CopyMe.Pad] = []
            while all.count < 60 {
                all = game.sequence
                guard all.count < 60 else { break }
                _ = try? game.watched()
                for pad in game.sequence { _ = try? game.press(pad) }
            }
            #expect(!(2..<all.count).contains { all[$0] == all[$0 - 1] && all[$0] == all[$0 - 2] }, "seed \(seed)")
        }
    }

    @Test func theShellPlayerMovesTheGem() throws {
        var moved = 0, swaps = 0, repeats = 0
        for seed in 0..<200 {
            var rng = G.Random(seed: UInt64(seed))
            var game = G.WhichCup(level: .fair)
            let shuffle = try game.start(using: &rng)
            var at = shuffle.hide
            for (i, pair) in shuffle.swaps.enumerated() {
                if pair.contains(at) { moved += 1; at = pair[0] == at ? pair[1] : pair[0] }
                if i > 0, pair == shuffle.swaps[i - 1] { repeats += 1 }
                swaps += 1
            }
            #expect(at == game.gem)
        }
        #expect(Double(moved) / Double(swaps) > 0.55 && Double(repeats) / Double(swaps) < 0.05, "\(moved) moves, \(repeats) repeats of \(swaps)")
    }
}
