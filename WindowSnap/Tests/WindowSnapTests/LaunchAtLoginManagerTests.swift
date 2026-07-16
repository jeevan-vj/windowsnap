import ServiceManagement
import XCTest
@testable import WindowSnap

@available(macOS 13.0, *)
final class LaunchAtLoginManagerTests: XCTestCase {
    func testMapsEverySystemServiceStatus() {
        XCTAssertEqual(LaunchAtLoginSystemStatus(SMAppService.Status.enabled), .enabled)
        XCTAssertEqual(LaunchAtLoginSystemStatus(SMAppService.Status.notRegistered), .disabled)
        XCTAssertEqual(LaunchAtLoginSystemStatus(SMAppService.Status.requiresApproval), .requiresApproval)
        XCTAssertEqual(LaunchAtLoginSystemStatus(SMAppService.Status.notFound), .notFound)
    }

    func testReadingOrRefreshingStateNeverRegistersWithoutExplicitUserAction() {
        let service = StubLaunchAtLoginService(status: .disabled)
        let preferences = InMemoryLaunchAtLoginPreferences(launchAtLogin: true)
        let manager = LaunchAtLoginManager(service: service, preferences: preferences)

        XCTAssertEqual(manager.status, .disabled)
        XCTAssertEqual(manager.refreshStatus(), .disabled)
        XCTAssertEqual(service.registerCount, 0)
        XCTAssertEqual(service.unregisterCount, 0)
        XCTAssertFalse(preferences.launchAtLogin)
    }

    func testEnableAndDisableMutateRealServiceAndSynchronizePreference() throws {
        let service = StubLaunchAtLoginService(status: .disabled)
        let preferences = InMemoryLaunchAtLoginPreferences(launchAtLogin: false)
        let manager = LaunchAtLoginManager(service: service, preferences: preferences)

        try manager.setEnabled(true)
        XCTAssertEqual(service.registerCount, 1)
        XCTAssertTrue(preferences.launchAtLogin)
        XCTAssertTrue(manager.isEnabled)

        try manager.setEnabled(false)
        XCTAssertEqual(service.unregisterCount, 1)
        XCTAssertFalse(preferences.launchAtLogin)
        XCTAssertFalse(manager.isEnabled)
    }

    func testRepeatedEnableAndDisableOperationsAreIdempotent() throws {
        let service = StubLaunchAtLoginService(status: .enabled)
        let manager = LaunchAtLoginManager(service: service, preferences: InMemoryLaunchAtLoginPreferences(launchAtLogin: false))

        try manager.setEnabled(true)
        try manager.setEnabled(true)
        XCTAssertEqual(service.registerCount, 0)

        try manager.setEnabled(false)
        try manager.setEnabled(false)
        XCTAssertEqual(service.unregisterCount, 1)
    }

    func testRefreshDetectsExternalSystemSettingsChangesAndSynchronizesPreference() {
        let service = StubLaunchAtLoginService(status: .disabled)
        let preferences = InMemoryLaunchAtLoginPreferences(launchAtLogin: false)
        let manager = LaunchAtLoginManager(service: service, preferences: preferences)

        service.status = .enabled
        XCTAssertEqual(manager.refreshStatus(), .enabled)
        XCTAssertTrue(preferences.launchAtLogin)

        service.status = .disabled
        XCTAssertEqual(manager.refreshStatus(), .disabled)
        XCTAssertFalse(preferences.launchAtLogin)
    }

    func testRequiresApprovalHasActionableSystemSettingsGuidance() {
        let service = StubLaunchAtLoginService(status: .requiresApproval)
        let preferences = InMemoryLaunchAtLoginPreferences(launchAtLogin: true)
        let manager = LaunchAtLoginManager(service: service, preferences: preferences)

        XCTAssertThrowsError(try manager.setEnabled(true)) { error in
            guard case LaunchAtLoginError.requiresApproval = error else { return XCTFail("Expected requiresApproval, got \(error)") }
            XCTAssertTrue(error.localizedDescription.contains("System Settings"))
        }
        XCTAssertFalse(preferences.launchAtLogin)
        XCTAssertEqual(service.registerCount, 0)
    }

    func testNotFoundHasActionableReinstallGuidance() {
        let manager = LaunchAtLoginManager(service: StubLaunchAtLoginService(status: .notFound), preferences: InMemoryLaunchAtLoginPreferences(launchAtLogin: true))

        XCTAssertThrowsError(try manager.setEnabled(true)) { error in
            guard case LaunchAtLoginError.serviceNotFound = error else { return XCTFail("Expected serviceNotFound, got \(error)") }
            XCTAssertTrue(error.localizedDescription.lowercased().contains("applications"))
        }
    }

    func testRegistrationFailureKeepsPreferenceSynchronizedWithActualState() {
        let service = StubLaunchAtLoginService(status: .disabled)
        service.registerError = TestError.denied
        let preferences = InMemoryLaunchAtLoginPreferences(launchAtLogin: false)
        let manager = LaunchAtLoginManager(service: service, preferences: preferences)

        XCTAssertThrowsError(try manager.setEnabled(true)) { error in
            guard case LaunchAtLoginError.registrationFailed = error else { return XCTFail("Expected registrationFailed, got \(error)") }
            XCTAssertTrue(error.localizedDescription.contains("System Settings"))
        }
        XCTAssertFalse(preferences.launchAtLogin)
    }

    func testStatusAfterRegistrationRequiresApprovalInsteadOfClaimingEnabled() {
        let service = StubLaunchAtLoginService(status: .disabled)
        service.statusAfterRegister = .requiresApproval
        let preferences = InMemoryLaunchAtLoginPreferences(launchAtLogin: false)
        let manager = LaunchAtLoginManager(service: service, preferences: preferences)

        XCTAssertThrowsError(try manager.setEnabled(true)) { error in
            guard case LaunchAtLoginError.requiresApproval = error else { return XCTFail("Expected requiresApproval, got \(error)") }
        }
        XCTAssertFalse(preferences.launchAtLogin)
    }

    func testUnregistrationFailureKeepsPreferenceSynchronizedWithActualState() {
        let service = StubLaunchAtLoginService(status: .enabled)
        service.unregisterError = TestError.denied
        let preferences = InMemoryLaunchAtLoginPreferences(launchAtLogin: true)
        let manager = LaunchAtLoginManager(service: service, preferences: preferences)

        XCTAssertThrowsError(try manager.setEnabled(false)) { error in
            guard case LaunchAtLoginError.unregistrationFailed = error else {
                return XCTFail("Expected unregistrationFailed, got \(error)")
            }
            XCTAssertTrue(error.localizedDescription.contains("System Settings"))
        }
        XCTAssertTrue(preferences.launchAtLogin)
    }

    func testStatusAfterUnregisterMustActuallyBecomeDisabled() {
        let service = StubLaunchAtLoginService(status: .enabled)
        service.statusAfterUnregister = .requiresApproval
        let preferences = InMemoryLaunchAtLoginPreferences(launchAtLogin: true)
        let manager = LaunchAtLoginManager(service: service, preferences: preferences)

        XCTAssertThrowsError(try manager.setEnabled(false)) { error in
            guard case LaunchAtLoginError.unregistrationDidNotDisable = error else {
                return XCTFail("Expected unregistrationDidNotDisable, got \(error)")
            }
        }
        XCTAssertFalse(preferences.launchAtLogin)
    }
}

@available(macOS 13.0, *)
private final class StubLaunchAtLoginService: LaunchAtLoginService {
    var status: LaunchAtLoginSystemStatus
    var statusAfterRegister: LaunchAtLoginSystemStatus = .enabled
    var statusAfterUnregister: LaunchAtLoginSystemStatus = .disabled
    var registerError: Error?
    var unregisterError: Error?
    private(set) var registerCount = 0
    private(set) var unregisterCount = 0

    init(status: LaunchAtLoginSystemStatus) { self.status = status }

    func register() throws {
        registerCount += 1
        if let registerError { throw registerError }
        status = statusAfterRegister
    }

    func unregister() throws {
        unregisterCount += 1
        if let unregisterError { throw unregisterError }
        status = statusAfterUnregister
    }
}

private final class InMemoryLaunchAtLoginPreferences: LaunchAtLoginPreferenceStoring {
    var launchAtLogin: Bool
    init(launchAtLogin: Bool) { self.launchAtLogin = launchAtLogin }
}

private enum TestError: Error { case denied }
