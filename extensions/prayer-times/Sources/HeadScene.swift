import Foundation
import SidefolkExtensionKit

/// Noor's head: the rosette, its name, where its times come from, and the way to Preferences. Its right end opens onto the pattern through a pendant arch; the words stay on quiet ground.
@MainActor
enum HeadScene {
    static func block(width w: Double, snapshot: NoorSnapshot, subtitle: String, remindersOn: Bool) -> Block {
        let h = 104.0
        let compact = w < 620
        let center = w * (compact ? 0.74 : 0.60), half = min(w * 0.16, 170)
        // Everything but the arch is filled, so the pattern shows only through it.
        let curtain = "M \(center - half) 0 C \(center - half * 0.72) \(h * 0.36) \(center - half * 0.3) \(h * 0.40) \(center) \(h - 8) C \(center + half * 0.3) \(h * 0.40) \(center + half * 0.72) \(h * 0.36) \(center + half) 0"
        let fill = "M 0 0 L \(center - half) 0 C \(center - half * 0.72) \(h * 0.36) \(center - half * 0.3) \(h * 0.40) \(center) \(h - 8) C \(center + half * 0.3) \(h * 0.40) \(center + half * 0.72) \(h * 0.36) \(center + half) 0 L \(w) 0 L \(w) \(h) L 0 \(h) Z"
        let scene = Scene(width: w, height: h) {
            Node.patternPanel(w, h, corner: 16)
            Node.path(fill, fill: .adaptive(light: "#EFE9F6", dark: "#171B3E")).size(w, h).at(0, 0)
            Node.path(curtain, stroke: Noor.inlay, lineWidth: 2).size(w, h).at(0, 0)
            Node.rect(stroke: Noor.hairline, lineWidth: 1, corner: 16).size(w, h).at(0, 0)
            Node.image("art/rosette-light.png", dark: "art/rosette-dark.png").size(68, 68).at(18, 18).leftToRight()
            Node.say(L("Noor"), 100, 14, compact ? w - 170 : center - half - 110, 34, size: 26, weight: "bold")
            Node.say(L("Islamic companion"), 100, 46, compact ? w - 170 : center - half - 110, 20, size: 14, color: Noor.muted)
            Node.group {
                Node.say(subtitle, 0, 0, (compact ? w - 170 : center - half - 110) - 18, 20, size: 12.5, color: Noor.muted)
                Node.symbol("chevron.down", color: Noor.muted).size(10, 10).at((compact ? w - 170 : center - half - 110) - 14, 5)
            }
            .size(compact ? w - 170 : center - half - 110, 20).at(100, 68)
            .area("source", label: L("Where the times come from: {source}. Open.", ["source": subtitle]), hover: .init(scale: 1.0))
            if compact {
                Node.group { Node.symbol("gearshape", color: Noor.text).size(20, 20).at(8, 8) }
                    .size(36, 36).at(w - 48, 12)
                    .area("preferences", label: L("Preferences"))
            } else {
                Node.group {
                    Node.symbol("gearshape", color: Noor.text).size(18, 18).at(0, 9)
                    Node.say(L("Preferences"), 26, 0, 96, 36, size: 13.5)
                }
                .size(122, 36).at(w - 188, 16)
                .area("preferences", label: L("Preferences"), hover: .init(scale: 1.02))
                Node.group {
                    Node.symbol(remindersOn ? "bell.badge" : "bell", color: Noor.text).size(20, 20).at(8, 8)
                }
                .size(36, 36).at(w - 52, 16)
                .area("reminders", label: remindersOn ? L("Reminders are on. Open reminder settings.") : L("Reminders are off. Open reminder settings."))
            }
        }
        return .scene(PageSceneBlock(scene, acts: [
            "source": .go(Go(set: ["sheet": "prefs", "section": "sources"], push: true)),
            "preferences": .go(Go(set: ["sheet": "prefs", "section": "place"], push: true)),
            "reminders": .go(Go(set: ["sheet": "prefs", "section": "reminders"], push: true)),
        ]))
    }
}
