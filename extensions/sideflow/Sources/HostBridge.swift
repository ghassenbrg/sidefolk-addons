import Foundation
import SidefolkExtensionKit

/// The real Sidefolk, through the Kit.
@MainActor final class SidefolkHost: FlowHost {
    func call(_ tool: String, _ input: [String: Any], plan: String?, written: [String: Any]?) async -> Actions.Outcome {
        await Actions.call(tool, input, plan: plan, written: written, seconds: tool == "ask.user" ? 615 : 300)
    }

    func check(_ tool: String, _ input: [String: Any], plan: String?) async -> Actions.Check? {
        await Actions.check(tool, input, plan: plan)
    }

    func write(_ prompt: String, label: String) async -> AI.Result {
        guard AI.available != nil else { return .refused("off") }
        return await AI.ask(prompt, label: label)
    }

    func approve(_ plan: Plan) async -> Plans.Answer { await Plans.approve(plan) }
    func forgetPlan(_ id: String) { Plans.forget(id) }

    func notify(title: String, body: String?, attention: Bool) async {
        var input: [String: Any] = ["title": title, "level": attention ? "attention" : "gentle"]
        if let body { input["body"] = body }
        _ = await Actions.call("notify.user", input, seconds: 30)
    }
}
