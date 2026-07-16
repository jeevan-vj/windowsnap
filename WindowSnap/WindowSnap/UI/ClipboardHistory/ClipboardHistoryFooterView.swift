import AppKit

final class ClipboardHistoryFooterView: NSView {
    let shortcutHintsLabel = NSTextField(labelWithString: "")
    let itemCountLabel = NSTextField(labelWithString: "")

    private let stackView = NSStackView()

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
        shortcutHintsLabel.font = ClipboardHistoryTheme.footerFont
        shortcutHintsLabel.textColor = ClipboardHistoryTheme.footerTextColor
        shortcutHintsLabel.alignment = .left
        shortcutHintsLabel.lineBreakMode = .byTruncatingTail
        shortcutHintsLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        shortcutHintsLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        updateShortcutHints()

        itemCountLabel.font = ClipboardHistoryTheme.footerFont
        itemCountLabel.textColor = ClipboardHistoryTheme.footerTextColor
        itemCountLabel.alignment = .right
        itemCountLabel.setContentHuggingPriority(.required, for: .horizontal)
        itemCountLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        stackView.orientation = .horizontal
        stackView.distribution = .fill
        stackView.spacing = 8
        stackView.addArrangedSubview(shortcutHintsLabel)
        stackView.addArrangedSubview(itemCountLabel)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    func updateShortcutHints() {
        let hints = [
            "\u{21A9} Paste",
            "\u{2318}\u{232B} Delete",
            "\u{2318}P Pin",
            "\u{2318}C Copy",
            "esc Close",
        ]
        shortcutHintsLabel.stringValue = hints.joined(separator: " \u{00B7} ")
    }

    func updateItemCount(_ text: String) {
        itemCountLabel.stringValue = text
    }
}
