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

    /// The ring's colour at an hour, from the day it is drawn for: night's indigo, blue to noon's gold, grey to the evening's rose, violet into the night.
    private static func hue(_ hour: Double, _ day: PrayerDay) -> (Int, Int, Int) {
        func at(_ id: PrayerID, _ fallback: Double) -> Double {
            guard let date = day.starts[id] else { return fallback }
            return CivilClock.hours(of: date, in: day.zone)
        }
        let fajr = at(.fajr, 5), dhuhr = at(.dhuhr, 12), asr = at(.asr, 15), maghrib = at(.maghrib, 18), isha = at(.isha, 19.5)
        let stops: [(Double, (Int, Int, Int))] = [
            (0, (34, 38, 112)), (fajr - 1, (36, 54, 142)), (fajr, (42, 92, 200)), ((fajr + dhuhr) / 2, (52, 112, 214)), (dhuhr - 0.8, (106, 128, 170)), (dhuhr, (222, 192, 118)), (dhuhr + 0.8, (116, 114, 128)),
            (asr, (92, 96, 136)), ((asr + maghrib) / 2, (128, 104, 146)), (maghrib - 0.4, (206, 104, 172)), (maghrib, (222, 70, 164)), (isha, (112, 74, 200)), (isha + 2, (66, 52, 160)), (24, (34, 38, 112)),
        ]
        var last = stops[0]
        for next in stops.dropFirst() {
            if hour <= next.0 {
                let t = next.0 > last.0 ? (hour - last.0) / (next.0 - last.0) : 0
                func mix(_ a: Int, _ b: Int) -> Int { Int((Double(a) + (Double(b) - Double(a)) * max(0, min(1, t))).rounded()) }
                return (mix(last.1.0, next.1.0), mix(last.1.1, next.1.1), mix(last.1.2, next.1.2))
            }
            last = next
        }
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

    static func nodes(cx: Double, cy: Double, radius: Double, labelRadius: Double, snapshot: NoorSnapshot, day: PrayerDay, focusAt: Date?, big: Bool, label: Double = 15) -> [Node] {
        let face = DialGeometry.nodes(day: day, now: snapshot.now)
        let zone = day.zone
        let box = (cx * 2, cy * 2)
        var out: [Node] = []
        let band = radius * 0.165
        let inner = radius - band
        out.append(Node.image("art/dial-face-l.png", dark: "art/dial-face-d.png", fit: "fill").size(inner * 2, inner * 2).at(cx - inner, cy - inner))
        // The ring: the day's light, a little at a time.
        for piece in 0..<48 {
            let from = Double(piece) * 7.5
            // The top of the ring is noon, so an angle is twelve hours on from the clock's.
            let hour = ((from + 3.75) / 15 + 12).truncatingRemainder(dividingBy: 24)
            let c = hue(hour, day)
            out.append(Node.path(ringPath(cx, cy, inner: inner, outer: radius, from: from, to: from + 7.9), fill: .hex(String(format: "#%02X%02X%02X", c.0, c.1, c.2))).size(box.0, box.1).at(0, 0))
        }
        out.append(Node.image("art/dial-ring.png", fit: "fill").size(radius * 2, radius * 2).at(cx - radius, cy - radius))
        // Hours as marks inside the ring, in one stroke each so a dial stays small; every sixth and every third is longer and gold.
        var fine = "", gold = ""
        for mark in 0..<96 {
            let degrees = Double(mark) * 3.75
            let a = clockPoint(cx, cy, inner - 3, degrees)
            if mark % 4 == 0 {
                let long = mark % 24 == 0
                let b = clockPoint(cx, cy, inner - (long ? radius * 0.11 : radius * 0.07), degrees)
                gold += "M \(n(a.x)) \(n(a.y)) L \(n(b.x)) \(n(b.y)) "
            } else if big {
                let b = clockPoint(cx, cy, inner - radius * 0.03, degrees)
                fine += "M \(n(a.x)) \(n(a.y)) L \(n(b.x)) \(n(b.y)) "
            }
        }
        if !fine.isEmpty { out.append(Node.path(fine, stroke: Noor.faint, lineWidth: 0.8).size(box.0, box.1).at(0, 0).opacity(0.7)) }
        out.append(Node.path(gold, stroke: .adaptive(light: "#B48A3E", dark: "#E7C37A"), lineWidth: 1.4).size(box.0, box.1).at(0, 0))
        // How far the day has come, and the way to what is next.
        if let now = face.nowAngle {
            if let focusAt, let target = angleOf(focusAt, on: day) {
                let end = target < now ? target + 360 : target
                out.append(Node.path(ringPath(cx, cy, inner: inner, outer: inner + band * 0.42, from: now, to: end), fill: .hex("#F6C47C")).gradient([.hex("#FFD99A"), .hex("#E98CC0")]).size(box.0, box.1).at(0, 0).shadow(.hex("#F6B45C99"), radius: radius * 0.03, dx: 0, dy: 0))
            }
            let p = clockPoint(cx, cy, radius - band / 2, now), size = band * 0.62
            out.append(Node.glow(.hex("#FFFFFF"), cx: p.x, cy: p.y, r: band * 0.9, opacity: 0.7))
            out.append(Node.ellipse(fill: .hex("#FFFFFF")).size(size, size).at(p.x - size / 2, p.y - size / 2).label(L("Now")))
        }
        for node in face.nodes {
            if let arc = node.iqamahArc {
                out.append(Node.path(ringPath(cx, cy, inner: radius - band - 3, outer: radius + 3, from: arc.startAngle, to: arc.startAngle + arc.sweep), fill: .hex("#F1D27AD0")).size(box.0, box.1).at(0, 0))
            }
        }
        var placed: [(angle: Double, x: Double, y: Double)] = []
        let textSize = big ? label : label * 0.86
        for node in face.nodes {
            let p = clockPoint(cx, cy, radius - band / 2, node.angle)
            guard case .prayer(let id) = node.event else {
                // Sunrise is told, not marked as a prayer: a small sun on the ring and no bell, no name in the way.
                out.append(Node.symbol("sun.horizon.fill", color: .hex("#F1D27A")).size(band * 0.8, band * 0.8).at(p.x - band * 0.4, p.y - band * 0.4).label(L("Sunrise {time}", ["time": Words.time(node.at, zone: zone)])))
                continue
            }
            let isNext = node.at == focusAt || day.iqamah[id] == focusAt
            let color = Color.hex(nodeColor(node.event))
            let spokeA = clockPoint(cx, cy, inner - 2, node.angle), spokeB = clockPoint(cx, cy, inner - radius * 0.1, node.angle)
            out.append(Node.path("M \(n(spokeA.x)) \(n(spokeA.y)) L \(n(spokeB.x)) \(n(spokeB.y))", stroke: .hex("#F1D27A"), lineWidth: 2).size(box.0, box.1).at(0, 0))
            let size = band * (isNext ? 1.0 : 0.82)
            out.append(Node.glow(color, cx: p.x, cy: p.y, r: size * (isNext ? 1.35 : 1.05), opacity: node.state == .past ? 0.25 : 0.85))
            switch node.state {
            case .past:
                // Past reads by shape too: hollow, and smaller.
                out.append(Node.ellipse(fill: .hex("#15182F"), stroke: color, lineWidth: 2).size(size * 0.8, size * 0.8).at(p.x - size * 0.4, p.y - size * 0.4))
            case .current, .upcoming:
                out.append(Node.ellipse(fill: color, stroke: .hex("#FFFFFF"), lineWidth: max(2, size * 0.16)).size(size, size).at(p.x - size / 2, p.y - size / 2))
                out.append(Node.ellipse(fill: .hex("#14183F")).size(size * 0.3, size * 0.3).at(p.x - size * 0.15, p.y - size * 0.15))
            }
            // Its name and time just outside the ring, pushed apart where two events lie close, as they do on a winter evening.
            var a = node.angle
            if let last = placed.last, abs(a - last.angle) < 24 { a = last.angle + 24 }
            let at = clockPoint(cx, cy, labelRadius, a)
            placed.append((a, at.x, at.y))
            let boxW = textSize * 6.2, boxH = textSize * 2.7
            let ink = isNext ? Noor.accent : (node.state == .past ? Noor.faint : Noor.text)
            out.append(Node.group {
                Node.say(Words.prayer(id), 0, 0, boxW, boxH * 0.5, size: textSize * 1.05, weight: isNext ? "semibold" : "medium", color: ink, align: "center")
                Node.say(Words.time(node.at, zone: zone), 0, boxH * 0.5, boxW, boxH * 0.5, size: textSize, color: isNext ? Noor.accent : Noor.muted, align: "center", tabular: true)
            }
            .size(boxW, boxH).at(at.x - boxW / 2, at.y - boxH / 2))
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
            Node.say(focus.eyebrow, cx - radius * 0.78, cy - 68 * scale, radius * 1.56, 24 * scale, size: 14.5 * scale, color: Noor.text, align: "center"),
            Node.say(focus.title, cx - radius * 0.82, cy - 46 * scale, radius * 1.64, 36 * scale, size: 24 * scale, weight: "medium", color: Noor.accent, align: "center"),
            Node.say(focus.time, cx - radius * 0.82, cy - 14 * scale, radius * 1.64, 62 * scale, size: 49 * scale, weight: "regular", align: "center", tabular: true),
            Node.say(focus.countdown, cx - radius * 0.82, cy + 44 * scale, radius * 1.64, 30 * scale, size: 20 * scale, color: Noor.warm, align: "center"),
        ]
        if let below = focus.below {
            out.append(Node.say(below, cx - radius * 0.72, cy + 74 * scale, radius * 1.44, 22 * scale, size: 13 * scale, color: Noor.muted, align: "center"))
        }
        return out
    }

    /// The whole of it for VoiceOver, once; the timetable beside it says each row. Doesn't count down aloud: it reads when someone goes there.
    static func spoken(_ snapshot: NoorSnapshot, focus: Focus?) -> String {
        guard let focus else { return L("No prayer time is available for this date.") }
        return L("Prayer dial. {eyebrow}: {title} at {time}, {countdown}.", ["eyebrow": focus.eyebrow, "title": focus.title, "time": focus.time, "countdown": focus.countdown])
    }
}
