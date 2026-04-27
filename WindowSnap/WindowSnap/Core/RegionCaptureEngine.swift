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
    
    weak var delegate: RegionCaptureDelegate?
    
    private var stream: SCStream?
    private var streamOutput: CaptureStreamOutput?
    private var isRunning = false
    
    private let displayID: CGDirectDisplayID
    private var _cropRect: CGRect
    private let frameRate: Int
    
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
        
        let content = try await SCShareableContent.current
        
        guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
            throw CaptureError.displayNotFound
        }
        
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
        
        try stream.addStreamOutput(output, type: .screen, sampleHandlerQueue: .global(qos: .userInteractive))
        
        try await stream.startCapture()
        
        self.stream = stream
        self.streamOutput = output
        self.isRunning = true
        
        print("🎬 Capture started for display \(displayID)")
    }
    
    func stopCapture() async {
        guard isRunning, let stream = stream else { return }
        
        do {
            try await stream.stopCapture()
        } catch {
            print("⚠️ Error stopping capture: \(error)")
        }
        
        self.stream = nil
        self.streamOutput = nil
        self.isRunning = false
        
        print("⏹️ Capture stopped")
    }
    
    private func processSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        let displayBounds = CGDisplayBounds(displayID)
        let scaleX = CGFloat(CVPixelBufferGetWidth(pixelBuffer)) / displayBounds.width
        let scaleY = CGFloat(CVPixelBufferGetHeight(pixelBuffer)) / displayBounds.height
        
        let currentCropRect = cropRect
        let scaledCropRect = CGRect(
            x: (currentCropRect.origin.x - displayBounds.origin.x) * scaleX,
            y: (displayBounds.height - currentCropRect.origin.y - currentCropRect.height) * scaleY,
            width: currentCropRect.width * scaleX,
            height: currentCropRect.height * scaleY
        )
        
        let croppedImage = ciImage.cropped(to: scaledCropRect)
        let translatedImage = croppedImage.transformed(by: CGAffineTransform(translationX: -scaledCropRect.origin.x, y: -scaledCropRect.origin.y))
        
        let outputRect = CGRect(origin: .zero, size: scaledCropRect.size)
        
        guard let cgImage = ciContext.createCGImage(translatedImage, from: outputRect) else { return }
        
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
}

@available(macOS 12.3, *)
extension RegionCaptureEngine: SCStreamDelegate {
    func stream(_ stream: SCStream, didStopWithError error: Error) {
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
