import Foundation
import SidefolkExtensionKit

/// A part playing by itself, what Sidefolk's panel used to time (PartsState): the cups' shuffle, the pads' sequence. Its scene says "Shuffling…" or
/// "Watch…" and holds moves while its run plays, then asks for the next (`after`), and the same board is drawn at rest with the game's own words.
struct Playback: Codable, Equatable {
    /// What is playing, so a board of the same round (the companion's paw checked mid-shuffle) carries on rather than starting again.
    var what: String
    var ms: Int
    var startedAt: Double
    var done = false

    var left: Int { ms - Int((Date().timeIntervalSince1970 - startedAt) * 1000) }

    /// A new board shows: what it plays starts now, unless it is what was already playing.
    static func settle(_ board: Board, local: inout LocalParts) {
        guard let plays = board.plays else {
            local.playback = nil
            return
        }
        guard local.playback?.what != plays.what else { return }
        local.playback = Playback(what: plays.what, ms: plays.ms, startedAt: Date().timeIntervalSince1970)
    }

    /// The person came back to the game (Back, or a game put away): its run starts again with the scene, a dance to copy always, a shuffle if it hadn't ended.
    static func cameBack(_ board: Board, local: inout LocalParts) {
        guard var playback = local.playback, board.plays?.what == playback.what, !playback.done || board.hasPads else { return }
        playback.done = false
        playback.startedAt = Date().timeIntervalSince1970
        local.playback = playback
    }

    /// The scene's time is up: at rest now, or (a run longer than one `after`) the same run on to its end.
    static func next(_ move: SurfaceMove, board: Board, local: inout LocalParts) -> StageAction? {
        guard move == .next, var playback = local.playback, !playback.done, board.plays?.what == playback.what else { return nil }
        if playback.left < 60 { playback.done = true }
        local.playback = playback
        return .redraw
    }
}

extension Board {
    /// What this board plays by itself, and for how long: a pause and each step of a dance; the gem shown and lowered, then each swap.
    var plays: (what: String, ms: Int)? {
        play { part -> (String, Int)? in
            switch part {
            case .pads(_, let steps, let ms, let locked) where !steps.isEmpty && !locked:
                ("pads \(steps) \(ms)", 600 + steps.count * ms)
            case .cups(let count, let hide, let swaps, let ms, _, let revealed, _, _) where !swaps.isEmpty && !revealed:
                ("cups \(count) \(hide ?? -1) \(swaps) \(ms)", 1400 + swaps.count * ms)
            default: nil
            }
        }.map { (what: $0.0, ms: $0.1) }
    }
}

extension BoardDrawing {
    /// Its run is playing on this scene: it holds the part's own moves, never a choice of who plays or at what level (`always` on those).
    var playing: Bool {
        guard let playback = ctx.local.playback, !playback.done else { return false }
        return board.plays?.what == playback.what
    }

    /// Asks for the next scene when the run has played, or as far as one `after` reaches.
    func untilPlayed() {
        partAfterMs = min(max((ctx.local.playback?.left ?? 0) + 30, 100), 10_000)
    }
}
