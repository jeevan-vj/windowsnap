import Foundation

enum AccessibilityAuthorizationStatus: Equatable {
    case notGranted
    case granted
    case unavailable(String)
}

enum AccessibilityOnboardingState: String, Equatable {
    case notPresented
    case presented
    case completed
}

protocol AccessibilityPermissionProviding: AnyObject {
    func currentStatus() -> AccessibilityAuthorizationStatus
    func requestPermission()
    func openSystemSettings()
}

protocol AccessibilityOnboardingStoring: AnyObject {
    var accessibilityOnboardingState: AccessibilityOnboardingState { get set }
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

        if status == .granted {
            store.accessibilityOnboardingState = .completed
        }
    }

    var onboardingState: AccessibilityOnboardingState {
        store.accessibilityOnboardingState
    }

    var shouldPresentOnLaunch: Bool {
        onboardingState == .notPresented && status != .granted
    }

    var canFinish: Bool {
        status == .granted
    }

    func refreshPermissionStatus() {
        status = permissionProvider.currentStatus()
        if status == .granted {
            store.accessibilityOnboardingState = .completed
        }
    }

    func markPresented() {
        guard store.accessibilityOnboardingState == .notPresented else { return }
        store.accessibilityOnboardingState = .presented
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
        store.accessibilityOnboardingState = .completed
        return true
    }
}
