import CoreGraphics
import Foundation

enum DialEvent: Hashable, Sendable {
    case prayer(PrayerID)
    case solar(SolarEvent)
}

enum DialState: Hashable, Sendable { case past, current, upcoming }

/// A start-to-iqamah stretch of the ring, clockwise from `startAngle` through `sweep` degrees.
struct DialArc: Hashable, Sendable {
    let startAngle: Double
    let endAngle: Double
    let sweep: Double
}

struct DialNode: Hashable, Sendable {
    let event: DialEvent
    let at: Date
    /// Degrees clockwise from the top, in 0..<360: where to draw it.
    let angle: Double
    /// Degrees travelled since the civil day began, not wrapped. It never goes backwards from node to node, even past midnight.
    let progress: Double
    let state: DialState
    let iqamahArc: DialArc?
}

struct DialFace: Hashable, Sendable {
    /// In the order of their instants.
    let nodes: [DialNode]
    /// Degrees clockwise from the top; nil when `now` isn't in this civil day.
    let nowAngle: Double?
}

/// The dial is the place-local civil day once around, clockwise, with midnight at the bottom and noon at the top. A clock
/// time keeps its place from day to day, so the ring needs no scale taken from the data, and it reads like the sky: the sun
/// climbs the left side and sets down the right.
///
/// A position is the share of the day's real elapsed time. On a 23- or 25-hour day noon therefore sits up to 7.5 degrees off
/// the top. Going by the wall clock instead would put an hour of a fall-back day on top of itself and could reverse two
/// events; order is what the dial has to keep. Nothing here knows about reading direction: time and geography don't mirror.
enum DialGeometry {
    static func nodes(day: PrayerDay, now: Date, solar: Set<SolarEvent> = [.sunrise]) -> DialFace {
        let start = CivilClock.startOfDay(day.date, in: day.zone)
        let end = CivilClock.startOfDay(day.date.next, in: day.zone)
        let length = end.timeIntervalSince(start)
        func progress(_ instant: Date) -> Double { 360 * instant.timeIntervalSince(start) / length }

        let prayers = PrayerID.allCases.map { (event: DialEvent.prayer($0), at: day.starts[$0]!) }
        let markers = SolarEvent.allCases.filter(solar.contains).compactMap { event in day.solar[event].map { (event: DialEvent.solar(event), at: $0) } }
        // Prayers first where instants tie: Maghrib and Sunset are often the same minute.
        let events = (prayers + markers).enumerated().sorted { ($0.element.at, $0.offset) < ($1.element.at, $1.offset) }.map(\.element)

        let isToday = now >= start && now < end
        let currentIndex = isToday ? events.lastIndex { $0.at <= now } : nil
        let nodes = events.enumerated().map { index, event -> DialNode in
            let state: DialState = index == currentIndex ? .current : event.at <= now ? .past : .upcoming
            var arc: DialArc?
            if case .prayer(let prayer) = event.event, let iqamah = day.iqamah[prayer], iqamah > event.at {
                arc = DialArc(startAngle: angle(progress(event.at)), endAngle: angle(progress(iqamah)), sweep: progress(iqamah) - progress(event.at))
            }
            return DialNode(event: event.event, at: event.at, angle: angle(progress(event.at)), progress: progress(event.at), state: state, iqamahArc: arc)
        }
        return DialFace(nodes: nodes, nowAngle: isToday ? angle(progress(now)) : nil)
    }

    /// Degrees clockwise from the top, from degrees since midnight at the bottom.
    private static func angle(_ progress: Double) -> Double {
        let degrees = (progress + 180).truncatingRemainder(dividingBy: 360)
        return degrees < 0 ? degrees + 360 : degrees
    }

    /// A point on a ring in a y-down drawing, for an angle clockwise from the top.
    static func point(angle: Double, radius: Double, center: CGPoint) -> CGPoint {
        let radians = angle * .pi / 180
        return CGPoint(x: center.x + radius * sin(radians), y: center.y - radius * cos(radians))
    }
}

/// The Qibla arrow on a north-up diagram: the bearing is geographic, so it never mirrors with the interface.
enum QiblaGeometry {
    /// Where the arrow ends in a y-down drawing with north at the top, for a bearing clockwise from true north.
    static func arrowEnd(bearing: Double, center: CGPoint, length: Double) -> CGPoint {
        DialGeometry.point(angle: bearing, radius: length, center: center)
    }
}
