import Foundation
import AppKit
import ScreenCaptureKit

class ScreenRecordingPermissions {
    
    private static var hasShownRestartAlert = false
    
    static func hasPermissions() -> Bool {
        let hasAccess = CGPreflightScreenCaptureAccess()
        print("🔍 Screen recording permission check: \(hasAccess)")
        return hasAccess
    }
    
    static func requestPermissions() -> Bool {
        let granted = CGRequestScreenCaptureAccess()
        print("📋 Screen recording permission requested, granted: \(granted)")
        return granted
    }
    
    static func checkPermissionsAsync(completion: @escaping (Bool) -> Void) {
        Task {
            do {
                _ = try await SCShareableContent.current
                await MainActor.run {
                    print("✅ Screen recording permission verified via ScreenCaptureKit")
                    completion(true)
                }
            } catch {
                await MainActor.run {
                    print("❌ Screen recording permission check failed: \(error)")
                    completion(false)
                }
            }
        }
    }
    
    static func showPermissionsAlert(completion: (() -> Void)? = nil) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Screen Recording Permission Required"
            alert.informativeText = """
            WindowSnap needs screen recording permission to capture and share screen regions.
            
            After clicking "Request Permission":
            1. If a system dialog appears, click "Open System Settings"
            2. Find WindowSnap in the list and enable the toggle
            3. You may need to restart WindowSnap after granting permission
            
            If WindowSnap doesn't appear in the list, try clicking "Request Permission" again.
            """
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Request Permission")
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Cancel")
            
            let response = alert.runModal()
            
            if response == .alertFirstButtonReturn {
                let granted = requestPermissions()
                if !granted {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        openScreenRecordingSettings()
                    }
                }
            } else if response == .alertSecondButtonReturn {
                openScreenRecordingSettings()
            }
            
            completion?()
        }
    }
    
    static func showRestartRequiredAlert() {
        guard !hasShownRestartAlert else { return }
        hasShownRestartAlert = true
        
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Restart Required"
            alert.informativeText = """
            Screen recording permission has been granted in System Settings, but macOS requires WindowSnap to restart for the permission to take effect.
            
            Would you like to restart WindowSnap now?
            """
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Restart Now")
            alert.addButton(withTitle: "Later")
            
            let response = alert.runModal()
            
            if response == .alertFirstButtonReturn {
                restartApp()
            }
        }
    }
    
    private static func restartApp() {
        let url = URL(fileURLWithPath: Bundle.main.resourcePath!)
        let path = url.deletingLastPathComponent().deletingLastPathComponent().absoluteString
        let task = Process()
        task.launchPath = "/usr/bin/open"
        task.arguments = [path]
        task.launch()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSApp.terminate(nil)
        }
    }
    
    static func openScreenRecordingSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
        NSWorkspace.shared.open(url)
    }
    
    static func checkPermissionsWithAlert(completion: @escaping (Bool) -> Void) {
        if hasPermissions() {
            completion(true)
            return
        }
        
        checkPermissionsAsync { hasAccessViaSCK in
            if hasAccessViaSCK {
                showRestartRequiredAlert()
                completion(false)
                return
            }
            
            let granted = requestPermissions()
            
            if granted {
                completion(true)
            } else {
                showPermissionsAlert {
                    checkPermissionsAsync { finalCheck in
                        if finalCheck && !hasPermissions() {
                            showRestartRequiredAlert()
                            completion(false)
                        } else {
                            completion(hasPermissions())
                        }
                    }
                }
            }
        }
    }
    
    static func ensurePermissionRegistered() {
        if !hasPermissions() {
            _ = requestPermissions()
        }
    }
    
    static func checkPermissionStatusOnLaunch() {
        let preflightResult = CGPreflightScreenCaptureAccess()
        print("🚀 Startup screen recording check (CGPreflight): \(preflightResult)")
        
        if preflightResult {
            print("✅ Screen recording permission is active")
            return
        }
        
        checkPermissionsAsync { hasAccessViaSCK in
            print("🚀 Startup screen recording check (SCK): \(hasAccessViaSCK)")
            
            if hasAccessViaSCK && !preflightResult {
                print("⚠️ Permission granted in System Settings but app needs restart")
                showRestartRequiredAlert()
            }
        }
    }
}
