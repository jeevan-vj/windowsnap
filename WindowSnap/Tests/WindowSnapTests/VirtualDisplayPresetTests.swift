import XCTest
@testable import WindowSnap

final class VirtualDisplayPresetTests: XCTestCase {
    func testAdvertisedModesStayWithinMaximumPixelCap() {
        for preset in VirtualDisplayPreset.all {
            XCTAssertLessThanOrEqual(CGFloat(preset.width), VirtualDisplayPreset.maximumPixelSize.width)
            XCTAssertLessThanOrEqual(CGFloat(preset.height), VirtualDisplayPreset.maximumPixelSize.height)
            XCTAssertGreaterThan(preset.width, 0)
            XCTAssertGreaterThan(preset.height, 0)
            XCTAssertEqual(preset.refreshRate, 60)
        }
    }

    func testMaximumPixelSizeCoversLargestPresetAndDeskPadCap() {
        let size = VirtualDisplayPreset.maximumPixelSize(in: VirtualDisplayPreset.all)
        XCTAssertEqual(size.width, 5120)
        XCTAssertEqual(size.height, 2160)
    }

    func testMaximumPixelSizeRaisesCapWhenPresetExceedsDefault() {
        let oversized = [
            VirtualDisplayPreset(name: "8K", width: 7680, height: 4320, refreshRate: 60)
        ]
        let size = VirtualDisplayPreset.maximumPixelSize(in: oversized)
        XCTAssertEqual(size.width, 7680)
        XCTAssertEqual(size.height, 4320)
    }
}
