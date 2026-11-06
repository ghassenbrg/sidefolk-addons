import Foundation
import Testing
@testable import ext_github_issues
@testable import ext_wikipedia
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
        #expect(Issues.waitFor(status: 200, remaining: "5", reset: nil, retryAfter: nil, now: now) == nil)
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
