import AppKit
import Foundation

private final class TopAlignedDocumentView: NSView {
    override var isFlipped: Bool { true }
}

class PreferencesWindow: NSWindowController {

    private var textExpanderWindow: TextExpanderWindow?
    private weak var clipboardPauseCheckbox: NSButton?
    private var clipboardPauseObserver: ClipboardPauseStateObserver?
    private weak var launchAtLoginCheckbox: NSButton?
    private weak var launchAtLoginStatusLabel: NSTextField?
    private weak var virtualCameraStatusLabel: NSTextField?
    private weak var screenRecordingStatusLabel: NSTextField?
    private weak var selectedRegionLabel: NSTextField?
    private weak var accessibilityStatusLabel: NSTextField?
    private weak var inputMonitoringStatusLabel: NSTextField?
    private weak var textExpanderEnabledCheckbox: NSButton?
    private weak var accessibilitySettingsButton: NSButton?
    private weak var inputMonitoringButton: NSButton?

    override init(window: NSWindow?) {
        super.init(window: window)
        setupWindow()
        observeClipboardPauseState()
    }

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        self.init(window: window)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupWindow()
        observeClipboardPauseState()
    }

    private func setupWindow() {
        guard let window = window else { return }

        window.title = "WindowSnap Preferences"
        window.center()
        window.isRestorable = false
        window.minSize = NSSize(width: 500, height: 400)

        setupContentView()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        refreshLaunchAtLoginControl()
        refreshRegionShareControls()
        refreshPermissionControls()
    }

    private func setupContentView() {
        guard let window = window else { return }

        let contentView = NSView(frame: window.contentRect(forFrameRect: window.frame))
        window.contentView = contentView

        // Create tab view
        let tabView = NSTabView(frame: contentView.bounds)
        tabView.autoresizingMask = [.width, .height]
        contentView.addSubview(tabView)

        // General tab
        let generalTab = NSTabViewItem(identifier: "general")
        generalTab.label = "General"
        generalTab.view = createGeneralTab()
        tabView.addTabViewItem(generalTab)

        // Shortcuts tab
        let shortcutsTab = NSTabViewItem(identifier: "shortcuts")
        shortcutsTab.label = "Shortcuts"
        shortcutsTab.view = createShortcutsTab()
        tabView.addTabViewItem(shortcutsTab)

        let clipboardTab = NSTabViewItem(identifier: "clipboard")
        clipboardTab.label = "Clipboard"
        clipboardTab.view = createClipboardTab()
        tabView.addTabViewItem(clipboardTab)

        // Text Expander tab
        let textExpanderTab = NSTabViewItem(identifier: "textexpander")
        textExpanderTab.label = "Text Expander"
        textExpanderTab.view = createTextExpanderTab()
        tabView.addTabViewItem(textExpanderTab)

        let regionShareTab = NSTabViewItem(identifier: "regionshare")
        regionShareTab.label = "Region Share"
        regionShareTab.view = createRegionShareTab()
        tabView.addTabViewItem(regionShareTab)
    }

    private func createGeneralTab() -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 350))

        var yPos: CGFloat = 300

        // Title
        let titleLabel = NSTextField(labelWithString: "General Settings")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 16)
        titleLabel.frame = NSRect(x: 20, y: yPos, width: 440, height: 25)
        view.addSubview(titleLabel)
        yPos -= 40

        // Launch at login checkbox
        let launchAtLoginCheckbox = NSButton(checkboxWithTitle: "Launch WindowSnap at login", target: self, action: #selector(toggleLaunchAtLogin(_:)))
        launchAtLoginCheckbox.frame = NSRect(x: 20, y: yPos, width: 300, height: 25)
        launchAtLoginCheckbox.state = getLaunchAtLoginState()
        view.addSubview(launchAtLoginCheckbox)
        self.launchAtLoginCheckbox = launchAtLoginCheckbox
        yPos -= 22

        let launchAtLoginStatusLabel = NSTextField(wrappingLabelWithString: "")
        launchAtLoginStatusLabel.frame = NSRect(x: 40, y: yPos - 28, width: 410, height: 32)
        launchAtLoginStatusLabel.font = NSFont.systemFont(ofSize: 11)
        launchAtLoginStatusLabel.textColor = .secondaryLabelColor
        view.addSubview(launchAtLoginStatusLabel)
        self.launchAtLoginStatusLabel = launchAtLoginStatusLabel
        updateLaunchAtLoginControl(for: LaunchAtLoginManager.shared.refreshStatus())
        yPos -= 48

        // Show notifications checkbox
        let showNotificationsCheckbox = NSButton(checkboxWithTitle: "Show notifications when windows are snapped", target: self, action: #selector(toggleNotifications(_:)))
        showNotificationsCheckbox.frame = NSRect(x: 20, y: yPos, width: 400, height: 25)
        showNotificationsCheckbox.state = getNotificationsState()
        view.addSubview(showNotificationsCheckbox)
        yPos -= 40

        // Accessibility permissions info
        let accessibilityLabel = NSTextField(labelWithString: "Accessibility Permissions:")
        accessibilityLabel.font = NSFont.boldSystemFont(ofSize: 13)
        accessibilityLabel.frame = NSRect(x: 20, y: yPos, width: 200, height: 20)
        view.addSubview(accessibilityLabel)
        yPos -= 25

        let permissionStatus = AccessibilityPermissions.hasPermissions() ? "✓ Granted" : "✗ Not Granted"
        let statusLabel = NSTextField(labelWithString: permissionStatus)
        statusLabel.textColor = AccessibilityPermissions.hasPermissions() ? .systemGreen : .systemRed
        statusLabel.frame = NSRect(x: 40, y: yPos, width: 150, height: 20)
        view.addSubview(statusLabel)
        accessibilityStatusLabel = statusLabel

        let openSettingsButton = NSButton(title: "Open System Settings", target: self, action: #selector(openAccessibilitySettings))
        openSettingsButton.frame = NSRect(x: 200, y: yPos - 5, width: 200, height: 30)
        openSettingsButton.isHidden = AccessibilityPermissions.hasPermissions()
        view.addSubview(openSettingsButton)
        accessibilitySettingsButton = openSettingsButton

        return view
    }

    private func createShortcutsTab() -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 350))

        var yPos: CGFloat = 320

        // Title
        let titleLabel = NSTextField(labelWithString: "Keyboard Shortcuts")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 16)
        titleLabel.frame = NSRect(x: 20, y: yPos, width: 440, height: 25)
        view.addSubview(titleLabel)
        yPos -= 30

        // Description
        let descriptionLabel = NSTextField(wrappingLabelWithString: "Default keyboard shortcuts for window positioning. These shortcuts are automatically registered when WindowSnap starts.")
        descriptionLabel.frame = NSRect(x: 20, y: yPos - 40, width: 440, height: 40)
        view.addSubview(descriptionLabel)
        yPos -= 70

        // Shortcuts list
        let shortcuts = ShortcutManager().getDefaultShortcuts()
        let scrollView = NSScrollView(frame: NSRect(x: 20, y: 15, width: 440, height: 200))
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder
        scrollView.autoresizingMask = [.width, .height]
        let listHeight = CGFloat(shortcuts.count * 25 + 16)
        let listView = TopAlignedDocumentView(frame: NSRect(x: 0, y: 0, width: 420, height: listHeight))
        listView.autoresizingMask = .width
        var rowY: CGFloat = 8

        for (shortcut, position) in shortcuts.sorted(by: { $0.value.rawValue < $1.value.rawValue }) {
            let shortcutLabel = NSTextField(labelWithString: shortcut.uppercased())
            shortcutLabel.frame = NSRect(x: 12, y: rowY, width: 150, height: 20)
            shortcutLabel.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)
            listView.addSubview(shortcutLabel)

            let actionLabel = NSTextField(labelWithString: position.displayName)
            actionLabel.frame = NSRect(x: 172, y: rowY, width: 230, height: 20)
            listView.addSubview(actionLabel)

            rowY += 25
        }
        scrollView.documentView = listView
        view.addSubview(scrollView)

        return view
    }

    private func createClipboardTab() -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 350))
        var yPos: CGFloat = 305

        let titleLabel = NSTextField(labelWithString: "Clipboard History & Privacy")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 16)
        titleLabel.frame = NSRect(x: 20, y: yPos, width: 440, height: 25)
        view.addSubview(titleLabel)
        yPos -= 50

        let localOnlyLabel = NSTextField(wrappingLabelWithString: "Clipboard history stays on this Mac and is never uploaded. Items marked private by password managers are not recorded, and sensitive-data filtering is always on.")
        localOnlyLabel.frame = NSRect(x: 20, y: yPos - 48, width: 440, height: 55)
        localOnlyLabel.textColor = .secondaryLabelColor
        view.addSubview(localOnlyLabel)
        yPos -= 80

        let retentionLabel = NSTextField(labelWithString: "Keep unpinned history:")
        retentionLabel.frame = NSRect(x: 20, y: yPos, width: 165, height: 24)
        view.addSubview(retentionLabel)

        let retentionPopup = NSPopUpButton(frame: NSRect(x: 190, y: yPos - 4, width: 150, height: 28))
        for option in ClipboardHistoryRetention.allCases {
            retentionPopup.addItem(withTitle: option.displayName)
            retentionPopup.lastItem?.representedObject = option.rawValue
        }
        if let selectedIndex = ClipboardHistoryRetention.allCases.firstIndex(of: ClipboardManager.shared.retention) {
            retentionPopup.selectItem(at: selectedIndex)
        }
        retentionPopup.target = self
        retentionPopup.action = #selector(changeClipboardRetention(_:))
        retentionPopup.setAccessibilityLabel("Clipboard history retention")
        view.addSubview(retentionPopup)
        yPos -= 55

        let pauseCheckbox = NSButton(
            checkboxWithTitle: "Pause clipboard history monitoring",
            target: self,
            action: #selector(toggleClipboardMonitoring(_:))
        )
        pauseCheckbox.frame = NSRect(x: 20, y: yPos, width: 310, height: 25)
        pauseCheckbox.state = ClipboardManager.shared.isMonitoringPaused ? .on : .off
        pauseCheckbox.setAccessibilityLabel("Pause clipboard history monitoring")
        view.addSubview(pauseCheckbox)
        clipboardPauseCheckbox = pauseCheckbox
        yPos -= 55

        let clearButton = NSButton(
            title: "Clear All History…",
            target: self,
            action: #selector(clearClipboardHistory(_:))
        )
        clearButton.frame = NSRect(x: 20, y: yPos, width: 160, height: 30)
        clearButton.setAccessibilityLabel("Clear all clipboard history")
        view.addSubview(clearButton)

        let pinnedLabel = NSTextField(wrappingLabelWithString: "Pinned items do not expire automatically. Clear All removes pinned items too.")
        pinnedLabel.frame = NSRect(x: 195, y: yPos - 5, width: 265, height: 40)
        pinnedLabel.textColor = .secondaryLabelColor
        pinnedLabel.font = NSFont.systemFont(ofSize: 11)
        view.addSubview(pinnedLabel)

        return view
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSButton) {
        let enable = sender.state == .on

        do {
            try LaunchAtLoginManager.shared.setEnabled(enable)
            updateLaunchAtLoginControl(for: LaunchAtLoginManager.shared.refreshStatus())
        } catch {
            // Show error alert if setting failed
            let alert = NSAlert()
            alert.messageText = "Failed to update launch at login setting"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open Login Items Settings")
            alert.addButton(withTitle: "Cancel")
            if alert.runModal() == .alertFirstButtonReturn {
                openLoginItemsSettings()
            }

            refreshLaunchAtLoginControl()
        }
    }

    @objc private func toggleNotifications(_ sender: NSButton) {
        let enable = sender.state == .on
        UserDefaults.standard.set(enable, forKey: "ShowNotifications")
    }

    @objc private func openAccessibilitySettings() {
        AccessibilityPermissions.openSecurityPreferences()
    }

    @objc private func changeClipboardRetention(_ sender: NSPopUpButton) {
        guard let rawValue = sender.selectedItem?.representedObject as? String,
              let retention = ClipboardHistoryRetention(rawValue: rawValue) else { return }
        ClipboardManager.shared.retention = retention
    }

    @objc private func toggleClipboardMonitoring(_ sender: NSButton) {
        if sender.state == .on {
            ClipboardManager.shared.pauseMonitoring()
        } else {
            ClipboardManager.shared.resumeMonitoring()
        }
    }

    private func observeClipboardPauseState() {
        clipboardPauseObserver = ClipboardPauseStateObserver { [weak self] isPaused in
            let update: () -> Void = { self?.clipboardPauseCheckbox?.state = isPaused ? .on : .off }
            if Thread.isMainThread { update() } else { DispatchQueue.main.async(execute: update) }
        }
    }

    @objc private func clearClipboardHistory(_ sender: NSButton) {
        let alert = NSAlert()
        alert.messageText = "Clear Clipboard History"
        alert.informativeText = "Remove all clipboard history from memory and this Mac? This includes pinned items and cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear All")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            ClipboardManager.shared.clearHistory()
        }
    }

    private func getLaunchAtLoginState() -> NSControl.StateValue {
        return LaunchAtLoginManager.shared.isEnabled ? .on : .off
    }

    @objc private func applicationDidBecomeActive() {
        guard window?.isVisible == true else { return }
        refreshLaunchAtLoginControl()
        refreshRegionShareControls()
        refreshPermissionControls()
    }

    private func refreshLaunchAtLoginControl() {
        updateLaunchAtLoginControl(for: LaunchAtLoginManager.shared.refreshStatus())
    }

    private func updateLaunchAtLoginControl(for status: LaunchAtLoginSystemStatus) {
        launchAtLoginCheckbox?.state = status.isEnabled ? .on : .off

        switch status {
        case .enabled, .disabled:
            launchAtLoginStatusLabel?.stringValue = ""
        case .requiresApproval:
            launchAtLoginStatusLabel?.stringValue = "Approval required in System Settings > General > Login Items."
        case .notFound:
            launchAtLoginStatusLabel?.stringValue = "Move WindowSnap to Applications, reopen it, and try again."
        case .unknown:
            launchAtLoginStatusLabel?.stringValue = "Login item status is unavailable. Reopen System Settings and try again."
        }
    }

    private func openLoginItemsSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") else { return }
        NSWorkspace.shared.open(url)
    }

    private func getNotificationsState() -> NSControl.StateValue {
        return UserDefaults.standard.bool(forKey: "ShowNotifications") ? .on : .off
    }

    private func createTextExpanderTab() -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 350))

        var yPos: CGFloat = 300

        let titleLabel = NSTextField(labelWithString: "Text Expander Settings")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 16)
        titleLabel.frame = NSRect(x: 20, y: yPos, width: 440, height: 25)
        view.addSubview(titleLabel)
        yPos -= 40

        let enabledCheckbox = NSButton(checkboxWithTitle: "Enable Text Expander", target: self, action: #selector(toggleTextExpander(_:)))
        enabledCheckbox.frame = NSRect(x: 20, y: yPos, width: 300, height: 25)
        enabledCheckbox.state = TextExpanderManager.shared.isEnabled ? .on : .off
        view.addSubview(enabledCheckbox)
        textExpanderEnabledCheckbox = enabledCheckbox
        yPos -= 35

        let descriptionLabel = NSTextField(wrappingLabelWithString: "Type a trigger phrase (e.g., ':email') and press Tab to automatically expand it to the configured replacement text.")
        descriptionLabel.frame = NSRect(x: 40, y: yPos - 30, width: 400, height: 40)
        descriptionLabel.textColor = .secondaryLabelColor
        view.addSubview(descriptionLabel)
        yPos -= 60

        let permissionLabel = NSTextField(labelWithString: "Input Monitoring Permission:")
        permissionLabel.font = NSFont.boldSystemFont(ofSize: 13)
        permissionLabel.frame = NSRect(x: 20, y: yPos, width: 250, height: 20)
        view.addSubview(permissionLabel)
        yPos -= 25

        let hasPermission = InputMonitoringPermissions.hasPermissions()
        let permissionStatus = hasPermission ? "✓ Granted" : "✗ Not Granted"
        let statusLabel = NSTextField(labelWithString: permissionStatus)
        statusLabel.textColor = hasPermission ? .systemGreen : .systemRed
        statusLabel.frame = NSRect(x: 40, y: yPos, width: 150, height: 20)
        view.addSubview(statusLabel)
        inputMonitoringStatusLabel = statusLabel

        let openSettingsButton = NSButton(title: "Grant Permission", target: self, action: #selector(openInputMonitoringSettings))
        openSettingsButton.frame = NSRect(x: 200, y: yPos - 5, width: 150, height: 30)
        openSettingsButton.isHidden = hasPermission
        view.addSubview(openSettingsButton)
        inputMonitoringButton = openSettingsButton
        yPos -= 45

        let snippetsLabel = NSTextField(labelWithString: "Snippets:")
        snippetsLabel.font = NSFont.boldSystemFont(ofSize: 13)
        snippetsLabel.frame = NSRect(x: 20, y: yPos, width: 100, height: 20)
        view.addSubview(snippetsLabel)

        let snippetCount = TextExpanderManager.shared.getAllSnippets().count
        let countLabel = NSTextField(labelWithString: "\(snippetCount) snippet\(snippetCount == 1 ? "" : "s") configured")
        countLabel.frame = NSRect(x: 130, y: yPos, width: 200, height: 20)
        countLabel.textColor = .secondaryLabelColor
        view.addSubview(countLabel)
        yPos -= 35

        let manageButton = NSButton(title: "Manage Snippets…", target: self, action: #selector(openTextExpanderWindow))
        manageButton.frame = NSRect(x: 40, y: yPos, width: 150, height: 30)
        view.addSubview(manageButton)
        yPos -= 45

        let stats = TextExpanderManager.shared.getUsageStats()
        let statsLabel = NSTextField(wrappingLabelWithString: "Usage: \(stats.expansionCount) expansions • \(stats.charactersSaved) characters saved • \(stats.timeSavedEstimate())")
        statsLabel.frame = NSRect(x: 40, y: yPos - 20, width: 400, height: 40)
        statsLabel.textColor = .secondaryLabelColor
        statsLabel.font = NSFont.systemFont(ofSize: 12)
        view.addSubview(statsLabel)

        return view
    }

    private func createRegionShareTab() -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 480, height: 350))
        var yPos: CGFloat = 300

        let titleLabel = NSTextField(labelWithString: "Region Share")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 16)
        titleLabel.frame = NSRect(x: 20, y: yPos, width: 440, height: 25)
        view.addSubview(titleLabel)
        yPos -= 45

        let screenRecordingLabel = NSTextField(labelWithString: "Screen Recording:")
        screenRecordingLabel.font = NSFont.boldSystemFont(ofSize: 13)
        screenRecordingLabel.frame = NSRect(x: 20, y: yPos, width: 160, height: 20)
        view.addSubview(screenRecordingLabel)

        let screenRecordingStatusLabel = NSTextField(labelWithString: "")
        screenRecordingStatusLabel.frame = NSRect(x: 185, y: yPos, width: 260, height: 20)
        view.addSubview(screenRecordingStatusLabel)
        self.screenRecordingStatusLabel = screenRecordingStatusLabel
        yPos -= 32

        let virtualCameraLabel = NSTextField(labelWithString: "Virtual Camera:")
        virtualCameraLabel.font = NSFont.boldSystemFont(ofSize: 13)
        virtualCameraLabel.frame = NSRect(x: 20, y: yPos, width: 160, height: 20)
        view.addSubview(virtualCameraLabel)

        let virtualCameraStatusLabel = NSTextField(labelWithString: "")
        virtualCameraStatusLabel.frame = NSRect(x: 185, y: yPos, width: 260, height: 20)
        view.addSubview(virtualCameraStatusLabel)
        self.virtualCameraStatusLabel = virtualCameraStatusLabel
        yPos -= 32

        let selectedRegionTitleLabel = NSTextField(labelWithString: "Selected Region:")
        selectedRegionTitleLabel.font = NSFont.boldSystemFont(ofSize: 13)
        selectedRegionTitleLabel.frame = NSRect(x: 20, y: yPos, width: 160, height: 20)
        view.addSubview(selectedRegionTitleLabel)

        let selectedRegionLabel = NSTextField(wrappingLabelWithString: "")
        selectedRegionLabel.frame = NSRect(x: 185, y: yPos - 16, width: 260, height: 40)
        selectedRegionLabel.textColor = .secondaryLabelColor
        view.addSubview(selectedRegionLabel)
        self.selectedRegionLabel = selectedRegionLabel
        yPos -= 70

        let enableButton = NSButton(title: "Enable Virtual Camera", target: self, action: #selector(enableVirtualCameraFromPreferences))
        enableButton.frame = NSRect(x: 20, y: yPos, width: 170, height: 30)
        view.addSubview(enableButton)

        let selectRegionButton = NSButton(title: "Select Region…", target: self, action: #selector(selectRegionFromPreferences))
        selectRegionButton.frame = NSRect(x: 205, y: yPos, width: 130, height: 30)
        view.addSubview(selectRegionButton)
        yPos -= 42

        let fallbackButton = NSButton(title: "Open Share Window", target: self, action: #selector(openShareWindowFromPreferences))
        fallbackButton.frame = NSRect(x: 20, y: yPos, width: 170, height: 30)
        view.addSubview(fallbackButton)

        let settingsButton = NSButton(title: "Screen Recording Settings", target: self, action: #selector(openScreenRecordingSettingsFromPreferences))
        settingsButton.frame = NSRect(x: 205, y: yPos, width: 210, height: 30)
        view.addSubview(settingsButton)
        yPos -= 58

        let noteLabel = NSTextField(wrappingLabelWithString: "Video apps should list WindowSnap Virtual Camera after macOS approves the bundled camera extension. Use the share window fallback while developing or if extension approval is pending.")
        noteLabel.frame = NSRect(x: 20, y: yPos - 45, width: 430, height: 58)
        noteLabel.textColor = .secondaryLabelColor
        noteLabel.font = NSFont.systemFont(ofSize: 12)
        view.addSubview(noteLabel)

        refreshRegionShareControls()
        VirtualCameraExtensionManager.shared.onStatusChanged = { [weak self] _ in
            DispatchQueue.main.async { self?.refreshRegionShareControls() }
        }

        return view
    }

    @objc private func toggleTextExpander(_ sender: NSButton) {
        let enabled = sender.state == .on
        let state = TextExpanderRuntimeController.shared.setDesiredEnabled(enabled)
        refreshPermissionControls()
        if state == .permissionRequired {
            InputMonitoringPermissions.showPermissionsAlert()
        }
    }

    @objc private func openInputMonitoringSettings() {
        InputMonitoringPermissions.openInputMonitoringSettings()
    }

    @objc private func openTextExpanderWindow() {
        if textExpanderWindow == nil {
            textExpanderWindow = TextExpanderWindow()
        }
        textExpanderWindow?.showWindow(nil)
        textExpanderWindow?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func enableVirtualCameraFromPreferences() {
        RegionShareController.shared.enableVirtualCameraShare()
        refreshRegionShareControls()
    }

    @objc private func selectRegionFromPreferences() {
        RegionShareController.shared.selectNewRegion()
    }

    @objc private func openShareWindowFromPreferences() {
        RegionShareController.shared.showVirtualDisplayShare()
    }

    @objc private func openScreenRecordingSettingsFromPreferences() {
        ScreenRecordingPermissions.openScreenRecordingSettings()
    }

    private func refreshRegionShareControls() {
        let hasScreenRecording = ScreenRecordingPermissions.hasPermissions()
        screenRecordingStatusLabel?.stringValue = hasScreenRecording ? "Granted" : "Not granted"
        screenRecordingStatusLabel?.textColor = hasScreenRecording ? .systemGreen : .systemRed

        let status = VirtualCameraExtensionManager.shared.status
        virtualCameraStatusLabel?.stringValue = status.displayText
        switch status {
        case .enabled:
            virtualCameraStatusLabel?.textColor = .systemGreen
        case .needsApproval, .willCompleteAfterReboot:
            virtualCameraStatusLabel?.textColor = .systemOrange
        case .failed:
            virtualCameraStatusLabel?.textColor = .systemRed
        default:
            virtualCameraStatusLabel?.textColor = .secondaryLabelColor
        }

        if let region = RegionShareManager.shared.currentRegion,
           let bounds = RegionShareManager.shared.getDisplayBounds(for: region.displayID) {
            let rect = region.absoluteRect(for: bounds)
            selectedRegionLabel?.stringValue = "\(Int(rect.width))x\(Int(rect.height)) on display \(region.displayID)"
        } else {
            selectedRegionLabel?.stringValue = "No region selected"
        }
    }

    private func refreshPermissionControls() {
        let hasAccessibility = AccessibilityPermissions.hasPermissions()
        accessibilityStatusLabel?.stringValue = hasAccessibility ? "✓ Granted" : "✗ Not Granted"
        accessibilityStatusLabel?.textColor = hasAccessibility ? .systemGreen : .systemRed
        accessibilitySettingsButton?.isHidden = hasAccessibility

        let state = TextExpanderRuntimeController.shared.state
        textExpanderEnabledCheckbox?.state = state == .disabled ? .off : .on
        inputMonitoringStatusLabel?.stringValue = state == .permissionRequired
            ? "⚠ Permission Required"
            : (InputMonitoringPermissions.hasPermissions() ? "✓ Granted" : "✗ Not Granted")
        inputMonitoringStatusLabel?.textColor = state == .permissionRequired
            ? .systemOrange
            : (InputMonitoringPermissions.hasPermissions() ? .systemGreen : .systemRed)
        inputMonitoringButton?.isHidden = InputMonitoringPermissions.hasPermissions()
    }
}
