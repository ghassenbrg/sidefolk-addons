import Foundation
import SidefolkExtensionKit

/// Wikipedia's own search, read only, in the language asked for: a page of results at a time, with where the next page starts.
enum Search {
    static let perPage = 10

    /// A Wikipedia's language as its address has it: `en`, `fr`, `pt`, `zh-yue`.
    static func language(_ text: String?) throws -> String {
        let code = (text ?? "en").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard code.range(of: #"^[a-z]{2,3}(-[a-z]{2,8})?$"#, options: .regularExpression) != nil else { throw Problem(L("Give a language code, like en or fr.")) }
        return code
    }

    /// Search's highlighting is HTML: its words without the tags, and its few entities read.
    static func plain(_ html: String) -> String {
        var out = html.replacingOccurrences(of: #"<[^>]{0,200}>"#, with: "", options: .regularExpression)
        for (entity, char) in [("&quot;", "\""), ("&#039;", "'"), ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"), ("&nbsp;", " ")] { out = out.replacingOccurrences(of: entity, with: char) }
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func read(_ object: [String: Any], language: String) throws -> (items: [[String: Any]], next: Int?) {
        guard let query = object["query"] as? [String: Any], let results = query["search"] as? [[String: Any]] else { throw Problem(L("Wikipedia sent something that isn't a list of results.")) }
        let items: [[String: Any]] = results.map { r in
            let title = r["title"] as? String ?? ""
            let address = "https://\(language).wikipedia.org/wiki/" + (title.replacingOccurrences(of: " ", with: "_").addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "")
            return ["title": title, "snippet": plain(r["snippet"] as? String ?? ""), "url": address, "words": r["wordcount"] ?? NSNull()]
        }
        let next = ((object["continue"] as? [String: Any])?["sroffset"] as? NSNumber)?.intValue
        return (items, next)
    }

    static let mostPages = 5

    /// From `offset`, up to `pages` pages, as one list, within what one call may take (D202). Busy before the first means nothing was read.
    static func find(_ words: String, language: String, from offset: Int, pages: Int) async throws -> ToolReply {
        let got = try await Paging.gather(from: offset, most: min(pages, mostPages), service: "Wikipedia") { at, seconds in try await fetch(words, language: language, from: at, seconds: seconds) }
        if got.pages == 0, let wait = got.wait {
            return ToolReply(L("Wikipedia asks to wait {time} before asking again. Nothing was read.", ["time": Format.duration(wait)])).with(data: got.fields)
        }
        var text = got.items.isEmpty ? L("Nothing found.") : got.items.prefix(50).map { "\($0["title"] as? String ?? ""): \($0["snippet"] as? String ?? "")" }.joined(separator: "\n")
        switch got.stopped {
        case "time": text += "\n" + L("It stopped after {count} pages to answer in time.", ["count": String(got.pages)])
        case "error": text += "\n" + L("It stopped after {count} pages: the next one didn't come.", ["count": String(got.pages)])
        case "wait": text += "\n" + L("It stopped after {count} pages: Wikipedia asks to wait {time}.", ["count": String(got.pages), "time": Format.duration(got.wait ?? 5)])
        default: break
        }
        if got.truncated { text += "\n" + L("Some of what it read was left out to keep the answer small enough.") }
        if let next = got.next { text += "\n" + L("There are more: the next page starts at {offset}.", ["offset": String(next)]) }
        return ToolReply(text).with(data: got.fields)
    }

    @Sendable private static func fetch(_ words: String, language: String, from offset: Int, seconds: TimeInterval) async throws -> Paging.Fetched {
        let url = Web.url("https://\(language).wikipedia.org/w/api.php", [("action", "query"), ("list", "search"), ("srsearch", words), ("format", "json"),
                                                                          ("srlimit", String(perPage)), ("sroffset", String(offset)), ("maxlag", "5")])
        var request = URLRequest(url: url, timeoutInterval: seconds)
        request.setValue("Sidefolk/1.0 (a Mac companion)", forHTTPHeaderField: "User-Agent")
        let (data, response): (Data, URLResponse)
        do { (data, response) = try await URLSession.shared.data(for: request) } catch {
            throw Problem(L("Couldn't reach Wikipedia ({error}). Check the internet connection.", ["error": error.localizedDescription]))
        }
        let http = response as? HTTPURLResponse
        let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        // Busy, as Wikipedia says with `maxlag` or a 429: nothing was read, and how long to wait.
        if http?.statusCode == 429 || (object["error"] as? [String: Any])?["code"] as? String == "maxlag" {
            return Paging.Fetched(items: [], next: offset, wait: Paging.wait(http?.value(forHTTPHeaderField: "retry-after").flatMap(Double.init)) ?? 5)
        }
        guard let status = http?.statusCode, (200..<300).contains(status) else { throw Problem(L("Wikipedia answered with HTTP {status}.", ["status": String(http?.statusCode ?? 0)])) }
        let found = try read(object, language: language)
        return Paging.Fetched(items: found.items, next: found.next, wait: nil)
    }
}
