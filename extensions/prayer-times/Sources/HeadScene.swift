import Foundation
import SidefolkExtensionKit

/// Noor's head and its tabs, out to the page's edges as the boards have them: the rosette, its name, where its times come from, the pendant hanging from the top, the way to Preferences, and the five places.
@MainActor
enum HeadScene {
    static func block(_ ctx: Context, subtitle: String, reminders: NoorSnapshot.ReminderStatus, tabs: Bool = true) -> Block {
        let w = ctx.width, r = ctx.ruler
        let bandH = r.u(112), tabsH = tabs ? r.u(62) : r.u(12)
        let spoken: String
        switch reminders {
        case .off: spoken = L("Reminders are off. Open reminder settings.")
        case .on: spoken = L("Reminders are on. Open reminder settings.")
        case .paused: spoken = L("Reminders are paused. Open reminder settings.")
        }
        let compact = w < 620
        let pendantW = compact ? 0 : r.u(430), pendantX = w * 0.486 - pendantW / 2
        let wordsX = r.u(142), wordsW = compact ? w - wordsX - 110 : pendantX - wordsX + r.u(60)
        var acts: [String: PageAct] = [
            "source": .go(Go(set: ["sheet": "prefs", "section": "sources"], push: true)),
            "preferences": .go(Go(set: ["sheet": "prefs", "section": "place"], push: true)),
            "reminders": .go(Go(set: ["sheet": "prefs", "section": "reminders"], push: true)),
        ]
        for tab in NoorTab.allCases { acts["tab-\(tab.rawValue)"] = .go(Go(set: ["tab": tab.rawValue, "sheet": NSNull()])) }
        let scene = Scene(width: w, height: bandH + tabsH) {
            if !compact {
                Node.image("art/pendant-l.png", dark: "art/pendant-d.png", fit: "fill").size(pendantW, r.u(122)).at(pendantX, 0)
            }
            Node.rect(fill: Noor.hairline).size(w, 1).at(0, bandH)
            Node.image("art/rosette-l.png", dark: "art/rosette-d.png").size(r.u(78), r.u(78)).at(r.u(38), r.u(16)).leftToRight()
            Node.say(L("Noor"), wordsX, r.u(14), wordsW, r.u(38), size: r.f(32, min: 20), weight: "semibold")
            Node.say(L("Islamic companion"), wordsX, r.u(50), wordsW, r.u(26), size: r.f(19, min: 12.5))
            Node.group {
                Node.say(subtitle, 0, 0, wordsW - 20, r.u(24), size: r.f(15.5), color: Noor.muted)
                Node.symbol("chevron.down", color: Noor.muted).size(r.f(11, min: 9), r.f(11, min: 9)).at(wordsW - 16, (r.u(24) - r.f(11, min: 9)) / 2)
            }
            .size(wordsW, r.u(24)).at(wordsX, r.u(76))
            .area("source", label: L("Where the times come from: {source}. Open.", ["source": subtitle]), hover: .init(scale: 1.0))
            if compact {
                Node.group { Node.symbol("gearshape", color: Noor.text).size(20, 20).at(8, 8) }.size(36, 36).at(w - 90, r.u(34)).area("preferences", label: L("Preferences"))
            } else {
                Node.group {
                    Node.symbol("gearshape", color: Noor.text).size(r.f(26, min: 17), r.f(26, min: 17)).at(0, (r.u(40) - r.f(26, min: 17)) / 2)
                    Node.say(L("Preferences"), r.f(26, min: 17) + r.u(18), 0, r.u(150), r.u(40), size: r.f(19, min: 13))
                }
                .size(r.u(190), r.u(40)).at(w - r.u(275), r.u(29))
                .area("preferences", label: L("Preferences"), hover: .init(scale: 1.02))
                Node.rect(fill: Noor.hairline).size(1, r.u(34)).at(w - r.u(95), r.u(32))
            }
            Node.group {
                Node.symbol(reminders == .off ? "bell" : "bell.badge", color: Noor.text).size(r.f(26, min: 18), r.f(26, min: 18)).at(6, 6)
            }
            .size(r.f(26, min: 18) + 12, r.f(26, min: 18) + 12).at(w - r.u(32) - r.f(26, min: 18), r.u(31))
            .area("reminders", label: spoken)
            if tabs { Self.tabs(ctx, y: bandH + r.u(10)) }
        }
        return .scene(PageSceneBlock(scene, acts: acts))
    }

    /// The five places. They fit by shrinking, and where they can't, only the chosen one keeps its word.
    private static func tabs(_ ctx: Context, y: Double) -> [Node] {
        let r = ctx.ruler, h = r.u(50), size = r.f(16, min: 12.5), glyph = r.f(24, min: 15)
        let words = NoorTab.allCases.map { Words.tab($0) }
        let room = ctx.width - r.u(60)
        let wanted = words.map { Double($0.count) * size * 0.56 + glyph + r.u(48) }
        let tight = wanted.reduce(0, +) > room
        var out: [Node] = []
        var x = r.u(30)
        for (tab, word) in zip(NoorTab.allCases, words) {
            // Preferences stands over the tabs and is none of them.
            let chosen = tab == ctx.tab && ctx.state.string("sheet") != "prefs"
            let width = tight && !chosen ? glyph + r.u(28) : Double(word.count) * size * 0.56 + glyph + r.u(48)
            let ink = chosen ? Color.hex("#FFFFFF") : Noor.text
            out.append(Node.group {
                if chosen { Node.rect(fill: Noor.picked, stroke: Noor.pickedEdge, lineWidth: 1, corner: r.u(12)).size(width, h) }
                Node.symbol(tab.symbol, color: ink).size(glyph, glyph).at(r.u(16), (h - glyph) / 2)
                if !tight || chosen { Node.say(word, r.u(16) + glyph + r.u(12), 0, width - glyph - r.u(30), h, size: size, weight: chosen ? "semibold" : "regular", color: ink) }
            }
            .size(width, h).at(x, y)
            .area("tab-\(tab.rawValue)", label: chosen ? L("{tab}, selected", ["tab": word]) : word, hover: .init(scale: 1.02)))
            x += width + r.u(8)
        }
        return out
    }
}
