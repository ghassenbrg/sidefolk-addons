import SidefolkExtensionKit

// The time left, as a bar that empties (TimerBar): Sidefolk keeps the clock and sends `.timeout`, and runs the bar by itself,
// so nothing is streamed. Hurry, not danger: the last five seconds turn warm, as a second bar fading in.
extension BoardDrawing {
    func startClock(id: String, seconds: Double) {
        guard !timers.contains(where: { $0.id == id }) else { return }
        timers.append((id, seconds * 1000))
    }

    func timerBar(id: String, seconds: Double, width: Double) -> Node {
        let ms = seconds * 1000, warmAt = max(ms - 5000, 0)
        // Named: the next scene with the same clock carries on rather than starting again. Essential: time doesn't stop for Reduce Motion.
        anims.append(Anim.to("timer.fill", ["sx": 0], ms: ms, ease: "linear").essential().named("timer_\(id)"))
        anims.append(Anim.sequence([.wait(ms: warmAt), .to("timer.warm", ["opacity": 1], ms: 200, ease: "linear")]).essential().named("timer_\(id)_warm"))
        return Node.box("timer", w: width, h: 5) {
            Node.capsule(fill: .surfaceSunken).id("timer.track").size(width, 5)
            Node.box("timer.fill", w: width, h: 5) {
                Node.capsule(fill: .accent).size(width, 5)
                Node.capsule(fill: .hex("#FF8A3D")).id("timer.warm").size(width, 5).opacity(0)
            }.anchor(0, 0.5)
        }.label(L("{n} seconds left", ["n": Int(seconds.rounded(.up))]))
    }
}
