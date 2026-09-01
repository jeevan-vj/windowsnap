import Foundation
import ApplicationServices
import AppKit

final class AccessibilityPermissions: AccessibilityPermissionProviding {
    static let shared = AccessibilityPermissions()

    private init() {}
    
    static func hasPermissions() -> Bool {
        let trusted = AXIsProcessTrusted()
        print("🔍 Accessibility permission check: \(trusted)")
        print("   Bundle ID: \(Bundle.main.bundleIdentifier ?? "unknown")")
        return trusted
    }
    
    static func requestPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    func currentStatus() -> AccessibilityAuthorizationStatus {
        .init(isTrusted: AXIsProcessTrusted())
    }

    func requestPermission() {
        Self.requestPermissions()
    }

    func openSystemSettings() {
        Self.openSecurityPreferences()
    }
    
    static func openSecurityPreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
    
}

private extension AccessibilityAuthorizationStatus {
    init(isTrusted: Bool) {
        self = isTrusted ? .granted : .notGranted
    }
}
