import AppKit
import Foundation

class TextExpanderWindow: NSWindowController, NSTableViewDelegate, NSTableViewDataSource {
    
    private var tableView: NSTableView!
    private var scrollView: NSScrollView!
    private var addButton: NSButton!
    private var removeButton: NSButton!
    private var editButton: NSButton!
    private var enabledCheckbox: NSButton!
    private var permissionStatusLabel: NSTextField!
    private var permissionButton: NSButton!
    private var snippets: [TextExpansionSnippet] = []
    private var runtimeStateObserver: NSObjectProtocol?
    
    override init(window: NSWindow?) {
        super.init(window: window)
        setupWindow()
    }
    
    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 450),
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
        
        window.title = "Text Expander"
        window.center()
        window.isRestorable = false
        window.minSize = NSSize(width: 500, height: 350)
        
        setupContentView()
        loadSnippets()
        runtimeStateObserver = NotificationCenter.default.addObserver(
            forName: .textExpanderRuntimeStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in self?.updatePermissionStatus() }
    }

    deinit {
        if let runtimeStateObserver { NotificationCenter.default.removeObserver(runtimeStateObserver) }
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        loadSnippets()
        updatePermissionStatus()
    }
    
    private func setupContentView() {
        guard let window = window else { return }
        
        let contentView = NSView(frame: window.contentRect(forFrameRect: window.frame))
        contentView.wantsLayer = true
        window.contentView = contentView
        
        var yPos: CGFloat = contentView.bounds.height - 30
        
        let titleLabel = NSTextField(labelWithString: "Text Expansion Snippets")
        titleLabel.font = NSFont.boldSystemFont(ofSize: 16)
        titleLabel.frame = NSRect(x: 20, y: yPos, width: 300, height: 25)
        contentView.addSubview(titleLabel)
        
        enabledCheckbox = NSButton(checkboxWithTitle: "Enable Text Expander", target: self, action: #selector(toggleEnabled(_:)))
        enabledCheckbox.frame = NSRect(x: contentView.bounds.width - 180, y: yPos, width: 160, height: 25)
        enabledCheckbox.state = TextExpanderManager.shared.isEnabled ? .on : .off
        enabledCheckbox.autoresizingMask = [.minXMargin]
        contentView.addSubview(enabledCheckbox)
        
        yPos -= 30
        
        let descriptionLabel = NSTextField(wrappingLabelWithString: "Type a trigger phrase and press Tab to expand it. For example, type ':email' then Tab to insert your email address.")
        descriptionLabel.frame = NSRect(x: 20, y: yPos - 35, width: contentView.bounds.width - 40, height: 35)
        descriptionLabel.textColor = .secondaryLabelColor
        descriptionLabel.font = NSFont.systemFont(ofSize: 12)
        descriptionLabel.autoresizingMask = [.width]
        contentView.addSubview(descriptionLabel)
        
        yPos -= 50
        
        permissionStatusLabel = NSTextField(labelWithString: "")
        permissionStatusLabel.frame = NSRect(x: 20, y: yPos, width: contentView.bounds.width - 160, height: 20)
        permissionStatusLabel.font = NSFont.systemFont(ofSize: 12)
        permissionStatusLabel.autoresizingMask = [.width]
        contentView.addSubview(permissionStatusLabel)
        
        permissionButton = NSButton(title: "Set Up…", target: self, action: #selector(requestPermission))
        permissionButton.frame = NSRect(x: contentView.bounds.width - 140, y: yPos - 3, width: 120, height: 25)
        permissionButton.bezelStyle = .rounded
        permissionButton.autoresizingMask = [.minXMargin]
        contentView.addSubview(permissionButton)
        
        updatePermissionStatus()
        
        yPos -= 35
        
        scrollView = NSScrollView(frame: NSRect(x: 20, y: 60, width: contentView.bounds.width - 40, height: yPos - 70))
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder
        scrollView.autoresizingMask = [.width, .height]
        
        tableView = NSTableView()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.allowsMultipleSelection = false
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.rowHeight = 28
        
        let enabledColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("enabled"))
        enabledColumn.title = ""
        enabledColumn.width = 30
        enabledColumn.minWidth = 30
        enabledColumn.maxWidth = 30
        tableView.addTableColumn(enabledColumn)
        
        let triggerColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("trigger"))
        triggerColumn.title = "Trigger"
        triggerColumn.width = 120
        triggerColumn.minWidth = 80
        tableView.addTableColumn(triggerColumn)
        
        let replacementColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("replacement"))
        replacementColumn.title = "Replacement"
        replacementColumn.width = 250
        replacementColumn.minWidth = 150
        tableView.addTableColumn(replacementColumn)

        let groupColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("group"))
        groupColumn.title = "Group"
        groupColumn.width = 100
        groupColumn.minWidth = 80
        tableView.addTableColumn(groupColumn)
        
        scrollView.documentView = tableView
        contentView.addSubview(scrollView)
        
        addButton = NSButton(title: "Add", target: self, action: #selector(addSnippet))
        addButton.frame = NSRect(x: 20, y: 20, width: 80, height: 30)
        addButton.bezelStyle = .rounded
        contentView.addSubview(addButton)
        
        removeButton = NSButton(title: "Remove", target: self, action: #selector(removeSnippet))
        removeButton.frame = NSRect(x: 110, y: 20, width: 80, height: 30)
        removeButton.bezelStyle = .rounded
        removeButton.isEnabled = false
        contentView.addSubview(removeButton)
        
        editButton = NSButton(title: "Edit", target: self, action: #selector(editSnippet))
        editButton.frame = NSRect(x: 200, y: 20, width: 80, height: 30)
        editButton.bezelStyle = .rounded
        editButton.isEnabled = false
        contentView.addSubview(editButton)
        
        let loadDefaultsButton = NSButton(title: "Load Defaults", target: self, action: #selector(loadDefaultSnippets))
        loadDefaultsButton.frame = NSRect(x: 290, y: 20, width: 110, height: 30)
        loadDefaultsButton.bezelStyle = .rounded
        contentView.addSubview(loadDefaultsButton)
        
        let importButton = NSButton(title: "Import…", target: self, action: #selector(importSnippets))
        importButton.frame = NSRect(x: contentView.bounds.width - 190, y: 20, width: 80, height: 30)
        importButton.bezelStyle = .rounded
        importButton.autoresizingMask = [.minXMargin]
        contentView.addSubview(importButton)
        
        let exportButton = NSButton(title: "Export…", target: self, action: #selector(exportSnippets))
        exportButton.frame = NSRect(x: contentView.bounds.width - 100, y: 20, width: 80, height: 30)
        exportButton.bezelStyle = .rounded
        exportButton.autoresizingMask = [.minXMargin]
        contentView.addSubview(exportButton)
    }
    
    private func loadSnippets() {
        snippets = TextExpanderManager.shared.getAllSnippets()
        tableView.reloadData()
    }
    
    private func updatePermissionStatus() {
        let state = TextExpanderRuntimeController.shared.state
        enabledCheckbox.state = state == .running ? .on : .off
        switch state {
        case .running:
            permissionStatusLabel.stringValue = "✓ Enabled and running"
            permissionStatusLabel.textColor = .systemGreen
            permissionButton.isHidden = true
        case .needsPermission(let missing):
            let names = missing.map(\.displayName).sorted().joined(separator: " and ")
            permissionStatusLabel.stringValue = "Setup needed: \(names)"
            permissionStatusLabel.textColor = .secondaryLabelColor
            permissionButton.isHidden = false
        case .disabled:
            permissionStatusLabel.stringValue = "Ready to enable"
            permissionStatusLabel.textColor = .secondaryLabelColor
            permissionButton.isHidden = true
        }
    }
    
    // MARK: - Actions
    
    @objc private func toggleEnabled(_ sender: NSButton) {
        let enabled = sender.state == .on
        let state = TextExpanderRuntimeController.shared.setDesiredEnabled(enabled)
        updatePermissionStatus()
        if case .needsPermission = state {
            InputMonitoringPermissions.showSetupAlert()
        }
    }
    
    @objc private func requestPermission() {
        InputMonitoringPermissions.showSetupAlert()
    }
    
    @objc private func addSnippet() {
        showSnippetEditor(snippet: nil)
    }
    
    @objc private func removeSnippet() {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0 && selectedRow < snippets.count else { return }
        
        let snippet = snippets[selectedRow]
        
        let alert = NSAlert()
        alert.messageText = "Delete Snippet"
        alert.informativeText = "Are you sure you want to delete the snippet '\(snippet.trigger)'?"
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        
        if alert.runModal() == .alertFirstButtonReturn {
            _ = TextExpanderManager.shared.removeSnippet(id: snippet.id)
            loadSnippets()
        }
    }
    
    @objc private func editSnippet() {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0 && selectedRow < snippets.count else {
            let alert = NSAlert()
            alert.messageText = "No Snippet Selected"
            alert.informativeText = "Please select a snippet to edit."
            alert.alertStyle = .informational
            alert.runModal()
            return
        }
        
        showSnippetEditor(snippet: snippets[selectedRow])
    }
    
    @objc private func loadDefaultSnippets() {
        let count = TextExpanderManager.shared.mergeDefaultSnippets()
        loadSnippets()
        
        let alert = NSAlert()
        if count > 0 {
            alert.messageText = "Defaults Loaded"
            alert.informativeText = "Added \(count) default snippet\(count == 1 ? "" : "s"). Existing snippets were preserved."
        } else {
            alert.messageText = "No New Snippets"
            alert.informativeText = "All default snippets already exist."
        }
        alert.alertStyle = .informational
        alert.runModal()
    }
    
    @objc private func importSnippets() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let data = try Data(contentsOf: url)
                let count = TextExpanderManager.shared.importSnippets(from: data, merge: true)
                loadSnippets()
                
                let alert = NSAlert()
                alert.messageText = "Import Complete"
                alert.informativeText = "Imported \(count) snippets."
                alert.alertStyle = .informational
                alert.runModal()
            } catch {
                let alert = NSAlert()
                alert.messageText = "Import Failed"
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .warning
                alert.runModal()
            }
        }
    }
    
    @objc private func exportSnippets() {
        guard let data = TextExpanderManager.shared.exportSnippets() else {
            let alert = NSAlert()
            alert.messageText = "Export Failed"
            alert.informativeText = "Could not export snippets."
            alert.alertStyle = .warning
            alert.runModal()
            return
        }
        
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "text-expander-snippets.json"
        
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try data.write(to: url)
                
                let alert = NSAlert()
                alert.messageText = "Export Complete"
                alert.informativeText = "Snippets exported successfully."
                alert.alertStyle = .informational
                alert.runModal()
            } catch {
                let alert = NSAlert()
                alert.messageText = "Export Failed"
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .warning
                alert.runModal()
            }
        }
    }
    
    private func showSnippetEditor(snippet: TextExpansionSnippet?) {
        let alert = NSAlert()
        alert.messageText = snippet == nil ? "Add Snippet" : "Edit Snippet"
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        
        let accessoryView = NSView(frame: NSRect(x: 0, y: 0, width: 350, height: 160))
        
        let triggerLabel = NSTextField(labelWithString: "Trigger:")
        triggerLabel.frame = NSRect(x: 0, y: 110, width: 80, height: 20)
        accessoryView.addSubview(triggerLabel)
        
        let triggerField = NSTextField(frame: NSRect(x: 85, y: 108, width: 265, height: 24))
        triggerField.stringValue = snippet?.trigger ?? ":"
        triggerField.placeholderString = ":email"
        accessoryView.addSubview(triggerField)
        
        let replacementLabel = NSTextField(labelWithString: "Replacement:")
        replacementLabel.frame = NSRect(x: 0, y: 75, width: 80, height: 20)
        accessoryView.addSubview(replacementLabel)
        
        let replacementScrollView = NSScrollView(frame: NSRect(x: 85, y: 40, width: 265, height: 80))
        replacementScrollView.hasVerticalScroller = true
        replacementScrollView.borderType = .bezelBorder
        
        let replacementTextView = NSTextView(frame: NSRect(x: 0, y: 0, width: 265, height: 80))
        replacementTextView.isEditable = true
        replacementTextView.isRichText = false
        replacementTextView.font = NSFont.systemFont(ofSize: 13)
        replacementTextView.string = snippet?.replacement ?? ""
        replacementScrollView.documentView = replacementTextView
        accessoryView.addSubview(replacementScrollView)

        let groupLabel = NSTextField(labelWithString: "Group:")
        groupLabel.frame = NSRect(x: 0, y: 10, width: 80, height: 20)
        accessoryView.addSubview(groupLabel)

        let groupField = NSTextField(frame: NSRect(x: 85, y: 8, width: 265, height: 24))
        groupField.stringValue = snippet?.groupName ?? ""
        groupField.placeholderString = "Work"
        accessoryView.addSubview(groupField)

        let hintLabel = NSTextField(labelWithString: "Use {date}, {time}, {cursor}, {field:Name}, {popup:Day:Mon|Tue|Wed}")
        hintLabel.frame = NSRect(x: 85, y: -10, width: 265, height: 16)
        hintLabel.font = NSFont.systemFont(ofSize: 10)
        hintLabel.textColor = .secondaryLabelColor
        accessoryView.addSubview(hintLabel)
        
        alert.accessoryView = accessoryView
        
        window?.makeFirstResponder(triggerField)
        
        while alert.runModal() == .alertFirstButtonReturn {
            let trigger = triggerField.stringValue.trimmingCharacters(in: .whitespaces)
            let replacement = replacementTextView.string
            let groupName = groupField.stringValue.trimmingCharacters(in: .whitespaces)
            let normalizedGroup = groupName.isEmpty ? nil : groupName
            
            guard TextExpanderManager.shared.validateTrigger(trigger) else {
                let errorAlert = NSAlert()
                errorAlert.messageText = "Invalid Trigger"
                errorAlert.informativeText = "Trigger must be at least 2 characters and cannot contain newlines or tabs."
                errorAlert.alertStyle = .warning
                errorAlert.runModal()
                continue
            }
            
            guard TextExpanderManager.shared.validateReplacement(replacement) else {
                let errorAlert = NSAlert()
                errorAlert.messageText = "Invalid Replacement"
                errorAlert.informativeText = "Replacement text cannot be empty."
                errorAlert.alertStyle = .warning
                errorAlert.runModal()
                continue
            }
            
            let saved: Bool
            if let existingSnippet = snippet {
                let updated = existingSnippet.withUpdate(
                    trigger: trigger,
                    replacement: replacement,
                    groupName: .some(normalizedGroup)
                )
                saved = TextExpanderManager.shared.updateSnippet(updated)
            } else {
                let newSnippet = TextExpansionSnippet(
                    trigger: trigger,
                    replacement: replacement,
                    groupName: normalizedGroup
                )
                saved = TextExpanderManager.shared.addSnippet(newSnippet)
            }
            if !saved {
                let errorAlert = NSAlert()
                errorAlert.messageText = snippet == nil ? "Add Failed" : "Update Failed"
                errorAlert.informativeText = "A snippet with this trigger already exists."
                errorAlert.alertStyle = .warning
                errorAlert.runModal()
                continue
            }
            
            loadSnippets()
            break
        }
    }
    
    // MARK: - NSTableViewDataSource
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return snippets.count
    }
    
    // MARK: - NSTableViewDelegate
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < snippets.count else { return nil }
        let snippet = snippets[row]
        
        let identifier = tableColumn?.identifier.rawValue ?? ""
        
        switch identifier {
        case "enabled":
            let checkbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(toggleSnippetEnabled(_:)))
            checkbox.state = snippet.isEnabled ? .on : .off
            checkbox.tag = row
            checkbox.setAccessibilityLabel("Enable snippet \(snippet.trigger)")
            return checkbox
            
        case "trigger":
            let textField = NSTextField(labelWithString: snippet.trigger)
            textField.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)
            textField.textColor = snippet.isEnabled ? .labelColor : .secondaryLabelColor
            return textField
            
        case "replacement":
            let preview = snippet.replacement.replacingOccurrences(of: "\n", with: " ↵ ")
            let truncated = preview.count > 50 ? String(preview.prefix(50)) + "…" : preview
            let textField = NSTextField(labelWithString: truncated)
            textField.textColor = snippet.isEnabled ? .labelColor : .secondaryLabelColor
            return textField

        case "group":
            let textField = NSTextField(labelWithString: snippet.groupName ?? "Ungrouped")
            textField.textColor = snippet.isEnabled ? .secondaryLabelColor : .tertiaryLabelColor
            return textField
            
        default:
            return nil
        }
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        let hasSelection = tableView.selectedRow >= 0
        removeButton.isEnabled = hasSelection
        editButton.isEnabled = hasSelection
    }
    
    @objc private func toggleSnippetEnabled(_ sender: NSButton) {
        let row = sender.tag
        guard row >= 0 && row < snippets.count else { return }
        
        _ = TextExpanderManager.shared.toggleSnippetEnabled(id: snippets[row].id)
        loadSnippets()
    }
}
