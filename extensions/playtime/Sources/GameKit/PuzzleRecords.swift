import Foundation

extension PlaytimeRecords {
    /// A puzzle's record, empty before its first solve.
    static func puzzle(_ id: String) -> Games.PuzzleRecord { load().puzzles?[id] ?? Games.PuzzleRecord() }

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
