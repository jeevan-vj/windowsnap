import CoreMedia
import CoreVideo
import Darwin
import Foundation

struct RegionFrameMetadata: Codable, Equatable {
    let width: Int
    let height: Int
    let frameRate: Int
    let pixelFormat: UInt32
    let presentationTimeSeconds: Double
    let updatedAt: Date
    let isPlaceholder: Bool

    var isActive: Bool {
        Date().timeIntervalSince(updatedAt) < 2.0 && !isPlaceholder
    }
}

final class RegionFrameHub: RegionFrameSink {
    static let appGroupIdentifier = "group.com.jeevanwijerathna.windowsnap"
    static let shared = RegionFrameHub()

    private let queue = DispatchQueue(label: "com.windowsnap.region-frame-hub")
    private let directory: URL
    private let metadataURL: URL
    private let frameURL: URL
    private let frameRate: Int
    private let fileManager: FileManager

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
        } else if let appGroupURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroupIdentifier) {
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
        self.frameURL = resolvedDirectory.appendingPathComponent("latest.bgra")
    }

    var currentMetadata: RegionFrameMetadata? {
        queue.sync {
            guard let data = try? Data(contentsOf: metadataURL) else { return nil }
            return try? JSONDecoder().decode(RegionFrameMetadata.self, from: data)
        }
    }

    var currentFrameURL: URL { frameURL }
    var currentMetadataURL: URL { metadataURL }

    func prepare() {
        queue.sync {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            writePlaceholderFrameLocked(width: 1280, height: 720)
        }
    }

    func markInactive() {
        queue.async {
            self.writePlaceholderFrameLocked(width: 1280, height: 720)
        }
    }

    func regionCaptureDidOutputFrame(_ frame: CVPixelBuffer, presentationTime: CMTime) {
        queue.async {
            self.writeFrameLocked(frame, presentationTime: presentationTime, isPlaceholder: false)
        }
    }

    private func writePlaceholderFrameLocked(width: Int, height: Int) {
        var pixelBuffer: CVPixelBuffer?
        let attributes = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ] as CFDictionary
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attributes,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let pixelBuffer else { return }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        if let base = CVPixelBufferGetBaseAddress(pixelBuffer) {
            memset(base, 28, CVPixelBufferGetDataSize(pixelBuffer))
        }
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])

        writeFrameLocked(pixelBuffer, presentationTime: .zero, isPlaceholder: true)
    }

    private func writeFrameLocked(_ frame: CVPixelBuffer, presentationTime: CMTime, isPlaceholder: Bool) {
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        CVPixelBufferLockBaseAddress(frame, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(frame, .readOnly) }

        guard let packedFrame = packedBGRAData(from: frame) else { return }
        let metadata = RegionFrameMetadata(
            width: CVPixelBufferGetWidth(frame),
            height: CVPixelBufferGetHeight(frame),
            frameRate: frameRate,
            pixelFormat: CVPixelBufferGetPixelFormatType(frame),
            presentationTimeSeconds: presentationTime.seconds.isFinite ? presentationTime.seconds : 0,
            updatedAt: Date(),
            isPlaceholder: isPlaceholder
        )

        do {
            try packedFrame.write(to: frameURL, options: .atomic)
            let metadataData = try JSONEncoder().encode(metadata)
            try metadataData.write(to: metadataURL, options: .atomic)
        } catch {
            print("⚠️ Failed to publish region frame: \(error)")
        }
    }

    /// Copies BGRA pixels without row padding so the camera extension can
    /// address them as `width * 4` bytes per row.
    private func packedBGRAData(from frame: CVPixelBuffer) -> Data? {
        guard let baseAddress = CVPixelBufferGetBaseAddress(frame) else { return nil }
        let width = CVPixelBufferGetWidth(frame)
        let height = CVPixelBufferGetHeight(frame)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(frame)
        let packedBytesPerRow = width * 4
        guard packedBytesPerRow > 0, height > 0, bytesPerRow >= packedBytesPerRow else { return nil }

        var packed = Data(count: packedBytesPerRow * height)
        packed.withUnsafeMutableBytes { dest in
            guard let destBase = dest.baseAddress else { return }
            for row in 0..<height {
                memcpy(
                    destBase.advanced(by: row * packedBytesPerRow),
                    baseAddress.advanced(by: row * bytesPerRow),
                    packedBytesPerRow
                )
            }
        }
        return packed
    }
}
