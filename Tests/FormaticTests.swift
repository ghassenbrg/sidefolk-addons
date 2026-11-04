import AVFoundation
import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import ext_formatic

/// Formatic's conversions on real files made here, in a temporary folder.
@MainActor struct FormaticTests {
    private func folder() throws -> String {
        let path = NSTemporaryDirectory() + "formatic-" + UUID().uuidString
        try FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        return path
    }

    /// A half-transparent picture, with a place in its details.
    private func picture(at path: String, width: Int = 3000, height: Int = 1500, type: UTType = .png) throws {
        let context = try #require(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                             space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width / 2, height: height))
        let out = try #require(CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, type.identifier as CFString, 1, nil))
        let details: [CFString: Any] = [kCGImagePropertyGPSDictionary: [kCGImagePropertyGPSLatitude: 36.8, kCGImagePropertyGPSLatitudeRef: "N"]]
        CGImageDestinationAddImage(out, try #require(context.makeImage()), details as CFDictionary)
        #expect(CGImageDestinationFinalize(out))
    }

    private func read(_ path: String) throws -> (image: CGImage, details: [CFString: Any]) {
        let source = try #require(CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil))
        return (try #require(CGImageSourceCreateImageAtIndex(source, 0, nil)), CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] ?? [:])
    }

    private func offers() throws -> [(id: String, target: String, patterns: [String])] {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: root.appendingPathComponent("extensions/formatic/sidefolk-extension.json"))
        let manifest = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        return try #require(manifest["drops"] as? [[String: Any]]).map {
            let input = $0["input"] as? [String: Any]
            return ($0["id"] as? String ?? "", input?["target"] as? String ?? "", $0["patterns"] as? [String] ?? [])
        }
    }

    /// The offer is a promise: its row never names the format the file is already in, unless it makes it smaller.
    @Test func noRowOffersAFileItsOwnFormat() throws {
        for offer in try offers() where offer.id != "photo_small" {
            for pattern in offer.patterns {
                #expect(!Convert.same("a" + pattern.dropFirst(), offer.target, small: false), "\(offer.id) offers \(pattern) its own format")
            }
        }
    }

    /// Every file kind still has a row when two kinds of it are dropped together.
    @Test(arguments: [("a.csv", "b.json"), ("a.m4a", "b.flac"), ("a.zip", "b.tar"), ("a.zip", "b.7z"), ("a.png", "b.jpg")])
    func aMixedBatchStillHasAnOffer(first: String, second: String) throws {
        func fits(_ name: String, _ patterns: [String]) -> Bool {
            patterns.contains { name.lowercased().hasSuffix(String($0.dropFirst())) }
        }
        #expect(try offers().contains { fits(first, $0.patterns) && fits(second, $0.patterns) })
    }

    @Test func thePageButtonMakesAUsefulFormatFromEveryKind() {
        #expect(Convert.usual(for: "/a.png") == "jpg")
        #expect(Convert.usual(for: "/a.JPEG") == "png")
        #expect(Convert.usual(for: "/a.pdf") == "png")
        #expect(Convert.usual(for: "/a.mp3") == "m4a")
        #expect(Convert.usual(for: "/a.m4a") == "flac")
        #expect(Convert.usual(for: "/a.json") == "csv")
        #expect(Convert.usual(for: "/a.csv") == "json")
        #expect(Convert.usual(for: "/a.tar") == "zip")
        #expect(Convert.usual(for: "/a.zip") == "7z")
    }

    @Test func aTransparentPictureBecomesAJPEGOnWhite() throws {
        let dir = try folder(), source = dir + "/a.png", made = dir + "/a.jpg"
        try picture(at: source)
        try Pictures.write(source, to: made, target: "jpg", maxSide: nil, removeLocation: false)
        let (image, _) = try read(made)
        #expect(image.width == 3000)
        let bytes = try #require(image.dataProvider?.data as Data?)
        let row = image.bytesPerRow, far = row * 700 + (image.width - 10) * image.bitsPerPixel / 8
        #expect(bytes[far] > 250 && bytes[far + 1] > 250 && bytes[far + 2] > 250)
    }

    @Test func smallForEmailFitsAndDropsTheLocation() throws {
        let dir = try folder(), source = dir + "/a.jpg", made = dir + "/b.jpg"
        try picture(at: source, type: .jpeg)
        #expect(try read(source).details[kCGImagePropertyGPSDictionary] != nil)
        try Pictures.write(source, to: made, target: "jpg", maxSide: Convert.smallSide, removeLocation: true)
        let (image, details) = try read(made)
        #expect(max(image.width, image.height) == Convert.smallSide)
        #expect(details[kCGImagePropertyGPSDictionary] == nil)
    }

    @Test(arguments: ["png", "heic", "avif", "tiff", "gif", "pdf"])
    func everyPictureFormatOnTheMenuIsMade(target: String) throws {
        let dir = try folder(), source = dir + "/a.jpg", made = dir + "/made." + target
        try picture(at: source, width: 200, height: 100, type: .jpeg)
        try Pictures.write(source, to: made, target: target, maxSide: nil, removeLocation: false)
        let size = try #require(try FileManager.default.attributesOfItem(atPath: made)[.size] as? Int)
        #expect(size > 0)
        if target != "pdf" { #expect(try read(made).image.width == 200) }
    }

    @Test func aPDFBecomesOnePictureForEachPage() throws {
        let dir = try folder(), source = dir + "/a.pdf"
        var box = CGRect(x: 0, y: 0, width: 72, height: 144)
        let context = try #require(CGContext(URL(fileURLWithPath: source) as CFURL, mediaBox: &box, nil))
        for _ in 0..<3 { context.beginPDFPage(nil); context.endPDFPage() }
        context.closePDF()
        let pages = try Pictures.pages(of: source, target: "png")
        #expect(pages.count == 3)
        let first = try #require(CGImageSourceCreateWithData(pages[0] as CFData, nil))
        #expect(CGImageSourceCreateImageAtIndex(first, 0, nil)?.width == 200)
        #expect(throws: Problem.self) { try Pictures.pages(of: dir + "/missing.pdf", target: "png") }
    }

    private func tone(at path: String, rate: Double, seconds: Double = 1) throws {
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: rate, channels: 2))
        let file = try AVAudioFile(forWriting: URL(fileURLWithPath: path), settings: format.settings)
        let frames = AVAudioFrameCount(rate * seconds)
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames))
        buffer.frameLength = frames
        for channel in 0..<2 { for frame in 0..<Int(frames) { buffer.floatChannelData![channel][frame] = sin(Float(frame) * 0.05) * 0.4 } }
        try file.write(from: buffer)
    }

    @Test(arguments: [("m4a", "m4a"), ("alac", "m4a"), ("flac", "flac"), ("wav", "wav"), ("aiff", "aiff"), ("opus", "caf")])
    func everySoundFormatOnTheMenuKeepsTheLength(target: String, ending: String) async throws {
        let dir = try folder(), source = dir + "/a.wav", made = dir + "/made." + ending
        // 44.1 kHz, which Opus can't take as it is.
        try tone(at: source, rate: 44100)
        try await Sounds.write(source, to: made, target: target)
        let file = try AVAudioFile(forReading: URL(fileURLWithPath: made))
        let seconds = Double(file.length) / file.processingFormat.sampleRate
        #expect(abs(seconds - 1) < 0.1, "\(target): \(seconds) s")
        #expect(file.processingFormat.channelCount == 2)
    }

    @Test func recordsGoBetweenFormatsAndStayRecords() throws {
        let dir = try folder(), source = dir + "/a.csv"
        try "name,note\nAda,\"one, two\"\nLin,\"said \"\"hi\"\"\nthere\"\n".write(toFile: source, atomically: true, encoding: .utf8)
        try Records.convert(source, to: dir + "/a.json", target: "json")
        let rows = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: dir + "/a.json"))) as? [[String: String]])
        #expect(rows == [["name": "Ada", "note": "one, two"], ["name": "Lin", "note": "said \"hi\"\nthere"]])
        try Records.convert(dir + "/a.json", to: dir + "/b.csv", target: "csv")
        #expect(Records.parse(try String(contentsOfFile: dir + "/b.csv", encoding: .utf8), by: ",") == [["name", "note"], ["Ada", "one, two"], ["Lin", "said \"hi\"\nthere"]])
        try Records.convert(dir + "/a.json", to: dir + "/c.plist", target: "plist")
        #expect((try PropertyListSerialization.propertyList(from: Data(contentsOf: URL(fileURLWithPath: dir + "/c.plist")), format: nil) as? [[String: String]]) == rows)
    }

    @Test func aCellThatASpreadsheetWouldRunStaysText() {
        let text = Records.delimited([["a": "=HYPERLINK(\"http://x\")", "b": "-3", "c": 4]], by: ",")
        #expect(Records.parse(text, by: ",")[1] == ["'=HYPERLINK(\"http://x\")", "-3", "4"])
    }

    @Test func somethingThatIsNotAListOfRecordsIsRefused() throws {
        let dir = try folder(), source = dir + "/a.json"
        try "[1, 2, 3]".write(toFile: source, atomically: true, encoding: .utf8)
        #expect(throws: Problem.self) { try Records.convert(source, to: dir + "/a.csv", target: "csv") }
    }

    @Test(arguments: ["zip", "7z", "tar", "tar.gz"])
    func archivesKeepTheirFiles(target: String) throws {
        let dir = try folder(), inside = dir + "/inside", source = dir + "/a.tar", made = dir + "/made." + target
        try FileManager.default.createDirectory(atPath: inside + "/deep", withIntermediateDirectories: true)
        try "hello".write(toFile: inside + "/deep/note.txt", atomically: true, encoding: .utf8)
        let packed = try SidefolkRun.tar(["-cf", source, "-C", inside, "."])
        #expect(packed.status == 0)
        try Archives.convert(source, to: made, target: target)
        #expect(try SidefolkRun.tar(["-tf", made]).out.contains("deep/note.txt"))
    }

    @Test func aDamagedArchiveIsRefused() throws {
        let dir = try folder(), source = dir + "/a.zip"
        try "not an archive".write(toFile: source, atomically: true, encoding: .utf8)
        #expect(throws: Problem.self) { try Archives.convert(source, to: dir + "/b.7z", target: "7z") }
    }

    @Test func anArchiveIsMeasuredBeforeItIsOpened() {
        #expect(Archives.unpackedSize("-rw-r--r--  0 ada  staff  1024 Nov  3 12:00 a b\n-rw-r--r--  0 ada  staff  2048 Nov  3 12:00 c\n") == 3072)
    }

    @Test func namesKeepTheirStem() {
        #expect(Convert.stem(of: "/x/Trip to Tunis.tar.gz") == "Trip to Tunis")
        #expect(Convert.stem(of: "/x/v1.2.notes.png") == "v1.2.notes")
    }

    @Test func aFileIsNotConvertedIntoWhatItAlreadyIs() {
        #expect(Convert.same("/x/a.JPEG", "jpg", small: false))
        #expect(!Convert.same("/x/a.jpeg", "jpg", small: true))
        #expect(Convert.same("/x/a.tgz", "tar.gz", small: false))
        #expect(!Convert.same("/x/a.tar", "tar.gz", small: false))
    }
}

import SidefolkExtensionKit
private enum SidefolkRun {
    static func tar(_ arguments: [String]) throws -> Output { try run("/usr/bin/bsdtar", arguments) }
}
