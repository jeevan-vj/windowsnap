import XCTest
@testable import WindowSnap

final class AccessibilityOnboardingModelTests: XCTestCase {
    func testCleanInstallWithoutPermissionPresentsOnboarding() {
        let store = InMemoryOnboardingStore(hasCompletedAccessibilityOnboarding: false)
        let permissions = StubAccessibilityPermissionProvider(status: .notGranted)
        let model = AccessibilityOnboardingModel(permissionProvider: permissions, store: store)

        XCTAssertTrue(model.shouldPresentOnLaunch)
        XCTAssertEqual(model.status, .notGranted)
        XCTAssertFalse(model.canFinish)
        XCTAssertEqual(permissions.requestCount, 0)
    }

    func testCheckingLaunchStateNeverRequestsSystemPermission() {
        let permissions = StubAccessibilityPermissionProvider(status: .notGranted)
        let model = AccessibilityOnboardingModel(
            permissionProvider: permissions,
            store: InMemoryOnboardingStore(hasCompletedAccessibilityOnboarding: false)
        )

        _ = model.shouldPresentOnLaunch
        model.refreshPermissionStatus()

        XCTAssertEqual(permissions.requestCount, 0)
    }

    func testExplicitRequestIsTheOnlyActionThatRequestsSystemPermission() {
        let permissions = StubAccessibilityPermissionProvider(status: .notGranted)
        let model = AccessibilityOnboardingModel(
            permissionProvider: permissions,
            store: InMemoryOnboardingStore(hasCompletedAccessibilityOnboarding: false)
        )

        model.requestPermission()

        XCTAssertEqual(permissions.requestCount, 1)
    }

    func testRefreshReflectsPermissionGrantedInSystemSettings() {
        let permissions = StubAccessibilityPermissionProvider(status: .notGranted)
        let model = AccessibilityOnboardingModel(
            permissionProvider: permissions,
            store: InMemoryOnboardingStore(hasCompletedAccessibilityOnboarding: false)
        )

        permissions.status = .granted
        model.refreshPermissionStatus()

        XCTAssertEqual(model.status, .granted)
        XCTAssertTrue(model.canFinish)
    }

    func testFinishPersistsCompletionOnlyAfterPermissionIsGranted() {
        let store = InMemoryOnboardingStore(hasCompletedAccessibilityOnboarding: false)
        let permissions = StubAccessibilityPermissionProvider(status: .notGranted)
        let model = AccessibilityOnboardingModel(permissionProvider: permissions, store: store)

        XCTAssertFalse(model.finish())
        XCTAssertFalse(store.hasCompletedAccessibilityOnboarding)

        permissions.status = .granted
        model.refreshPermissionStatus()

        XCTAssertTrue(model.finish())
        XCTAssertTrue(store.hasCompletedAccessibilityOnboarding)
    }

    func testCompletionIsIndependentFromLaterPermissionChanges() {
        let store = InMemoryOnboardingStore(hasCompletedAccessibilityOnboarding: true)
        let permissions = StubAccessibilityPermissionProvider(status: .notGranted)
        let model = AccessibilityOnboardingModel(permissionProvider: permissions, store: store)

        XCTAssertFalse(model.shouldPresentOnLaunch)
        XCTAssertTrue(model.hasCompletedOnboarding)
        XCTAssertEqual(model.status, .notGranted)
    }

    func testExistingAuthorizedUserIsNotShownOnboarding() {
        let store = InMemoryOnboardingStore(hasCompletedAccessibilityOnboarding: false)
        let permissions = StubAccessibilityPermissionProvider(status: .granted)
        let model = AccessibilityOnboardingModel(
            permissionProvider: permissions,
            store: store
        )

        XCTAssertFalse(model.shouldPresentOnLaunch)
        XCTAssertTrue(model.canFinish)
        XCTAssertTrue(store.hasCompletedAccessibilityOnboarding)
    }

    func testUnavailableStatusIsExposedAsActionableState() {
        let permissions = StubAccessibilityPermissionProvider(status: .unavailable("Permission status could not be read"))
        let model = AccessibilityOnboardingModel(
            permissionProvider: permissions,
            store: InMemoryOnboardingStore(hasCompletedAccessibilityOnboarding: false)
        )

        XCTAssertEqual(model.status, .unavailable("Permission status could not be read"))
        XCTAssertFalse(model.canFinish)
        XCTAssertTrue(model.shouldPresentOnLaunch)
    }

    func testOpenSettingsDelegatesWithoutRequestingPermission() {
        let permissions = StubAccessibilityPermissionProvider(status: .notGranted)
        let model = AccessibilityOnboardingModel(
            permissionProvider: permissions,
            store: InMemoryOnboardingStore(hasCompletedAccessibilityOnboarding: false)
        )

        model.openSystemSettings()

        XCTAssertEqual(permissions.openSettingsCount, 1)
        XCTAssertEqual(permissions.requestCount, 0)
    }
}

private final class StubAccessibilityPermissionProvider: AccessibilityPermissionProviding {
    var status: AccessibilityAuthorizationStatus
    private(set) var requestCount = 0
    private(set) var openSettingsCount = 0

    init(status: AccessibilityAuthorizationStatus) {
        self.status = status
    }

    func currentStatus() -> AccessibilityAuthorizationStatus { status }
    func requestPermission() { requestCount += 1 }
    func openSystemSettings() { openSettingsCount += 1 }
}

private final class InMemoryOnboardingStore: AccessibilityOnboardingStoring {
    var hasCompletedAccessibilityOnboarding: Bool

    init(hasCompletedAccessibilityOnboarding: Bool) {
        self.hasCompletedAccessibilityOnboarding = hasCompletedAccessibilityOnboarding
    }
}
