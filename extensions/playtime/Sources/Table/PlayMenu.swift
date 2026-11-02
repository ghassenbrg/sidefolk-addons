import Foundation
import SidefolkExtensionKit

/// The menu when no game is open: every game as a card in its own colour and art, with its tagline, the person's stats against the companion
/// (counted from Playtime's own record of games played), and the companion in the scene inviting them. A game put away shows "Resume". Arrow
/// keys move, Return opens. The frame's header holds what the panel's own header did.
@MainActor
enum PlayMenu {
    /// The cards in the order the arrows follow: the games against the companion, then the puzzles.
    static var order: [GameEntry] { GameCatalog.all.filter { !$0.solo } + GameCatalog.all.filter(\.solo) }

    static func index(of game: String) -> Int? { order.firstIndex { $0.id == game } }

    /// Arrows move through the two columns.
    static func step(_ key: String, from: Int, count: Int, rtl: Bool) -> Int {
        switch key {
        case "arrow_left": min(max(from + (rtl ? 1 : -1), 0), count - 1)
        case "arrow_right": min(max(from + (rtl ? -1 : 1), 0), count - 1)
        case "arrow_up": max(0, from - 2)
        default: min(count - 1, from + 2)
        }
    }

    static func scene(selected: Int, kept: String?) -> Scene {
        let width = BoardDrawing.width, pad = BoardDrawing.pad, inner = BoardDrawing.inner
        var y = 7.0
        var nodes: [Node] = []
        let bubbleW = inner - 64 - 4
        let invite = L("Pick a game! Can you beat me?")
        let drawing = BoardDrawing(Board([]), StageContext(entry: GameEntry(id: "", title: "", tagline: "", symbol: "", look: .dance), fresh: false))
        let bubble = drawing.speechBubble(invite, chip: nil, width: bubbleW)
        let stageH = max(64, bubble.height)
        nodes.append(.box("menu.stage", x: pad, y: y, w: inner, h: stageH) {
            Node.ellipse(fill: Paint.clear("#000000", 0.16)).at(3, stageH - 6).size(58, 8)
            Node.companion(pose: "listening").figure(bottom: true).id("menu.figure").at(0, stageH - 64).size(64, 64)
            bubble.node.at(68, stageH - bubble.height)
        })
        y += stageH + 10
        nodes.append(stats(width: inner).at(pad, y))
        y += 50 + 10
        let list = cards(selected: selected, kept: kept)
        let room = min(list.height, 420)
        let selectedId = "card.\(order[safe: selected]?.id ?? "")"
        nodes.append(Node.scroll(contentHeight: list.height, scrollTo: selectedId) { list.nodes }.id("menu.cards").at(0, y).size(width, room))
        y += room + 10
        let hint = BoardDrawing.hintCard(L("Arrows to choose · Return to play · Esc to close"), width: inner)
        nodes.append(hint.node.at(pad, y))
        y += hint.height + 10
        let height = min(y, BoardDrawing.maxHeight)
        var scene = Scene(width: width, height: height) {
            SceneBackdrop.nodes(.dance, width: width, height: height)
            nodes
        }
        .title(L("Playtime"))
        // The menu has no sound, so no speaker; and whatever the last game put above the companion is put away.
        .noSpeaker()
        .react(Reaction(prop: "none", look: "panel"))
        for arrow in ["left", "right", "up", "down"] { scene = scene.key(arrow, id: "arrow_\(arrow)") }
        return scene.key("return", id: "menu_return").key("space", id: "menu_space")
    }

    /// Wins, the current run of wins, and games played, on one card.
    private static func stats(width: Double) -> Node {
        let s = PlaytimeRecords.load().stats
        let w = (width - 8 - 2) / 3
        func stat(_ i: Int, _ value: Int, _ label: String, _ symbol: String, _ color: Color, _ soft: Color) -> Node {
            .box("menu.stat.\(i)", x: 4 + Double(i) * (w + 1), y: 8, w: w, h: 34) {
                Node.ellipse(fill: soft).at(8, 1).size(32, 32)
                Node.symbol(symbol, color: color).symbolLook(weight: "bold").at(14, 7).size(20, 20)
                Node.words(Format.integer(value), size: 20, weight: "black", x: 48, y: -2, w: w - 52, h: 24).textLook(tabular: true)
                Node.words(label, size: 11, weight: "bold", color: .inkMuted, x: 48, y: 20, w: w - 52, h: 14)
            }
        }
        return .box("menu.stats", w: width, h: 50) {
            Node.gameCard(w: width, h: 50)
            stat(0, s.wins, L("Wins"), "trophy.fill", Paint.sun, Paint.clear("#FFC93C", 0.16))
            Node.rect(fill: Paint.edge).at(4 + w, 10).size(1, 30)
            stat(1, s.streak, L("Streak", context: "games"), "flame.fill", .win, Color.win.tuned(alpha: 0.16))
            Node.rect(fill: Paint.edge).at(4 + 2 * w + 1, 10).size(1, 30)
            stat(2, s.played, L("Played", context: "games"), "gamecontroller.fill", .accent, Color.accent.tuned(alpha: 0.16))
        }
    }

    /// The games against the companion, then the puzzles played alone, each a grid of cards.
    private static func cards(selected: Int, kept: String?) -> (nodes: [Node], height: Double) {
        let pad = BoardDrawing.pad, inner = BoardDrawing.inner
        var nodes: [Node] = []
        var y = 2.0
        let w = (inner - 8) / 2
        let versus = order.filter { !$0.solo }, puzzles = order.filter(\.solo)
        func group(_ title: String, solo: Bool, _ games: [GameEntry]) {
            guard !games.isEmpty else { return }
            nodes.append(sectionHeader(title, solo: solo, width: inner).at(pad, y))
            y += 34 + 8
            for start in stride(from: 0, to: games.count, by: 2) {
                let row = Array(games[start..<min(start + 2, games.count)])
                let h = row.map { cardHeight($0, kept: kept, w: w) }.max() ?? 70
                for (c, game) in row.enumerated() {
                    nodes.append(card(game, selected: index(of: game.id) == selected, resume: kept == game.id, x: pad + Double(c) * (w + 8), y: y, w: w, h: h))
                }
                y += h + 8
            }
            y += 4
        }
        group(L("Play against {name}", ["name": "{companion}"]), solo: false, versus)
        group(L("Puzzles"), solo: true, puzzles)
        return (nodes, y)
    }

    /// A heading over a group of games: "Play against <companion>" with its face, or "Puzzles" with a piece, on a band tinted warm or cool.
    private static func sectionHeader(_ title: String, solo: Bool, width: Double) -> Node {
        let hex = solo ? "#4D9BEA" : "#FFC93C"
        return .box("menu.head.\(solo ? "solo" : "versus")", w: width, h: 34) {
            Node.rect(fill: Paint.card(0.95), corner: 12).size(width, 34)
            Node.rect(fill: Paint.clear(hex, 0.16), stroke: Paint.clear(hex, 0.35), lineWidth: 1, corner: 12).size(width, 34)
            if solo {
                Node.symbol("puzzlepiece.fill", color: .hex(hex)).symbolLook(weight: "bold").at(10, 7).size(20, 20)
            } else {
                Node.faceDisc(x: 8, y: 5, side: 24, ring: 1.5)
            }
            Node.words(title, size: 15, weight: "heavy", x: 40, w: width - 48, h: 34)
        }
    }

    private static func cardHeight(_ game: GameEntry, kept: String?, w: Double) -> Double {
        let room = w - 14 - 54 - 9
        let title = TextFit.height(game.title, size: 14, weight: "heavy", width: room, lines: 2)
        let tag = TextFit.height(game.tagline, size: 11, weight: "semibold", width: room, lines: 3)
        return max(70, 14 + title + 2 + tag)
    }

    /// A game on a menu: its picture tile, its title and tagline beside it, "Resume" when it was put away.
    private static func card(_ game: GameEntry, selected: Bool, resume: Bool, x: Double, y: Double, w: Double, h: Double) -> Node {
        let id = "card.\(game.id)"
        let room = w - 14 - 54 - 9
        let title = TextFit.height(game.title, size: 14, weight: "heavy", width: room, lines: 2)
        return Node.box(id, x: x, y: y, w: w, h: h) {
            Node.rect(fill: Paint.card, corner: 17).size(w, h).shadow(Paint.clear("#000000", 0.07), radius: 3, dx: 0, dy: 2)
            Node.rect(stroke: selected ? .accent : Paint.edge, lineWidth: selected ? 2.5 : 1, corner: 17).id(id + ".edge").size(w, h)
            artTile(game, id: id + ".tile", side: 54, corner: 13).at(7, (h - 54) / 2)
            Node.words(game.title, size: 14, weight: "heavy", valign: "top", lines: 2, minScale: 0.85, x: 7 + 54 + 9, y: 7, w: room, h: title)
            if resume {
                Node.symbol("play.fill", color: .link).symbolLook(weight: "heavy").at(70, 9 + title).size(11, 11)
                Node.words(L("Resume"), size: 11, weight: "heavy", color: .link, x: 84, y: 7 + title, w: room - 14, h: 15)
            } else {
                Node.words(game.tagline, size: 11, weight: "semibold", color: .inkMuted, valign: "top", lines: 3, minScale: 0.9, x: 7 + 54 + 9, y: 9 + title, w: room, h: max(h - 16 - title, 14))
            }
        }.area("open", value: game.id, label: resume ? "\(game.title), \(L("Resume"))" : "\(game.title), \(game.tagline)", hover: nil, press: AreaLook(scale: 0.95),
               looks: [id + ".tile.icon": AreaLook(scale: 1.07, rotate: -4)], selected: selected, sound: "sounds/tap.wav")
    }

    /// A game's picture on a tile in its colour.
    static func artTile(_ game: GameEntry, id: String, side: Double, corner: Double) -> Node {
        Node.box(id, w: side, h: side) {
            Node.rect(corner: corner).gradient([game.look.top, game.look.bottom]).size(side, side)
            Node.rect(corner: corner).gradient([Paint.clear("#FFFFFF", 0.3), Paint.clear("#FFFFFF", 0)], from: (0.5, 0), to: (0.5, 0.5)).size(side, side)
            Node.image(game.look.icon).id(id + ".icon").at(side * 0.07, side * 0.07).size(side * 0.86, side * 0.86).shadow(Paint.clear("#000000", 0.2), radius: 2.5, dx: 0, dy: 2)
        }
    }
}
