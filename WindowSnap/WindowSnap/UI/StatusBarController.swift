import AppKit
import Foundation

class StatusBarController: NSObject, NSMenuDelegate {
    var onShowAccessibilitySetup: (() -> Void)?
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private var preferencesWindow: PreferencesWindow?
    private var textExpanderWindow: TextExpanderWindow?
    private var clipboardHistoryWindow: ClipboardHistoryWindow?
    private var customPositionsWindow: CustomPositionsWindow?
    private var workspaceArrangementsWindow: WorkspaceArrangementsWindow?
    private var pauseClipboardMenuItem: NSMenuItem?
    private var clipboardPauseObserver: ClipboardPauseStateObserver?
    private weak var textExpanderEnabledMenuItem: NSMenuItem?
    private var textExpanderStateObserver: NSObjectProtocol?
    private var quickActionItems: [NSMenuItem] = []
    private weak var accessibilitySetupMenuItem: NSMenuItem?

    var menuForTesting: NSMenu? { statusItem.menu }

    override init() {
        super.init()
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
        menu.delegate = self
        quickActionItems.removeAll()

        addQuickAction(to: menu, title: "Left Half", position: .leftHalf, key: "\u{F702}", modifiers: [.command, .shift])
        addQuickAction(to: menu, title: "Right Half", position: .rightHalf, key: "\u{F703}", modifiers: [.command, .shift])
        addQuickAction(to: menu, title: "Maximize", position: .maximize, key: "m", modifiers: [.command, .shift])
        addQuickAction(to: menu, title: "Center", position: .center, key: "c", modifiers: [.command, .shift])

        let morePositionsMenu = NSMenu()
        addQuickAction(to: morePositionsMenu, title: "Top Half", position: .topHalf, key: "\u{F700}", modifiers: [.command, .shift])
        addQuickAction(to: morePositionsMenu, title: "Bottom Half", position: .bottomHalf, key: "\u{F701}", modifiers: [.command, .shift])
        morePositionsMenu.addItem(.separator())
        addQuickAction(to: morePositionsMenu, title: "Top Left", position: .topLeft, key: "1", modifiers: [.command, .option])
        addQuickAction(to: morePositionsMenu, title: "Top Right", position: .topRight, key: "2", modifiers: [.command, .option])
        addQuickAction(to: morePositionsMenu, title: "Bottom Left", position: .bottomLeft, key: "3", modifiers: [.command, .option])
        addQuickAction(to: morePositionsMenu, title: "Bottom Right", position: .bottomRight, key: "4", modifiers: [.command, .option])
        morePositionsMenu.addItem(.separator())
        addQuickAction(to: morePositionsMenu, title: "Left Third", position: .leftThird, key: "\u{F702}", modifiers: [.command, .option])
        addQuickAction(to: morePositionsMenu, title: "Right Third", position: .rightThird, key: "\u{F703}", modifiers: [.command, .option])
        addQuickAction(to: morePositionsMenu, title: "Left Two-Thirds", position: .leftTwoThirds, key: "\u{F700}", modifiers: [.command, .option])
        addQuickAction(to: morePositionsMenu, title: "Right Two-Thirds", position: .rightTwoThirds, key: "\u{F701}", modifiers: [.command, .option])
        let morePositionsItem = NSMenuItem(title: "More Positions", action: nil, keyEquivalent: "")
        morePositionsItem.submenu = morePositionsMenu
        menu.addItem(morePositionsItem)

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

        let textExpanderEnabledItem = NSMenuItem(title: "Enable Text Expander", action: #selector(toggleTextExpander(_:)), keyEquivalent: "")
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
        let showClipboardItem = NSMenuItem(
            title: "Show Clipboard History",
            action: #selector(showClipboardHistory),
            keyEquivalent: "v"
        )
        showClipboardItem.keyEquivalentModifierMask = [.command, .shift]
        showClipboardItem.target = self
        clipboardMenu.addItem(showClipboardItem)
        clipboardMenu.addItem(.separator())

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

        menu.addItem(NSMenuItem.separator())

        let accessibilityItem = NSMenuItem(title: "Set Up Accessibility…", action: #selector(showAccessibilitySetup), keyEquivalent: "")
        accessibilityItem.target = self
        menu.addItem(accessibilityItem)
        accessibilitySetupMenuItem = accessibilityItem

        let preferencesItem = NSMenuItem(title: "Settings…", action: #selector(showPreferences), keyEquivalent: ",")
        preferencesItem.target = self
        menu.addItem(preferencesItem)

        let aboutItem = NSMenuItem(title: "About WindowSnap", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit WindowSnap", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        refreshPermissionState()
        updateTextExpanderMenuItem(for: TextExpanderRuntimeController.shared.state)
        return menu
    }

    private func addQuickAction(
        to menu: NSMenu,
        title: String,
        position: GridPosition,
        key: String,
        modifiers: NSEvent.ModifierFlags
    ) {
        let item = NSMenuItem(title: title, action: #selector(handleQuickAction(_:)), keyEquivalent: key)
        item.target = self
        item.keyEquivalentModifierMask = modifiers
        item.representedObject = position
        menu.addItem(item)
        quickActionItems.append(item)
    }

    @objc private func handleQuickAction(_ sender: NSMenuItem) {
        guard let position = sender.representedObject as? GridPosition else { return }

        let windowManager = WindowManager.shared

        guard AccessibilityPermissions.hasPermissions() else { return }

        guard let focusedWindow = windowManager.getFocusedWindow() else {
            NSSound.beep()
            return
        }

        windowManager.snapWindow(focusedWindow, to: position)
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
        if case .needsPermission = state {
            InputMonitoringPermissions.showSetupAlert()
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

    @objc private func showClipboardHistory() {
        if clipboardHistoryWindow == nil {
            clipboardHistoryWindow = ClipboardHistoryWindow()
        }
        if clipboardHistoryWindow?.isVisible == true {
            clipboardHistoryWindow?.requestClose()
        } else {
            clipboardHistoryWindow?.showWindow()
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
        switch state {
        case .running:
            textExpanderEnabledMenuItem?.title = "Disable Text Expander"
            textExpanderEnabledMenuItem?.state = .on
        case .needsPermission:
            textExpanderEnabledMenuItem?.title = "Set Up Text Expander…"
            textExpanderEnabledMenuItem?.state = .off
        case .disabled:
            textExpanderEnabledMenuItem?.title = "Enable Text Expander"
            textExpanderEnabledMenuItem?.state = .off
        }
        textExpanderEnabledMenuItem?.toolTip = state.statusText
    }

    func menuWillOpen(_ menu: NSMenu) {
        refreshPermissionState()
        updateTextExpanderMenuItem(for: TextExpanderRuntimeController.shared.state)
    }

    func refreshPermissionState() {
        let granted = AccessibilityPermissions.hasPermissions()
        quickActionItems.forEach { $0.isEnabled = granted }
        accessibilitySetupMenuItem?.isHidden = granted
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

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

}
