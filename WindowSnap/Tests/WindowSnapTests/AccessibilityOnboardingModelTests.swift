import XCTest
@testable import WindowSnap

final class AccessibilityOnboardingModelTests: XCTestCase {
    func testCleanInstallWithoutPermissionPresentsOnboardingOnce() {
        let store = InMemoryOnboardingStore(state: .notPresented)
        let permissions = StubAccessibilityPermissionProvider(status: .notGranted)
        let model = AccessibilityOnboardingModel(permissionProvider: permissions, store: store)

        XCTAssertTrue(model.shouldPresentOnLaunch)
        model.markPresented()
        XCTAssertEqual(store.accessibilityOnboardingState, .presented)
        XCTAssertFalse(model.shouldPresentOnLaunch)
        XCTAssertEqual(permissions.requestCount, 0)
    }

    func testClosingOrDeferringPresentedOnboardingNeverReopensIt() {
        let model = AccessibilityOnboardingModel(
            permissionProvider: StubAccessibilityPermissionProvider(status: .notGranted),
            store: InMemoryOnboardingStore(state: .presented)
        )

        XCTAssertFalse(model.shouldPresentOnLaunch)
        model.refreshPermissionStatus()
        XCTAssertFalse(model.shouldPresentOnLaunch)
    }

    func testCheckingLaunchStateNeverRequestsSystemPermission() {
        let permissions = StubAccessibilityPermissionProvider(status: .notGranted)
        let model = AccessibilityOnboardingModel(
            permissionProvider: permissions,
            store: InMemoryOnboardingStore(state: .notPresented)
        )

        _ = model.shouldPresentOnLaunch
        model.refreshPermissionStatus()
        XCTAssertEqual(permissions.requestCount, 0)
    }

    func testExplicitContinueIsTheOnlyActionThatRequestsSystemPermission() {
        let permissions = StubAccessibilityPermissionProvider(status: .notGranted)
        let model = AccessibilityOnboardingModel(
            permissionProvider: permissions,
            store: InMemoryOnboardingStore(state: .presented)
        )

        model.requestPermission()
        XCTAssertEqual(permissions.requestCount, 1)
    }

    func testRefreshCompletesOnboardingWhenPermissionIsGranted() {
        let store = InMemoryOnboardingStore(state: .presented)
        let permissions = StubAccessibilityPermissionProvider(status: .notGranted)
        let model = AccessibilityOnboardingModel(permissionProvider: permissions, store: store)

        permissions.status = .granted
        model.refreshPermissionStatus()

        XCTAssertEqual(model.status, .granted)
        XCTAssertEqual(store.accessibilityOnboardingState, .completed)
        XCTAssertTrue(model.canFinish)
    }

    func testFinishRequiresPermissionAndPersistsCompletion() {
        let store = InMemoryOnboardingStore(state: .presented)
        let permissions = StubAccessibilityPermissionProvider(status: .notGranted)
        let model = AccessibilityOnboardingModel(permissionProvider: permissions, store: store)

        XCTAssertFalse(model.finish())
        XCTAssertEqual(store.accessibilityOnboardingState, .presented)

        permissions.status = .granted
        model.refreshPermissionStatus()
        XCTAssertTrue(model.finish())
        XCTAssertEqual(store.accessibilityOnboardingState, .completed)
    }

    func testExistingAuthorizedUserIsCompletedWithoutPrompt() {
        let store = InMemoryOnboardingStore(state: .notPresented)
        let model = AccessibilityOnboardingModel(
            permissionProvider: StubAccessibilityPermissionProvider(status: .granted),
            store: store
        )

        XCTAssertFalse(model.shouldPresentOnLaunch)
        XCTAssertEqual(store.accessibilityOnboardingState, .completed)
    }

    func testOpenSettingsDoesNotRequestPermission() {
        let permissions = StubAccessibilityPermissionProvider(status: .notGranted)
        let model = AccessibilityOnboardingModel(
            permissionProvider: permissions,
            store: InMemoryOnboardingStore(state: .presented)
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

    init(status: AccessibilityAuthorizationStatus) { self.status = status }
    func currentStatus() -> AccessibilityAuthorizationStatus { status }
    func requestPermission() { requestCount += 1 }
    func openSystemSettings() { openSettingsCount += 1 }
}

private final class InMemoryOnboardingStore: AccessibilityOnboardingStoring {
    var accessibilityOnboardingState: AccessibilityOnboardingState
    init(state: AccessibilityOnboardingState) { accessibilityOnboardingState = state }
}
