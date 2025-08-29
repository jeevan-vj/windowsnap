import AppKit
import Foundation

class LaunchAtLoginPrompt {
    static let shared = LaunchAtLoginPrompt()
    
    private init() {}
    
    // Show the launch at login prompt if it hasn't been shown before
    func showPromptIfNeeded() {
        let preferences = PreferencesManager.shared
        
        // Don't show if we've already prompted the user
        guard !preferences.hasShownLaunchAtLoginPrompt else { return }
        
        // Don't show if launch at login is already enabled
        guard !LaunchAtLoginManager.shared.isEnabled else {
            preferences.hasShownLaunchAtLoginPrompt = true
            return
        }
        
        // Show the prompt after a short delay to let the app fully load
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.presentPrompt()
        }
    }
    
    private func presentPrompt() {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Start WindowSnap automatically?"
        alert.informativeText = """
        Would you like WindowSnap to start automatically when you log in to your Mac? 
        
        This ensures your window management shortcuts are always available without needing to manually launch the app.
        
        You can change this setting later in Preferences.
        """
        
        // Add buttons
        let enableButton = alert.addButton(withTitle: "Yes, Start Automatically")
        enableButton.keyEquivalent = "\r" // Make it the default button
        
        let disableButton = alert.addButton(withTitle: "No, Don't Auto-Start")
        disableButton.keyEquivalent = "\u{1b}" // Escape key
        
        _ = alert.addButton(withTitle: "Decide Later")
        
        // Set app icon if available
        if let appIcon = NSApp.applicationIconImage {
            alert.icon = appIcon
        }
        
        // Show the alert
        let response = alert.runModal()
        
        // Handle the response
        handlePromptResponse(response)
        
        // Mark that we've shown the prompt
        PreferencesManager.shared.hasShownLaunchAtLoginPrompt = true
    }
    
    private func handlePromptResponse(_ response: NSApplication.ModalResponse) {
        switch response {
        case .alertFirstButtonReturn: // "Yes, Start Automatically"
            enableLaunchAtLogin()
            
        case .alertSecondButtonReturn: // "No, Don't Auto-Start"
            // User explicitly chose not to enable, respect their choice
            showFeedbackMessage("WindowSnap will not start automatically. You can change this in Preferences anytime.")
            
        case .alertThirdButtonReturn: // "Decide Later"
            // User wants to decide later, show how to access preferences
            showPreferencesInfo()
            
        default:
            break
        }
    }
    
    private func enableLaunchAtLogin() {
        do {
            try LaunchAtLoginManager.shared.setEnabled(true)
            showFeedbackMessage("✅ WindowSnap will now start automatically when you log in!")
        } catch {
            showErrorMessage("Failed to enable auto-start: \(error.localizedDescription)")
        }
    }
    
    private func showFeedbackMessage(_ message: String) {
        // Show a temporary notification-style message
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Auto-Start Setting Updated"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        
        // Auto-close after a few seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            alert.runModal()
        }
    }
    
    private func showErrorMessage(_ message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Error"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    private func showPreferencesInfo() {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Access Preferences Anytime"
        alert.informativeText = """
        You can enable or disable auto-start anytime by:
        
        1. Clicking the WindowSnap icon in your menu bar
        2. Selecting "Preferences"
        3. Checking or unchecking "Launch WindowSnap at login"
        """
        alert.addButton(withTitle: "Got It")
        
        _ = alert.addButton(withTitle: "Open Preferences Now")
        
        let response = alert.runModal()
        
        if response == .alertSecondButtonReturn {
            // User wants to open preferences now
            openPreferences()
        }
    }
    
    private func openPreferences() {
        // Post a notification to open preferences
        NotificationCenter.default.post(name: .openPreferences, object: nil)
    }
}

// MARK: - Notification Extension
extension Notification.Name {
    static let openPreferences = Notification.Name("openPreferences")
}
