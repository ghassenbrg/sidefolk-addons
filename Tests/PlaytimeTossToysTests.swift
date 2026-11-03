import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import SidefolkExtensionKit
@testable import ext_playtime

/// The desktop's clay coin and dice: what it lands on is what was drawn, down to the pixels of the last picture, and the landed scene stands exactly where the flying one did.
@Suite(.serialized) @MainActor
struct PlaytimeTossToysTests {
    static let art = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("extensions/playtime/assets")

    private func node(_ id: String, in scene: Scene) -> [String: Any]? {
        func find(_ list: [[String: Any]]) -> [String: Any]? {
            for n in list {
                if n["id"] as? String == id { return n }
                if let hit = find(n["children"] as? [[String: Any]] ?? []) { return hit }
            }
            return nil
        }
        return find(scene.json["nodes"] as? [[String: Any]] ?? [])
    }

    private func pictures(_ target: String, in scene: Scene) -> [String] {
        let runs = scene.json["animations"] as? [[String: Any]] ?? []
        return runs.first { $0["target"] as? String == target && $0["frames"] != nil }?["frames"] as? [String] ?? []
    }

    private func image(_ path: String) throws -> (width: Int, height: Int, pixels: [UInt8]) {
        let url = Self.art.appendingPathComponent(path)
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil), "\(path)")
        let picture = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil), "\(path)")
        let (w, h) = (picture.width, picture.height)
        var pixels = [UInt8](repeating: 0, count: w * h * 4)
        let drawn = pixels.withUnsafeMutableBytes { raw in
            CGContext(data: raw.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue).map { context in
                context.draw(picture, in: CGRect(x: 0, y: 0, width: w, height: h))
            }
        }
        #expect(drawn != nil)
        return (w, h, pixels)
    }

    /// The dimples seen from straight above in this picture: navy blobs, large and round. Those on the sides that show are slivers, and don't count.
    private func pipsOnTop(_ path: String) throws -> Int {
        let (w, h, p) = try image(path)
        func navy(_ i: Int) -> Bool { p[i * 4 + 3] > 200 && Int(p[i * 4 + 2]) > Int(p[i * 4]) + 15 && p[i * 4] < 90 }
        var seen = [Bool](repeating: false, count: w * h)
        var found = 0
        for start in 0..<(w * h) where !seen[start] && navy(start) {
            var stack = [start]
            seen[start] = true
            var area = 0, minX = w, maxX = 0, minY = h, maxY = 0
            while let at = stack.popLast() {
                area += 1
                let x = at % w, y = at / w
                minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
                for next in [x + 1 < w ? at + 1 : -1, x > 0 ? at - 1 : -1, y + 1 < h ? at + w : -1, y > 0 ? at - w : -1] where next >= 0 && !seen[next] && navy(next) {
                    seen[next] = true
                    stack.append(next)
                }
            }
            let across = Double(maxX - minX + 1), down = Double(maxY - minY + 1)
            if area > w * h / 300, down / across > 0.6 { found += 1 }
        }
        return found
    }

    /// Every d6 landing: the last picture of its flight is the one it rests on, which has the rolled number on top; before that only that landing's own settle.
    @Test func everyD6LandsOnItsTrueFace() throws {
        for value in 1...6 {
            let toss = Toss.dice(sides: 6, rolls: [value], modifier: 0)
            let flying = TossSurface.flying(toss), landed = TossSurface.landed(toss)
            let final = TossFrames.dieFinal(sides: 6, value: value)
            #expect(try pipsOnTop(final) == value, "\(final)")
            #expect(node("toss.die.0.f", in: landed)?["image"] as? String == final)
            #expect(node("toss.die.0.f", in: flying)?["image"] as? String == final, "Reduce Motion sees the end at once")
            let list = pictures("toss.die.0.f", in: flying)
            #expect(list.last == final)
            #expect(list.count <= 64)
            let settle = list.suffix(TossFrames.d6Settle)
            #expect(settle.allSatisfy { $0.hasPrefix("art/toss-d6-\(value)-") }, "\(settle)")
            #expect(list.dropLast(TossFrames.d6Settle).allSatisfy { $0.contains("d6-l") })
        }
    }

    /// And so for several at once, each its own.
    @Test func severalDiceEachLandOnTheirOwn() throws {
        let rolls = [1, 2, 3, 4, 5, 6, 6, 5, 4, 3]
        let toss = Toss.dice(sides: 6, rolls: rolls, modifier: 3)
        let flying = TossSurface.flying(toss), landed = TossSurface.landed(toss)
        var starts = Set<String>(), rests = Set<Double>(), ys = Set<Double>()
        for (i, value) in rolls.enumerated() {
            let id = "toss.die.\(i)"
            #expect(pictures(id + ".f", in: flying).last == TossFrames.dieFinal(sides: 6, value: value))
            #expect(node(id + ".f", in: landed)?["image"] as? String == TossFrames.dieFinal(sides: 6, value: value))
            starts.insert(pictures(id + ".f", in: flying)[0])
            rests.insert(node(id + ".p", in: landed)?["rotate"] as? Double ?? 0)
            ys.insert(node(id, in: landed)?["y"] as? Double ?? 0)
        }
        #expect(starts.count >= 5, "no two in step")
        #expect(rests.count == rolls.count && ys.count == rolls.count, "a handful, not a grid")
    }

    /// A polyhedron's faces are blank in every picture: its number is the only number on it, laid on as it comes up, and it is the roll.
    @Test func otherDiceShowOnlyTheirNumberAndOnlyAtTheEnd() throws {
        for (sides, shape) in [(2, "gem"), (4, "d4"), (7, "gem"), (8, "d8"), (10, "d10"), (12, "d12"), (20, "d20"), (100, "gem")] {
            let toss = Toss.dice(sides: sides, rolls: [sides], modifier: 0)
            let flying = TossSurface.flying(toss), landed = TossSurface.landed(toss)
            #expect(pictures("toss.die.0.f", in: flying).last == TossFrames.dieFinal(sides: sides, value: sides))
            #expect(pictures("toss.die.0.f", in: flying).allSatisfy { $0.contains("toss-\(shape)-") })
            #expect(PlaytimeHandsAndTossTests.text(node("toss.die.0.n", in: landed) ?? [:]).contains("\"\(Toss.number(sides))\""))
            let run = (flying.json["animations"] as? [[String: Any]] ?? []).first { $0["target"] as? String == "toss.die.0.n" }
            let keys = try #require(run?["keys"] as? [[String: Double]])
            #expect(keys[0]["opacity"] == 0 && keys.last?["opacity"] == 1)
            let shows = keys.dropLast().last?["t"] ?? 0, whole = run?["ms"] as? Double ?? 0
            #expect(shows * whole > 1000, "hidden till the face has come up")
        }
    }

    /// Heads rests with the dish for the companion's face, tails with a star of gold; heads wears the real face, tails none.
    @Test func coinsLandOnTheirTrueSide() throws {
        func middle(_ path: String) throws -> (r: Int, g: Int, b: Int) {
            let (w, h, p) = try image(path)
            let at = (h / 2 * w + w / 2) * 4
            return (Int(p[at]), Int(p[at + 1]), Int(p[at + 2]))
        }
        let heads = try middle(TossFrames.coinFinal(heads: true)), tails = try middle(TossFrames.coinFinal(heads: false))
        #expect(heads.b > 180, "the cream dish: \(heads)")
        #expect(tails.b < 140 && tails.r > 200, "the gold star: \(tails)")
        for (flip, name) in [(true, "heads"), (false, "tails")] {
            let toss = Toss.coins([flip])
            let flying = TossSurface.flying(toss), landed = TossSurface.landed(toss)
            let final = TossFrames.coinFinal(heads: flip)
            #expect(node("toss.coin.0.f", in: landed)?["image"] as? String == final, "\(name)")
            #expect(pictures("toss.coin.0.f", in: flying).last == final, "\(name)")
            #expect(pictures("toss.coin.0.f", in: flying).count <= 64)
            #expect((node("toss.coin.0.face", in: landed) != nil) == flip, "\(name)")
            if !flip { #expect(node("toss.coin.0.face", in: flying)?["opacity"] as? Double == 0, "under Reduce Motion it isn't there") }
        }
        // Several: each its own.
        let flips = [true, false, false, true, false]
        let several = TossSurface.landed(.coins(flips))
        for (i, flip) in flips.enumerated() { #expect(node("toss.coin.\(i).f", in: several)?["image"] as? String == TossFrames.coinFinal(heads: flip)) }
    }

    /// Nothing moves when the result shows: on the bottom edge the host keeps still, every toy and the tag are as far up in both scenes, whatever kind of toss, and as wide.
    @Test func nothingMovesWhenTheResultShows() throws {
        let tosses: [(Toss, [String])] = [
            (.coins([true]), ["toss.coin.0"]), (.coins([true, false, true, false, true]), ["toss.coin.0", "toss.coin.4"]), (.coins([true], call: true), ["toss.coin.0"]),
            (.dice(sides: 6, rolls: [4], modifier: 0), ["toss.die.0"]), (.dice(sides: 20, rolls: [20], modifier: 0), ["toss.die.0"]),
            (.dice(sides: 6, rolls: [1, 1], modifier: 0), ["toss.die.1"]), (.dice(sides: 100, rolls: Array(repeating: 100, count: 10), modifier: -100), ["toss.die.0", "toss.die.9"]),
            (.hands(person: .rock, companion: .paper), ["toss.hands"]),
        ]
        for (toss, ids) in tosses {
            let flying = TossSurface.flying(toss), landed = TossSurface.landed(toss)
            #expect(flying.width == landed.width, "\(toss)")
            func fromBottom(_ id: String, _ scene: Scene) -> Double? { (node(id, in: scene)?["y"] as? Double).map { scene.height - $0 } }
            for id in ids {
                let a = fromBottom(id, flying), b = fromBottom(id, landed)
                #expect(a != nil && abs((a ?? 0) - (b ?? 9)) < 0.001, "\(toss) \(id): \(String(describing: a)) and \(String(describing: b))")
            }
        }
    }

    /// The host drops what a scene asks past these.
    @Test func everyStepFitsWhatTheHostTakes() throws {
        let worst: [Toss] = [.coins([true, false, true, false, true]), .dice(sides: 6, rolls: Array(repeating: 6, count: 10), modifier: 100),
                             .dice(sides: 100, rolls: Array(repeating: 100, count: 10), modifier: -100), .dice(sides: 20, rolls: Array(repeating: 19, count: 10), modifier: 0)]
        for toss in worst {
            for scene in [TossSurface.flying(toss), TossSurface.flying(toss, after: toss), TossSurface.landed(toss)] {
                try PlaytimeStageTests.check(scene, "\(toss)")
                var tracks: [String: Double] = [:]
                for run in scene.json["animations"] as? [[String: Any]] ?? [] {
                    #expect((run["keys"] as? [Any])?.count ?? 0 <= 32, "\(run["target"] ?? "")")
                    #expect((run["frames"] as? [Any])?.count ?? 0 <= 64)
                    // One after another on a value: a step started before the last ended cuts that one off.
                    guard let target = run["target"] as? String, let keys = run["keys"] as? [[String: Double]] else { continue }
                    let begin = run["delay_ms"] as? Double ?? 0, end = begin + (run["ms"] as? Double ?? 0)
                    for value in Set(keys.flatMap(\.keys)) where value != "t" {
                        let track = target + "." + value
                        #expect((tracks[track] ?? 0) <= begin + 0.5, "\(track)")
                        tracks[track] = end
                    }
                }
            }
        }
    }

    /// The family's budget in the pack: what the brief set for it.
    @Test func theFamilysPicturesStayInBudget() throws {
        let folder = Self.art.appendingPathComponent("art")
        let names = try FileManager.default.contentsOfDirectory(atPath: folder.path).filter { $0.hasPrefix("toss-") }
        let bytes = try names.reduce(0) { $0 + (try FileManager.default.attributesOfItem(atPath: folder.appendingPathComponent($1).path)[.size] as? Int ?? 0) }
        #expect(names.count <= 200, "\(names.count) files")
        #expect(bytes <= 10 * 1024 * 1024, "\(bytes) bytes")
        // No file left over: every frame a flight can show exists, and the old flat art is gone.
        for sides in [6, 4, 8, 10, 12, 20, 100] {
            for name in TossFrames.dieFrames(sides: sides, value: min(sides, 6), loopSteps: 30) {
                #expect(FileManager.default.fileExists(atPath: Self.art.appendingPathComponent(name).path), "\(name)")
            }
        }
    }

    /// Reduce Motion: the flying scene already stands on the true result, and goes on within 200 ms.
    @Test func withReduceMotionTheEndIsAlreadyThere() {
        let toss = Toss.dice(sides: 6, rolls: [3, 5], modifier: 0)
        let flying = TossSurface.flying(toss), landed = TossSurface.landed(toss)
        for i in 0..<2 {
            let id = "toss.die.\(i)"
            #expect(node(id + ".f", in: flying)?["image"] as? String == node(id + ".f", in: landed)?["image"] as? String)
            #expect(node(id, in: flying)?["opacity"] == nil, "standing, not hidden")
        }
        #expect(flying.json["after_still_ms"] as? Int == 200)
    }
}
