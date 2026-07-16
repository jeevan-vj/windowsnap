import AppKit
import Foundation

private final class NonDraggableScrollView: NSScrollView {
    override var mouseDownCanMoveWindow: Bool { false }
}

private final class NonDraggableTableView: NSTableView {
    override var mouseDownCanMoveWindow: Bool { false }
}

class ClipboardHistoryWindow: NSWindow {
    private var tableView: NSTableView!
    private var scrollView: NSScrollView!
    private var emptyLabel: NSTextField!
    private var visualEffectView: NSVisualEffectView!
    private var searchBar: ClipboardHistorySearchBar!
    private var filterBar: ClipboardHistoryFilterBar!
    private var footerView: ClipboardHistoryFooterView!

    private let presentationCache = ClipboardHistoryPresentationCache()
    private var history: [ClipboardHistoryItem] {
        get { presentationCache.history }
        set { presentationCache.history = newValue }
    }
    private var filteredHistory: [ClipboardHistoryItem] {
        get { presentationCache.filteredHistory }
        set { presentationCache.filteredHistory = newValue }
    }
    private var displayItems: [ClipboardHistorySectionItem] {
        get { presentationCache.displayItems }
        set { presentationCache.displayItems = newValue }
    }
    private var selectedIndex: Int {
        get { presentationCache.selectedIndex }
        set { presentationCache.selectedIndex = newValue }
    }
    private var previousApp: NSRunningApplication?
    private var quickLookPopover: NSPopover?

    private var searchWorkItem: DispatchWorkItem?
    private var refreshTimer: Timer?
    private var lastHistoryCount: Int {
        get { presentationCache.lastHistoryCount }
        set { presentationCache.lastHistoryCount = newValue }
    }
    private var prefersSearchFocus = true
    private var localKeyMonitor: Any?

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override init(contentRect: NSRect, styleMask style: NSWindow.StyleMask, backing backingStoreType: NSWindow.BackingStoreType, defer flag: Bool) {
        super.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag)
        setupWindow()
    }

    convenience init() {
        let contentRect = NSRect(
            x: 0,
            y: 0,
            width: ClipboardHistoryTheme.windowWidth,
            height: ClipboardHistoryTheme.windowHeight
        )
        let styleMask: NSWindow.StyleMask = [.borderless, .resizable, .fullSizeContentView]
        self.init(contentRect: contentRect, styleMask: styleMask, backing: .buffered, defer: false)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func setupWindow() {
        title = ""
        titlebarAppearsTransparent = true
        level = .floating
        isMovableByWindowBackground = true
        backgroundColor = .clear
        isReleasedWhenClosed = false
        minSize = NSSize(width: 360, height: 380)
        hasShadow = true

        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true

        visualEffectView = NSVisualEffectView(
            frame: NSRect(x: 0, y: 0, width: ClipboardHistoryTheme.windowWidth, height: ClipboardHistoryTheme.windowHeight)
        )
        visualEffectView.material = .popover
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = ClipboardHistoryTheme.windowCornerRadius
        visualEffectView.layer?.masksToBounds = true

        let opaqueBack = CALayer()
        opaqueBack.name = "opaqueBacking"
        opaqueBack.backgroundColor = NSColor.windowBackgroundColor
            .withAlphaComponent(ClipboardHistoryTheme.windowBackingAlpha).cgColor
        opaqueBack.cornerRadius = ClipboardHistoryTheme.windowCornerRadius
        opaqueBack.frame = visualEffectView.bounds
        opaqueBack.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        visualEffectView.layer?.insertSublayer(opaqueBack, at: 0)

        visualEffectView.shadow = NSShadow()
        visualEffectView.layer?.shadowColor = NSColor.black.cgColor
        visualEffectView.layer?.shadowOpacity = 0.2
        visualEffectView.layer?.shadowOffset = CGSize(width: 0, height: -3)
        visualEffectView.layer?.shadowRadius = 14

        contentView = visualEffectView
        setupUI()
        presentationCache.onPurge = { [weak self] in
            self?.handleHistoryPurged()
        }
        acceptsMouseMovedEvents = true
        loadHistory()
    }

    private func setupUI() {
        guard let contentView = visualEffectView else { return }

        searchBar = ClipboardHistorySearchBar()
        searchBar.delegate = self
        contentView.addSubview(searchBar)

        filterBar = ClipboardHistoryFilterBar()
        filterBar.delegate = self
        contentView.addSubview(filterBar)

        scrollView = NonDraggableScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.backgroundColor = .clear
        scrollView.drawsBackground = false
        scrollView.scrollerStyle = .overlay
        scrollView.wantsLayer = true

        tableView = NonDraggableTableView()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.intercellSpacing = NSSize(width: 0, height: 4)
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
            self,
            selector: #selector(updateColumnWidth),
            name: NSView.frameDidChangeNotification,
            object: scrollView
        )

        scrollView.documentView = tableView
        contentView.addSubview(scrollView)

        emptyLabel = NSTextField(labelWithString: "No clipboard history\n\nCopy something to get started")
        emptyLabel.alignment = .center
        emptyLabel.textColor = .secondaryLabelColor
        emptyLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        emptyLabel.maximumNumberOfLines = 0
        emptyLabel.lineBreakMode = .byWordWrapping
        emptyLabel.wantsLayer = true
        contentView.addSubview(emptyLabel)

        footerView = ClipboardHistoryFooterView()
        contentView.addSubview(footerView)

        for view in [searchBar, filterBar, scrollView, emptyLabel, footerView] as [NSView] {
            view.translatesAutoresizingMaskIntoConstraints = false
        }

        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: contentView.topAnchor, constant: ClipboardHistoryTheme.topInset),
            searchBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: ClipboardHistoryTheme.contentInset),
            searchBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -ClipboardHistoryTheme.contentInset),

            filterBar.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 10),
            filterBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: ClipboardHistoryTheme.contentInset),
            filterBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -ClipboardHistoryTheme.contentInset),
            filterBar.heightAnchor.constraint(equalToConstant: 24),

            scrollView.topAnchor.constraint(equalTo: filterBar.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 10),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -10),
            scrollView.bottomAnchor.constraint(equalTo: footerView.topAnchor, constant: -8),

            footerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: ClipboardHistoryTheme.contentInset),
            footerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -ClipboardHistoryTheme.contentInset),
            footerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            footerView.heightAnchor.constraint(equalToConstant: 20),

            emptyLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])

        DispatchQueue.main.async { self.updateColumnWidth() }
    }

    func showWindow() {
        previousApp = NSWorkspace.shared.frontmostApplication
        prefersSearchFocus = true
        loadHistory()
        center()
        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        startPeriodicRefresh()
        installLocalKeyMonitor()
        focusSearchFieldOnOpen()
    }

    private func focusSearchFieldOnOpen() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.makeKey()
            self.searchBar.focusSearchField()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.searchBar.focusSearchField()
        }
    }

    override func becomeKey() {
        super.becomeKey()
        if prefersSearchFocus {
            searchBar.focusSearchField()
        }
    }

    private func restoreSearchFocusIfNeeded() {
        guard prefersSearchFocus else { return }
        guard !searchBar.isSearchFieldFocused else { return }
        DispatchQueue.main.async { [weak self] in
            self?.searchBar.focusSearchField()
        }
    }

    private func installLocalKeyMonitor() {
        removeLocalKeyMonitor()
        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isKeyWindow else { return event }
            if event.keyCode == 53 {
                self.handleEscapeKey()
                return nil
            }
            return event
        }
    }

    private func removeLocalKeyMonitor() {
        if let localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
            self.localKeyMonitor = nil
        }
    }

    private func handleEscapeKey() {
        if !searchBar.searchField.stringValue.isEmpty, searchBar.isSearchFieldFocused {
            searchBar.searchField.stringValue = ""
            applySearchFilter()
            updateUI()
            searchBar.focusSearchField()
        } else {
            requestClose()
        }
    }

    func requestClose() {
        hideWindow()
    }

    func hideWindow() {
        stopPeriodicRefresh()
        removeLocalKeyMonitor()
        orderOut(nil)
    }

    private func startPeriodicRefresh() {
        stopPeriodicRefresh()
        lastHistoryCount = ClipboardManager.shared.getHistory().count
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self, self.isVisible else { return }
            let currentCount = ClipboardManager.shared.getHistory().count
            if currentCount != self.lastHistoryCount {
                self.lastHistoryCount = currentCount
                if self.searchBar.searchField.stringValue.isEmpty {
                    self.loadHistory()
                }
            }
        }
    }

    private func stopPeriodicRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func selectedItem() -> ClipboardHistoryItem? {
        guard selectedIndex >= 0, selectedIndex < displayItems.count else { return nil }
        if case .item(let item) = displayItems[selectedIndex] { return item }
        return nil
    }

    private func loadHistory() {
        history = ClipboardManager.shared.getHistory()
        applySearchFilter()
        updateUI()
    }

    private func handleHistoryPurged() {
        searchWorkItem?.cancel()
        searchWorkItem = nil
        quickLookPopover?.performClose(nil)
        quickLookPopover = nil
        searchBar.resetSearch()
        filterBar.resetFilters()
        tableView.reloadData()
        updateUI()
    }

    private func applySearchFilter() {
        filteredHistory = ClipboardHistoryFilterModel.filter(
            history: history,
            searchText: searchBar.searchField.stringValue,
            activeTypeFilters: filterBar.activeTypeFilters
        )
        displayItems = ClipboardHistoryFilterModel.buildDisplayItems(from: filteredHistory)
        selectedIndex = ClipboardHistoryFilterModel.firstSelectableRow(in: displayItems)
        tableView.reloadData()
        if !displayItems.isEmpty {
            tableView.selectRowIndexes(IndexSet(integer: selectedIndex), byExtendingSelection: false)
        }
    }

    private func updateUI() {
        let hasItems = !filteredHistory.isEmpty

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = ClipboardHistoryTheme.animationNormal
            ctx.allowsImplicitAnimation = true
            emptyLabel.alphaValue = hasItems ? 0 : 1
            emptyLabel.isHidden = hasItems
        }

        tableView.isHidden = !hasItems
        scrollView.isHidden = !hasItems
        searchBar.setClearButtonEnabled(!history.isEmpty)

        let isFiltering = ClipboardHistoryFilterModel.isFiltering(
            searchText: searchBar.searchField.stringValue,
            activeTypeFilters: filterBar.activeTypeFilters
        )
        let filterNames = filterBar.activeTypeFilters.map(\.displayName)
        footerView.updateItemCount(
            ClipboardHistoryFilterModel.itemCountLabel(
                filteredCount: filteredHistory.count,
                totalCount: history.count,
                isSearching: isFiltering,
                activeFilterNames: filterNames
            )
        )

        if hasItems {
            tableView.reloadData()
            if selectedIndex < displayItems.count {
                tableView.selectRowIndexes(IndexSet(integer: selectedIndex), byExtendingSelection: false)
            }
        }
        restoreSearchFocusIfNeeded()
    }

    func copyItemWithoutPasting(_ item: ClipboardHistoryItem) {
        ClipboardManager.shared.copyToClipboard(item)
    }

    func deleteItemById(id: UUID) {
        ClipboardManager.shared.deleteItem(id: id)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.loadHistory()
        }
    }

    func togglePinStateForItem(id: UUID) {
        _ = ClipboardManager.shared.togglePinState(id: id)
        loadHistory()
        for (index, displayItem) in displayItems.enumerated() {
            if case .item(let item) = displayItem, item.id == id {
                selectedIndex = index
                tableView.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
                tableView.scrollRowToVisible(index)
                break
            }
        }
    }

    private func deleteSelectedItem() {
        guard let item = selectedItem() else { return }
        deleteItemById(id: item.id)
    }

    private func togglePinStateForSelectedItem() {
        guard let item = selectedItem() else { return }
        togglePinStateForItem(id: item.id)
    }

    private func copySelectedItem() {
        guard let item = selectedItem() else { return }
        let previousAppToRestore = previousApp
        ClipboardHistoryPasteCoordinator.copyAndPaste(item: item, previousApp: previousAppToRestore)
        hideWindow()
    }

    @objc private func updateColumnWidth() {
        if let column = tableView.tableColumns.first {
            column.width = max(scrollView.bounds.width - 16, 200)
        }
    }

    @objc private func handleDoubleClick(_ sender: NSTableView) {
        let clickedRow = sender.clickedRow
        guard clickedRow >= 0, clickedRow < displayItems.count else { return }
        if case .item = displayItems[clickedRow] {
            selectedIndex = clickedRow
            copySelectedItem()
        }
    }

    private func scheduleSearchFilter() {
        searchWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.applySearchFilter()
            self?.updateUI()
        }
        searchWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + ClipboardHistoryTheme.searchDebounceInterval, execute: workItem)
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

    override func keyDown(with event: NSEvent) {
        if searchBar.isSearchFieldFocused {
            super.keyDown(with: event)
            return
        }

        let key = event.keyCode
        let modifierFlags = event.modifierFlags

        if modifierFlags.contains(.command) {
            switch key {
            case 3:
                searchBar.focusSearchField(selectAll: true)
                return
            case 8:
                if let item = selectedItem() { copyItemWithoutPasting(item) }
                return
            case 35:
                togglePinStateForSelectedItem()
                return
            case 51:
                if modifierFlags.contains(.shift) {
                    if !history.isEmpty { clearHistory(searchBar.clearButton) }
                } else {
                    deleteSelectedItem()
                }
                return
            default:
                break
            }
        }

        switch key {
        case 36, 76:
            copySelectedItem()
        case 53:
            handleEscapeKey()
        case 125:
            prefersSearchFocus = false
            if let next = ClipboardHistoryFilterModel.nextSelectableRow(
                after: selectedIndex,
                direction: 1,
                in: displayItems
            ) {
                selectedIndex = next
                tableView.selectRowIndexes(IndexSet(integer: selectedIndex), byExtendingSelection: false)
                tableView.scrollRowToVisible(selectedIndex)
            }
        case 126:
            prefersSearchFocus = false
            if let previous = ClipboardHistoryFilterModel.nextSelectableRow(
                after: selectedIndex,
                direction: -1,
                in: displayItems
            ) {
                selectedIndex = previous
                tableView.selectRowIndexes(IndexSet(integer: selectedIndex), byExtendingSelection: false)
                tableView.scrollRowToVisible(selectedIndex)
            }
        case 49:
            toggleQuickLook()
        case 48:
            if searchBar.isSearchFieldFocused {
                prefersSearchFocus = false
                makeFirstResponder(tableView)
            } else {
                prefersSearchFocus = true
                searchBar.focusSearchField()
            }
        default:
            if let characters = event.characters,
               characters.count == 1,
               characters.unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.union(.punctuationCharacters).union(.whitespaces).contains($0) }),
               !modifierFlags.contains(.command),
               !modifierFlags.contains(.control) {
                prefersSearchFocus = true
                searchBar.focusSearchField()
                searchBar.searchField.stringValue += characters
                scheduleSearchFilter()
                return
            }
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
        popover.contentViewController = ClipboardHistoryQuickLookBuilder.makeViewController(for: item)
        popover.contentSize = ClipboardHistoryQuickLookBuilder.popoverSize

        let rowRect = tableView.rect(ofRow: selectedIndex)
        popover.show(relativeTo: rowRect, of: tableView, preferredEdge: .maxX)
        quickLookPopover = popover
    }
}

extension ClipboardHistoryWindow: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        displayItems.count
    }
}

extension ClipboardHistoryWindow: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        guard row >= 0, row < displayItems.count else { return ClipboardHistoryTheme.rowHeight }
        switch displayItems[row] {
        case .header:
            return ClipboardHistoryTheme.headerRowHeight
        case .item(let item):
            if item.type == .image, item.thumbnail != nil {
                return ClipboardHistoryTheme.imageRowHeight
            }
            return ClipboardHistoryTheme.rowHeight
        }
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < displayItems.count else { return nil }
        switch displayItems[row] {
        case .header(let title):
            return SectionHeaderCellView(title: title)
        case .item(let item):
            let cellView = ClipboardHistoryCellView()
            cellView.delegate = self
            cellView.configure(with: item)
            cellView.isSelected = row == selectedIndex
            return cellView
        }
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        ModernTableRowView()
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = tableView.selectedRow
        guard row >= 0, row < displayItems.count else { return }
        if case .header = displayItems[row] { return }
        selectedIndex = row
        tableView.enumerateAvailableRowViews { rowView, index in
            if let cellView = rowView.view(atColumn: 0) as? ClipboardHistoryCellView {
                cellView.isSelected = index == selectedIndex
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

extension ClipboardHistoryWindow: ClipboardHistorySearchBarDelegate {
    func searchBarTextDidChange(_ searchBar: ClipboardHistorySearchBar) {
        scheduleSearchFilter()
    }

    func searchBarClearHistoryRequested(_ searchBar: ClipboardHistorySearchBar) {
        clearHistory(searchBar.clearButton)
    }

    func searchBarCloseRequested(_ searchBar: ClipboardHistorySearchBar) {
        requestClose()
    }

    func searchBarFocusDidChange(_ searchBar: ClipboardHistorySearchBar, focused: Bool) {
        _ = focused
    }
}

extension ClipboardHistoryWindow: ClipboardHistoryFilterBarDelegate {
    func filterBar(_ filterBar: ClipboardHistoryFilterBar, didToggle type: ClipboardItemType, isActive: Bool) {
        _ = type
        _ = isActive
        applySearchFilter()
        updateUI()
    }
}

extension ClipboardHistoryWindow: ClipboardHistoryCellDelegate {
    func clipboardCellDidRequestCopy(_ cell: ClipboardHistoryCellView, item: ClipboardHistoryItem) {
        copyItemWithoutPasting(item)
    }

    func clipboardCellDidRequestDelete(_ cell: ClipboardHistoryCellView, item: ClipboardHistoryItem) {
        deleteItemById(id: item.id)
    }

    func clipboardCellDidRequestTogglePin(_ cell: ClipboardHistoryCellView, item: ClipboardHistoryItem) {
        togglePinStateForItem(id: item.id)
    }
}
