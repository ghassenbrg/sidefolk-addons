import Foundation
import SidefolkExtensionKit

/// The real Sidefolk, through the Kit.
@MainActor final class SidefolkHost: FlowHost {
    func call(_ tool: String, _ input: [String: Any], plan: String?, written: [String: Any]?) async -> Actions.Outcome {
        await Actions.call(tool, input, plan: plan, written: written, seconds: tool == "ask.user" ? 615 : 300)
    }

    private var requests: [String: String] = [:]

    func call(_ tool: String, _ input: [String: Any], plan: String?, written: [String: Any]?, run: String, counted: String, progress: @escaping (Actions.Progress) -> Void) async -> Actions.Outcome {
        defer { requests[run] = nil }
        return await Actions.call(tool, input, plan: plan, written: written, seconds: tool == "ask.user" ? 615 : 300, run: counted, request: { [weak self] in self?.requests[run] = $0 }, progress: progress)
    }

    func cancel(run: String) {
        if let request = requests[run] { Actions.cancel(request) }
    }

    func check(_ tool: String, _ input: [String: Any], plan: String?) async -> Actions.Check? {
        await Actions.check(tool, input, plan: plan)
    }

    func write(_ prompt: String, label: String) async -> AI.Result {
        guard AI.available != nil else { return .refused("off") }
        // Past Sidefolk's own limit: given up on sooner, its request would still be in the air and the next turn refused.
        return await AI.ask(prompt, label: label, seconds: 130)
    }

    func approve(_ plan: Plan) async -> Plans.Answer { await Plans.approve(plan) }
    func checkPlan(_ plan: Plan) async -> Plans.Checked? { await Plans.check(plan) }
    func forgetPlan(_ id: String) { Plans.forget(id) }

    func notify(title: String, body: String?, attention: Bool) async {
        var input: [String: Any] = ["title": title, "level": attention ? "attention" : "gentle"]
        if let body { input["body"] = body }
        let first = await Actions.call("notify.user", input, seconds: 30)
        // A long loop can use up the minute's calls, and this may be what says another flow stopped.
        guard first.status == .busy else { return }
        try? await Task.sleep(for: .seconds(Engine.busyWait))
        _ = await Actions.call("notify.user", input, seconds: 30)
    }
}
