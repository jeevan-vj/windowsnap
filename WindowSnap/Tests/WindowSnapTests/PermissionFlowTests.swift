import XCTest
@testable import WindowSnap

final class PermissionFlowTests: XCTestCase {
    private var suiteNames: [String] = []

    override func tearDown() {
        for name in suiteNames {
            UserDefaults.standard.removePersistentDomain(forName: name)
        }
        super.tearDown()
    }

    func testScreenRecordingRequestsExactlyOnceAndThenRoutesToDeniedState() {
        let provider = StubScreenRecordingProvider(hasAccess: false, requestResult: false)
        let store = InMemoryScreenRecordingStore(hasRequested: false)
        let coordinator = ScreenRecordingPermissionCoordinator(provider: provider, store: store)

        XCTAssertEqual(coordinator.immediateState, .notRequested)
        XCTAssertEqual(coordinator.requestAccess(), .denied)
        XCTAssertEqual(provider.requestCount, 1)
        XCTAssertTrue(store.hasRequestedScreenRecordingPermission)

        XCTAssertEqual(coordinator.requestAccess(), .denied)
        XCTAssertEqual(provider.requestCount, 1)
    }

    func testScreenRecordingExplicitRecoveryRetriesAStaleRegistration() {
        let provider = StubScreenRecordingProvider(hasAccess: false, requestResult: false)
        let store = InMemoryScreenRecordingStore(hasRequested: true)
        let coordinator = ScreenRecordingPermissionCoordinator(provider: provider, store: store)

        XCTAssertEqual(coordinator.retryAccess(), .denied)
        XCTAssertEqual(provider.requestCount, 1)

        provider.requestResult = true
        XCTAssertEqual(coordinator.retryAccess(), .granted)
        XCTAssertEqual(provider.requestCount, 2)
    }

    func testScreenRecordingNeverRequestsWhenAlreadyGranted() {
        let provider = StubScreenRecordingProvider(hasAccess: true, requestResult: true)
        let coordinator = ScreenRecordingPermissionCoordinator(
            provider: provider,
            store: InMemoryScreenRecordingStore(hasRequested: false)
        )

        XCTAssertEqual(coordinator.requestAccess(), .granted)
        XCTAssertEqual(provider.requestCount, 0)
    }

    func testScreenRecordingRefreshDoesNotConsultScreenCaptureKitBeforeExplicitRequest() {
        let provider = StubScreenRecordingProvider(hasAccess: false, requestResult: false)
        provider.asyncCheckResult = true
        let coordinator = ScreenRecordingPermissionCoordinator(
            provider: provider,
            store: InMemoryScreenRecordingStore(hasRequested: false)
        )
        let expectation = expectation(description: "state refreshed")

        coordinator.refreshState { state in
            XCTAssertEqual(state, .notRequested)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(provider.checkCount, 0)
        XCTAssertEqual(provider.requestCount, 0)
    }

    func testScreenRecordingDetectsRestartRequiredWithoutRequestingAgain() {
        let provider = StubScreenRecordingProvider(hasAccess: false, requestResult: false)
        provider.asyncCheckResult = true
        let coordinator = ScreenRecordingPermissionCoordinator(
            provider: provider,
            store: InMemoryScreenRecordingStore(hasRequested: true)
        )
        let expectation = expectation(description: "state refreshed")

        coordinator.refreshState { state in
            XCTAssertEqual(state, .restartRequired)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 1)
        XCTAssertEqual(provider.requestCount, 0)
    }

    func testTextExpanderReportsEachMissingPermissionAndStaysOff() {
        let defaults = makeDefaults()
        defaults.set(true, forKey: "WindowSnap_TextExpanderHasPopulatedDefaults")
        let manager = TextExpanderManager(userDefaults: defaults)
        var missing: Set<PermissionKind> = [.accessibility]
        let controller = TextExpanderRuntimeController(manager: manager, missingPermissions: { missing })

        XCTAssertEqual(controller.setDesiredEnabled(true), .needsPermission([.accessibility]))
        XCTAssertFalse(manager.isEnabled)

        missing = [.inputMonitoring]
        XCTAssertEqual(controller.setDesiredEnabled(true), .needsPermission([.inputMonitoring]))
        XCTAssertFalse(manager.isEnabled)

        missing = []
        XCTAssertEqual(controller.setDesiredEnabled(true), .running)
        XCTAssertTrue(manager.isEnabled)
        controller.setDesiredEnabled(false)
    }

    func testTextExpanderRequiresOnlyAccessibilityPermission() {
        XCTAssertEqual(
            InputMonitoringPermissions.missingPermissions(accessibilityGranted: false),
            [.accessibility]
        )
        XCTAssertEqual(
            InputMonitoringPermissions.missingPermissions(accessibilityGranted: true),
            []
        )
    }

    func testExistingIncompleteUserMigratesToPresentedWithoutPrompt() {
        let defaults = makeDefaults()
        defaults.set(false, forKey: "IsFirstRun")
        defaults.set(false, forKey: "HasCompletedAccessibilityOnboarding")

        let manager = PreferencesManager(userDefaults: defaults)
        XCTAssertEqual(manager.accessibilityOnboardingState, .presented)
    }

    func testLegacyCompletedAndNewInstallMigration() {
        let completedDefaults = makeDefaults()
        completedDefaults.set(true, forKey: "HasCompletedAccessibilityOnboarding")
        XCTAssertEqual(PreferencesManager(userDefaults: completedDefaults).accessibilityOnboardingState, .completed)

        let newDefaults = makeDefaults()
        newDefaults.set(true, forKey: "IsFirstRun")
        XCTAssertEqual(PreferencesManager(userDefaults: newDefaults).accessibilityOnboardingState, .notPresented)
    }

    private func makeDefaults() -> UserDefaults {
        let name = "PermissionFlowTests.\(UUID().uuidString)"
        suiteNames.append(name)
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }
}

private final class StubScreenRecordingProvider: ScreenRecordingPermissionProviding {
    var hasAccessValue: Bool
    var requestResult: Bool
    var asyncCheckResult = false
    private(set) var requestCount = 0
    private(set) var checkCount = 0
    private(set) var openSettingsCount = 0

    init(hasAccess: Bool, requestResult: Bool) {
        hasAccessValue = hasAccess
        self.requestResult = requestResult
    }

    func hasAccess() -> Bool { hasAccessValue }
    func requestAccess() -> Bool {
        requestCount += 1
        return requestResult
    }
    func checkAccess(completion: @escaping (Bool) -> Void) {
        checkCount += 1
        completion(asyncCheckResult)
    }
    func openSettings() { openSettingsCount += 1 }
}

private final class InMemoryScreenRecordingStore: ScreenRecordingPermissionStoring {
    var hasRequestedScreenRecordingPermission: Bool
    init(hasRequested: Bool) { hasRequestedScreenRecordingPermission = hasRequested }
}
