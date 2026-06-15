import Foundation
import ScreenCaptureKit
import CoreMedia
import CoreImage
import AppKit

@available(macOS 12.3, *)
protocol RegionCaptureDelegate: AnyObject {
    func captureEngine(_ engine: RegionCaptureEngine, didOutputFrame image: CGImage)
    func captureEngine(_ engine: RegionCaptureEngine, didFailWithError error: Error)
}

@available(macOS 12.3, *)
class RegionCaptureEngine: NSObject {
    private static let lastStopLock = NSLock()
    private static var lastStopCompletedAtMs: Int?
    
    weak var delegate: RegionCaptureDelegate?
    
    private var stream: SCStream?
    private var streamOutput: CaptureStreamOutput?
    private var isRunning = false
    private var isStoppingRequested = false
    
    private let displayID: CGDirectDisplayID
    private var _cropRect: CGRect
    private let frameRate: Int
    private let engineID = UUID().uuidString
    private let sampleHandlerQueue = DispatchQueue(label: "com.windowsnap.regionshare.sample-handler", qos: .userInteractive)
    
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
    private var didLogFirstFrame = false
    private let frameStateLock = NSLock()
    private var frameSequence = 0
    private var didLogEarlyDropWhileStopping = false
    private var inFlightFrames = 0
    private var didLogConcurrentFrameProcessing = false
    
    init(displayID: CGDirectDisplayID, cropRect: CGRect, frameRate: Int = 30) {
        self.displayID = displayID
        self._cropRect = cropRect
        self.frameRate = frameRate
        super.init()
    }
    
    func updateCropRect(_ rect: CGRect) {
        cropRect = rect
    }
    
    func startCapture() async throws {
        guard !isRunning else { return }
        isStoppingRequested = false
        let nowMs = Int(Date().timeIntervalSince1970 * 1000)
        Self.lastStopLock.lock()
        let previousStopMs = Self.lastStopCompletedAtMs
        Self.lastStopLock.unlock()
        let msSinceLastStop = previousStopMs.map { nowMs - $0 } ?? -1
        // #region agent log
        RegionShareDebugLog.write(hypothesis: "H5", message: "engine startCapture entry", data: [
            "runId": "run6",
            "engineID": engineID,
            "displayID": displayID,
            "isRunning": isRunning,
            "isMainThread": Thread.isMainThread,
            "msSinceLastStop": msSinceLastStop
        ], sync: true)
        // #endregion
        
        // #region agent log
        RegionShareDebugLog.write(hypothesis: "H14,H15", message: "engine content fetch begin", data: [
            "runId": "run6",
            "engineID": engineID,
            "displayID": displayID,
            "isMainThread": Thread.isMainThread,
            "msSinceLastStop": msSinceLastStop
        ], sync: true)
        // #endregion
        let content: SCShareableContent
        do {
            content = try await SCShareableContent.current
        } catch {
            // #region agent log
            RegionShareDebugLog.write(hypothesis: "H14,H15", message: "engine content fetch throw", data: [
                "runId": "run6",
                "engineID": engineID,
                "error": String(describing: error)
            ], sync: true)
            // #endregion
            throw error
        }
        // #region agent log
        RegionShareDebugLog.write(hypothesis: "H14,H15", message: "engine content fetch end", data: [
            "runId": "run6",
            "engineID": engineID,
            "displayCount": content.displays.count,
            "isMainThread": Thread.isMainThread
        ], sync: true)
        // #endregion
        
        guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
            // #region agent log
            RegionShareDebugLog.write(hypothesis: "J", message: "startCapture: display NOT found", data: ["runId": "post-fix", "displayID": displayID, "available": content.displays.map { $0.displayID }], sync: true)
            // #endregion
            throw CaptureError.displayNotFound
        }
        
        // #region agent log
        RegionShareDebugLog.write(hypothesis: "J", message: "startCapture: display found", data: ["runId": "post-fix", "displayID": displayID, "w": display.width, "h": display.height], sync: true)
        // #endregion
        let filter = SCContentFilter(display: display, excludingWindows: [])
        
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
        
        self.stream = stream
        self.streamOutput = output
        self.isRunning = true
        
        // #region agent log
        RegionShareDebugLog.write(hypothesis: "J", message: "startCapture: stream running", data: ["runId": "post-fix", "displayID": displayID], sync: true)
        // #endregion
        print("🎬 Capture started for display \(displayID)")
    }
    
    func stopCapture() async {
        // #region agent log
        RegionShareDebugLog.write(hypothesis: "H5", message: "engine stopCapture entry", data: [
            "runId": "run1",
            "engineID": engineID,
            "isRunning": isRunning,
            "hasStream": stream != nil
        ], sync: true)
        // #endregion
        guard isRunning, let stream = stream else {
            // #region agent log
            RegionShareDebugLog.write(hypothesis: "H5", message: "engine stopCapture no-op", data: [
                "runId": "run1",
                "engineID": engineID
            ], sync: true)
            // #endregion
            return
        }
        isStoppingRequested = true
        
        do {
            try await stream.stopCapture()
        } catch {
            print("⚠️ Error stopping capture: \(error)")
        }
        
        self.stream = nil
        self.streamOutput = nil
        self.isRunning = false
        self.isStoppingRequested = false
        let stopCompletedMs = Int(Date().timeIntervalSince1970 * 1000)
        Self.lastStopLock.lock()
        Self.lastStopCompletedAtMs = stopCompletedMs
        Self.lastStopLock.unlock()
        // #region agent log
        RegionShareDebugLog.write(hypothesis: "H5", message: "engine stopCapture complete", data: [
            "runId": "run6",
            "engineID": engineID,
            "stopCompletedAtMs": stopCompletedMs
        ], sync: true)
        // #endregion
        
        print("⏹️ Capture stopped")
    }
    
    private func processSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        frameStateLock.lock()
        inFlightFrames += 1
        let currentInFlightFrames = inFlightFrames
        if currentInFlightFrames > 1, !didLogConcurrentFrameProcessing {
            didLogConcurrentFrameProcessing = true
            // #region agent log
            RegionShareDebugLog.write(hypothesis: "H16", message: "concurrent frame processing detected", data: [
                "runId": "post-fix-run7",
                "engineID": engineID,
                "inFlightFrames": currentInFlightFrames
            ], sync: true)
            // #endregion
        }
        frameStateLock.unlock()
        
        defer {
            frameStateLock.lock()
            inFlightFrames -= 1
            frameStateLock.unlock()
        }
        
        frameStateLock.lock()
        frameSequence += 1
        let currentFrame = frameSequence
        frameStateLock.unlock()
        
        if isStoppingRequested || delegate == nil {
            if !didLogEarlyDropWhileStopping {
                didLogEarlyDropWhileStopping = true
                // #region agent log
                RegionShareDebugLog.write(hypothesis: "H10", message: "engine dropped frame early", data: [
                    "runId": "post-fix-run4",
                    "engineID": engineID,
                    "frame": currentFrame,
                    "isStoppingRequested": isStoppingRequested,
                    "delegateNil": delegate == nil
                ], sync: true)
                // #endregion
            }
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
        
        // #region agent log
        if !didLogFirstFrame {
            didLogFirstFrame = true
            RegionShareDebugLog.write(hypothesis: "K", message: "processSampleBuffer first frame", data: [
                "runId": "post-fix-v2",
                "displayID": displayID,
                "displayBounds": NSStringFromRect(displayBounds),
                "pixelW": CVPixelBufferGetWidth(pixelBuffer),
                "pixelH": CVPixelBufferGetHeight(pixelBuffer),
                "cropRect": NSStringFromRect(currentCropRect),
                "localYFromBottom": localYFromBottom,
                "localYFromTop": localYFromTop,
                "scaledCropRect": NSStringFromRect(scaledCropRect),
                "clampedCropRect": NSStringFromRect(clampedCropRect)
            ], sync: true)
        }
        // #endregion
        
        guard clampedCropRect.width > 0, clampedCropRect.height > 0 else { return }
        
        let outputRect = CGRect(origin: .zero, size: clampedCropRect.size)
        var renderedImage: CGImage?
        autoreleasepool {
            let croppedImage = ciImage.cropped(to: clampedCropRect)
            let translatedImage = croppedImage.transformed(by: CGAffineTransform(translationX: -clampedCropRect.origin.x, y: -clampedCropRect.origin.y))
            renderLock.lock()
            renderedImage = ciContext.createCGImage(translatedImage, from: outputRect)
            renderLock.unlock()
        }
        
        guard let cgImage = renderedImage else { return }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.captureEngine(self, didOutputFrame: cgImage)
        }
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
    
    deinit {
        // #region agent log
        RegionShareDebugLog.write(hypothesis: "H7", message: "engine deinit", data: [
            "runId": "run6",
            "engineID": engineID,
            "displayID": displayID,
            "isRunning": isRunning,
            "isStoppingRequested": isStoppingRequested
        ], sync: true)
        // #endregion
    }
}

@available(macOS 12.3, *)
extension RegionCaptureEngine: SCStreamDelegate {
    func stream(_ stream: SCStream, didStopWithError error: Error) {
        // #region agent log
        RegionShareDebugLog.write(hypothesis: "H4,H5", message: "engine didStopWithError callback", data: [
            "runId": "run1",
            "engineID": engineID,
            "isStoppingRequested": isStoppingRequested,
            "isMainThread": Thread.isMainThread,
            "error": String(describing: error)
        ], sync: true)
        // #endregion
        if isStoppingRequested {
            // #region agent log
            RegionShareDebugLog.write(hypothesis: "T", message: "stream stopped during intentional stop", data: [
                "runId": "post-fix-v9",
                "displayID": displayID,
                "error": String(describing: error)
            ], sync: true)
            // #endregion
            isRunning = false
            isStoppingRequested = false
            return
        }
        
        print("❌ Stream stopped with error: \(error)")
        isRunning = false
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.captureEngine(self, didFailWithError: error)
        }
    }
}

@available(macOS 12.3, *)
private class CaptureStreamOutput: NSObject, SCStreamOutput {
    private let handler: (CMSampleBuffer) -> Void
    
    init(handler: @escaping (CMSampleBuffer) -> Void) {
        self.handler = handler
        super.init()
    }
    
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen else { return }
        handler(sampleBuffer)
    }
}
