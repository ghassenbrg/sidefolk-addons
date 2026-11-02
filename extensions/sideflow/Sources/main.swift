import Foundation
import SidefolkExtensionKit

// Sideflow: teach your companion a routine. A flow is something you could read aloud; it practises first, you read what it will do, and from
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
Plans.ended = { plan in
    guard plan.hasPrefix("flow-"), var flow = app.store.flow(String(plan.dropFirst(5))) else { return }
    flow.state = .paused
    flow.pausedBecause = L("You ended what you'd allowed in Settings, so it asks again before running.")
    flow.live = nil
    app.store.save(flow)
}

ext.background { await app.run() }

await ext.serve()
