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

    static func find(_ words: String, language: String, from offset: Int) async throws -> ToolReply {
        let url = Web.url("https://\(language).wikipedia.org/w/api.php", [("action", "query"), ("list", "search"), ("srsearch", words), ("format", "json"),
                                                                          ("srlimit", String(perPage)), ("sroffset", String(offset)), ("maxlag", "5")])
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue("Sidefolk/1.0 (a Mac companion)", forHTTPHeaderField: "User-Agent")
        let (data, response): (Data, URLResponse)
        do { (data, response) = try await URLSession.shared.data(for: request) } catch {
            throw Problem(L("Couldn't reach Wikipedia ({error}). Check the internet connection.", ["error": error.localizedDescription]))
        }
        let http = response as? HTTPURLResponse
        let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        // Busy, as Wikipedia says with `maxlag` or a 429: nothing was read, and how long to wait.
        if http?.statusCode == 429 || (object["error"] as? [String: Any])?["code"] as? String == "maxlag" {
            let wait = http?.value(forHTTPHeaderField: "retry-after").flatMap(Double.init) ?? 5
            return ToolReply(L("Wikipedia asks to wait {time} before asking again. Nothing was read.", ["time": Format.duration(wait)])).with(data: ["rate_limited": true, "retry_after_seconds": Int(wait.rounded(.up))])
        }
        guard let status = http?.statusCode, (200..<300).contains(status) else { throw Problem(L("Wikipedia answered with HTTP {status}.", ["status": String(http?.statusCode ?? 0)])) }
        let found = try read(object, language: language)
        var text = found.items.isEmpty ? L("Nothing found.") : found.items.map { "\($0["title"] as? String ?? ""): \($0["snippet"] as? String ?? "")" }.joined(separator: "\n")
        if let next = found.next { text += "\n" + L("There are more: the next page starts at {offset}.", ["offset": String(next)]) }
        var fields: [String: Any] = ["items": found.items, "count": found.items.count]
        if let next = found.next { fields["next_page"] = next }
        return ToolReply(text).with(data: fields)
    }
}
