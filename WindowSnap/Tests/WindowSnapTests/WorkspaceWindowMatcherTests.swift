import CoreGraphics
import XCTest
@testable import WindowSnap

final class WorkspaceWindowMatcherTests: XCTestCase {
    func testNamedTitleTakesExactMatch() {
        var available = [
            makeWindow(id: 1, title: "Inbox"),
            makeWindow(id: 2, title: "Drafts")
        ]

        let matched = WorkspaceManager.takeMatchingWindow(title: "Drafts", from: &available)

        XCTAssertEqual(matched?.windowID, 2)
        XCTAssertEqual(available.map(\.windowID), [1])
    }

    func testUnmatchedNamedTitleLeavesWindowsUntouched() {
        var available = [
            makeWindow(id: 1, title: "Inbox"),
            makeWindow(id: 2, title: "Drafts")
        ]

        let matched = WorkspaceManager.takeMatchingWindow(title: "Archive", from: &available)

        XCTAssertNil(matched)
        XCTAssertEqual(available.map(\.windowID), [1, 2])
    }

    func testUntitledLayoutTakesNextLeftoverWindow() {
        var available = [
            makeWindow(id: 1, title: "Inbox"),
            makeWindow(id: 2, title: "Drafts")
        ]

        let matched = WorkspaceManager.takeMatchingWindow(title: "", from: &available)

        XCTAssertEqual(matched?.windowID, 1)
        XCTAssertEqual(available.map(\.windowID), [2])
    }

    func testEmptyAvailableReturnsNil() {
        var available: [WindowInfo] = []

        XCTAssertNil(WorkspaceManager.takeMatchingWindow(title: "Inbox", from: &available))
        XCTAssertNil(WorkspaceManager.takeMatchingWindow(title: "", from: &available))
    }

    private func makeWindow(id: CGWindowID, title: String) -> WindowInfo {
        WindowInfo(
            windowID: id,
            processID: 99,
            applicationName: "Mail",
            windowTitle: title,
            frame: CGRect(x: 0, y: 0, width: 400, height: 300)
        )
    }
}
