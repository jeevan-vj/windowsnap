import Foundation
import ApplicationServices
import AppKit

class AccessibilityPermissions {
    
    static func hasPermissions() -> Bool {
        return AXIsProcessTrusted()
    }
    
    static func requestPermissionIfNeeded() {
        if !hasPermissions() {
            requestPermissions()
        }
    }
    
    static func requestPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }
    
    static func showPermissionsAlert() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Access Required"
        alert.informativeText = """
        WindowSnap requires accessibility permissions to manage windows.
        
        Please:
        1. Open System Preferences
        2. Go to Security & Privacy
        3. Select Privacy tab
        4. Choose Accessibility
        5. Add WindowSnap to the list and enable it
        
        After granting permission, please restart WindowSnap.
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Preferences")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            openSecurityPreferences()
        }
    }
    
    static func openSecurityPreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }
    
    static func checkPermissionsWithAlert() -> Bool {
        if hasPermissions() {
            return true
        } else {
            showPermissionsAlert()
            return false
        }
    }
}