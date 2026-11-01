import Foundation

extension Games {
    /// What one puzzle keeps between games (the adapter saves it in Playtime's records): the best time per level, the
    /// daily boards solved (one per level and day), one daily streak and the practice tally. A best time is only earned
    /// without hints. Every field reads leniently, so a record from an older Playtime, or one this version doesn't
    /// fully know, still loads.
    struct PuzzleRecord: Codable, Equatable, Sendable {
        /// Seconds, by `Level.rawValue`.
        var best: [String: Int] = [:]
        /// Practice boards solved, by `Level.rawValue`.
        var practice: [String: Int] = [:]
        /// The last day a daily board was solved at any level: the streak's day.
        var lastSolvedDay: Int?
        /// The last day each level's daily board was solved, and in how many seconds, by `Level.rawValue`.
        var days: [String: Int] = [:]
        var daySeconds: [String: Int] = [:]
        /// Days in a row with a daily board solved (any level), and the most ever.
        var streak = 0
        var bestStreak = 0
        /// Daily boards solved, every level.
        var dailies = 0
        /// The level the person last picked, for the next board.
        var lastLevel: String?

        init() {}

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            best = (try? c.decodeIfPresent([String: Int].self, forKey: .best)) ?? [:]
            practice = (try? c.decodeIfPresent([String: Int].self, forKey: .practice)) ?? [:]
            lastSolvedDay = try? c.decodeIfPresent(Int.self, forKey: .lastSolvedDay)
            streak = (try? c.decodeIfPresent(Int.self, forKey: .streak)) ?? 0
            bestStreak = (try? c.decodeIfPresent(Int.self, forKey: .bestStreak)) ?? 0
            dailies = (try? c.decodeIfPresent(Int.self, forKey: .dailies)) ?? 0
            lastLevel = try? c.decodeIfPresent(String.self, forKey: .lastLevel)
            if let days = try? c.decodeIfPresent([String: Int].self, forKey: .days) {
                self.days = days
                daySeconds = (try? c.decodeIfPresent([String: Int].self, forKey: .daySeconds)) ?? [:]
            } else if let day = lastSolvedDay {
                // Before a daily board per level there was one, at Fair, its time kept as `lastSeconds`.
                days = [Level.fair.rawValue: day]
                let legacy = try? decoder.container(keyedBy: Legacy.self)
                if let seconds = try? legacy?.decodeIfPresent(Int.self, forKey: .lastSeconds) { daySeconds = [Level.fair.rawValue: seconds] }
            }
        }

        private enum Legacy: String, CodingKey { case lastSeconds }

        /// Whether the daily board of `level` for `day` is solved.
        func solved(_ level: Level, day: Int) -> Bool { days[level.rawValue] == day }

        /// A board solved: a daily one once per level and day (`day` is the board's day, nil for practice), the
        /// streak once a day whatever the level, the practice tally, and the level's best time when no hint was taken.
        /// - Returns: whether the time beat an earlier best (a first time is a best, not a record broken).
        @discardableResult
        mutating func finish(level: Level, day: Int?, seconds: Int, hints: Int) -> Bool {
            if let day {
                guard days[level.rawValue].map({ $0 < day }) ?? true else { return false }
                if lastSolvedDay.map({ $0 < day }) ?? true {
                    streak = lastSolvedDay == day - 1 ? streak + 1 : 1
                    bestStreak = max(bestStreak, streak)
                    lastSolvedDay = day
                }
                dailies += 1
                days[level.rawValue] = day
                daySeconds[level.rawValue] = seconds
            } else {
                practice[level.rawValue, default: 0] += 1
            }
            guard hints == 0 else { return false }
            let old = best[level.rawValue]
            if old.map({ seconds < $0 }) ?? true { best[level.rawValue] = seconds }
            return old.map { seconds < $0 } ?? false
        }

        /// The Today tile for `today`: each level's daily board solved today with its time, and the streak while it is
        /// alive (a daily board solved yesterday or today).
        func tile(today: Int) -> Tile {
            let alive = lastSolvedDay.map { $0 >= today - 1 } ?? false
            let solved = Level.allCases.filter { solved($0, day: today) }.map { Tile.Solve(level: $0, seconds: daySeconds[$0.rawValue] ?? 0) }
            return Tile(solved: solved, streak: alive ? streak : 0)
        }

        struct Tile: Equatable, Sendable {
            struct Solve: Equatable, Sendable {
                let level: Level
                let seconds: Int
            }

            /// Today's daily boards solved, easiest first.
            let solved: [Solve]
            let streak: Int

            /// Today's daily boards not solved yet.
            var left: Int { Level.allCases.count - solved.count }
        }
    }
}
