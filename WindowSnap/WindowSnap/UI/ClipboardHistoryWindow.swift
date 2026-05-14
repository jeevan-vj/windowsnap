import AppKit
import Foundation
import QuartzCore

// MARK: - Design Constants

private struct DesignConstants {
    static let animationFast: TimeInterval = 0.12
    static let animationNormal: TimeInterval = 0.18
    static let animationSlow: TimeInterval = 0.25

    static let cardCornerRadius: CGFloat = 10
    static let iconCornerRadius: CGFloat = 8

    static let windowCornerRadius: CGFloat = 16
    static let windowWidth: CGFloat = 440
    static let windowHeight: CGFloat = 540
    static let rowHeight: CGFloat = 68
    static let imageRowHeight: CGFloat = 84
}

private enum SectionItem {
    case header(String)
    case item(ClipboardHistoryItem)
}

// MARK: - ClipboardHistoryWindow

class ClipboardHistoryWindow: NSWindow {
    private var tableView: NSTableView!
    private var scrollView: NSScrollView!
    private var searchField: NSSearchField!
    private var emptyLabel: NSTextField!
    private var clearButton: NSButton!
    private var clearButtonContainer: HoverableClearButtonContainer!
    private var visualEffectView: NSVisualEffectView!
    private var shortcutHintsLabel: NSTextField!
    private var itemCountLabel: NSTextField!
    private var footerStack: NSStackView!
    private var searchContainerView: NSView!

    private var history: [ClipboardHistoryItem] = []
    private var filteredHistory: [ClipboardHistoryItem] = []
    private var displayItems: [SectionItem] = []
    private var selectedIndex: Int = 0
    private var previousApp: NSRunningApplication?
    private var quickLookPopover: NSPopover?
    private var activeTypeFilters: Set<ClipboardItemType> = []
    private var filterChipsStack: NSStackView!

    private var searchWorkItem: DispatchWorkItem?
    private let searchDebounceInterval: TimeInterval = 0.25

    // MARK: Init

    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        setupWindow()
    }

    convenience init() {
        let contentRect = NSRect(x: 0, y: 0, width: DesignConstants.windowWidth, height: DesignConstants.windowHeight)
        let styleMask: NSWindow.StyleMask = [.borderless, .resizable, .fullSizeContentView]
        self.init(contentRect: contentRect, styleMask: styleMask, backing: .buffered, defer: false)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Window Setup

    private func setupWindow() {
        title = ""
        titlebarAppearsTransparent = true
        level = .floating
        isMovableByWindowBackground = true
        backgroundColor = .clear
        isReleasedWhenClosed = false
        minSize = NSSize(width: 360, height: 380)
        hasShadow = true

        // Hide traffic-light buttons so they don't collide with the search bar
        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true

        visualEffectView = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: DesignConstants.windowWidth, height: DesignConstants.windowHeight))
        visualEffectView.material = .popover
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = DesignConstants.windowCornerRadius
        visualEffectView.layer?.masksToBounds = true

        // Semi-opaque backing so background does not bleed through
        let opaqueBack = CALayer()
        opaqueBack.name = "opaqueBacking"
        opaqueBack.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.82).cgColor
        opaqueBack.cornerRadius = DesignConstants.windowCornerRadius
        opaqueBack.frame = visualEffectView.bounds
        opaqueBack.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        visualEffectView.layer?.insertSublayer(opaqueBack, at: 0)

        // Window shadow
        visualEffectView.shadow = NSShadow()
        visualEffectView.layer?.shadowColor = NSColor.black.cgColor
        visualEffectView.layer?.shadowOpacity = 0.28
        visualEffectView.layer?.shadowOffset = CGSize(width: 0, height: -4)
        visualEffectView.layer?.shadowRadius = 18

        contentView = visualEffectView

        setupUI()
        setupKeyboardHandling()
        loadHistory()
    }

    // MARK: - UI Layout

    private func setupUI() {
        guard let contentView = visualEffectView else { return }

        // --- Search container ---
        searchContainerView = NSView()
        searchContainerView.wantsLayer = true
        searchContainerView.layer?.cornerRadius = 10
        searchContainerView.layer?.borderWidth = 1
        searchContainerView.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.5).cgColor
        searchContainerView.layer?.backgroundColor = NSColor.textBackgroundColor.withAlphaComponent(0.35).cgColor
        contentView.addSubview(searchContainerView)

        // Search field
        searchField = NSSearchField()
        let cell = PaddedSearchFieldCell(textCell: "")
        searchField.cell = cell
        searchField.placeholderString = "Search Clipboard..."
        searchField.target = self
        searchField.action = #selector(searchFieldChanged(_:))
        searchField.focusRingType = .none
        searchField.wantsLayer = true
        searchField.font = NSFont.systemFont(ofSize: 15)
        searchField.backgroundColor = .clear
        searchField.isBordered = false
        searchField.isBezeled = false
        searchField.drawsBackground = false
        searchField.isEditable = true
        searchField.isSelectable = true
        searchField.isEnabled = true
        searchField.setAccessibilityLabel("Search clipboard history")
        searchField.setAccessibilityRole(.textField)
        searchContainerView.addSubview(searchField)

        NotificationCenter.default.addObserver(
            forName: NSControl.textDidBeginEditingNotification,
            object: searchField, queue: .main
        ) { [weak self] _ in
            self?.animateSearchFocus(focused: true)
        }
        NotificationCenter.default.addObserver(
            forName: NSControl.textDidEndEditingNotification,
            object: searchField, queue: .main
        ) { [weak self] _ in
            self?.animateSearchFocus(focused: false)
        }

        // --- Clear history button ---
        clearButton = NSButton()
        clearButton.bezelStyle = .texturedRounded
        clearButton.target = self
        clearButton.action = #selector(clearHistory(_:))
        clearButton.wantsLayer = true
        clearButton.contentTintColor = .secondaryLabelColor
        clearButton.isBordered = false
        clearButton.imagePosition = .imageOnly
        clearButton.toolTip = "Clear All History"
        if let img = NSImage(systemSymbolName: "trash", accessibilityDescription: "Clear All History") {
            clearButton.image = img
        }
        clearButton.setAccessibilityLabel("Clear all clipboard history")

        clearButtonContainer = HoverableClearButtonContainer()
        clearButtonContainer.wantsLayer = true
        clearButtonContainer.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.18).cgColor
        clearButtonContainer.layer?.cornerRadius = 8
        clearButtonContainer.button = clearButton
        clearButtonContainer.addSubview(clearButton)
        contentView.addSubview(clearButtonContainer)

        // --- Filter chips ---
        filterChipsStack = NSStackView()
        filterChipsStack.orientation = .horizontal
        filterChipsStack.spacing = 6
        filterChipsStack.distribution = .fill
        filterChipsStack.alignment = .centerY

        for itemType in ClipboardItemType.allCases {
            let chip = NSButton()
            chip.bezelStyle = .texturedRounded
            chip.isBordered = false
            chip.wantsLayer = true
            chip.title = itemType.displayName
            chip.font = NSFont.systemFont(ofSize: 11, weight: .medium)
            chip.contentTintColor = .secondaryLabelColor
            chip.layer?.cornerRadius = 10
            chip.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.15).cgColor
            chip.tag = ClipboardItemType.allCases.firstIndex(of: itemType) ?? 0
            chip.target = self
            chip.action = #selector(filterChipClicked(_:))
            chip.setAccessibilityLabel("Filter by \(itemType.displayName)")
            chip.translatesAutoresizingMaskIntoConstraints = false
            chip.heightAnchor.constraint(equalToConstant: 22).isActive = true
            filterChipsStack.addArrangedSubview(chip)
        }

        let chipSpacer = NSView()
        chipSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        filterChipsStack.addArrangedSubview(chipSpacer)
        contentView.addSubview(filterChipsStack)

        // --- Table view ---
        scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.backgroundColor = .clear
        scrollView.drawsBackground = false
        scrollView.scrollerStyle = .overlay
        scrollView.wantsLayer = true

        tableView = NSTableView()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.intercellSpacing = NSSize(width: 0, height: 6)
        tableView.selectionHighlightStyle = .none
        tableView.allowsEmptySelection = false
        tableView.backgroundColor = .clear
        tableView.target = self
        tableView.doubleAction = #selector(handleDoubleClick(_:))
        tableView.wantsLayer = true
        tableView.setAccessibilityLabel("Clipboard history items")
        tableView.setAccessibilityRole(.list)

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("ClipboardItem"))
        column.title = ""
        column.resizingMask = .autoresizingMask
        column.minWidth = 200
        tableView.addTableColumn(column)

        NotificationCenter.default.addObserver(
            self, selector: #selector(updateColumnWidth),
            name: NSView.frameDidChangeNotification, object: scrollView
        )

        scrollView.documentView = tableView
        contentView.addSubview(scrollView)

        // --- Empty state ---
        emptyLabel = NSTextField(labelWithString: "No clipboard history\n\nCopy something to get started")
        emptyLabel.alignment = .center
        emptyLabel.textColor = .tertiaryLabelColor
        emptyLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        emptyLabel.maximumNumberOfLines = 0
        emptyLabel.lineBreakMode = .byWordWrapping
        emptyLabel.wantsLayer = true
        contentView.addSubview(emptyLabel)

        // --- Footer ---
        shortcutHintsLabel = NSTextField(labelWithString: "")
        shortcutHintsLabel.font = NSFont.monospacedSystemFont(ofSize: 10.5, weight: .regular)
        shortcutHintsLabel.textColor = .tertiaryLabelColor
        shortcutHintsLabel.alignment = .left
        shortcutHintsLabel.lineBreakMode = .byTruncatingTail
        shortcutHintsLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        shortcutHintsLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        updateFooterHints()

        itemCountLabel = NSTextField(labelWithString: "")
        itemCountLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 10.5, weight: .regular)
        itemCountLabel.textColor = .tertiaryLabelColor
        itemCountLabel.alignment = .right
        itemCountLabel.setContentHuggingPriority(.required, for: .horizontal)
        itemCountLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        footerStack = NSStackView(views: [shortcutHintsLabel, itemCountLabel])
        footerStack.orientation = .horizontal
        footerStack.distribution = .fill
        footerStack.spacing = 8
        contentView.addSubview(footerStack)

        // --- Constraints ---
        for v: NSView in [searchContainerView, searchField, clearButtonContainer, clearButton, scrollView, emptyLabel, footerStack, filterChipsStack] {
            v.translatesAutoresizingMaskIntoConstraints = false
        }

        let topInset: CGFloat = 24

        NSLayoutConstraint.activate([
            searchContainerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: topInset),
            searchContainerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            searchContainerView.trailingAnchor.constraint(equalTo: clearButtonContainer.leadingAnchor, constant: -10),
            searchContainerView.heightAnchor.constraint(equalToConstant: 40),

            searchField.leadingAnchor.constraint(equalTo: searchContainerView.leadingAnchor, constant: 6),
            searchField.trailingAnchor.constraint(equalTo: searchContainerView.trailingAnchor, constant: -6),
            searchField.centerYAnchor.constraint(equalTo: searchContainerView.centerYAnchor),

            clearButtonContainer.centerYAnchor.constraint(equalTo: searchContainerView.centerYAnchor),
            clearButtonContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            clearButtonContainer.widthAnchor.constraint(equalToConstant: 36),
            clearButtonContainer.heightAnchor.constraint(equalToConstant: 36),

            clearButton.centerXAnchor.constraint(equalTo: clearButtonContainer.centerXAnchor),
            clearButton.centerYAnchor.constraint(equalTo: clearButtonContainer.centerYAnchor),
            clearButton.widthAnchor.constraint(equalToConstant: 20),
            clearButton.heightAnchor.constraint(equalToConstant: 20),

            filterChipsStack.topAnchor.constraint(equalTo: searchContainerView.bottomAnchor, constant: 10),
            filterChipsStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            filterChipsStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            filterChipsStack.heightAnchor.constraint(equalToConstant: 24),

            scrollView.topAnchor.constraint(equalTo: filterChipsStack.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            scrollView.bottomAnchor.constraint(equalTo: footerStack.topAnchor, constant: -6),

            footerStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            footerStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            footerStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
            footerStack.heightAnchor.constraint(equalToConstant: 18),

            emptyLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])

        DispatchQueue.main.async { self.updateColumnWidth() }
    }

    private func updateFooterHints() {
        let hints = [
            "\u{21A9} Paste",
            "\u{2318}\u{232B} Delete",
            "\u{2318}P Pin",
            "\u{2318}C Copy",
            "esc Close",
        ]
        shortcutHintsLabel.stringValue = hints.joined(separator: "  \u{00B7}  ")
    }

    // MARK: - Search Focus Animation

    private func animateSearchFocus(focused: Bool) {
        guard let layer = searchContainerView.layer else { return }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = DesignConstants.animationNormal
            ctx.allowsImplicitAnimation = true
            if focused {
                layer.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.65).cgColor
                layer.borderWidth = 1.5
            } else {
                layer.borderColor = NSColor.separatorColor.withAlphaComponent(0.5).cgColor
                layer.borderWidth = 1
            }
        }
    }

    private func setupKeyboardHandling() {
        acceptsMouseMovedEvents = true
    }

    // MARK: - Public Methods

    func showWindow() {
        previousApp = NSWorkspace.shared.frontmostApplication
        loadHistory()
        center()
        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        startPeriodicRefresh()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            self.makeKey()
            self.makeFirstResponder(self.searchField)
            if let editor = self.searchField.currentEditor() {
                editor.selectAll(nil)
            }
        }
    }

    func hideWindow() {
        stopPeriodicRefresh()
        close()
    }

    // MARK: Periodic Refresh

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

    // MARK: - Data

    private func selectedItem() -> ClipboardHistoryItem? {
        guard selectedIndex >= 0 && selectedIndex < displayItems.count else { return nil }
        if case .item(let item) = displayItems[selectedIndex] { return item }
        return nil
    }

    private func buildDisplayItems() {
        let pinned = filteredHistory.filter { $0.isPinned }
        let unpinned = filteredHistory.filter { !$0.isPinned }
        var items: [SectionItem] = []
        if !pinned.isEmpty {
            items.append(.header("Pinned"))
            items.append(contentsOf: pinned.map { .item($0) })
        }
        if !unpinned.isEmpty {
            items.append(.header("Recent"))
            items.append(contentsOf: unpinned.map { .item($0) })
        }
        displayItems = items
    }

    private func firstSelectableRow() -> Int {
        for (i, item) in displayItems.enumerated() {
            if case .item = item { return i }
        }
        return 0
    }

    private func nextSelectableRow(after row: Int, direction: Int) -> Int? {
        var candidate = row + direction
        while candidate >= 0 && candidate < displayItems.count {
            if case .item = displayItems[candidate] { return candidate }
            candidate += direction
        }
        return nil
    }

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
            let pinned = filtered.filter { $0.isPinned }.sorted { $0.timestamp > $1.timestamp }
            let unpinned = filtered.filter { !$0.isPinned }.sorted { $0.timestamp > $1.timestamp }
            filteredHistory = pinned + unpinned
        }

        if !activeTypeFilters.isEmpty {
            filteredHistory = filteredHistory.filter { activeTypeFilters.contains($0.type) }
        }

        buildDisplayItems()
        selectedIndex = firstSelectableRow()
        tableView.reloadData()
        if !displayItems.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: selectedIndex), byExtendingSelection: false)
        }
    }

    private func updateUI() {
        let hasItems = !filteredHistory.isEmpty

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = DesignConstants.animationNormal
            ctx.allowsImplicitAnimation = true
            emptyLabel.alphaValue = hasItems ? 0 : 1
            emptyLabel.isHidden = hasItems
        }

        tableView.isHidden = !hasItems
        scrollView.isHidden = !hasItems
        clearButton.isEnabled = !history.isEmpty

        // Footer count with filter awareness
        let isFiltering = !searchField.stringValue.isEmpty || !activeTypeFilters.isEmpty
        if isFiltering {
            let filterNames = activeTypeFilters.map { $0.displayName }.sorted().joined(separator: ", ")
            if !filterNames.isEmpty && !searchField.stringValue.isEmpty {
                itemCountLabel.stringValue = "\(filteredHistory.count) of \(history.count) (\(filterNames))"
            } else if !filterNames.isEmpty {
                itemCountLabel.stringValue = "\(filteredHistory.count) of \(history.count) \u{2022} \(filterNames)"
            } else {
                itemCountLabel.stringValue = "\(filteredHistory.count) of \(history.count)"
            }
        } else {
            itemCountLabel.stringValue = "\(history.count) item\(history.count == 1 ? "" : "s")"
        }

        if hasItems {
            tableView.reloadData()
            if selectedIndex < displayItems.count {
                tableView.selectRowIndexes(IndexSet(integer: selectedIndex), byExtendingSelection: false)
            }
        }
    }

    // MARK: - Clipboard Actions

    func copyItemWithoutPasting(_ item: ClipboardHistoryItem) {
        ClipboardManager.shared.copyToClipboard(item)
    }

    func deleteItemById(id: UUID) {
        ClipboardManager.shared.deleteItem(id: id)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.loadHistory()
        }
    }

    private func deleteSelectedItem() {
        guard let item = selectedItem() else { return }
        deleteItemById(id: item.id)
    }

    func togglePinStateForItem(id: UUID) {
        _ = ClipboardManager.shared.togglePinState(id: id)
        loadHistory()
        for (i, displayItem) in displayItems.enumerated() {
            if case .item(let item) = displayItem, item.id == id {
                selectedIndex = i
                tableView.selectRowIndexes(IndexSet(integer: i), byExtendingSelection: false)
                tableView.scrollRowToVisible(i)
                break
            }
        }
    }

    private func togglePinStateForSelectedItem() {
        guard let item = selectedItem() else { return }
        togglePinStateForItem(id: item.id)
    }

    private func copySelectedItem() {
        guard let selectedItem = selectedItem() else { return }
        let previousAppToRestore = previousApp
        ClipboardManager.shared.copyToClipboard(selectedItem)

        let pasteboard = NSPasteboard.general
        let initialChangeCount = pasteboard.changeCount
        var attempts = 0
        let maxAttempts = 3

        func verifyAndPaste() {
            attempts += 1
            if pasteboard.changeCount != initialChangeCount {
                performPasteSequence(previousApp: previousAppToRestore)
            } else if attempts < maxAttempts {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { verifyAndPaste() }
            } else {
                performPasteSequence(previousApp: previousAppToRestore)
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { verifyAndPaste() }
        hideWindow()
    }

    private func performPasteSequence(previousApp: NSRunningApplication?) {
        if let app = previousApp {
            app.activate(options: .activateIgnoringOtherApps)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { Self.simulatePaste() }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { Self.simulatePaste() }
        }
    }

    private static func simulatePaste() {
        let source = CGEventSource(stateID: .hidSystemState)
        if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) {
            keyDown.flags = .maskCommand
            keyDown.post(tap: .cghidEventTap)
        }
        if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false) {
            keyUp.flags = .maskCommand
            keyUp.post(tap: .cghidEventTap)
        }
    }

    @objc private func updateColumnWidth() {
        if let column = tableView.tableColumns.first {
            let scrollViewWidth = scrollView.bounds.width
            column.width = max(scrollViewWidth - 20, 200)
        }
    }

    // MARK: - Actions

    @objc private func handleDoubleClick(_ sender: NSTableView) {
        let clickedRow = sender.clickedRow
        guard clickedRow >= 0, clickedRow < displayItems.count else { return }
        if case .item = displayItems[clickedRow] {
            selectedIndex = clickedRow
            copySelectedItem()
        }
    }

    @objc private func searchFieldChanged(_ sender: NSSearchField) {
        searchWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in self?.applySearchFilter() }
        searchWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + searchDebounceInterval, execute: workItem)
    }

    @objc private func filterChipClicked(_ sender: NSButton) {
        let allCases = ClipboardItemType.allCases
        guard sender.tag >= 0, sender.tag < allCases.count else { return }
        let type = allCases[sender.tag]
        if activeTypeFilters.contains(type) {
            activeTypeFilters.remove(type)
        } else {
            activeTypeFilters.insert(type)
        }
        updateFilterChipAppearances()
        applySearchFilter()
        updateUI()
    }

    private func updateFilterChipAppearances() {
        let allCases = ClipboardItemType.allCases
        for view in filterChipsStack.arrangedSubviews {
            guard let chip = view as? NSButton, chip.tag < allCases.count else { continue }
            let type = allCases[chip.tag]
            let isActive = activeTypeFilters.contains(type)
            if isActive {
                chip.contentTintColor = .controlAccentColor
                chip.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.18).cgColor
                chip.layer?.borderWidth = 1
                chip.layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.4).cgColor
            } else {
                chip.contentTintColor = .secondaryLabelColor
                chip.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.15).cgColor
                chip.layer?.borderWidth = 0
                chip.layer?.borderColor = nil
            }
        }
    }

    @objc private func clearHistory(_ sender: NSButton) {
        let alert = NSAlert()
        alert.messageText = "Clear Clipboard History"
        alert.informativeText = "Are you sure you want to clear all clipboard history? This action cannot be undone."
        alert.addButton(withTitle: "Clear All")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        if alert.runModal() == .alertFirstButtonReturn {
            ClipboardManager.shared.clearHistory()
            loadHistory()
        }
    }

    // MARK: - Key Event Handling

    override func keyDown(with event: NSEvent) {
        let key = event.keyCode
        let modifierFlags = event.modifierFlags

        if modifierFlags.contains(.command) {
            switch key {
            case 3: // Cmd+F
                searchField.becomeFirstResponder()
                return
            case 8: // Cmd+C
                if let item = selectedItem() { copyItemWithoutPasting(item) }
                return
            case 35: // Cmd+P
                togglePinStateForSelectedItem()
                return
            case 51: // Cmd+Backspace
                if modifierFlags.contains(.shift) {
                    if !history.isEmpty { clearHistory(clearButton) }
                } else {
                    deleteSelectedItem()
                }
                return
            default:
                break
            }
        }

        switch key {
        case 36, 76: // Enter / Return
            copySelectedItem()
        case 53: // Escape
            if !searchField.stringValue.isEmpty && searchField.currentEditor() != nil {
                searchField.stringValue = ""
                applySearchFilter()
            } else {
                hideWindow()
            }
        case 125: // Down arrow
            if let next = nextSelectableRow(after: selectedIndex, direction: 1) {
                selectedIndex = next
                tableView.selectRowIndexes(IndexSet(integer: selectedIndex), byExtendingSelection: false)
                tableView.scrollRowToVisible(selectedIndex)
            }
        case 126: // Up arrow
            if let prev = nextSelectableRow(after: selectedIndex, direction: -1) {
                selectedIndex = prev
                tableView.selectRowIndexes(IndexSet(integer: selectedIndex), byExtendingSelection: false)
                tableView.scrollRowToVisible(selectedIndex)
            }
        case 49: // Space
            toggleQuickLook()
        case 48: // Tab
            if searchField.currentEditor() != nil {
                makeFirstResponder(tableView)
            } else {
                searchField.becomeFirstResponder()
            }
        default:
            super.keyDown(with: event)
        }
    }

    private func toggleQuickLook() {
        if let popover = quickLookPopover, popover.isShown {
            popover.close()
            quickLookPopover = nil
            return
        }
        guard let item = selectedItem() else { return }

        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true

        let viewController = NSViewController()
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: 340, height: 240))

        if item.type == .image,
           let thumbnailString = item.thumbnail,
           let thumbnailData = Data(base64Encoded: thumbnailString),
           let image = NSImage(data: thumbnailData) {
            let imageView = NSImageView(frame: containerView.bounds)
            imageView.image = image
            imageView.imageScaling = .scaleProportionallyUpOrDown
            imageView.autoresizingMask = [.width, .height]
            containerView.addSubview(imageView)
        } else {
            let sv = NSScrollView(frame: containerView.bounds)
            sv.autoresizingMask = [.width, .height]
            sv.hasVerticalScroller = true
            sv.borderType = .noBorder
            let tv = NSTextView(frame: containerView.bounds)
            tv.isEditable = false
            tv.isSelectable = true
            tv.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
            tv.textColor = .labelColor
            tv.backgroundColor = .clear
            tv.textContainerInset = NSSize(width: 12, height: 12)
            tv.string = item.content.count > 2000 ? String(item.content.prefix(2000)) + "\n..." : item.content
            sv.documentView = tv
            containerView.addSubview(sv)
        }

        viewController.view = containerView
        popover.contentViewController = viewController
        popover.contentSize = NSSize(width: 340, height: 240)

        let rowRect = tableView.rect(ofRow: selectedIndex)
        popover.show(relativeTo: rowRect, of: tableView, preferredEdge: .maxX)
        quickLookPopover = popover
    }
}

// MARK: - NSTableViewDataSource

extension ClipboardHistoryWindow: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return displayItems.count
    }
}

// MARK: - NSTableViewDelegate

extension ClipboardHistoryWindow: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        guard row >= 0, row < displayItems.count else { return DesignConstants.rowHeight }
        switch displayItems[row] {
        case .header:
            return 26
        case .item(let item):
            if item.type == .image, item.thumbnail != nil { return DesignConstants.imageRowHeight }
            return DesignConstants.rowHeight
        }
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < displayItems.count else { return nil }
        switch displayItems[row] {
        case .header(let title):
            return SectionHeaderCellView(title: title)
        case .item(let item):
            let cellView = ClipboardHistoryCellView()
            cellView.parentWindow = self
            cellView.configure(with: item)
            cellView.isSelected = (row == selectedIndex)
            return cellView
        }
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        return ModernTableRowView()
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = tableView.selectedRow
        guard row >= 0, row < displayItems.count else { return }
        if case .header = displayItems[row] { return }
        selectedIndex = row
        tableView.enumerateAvailableRowViews { rowView, r in
            if let cellView = rowView.view(atColumn: 0) as? ClipboardHistoryCellView {
                cellView.isSelected = (r == selectedIndex)
            }
        }
    }

    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        guard row >= 0, row < displayItems.count else { return false }
        if case .header = displayItems[row] { return false }
        selectedIndex = row
        return true
    }
}

// MARK: - Section Header Cell View

class SectionHeaderCellView: NSView {
    init(title: String) {
        super.init(frame: .zero)
        wantsLayer = true
        let label = NSTextField(labelWithString: title.uppercased())
        label.font = NSFont.systemFont(ofSize: 10, weight: .semibold)
        label.textColor = .tertiaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - Modern Table Row View

class ModernTableRowView: NSTableRowView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        backgroundColor = .clear
    }

    override var isSelected: Bool {
        didSet {
            layer?.backgroundColor = NSColor.clear.cgColor
        }
    }
}

// MARK: - ClipboardHistoryCellView

class ClipboardHistoryCellView: NSView {
    private var cardView: NSView!
    private var iconImageView: NSImageView!
    private var previewLabel: NSTextField!
    private var timestampLabel: NSTextField!
    private var hoverTrackingArea: NSTrackingArea?
    private var iconContainer: NSView!
    private var pinButton: NSButton!
    private var copyButton: NSButton!
    private var deleteButton: NSButton!
    private var currentItem: ClipboardHistoryItem?
    weak var parentWindow: ClipboardHistoryWindow?

    private var layoutConstraintsStandard: [NSLayoutConstraint] = []
    private var layoutConstraintsImagePreview: [NSLayoutConstraint] = []
    private var usesImagePreviewLayout = false

    private var previewTrailingToCard: NSLayoutConstraint!
    private var previewTrailingToButtons: NSLayoutConstraint!
    private var timestampTrailingToCard: NSLayoutConstraint!
    private var timestampTrailingToButtons: NSLayoutConstraint!

    var isSelected: Bool = false {
        didSet { updateAppearance() }
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

        // Card background
        cardView = NSView()
        cardView.wantsLayer = true
        cardView.layer?.cornerRadius = DesignConstants.cardCornerRadius
        cardView.layer?.masksToBounds = true
        addSubview(cardView)

        // Icon container
        iconContainer = NSView()
        iconContainer.wantsLayer = true
        iconContainer.layer?.cornerRadius = DesignConstants.iconCornerRadius
        iconContainer.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.1).cgColor
        cardView.addSubview(iconContainer)

        // Icon
        iconImageView = NSImageView()
        iconImageView.imageScaling = .scaleProportionallyUpOrDown
        iconImageView.wantsLayer = true
        iconImageView.layer?.cornerRadius = 5
        iconImageView.layer?.masksToBounds = true
        iconContainer.addSubview(iconImageView)

        // Preview label
        previewLabel = NSTextField(labelWithString: "")
        previewLabel.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        previewLabel.textColor = .labelColor
        previewLabel.lineBreakMode = .byTruncatingTail
        previewLabel.maximumNumberOfLines = 2
        cardView.addSubview(previewLabel)

        // Timestamp label
        timestampLabel = NSTextField(labelWithString: "")
        timestampLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        timestampLabel.textColor = .tertiaryLabelColor
        cardView.addSubview(timestampLabel)

        // Action buttons (hidden by default)
        deleteButton = makeActionButton(icon: "xmark.circle", label: "Delete")
        deleteButton.target = self
        deleteButton.action = #selector(deleteButtonClicked(_:))
        cardView.addSubview(deleteButton)

        copyButton = makeActionButton(icon: "doc.on.doc", label: "Copy")
        copyButton.target = self
        copyButton.action = #selector(copyButtonClicked(_:))
        cardView.addSubview(copyButton)

        pinButton = makeActionButton(icon: "pin", label: "Pin")
        pinButton.target = self
        pinButton.action = #selector(pinButtonClicked(_:))
        cardView.addSubview(pinButton)

        // Auto-layout
        cardView.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        previewLabel.translatesAutoresizingMaskIntoConstraints = false
        timestampLabel.translatesAutoresizingMaskIntoConstraints = false
        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        copyButton.translatesAutoresizingMaskIntoConstraints = false
        pinButton.translatesAutoresizingMaskIntoConstraints = false

        previewTrailingToCard = previewLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -14)
        previewTrailingToButtons = previewLabel.trailingAnchor.constraint(equalTo: deleteButton.leadingAnchor, constant: -8)
        timestampTrailingToCard = timestampLabel.trailingAnchor.constraint(lessThanOrEqualTo: cardView.trailingAnchor, constant: -14)
        timestampTrailingToButtons = timestampLabel.trailingAnchor.constraint(lessThanOrEqualTo: deleteButton.leadingAnchor, constant: -8)

        // Start with full-width text (no buttons visible)
        previewTrailingToCard.isActive = true
        previewTrailingToButtons.isActive = false
        timestampTrailingToCard.isActive = true
        timestampTrailingToButtons.isActive = false

        let sharedConstraints: [NSLayoutConstraint] = [
            cardView.topAnchor.constraint(equalTo: topAnchor, constant: 2),
            cardView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            cardView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2),
            cardView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2),

            iconContainer.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 12),
            iconContainer.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),

            previewLabel.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 10),
            previewLabel.topAnchor.constraint(equalTo: iconContainer.topAnchor, constant: 0),

            timestampLabel.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 10),
            timestampLabel.topAnchor.constraint(equalTo: previewLabel.bottomAnchor, constant: 3),

            deleteButton.trailingAnchor.constraint(equalTo: copyButton.leadingAnchor, constant: -6),
            deleteButton.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            deleteButton.widthAnchor.constraint(equalToConstant: 20),
            deleteButton.heightAnchor.constraint(equalToConstant: 20),

            copyButton.trailingAnchor.constraint(equalTo: pinButton.leadingAnchor, constant: -6),
            copyButton.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            copyButton.widthAnchor.constraint(equalToConstant: 20),
            copyButton.heightAnchor.constraint(equalToConstant: 20),

            pinButton.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -10),
            pinButton.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),
            pinButton.widthAnchor.constraint(equalToConstant: 20),
            pinButton.heightAnchor.constraint(equalToConstant: 20),
        ]

        layoutConstraintsStandard = [
            iconContainer.widthAnchor.constraint(equalToConstant: 36),
            iconContainer.heightAnchor.constraint(equalToConstant: 36),
            iconImageView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 18),
            iconImageView.heightAnchor.constraint(equalToConstant: 18),
        ]

        layoutConstraintsImagePreview = [
            iconContainer.widthAnchor.constraint(equalToConstant: 64),
            iconContainer.heightAnchor.constraint(equalToConstant: 48),
            iconImageView.leadingAnchor.constraint(equalTo: iconContainer.leadingAnchor, constant: 2),
            iconImageView.trailingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: -2),
            iconImageView.topAnchor.constraint(equalTo: iconContainer.topAnchor, constant: 2),
            iconImageView.bottomAnchor.constraint(equalTo: iconContainer.bottomAnchor, constant: -2),
        ]

        NSLayoutConstraint.activate(sharedConstraints + layoutConstraintsStandard)
        usesImagePreviewLayout = false
        setupHoverTracking()
    }

    private func makeActionButton(icon: String, label: String) -> NSButton {
        let btn = NSButton()
        btn.bezelStyle = .texturedRounded
        btn.isBordered = false
        btn.wantsLayer = true
        btn.imagePosition = .imageOnly
        btn.contentTintColor = .secondaryLabelColor
        btn.alphaValue = 0
        if let img = NSImage(systemSymbolName: icon, accessibilityDescription: label) {
            btn.image = img
        }
        btn.setAccessibilityLabel(label)
        return btn
    }

    private func setImagePreviewLayout(_ usePreview: Bool) {
        guard usePreview != usesImagePreviewLayout else { return }
        NSLayoutConstraint.deactivate(usesImagePreviewLayout ? layoutConstraintsImagePreview : layoutConstraintsStandard)
        NSLayoutConstraint.activate(usePreview ? layoutConstraintsImagePreview : layoutConstraintsStandard)
        usesImagePreviewLayout = usePreview
        iconContainer.layer?.masksToBounds = usePreview
        if usePreview {
            iconContainer.layer?.backgroundColor = NSColor.tertiaryLabelColor.withAlphaComponent(0.1).cgColor
        } else {
            iconContainer.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.1).cgColor
        }
        needsLayout = true
    }

    private static func relativeTimeDescription(since date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "Just now" }
        if interval < 3600 {
            let m = Int(interval / 60)
            return "\(m) min\(m == 1 ? "" : "s") ago"
        }
        if interval < 86400 {
            let h = Int(interval / 3600)
            return "\(h) hour\(h == 1 ? "" : "s") ago"
        }
        let fmt = DateFormatter()
        fmt.dateStyle = .short
        fmt.timeStyle = .short
        return fmt.string(from: date)
    }

    // MARK: Tracking

    private func setupHoverTracking() {
        let opts: NSTrackingArea.Options = [.activeInKeyWindow, .mouseEnteredAndExited, .inVisibleRect]
        hoverTrackingArea = NSTrackingArea(rect: bounds, options: opts, owner: self, userInfo: nil)
        addTrackingArea(hoverTrackingArea!)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let ta = hoverTrackingArea { removeTrackingArea(ta) }
        setupHoverTracking()
    }

    // MARK: Hover / Selection

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        if !isSelected { animateHover(entered: true) }
        setButtonsVisible(true)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        if !isSelected { animateHover(entered: false) }
        setButtonsVisible(false)
    }

    private func setButtonsVisible(_ visible: Bool) {
        // Swap trailing constraints so text reclaims width
        previewTrailingToCard.isActive = !visible
        previewTrailingToButtons.isActive = visible
        timestampTrailingToCard.isActive = !visible
        timestampTrailingToButtons.isActive = visible

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = DesignConstants.animationFast
            ctx.allowsImplicitAnimation = true
            copyButton.alphaValue = visible ? 1 : 0
            deleteButton.alphaValue = visible ? 1 : 0
            let isPinned = currentItem?.isPinned ?? false
            pinButton.alphaValue = visible ? 1 : (isPinned ? 0.7 : 0)
            cardView.layoutSubtreeIfNeeded()
        }
    }

    private func animateHover(entered: Bool) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = DesignConstants.animationNormal
            ctx.allowsImplicitAnimation = true
            cardView.layer?.backgroundColor = entered
                ? NSColor.labelColor.withAlphaComponent(0.04).cgColor
                : NSColor.clear.cgColor
        }
    }

    private func updateAppearance() {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = DesignConstants.animationNormal
            ctx.allowsImplicitAnimation = true
            if isSelected {
                cardView.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.12).cgColor
                cardView.layer?.borderWidth = 1.5
                cardView.layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.35).cgColor
            } else {
                cardView.layer?.backgroundColor = NSColor.clear.cgColor
                cardView.layer?.borderWidth = 0
                cardView.layer?.borderColor = nil
            }
        }
    }

    // MARK: Configure

    func configure(with item: ClipboardHistoryItem) {
        currentItem = item
        let hasImageThumbnail = item.type == .image && item.thumbnail != nil
        setImagePreviewLayout(hasImageThumbnail)

        if item.type == .image, let thumbStr = item.thumbnail,
           let thumbData = Data(base64Encoded: thumbStr),
           let thumbImg = NSImage(data: thumbData) {
            iconImageView.image = thumbImg
            iconImageView.contentTintColor = nil
            iconImageView.imageScaling = .scaleProportionallyUpOrDown
        } else if let img = NSImage(systemSymbolName: item.type.icon, accessibilityDescription: item.type.displayName) {
            iconImageView.image = img
            iconImageView.contentTintColor = .controlAccentColor
            iconImageView.imageScaling = .scaleProportionallyDown
        }

        if hasImageThumbnail {
            if let w = item.imageWidth, let h = item.imageHeight {
                previewLabel.stringValue = "Copied Image (\(w) \u{00D7} \(h))"
            } else {
                previewLabel.stringValue = "Copied Image"
            }
        } else {
            previewLabel.stringValue = item.preview
        }

        timestampLabel.stringValue = Self.relativeTimeDescription(since: item.timestamp)

        if item.type != .image {
            previewLabel.toolTip = item.content.count > 500 ? String(item.content.prefix(500)) + "..." : item.content
        } else {
            previewLabel.toolTip = nil
        }

        updatePinButtonState(isPinned: item.isPinned)
        updatePinnedAppearance(isPinned: item.isPinned)
        updateAppearance()
    }

    private func updatePinButtonState(isPinned: Bool) {
        let iconName = isPinned ? "pin.fill" : "pin"
        if let img = NSImage(systemSymbolName: iconName, accessibilityDescription: isPinned ? "Unpin" : "Pin") {
            pinButton.image = img
        }
        pinButton.contentTintColor = isPinned ? .controlAccentColor : .secondaryLabelColor
        pinButton.setAccessibilityLabel(isPinned ? "Unpin item" : "Pin item")
        if isPinned { pinButton.alphaValue = 0.7 }
    }

    private func updatePinnedAppearance(isPinned: Bool) {
        if isPinned {
            cardView.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.05).cgColor
        }
    }

    // MARK: Button Actions

    @objc private func copyButtonClicked(_ sender: NSButton) {
        guard let item = currentItem else { return }
        animateButtonTap(sender)
        if let checkImg = NSImage(systemSymbolName: "checkmark", accessibilityDescription: "Copied") {
            let orig = sender.image
            sender.image = checkImg
            sender.contentTintColor = .controlAccentColor
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                sender.image = orig
                sender.contentTintColor = .secondaryLabelColor
            }
        }
        parentWindow?.copyItemWithoutPasting(item)
    }

    @objc private func deleteButtonClicked(_ sender: NSButton) {
        guard let item = currentItem else { return }
        animateButtonTap(sender)
        parentWindow?.deleteItemById(id: item.id)
    }

    @objc private func pinButtonClicked(_ sender: NSButton) {
        guard let item = currentItem else { return }
        animateButtonTap(sender)
        parentWindow?.togglePinStateForItem(id: item.id)
    }

    private func animateButtonTap(_ button: NSButton) {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = DesignConstants.animationFast
            ctx.allowsImplicitAnimation = true
            button.layer?.transform = CATransform3DMakeScale(0.88, 0.88, 1)
        }, completionHandler: {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = DesignConstants.animationFast
                ctx.allowsImplicitAnimation = true
                button.layer?.transform = CATransform3DIdentity
            }
        })
    }
}

// MARK: - Hoverable Clear Button Container

class HoverableClearButtonContainer: NSView {
    var button: NSButton?
    private var trackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea { removeTrackingArea(existing) }
        let area = NSTrackingArea(rect: bounds, options: [.activeInKeyWindow, .mouseEnteredAndExited, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            ctx.allowsImplicitAnimation = true
            layer?.backgroundColor = NSColor.systemRed.withAlphaComponent(0.12).cgColor
            button?.contentTintColor = .systemRed
        }
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.12
            ctx.allowsImplicitAnimation = true
            layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.18).cgColor
            button?.contentTintColor = .secondaryLabelColor
        }
    }
}

// MARK: - Padded Search Field Cell

class PaddedSearchFieldCell: NSSearchFieldCell {
    override func searchButtonRect(forBounds rect: NSRect) -> NSRect {
        var r = super.searchButtonRect(forBounds: rect)
        r.origin.x = 8
        r.origin.y = floor((rect.height - r.height) / 2)
        return r
    }

    override func searchTextRect(forBounds rect: NSRect) -> NSRect {
        var r = super.searchTextRect(forBounds: rect)
        let newX: CGFloat = 34
        let diff = newX - r.origin.x
        if diff > 0 { r.origin.x = newX; r.size.width -= diff }
        return r
    }

    override func edit(withFrame rect: NSRect, in controlView: NSView, editor: NSText, delegate: Any?, event: NSEvent?) {
        super.edit(withFrame: searchTextRect(forBounds: rect), in: controlView, editor: editor, delegate: delegate, event: event)
    }

    override func select(withFrame rect: NSRect, in controlView: NSView, editor: NSText, delegate: Any?, start selStart: Int, length selLength: Int) {
        super.select(withFrame: searchTextRect(forBounds: rect), in: controlView, editor: editor, delegate: delegate, start: selStart, length: selLength)
    }

    override func drawInterior(withFrame cellFrame: NSRect, in controlView: NSView) {
        super.drawInterior(withFrame: searchTextRect(forBounds: cellFrame), in: controlView)
    }
}
