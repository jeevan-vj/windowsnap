import AppKit
import XCTest
@testable import WindowSnap

final class CoordinateConverterTests: XCTestCase {
    func testAXAndAppKitRectsRoundTripOnPrimaryHeight() {
        let primaryHeight: CGFloat = 1080
        let appKit = CGRect(x: 100, y: 200, width: 400, height: 300)

        let ax = CoordinateConverter.axRect(fromAppKitRect: appKit, primaryScreenHeight: primaryHeight)
        XCTAssertEqual(ax.origin.x, 100)
        XCTAssertEqual(ax.origin.y, primaryHeight - appKit.maxY)
        XCTAssertEqual(ax.size, appKit.size)

        let restored = CoordinateConverter.appKitRect(fromAXRect: ax, primaryScreenHeight: primaryHeight)
        XCTAssertEqual(restored, appKit)
    }

    func testWindowLocalRectSubtractsScreenOrigin() {
        let screen = CGRect(x: 1920, y: 0, width: 1920, height: 1080)
        let global = CGRect(x: 1920, y: 100, width: 960, height: 500)
        let local = CoordinateConverter.windowLocalRect(fromGlobalAppKitRect: global, screenFrame: screen)
        XCTAssertEqual(local.origin.x, 0)
        XCTAssertEqual(local.origin.y, 100)
        XCTAssertEqual(local.size, global.size)
    }

    func testCenterKeepsCurrentSize() {
        let screen = CGRect(x: 0, y: 0, width: 1600, height: 1000)
        let frame = WindowManager.shared.calculateAXFrame(
            for: .center,
            in: screen,
            currentSize: CGSize(width: 420, height: 310)
        )
        XCTAssertEqual(frame?.size, CGSize(width: 420, height: 310))
        XCTAssertEqual(frame?.origin.x, (1600 - 420) / 2)
        XCTAssertEqual(frame?.origin.y, (1000 - 310) / 2)
    }

    func testCustomPositionPercentsUseAppKitFrame() throws {
        guard let screen = NSScreen.main else {
            throw XCTSkip("No display available")
        }

        let visible = screen.visibleFrame
        let appKit = CGRect(
            x: visible.minX + visible.width * 0.25,
            y: visible.minY + visible.height * 0.25,
            width: visible.width * 0.5,
            height: visible.height * 0.5
        )
        let position = try XCTUnwrap(CustomPosition(name: "Mid", appKitFrame: appKit, on: screen))
        XCTAssertEqual(position.widthPercent, 0.5, accuracy: 0.02)
        XCTAssertEqual(position.heightPercent, 0.5, accuracy: 0.02)
        XCTAssertEqual(position.xPercent, 0.25, accuracy: 0.02)
        XCTAssertEqual(position.yPercent, 0.25, accuracy: 0.02)
    }
}
