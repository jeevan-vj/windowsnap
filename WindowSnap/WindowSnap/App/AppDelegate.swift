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
        // Only check permissions, don't automatically prompt
        if !AccessibilityPermissions.hasPermissions() {
            print("⚠️ WindowSnap requires accessibility permissions to function properly.")
            print("   You can grant permissions via the menu bar icon -> Preferences")
        }
    }
    
    private func initializeManagers() {
        windowManager = WindowManager.shared
        shortcutManager = ShortcutManager()
        statusBarController = StatusBarController()
        
        setupDefaultShortcuts()
    }
    
    private func setupDefaultShortcuts() {
        guard let shortcutManager = shortcutManager else { return }
        
        // Register window positioning shortcuts
        let defaultShortcuts = shortcutManager.getDefaultShortcuts()
        
        for (shortcut, position) in defaultShortcuts {
            let success = shortcutManager.registerGlobalShortcut(shortcut) { [weak self] in
                self?.handleWindowSnap(to: position)
            }
            if !success {
                print("Failed to register shortcut: \(shortcut)")
            }
        }
        
        // SPECTACLE PRODUCTIVITY: Register undo/redo shortcuts
        let undoRedoShortcuts = shortcutManager.getUndoRedoShortcuts()
        
        for (shortcut, action) in undoRedoShortcuts {
            let success = shortcutManager.registerGlobalShortcut(shortcut, action: action)
            if !success {
                print("Failed to register undo/redo shortcut: \(shortcut)")
            }
        }
        
        // SPECTACLE PRODUCTIVITY: Register display switching shortcuts
        let displayShortcuts = shortcutManager.getDisplaySwitchingShortcuts()
        
        for (shortcut, action) in displayShortcuts {
            let success = shortcutManager.registerGlobalShortcut(shortcut, action: action)
            if !success {
                print("Failed to register display switching shortcut: \(shortcut)")
            }
        }
        
        // SPECTACLE PRODUCTIVITY: Register incremental resizing shortcuts
        let resizingShortcuts = shortcutManager.getIncrementalResizingShortcuts()
        
        for (shortcut, action) in resizingShortcuts {
            let success = shortcutManager.registerGlobalShortcut(shortcut, action: action)
            if !success {
                print("Failed to register incremental resizing shortcut: \(shortcut)")
            }
        }
        
        print("🎯 PRODUCTIVITY SHORTCUTS REGISTERED:")
        print("   ⏪ Undo: ⌘⌥Z")
        print("   ⏩ Redo: ⌘⌥⇧Z")
        print("   🖥️ Next Display: ⌃⌥⌘→")  
        print("   🖥️ Previous Display: ⌃⌥⌘←")
        print("   📏 Make Larger: ⌃⌥⇧→")
        print("   📏 Make Smaller: ⌃⌥⇧←")
    }
    
    private func handleWindowSnap(to position: GridPosition) {
        guard let windowManager = windowManager,
              let focusedWindow = windowManager.getFocusedWindow() else {
            return
        }
        
        windowManager.snapWindow(focusedWindow, to: position)
    }
}