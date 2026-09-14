import XCTest
@testable import WindowSnap

final class WindowActionHistoryTests: XCTestCase {
    override func setUp() {
        super.setUp()
        WindowActionHistory.shared.resetForTesting()
    }

    override func tearDown() {
        WindowActionHistory.shared.resetForTesting()
        super.tearDown()
    }

    func testLeftHalfCyclesThroughThirdAndTwoThirds() {
        let window = makeWindow()
        let history = WindowActionHistory.shared

        XCTAssertEqual(history.getNextCyclePosition(for: .leftHalf, window: window), .leftHalf)
        XCTAssertEqual(history.getNextCyclePosition(for: .leftHalf, window: window), .leftThird)
        XCTAssertEqual(history.getNextCyclePosition(for: .leftHalf, window: window), .leftTwoThirds)
        XCTAssertEqual(history.getNextCyclePosition(for: .leftHalf, window: window), .leftHalf)
    }

    func testRightHalfCyclesThroughThirdAndTwoThirds() {
        let window = makeWindow()
        let history = WindowActionHistory.shared

        XCTAssertEqual(history.getNextCyclePosition(for: .rightHalf, window: window), .rightHalf)
        XCTAssertEqual(history.getNextCyclePosition(for: .rightHalf, window: window), .rightThird)
        XCTAssertEqual(history.getNextCyclePosition(for: .rightHalf, window: window), .rightTwoThirds)
    }

    func testThirdsGroupStillCyclesLeftCenterRight() {
        let window = makeWindow()
        let history = WindowActionHistory.shared

        XCTAssertEqual(history.getNextCyclePosition(for: .leftThird, window: window), .leftThird)
        XCTAssertEqual(history.getNextCyclePosition(for: .leftThird, window: window), .centerThird)
        XCTAssertEqual(history.getNextCyclePosition(for: .leftThird, window: window), .rightThird)
    }

    func testCycleResetsAfterCooldown() {
        let window = makeWindow()
        let history = WindowActionHistory.shared

        XCTAssertEqual(history.getNextCyclePosition(for: .leftHalf, window: window), .leftHalf)
        XCTAssertEqual(history.getNextCyclePosition(for: .leftHalf, window: window), .leftThird)

        history.resetForTesting()
        XCTAssertEqual(history.getNextCyclePosition(for: .leftHalf, window: window), .leftHalf)
    }

    private func makeWindow() -> WindowInfo {
        WindowInfo(
            windowID: 1,
            processID: 99,
            applicationName: "Safari",
            windowTitle: "Home",
            frame: CGRect(x: 10, y: 20, width: 400, height: 300)
        )
    }
}
