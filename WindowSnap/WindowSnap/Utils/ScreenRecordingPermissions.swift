import AppKit
import Foundation
import ScreenCaptureKit

enum ScreenRecordingPermissionState: Equatable {
    case notRequested
    case denied
    case restartRequired
    case granted

    var statusText: String {
        switch self {
        case .notRequested: return "Not set up"
        case .denied: return "Screen Recording is off"
        case .restartRequired: return "Restart required"
        case .granted: return "Granted"
        }
    }
}

protocol ScreenRecordingPermissionProviding {
    func hasAccess() -> Bool
    func requestAccess() -> Bool
    func checkAccess(completion: @escaping (Bool) -> Void)
    func openSettings()
}

protocol ScreenRecordingPermissionStoring: AnyObject {
    var hasRequestedScreenRecordingPermission: Bool { get set }
}

extension PreferencesManager: ScreenRecordingPermissionStoring {}

private struct SystemScreenRecordingPermissionProvider: ScreenRecordingPermissionProviding {
    func hasAccess() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    func requestAccess() -> Bool {
        CGRequestScreenCaptureAccess()
    }

    func checkAccess(completion: @escaping (Bool) -> Void) {
        Task {
            let hasAccess: Bool
            do {
                _ = try await SCShareableContent.current
                hasAccess = true
            } catch {
                hasAccess = false
            }
            await MainActor.run { completion(hasAccess) }
        }
    }

    func openSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else { return }
        NSWorkspace.shared.open(url)
    }
}

final class ScreenRecordingPermissionCoordinator {
    private let provider: ScreenRecordingPermissionProviding
    private let store: ScreenRecordingPermissionStoring

    init(provider: ScreenRecordingPermissionProviding, store: ScreenRecordingPermissionStoring) {
        self.provider = provider
        self.store = store
    }

    var immediateState: ScreenRecordingPermissionState {
        if provider.hasAccess() { return .granted }
        return store.hasRequestedScreenRecordingPermission ? .denied : .notRequested
    }

    func refreshState(completion: @escaping (ScreenRecordingPermissionState) -> Void) {
        if provider.hasAccess() {
            completion(.granted)
            return
        }

        // ScreenCaptureKit can participate in the system permission flow. Do not
        // consult it until the user has explicitly requested Screen Recording.
        guard store.hasRequestedScreenRecordingPermission else {
            completion(.notRequested)
            return
        }

        provider.checkAccess { hasAccessViaScreenCaptureKit in
            if hasAccessViaScreenCaptureKit {
                completion(.restartRequired)
            } else {
                completion(.denied)
            }
        }
    }

    @discardableResult
    func requestAccess() -> ScreenRecordingPermissionState {
        if provider.hasAccess() { return .granted }
        guard !store.hasRequestedScreenRecordingPermission else { return .denied }

        store.hasRequestedScreenRecordingPermission = true
        return provider.requestAccess() ? .granted : .denied
    }

    func openSettings() {
        provider.openSettings()
    }
}

enum ScreenRecordingPermissions {
    private static let coordinator = ScreenRecordingPermissionCoordinator(
        provider: SystemScreenRecordingPermissionProvider(),
        store: PreferencesManager.shared
    )
    private static var hasShownRestartAlert = false
    private static var lastKnownState: ScreenRecordingPermissionState?

    static func hasPermissions() -> Bool {
        coordinator.immediateState == .granted
    }

    static var state: ScreenRecordingPermissionState {
        let immediate = coordinator.immediateState
        if immediate == .granted { return .granted }
        return lastKnownState ?? immediate
    }

    static func refreshState(completion: @escaping (ScreenRecordingPermissionState) -> Void) {
        coordinator.refreshState { state in
            lastKnownState = state
            completion(state)
        }
    }

    static func requestPermissionForRegionShare(completion: @escaping (Bool) -> Void) {
        switch state {
        case .granted:
            completion(true)
        case .notRequested:
            showPrimer(completion: completion)
        case .denied:
            showSettingsRecovery()
            completion(false)
        case .restartRequired:
            showRestartRequiredAlert()
            completion(false)
        }
    }

    private static func showPrimer(completion: @escaping (Bool) -> Void) {
        let alert = NSAlert()
        alert.messageText = "Set Up Region Share"
        alert.informativeText = "Region Share needs Screen Recording access to capture only the area you select. macOS uses generic screen-and-audio wording, but WindowSnap requests no audio stream and crops the selected area locally on this Mac."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Continue")
        alert.addButton(withTitle: "Not Now")

        guard alert.runModal() == .alertFirstButtonReturn else {
            completion(false)
            return
        }

        let state = coordinator.requestAccess()
        lastKnownState = state
        completion(state == .granted)
    }

    private static func showSettingsRecovery() {
        let alert = NSAlert()
        alert.messageText = "Screen Recording Is Off"
        alert.informativeText = "Enable WindowSnap in Privacy & Security > Screen Recording, then return to WindowSnap."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            coordinator.openSettings()
        }
    }

    static func showRestartRequiredAlert() {
        guard !hasShownRestartAlert else { return }
        hasShownRestartAlert = true

        let alert = NSAlert()
        alert.messageText = "Restart WindowSnap"
        alert.informativeText = "Screen Recording is enabled, but WindowSnap needs to restart before Region Share can use it."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Restart Now")
        alert.addButton(withTitle: "Later")
        if alert.runModal() == .alertFirstButtonReturn {
            restartApp()
        }
    }

    private static func restartApp() {
        let url = URL(fileURLWithPath: Bundle.main.resourcePath!)
        let appURL = url.deletingLastPathComponent().deletingLastPathComponent()
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = [appURL.path]
        try? task.run()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { NSApp.terminate(nil) }
    }

    static func openScreenRecordingSettings() {
        coordinator.openSettings()
    }

    static func checkPermissionsWithAlert(completion: @escaping (Bool) -> Void) {
        refreshState { state in
            switch state {
            case .granted:
                completion(true)
            case .restartRequired:
                showRestartRequiredAlert()
                completion(false)
            case .notRequested, .denied:
                requestPermissionForRegionShare(completion: completion)
            }
        }
    }
}
