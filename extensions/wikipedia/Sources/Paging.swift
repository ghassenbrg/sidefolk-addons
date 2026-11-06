import Foundation

/// Going through a service's pages inside one call (D202), within what one call may take: Sidefolk gives a tool 30 seconds, and keeps an answer's fields only up to 256 KB.
/// What was read is never thrown away: stopping early says why and where to go on. (The same file in each connector.)
enum Paging {
    struct Fetched {
        var items: [[String: Any]]
        var next: Int?
        /// The service asked to wait this long, and nothing on this page was read.
        var wait: Double?
    }

    struct Gathered {
        var items: [[String: Any]] = []
        var next: Int?
        var pages = 0
        /// Why it stopped before the last page it was asked for: "time", "error" or "wait".
        var stopped: String?
        var wait: Double?
        /// Some of what was read was left out to fit, and `next` goes on from after it.
        var truncated = false

        var fields: [String: Any] {
            var out: [String: Any] = ["items": items, "count": items.count, "pages": pages]
            if let next { out["next_page"] = next }
            if let stopped { out["stopped"] = stopped }
            if truncated { out["truncated"] = true }
            if let wait { out["rate_limited"] = true; out["retry_after_seconds"] = Int(wait.rounded(.up)) }
            return out
        }
    }

    /// Well under the call's 30 seconds, so a slow page still leaves time to answer with what was read.
    static let deadline: TimeInterval = 22
    static let mostBytes = 150_000

    /// What a service said to wait, as a number of seconds Sidefolk can use: none if it's not a number, 1 at the least and an hour at the most.
    static func wait(_ seconds: Double?) -> Double? {
        guard let seconds, seconds.isFinite else { return nil }
        return min(max(seconds, 1), 3600)
    }

    static func gather(from start: Int, most: Int, clock: () -> Date = Date.init, fetch: (Int) async throws -> Fetched) async throws -> Gathered {
        var out = Gathered(next: start), bytes = 0
        let began = clock()
        while let at = out.next, out.pages < max(most, 1) {
            if out.pages > 0, clock().timeIntervalSince(began) > deadline {
                out.stopped = "time"
                break
            }
            let one: Fetched
            do { one = try await fetch(at) } catch {
                // The first page failing is the call failing; a later one leaves what came before.
                guard out.pages > 0 else { throw error }
                out.stopped = "error"
                break
            }
            if let wait = one.wait {
                out.wait = wait
                if out.pages > 0 { out.stopped = "wait" }
                break
            }
            for item in one.items {
                let size = (try? JSONSerialization.data(withJSONObject: item))?.count ?? 0
                guard bytes + size <= mostBytes else {
                    out.truncated = true
                    break
                }
                bytes += size
                out.items.append(item)
            }
            out.pages += 1
            out.next = one.next
            if out.truncated { break }
        }
        return out
    }
}
