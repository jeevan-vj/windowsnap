import XCTest
@testable import WindowSnap

final class VirtualCameraExtensionManagerTests: XCTestCase {
    func testStatusDisplayTextCoversLifecycleStates() {
        XCTAssertEqual(VirtualCameraExtensionStatus.notRequested.displayText, "Not enabled")
        XCTAssertEqual(VirtualCameraExtensionStatus.activating.displayText, "Activating...")
        XCTAssertEqual(VirtualCameraExtensionStatus.enabled.displayText, "Enabled")
        XCTAssertEqual(VirtualCameraExtensionStatus.needsApproval.displayText, "Approval required in System Settings")
        XCTAssertEqual(VirtualCameraExtensionStatus.willCompleteAfterReboot.displayText, "Restart required")
        XCTAssertEqual(VirtualCameraExtensionStatus.failed("No bundled extension").displayText, "Failed: No bundled extension")
    }
}
