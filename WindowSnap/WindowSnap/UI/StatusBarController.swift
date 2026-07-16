import AppKit
import Foundation

class StatusBarController {
    var onShowAccessibilitySetup: (() -> Void)?
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private var preferencesWindow: PreferencesWindow?
    private var textExpanderWindow: TextExpanderWindow?
    
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
        
        // TEXT EXPANDER FEATURE: Quick toggle and settings access
        let textExpanderMenu = NSMenu()
        
        let textExpanderEnabledItem = NSMenuItem(title: "Enabled", action: #selector(toggleTextExpander(_:)), keyEquivalent: "")
        textExpanderEnabledItem.target = self
        textExpanderEnabledItem.state = TextExpanderManager.shared.isEnabled ? .on : .off
        textExpanderMenu.addItem(textExpanderEnabledItem)
        
        textExpanderMenu.addItem(NSMenuItem.separator())
        
        let textExpanderSettingsItem = NSMenuItem(title: "Manage Snippets...", action: #selector(showTextExpanderSettings), keyEquivalent: "")
        textExpanderSettingsItem.target = self
        textExpanderMenu.addItem(textExpanderSettingsItem)
        
        let textExpanderItem = NSMenuItem(title: "Text Expander", action: nil, keyEquivalent: "")
        textExpanderItem.submenu = textExpanderMenu
        menu.addItem(textExpanderItem)

        let clipboardMenu = NSMenu()
        let pauseClipboardItem = NSMenuItem(
            title: "Pause History",
            action: #selector(toggleClipboardHistory(_:)),
            keyEquivalent: ""
        )
        pauseClipboardItem.target = self
        pauseClipboardItem.state = ClipboardManager.shared.isMonitoringPaused ? .on : .off
        pauseClipboardItem.setAccessibilityLabel("Pause clipboard history monitoring")
        clipboardMenu.addItem(pauseClipboardItem)

        let clipboardItem = NSMenuItem(title: "Clipboard History", action: nil, keyEquivalent: "")
        clipboardItem.submenu = clipboardMenu
        menu.addItem(clipboardItem)
        
        // REGION SHARE FEATURE: Screen region sharing for video calls
        if #available(macOS 12.3, *) {
            let regionShareMenu = NSMenu()
            
            let showRegionItem = NSMenuItem(title: "Show Region Share", action: #selector(showRegionShare), keyEquivalent: "")
            showRegionItem.target = self
            regionShareMenu.addItem(showRegionItem)
            
            let newRegionItem = NSMenuItem(title: "Select New Region...", action: #selector(selectNewRegion), keyEquivalent: "")
            newRegionItem.target = self
            regionShareMenu.addItem(newRegionItem)
            
            let regionShareItem = NSMenuItem(title: "Region Share", action: nil, keyEquivalent: "")
            regionShareItem.submenu = regionShareMenu
            menu.addItem(regionShareItem)
        }
        
        // Settings and Info
        let accessibilityItem = NSMenuItem(title: "Accessibility Setup…", action: #selector(showAccessibilitySetup), keyEquivalent: "")
        accessibilityItem.target = self
        menu.addItem(accessibilityItem)

        let preferencesItem = NSMenuItem(title: "Preferences...", action: #selector(showPreferences), keyEquivalent: ",")
        preferencesItem.target = self
        menu.addItem(preferencesItem)
        
        let aboutItem = NSMenuItem(title: "About WindowSnap", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)
        
        menu.addItem(NSMenuItem.separator())
        
        let restartItem = NSMenuItem(title: "Restart WindowSnap", action: #selector(restartApp), keyEquivalent: "")
        restartItem.target = self
        menu.addItem(restartItem)
        
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
        showNotification(title: "Window Snapped", message: "Window moved to \(position.displayName)")
    }
    
    @objc func showPreferences() {
        if preferencesWindow == nil {
            preferencesWindow = PreferencesWindow()
        }
        preferencesWindow?.showWindow(nil)
        preferencesWindow?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func showAccessibilitySetup() {
        onShowAccessibilitySetup?()
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
    
    @objc private func toggleTextExpander(_ sender: NSMenuItem) {
        let newState = !TextExpanderManager.shared.isEnabled
        TextExpanderManager.shared.isEnabled = newState
        sender.state = newState ? .on : .off
        
        if newState {
            if InputMonitoringPermissions.hasPermissions() {
                TextExpansionEngine.shared.start()
            } else {
                InputMonitoringPermissions.showPermissionsAlert()
            }
        } else {
            TextExpansionEngine.shared.stop()
        }
    }

    @objc private func toggleClipboardHistory(_ sender: NSMenuItem) {
        if ClipboardManager.shared.isMonitoringPaused {
            ClipboardManager.shared.resumeMonitoring()
            sender.state = .off
        } else {
            ClipboardManager.shared.pauseMonitoring()
            sender.state = .on
        }
    }
    
    @objc private func showTextExpanderSettings() {
        if textExpanderWindow == nil {
            textExpanderWindow = TextExpanderWindow()
        }
        textExpanderWindow?.showWindow(nil)
        textExpanderWindow?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @available(macOS 12.3, *)
    @objc private func showRegionShare() {
        RegionShareController.shared.showRegionShare()
    }
    
    @available(macOS 12.3, *)
    @objc private func selectNewRegion() {
        RegionShareController.shared.selectNewRegion()
    }
    
    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "WindowSnap"
        alert.informativeText = """
        Version 1.0
        
        A native macOS window management application that allows you to quickly arrange application windows using keyboard shortcuts.
        
        © 2025 WindowSnap. All rights reserved.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    @objc private func restartApp() {
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
    
    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
    
    private func showNotification(title: String, message: String) {
        let notification = NSUserNotification()
        notification.title = title
        notification.informativeText = message
        notification.soundName = nil
        
        let notificationCenter = NSUserNotificationCenter.default
        notificationCenter.deliver(notification)
    }
}
