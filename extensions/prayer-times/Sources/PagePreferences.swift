import Foundation
import SidefolkExtensionKit

/// Preferences. Every change is a draft in the page's state until Save; a preview says what it would do, and Cancel leaves everything as it was. Reminders is one pearl sheet (F05), place, calculation, calendar and data
/// one board of four framed panels (F06), and `section` says which of them is meant; Sources is the F02 board, the same one first run has.
@MainActor
enum PreferencesPage {
    static let tabs: [(id: String, word: String, symbol: String)] = [("place", L("Place"), Node.Glyph.pin), ("sources", L("Sources"), "cylinder.split.1x2"), ("calculation", L("Calculation"), "square.grid.3x3.square"), ("calendar", L("Calendar"), "calendar"), ("reminders", L("Reminders"), "bell"), ("data", L("Data"), "square.and.arrow.down")]

    static func sections(_ ctx: Context) -> [Section] {
        let section = ctx.state.string("section") ?? "place"
        switch section {
        case "sources": return SourcePage.sections(ctx)
        case "reminders": return RemindersSheet.sections(ctx)
        default: return SettingsBoard.sections(ctx, section: section)
        }
    }

    /// The proposed source's own day. A calculated one isn't asked for until it is chosen, so it has none yet: better a dash than the current times under its name.
    static func proposedDay(_ ctx: Context, _ next: TimetableSource) -> PrayerDay? {
        if case .ok(let table) = ctx.model.store.timetable(sourceID: next.id), case .success(let day) = table.day(on: CivilDate(ctx.snapshot.now, in: next.zone)) { return day }
        return nil
    }

    // MARK: Method

    /// Methods as the provider lists them, in its order. None is marked as recommended, on purpose.
    static func methodChoice(_ ctx: Context, selected: String, list: Bool = false) -> [Block] {
        guard !ctx.model.prayerMethods.isEmpty else {
            return [.note(ctx.model.load == .loading ? L("Loading the methods…") : (Words.problem(ctx.model.problem).isEmpty ? L("The list of methods isn't here yet.") : Words.problem(ctx.model.problem)), tone: .neutral),
                    .action(Action(L("Try again"), tool: "refresh", symbol: "arrow.clockwise"))]
        }
        return [.draftChoice(L("Calculation method"), detail: L("From the provider's list, in its order."), options: ctx.model.prayerMethods.filter { $0.id != 99 }.prefix(24).map { Option("\($0.id)", $0.name) }, selected: selected, key: "d_method", style: list ? .rows : nil)]
    }
}

/// About how many lines words take in a width, broken as text breaks: long German words leave a line's end empty, Chinese and Japanese break anywhere. Enough to give them the room, which matters more than a point or two spare.
func lineCount(_ words: String, width: Double, size: Double, em: Double = 0.52) -> Int {
    let room = max(width, 40)
    var lines = 1, used = 0.0, word = ""
    func place(_ wide: Double) {
        if used > 0, used + wide > room {
            lines += 1
            used = 0
        }
        // A word longer than a line takes the lines it needs.
        while wide > room, used == 0, wide - Double(lines) * room > room { lines += 1 }
        used += wide
    }
    for character in words + " " {
        if character == " " || character == "\n" {
            place(wordsWidth(word, size: size, em: em))
            word = ""
            used += size * 0.28
        } else if wordsWidth(String(character), size: 1, em: 0) == 1 {
            if !word.isEmpty { place(wordsWidth(word, size: size, em: em)); word = "" }
            place(size)
        } else {
            word.append(character)
        }
    }
    return lines
}

/// A scene being put together in the page's own numbers: what it draws, the native controls laid into it, and what its areas do.
struct Sketch {
    var nodes: [Node] = []
    var inlays: [PageInlay] = []
    var tools: [String: (tool: String, input: [String: Any])] = [:]
    var acts: [String: PageAct] = [:]

    mutating func add(_ node: Node) { nodes.append(node) }
    mutating func add(_ more: [Node]) { nodes += more }
    mutating func inlay(_ x: Double, _ y: Double, _ w: Double, _ h: Double, _ part: Block) { inlays.append(PageInlay(x: x, y: y, w: w, h: h, part)) }
    mutating func take(_ other: Sketch) {
        nodes += other.nodes
        inlays += other.inlays
        tools.merge(other.tools) { $1 }
        acts.merge(other.acts) { $1 }
    }

    func block(_ w: Double, _ h: Double) -> Block {
        let all = nodes
        return .scene(PageSceneBlock(Scene(width: w, height: h) { all }, actions: tools, acts: acts, inlays: inlays))
    }
}

extension Node {
    /// A map pin in a `w × h` box, outlined, or filled with its hole showing `hole`.
    static func pin(x: Double, y: Double, w: Double, h: Double, color: Color, hole: Color? = nil, lineWidth: Double = 1.6) -> Node {
        let cx = w / 2, side = w * 0.42
        let shape = "M \(n(cx)) \(n(h)) C \(n(cx - w * 0.18)) \(n(h * 0.72)) 0 \(n(h * 0.56)) 0 \(n(h * 0.38)) C 0 \(n(h * 0.16)) \(n(w * 0.22)) 0 \(n(cx)) 0 C \(n(w * 0.78)) 0 \(n(w)) \(n(h * 0.16)) \(n(w)) \(n(h * 0.38)) C \(n(w)) \(n(h * 0.56)) \(n(cx + w * 0.18)) \(n(h * 0.72)) \(n(cx)) \(n(h)) Z"
        return Node.group {
            if let hole {
                Node.path(shape, fill: color).size(w, h)
                Node.ellipse(fill: hole).size(side, side).at(cx - side / 2, h * 0.38 - side / 2)
            } else {
                Node.path(shape, stroke: color, lineWidth: lineWidth).size(w, h)
                Node.ellipse(stroke: color, lineWidth: lineWidth).size(side, side).at(cx - side / 2, h * 0.38 - side / 2)
            }
        }
        .size(w, h).at(x, y)
    }

    /// What a menu looks like before it opens: its words and a chevron on a drawn pill. The native menu lies invisibly over it.
    static func menuPill(_ words: String, x: Double, y: Double, w: Double, h: Double, size: Double, fill: Color, line: Color, ink: Color, corner: Double, disabled: Bool = false) -> Node {
        let chevron = max(size * 0.72, 9)
        return Node.group {
            Node.rect(fill: fill, stroke: line, lineWidth: 1, corner: corner).size(w, h)
            Node.say(words, h * 0.38, 0, w - h * 0.38 - chevron - h * 0.5, h, size: size, color: ink, tabular: true)
            Node.symbol("chevron.down", color: ink).symbolLook(weight: "semibold").size(chevron, chevron).at(w - chevron - h * 0.36, (h - chevron) / 2)
        }
        .size(w, h).at(x, y).opacity(disabled ? 0.5 : 1)
    }
}
