import AppKit
@testable import WindowSnap
import XCTest

final class AccessibilityOnboardingWindowTests: XCTestCase {
    override func setUp() {
        super.setUp()
        _ = NSApplication.shared
    }

    func testOnboardingWindowFloatsOnEverySpace() throws {
        let controller = AccessibilityOnboardingWindowController(model: makeModel())
        let window = try XCTUnwrap(controller.window)

        XCTAssertEqual(window.level, .floating)
        XCTAssertEqual(window.level, AccessibilityOnboardingWindowController.presentationLevel)
        XCTAssertEqual(
            window.collectionBehavior,
            [.canJoinAllSpaces, .fullScreenAuxiliary]
        )
        XCTAssertFalse(window.collectionBehavior.contains(.moveToActiveSpace))
        XCTAssertEqual(
            window.collectionBehavior,
            AccessibilityOnboardingWindowController.presentationCollectionBehavior
        )
    }

    func testBringToFrontActivatesBeforeOrdering() {
        let window = OrderRecordingWindow(
            contentRect: NSRect(x: 0, y: 0, width: 120, height: 80),
            styleMask: [.titled],
            backing: .buffered,
            defer: true
        )
        var events: [String] = []

        AccessibilityOnboardingWindowController.bringToFront(window) {
            events.append("activate")
        }
        events.append(contentsOf: window.events)

        XCTAssertEqual(
            events,
            ["activate", "makeKeyAndOrderFront", "orderFrontRegardless"]
        )
    }

    func testReassertOrdersFrontWithoutActivating() {
        let window = OrderRecordingWindow(
            contentRect: NSRect(x: 0, y: 0, width: 120, height: 80),
            styleMask: [.titled],
            backing: .buffered,
            defer: true
        )

        AccessibilityOnboardingWindowController.reassert(window, wantsVisible: true, dismissed: false)

        XCTAssertEqual(window.events, ["orderFrontRegardless"])
    }

    func testReassertDoesNothingAfterDismissOrBeforePresentation() {
        let window = OrderRecordingWindow(
            contentRect: NSRect(x: 0, y: 0, width: 120, height: 80),
            styleMask: [.titled],
            backing: .buffered,
            defer: true
        )

        AccessibilityOnboardingWindowController.reassert(window, wantsVisible: true, dismissed: true)
        AccessibilityOnboardingWindowController.reassert(window, wantsVisible: false, dismissed: false)

        XCTAssertEqual(window.events, [])
    }

    private func makeModel() -> AccessibilityOnboardingModel {
        AccessibilityOnboardingModel(
            permissionProvider: FrontmostTestPermissionProvider(),
            store: FrontmostTestOnboardingStore()
        )
    }
}

private final class OrderRecordingWindow: NSWindow {
    private(set) var events: [String] = []

    override func makeKeyAndOrderFront(_ sender: Any?) {
        events.append("makeKeyAndOrderFront")
    }

    override func orderFrontRegardless() {
        events.append("orderFrontRegardless")
    }
}

private final class FrontmostTestPermissionProvider: AccessibilityPermissionProviding {
    func currentStatus() -> AccessibilityAuthorizationStatus { .notGranted }
    func requestPermission() {}
    func openSystemSettings() {}
}

private final class FrontmostTestOnboardingStore: AccessibilityOnboardingStoring {
    var accessibilityOnboardingState: AccessibilityOnboardingState = .notPresented
}
