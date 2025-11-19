import AppKit
import Foundation
import QuartzCore

// MARK: - Design Constants

private struct DesignConstants {
    // Colors - Purple gradient theme
    static let accentPrimary = NSColor(red: 0.388, green: 0.404, blue: 0.945, alpha: 1.0) // #6366f1
    static let accentSecondary = NSColor(red: 0.545, green: 0.361, blue: 0.965, alpha: 1.0) // #8b5cf6
    
    // Animation durations
    static let animationFast: TimeInterval = 0.15
    static let animationNormal: TimeInterval = 0.2
    static let animationSlow: TimeInterval = 0.3
    
    // Corner radius
    static let cardCornerRadius: CGFloat = 12
    static let buttonCornerRadius: CGFloat = 8
    static let iconCornerRadius: CGFloat = 8
}

// MARK: - Gradient Utilities

extension NSColor {
    static var accentGradientColors: [CGColor] {
        return [DesignConstants.accentPrimary.cgColor, DesignConstants.accentSecondary.cgColor]
    }
    
    static func createGradientLayer(colors: [CGColor], frame: CGRect, cornerRadius: CGFloat = 0) -> CAGradientLayer {
        let gradient = CAGradientLayer()
        gradient.colors = colors
        gradient.startPoint = CGPoint(x: 0, y: 0.5)
        gradient.endPoint = CGPoint(x: 1, y: 0.5)
        gradient.frame = frame
        gradient.cornerRadius = cornerRadius
        return gradient
    }
}

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
    private let rowHeight: CGFloat = 76 // Slightly increased for better spacing
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
        
        // Enhanced shadow system with multi-layer depth and colored glow
        visualEffectView.layer?.shadowColor = NSColor.black.cgColor
        visualEffectView.layer?.shadowOpacity = 0.35
        visualEffectView.layer?.shadowOffset = CGSize(width: 0, height: -6)
        visualEffectView.layer?.shadowRadius = 24
        
        // Add colored shadow layer for depth
        let shadowLayer = CALayer()
        shadowLayer.frame = visualEffectView.bounds
        shadowLayer.shadowColor = DesignConstants.accentPrimary.withAlphaComponent(0.2).cgColor
        shadowLayer.shadowOpacity = 0.3
        shadowLayer.shadowOffset = CGSize(width: 0, height: -2)
        shadowLayer.shadowRadius = 16
        shadowLayer.shadowPath = CGPath(roundedRect: visualEffectView.bounds, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        visualEffectView.layer?.insertSublayer(shadowLayer, at: 0)
        
        self.contentView = visualEffectView
        hasShadow = true
        
        setupUI()
        setupKeyboardHandling()
        loadHistory()
    }
    
    private func setupUI() {
        guard let contentView = visualEffectView else { return }
        
        // Search Container View - Handles the visual styling (border, background, corner radius)
        let searchContainerView = NSView()
        searchContainerView.wantsLayer = true
        searchContainerView.layer?.cornerRadius = 10
        searchContainerView.layer?.borderWidth = 1.5
        searchContainerView.layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.4).cgColor
        searchContainerView.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.25).cgColor
        searchContainerView.layer?.shadowColor = NSColor.controlAccentColor.cgColor
        searchContainerView.layer?.shadowOpacity = 0.3
        searchContainerView.layer?.shadowOffset = CGSize(width: 0, height: 0)
        searchContainerView.layer?.shadowRadius = 4
        
        contentView.addSubview(searchContainerView)
        
        // Search field - Standard NSSearchField inside the container
        searchField = NSSearchField()
        
        // Use custom cell to fix text overlap with icon
        let cell = PaddedSearchFieldCell(textCell: "")
        searchField.cell = cell
        
        searchField.placeholderString = "Search Clipboard..."
        searchField.target = self
        searchField.action = #selector(searchFieldChanged(_:))
        searchField.focusRingType = .none
        searchField.wantsLayer = true
        searchField.font = NSFont.systemFont(ofSize: 16)
        searchField.backgroundColor = .clear
        searchField.isBordered = false
        searchField.isBezeled = false
        searchField.drawsBackground = false
        searchField.isEditable = true
        searchField.isSelectable = true
        searchField.isEnabled = true
        searchField.setAccessibilityLabel("Search clipboard history")
        searchField.setAccessibilityRole(.textField)
        searchField.setAccessibilityPlaceholderValue("Search Clipboard...")
        
        // Monitor focus to enhance glow on the CONTAINER
        NotificationCenter.default.addObserver(
            forName: NSControl.textDidBeginEditingNotification,
            object: searchField,
            queue: .main
        ) { [weak self] _ in
            self?.animateSearchFocus(focused: true, container: searchContainerView)
        }
        
        NotificationCenter.default.addObserver(
            forName: NSControl.textDidEndEditingNotification,
            object: searchField,
            queue: .main
        ) { [weak self] _ in
            self?.animateSearchFocus(focused: false, container: searchContainerView)
        }
        
        searchContainerView.addSubview(searchField)
        
        // Clear button - Icon only (Trash)
        clearButton = NSButton()
        clearButton.bezelStyle = .texturedRounded
        clearButton.target = self
        clearButton.action = #selector(clearHistory(_:))
        clearButton.wantsLayer = true
        clearButton.contentTintColor = .secondaryLabelColor
        clearButton.isBordered = false
        clearButton.imagePosition = .imageOnly
        if let trashImage = NSImage(systemSymbolName: "trash", accessibilityDescription: "Clear All") {
            clearButton.image = trashImage
        }
        clearButton.setAccessibilityLabel("Clear all clipboard history")
        clearButton.setAccessibilityRole(.button)
        clearButton.setAccessibilityHelp("Press Cmd+Backspace or click to clear all clipboard history")
        
        // Add a subtle background to the clear button for better visibility
        let clearButtonContainer = NSView()
        clearButtonContainer.wantsLayer = true
        clearButtonContainer.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.2).cgColor
        clearButtonContainer.layer?.cornerRadius = 8
        clearButtonContainer.addSubview(clearButton)
        contentView.addSubview(clearButtonContainer)
        
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
        
        // Enhanced empty state label with better typography
        emptyLabel = NSTextField(labelWithString: "No clipboard history\n\nCopy some text to get started!")
        emptyLabel.alignment = .center
        emptyLabel.textColor = .secondaryLabelColor
        emptyLabel.font = NSFont.systemFont(ofSize: 15, weight: .medium)
        emptyLabel.isBezeled = false
        emptyLabel.isEditable = false
        emptyLabel.backgroundColor = .clear
        emptyLabel.maximumNumberOfLines = 0
        emptyLabel.lineBreakMode = .byWordWrapping
        
        // Add subtle animation to empty state
        emptyLabel.wantsLayer = true
        contentView.addSubview(emptyLabel)
        
        // Auto-layout setup for resizing
        searchContainerView.translatesAutoresizingMaskIntoConstraints = false
        searchField.translatesAutoresizingMaskIntoConstraints = false
        clearButtonContainer.translatesAutoresizingMaskIntoConstraints = false
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Search Container - Prominent at top
            searchContainerView.topAnchor.constraint(equalTo: visualEffectView.topAnchor, constant: 20),
            searchContainerView.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor, constant: 20),
            searchContainerView.trailingAnchor.constraint(equalTo: clearButtonContainer.leadingAnchor, constant: -12),
            searchContainerView.heightAnchor.constraint(equalToConstant: 44),
            
            // Search Field inside Container - Vertically centered, with padding
            searchField.leadingAnchor.constraint(equalTo: searchContainerView.leadingAnchor, constant: 8),
            searchField.trailingAnchor.constraint(equalTo: searchContainerView.trailingAnchor, constant: -8),
            searchField.centerYAnchor.constraint(equalTo: searchContainerView.centerYAnchor),
            // Let intrinsic height handle the text field height
            
            // Clear button container
            clearButtonContainer.centerYAnchor.constraint(equalTo: searchContainerView.centerYAnchor),
            clearButtonContainer.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor, constant: -20),
            clearButtonContainer.widthAnchor.constraint(equalToConstant: 44),
            clearButtonContainer.heightAnchor.constraint(equalToConstant: 44),
            
            // Clear button inside container
            clearButton.centerXAnchor.constraint(equalTo: clearButtonContainer.centerXAnchor),
            clearButton.centerYAnchor.constraint(equalTo: clearButtonContainer.centerYAnchor),
            clearButton.widthAnchor.constraint(equalToConstant: 24),
            clearButton.heightAnchor.constraint(equalToConstant: 24),
            
            // Scroll view - Below search field
            scrollView.topAnchor.constraint(equalTo: searchContainerView.bottomAnchor, constant: 16),
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
    
    private func animateSearchFocus(focused: Bool, container: NSView) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = DesignConstants.animationNormal
            context.allowsImplicitAnimation = true
            context.timingFunction = CAMediaTimingFunction(name: focused ? .easeOut : .easeIn)
            
            if let layer = container.layer {
                if focused {
                    // Add gradient border
                    let gradientBorder = CAGradientLayer()
                    gradientBorder.name = "gradientBorder"
                    gradientBorder.colors = NSColor.accentGradientColors
                    gradientBorder.startPoint = CGPoint(x: 0, y: 0.5)
                    gradientBorder.endPoint = CGPoint(x: 1, y: 0.5)
                    gradientBorder.frame = layer.bounds
                    gradientBorder.cornerRadius = 10
                    
                    let borderMask = CAShapeLayer()
                    let borderPath = CGMutablePath()
                    let rect = layer.bounds
                    let borderWidth: CGFloat = 1.5
                    
                    borderPath.addRoundedRect(in: rect, cornerWidth: 10, cornerHeight: 10)
                    let innerRect = rect.insetBy(dx: borderWidth, dy: borderWidth)
                    borderPath.addRoundedRect(in: innerRect, cornerWidth: 10 - borderWidth, cornerHeight: 10 - borderWidth)
                    
                    borderMask.path = borderPath
                    borderMask.fillRule = .evenOdd
                    gradientBorder.mask = borderMask
                    
                    // Remove old border if exists
                    layer.sublayers?.filter { $0.name == "gradientBorder" }.forEach { $0.removeFromSuperlayer() }
                    layer.insertSublayer(gradientBorder, at: 0)
                    
                    layer.shadowOpacity = 0.6
                    layer.shadowRadius = 8
                } else {
                    // Remove gradient border
                    layer.sublayers?.filter { $0.name == "gradientBorder" }.forEach { $0.removeFromSuperlayer() }
                    
                    layer.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.4).cgColor
                    layer.shadowOpacity = 0.3
                    layer.shadowRadius = 4
                }
            }
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
        
        // Start periodic refresh to catch new clipboard items
        startPeriodicRefresh()
        
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
        stopPeriodicRefresh()
        close()
    }
    
    private var refreshTimer: Timer?
    private var lastHistoryCount: Int = 0
    
    private func startPeriodicRefresh() {
        stopPeriodicRefresh()
        lastHistoryCount = ClipboardManager.shared.getHistory().count
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self, self.isVisible else { return }
            let currentCount = ClipboardManager.shared.getHistory().count
            if currentCount != self.lastHistoryCount {
                self.lastHistoryCount = currentCount
                // Only reload if search field is empty or user isn't actively typing
                if self.searchField.stringValue.isEmpty {
                    self.loadHistory()
                }
            }
        }
    }
    
    private func stopPeriodicRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
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
            let filtered = history.filter { item in
                item.preview.lowercased().contains(searchText) ||
                item.content.lowercased().contains(searchText) ||
                item.type.displayName.lowercased().contains(searchText)
            }
            // Maintain pinned items at top in search results
            let pinned = filtered.filter { $0.isPinned }.sorted { $0.timestamp > $1.timestamp }
            let unpinned = filtered.filter { !$0.isPinned }.sorted { $0.timestamp > $1.timestamp }
            filteredHistory = pinned + unpinned
        }
        
        selectedIndex = 0
        tableView.reloadData()
        
        if !filteredHistory.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
    }
    
    private func updateUI() {
        let hasItems = !filteredHistory.isEmpty
        
        // Animate empty state appearance
        NSAnimationContext.runAnimationGroup { context in
            context.duration = DesignConstants.animationNormal
            context.allowsImplicitAnimation = true
            emptyLabel.alphaValue = hasItems ? 0 : 1
            emptyLabel.isHidden = hasItems
            
            // Add subtle fade animation to empty state
            if !hasItems && emptyLabel.alphaValue < 1 {
                let fadeAnimation = CABasicAnimation(keyPath: "opacity")
                fadeAnimation.fromValue = 0
                fadeAnimation.toValue = 1
                fadeAnimation.duration = DesignConstants.animationSlow
                fadeAnimation.timingFunction = CAMediaTimingFunction(name: .easeOut)
                emptyLabel.layer?.add(fadeAnimation, forKey: "fadeIn")
            }
        }
        
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
    
    func copyItemWithoutPasting(_ item: ClipboardHistoryItem) {
        // Copy to clipboard without auto-paste
        ClipboardManager.shared.copyToClipboard(item)
        print("📋 Copied item to clipboard (no auto-paste): \(item.preview)")
    }
    
    func togglePinStateForItem(id: UUID) {
        _ = ClipboardManager.shared.togglePinState(id: id)
        // Reload history to reflect pin state changes
        loadHistory()
        // Find the item in filtered history and maintain selection
        if let index = filteredHistory.firstIndex(where: { $0.id == id }) {
            selectedIndex = index
            tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
            tableView.scrollRowToVisible(index)
        }
    }
    
    private func togglePinStateForSelectedItem() {
        guard selectedIndex >= 0 && selectedIndex < filteredHistory.count else { return }
        let selectedItem = filteredHistory[selectedIndex]
        togglePinStateForItem(id: selectedItem.id)
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
        // Handled by notification observer in setupUI
    }
    
    @objc private func searchFieldDidResignFirstResponder() {
        // Handled by notification observer in setupUI
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

            case 8: // Cmd+C - Copy without auto-paste
                if selectedIndex >= 0 && selectedIndex < filteredHistory.count {
                    let selectedItem = filteredHistory[selectedIndex]
                    copyItemWithoutPasting(selectedItem)
                }
                return

            case 35: // Cmd+P - Toggle pin state
                togglePinStateForSelectedItem()
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
        cellView.parentWindow = self
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
    // private var typeLabel: NSTextField! // Removed for cleaner look
    private var previewLabel: NSTextField!
    private var timestampLabel: NSTextField!
    private var hoverTrackingArea: NSTrackingArea?
    private var gradientBorderLayer: CAGradientLayer?
    private var iconContainer: NSView!
    private var pinButton: NSButton!
    private var copyButton: NSButton!
    private var currentItem: ClipboardHistoryItem?
    weak var parentWindow: ClipboardHistoryWindow?
    
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
        layer?.cornerRadius = DesignConstants.cardCornerRadius
        layer?.masksToBounds = false // Allow shadow to be visible
        
        // Visual effect view for glass effect with enhanced styling
        visualEffectView = NSVisualEffectView()
        visualEffectView.material = .sidebar
        visualEffectView.blendingMode = .withinWindow
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = DesignConstants.cardCornerRadius
        visualEffectView.layer?.masksToBounds = false // Allow gradient border to be visible
        
        // Enhanced shadow system with colored glow
        visualEffectView.layer?.shadowColor = NSColor.black.cgColor
        visualEffectView.layer?.shadowOpacity = 0.12
        visualEffectView.layer?.shadowOffset = CGSize(width: 0, height: -2)
        visualEffectView.layer?.shadowRadius = 10
        
        // Add colored shadow for depth
        let coloredShadow = CALayer()
        coloredShadow.shadowColor = DesignConstants.accentPrimary.withAlphaComponent(0.15).cgColor
        coloredShadow.shadowOpacity = 0.2
        coloredShadow.shadowOffset = CGSize(width: 0, height: -1)
        coloredShadow.shadowRadius = 6
        visualEffectView.layer?.insertSublayer(coloredShadow, at: 0)
        
        addSubview(visualEffectView)
        
        // Icon container with gradient background
        iconContainer = NSView()
        iconContainer.wantsLayer = true
        iconContainer.layer?.cornerRadius = DesignConstants.iconCornerRadius
        
        // Create gradient background for icon container
        let iconGradient = CAGradientLayer()
        iconGradient.colors = [
            DesignConstants.accentPrimary.withAlphaComponent(0.2).cgColor,
            DesignConstants.accentSecondary.withAlphaComponent(0.15).cgColor
        ]
        iconGradient.startPoint = CGPoint(x: 0, y: 0)
        iconGradient.endPoint = CGPoint(x: 1, y: 1)
        iconGradient.cornerRadius = DesignConstants.iconCornerRadius
        iconContainer.layer?.insertSublayer(iconGradient, at: 0)
        
        visualEffectView.addSubview(iconContainer)
        
        // Icon
        iconImageView = NSImageView()
        iconImageView.imageScaling = .scaleProportionallyUpOrDown
        iconContainer.addSubview(iconImageView)
        
        // Preview label with better line spacing
        previewLabel = NSTextField(labelWithString: "")
        previewLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        previewLabel.textColor = .labelColor
        previewLabel.lineBreakMode = .byTruncatingTail
        previewLabel.maximumNumberOfLines = 2
        visualEffectView.addSubview(previewLabel)
        
        // Timestamp label with refined styling
        timestampLabel = NSTextField(labelWithString: "")
        timestampLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        timestampLabel.textColor = .tertiaryLabelColor
        visualEffectView.addSubview(timestampLabel)
        
        // Copy button
        copyButton = NSButton()
        copyButton.bezelStyle = .texturedRounded
        copyButton.isBordered = false
        copyButton.wantsLayer = true
        copyButton.target = self
        copyButton.action = #selector(copyButtonClicked(_:))
        if let copyImage = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: "Copy") {
            copyButton.image = copyImage
        }
        copyButton.imagePosition = .imageOnly
        copyButton.contentTintColor = .secondaryLabelColor
        copyButton.alphaValue = 0.6 // Start with lower opacity
        copyButton.setAccessibilityLabel("Copy item")
        copyButton.setAccessibilityRole(.button)
        copyButton.setAccessibilityHelp("Copy this item to clipboard")
        visualEffectView.addSubview(copyButton)
        
        // Pin button
        pinButton = NSButton()
        pinButton.bezelStyle = .texturedRounded
        pinButton.isBordered = false
        pinButton.wantsLayer = true
        pinButton.target = self
        pinButton.action = #selector(pinButtonClicked(_:))
        if let pinImage = NSImage(systemSymbolName: "pin", accessibilityDescription: "Pin") {
            pinButton.image = pinImage
        }
        pinButton.imagePosition = .imageOnly
        pinButton.contentTintColor = .secondaryLabelColor
        pinButton.alphaValue = 0.6 // Start with lower opacity
        pinButton.setAccessibilityLabel("Pin item")
        pinButton.setAccessibilityRole(.button)
        pinButton.setAccessibilityHelp("Pin or unpin this item")
        visualEffectView.addSubview(pinButton)
        
        // Auto-layout
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        previewLabel.translatesAutoresizingMaskIntoConstraints = false
        timestampLabel.translatesAutoresizingMaskIntoConstraints = false
        copyButton.translatesAutoresizingMaskIntoConstraints = false
        pinButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            // Visual effect view fills the cell with improved margins
            visualEffectView.topAnchor.constraint(equalTo: topAnchor, constant: 4),
            visualEffectView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 0),
            visualEffectView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            visualEffectView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            
            // Icon container with consistent spacing
            iconContainer.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor, constant: 16),
            iconContainer.centerYAnchor.constraint(equalTo: visualEffectView.centerYAnchor),
            iconContainer.widthAnchor.constraint(equalToConstant: 44),
            iconContainer.heightAnchor.constraint(equalToConstant: 44),
            
            // Icon inside container
            iconImageView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 20),
            iconImageView.heightAnchor.constraint(equalToConstant: 20),
            
            // Preview label - Aligned with top of icon container
            previewLabel.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 12),
            previewLabel.topAnchor.constraint(equalTo: iconContainer.topAnchor, constant: 0),
            previewLabel.trailingAnchor.constraint(equalTo: copyButton.leadingAnchor, constant: -12),
            
            // Timestamp label - Below preview
            timestampLabel.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 12),
            timestampLabel.topAnchor.constraint(equalTo: previewLabel.bottomAnchor, constant: 4),
            timestampLabel.trailingAnchor.constraint(lessThanOrEqualTo: copyButton.leadingAnchor, constant: -12),
            
            // Copy button - right side, top area
            copyButton.trailingAnchor.constraint(equalTo: pinButton.leadingAnchor, constant: -12),
            copyButton.centerYAnchor.constraint(equalTo: visualEffectView.centerYAnchor),
            copyButton.widthAnchor.constraint(equalToConstant: 20),
            copyButton.heightAnchor.constraint(equalToConstant: 20),
            
            // Pin button - right side, top area
            pinButton.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor, constant: -12),
            pinButton.centerYAnchor.constraint(equalTo: visualEffectView.centerYAnchor),
            pinButton.widthAnchor.constraint(equalToConstant: 20),
            pinButton.heightAnchor.constraint(equalToConstant: 20)
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
    
    override func layout() {
        super.layout()
        // Update icon container gradient frame
        if let iconGradient = iconContainer.layer?.sublayers?.first as? CAGradientLayer {
            iconGradient.frame = iconContainer.bounds
        }
        
        // Update gradient border frame if selected
        if isSelected, let gradientBorder = gradientBorderLayer {
            gradientBorder.frame = visualEffectView.bounds
            // Update border mask path
            if let borderMask = gradientBorder.mask as? CAShapeLayer {
                let rect = visualEffectView.bounds
                let cornerRadius = DesignConstants.cardCornerRadius
                let borderWidth: CGFloat = 2.0
                
                // Validate rect dimensions
                guard rect.width > 0 && rect.height > 0,
                      rect.width >= 2 * cornerRadius,
                      rect.height >= 2 * cornerRadius else {
                    return
                }
                
                let borderPath = CGMutablePath()
                borderPath.addRoundedRect(in: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius)
                
                let innerRect = rect.insetBy(dx: borderWidth, dy: borderWidth)
                let innerCornerRadius = max(0, cornerRadius - borderWidth)
                
                if innerRect.width > 0 && innerRect.height > 0 &&
                   innerRect.width >= 2 * innerCornerRadius &&
                   innerRect.height >= 2 * innerCornerRadius {
                    borderPath.addRoundedRect(in: innerRect, cornerWidth: innerCornerRadius, cornerHeight: innerCornerRadius)
                }
                
                borderMask.path = borderPath
            }
        }
    }
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        if !isSelected {
            animateHover(entered: true)
        }
        // Show buttons on hover
        animateButtons(visible: true)
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        if !isSelected {
            animateHover(entered: false)
        }
        // Hide buttons when mouse exits
        animateButtons(visible: false)
    }
    
    private func animateButtons(visible: Bool) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = DesignConstants.animationFast
            context.allowsImplicitAnimation = true
            copyButton.alphaValue = visible ? 1.0 : 0.6
            pinButton.alphaValue = visible ? 1.0 : 0.6
        }
    }
    
    private func animateHover(entered: Bool) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = DesignConstants.animationNormal
            context.allowsImplicitAnimation = true
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            
            if entered {
                // Enhanced scale transform
                visualEffectView.layer?.transform = CATransform3DMakeScale(1.03, 1.03, 1.0)
                visualEffectView.layer?.shadowOpacity = 0.18
                visualEffectView.layer?.shadowRadius = 12
            } else {
                visualEffectView.layer?.transform = CATransform3DIdentity
                visualEffectView.layer?.shadowOpacity = 0.12
                visualEffectView.layer?.shadowRadius = 10
            }
        }
    }
    
    private func updateAppearance() {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = DesignConstants.animationNormal
            context.allowsImplicitAnimation = true
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            
            if isSelected {
                // Remove existing gradient border if any
                gradientBorderLayer?.removeFromSuperlayer()
                gradientBorderLayer = nil
                
                // Create gradient border
                let gradient = CAGradientLayer()
                gradient.colors = NSColor.accentGradientColors
                gradient.startPoint = CGPoint(x: 0, y: 0.5)
                gradient.endPoint = CGPoint(x: 1, y: 0.5)
                gradient.cornerRadius = DesignConstants.cardCornerRadius
                
                // Create mask for border
                let borderMask = CAShapeLayer()
                let borderPath = CGMutablePath()
                let rect = visualEffectView.bounds
                let cornerRadius = DesignConstants.cardCornerRadius
                let borderWidth: CGFloat = 2.0
                
                // Enhanced material and shadow (set these regardless of border creation)
                visualEffectView.material = .selection
                visualEffectView.layer?.shadowColor = DesignConstants.accentPrimary.cgColor
                visualEffectView.layer?.shadowOpacity = 0.25
                visualEffectView.layer?.shadowRadius = 14
                visualEffectView.layer?.shadowOffset = CGSize(width: 0, height: -2)
                
                // Scale up slightly
                visualEffectView.layer?.transform = CATransform3DMakeScale(1.02, 1.02, 1.0)
                
                // Validate rect dimensions before creating rounded rect
                // CoreGraphics requires: 2 * cornerRadius <= width/height
                guard rect.width > 0 && rect.height > 0,
                      rect.width >= 2 * cornerRadius,
                      rect.height >= 2 * cornerRadius else {
                    // If rect is too small, skip gradient border for now
                    // It will be updated in layout() when bounds are valid
                    return
                }
                
                // Outer path
                borderPath.addRoundedRect(in: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius)
                // Inner path
                let innerRect = rect.insetBy(dx: borderWidth, dy: borderWidth)
                let innerCornerRadius = max(0, cornerRadius - borderWidth)
                
                // Validate inner rect as well
                if innerRect.width > 0 && innerRect.height > 0 &&
                   innerRect.width >= 2 * innerCornerRadius &&
                   innerRect.height >= 2 * innerCornerRadius {
                    borderPath.addRoundedRect(in: innerRect, cornerWidth: innerCornerRadius, cornerHeight: innerCornerRadius)
                }
                
                borderMask.path = borderPath
                borderMask.fillRule = .evenOdd
                gradient.mask = borderMask
                
                gradient.frame = visualEffectView.bounds
                visualEffectView.layer?.insertSublayer(gradient, at: 0)
                gradientBorderLayer = gradient
            } else {
                // Remove gradient border
                gradientBorderLayer?.removeFromSuperlayer()
                gradientBorderLayer = nil
                
                visualEffectView.layer?.borderWidth = 0
                visualEffectView.layer?.borderColor = nil
                visualEffectView.material = .sidebar
                visualEffectView.layer?.shadowColor = NSColor.black.cgColor
                visualEffectView.layer?.shadowOpacity = 0.12
                visualEffectView.layer?.shadowRadius = 10
                visualEffectView.layer?.transform = CATransform3DIdentity
            }
        }
    }
    
    func configure(with item: ClipboardHistoryItem) {
        currentItem = item
        
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
        
        // Update pin button state
        updatePinButtonState(isPinned: item.isPinned)
        
        // Update visual appearance for pinned items
        updatePinnedAppearance(isPinned: item.isPinned)
        
        updateAppearance()
    }
    
    private func updatePinButtonState(isPinned: Bool) {
        let iconName = isPinned ? "pin.fill" : "pin"
        if let pinImage = NSImage(systemSymbolName: iconName, accessibilityDescription: isPinned ? "Unpin" : "Pin") {
            pinButton.image = pinImage
        }
        pinButton.contentTintColor = isPinned ? DesignConstants.accentPrimary : .secondaryLabelColor
        pinButton.setAccessibilityLabel(isPinned ? "Unpin item" : "Pin item")
        // Pinned items should always show button at full opacity
        if isPinned {
            pinButton.alphaValue = 1.0
        }
    }
    
    private func updatePinnedAppearance(isPinned: Bool) {
        if isPinned {
            // Add subtle background tint for pinned items
            visualEffectView.layer?.backgroundColor = DesignConstants.accentPrimary.withAlphaComponent(0.05).cgColor
        } else {
            visualEffectView.layer?.backgroundColor = NSColor.clear.cgColor
        }
    }
    
    @objc private func copyButtonClicked(_ sender: NSButton) {
        guard let item = currentItem else { return }
        
        // Animate button click
        NSAnimationContext.runAnimationGroup { context in
            context.duration = DesignConstants.animationFast
            context.allowsImplicitAnimation = true
            sender.layer?.transform = CATransform3DMakeScale(0.9, 0.9, 1.0)
        } completionHandler: {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = DesignConstants.animationFast
                context.allowsImplicitAnimation = true
                sender.layer?.transform = CATransform3DIdentity
            }
        }
        
        // Brief checkmark flash
        if let checkImage = NSImage(systemSymbolName: "checkmark", accessibilityDescription: "Copied") {
            let originalImage = sender.image
            sender.image = checkImage
            sender.contentTintColor = DesignConstants.accentPrimary
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                sender.image = originalImage
                sender.contentTintColor = .secondaryLabelColor
            }
        }
        
        // Copy to clipboard without auto-paste
        parentWindow?.copyItemWithoutPasting(item)
    }
    
    @objc private func pinButtonClicked(_ sender: NSButton) {
        guard let item = currentItem else { return }
        
        // Animate button click
        NSAnimationContext.runAnimationGroup { context in
            context.duration = DesignConstants.animationFast
            context.allowsImplicitAnimation = true
            sender.layer?.transform = CATransform3DMakeScale(0.9, 0.9, 1.0)
        } completionHandler: {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = DesignConstants.animationFast
                context.allowsImplicitAnimation = true
                sender.layer?.transform = CATransform3DIdentity
            }
        }
        
        // Toggle pin state
        parentWindow?.togglePinStateForItem(id: item.id)
    }
}

// MARK: - Padded Search Field Cell

class PaddedSearchFieldCell: NSSearchFieldCell {
    override func searchButtonRect(forBounds rect: NSRect) -> NSRect {
        var buttonRect = super.searchButtonRect(forBounds: rect)
        // Fix the search icon position
        buttonRect.origin.x = 8
        // Center vertically
        buttonRect.origin.y = floor((rect.height - buttonRect.height) / 2)
        return buttonRect
    }
    
    override func searchTextRect(forBounds rect: NSRect) -> NSRect {
        var textRect = super.searchTextRect(forBounds: rect)
        // Force text to start after the icon with a clear gap
        // Icon is at x=8, width approx 16-20. Let's start text at x=36
        let newX: CGFloat = 36
        let diff = newX - textRect.origin.x
        
        if diff > 0 {
            textRect.origin.x = newX
            textRect.size.width -= diff
        }
        
        return textRect
    }
    
    override func edit(withFrame rect: NSRect, in controlView: NSView, editor: NSText, delegate: Any?, event: NSEvent?) {
        let textRect = searchTextRect(forBounds: rect)
        super.edit(withFrame: textRect, in: controlView, editor: editor, delegate: delegate, event: event)
    }
    
    override func select(withFrame rect: NSRect, in controlView: NSView, editor: NSText, delegate: Any?, start selStart: Int, length selLength: Int) {
        let textRect = searchTextRect(forBounds: rect)
        super.select(withFrame: textRect, in: controlView, editor: editor, delegate: delegate, start: selStart, length: selLength)
    }
    
    override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView) {
        let textRect = searchTextRect(forBounds: cellFrame)
        super.drawInterior(withFrame: textRect, in: controlView)
    }
}

