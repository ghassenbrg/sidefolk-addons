// Adapted from Miraya (macos/Sources/Miraya/CaptureEngine.swift), MIT License, Copyright (c) 2026 Ghassen Bargougui:
// licenses/Miraya-LICENSE.txt. Only its WebRTC path: frames go to the sender as they come, and WebRTC encodes them
// (the Mac app also kept an older encoder for TVs from before WebRTC; the extension needs a TV that has it).
// ScreenCaptureKit runs in the extension's sandbox with permissions.screen; macOS asks the person, for Sidefolk.
import Foundation
@preconcurrency import ScreenCaptureKit
import CoreGraphics
import CoreMedia
import CoreVideo

/// Display, window or area capture with the Mac's sound. Lifecycle methods are called from the main actor; samples
/// and callbacks stay on captureQueue.
final class CaptureEngine: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    var onFrame: ((CVPixelBuffer, CMTime) -> Void)?
    var onAudio: ((Data, UInt64) -> Void)?
    var onError: ((Error) -> Void)?

    private let captureQueue = DispatchQueue(label: "dev.sidefolk.miraya.capture", qos: .userInteractive)
    private var captureStream: SCStream?
    private var running = false
    private var generation = UUID()
    private var displayID: CGDirectDisplayID = 0
    private var maximumOutputSize: (width: Int, height: Int)?
    private var quality: CaptureQuality = .balanced
    private var capturesAudio = false
    private var configuredSize = (width: 0, height: 0)
    private var lastDisplayCheck: UInt64 = 0
    private var changingConfiguration = false
    private var sourceKind = CaptureSourceKind.display
    private var region: CaptureRegion?

    static func isPermissionDenied(_ failure: Error) -> Bool {
        let error = failure as NSError
        return error.domain == SCStreamErrorDomain && error.code == SCStreamError.Code.userDeclined.rawValue
    }

    func start(displayID: CGDirectDisplayID, quality: CaptureQuality, audio: Bool, maximumOutputSize: (width: Int, height: Int)? = nil,
               source: CaptureSourceKind = .display, windowID: UInt32? = nil, region: CaptureRegion? = nil) async throws {
        await stop()
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        let displays = content.displays
        try Task.checkCancellation()
        guard let display = displays.first(where: { $0.displayID == displayID }) ?? (source == .window ? displays.first : nil) else {
            throw CaptureFailure.displayUnavailable
        }
        let bounds = CGDisplayBounds(display.displayID)
        // SCDisplay width/height may be logical pixels on Retina displays. Use native pixel dimensions while taking
        // rotation from display bounds.
        var size = Self.displaySize(display.displayID, fallbackWidth: display.width, fallbackHeight: display.height, bounds: bounds)
        let filter: SCContentFilter
        if source == .window {
            guard let window = content.windows.first(where: { $0.windowID == windowID }), window.frame.width > 0, window.frame.height > 0 else {
                throw CaptureFailure.displayUnavailable
            }
            filter = SCContentFilter(desktopIndependentWindow: window)
            let containing = displays.max {
                $0.frame.intersection(window.frame).width * $0.frame.intersection(window.frame).height
                    < $1.frame.intersection(window.frame).width * $1.frame.intersection(window.frame).height
            } ?? display
            let scale = Double(CGDisplayCopyDisplayMode(containing.displayID)?.pixelWidth ?? containing.width) / max(1, containing.frame.width)
            size = (Int(window.frame.width * scale), Int(window.frame.height * scale))
        } else {
            filter = SCContentFilter(display: display, excludingWindows: [])
            if source == .area {
                guard let region, region.validated(displayWidth: bounds.width, displayHeight: bounds.height) else { throw CaptureFailure.displayUnavailable }
                size = (Int(region.width * Double(size.width) / bounds.width), Int(region.height * Double(size.height) / bounds.height))
            }
        }
        let fitted = Self.outputSize(width: size.width, height: size.height, quality: quality, limit: maximumOutputSize)
        let config = Self.configuration(width: fitted.width, height: fitted.height, quality: quality, audio: audio)
        if source == .area, let region { config.sourceRect = CGRect(x: region.x, y: region.y, width: region.width, height: region.height) }
        let stream = SCStream(filter: filter, configuration: config, delegate: self)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: captureQueue)
        if audio { try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: captureQueue) }
        await withCheckedContinuation { continuation in
            captureQueue.async {
                self.displayID = display.displayID
                self.sourceKind = source; self.region = region
                self.maximumOutputSize = maximumOutputSize
                self.quality = quality
                self.capturesAudio = audio
                self.configuredSize = fitted
                self.captureStream = stream
                self.running = true
                self.generation = UUID()
                self.lastDisplayCheck = 0
                self.changingConfiguration = false
                continuation.resume()
            }
        }
        do {
            try await stream.startCapture()
            try Task.checkCancellation()
            let stillCurrent: Bool = await withCheckedContinuation { continuation in
                captureQueue.async { continuation.resume(returning: self.running && self.captureStream === stream) }
            }
            guard stillCurrent else {
                try? await stream.stopCapture()
                throw CancellationError()
            }
        } catch {
            // An overlapping stop or new start must not let this old operation tear down the newer stream.
            let stillCurrent: Bool = await withCheckedContinuation { continuation in
                captureQueue.async { continuation.resume(returning: self.captureStream === stream) }
            }
            if stillCurrent { await stop() }
            throw error
        }
    }

    func stop() async {
        let previous: SCStream? = await withCheckedContinuation { continuation in
            captureQueue.async {
                let previous = self.captureStream
                self.running = false
                self.generation = UUID()
                self.captureStream = nil
                continuation.resume(returning: previous)
            }
        }
        if let previous { try? await previous.stopCapture() }
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard running, stream === captureStream, CMSampleBufferIsValid(sampleBuffer), CMSampleBufferDataIsReady(sampleBuffer) else { return }
        do {
            switch type {
            case .screen: video(sampleBuffer)
            case .audio: if capturesAudio { try audio(sampleBuffer) }
            default: break
            }
        } catch { fail(error) }
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        captureQueue.async {
            guard stream === self.captureStream, self.running else { return }
            self.fail(error)
        }
    }

    private func video(_ sample: CMSampleBuffer) {
        let now = DispatchTime.now().uptimeNanoseconds
        if now - lastDisplayCheck > 1_000_000_000 {
            lastDisplayCheck = now
            checkDisplay()
        }
        if let attachments = CMSampleBufferGetSampleAttachmentsArray(sample, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
           let raw = attachments.first?[.status] as? Int,
           let status = SCFrameStatus(rawValue: raw), status != .complete { return }
        guard let buffer = CMSampleBufferGetImageBuffer(sample) else { return }
        onFrame?(buffer, CMSampleBufferGetPresentationTimeStamp(sample))
    }

    private func audio(_ sample: CMSampleBuffer) throws {
        let data = try SystemAudioPCM.convert(sample)
        let start = Self.microseconds(CMSampleBufferGetPresentationTimeStamp(sample))
        var offset = 0
        while offset < data.count {
            let count = min(19_200, data.count - offset)
            let pts = start + UInt64(offset / 4) * 1_000_000 / 48_000
            onAudio?(Data(data[offset..<offset + count]), pts)
            offset += count
        }
    }

    static func microseconds(_ time: CMTime) -> UInt64 {
        let value = CMTimeConvertScale(time, timescale: 1_000_000, method: .roundTowardZero).value
        return value > 0 ? UInt64(value) : 0
    }

    private func fail(_ error: Error) {
        guard running else { return }
        running = false
        onError?(error)
    }

    private func checkDisplay() {
        // A desktop-independent window may move to another screen or Space; ScreenCaptureKit scales it.
        guard sourceKind != .window else { return }
        guard CGDisplayIsActive(displayID) != 0 else { fail(CaptureFailure.displayUnavailable); return }
        guard !changingConfiguration, let stream = captureStream else { return }
        let bounds = CGDisplayBounds(displayID)
        var native = Self.displaySize(displayID, fallbackWidth: configuredSize.width, fallbackHeight: configuredSize.height, bounds: bounds)
        if sourceKind == .area, let region {
            guard region.validated(displayWidth: bounds.width, displayHeight: bounds.height) else { fail(CaptureFailure.displayUnavailable); return }
            native = (Int(region.width * Double(native.width) / bounds.width), Int(region.height * Double(native.height) / bounds.height))
        }
        let fitted = Self.outputSize(width: native.width, height: native.height, quality: quality, limit: maximumOutputSize)
        guard fitted != configuredSize else { return }
        changingConfiguration = true
        let expected = generation
        let config = Self.configuration(width: fitted.width, height: fitted.height, quality: quality, audio: capturesAudio)
        if sourceKind == .area, let region { config.sourceRect = CGRect(x: region.x, y: region.y, width: region.width, height: region.height) }
        Task {
            do {
                try await stream.updateConfiguration(config)
                captureQueue.async {
                    guard self.generation == expected else { return }
                    self.configuredSize = fitted
                    self.changingConfiguration = false
                }
            } catch {
                captureQueue.async {
                    guard self.generation == expected else { return }
                    self.changingConfiguration = false
                    self.fail(error)
                }
            }
        }
    }

    static func outputSize(width: Int, height: Int, quality: CaptureQuality, limit: (width: Int, height: Int)?) -> (width: Int, height: Int) {
        let maximumWidth = min(quality.maxWidth, limit?.width ?? quality.maxWidth)
        let maximumHeight = min(quality.maxHeight, limit?.height ?? quality.maxHeight)
        let size = VideoSize.fit(width: width, height: height, maxWidth: maximumWidth, maxHeight: maximumHeight)
        return (size.width, size.height)
    }

    private static func displaySize(_ id: CGDirectDisplayID, fallbackWidth: Int, fallbackHeight: Int, bounds: CGRect) -> (width: Int, height: Int) {
        // The display mode's pixel dimensions describe backing pixels and keep the detail when fitting to 1080p.
        let mode = CGDisplayCopyDisplayMode(id)
        let nativeWidth = mode?.pixelWidth ?? CGDisplayPixelsWide(id)
        let nativeHeight = mode?.pixelHeight ?? CGDisplayPixelsHigh(id)
        let landscape = bounds.width >= bounds.height
        let width = nativeWidth > 0 ? nativeWidth : fallbackWidth
        let height = nativeHeight > 0 ? nativeHeight : fallbackHeight
        return landscape ? (max(width, height), min(width, height)) : (min(width, height), max(width, height))
    }

    private static func configuration(width: Int, height: Int, quality: CaptureQuality, audio: Bool) -> SCStreamConfiguration {
        let config = SCStreamConfiguration()
        config.width = width
        config.height = height
        config.pixelFormat = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        config.minimumFrameInterval = CMTime(value: 1, timescale: Int32(quality.fps))
        config.queueDepth = 3
        config.showsCursor = true
        config.scalesToFit = true
        config.backgroundColor = CGColor.black
        config.colorSpaceName = CGColorSpace.sRGB
        config.preservesAspectRatio = true
        config.capturesAudio = audio
        config.sampleRate = 48_000
        config.channelCount = 2
        config.excludesCurrentProcessAudio = true
        return config
    }
}
