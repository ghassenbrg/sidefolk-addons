import Foundation

/// Going through a service's pages inside one call (D202), within what one call may take: Sidefolk gives a tool 30 seconds, and keeps an answer's fields only up to 256 KB.
/// What was read is never thrown away: stopping early says why and where to go on. (The same file in each connector.)
enum Paging {
    /// Plain values from JSON, made in one task and read in another, never shared while changing.
    struct Fetched: @unchecked Sendable {
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

    /// Well under the call's 30 seconds: no page starts that couldn't end by then, and each gets only the time that's left.
    static let deadline: TimeInterval = 24
    static let longestPage: TimeInterval = 8
    static let mostBytes = 150_000

    /// What a service said to wait, as a number of seconds Sidefolk can use: none if it's not a number, 1 at the least and an hour at the most.
    static func wait(_ seconds: Double?) -> Double? {
        guard let seconds, seconds.isFinite else { return nil }
        return min(max(seconds, 1), 3600)
    }

    struct OutOfTime: Error {}

    /// `fetch` gets the page and how long it may take, which it gives its request; the page is also stopped at that time, however slowly it trickles in.
    static func gather(from start: Int, most: Int, clock: @escaping () -> Date = Date.init, fetch: @escaping @Sendable (Int, TimeInterval) async throws -> Fetched) async throws -> Gathered {
        var out = Gathered(next: start), bytes = 0
        let began = clock()
        while let at = out.next, out.pages < max(most, 1) {
            let left = deadline - clock().timeIntervalSince(began)
            if out.pages > 0, left < longestPage {
                out.stopped = "time"
                break
            }
            let one: Fetched
            do { one = try await within(min(longestPage, max(left, 1))) { try await fetch(at, min(longestPage, max(left, 1))) } } catch {
                // The first page failing is the call failing; a later one leaves what came before.
                guard out.pages > 0 else { throw error }
                out.stopped = error is OutOfTime ? "time" : "error"
                break
            }
            if let wait = one.wait {
                out.wait = wait
                if out.pages > 0 { out.stopped = "wait" }
                break
            }
            let sizes = one.items.map { (try? JSONSerialization.data(withJSONObject: $0))?.count ?? 0 }
            // A page that doesn't fit stays for next time, whole: where to go on is that page, so nothing is skipped.
            if out.pages > 0, bytes + sizes.reduce(0, +) > mostBytes {
                out.truncated = true
                out.next = at
                break
            }
            // Only a first page too big on its own is cut, by whole items, and then it says so.
            for (item, size) in zip(one.items, sizes) {
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

    /// The work, or `OutOfTime` once these seconds are up.
    static func within<T: Sendable>(_ seconds: TimeInterval, _ work: @escaping @Sendable () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await work() }
            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                throw OutOfTime()
            }
            defer { group.cancelAll() }
            guard let first = try await group.next() else { throw OutOfTime() }
            return first
        }
    }
}
