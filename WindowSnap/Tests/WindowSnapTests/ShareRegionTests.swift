import CoreGraphics
import XCTest
@testable import WindowSnap

final class ShareRegionTests: XCTestCase {
    func testNormalizedRectRoundTripsThroughAbsoluteRect() {
        let bounds = CGRect(x: 1920, y: 0, width: 1920, height: 1080)
        let absolute = CGRect(x: 2120, y: 100, width: 800, height: 450)
        let normalized = ShareRegion.normalizedRect(from: absolute, in: bounds)
        let region = ShareRegion(displayID: 1, normalizedRect: normalized)

        let restored = region.absoluteRect(for: bounds)
        XCTAssertEqual(restored.origin.x, absolute.origin.x, accuracy: 0.001)
        XCTAssertEqual(restored.origin.y, absolute.origin.y, accuracy: 0.001)
        XCTAssertEqual(restored.width, absolute.width, accuracy: 0.001)
        XCTAssertEqual(restored.height, absolute.height, accuracy: 0.001)
    }

    func testCaptureRectIdentityWhenOverlayMatchesDisplayBounds() {
        let overlay = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let display = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let viewRect = CGRect(x: 100, y: 200, width: 400, height: 300)

        let capture = ShareRegion.captureRect(
            fromViewRect: viewRect,
            overlayFrame: overlay,
            displayBounds: display
        )

        XCTAssertEqual(capture, CGRect(x: 100, y: 200, width: 400, height: 300))
    }

    func testCaptureRectScalesBothAxesWhenOverlayAndDisplayDiffer() {
        let overlay = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let display = CGRect(x: 0, y: 0, width: 2880, height: 1800)
        let viewRect = CGRect(x: 144, y: 90, width: 720, height: 450)

        let capture = ShareRegion.captureRect(
            fromViewRect: viewRect,
            overlayFrame: overlay,
            displayBounds: display
        )

        XCTAssertEqual(capture.origin.x, 288, accuracy: 0.001)
        XCTAssertEqual(capture.origin.y, 180, accuracy: 0.001)
        XCTAssertEqual(capture.width, 1440, accuracy: 0.001)
        XCTAssertEqual(capture.height, 900, accuracy: 0.001)
    }

    func testCaptureRectOffsetsIntoDisplayOrigin() {
        let overlay = CGRect(x: 1920, y: 0, width: 1920, height: 1080)
        let display = CGRect(x: 1920, y: 0, width: 1920, height: 1080)
        let viewRect = CGRect(x: 10, y: 20, width: 100, height: 80)

        let capture = ShareRegion.captureRect(
            fromViewRect: viewRect,
            overlayFrame: overlay,
            displayBounds: display
        )

        XCTAssertEqual(capture, CGRect(x: 1930, y: 20, width: 100, height: 80))
    }

    func testNormalizedRectReturnsZeroForEmptyDisplayBounds() {
        let normalized = ShareRegion.normalizedRect(
            from: CGRect(x: 10, y: 10, width: 50, height: 50),
            in: .zero
        )
        XCTAssertEqual(normalized, .zero)
    }
}
