import Foundation
import AppKit
import IOKit

/// Manages Input Monitoring and Accessibility permission checks for the text expander
enum InputMonitoringPermissions {
    static func hasInputMonitoringAccess() -> Bool {
        IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
    }

    static func hasAccessibilityAccess() -> Bool {
        AccessibilityPermissions.hasPermissions()
    }

    static func hasPermissions() -> Bool {
        missingPermissions().isEmpty
    }

    static func missingPermissions() -> Set<PermissionKind> {
        var missing: Set<PermissionKind> = []
        if !hasInputMonitoringAccess() { missing.insert(.inputMonitoring) }
        if !hasAccessibilityAccess() { missing.insert(.accessibility) }
        return missing
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

        let ordered = [PermissionKind.inputMonitoring, .accessibility].filter { missing.contains($0) }
        for permission in ordered {
            alert.addButton(withTitle: "Open \(permission.displayName) Settings")
        }
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        let index = response.rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
        guard index >= 0, index < ordered.count else { return }
        switch ordered[index] {
        case .inputMonitoring: requestInputMonitoringAccess()
        case .accessibility: AccessibilityPermissions.openSecurityPreferences()
        case .screenRecording: break
        }
    }

    /// Registers WindowSnap with macOS before opening the Input Monitoring pane.
    /// Merely opening System Settings does not add an app to the permission list.
    @discardableResult
    static func requestInputMonitoringAccess(
        requestAccess: () -> Bool = { IOHIDRequestAccess(kIOHIDRequestTypeListenEvent) },
        openSettings: () -> Void = { openInputMonitoringSettings() }
    ) -> Bool {
        let granted = requestAccess()
        if !granted {
            openSettings()
        }
        return granted
    }

    static func openInputMonitoringSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }

    static func missingPermissionDescription() -> String {
        missingPermissions().map(\.displayName).sorted().joined(separator: " and ")
    }
}
