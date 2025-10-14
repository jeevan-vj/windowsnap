import AppKit
import Foundation

class ClipboardHistoryWindow: NSWindow {
    private var tableView: NSTableView!
    private var scrollView: NSScrollView!
    private var searchField: NSSearchField!
    private var emptyLabel: NSTextField!
    private var clearButton: NSButton!
    
    private var history: [ClipboardHistoryItem] = []
    private var filteredHistory: [ClipboardHistoryItem] = []
    private var selectedIndex: Int = 0
    private var previousApp: NSRunningApplication?
    
    private let windowWidth: CGFloat = 400
    private let windowHeight: CGFloat = 500
    private let rowHeight: CGFloat = 60
    
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        setupWindow()
    }
    
    convenience init() {
        let contentRect = NSRect(x: 0, y: 0, width: 400, height: 500)
        let styleMask: NSWindow.StyleMask = [.titled, .closable, .resizable]
        self.init(contentRect: contentRect, styleMask: styleMask, backing: .buffered, defer: false)
    }
    
    private func setupWindow() {
        title = "Clipboard History"
        
        // Configure window behavior
        level = .floating
        isMovableByWindowBackground = true
        backgroundColor = NSColor.controlBackgroundColor
        
        // Create content view
        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight))
        self.contentView = contentView
        
        setupUI()
        setupKeyboardHandling()
        loadHistory()
    }
    
    private func setupUI() {
        guard let contentView = contentView else { return }
        
        // Search field at the top
        searchField = NSSearchField(frame: NSRect(x: 20, y: windowHeight - 60, width: windowWidth - 40, height: 30))
        searchField.placeholderString = "Search clipboard history..."
        searchField.target = self
        searchField.action = #selector(searchFieldChanged(_:))
        contentView.addSubview(searchField)
        
        // Clear button
        clearButton = NSButton(frame: NSRect(x: windowWidth - 100, y: windowHeight - 100, width: 80, height: 25))
        clearButton.title = "Clear All"
        clearButton.bezelStyle = .rounded
        clearButton.target = self
        clearButton.action = #selector(clearHistory(_:))
        contentView.addSubview(clearButton)
        
        // Table view for history
        let tableFrame = NSRect(x: 20, y: 20, width: windowWidth - 40, height: windowHeight - 120)
        
        scrollView = NSScrollView(frame: tableFrame)
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder
        
        tableView = NSTableView(frame: scrollView.bounds)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = rowHeight
        tableView.intercellSpacing = NSSize(width: 0, height: 1)
        tableView.selectionHighlightStyle = .regular
        tableView.allowsEmptySelection = false
        tableView.target = self
        tableView.doubleAction = #selector(handleDoubleClick(_:))
        
        // Create table column
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("ClipboardItem"))
        column.title = ""
        column.width = tableFrame.width - 20
        tableView.addTableColumn(column)
        
        scrollView.documentView = tableView
        contentView.addSubview(scrollView)
        
        // Empty state label
        emptyLabel = NSTextField(frame: NSRect(x: 50, y: windowHeight/2 - 20, width: windowWidth - 100, height: 40))
        emptyLabel.stringValue = "No clipboard history\n\nCopy some text to get started!"
        emptyLabel.alignment = .center
        emptyLabel.textColor = .secondaryLabelColor
        emptyLabel.font = NSFont.systemFont(ofSize: 14)
        emptyLabel.isBezeled = false
        emptyLabel.isEditable = false
        emptyLabel.backgroundColor = .clear
        contentView.addSubview(emptyLabel)
        
        // Auto-layout setup for resizing
        searchField.translatesAutoresizingMaskIntoConstraints = false
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Search field
            searchField.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            searchField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            searchField.trailingAnchor.constraint(equalTo: clearButton.leadingAnchor, constant: -10),
            searchField.heightAnchor.constraint(equalToConstant: 30),
            
            // Clear button
            clearButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            clearButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            clearButton.widthAnchor.constraint(equalToConstant: 80),
            clearButton.heightAnchor.constraint(equalToConstant: 25),
            
            // Scroll view
            scrollView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 20),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            
            // Empty label
            emptyLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }
    
    private func setupKeyboardHandling() {
        // Handle keyboard events for navigation and selection
        acceptsMouseMovedEvents = true
        makeFirstResponder(tableView)
    }
    
    // MARK: - Public Methods
    
    func showWindow() {
        // Capture the previously active application
        previousApp = NSWorkspace.shared.frontmostApplication
        
        loadHistory()
        center()
        makeKeyAndOrderFront(nil)
        searchField.becomeFirstResponder()
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func hideWindow() {
        close()
    }
    
    // MARK: - Private Methods
    
    private func loadHistory() {
        history = ClipboardManager.shared.getHistory()
        applySearchFilter()
        updateUI()
    }
    
    private func applySearchFilter() {
        let searchText = searchField.stringValue.lowercased()
        
        if searchText.isEmpty {
            filteredHistory = history
        } else {
            filteredHistory = history.filter { item in
                item.preview.lowercased().contains(searchText) ||
                item.content.lowercased().contains(searchText) ||
                item.type.displayName.lowercased().contains(searchText)
            }
        }
        
        selectedIndex = 0
        tableView.reloadData()
        
        if !filteredHistory.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
    }
    
    private func updateUI() {
        let hasItems = !filteredHistory.isEmpty
        
        emptyLabel.isHidden = hasItems
        tableView.isHidden = !hasItems
        scrollView.isHidden = !hasItems
        clearButton.isEnabled = !history.isEmpty
        
        if hasItems {
            tableView.reloadData()
            if selectedIndex < filteredHistory.count {
                tableView.selectRowIndexes(IndexSet(integer: selectedIndex), byExtendingSelection: false)
            }
        }
    }
    
    private func copySelectedItem() {
        guard selectedIndex >= 0 && selectedIndex < filteredHistory.count else { return }
        
        let selectedItem = filteredHistory[selectedIndex]
        let previousAppToRestore = previousApp
        
        // Copy to clipboard
        ClipboardManager.shared.copyToClipboard(selectedItem)
        print("📋 Copied: \(selectedItem.preview)")
        
        // Close window immediately
        hideWindow()
        
        // Restore focus to previous app and simulate paste
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Restore focus to the previous application
            if let app = previousAppToRestore {
                app.activate(options: .activateIgnoringOtherApps)
            }
            
            // Wait a bit more for focus to settle, then simulate paste
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.simulatePaste()
            }
        }
    }
    
    private func simulatePaste() {
        // Simulate Cmd+V keypress using CGEvent
        let source = CGEventSource(stateID: .hidSystemState)
        
        // Key down for 'v' with command modifier
        if let keyDownEvent = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) {
            keyDownEvent.flags = .maskCommand
            keyDownEvent.post(tap: .cghidEventTap)
        }
        
        // Key up for 'v'
        if let keyUpEvent = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false) {
            keyUpEvent.flags = .maskCommand
            keyUpEvent.post(tap: .cghidEventTap)
        }
        
        print("📋 Simulated paste command")
    }
    
    // MARK: - Actions
    
    @objc private func handleDoubleClick(_ sender: NSTableView) {
        let clickedRow = sender.clickedRow
        if clickedRow >= 0 && clickedRow < filteredHistory.count {
            selectedIndex = clickedRow
            copySelectedItem()
        }
    }
    
    @objc private func searchFieldChanged(_ sender: NSSearchField) {
        applySearchFilter()
    }
    
    @objc private func clearHistory(_ sender: NSButton) {
        let alert = NSAlert()
        alert.messageText = "Clear Clipboard History"
        alert.informativeText = "Are you sure you want to clear all clipboard history? This action cannot be undone."
        alert.addButton(withTitle: "Clear")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            ClipboardManager.shared.clearHistory()
            loadHistory()
        }
    }
    
    // MARK: - Key Event Handling
    
    override func keyDown(with event: NSEvent) {
        let key = event.keyCode
        
        switch key {
        case 36, 76: // Enter or Return
            copySelectedItem()
            
        case 53: // Escape
            hideWindow()
            
        case 125: // Down arrow
            if selectedIndex < filteredHistory.count - 1 {
                selectedIndex += 1
                tableView.selectRowIndexes(IndexSet(integer: selectedIndex), byExtendingSelection: false)
                tableView.scrollRowToVisible(selectedIndex)
            }
            
        case 126: // Up arrow
            if selectedIndex > 0 {
                selectedIndex -= 1
                tableView.selectRowIndexes(IndexSet(integer: selectedIndex), byExtendingSelection: false)
                tableView.scrollRowToVisible(selectedIndex)
            }
            
        default:
            super.keyDown(with: event)
        }
    }
}

// MARK: - NSTableViewDataSource

extension ClipboardHistoryWindow: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return filteredHistory.count
    }
}

// MARK: - NSTableViewDelegate

extension ClipboardHistoryWindow: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < filteredHistory.count else { return nil }
        
        let item = filteredHistory[row]
        let cellView = ClipboardHistoryCellView()
        cellView.configure(with: item)
        
        return cellView
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        selectedIndex = tableView.selectedRow
    }
    
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        selectedIndex = row
        return true
    }
}

// MARK: - Custom Cell View

class ClipboardHistoryCellView: NSView {
    private var iconImageView: NSImageView!
    private var typeLabel: NSTextField!
    private var previewLabel: NSTextField!
    private var timestampLabel: NSTextField!
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        // Icon
        iconImageView = NSImageView(frame: NSRect(x: 10, y: 20, width: 20, height: 20))
        addSubview(iconImageView)
        
        // Type label
        typeLabel = NSTextField(frame: NSRect(x: 40, y: 35, width: 100, height: 16))
        typeLabel.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        typeLabel.textColor = .secondaryLabelColor
        typeLabel.isBezeled = false
        typeLabel.isEditable = false
        typeLabel.backgroundColor = .clear
        addSubview(typeLabel)
        
        // Preview label
        previewLabel = NSTextField(frame: NSRect(x: 40, y: 15, width: 300, height: 18))
        previewLabel.font = NSFont.systemFont(ofSize: 13)
        previewLabel.textColor = .labelColor
        previewLabel.isBezeled = false
        previewLabel.isEditable = false
        previewLabel.backgroundColor = .clear
        previewLabel.lineBreakMode = .byTruncatingTail
        addSubview(previewLabel)
        
        // Timestamp label
        timestampLabel = NSTextField(frame: NSRect(x: 40, y: 2, width: 200, height: 12))
        timestampLabel.font = NSFont.systemFont(ofSize: 9)
        timestampLabel.textColor = .tertiaryLabelColor
        timestampLabel.isBezeled = false
        timestampLabel.isEditable = false
        timestampLabel.backgroundColor = .clear
        addSubview(timestampLabel)
        
        // Auto-layout
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        typeLabel.translatesAutoresizingMaskIntoConstraints = false
        previewLabel.translatesAutoresizingMaskIntoConstraints = false
        timestampLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            iconImageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            iconImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 20),
            iconImageView.heightAnchor.constraint(equalToConstant: 20),
            
            typeLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 10),
            typeLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            typeLabel.widthAnchor.constraint(equalToConstant: 100),
            
            previewLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 10),
            previewLabel.topAnchor.constraint(equalTo: typeLabel.bottomAnchor, constant: 2),
            previewLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            
            timestampLabel.leadingAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 10),
            timestampLabel.topAnchor.constraint(equalTo: previewLabel.bottomAnchor, constant: 2),
            timestampLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10)
        ])
    }
    
    func configure(with item: ClipboardHistoryItem) {
        // Set icon
        iconImageView.image = NSImage(systemSymbolName: item.type.icon, accessibilityDescription: item.type.displayName)
        iconImageView.contentTintColor = .controlAccentColor
        
        // Set labels
        typeLabel.stringValue = item.type.displayName
        previewLabel.stringValue = item.preview
        
        // Format timestamp
        let formatter = DateFormatter()
        let now = Date()
        let timeInterval = now.timeIntervalSince(item.timestamp)
        
        if timeInterval < 60 {
            timestampLabel.stringValue = "Just now"
        } else if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            timestampLabel.stringValue = "\(minutes) minute\(minutes == 1 ? "" : "s") ago"
        } else if timeInterval < 86400 {
            let hours = Int(timeInterval / 3600)
            timestampLabel.stringValue = "\(hours) hour\(hours == 1 ? "" : "s") ago"
        } else {
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            timestampLabel.stringValue = formatter.string(from: item.timestamp)
        }
    }
}

