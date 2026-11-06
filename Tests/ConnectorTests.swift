import Foundation
import Testing
@testable import ext_github_issues
@testable import ext_wikipedia
// Both have a `Paging` of their own, the same file: these use GitHub's.
private typealias Paging = ext_github_issues.Paging
import SidefolkExtensionKit

/// The two reference connectors: what they read from an answer, where the next page is, and when they say to wait.
@Suite struct ConnectorTests {
    @Test func aRepositoryIsOwnerAndNameAndNothingElse() throws {
        #expect(try Issues.repository("apple/swift") == "apple/swift")
        #expect(try Issues.repository("https://github.com/apple/swift") == "apple/swift")
        for bad in ["apple", "apple/swift/issues", "../etc", "a/..", "evil.com/x?y", "a b/c", ""] {
            #expect(throws: Problem.self, "\(bad)") { try Issues.repository(bad) }
        }
    }

    @Test func issuesLeavePullRequestsOutAndSayWhenThereIsMore() throws {
        let answer = #"[{"number": 1, "title": "Crash", "state": "open", "html_url": "https://github.com/a/b/issues/1", "updated_at": "2026-11-01", "user": {"login": "sam"}, "labels": [{"name": "bug"}]},{"number": 2, "title": "PR", "pull_request": {}}]"#
        let page = try Issues.read(Data(answer.utf8), page: 1, linkHeader: #"<https://api.github.com/x?page=2>; rel="next""#)
        #expect(page.items.count == 1 && page.items[0]["author"] as? String == "sam" && page.next == 2)
        #expect(try Issues.read(Data("[]".utf8), page: 3, linkHeader: nil).next == nil)
        #expect(throws: Problem.self) { try Issues.read(Data("{}".utf8), page: 1, linkHeader: nil) }
    }

    @Test func gitHubsLimitIsAWaitNotAFailure() {
        let now = Date(timeIntervalSince1970: 1_000)
        #expect(Issues.waitFor(status: 403, remaining: "0", reset: "1060", retryAfter: nil, now: now) == 60)
        #expect(Issues.waitFor(status: 429, remaining: nil, reset: nil, retryAfter: "30", now: now) == 30)
        #expect(Issues.waitFor(status: 403, remaining: "12", reset: "1060", retryAfter: nil, now: now) == nil, "a 403 that isn't the limit is an error")
        #expect(Issues.waitFor(status: 200, remaining: "5", reset: nil, retryAfter: "30", now: now) == nil, "a Retry-After beside an answer isn't a wait")
        #expect(Issues.waitFor(status: 429, remaining: nil, reset: nil, retryAfter: "-5", now: now) == 1)
        #expect(Issues.waitFor(status: 429, remaining: nil, reset: nil, retryAfter: "1e12", now: now) == 3600)
        #expect(Issues.waitFor(status: 403, remaining: "0", reset: "900", retryAfter: nil, now: now) == 1, "a reset gone by")
        for odd in ["inf", "nan", "-inf"] { #expect(Paging.wait(Double(odd)) == nil, "\(odd)") }
    }

    private func page(_ n: Int, next: Int?) -> ext_github_issues.Paging.Fetched {
        ext_github_issues.Paging.Fetched(items: [["n": n]], next: next, wait: nil)
    }

    @Test func pagesStopInTimeAndKeepWhatWasRead() async throws {
        var now = Date(timeIntervalSince1970: 0)
        let got = try await Paging.gather(from: 1, most: 10, clock: { now }) { at in
            now = now.addingTimeInterval(9)
            return page(at, next: at + 1)
        }
        #expect(got.pages == 3 && got.stopped == "time" && got.next == 4, "\(got.pages) \(got.stopped ?? "")")
        #expect(got.fields["next_page"] as? Int == 4 && got.fields["stopped"] as? String == "time")
    }

    @Test func aLaterPageFailingKeepsTheOnesBefore() async throws {
        struct Down: Error {}
        let got = try await Paging.gather(from: 1, most: 5) { at in
            if at == 2 { throw Down() }
            return page(at, next: at + 1)
        }
        #expect(got.items.count == 1 && got.stopped == "error" && got.next == 2)
        await #expect(throws: Down.self, "the first failing is the call failing") { try await Paging.gather(from: 1, most: 5) { _ in throw Down() } }
    }

    @Test func aWaitAfterSomePagesSaysSoWithWhatWasRead() async throws {
        let got = try await Paging.gather(from: 1, most: 5) { at in
            at == 3 ? ext_github_issues.Paging.Fetched(items: [], next: 3, wait: 40) : page(at, next: at + 1)
        }
        #expect(got.pages == 2 && got.stopped == "wait" && got.next == 3)
        #expect(got.fields["rate_limited"] as? Bool == true && got.fields["retry_after_seconds"] as? Int == 40)
    }

    @Test func whatsReadStaysUnderWhatSidefolkKeeps() async throws {
        let big = String(repeating: "x", count: 1000)
        let got = try await Paging.gather(from: 1, most: 10) { at in
            ext_github_issues.Paging.Fetched(items: (0..<30).map { ["title": big, "n": $0] }, next: at + 1, wait: nil)
        }
        let size = try JSONSerialization.data(withJSONObject: got.fields).count
        #expect(size < 256 * 1024 && got.truncated && got.next != nil, "\(size)")
        #expect(got.fields["truncated"] as? Bool == true)
    }

    @Test func wikipediaResultsAreWordsAndAddressesWithWhereTheNextPageStarts() throws {
        let answer: [String: Any] = ["continue": ["sroffset": 10], "query": ["search": [["title": "Tidal locking", "snippet": "<span class=\"searchmatch\">Tidal</span> locking &quot;is&quot;", "wordcount": 3000]]]]
        let found = try Search.read(answer, language: "en")
        #expect(found.items[0]["snippet"] as? String == "Tidal locking \"is\"")
        #expect(found.items[0]["url"] as? String == "https://en.wikipedia.org/wiki/Tidal_locking")
        #expect(found.next == 10)
        #expect(try Search.language(nil) == "en" && Search.language("zh-yue") == "zh-yue")
        for bad in ["english", "en.evil.com", "../", "e"] { #expect(throws: Problem.self, "\(bad)") { try Search.language(bad) } }
    }
}
