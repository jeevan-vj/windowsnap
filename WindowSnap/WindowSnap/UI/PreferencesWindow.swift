import AppKit

private final class SettingsDocumentView: NSView {
    override var isFlipped: Bool { true }
}
import Foundation

final class PreferencesWindow: NSWindowController, NSToolbarDelegate {
    enum Section: String, CaseIterable {
        case general
        case shortcuts
        case clipboard
        case textExpander
        case regionShare

        var identifier: NSToolbarItem.Identifier { .init(rawValue) }

        var title: String {
            switch self {
            case .general: return "General"
            case .shortcuts: return "Shortcuts"
            case .clipboard: return "Clipboard"
            case .textExpander: return "Text Expander"
            case .regionShare: return "Region Share"
            }
        }

        var symbolName: String {
            switch self {
            case .general: return "gearshape"
            case .shortcuts: return "keyboard"
            case .clipboard: return "doc.on.clipboard"
            case .textExpander: return "text.cursor"
            case .regionShare: return "rectangle.dashed"
            }
        }
    }

    static let toolbarIdentifiers = Section.allCases.map(\.identifier)

    private let contentContainer = NSView()
    private var sectionViews: [Section: NSView] = [:]
    private var selectedSection: Section = .general
    private var textExpanderWindow: TextExpanderWindow?
    private var clipboardPauseObserver: ClipboardPauseStateObserver?

    private weak var launchAtLoginCheckbox: NSButton?
    private weak var launchAtLoginStatusLabel: NSTextField?
    private weak var clipboardPauseCheckbox: NSButton?
    private weak var accessibilityStatusLabel: NSTextField?
    private weak var accessibilitySettingsButton: NSButton?
    private weak var textExpanderEnabledCheckbox: NSButton?
    private weak var textExpanderStatusLabel: NSTextField?
    private weak var textExpanderSetupButton: NSButton?
    private weak var screenRecordingStatusLabel: NSTextField?
    private weak var screenRecordingSetupButton: NSButton?
    private weak var virtualCameraStatusLabel: NSTextField?
    private weak var selectedRegionLabel: NSTextField?
    private weak var selectRegionButton: NSButton?
    private weak var openShareWindowButton: NSButton?
    private weak var enableVirtualCameraButton: NSButton?

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        self.init(window: window)
    }

    override init(window: NSWindow?) {
        super.init(window: window)
        configureWindow()
        observeClipboardPauseState()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureWindow()
        observeClipboardPauseState()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        refreshAllStates()
    }

    private func configureWindow() {
        guard let window else { return }
        window.title = "WindowSnap Settings"
        window.minSize = NSSize(width: 640, height: 480)
        window.isRestorable = false
        window.center()
        window.toolbarStyle = .preference

        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = contentContainer

        let toolbar = NSToolbar(identifier: "WindowSnapSettingsToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconAndLabel
        toolbar.allowsUserCustomization = false
        toolbar.selectedItemIdentifier = Section.general.identifier
        window.toolbar = toolbar

        show(section: .general)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        Self.toolbarIdentifiers
    }

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        Self.toolbarIdentifiers
    }

    func toolbarSelectableItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        Self.toolbarIdentifiers
    }

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        guard let section = Section(rawValue: itemIdentifier.rawValue) else { return nil }
        let item = NSToolbarItem(itemIdentifier: itemIdentifier)
        item.label = section.title
        item.paletteLabel = section.title
        item.image = NSImage(systemSymbolName: section.symbolName, accessibilityDescription: section.title)
        item.target = self
        item.action = #selector(selectSection(_:))
        item.toolTip = section.title
        return item
    }

    @objc private func selectSection(_ sender: NSToolbarItem) {
        guard let section = Section(rawValue: sender.itemIdentifier.rawValue) else { return }
        show(section: section)
    }

    private func show(section: Section) {
        selectedSection = section
        contentContainer.subviews.forEach { $0.removeFromSuperview() }
        let view = sectionViews[section] ?? makeSectionView(section)
        sectionViews[section] = view
        view.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(view)
        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            view.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            view.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor)
        ])
        window?.toolbar?.selectedItemIdentifier = section.identifier
        window?.title = "\(section.title) — WindowSnap Settings"
        refreshAllStates()
    }

    private func makeSectionView(_ section: Section) -> NSView {
        switch section {
        case .general: return makeGeneralView()
        case .shortcuts: return makeShortcutsView()
        case .clipboard: return makeClipboardView()
        case .textExpander: return makeTextExpanderView()
        case .regionShare: return makeRegionShareView()
        }
    }

    private func makeScrollableSection(title: String, detail: String? = nil) -> (NSScrollView, NSStackView) {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false

        let documentView = SettingsDocumentView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.edgeInsets = NSEdgeInsets(top: 28, left: 32, bottom: 32, right: 32)
        stack.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(stack)
        scrollView.documentView = documentView

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 20, weight: .semibold)
        stack.addArrangedSubview(titleLabel)
        if let detail {
            let detailLabel = NSTextField(wrappingLabelWithString: detail)
            detailLabel.textColor = .secondaryLabelColor
            detailLabel.maximumNumberOfLines = 0
            stack.addArrangedSubview(detailLabel)
            detailLabel.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -64).isActive = true
        }

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: documentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: documentView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: documentView.topAnchor),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: documentView.bottomAnchor),
            documentView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),
            documentView.heightAnchor.constraint(greaterThanOrEqualTo: scrollView.contentView.heightAnchor)
        ])
        return (scrollView, stack)
    }

    private func makeGeneralView() -> NSView {
        let (view, stack) = makeScrollableSection(
            title: "General",
            detail: "Choose how WindowSnap starts and confirm the access needed to move and resize windows."
        )

        let launchCheckbox = NSButton(
            checkboxWithTitle: "Launch WindowSnap at login",
            target: self,
            action: #selector(toggleLaunchAtLogin(_:))
        )
        launchCheckbox.setAccessibilityLabel("Launch WindowSnap at login")
        stack.addArrangedSubview(launchCheckbox)
        launchAtLoginCheckbox = launchCheckbox

        let launchStatus = secondaryLabel()
        stack.addArrangedSubview(launchStatus)
        launchAtLoginStatusLabel = launchStatus

        stack.addArrangedSubview(separator())
        stack.addArrangedSubview(sectionHeading("Window management access"))

        let accessRow = horizontalStack()
        let accessStatus = NSTextField(labelWithString: "")
        accessRow.addArrangedSubview(accessStatus)
        let accessButton = NSButton(title: "Open Accessibility Settings…", target: self, action: #selector(openAccessibilitySettings))
        accessButton.setAccessibilityLabel("Open Accessibility settings")
        accessRow.addArrangedSubview(accessButton)
        stack.addArrangedSubview(accessRow)
        accessibilityStatusLabel = accessStatus
        accessibilitySettingsButton = accessButton

        let privacy = secondaryLabel("WindowSnap uses Accessibility only to move and resize windows. Window information stays on this Mac.")
        stack.addArrangedSubview(privacy)
        privacy.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -64).isActive = true
        return view
    }

    private func makeShortcutsView() -> NSView {
        let (view, stack) = makeScrollableSection(
            title: "Shortcut Reference",
            detail: "These fixed global shortcuts remain available while WindowSnap is running. Custom positions and workspaces can have their own shortcuts."
        )
        let shortcuts = ShortcutManager().getDefaultShortcuts()
            .sorted { $0.value.rawValue < $1.value.rawValue }
        for (shortcut, position) in shortcuts {
            let row = horizontalStack()
            let action = NSTextField(labelWithString: position.displayName)
            action.setContentHuggingPriority(.defaultLow, for: .horizontal)
            let key = NSTextField(labelWithString: shortcutGlyphs(shortcut))
            key.font = .monospacedSystemFont(ofSize: 12, weight: .medium)
            key.alignment = .right
            key.setContentHuggingPriority(.required, for: .horizontal)
            row.addArrangedSubview(action)
            row.addArrangedSubview(key)
            row.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -64).isActive = true
            stack.addArrangedSubview(row)
        }
        return view
    }

    private func makeClipboardView() -> NSView {
        let (view, stack) = makeScrollableSection(
            title: "Clipboard History",
            detail: "History stays on this Mac, private password-manager items are excluded, and sensitive-data filtering remains on."
        )

        let retentionRow = horizontalStack()
        retentionRow.addArrangedSubview(NSTextField(labelWithString: "Keep unpinned history"))
        let retentionPopup = NSPopUpButton()
        for option in ClipboardHistoryRetention.allCases {
            retentionPopup.addItem(withTitle: option.displayName)
            retentionPopup.lastItem?.representedObject = option.rawValue
        }
        if let index = ClipboardHistoryRetention.allCases.firstIndex(of: ClipboardManager.shared.retention) {
            retentionPopup.selectItem(at: index)
        }
        retentionPopup.target = self
        retentionPopup.action = #selector(changeClipboardRetention(_:))
        retentionPopup.setAccessibilityLabel("Clipboard history retention")
        retentionRow.addArrangedSubview(retentionPopup)
        stack.addArrangedSubview(retentionRow)

        let pause = NSButton(
            checkboxWithTitle: "Pause clipboard history monitoring",
            target: self,
            action: #selector(toggleClipboardMonitoring(_:))
        )
        pause.setAccessibilityLabel("Pause clipboard history monitoring")
        stack.addArrangedSubview(pause)
        clipboardPauseCheckbox = pause

        let clear = NSButton(title: "Clear All History…", target: self, action: #selector(clearClipboardHistory(_:)))
        clear.setAccessibilityLabel("Clear all clipboard history")
        stack.addArrangedSubview(clear)
        let note = secondaryLabel("Pinned items do not expire automatically. Clear All removes pinned items too.")
        stack.addArrangedSubview(note)
        return view
    }

    private func makeTextExpanderView() -> NSView {
        let (view, stack) = makeScrollableSection(
            title: "Text Expander",
            detail: "Type a trigger phrase and press Tab to insert its replacement. Accessibility and Input Monitoring are required only while this feature is enabled."
        )

        let enabled = NSButton(
            checkboxWithTitle: "Enable Text Expander",
            target: self,
            action: #selector(toggleTextExpander(_:))
        )
        enabled.setAccessibilityLabel("Enable Text Expander")
        stack.addArrangedSubview(enabled)
        textExpanderEnabledCheckbox = enabled

        let statusRow = horizontalStack()
        let status = NSTextField(labelWithString: "")
        statusRow.addArrangedSubview(status)
        let setup = NSButton(title: "Set Up Text Expander…", target: self, action: #selector(setUpTextExpander))
        statusRow.addArrangedSubview(setup)
        stack.addArrangedSubview(statusRow)
        textExpanderStatusLabel = status
        textExpanderSetupButton = setup

        let manage = NSButton(title: "Manage Snippets…", target: self, action: #selector(openTextExpanderWindow))
        stack.addArrangedSubview(manage)
        let stats = TextExpanderManager.shared.getUsageStats()
        stack.addArrangedSubview(secondaryLabel("\(stats.expansionCount) expansions • \(stats.charactersSaved) characters saved • \(stats.timeSavedEstimate())"))
        return view
    }

    private func makeRegionShareView() -> NSView {
        let (view, stack) = makeScrollableSection(
            title: "Region Share",
            detail: "Capture a selected area for video calls. Captured frames are processed locally and require Screen Recording access."
        )

        let screenRow = horizontalStack()
        screenRow.addArrangedSubview(sectionHeading("Screen Recording"))
        let screenStatus = NSTextField(labelWithString: "")
        screenRow.addArrangedSubview(screenStatus)
        let setup = NSButton(title: "Set Up…", target: self, action: #selector(setUpScreenRecording))
        screenRow.addArrangedSubview(setup)
        stack.addArrangedSubview(screenRow)
        screenRecordingStatusLabel = screenStatus
        screenRecordingSetupButton = setup

        let cameraRow = horizontalStack()
        cameraRow.addArrangedSubview(sectionHeading("Virtual Camera"))
        let cameraStatus = NSTextField(labelWithString: "")
        cameraRow.addArrangedSubview(cameraStatus)
        stack.addArrangedSubview(cameraRow)
        virtualCameraStatusLabel = cameraStatus

        let regionRow = horizontalStack()
        regionRow.addArrangedSubview(sectionHeading("Selected Region"))
        let region = secondaryLabel()
        regionRow.addArrangedSubview(region)
        stack.addArrangedSubview(regionRow)
        selectedRegionLabel = region

        let actions = horizontalStack()
        let selectRegion = NSButton(title: "Select Region…", target: self, action: #selector(selectRegionFromPreferences))
        selectRegion.setAccessibilityLabel("Select a region to share")
        let openShare = NSButton(title: "Open Share Window", target: self, action: #selector(openShareWindowFromPreferences))
        openShare.setAccessibilityLabel("Open the selected region in a share window")
        let enableCamera = NSButton(title: "Enable Virtual Camera", target: self, action: #selector(enableVirtualCameraFromPreferences))
        enableCamera.setAccessibilityLabel("Enable the virtual camera for the selected region")
        actions.addArrangedSubview(selectRegion)
        actions.addArrangedSubview(openShare)
        actions.addArrangedSubview(enableCamera)
        stack.addArrangedSubview(actions)
        selectRegionButton = selectRegion
        openShareWindowButton = openShare
        enableVirtualCameraButton = enableCamera

        let note = secondaryLabel("Use the share window while the optional virtual camera extension is awaiting approval or a restart.")
        stack.addArrangedSubview(note)
        VirtualCameraExtensionManager.shared.onStatusChanged = { [weak self] _ in
            DispatchQueue.main.async { self?.refreshRegionShareControls() }
        }
        return view
    }

    private func horizontalStack() -> NSStackView {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 12
        return stack
    }

    private func sectionHeading(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 13, weight: .semibold)
        return label
    }

    private func secondaryLabel(_ text: String = "") -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.textColor = .secondaryLabelColor
        label.font = .systemFont(ofSize: 12)
        return label
    }

    private func shortcutGlyphs(_ shortcut: String) -> String {
        let glyphs = shortcut.lowercased().split(separator: "+").map { token -> String in
            switch token {
            case "cmd": return "⌘"
            case "shift": return "⇧"
            case "option": return "⌥"
            case "ctrl": return "⌃"
            case "left": return "←"
            case "right": return "→"
            case "up": return "↑"
            case "down": return "↓"
            case "space": return "Space"
            default: return token.uppercased()
            }
        }
        return glyphs.joined()
    }

    private func separator() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        box.widthAnchor.constraint(equalToConstant: 560).isActive = true
        return box
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSButton) {
        do {
            try LaunchAtLoginManager.shared.setEnabled(sender.state == .on)
        } catch {
            let alert = NSAlert()
            alert.messageText = "Couldn’t Update Launch at Login"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open Login Items Settings")
            alert.addButton(withTitle: "Cancel")
            if alert.runModal() == .alertFirstButtonReturn { openLoginItemsSettings() }
        }
        refreshLaunchAtLoginControl()
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
        sender.state == .on ? ClipboardManager.shared.pauseMonitoring() : ClipboardManager.shared.resumeMonitoring()
    }

    @objc private func clearClipboardHistory(_ sender: NSButton) {
        let alert = NSAlert()
        alert.messageText = "Clear Clipboard History?"
        alert.informativeText = "This removes all clipboard history, including pinned items, from this Mac. This can’t be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear All")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn { ClipboardManager.shared.clearHistory() }
    }

    @objc private func toggleTextExpander(_ sender: NSButton) {
        let state = TextExpanderRuntimeController.shared.setDesiredEnabled(sender.state == .on)
        refreshTextExpanderControls()
        if case .needsPermission = state { InputMonitoringPermissions.showSetupAlert() }
    }

    @objc private func setUpTextExpander() {
        InputMonitoringPermissions.showSetupAlert()
    }

    @objc private func openTextExpanderWindow() {
        if textExpanderWindow == nil { textExpanderWindow = TextExpanderWindow() }
        textExpanderWindow?.showWindow(nil)
        textExpanderWindow?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func setUpScreenRecording() {
        switch ScreenRecordingPermissions.state {
        case .notRequested:
            ScreenRecordingPermissions.requestPermissionForRegionShare { [weak self] _ in self?.refreshRegionShareControls() }
        case .denied:
            ScreenRecordingPermissions.openScreenRecordingSettings()
        case .restartRequired:
            ScreenRecordingPermissions.showRestartRequiredAlert()
        case .granted:
            break
        }
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

    @objc private func applicationDidBecomeActive() {
        guard window?.isVisible == true else { return }
        refreshAllStates()
    }

    private func observeClipboardPauseState() {
        clipboardPauseObserver = ClipboardPauseStateObserver { [weak self] paused in
            let update: () -> Void = { self?.clipboardPauseCheckbox?.state = paused ? .on : .off }
            if Thread.isMainThread {
                update()
            } else {
                DispatchQueue.main.async(execute: update)
            }
        }
    }

    private func refreshAllStates() {
        refreshLaunchAtLoginControl()
        refreshAccessibilityControl()
        refreshTextExpanderControls()
        refreshRegionShareControls()
        clipboardPauseCheckbox?.state = ClipboardManager.shared.isMonitoringPaused ? .on : .off
    }

    private func refreshLaunchAtLoginControl() {
        let status = LaunchAtLoginManager.shared.refreshStatus()
        launchAtLoginCheckbox?.state = status.isEnabled ? .on : .off
        launchAtLoginCheckbox?.isEnabled = status != .notFound && status != .unknown
        switch status {
        case .enabled, .disabled:
            launchAtLoginStatusLabel?.stringValue = ""
        case .requiresApproval:
            launchAtLoginStatusLabel?.stringValue = "Approval is required in System Settings > General > Login Items."
        case .notFound:
            launchAtLoginStatusLabel?.stringValue = "Move WindowSnap to Applications, reopen it, and try again."
        case .unknown:
            launchAtLoginStatusLabel?.stringValue = "Login item status is unavailable."
        }
    }

    private func refreshAccessibilityControl() {
        let granted = AccessibilityPermissions.hasPermissions()
        accessibilityStatusLabel?.stringValue = granted ? "Granted" : "Setup needed"
        accessibilityStatusLabel?.textColor = granted ? .systemGreen : .secondaryLabelColor
        accessibilitySettingsButton?.isHidden = granted
    }

    private func refreshTextExpanderControls() {
        let state = TextExpanderRuntimeController.shared.state
        textExpanderEnabledCheckbox?.state = state == .running ? .on : .off
        switch state {
        case .running:
            textExpanderStatusLabel?.stringValue = "Enabled and running"
            textExpanderStatusLabel?.textColor = .systemGreen
            textExpanderSetupButton?.isHidden = true
        case .needsPermission(let missing):
            let names = missing.map(\.displayName).sorted().joined(separator: " and ")
            textExpanderStatusLabel?.stringValue = "Setup needed: \(names)"
            textExpanderStatusLabel?.textColor = .secondaryLabelColor
            textExpanderSetupButton?.isHidden = false
        case .disabled:
            textExpanderStatusLabel?.stringValue = "Ready to enable"
            textExpanderStatusLabel?.textColor = .secondaryLabelColor
            textExpanderSetupButton?.isHidden = true
        }
    }

    private func refreshRegionShareControls() {
        let hasRegion = RegionShareManager.shared.currentRegion != nil
        ScreenRecordingPermissions.refreshState { [weak self] state in
            let update = {
                guard let self else { return }
                let granted = state == .granted
                self.screenRecordingStatusLabel?.stringValue = state.statusText
                self.screenRecordingStatusLabel?.textColor = granted ? .systemGreen : .secondaryLabelColor
                self.screenRecordingSetupButton?.isHidden = granted
                self.selectRegionButton?.isEnabled = granted
                self.openShareWindowButton?.isEnabled = granted && hasRegion
                self.enableVirtualCameraButton?.isEnabled = granted && hasRegion
                switch state {
                case .notRequested: self.screenRecordingSetupButton?.title = "Set Up…"
                case .denied: self.screenRecordingSetupButton?.title = "Open System Settings…"
                case .restartRequired: self.screenRecordingSetupButton?.title = "Restart WindowSnap…"
                case .granted: break
                }
            }
            if Thread.isMainThread { update() } else { DispatchQueue.main.async(execute: update) }
        }

        let cameraStatus = VirtualCameraExtensionManager.shared.status
        virtualCameraStatusLabel?.stringValue = cameraStatus.displayText
        switch cameraStatus {
        case .enabled: virtualCameraStatusLabel?.textColor = .systemGreen
        case .failed: virtualCameraStatusLabel?.textColor = .systemRed
        default: virtualCameraStatusLabel?.textColor = .secondaryLabelColor
        }

        if let region = RegionShareManager.shared.currentRegion,
           let bounds = RegionShareManager.shared.getDisplayBounds(for: region.displayID) {
            let rect = region.absoluteRect(for: bounds)
            selectedRegionLabel?.stringValue = "\(Int(rect.width)) × \(Int(rect.height))"
        } else {
            selectedRegionLabel?.stringValue = "No region selected"
        }
    }

    private func openLoginItemsSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") else { return }
        NSWorkspace.shared.open(url)
    }
}
