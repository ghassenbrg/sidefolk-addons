import Foundation
import SidefolkExtensionKit

/// All games: every game with its one icon on a tile of its own colour, the person's real numbers, and the companion inviting them. Everything fits at once, in the same
/// canvas as a game, so nothing scrolls or jumps. A game put away says Resume. Arrows move, Return opens.
@MainActor
enum PlayMenu {
    /// A tile that opens one game the person hasn't just played, as the Game Center's Surprise me does.
    static let surprise = "random"

    /// The games against the companion, then the puzzles.
    static var order: [GameEntry] { versus + GameCatalog.all.filter(\.solo) }
    private static var versus: [GameEntry] { GameCatalog.all.filter { !$0.solo } }
    private static var daily: GameEntry? { GameCatalog.entry(DailyWordScreen.id) }
    private static var puzzles: [GameEntry] { GameCatalog.all.filter { $0.solo && $0.id != DailyWordScreen.id } }

    /// What the arrows walk, row by row: pairs of cards, a banner alone.
    static var rows: [[String]] {
        var ids = versus.map(\.id)
        if !ids.count.isMultiple(of: 2) { ids.append(surprise) }
        var out = stride(from: 0, to: ids.count, by: 2).map { Array(ids[$0..<min($0 + 2, ids.count)]) }
        if let daily { out.append([daily.id]) }
        let solos = puzzles.map(\.id)
        out += stride(from: 0, to: solos.count, by: 2).map { Array(solos[$0..<min($0 + 2, solos.count)]) }
        return out
    }

    static var slots: [String] { rows.flatMap { $0 } }

    static func index(of game: String) -> Int? { slots.firstIndex(of: game) }

    /// Arrows move across a row and between rows, keeping their side where they can.
    static func step(_ key: String, from: Int, rtl: Bool) -> Int {
        let rows = self.rows
        var at = 0, row = 0, column = 0
        for (r, ids) in rows.enumerated() {
            if from < at + ids.count { (row, column) = (r, from - at); break }
            at += ids.count
        }
        func index(_ r: Int, _ c: Int) -> Int { rows[..<r].reduce(0) { $0 + $1.count } + min(c, rows[r].count - 1) }
        switch key {
        case "arrow_left": return index(row, max(column + (rtl ? 1 : -1), 0))
        case "arrow_right": return index(row, max(column + (rtl ? -1 : 1), 0))
        case "arrow_up": return row > 0 ? index(row - 1, column) : from
        default: return row + 1 < rows.count ? index(row + 1, column) : from
        }
    }

    private static let cardH = 41.0, gap = 5.0

    static func scene(selected: Int, kept: String?) -> Scene {
        let width = BoardDrawing.width, pad = BoardDrawing.pad, inner = BoardDrawing.inner
        let drawing = BoardDrawing(Board([]), StageContext(entry: GameEntry(id: "", title: "", tagline: "", symbol: "", look: .plain), fresh: false))
        let slots = self.slots
        let chosen = slots[safe: selected]
        var nodes: [Node] = [drawing.titleRow(L("All games"), icon: "art/brand-controller.webp", width: inner).at(pad, 4)]
        var y = 40.0
        let side = 66.0, bubbleH = 46.0
        nodes.append(.box("menu.stage", x: pad, y: y, w: inner, h: 62) {
            Node.companion(pose: "listening").figure(bottom: true).id("menu.figure").at(0, 0).size(side, 66)
            drawing.speechBubble(L("What shall we play?"), width: inner - side - 8, height: bubbleH).node.at(side + 8, 0)
            Node.words(statsLine(), size: 12, weight: "semibold", color: Paint.inkSoft, align: "center", minScale: 0.7, x: side + 8, y: bubbleH + 2, w: inner - side - 8, h: 16).id("menu.stats")
        }.z(1))
        y += 66
        nodes.append(sectionPill(L("Play against {name}", ["name": "{companion}"]), width: inner).at(pad, y))
        y += 26
        let w = (inner - 8) / 2
        func card(_ id: String, row: Int, column: Int) -> Node {
            let at = (x: pad + Double(column) * (w + 8), y: y)
            if id == surprise { return surpriseCard(selected: chosen == id, x: at.x, y: at.y, w: w, h: cardH) }
            return gameCard(GameCatalog.entry(id)!, selected: chosen == id, resume: kept == id, x: at.x, y: at.y, w: w, h: cardH)
        }
        var puzzlesHeaded = false
        for (r, ids) in rows.enumerated() {
            if ids.count == 1, let daily, ids[0] == daily.id {
                nodes.append(dailyBanner(daily, selected: chosen == daily.id, resume: kept == daily.id, x: pad, y: y + 1, w: inner, h: 40))
                y += 46
                continue
            }
            if let first = ids.first, GameCatalog.entry(first)?.solo == true, !puzzlesHeaded {
                puzzlesHeaded = true
                nodes.append(sectionPill(L("Puzzles"), width: inner).at(pad, y))
                y += 26
            }
            for (c, id) in ids.enumerated() { nodes.append(card(id, row: r, column: c)) }
            y += cardH + gap
        }
        nodes.append(BoardDrawing.hintCard(L("Arrows to choose · Return to play · Esc to close"), width: inner).node.at(pad, BoardDrawing.canvas - BoardDrawing.footerRoom))
        var scene = Scene(width: width, height: BoardDrawing.canvas) {
            Node.rect(fill: Paint.paper).id("bg.base").size(width, BoardDrawing.canvas)
            nodes.map(\.rounded)
        }
        .title(L("A little break, together."))
        // The menu has no sound, so no speaker; and whatever the last game put above the companion is put away.
        .noSpeaker()
        .transition(ms: 160)
        .react(Reaction(prop: "none", look: "panel"))
        for arrow in ["left", "right", "up", "down"] { scene = scene.key(arrow, id: "arrow_\(arrow)") }
        return scene.key("return", id: "menu_return").key("space", id: "menu_space")
    }

    /// The person's real numbers, in a line.
    private static func statsLine() -> String {
        let s = PlaytimeRecords.load().stats
        return [L(one: "{count} win", other: "{count} wins", count: s.wins), L("{n} played", ["n": s.played]), L("{n} streak", ["n": s.streak])].joined(separator: " · ")
    }

    private static func sectionPill(_ title: String, width: Double) -> Node {
        let w = Swift.min(TextFit.width(title, size: 12, weight: "heavy") + 24, width - 40)
        return .box("menu.head.\(title.hashValue & 0xFFFF)", w: width, h: 22) {
            Node.capsule(fill: Paint.action).size(w, 22)
            Node.words(title, size: 12, weight: "heavy", color: Paint.onAction, align: "center", minScale: 0.7, x: 8, w: w - 16, h: 22)
            Node.rect(fill: Paint.clear("#A08A70", 0.35)).at(w + 10, 11).size(width - w - 14, 1)
        }
    }

    private static func base(_ id: String, selected: Bool, w: Double, h: Double, tile: Color, icon: String?, symbol: String? = nil) -> [Node] {
        var out: [Node] = [
            Node.rect(fill: Paint.card, corner: 13).id(id + ".face").size(w, h).shadow(Paint.clear("#7A5A3A", 0.13), radius: 3, dx: 0, dy: 2),
            Node.rect(fill: tile, corner: 13).id(id + ".tile").size(58, h),
        ]
        if let icon { out.append(Node.image(icon).id(id + ".icon").at(58 / 2 - 18, (h - 36) / 2).size(36, 36)) }
        if let symbol { out.append(Node.symbol(symbol, color: Paint.ink).symbolLook(weight: "bold").id(id + ".icon").at(58 / 2 - 11, (h - 22) / 2).size(22, 22)) }
        out.append(Node.rect(stroke: selected ? Paint.action : Paint.edge, lineWidth: selected ? 2.5 : 1, corner: 13).id(id + ".edge").size(w, h))
        return out
    }

    private static let hoverIcon = AreaLook(scale: 1.1, rotate: -3)

    /// A game: its tile and name. Put away, it also says Resume, in the room its name leaves.
    private static func gameCard(_ game: GameEntry, selected: Bool, resume: Bool, x: Double, y: Double, w: Double, h: Double) -> Node {
        let id = "card.\(game.id)", room = w - 58 - 16
        return Node.box(id, x: x, y: y, w: w, h: h) {
            base(id, selected: selected, w: w, h: h, tile: game.look.tile, icon: game.look.icon)
            if resume {
                Node.words(game.title, size: 13.5, weight: "heavy", minScale: 0.7, x: 58 + 9, y: 4, w: room, h: 18)
                Node.words(L("Resume"), size: 11, weight: "heavy", color: Paint.inkSoft, x: 58 + 9, y: 21, w: room, h: 15)
            } else {
                Node.words(game.title, size: 13.5, weight: "heavy", lines: 2, minScale: 0.7, x: 58 + 9, w: room, h: h)
            }
        }.area("open", value: game.id, label: resume ? "\(game.title), \(L("Resume"))" : "\(game.title), \(game.tagline)", hover: AreaLook(dy: -1), press: AreaLook(scale: 0.97),
               looks: [id + ".icon": hoverIcon], selected: selected, sound: "sounds/tap.wav")
    }

    private static func surpriseCard(selected: Bool, x: Double, y: Double, w: Double, h: Double) -> Node {
        let id = "card.random", words = L("Surprise me")
        return Node.box(id, x: x, y: y, w: w, h: h) {
            base(id, selected: selected, w: w, h: h, tile: Paint.lilac, icon: nil, symbol: "dice.fill")
            Node.words(words, size: 13.5, weight: "heavy", lines: 2, minScale: 0.7, x: 58 + 9, w: w - 58 - 16, h: h)
        }.area("open", value: surprise, label: words, hover: AreaLook(dy: -1), press: AreaLook(scale: 0.97), looks: [id + ".icon": hoverIcon], selected: selected, sound: "sounds/tap.wav")
    }

    /// Daily Word has the one navy banner: it is the game of the day.
    private static func dailyBanner(_ game: GameEntry, selected: Bool, resume: Bool, x: Double, y: Double, w: Double, h: Double) -> Node {
        let id = "card.\(game.id)"
        let words = resume ? "\(game.title) · \(L("Resume"))" : game.title
        let textW = Swift.min(TextFit.width(words, size: 16, weight: "black") + 2, w - 80)
        let start = (w - 40 - 8 - textW) / 2
        return Node.box(id, x: x, y: y, w: w, h: h) {
            Node.capsule(fill: Paint.action).id(id + ".face").size(w, h).shadow(Paint.clear("#14275A", 0.22), radius: 4, dx: 0, dy: 2)
            Node.image(game.look.icon).id(id + ".icon").at(start, 2).size(36, 36)
            Node.words(words, size: 16, weight: "black", color: Paint.onAction, minScale: 0.7, x: start + 44, w: textW, h: h)
            if selected { Node.capsule(stroke: Paint.coral, lineWidth: 2.5).id(id + ".edge").at(1.25, 1.25).size(w - 2.5, h - 2.5) }
        }.area("open", value: game.id, label: "\(game.title), \(game.tagline)", hover: AreaLook(dy: -1), press: AreaLook(scale: 0.98), looks: [id + ".icon": hoverIcon], selected: selected, sound: "sounds/tap.wav")
    }
}
