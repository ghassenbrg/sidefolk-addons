import Foundation
import SidefolkExtensionKit

/// Playtime's page in Home as the accepted design draws it: one scene, today's game in a banner with the real companion, every game as a tile with its one icon, and the
/// person's real numbers and last games at the side. A scene rather than parts, so it holds together as one room. Everything in it is live, and every tile runs the same `open` tool a person's click always did.
@MainActor
enum PlaytimeHome {
    private static let width = 1000.0, height = 664.0, top = 44.0, sideX = 752.0, mainW = 736.0

    static func block(totals: GameCenterPage.Totals, dailies: [GameEntry], record: (GameEntry) -> GameCenterPage.Record, kept: String?, history: [PlaytimeRecords.Played]) -> PageSceneBlock {
        var actions: [String: (tool: String, input: [String: Any])] = [:]
        func open(_ game: String) -> String {
            let area = "open_" + game
            actions[area] = ("open", ["game": game, "person": true])
            return area
        }
        let entries = GameCatalog.all
        let versus = entries.filter { !$0.solo }, puzzles = entries.filter { $0.solo && $0.id != DailyWordScreen.id }
        let nodes = [Node.box("home.bar", w: width, h: top) {
            Node.art("art/brand-controller.webp", x: 6, y: 4, w: 36, h: 36).id("bar.mark")
            Node.words(L("Playtime"), size: 22, weight: "black", x: 50, w: 150, h: top - 4).id("bar.title")
            Node.rect(fill: Paint.edge).at(160, 10).size(1, 22)
            Node.words(L("A little break, together."), size: 15, weight: "medium", color: Paint.inkSoft, x: 172, w: 500, h: top - 4).id("bar.tagline")
        }, Node.box("home.base", y: top, w: width, h: height - top) {
            hero(dailies: dailies, record: record, kept: kept, open: open)
            heading(L("Quick games"), y: 200)
            let w = (mainW - 5 * 8) / 6
            for (i, e) in versus.prefix(12).enumerated() {
                tile(e.title, icon: e.look.icon, color: e.look.tile, resume: kept == e.id, area: open(e.id), x: Double(i % 6) * (w + 8), y: 232 + Double(i / 6) * 114, w: w, h: 106)
            }
            if versus.count < 12 {
                surprise(area: open("random"), x: Double(versus.count % 6) * (w + 8), y: 232 + Double(versus.count / 6) * 114, w: w, h: 106)
            }
            heading(L("Puzzles"), y: 456)
            let pw = (mainW - 3 * 10) / 4
            for (i, e) in puzzles.enumerated() {
                tile(e.title, icon: e.look.icon, color: e.look.tile, resume: kept == e.id, area: open(e.id), x: Double(i) * (pw + 10), y: 488, w: pw, h: 124)
            }
            side(totals: totals, history: history)
        }]
        let scene = PlayLanguage.stamped(Scene(width: width, height: height) { nodes.map(\.rounded) }.noSpeaker())
        return PageSceneBlock(scene, actions: actions)
    }

    private static func heading(_ words: String, y: Double) -> Node {
        Node.words(words, size: 21, weight: "black", minScale: 0.7, x: 8, y: y, w: mainW - 16, h: 28)
    }

    // MARK: The banner

    /// The game the page is asking about: the one put away, else today's first unplayed board, else any game at all.
    private static func hero(dailies: [GameEntry], record: (GameEntry) -> GameCenterPage.Record, kept: String?, open: (String) -> String) -> Node {
        var title = L("Today's {title}", ["title": L("Daily Word")]), detail = L("A fresh word in six tries.")
        var action = L("Play {title}", ["title": L("Daily Word")]), target = DailyWordScreen.id
        var tiles = Array(L("PLAY").uppercased()).map(String.init) + ["?"]
        if let kept, let entry = GameCatalog.entry(kept) {
            title = entry.title
            detail = L("Ready when you are!")
            action = L("Continue {title}", ["title": entry.title])
            target = kept
        } else if let word = dailies.first(where: { $0.id == DailyWordScreen.id }), record(word).today?.done == true {
            // The word is done: its result stands in the tray, and the next of today's boards is asked for.
            tiles = Array(L("DONE").uppercased()).map(String.init) + ["✓"]
            if let next = dailies.first(where: { record($0).today?.done != true }) {
                title = L("Today's {title}", ["title": next.title])
                detail = next.tagline
                action = L("Play {title}", ["title": next.title])
                target = next.id
            } else {
                title = L("All of today's boards are done")
                detail = L("Pick a game! Can you beat me?")
                action = L("Surprise me")
                target = "random"
            }
        }
        let w = mainW, h = 188.0
        let buttonW = Swift.min(Swift.max(TextFit.width(action, size: 16, weight: "heavy") + 44, 170), 230)
        let trayX = 196.0, count = Double(tiles.count), side = 42.0, gap = 4.0
        let tilesW = count * side + (count - 1) * gap
        return Node.box("hero", w: w, h: h) {
            Node.image("art/home-hero.webp", dark: "art/home-hero-night.webp", fit: "fill").id("hero.back").size(w, h).corner(22).clip()
            Node.companion(pose: "listening").figure(bottom: true).id("hero.figure").at(26, 18).size(140, 150)
            Node.art(GameCatalog.entry(target)?.look.icon ?? Look.words.icon, x: trayX, y: 22, w: 46, h: 46).id("hero.icon")
            Node.words(title, size: 28, weight: "black", minScale: 0.6, x: trayX + 54, y: 18, w: w - trayX - 70, h: 36).id("hero.title")
            Node.words(detail, size: 15, weight: "medium", color: Paint.inkSoft, minScale: 0.7, x: trayX + 54, y: 52, w: w - trayX - 70, h: 22).id("hero.detail")
            Node.art("art/word-tray.webp", x: trayX - 6, y: 136, w: tilesW + 28, h: 34).id("hero.tray")
            for (i, letter) in tiles.enumerated() {
                let last = i == tiles.count - 1
                Node.box("hero.tile.\(i)", x: trayX + 8 + Double(i) * (side + gap), y: 100, w: side, h: side) {
                    Node.rect(fill: last ? Color.hex("#CDB9E6") : Paint.ivory, stroke: Paint.clear("#7A5A3A", 0.2), lineWidth: 1, corner: 9).size(side, side).shadow(Paint.clear("#5A3A1A", 0.22), radius: 2, dx: 0, dy: 2)
                    Node.words(letter, size: 23, weight: "black", color: Paint.navy2, align: "center", minScale: 0.6, w: side, h: side)
                }
            }
            Node.box("hero.action", x: w - buttonW - 22, y: 104, w: buttonW, h: 44) {
                Node.capsule(fill: Paint.action).id("hero.action.fill").size(buttonW, 44).shadow(Paint.clear("#14275A", 0.25), radius: 4, dx: 0, dy: 2)
                Node.words(action, size: 16, weight: "heavy", color: Paint.onAction, align: "center", minScale: 0.65, x: 14, w: buttonW - 28, h: 44)
            }.area(open(target), label: action, hover: AreaLook(scale: 1.02), press: AreaLook(scale: 0.97), sound: nil)
        }
    }

    // MARK: Tiles

    private static func tile(_ title: String, icon: String, color: Color, resume: Bool, area: String, x: Double, y: Double, w: Double, h: Double) -> Node {
        let id = "tile." + area, art = Swift.min(h - 34, w - 24)
        return Node.box(id, x: x, y: y, w: w, h: h) {
            Node.rect(fill: color, corner: 16).id(id + ".back").size(w, h).shadow(Paint.clear("#7A5A3A", 0.14), radius: 3, dx: 0, dy: 2)
            Node.art(icon, x: (w - art) / 2, y: 4, w: art, h: art).id(id + ".icon")
            label(title, id: id, w: w, h: h)
            if resume {
                Node.ellipse(fill: Paint.action).id(id + ".resume").at(w - 28, 6).size(22, 22)
                Node.symbol("play.fill", color: Paint.onAction).symbolLook(weight: "bold").at(w - 23, 11).size(12, 12)
            }
        }.area(area, label: resume ? "\(title), \(L("Resume"))" : title, hover: AreaLook(dy: -2), press: AreaLook(scale: 0.97), looks: [id + ".icon": AreaLook(scale: 1.07)], sound: nil)
    }

    private static func label(_ title: String, id: String, w: Double, h: Double) -> Node {
        .box(id + ".label", x: 6, y: h - 31, w: w - 12, h: 26) {
            Node.capsule(fill: Paint.ivory).size(w - 12, 26).shadow(Paint.clear("#7A5A3A", 0.12), radius: 2, dx: 0, dy: 1)
            Node.words(title, size: 13.5, weight: "heavy", color: Paint.navy2, align: "center", minScale: 0.55, x: 3, w: w - 18, h: 26)
        }
    }

    private static func surprise(area: String, x: Double, y: Double, w: Double, h: Double) -> Node {
        let id = "tile.random", words = L("Surprise me")
        return Node.box(id, x: x, y: y, w: w, h: h) {
            Node.rect(fill: Paint.lilac, corner: 16).id(id + ".back").size(w, h).shadow(Paint.clear("#7A5A3A", 0.14), radius: 3, dx: 0, dy: 2)
            Node.image("art/game-icon-surprise.webp").id(id + ".icon").at((w - 64) / 2, 4).size(64, 64)
            label(words, id: id, w: w, h: h)
        }.area(area, label: words, hover: AreaLook(dy: -2), press: AreaLook(scale: 0.97), looks: [id + ".icon": AreaLook(scale: 1.07)], sound: nil)
    }

    // MARK: Your games

    private static func side(totals t: GameCenterPage.Totals, history: [PlaytimeRecords.Played]) -> Node {
        let w = width - sideX, h = 612.0
        let numbers = [L(one: "{count} win", other: "{count} wins", count: t.wins + t.solved), L("{n} played", ["n": t.played]), L("{n} streak", ["n": t.bestStreak])].joined(separator: " · ")
        let shown = history.compactMap { p -> (PlaytimeRecords.Played, GameEntry)? in
            (GameCatalog.entry(p.game) ?? GameCatalog.all.first { p.game.hasPrefix($0.id + "_") }).map { (p, $0) }
        }.prefix(7)
        return Node.box("side", x: sideX, w: w, h: h) {
            Node.rect(fill: Paint.card(0.65), stroke: Paint.edge, lineWidth: 1, corner: 20).id("side.card").size(w, h)
            Node.words(L("Your games"), size: 21, weight: "black", minScale: 0.7, x: 18, y: 14, w: w - 36, h: 28)
            Node.words(numbers, size: 12.5, weight: "semibold", color: Paint.inkSoft, minScale: 0.7, x: 18, y: 44, w: w - 36, h: 18).id("side.numbers")
            Node.rect(fill: Paint.edge).at(18, 70).size(w - 36, 1)
            if shown.isEmpty {
                Node.words(L("Games you finish show here."), size: 13, weight: "semibold", color: Paint.inkSoft, align: "center", lines: 3, x: 24, y: 90, w: w - 48, h: 60)
            }
            for (i, row) in shown.enumerated() { recent(row.0, row.1, y: 80 + Double(i) * 74, i: i, w: w) }
        }
    }

    private static func recent(_ p: PlaytimeRecords.Played, _ e: GameEntry, y: Double, i: Int, w: Double) -> Node {
        let id = "side.row.\(i)"
        return .box(id, x: 10, y: y, w: w - 20, h: 66) {
            Node.rect(fill: Paint.card, stroke: Paint.edge, lineWidth: 1, corner: 14).size(w - 20, 66)
            Node.rect(fill: e.look.tile, corner: 11).at(7, 7).size(52, 52)
            Node.art(e.look.icon, x: 11, y: 11, w: 44, h: 44)
            Node.words(e.title, size: 14, weight: "heavy", minScale: 0.7, x: 68, y: 12, w: w - 20 - 76, h: 20)
            Node.words(line(p, e), size: 12, weight: "semibold", color: Paint.inkSoft, minScale: 0.65, x: 68, y: 33, w: w - 20 - 76, h: 18)
        }
    }

    /// What happened, in plain words, and when: true of the record, never a made-up score.
    private static func line(_ p: PlaytimeRecords.Played, _ e: GameEntry) -> String {
        let when: String
        let days = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: p.date), to: Calendar.current.startOfDay(for: Date())).day ?? 0
        switch days {
        case 0: when = L("Today")
        case 1: when = L("Yesterday")
        default: when = p.date.formatted(.dateTime.day().month(.abbreviated).locale(Language.locale))
        }
        let what: String
        if PlaytimePage.puzzles.contains(where: { $0.id == p.game }) {
            what = L("Solved in {time}", ["time": PuzzleParts.clock(p.you)])
        } else {
            switch p.outcome {
            case .won: what = L("You won")
            case .lost: what = L("{name} won", ["name": "{companion}"])
            case .draw: what = L("A draw")
            }
        }
        return "\(what) — \(when)"
    }
}
