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

    func testPreflightFalseNeverTriggersScreenCaptureKitProbe() {
        for hasRequested in [false, true] {
            let provider = StubScreenRecordingProvider(hasAccess: false, requestResult: false)
            provider.asyncCheckResult = true
            let coordinator = ScreenRecordingPermissionCoordinator(
                provider: provider,
                store: InMemoryScreenRecordingStore(hasRequested: hasRequested)
            )

            var states: [ScreenRecordingPermissionState] = []
            coordinator.refreshState { states.append($0) }
            _ = coordinator.immediateState
            coordinator.requestAccess()
            coordinator.refreshState { states.append($0) }

            XCTAssertEqual(states.count, 2, "refreshState must complete synchronously from preflight")
            XCTAssertEqual(provider.checkCount, 0)
        }
    }

    func testRefreshNeverPrompts() {
        let provider = StubScreenRecordingProvider(hasAccess: false, requestResult: false)
        let coordinator = ScreenRecordingPermissionCoordinator(
            provider: provider,
            store: InMemoryScreenRecordingStore(hasRequested: false)
        )
        for _ in 0..<5 { coordinator.refreshState { _ in } }
        XCTAssertEqual(coordinator.immediateState, .notRequested)
        XCTAssertEqual(provider.requestCount, 0)
    }

    func testScreenRecordingPromptsAtMostOncePerLaunch() {
        let provider = StubScreenRecordingProvider(hasAccess: false, requestResult: false)
        let store = InMemoryScreenRecordingStore(hasRequested: false)
        let coordinator = ScreenRecordingPermissionCoordinator(provider: provider, store: store)

        coordinator.requestAccess()
        coordinator.requestAccess()
        coordinator.retryAccess()
        coordinator.retryAccess()

        XCTAssertEqual(provider.requestCount, 1)
        XCTAssertTrue(store.hasRequestedScreenRecordingPermission)
    }

    func testRecoveryRetryAlsoLimitedToOnePromptPerLaunch() {
        let provider = StubScreenRecordingProvider(hasAccess: false, requestResult: false)
        let coordinator = ScreenRecordingPermissionCoordinator(
            provider: provider,
            store: InMemoryScreenRecordingStore(hasRequested: true)
        )

        XCTAssertEqual(coordinator.retryAccess(), .restartRequired)
        XCTAssertEqual(coordinator.retryAccess(), .restartRequired)
        XCTAssertEqual(provider.requestCount, 1)
    }

    func testPendingGrantThisLaunchLeadsToRestartRequired() {
        let provider = StubScreenRecordingProvider(hasAccess: false, requestResult: false)
        let coordinator = ScreenRecordingPermissionCoordinator(
            provider: provider,
            store: InMemoryScreenRecordingStore(hasRequested: false)
        )

        XCTAssertEqual(coordinator.immediateState, .notRequested)
        XCTAssertEqual(coordinator.requestAccess(), .restartRequired)
        XCTAssertTrue(coordinator.hasRequestedThisLaunch)

        var refreshed: ScreenRecordingPermissionState?
        coordinator.refreshState { refreshed = $0 }
        XCTAssertEqual(refreshed, .restartRequired)
        XCTAssertEqual(provider.checkCount, 0)
    }

    func testStaleGrantFromEarlierLaunchLeadsToRecoveryWithoutPrompting() {
        let provider = StubScreenRecordingProvider(hasAccess: false, requestResult: false)
        let coordinator = ScreenRecordingPermissionCoordinator(
            provider: provider,
            store: InMemoryScreenRecordingStore(hasRequested: true)
        )

        var refreshed: ScreenRecordingPermissionState?
        coordinator.refreshState { refreshed = $0 }
        XCTAssertEqual(refreshed, .needsRecovery)
        XCTAssertEqual(coordinator.immediateState, .needsRecovery)
        XCTAssertEqual(provider.requestCount, 0)
        XCTAssertEqual(provider.checkCount, 0)
    }

    func testGrantedWinsOverEveryOtherState() {
        let provider = StubScreenRecordingProvider(hasAccess: false, requestResult: false)
        let coordinator = ScreenRecordingPermissionCoordinator(
            provider: provider,
            store: InMemoryScreenRecordingStore(hasRequested: true)
        )
        coordinator.requestAccess()
        provider.hasAccessValue = true
        XCTAssertEqual(coordinator.immediateState, .granted)
        XCTAssertEqual(coordinator.requestAccess(), .granted)
        XCTAssertEqual(provider.requestCount, 1)
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

    func testRecoveryAlertIsDebounced() {
        var now = Date(timeIntervalSince1970: 1_000)
        let coordinator = ScreenRecordingPermissionCoordinator(
            provider: StubScreenRecordingProvider(hasAccess: false, requestResult: false),
            store: InMemoryScreenRecordingStore(hasRequested: true),
            now: { now }
        )

        XCTAssertTrue(coordinator.shouldPresentRecoveryAlert())
        now += 5
        XCTAssertFalse(coordinator.shouldPresentRecoveryAlert())
        now += ScreenRecordingPermissionCoordinator.recoveryAlertDebounce
        XCTAssertTrue(coordinator.shouldPresentRecoveryAlert())
    }

    func testSigningIdentityWarnsForAdHocAndOutsideApplications() {
        let good = AppSigningIdentity(
            bundlePath: "/Applications/WindowSnap.app",
            bundleIdentifier: "com.jeevanwijerathna.windowsnap",
            teamIdentifier: "88282K637B",
            isAdHoc: false,
            isSigned: true
        )
        XCTAssertEqual(good.signingSummary, "team 88282K637B")
        XCTAssertTrue(good.warnings.isEmpty)

        var adHoc = good
        adHoc.isAdHoc = true
        adHoc.teamIdentifier = nil
        adHoc.bundlePath = "/Users/dev/windowsnap/dist/WindowSnap.app"
        XCTAssertEqual(adHoc.signingSummary, "ad-hoc")
        XCTAssertEqual(adHoc.warnings.count, 2)
    }

    func testTextExpanderReportsEachMissingPermissionAndStaysOff() {
        let defaults = makeDefaults()
        defaults.set(true, forKey: "WindowSnap_TextExpanderHasPopulatedDefaults")
        let manager = TextExpanderManager(userDefaults: defaults)
        var missing: Set<PermissionKind> = [.accessibility]
        let controller = TextExpanderRuntimeController(manager: manager, missingPermissions: { missing })

        XCTAssertEqual(controller.setDesiredEnabled(true), .needsPermission([.accessibility]))
        XCTAssertTrue(manager.isEnabled)

        missing = [.inputMonitoring]
        XCTAssertEqual(controller.setDesiredEnabled(true), .needsPermission([.inputMonitoring]))
        XCTAssertTrue(manager.isEnabled)

        missing = []
        XCTAssertEqual(controller.reconcile(), .running)
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
