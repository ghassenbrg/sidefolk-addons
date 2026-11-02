import Foundation
import SidefolkExtensionKit

/// Qibla: the bearing from the chosen place, clockwise from true north. A Mac has no compass, so nothing here says it is pointing anywhere.
@MainActor
enum QiblaPage {
    static func sections(_ ctx: Context) -> [Section] {
        guard let place = ctx.snapshot.place else { return [NoorPage.unavailable(ctx)].compactMap { $0 } }
        guard let bearing = ctx.snapshot.qibla else {
            return [NoorPage.status(ctx, symbol: "safari", title: ctx.model.load == .loading ? L("Finding the bearing…") : L("No bearing for this place yet"), detail: ctx.model.load == .loading ? place.label : L("It needs one connection, then it is saved. {why}", ["why": Words.problem(ctx.model.problem)]),
                                    buttons: ctx.model.load == .loading ? [] : [("retry", L("Try again"), true, .tool("refresh")), ("place", L("Choose another place"), false, .go(Go(set: ["sheet": "prefs", "section": "place"], push: true)))])]
        }
        let w = ctx.width
        let gap = 16.0
        let side = ctx.narrow ? w : min((w - gap) * 0.54, 560)
        let infoW = ctx.narrow ? w : w - side - gap
        let infoX = ctx.narrow ? 0 : side + gap, infoY = ctx.narrow ? side + gap : 0
        let infoH = ctx.narrow ? 400.0 : side
        let total = ctx.narrow ? side + gap + infoH : side
        let scene = Scene(width: w, height: total) {
            Node.group {
                Node.patternPanel(side, side)
                Node.arch(side - 40, side - 26, lift: 54).at(20, 26)
                Node.inlay(side, side)
                CompassScene.dial(bearing.degrees, side: side - 80, letters: 22).at(40, 60).leftToRight()
                    .label(L("{degrees} degrees clockwise from true north, from {place}.", ["degrees": "\(bearing.rounded)", "place": place.label]))
            }
            .size(side, side)
            info(ctx, bearing, place, w: infoW, h: infoH).at(infoX, infoY)
        }
        var out: [Section] = []
        if let note = NoorPage.offlineNote(ctx) { out.append(Section(nil, [note], wide: true)) }
        out.append(Section(nil, [.scene(PageSceneBlock(scene, acts: ["place": .go(Go(set: ["sheet": "prefs", "section": "place"], push: true))]))], wide: true))
        out.append(Section(nil, [
            .action(Action(L("Copy bearing"), act: .copy(L("Qibla from {place}: {degrees}° clockwise from true north", ["place": place.label, "degrees": "\(bearing.rounded)"])), symbol: "doc.on.doc")),
            .action(Action(L("Check again"), tool: "refresh", symbol: "arrow.clockwise")),
        ], wide: true))
        return out
    }

    private static func info(_ ctx: Context, _ bearing: QiblaBearing, _ place: Place, w: Double, h: Double) -> Node {
        Node.group {
            OverviewPage.card(w, h)
            Node.say(L("Qibla"), 20, 16, w - 40, 34, size: 26, weight: "bold")
            Node.say(L("Direction from your place"), 20, 50, w - 40, 22, size: 14, color: Noor.muted)
            Node.rect(fill: Noor.hairline).size(w - 40, 1).at(20, 80)
            Node.say("\(bearing.rounded)°", 20, 92, w * 0.46, 70, size: 58, weight: "semibold", color: Noor.warm, tabular: true)
            Node.say(L("From true north"), 20, 160, w * 0.46, 24, size: 15, color: Noor.warm)
            Node.say(L("North-up direction"), w * 0.5, 96, w * 0.5 - 18, 22, size: 14, weight: "semibold")
            Node.say(L("A bearing from your place. This Mac can't sense which way you are facing: line up a real compass with true north to use it."), w * 0.5, 118, w * 0.5 - 18, 86, size: 12.5, color: Noor.muted, lines: 5)
            Node.group {
                Node.rect(fill: Noor.quiet, stroke: Noor.hairline, lineWidth: 1, corner: 12).size(w - 32, 108)
                Node.symbol("mappin.circle", color: Noor.accent).size(22, 22).at(14, 14)
                Node.say(place.label + (place.country.map { ", \($0)" } ?? ""), 46, 8, w - 100, 26, size: 15, weight: "medium")
                Node.say(String(format: "%.4f, %.4f", place.latitude, place.longitude), 46, 32, w - 100, 22, size: 13, color: Noor.muted, tabular: true).leftToRight()
                Node.say(L("Source: AlAdhan. Fetched {when}.", ["when": Format.dateTime(bearing.fetched, timeZone: ctx.zone)]), 46, 54, w - 100, 40, size: 12, color: Noor.faint, lines: 2)
            }
            .size(w - 32, 108).at(16, 212)
            Node.pill("place", label: L("Choose another place"), x: 16, y: min(h - 52, 330), w: w - 32, symbol: "mappin.and.ellipse")
        }
        .size(w, h)
    }
}
