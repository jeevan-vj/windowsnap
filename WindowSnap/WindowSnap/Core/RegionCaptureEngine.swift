import Foundation
import ScreenCaptureKit
import CoreMedia
import CoreImage
import CoreVideo
import AppKit

protocol RegionCaptureDelegate: AnyObject {
    func captureEngine(_ engine: RegionCaptureEngine, didOutputFrame image: CGImage)
    func captureEngine(_ engine: RegionCaptureEngine, didFailWithError error: Error)
}

final class RegionCaptureEngine: NSObject {
    weak var delegate: RegionCaptureDelegate?
    weak var frameSink: RegionFrameSink?

    private var stream: SCStream?
    private var streamOutput: CaptureStreamOutput?

    private let displayID: CGDirectDisplayID
    private var _cropRect: CGRect
    private let frameRate: Int
    private let sampleHandlerQueue = DispatchQueue(
        label: "com.windowsnap.regionshare.sample-handler",
        qos: .userInteractive
    )

    private let cropRectLock = NSLock()
    private var cropRect: CGRect {
        get {
            cropRectLock.lock()
            defer { cropRectLock.unlock() }
            return _cropRect
        }
        set {
            cropRectLock.lock()
            _cropRect = newValue
            cropRectLock.unlock()
        }
    }

    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    private let renderLock = NSLock()
    private let stateLock = NSLock()
    private var isRunning = false
    private var isStoppingRequested = false

    init(displayID: CGDirectDisplayID, cropRect: CGRect, frameRate: Int = 30) {
        self.displayID = displayID
        self._cropRect = cropRect
        self.frameRate = frameRate
        super.init()
    }

    func updateCropRect(_ rect: CGRect) {
        cropRect = rect
    }

    /// Marks the engine so an in-flight `startCapture()` aborts after the next await.
    func requestStop() {
        stateLock.lock()
        isStoppingRequested = true
        stateLock.unlock()
    }

    func startCapture() async throws {
        guard canBeginStart() else { return }

        let content = try await SCShareableContent.current
        guard !stopWasRequested() else { return }

        guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
            throw CaptureError.displayNotFound
        }

        let excludedWindows: [SCWindow]
        if let bundleID = Bundle.main.bundleIdentifier {
            excludedWindows = content.windows.filter { $0.owningApplication?.bundleIdentifier == bundleID }
        } else {
            excludedWindows = []
        }
        let filter = SCContentFilter(display: display, excludingWindows: excludedWindows)

        let config = SCStreamConfiguration()
        config.width = Int(display.width)
        config.height = Int(display.height)
        config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(frameRate))
        config.showsCursor = true
        config.pixelFormat = kCVPixelFormatType_32BGRA
        config.queueDepth = 3

        let stream = SCStream(filter: filter, configuration: config, delegate: self)
        let output = CaptureStreamOutput { [weak self] sampleBuffer in
            self?.processSampleBuffer(sampleBuffer)
        }

        try stream.addStreamOutput(output, type: .screen, sampleHandlerQueue: sampleHandlerQueue)
        try await stream.startCapture()

        if !commitStartedStream(stream, output: output) {
            try? await stream.stopCapture()
            return
        }

        print("🎬 Capture started for display \(displayID)")
    }

    func stopCapture() async {
        requestStop()
        guard let stream = takeRunningStream() else { return }

        do {
            try await stream.stopCapture()
        } catch {
            print("⚠️ Error stopping capture: \(error)")
        }

        markStopped()
        print("⏹️ Capture stopped")
    }

    private func canBeginStart() -> Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return !isRunning && !isStoppingRequested
    }

    private func stopWasRequested() -> Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return isStoppingRequested
    }

    private func commitStartedStream(_ stream: SCStream, output: CaptureStreamOutput) -> Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        if isStoppingRequested { return false }
        self.stream = stream
        self.streamOutput = output
        self.isRunning = true
        return true
    }

    private func takeRunningStream() -> SCStream? {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard isRunning else { return nil }
        return stream
    }

    private func markStopped() {
        stateLock.lock()
        stream = nil
        streamOutput = nil
        isRunning = false
        isStoppingRequested = false
        stateLock.unlock()
    }

    private func processSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        if stopWasRequested() || (delegate == nil && frameSink == nil) {
            return
        }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)

        let displayBounds = CGDisplayBounds(displayID)
        let scaleX = CGFloat(CVPixelBufferGetWidth(pixelBuffer)) / displayBounds.width
        let scaleY = CGFloat(CVPixelBufferGetHeight(pixelBuffer)) / displayBounds.height

        let currentCropRect = cropRect
        let localX = currentCropRect.origin.x - displayBounds.origin.x
        let localYFromBottom = currentCropRect.origin.y - displayBounds.origin.y
        let localYFromTop = displayBounds.height - localYFromBottom - currentCropRect.height

        let scaledCropRect = CGRect(
            x: localX * scaleX,
            y: localYFromTop * scaleY,
            width: currentCropRect.width * scaleX,
            height: currentCropRect.height * scaleY
        )

        let pixelWidth = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
        let pixelHeight = CGFloat(CVPixelBufferGetHeight(pixelBuffer))
        let clampedCropRect = scaledCropRect.intersection(
            CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight)
        )

        guard clampedCropRect.width > 0, clampedCropRect.height > 0 else { return }

        let outputWidth = max(1, Int(clampedCropRect.width.rounded(.down)))
        let outputHeight = max(1, Int(clampedCropRect.height.rounded(.down)))
        let outputRect = CGRect(x: 0, y: 0, width: outputWidth, height: outputHeight)
        var renderedImage: CGImage?
        var renderedPixelBuffer: CVPixelBuffer?
        autoreleasepool {
            let croppedImage = ciImage.cropped(to: clampedCropRect)
            let translatedImage = croppedImage.transformed(
                by: CGAffineTransform(
                    translationX: -clampedCropRect.origin.x,
                    y: -clampedCropRect.origin.y
                )
            )
            renderLock.lock()
            renderedImage = ciContext.createCGImage(translatedImage, from: outputRect)
            renderedPixelBuffer = makePixelBuffer(width: outputWidth, height: outputHeight)
            if let renderedPixelBuffer {
                ciContext.render(
                    translatedImage,
                    to: renderedPixelBuffer,
                    bounds: outputRect,
                    colorSpace: CGColorSpaceCreateDeviceRGB()
                )
            }
            renderLock.unlock()
        }

        guard let cgImage = renderedImage else { return }

        if let renderedPixelBuffer {
            frameSink?.regionCaptureDidOutputFrame(
                renderedPixelBuffer,
                presentationTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            )
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.captureEngine(self, didOutputFrame: cgImage)
        }
    }

    private func makePixelBuffer(width: Int, height: Int) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let attributes = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: [:]
        ] as CFDictionary
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attributes,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess else { return nil }
        return pixelBuffer
    }

    enum CaptureError: LocalizedError {
        case displayNotFound
        case permissionDenied
        case streamCreationFailed

        var errorDescription: String? {
            switch self {
            case .displayNotFound:
                return "Display not found"
            case .permissionDenied:
                return "Screen recording permission denied"
            case .streamCreationFailed:
                return "Failed to create capture stream"
            }
        }
    }
}

extension RegionCaptureEngine: SCStreamDelegate {
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        stateLock.lock()
        let wasIntentional = isStoppingRequested
        isRunning = false
        if wasIntentional {
            isStoppingRequested = false
        }
        stateLock.unlock()

        if wasIntentional { return }

        print("❌ Stream stopped with error: \(error)")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.captureEngine(self, didFailWithError: error)
        }
    }
}

private final class CaptureStreamOutput: NSObject, SCStreamOutput {
    private let handler: (CMSampleBuffer) -> Void

    init(handler: @escaping (CMSampleBuffer) -> Void) {
        self.handler = handler
        super.init()
    }

    func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of type: SCStreamOutputType
    ) {
        guard type == .screen else { return }
        handler(sampleBuffer)
    }
}
