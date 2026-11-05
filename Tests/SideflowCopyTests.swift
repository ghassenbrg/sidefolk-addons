import Foundation
import Testing
@testable import ext_sideflow
import SidefolkExtensionKit

/// Copy as a definition: the button copies, on any tab, and what it copies comes back as the same flow.
@MainActor @Suite(.serialized) struct SideflowCopyTests {
    typealias World = SideflowTests.World

    private func app(_ w: World) -> App {
        let app = App(folder: w.folder.appendingPathComponent("app"))
        app.engine.host = w.host
        return app
    }

    /// Every step there is, each with what can be written on it.
    private let everything: [String: Any] = ["trigger": ["type": "manual"], "steps": [
        ["id": "f", "name": "Ask", "form": ["title": "T", "hours": 2, "fields": [["name": "who", "label": "Who", "kind": "text", "required": true], ["name": "n", "label": "N", "kind": "number"], ["name": "c", "label": "C", "kind": "choice", "options": ["a", "b"]], ["name": "y", "label": "Y", "kind": "yes_no"]]]],
        ["id": "a", "ai": "Write {{f.who}}", "fields": ["total": "number", "who": "text"]],
        ["id": "act", "do": "reads.it", "with": ["q": "{{a.who}}", "deep": ["x": 1]], "on_failure": "carry_on", "sample": "made up"],
        ["id": "t", "text": "words “quoted” \\ and\nlines"],
        ["if": ["value": "{{a.total}}", "test": "more_than", "than": "3"], "then": [["id": "y", "text": "yes"]], "else": [["id": "n", "text": "no"]]],
        ["id": "each", "for_each": "{{act.items}}", "limit": 5, "item_failure": "collect", "steps": [["id": "one", "text": "{{item}}"]]],
        ["id": "again", "repeat": [["id": "go", "text": "{{index}}"]], "until": ["value": "{{go}}", "test": "contains", "than": "3"], "times": 4],
        ["choose": "{{f.c}}", "paths": [["when": "a", "steps": [["id": "pa", "text": "a"]]]], "else": [["id": "pe", "text": "e"]]],
        ["try": [["id": "tr", "text": "t"]], "recover": [["id": "re", "text": "{{error}}"]], "always": [["id": "al", "text": "al"]]],
        ["id": "both", "parallel": [["name": "left", "steps": [["id": "l", "text": "l"]]], ["name": "right", "steps": [["id": "r", "text": "r"]]]]],
        ["id": "called", "call_flow": "Other", "inputs": ["who": "{{f.who}}"]],
        ["run_flow": "Other"],
        ["id": "d", "data": ["op": "filter", "from": "{{act.items}}", "field": "a.b", "test": "contains", "than": "x"]],
        ["id": "w", "wait_for": ["event": "note.saved", "contains": "x", "minutes": 5]],
        ["wait_minutes": 1],
        ["id": "q", "ask": "Sure?", "options": ["Yes", "No"]],
        ["finish": "{{t}}"],
    ] as [[String: Any]]]

    private func copied(_ action: Action) -> String? {
        if case .copy(let words)? = action.act { words } else { nil }
    }

    @Test func itCopiesWithNoSecondButtonAndOnAnyTab() async throws {
        let w = try World()
        let app = app(w)
        let flow = app.newFlow(name: "Mine", body: try FlowCodec.body(everything))
        let words = try #require(copied(Pages.copyDefinition(flow)))
        #expect((JSONText.read(words) as? [String: Any])?["name"] as? String == "Mine")
        for tab in ["builder", "runs", "activity"] {
            let page = String(describing: await Pages.make(app, state: Arguments(["flow": flow.id, "tab": tab]), background: false).sent)
            #expect(page.contains("Copy as a definition"), "\(tab)")
            #expect(page.contains("copy"), "\(tab)")
            #expect(!page.contains("Its definition"), "no section to look for: \(tab)")
        }
    }

    @Test func whatItCopiesComesBackAsTheSameFlowThroughTheBox() async throws {
        let w = try World()
        let app = app(w)
        let flow = app.newFlow(name: "Mine", body: try FlowCodec.body(everything))
        let words = try #require(copied(Pages.copyDefinition(flow)))
        _ = try await Actions_UI.handle(Arguments(["op": "import", "text": words]), app)
        let back = try #require(app.store.flows().first { $0.id != flow.id })
        #expect(back.draft == flow.draft)
        #expect(back.state == .draft)
        #expect(back.live == nil)
        #expect(back.name != "Mine", "a name that's taken isn't taken over")
    }

    @Test func itCopiesWhatsOnScreenAndItsLabelSaysWhenThatIsntSaved() throws {
        let w = try World()
        let app = app(w)
        var flow = app.newFlow(name: "Mine", body: try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "a", "text": "saved"]]]))
        #expect(Pages.copyDefinition(flow).label == "Copy as a definition")
        flow.saved = flow.draft
        flow.draft = try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "a", "text": "changing"]]])
        let action = Pages.copyDefinition(flow)
        let words = try #require(copied(action))
        #expect(words.contains("changing") && !words.contains("saved"))
        #expect(action.label.contains("unsaved"), "a menu shows only the label")
        #expect(action.label.count <= 30, "and cuts it at 30")
    }

    @Test func pastWhatAPageShouldCarryItSaysSoAndCopiesNothing() throws {
        let w = try World()
        let app = app(w)
        // Counted in what a page counts in: this is far fewer characters than the limit, and more bytes.
        for long in [String(repeating: "x", count: Pages.longestCopy), String(repeating: "語", count: Pages.longestCopy / 3 + 1)] {
            let flow = app.newFlow(name: "Mine", body: try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "a", "text": long]]]))
            let action = Pages.copyDefinition(flow)
            #expect(copied(action) == nil)
            #expect(action.disabled)
            #expect(action.label.contains("Too long"))
            #expect(copied(Pages.copyWords(flow, app)) == nil, "the words beside it too")
        }
        // Words that double when a page carries them, like a pasted definition.
        let quoted = app.newFlow(name: "Quoted", body: try FlowCodec.body(["trigger": ["type": "manual"], "steps": [["id": "a", "text": String(repeating: "\"", count: Pages.longestCopy * 2 / 3)]]]))
        #expect(copied(Pages.copyDefinition(quoted)) == nil)
    }
}
