import AppKit

final class NonDraggableTextField: NSTextField {
    override var mouseDownCanMoveWindow: Bool { false }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override var acceptsFirstResponder: Bool { true }
}

final class HoverableClearButtonContainer: NSView {
    var button: NSButton?
    private var trackingArea: NSTrackingArea?

    override var mouseDownCanMoveWindow: Bool { false }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea { removeTrackingArea(existing) }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = ClipboardHistoryTheme.animationFast
            ctx.allowsImplicitAnimation = true
            layer?.backgroundColor = NSColor.systemRed.withAlphaComponent(0.12).cgColor
            button?.contentTintColor = .systemRed
        }
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = ClipboardHistoryTheme.animationFast
            ctx.allowsImplicitAnimation = true
            layer?.backgroundColor = NSColor.quaternaryLabelColor.withAlphaComponent(0.12).cgColor
            button?.contentTintColor = .secondaryLabelColor
        }
    }
}

private final class SearchInputContainerView: NSView {
    weak var searchBar: ClipboardHistorySearchBar?

    override var mouseDownCanMoveWindow: Bool { false }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        searchBar?.focusSearchField()
    }
}

protocol ClipboardHistorySearchBarDelegate: AnyObject {
    func searchBarTextDidChange(_ searchBar: ClipboardHistorySearchBar)
    func searchBarClearHistoryRequested(_ searchBar: ClipboardHistorySearchBar)
    func searchBarCloseRequested(_ searchBar: ClipboardHistorySearchBar)
    func searchBarFocusDidChange(_ searchBar: ClipboardHistorySearchBar, focused: Bool)
}

final class ClipboardHistorySearchBar: NSView {
    weak var delegate: ClipboardHistorySearchBarDelegate?

    let searchField: NSTextField = NonDraggableTextField()
    let clearButton = NSButton()
    let closeButton = NSButton()
    private let searchContainerView = SearchInputContainerView()
    private let clearButtonContainer = HoverableClearButtonContainer()
    private let searchIconView = NSImageView()

    override var mouseDownCanMoveWindow: Bool { false }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        searchContainerView.searchBar = self
        searchContainerView.wantsLayer = true
        searchContainerView.layer?.cornerRadius = ClipboardHistoryTheme.controlCornerRadius
        searchContainerView.layer?.borderWidth = 1
        searchContainerView.layer?.borderColor = NSColor.separatorColor
            .withAlphaComponent(ClipboardHistoryTheme.searchBorderAlpha).cgColor
        searchContainerView.layer?.backgroundColor = NSColor.textBackgroundColor
            .withAlphaComponent(0.25).cgColor

        if let icon = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "Search") {
            searchIconView.image = icon
        }
        searchIconView.contentTintColor = .secondaryLabelColor
        searchIconView.imageScaling = .scaleProportionallyDown
        searchContainerView.addSubview(searchIconView)

        searchField.placeholderString = "Search Clipboard..."
        searchField.isEditable = true
        searchField.isSelectable = true
        searchField.isEnabled = true
        searchField.isBezeled = false
        searchField.isBordered = false
        searchField.drawsBackground = false
        searchField.backgroundColor = .clear
        searchField.focusRingType = .none
        searchField.font = NSFont.systemFont(ofSize: 15)
        searchField.target = self
        searchField.action = #selector(searchFieldChanged(_:))
        searchField.setAccessibilityLabel("Search clipboard history")
        searchField.setAccessibilityRole(.textField)
        searchContainerView.addSubview(searchField)

        clearButton.bezelStyle = .texturedRounded
        clearButton.target = self
        clearButton.action = #selector(clearHistoryClicked(_:))
        clearButton.wantsLayer = true
        clearButton.contentTintColor = .secondaryLabelColor
        clearButton.isBordered = false
        clearButton.imagePosition = .imageOnly
        clearButton.toolTip = "Clear All History"
        if let image = NSImage(systemSymbolName: "trash", accessibilityDescription: "Clear All History") {
            clearButton.image = image
        }
        clearButton.setAccessibilityLabel("Clear all clipboard history")

        clearButtonContainer.wantsLayer = true
        clearButtonContainer.layer?.backgroundColor = NSColor.quaternaryLabelColor
            .withAlphaComponent(0.12).cgColor
        clearButtonContainer.layer?.cornerRadius = ClipboardHistoryTheme.chipCornerRadius
        clearButtonContainer.button = clearButton
        clearButtonContainer.addSubview(clearButton)

        closeButton.bezelStyle = .texturedRounded
        closeButton.target = self
        closeButton.action = #selector(closeClicked(_:))
        closeButton.wantsLayer = true
        closeButton.contentTintColor = .secondaryLabelColor
        closeButton.isBordered = false
        closeButton.imagePosition = .imageOnly
        closeButton.toolTip = "Close"
        if let image = NSImage(systemSymbolName: "xmark", accessibilityDescription: "Close") {
            closeButton.image = image
        }
        closeButton.setAccessibilityLabel("Close clipboard history")

        addSubview(searchContainerView)
        addSubview(clearButtonContainer)
        addSubview(closeButton)

        searchContainerView.translatesAutoresizingMaskIntoConstraints = false
        searchIconView.translatesAutoresizingMaskIntoConstraints = false
        searchField.translatesAutoresizingMaskIntoConstraints = false
        clearButtonContainer.translatesAutoresizingMaskIntoConstraints = false
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            searchContainerView.topAnchor.constraint(equalTo: topAnchor),
            searchContainerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            searchContainerView.trailingAnchor.constraint(equalTo: clearButtonContainer.leadingAnchor, constant: -8),
            searchContainerView.heightAnchor.constraint(equalToConstant: 40),
            searchContainerView.bottomAnchor.constraint(equalTo: bottomAnchor),

            searchIconView.leadingAnchor.constraint(equalTo: searchContainerView.leadingAnchor, constant: 10),
            searchIconView.centerYAnchor.constraint(equalTo: searchContainerView.centerYAnchor),
            searchIconView.widthAnchor.constraint(equalToConstant: 16),
            searchIconView.heightAnchor.constraint(equalToConstant: 16),

            searchField.leadingAnchor.constraint(equalTo: searchIconView.trailingAnchor, constant: 6),
            searchField.trailingAnchor.constraint(equalTo: searchContainerView.trailingAnchor, constant: -8),
            searchField.topAnchor.constraint(equalTo: searchContainerView.topAnchor, constant: 6),
            searchField.bottomAnchor.constraint(equalTo: searchContainerView.bottomAnchor, constant: -6),

            clearButtonContainer.centerYAnchor.constraint(equalTo: searchContainerView.centerYAnchor),
            clearButtonContainer.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -8),
            clearButtonContainer.widthAnchor.constraint(equalToConstant: 36),
            clearButtonContainer.heightAnchor.constraint(equalToConstant: 36),

            clearButton.centerXAnchor.constraint(equalTo: clearButtonContainer.centerXAnchor),
            clearButton.centerYAnchor.constraint(equalTo: clearButtonContainer.centerYAnchor),
            clearButton.widthAnchor.constraint(equalToConstant: 20),
            clearButton.heightAnchor.constraint(equalToConstant: 20),

            closeButton.centerYAnchor.constraint(equalTo: searchContainerView.centerYAnchor),
            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 28),
            closeButton.heightAnchor.constraint(equalToConstant: 28),
        ])

        NotificationCenter.default.addObserver(
            forName: NSControl.textDidChangeNotification,
            object: searchField,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.delegate?.searchBarTextDidChange(self)
        }

        NotificationCenter.default.addObserver(
            forName: NSControl.textDidBeginEditingNotification,
            object: searchField,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.animateSearchFocus(focused: true)
            self.delegate?.searchBarFocusDidChange(self, focused: true)
        }
        NotificationCenter.default.addObserver(
            forName: NSControl.textDidEndEditingNotification,
            object: searchField,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.animateSearchFocus(focused: false)
            self.delegate?.searchBarFocusDidChange(self, focused: false)
        }
    }

    func setClearButtonEnabled(_ enabled: Bool) {
        clearButton.isEnabled = enabled
    }

    func focusSearchField(selectAll: Bool = false) {
        guard let window else { return }
        if isSearchFieldFocused {
            if selectAll {
                searchField.selectText(nil)
            }
            return
        }
        window.makeFirstResponder(searchField)
        if selectAll {
            searchField.selectText(nil)
        } else if searchField.currentEditor() == nil {
            window.makeFirstResponder(searchField)
        }
    }

    var isSearchFieldFocused: Bool {
        guard let firstResponder = window?.firstResponder else { return false }
        if firstResponder === searchField { return true }
        if let textView = firstResponder as? NSTextView,
           let fieldEditor = searchField.currentEditor(),
           textView === fieldEditor {
            return true
        }
        return false
    }

    private func animateSearchFocus(focused: Bool) {
        guard let layer = searchContainerView.layer else { return }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = ClipboardHistoryTheme.animationNormal
            ctx.allowsImplicitAnimation = true
            if focused {
                layer.borderColor = NSColor.controlAccentColor
                    .withAlphaComponent(ClipboardHistoryTheme.searchFocusBorderAlpha).cgColor
                layer.borderWidth = 1.5
            } else {
                layer.borderColor = NSColor.separatorColor
                    .withAlphaComponent(ClipboardHistoryTheme.searchBorderAlpha).cgColor
                layer.borderWidth = 1
            }
        }
    }

    @objc private func searchFieldChanged(_ sender: NSTextField) {
        delegate?.searchBarTextDidChange(self)
    }

    @objc private func clearHistoryClicked(_ sender: NSButton) {
        delegate?.searchBarClearHistoryRequested(self)
    }

    @objc private func closeClicked(_ sender: NSButton) {
        delegate?.searchBarCloseRequested(self)
    }
}
