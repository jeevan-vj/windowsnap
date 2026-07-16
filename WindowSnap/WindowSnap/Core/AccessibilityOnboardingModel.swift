import Foundation

enum AccessibilityAuthorizationStatus: Equatable {
    case notGranted
    case granted
    case unavailable(String)
}

protocol AccessibilityPermissionProviding: AnyObject {
    func currentStatus() -> AccessibilityAuthorizationStatus
    func requestPermission()
    func openSystemSettings()
}

protocol AccessibilityOnboardingStoring: AnyObject {
    var hasCompletedAccessibilityOnboarding: Bool { get set }
}

final class AccessibilityOnboardingModel {
    private let permissionProvider: AccessibilityPermissionProviding
    private let store: AccessibilityOnboardingStoring

    private(set) var status: AccessibilityAuthorizationStatus

    init(
        permissionProvider: AccessibilityPermissionProviding,
        store: AccessibilityOnboardingStoring
    ) {
        self.permissionProvider = permissionProvider
        self.store = store
        status = permissionProvider.currentStatus()

        // Existing users may already have granted access before onboarding existed.
        // Treat that authorization as completed so a later TCC change does not
        // retroactively turn them into first-run users; the menu retry remains available.
        if status == .granted {
            store.hasCompletedAccessibilityOnboarding = true
        }
    }

    var hasCompletedOnboarding: Bool {
        store.hasCompletedAccessibilityOnboarding
    }

    var shouldPresentOnLaunch: Bool {
        guard !hasCompletedOnboarding else { return false }
        return status != .granted
    }

    var canFinish: Bool {
        status == .granted
    }

    func refreshPermissionStatus() {
        status = permissionProvider.currentStatus()
    }

    /// Must only be called in direct response to an explicit user action.
    func requestPermission() {
        permissionProvider.requestPermission()
        refreshPermissionStatus()
    }

    func openSystemSettings() {
        permissionProvider.openSystemSettings()
    }

    @discardableResult
    func finish() -> Bool {
        guard canFinish else { return false }
        store.hasCompletedAccessibilityOnboarding = true
        return true
    }
}
