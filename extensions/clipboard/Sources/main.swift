import Foundation
import SidefolkExtensionKit

// Clipboard, Sidefolk's own: everything you copy, a shortcut away from any app, kept on this Mac. It runs in the
// background (the clipboard has no notification), with the clipboard permission only: no internet, no files.
let ext = Extension(name: "clipboard", version: "1.0.1")
let history = History(folder: URL(fileURLWithPath: Paths.data, isDirectory: true))
let watch = Watch(history: history)

ext.background { await watch.run() }

ext.palette("history", query: { query in
    let found = history.search(query)
    let note = history.isKeeping() ? "\(history.entries.count) copies kept" : Words.status(history)
    return PaletteList(found.prefix(200).map { Words.item($0) }, note: note)
}, choose: { id, action in
    guard let entry = history.entries.first(where: { $0.id == id }) else { return PaletteChoice(message: "That copy is gone.") }
    switch action {
    case "pin":
        history.togglePin(id)
        return PaletteChoice()
    case "delete":
        history.delete(id)
        return PaletteChoice()
    default:
        watch.write(entry, plain: action == "plain")
        history.raise(id)
        return PaletteChoice(close: true, paste: true)
    }
})

ext.page("clipboard") { _ in ClipboardPage.make(history) }

ext.tool("recent_copies", "Recent copies", "The latest things the person copied, newest first, with the app and when. Secrets show "
    + "masked.", input: Schema.object(["count": Schema.integer("How many, 1–30 (10 if missing).", minimum: 1, maximum: 30)])) { args in
    let list = history.entries.prefix(args.int("count") ?? 10)
    guard !list.isEmpty else { return history.isKeeping() ? "Nothing copied yet." : "\(Words.status(history)), so there's nothing new." }
    return list.enumerated().map { Words.line($0.element, index: $0.offset + 1) }.joined(separator: "\n")
}
ext.tool("search_copies", "Search copies", "Find copies by words in them, a file name or the app they came from (\"the address "
    + "from Mail\").", input: Schema.object(["query": Schema.string("Words to look for.")], required: ["query"])) { args in
    let found = history.search(try args.required("query")).prefix(15)
    return found.isEmpty ? "No copy matches “\(try args.required("query"))”."
        : found.enumerated().map { Words.line($0.element, index: $0.offset + 1) }.joined(separator: "\n")
}
ext.tool("copy_again", "Copy again", "Puts an earlier copy back on the clipboard, by its number in the latest list (1 is the latest) "
    + "or words in it.", input: Schema.object(["number": Schema.integer("Its number, 1 is the latest.", minimum: 1),
                                               "query": Schema.string("Words in it, instead of a number.")])) { args in
    let entry = args.int("number").flatMap { n in history.entries.dropFirst(n - 1).first } ?? args.string("query").flatMap { history.search($0).first }
    guard let entry else { throw Problem("I couldn't find that copy.") }
    watch.write(entry, plain: false)
    history.raise(entry.id)
    return "On the clipboard again: \(Words.title(entry))."
}
ext.tool("pause", "Pause the history", "Stops keeping copies for a while.", input: Schema.object([
    "minutes": Schema.integer("For how long, 1–1440 (30 if missing).", minimum: 1, maximum: 1440),
])) { args in
    let until = Date().addingTimeInterval(Double(args.int("minutes") ?? 30) * 60)
    history.set { $0.pausedUntil = until }
    return "Paused until \(until.formatted(date: .omitted, time: .shortened)): nothing you copy is kept until then."
}
ext.tool("resume", "Resume the history", "Keeps copies again, after a pause.") { _ in
    history.set {
        $0.pausedUntil = nil
        $0.keeping = true
    }
    return "Keeping your copies again."
}
ext.tool("clear_history", "Clear the history", "Forgets the copies kept so far; pinned ones stay unless keep_pinned is false.",
         input: Schema.object(["keep_pinned": Schema.boolean("Keep pinned copies (true if missing).")])) { args in
    let pinned = history.entries.filter(\.pinned).count
    let keep = args.bool("keep_pinned") ?? true
    history.clear(everything: !keep)
    return keep && pinned > 0 ? "Cleared. \(pinned) pinned \(pinned == 1 ? "copy stays" : "copies stay")." : "Cleared."
}
ext.tool("set_option", "Clipboard setting", "Turns a setting on or off: keeping (the history) or hide_secrets.",
         input: Schema.object(["option": Schema.string("keeping or hide_secrets.", oneOf: ["keeping", "hide_secrets"]),
                               "on": Schema.boolean("On or off.")], required: ["option", "on"])) { args in
    let on = args.bool("on") ?? true
    switch try args.required("option") {
    case "keeping": history.set {
        $0.keeping = on
        $0.pausedUntil = nil
    }
    case "hide_secrets": history.set { $0.hideSecrets = on }
    default: throw Problem("There's no such setting.")
    }
    return on ? "Turned on." : "Turned off."
}

await ext.serve()
