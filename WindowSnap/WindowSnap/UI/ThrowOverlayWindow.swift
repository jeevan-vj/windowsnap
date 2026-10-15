import AppKit
import Foundation

/// The overlay window that displays throw position options
@MainActor
final class ThrowOverlayWindow: NSWindow {
    
    private var positionViews: [ThrowPositionView] = []
    private var highlightedIndex: Int = -1
    var onCancel: (() -> Void)?
    
    init() {
        super.init(
            contentRect: NSRect.zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        setupWindow()
    }
    
    private func setupWindow() {
        level = .floating
        backgroundColor = NSColor.clear
        isOpaque = false
        hasShadow = false
        ignoresMouseEvents = false
        collectionBehavior = [.canJoinAllSpaces, .stationary]
        isReleasedWhenClosed = false
        setupContentView()
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel("Window throw positions")
        setAccessibilityHelp("Use the arrow keys to choose a position, Return to confirm, or Escape to cancel.")
        setAccessibilityCustomActions([
            NSAccessibilityCustomAction(name: "Confirm highlighted position") { [weak self] in
                self?.confirmHighlightedPosition() ?? false
            },
            NSAccessibilityCustomAction(name: "Cancel window throw") { [weak self] in
                guard let self else { return false }
                self.onCancel?()
                return true
            }
        ])
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
    
    private func setupContentView() {
        let containerView = NSView(frame: contentRect(forFrameRect: frame))
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.underPageBackgroundColor.withAlphaComponent(0.55).cgColor
        contentView = containerView
    }
    
    /// Display the throw positions on the overlay covering `screen`.
    func displayPositions(_ positions: [ThrowPosition], for targetWindow: WindowInfo, on screen: NSScreen) {
        setFrame(screen.frame, display: true)
        contentView?.frame = contentRect(forFrameRect: frame)
        clearPositions()

        guard let containerView = contentView else { return }

        for (index, position) in positions.enumerated() {
            let localFrame = CoordinateConverter.windowLocalRect(
                fromGlobalAppKitRect: position.frame,
                screenFrame: screen.frame
            )
            let positionView = ThrowPositionView(throwPosition: position)
            positionView.onActivate = { [weak self] in
                self?.selectPosition(at: index + 1)
            }
            positionView.frame = localFrame
            containerView.addSubview(positionView)
            positionViews.append(positionView)
        }

        highlightCurrentWindow(targetWindow, on: screen)
        if !positionViews.isEmpty {
            highlightPosition(1)
        }
    }
    
    /// Highlight a specific position by index
    func highlightPosition(_ index: Int) {
        // Remove previous highlight
        if highlightedIndex >= 0 && highlightedIndex < positionViews.count {
            positionViews[highlightedIndex].setHighlighted(false)
        }
        
        // Set new highlight
        highlightedIndex = index - 1 // Convert from 1-based to 0-based
        if highlightedIndex >= 0 && highlightedIndex < positionViews.count {
            positionViews[highlightedIndex].setHighlighted(true)
        }
    }
    
    /// Get the position for a given index
    func getPosition(for index: Int) -> ThrowPosition? {
        let arrayIndex = index - 1 // Convert from 1-based to 0-based
        guard arrayIndex >= 0 && arrayIndex < positionViews.count else { return nil }
        return positionViews[arrayIndex].throwPosition
    }

    func moveHighlight(by offset: Int) {
        guard !positionViews.isEmpty else { return }
        let current = highlightedIndex >= 0 ? highlightedIndex : 0
        let next = (current + offset + positionViews.count) % positionViews.count
        highlightPosition(next + 1)
    }

    @discardableResult
    func confirmHighlightedPosition() -> Bool {
        guard positionViews.indices.contains(highlightedIndex) else {
            NSSound.beep()
            return false
        }
        selectPosition(at: highlightedIndex + 1)
        return true
    }

    private func selectPosition(at index: Int) {
        guard let position = getPosition(for: index) else { return }
        NotificationCenter.default.post(
            name: .throwPositionSelected,
            object: self,
            userInfo: ["index": index, "position": position]
        )
    }
    
    /// Clear all position views
    private func clearPositions() {
        contentView?.subviews.forEach { $0.removeFromSuperview() }
        positionViews.removeAll()
        highlightedIndex = -1
    }
    
    /// Highlight the current window's position
    private func highlightCurrentWindow(_ window: WindowInfo, on screen: NSScreen) {
        guard let containerView = contentView else { return }

        let appKitFrame = CoordinateConverter.appKitRect(
            fromAXRect: window.frame,
            primaryScreenHeight: CoordinateConverter.primaryScreenHeight
        )
        let localFrame = CoordinateConverter.windowLocalRect(
            fromGlobalAppKitRect: appKitFrame,
            screenFrame: screen.frame
        )

        let currentWindowView = NSView(frame: localFrame)
        currentWindowView.wantsLayer = true
        currentWindowView.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.25).cgColor
        currentWindowView.layer?.borderColor = NSColor.controlAccentColor.cgColor
        currentWindowView.layer?.borderWidth = 2.0
        currentWindowView.layer?.cornerRadius = 4.0

        containerView.addSubview(currentWindowView)

        let label = NSTextField(labelWithString: "Current: \(window.windowTitle)")
        label.textColor = .labelColor
        label.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.45)
        label.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        label.sizeToFit()
        label.frame.origin = CGPoint(x: 8, y: max(8, localFrame.height - label.frame.height - 8))
        currentWindowView.addSubview(label)
    }
    
    /// Handle mouse clicks on position views
    override func mouseDown(with event: NSEvent) {
        let clickLocation = event.locationInWindow
        
        for (index, positionView) in positionViews.enumerated() {
            if positionView.frame.contains(clickLocation) {
                highlightPosition(index + 1) // Convert to 1-based
                // Notify delegate or use callback
                selectPosition(at: index + 1)
                return
            }
        }
        
        super.mouseDown(with: event)
    }
}

/// Individual position view in the throw overlay
@MainActor
final class ThrowPositionView: NSView {
    
    let throwPosition: ThrowPosition
    private let calculator = ThrowPositionCalculator()
    private var isHighlighted = false
    var onActivate: (() -> Void)?
    
    init(throwPosition: ThrowPosition) {
        self.throwPosition = throwPosition
        super.init(frame: throwPosition.frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        wantsLayer = true
        updateAppearance()
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        setAccessibilityLabel("\(throwPosition.shortDisplayName), key \(calculator.getKeyCharacter(for: throwPosition.keyIndex))")
        setAccessibilityHelp("Moves the current window to \(throwPosition.displayName).")
        setAccessibilityCustomActions([
            NSAccessibilityCustomAction(name: "Choose position") { [weak self] in
                guard let self else { return false }
                self.onActivate?()
                return true
            }
        ])
        
        // Add key label
        let keyLabel = NSTextField(labelWithString: calculator.getKeyCharacter(for: throwPosition.keyIndex))
        keyLabel.font = NSFont.boldSystemFont(ofSize: 24)
        keyLabel.textColor = .labelColor
        keyLabel.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.85)
        keyLabel.alignment = .center
        keyLabel.frame = CGRect(x: 8, y: frame.height - 40, width: 32, height: 32)
        addSubview(keyLabel)
        
        // Add position name label
        let nameLabel = NSTextField(labelWithString: throwPosition.shortDisplayName)
        nameLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        nameLabel.textColor = .labelColor
        nameLabel.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.7)
        nameLabel.alignment = .center
        nameLabel.sizeToFit()
        nameLabel.frame.size.width += 16 // Add padding
        nameLabel.frame.origin = CGPoint(
            x: (frame.width - nameLabel.frame.width) / 2,
            y: (frame.height - nameLabel.frame.height) / 2
        )
        addSubview(nameLabel)
    }
    
    func setHighlighted(_ highlighted: Bool) {
        isHighlighted = highlighted
        updateAppearance()
    }
    
    private func updateAppearance() {
        if isHighlighted {
            layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.4).cgColor
            layer?.borderColor = NSColor.controlAccentColor.cgColor
            layer?.borderWidth = 3.0
        } else {
            layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.35).cgColor
            layer?.borderColor = NSColor.separatorColor.cgColor
            layer?.borderWidth = 1.0
        }
        layer?.cornerRadius = 6.0
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let throwPositionSelected = Notification.Name("throwPositionSelected")
}
