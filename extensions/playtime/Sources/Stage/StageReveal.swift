import Foundation
import SidefolkExtensionKit

// A result drawn as it happens (RevealView), fixed before it plays. It plays during the build-up; the verdict's board shows where it landed and never plays it twice. The toys are in StageToys.
// With Reduce Motion a step isn't played and its end shows at once. Only the hands are played on a board; coins and dice are the desktop's (Sources/Toss).
extension BoardDrawing {
    /// Where the overlay and any plain board draw a throw.
    struct RevealBeat {
        var width = BoardDrawing.inner
        var height = 150.0
    }

    func revealCard(_ reveal: Reveal) -> PartBlock {
        let width = Self.inner, height = 150.0
        return PartBlock(.box("reveal", w: width, h: height) {
            if case .hands(let you, let companion) = reveal {
                hands(you: you, companion: companion, width: width, playing: ctx.buildUp, prefix: "reveal", beat: RevealBeat(width: width, height: height))
            }
        }, height: height)
    }

    /// A throw in a small room: both boxes shut and sealed to begin with, then the same throw as on the arena, with whose box is whose under each. The desktop's overlay is this.
    func hands(you: String, companion: String, width: Double, playing: Bool, prefix: String, beat: RevealBeat) -> [Node] {
        let scale = 0.62, frame = ToyArt.boxFrame * scale, plateH = 20.0
        var stage = ToyStage(width: width, scale: scale, youX: width / 2 - frame * 0.58, themX: width / 2 + frame * 0.58, boxY: beat.height - plateH - 2 - frame * ToyArt.boxFloor)
        stage.sealedYou = true
        stage.sealedThem = true
        stage.plates = (beat.height - plateH, frame * 1.08, plateH, L("You"), "{companion}")
        let layers = toyLayers(you: you, companion: companion, stage: stage, playing: playing, prefix: prefix)
        return layers.behind + layers.toys + layers.front
    }

    func handsVerdict(_ you: String, _ companion: String) -> Verdict {
        if you == companion { return .draw }
        let beats = ["rock": "scissors", "paper": "rock", "scissors": "paper"]
        return beats[you] == companion ? .win : .loss
    }
}
