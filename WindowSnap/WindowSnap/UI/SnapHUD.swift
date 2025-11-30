import AppKit
import Foundation

/// Modern HUD notification for window snap feedback
/// Replaces deprecated NSUserNotification with a beautiful floating HUD
class SnapHUD: NSWindow {
    
    // MARK: - Design Constants
    private struct Design {
        static let windowWidth: CGFloat = 200
        static let windowHeight: CGFloat = 80
        static let cornerRadius: CGFloat = 16
        static let iconSize: CGFloat = 32
        static let animationDuration: TimeInterval = 0.2
        static let displayDuration: TimeInterval = 0.8
        
        // Colors
        static let backgroundColor = NSColor.black.withAlphaComponent(0.75)
        static let textColor = NSColor.white
        static let subtitleColor = NSColor.white.withAlphaComponent(0.7)
        static let accentColor = NSColor(red: 0.388, green: 0.404, blue: 0.945, alpha: 1.0)
    }
    
    // MARK: - Singleton
    static let shared = SnapHUD()
    
    // MARK: - UI Elements
    private var visualEffectView: NSVisualEffectView!
    private var iconImageView: NSImageView!
    private var titleLabel: NSTextField!
    private var subtitleLabel: NSTextField!
    private var containerView: NSView!
    
    // MARK: - State
    private var dismissWorkItem: DispatchWorkItem?
    private var isAnimating = false
    
    // MARK: - Initialization
    private init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: Design.windowWidth, height: Design.windowHeight),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        setupWindow()
        setupUI()
    }
    
    private func setupWindow() {
        level = .floating
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        isReleasedWhenClosed = false
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
    }
    
    private func setupUI() {
        // Container view
        containerView = NSView(frame: NSRect(x: 0, y: 0, width: Design.windowWidth, height: Design.windowHeight))
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = Design.cornerRadius
        containerView.layer?.masksToBounds = true
        
        // Visual effect for blur
        visualEffectView = NSVisualEffectView(frame: containerView.bounds)
        visualEffectView.material = .hudWindow
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = Design.cornerRadius
        containerView.addSubview(visualEffectView)
        
        // Dark overlay for better contrast
        let overlayView = NSView(frame: containerView.bounds)
        overlayView.wantsLayer = true
        overlayView.layer?.backgroundColor = Design.backgroundColor.cgColor
        overlayView.layer?.cornerRadius = Design.cornerRadius
        containerView.addSubview(overlayView)
        
        // Icon
        iconImageView = NSImageView(frame: NSRect(x: 20, y: (Design.windowHeight - Design.iconSize) / 2, width: Design.iconSize, height: Design.iconSize))
        iconImageView.imageScaling = .scaleProportionallyUpOrDown
        iconImageView.contentTintColor = Design.accentColor
        containerView.addSubview(iconImageView)
        
        // Title
        titleLabel = NSTextField(labelWithString: "")
        titleLabel.font = NSFont.systemFont(ofSize: 14, weight: .semibold)
        titleLabel.textColor = Design.textColor
        titleLabel.frame = NSRect(x: 64, y: 42, width: Design.windowWidth - 80, height: 20)
        titleLabel.lineBreakMode = .byTruncatingTail
        containerView.addSubview(titleLabel)
        
        // Subtitle (shortcut)
        subtitleLabel = NSTextField(labelWithString: "")
        subtitleLabel.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .medium)
        subtitleLabel.textColor = Design.subtitleColor
        subtitleLabel.frame = NSRect(x: 64, y: 20, width: Design.windowWidth - 80, height: 16)
        subtitleLabel.lineBreakMode = .byTruncatingTail
        containerView.addSubview(subtitleLabel)
        
        // Shadow
        containerView.shadow = NSShadow()
        containerView.layer?.shadowColor = NSColor.black.cgColor
        containerView.layer?.shadowOpacity = 0.3
        containerView.layer?.shadowOffset = CGSize(width: 0, height: -4)
        containerView.layer?.shadowRadius = 12
        
        contentView = containerView
        
        // Start hidden
        alphaValue = 0
    }
    
    // MARK: - Public API
    
    /// Show HUD for a grid position
    func show(for position: GridPosition, shortcut: String? = nil) {
        guard PreferencesManager.shared.showNotifications else { return }
        
        // Cancel any pending dismiss
        dismissWorkItem?.cancel()
        
        // Configure content
        titleLabel.stringValue = position.displayName
        subtitleLabel.stringValue = shortcut ?? position.defaultShortcut
        iconImageView.image = position.hudIcon
        
        // Position window at bottom center of main screen
        positionWindow()
        
        // Animate in
        animateIn()
        
        // Schedule dismiss
        let workItem = DispatchWorkItem { [weak self] in
            self?.animateOut()
        }
        dismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Design.displayDuration, execute: workItem)
    }
    
    /// Show HUD with custom message
    func show(title: String, subtitle: String, icon: NSImage?) {
        guard PreferencesManager.shared.showNotifications else { return }
        
        dismissWorkItem?.cancel()
        
        titleLabel.stringValue = title
        subtitleLabel.stringValue = subtitle
        iconImageView.image = icon
        iconImageView.contentTintColor = Design.accentColor
        
        positionWindow()
        animateIn()
        
        let workItem = DispatchWorkItem { [weak self] in
            self?.animateOut()
        }
        dismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Design.displayDuration, execute: workItem)
    }
    
    // MARK: - Private Methods
    
    private func positionWindow() {
        guard let screen = NSScreen.main else { return }
        
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - Design.windowWidth / 2
        let y = screenFrame.minY + 100 // 100pt from bottom
        
        setFrameOrigin(NSPoint(x: x, y: y))
    }
    
    private func animateIn() {
        guard !isAnimating else { return }
        isAnimating = true
        
        // Start below and transparent
        let currentOrigin = frame.origin
        setFrameOrigin(NSPoint(x: currentOrigin.x, y: currentOrigin.y - 20))
        alphaValue = 0
        
        // Make visible
        orderFront(nil)
        
        // Animate
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = Design.animationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            context.allowsImplicitAnimation = true
            
            self.animator().alphaValue = 1
            self.animator().setFrameOrigin(currentOrigin)
        }, completionHandler: {
            self.isAnimating = false
        })
    }
    
    private func animateOut() {
        guard !isAnimating else { return }
        isAnimating = true
        
        let currentOrigin = frame.origin
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = Design.animationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            context.allowsImplicitAnimation = true
            
            self.animator().alphaValue = 0
            self.animator().setFrameOrigin(NSPoint(x: currentOrigin.x, y: currentOrigin.y - 10))
        }, completionHandler: {
            self.orderOut(nil)
            self.isAnimating = false
        })
    }
}

// MARK: - GridPosition Extension for HUD

extension GridPosition {
    /// SF Symbol icon for HUD display
    var hudIcon: NSImage? {
        let symbolName: String
        
        switch self {
        case .leftHalf:
            symbolName = "rectangle.lefthalf.filled"
        case .rightHalf:
            symbolName = "rectangle.righthalf.filled"
        case .topHalf:
            symbolName = "rectangle.tophalf.filled"
        case .bottomHalf:
            symbolName = "rectangle.bottomhalf.filled"
        case .topLeft:
            symbolName = "rectangle.topthird.inset.filled"
        case .topRight:
            symbolName = "rectangle.topthird.inset.filled"
        case .bottomLeft:
            symbolName = "rectangle.bottomthird.inset.filled"
        case .bottomRight:
            symbolName = "rectangle.bottomthird.inset.filled"
        case .leftThird:
            symbolName = "rectangle.leftthird.inset.filled"
        case .centerThird:
            symbolName = "rectangle.center.inset.filled"
        case .rightThird:
            symbolName = "rectangle.rightthird.inset.filled"
        case .leftTwoThirds:
            symbolName = "rectangle.lefthalf.filled"
        case .rightTwoThirds:
            symbolName = "rectangle.righthalf.filled"
        case .maximize:
            symbolName = "rectangle.inset.filled"
        case .center:
            symbolName = "rectangle.center.inset.filled"
        }
        
        return NSImage(systemSymbolName: symbolName, accessibilityDescription: displayName)
    }
    
    /// Default keyboard shortcut string
    var defaultShortcut: String {
        switch self {
        case .leftHalf: return "⌘⇧←"
        case .rightHalf: return "⌘⇧→"
        case .topHalf: return "⌘⇧↑"
        case .bottomHalf: return "⌘⇧↓"
        case .topLeft: return "⌘⌥1"
        case .topRight: return "⌘⌥2"
        case .bottomLeft: return "⌘⌥3"
        case .bottomRight: return "⌘⌥4"
        case .leftThird: return "⌘⌥←"
        case .centerThird: return "⌘⌥C"
        case .rightThird: return "⌘⌥→"
        case .leftTwoThirds: return "⌘⌥↑"
        case .rightTwoThirds: return "⌘⌥↓"
        case .maximize: return "⌘⇧M"
        case .center: return "⌘⇧C"
        }
    }
}
