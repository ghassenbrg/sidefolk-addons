import AVFoundation
import Foundation
import ImageIO
import PDFKit
import SidefolkExtensionKit
import UniformTypeIdentifiers

/// What one file became, in the data folder, for Sidefolk to save beside the original.
struct Made {
    var data: String
    var name: String
    var note: String?
}

/// Files turned into other files with what macOS already has (Sidefolk's native-first decision): nothing third-party, and no network.
enum Convert {
    /// Where results wait, under the data folder.
    static let holding = "out"
    static let smallSide = 2000

    enum Kind { case picture, pdf, sound, data, archive }

    static func kind(of path: String) -> Kind? {
        let ending = (path as NSString).pathExtension.lowercased()
        if ending == "pdf" { return .pdf }
        if ["jpg", "jpeg", "png", "heic", "heif", "tif", "tiff", "webp", "avif", "bmp", "gif", "dng", "cr2", "nef", "arw"].contains(ending) { return .picture }
        if ["mp3", "m4a", "aac", "wav", "aif", "aiff", "flac", "caf", "opus", "ogg"].contains(ending) { return .sound }
        if ["json", "csv", "tsv", "plist"].contains(ending) { return .data }
        if ["7z", "rar", "tar", "tgz", "gz", "xz", "bz2", "iso", "zip"].contains(ending) { return .archive }
        return nil
    }

    static func size(of path: String) -> Int64 {
        (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int64) ?? 0
    }

    /// The offers are by kind of file, so one can name the kind the file already is. Making a picture smaller is still a change.
    static func same(_ path: String, _ target: String, small: Bool) -> Bool {
        guard !small else { return false }
        let name = path.lowercased(), aliases = ["jpg": ["jpg", "jpeg"], "tiff": ["tif", "tiff"], "aiff": ["aif", "aiff"], "tar.gz": ["tar.gz", "tgz"]]
        return (aliases[target] ?? [target]).contains { name.hasSuffix("." + $0) }
    }

    /// The file's name without its ending, also for double endings like `.tar.gz`.
    static func stem(of path: String) -> String {
        var name = (path as NSString).lastPathComponent
        for double in [".tar.gz", ".tar.xz", ".tar.bz2"] where name.lowercased().hasSuffix(double) { name = String(name.dropLast(double.count)) + ".tar" }
        return (name as NSString).deletingPathExtension
    }

    static func make(_ path: String, target: String, small: Bool, removeLocation: Bool) async throws -> [Made] {
        guard let kind = kind(of: path) else { throw Problem(L("{file} isn't a kind of file Formatic knows.", ["file": (path as NSString).lastPathComponent])) }
        guard !same(path, target, small: small) else { throw Problem(L("{file} is already that kind of file. Drop it again and pick another format.", ["file": (path as NSString).lastPathComponent])) }
        let folder = Paths.data + "/" + holding
        try FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
        let stem = stem(of: path)
        func spot(_ ending: String) -> (full: String, data: String) {
            let name = UUID().uuidString + "." + ending
            return (folder + "/" + name, holding + "/" + name)
        }
        switch kind {
        case .picture:
            let ending = target == "tiff" ? "tiff" : target
            let place = spot(ending)
            let more = try Pictures.write(path, to: place.full, target: target, maxSide: small ? smallSide : nil, removeLocation: small && removeLocation)
            // Compressing a small JPEG again can make it bigger, and the offer promised smaller.
            if small, size(of: place.full) >= size(of: path), !removeLocation || !Pictures.hasLocation(path) {
                try? FileManager.default.removeItem(atPath: place.full)
                throw Problem(L("{file} is already small enough, so it was left as it is.", ["file": (path as NSString).lastPathComponent]))
            }
            return [Made(data: place.data, name: stem + (small ? " small" : "") + "." + ending,
                         note: more ? L("{file} holds several pictures, and this is the first.", ["file": (path as NSString).lastPathComponent]) : nil)]
        case .pdf:
            return try Pictures.pages(of: path, target: target).enumerated().map { index, data in
                let place = spot(target)
                try data.write(to: URL(fileURLWithPath: place.full))
                return Made(data: place.data, name: "\(stem) \(index + 1).\(target)")
            }
        case .sound:
            let ending = target == "alac" ? "m4a" : target == "opus" ? "caf" : target
            let place = spot(ending)
            try await Sounds.write(path, to: place.full, target: target)
            return [Made(data: place.data, name: stem + "." + ending)]
        case .data:
            let place = spot(target)
            try Records.convert(path, to: place.full, target: target)
            return [Made(data: place.data, name: stem + "." + target)]
        case .archive:
            let ending = target
            let place = spot(ending == "tar.gz" ? "gz" : ending)
            try Archives.convert(path, to: place.full, target: target)
            return [Made(data: place.data, name: stem + "." + ending)]
        }
    }
}

enum Pictures {
    static let types: [String: UTType] = ["jpg": .jpeg, "png": .png, "heic": .heic, "avif": UTType("public.avif") ?? .jpeg, "tiff": .tiff, "gif": .gif, "pdf": .pdf]
    /// Formats with no transparency, flattened on white as the offer says.
    static let opaque: Set<String> = ["jpg", "pdf"]

    /// Whether the file held more pictures than the one written.
    @discardableResult
    static func write(_ source: String, to destination: String, target: String, maxSide: Int?, removeLocation: Bool, quality: Double = 0.85) throws -> Bool {
        guard let type = types[target] else { throw Problem(L("Formatic can't make that kind of picture.")) }
        guard let input = CGImageSourceCreateWithURL(URL(fileURLWithPath: source) as CFURL, nil), CGImageSourceGetCount(input) > 0 else {
            throw Problem(L("{file} couldn't be read, so it was left as it is.", ["file": (source as NSString).lastPathComponent]))
        }
        var options: [CFString: Any] = [kCGImageSourceCreateThumbnailWithTransform: true, kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceShouldCacheImmediately: true]
        let properties = CGImageSourceCopyPropertiesAtIndex(input, 0, nil) as? [CFString: Any] ?? [:]
        let width = properties[kCGImagePropertyPixelWidth] as? Int ?? 0, height = properties[kCGImagePropertyPixelHeight] as? Int ?? 0
        options[kCGImageSourceThumbnailMaxPixelSize] = min(maxSide ?? Int.max, max(width, height, 1))
        guard var image = CGImageSourceCreateThumbnailAtIndex(input, 0, options as CFDictionary) else {
            throw Problem(L("{file} couldn't be read, so it was left as it is.", ["file": (source as NSString).lastPathComponent]))
        }
        if opaque.contains(target), let flat = flattened(image) { image = flat }
        guard let output = CGImageDestinationCreateWithURL(URL(fileURLWithPath: destination) as CFURL, type.identifier as CFString, 1, nil) else {
            throw Problem(L("This Mac can't make that kind of picture."))
        }
        var written = properties
        // The picture was already turned upright above.
        written[kCGImagePropertyOrientation] = 1
        if var tiff = written[kCGImagePropertyTIFFDictionary] as? [CFString: Any] {
            tiff[kCGImagePropertyTIFFOrientation] = 1
            written[kCGImagePropertyTIFFDictionary] = tiff
        }
        if removeLocation { written[kCGImagePropertyGPSDictionary] = nil }
        written[kCGImageDestinationLossyCompressionQuality] = quality
        CGImageDestinationAddImage(output, image, written as CFDictionary)
        guard CGImageDestinationFinalize(output) else { throw Problem(L("This Mac can't make that kind of picture.")) }
        return CGImageSourceGetCount(input) > 1
    }

    static func hasLocation(_ path: String) -> Bool {
        guard let input = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(input, 0, nil) as? [CFString: Any] else { return false }
        return properties[kCGImagePropertyGPSDictionary] != nil
    }

    private static func flattened(_ image: CGImage) -> CGImage? {
        guard let context = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: image.width, height: image.height))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return context.makeImage()
    }

    /// Every page as a picture, at about 200 dots an inch.
    static func pages(of source: String, target: String) throws -> [Data] {
        guard let document = PDFDocument(url: URL(fileURLWithPath: source)), document.pageCount > 0 else {
            throw Problem(L("{file} couldn't be read, so it was left as it is.", ["file": (source as NSString).lastPathComponent]))
        }
        guard document.pageCount <= 64 else { throw Problem(L("That has {count} pages. Formatic does at most 64 at a time.", ["count": document.pageCount])) }
        guard let type = types[target], target != "pdf" else { throw Problem(L("Formatic can't make that kind of picture.")) }
        return try (0..<document.pageCount).map { index in
            guard let page = document.page(at: index) else { throw Problem(L("A page couldn't be read.")) }
            let box = page.bounds(for: .mediaBox), scale: CGFloat = 200 / 72
            guard let context = CGContext(data: nil, width: Int(box.width * scale), height: Int(box.height * scale), bitsPerComponent: 8, bytesPerRow: 0,
                                          space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { throw Problem(L("A page couldn't be read.")) }
            context.setFillColor(CGColor(gray: 1, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: context.width, height: context.height))
            context.scaleBy(x: scale, y: scale)
            page.draw(with: .mediaBox, to: context)
            let out = NSMutableData()
            guard let image = context.makeImage(), let destination = CGImageDestinationCreateWithData(out, type.identifier as CFString, 1, nil) else { throw Problem(L("A page couldn't be read.")) }
            CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
            guard CGImageDestinationFinalize(destination) else { throw Problem(L("A page couldn't be read.")) }
            return out as Data
        }
    }
}

enum Sounds {
    static func settings(_ target: String, sampleRate: Double, channels: Int) throws -> [String: Any] {
        let rate = min(max(sampleRate, 8000), target == "opus" ? 48000 : 192000)
        var settings: [String: Any] = [AVSampleRateKey: target == "opus" ? 48000 : rate, AVNumberOfChannelsKey: channels]
        switch target {
        case "m4a": settings[AVFormatIDKey] = kAudioFormatMPEG4AAC; settings[AVEncoderBitRateKey] = 96_000 * channels; settings[AVSampleRateKey] = min(rate, 48000)
        case "alac": settings[AVFormatIDKey] = kAudioFormatAppleLossless; settings[AVEncoderBitDepthHintKey] = 24
        case "flac": settings[AVFormatIDKey] = kAudioFormatFLAC; settings[AVEncoderBitDepthHintKey] = 24
        case "opus": settings[AVFormatIDKey] = kAudioFormatOpus; settings[AVEncoderBitRateKey] = 128_000
        case "wav", "aiff":
            settings[AVFormatIDKey] = kAudioFormatLinearPCM; settings[AVLinearPCMBitDepthKey] = 24; settings[AVLinearPCMIsFloatKey] = false
            settings[AVLinearPCMIsBigEndianKey] = target == "aiff"; settings[AVLinearPCMIsNonInterleaved] = false
        default: throw Problem(L("Formatic can't make that kind of sound file."))
        }
        return settings
    }

    static func write(_ source: String, to destination: String, target: String) async throws {
        let unreadable = Problem(L("{file} couldn't be read, so it was left as it is.", ["file": (source as NSString).lastPathComponent]))
        let cannot = Problem(L("This Mac can't make that kind of sound file."))
        guard let input = try? AVAudioFile(forReading: URL(fileURLWithPath: source), commonFormat: .pcmFormatFloat32, interleaved: false) else { throw unreadable }
        let format = input.processingFormat
        guard let wanted = try? settings(target, sampleRate: format.sampleRate, channels: Int(format.channelCount)),
              let output = try? AVAudioFile(forWriting: URL(fileURLWithPath: destination), settings: wanted, commonFormat: .pcmFormatFloat32, interleaved: false),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 65536) else { throw cannot }
        // Some formats only take certain rates (Opus: 48 kHz), so a converter stands between the two when they differ.
        let converter = format.sampleRate == output.processingFormat.sampleRate ? nil : AVAudioConverter(from: format, to: output.processingFormat)
        let ratio = output.processingFormat.sampleRate / format.sampleRate
        guard converter != nil || ratio == 1,
              let resampled = AVAudioPCMBuffer(pcmFormat: output.processingFormat, frameCapacity: AVAudioFrameCount(65536 * ratio) + 1024) else { throw cannot }
        var pace = Pace()
        while input.framePosition < input.length {
            do { try input.read(into: buffer) } catch { throw unreadable }
            if buffer.frameLength == 0 { break }
            do {
                if let converter {
                    var given = false
                    var failure: NSError?
                    resampled.frameLength = 0
                    let status = converter.convert(to: resampled, error: &failure) { _, state in
                        if given { state.pointee = .noDataNow; return nil }
                        given = true
                        state.pointee = .haveData
                        return buffer
                    }
                    guard status != .error else { throw cannot }
                    if resampled.frameLength > 0 { try output.write(from: resampled) }
                } else {
                    try output.write(from: buffer)
                }
            } catch { throw cannot }
            await pace.rest()
        }
    }
}

/// Lists of records between CSV, TSV, JSON and property lists.
enum Records {
    static func convert(_ source: String, to destination: String, target: String) throws {
        let name = (source as NSString).lastPathComponent
        guard let data = FileManager.default.contents(atPath: source) else { throw Problem(L("{file} couldn't be read, so it was left as it is.", ["file": name])) }
        let rows = try read(data, ending: (source as NSString).pathExtension.lowercased(), name: name)
        let out: Data
        switch target {
        case "csv": out = Data(delimited(rows, by: ",").utf8)
        case "tsv": out = Data(delimited(rows, by: "\t").utf8)
        case "json": out = try JSONSerialization.data(withJSONObject: rows, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        case "plist": out = try PropertyListSerialization.data(fromPropertyList: rows, format: .xml, options: 0)
        default: throw Problem(L("Formatic can't make that kind of file."))
        }
        try out.write(to: URL(fileURLWithPath: destination))
    }

    static func read(_ data: Data, ending: String, name: String) throws -> [[String: Any]] {
        let notRecords = Problem(L("{file} isn't a list of records, so it was left as it is.", ["file": name]))
        switch ending {
        case "json":
            guard let value = try? JSONSerialization.jsonObject(with: data) else { throw notRecords }
            if let rows = value as? [[String: Any]] { return rows }
            if let one = value as? [String: Any] { return [one] }
            throw notRecords
        case "plist":
            guard let value = try? PropertyListSerialization.propertyList(from: data, format: nil) else { throw notRecords }
            if let rows = value as? [[String: Any]] { return rows }
            if let one = value as? [String: Any] { return [one] }
            throw notRecords
        case "csv", "tsv":
            guard let text = String(data: data, encoding: .utf8) else { throw notRecords }
            let table = parse(text, by: ending == "tsv" ? "\t" : ",")
            guard let head = table.first else { throw notRecords }
            return table.dropFirst().map { row in
                var record: [String: Any] = [:]
                for (index, key) in head.enumerated() where index < row.count { record[key] = row[index] }
                return record
            }
        default: throw notRecords
        }
    }

    /// RFC 4180: quotes around a field, doubled inside it, and line breaks allowed in a quoted field.
    static func parse(_ text: String, by separator: Character) -> [[String]] {
        var rows: [[String]] = [], row: [String] = [], field = "", quoted = false
        var characters = Array(text)[...]
        while let c = characters.popFirst() {
            if quoted {
                if c == "\"" {
                    if characters.first == "\"" { field.append("\""); characters.removeFirst() } else { quoted = false }
                } else { field.append(c) }
            } else if c == "\"", field.isEmpty {
                quoted = true
            } else if c == separator {
                row.append(field); field = ""
            } else if c == "\n" || c == "\r\n" {
                row.append(field); field = ""; rows.append(row); row = []
            } else if c != "\r" {
                field.append(c)
            }
        }
        if !field.isEmpty || !row.isEmpty { row.append(field); rows.append(row) }
        return rows
    }

    static func delimited(_ rows: [[String: Any]], by separator: String) -> String {
        var keys: [String] = []
        for row in rows { for key in row.keys.sorted() where !keys.contains(key) { keys.append(key) } }
        func cell(_ value: Any?) -> String {
            let text: String
            switch value {
            case nil: text = ""
            case let string as String: text = string
            case let number as NSNumber: text = number.stringValue
            case let other?: text = (try? JSONSerialization.data(withJSONObject: other, options: [.fragmentsAllowed])).map { String(decoding: $0, as: UTF8.self) } ?? "\(other)"
            }
            // A spreadsheet runs a cell starting with these as a formula, so it's kept as text.
            let safe = ["=", "+", "-", "@"].contains(where: { text.hasPrefix($0) }) && Double(text) == nil ? "'" + text : text
            return safe.contains(separator) || safe.contains("\"") || safe.contains("\n") ? "\"" + safe.replacingOccurrences(of: "\"", with: "\"\"") + "\"" : safe
        }
        return ([keys.map { cell($0) }.joined(separator: separator)] + rows.map { row in keys.map { cell(row[$0]) }.joined(separator: separator) }).joined(separator: "\n") + "\n"
    }
}

/// Archives through macOS's own `bsdtar`, which reads most kinds and writes these.
enum Archives {
    /// What an archive may hold once opened, so that a tiny file can't fill the disk.
    static let largest: Int64 = 16 * 1024 * 1024 * 1024
    /// Under the 300 seconds Sidefolk gives a call, so that the person hears why.
    static let patience: TimeInterval = 280

    static func convert(_ source: String, to destination: String, target: String) throws {
        let name = (source as NSString).lastPathComponent
        let unreadable = Problem(L("{file} couldn't be read, so it was left as it is.", ["file": name]))
        let format: [String]
        switch target {
        case "zip": format = ["--format", "zip"]
        case "7z": format = ["--format", "7zip"]
        case "tar": format = ["--format", "pax"]
        case "tar.gz": format = ["--format", "pax", "-z"]
        default: throw Problem(L("Formatic can't make that kind of archive."))
        }
        guard let listing = tar(["-tvf", source]) else { throw unreadable }
        guard unpackedSize(listing) <= largest else { throw Problem(L("{file} is too large to open here.", ["file": name])) }
        let work = Paths.data + "/tmp/" + UUID().uuidString
        try FileManager.default.createDirectory(atPath: work, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(atPath: work) }
        // Without -P, it keeps everything inside `work`, whatever names the archive holds.
        guard tar(["-xf", source, "-C", work]) != nil else { throw unreadable }
        guard tar(["-c"] + format + ["-f", destination, "-C", work, "."]) != nil else {
            throw Problem(L("That archive couldn't be made."))
        }
    }

    /// What `tar` printed, or nil if it failed: `run` reports a failed program by its status, not by throwing.
    private static func tar(_ arguments: [String]) -> String? {
        guard let output = try? run("/usr/bin/bsdtar", arguments, timeout: patience), output.status == 0 else { return nil }
        return output.out
    }

    /// The fifth column of `tar -tv` is each file's size.
    static func unpackedSize(_ listing: String) -> Int64 {
        listing.split(separator: "\n").reduce(0) { total, line in
            let columns = line.split(separator: " ", maxSplits: 5, omittingEmptySubsequences: true)
            return columns.count > 4 ? total &+ (Int64(columns[4]) ?? 0) : total
        }
    }
}

/// Keeps long work under the half a core Sidefolk allows an extension, by resting in proportion to what it used.
struct Pace {
    static let share = 0.45
    private var began = Pace.cpu()
    private var since = Date()

    private static func cpu() -> Double {
        var time = timespec()
        clock_gettime(CLOCK_PROCESS_CPUTIME_ID, &time)
        return Double(time.tv_sec) + Double(time.tv_nsec) / 1e9
    }

    mutating func rest() async {
        let used = Self.cpu() - began, passed = Date().timeIntervalSince(since)
        guard passed >= 0.25 else { return }
        let owed = used / Self.share - passed
        if owed > 0 { try? await Task.sleep(for: .seconds(min(owed, 2))) }
        began = Self.cpu()
        since = Date()
    }
}
