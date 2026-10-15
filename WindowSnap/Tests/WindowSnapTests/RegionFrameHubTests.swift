import CoreMedia
import CoreVideo
import IOSurface
import XCTest
@testable import WindowSnap

final class RegionFrameHubTests: XCTestCase {
    func testPrepareWritesInactivePlaceholderMetadata() throws {
        let directory = try makeTemporaryDirectory()
        let hub = RegionFrameHub(directory: directory)

        hub.prepare()

        let metadata = try XCTUnwrap(hub.currentMetadata)
        XCTAssertEqual(metadata.width, 1280)
        XCTAssertEqual(metadata.height, 720)
        XCTAssertEqual(metadata.frameRate, 30)
        XCTAssertEqual(metadata.pixelFormat, kCVPixelFormatType_32BGRA)
        XCTAssertTrue(metadata.isPlaceholder)
        XCTAssertFalse(metadata.isActive)
        XCTAssertNotEqual(metadata.surfaceID, 0)
        XCTAssertNotNil(IOSurfaceLookup(metadata.surfaceID))
        XCTAssertFalse(FileManager.default.fileExists(atPath: hub.currentFrameURL.path))
    }

    func testRegionCaptureDidOutputFramePersistsFrameMetadata() throws {
        let directory = try makeTemporaryDirectory()
        let hub = RegionFrameHub(directory: directory)
        let pixelBuffer = try makePixelBuffer(width: 64, height: 36, fill: 120)

        hub.regionCaptureDidOutputFrame(pixelBuffer, presentationTime: CMTime(value: 1, timescale: 30))

        let metadata = try waitForMetadata(from: hub) { !$0.isPlaceholder }
        XCTAssertEqual(metadata.width, 64)
        XCTAssertEqual(metadata.height, 36)
        XCTAssertEqual(metadata.pixelFormat, kCVPixelFormatType_32BGRA)
        XCTAssertFalse(metadata.isPlaceholder)
        XCTAssertTrue(metadata.isActive)

        let surface = try XCTUnwrap(IOSurfaceLookup(metadata.surfaceID))
        XCTAssertEqual(IOSurfaceGetWidth(surface), 64)
        XCTAssertEqual(IOSurfaceGetHeight(surface), 36)
    }

    func testMarkInactiveReplacesLatestFrameWithPlaceholder() throws {
        let directory = try makeTemporaryDirectory()
        let hub = RegionFrameHub(directory: directory)
        let pixelBuffer = try makePixelBuffer(width: 32, height: 32, fill: 220)

        hub.regionCaptureDidOutputFrame(pixelBuffer, presentationTime: .zero)
        _ = try waitForMetadata(from: hub) { !$0.isPlaceholder }

        hub.markInactive()

        let metadata = try waitForMetadata(from: hub) { $0.isPlaceholder }
        XCTAssertEqual(metadata.width, 1280)
        XCTAssertEqual(metadata.height, 720)
        XCTAssertTrue(metadata.isPlaceholder)
    }

    func testOlderPresentationTimeDoesNotReplaceNewestFrame() throws {
        let directory = try makeTemporaryDirectory()
        let hub = RegionFrameHub(directory: directory)
        let newer = try makePixelBuffer(width: 64, height: 36, fill: 220)
        let older = try makePixelBuffer(width: 32, height: 18, fill: 40)

        hub.regionCaptureDidOutputFrame(newer, presentationTime: CMTime(seconds: 2, preferredTimescale: 600))
        let published = try waitForMetadata(from: hub) { !$0.isPlaceholder }
        hub.regionCaptureDidOutputFrame(older, presentationTime: CMTime(seconds: 1, preferredTimescale: 600))

        let afterStaleFrame = try XCTUnwrap(hub.currentMetadata)
        XCTAssertEqual(afterStaleFrame.sequence, published.sequence)
        XCTAssertEqual(afterStaleFrame.width, 64)
        XCTAssertEqual(afterStaleFrame.height, 36)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func makePixelBuffer(width: Int, height: Int, fill: UInt8) throws -> CVPixelBuffer {
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
        XCTAssertEqual(status, kCVReturnSuccess)
        let buffer = try XCTUnwrap(pixelBuffer)
        CVPixelBufferLockBaseAddress(buffer, [])
        if let base = CVPixelBufferGetBaseAddress(buffer) {
            memset(base, Int32(fill), CVPixelBufferGetDataSize(buffer))
        }
        CVPixelBufferUnlockBaseAddress(buffer, [])
        return buffer
    }

    private func waitForMetadata(
        from hub: RegionFrameHub,
        matching predicate: (RegionFrameMetadata) -> Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> RegionFrameMetadata {
        let deadline = Date().addingTimeInterval(2)
        while Date() < deadline {
            if let metadata = hub.currentMetadata, predicate(metadata) {
                return metadata
            }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.01))
        }
        XCTFail("Timed out waiting for frame metadata", file: file, line: line)
        throw TestError.timeout
    }

    private enum TestError: Error {
        case timeout
    }
}
