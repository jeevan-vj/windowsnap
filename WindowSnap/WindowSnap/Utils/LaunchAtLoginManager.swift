import Foundation
import ServiceManagement

enum LaunchAtLoginSystemStatus: Equatable {
    case enabled
    case disabled
    case requiresApproval
    case notFound
    case unknown

    init(_ status: SMAppService.Status) {
        switch status {
        case .enabled:
            self = .enabled
        case .notRegistered:
            self = .disabled
        case .requiresApproval:
            self = .requiresApproval
        case .notFound:
            self = .notFound
        @unknown default:
            self = .unknown
        }
    }

    var isEnabled: Bool { self == .enabled }
}

protocol LaunchAtLoginService: AnyObject {
    var status: LaunchAtLoginSystemStatus { get }
    func register() throws
    func unregister() throws
}

protocol LaunchAtLoginPreferenceStoring: AnyObject {
    var launchAtLogin: Bool { get set }
}

extension PreferencesManager: LaunchAtLoginPreferenceStoring {}

private final class MainAppLaunchAtLoginService: LaunchAtLoginService {
    var status: LaunchAtLoginSystemStatus {
        LaunchAtLoginSystemStatus(SMAppService.mainApp.status)
    }

    func register() throws {
        try SMAppService.mainApp.register()
    }

    func unregister() throws {
        try SMAppService.mainApp.unregister()
    }
}

final class LaunchAtLoginManager {
    static let shared = LaunchAtLoginManager(
        service: MainAppLaunchAtLoginService(),
        preferences: PreferencesManager.shared
    )

    private let service: LaunchAtLoginService
    private let preferences: LaunchAtLoginPreferenceStoring

    init(service: LaunchAtLoginService, preferences: LaunchAtLoginPreferenceStoring) {
        self.service = service
        self.preferences = preferences
    }

    var status: LaunchAtLoginSystemStatus {
        service.status
    }

    var isEnabled: Bool {
        status.isEnabled
    }

    /// Reads the real system registration and mirrors it into the cached preference.
    /// This method never registers a login item; registration requires `setEnabled(true)`.
    @discardableResult
    func refreshStatus() -> LaunchAtLoginSystemStatus {
        let actualStatus = status
        preferences.launchAtLogin = actualStatus.isEnabled
        return actualStatus
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try enable()
        } else {
            try disable()
        }
    }

    private func enable() throws {
        switch status {
        case .enabled:
            preferences.launchAtLogin = true
            return
        case .requiresApproval:
            preferences.launchAtLogin = false
            throw LaunchAtLoginError.requiresApproval
        case .notFound:
            preferences.launchAtLogin = false
            throw LaunchAtLoginError.serviceNotFound
        case .disabled, .unknown:
            break
        }

        do {
            try service.register()
        } catch {
            preferences.launchAtLogin = status.isEnabled
            throw LaunchAtLoginError.registrationFailed(underlying: error)
        }

        try validateEnabledStatus()
    }

    private func validateEnabledStatus() throws {
        switch refreshStatus() {
        case .enabled:
            return
        case .requiresApproval:
            throw LaunchAtLoginError.requiresApproval
        case .notFound:
            throw LaunchAtLoginError.serviceNotFound
        case .disabled, .unknown:
            throw LaunchAtLoginError.registrationDidNotEnable
        }
    }

    private func disable() throws {
        switch status {
        case .disabled, .notFound:
            preferences.launchAtLogin = false
            return
        case .enabled, .requiresApproval, .unknown:
            break
        }

        do {
            try service.unregister()
        } catch {
            preferences.launchAtLogin = status.isEnabled
            throw LaunchAtLoginError.unregistrationFailed(underlying: error)
        }

        switch refreshStatus() {
        case .disabled, .notFound:
            return
        case .enabled, .requiresApproval, .unknown:
            throw LaunchAtLoginError.unregistrationDidNotDisable
        }
    }
}

enum LaunchAtLoginError: LocalizedError {
    case requiresApproval
    case serviceNotFound
    case registrationFailed(underlying: Error)
    case registrationDidNotEnable
    case unregistrationFailed(underlying: Error)
    case unregistrationDidNotDisable

    var errorDescription: String? {
        switch self {
        case .requiresApproval:
            return "WindowSnap needs your approval in System Settings > General > Login Items. Allow WindowSnap, then return to Preferences."
        case .serviceNotFound:
            return "macOS could not find WindowSnap as an installed application. Move WindowSnap to the Applications folder, reopen it, and try again."
        case .registrationFailed(let error):
            return "WindowSnap could not be added to Login Items (\(error.localizedDescription)). Check System Settings > General > Login Items and try again."
        case .registrationDidNotEnable:
            return "macOS did not enable WindowSnap. Check System Settings > General > Login Items and try again."
        case .unregistrationFailed(let error):
            return "WindowSnap could not be removed from Login Items (\(error.localizedDescription)). Remove it in System Settings > General > Login Items."
        case .unregistrationDidNotDisable:
            return "macOS still reports WindowSnap as enabled. Remove it in System Settings > General > Login Items."
        }
    }
}
