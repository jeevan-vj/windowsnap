import CoreMedia
import CoreVideo
import Darwin
import Foundation
import IOSurface

struct RegionFrameMetadata: Codable, Equatable {
    let hostSessionID: UUID
    let width: Int
    let height: Int
    let frameRate: Int
    let pixelFormat: UInt32
    let presentationTimeSeconds: Double
    let updatedAt: Date
    let isPlaceholder: Bool
    let surfaceID: UInt32
    let sequence: UInt64

    var isActive: Bool {
        Date().timeIntervalSince(updatedAt) < 2.0 && !isPlaceholder
    }
}

final class RegionFrameHub: RegionFrameSink {
    static let defaultAppGroupIdentifier = "group.com.jeevanwijerathna.windowsnap"
    static let shared = RegionFrameHub()

    static var appGroupIdentifier: String {
        Bundle.main.object(forInfoDictionaryKey: "WindowSnapCameraAppGroupIdentifier") as? String
            ?? defaultAppGroupIdentifier
    }

    private struct PendingFrame {
        let pixelBuffer: CVPixelBuffer
        let presentationTime: CMTime
        let sequence: UInt64
    }

    private let queue = DispatchQueue(label: "com.windowsnap.region-frame-hub", qos: .userInteractive)
    private let pendingLock = NSLock()
    private let directory: URL
    private let metadataURL: URL
    private let legacyFrameURL: URL
    private let frameRate: Int
    private let fileManager: FileManager
    private var pendingFrame: PendingFrame?
    private var isDrainScheduled = false
    private var nextSequence: UInt64 = 0
    private var lastPublishedPresentationTime = CMTime.invalid
    private var pools: [String: CVPixelBufferPool] = [:]
    private let hostSessionID = UUID()
    private var publishedBuffers: [CVPixelBuffer] = []
    private let publishedBufferLimit = 4

    init(
        directory: URL? = nil,
        frameRate: Int = 30,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        self.frameRate = frameRate

        let resolvedDirectory: URL
        if let directory {
            resolvedDirectory = directory
        } else if let appGroupURL = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier
        ) {
            resolvedDirectory = appGroupURL.appendingPathComponent("RegionFrameHub", isDirectory: true)
        } else if let appSupport = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first {
            resolvedDirectory = appSupport.appendingPathComponent(
                "WindowSnap/RegionFrameHub",
                isDirectory: true
            )
        } else {
            resolvedDirectory = fileManager.temporaryDirectory.appendingPathComponent(
                "WindowSnap/RegionFrameHub",
                isDirectory: true
            )
        }

        self.directory = resolvedDirectory
        self.metadataURL = resolvedDirectory.appendingPathComponent("metadata.json")
        self.legacyFrameURL = resolvedDirectory.appendingPathComponent("latest.bgra")
    }

    var currentMetadata: RegionFrameMetadata? {
        queue.sync {
            guard let data = try? Data(contentsOf: metadataURL) else { return nil }
            return try? JSONDecoder().decode(RegionFrameMetadata.self, from: data)
        }
    }

    /// Retained for source compatibility. Frames are now shared through `surfaceID` in metadata.
    var currentFrameURL: URL { legacyFrameURL }
    var currentMetadataURL: URL { metadataURL }

    func prepare() {
        queue.sync {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            try? fileManager.removeItem(at: legacyFrameURL)
            publishPlaceholderLocked(width: 1280, height: 720)
        }
    }

    func markInactive() {
        pendingLock.lock()
        pendingFrame = nil
        pendingLock.unlock()
        queue.async { [weak self] in
            self?.publishPlaceholderLocked(width: 1280, height: 720)
        }
    }

    func regionCaptureDidOutputFrame(_ frame: CVPixelBuffer, presentationTime: CMTime) {
        pendingLock.lock()
        nextSequence &+= 1
        pendingFrame = PendingFrame(
            pixelBuffer: frame,
            presentationTime: presentationTime,
            sequence: nextSequence
        )
        let shouldSchedule = !isDrainScheduled
        isDrainScheduled = true
        pendingLock.unlock()

        guard shouldSchedule else { return }
        queue.async { [weak self] in
            self?.drainPendingFramesLocked()
        }
    }

    private func drainPendingFramesLocked() {
        while true {
            pendingLock.lock()
            guard let pendingFrame else {
                isDrainScheduled = false
                pendingLock.unlock()
                return
            }
            self.pendingFrame = nil
            pendingLock.unlock()

            if lastPublishedPresentationTime.isValid,
               pendingFrame.presentationTime.isValid,
               CMTimeCompare(pendingFrame.presentationTime, lastPublishedPresentationTime) <= 0 {
                continue
            }

            publishFrameLocked(
                pendingFrame.pixelBuffer,
                presentationTime: pendingFrame.presentationTime,
                sequence: pendingFrame.sequence,
                isPlaceholder: false
            )
        }
    }

    private func publishPlaceholderLocked(width: Int, height: Int) {
        pendingLock.lock()
        nextSequence &+= 1
        let sequence = nextSequence
        pendingLock.unlock()
        guard let pixelBuffer = makePooledPixelBuffer(width: width, height: height) else { return }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        if let base = CVPixelBufferGetBaseAddress(pixelBuffer) {
            memset(base, 28, CVPixelBufferGetDataSize(pixelBuffer))
        }
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
        lastPublishedPresentationTime = .invalid
        writeMetadataLocked(
            for: pixelBuffer,
            presentationTime: .zero,
            sequence: sequence,
            isPlaceholder: true
        )
    }

    private func publishFrameLocked(
        _ source: CVPixelBuffer,
        presentationTime: CMTime,
        sequence: UInt64,
        isPlaceholder: Bool
    ) {
        guard CVPixelBufferGetPixelFormatType(source) == kCVPixelFormatType_32BGRA else { return }
        let width = CVPixelBufferGetWidth(source)
        let height = CVPixelBufferGetHeight(source)
        guard let destination = makePooledPixelBuffer(width: width, height: height) else { return }

        CVPixelBufferLockBaseAddress(source, .readOnly)
        CVPixelBufferLockBaseAddress(destination, [])
        defer {
            CVPixelBufferUnlockBaseAddress(destination, [])
            CVPixelBufferUnlockBaseAddress(source, .readOnly)
        }

        guard let sourceBase = CVPixelBufferGetBaseAddress(source),
              let destinationBase = CVPixelBufferGetBaseAddress(destination) else { return }
        let sourceBytesPerRow = CVPixelBufferGetBytesPerRow(source)
        let destinationBytesPerRow = CVPixelBufferGetBytesPerRow(destination)
        let bytesToCopy = width * 4
        guard sourceBytesPerRow >= bytesToCopy, destinationBytesPerRow >= bytesToCopy else { return }

        for row in 0..<height {
            memcpy(
                destinationBase.advanced(by: row * destinationBytesPerRow),
                sourceBase.advanced(by: row * sourceBytesPerRow),
                bytesToCopy
            )
        }

        lastPublishedPresentationTime = presentationTime
        writeMetadataLocked(
            for: destination,
            presentationTime: presentationTime,
            sequence: sequence,
            isPlaceholder: isPlaceholder
        )
    }

    private func writeMetadataLocked(
        for pixelBuffer: CVPixelBuffer,
        presentationTime: CMTime,
        sequence: UInt64,
        isPlaceholder: Bool
    ) {
        guard let unmanagedSurface = CVPixelBufferGetIOSurface(pixelBuffer) else { return }
        let surfaceID = IOSurfaceGetID(unmanagedSurface.takeUnretainedValue())
        let metadata = RegionFrameMetadata(
            hostSessionID: hostSessionID,
            width: CVPixelBufferGetWidth(pixelBuffer),
            height: CVPixelBufferGetHeight(pixelBuffer),
            frameRate: frameRate,
            pixelFormat: CVPixelBufferGetPixelFormatType(pixelBuffer),
            presentationTimeSeconds: presentationTime.seconds.isFinite ? presentationTime.seconds : 0,
            updatedAt: Date(),
            isPlaceholder: isPlaceholder,
            surfaceID: surfaceID,
            sequence: sequence
        )

        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            let metadataData = try JSONEncoder().encode(metadata)
            try metadataData.write(to: metadataURL, options: .atomic)
            publishedBuffers.append(pixelBuffer)
            if publishedBuffers.count > publishedBufferLimit {
                publishedBuffers.removeFirst(publishedBuffers.count - publishedBufferLimit)
            }
        } catch {
            AppLog.regionShare.error("Failed to publish frame metadata: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func makePooledPixelBuffer(width: Int, height: Int) -> CVPixelBuffer? {
        let key = "\(width)x\(height)"
        let pool: CVPixelBufferPool
        if let existing = pools[key] {
            pool = existing
        } else {
            var createdPool: CVPixelBufferPool?
            let poolAttributes = [kCVPixelBufferPoolMinimumBufferCountKey: 3] as CFDictionary
            // The camera extension receives the surface by ID through the shared metadata file.
            // Use the literal key to support that legacy handoff without referencing the SDK's
            // deprecated symbol (the signed extension and host share one application group).
            let surfaceProperties = ["IOSurfaceIsGlobal" as CFString: true] as CFDictionary
            let pixelAttributes = [
                kCVPixelBufferWidthKey: width,
                kCVPixelBufferHeightKey: height,
                kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
                kCVPixelBufferIOSurfacePropertiesKey: surfaceProperties
            ] as CFDictionary
            guard CVPixelBufferPoolCreate(
                kCFAllocatorDefault,
                poolAttributes,
                pixelAttributes,
                &createdPool
            ) == kCVReturnSuccess, let createdPool else {
                return nil
            }
            pools[key] = createdPool
            pool = createdPool
        }

        var pixelBuffer: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(
            kCFAllocatorDefault,
            pool,
            &pixelBuffer
        ) == kCVReturnSuccess else {
            return nil
        }
        return pixelBuffer
    }
}
