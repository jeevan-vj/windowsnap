import XCTest
import SystemExtensions
@testable import WindowSnap

final class VirtualCameraExtensionManagerTests: XCTestCase {
    func testStatusDisplayTextCoversLifecycleStates() {
        XCTAssertEqual(VirtualCameraExtensionStatus.unavailable.displayText, "Not included in this build")
        XCTAssertEqual(VirtualCameraExtensionStatus.notRequested.displayText, "Not enabled")
        XCTAssertEqual(VirtualCameraExtensionStatus.activating.displayText, "Activating...")
        XCTAssertEqual(VirtualCameraExtensionStatus.enabled.displayText, "Enabled")
        XCTAssertEqual(VirtualCameraExtensionStatus.needsApproval.displayText, "Approval required in System Settings")
        XCTAssertEqual(VirtualCameraExtensionStatus.willCompleteAfterReboot.displayText, "Restart required")
        XCTAssertEqual(VirtualCameraExtensionStatus.failed("No bundled extension").displayText, "Failed: No bundled extension")
    }

    func testActivationIsBlockedWhenExtensionIsNotBundled() {
        let activator = StubVirtualCameraExtensionActivator()
        let manager = VirtualCameraExtensionManager(
            activator: activator,
            extensionAvailability: { false }
        )

        XCTAssertEqual(manager.status, .unavailable)
        manager.activate()
        XCTAssertEqual(manager.status, .unavailable)
        XCTAssertEqual(activator.activationCount, 0)
    }
}

private final class StubVirtualCameraExtensionActivator: VirtualCameraExtensionActivating {
    private(set) var activationCount = 0

    func activateExtension(identifier: String, delegate: OSSystemExtensionRequestDelegate) {
        activationCount += 1
    }
}
