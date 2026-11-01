import Foundation

extension PlaytimeRecords {
    /// A puzzle's record, empty before its first solve.
    static func puzzle(_ id: String) -> Games.PuzzleRecord { load().puzzles?[id] ?? Games.PuzzleRecord() }

    /// Today's board of a puzzle at a level as far as it was played, if one was kept.
    static func puzzleDay<T: Decodable>(_ id: String, level: GameLevel, as type: T.Type) -> T? {
        let days = load().puzzleDays
        // Before a daily board per level, the one board (Fair) was kept under the puzzle's id alone.
        return (days?[dayKey(id, level)] ?? (level == .fair ? days?[id] : nil)).flatMap { try? JSONDecoder().decode(T.self, from: $0) }
    }

    /// Keeps a day's board as far as played, one per puzzle and level.
    static func keepPuzzleDay<T: Encodable>(_ id: String, level: GameLevel, _ game: T) {
        guard let data = try? JSONEncoder().encode(game) else { return }
        update { r in
            var days = r.puzzleDays ?? [:]
            if level == .fair { days[id] = nil }
            days[dayKey(id, level)] = data
            r.puzzleDays = days
        }
    }

    private static func dayKey(_ id: String, _ level: GameLevel) -> String { "\(id).\(level.rawValue)" }

    /// A puzzle solved (`PuzzleRecord.finish`), saved in the records file.
    /// - Returns: whether the time beat an earlier best.
    @discardableResult
    static func finishPuzzle(_ id: String, level: GameLevel, day: Int?, seconds: Int, hints: Int) -> Bool {
        var beaten = false
        update { r in
            var record = r.puzzles?[id] ?? Games.PuzzleRecord()
            beaten = record.finish(level: level, day: day, seconds: seconds, hints: hints)
            r.puzzles = (r.puzzles ?? [:]).merging([id: record]) { $1 }
        }
        return beaten
    }

    /// The level the person picked, for the puzzle's next board.
    static func pickPuzzleLevel(_ id: String, _ level: GameLevel) {
        update { r in
            var record = r.puzzles?[id] ?? Games.PuzzleRecord()
            record.lastLevel = level.rawValue
            r.puzzles = (r.puzzles ?? [:]).merging([id: record]) { $1 }
        }
    }
}
