import AppKit
import Foundation

class ClipboardHistoryWindow: NSWindow {
    private var tableView: NSTableView!
    private var scrollView: NSScrollView!
    private var searchField: NSSearchField!
    private var emptyLabel: NSTextField!
    private var clearButton: NSButton!
    private var clearButtonContainer: NSVisualEffectView!
    private var titleLabel: NSTextField!
    private var visualEffectView: NSVisualEffectView!
    
    private var history: [ClipboardHistoryItem] = []
    private var filteredHistory: [ClipboardHistoryItem] = []
    private var selectedIndex: Int = 0
    private var previousApp: NSRunningApplication?

    // Search debouncing
    private var searchWorkItem: DispatchWorkItem?
    private let searchDebounceInterval: TimeInterval = 0.3
    
    private let windowWidth: CGFloat = 400
    private let windowHeight: CGFloat = 500
    private let rowHeight: CGFloat = 72
    private let cornerRadius: CGFloat = 14
    
    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        setupWindow()
    }
    
    convenience init() {
        let contentRect = NSRect(x: 0, y: 0, width: 400, height: 500)
        let styleMask: NSWindow.StyleMask = [.titled, .closable, .resizable, .fullSizeContentView]
        self.init(contentRect: contentRect, styleMask: styleMask, backing: .buffered, defer: false)
    }

    deinit {
        // Remove all NotificationCenter observers
        NotificationCenter.default.removeObserver(self)
        print("📋 ClipboardHistoryWindow deallocated")
    }

    private func setupWindow() {
        // Hide default title bar for cleaner look
        title = ""
        titlebarAppearsTransparent = true
        
        // Configure window behavior
        level = .floating
        isMovableByWindowBackground = true
        backgroundColor = .clear
        
        // CRITICAL: Prevent window from being deallocated when closed
        // This allows us to reuse the window on subsequent shortcut presses
        isReleasedWhenClosed = false
        
        // Setup visual effect view for glass effect
        visualEffectView = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight))
        visualEffectView.material = .hudWindow
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = cornerRadius
        // Don't mask to bounds so shadow is visible
        visualEffectView.layer?.masksToBounds = false
        
        // Add shadow using layer properties on the visual effect view
        visualEffectView.layer?.shadowColor = NSColor.black.cgColor
        visualEffectView.layer?.shadowOpacity = 0.3
        visualEffectView.layer?.shadowOffset = CGSize(width: 0, height: -4)
        visualEffectView.layer?.shadowRadius = 20
        
        self.contentView = visualEffectView
        hasShadow = true
        
        setupUI()
        setupKeyboardHandling()
        loadHistory()
    }
    
    private func setupUI() {
        guard let contentView = visualEffectView else { return }
        
        // Custom title label
        titleLabel = NSTextField(labelWithString: "Clipboard History")
        titleLabel.font = NSFont.systemFont(ofSize: 20, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.alignment = .left
        titleLabel.setAccessibilityLabel("Clipboard History")
        titleLabel.setAccessibilityRole(.staticText)
        contentView.addSubview(titleLabel)
        
        // Search field - no container, integrated directly
        searchField = NSSearchField()
        searchField.placeholderString = "Search..."
        searchField.target = self
        searchField.action = #selector(searchFieldChanged(_:))
        searchField.focusRingType = .none
        searchField.wantsLayer = true
        searchField.font = NSFont.systemFont(ofSize: 13)
        searchField.backgroundColor = .clear
        searchField.isBordered = false
        searchField.isBezeled = false
        searchField.isEditable = true
        searchField.isSelectable = true
        searchField.isEnabled = true
        searchField.setAccessibilityLabel("Search clipboard history")
        searchField.setAccessibilityRole(.textField)
        searchField.setAccessibilityPlaceholderValue("Search...")
        
        // Use a custom cell subclass to fix text rect positioning
        // Create cell first, then assign to search field
        let customCell = CustomSearchFieldCell(textCell: "")
        customCell.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.3)
        customCell.isBezeled = false
        customCell.isBordered = false
        customCell.placeholderString = "Search..."
        customCell.target = self
        customCell.action = #selector(searchFieldChanged(_:))
        customCell.isEditable = true
        customCell.isSelectable = true
        customCell.isEnabled = true
        
        // Assign cell to search field - this must happen before other setup
        searchField.cell = customCell
        
        // Force the cell to recalculate its layout
        searchField.needsLayout = true
        
        // Add glowing border effect
        searchField.layer?.cornerRadius = 8
        searchField.layer?.borderWidth = 1.5
        searchField.layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.4).cgColor
        searchField.layer?.shadowColor = NSColor.controlAccentColor.cgColor
        searchField.layer?.shadowOpacity = 0.3
        searchField.layer?.shadowOffset = CGSize(width: 0, height: 0)
        searchField.layer?.shadowRadius = 4
        
        // Monitor focus to enhance glow
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(searchFieldDidBecomeFirstResponder),
            name: NSControl.textDidBeginEditingNotification,
            object: searchField
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(searchFieldDidResignFirstResponder),
            name: NSControl.textDidEndEditingNotification,
            object: searchField
        )
        
        contentView.addSubview(searchField)
        
        // Clear button container with glass effect
        clearButtonContainer = NSVisualEffectView()
        clearButtonContainer.material = .sidebar
        clearButtonContainer.blendingMode = .withinWindow
        clearButtonContainer.state = .active
        clearButtonContainer.wantsLayer = true
        clearButtonContainer.layer?.cornerRadius = 8
        clearButtonContainer.layer?.masksToBounds = true
        contentView.addSubview(clearButtonContainer)
        
        // Clear button with modern styling
        clearButton = NSButton()
        clearButton.title = "Clear All"
        clearButton.bezelStyle = .texturedRounded
        clearButton.target = self
        clearButton.action = #selector(clearHistory(_:))
        clearButton.wantsLayer = true
        clearButton.contentTintColor = .controlAccentColor
        clearButton.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        clearButton.isBordered = false
        clearButton.setAccessibilityLabel("Clear all clipboard history")
        clearButton.setAccessibilityRole(.button)
        clearButton.setAccessibilityHelp("Press Cmd+Backspace or click to clear all clipboard history")
        clearButtonContainer.addSubview(clearButton)
        
        // Table view for history
        scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.backgroundColor = .clear
        scrollView.drawsBackground = false
        scrollView.wantsLayer = true
        
        tableView = NSTableView()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = rowHeight
        tableView.intercellSpacing = NSSize(width: 0, height: 8)
        tableView.selectionHighlightStyle = .none
        tableView.allowsEmptySelection = false
        tableView.backgroundColor = .clear
        tableView.enclosingScrollView?.drawsBackground = false
        tableView.target = self
        tableView.doubleAction = #selector(handleDoubleClick(_:))
        tableView.wantsLayer = true
        tableView.setAccessibilityLabel("Clipboard history items")
        tableView.setAccessibilityRole(.list)
        tableView.setAccessibilityHelp("Use arrow keys to navigate, Enter to paste selected item")
        
        // Create table column - width will be set dynamically
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("ClipboardItem"))
        column.title = ""
        column.resizingMask = .autoresizingMask
        column.minWidth = 200
        tableView.addTableColumn(column)
        
        // Update column width when scroll view resizes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateColumnWidth),
            name: NSView.frameDidChangeNotification,
            object: scrollView
        )
        
        scrollView.documentView = tableView
        visualEffectView.addSubview(scrollView)
        
        // Empty state label
        emptyLabel = NSTextField(labelWithString: "No clipboard history\n\nCopy some text to get started!")
        emptyLabel.alignment = .center
        emptyLabel.textColor = .secondaryLabelColor
        emptyLabel.font = NSFont.systemFont(ofSize: 14, weight: .regular)
        emptyLabel.isBezeled = false
        emptyLabel.isEditable = false
        emptyLabel.backgroundColor = .clear
        contentView.addSubview(emptyLabel)
        
        // Auto-layout setup for resizing
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        searchField.translatesAutoresizingMaskIntoConstraints = false
        clearButtonContainer.translatesAutoresizingMaskIntoConstraints = false
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Title label - consistent 20px margins
            titleLabel.topAnchor.constraint(equalTo: visualEffectView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: clearButtonContainer.leadingAnchor, constant: -16),
            
            // Search field - directly positioned with consistent alignment
            searchField.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            searchField.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor, constant: 20),
            searchField.trailingAnchor.constraint(equalTo: clearButtonContainer.leadingAnchor, constant: -12),
            searchField.heightAnchor.constraint(equalToConstant: 36),
            
            // Clear button container - align with search field
            clearButtonContainer.centerYAnchor.constraint(equalTo: searchField.centerYAnchor),
            clearButtonContainer.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor, constant: -20),
            clearButtonContainer.widthAnchor.constraint(equalToConstant: 90),
            clearButtonContainer.heightAnchor.constraint(equalToConstant: 40),
            
            // Clear button inside container
            clearButton.centerXAnchor.constraint(equalTo: clearButtonContainer.centerXAnchor),
            clearButton.centerYAnchor.constraint(equalTo: clearButtonContainer.centerYAnchor),
            clearButton.widthAnchor.constraint(equalToConstant: 80),
            clearButton.heightAnchor.constraint(equalToConstant: 28),
            
            // Scroll view - consistent 20px margins, aligned with title and search
            scrollView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 16),
            scrollView.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor, constant: -20),
            scrollView.bottomAnchor.constraint(equalTo: visualEffectView.bottomAnchor, constant: -20),
            
            // Empty label
            emptyLabel.centerXAnchor.constraint(equalTo: visualEffectView.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: visualEffectView.centerYAnchor)
        ])
        
        // Set initial column width
        DispatchQueue.main.async {
            self.updateColumnWidth()
        }
    }
    
    private func setupKeyboardHandling() {
        // Handle keyboard events for navigation and selection
        acceptsMouseMovedEvents = true
        // Don't make table view first responder - let search field be focusable
    }
    
    // MARK: - Public Methods
    
    func showWindow() {
        // Capture the previously active application
        previousApp = NSWorkspace.shared.frontmostApplication
        
        loadHistory()
        center()
        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        // Focus search field after window is shown
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            // Ensure window is key first
            self.makeKey()
            // Then make search field first responder
            self.makeFirstResponder(self.searchField)
            // Also try selecting all text to ensure it's active
            if let editor = self.searchField.currentEditor() {
                editor.selectAll(nil)
            }
        }
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

        // Verify clipboard was updated successfully
        let pasteboard = NSPasteboard.general
        let initialChangeCount = pasteboard.changeCount

        // Wait for clipboard to update (with retry)
        var attempts = 0
        let maxAttempts = 3

        func verifyAndPaste() {
            attempts += 1
            let currentChangeCount = pasteboard.changeCount

            if currentChangeCount != initialChangeCount {
                print("📋 Clipboard updated successfully: \(selectedItem.preview)")
                performPasteSequence(previousApp: previousAppToRestore)
            } else if attempts < maxAttempts {
                // Retry after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    verifyAndPaste()
                }
            } else {
                print("⚠️ Clipboard update verification failed, proceeding anyway")
                performPasteSequence(previousApp: previousAppToRestore)
            }
        }

        // Start verification
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            verifyAndPaste()
        }

        // Close window immediately for better UX
        hideWindow()
    }

    private func performPasteSequence(previousApp: NSRunningApplication?) {
        // Restore focus to the previous application
        if let app = previousApp {
            app.activate(options: .activateIgnoringOtherApps)

            // Wait for app activation, then paste
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                Self.simulatePaste()
            }
        } else {
            // No previous app, just simulate paste immediately
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                Self.simulatePaste()
            }
        }
    }
    
    private static func simulatePaste() {
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
    
    @objc private func updateColumnWidth() {
        if let column = tableView.tableColumns.first {
            let scrollViewWidth = scrollView.bounds.width
            // Account for scrollbar width (typically 15px) and increased padding (28px total)
            // Scrollbar: 15px, right padding: 8px, cell trailing margin: 4px, extra buffer: 1px
            let scrollbarAndPadding: CGFloat = 28
            column.width = max(scrollViewWidth - scrollbarAndPadding, 200)
        }
    }
    
    @objc private func searchFieldDidBecomeFirstResponder() {
        // Enhance glow when focused
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.allowsImplicitAnimation = true
            searchField.layer?.borderColor = NSColor.controlAccentColor.cgColor
            searchField.layer?.shadowOpacity = 0.5
            searchField.layer?.shadowRadius = 6
        }
    }
    
    @objc private func searchFieldDidResignFirstResponder() {
        // Reduce glow when not focused
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.allowsImplicitAnimation = true
            searchField.layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.4).cgColor
            searchField.layer?.shadowOpacity = 0.3
            searchField.layer?.shadowRadius = 4
        }
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
        // Cancel any pending search
        searchWorkItem?.cancel()

        // Create a new work item for the search
        let workItem = DispatchWorkItem { [weak self] in
            self?.applySearchFilter()
        }

        searchWorkItem = workItem

        // Execute the search after the debounce interval
        DispatchQueue.main.asyncAfter(deadline: .now() + searchDebounceInterval, execute: workItem)
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
        let modifierFlags = event.modifierFlags

        // Handle keyboard shortcuts with modifiers
        if modifierFlags.contains(.command) {
            switch key {
            case 3: // Cmd+F - Focus search field
                searchField.becomeFirstResponder()
                return

            case 51: // Cmd+Backspace/Delete - Clear history
                if !history.isEmpty {
                    clearHistory(clearButton)
                }
                return

            default:
                break
            }
        }

        // Handle regular key presses
        switch key {
        case 36, 76: // Enter or Return
            copySelectedItem()

        case 53: // Escape
            // If search field is focused and has text, clear it first
            if searchField.stringValue.isEmpty == false && searchField.currentEditor() != nil {
                searchField.stringValue = ""
                applySearchFilter()
            } else {
                hideWindow()
            }

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

        case 48: // Tab key
            // Cycle focus between search field and table
            if searchField.currentEditor() != nil {
                makeFirstResponder(tableView)
            } else {
                searchField.becomeFirstResponder()
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
        cellView.isSelected = (row == selectedIndex)
        
        return cellView
    }
    
    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        return ModernTableRowView()
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        selectedIndex = tableView.selectedRow
        tableView.enumerateAvailableRowViews { rowView, row in
            if let cellView = rowView.view(atColumn: 0) as? ClipboardHistoryCellView {
                cellView.isSelected = (row == selectedIndex)
            }
        }
    }
    
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        selectedIndex = row
        return true
    }
}

// MARK: - Modern Table Row View

class ModernTableRowView: NSTableRowView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        wantsLayer = true
        backgroundColor = .clear
    }
    
    override var isSelected: Bool {
        didSet {
            if isSelected {
                layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.15).cgColor
            } else {
                layer?.backgroundColor = NSColor.clear.cgColor
            }
        }
    }
}

// MARK: - Custom Cell View

class ClipboardHistoryCellView: NSView {
    private var visualEffectView: NSVisualEffectView!
    private var iconImageView: NSImageView!
    private var typeLabel: NSTextField!
    private var previewLabel: NSTextField!
    private var timestampLabel: NSTextField!
    private var hoverTrackingArea: NSTrackingArea?
    
    var isSelected: Bool = false {
        didSet {
            updateAppearance()
        }
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.masksToBounds = true
        
        // Visual effect view for glass effect
        visualEffectView = NSVisualEffectView()
        visualEffectView.material = .sidebar
        visualEffectView.blendingMode = .withinWindow
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 10
        visualEffectView.layer?.masksToBounds = true
        
        // Add subtle shadow using layer properties
        visualEffectView.layer?.shadowColor = NSColor.black.cgColor
        visualEffectView.layer?.shadowOpacity = 0.1
        visualEffectView.layer?.shadowOffset = CGSize(width: 0, height: -2)
        visualEffectView.layer?.shadowRadius = 8
        
        addSubview(visualEffectView)
        
        // Icon container
        let iconContainer = NSView()
        iconContainer.wantsLayer = true
        iconContainer.layer?.cornerRadius = 8
        iconContainer.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.15).cgColor
        visualEffectView.addSubview(iconContainer)
        
        // Icon
        iconImageView = NSImageView()
        iconImageView.imageScaling = .scaleProportionallyUpOrDown
        iconContainer.addSubview(iconImageView)
        
        // Type label
        typeLabel = NSTextField(labelWithString: "")
        typeLabel.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        typeLabel.textColor = .secondaryLabelColor
        visualEffectView.addSubview(typeLabel)
        
        // Preview label
        previewLabel = NSTextField(labelWithString: "")
        previewLabel.font = NSFont.systemFont(ofSize: 14, weight: .regular)
        previewLabel.textColor = .labelColor
        previewLabel.lineBreakMode = .byTruncatingTail
        visualEffectView.addSubview(previewLabel)
        
        // Timestamp label
        timestampLabel = NSTextField(labelWithString: "")
        timestampLabel.font = NSFont.systemFont(ofSize: 10, weight: .regular)
        timestampLabel.textColor = .tertiaryLabelColor
        visualEffectView.addSubview(timestampLabel)
        
        // Auto-layout
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        typeLabel.translatesAutoresizingMaskIntoConstraints = false
        previewLabel.translatesAutoresizingMaskIntoConstraints = false
        timestampLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Visual effect view fills the cell with proper margins
            visualEffectView.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            visualEffectView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 0),
            visualEffectView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            visualEffectView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            
            // Icon container
            iconContainer.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor, constant: 16),
            iconContainer.centerYAnchor.constraint(equalTo: visualEffectView.centerYAnchor),
            iconContainer.widthAnchor.constraint(equalToConstant: 40),
            iconContainer.heightAnchor.constraint(equalToConstant: 40),
            
            // Icon inside container
            iconImageView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 20),
            iconImageView.heightAnchor.constraint(equalToConstant: 20),
            
            // Type label - increased right padding for consistency
            typeLabel.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 12),
            typeLabel.topAnchor.constraint(equalTo: visualEffectView.topAnchor, constant: 12),
            typeLabel.trailingAnchor.constraint(lessThanOrEqualTo: visualEffectView.trailingAnchor, constant: -28),
            
            // Preview label - ensure proper spacing from scrollbar (increased padding)
            previewLabel.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 12),
            previewLabel.topAnchor.constraint(equalTo: typeLabel.bottomAnchor, constant: 4),
            previewLabel.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor, constant: -28),
            
            // Timestamp label - increased right padding
            timestampLabel.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 12),
            timestampLabel.topAnchor.constraint(equalTo: previewLabel.bottomAnchor, constant: 4),
            timestampLabel.trailingAnchor.constraint(lessThanOrEqualTo: visualEffectView.trailingAnchor, constant: -28)
        ])
        
        // Setup hover tracking
        setupHoverTracking()
    }
    
    private func setupHoverTracking() {
        let options: NSTrackingArea.Options = [.activeInKeyWindow, .mouseEnteredAndExited, .inVisibleRect]
        hoverTrackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(hoverTrackingArea!)
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea = hoverTrackingArea {
            removeTrackingArea(trackingArea)
        }
        setupHoverTracking()
    }
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        animateHover(entered: true)
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        animateHover(entered: false)
    }
    
    private func animateHover(entered: Bool) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.allowsImplicitAnimation = true
            if entered {
                visualEffectView.layer?.transform = CATransform3DMakeScale(1.02, 1.02, 1.0)
                visualEffectView.layer?.shadowOpacity = 0.1
            } else {
                visualEffectView.layer?.transform = CATransform3DIdentity
                visualEffectView.layer?.shadowOpacity = 0.0
            }
        }
    }
    
    private func updateAppearance() {
        if isSelected {
            visualEffectView.layer?.borderWidth = 1.5
            visualEffectView.layer?.borderColor = NSColor.controlAccentColor.cgColor
            visualEffectView.material = .selection
        } else {
            visualEffectView.layer?.borderWidth = 0
            visualEffectView.layer?.borderColor = nil
            visualEffectView.material = .sidebar
        }
    }
    
    func configure(with item: ClipboardHistoryItem) {
        // Set icon or thumbnail
        if item.type == .image, let thumbnailString = item.thumbnail,
           let thumbnailData = Data(base64Encoded: thumbnailString),
           let thumbnailImage = NSImage(data: thumbnailData) {
            // Display thumbnail for images
            iconImageView.image = thumbnailImage
            iconImageView.contentTintColor = nil
            iconImageView.imageScaling = .scaleProportionallyUpOrDown
        } else if let iconImage = NSImage(systemSymbolName: item.type.icon, accessibilityDescription: item.type.displayName) {
            // Display icon for other types
            iconImageView.image = iconImage
            iconImageView.contentTintColor = .controlAccentColor
            iconImageView.imageScaling = .scaleProportionallyDown
        }

        // Set labels
        typeLabel.stringValue = item.type.displayName.uppercased()

        // For images with thumbnails, show dimensions or file info instead of "[Image]"
        if item.type == .image && item.thumbnail != nil {
            previewLabel.stringValue = "Image content"
        } else {
            previewLabel.stringValue = item.preview
        }
        
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
        
        updateAppearance()
    }
}

// MARK: - Custom Search Field Cell

class CustomSearchFieldCell: NSSearchFieldCell {
    override init(textCell string: String) {
        super.init(textCell: string)
        setupCell()
        setupSearchButton()
    }
    
    required init(coder: NSCoder) {
        super.init(coder: coder)
        setupCell()
        setupSearchButton()
    }
    
    private func setupCell() {
        isEditable = true
        isSelectable = true
        isEnabled = true
        isBezeled = false
        isBordered = false
    }
    
    private func setupSearchButton() {
        // Configure search button cell for consistent styling
        if let searchButton = searchButtonCell {
            searchButton.imagePosition = .imageOnly
            searchButton.bezelStyle = .shadowlessSquare
            // Use system symbol if available
            if let magnifyingGlass = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "Search") {
                searchButton.image = magnifyingGlass
            }
        }
    }
    
    override func searchTextRect(forBounds rect: NSRect) -> NSRect {
        // Calculate text rect with proper spacing
        let iconStart: CGFloat = 18
        let iconWidth: CGFloat = 20
        let iconTextSpacing: CGFloat = 14
        let textStartX = iconStart + iconWidth + iconTextSpacing  // 52px
        
        let rightPadding: CGFloat = 16
        let cancelButtonWidth: CGFloat = cancelButtonCell != nil ? 28 : 0
        
        // Get the default rect to preserve vertical centering
        let defaultRect = super.searchTextRect(forBounds: rect)
        
        // Create new rect with custom horizontal values but preserve vertical positioning
        var textRect = NSRect.zero
        textRect.origin.x = textStartX
        textRect.origin.y = defaultRect.origin.y  // Preserve vertical center from super
        textRect.size.width = rect.width - textStartX - rightPadding - cancelButtonWidth
        textRect.size.height = defaultRect.size.height  // Preserve height from super
        
        return textRect
    }
    
    override func searchButtonRect(forBounds rect: NSRect) -> NSRect {
        var buttonRect = super.searchButtonRect(forBounds: rect)
        buttonRect.origin.x = 18
        buttonRect.size.width = 20
        buttonRect.size.height = 20
        buttonRect.origin.y = rect.midY - buttonRect.size.height / 2
        return buttonRect
    }
    
    override func cancelButtonRect(forBounds rect: NSRect) -> NSRect {
        // Ensure cancel button maintains 12px padding from right edge
        var buttonRect = super.cancelButtonRect(forBounds: rect)
        if cancelButtonCell != nil {
            buttonRect.origin.x = rect.width - 28 - 12  // Button width (28) + right padding (12)
            buttonRect.size.width = 28
            buttonRect.size.height = 20
            buttonRect.origin.y = (rect.height - buttonRect.height) / 2
        }
        return buttonRect
    }
    
    override var isEditable: Bool {
        get { return super.isEditable }
        set { super.isEditable = newValue }
    }
    
    override var isSelectable: Bool {
        get { return super.isSelectable }
        set { super.isSelectable = newValue }
    }
    
    override func drawingRect(forBounds rect: NSRect) -> NSRect {
        return searchTextRect(forBounds: rect)
    }
    
    override func select(withFrame rect: NSRect, in controlView: NSView, editor: NSText, delegate: Any?, start selStart: Int, length selLength: Int) {
        let textRect = searchTextRect(forBounds: rect)
        super.select(withFrame: textRect, in: controlView, editor: editor, delegate: delegate, start: selStart, length: selLength)
    }
    
    override func edit(withFrame rect: NSRect, in controlView: NSView, editor: NSText, delegate: Any?, event: NSEvent?) {
        let textRect = searchTextRect(forBounds: rect)
        super.edit(withFrame: textRect, in: controlView, editor: editor, delegate: delegate, event: event)
    }
    
    override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView) {
        let rect = searchTextRect(forBounds: cellFrame)
        super.drawInterior(withFrame: rect, in: controlView)
    }
}

