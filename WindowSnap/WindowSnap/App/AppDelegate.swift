import AppKit
import Foundation

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private var windowManager: WindowManager?
    private var shortcutManager: ShortcutManager?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBarApp()
        requestAccessibilityPermissions()
        initializeManagers()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        shortcutManager?.unregisterAllShortcuts()
    }
    
    private func setupMenuBarApp() {
        NSApp.setActivationPolicy(.accessory)
    }
    
    private func requestAccessibilityPermissions() {
        AccessibilityPermissions.requestPermissionIfNeeded()
    }
    
    private func initializeManagers() {
        windowManager = WindowManager.shared
        shortcutManager = ShortcutManager()
        statusBarController = StatusBarController()
        
        setupDefaultShortcuts()
    }
    
    private func setupDefaultShortcuts() {
        guard let shortcutManager = shortcutManager else { return }
        
        let defaultShortcuts = shortcutManager.getDefaultShortcuts()
        
        for (shortcut, position) in defaultShortcuts {
            let success = shortcutManager.registerGlobalShortcut(shortcut) { [weak self] in
                self?.handleWindowSnap(to: position)
            }
            if !success {
                print("Failed to register shortcut: \(shortcut)")
            }
        }
    }
    
    private func handleWindowSnap(to position: GridPosition) {
        guard let windowManager = windowManager,
              let focusedWindow = windowManager.getFocusedWindow() else {
            return
        }
        
        windowManager.snapWindow(focusedWindow, to: position)
    }
}