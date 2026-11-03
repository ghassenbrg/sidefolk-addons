import Foundation
import Testing
@testable import SidefolkExtensionKit
@testable import ext_playtime

/// Daily Word: letters typed while a played row turns aren't lost, and typing doesn't restart or shorten the turning.
@Suite(.serialized) @MainActor
struct PlaytimeTypeAheadTests {
    private func clear() {
        try? FileManager.default.removeItem(atPath: PlayTable.folder)
        PlaytimeRecords.update { $0 = PlaytimeRecords() }
    }

    private func key(_ session: String, _ id: String, _ character: String? = nil) -> Scene {
        var key: [String: Any] = ["id": id]
        if let character { key["char"] = character }
        return PlayTable.move(SurfaceRequest(["session": session, "move": ["key": key]]))
    }

    private func next(_ session: String) -> Scene { PlayTable.move(SurfaceRequest(["session": session, "move": ["next": true]])) }

    private func text(_ scene: Scene) -> String { String(decoding: (try? JSONSerialization.data(withJSONObject: scene.json)) ?? Data(), as: UTF8.self) }

    private func word(_ session: String, _ letters: String) -> Scene {
        for c in letters { _ = key(session, "letter", String(c)) }
        return key(session, "draft_return")
    }

    @Test func lettersTypedDuringTheTurnBecomeTheNextWord() throws {
        clear()
        defer { clear() }
        try Language.with("en", strings: PlaytimeGameTests.strings) {
            let session = PlayTable.open(SurfaceRequest(["session": "", "arguments": ["game": "daily_word"]])).session
            let turning = word(session, "crane")
            let waited = try #require(turning.json["after_ms"] as? Int)
            #expect(text(turning).contains("\"letter\""), "the keyboard listens while the row turns")
            let during = key(session, "letter", "s")
            let left = try #require(during.json["after_ms"] as? Int)
            #expect(left <= waited, "the turning ends when it would have")
            #expect(left >= 100, "Sidefolk takes nothing shorter: the wait would never end")
            let names = Set((turning.json["animations"] as? [[String: Any]] ?? []).compactMap { $0["id"] as? String }.filter { $0.hasPrefix("turn_") })
            #expect(names.count == 10, "two named per tile, so typing doesn't restart them")
            #expect(names == Set((during.json["animations"] as? [[String: Any]] ?? []).compactMap { $0["id"] as? String }.filter { $0.hasPrefix("turn_") }))
            #expect(text(during).contains("\"S\"") || text(during).contains("\"s\""), "it shows in the next row at once")
            _ = key(session, "letter", "x")
            _ = key(session, "draft_delete")
            _ = key(session, "letter", "l")
            let settled = next(session)
            #expect(text(settled).contains("\"S\"") || text(settled).contains("\"s\""))
            #expect(text(settled).contains("\"L\"") || text(settled).contains("\"l\""))
            #expect(!(text(settled).contains("\"X\"") && !text(turning).contains("\"X\"")), "the deleted one stays deleted")
            // On from what was typed.
            let after = word(session, "ate")
            #expect(after.json["after_ms"] as? Int != nil, "slate was played as one word")
        }
    }
}
