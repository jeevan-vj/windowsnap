import AppKit
import Foundation

final class SnippetPickerWindow: NSWindow {
    private var searchField: NSTextField!
    private var tableView: NSTableView!
    private var footerLabel: NSTextField!
    private var snippets: [TextExpansionSnippet] = []
    private var filteredSnippets: [TextExpansionSnippet] = []
    private var displayItems: [SnippetPickerSectionItem] = []
    private var selectedIndex: Int = 0
    var onSnippetSelected: ((TextExpansionSnippet) -> Void)?

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 420),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        title = "Snippet Picker"
        isOpaque = false
        backgroundColor = .clear
        level = .floating
        hasShadow = true
        isMovableByWindowBackground = true
        setupContent()
        reloadData()
    }

    private func setupContent() {
        let contentView = NSView()
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        contentView.layer?.cornerRadius = 12
        self.contentView = contentView

        searchField = NSTextField()
        searchField.placeholderString = "Search snippets..."
        searchField.font = NSFont.systemFont(ofSize: 14)
        searchField.target = self
        searchField.action = #selector(searchChanged)
        searchField.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(searchField)

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(scrollView)

        tableView = NSTableView()
        tableView.headerView = nil
        tableView.rowHeight = 34
        tableView.delegate = self
        tableView.dataSource = self
        tableView.target = self
        tableView.doubleAction = #selector(insertSelectedSnippet)
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("snippet"))
        column.width = 480
        tableView.addTableColumn(column)
        scrollView.documentView = tableView

        footerLabel = NSTextField(labelWithString: "")
        footerLabel.font = NSFont.systemFont(ofSize: 11)
        footerLabel.textColor = .secondaryLabelColor
        footerLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(footerLabel)

        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            searchField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            searchField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            scrollView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 12),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            scrollView.bottomAnchor.constraint(equalTo: footerLabel.topAnchor, constant: -8),

            footerLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            footerLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            footerLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
        ])
    }

    func presentNearMouse() {
        let mouseLocation = NSEvent.mouseLocation
        setFrameTopLeftPoint(NSPoint(x: mouseLocation.x - frame.width / 2, y: mouseLocation.y - frame.height - 12))
        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        searchField.stringValue = ""
        reloadData()
        makeFirstResponder(searchField)
    }

    @objc private func searchChanged() {
        reloadData()
    }

    private func reloadData() {
        snippets = TextExpanderManager.shared.getEnabledSnippets()
        filteredSnippets = SnippetPickerFilterModel.filter(
            snippets: snippets,
            searchText: searchField.stringValue,
            activeGroup: nil
        )
        displayItems = SnippetPickerFilterModel.buildDisplayItems(from: filteredSnippets)
        selectedIndex = SnippetPickerFilterModel.firstSelectableRow(in: displayItems)
        tableView.reloadData()
        updateFooter()
        if selectedIndex < displayItems.count {
            tableView.selectRowIndexes(IndexSet(integer: selectedIndex), byExtendingSelection: false)
        }
    }

    private func updateFooter() {
        let isSearching = !searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        footerLabel.stringValue = SnippetPickerFilterModel.itemCountLabel(
            filteredCount: filteredSnippets.count,
            totalCount: snippets.count,
            isSearching: isSearching
        ) + "  •  Enter to insert  •  Esc to close"
    }

    private func selectedSnippet() -> TextExpansionSnippet? {
        guard selectedIndex >= 0, selectedIndex < displayItems.count else { return nil }
        if case .item(let snippet) = displayItems[selectedIndex] {
            return snippet
        }
        return nil
    }

    @objc private func insertSelectedSnippet() {
        guard let snippet = selectedSnippet() else { return }
        orderOut(nil)
        onSnippetSelected?(snippet)
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 53:
            orderOut(nil)
        case 36, 76:
            insertSelectedSnippet()
        case 125:
            if let next = SnippetPickerFilterModel.nextSelectableRow(after: selectedIndex, direction: 1, in: displayItems) {
                selectedIndex = next
                tableView.selectRowIndexes(IndexSet(integer: next), byExtendingSelection: false)
                tableView.scrollRowToVisible(next)
            }
        case 126:
            if let previous = SnippetPickerFilterModel.nextSelectableRow(after: selectedIndex, direction: -1, in: displayItems) {
                selectedIndex = previous
                tableView.selectRowIndexes(IndexSet(integer: previous), byExtendingSelection: false)
                tableView.scrollRowToVisible(previous)
            }
        default:
            super.keyDown(with: event)
        }
    }
}

extension SnippetPickerWindow: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        displayItems.count
    }
}

extension SnippetPickerWindow: NSTableViewDelegate {
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < displayItems.count else { return nil }

        switch displayItems[row] {
        case .header(let title):
            let label = NSTextField(labelWithString: title.uppercased())
            label.font = NSFont.boldSystemFont(ofSize: 11)
            label.textColor = .secondaryLabelColor
            return label
        case .item(let snippet):
            let container = NSView()
            let trigger = NSTextField(labelWithString: snippet.trigger)
            trigger.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)
            trigger.frame = NSRect(x: 0, y: 8, width: 120, height: 18)
            container.addSubview(trigger)

            let preview = NSTextField(labelWithString: snippet.displayDescription)
            preview.frame = NSRect(x: 130, y: 8, width: 340, height: 18)
            preview.lineBreakMode = .byTruncatingTail
            container.addSubview(preview)
            return container
        }
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        selectedIndex = tableView.selectedRow
    }
}
