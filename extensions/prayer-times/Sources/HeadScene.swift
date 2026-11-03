import Foundation
import SidefolkExtensionKit

/// Noor's head and its tabs, out to the page's edges as the boards have them: the rosette, its name, where its times come from, the pendant hanging from the top, the way to Preferences, and the five places.
@MainActor
enum HeadScene {
    static func block(_ ctx: Context, subtitle: String, reminders: NoorSnapshot.ReminderStatus, tabs: Bool = true) -> Block {
        let w = ctx.width, r = ctx.ruler
        let tabsH = tabs ? r.u(62) : r.u(12)
        let spoken: String
        switch reminders {
        case .off: spoken = L("Reminders are off. Open reminder settings.")
        case .on: spoken = L("Reminders are on. Open reminder settings.")
        case .paused: spoken = L("Reminders are paused. Open reminder settings.")
        }
        let compact = ctx.narrow
        let pendantW = compact ? 0 : r.u(430), pendantX = w * 0.486 - pendantW / 2
        let wordsX = r.u(142), wordsW = compact ? w - wordsX - 110 : pendantX - wordsX + r.u(60)
        // Where the times come from runs on under the pendant's shoulder, or under the two buttons, which stand higher. Longer than that it takes a second line and the band grows: a source's name is never cut.
        let lineRoom = compact ? w - wordsX - 16 : pendantX + pendantW * 0.27 - wordsX
        let lineSize = r.f(15.5), mark = r.f(11, min: 9), oneLine = max(r.u(24), lineSize * 1.35)
        let lineLong = wordsWide(subtitle, size: lineSize)
        let wraps = lineLong + mark + 8 > lineRoom
        let lineH = wraps ? oneLine * 2 : oneLine
        let bandH = r.u(112) + (wraps ? oneLine : 0)
        var acts: [String: PageAct] = [
            "source": .go(Go(set: ["sheet": "prefs", "section": "sources"], push: true)),
            "preferences": .go(Go(set: ["sheet": "prefs", "section": "place"], push: true)),
            "reminders": .go(Go(set: ["sheet": "prefs", "section": "reminders"], push: true)),
        ]
        for tab in NoorTab.allCases { acts["tab-\(tab.rawValue)"] = .go(Go(set: ["tab": tab.rawValue, "sheet": NSNull(), "setup": NSNull()])) }
        let scene = Scene(width: w, height: bandH + tabsH) {
            if !compact {
                Node.image("art/pendant-l.png", dark: "art/pendant-d.png", fit: "fill").size(pendantW, r.u(122)).at(pendantX, 0)
            }
            Node.rect(fill: Noor.hairline).size(w, 1).at(0, bandH)
            Node.image("art/rosette-l.png", dark: "art/rosette-d.png").size(r.u(78), r.u(78)).at(r.u(38), r.u(16)).leftToRight()
            Node.say(L("Noor"), wordsX, r.u(14), wordsW, r.u(38), size: r.f(32, min: 20), weight: "semibold")
            Node.say(L("Islamic companion"), wordsX, r.u(50), wordsW, r.u(26), size: r.f(19, min: 12.5))
            Node.group {
                Node.say(subtitle, 0, 0, lineRoom - mark - 8, lineH, size: lineSize, color: Noor.muted, lines: wraps ? 2 : 1)
                // Just after the words, as the board has it.
                Node.symbol("chevron.down", color: Noor.muted).size(mark, mark).at(wraps ? lineRoom - mark : min(lineLong + 7, lineRoom - mark), (lineH - mark) / 2)
            }
            .size(lineRoom, lineH).at(wordsX, r.u(76))
            .area("source", label: L("Where the times come from: {source}. Open.", ["source": subtitle]), hover: .init(scale: 1.0))
            if compact {
                Node.group { Node.symbol("gearshape", color: Noor.text).size(20, 20).at(8, 8) }.size(36, 36).at(w - 90, r.u(34)).area("preferences", label: L("Preferences"))
            } else {
                // Measured back from its divider, so the word keeps the board's gap where type has stopped shrinking.
                let word = L("Preferences"), size = r.f(19, min: 13), gear = r.f(26, min: 17), dividerX = w - r.u(95)
                let wordW = Double(word.count) * size * 0.5 + 4, buttonW = gear + r.u(17) + wordW
                Node.group {
                    Node.symbol("gearshape", color: Noor.text).size(gear, gear).at(0, (r.u(40) - gear) / 2)
                    Node.say(word, gear + r.u(17), 0, wordW, r.u(40), size: size)
                }
                .size(buttonW, r.u(40)).at(dividerX - r.u(32) - buttonW, r.u(29))
                .area("preferences", label: L("Preferences"), hover: .init(scale: 1.02))
                Node.rect(fill: Noor.hairline).size(1, r.u(34)).at(dividerX, r.u(32))
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

    /// About how wide words stand: enough to put a mark just after them, which a count of letters alone isn't, as a line of narrow dots and spaces shows.
    private static func wordsWide(_ words: String, size: Double) -> Double {
        words.reduce(0) { sum, c in
            if " ·.,:;'ijltfrI".contains(c) { return sum + 0.29 }
            if "mwMW".contains(c) { return sum + 0.82 }
            return sum + (c.isUppercase ? 0.66 : 0.54)
        } * size * 1.03
    }

    /// The five places. They fit by shrinking, and where they can't, only the chosen one keeps its word.
    private static func tabs(_ ctx: Context, y: Double) -> [Node] {
        let r = ctx.ruler, h = r.u(50), size = r.f(16, min: 12.5), glyph = r.f(24, min: 15)
        let words = NoorTab.allCases.map { Words.tab($0) }
        let room = ctx.width - r.u(60)
        let wanted = words.map { Double($0.count) * size * 0.56 + glyph + r.u(48) }
        let tight = wanted.reduce(0, +) > room
        // Preferences stands over the tabs and is none of them, except where the times come from: that is Prayer's, as F02 has it.
        let sheet = ctx.state.string("sheet")
        let place: NoorTab? = sheet == "prefs" ? (ctx.state.string("section") == "sources" ? .prayer : nil) : sheet == "import" || sheet == "manual" ? .prayer : ctx.tab
        var out: [Node] = []
        var x = r.u(30)
        for (tab, word) in zip(NoorTab.allCases, words) {
            let chosen = tab == place
            let width = tight && !chosen ? glyph + r.u(28) : Double(word.count) * size * 0.56 + glyph + r.u(48)
            let ink = chosen ? Color.hex("#FFFFFF") : Noor.text
            out.append(Node.group {
                if chosen { Node.rect(fill: Noor.picked, stroke: Noor.pickedEdge, lineWidth: 1, corner: r.u(12)).size(width, h) }
                Node.icon(tab.symbol, color: ink, side: glyph).at(r.u(16), (h - glyph) / 2)
                if !tight || chosen { Node.say(word, r.u(16) + glyph + r.u(12), 0, width - glyph - r.u(30), h, size: size, weight: chosen ? "semibold" : "regular", color: ink) }
            }
            .size(width, h).at(x, y)
            .area("tab-\(tab.rawValue)", label: chosen ? L("{tab}, selected", ["tab": word]) : word, hover: .init(scale: 1.02)))
            x += width + r.u(8)
        }
        return out
    }
}
