import AppKit

final class NonDraggableTextField: NSTextField {
    override var mouseDownCanMoveWindow: Bool { false }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override var acceptsFirstResponder: Bool { true }
}

final class HoverableClearButtonContainer: NSView {
    var button: NSButton?
    var hoverTintColor: NSColor = .systemRed
    var hoverBackgroundColor: NSColor = .systemRed
    var defaultBackgroundAlpha: CGFloat = 0.0
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
            layer?.backgroundColor = hoverBackgroundColor.withAlphaComponent(0.14).cgColor
            button?.contentTintColor = hoverTintColor
        }
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = ClipboardHistoryTheme.animationFast
            ctx.allowsImplicitAnimation = true
            layer?.backgroundColor = NSColor.quaternaryLabelColor.withAlphaComponent(defaultBackgroundAlpha).cgColor
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
    private let closeButtonContainer = HoverableClearButtonContainer()
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
            .withAlphaComponent(0.18).cgColor

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
        searchField.font = NSFont.systemFont(ofSize: 14.5)
        searchField.target = self
        searchField.action = #selector(searchFieldChanged(_:))
        searchField.setAccessibilityLabel("Search clipboard history")
        searchField.setAccessibilityRole(.textField)
        searchContainerView.addSubview(searchField)

        configureActionButton(clearButton, icon: "trash", label: "Clear All History", accessibilityLabel: "Clear all clipboard history")
        clearButton.target = self
        clearButton.action = #selector(clearHistoryClicked(_:))
        clearButton.toolTip = "Clear All History"

        clearButtonContainer.wantsLayer = true
        clearButtonContainer.layer?.backgroundColor = NSColor.quaternaryLabelColor
            .withAlphaComponent(clearButtonContainer.defaultBackgroundAlpha).cgColor
        clearButtonContainer.layer?.cornerRadius = ClipboardHistoryTheme.actionButtonCornerRadius
        clearButtonContainer.button = clearButton
        clearButtonContainer.addSubview(clearButton)

        configureActionButton(closeButton, icon: "xmark", label: "Close", accessibilityLabel: "Close clipboard history")
        closeButton.target = self
        closeButton.action = #selector(closeClicked(_:))
        closeButton.toolTip = "Close"
        closeButtonContainer.wantsLayer = true
        closeButtonContainer.layer?.backgroundColor = NSColor.quaternaryLabelColor
            .withAlphaComponent(closeButtonContainer.defaultBackgroundAlpha).cgColor
        closeButtonContainer.layer?.cornerRadius = ClipboardHistoryTheme.actionButtonCornerRadius
        closeButtonContainer.hoverTintColor = .labelColor
        closeButtonContainer.hoverBackgroundColor = .quaternaryLabelColor
        closeButtonContainer.button = closeButton
        closeButtonContainer.addSubview(closeButton)

        addSubview(searchContainerView)
        addSubview(clearButtonContainer)
        addSubview(closeButtonContainer)

        searchContainerView.translatesAutoresizingMaskIntoConstraints = false
        searchIconView.translatesAutoresizingMaskIntoConstraints = false
        searchField.translatesAutoresizingMaskIntoConstraints = false
        clearButtonContainer.translatesAutoresizingMaskIntoConstraints = false
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        closeButtonContainer.translatesAutoresizingMaskIntoConstraints = false
        closeButton.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            searchContainerView.topAnchor.constraint(equalTo: topAnchor),
            searchContainerView.leadingAnchor.constraint(equalTo: leadingAnchor),
            searchContainerView.trailingAnchor.constraint(equalTo: clearButtonContainer.leadingAnchor, constant: -ClipboardHistoryTheme.searchActionSpacing),
            searchContainerView.heightAnchor.constraint(equalToConstant: ClipboardHistoryTheme.searchHeight),
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
            clearButtonContainer.trailingAnchor.constraint(equalTo: closeButtonContainer.leadingAnchor, constant: -ClipboardHistoryTheme.searchActionSpacing),
            clearButtonContainer.widthAnchor.constraint(equalToConstant: ClipboardHistoryTheme.searchActionButtonSize),
            clearButtonContainer.heightAnchor.constraint(equalToConstant: ClipboardHistoryTheme.searchActionButtonSize),

            clearButton.centerXAnchor.constraint(equalTo: clearButtonContainer.centerXAnchor),
            clearButton.centerYAnchor.constraint(equalTo: clearButtonContainer.centerYAnchor),
            clearButton.widthAnchor.constraint(equalToConstant: ClipboardHistoryTheme.searchActionIconSize),
            clearButton.heightAnchor.constraint(equalToConstant: ClipboardHistoryTheme.searchActionIconSize),

            closeButtonContainer.centerYAnchor.constraint(equalTo: searchContainerView.centerYAnchor),
            closeButtonContainer.trailingAnchor.constraint(equalTo: trailingAnchor),
            closeButtonContainer.widthAnchor.constraint(equalToConstant: ClipboardHistoryTheme.searchActionButtonSize),
            closeButtonContainer.heightAnchor.constraint(equalToConstant: ClipboardHistoryTheme.searchActionButtonSize),

            closeButton.centerXAnchor.constraint(equalTo: closeButtonContainer.centerXAnchor),
            closeButton.centerYAnchor.constraint(equalTo: closeButtonContainer.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: ClipboardHistoryTheme.searchActionIconSize),
            closeButton.heightAnchor.constraint(equalToConstant: ClipboardHistoryTheme.searchActionIconSize),
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

    private func configureActionButton(_ button: NSButton, icon: String, label: String, accessibilityLabel: String) {
        button.bezelStyle = .texturedRounded
        button.wantsLayer = true
        button.contentTintColor = .secondaryLabelColor
        button.isBordered = false
        button.imagePosition = .imageOnly
        if let image = NSImage(systemSymbolName: icon, accessibilityDescription: label) {
            button.image = image
        }
        button.setAccessibilityLabel(accessibilityLabel)
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
