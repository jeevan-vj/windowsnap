import AppKit
import Foundation

/// Window for managing app-specific positioning rules
class AppPositioningRulesWindow: NSWindowController {

    private var ruleManager = AppPositioningRuleManager.shared
    private var tableView: NSTableView!
    private var rules: [AppPositioningRule] = []
    private var enabledCheckboxes: [UUID: NSButton] = [:]

    override init(window: NSWindow?) {
        super.init(window: window)
        setupWindow()
    }

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 550),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        self.init(window: window)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupWindow()
    }

    private func setupWindow() {
        guard let window = window else { return }

        window.title = "App Auto-Positioning Rules"
        window.center()
        window.isRestorable = false
        window.minSize = NSSize(width: 600, height: 500)

        setupContentView()
        refreshRules()
    }

    private func setupContentView() {
        guard let window = window else { return }

        let contentView = NSView(frame: window.contentRect(forFrameRect: window.frame))
        window.contentView = contentView

        // Title label
        let titleLabel = NSTextField(labelWithString: "App Auto-Positioning Rules")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 16)
        titleLabel.frame = NSRect(x: 20, y: contentView.frame.height - 40, width: 400, height: 25)
        titleLabel.autoresizingMask = [.minYMargin]
        contentView.addSubview(titleLabel)

        // Subtitle
        let subtitleLabel = NSTextField(labelWithString: "Automatically position windows when apps launch")
        subtitleLabel.font = NSFont.systemFont(ofSize: 12)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.frame = NSRect(x: 20, y: contentView.frame.height - 60, width: 450, height: 20)
        subtitleLabel.autoresizingMask = [.minYMargin]
        contentView.addSubview(subtitleLabel)

        // Monitoring status and toggle
        let monitoringLabel = NSTextField(labelWithString: "Auto-positioning:")
        monitoringLabel.frame = NSRect(x: contentView.frame.width - 220, y: contentView.frame.height - 40, width: 110, height: 20)
        monitoringLabel.autoresizingMask = [.minXMargin, .minYMargin]
        monitoringLabel.alignment = .right
        contentView.addSubview(monitoringLabel)

        let monitoringToggle = NSButton(checkboxWithTitle: "Enabled", target: self, action: #selector(toggleMonitoring))
        monitoringToggle.frame = NSRect(x: contentView.frame.width - 100, y: contentView.frame.height - 42, width: 80, height: 20)
        monitoringToggle.autoresizingMask = [.minXMargin, .minYMargin]
        monitoringToggle.state = .on
        contentView.addSubview(monitoringToggle)

        // Create table view with scroll view
        let scrollView = NSScrollView(frame: NSRect(x: 20, y: 80, width: contentView.frame.width - 40, height: contentView.frame.height - 160))
        scrollView.autoresizingMask = [.width, .height]
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .lineBorder

        tableView = NSTableView()
        tableView.headerView = NSTableHeaderView()
        tableView.allowsMultipleSelection = false
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.rowHeight = 30

        // Create columns
        let enabledColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("enabled"))
        enabledColumn.title = "On"
        enabledColumn.width = 40
        tableView.addTableColumn(enabledColumn)

        let appColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("app"))
        appColumn.title = "Application"
        appColumn.width = 150
        tableView.addTableColumn(appColumn)

        let positionColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("position"))
        positionColumn.title = "Position"
        positionColumn.width = 150
        tableView.addTableColumn(positionColumn)

        let screenColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("screen"))
        screenColumn.title = "Screen"
        screenColumn.width = 100
        tableView.addTableColumn(screenColumn)

        let filterColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("filter"))
        filterColumn.title = "Window Filter"
        filterColumn.width = 120
        tableView.addTableColumn(filterColumn)

        let lastUsedColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("lastUsed"))
        lastUsedColumn.title = "Last Used"
        lastUsedColumn.width = 120
        tableView.addTableColumn(lastUsedColumn)

        tableView.dataSource = self
        tableView.delegate = self

        scrollView.documentView = tableView
        contentView.addSubview(scrollView)

        // Create buttons
        setupButtons(in: contentView)
    }

    private func setupButtons(in contentView: NSView) {
        let buttonHeight: CGFloat = 32
        let buttonSpacing: CGFloat = 10
        var xPos: CGFloat = 20

        // Add Rule for Current App button
        let addCurrentAppButton = NSButton(title: "Add Current App", target: self, action: #selector(addCurrentApp))
        addCurrentAppButton.frame = NSRect(x: xPos, y: 20, width: 130, height: buttonHeight)
        addCurrentAppButton.autoresizingMask = [.minYMargin]
        addCurrentAppButton.bezelStyle = .rounded
        contentView.addSubview(addCurrentAppButton)
        xPos += 130 + buttonSpacing

        // Add Custom Rule button
        let addCustomButton = NSButton(title: "Add Custom", target: self, action: #selector(addCustomRule))
        addCustomButton.frame = NSRect(x: xPos, y: 20, width: 100, height: buttonHeight)
        addCustomButton.autoresizingMask = [.minYMargin]
        addCustomButton.bezelStyle = .rounded
        contentView.addSubview(addCustomButton)
        xPos += 100 + buttonSpacing

        // Edit button
        let editButton = NSButton(title: "Edit", target: self, action: #selector(editRule))
        editButton.frame = NSRect(x: xPos, y: 20, width: 70, height: buttonHeight)
        editButton.autoresizingMask = [.minYMargin]
        editButton.bezelStyle = .rounded
        contentView.addSubview(editButton)
        xPos += 70 + buttonSpacing

        // Delete button
        let deleteButton = NSButton(title: "Delete", target: self, action: #selector(deleteRule))
        deleteButton.frame = NSRect(x: xPos, y: 20, width: 70, height: buttonHeight)
        deleteButton.autoresizingMask = [.minYMargin]
        deleteButton.bezelStyle = .rounded
        contentView.addSubview(deleteButton)
        xPos += 70 + buttonSpacing

        // Import Presets button
        let presetsButton = NSButton(title: "Import Presets", target: self, action: #selector(importPresets))
        presetsButton.frame = NSRect(x: xPos, y: 20, width: 120, height: buttonHeight)
        presetsButton.autoresizingMask = [.minYMargin]
        presetsButton.bezelStyle = .rounded
        contentView.addSubview(presetsButton)
        xPos += 120 + buttonSpacing

        // Apply Now button (right-aligned)
        let applyButton = NSButton(title: "Apply Now", target: self, action: #selector(applyNow))
        applyButton.frame = NSRect(x: contentView.frame.width - 110, y: 20, width: 90, height: buttonHeight)
        applyButton.autoresizingMask = [.minXMargin, .minYMargin]
        applyButton.bezelStyle = .rounded
        applyButton.keyEquivalent = "\r" // Enter key
        contentView.addSubview(applyButton)
    }

    private func refreshRules() {
        rules = ruleManager.getAllRules()
        enabledCheckboxes.removeAll()
        tableView?.reloadData()
    }

    // MARK: - Button Actions

    @objc private func toggleMonitoring(_ sender: NSButton) {
        if sender.state == .on {
            ruleManager.startMonitoring()
            showNotification("Auto-positioning enabled", "Windows will be positioned automatically when apps launch")
        } else {
            ruleManager.stopMonitoring()
            showNotification("Auto-positioning disabled", "Rules will not be applied automatically")
        }
    }

    @objc private func addCurrentApp() {
        guard let focusedWindow = WindowManager.shared.getFocusedWindow() else {
            showAlert("No Focused Window", message: "Please focus a window from the app you want to add a rule for.")
            return
        }

        // Show dialog to configure the rule
        showRuleDialog(for: focusedWindow.applicationName, bundleId: nil, editingRule: nil)
    }

    @objc private func addCustomRule() {
        // Show dialog to select app and configure rule
        showAppSelectionDialog()
    }

    @objc private func editRule() {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0 && selectedRow < rules.count else {
            showAlert("No Selection", message: "Please select a rule to edit.")
            return
        }

        let rule = rules[selectedRow]
        showRuleDialog(for: rule.appName, bundleId: rule.bundleIdentifier, editingRule: rule)
    }

    @objc private func deleteRule() {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0 && selectedRow < rules.count else {
            showAlert("No Selection", message: "Please select a rule to delete.")
            return
        }

        let rule = rules[selectedRow]

        let alert = NSAlert()
        alert.messageText = "Delete Rule?"
        alert.informativeText = "Are you sure you want to delete the rule for '\(rule.appName)'?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            ruleManager.removeRule(id: rule.id)
            refreshRules()
        }
    }

    @objc private func importPresets() {
        let alert = NSAlert()
        alert.messageText = "Import Common Presets?"
        alert.informativeText = "This will add positioning rules for common productivity apps (Terminal, VS Code, browsers, etc.)"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Import")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            ruleManager.importCommonPresets()
            refreshRules()
            showNotification("Presets Imported", "Common app positioning rules have been added")
        }
    }

    @objc private func applyNow() {
        ruleManager.resetTracking()
        ruleManager.applyRulesToRunningApps()
        showNotification("Rules Applied", "Positioning rules have been applied to all running apps")
    }

    @objc private func toggleRuleEnabled(_ sender: NSButton) {
        guard let ruleId = enabledCheckboxes.first(where: { $0.value == sender })?.key else {
            return
        }

        ruleManager.toggleRule(id: ruleId)
        refreshRules()
    }

    // MARK: - Dialogs

    private func showRuleDialog(for appName: String, bundleId: String?, editingRule: AppPositioningRule?) {
        let dialog = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        dialog.title = editingRule != nil ? "Edit Rule" : "Add Rule for \(appName)"
        dialog.center()
        dialog.level = .floating

        let contentView = NSView(frame: dialog.contentRect(forFrameRect: dialog.frame))
        dialog.contentView = contentView

        var yPos: CGFloat = contentView.frame.height - 40

        // App name
        let appLabel = NSTextField(labelWithString: "Application: \(appName)")
        appLabel.font = NSFont.boldSystemFont(ofSize: 13)
        appLabel.frame = NSRect(x: 20, y: yPos, width: 410, height: 20)
        contentView.addSubview(appLabel)
        yPos -= 35

        // Position selection
        let positionLabel = NSTextField(labelWithString: "Position:")
        positionLabel.frame = NSRect(x: 20, y: yPos, width: 100, height: 20)
        contentView.addSubview(positionLabel)

        let positionPopup = NSPopUpButton(frame: NSRect(x: 130, y: yPos - 2, width: 300, height: 25))
        positionPopup.addItems(withTitles: [
            "Left Half", "Right Half", "Top Half", "Bottom Half",
            "Top Left Quarter", "Top Right Quarter", "Bottom Left Quarter", "Bottom Right Quarter",
            "Left Third", "Center Third", "Right Third",
            "Left Two-Thirds", "Right Two-Thirds",
            "Maximize", "Center"
        ])
        contentView.addSubview(positionPopup)
        yPos -= 35

        // Screen selection
        let screenLabel = NSTextField(labelWithString: "Screen:")
        screenLabel.frame = NSRect(x: 20, y: yPos, width: 100, height: 20)
        contentView.addSubview(screenLabel)

        let screenPopup = NSPopUpButton(frame: NSRect(x: 130, y: yPos - 2, width: 300, height: 25))
        let screens = NSScreen.screens
        for (index, screen) in screens.enumerated() {
            let title = index == 0 ? "Main Screen" : "Screen \(index + 1)"
            screenPopup.addItem(withTitle: title)
        }
        contentView.addSubview(screenPopup)
        yPos -= 35

        // Window filter
        let filterLabel = NSTextField(labelWithString: "Apply to:")
        filterLabel.frame = NSRect(x: 20, y: yPos, width: 100, height: 20)
        contentView.addSubview(filterLabel)

        let filterPopup = NSPopUpButton(frame: NSRect(x: 130, y: yPos - 2, width: 300, height: 25))
        filterPopup.addItems(withTitles: ["First Window Only", "All Windows"])
        contentView.addSubview(filterPopup)
        yPos -= 35

        // Enabled checkbox
        let enabledCheckbox = NSButton(checkboxWithTitle: "Enable this rule", target: nil, action: nil)
        enabledCheckbox.frame = NSRect(x: 130, y: yPos, width: 200, height: 20)
        enabledCheckbox.state = .on
        contentView.addSubview(enabledCheckbox)
        yPos -= 50

        // Set values if editing
        if let rule = editingRule {
            switch rule.positionType {
            case .gridPosition(let pos):
                positionPopup.selectItem(at: getPositionIndex(pos))
            case .maximize:
                positionPopup.selectItem(withTitle: "Maximize")
            case .center:
                positionPopup.selectItem(withTitle: "Center")
            default:
                break
            }
            screenPopup.selectItem(at: rule.targetScreenIndex)
            filterPopup.selectItem(at: rule.windowFilter == .firstWindowOnly ? 0 : 1)
            enabledCheckbox.state = rule.isEnabled ? .on : .off
        }

        // Buttons
        let saveButton = NSButton(title: "Save", target: nil, action: nil)
        saveButton.frame = NSRect(x: contentView.frame.width - 180, y: 20, width: 80, height: 32)
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        contentView.addSubview(saveButton)

        let cancelButton = NSButton(title: "Cancel", target: nil, action: nil)
        cancelButton.frame = NSRect(x: contentView.frame.width - 90, y: 20, width: 70, height: 32)
        cancelButton.bezelStyle = .rounded
        contentView.addSubview(cancelButton)

        // Button actions
        saveButton.target = self
        saveButton.action = #selector(saveRuleFromDialog(_:))

        cancelButton.target = self
        cancelButton.action = #selector(closeDialog(_:))

        // Store dialog references
        objc_setAssociatedObject(saveButton, "dialog", dialog, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(saveButton, "appName", appName, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(saveButton, "bundleId", bundleId, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(saveButton, "editingRule", editingRule, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(saveButton, "positionPopup", positionPopup, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(saveButton, "screenPopup", screenPopup, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(saveButton, "filterPopup", filterPopup, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(saveButton, "enabledCheckbox", enabledCheckbox, .OBJC_ASSOCIATION_RETAIN)

        objc_setAssociatedObject(cancelButton, "dialog", dialog, .OBJC_ASSOCIATION_RETAIN)

        dialog.makeKeyAndOrderFront(nil)
    }

    @objc private func saveRuleFromDialog(_ sender: NSButton) {
        guard let dialog = objc_getAssociatedObject(sender, "dialog") as? NSWindow,
              let appName = objc_getAssociatedObject(sender, "appName") as? String,
              let positionPopup = objc_getAssociatedObject(sender, "positionPopup") as? NSPopUpButton,
              let screenPopup = objc_getAssociatedObject(sender, "screenPopup") as? NSPopUpButton,
              let filterPopup = objc_getAssociatedObject(sender, "filterPopup") as? NSPopUpButton,
              let enabledCheckbox = objc_getAssociatedObject(sender, "enabledCheckbox") as? NSButton else {
            return
        }

        let bundleId = objc_getAssociatedObject(sender, "bundleId") as? String
        let editingRule = objc_getAssociatedObject(sender, "editingRule") as? AppPositioningRule

        // Get selected values
        let selectedPosition = getGridPosition(from: positionPopup.indexOfSelectedItem)
        let selectedScreen = screenPopup.indexOfSelectedItem
        let selectedFilter: AppPositioningRule.WindowFilter = filterPopup.indexOfSelectedItem == 0 ? .firstWindowOnly : .allWindows
        let isEnabled = enabledCheckbox.state == .on

        // Determine bundle ID
        let finalBundleId: String
        if let bid = bundleId {
            finalBundleId = bid
        } else if let window = WindowManager.shared.getFocusedWindow() {
            // Try to get bundle ID from focused window
            let runningApps = NSWorkspace.shared.runningApplications
            if let app = runningApps.first(where: { $0.processIdentifier == window.processID }),
               let bid = app.bundleIdentifier {
                finalBundleId = bid
            } else {
                finalBundleId = "unknown.\(appName)"
            }
        } else {
            finalBundleId = "unknown.\(appName)"
        }

        if let existingRule = editingRule {
            // Update existing rule
            let updatedRule = AppPositioningRule(
                appName: appName,
                bundleIdentifier: finalBundleId,
                positionType: selectedPosition,
                targetScreenIndex: selectedScreen,
                windowFilter: selectedFilter,
                isEnabled: isEnabled
            )
            ruleManager.updateRule(updatedRule)
        } else {
            // Create new rule
            let newRule = AppPositioningRule(
                appName: appName,
                bundleIdentifier: finalBundleId,
                positionType: selectedPosition,
                targetScreenIndex: selectedScreen,
                windowFilter: selectedFilter,
                isEnabled: isEnabled
            )
            ruleManager.addRule(newRule)
        }

        refreshRules()
        dialog.close()
    }

    @objc private func closeDialog(_ sender: NSButton) {
        guard let dialog = objc_getAssociatedObject(sender, "dialog") as? NSWindow else {
            return
        }
        dialog.close()
    }

    private func showAppSelectionDialog() {
        let runningApps = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular
        }.sorted {
            ($0.localizedName ?? "") < ($1.localizedName ?? "")
        }

        let dialog = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 350, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        dialog.title = "Select Application"
        dialog.center()
        dialog.level = .floating

        let contentView = NSView(frame: dialog.contentRect(forFrameRect: dialog.frame))
        dialog.contentView = contentView

        let label = NSTextField(labelWithString: "Choose an application to create a rule for:")
        label.frame = NSRect(x: 20, y: contentView.frame.height - 35, width: 310, height: 20)
        contentView.addSubview(label)

        let scrollView = NSScrollView(frame: NSRect(x: 20, y: 60, width: 310, height: contentView.frame.height - 100))
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .lineBorder

        let tableView = NSTableView()
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("app"))
        column.width = 290
        tableView.addTableColumn(column)
        tableView.headerView = nil

        scrollView.documentView = tableView
        contentView.addSubview(scrollView)

        // Simple data source
        class AppListDataSource: NSObject, NSTableViewDataSource, NSTableViewDelegate {
            let apps: [NSRunningApplication]

            init(apps: [NSRunningApplication]) {
                self.apps = apps
            }

            func numberOfRows(in tableView: NSTableView) -> Int {
                return apps.count
            }

            func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
                let textField = NSTextField(labelWithString: apps[row].localizedName ?? "Unknown")
                return textField
            }
        }

        let dataSource = AppListDataSource(apps: runningApps)
        tableView.dataSource = dataSource
        tableView.delegate = dataSource
        tableView.reloadData()

        let selectButton = NSButton(title: "Select", target: self, action: #selector(selectAppFromDialog(_:)))
        selectButton.frame = NSRect(x: contentView.frame.width - 160, y: 20, width: 70, height: 32)
        selectButton.bezelStyle = .rounded
        contentView.addSubview(selectButton)

        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(closeDialog(_:)))
        cancelButton.frame = NSRect(x: contentView.frame.width - 80, y: 20, width: 60, height: 32)
        cancelButton.bezelStyle = .rounded
        contentView.addSubview(cancelButton)

        objc_setAssociatedObject(selectButton, "dialog", dialog, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(selectButton, "tableView", tableView, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(selectButton, "apps", runningApps, .OBJC_ASSOCIATION_RETAIN)
        objc_setAssociatedObject(cancelButton, "dialog", dialog, .OBJC_ASSOCIATION_RETAIN)

        dialog.makeKeyAndOrderFront(nil)
    }

    @objc private func selectAppFromDialog(_ sender: NSButton) {
        guard let dialog = objc_getAssociatedObject(sender, "dialog") as? NSWindow,
              let tableView = objc_getAssociatedObject(sender, "tableView") as? NSTableView,
              let apps = objc_getAssociatedObject(sender, "apps") as? [NSRunningApplication] else {
            return
        }

        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0 && selectedRow < apps.count else {
            showAlert("No Selection", message: "Please select an application.")
            return
        }

        let app = apps[selectedRow]
        dialog.close()

        showRuleDialog(for: app.localizedName ?? "Unknown", bundleId: app.bundleIdentifier, editingRule: nil)
    }

    // MARK: - Utility Methods

    private func getPositionIndex(_ position: GridPosition) -> Int {
        switch position {
        case .leftHalf: return 0
        case .rightHalf: return 1
        case .topHalf: return 2
        case .bottomHalf: return 3
        case .topLeft: return 4
        case .topRight: return 5
        case .bottomLeft: return 6
        case .bottomRight: return 7
        case .leftThird: return 8
        case .centerThird: return 9
        case .rightThird: return 10
        case .leftTwoThirds: return 11
        case .rightTwoThirds: return 12
        case .maximize: return 13
        case .center: return 14
        }
    }

    private func getGridPosition(from index: Int) -> AppPositioningRule.PositionType {
        let positions: [GridPosition] = [
            .leftHalf, .rightHalf, .topHalf, .bottomHalf,
            .topLeft, .topRight, .bottomLeft, .bottomRight,
            .leftThird, .centerThird, .rightThird,
            .leftTwoThirds, .rightTwoThirds
        ]

        if index == 13 {
            return .maximize
        } else if index == 14 {
            return .center
        } else if index >= 0 && index < positions.count {
            return .gridPosition(positions[index])
        }

        return .gridPosition(.leftHalf)
    }

    private func showAlert(_ title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func showNotification(_ title: String, _ message: String) {
        print("📢 \(title): \(message)")
        // Could integrate with NotificationCenter for user notifications
    }
}

// MARK: - Table View Data Source & Delegate

extension AppPositioningRulesWindow: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return rules.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row >= 0 && row < rules.count else { return nil }

        let rule = rules[row]
        let identifier = tableColumn?.identifier

        if identifier?.rawValue == "enabled" {
            let checkbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(toggleRuleEnabled(_:)))
            checkbox.state = rule.isEnabled ? .on : .off
            enabledCheckboxes[rule.id] = checkbox
            return checkbox
        } else if identifier?.rawValue == "app" {
            return NSTextField(labelWithString: rule.appName)
        } else if identifier?.rawValue == "position" {
            return NSTextField(labelWithString: rule.positionType.displayName)
        } else if identifier?.rawValue == "screen" {
            let screenName = rule.targetScreenIndex == 0 ? "Main" : "Screen \(rule.targetScreenIndex + 1)"
            return NSTextField(labelWithString: screenName)
        } else if identifier?.rawValue == "filter" {
            return NSTextField(labelWithString: rule.windowFilter.displayName)
        } else if identifier?.rawValue == "lastUsed" {
            let text: String
            if let lastUsed = rule.lastUsed {
                let formatter = RelativeDateTimeFormatter()
                formatter.unitsStyle = .short
                text = formatter.localizedString(for: lastUsed, relativeTo: Date())
            } else {
                text = "Never"
            }
            let textField = NSTextField(labelWithString: text)
            textField.textColor = .secondaryLabelColor
            textField.font = NSFont.systemFont(ofSize: 11)
            return textField
        }

        return nil
    }
}
