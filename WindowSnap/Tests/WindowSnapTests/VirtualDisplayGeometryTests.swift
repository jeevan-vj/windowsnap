import XCTest
@testable import WindowSnap

final class VirtualDisplayGeometryTests: XCTestCase {
    func testContainsCursorUsesScreenFrame() {
        let frame = CGRect(x: 1920, y: 0, width: 1920, height: 1080)
        XCTAssertTrue(VirtualDisplayGeometry.containsCursor(CGPoint(x: 2000, y: 10), in: frame))
        XCTAssertFalse(VirtualDisplayGeometry.containsCursor(CGPoint(x: 10, y: 10), in: frame))
    }

    func testDisplayPointFlipsPreviewYIntoDisplaySpace() {
        let preview = CGRect(x: 0, y: 0, width: 960, height: 540)
        let display = CGSize(width: 1920, height: 1080)

        let topLeft = VirtualDisplayGeometry.displayPoint(
            fromPreviewLocation: CGPoint(x: 0, y: 540),
            previewBounds: preview,
            displaySize: display
        )
        XCTAssertEqual(topLeft.x, 0, accuracy: 0.001)
        XCTAssertEqual(topLeft.y, 0, accuracy: 0.001)

        let bottomRight = VirtualDisplayGeometry.displayPoint(
            fromPreviewLocation: CGPoint(x: 960, y: 0),
            previewBounds: preview,
            displaySize: display
        )
        XCTAssertEqual(bottomRight.x, 1920, accuracy: 0.001)
        XCTAssertEqual(bottomRight.y, 1080, accuracy: 0.001)
    }

    func testDisplayPointReturnsZeroForEmptyPreview() {
        let point = VirtualDisplayGeometry.displayPoint(
            fromPreviewLocation: CGPoint(x: 10, y: 10),
            previewBounds: .zero,
            displaySize: CGSize(width: 1920, height: 1080)
        )
        XCTAssertEqual(point, .zero)
    }

    func testHostScreenFramePrefersNonVirtualScreen() {
        let main = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let virtual = CGRect(x: 1440, y: 0, width: 1920, height: 1080)
        let host = VirtualDisplayGeometry.hostScreenFrame(from: [virtual, main], excluding: virtual)
        XCTAssertEqual(host, main)
    }

    func testHostScreenFrameFallsBackToOnlyScreen() {
        let virtual = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let host = VirtualDisplayGeometry.hostScreenFrame(from: [virtual], excluding: virtual)
        XCTAssertEqual(host, virtual)
    }
}
