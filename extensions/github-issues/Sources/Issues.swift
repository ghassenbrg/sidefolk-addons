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

    /// GitHub's word that it's had enough for now: how long until it takes requests again. Only on a refusal: a Retry-After beside an answer isn't one.
    static func waitFor(status: Int, remaining: String?, reset: String?, retryAfter: String?, now: Date) -> Double? {
        guard status == 403 || status == 429 else { return nil }
        // A Retry-After that isn't a number of seconds ("nan", a date) isn't used; the reset time or a plain refusal says the rest.
        if let after = retryAfter.flatMap(Double.init).flatMap(Paging.wait) { return after }
        guard remaining == "0" || status == 429 else { return nil }
        return Paging.wait(reset.flatMap(Double.init).map { $0 - now.timeIntervalSince1970 } ?? 60)
    }

    /// The most pages one call goes through: the flow's plan never carries a cursor, so going through them here asks nothing more of the person (D202).
    static let mostPages = 10

    /// From `page`, up to `pages` of them, as one list, within what one call may take. GitHub asking to wait before the first means nothing was read.
    static func list(_ repo: String, state: String, page: Int, pages: Int) async throws -> ToolReply {
        var got = try await Paging.gather(from: page, most: min(pages, mostPages), service: "GitHub") { at, seconds in try await fetch(repo, state: state, page: at, seconds: seconds) }
        // Past what `page` takes, so not a page to go on from here.
        // Past what `page` takes, so not a page to go on from here, whatever else stopped it.
        if let next = got.next, next > 100 {
            got.next = nil
            got.stopped = "limit"
        }
        if got.pages == 0, let wait = got.wait {
            return ToolReply(L("GitHub asks to wait {time} before asking again. Nothing was read.", ["time": Format.duration(wait)])).with(data: got.fields)
        }
        let lines = got.items.prefix(60).map { "#\($0["number"].map { "\($0)" } ?? "") \($0["title"] as? String ?? "") (\($0["state"] as? String ?? ""))" }
        var text = lines.isEmpty ? L("No issues on this page.") : lines.joined(separator: "\n")
        text += Said.stopped(got)
        return ToolReply(text).with(data: got.fields)
    }

    @Sendable private static func fetch(_ repo: String, state: String, page: Int, seconds: TimeInterval) async throws -> Paging.Fetched {
        let url = Web.url("https://api.github.com/repos/\(repo)/issues", [("state", state), ("per_page", String(perPage)), ("page", String(page))])
        var request = URLRequest(url: url, timeoutInterval: seconds)
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
            return Paging.Fetched(items: [], next: page, wait: wait)
        }
        if status == 404 { throw Problem(L("GitHub has no public repository {repo}.", ["repo": repo])) }
        guard (200..<300).contains(status) else { throw Problem(L("GitHub answered with HTTP {status}.", ["status": String(status)])) }
        let found = try read(data, page: page, linkHeader: http?.value(forHTTPHeaderField: "link"))
        return Paging.Fetched(items: found.items, next: found.next, wait: nil)
    }
}

/// What a stop before the end says to a person, in words beside the fields.
enum Said {
    static func stopped(_ got: Paging.Gathered) -> String {
        var out = ""
        switch got.stopped {
        case "time": out += "\n" + L("It stopped after {count} pages to answer in time.", ["count": String(got.pages)])
        case "error": out += "\n" + L("It stopped after {count} pages: the next one didn't come.", ["count": String(got.pages)])
        case "wait": out += "\n" + L("It stopped after {count} pages: GitHub asks to wait {time}.", ["count": String(got.pages), "time": Format.duration(got.wait ?? 60)])
        case "limit": out += "\n" + L("It stopped at page 100, as far as it goes.")
        default: break
        }
        if got.truncated { out += "\n" + L("Some of what it read was left out to keep the answer small enough.") }
        if let next = got.next { out += "\n" + L("There's another page: page {page}.", ["page": String(next)]) }
        return out
    }
}
