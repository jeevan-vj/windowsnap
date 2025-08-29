import Foundation
import ServiceManagement

class LaunchAtLoginManager {
    static let shared = LaunchAtLoginManager()
    
    private init() {}
    
    // App bundle identifier
    private var bundleIdentifier: String {
        return Bundle.main.bundleIdentifier ?? "com.windowsnap.app"
    }
    
    // Check if app is set to launch at login
    var isEnabled: Bool {
        get {
            if #available(macOS 13.0, *) {
                return SMAppService.mainApp.status == .enabled
            } else {
                return isEnabledLegacy()
            }
        }
    }
    
    // Enable or disable launch at login
    func setEnabled(_ enabled: Bool) throws {
        if #available(macOS 13.0, *) {
            try setEnabledModern(enabled)
        } else {
            try setEnabledLegacy(enabled)
        }
        
        // Update preferences via UserDefaults directly to avoid circular import
        UserDefaults.standard.set(enabled, forKey: "LaunchAtLogin")
    }
    
    // Modern approach for macOS 13+
    @available(macOS 13.0, *)
    private func setEnabledModern(_ enabled: Bool) throws {
        if enabled {
            if SMAppService.mainApp.status == .enabled {
                return // Already enabled
            }
            try SMAppService.mainApp.register()
        } else {
            if SMAppService.mainApp.status != .enabled {
                return // Already disabled
            }
            try SMAppService.mainApp.unregister()
        }
    }
    
    // Legacy approach for macOS 12 and earlier
    private func setEnabledLegacy(_ enabled: Bool) throws {
        let success: Bool
        if enabled {
            // Suppress deprecation warning for backward compatibility
            success = SMLoginItemSetEnabled(bundleIdentifier as CFString, true)
        } else {
            // Suppress deprecation warning for backward compatibility
            success = SMLoginItemSetEnabled(bundleIdentifier as CFString, false)
        }
        
        if !success {
            throw LaunchAtLoginError.failedToSetState
        }
    }
    
    private func isEnabledLegacy() -> Bool {
        // For older systems, we'll use a simpler approach
        // Check UserDefaults as the source of truth for legacy systems
        return UserDefaults.standard.bool(forKey: "LaunchAtLogin")
    }
}

// MARK: - Error Types
enum LaunchAtLoginError: Error, LocalizedError {
    case failedToSetState
    case unsupportedSystem
    
    var errorDescription: String? {
        switch self {
        case .failedToSetState:
            return "Failed to update launch at login setting"
        case .unsupportedSystem:
            return "This system version is not supported"
        }
    }
}
