import Foundation
import SidefolkExtensionKit

// Sideflow: teach your companion a routine. A flow is something you could read aloud; it practices first, you read what it will do, and from
// then on it runs by itself under exactly that. All of it lives here: the model, the engine, its words and its screens. From Sidefolk it uses only
// what any extension can: its tools through Guard (`permissions.act`), plans the person reads, the person's AI, a page.
let ext = Extension(name: "sideflow")
let folder = URL(fileURLWithPath: Paths.data, isDirectory: true)
let app = App(folder: folder)

FlowTools.register(ext, app)

ext.page("flows") { args in await Pages.make(app, state: args.pageState, background: args.pageIsBackground) }

ext.on("sidefolk/watch.fired") { args in
    app.engine.watchFired(title: args.string("title") ?? "", summary: args.string("summary") ?? "")
}
ext.on("sidefolk/happened") { args in
    app.engine.happened(name: args.string("name") ?? "", title: args.string("title"), detail: args.string("detail"), id: args.string("id"))
}
ext.palette("run", query: { words in
    let wanted = words.trimmed.lowercased()
    let flows = app.store.flows().filter { wanted.isEmpty || $0.name.lowercased().contains(wanted) }
    return PaletteList(flows.map { PaletteItem(id: $0.id, title: $0.name, detail: Words.triggers($0.running), kind: .text) }, note: flows.isEmpty ? L("No flows called that.") : nil)
}, choose: { id, _ in
    guard let flow = app.store.flow(id) else { return PaletteChoice(message: L("That flow is gone.")) }
    // What this would run: what's on, or what was saved, not what's being typed.
    let problems = flow.kept.problems(app.catalog)
    guard problems.isEmpty else { return PaletteChoice(message: L("To fix first: {list}", ["list": problems.map(\.text).joined(separator: " ")])) }
    guard flow.state != .paused else { return PaletteChoice(message: L("“{name}” is paused. Ask the person to resume it first.", ["name": flow.name])) }
    // Choosing here isn't a click on a card's words, and there's nowhere here to read one: what's new is read on its page.
    guard flow.live == flow.kept, app.catalog.plan(flow.planId) != nil || !Engine.needsCard(flow.kept) else {
        return PaletteChoice(message: L("“{name}” has something new to allow first. Open it to run it.", ["name": flow.name]))
    }
    Task { await app.engine.runNow(flow.id, why: L("You asked for it.")) }
    return PaletteChoice(close: true, message: L("Running “{name}”.", ["name": flow.name]))
})
Plans.ended = { plan in
    guard plan.hasPrefix("flow-") else { return }
    app.engine.planEnded(String(plan.dropFirst(5)))
}

ext.background { await app.run() }

await ext.serve()
