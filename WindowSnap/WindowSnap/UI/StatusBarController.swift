import AppKit
import Foundation

class StatusBarController {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private var preferencesWindow: PreferencesWindow?
    
    init() {
        setupStatusBar()
    }
    
    private func setupStatusBar() {
        guard let button = statusItem.button else { return }
        
        // Set the status bar icon (white icons for dark mode visibility)
        let image = NSImage(named: "MenuBarIcon")
        image?.isTemplate = false  // Use white icons directly, not as template
        button.image = image
        button.imageScaling = .scaleProportionallyDown
        
        // Create the menu
        statusItem.menu = createContextMenu()
    }
    
    private func createContextMenu() -> NSMenu {
        let menu = NSMenu()
        
        // Quick Actions
        menu.addItem(NSMenuItem.separator())
        let quickActionsItem = NSMenuItem(title: "Quick Actions", action: nil, keyEquivalent: "")
        quickActionsItem.isEnabled = false
        menu.addItem(quickActionsItem)
        
        // Window positioning actions with keyboard shortcuts
        addQuickAction(to: menu, title: "Left Half", position: .leftHalf, shortcut: "⌘⇧←")
        addQuickAction(to: menu, title: "Right Half", position: .rightHalf, shortcut: "⌘⇧→")
        addQuickAction(to: menu, title: "Top Half", position: .topHalf, shortcut: "⌘⇧↑")
        addQuickAction(to: menu, title: "Bottom Half", position: .bottomHalf, shortcut: "⌘⇧↓")
        
        menu.addItem(NSMenuItem.separator())
        
        addQuickAction(to: menu, title: "Top Left", position: .topLeft, shortcut: "⌘⌥1")
        addQuickAction(to: menu, title: "Top Right", position: .topRight, shortcut: "⌘⌥2")
        addQuickAction(to: menu, title: "Bottom Left", position: .bottomLeft, shortcut: "⌘⌥3")
        addQuickAction(to: menu, title: "Bottom Right", position: .bottomRight, shortcut: "⌘⌥4")
        
        menu.addItem(NSMenuItem.separator())
        
        addQuickAction(to: menu, title: "Left Third", position: .leftThird, shortcut: "⌘⌥←")
        addQuickAction(to: menu, title: "Right Third", position: .rightThird, shortcut: "⌘⌥→")
        addQuickAction(to: menu, title: "Left Two-Thirds", position: .leftTwoThirds, shortcut: "⌘⌥↑")
        addQuickAction(to: menu, title: "Right Two-Thirds", position: .rightTwoThirds, shortcut: "⌘⌥↓")
        
        menu.addItem(NSMenuItem.separator())
        
        addQuickAction(to: menu, title: "Maximize", position: .maximize, shortcut: "⌘⇧M")
        addQuickAction(to: menu, title: "Center", position: .center, shortcut: "⌘⇧C")
        
        menu.addItem(NSMenuItem.separator())
        
        // RECTANGLE PRO FEATURE: Custom Positions
        let customPositionsItem = NSMenuItem(title: "Custom Positions...", action: #selector(showCustomPositions), keyEquivalent: "")
        customPositionsItem.target = self
        menu.addItem(customPositionsItem)
        
        // RECTANGLE PRO FEATURE: Workspace Arrangements
        let workspaceArrangementsItem = NSMenuItem(title: "Workspace Arrangements...", action: #selector(showWorkspaceArrangements), keyEquivalent: "")
        workspaceArrangementsItem.target = self
        menu.addItem(workspaceArrangementsItem)
        
        // Settings and Info
        let shortcutReferenceItem = NSMenuItem(title: "Shortcut Reference...", action: #selector(showShortcutReference), keyEquivalent: "/")
        shortcutReferenceItem.keyEquivalentModifierMask = [.command, .shift]
        shortcutReferenceItem.target = self
        menu.addItem(shortcutReferenceItem)
        
        let preferencesItem = NSMenuItem(title: "Preferences...", action: #selector(showPreferences), keyEquivalent: ",")
        preferencesItem.target = self
        menu.addItem(preferencesItem)
        
        let aboutItem = NSMenuItem(title: "About WindowSnap", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let quitItem = NSMenuItem(title: "Quit WindowSnap", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        return menu
    }
    
    private func addQuickAction(to menu: NSMenu, title: String, position: GridPosition, shortcut: String) {
        // Create menu item with title that shows shortcut in the standard macOS way
        let item = NSMenuItem(title: "\(title) (\(shortcut))", action: #selector(handleQuickAction(_:)), keyEquivalent: "")
        
        item.target = self
        item.representedObject = position
        menu.addItem(item)
    }
    
    @objc private func handleQuickAction(_ sender: NSMenuItem) {
        guard let position = sender.representedObject as? GridPosition else { return }
        
        let windowManager = WindowManager.shared
        
        if !AccessibilityPermissions.hasPermissions() {
            AccessibilityPermissions.showPermissionsAlert()
            return
        }
        
        guard let focusedWindow = windowManager.getFocusedWindow() else {
            showNotification(title: "No Window", message: "No active window found to snap")
            return
        }
        
        windowManager.snapWindow(focusedWindow, to: position)
        // HUD notification is shown by WindowManager.snapWindow
    }
    
    @objc func showPreferences() {
        if preferencesWindow == nil {
            preferencesWindow = PreferencesWindow()
        }
        preferencesWindow?.showWindow(nil)
        preferencesWindow?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func showCustomPositions() {
        let customPositionsWindow = CustomPositionsWindow()
        customPositionsWindow.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func showWorkspaceArrangements() {
        let workspaceWindow = WorkspaceArrangementsWindow()
        workspaceWindow.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @objc private func showAbout() {
        AboutWindow.shared.show()
    }
    
    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
    
    private func showNotification(title: String, message: String) {
        // Use modern HUD notification instead of deprecated NSUserNotification
        SnapHUD.shared.show(title: title, subtitle: message, icon: NSImage(systemSymbolName: "exclamationmark.triangle", accessibilityDescription: "Alert"))
    }
    
    @objc private func showShortcutReference() {
        ShortcutCheatSheet.shared.show()
    }
}