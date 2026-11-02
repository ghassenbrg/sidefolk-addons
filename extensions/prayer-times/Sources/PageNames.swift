import Foundation
import SidefolkExtensionKit

/// Names: all 99 as the provider supplied them, Arabic with its own shaping, transliteration and English meaning. Nothing is added to them: no commentary, audio or translated meanings.
@MainActor
enum NamesPage {
    private static func filtered(_ ctx: Context) -> [NameEntry] {
        let query = (ctx.state.string("q") ?? "").trimmingCharacters(in: .whitespaces).lowercased()
        let saved = ctx.state.string("filter") == "saved"
        let names = ctx.model.names.sorted { $0.number < $1.number }
        return names.filter { name in
            (!saved || ctx.model.bookmarks.contains(name.number))
                && (query.isEmpty || name.transliteration.lowercased().contains(query) || name.meaning.lowercased().contains(query) || name.arabic.contains(query)
                    || Self.bare(name.arabic).contains(Self.bare(query)))
        }
    }

    /// Arabic without its vowel marks: people type it that way.
    private static func bare(_ text: String) -> String { String(text.unicodeScalars.filter { !(0x064B...0x065F).contains($0.value) && $0.value != 0x0670 }.map(Character.init)) }

    static func sections(_ ctx: Context) -> [Section] {
        guard !ctx.model.names.isEmpty else {
            let busy = ctx.model.load == .loading
            return [NoorPage.status(ctx, symbol: "book", title: busy ? L("Loading the Names…") : L("The Names aren't here yet"), detail: busy ? "" : L("They need one connection, then they are saved. {why}", ["why": Words.problem(ctx.model.problem)]), buttons: busy ? [] : [("retry", L("Try again"), true, .tool("refresh"))])]
        }
        let query = ctx.state.string("q") ?? ""
        let saved = ctx.state.string("filter") == "saved"
        let list = filtered(ctx)
        let selected = ctx.state.int("name").flatMap { n in ctx.model.names.first { $0.number == n } } ?? list.first ?? ctx.model.names.first
        // Twenty at a time: a scene is sent whole, and a page has a limit. Searching or following one by number shows where it is.
        let start = shelf(ctx, list, selected: selected)
        var out: [Section] = [
            Section(nil, [
                .draftField(L("Search the Names"), placeholder: L("Search Arabic, transliteration or meaning"), button: L("Clear"), key: "q", value: query.isEmpty ? nil : query, live: true, set: ["shelf": NSNull(), "name": NSNull()]),
                .draftChoice(L("Show"), options: [Option("all", L("All {count}", ["count": "99"])), Option("saved", L("Saved ({count})", ["count": "\(ctx.model.bookmarks.count)"]))], selected: saved ? "saved" : "all", key: "filter"),
            ], wide: true),
        ]
        if list.isEmpty {
            if saved && query.isEmpty {
                out.append(NoorPage.status(ctx, symbol: "bookmark", title: L("No saved names yet"), detail: L("Save names as you explore the 99 Names. They stay on this Mac."), buttons: [("browse", L("Browse names"), true, .go(Go(set: ["filter": "all"])))]))
            } else {
                out.append(NoorPage.status(ctx, symbol: "magnifyingglass", title: L("No results for “{query}”", ["query": query]), detail: L("Try a different spelling or name."), buttons: [("clear", L("Clear search"), true, .go(Go(set: ["q": NSNull()])))]))
            }
            return out
        }
        let w = ctx.width
        if ctx.narrow {
            out.append(Section(nil, [listScene(ctx, list, start: start, width: w, height: 560, selected: nil, pushes: true)], wide: true))
        } else if let selected {
            let gap = 14.0
            let leftW = (w - gap) * 0.44, h = 600.0
            let scene = Scene(width: w, height: h) {
                listNode(ctx, list, start: start, w: leftW, h: h, selected: selected.number)
                detail(ctx, selected, w: w - leftW - gap, h: h).at(leftW + gap, 0)
            }
            out.append(Section(nil, [.scene(PageSceneBlock(scene, actions: tools(ctx, selected), acts: acts(ctx, selected, list: list, start: start, pushes: false)))], wide: true))
            out.append(Section(nil, [.action(copy(selected))], wide: true))
        }
        return out
    }

    /// One Name on its own: where a narrow window goes from the list, and where "Show Ar Rahmaan" lands.
    static func detailOnly(_ ctx: Context) -> [Section] {
        guard let name = ctx.state.int("name").flatMap({ n in ctx.model.names.first { $0.number == n } }) else { return [] }
        let w = ctx.width, h = 560.0
        let scene = Scene(width: w, height: h) { detail(ctx, name, w: w, h: h) }
        return [Section(nil, [.scene(PageSceneBlock(scene, actions: tools(ctx, name), acts: acts(ctx, name, list: [], start: 0, pushes: false)))], wide: true),
                Section(nil, [.action(copy(name))], wide: true)]
    }

    private static func copy(_ name: NameEntry) -> Action {
        Action(L("Copy"), act: .copy("\(name.arabic) · \(name.transliteration) · \(name.meaning)"), symbol: "doc.on.doc")
    }

    private static func tools(_ ctx: Context, _ name: NameEntry) -> [String: (tool: String, input: [String: Any])] {
        ["save": ("save_name", ["number": name.number, "saved": !ctx.model.bookmarks.contains(name.number)])]
    }

    static let shelfSize = 20

    /// Where in the list the shelf starts: where they turned to, or wherever the Name being read is.
    private static func shelf(_ ctx: Context, _ list: [NameEntry], selected: NameEntry?) -> Int {
        if let wanted = ctx.state.int("shelf") { return max(0, min(wanted, max(0, list.count - 1))) }
        guard let selected, let i = list.firstIndex(of: selected) else { return 0 }
        return i / shelfSize * shelfSize
    }

    private static func acts(_ ctx: Context, _ selected: NameEntry, list: [NameEntry], start: Int, pushes: Bool) -> [String: PageAct] {
        var out: [String: PageAct] = [:]
        if start > 0 { out["shelf-back"] = .go(Go(set: ["shelf": max(0, start - shelfSize)])) }
        if start + shelfSize < list.count { out["shelf-on"] = .go(Go(set: ["shelf": start + shelfSize])) }
        for name in list[min(start, list.count)..<min(start + shelfSize, list.count)] {
            out["n\(name.number)"] = pushes ? .go(Go(set: ["name": name.number, "sheet": "name"], push: true)) : .go(Go(set: ["name": name.number]))
        }
        let all = ctx.model.names.sorted { $0.number < $1.number }
        if let i = all.firstIndex(of: selected) {
            if i > 0 { out["previous"] = .go(Go(set: ["name": all[i - 1].number, "shelf": NSNull()])) }
            if i + 1 < all.count { out["following"] = .go(Go(set: ["name": all[i + 1].number, "shelf": NSNull()])) }
        }
        return out
    }

    private static func listScene(_ ctx: Context, _ list: [NameEntry], start: Int, width: Double, height: Double, selected: Int?, pushes: Bool) -> Block {
        let scene = Scene(width: width, height: height) { listNode(ctx, list, start: start, w: width, h: height, selected: selected) }
        return .scene(PageSceneBlock(scene, acts: acts(ctx, list[0], list: list, start: start, pushes: pushes)))
    }

    private static func listNode(_ ctx: Context, _ list: [NameEntry], start: Int, w: Double, h: Double, selected: Int?) -> Node {
        let rowH = 92.0
        let shelf = Array(list[min(start, list.count)..<min(start + shelfSize, list.count)])
        let more = list.count > shelfSize
        let listH = more ? h - 48 : h
        let inShelf = selected.map { n in shelf.contains { $0.number == n } } ?? false
        return Node.group {
            if more {
                Node.say(L("{from} to {to} of {count}", ["from": "\(start + 1)", "to": "\(start + shelf.count)", "count": "\(list.count)"]), 120, h - 40, w - 240, 36, size: 12.5, color: Noor.muted, align: "center")
                Node.pill("shelf-back", label: L("Earlier"), x: 0, y: h - 40, w: 110, h: 36, symbol: "chevron.backward", disabled: start == 0)
                Node.pill("shelf-on", label: L("Later"), x: w - 122, y: h - 40, w: 110, h: 36, symbol: "chevron.forward", disabled: start + shelfSize >= list.count)
            }
            Node.scroll(contentHeight: Double(shelf.count) * rowH, scrollTo: inShelf && (selected ?? 0) != shelf.first?.number ? selected.map { "name-\($0)" } : nil) {
                for (i, name) in shelf.enumerated() {
                    Node.group {
                        Node.rect(fill: name.number == selected ? .adaptive(light: "#EDE4F7", dark: "#2F2558") : Noor.surface, stroke: name.number == selected ? Noor.accent : Noor.hairline, lineWidth: name.number == selected ? 1.5 : 1, corner: 12).size(w - 12, rowH - 8)
                        Node.ellipse(fill: Noor.well, stroke: Noor.hairline, lineWidth: 1).size(36, 36).at(12, (rowH - 8) / 2 - 18)
                        Node.say("\(name.number)", 12, (rowH - 8) / 2 - 18, 36, 36, size: 14, align: "center", tabular: true)
                        Node.say(name.transliteration, 60, 12, w * 0.5 - 40, 28, size: 17, weight: "medium")
                        Node.say(name.meaning, 60, 40, w * 0.5 - 40, 34, size: 12.5, color: Noor.muted, lines: 2)
                        Node.say(name.arabic, w * 0.56, 8, w * 0.38 - 18, rowH - 24, size: 27, align: "center").leftToRight()
                        if ctx.model.bookmarks.contains(name.number) {
                            Node.symbol("bookmark.fill", color: Noor.accent).size(12, 14).at(w - 38, 8).label(L("Saved"))
                        }
                    }
                    .size(w - 12, rowH - 8).at(0, Double(i) * rowH).id("name-\(name.number)")
                    .area("n\(name.number)", label: "\(name.number), \(name.transliteration), \(name.meaning)", hover: nil, press: nil, selected: name.number == selected)
                }
            }
            .size(w, listH).id("names-list")
        }
        .size(w, h)
    }

    private static func detail(_ ctx: Context, _ name: NameEntry, w: Double, h: Double) -> Node {
        let saved = ctx.model.bookmarks.contains(name.number)
        let inset = 18.0
        return Node.group {
            Node.patternPanel(w, h)
            Node.arch(w - inset * 2, h - 24, lift: 70).at(inset, 24)
            Node.inlay(w, h)
            Node.say(L("Name {number} of 99", ["number": Format.integer(name.number)]), w / 2 - 80, 74, 160, 22, size: 13, color: Noor.muted, align: "center")
            // Reading text in the source's own Unicode, drawn by the system so it shapes properly.
            Node.say(name.arabic, inset + 16, 104, w - (inset + 16) * 2, 124, size: min(w * 0.14, 76), weight: "medium", align: "center", lines: 1).leftToRight()
            Node.say(name.transliteration, inset + 16, 232, w - (inset + 16) * 2, 46, size: 32, weight: "semibold", color: Noor.warm, align: "center")
            Node.say(name.meaning, inset + 24, 278, w - (inset + 24) * 2, 54, size: 19, color: Noor.text, align: "center", lines: 2)
            Node.image("art/rosette-light.png", dark: "art/rosette-dark.png").size(20, 20).at(w / 2 - 10, 340).leftToRight()
            Node.rect(fill: Noor.inlay).size(70, 1).at(w / 2 - 90, 350)
            Node.rect(fill: Noor.inlay).size(70, 1).at(w / 2 + 20, 350)
            Node.say(L("Source: AlAdhan"), inset + 24, 372, w - (inset + 24) * 2, 22, size: 13, color: Noor.muted, align: "center")
            Node.say(L("English meaning"), inset + 24, 392, w - (inset + 24) * 2, 22, size: 13, color: Noor.muted, align: "center")
            Node.pill("save", label: saved ? L("Saved") : L("Save"), spoken: saved ? L("Remove {name} from saved names", ["name": name.transliteration]) : L("Save {name}", ["name": name.transliteration]), x: w / 2 - 70, y: 430, w: 140, h: 40, symbol: saved ? "bookmark.fill" : "bookmark", filled: !saved)
            Node.pill("previous", label: L("Previous"), x: inset + 20, y: h - 66, w: 120, h: 38, symbol: "chevron.backward", disabled: name.number == 1)
            Node.pill("following", label: L("Next"), x: w - inset - 140, y: h - 66, w: 120, h: 38, symbol: "chevron.forward", disabled: name.number == 99)
        }
        .size(w, h)
    }
}
