import Foundation
import AppKit

/// Manages the Accessibility permission required by the text expander.
/// Accessibility grants both event listening and event posting on macOS, so
/// requiring Input Monitoring as well would be redundant.
enum InputMonitoringPermissions {
    static func hasAccessibilityAccess() -> Bool {
        AccessibilityPermissions.hasPermissions()
    }

    static func hasPermissions() -> Bool {
        missingPermissions().isEmpty
    }

    static func missingPermissions(accessibilityGranted: Bool? = nil) -> Set<PermissionKind> {
        let isGranted = accessibilityGranted ?? hasAccessibilityAccess()
        return isGranted ? [] : [.accessibility]
    }

    static func canCreateEventTap() -> Bool {
        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)

        let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: { _, _, event, _ in Unmanaged.passRetained(event) },
            userInfo: nil
        )

        return tap != nil
    }

    static func showSetupAlert() {
        let missing = missingPermissions()
        guard !missing.isEmpty else { return }

        let alert = NSAlert()
        alert.messageText = "Set Up Text Expander"
        let names = missing.map(\.displayName).sorted().joined(separator: " and ")
        alert.informativeText = "WindowSnap needs \(names) access to detect a trigger and insert its replacement. Enable the missing access in Privacy & Security, then return to WindowSnap."
        alert.alertStyle = .informational

        alert.addButton(withTitle: "Open Accessibility Settings")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            AccessibilityPermissions.openSecurityPreferences()
        }
    }

    static func missingPermissionDescription() -> String {
        missingPermissions().map(\.displayName).sorted().joined(separator: " and ")
    }
}
