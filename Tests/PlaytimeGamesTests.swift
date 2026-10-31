import Foundation
import Testing
@testable import ext_playtime

/// Playtime's game engines, played move by move with seeded chance: the rules, the companion's play at each level,
/// and the events the Play panel turns into cues. Nothing here waits: timings are only values.
struct PlaytimeGamesTests {
    typealias G = Games

    @Test func randomIsTheSameEverywhere() {
        var a = G.Random(seed: 42), b = G.Random(seed: 42)
        #expect((0..<20).map { _ in a.next() } == (0..<20).map { _ in b.next() })
        // SplitMix64's first value for seed 0, so a change of algorithm (and of every Daily Word) can't slip by.
        var zero = G.Random(seed: 0)
        #expect(zero.next() == 0xE220_A839_7B1D_CDAF)
        var r = G.Random(seed: 7)
        #expect(r.shuffled(Array(0..<10)).sorted() == Array(0..<10))
        #expect((0..<1000).allSatisfy { _ in (3...5).contains(r.between(3, 5)) })
        #expect(G.stableHash("mochi") == G.stableHash("mochi") && G.stableHash("mochi") != G.stableHash("ember"))
        #expect(G.Language(code: "pt") == .pt && G.Language(code: "zh-CN") == .zh && G.Language(code: "en-GB") == .en)
        #expect(G.Language(code: "sv") == .en && G.Language.pt.rawValue == "pt-BR" && G.Language.zh.key == "zh")
    }

    // MARK: Tic-tac-toe

    @Test func ticTacToeNumberPadAndRefusals() throws {
        #expect(G.TicTacToe.cell(forKey: 7) == 0 && G.TicTacToe.cell(forKey: 5) == 4 && G.TicTacToe.cell(forKey: 3) == 8)
        var game = G.TicTacToe(level: .fair)
        let events = try game.play(4, by: .you)
        #expect(events.contains(.turn(.companion)) && events.contains { if case .think = $0 { true } else { false } })
        #expect(throws: G.Refusal("not_your_turn")) { _ = try game.play(0, by: .you) }
        #expect(throws: G.Refusal("taken")) { _ = try game.play(4, by: .companion) }
    }

    @Test func ticTacToeNoticesAForkAndAWin() throws {
        var game = G.TicTacToe(level: .fair)
        _ = try game.play(0, by: .you)
        _ = try game.play(1, by: .companion)
        #expect(try game.play(3, by: .you).contains(.threat(.you)))
        _ = try game.play(6, by: .companion)
        #expect(try game.play(4, by: .you).contains(.fork(.you)))
        _ = try game.play(8, by: .companion)
        let won = try game.play(5, by: .you)
        #expect(won.contains(.roundOver(winner: .you)) && game.winningLine == [3, 4, 5] && game.series.you == 1)
        #expect(try game.nextGame().first == .turn(.companion), "who starts alternates")
    }

    @Test func hardTicTacToeNeverLoses() throws {
        for seed in 0..<40 {
            var rng = G.Random(seed: UInt64(seed))
            var game = G.TicTacToe(level: .hard, first: seed.isMultiple(of: 2) ? .you : .companion)
            while !game.gameOver {
                let cell = game.turn == .you ? rng.pick(game.legalMoves) : game.companionMove(using: &rng)
                _ = try game.play(cell, by: game.turn)
            }
            #expect(game.series.you == 0, "seed \(seed)")
        }
    }

    @Test func hardTicTacToeAdmitsItAfterThreeDraws() throws {
        var rng = G.Random(seed: 1)
        var game = G.TicTacToe(level: .hard)
        var said = false
        for _ in 0..<3 {
            while !game.gameOver {
                let cell = game.turn == .you ? G.TicTacToe.bestMoves(game.cells, for: .you)[0] : game.companionMove(using: &rng)
                said = try game.play(cell, by: game.turn).contains(.unbeatable) || said
            }
            if !game.seriesOver, game.drawsInARow < 3 { _ = try game.nextGame() }
        }
        #expect(game.drawsInARow == 3 && said)
    }

    @Test func fairTicTacToeWinsAndBlocks() throws {
        var rng = G.Random(seed: 3)
        var game = G.TicTacToe(level: .fair)
        _ = try game.play(0, by: .you)
        _ = try game.play(4, by: .companion)
        _ = try game.play(1, by: .you)
        #expect(game.companionMove(using: &rng) == 2, "blocks the top row")
        _ = try game.play(2, by: .companion)
        _ = try game.play(8, by: .you)
        #expect(game.companionMove(using: &rng) == 6, "takes its own win")
        var hinted = G.TicTacToe(level: .easy)
        _ = try hinted.play(0, by: .you)
        _ = try hinted.play(4, by: .companion)
        #expect(try hinted.hint().events == [.hint])
        #expect(throws: G.Refusal("hint_used")) { _ = try hinted.hint() }
    }

    // MARK: Copy Me

    @Test func copyMeGrowsAndEndsOnAMistake() throws {
        var rng = G.Random(seed: 9)
        var game = G.CopyMe(level: .fair, best: 0, using: &rng)
        #expect(game.sequence.count == 1 && game.pads.count == 4)
        let firstTempo = game.stepMs
        _ = try game.watched()
        let grew = try game.press(game.sequence[0])
        #expect(grew == [.point(.you), .grew(2), .turn(.companion)] && game.stepMs < firstTempo)
        #expect(throws: G.Refusal("not_now")) { _ = try game.press(.wave) }
        _ = try game.watched()
        _ = try game.press(game.sequence[0])
        let wrong = G.CopyMe.Pad.allCases.first { $0 != game.sequence[1] }!
        #expect(try game.press(wrong) == [.mistake, .matchOver(winner: nil), .newBest(1)] && game.copied == 1)
        var again = G.Random(seed: 9)
        #expect(G.CopyMe(level: .fair, best: 0, using: &again).sequence == Array(game.sequence.prefix(1)), "same seed, same dance")
        var hard = G.Random(seed: 2)
        let h = G.CopyMe(level: .hard, using: &hard)
        #expect(h.sequence.count == 3 && h.pads.count == 5)
    }

    // MARK: Quick Paws

    @Test func quickPawsJudgesPresses() throws {
        var rng = G.Random(seed: 4)
        var game = G.QuickPaws(level: .fair, best: 250)
        let round = try game.start(using: &rng)
        #expect((1500...5000).contains(round.waitMs) && abs(round.companionMs - 320) <= 60)
        #expect(try game.press(ms: 200) == [.newBest(200), .point(.you)] && game.lastYouMs == 200)
        _ = try game.start(using: &rng)
        #expect(try game.early() == [.tooSoon, .point(.companion)] && game.lastYouMs == nil)
        _ = try game.start(using: &rng)
        #expect(try game.press(ms: 2000) == [.tooSlow, .point(.companion)])
        let r = try game.start(using: &rng)
        #expect(try game.press(ms: r.companionMs) == [.point(.you)], "a tie goes to you")
        _ = try game.start(using: &rng)
        #expect(try game.press(ms: 100) == [.newBest(100), .point(.you), .matchOver(winner: .you)])
        #expect(throws: G.Refusal("over")) { _ = try game.start(using: &rng) }
        for level in G.Level.allCases {
            var r2 = G.Random(seed: 11)
            var g = G.QuickPaws(level: level)
            let typical = g.companionTypicalMs
            #expect(abs(try g.start(using: &r2).companionMs - typical) <= 60)
        }
    }

    // MARK: Which Cup?

    @Test func whichCupFollowsTheSwaps() throws {
        for seed in 0..<20 {
            var rng = G.Random(seed: UInt64(seed))
            var game = G.WhichCup(level: .hard)
            let shuffle = try game.start(using: &rng)
            var at = shuffle.hide
            for swap in shuffle.swaps {
                #expect(swap[0] != swap[1] && swap.allSatisfy { (0..<5).contains($0) })
                if at == swap[0] { at = swap[1] } else if at == swap[1] { at = swap[0] }
            }
            let picked = try game.pick(at)
            #expect(picked.gemAt == at && picked.events.contains(.point(.you)), "without Sneaky the gem is where the swaps say")
        }
        var rng = G.Random(seed: 5)
        var game = G.WhichCup(level: .easy)
        var lastMs = Int.max
        for _ in 0..<G.WhichCup.rounds {
            let s = try game.start(using: &rng)
            #expect(s.cups == 3 && s.swapMs <= lastMs)
            lastMs = s.swapMs
            _ = try game.pick(0)
        }
        #expect(game.over && game.score.you + game.score.companion == 5)
    }

    @Test func sneakyCompanionCanBeCaught() throws {
        var caught = 0, innocent = 0, confessed = 0
        for seed in 0..<60 {
            var rng = G.Random(seed: UInt64(seed))
            var game = G.WhichCup(level: .fair, sneaky: true)
            _ = try game.start(using: &rng)
            if seed.isMultiple(of: 2) {
                let events = try game.accuse()
                if events.contains(.caught) { caught += 1; #expect(game.score.you == 2) }
                if events == [.innocent] { innocent += 1; _ = try game.pick(0) }
            } else if try game.pick(0).events.contains(.confess) {
                confessed += 1
            }
        }
        #expect(caught > 0 && innocent > 0 && confessed > 0)
    }

    // MARK: Higher or Lower

    @Test func higherOrLowerBothWays() throws {
        var rng = G.Random(seed: 8)
        var mine = G.HigherLower.GuessMine(using: &rng)
        #expect(throws: G.Refusal("out_of_range")) { _ = try mine.guess(0) }
        var low = 1, high = 100, events: [G.Event] = []
        while !mine.found {
            let guess = (low + high) / 2
            events = try mine.guess(guess)
            if events == [.higher] { low = guess + 1 } else if events == [.lower] { high = guess - 1 }
            #expect(mine.low == low && mine.high == high)
        }
        #expect(mine.guesses.count <= 7 && events.contains(.roundOver(winner: .you)) && mine.shown != nil && mine.warmth == 1)
        for secret in G.HigherLower.range {
            var yours = G.HigherLower.GuessYours()
            while !yours.found {
                let answer: G.HigherLower.GuessYours.Answer = yours.guess == secret ? .yes : (secret > yours.guess ? .higher : .lower)
                _ = try yours.answer(answer)
            }
            #expect(yours.asked <= 7, "\(secret)")
        }
        var fibbed = G.HigherLower.GuessYours()
        _ = try fibbed.answer(.lower)      // below 50
        _ = try fibbed.answer(.higher)     // above 25
        while fibbed.high > fibbed.low { _ = try fibbed.answer(.higher) }
        #expect(try fibbed.answer(.higher) == [.contradiction] && fibbed.contradicts == 50)
    }

    // MARK: Last Stick

    @Test func hardLastStickWinsWhenYouStart() throws {
        for seed in 0..<30 {
            var rng = G.Random(seed: UInt64(seed))
            var game = G.LastStick(level: .hard)
            while !game.over {
                let n = game.turn == .you ? rng.pick(game.legalTakes) : game.companionTake(using: &rng)
                _ = try game.take(n, by: game.turn)
            }
            #expect(game.winner == .companion, "21 is a losing start")
        }
    }

    @Test func theTrickBeatsHardWhenItStarts() throws {
        var rng = G.Random(seed: 2)
        var game = G.LastStick(level: .hard, first: .companion, losses: 2)
        while !game.over {
            let n = game.turn == .you ? G.LastStick.winningTake(game.left)! : game.companionTake(using: &rng)
            _ = try game.take(n, by: game.turn)
        }
        #expect(game.winner == .you)
        var losing = G.LastStick(level: .easy, sticks: 1, losses: 2)
        #expect(try losing.take(1, by: .you) == [.roundOver(winner: .companion), .offerSecret] && losing.secretOffered)
        #expect(throws: G.Refusal("bad_take")) { var g = G.LastStick(level: .easy); _ = try g.take(4, by: .you) }
        let lesson = G.LastStick(level: .easy, sticks: 20).lesson
        #expect(lesson.takeNow == [17, 18, 19] && lesson.groups.count == 4 && lesson.groups.allSatisfy { $0.count == 4 })
    }

    // MARK: Memory Pairs

    @Test func memoryPairsPlaysToTheEnd() throws {
        for level in G.Level.allCases {
            var rng = G.Random(seed: 6)
            var game = G.MemoryPairs(level: level, using: &rng)
            #expect(game.cards.count == 16 && Set(game.cards).count == 8)
            var recalled = false
            var person = G.Random(seed: 99)
            while !game.over {
                if game.waitingToCover { _ = try game.cover(); continue }
                let cell: Int
                if game.turn == .companion {
                    let pick = game.companionFlip(using: &rng)
                    recalled = recalled || pick.recalled
                    cell = pick.cell
                } else {
                    cell = person.pick(game.cards.indices.filter { game.owner[$0] == nil && !game.faceUp.contains($0) })
                }
                _ = try game.flip(cell, by: game.turn)
            }
            #expect(game.score.you + game.score.companion == 8)
            if level == .hard { #expect(recalled) }
        }
    }

    @Test func memoryPairsKeepsTheTurnOnAPair() throws {
        var rng = G.Random(seed: 1)
        var game = G.MemoryPairs(level: .fair, using: &rng)
        let a = 0, b = game.cards.indices.first { $0 != 0 && game.cards[$0] == game.cards[0] }!
        _ = try game.flip(a, by: .you)
        #expect(try game.flip(b, by: .you) == [.pair(.you), .turn(.you)] && game.score.you == 1)
        let c = game.cards.indices.first { game.owner[$0] == nil }!
        let d = game.cards.indices.first { game.owner[$0] == nil && game.cards[$0] != game.cards[c] }!
        _ = try game.flip(c, by: .you)
        #expect(try game.flip(d, by: .you) == [.noPair(.you)])
        #expect(throws: G.Refusal("not_now")) { _ = try game.flip(c, by: .you) }
        #expect(try game.cover() == [.turn(.companion), .think(ms: 900)])
    }

    // MARK: Words

    @Test func wordScriptSplitsEachLanguage() {
        let fr = G.WordScript.units("Éléphant", .fr, for: .balloon)
        #expect(fr.map(\.key).joined() == "elephant" && fr[0].shown == "É")
        #expect(G.WordScript.units("niño", .es, for: .daily).map(\.key) == ["n", "i", "ñ", "o"])
        #expect(G.WordScript.units("Bär", .de, for: .daily).map(\.key) == ["b", "ä", "r"])
        #expect(G.WordScript.units("がっこう", .ja, for: .balloon).map(\.key) == ["か", "つ", "こ", "う"])
        #expect(G.WordScript.units("ガッコウ", .ja, for: .daily).map(\.key) == ["が", "っ", "こ", "う"])
        let ko = G.WordScript.units("사과", .ko, for: .daily)
        #expect(ko.map(\.key) == ["ㅅ", "ㅏ", "ㄱ", "ㅗ", "ㅏ"] && ko.map(\.group) == [0, 0, 1, 1, 1])
        #expect(G.WordScript.units("닭", .ko, for: .daily).map(\.key) == ["ㄷ", "ㅏ", "ㄹ", "ㄱ"])
        let zh = G.WordScript.units("lü se", .zh, for: .balloon)
        #expect(zh.map(\.key) == ["l", "u", "s", "e"] && zh.map(\.group) == [0, 0, 1, 1])
        #expect(G.WordScript.units("一心一意", .zh, for: .daily).count == 4)
        #expect(G.WordScript.units("أَرْنَب", .ar, for: .balloon).map(\.key) == ["ا", "ر", "ن", "ب"])
        #expect(G.WordScript.key(typed: "É", .fr, for: .balloon) == "e" && G.WordScript.key(typed: "7", .en, for: .balloon) == nil)
        #expect(G.WordScript.key(typed: "ぱ", .ja, for: .balloon) == "は" && G.WordScript.key(typed: "إ", .ar, for: .daily) == "ا")
        #expect(G.WordScript.alphabet(.zh, for: .daily).isEmpty && G.WordScript.alphabet(.ja, for: .balloon).count == 46)
        #expect(G.WordScript.units("arc-en-ciel", .fr, for: .balloon)[3].key == "" && G.WordScript.units("ケーキ", .ja, for: .balloon)[1].key == "")
    }

    @Test func balloonWordsPopsAndWins() throws {
        var game = G.BalloonWords(language: .en, entry: .init(word: "banana", spelling: "banana", category: "food"))
        #expect(game.slots == Array(repeating: nil, count: 6))
        #expect(try game.guess("a") == [.hit(3)])
        #expect(try game.guess("z") == [.miss(left: 6)])
        #expect(throws: G.Refusal("already_guessed")) { _ = try game.guess("A") }
        #expect(throws: G.Refusal("not_letters")) { _ = try game.guess("1") }
        let hint = try game.hint()
        #expect(hint.key == "n" && hint.events == [.hint, .hit(2)])
        #expect(try game.guess("b") == [.hit(1), .reveal, .roundOver(winner: .you)] && game.slots.compactMap { $0 }.joined() == "banana")
        var lost = G.BalloonWords(language: .ko, entry: .init(word: "사과", spelling: "사과", category: "food"))
        #expect(try lost.guess("ㅏ") == [.hit(2)])
        for k in ["ㄴ", "ㄷ", "ㄹ", "ㅁ", "ㅂ", "ㅈ"] { _ = try lost.guess(k) }
        #expect(try lost.guess("ㅊ") == [.miss(left: 0), .reveal, .roundOver(winner: .companion)] && lost.slots.allSatisfy { $0 != nil })
        var rng = G.Random(seed: 3)
        for language in G.Language.allCases {
            let easy = G.BalloonWords(language: language, level: .easy, using: &rng)
            let hard = G.BalloonWords(language: language, level: .hard, using: &rng)
            #expect(easy.units.count <= hard.units.count, "\(language)")
            #expect(!easy.keys.isEmpty)
        }
    }

    @Test func dailyWordMarksLikeWordle() throws {
        #expect(G.DailyWord.marks(["a", "l", "l", "e", "e"], ["a", "p", "p", "l", "e"]) == [.right, .elsewhere, .absent, .absent, .right])
        #expect(G.DailyWord.marks(["e", "e", "e", "e", "e"], ["a", "p", "p", "l", "e"]) == [.absent, .absent, .absent, .absent, .right])
        #expect(G.DailyWord.day(year: 2026, month: 1, day: 1) == 0 && G.DailyWord.day(year: 2026, month: 10, day: 31) == 303)
        #expect(G.DailyWord.day(year: 2025, month: 12, day: 31) == -1 && G.DailyWord.day(year: 2028, month: 3, day: 1) == 790)
        for language in G.Language.allCases {
            let order = G.WordBank.dailyOrder(language)
            #expect(G.DailyWord.answer(day: 303, language: language) == G.DailyWord.answer(day: 303, language: language))
            #expect(Set((0..<order.count).map { G.DailyWord.answer(day: $0, language: language) }).count == order.count, "no repeat before the list ends")
            let game = G.DailyWord(language: language, day: 303)
            #expect(game.length == G.WordBank.dailyLength(language) && game.shown == nil)
        }
    }

    @Test func dailyWordPlaysADay() throws {
        let day = 10
        let answer = G.DailyWord.answer(day: day, language: .en)
        var game = G.DailyWord(language: .en, day: day)
        #expect(throws: G.Refusal("wrong_length")) { _ = try game.guess("cat") }
        #expect(throws: G.Refusal("not_letters")) { _ = try game.guess("ca7ts") }
        #expect(throws: G.Refusal("not_a_word")) { _ = try game.guess("zzzzz", isWord: { _ in false }) }
        let wrong = answer == "zzzzz" ? "yyyyy" : "zzzzz"
        _ = try game.guess(wrong)
        #expect(throws: G.Refusal("already_guessed")) { _ = try game.guess(wrong) }
        let firstUnfound = game.rows[0].marks.firstIndex { $0 != .right }!
        let hint = try game.hint()
        #expect(hint.place == firstUnfound && hint.shown == String(Array(answer)[firstUnfound]))
        #expect(try game.guess(answer.uppercased()) == [.reveal, .found(guesses: 2), .roundOver(winner: .you)] && game.shown == answer)
        var record = G.DailyWord.Record()
        record.finish(game)
        record.finish(game)
        #expect(record.played == 1 && record.streak == 1)
        #expect(record.tile(today: day) == .init(state: .solved(guesses: 2), streak: 1))
        #expect(record.tile(today: day + 1).state == .notPlayed)
        var next = G.DailyWord(language: .en, day: day + 1)
        for _ in 0..<6 { _ = try? next.guess(["aaaaa", "bbbbb", "ccccc", "ddddd", "fffff", "ggggg"][next.rows.count]) }
        if !next.solved {
            record.finish(next)
            #expect(record.streak == 0 && record.tile(today: day + 1).state == .missed)
        }
        let tile = G.DailyWord.Tile(state: .solved(guesses: 4), streak: 12)
        #expect(tile.lines(.en) == ["Solved in 4", "Streak 12"] && tile.lines(.fr) == ["Trouvé en 4", "Série de 12"])
        var ko = G.DailyWord(language: .ko, day: 0)
        let koAnswer = G.DailyWord.answer(day: 0, language: .ko)
        #expect(try ko.guess(koAnswer).contains(.found(guesses: 1)))
        var zh = G.DailyWord(language: .zh, day: 0)
        #expect(try zh.guess("一二三四").first == .reveal, "any four characters are a guess")
    }

    // MARK: Guess My Animal

    @Test func guessMyAnimalWalksAndLearns() throws {
        var memory = G.GuessAnimal.Memory()
        var game = G.GuessAnimal(language: .en, memory: memory)
        #expect(game.question != nil)
        while game.phase == .asking { _ = try game.answer(.no) }
        let guessed = game.guess!.name
        #expect(try game.verdict(right: false) == [.roundOver(winner: .you)] && game.phase == .teaching)
        #expect(throws: G.Refusal("same_animal")) { _ = try game.teach(animal: guessed, question: "Is it pink?", answerForNew: true, memory: &memory) }
        #expect(try game.teach(animal: "axolotl", question: "Does it keep its gills all its life?", answerForNew: true, memory: &memory) == [.learned])
        let saved = try JSONDecoder().decode(G.GuessAnimal.Memory.self, from: JSONEncoder().encode(memory))
        var again = G.GuessAnimal(language: .en, memory: saved)
        while again.phase == .asking {
            _ = try again.answer(again.question == "Does it keep its gills all its life?" ? .yes : .no)
        }
        #expect(again.guess?.name == "axolotl")
        #expect(G.GuessAnimal(language: .fr, memory: saved).question != nil, "French has its own tree, without the English lesson")
    }

    @Test func guessMyAnimalGoesBackAfterNotSure() throws {
        var game = G.GuessAnimal(language: .en)
        _ = try game.answer(.unsure)
        while game.phase == .asking { _ = try game.answer(.yes) }
        #expect(game.pending.count == 1)
        let events = try game.verdict(right: false)
        #expect(events.first == .think(ms: 900) && game.path == [false] && game.phase == .asking && game.pending.isEmpty)
    }

    @Test func guessMyAnimalForgetsTheOldestWhenFull() {
        var memory = G.GuessAnimal.Memory()
        let leaf = G.AnimalBank.ids.sorted()[0]
        var forgot = false
        for i in 0...G.GuessAnimal.Memory.capacity {
            forgot = memory.learn(.en, at: leaf, animal: "beast \(i)", question: "Is it number \(i)?", answerForNew: true) || forgot
        }
        #expect(forgot && memory.lessons["en"]!.count == G.GuessAnimal.Memory.capacity)
        #expect(memory.lessons["en"]!.first?.animal == "beast 1")
    }

    // MARK: Trivia

    @Test func quizPlaysARoundAgainstTheCompanion() throws {
        var rng = G.Random(seed: 12)
        var quiz = G.Quiz(language: .fr, category: nil, length: 10, companion: "mochi", using: &rng)
        #expect(quiz.opening.count == 2 && quiz.opening.last == .sealed)
        #expect(quiz.current?.number == 1 && quiz.current?.options.count == 4)
        let lifeline = try quiz.askCompanion()
        #expect(lifeline.faded.count == 2 && !lifeline.faded.contains(quiz.asked.last!.companionPick) || lifeline.sure)
        #expect(throws: G.Refusal("hint_used")) { _ = try quiz.askCompanion() }
        var ids: Set<String> = []
        var events: [G.Event] = []
        while !quiz.over {
            ids.insert(quiz.current!.id)
            let right = quiz.asked.last!.right
            events = try quiz.answer(quiz.asked.last!.faded.contains(right) ? quiz.asked.last!.companionPick : right)
            if !quiz.over { _ = try quiz.next(using: &rng) }
        }
        #expect(ids.count == 10 && events.contains { if case .matchOver = $0 { true } else { false } })
        let summary = quiz.summary
        #expect(summary.results.count == 10 && summary.score.you >= 9 && summary.newBest)
        var record = G.Quiz.Record()
        record.finish(quiz)
        #expect(record.best["10"] == summary.score.you && record.recent.count == 10)
        var next = G.Quiz(language: .en, category: nil, length: 10, companion: "mochi", record: record, using: &rng)
        #expect(!ids.contains(next.current!.id), "recent questions wait")
        _ = try next.answer(nil)
        #expect(next.streak == 0)
    }

    @Test func quizCompanionHasStrengthsAndWeakSpots() throws {
        var rng = G.Random(seed: 5)
        var right = 0, total = 0
        for _ in 0..<20 {
            var quiz = G.Quiz(language: .en, category: nil, length: 10, companion: "ember", using: &rng)
            while !quiz.over {
                total += 1
                if quiz.asked.last!.companionRight { right += 1 }
                _ = try quiz.answer(0)
                if !quiz.over { _ = try quiz.next(using: &rng) }
            }
        }
        let share = Double(right) / Double(total)
        #expect(share > 0.5 && share < 0.9, "\(share)")
        let quiz = G.Quiz(language: .en, category: "space", length: nil, companion: "ember", using: &rng)
        let strengths = G.QuizBank.categories.map { quiz.strength($0) }
        #expect(strengths.allSatisfy { (0.55...0.85).contains($0) } && Set(strengths).count > 3)
        var endless = G.Quiz(language: .ja, category: "space", length: nil, companion: "ember", using: &rng)
        var n = 0
        while !endless.over { n += 1; _ = try endless.answer(1); if !endless.over { _ = try endless.next(using: &rng) } }
        #expect(n == G.QuizBank.all.filter { $0.category == "space" }.count)
    }
}
