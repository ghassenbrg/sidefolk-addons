import Foundation
import SidefolkExtensionKit

/// What the companion drew, in the air above it: clay coins flicked high (TossCoin), clay dice thrown (TossDice), or two toy boxes that clash (the panel's own, BoardDrawing.hands). Fixed before
/// it plays; the objects are the heroes, and the result goes on the felt tag under them (TossToys). The words stay in this frame: the companion says nothing on the desktop (D98). One scene while
/// it flies, asked for again when it has landed, the toys standing in the same place on the screen in both; with Reduce Motion nothing spins and the result shows at once.
@MainActor
enum TossSurface {
    /// When the objects leave the companion's paws (for hands, when the fists start pumping), how long they fly, and how long a coin wobbles or dice slide after.
    @MainActor struct Timing {
        var launch: Double
        var flight: Double
        let settle = 600.0

        init(_ toss: Toss) {
            switch toss {
            case .coins(let flips, _): (launch, flight) = (0, Double(TossCoin.totalMs(flips.count)) - 600)
            case .dice(_, let rolls, _): (launch, flight) = (0, Double(TossDice.totalMs(rolls.count)) - 600)
            // The throw's own timing: thumps, lids, hold and gag, to the end of which the settling is the last part.
            case .hands: (launch, flight) = (0, Double(Suspense.revealMs) - 600)
            }
        }

        var totalMs: Int { Int(launch + flight + settle) }
    }

    /// What is on the overlay now: enough to draw it again and to throw again.
    private static var shown: [String: Toss] = [:]
    /// Calls the person got right in a row, for the streak's sparkles.
    private static var calledRight = 0

    static func install(on ext: Extension) {
        ext.surface("toss", open: { request in
            PlayLanguage.enter(request.language)
            var random = Games.Random.fresh()
            // Opened with nothing said (the AI's own road, `surfaces.open`): a real coin, as a person asking for one would get.
            let toss = Toss(arguments: request.arguments) ?? Toss.coins([random.below(2) == 1])
            let session = UUID().uuidString
            shown[session] = toss
            return SurfaceReply(session: session, scene: PlayLanguage.stamped(flying(toss)))
        }, move: { request in
            PlayLanguage.enter(request.language)
            guard let toss = shown[request.session] else { return Scene(width: 200, height: 120).closing() }
            switch request.move {
            case .next: return PlayLanguage.stamped(landed(toss))
            case .click(area: "again", _, _):
                let next = again(toss)
                shown[request.session] = next
                return PlayLanguage.stamped(flying(next, after: toss))
            default: return PlayLanguage.stamped(landed(toss))
            }
        }, close: { request in
            shown[request.session] = nil
        })
    }

    /// The same coin or dice once more: a fresh draw, and its row in History, as a tool call has.
    private static func again(_ toss: Toss) -> Toss {
        var random = Games.Random.fresh()
        switch toss {
        case .coins(let flips, _):
            Activity.add(flips.count == 1 ? L("Flip a coin") : L("Flip {n} coins", ["n": flips.count]), key: "toss")
            return .coins(flips.map { _ in random.below(2) == 1 })
        case .dice(let sides, let rolls, let modifier):
            Activity.add(title(toss), key: "toss")
            return .dice(sides: sides, rolls: rolls.map { _ in random.between(1, sides) }, modifier: modifier)
        case .hands: return toss
        }
    }

    static func title(_ toss: Toss) -> String {
        switch toss {
        case .coins(let flips, _): flips.count > 1 ? L("Flip {n} coins", ["n": flips.count]) : L("Flip a coin")
        case .dice(let sides, let rolls, let modifier):
            rolls.count == 1 && sides == 6 && modifier == 0 ? L("Roll a die") : L("Roll {dice}", ["dice": Toss.notation(count: rolls.count, sides: sides, modifier: modifier)])
        case .hands: L("Rock, paper, scissors")
        }
    }

    // MARK: Flying and landed

    /// `previous`: what it lands on now is thrown again from where that lies.
    static func flying(_ toss: Toss, after previous: Toss? = nil) -> Scene {
        switch toss {
        case .coins(let flips, _):
            var before: [Bool]?
            if case .coins(let last, _)? = previous { before = last }
            return TossCoin.flying(toss, flips: flips, previous: before, words: L("Heads or tails…"))
        case .dice(let sides, let rolls, _):
            var before: [Int]?
            if case .dice(_, let last, _)? = previous { before = last }
            return TossDice.flying(toss, sides: sides, rolls: rolls, previous: before, words: L("Rolling…"))
        case .hands(let person, let companion):
            return TossParts.handsFlying(toss, person: person, companion: companion, time: Timing(toss))
        }
    }

    static func landed(_ toss: Toss) -> Scene {
        let (move, effect, line) = reaction(toss)
        let answer = move != nil || effect != nil ? Reaction(move: move, effect: effect) : nil
        switch toss {
        case .coins(let flips, _): return TossCoin.landed(toss, flips: flips, line: line, reaction: answer)
        case .dice(let sides, let rolls, _): return TossDice.landed(toss, sides: sides, rolls: rolls, line: line, reaction: answer)
        case .hands(let person, let companion): return TossParts.handsLanded(toss, person: person, companion: companion, time: Timing(toss), line: line, reaction: answer)
        }
    }

    /// How the companion takes what came up: a call right or wrong, a natural 20 or a 1, doubles, a hand won or lost.
    private static func reaction(_ toss: Toss) -> (move: String?, effect: String?, line: String?) {
        switch toss {
        case .coins:
            guard let right = toss.called else { return ("nod", nil, nil) }
            calledRight = right ? calledRight + 1 : 0
            if right, calledRight >= 3, calledRight % 3 == 0 { return ("cheer", "sparkles", L("{n} in a row!", ["n": calledRight])) }
            return right ? ("cheer", nil, L("You called it!")) : ("giggle", nil, L("Next one's yours."))
        case .dice(let sides, let rolls, _):
            if sides == 20, rolls == [20] { return ("cheer", "sparkles", L("Natural 20!")) }
            if sides == 20, rolls == [1] { return ("gasp", nil, L("Oof.")) }
            if sides == 6, rolls == [1, 1] { return ("giggle", nil, L("Snake eyes!")) }
            if rolls.count == 2, rolls[0] == rolls[1] { return ("cheer", nil, L("Doubles!")) }
            return ("nod", nil, nil)
        case .hands(let person, let mine):
            // A good sport: a bow when the person wins, a cheer when it does, a nod for a draw.
            return (person == mine ? "nod" : person.beats == mine ? "bow" : "cheer", nil, nil)
        }
    }
}

/// A hand on the overlay: the panel's own clash above the felt tag, in the same place while it plays and when it has landed.
@MainActor
enum TossParts {
    private static let width = 260.0, height = 170.0, pad = 8.0

    private static func hands(_ person: Toss.Hand, _ companion: Toss.Hand, time: TossSurface.Timing, playing: Bool) -> (node: Node, anims: [Anim]) {
        let drawing = BoardDrawing(Board([]), StageContext(entry: GameEntry(id: "", title: "", tagline: "", symbol: "", look: .hands), fresh: false))
        let nodes = drawing.hands(you: person.rawValue, companion: companion.rawValue, width: width, playing: playing, prefix: "toss", beat: .init(width: width, height: height))
        return (.box("toss.hands", w: width, h: height) { nodes }, drawing.anims)
    }

    private static func sceneSize(_ tag: TossToys.Tag) -> (w: Double, h: Double) { (Swift.max(width, tag.w) + 2 * pad, pad + height + 6 + tag.h + pad) }

    static func handsFlying(_ toss: Toss, person: Toss.Hand, companion: Toss.Hand, time: TossSurface.Timing) -> Scene {
        let result = TossToys.Tag(toss, line: nil), tag = TossToys.Tag(waiting: L("Rock… paper… scissors…"), like: result)
        let drawn = hands(person, companion, time: time, playing: true), size = sceneSize(result)
        var anims = drawn.anims
        anims.append(.sequence([.react(Reaction(move: "ready", look: "panel"))]))
        return Scene(width: size.w, height: size.h) {
            drawn.node.at((size.w - width) / 2, pad)
            tag.node.at((size.w - tag.w) / 2, pad + height + 6)
        }
        .animating(anims)
        .after(ms: time.totalMs)
        .afterStill(ms: 200)
    }

    static func handsLanded(_ toss: Toss, person: Toss.Hand, companion: Toss.Hand, time: TossSurface.Timing, line: String?, reaction: Reaction?) -> Scene {
        let tag = TossToys.Tag(toss, line: nil), drawn = hands(person, companion, time: time, playing: false), size = sceneSize(tag)
        var scene = Scene(width: size.w, height: size.h) {
            drawn.node.at((size.w - width) / 2, pad)
            tag.node.at((size.w - tag.w) / 2, pad + height + 6)
        }
        .announcing([toss.result, line].compactMap { $0 }.joined(separator: " "))
        .animating([.keys("toss.tag", [["t": 0, "scale": 0.92], ["t": 1, "scale": 1]], ms: 240, ease: "spring")])
        .closing(afterMs: 5000)
        if let reaction { scene = scene.react(reaction) }
        return scene
    }
}
