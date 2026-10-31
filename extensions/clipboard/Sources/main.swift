import Foundation
import SidefolkExtensionKit

// Clipboard, Sidefolk's own: everything you copy, a shortcut away from any app, kept on this Mac. It runs in the
// background (the clipboard has no notification), with the clipboard permission only: no internet, no files.
let ext = Extension(name: "clipboard")
let history = History(folder: URL(fileURLWithPath: Paths.data, isDirectory: true))
let source = Source { ext.send("sidefolk/clipboard.source") }
let watch = Watch(history: history, source: source)

ext.background { await watch.run() }
ext.on("sidefolk/clipboard.source") { args in
    source.receive(change: args.int("change"), app: args.string("app"), name: args.string("name"))
}

ext.palette("history", query: { query in
    guard let found = history.find(query) else { return PaletteList([], note: "That isn't a pattern Clipboard can read.", preview: true) }
    return PaletteList(Words.list(found, h: history), note: Words.note(history), preview: true, actions: ["clear", "clear_all"])
}, choose: { id, action in
    switch action {
    case "clear", "clear_all":
        history.clear(everything: action == "clear_all")
        return PaletteChoice(message: action == "clear_all" ? "Cleared, pinned copies too." : "Cleared. Pinned copies stay.")
    default: break
    }
    guard let entry = history.entries.first(where: { $0.id == id }) else { return PaletteChoice(message: "That copy is gone.") }
    switch action {
    case "pin":
        history.togglePin(id)
        return PaletteChoice()
    case "delete":
        history.delete(id)
        return PaletteChoice()
    default:
        // Return does what the person chose (paste, or only copy), Option-Return the other; Shift-Return pastes plain.
        let paste = action == "alternate" ? !history.options.paste : history.options.paste
        watch.write(entry, plain: action == "plain" || history.options.plain)
        history.raise(id)
        return PaletteChoice(close: true, paste: paste)
    }
}, preview: { id in
    history.entries.first { $0.id == id }.map { Words.preview($0) }
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
                                               "query": Schema.string("Words in it, instead of a number."),
                                               "id": Schema.string("Its id, from the Clipboard page.")])) { args in
    let entry = args.string("id").flatMap { id in history.entries.first { $0.id == id } }
        ?? args.int("number").flatMap { n in history.entries.dropFirst(n - 1).first } ?? args.string("query").flatMap { history.search($0).first }
    guard let entry else { throw Problem("I couldn't find that copy.") }
    watch.write(entry, plain: history.options.plain)
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
ext.tool("skip_next", "Skip the next copy", "Leaves the next thing the person copies out of the history (a password they're about to copy).") { _ in
    history.set { $0.skipNext = true }
    return "Your next copy won't be kept."
}
ext.tool("clear_history", "Clear the history", "Forgets the copies kept so far; pinned ones stay unless keep_pinned is false.",
         input: Schema.object(["keep_pinned": Schema.boolean("Keep pinned copies (true if missing).")])) { args in
    let pinned = history.entries.filter(\.pinned).count
    let keep = args.bool("keep_pinned") ?? true
    history.clear(everything: !keep)
    return keep && pinned > 0 ? "Cleared. \(pinned) pinned \(pinned == 1 ? "copy stays" : "copies stay")." : "Cleared."
}
ext.tool("ignore", "Ignore copies", "Leaves out, or keeps again, copies from an app (its name or bundle id), copies whose text matches a "
    + "regular expression, or copies marked with a clipboard type.", input: Schema.object([
        "app": Schema.string("An app's name or bundle id."), "pattern": Schema.string("A regular expression."),
        "type": Schema.string("A clipboard type, like com.apple.is-remote-clipboard."),
        "on": Schema.boolean("Leave them out (true if missing) or keep them again."),
    ])) { args in
    try Settings.ignore(args, history)
}
ext.tool("set_option", "Clipboard setting", "Changes a setting: keeping, hide_secrets, paste, plain, keep_images, keep_files or "
    + "keep_formatting with on; limit, sort, pins or search with value.",
         input: Schema.object(["option": Schema.string("The setting.", oneOf: Settings.names), "on": Schema.boolean("On or off."),
                               "value": Schema.string("The value, for limit, sort, pins and search.")], required: ["option"])) { args in
    try Settings.set(args, history)
}

await ext.serve()
