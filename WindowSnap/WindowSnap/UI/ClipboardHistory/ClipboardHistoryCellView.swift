import AppKit

protocol ClipboardHistoryCellDelegate: AnyObject {
    func clipboardCellDidRequestCopy(_ cell: ClipboardHistoryCellView, item: ClipboardHistoryItem)
    func clipboardCellDidRequestDelete(_ cell: ClipboardHistoryCellView, item: ClipboardHistoryItem)
    func clipboardCellDidRequestTogglePin(_ cell: ClipboardHistoryCellView, item: ClipboardHistoryItem)
}

final class SectionHeaderCellView: NSView {
    init(title: String) {
        super.init(frame: .zero)
        wantsLayer = true
        let label = NSTextField(labelWithString: title.uppercased())
        label.font = NSFont.systemFont(ofSize: 10, weight: .semibold)
        label.textColor = .secondaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

final class ModernTableRowView: NSTableRowView {
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

final class ClipboardHistoryCellView: NSView {
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
    weak var delegate: ClipboardHistoryCellDelegate?

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

    override var mouseDownCanMoveWindow: Bool { false }

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

        cardView = NSView()
        cardView.wantsLayer = true
        cardView.layer?.cornerRadius = ClipboardHistoryTheme.cardCornerRadius
        cardView.layer?.masksToBounds = true
        addSubview(cardView)

        iconContainer = NSView()
        iconContainer.wantsLayer = true
        iconContainer.layer?.cornerRadius = ClipboardHistoryTheme.iconCornerRadius
        iconContainer.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.08).cgColor
        cardView.addSubview(iconContainer)

        iconImageView = NSImageView()
        iconImageView.imageScaling = .scaleProportionallyUpOrDown
        iconImageView.wantsLayer = true
        iconImageView.layer?.cornerRadius = 4
        iconImageView.layer?.masksToBounds = true
        iconContainer.addSubview(iconImageView)

        previewLabel = NSTextField(labelWithString: "")
        previewLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        previewLabel.textColor = .labelColor
        previewLabel.lineBreakMode = .byTruncatingTail
        previewLabel.maximumNumberOfLines = 2
        cardView.addSubview(previewLabel)

        timestampLabel = NSTextField(labelWithString: "")
        timestampLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        timestampLabel.textColor = .secondaryLabelColor
        cardView.addSubview(timestampLabel)

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

        cardView.translatesAutoresizingMaskIntoConstraints = false
        iconContainer.translatesAutoresizingMaskIntoConstraints = false
        iconImageView.translatesAutoresizingMaskIntoConstraints = false
        previewLabel.translatesAutoresizingMaskIntoConstraints = false
        timestampLabel.translatesAutoresizingMaskIntoConstraints = false
        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        copyButton.translatesAutoresizingMaskIntoConstraints = false
        pinButton.translatesAutoresizingMaskIntoConstraints = false

        previewTrailingToCard = previewLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -12)
        previewTrailingToButtons = previewLabel.trailingAnchor.constraint(equalTo: deleteButton.leadingAnchor, constant: -8)
        timestampTrailingToCard = timestampLabel.trailingAnchor.constraint(lessThanOrEqualTo: cardView.trailingAnchor, constant: -12)
        timestampTrailingToButtons = timestampLabel.trailingAnchor.constraint(lessThanOrEqualTo: deleteButton.leadingAnchor, constant: -8)

        previewTrailingToCard.isActive = true
        timestampTrailingToCard.isActive = true

        let sharedConstraints: [NSLayoutConstraint] = [
            cardView.topAnchor.constraint(equalTo: topAnchor, constant: 1),
            cardView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 1),
            cardView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -1),
            cardView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -1),

            iconContainer.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 10),
            iconContainer.centerYAnchor.constraint(equalTo: cardView.centerYAnchor),

            previewLabel.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 10),
            previewLabel.topAnchor.constraint(equalTo: iconContainer.topAnchor),

            timestampLabel.leadingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: 10),
            timestampLabel.topAnchor.constraint(equalTo: previewLabel.bottomAnchor, constant: 2),

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
            iconContainer.widthAnchor.constraint(equalToConstant: 30),
            iconContainer.heightAnchor.constraint(equalToConstant: 30),
            iconImageView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconContainer.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 16),
            iconImageView.heightAnchor.constraint(equalToConstant: 16),
        ]

        layoutConstraintsImagePreview = [
            iconContainer.widthAnchor.constraint(equalToConstant: 52),
            iconContainer.heightAnchor.constraint(equalToConstant: 38),
            iconImageView.leadingAnchor.constraint(equalTo: iconContainer.leadingAnchor, constant: 2),
            iconImageView.trailingAnchor.constraint(equalTo: iconContainer.trailingAnchor, constant: -2),
            iconImageView.topAnchor.constraint(equalTo: iconContainer.topAnchor, constant: 2),
            iconImageView.bottomAnchor.constraint(equalTo: iconContainer.bottomAnchor, constant: -2),
        ]

        NSLayoutConstraint.activate(sharedConstraints + layoutConstraintsStandard)
        setupHoverTracking()
    }

    private func makeActionButton(icon: String, label: String) -> NSButton {
        let button = NSButton()
        button.bezelStyle = .texturedRounded
        button.isBordered = false
        button.wantsLayer = true
        button.imagePosition = .imageOnly
        button.contentTintColor = .secondaryLabelColor
        button.alphaValue = 0
        if let image = NSImage(systemSymbolName: icon, accessibilityDescription: label) {
            button.image = image
        }
        button.setAccessibilityLabel(label)
        return button
    }

    private func setImagePreviewLayout(_ usePreview: Bool) {
        guard usePreview != usesImagePreviewLayout else { return }
        NSLayoutConstraint.deactivate(usesImagePreviewLayout ? layoutConstraintsImagePreview : layoutConstraintsStandard)
        NSLayoutConstraint.activate(usePreview ? layoutConstraintsImagePreview : layoutConstraintsStandard)
        usesImagePreviewLayout = usePreview
        iconContainer.layer?.masksToBounds = usePreview
        iconContainer.layer?.backgroundColor = usePreview
            ? NSColor.quaternaryLabelColor.withAlphaComponent(0.12).cgColor
            : NSColor.controlAccentColor.withAlphaComponent(0.08).cgColor
        needsLayout = true
    }

    static func relativeTimeDescription(since date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "Just now" }
        if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes) min\(minutes == 1 ? "" : "s") ago"
        }
        if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func setupHoverTracking() {
        let options: NSTrackingArea.Options = [.activeInKeyWindow, .mouseEnteredAndExited, .inVisibleRect]
        hoverTrackingArea = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(hoverTrackingArea!)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let area = hoverTrackingArea { removeTrackingArea(area) }
        setupHoverTracking()
    }

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
        previewTrailingToCard.isActive = !visible
        previewTrailingToButtons.isActive = visible
        timestampTrailingToCard.isActive = !visible
        timestampTrailingToButtons.isActive = visible

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = ClipboardHistoryTheme.animationFast
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
            ctx.duration = ClipboardHistoryTheme.animationNormal
            ctx.allowsImplicitAnimation = true
            cardView.layer?.backgroundColor = entered
                ? NSColor.labelColor.withAlphaComponent(ClipboardHistoryTheme.hoverBackgroundAlpha).cgColor
                : NSColor.clear.cgColor
        }
    }

    private func updateAppearance() {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = ClipboardHistoryTheme.animationNormal
            ctx.allowsImplicitAnimation = true
            if isSelected {
                cardView.layer?.backgroundColor = NSColor.controlAccentColor
                    .withAlphaComponent(ClipboardHistoryTheme.selectionBackgroundAlpha).cgColor
                cardView.layer?.borderWidth = ClipboardHistoryTheme.selectionBorderWidth
                cardView.layer?.borderColor = NSColor.controlAccentColor
                    .withAlphaComponent(ClipboardHistoryTheme.selectionBorderAlpha).cgColor
            } else {
                cardView.layer?.backgroundColor = NSColor.clear.cgColor
                cardView.layer?.borderWidth = 0
                cardView.layer?.borderColor = nil
            }
        }
    }

    func configure(with item: ClipboardHistoryItem) {
        currentItem = item
        let hasImageThumbnail = item.type == .image && item.thumbnail != nil
        setImagePreviewLayout(hasImageThumbnail)

        if item.type == .image,
           let thumbString = item.thumbnail,
           let thumbData = Data(base64Encoded: thumbString),
           let thumbImage = NSImage(data: thumbData) {
            iconImageView.image = thumbImage
            iconImageView.contentTintColor = nil
            iconImageView.imageScaling = .scaleProportionallyUpOrDown
        } else if let image = NSImage(systemSymbolName: item.type.icon, accessibilityDescription: item.type.displayName) {
            iconImageView.image = image
            iconImageView.contentTintColor = .controlAccentColor
            iconImageView.imageScaling = .scaleProportionallyDown
        }

        if hasImageThumbnail {
            if let width = item.imageWidth, let height = item.imageHeight {
                previewLabel.stringValue = "Copied Image (\(width) \u{00D7} \(height))"
            } else {
                previewLabel.stringValue = "Copied Image"
            }
        } else {
            previewLabel.stringValue = item.preview
        }

        timestampLabel.stringValue = Self.relativeTimeDescription(since: item.timestamp)

        if item.type != .image {
            previewLabel.toolTip = item.content.count > 500
                ? String(item.content.prefix(500)) + "..."
                : item.content
        } else {
            previewLabel.toolTip = nil
        }

        updatePinButtonState(isPinned: item.isPinned)
        updatePinnedAppearance(isPinned: item.isPinned)
        updateAppearance()
    }

    private func updatePinButtonState(isPinned: Bool) {
        let iconName = isPinned ? "pin.fill" : "pin"
        if let image = NSImage(systemSymbolName: iconName, accessibilityDescription: isPinned ? "Unpin" : "Pin") {
            pinButton.image = image
        }
        pinButton.contentTintColor = isPinned ? .controlAccentColor : .secondaryLabelColor
        pinButton.setAccessibilityLabel(isPinned ? "Unpin item" : "Pin item")
        if isPinned { pinButton.alphaValue = 0.7 }
    }

    private func updatePinnedAppearance(isPinned: Bool) {
        if isPinned, !isSelected {
            cardView.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.04).cgColor
        }
    }

    @objc private func copyButtonClicked(_ sender: NSButton) {
        guard let item = currentItem else { return }
        animateButtonTap(sender)
        if let checkImage = NSImage(systemSymbolName: "checkmark", accessibilityDescription: "Copied") {
            let original = sender.image
            sender.image = checkImage
            sender.contentTintColor = .controlAccentColor
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                sender.image = original
                sender.contentTintColor = .secondaryLabelColor
            }
        }
        delegate?.clipboardCellDidRequestCopy(self, item: item)
    }

    @objc private func deleteButtonClicked(_ sender: NSButton) {
        guard let item = currentItem else { return }
        animateButtonTap(sender)
        delegate?.clipboardCellDidRequestDelete(self, item: item)
    }

    @objc private func pinButtonClicked(_ sender: NSButton) {
        guard let item = currentItem else { return }
        animateButtonTap(sender)
        delegate?.clipboardCellDidRequestTogglePin(self, item: item)
    }

    private func animateButtonTap(_ button: NSButton) {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = ClipboardHistoryTheme.animationFast
            ctx.allowsImplicitAnimation = true
            button.layer?.transform = CATransform3DMakeScale(0.88, 0.88, 1)
        }, completionHandler: {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = ClipboardHistoryTheme.animationFast
                ctx.allowsImplicitAnimation = true
                button.layer?.transform = CATransform3DIdentity
            }
        })
    }
}
