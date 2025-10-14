import AppKit
import Foundation

/// The overlay window that displays throw position options
class ThrowOverlayWindow: NSWindow {
    
    private var positionViews: [ThrowPositionView] = []
    private var highlightedIndex: Int = -1
    
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
        
        // Make window cover the entire screen
        if let screen = NSScreen.main {
            setFrame(screen.frame, display: true)
        }
        
        setupContentView()
    }
    
    private func setupContentView() {
        let containerView = NSView(frame: contentRect(forFrameRect: frame))
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.3).cgColor
        contentView = containerView
    }
    
    /// Display the throw positions on the overlay
    func displayPositions(_ positions: [ThrowPosition], for targetWindow: WindowInfo) {
        clearPositions()
        
        guard let containerView = contentView else { return }
        
        // Create position views
        for position in positions {
            let positionView = ThrowPositionView(throwPosition: position)
            positionView.frame = position.frame
            containerView.addSubview(positionView)
            positionViews.append(positionView)
        }
        
        // Highlight the current window's frame
        highlightCurrentWindow(targetWindow)
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
    
    /// Clear all position views
    private func clearPositions() {
        positionViews.forEach { $0.removeFromSuperview() }
        positionViews.removeAll()
        highlightedIndex = -1
    }
    
    /// Highlight the current window's position
    private func highlightCurrentWindow(_ window: WindowInfo) {
        guard let containerView = contentView else { return }
        
        let currentWindowView = NSView(frame: window.frame)
        currentWindowView.wantsLayer = true
        currentWindowView.layer?.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.3).cgColor
        currentWindowView.layer?.borderColor = NSColor.systemBlue.cgColor
        currentWindowView.layer?.borderWidth = 2.0
        currentWindowView.layer?.cornerRadius = 4.0
        
        containerView.addSubview(currentWindowView)
        
        // Add label showing current window
        let label = NSTextField(labelWithString: "Current: \(window.windowTitle)")
        label.textColor = .white
        label.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.8)
        label.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        label.sizeToFit()
        label.frame.origin = CGPoint(
            x: window.frame.minX + 8,
            y: window.frame.maxY - label.frame.height - 8
        )
        currentWindowView.addSubview(label)
    }
    
    /// Handle mouse clicks on position views
    override func mouseDown(with event: NSEvent) {
        let clickLocation = event.locationInWindow
        
        for (index, positionView) in positionViews.enumerated() {
            if positionView.frame.contains(clickLocation) {
                highlightPosition(index + 1) // Convert to 1-based
                // Notify delegate or use callback
                NotificationCenter.default.post(
                    name: .throwPositionSelected,
                    object: nil,
                    userInfo: ["index": index + 1, "position": positionView.throwPosition]
                )
                return
            }
        }
        
        super.mouseDown(with: event)
    }
}

/// Individual position view in the throw overlay
class ThrowPositionView: NSView {
    
    let throwPosition: ThrowPosition
    private let calculator = ThrowPositionCalculator()
    private var isHighlighted = false
    
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
        
        // Add key label
        let keyLabel = NSTextField(labelWithString: calculator.getKeyCharacter(for: throwPosition.keyIndex))
        keyLabel.font = NSFont.boldSystemFont(ofSize: 24)
        keyLabel.textColor = .white
        keyLabel.backgroundColor = NSColor.black.withAlphaComponent(0.7)
        keyLabel.alignment = .center
        keyLabel.frame = CGRect(x: 8, y: frame.height - 40, width: 32, height: 32)
        addSubview(keyLabel)
        
        // Add position name label
        let nameLabel = NSTextField(labelWithString: throwPosition.shortDisplayName)
        nameLabel.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        nameLabel.textColor = .white
        nameLabel.backgroundColor = NSColor.black.withAlphaComponent(0.5)
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
            layer?.backgroundColor = NSColor.systemBlue.withAlphaComponent(0.4).cgColor
            layer?.borderColor = NSColor.systemBlue.cgColor
            layer?.borderWidth = 3.0
        } else {
            layer?.backgroundColor = NSColor.gray.withAlphaComponent(0.2).cgColor
            layer?.borderColor = NSColor.white.withAlphaComponent(0.5).cgColor
            layer?.borderWidth = 1.0
        }
        layer?.cornerRadius = 6.0
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let throwPositionSelected = Notification.Name("throwPositionSelected")
}
