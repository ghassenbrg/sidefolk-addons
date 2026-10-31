import Foundation

extension PlaytimeRecords {
    /// A puzzle's record, empty before its first solve.
    static func puzzle(_ id: String) -> Games.PuzzleRecord { load().puzzles?[id] ?? Games.PuzzleRecord() }

    /// Today's board of a puzzle as far as it was played, if one was kept.
    static func puzzleDay<T: Decodable>(_ id: String, as type: T.Type) -> T? {
        load().puzzleDays?[id].flatMap { try? JSONDecoder().decode(T.self, from: $0) }
    }

    /// A day's board for the records, one per puzzle.
    static func encode<T: Encodable>(_ game: T) -> Data { (try? JSONEncoder().encode(game)) ?? Data() }

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
}
