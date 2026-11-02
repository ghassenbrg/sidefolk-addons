import Foundation
import SidefolkExtensionKit

/// The functional dial: one civil day once round, every mark at the angle of its real instant (`DialGeometry`). It never mirrors: time doesn't read right to left.
@MainActor
enum DialScene {
    /// What the middle says, from the snapshot's focus. The same words Today and Ask use.
    struct Focus {
        var eyebrow: String
        var title: String
        var time: String
        var countdown: String
        var below: String?
    }

    static func focus(_ snapshot: NoorSnapshot) -> Focus? {
        let zone = snapshot.source?.zone ?? snapshot.place?.zone ?? .current
        switch snapshot.next {
        case .prayerStart(let id, let at, let day):
            let tomorrow = snapshot.localDate.map { day != $0 } ?? false
            return Focus(eyebrow: tomorrow ? L("Tomorrow") : L("Next prayer"), title: Words.prayer(id), time: Words.time(at, zone: zone), countdown: Words.countdown(to: at, from: snapshot.now))
        case .iqamah(let id, let at, let started):
            return Focus(eyebrow: L("Iqamah"), title: L("{prayer} iqamah", ["prayer": Words.prayer(id)]), time: Words.time(at, zone: zone), countdown: Words.countdown(to: at, from: snapshot.now),
                         below: L("Prayer started {time}", ["time": Words.time(started, zone: zone)]))
        case .unavailable:
            return nil
        }
    }

    /// The colour of the ring at an hour: night's lapis, the day's light, evening's rose. Light is what a dial is for, so it follows the real sun where it can.
    private static func hue(_ hour: Double, _ day: PrayerDay) -> String {
        let table: [(Double, String)] = [(0, "#26367F"), (3, "#2A3F96"), (4.5, "#2F58BE"), (6, "#3F7FDB"), (8, "#6FA8E8"), (10.5, "#A9C2D9"), (11.5, "#E8CF87"), (12.5, "#E8CF87"), (13.5, "#A9B4C8"), (15, "#8F86B8"), (16, "#C57BB0"), (17, "#A968C4"), (18.5, "#7354B8"), (21, "#3E3F9A"), (24, "#26367F")]
        var last = table[0]
        for entry in table where entry.0 <= hour { last = entry }
        return last.1
    }

    private static func nodeColor(_ event: DialEvent) -> String {
        switch event {
        case .prayer(.fajr): "#3C9BEB"
        case .prayer(.dhuhr): "#F1D27A"
        case .prayer(.asr): "#3C9BEB"
        case .prayer(.maghrib): "#E46CB2"
        case .prayer(.isha): "#7354E0"
        case .solar: "#E9C46A"
        }
    }

    static func nodes(cx: Double, cy: Double, radius: Double, labelRadius: Double, snapshot: NoorSnapshot, day: PrayerDay, focusAt: Date?, big: Bool) -> [Node] {
        let face = DialGeometry.nodes(day: day, now: snapshot.now)
        let zone = day.zone
        var out: [Node] = []
        let band = radius * 0.13
        // The ring: an hour at a time, so it reads as the day's light.
        for hour in 0..<48 {
            let from = Double(hour) * 7.5, to = from + 7.8
            // The top of the ring is noon, so an angle is twelve hours on from the clock's.
            let clockHour = (from / 15 + 12).truncatingRemainder(dividingBy: 24)
            out.append(Node.path(ringPath(cx, cy, inner: radius - band, outer: radius, from: from, to: to), fill: .hex(hue(clockHour, day))).size(cx * 2, cy * 2).at(0, 0))
        }
        // Hours as fine marks inside the ring; the quarter marks are longer.
        for hour in 0..<24 {
            let degrees = Double(hour) * 15
            let long = hour % 6 == 0
            let a = clockPoint(cx, cy, radius - band - 4, degrees), b = clockPoint(cx, cy, radius - band - (long ? 16 : 9), degrees)
            out.append(Node.path("M \(n(a.x)) \(n(a.y)) L \(n(b.x)) \(n(b.y))", stroke: long ? Noor.inlay : Noor.faint, lineWidth: long ? 1.6 : 1).size(cx * 2, cy * 2).at(0, 0))
        }
        // How far the day has come, and the way to what is next.
        if let now = face.nowAngle {
            if let focusAt, let target = angleOf(focusAt, on: day) {
                let end = target < now ? target + 360 : target
                out.append(Node.path(ringPath(cx, cy, inner: radius - band - 1, outer: radius + 1, from: now, to: end), fill: .hex("#F4C98AB8")).size(cx * 2, cy * 2).at(0, 0))
            }
            let p = clockPoint(cx, cy, radius - band / 2, now)
            out.append(Node.ellipse(fill: .hex("#FFFFFF"), stroke: .hex("#15182F"), lineWidth: 1.5).size(band + 3, band + 3).at(p.x - (band + 3) / 2, p.y - (band + 3) / 2).label(L("Now")))
        }
        for node in face.nodes {
            if let arc = node.iqamahArc {
                out.append(Node.path(ringPath(cx, cy, inner: radius - band - 3, outer: radius + 3, from: arc.startAngle, to: arc.startAngle + arc.sweep), fill: .hex("#F1D27AD0")).size(cx * 2, cy * 2).at(0, 0))
            }
        }
        let prayers = face.nodes
        var placed: [(angle: Double, x: Double, y: Double)] = []
        for node in prayers {
            let p = clockPoint(cx, cy, radius - band / 2, node.angle)
            guard case .prayer(let id) = node.event else {
                // Sunrise is told, not marked as a prayer: a small sun on the ring and no bell, no name in the way.
                out.append(Node.symbol("sun.horizon.fill", color: .hex("#F1D27A")).size(14, 14).at(p.x - 7, p.y - 7).label(L("Sunrise {time}", ["time": Words.time(node.at, zone: zone)])))
                continue
            }
            let isNext = node.at == focusAt || day.iqamah[id] == focusAt
            let size = isNext ? band + 8 : band + 3
            let color = Color.hex(nodeColor(node.event))
            switch node.state {
            case .past:
                // Past reads by shape too: hollow, and smaller.
                out.append(Node.ellipse(fill: .hex("#15182F"), stroke: color, lineWidth: 2).size(band, band).at(p.x - band / 2, p.y - band / 2))
            case .current, .upcoming:
                out.append(Node.ellipse(fill: .hex("#FFFFFF"), stroke: color, lineWidth: isNext ? 5 : 4).size(size, size).at(p.x - size / 2, p.y - size / 2))
            }
            // Its name and time just outside the ring, pushed apart where two events lie close, as they do on a winter evening.
            var a = node.angle
            if let last = placed.last, abs(a - last.angle) < 24 { a = last.angle + 24 }
            let label = clockPoint(cx, cy, labelRadius, a)
            placed.append((a, label.x, label.y))
            let boxW = big ? 92.0 : 74.0, boxH = big ? 42.0 : 36.0
            let ink = isNext ? Noor.accent : (node.state == .past ? Noor.faint : Noor.text)
            out.append(Node.group {
                Node.say(Words.prayer(id), 0, 0, boxW, boxH * 0.5, size: big ? 15 : 13, weight: isNext ? "semibold" : "medium", color: ink, align: "center")
                Node.say(Words.time(node.at, zone: zone), 0, boxH * 0.5, boxW, boxH * 0.5, size: big ? 14 : 12, color: isNext ? Noor.accent : Noor.muted, align: "center", tabular: true)
            }
            .size(boxW, boxH).at(label.x - boxW / 2, label.y - boxH / 2))
        }
        return out
    }

    private static func angleOf(_ date: Date, on day: PrayerDay) -> Double? {
        let start = CivilClock.startOfDay(day.date, in: day.zone), end = CivilClock.startOfDay(day.date.next, in: day.zone)
        guard date >= start, date < end else { return nil }
        let share = date.timeIntervalSince(start) / end.timeIntervalSince(start)
        return (share * 360 + 180).truncatingRemainder(dividingBy: 360)
    }

    /// The moment in the middle, shared by every dial.
    static func middle(cx: Double, cy: Double, radius: Double, focus: Focus?) -> [Node] {
        guard let focus else {
            return [Node.say(L("No time available"), cx - radius * 0.7, cy - 24, radius * 1.4, 48, size: 16, color: Noor.muted, align: "center", lines: 2)]
        }
        let scale = radius / 150
        var out = [
            Node.say(focus.eyebrow, cx - radius * 0.68, cy - 66 * scale, radius * 1.36, 22 * scale, size: 14 * scale, color: Noor.muted, align: "center"),
            Node.say(focus.title, cx - radius * 0.72, cy - 46 * scale, radius * 1.44, 34 * scale, size: 25 * scale, weight: "bold", color: Noor.accent, align: "center"),
            Node.say(focus.time, cx - radius * 0.72, cy - 12 * scale, radius * 1.44, 56 * scale, size: 46 * scale, weight: "medium", align: "center", tabular: true),
            Node.say(focus.countdown, cx - radius * 0.72, cy + 42 * scale, radius * 1.44, 28 * scale, size: 19 * scale, weight: "medium", color: Noor.warm, align: "center"),
        ]
        if let below = focus.below {
            out.append(Node.say(below, cx - radius * 0.72, cy + 70 * scale, radius * 1.44, 22 * scale, size: 13 * scale, color: Noor.muted, align: "center"))
        }
        return out
    }

    /// The whole of it for VoiceOver, once; the timetable beside it says each row. Doesn't count down aloud: it reads when someone goes there.
    static func spoken(_ snapshot: NoorSnapshot, focus: Focus?) -> String {
        guard let focus else { return L("No prayer time is available for this date.") }
        return L("Prayer dial. {eyebrow}: {title} at {time}, {countdown}.", ["eyebrow": focus.eyebrow, "title": focus.title, "time": focus.time, "countdown": focus.countdown])
    }
}
