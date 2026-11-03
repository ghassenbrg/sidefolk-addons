import Foundation
import SidefolkExtensionKit

// Formatic: files into other formats, with what macOS has. The person hands files over by dropping them on the companion or
// choosing one on the page; Sidefolk saves the results beside them, and the program can't write in that folder.
let ext = Extension(name: "convert")

let targets = ["jpg", "png", "heic", "avif", "tiff", "gif", "pdf", "m4a", "alac", "flac", "wav", "aiff", "opus", "csv", "tsv", "json", "plist", "zip", "7z", "tar", "tar.gz"]

ext.tool("convert", "Convert files", "Makes new files in another format, saved beside the originals.",
         input: Schema.object([
             "files": Schema.array(of: Schema.path("A file."), "The files.", minItems: 0, maxItems: 64),
             "path": Schema.path("One file."),
             "target": Schema.string("The format to make.", oneOf: targets),
             "small": Schema.boolean("Make pictures small enough to email."),
         ], required: [])) { args -> ToolReply in
    let files = args.strings("files") + (args.string("path").map { [$0] } ?? [])
    guard !files.isEmpty else { throw Problem(L("Choose a file first.")) }
    let target = args.string("target") ?? "jpg", small = args.bool("small") ?? false
    let removeLocation = ExtensionSettings.bool("remove_location") ?? true
    var reply = ToolReply(""), lines: [String] = [], madeAny = false
    var pace = Pace()
    for path in files {
        do {
            let made = try await Convert.make(path, target: target, small: small, removeLocation: removeLocation)
            madeAny = madeAny || !made.isEmpty
            for one in made { reply = reply.saving(data: one.data, as: one.name, beside: path) }
            let before = Convert.size(of: path), after = made.reduce(Int64(0)) { $0 + Convert.size(of: Paths.data + "/" + $1.data) }
            let from = (path as NSString).pathExtension.uppercased(), to = target == "tar.gz" ? "TAR.GZ" : ((made.first?.name ?? "") as NSString).pathExtension.uppercased()
            let saved = before > 0 && after < before ? L("{percent}% smaller", ["percent": Int((1 - Double(after) / Double(before)) * 100)]) : Format.bytes(after)
            Recent.add(RecentFile(name: (path as NSString).lastPathComponent, change: L("{from} to {to}", ["from": from, "to": to]), result: saved, at: Date()), from: path)
            lines += made.compactMap(\.note)
        } catch let problem as Problem {
            lines.append(problem.message)
        } catch {
            lines.append(L("{file} couldn't be converted, so it was left as it is.", ["file": (path as NSString).lastPathComponent]))
        }
        await pace.rest()
    }
    // Nothing made is an error the person should see; a batch with some made reports the rest beside them.
    guard madeAny else { throw Problem(lines.joined(separator: "\n")) }
    reply.text = lines.joined(separator: "\n")
    return reply
}

ext.tool("clear_recent", "Clear the list of recent files", "Forgets the recent files and their small pictures. Nothing else changes.") { _ -> String in
    Recent.clear()
    return L("Cleared.")
}

ext.page("main") { _ in
    let recent = Recent.all()
    var sections = [
        Section(nil, [.hero(Hero(L("Any file, in the form you need."),
                                 detail: L("Drop files on your companion. Originals never change."),
                                 actions: [Action(L("Choose a file…"), act: .file(tool: "convert", param: "path", types: [], input: [:]), style: .secondary)],
                                 scene: Picture.pack("glass-pair.png")))]),
    ]
    if !recent.isEmpty {
        sections.append(Section(L("Lately"), [.list(nil, recent.map {
            Row($0.name, detail: "\($0.change) · \($0.result) · \(Format.date($0.at))", image: $0.picture, symbol: $0.picture == nil ? "doc" : nil)
        })]))
        sections.append(Section(nil, [.button(L("Clear this list"), tool: "clear_recent", input: [:], style: .plain)]))
    }
    sections.append(Section(L("Defaults"), [.settings(nil, keys: ["remove_location"])]))
    return Page(summary: Summary(recent.isEmpty ? L("Ready when you are") : L(one: "{count} file made lately", other: "{count} files made lately", count: recent.count),
                                 detail: L("Originals are never changed."), symbol: "doc.on.doc"), sections: sections)
}

await ext.serve()
