import Foundation
import Testing
@testable import ext_sideflow
import SidefolkExtensionKit

/// The later list's narrow ones: practice's made-up words, a practice's one go, and a pause at the wrong moment.
@MainActor @Suite(.serialized) struct SideflowLaterNarrowTests {
    typealias World = SideflowTests.World

    @Test func madeUpWordsInOtherWordsAreStillMadeUp() {
        var values = Values()
        values.set("t", "Hello \(L("(sample)")) there")
        #expect(values.pretends("{{t}}"))
        values.set("u", "Hello there")
        #expect(!values.pretends("{{u}}"))
    }

    @Test func aPracticesOneGoThatMadeNothingDoesntStopWhatComesAfter() async throws {
        let w = try World()
        let flow = try w.flow([
            ["id": "again", "repeat": [["id": "b", "if": ["value": "a", "test": "is", "than": "b"], "then": [["id": "x", "text": "x"]], "else": []]], "until": ["value": "{{index}}", "test": "is", "than": "3"], "times": 3],
            ["id": "after", "text": "{{again}}"],
        ], state: .draft)
        let run = try #require(w.engine.start(flow, mode: .practice, why: "t"))
        await w.quiet()
        #expect(w.store.run(run.id)?.status == .done, "\(w.store.run(run.id)?.problem ?? "")")
    }
}
