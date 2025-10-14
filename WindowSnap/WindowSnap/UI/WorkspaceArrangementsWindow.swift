import Cocoa

/// Workspace arrangements management window
class WorkspaceArrangementsWindow: NSWindow {
    
    private var tableView: NSTableView!
    private var scrollView: NSScrollView!
    private var workspaceManager = WorkspaceManager.shared
    private var arrangements: [WorkspaceArrangement] = []
    
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 600, height: 500), 
                   styleMask: [.titled, .closable, .resizable], 
                   backing: .buffered, 
                   defer: false)
        
        self.title = "Workspace Arrangements"
        self.center()
        setupUI()
        loadArrangements()
    }
    
    private func setupUI() {
        let contentView = NSView()
        self.contentView = contentView
        
        // Main stack view
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stackView)
        
        // Header
        let headerLabel = NSTextField(labelWithString: "Workspace Arrangements")
        headerLabel.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        stackView.addArrangedSubview(headerLabel)
        
        let descriptionLabel = NSTextField(labelWithString: "Save and restore complete desktop layouts with one click.")
        descriptionLabel.font = NSFont.systemFont(ofSize: 13)
        descriptionLabel.textColor = .secondaryLabelColor
        stackView.addArrangedSubview(descriptionLabel)
        
        // Toolbar
        let toolbar = createToolbar()
        stackView.addArrangedSubview(toolbar)
        
        // Table view
        setupTableView()
        stackView.addArrangedSubview(scrollView)
        
        // Constraints
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }
    
    private func createToolbar() -> NSView {
        let toolbar = NSView()
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        
        let captureButton = NSButton(title: "Capture Current", target: self, action: #selector(captureCurrentWorkspace))
        captureButton.bezelStyle = .rounded
        captureButton.keyEquivalent = "\r"
        
        let restoreButton = NSButton(title: "Restore", target: self, action: #selector(restoreSelectedWorkspace))
        restoreButton.bezelStyle = .rounded
        
        let editButton = NSButton(title: "Edit", target: self, action: #selector(editSelectedWorkspace))
        editButton.bezelStyle = .rounded
        
        let deleteButton = NSButton(title: "Delete", target: self, action: #selector(deleteSelectedWorkspace))
        deleteButton.bezelStyle = .rounded
        
        let refreshButton = NSButton(title: "Refresh", target: self, action: #selector(refreshArrangements))
        refreshButton.bezelStyle = .rounded
        
        // Layout buttons
        let stackView = NSStackView(views: [captureButton, restoreButton, editButton, deleteButton, refreshButton])
        stackView.orientation = .horizontal
        stackView.spacing = 8
        stackView.translatesAutoresizingMaskIntoConstraints = false
        toolbar.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.centerYAnchor.constraint(equalTo: toolbar.centerYAnchor),
            stackView.leadingAnchor.constraint(equalTo: toolbar.leadingAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: 32)
        ])
        
        return toolbar
    }
    
    private func setupTableView() {
        // Create table view
        tableView = NSTableView()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.headerView = nil
        tableView.allowsColumnReordering = false
        tableView.allowsColumnResizing = true
        tableView.allowsMultipleSelection = false
        tableView.rowSizeStyle = .medium
        tableView.intercellSpacing = NSSize(width: 0, height: 4)
        
        // Create columns
        let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameColumn.title = "Name"
        nameColumn.width = 200
        nameColumn.minWidth = 150
        tableView.addTableColumn(nameColumn)
        
        let descriptionColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("description"))
        descriptionColumn.title = "Description"
        descriptionColumn.width = 200
        descriptionColumn.minWidth = 150
        tableView.addTableColumn(descriptionColumn)
        
        let shortcutColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("shortcut"))
        shortcutColumn.title = "Shortcut"
        shortcutColumn.width = 100
        shortcutColumn.minWidth = 80
        tableView.addTableColumn(shortcutColumn)
        
        let lastUsedColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("lastUsed"))
        lastUsedColumn.title = "Last Used"
        lastUsedColumn.width = 100
        lastUsedColumn.minWidth = 80
        tableView.addTableColumn(lastUsedColumn)
        
        // Create scroll view
        scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 300)
        ])
    }
    
    private func loadArrangements() {
        arrangements = workspaceManager.getAllArrangements()
        tableView.reloadData()
    }
    
    // MARK: - Actions
    
    @objc private func captureCurrentWorkspace() {
        let dialog = WorkspaceDialog(mode: .create)
        dialog.onSave = { [weak self] name, shortcut in
            let _ = self?.workspaceManager.captureCurrentWorkspace(name: name, shortcut: shortcut)
            self?.loadArrangements()
        }
        dialog.showModal(for: self)
    }
    
    @objc private func restoreSelectedWorkspace() {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0, selectedRow < arrangements.count else {
            showAlert(title: "No Selection", message: "Please select a workspace arrangement to restore.")
            return
        }
        
        let arrangement = arrangements[selectedRow]
        
        let alert = NSAlert()
        alert.messageText = "Restore Workspace?"
        alert.informativeText = "This will restore '\(arrangement.name)' and may move or launch applications. This action can be undone."
        alert.addButton(withTitle: "Restore")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .informational
        
        alert.beginSheetModal(for: self) { [weak self] response in
            if response == .alertFirstButtonReturn {
                self?.workspaceManager.restoreWorkspace(arrangement)
                self?.loadArrangements()
            }
        }
    }
    
    @objc private func editSelectedWorkspace() {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0, selectedRow < arrangements.count else {
            showAlert(title: "No Selection", message: "Please select a workspace arrangement to edit.")
            return
        }
        
        let arrangement = arrangements[selectedRow]
        let dialog = WorkspaceDialog(mode: .edit, arrangement: arrangement)
        dialog.onSave = { [weak self] name, shortcut in
            var updatedArrangement = arrangement
            // Create updated arrangement with new name/shortcut
            // For now, we'll just print since the model doesn't have an update method for name/shortcut
            print("Would update arrangement: \(name), shortcut: \(shortcut ?? "none")")
            self?.loadArrangements()
        }
        dialog.showModal(for: self)
    }
    
    @objc private func deleteSelectedWorkspace() {
        let selectedRow = tableView.selectedRow
        guard selectedRow >= 0, selectedRow < arrangements.count else {
            showAlert(title: "No Selection", message: "Please select a workspace arrangement to delete.")
            return
        }
        
        let arrangement = arrangements[selectedRow]
        
        let alert = NSAlert()
        alert.messageText = "Delete Workspace Arrangement?"
        alert.informativeText = "This will permanently delete '\(arrangement.name)'. This action cannot be undone."
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        
        alert.beginSheetModal(for: self) { [weak self] response in
            if response == .alertFirstButtonReturn {
                self?.workspaceManager.removeArrangement(id: arrangement.id)
                self?.loadArrangements()
            }
        }
    }
    
    @objc private func refreshArrangements() {
        loadArrangements()
    }
    
    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

// MARK: - NSTableViewDataSource

extension WorkspaceArrangementsWindow: NSTableViewDataSource {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return arrangements.count
    }
}

// MARK: - NSTableViewDelegate

extension WorkspaceArrangementsWindow: NSTableViewDelegate {
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < arrangements.count else { return nil }
        
        let arrangement = arrangements[row]
        let identifier = tableColumn?.identifier
        
        let cellView = NSTableCellView()
        let textField = NSTextField()
        textField.isEditable = false
        textField.isBordered = false
        textField.backgroundColor = .clear
        textField.font = NSFont.systemFont(ofSize: 13)
        
        switch identifier?.rawValue {
        case "name":
            textField.stringValue = arrangement.name
            textField.font = NSFont.systemFont(ofSize: 13, weight: .medium)
            
        case "description":
            textField.stringValue = arrangement.displayDescription
            textField.textColor = .secondaryLabelColor
            
        case "shortcut":
            textField.stringValue = arrangement.shortcut ?? "—"
            textField.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
            
        case "lastUsed":
            if let lastUsed = arrangement.lastUsed {
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                formatter.timeStyle = .none
                textField.stringValue = formatter.string(from: lastUsed)
            } else {
                textField.stringValue = "Never"
            }
            textField.textColor = .secondaryLabelColor
            
        default:
            textField.stringValue = ""
        }
        
        cellView.addSubview(textField)
        textField.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 4),
            textField.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -4),
            textField.centerYAnchor.constraint(equalTo: cellView.centerYAnchor)
        ])
        
        return cellView
    }
    
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 32
    }
}

// MARK: - Workspace Dialog

class WorkspaceDialog: NSWindow {
    
    enum Mode {
        case create
        case edit
    }
    
    private let mode: Mode
    private let arrangement: WorkspaceArrangement?
    private var nameField: NSTextField!
    private var shortcutField: NSTextField!
    
    var onSave: ((String, String?) -> Void)?
    
    init(mode: Mode, arrangement: WorkspaceArrangement? = nil) {
        self.mode = mode
        self.arrangement = arrangement
        
        super.init(contentRect: NSRect(x: 0, y: 0, width: 400, height: 200), 
                   styleMask: [.titled, .closable], 
                   backing: .buffered, 
                   defer: false)
        
        self.title = mode == .create ? "Capture Workspace" : "Edit Workspace"
        self.center()
        setupUI()
    }
    
    private func setupUI() {
        let contentView = NSView()
        self.contentView = contentView
        
        // Stack view
        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stackView)
        
        // Header
        let headerText = mode == .create ? 
            "Enter a name for this workspace arrangement:" : 
            "Edit workspace arrangement details:"
        let headerLabel = NSTextField(labelWithString: headerText)
        headerLabel.font = NSFont.systemFont(ofSize: 13)
        stackView.addArrangedSubview(headerLabel)
        
        // Name field
        let nameLabel = NSTextField(labelWithString: "Name:")
        nameLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        stackView.addArrangedSubview(nameLabel)
        
        nameField = NSTextField()
        nameField.stringValue = arrangement?.name ?? ""
        nameField.placeholderString = "e.g., Development Setup"
        stackView.addArrangedSubview(nameField)
        
        // Shortcut field
        let shortcutLabel = NSTextField(labelWithString: "Keyboard Shortcut (optional):")
        shortcutLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        stackView.addArrangedSubview(shortcutLabel)
        
        shortcutField = NSTextField()
        shortcutField.stringValue = arrangement?.shortcut ?? ""
        shortcutField.placeholderString = "e.g., Cmd+Shift+1"
        stackView.addArrangedSubview(shortcutField)
        
        // Buttons
        let buttonStackView = NSStackView()
        buttonStackView.orientation = .horizontal
        buttonStackView.spacing = 8
        
        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancel))
        cancelButton.bezelStyle = .rounded
        
        let saveButtonTitle = mode == .create ? "Capture" : "Save"
        let saveButton = NSButton(title: saveButtonTitle, target: self, action: #selector(save))
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        
        buttonStackView.addArrangedSubview(cancelButton)
        buttonStackView.addArrangedSubview(saveButton)
        stackView.addArrangedSubview(buttonStackView)
        
        // Constraints
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            
            nameField.widthAnchor.constraint(equalTo: stackView.widthAnchor),
            shortcutField.widthAnchor.constraint(equalTo: stackView.widthAnchor)
        ])
        
        // Focus on name field
        DispatchQueue.main.async {
            self.nameField.becomeFirstResponder()
        }
    }
    
    @objc private func cancel() {
        close()
    }
    
    @objc private func save() {
        let name = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let shortcut = shortcutField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !name.isEmpty else {
            let alert = NSAlert()
            alert.messageText = "Name Required"
            alert.informativeText = "Please enter a name for the workspace arrangement."
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }
        
        let finalShortcut = shortcut.isEmpty ? nil : shortcut
        onSave?(name, finalShortcut)
        close()
    }
    
    func showModal(for parentWindow: NSWindow) {
        parentWindow.beginSheet(self)
    }
}
