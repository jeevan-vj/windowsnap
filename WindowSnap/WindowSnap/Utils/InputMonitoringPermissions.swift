import Foundation
import AppKit
import IOKit
import UserNotifications

/// Manages Input Monitoring and Accessibility permission checks for the text expander
enum InputMonitoringPermissions {
    static func hasInputMonitoringAccess() -> Bool {
        IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
    }

    static func hasAccessibilityAccess() -> Bool {
        AccessibilityPermissions.hasPermissions()
    }

    static func hasPermissions() -> Bool {
        hasInputMonitoringAccess() && hasAccessibilityAccess()
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

    static func requestPermissions() {
        _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        AccessibilityPermissions.requestPermissions()
    }

    static func showPermissionsAlert() {
        let alert = NSAlert()
        alert.messageText = "Permissions Required for Text Expander"
        alert.informativeText = """
        The Text Expander requires both Input Monitoring and Accessibility permissions.

        Input Monitoring:
        1. Open System Settings
        2. Go to Privacy & Security
        3. Select Input Monitoring
        4. Enable WindowSnap

        Accessibility:
        1. Open System Settings
        2. Go to Privacy & Security
        3. Select Accessibility
        4. Enable WindowSnap

        After granting both permissions, restart the Text Expander from the menu bar.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open Input Monitoring")
        alert.addButton(withTitle: "Open Accessibility")
        alert.addButton(withTitle: "Later")

        let response = alert.runModal()

        switch response {
        case .alertFirstButtonReturn:
            openInputMonitoringSettings()
        case .alertSecondButtonReturn:
            AccessibilityPermissions.openSecurityPreferences()
        default:
            break
        }
    }

    static func openInputMonitoringSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent") {
            NSWorkspace.shared.open(url)
        }
    }

    static func checkPermissionsWithAlert() -> Bool {
        if hasPermissions() {
            return true
        }
        showPermissionsAlert()
        return false
    }

    static func missingPermissionDescription() -> String {
        var missing: [String] = []
        if !hasInputMonitoringAccess() {
            missing.append("Input Monitoring")
        }
        if !hasAccessibilityAccess() {
            missing.append("Accessibility")
        }
        return missing.joined(separator: " and ")
    }

    static func showPermissionDeniedNotification() {
        requestNotificationAuthorizationIfNeeded()

        let content = UNMutableNotificationContent()
        content.title = "Text Expander Disabled"
        content.body = "Input Monitoring and Accessibility permissions are required for text expansion."

        let request = UNNotificationRequest(
            identifier: "com.windowsnap.textexpander.permissions",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                AppLog.permissions.error("Failed to deliver permission notification: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private static func requestNotificationAuthorizationIfNeeded() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                AppLog.permissions.error("Notification authorization failed: \(error.localizedDescription, privacy: .public)")
            } else if !granted {
                AppLog.permissions.debug("Notification authorization not granted")
            }
        }
    }
}
