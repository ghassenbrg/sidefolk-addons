import Foundation
import SidefolkExtensionKit

/// The tools behind the page's switches, choices and fields: one setting at a time, checked, in plain words back.
@MainActor
enum Settings {
    static let switches = ["keeping", "hide_secrets", "paste", "plain", "keep_images", "keep_files", "keep_formatting"]
    static let values = ["limit", "sort", "pins", "search"]
    static var names: [String] { switches + values }

    static func set(_ args: Arguments, _ h: History) throws -> String {
        let option = try args.required("option")
        if switches.contains(option) {
            // A choice on the page sends a value; a switch or a command sends on.
            let on = args.bool("on") ?? args.string("value").map { ["paste", "remove", "on", "true"].contains($0) } ?? true
            h.set { o in
                switch option {
                case "keeping":
                    o.keeping = on
                    o.pausedUntil = nil
                case "hide_secrets": o.hideSecrets = on
                case "paste": o.paste = on
                case "plain": o.plain = on
                case "keep_images": o.keepImages = on
                case "keep_files": o.keepFiles = on
                default: o.keepFormatting = on
                }
            }
            return on ? "Turned on." : "Turned off."
        }
        let value = try args.required("value")
        switch option {
        case "limit":
            guard let n = Int(value), Options.limits.contains(n) else { throw Problem("Keep up to \(Options.limits.map(String.init).joined(separator: ", ")) copies.") }
            h.set { $0.limit = n }
            return "Keeping up to \(n) copies."
        case "sort":
            guard let sort = Options.Sort(rawValue: value) else { throw Problem("The order is recent, first or count.") }
            h.set { $0.sort = sort }
        case "pins":
            guard let pins = Options.Pins(rawValue: value) else { throw Problem("Pinned copies go top or bottom.") }
            h.set { $0.pins = pins }
        case "search":
            guard let search = Options.Search(rawValue: value) else { throw Problem("Search is words, exact, fuzzy or regex.") }
            h.set { $0.search = search }
        default:
            throw Problem("There's no such setting.")
        }
        return "Done."
    }

    static func ignore(_ args: Arguments, _ h: History) throws -> String {
        let on = args.bool("on") ?? true
        if let app = args.string("app") {
            guard app.count <= 200 else { throw Problem("That's too long for an app's name.") }
            h.set { o in
                o.ignoredApps.removeAll { $0.lowercased() == app.lowercased() }
                if on { o.ignoredApps.append(app) }
            }
            return on ? "Copies from \(app) aren't kept from now on." : "Copies from \(app) are kept again."
        }
        if let pattern = args.string("pattern") {
            guard (try? NSRegularExpression(pattern: pattern)) != nil, pattern.count <= 300 else {
                throw Problem("“\(pattern)” isn't a regular expression Clipboard can read.")
            }
            h.set { o in
                o.ignoredPatterns.removeAll { $0 == pattern }
                if on { o.ignoredPatterns.append(pattern) }
            }
            return on ? "Copies matching \(pattern) aren't kept from now on." : "Copies matching \(pattern) are kept again."
        }
        if let type = args.string("type") {
            guard type.count <= 200, !type.contains(where: \.isWhitespace) else { throw Problem("A clipboard type is one word, like public.png.") }
            h.set { o in
                o.ignoredTypes.removeAll { $0 == type }
                if on { o.ignoredTypes.append(type) }
            }
            return on ? "Copies marked \(type) aren't kept from now on." : "Copies marked \(type) are kept again."
        }
        throw Problem("Say which app, pattern or clipboard type.")
    }
}
