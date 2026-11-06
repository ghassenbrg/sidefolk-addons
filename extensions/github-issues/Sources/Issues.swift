import Foundation
import SidefolkExtensionKit

/// Public GitHub, read only and with no account: a repository's issues, a page at a time. What GitHub says about its limit comes back as fields, so a flow waits rather than fails.
enum Issues {
    static let perPage = 30

    struct Page {
        var items: [[String: Any]]
        var next: Int?
    }

    /// `owner/name`, as GitHub writes it, and nothing that could be another address.
    static func repository(_ text: String) throws -> String {
        let plain = text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "https://github.com/", with: "")
        guard plain.range(of: #"^[A-Za-z0-9_.-]{1,39}/[A-Za-z0-9_.-]{1,100}$"#, options: .regularExpression) != nil, !plain.contains("..") else {
            throw Problem(L("Give the repository as owner/name, like apple/swift."))
        }
        return plain
    }

    /// What GitHub answered: issues only (pull requests come in the same list), and whether there's another page.
    static func read(_ data: Data, page: Int, linkHeader: String?) throws -> Page {
        guard let list = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { throw Problem(L("GitHub sent something that isn't a list of issues.")) }
        let items: [[String: Any]] = list.filter { $0["pull_request"] == nil }.map { issue in
            var out: [String: Any] = ["number": issue["number"] ?? NSNull(), "title": issue["title"] as? String ?? "", "state": issue["state"] as? String ?? "",
                                      "url": issue["html_url"] as? String ?? "", "updated": issue["updated_at"] as? String ?? ""]
            if let user = issue["user"] as? [String: Any], let login = user["login"] as? String { out["author"] = login }
            out["labels"] = (issue["labels"] as? [[String: Any]] ?? []).compactMap { $0["name"] as? String }
            return out
        }
        let more = linkHeader?.contains("rel=\"next\"") == true
        return Page(items: items, next: more ? page + 1 : nil)
    }

    /// GitHub's word that it's had enough for now: how long until it takes requests again.
    static func waitFor(status: Int, remaining: String?, reset: String?, retryAfter: String?, now: Date) -> Double? {
        if let after = retryAfter.flatMap(Double.init) { return after }
        guard status == 403 || status == 429, remaining == "0" || status == 429 else { return nil }
        let until = reset.flatMap(Double.init).map { $0 - now.timeIntervalSince1970 } ?? 60
        return max(1, until)
    }

    static func list(_ repo: String, state: String, page: Int) async throws -> ToolReply {
        let url = Web.url("https://api.github.com/repos/\(repo)/issues", [("state", state), ("per_page", String(perPage)), ("page", String(page))])
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue("Sidefolk/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, response): (Data, URLResponse)
        do { (data, response) = try await URLSession.shared.data(for: request) } catch {
            throw Problem(L("Couldn't reach GitHub ({error}). Check the internet connection.", ["error": error.localizedDescription]))
        }
        let http = response as? HTTPURLResponse
        let status = http?.statusCode ?? 0
        if let wait = waitFor(status: status, remaining: http?.value(forHTTPHeaderField: "x-ratelimit-remaining"), reset: http?.value(forHTTPHeaderField: "x-ratelimit-reset"),
                              retryAfter: http?.value(forHTTPHeaderField: "retry-after"), now: Date()) {
            // Nothing was read: said in words for a person, and in fields for a flow, which waits and asks again.
            return ToolReply(L("GitHub asks to wait {time} before asking again. Nothing was read.", ["time": Format.duration(wait)])).with(data: ["rate_limited": true, "retry_after_seconds": Int(wait.rounded(.up))])
        }
        if status == 404 { throw Problem(L("GitHub has no public repository {repo}.", ["repo": repo])) }
        guard (200..<300).contains(status) else { throw Problem(L("GitHub answered with HTTP {status}.", ["status": String(status)])) }
        let found = try read(data, page: page, linkHeader: http?.value(forHTTPHeaderField: "link"))
        let lines = found.items.prefix(30).map { "#\($0["number"].map { "\($0)" } ?? "") \($0["title"] as? String ?? "") (\($0["state"] as? String ?? ""))" }
        var text = lines.isEmpty ? L("No issues on this page.") : lines.joined(separator: "\n")
        if found.next != nil { text += "\n" + L("There's another page: page {page}.", ["page": String(page + 1)]) }
        var data: [String: Any] = ["items": found.items, "count": found.items.count, "page": page]
        if let next = found.next { data["next_page"] = next }
        return ToolReply(text).with(data: data)
    }
}
