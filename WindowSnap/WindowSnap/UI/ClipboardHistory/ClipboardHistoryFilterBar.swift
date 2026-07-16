import AppKit

protocol ClipboardHistoryFilterBarDelegate: AnyObject {
    func filterBar(_ filterBar: ClipboardHistoryFilterBar, didToggle type: ClipboardItemType, isActive: Bool)
}

final class ClipboardHistoryFilterBar: NSView {
    weak var delegate: ClipboardHistoryFilterBarDelegate?

    private let stackView = NSStackView()
    private var chipButtons: [ClipboardItemType: NSButton] = [:]
    private(set) var activeTypeFilters: Set<ClipboardItemType> = []

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
        stackView.orientation = .horizontal
        stackView.spacing = 7
        stackView.distribution = .fill
        stackView.alignment = .centerY
        stackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stackView)

        for (index, itemType) in ClipboardItemType.allCases.enumerated() {
            let chip = NSButton()
            chip.bezelStyle = .texturedRounded
            chip.isBordered = false
            chip.wantsLayer = true
            chip.title = itemType.displayName
            chip.font = NSFont.systemFont(ofSize: 10.5, weight: .medium)
            chip.contentTintColor = .secondaryLabelColor
            chip.tag = index
            chip.target = self
            chip.action = #selector(chipClicked(_:))
            chip.setAccessibilityLabel("Filter by \(itemType.displayName)")
            chip.translatesAutoresizingMaskIntoConstraints = false
            chip.heightAnchor.constraint(equalToConstant: 22).isActive = true
            chipButtons[itemType] = chip
            stackView.addArrangedSubview(chip)
        }

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        stackView.addArrangedSubview(spacer)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.topAnchor.constraint(equalTo: topAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])

        updateChipAppearances()
    }

    @objc private func chipClicked(_ sender: NSButton) {
        let allCases = ClipboardItemType.allCases
        guard sender.tag >= 0, sender.tag < allCases.count else { return }
        let type = allCases[sender.tag]

        if activeTypeFilters.contains(type) {
            activeTypeFilters.remove(type)
        } else {
            activeTypeFilters.insert(type)
        }

        updateChipAppearances()
        delegate?.filterBar(self, didToggle: type, isActive: activeTypeFilters.contains(type))
    }

    func updateChipAppearances() {
        for (type, chip) in chipButtons {
            let isActive = activeTypeFilters.contains(type)
            if isActive {
                chip.contentTintColor = .controlAccentColor
                chip.layer?.backgroundColor = NSColor.controlAccentColor
                    .withAlphaComponent(ClipboardHistoryTheme.chipActiveBackgroundAlpha).cgColor
                chip.layer?.borderWidth = 1
                chip.layer?.borderColor = NSColor.controlAccentColor
                    .withAlphaComponent(0.42).cgColor
                chip.layer?.cornerRadius = ClipboardHistoryTheme.chipCornerRadius
            } else {
                chip.contentTintColor = .secondaryLabelColor
                chip.layer?.backgroundColor = NSColor.quaternaryLabelColor
                    .withAlphaComponent(ClipboardHistoryTheme.chipInactiveBackgroundAlpha).cgColor
                chip.layer?.borderWidth = 1
                chip.layer?.borderColor = NSColor.separatorColor
                    .withAlphaComponent(0.12).cgColor
                chip.layer?.cornerRadius = ClipboardHistoryTheme.chipCornerRadius
            }
        }
    }
}
