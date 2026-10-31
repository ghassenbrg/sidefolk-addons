import Foundation

extension Games {
    /// What one puzzle keeps between games (the adapter saves it in Playtime's records): the best time per level, the
    /// daily streak and the practice tally. A best time is only earned without hints. Every field reads leniently, so
    /// a record from an older Playtime, or one this version doesn't fully know, still loads.
    struct PuzzleRecord: Codable, Equatable, Sendable {
        /// Seconds, by `Level.rawValue`.
        var best: [String: Int] = [:]
        /// Practice boards solved, by `Level.rawValue`.
        var practice: [String: Int] = [:]
        /// The last daily board solved, and in how many seconds.
        var lastSolvedDay: Int?
        var lastSeconds: Int?
        /// Daily boards solved on days in a row, and the most ever.
        var streak = 0
        var bestStreak = 0
        var dailies = 0

        init() {}

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            best = (try? c.decodeIfPresent([String: Int].self, forKey: .best)) ?? [:]
            practice = (try? c.decodeIfPresent([String: Int].self, forKey: .practice)) ?? [:]
            lastSolvedDay = try? c.decodeIfPresent(Int.self, forKey: .lastSolvedDay)
            lastSeconds = try? c.decodeIfPresent(Int.self, forKey: .lastSeconds)
            streak = (try? c.decodeIfPresent(Int.self, forKey: .streak)) ?? 0
            bestStreak = (try? c.decodeIfPresent(Int.self, forKey: .bestStreak)) ?? 0
            dailies = (try? c.decodeIfPresent(Int.self, forKey: .dailies)) ?? 0
        }

        /// A board solved: the daily's streak once a day (`day` is the board's day, nil for practice), the practice
        /// tally, and the level's best time when no hint was taken.
        /// - Returns: whether the time beat an earlier best (a first time is a best, not a record broken).
        @discardableResult
        mutating func finish(level: Level, day: Int?, seconds: Int, hints: Int) -> Bool {
            if let day {
                guard lastSolvedDay.map({ $0 < day }) ?? true else { return false }
                streak = lastSolvedDay == day - 1 ? streak + 1 : 1
                bestStreak = max(bestStreak, streak)
                dailies += 1
                lastSolvedDay = day
                lastSeconds = seconds
            } else {
                practice[level.rawValue, default: 0] += 1
            }
            guard hints == 0 else { return false }
            let old = best[level.rawValue]
            if old.map({ seconds < $0 }) ?? true { best[level.rawValue] = seconds }
            return old.map { seconds < $0 } ?? false
        }

        /// The Today tile for `today`: whether the day's board is solved (and its time), and the streak while it is
        /// alive (solved yesterday or today).
        func tile(today: Int) -> Tile {
            let alive = lastSolvedDay.map { $0 >= today - 1 } ?? false
            let solvedToday = lastSolvedDay == today
            return Tile(solved: solvedToday, seconds: solvedToday ? lastSeconds : nil, streak: alive ? streak : 0)
        }

        struct Tile: Codable, Equatable, Sendable {
            let solved: Bool
            let seconds: Int?
            let streak: Int
        }
    }
}
