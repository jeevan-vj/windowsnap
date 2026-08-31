import AppKit
import Foundation

class StatusBarController {
    var onShowAccessibilitySetup: (() -> Void)?
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private var preferencesWindow: PreferencesWindow?
    private var textExpanderWindow: TextExpanderWindow?
    private var customPositionsWindow: CustomPositionsWindow?
    private var workspaceArrangementsWindow: WorkspaceArrangementsWindow?
    private var pauseClipboardMenuItem: NSMenuItem?
    private var clipboardPauseObserver: ClipboardPauseStateObserver?
    private weak var textExpanderEnabledMenuItem: NSMenuItem?
    private var textExpanderStateObserver: NSObjectProtocol?

    init() {
        setupStatusBar()
        observeClipboardPauseState()
        observeTextExpanderState()
    }

    private func setupStatusBar() {
        guard let button = statusItem.button else { return }

        button.image = makeMenuBarIcon()
        button.imageScaling = .scaleProportionallyDown

        // Create the menu
        statusItem.menu = createContextMenu()
    }

    private func makeMenuBarIcon() -> NSImage? {
        let image = NSImage(named: "MenuBarIcon")
            ?? NSImage(systemSymbolName: "rectangle.3.group", accessibilityDescription: "WindowSnap")
            ?? NSImage(systemSymbolName: "rectangle.on.rectangle", accessibilityDescription: "WindowSnap")
        image?.isTemplate = true
        return image
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
        let customPositionsItem = NSMenuItem(title: "Custom Positions…", action: #selector(showCustomPositions), keyEquivalent: "")
        customPositionsItem.target = self
        menu.addItem(customPositionsItem)

        // RECTANGLE PRO FEATURE: Workspace Arrangements
        let workspaceArrangementsItem = NSMenuItem(title: "Workspace Arrangements…", action: #selector(showWorkspaceArrangements), keyEquivalent: "")
        workspaceArrangementsItem.target = self
        menu.addItem(workspaceArrangementsItem)

        // TEXT EXPANDER FEATURE: Quick toggle and settings access
        let textExpanderMenu = NSMenu()

        let textExpanderEnabledItem = NSMenuItem(title: "Enabled", action: #selector(toggleTextExpander(_:)), keyEquivalent: "")
        textExpanderEnabledItem.target = self
        textExpanderEnabledItem.state = TextExpanderManager.shared.isEnabled ? .on : .off
        textExpanderMenu.addItem(textExpanderEnabledItem)
        self.textExpanderEnabledMenuItem = textExpanderEnabledItem

        textExpanderMenu.addItem(NSMenuItem.separator())

        let textExpanderSettingsItem = NSMenuItem(title: "Manage Snippets…", action: #selector(showTextExpanderSettings), keyEquivalent: "")
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
        self.pauseClipboardMenuItem = pauseClipboardItem

        let clipboardItem = NSMenuItem(title: "Clipboard History", action: nil, keyEquivalent: "")
        clipboardItem.submenu = clipboardMenu
        menu.addItem(clipboardItem)

        // REGION SHARE FEATURE: Screen region sharing for video calls
        let regionShareMenu = NSMenu()

        let showRegionItem = NSMenuItem(title: "Show Region Share", action: #selector(showRegionShare), keyEquivalent: "")
        showRegionItem.target = self
        regionShareMenu.addItem(showRegionItem)

        let showVirtualDisplayItem = NSMenuItem(title: "Show Virtual Display Window", action: #selector(showVirtualDisplayShare), keyEquivalent: "")
        showVirtualDisplayItem.target = self
        showVirtualDisplayItem.toolTip = "Open the selected region as a stable window for Zoom, Meet, Teams, and other screen sharing pickers"
        regionShareMenu.addItem(showVirtualDisplayItem)

        let enableVirtualCameraItem = NSMenuItem(title: "Enable WindowSnap Virtual Camera", action: #selector(enableVirtualCameraShare), keyEquivalent: "")
        enableVirtualCameraItem.target = self
        enableVirtualCameraItem.toolTip = "Install or activate the WindowSnap Virtual Camera and stream the selected region to it"
        regionShareMenu.addItem(enableVirtualCameraItem)

        let newRegionItem = NSMenuItem(title: "Select New Region…", action: #selector(selectNewRegion), keyEquivalent: "")
        newRegionItem.target = self
        regionShareMenu.addItem(newRegionItem)

        regionShareMenu.addItem(NSMenuItem.separator())

        let helpItem = NSMenuItem(title: "How to Share…", action: #selector(showRegionShareHelp), keyEquivalent: "")
        helpItem.target = self
        regionShareMenu.addItem(helpItem)

        let regionShareItem = NSMenuItem(title: "Region Share", action: nil, keyEquivalent: "")
        regionShareItem.submenu = regionShareMenu
        menu.addItem(regionShareItem)

        // Settings and Info
        let accessibilityItem = NSMenuItem(title: "Accessibility Setup…", action: #selector(showAccessibilitySetup), keyEquivalent: "")
        accessibilityItem.target = self
        menu.addItem(accessibilityItem)

        let preferencesItem = NSMenuItem(title: "Preferences…", action: #selector(showPreferences), keyEquivalent: ",")
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
        if customPositionsWindow == nil { customPositionsWindow = CustomPositionsWindow() }
        customPositionsWindow?.showWindow(nil)
        customPositionsWindow?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func showWorkspaceArrangements() {
        if workspaceArrangementsWindow == nil { workspaceArrangementsWindow = WorkspaceArrangementsWindow() }
        workspaceArrangementsWindow?.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func toggleTextExpander(_ sender: NSMenuItem) {
        let newState = !TextExpanderManager.shared.isEnabled
        let state = TextExpanderRuntimeController.shared.setDesiredEnabled(newState)
        updateTextExpanderMenuItem(for: state)
        if state == .permissionRequired {
            InputMonitoringPermissions.showPermissionsAlert()
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

    private func observeClipboardPauseState() {
        clipboardPauseObserver = ClipboardPauseStateObserver { [weak self] isPaused in
            let update: () -> Void = { self?.pauseClipboardMenuItem?.state = isPaused ? .on : .off }
            if Thread.isMainThread { update() } else { DispatchQueue.main.async(execute: update) }
        }
    }

    private func observeTextExpanderState() {
        textExpanderStateObserver = NotificationCenter.default.addObserver(
            forName: .textExpanderRuntimeStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateTextExpanderMenuItem(for: TextExpanderRuntimeController.shared.state)
        }
    }

    private func updateTextExpanderMenuItem(for state: TextExpanderRuntimeState) {
        textExpanderEnabledMenuItem?.state = state == .disabled ? .off : .on
        textExpanderEnabledMenuItem?.toolTip = state.statusText
    }

    @objc private func showTextExpanderSettings() {
        if textExpanderWindow == nil {
            textExpanderWindow = TextExpanderWindow()
        }
        textExpanderWindow?.showWindow(nil)
        textExpanderWindow?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func showRegionShare() {
        RegionShareController.shared.showRegionShare()
    }

    @objc private func showVirtualDisplayShare() {
        RegionShareController.shared.showVirtualDisplayShare()
    }

    @objc private func enableVirtualCameraShare() {
        RegionShareController.shared.enableVirtualCameraShare()
    }

    @objc private func selectNewRegion() {
        RegionShareController.shared.selectNewRegion()
    }

    @objc private func showRegionShareHelp() {
        let alert = NSAlert()
        alert.messageText = "Share WindowSnap Virtual Display"
        alert.informativeText = "Choose Region Share > Show Virtual Display Window, then pick the window named “WindowSnap Virtual Display” in your video app's window sharing picker."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "WindowSnap"
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        let year = Calendar.current.component(.year, from: Date())
        alert.informativeText = """
        Version \(version)

        A native macOS window management application that allows you to quickly arrange application windows using keyboard shortcuts.

        © \(year) WindowSnap. All rights reserved.
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
        guard PreferencesManager.shared.showNotifications else { return }
        let notification = NSUserNotification()
        notification.title = title
        notification.informativeText = message
        notification.soundName = nil

        let notificationCenter = NSUserNotificationCenter.default
        notificationCenter.deliver(notification)
    }
}
