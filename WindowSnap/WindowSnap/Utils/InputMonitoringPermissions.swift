import Foundation
import AppKit
import IOKit

/// Manages Input Monitoring permission checks and user guidance
class InputMonitoringPermissions {
    
    static func hasPermissions() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): false] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        
        if trusted {
            return true
        }
        
        return canCreateEventTap()
    }
    
    private static func canCreateEventTap() -> Bool {
        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
        
        let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: { _, _, event, _ in Unmanaged.passRetained(event) },
            userInfo: nil
        )
        
        if tap != nil {
            return true
        }
        
        return false
    }
    
    static func requestPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
    
    static func showPermissionsAlert() {
        let alert = NSAlert()
        alert.messageText = "Input Monitoring Access Required"
        alert.informativeText = """
        The Text Expander feature requires Input Monitoring permissions to detect when you type trigger phrases.
        
        Please:
        1. Open System Settings
        2. Go to Privacy & Security
        3. Select Input Monitoring
        4. Enable WindowSnap in the list
        
        After granting permission, the Text Expander feature will be enabled automatically.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Later")
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            openInputMonitoringSettings()
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
        } else {
            showPermissionsAlert()
            return false
        }
    }
    
    static func showPermissionDeniedNotification() {
        let notification = NSUserNotification()
        notification.title = "Text Expander Disabled"
        notification.informativeText = "Input Monitoring permission is required for text expansion. Click to enable."
        notification.soundName = nil
        
        NSUserNotificationCenter.default.deliver(notification)
    }
}
