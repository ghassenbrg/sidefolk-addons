import Foundation
import SidefolkExtensionKit

// Noor, an Islamic companion: prayer times by calculation or from a mosque's own timetable, the Hijri calendar, the Qibla bearing, the Names, and a Ramadan planner, in one Home page. Everything that
// is Noor's lives in this pack; what it needs of Sidefolk are general abilities (D105–D108). It adds nothing while it is off, and all its reminders start off.
let ext = Extension(name: "prayer-times", version: "1.0.0")

NoorTools.install(on: ext)

ext.page("noor") { args in
    ImportHolding.restore(into: NoorModel.shared)
    NoorTools.placeMoved()
    return await NoorPage.render(args)
}

ext.planOccurrences { _ in
    let model = NoorModel.shared
    NoorTools.placeMoved()
    model.freshen()
    await model.settle(ms: 15_000)
    // No plan is better than a plan without today's days: Sidefolk keeps the one it has when this says it can't make one.
    guard model.planIsReady else { throw Problem("The days a plan needs aren't here yet.") }
    return PlanWords.plan(model: model)
}

ext.placeChanged { NoorTools.placeMoved() }

await ext.serve()
