import Foundation
import Testing
@testable import ext_currency
@testable import ext_dev_toolbox
@testable import ext_feeds
@testable import ext_playtime

/// The add-on extensions' own logic, read directly with canned data: their words, their parsers. Nothing here starts a
/// process or reaches the network. (Moved from sidefolk's ShippedExtensionLogicTests with the extensions, D55.)
struct ExtensionLogicTests {
    @Test func currencyReadsTheECBFile() throws {
        let xml = """
            <gesmes:Envelope><Cube><Cube time='2026-10-27'>
            <Cube currency='USD' rate='1.1150'/><Cube currency='JPY' rate='175.97'/><Cube currency='GBP' rate='0.8366'/>
            </Cube></Cube></gesmes:Envelope>
            """
        let table = try Rates.parse(xml)
        #expect(table.day == "2026-10-27")
        #expect(table.perEuro == ["EUR": 1, "USD": 1.115, "JPY": 175.97, "GBP": 0.8366])
        #expect(abs(Rates.rate("USD", "JPY", in: table) - 175.97 / 1.115) < 1e-9)
        #expect(Rates.money(1234.5) == "1,234.50")
        #expect(Rates.rateText(0.896861) == "0.8969")
        #expect(throws: (any Error).self) { try Rates.parse("<html>maintenance</html>") }
    }
    @Test func feedsReadRSSAtomAndFindTheFeedOfASite() throws {
        let rss = Parser.parse(Data("""
            <rss version="2.0"><channel><title>Tea Blog</title>
            <item><title>Green tea</title><link>https://tea.example/green</link><pubDate>Tue, 27 Oct 2026 09:00:00 GMT</pubDate></item>
            <item><title><![CDATA[Oolong & more]]></title><link>https://tea.example/oolong</link></item>
            </channel></rss>
            """.utf8))
        #expect(rss.isFeed && rss.title == "Tea Blog")
        #expect(rss.items.map(\.title) == ["Green tea", "Oolong & more"])
        #expect(rss.items.first?.date == "Tue, 27 Oct 2026 09:00:00 GMT")
        let atom = Parser.parse(Data("""
            <feed xmlns="http://www.w3.org/2005/Atom"><title>Notes</title>
            <entry><title>Hello</title><link rel="alternate" href="https://notes.example/hello"/><updated>2026-10-27T10:00:00Z</updated></entry>
            </feed>
            """.utf8))
        #expect(atom.items.first?.link == "https://notes.example/hello" && atom.items.first?.date == "2026-10-27T10:00:00Z")
        let html = #"<head><link rel="alternate" type="application/rss+xml" title="Feed" href="/feed.xml?a=1&amp;b=2"></head>"#
        #expect(Feeds.discover(html, base: URL(string: "https://tea.example/blog")!)?.absoluteString == "https://tea.example/feed.xml?a=1&b=2")
        #expect(!Parser.parse(Data("<html><body>No feed</body></html>".utf8)).isFeed)
    }
    @Test func devToolboxConversions() throws {
        #expect(try Toolbox.transform("json_pretty", #"{"b":1,"a":[1,2]}"#) == "{\n  \"a\" : [\n    1,\n    2\n  ],\n  \"b\" : 1\n}")
        #expect(try Toolbox.transform("json_minify", "{ \"a\" : \"x/y\" }") == #"{"a":"x/y"}"#)
        #expect(throws: (any Error).self, "Foundation accepts it; JSON doesn't") { try Toolbox.transform("json_pretty", #"[1, 2,]"#) }
        #expect(Toolbox.trailingComma(#"{"s":"a,]","t":[1]}"#) == nil, "a comma inside a string is text")
        #expect(try Toolbox.transform("base64_decode", "aGVsbG8gd29ybGQ") == "hello world", "URL-safe, no padding")
        #expect(try Toolbox.transform("url_encode", "a b&c=d") == "a%20b%26c%3Dd")
        #expect(try Toolbox.transform("hex_decode", try Toolbox.transform("hex_encode", "Sidefolk")) == "Sidefolk")
        #expect(try Toolbox.transform("md5", "") == "d41d8cd98f00b204e9800998ecf8427e")
        let jwt = try Toolbox.transform("jwt_decode", "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjMiLCJleHAiOjE3MDAwMDAwMDB9.sig")
        #expect(jwt.contains("\"sub\" : \"123\"") && jwt.contains("Expires: 2023-11-14T22:13:20Z (expired)"), "\(jwt)")
        #expect(try Toolbox.timestamp("1700000000000").contains("UTC: 2023-11-14T22:13:20Z"), "milliseconds are recognised")
        #expect(try Toolbox.transform("count", "one two\nthree") == "13 characters, 3 words, 2 lines, 13 bytes in UTF-8.")
    }
    @Test func playtimeQuestionsAndPicks() throws {
        #expect(Trivia.bank.count >= 50)
        #expect(Set(Trivia.bank.map(\.text)).count == Trivia.bank.count, "no question twice")
        #expect(Trivia.categories.count >= 8)
        for q in Trivia.bank {
            #expect(q.choices.count == 4 && (0..<4).contains(q.answer) && Set(q.choices).count == 4 && !q.fact.isEmpty, "\(q.text)")
        }
        let number = try Chance.number(3, 3)
        #expect(number == "Picked 3 (from 3 to 3).")
        #expect(throws: (any Error).self) { try Chance.number(5, 1) }
        #expect(try Chance.pick(["tea"], count: 1) == "Picked: tea.")
        #expect(throws: (any Error).self) { try Chance.pick(["tea"], count: 2) }
    }
}
