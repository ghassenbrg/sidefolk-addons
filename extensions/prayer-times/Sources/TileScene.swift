import Foundation
import SidefolkExtensionKit

/// Noor's Today tile, the C01 board's: the rosette on the lattice, what is next and what follows it. A picture of the page's summary, with the same words and the same instant; the host opens the page on a click.
@MainActor
enum TileScene {
    static let w = 640.0, h = 208.0

    static func scene(_ snapshot: NoorSnapshot) -> Scene? {
        guard let first = event(snapshot) else { return nil }
        let second = following(snapshot)
        let source = Words.tileSource(snapshot)
        let cardW = second == nil ? 300.0 : 226.0, cardH = h - 44, x0 = 134.0
        return Scene(width: w, height: h) {
            // The frame all but silent, as the board's: its pattern a whisper on the card's own ground, so what is next is what's read.
            Node.rect(fill: Noor.surface, corner: 16).size(w, h)
            Node.lattice(w, h, corner: 16).opacity(0.18)
            Node.image("art/glow.png", tint: .adaptive(light: "#FBF9FD", dark: "#0C0F2C")).size(420, 420).at(-110, -106)
            Node.rect(stroke: Noor.inlay, lineWidth: 1, corner: 16).size(w, h)
            Node.image("art/rosette-l.png", dark: "art/rosette-d.png").size(86, 86).at(26, (h - 86) / 2).leftToRight()
            card(first, source: source, w: cardW, h: cardH, big: true).at(x0, 22)
            if let second { card(second, source: source, w: cardW, h: cardH, big: false).at(x0 + cardW + 14, 22) }
        }
    }

    private struct Event { var title: String; var time: String; var countdown: String }

    private static func event(_ s: NoorSnapshot) -> Event? {
        guard let focus = DialScene.focus(s) else { return nil }
        return Event(title: focus.title, time: focus.time, countdown: focus.countdown)
    }

    /// What comes after the moment in focus: that prayer's iqamah, or the next prayer's start. Only what the day says.
    private static func following(_ s: NoorSnapshot) -> Event? {
        guard let today = s.today else { return nil }
        let zone = today.zone
        func made(_ title: String, _ at: Date) -> Event { Event(title: title, time: Words.time(at, zone: zone), countdown: Words.countdown(to: at, from: s.now)) }
        let after: Date
        switch s.next {
        case .prayerStart(let id, let at, _):
            if let iqamah = today.iqamah[id], iqamah > at { return made(L("{prayer} iqamah", ["prayer": Words.prayer(id)]), iqamah) }
            after = at
        case .iqamah(_, let at, _):
            after = at
        case .unavailable:
            return nil
        }
        return PrayerID.allCases.compactMap { id in today.starts[id].map { (id, $0) } }.filter { $0.1 > after }.min { $0.1 < $1.1 }.map { made(Words.prayer($0.0), $0.1) }
    }

    private static func card(_ e: Event, source: String, w: Double, h: Double, big: Bool) -> Node {
        Node.group {
            Node.rect(fill: Noor.surface, stroke: Noor.hairline, lineWidth: 1, corner: 14).size(w, h)
            // Today shows this at about half its size, so these are large for what they read as.
            Node.say(e.title, 16, 8, w - 28, 32, size: 24, weight: "medium", color: big ? Noor.accent : Noor.text)
            Node.say(e.time, 16, 39, w - 28, 54, size: big ? 46 : 40, weight: "regular", tabular: true)
            Node.say(e.countdown, 16, 92, w - 28, 30, size: 23, color: Noor.warm)
            Node.say(source, 16, h - 38, w - 28, 28, size: 18, color: Noor.muted)
        }
        .size(w, h)
    }
}
