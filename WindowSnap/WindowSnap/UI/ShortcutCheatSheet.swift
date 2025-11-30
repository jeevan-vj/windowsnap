import AppKit
import Foundation

/// Beautiful shortcut reference overlay
/// Shows all available keyboard shortcuts in an organized, visually appealing format
class ShortcutCheatSheet: NSWindow {
    
    // MARK: - Design Constants
    private struct Design {
        static let windowWidth: CGFloat = 600
        static let windowHeight: CGFloat = 520
        static let cornerRadius: CGFloat = 20
        static let animationDuration: TimeInterval = 0.25
        
        // Colors
        static let backgroundColor = NSColor(white: 0.1, alpha: 0.95)
        static let cardBackground = NSColor(white: 0.15, alpha: 1.0)
        static let titleColor = NSColor.white
        static let labelColor = NSColor.white.withAlphaComponent(0.9)
        static let shortcutColor = NSColor(red: 0.388, green: 0.404, blue: 0.945, alpha: 1.0)
        static let subtitleColor = NSColor.white.withAlphaComponent(0.5)
        static let separatorColor = NSColor.white.withAlphaComponent(0.1)
    }
    
    // MARK: - Singleton
    static let shared = ShortcutCheatSheet()
    
    // MARK: - State
    private var isShowing = false
    
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
        collectionBehavior = [.canJoinAllSpaces, .stationary]
    }
    
    private func setupUI() {
        let containerView = NSView(frame: NSRect(x: 0, y: 0, width: Design.windowWidth, height: Design.windowHeight))
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = Design.cornerRadius
        containerView.layer?.backgroundColor = Design.backgroundColor.cgColor
        containerView.layer?.masksToBounds = true
        
        // Shadow
        containerView.layer?.shadowColor = NSColor.black.cgColor
        containerView.layer?.shadowOpacity = 0.5
        containerView.layer?.shadowOffset = CGSize(width: 0, height: -8)
        containerView.layer?.shadowRadius = 30
        
        // Title
        let titleLabel = createLabel(text: "WindowSnap Shortcuts", size: 20, weight: .bold, color: Design.titleColor)
        titleLabel.frame = NSRect(x: 0, y: Design.windowHeight - 50, width: Design.windowWidth, height: 30)
        titleLabel.alignment = .center
        containerView.addSubview(titleLabel)
        
        // Shortcut sections
        let sectionWidth: CGFloat = 270
        let sectionHeight: CGFloat = 160
        let padding: CGFloat = 20
        let sectionY1: CGFloat = Design.windowHeight - 80 - sectionHeight
        let sectionY2: CGFloat = sectionY1 - sectionHeight - 15
        
        // Section 1: Halves (top-left)
        let halvesSection = createShortcutSection(
            title: "Halves",
            shortcuts: [
                ("⌘⇧←", "Left Half"),
                ("⌘⇧→", "Right Half"),
                ("⌘⇧↑", "Top Half"),
                ("⌘⇧↓", "Bottom Half")
            ],
            frame: NSRect(x: padding, y: sectionY1, width: sectionWidth, height: sectionHeight)
        )
        containerView.addSubview(halvesSection)
        
        // Section 2: Quarters (top-right)
        let quartersSection = createShortcutSection(
            title: "Quarters",
            shortcuts: [
                ("⌘⌥1", "Top Left"),
                ("⌘⌥2", "Top Right"),
                ("⌘⌥3", "Bottom Left"),
                ("⌘⌥4", "Bottom Right")
            ],
            frame: NSRect(x: Design.windowWidth - sectionWidth - padding, y: sectionY1, width: sectionWidth, height: sectionHeight)
        )
        containerView.addSubview(quartersSection)
        
        // Section 3: Thirds (bottom-left)
        let thirdsSection = createShortcutSection(
            title: "Thirds",
            shortcuts: [
                ("⌘⌥←", "Left Third"),
                ("⌘⌥→", "Right Third"),
                ("⌘⌥↑", "Left Two-Thirds"),
                ("⌘⌥↓", "Right Two-Thirds")
            ],
            frame: NSRect(x: padding, y: sectionY2, width: sectionWidth, height: sectionHeight)
        )
        containerView.addSubview(thirdsSection)
        
        // Section 4: Special & Actions (bottom-right)
        let specialSection = createShortcutSection(
            title: "Special & Actions",
            shortcuts: [
                ("⌘⇧M", "Maximize"),
                ("⌘⇧C", "Center"),
                ("⌘⌥Z", "Undo"),
                ("⌘⌥⇧Z", "Redo")
            ],
            frame: NSRect(x: Design.windowWidth - sectionWidth - padding, y: sectionY2, width: sectionWidth, height: sectionHeight)
        )
        containerView.addSubview(specialSection)
        
        // Advanced shortcuts section
        let advancedY = sectionY2 - 95
        let advancedSection = createAdvancedSection(
            frame: NSRect(x: padding, y: advancedY, width: Design.windowWidth - (padding * 2), height: 80)
        )
        containerView.addSubview(advancedSection)
        
        // Footer
        let footerLabel = createLabel(text: "Press Escape or any key to close", size: 12, weight: .regular, color: Design.subtitleColor)
        footerLabel.frame = NSRect(x: 0, y: 15, width: Design.windowWidth, height: 20)
        footerLabel.alignment = .center
        containerView.addSubview(footerLabel)
        
        contentView = containerView
        
        // Start hidden
        alphaValue = 0
    }
    
    private func createShortcutSection(title: String, shortcuts: [(String, String)], frame: NSRect) -> NSView {
        let section = NSView(frame: frame)
        section.wantsLayer = true
        section.layer?.backgroundColor = Design.cardBackground.cgColor
        section.layer?.cornerRadius = 12
        
        // Title
        let titleLabel = createLabel(text: title, size: 13, weight: .semibold, color: Design.shortcutColor)
        titleLabel.frame = NSRect(x: 16, y: frame.height - 32, width: frame.width - 32, height: 20)
        section.addSubview(titleLabel)
        
        // Shortcuts
        var y: CGFloat = frame.height - 58
        for (shortcut, description) in shortcuts {
            let row = createShortcutRow(shortcut: shortcut, description: description, width: frame.width - 32)
            row.frame.origin = NSPoint(x: 16, y: y)
            section.addSubview(row)
            y -= 28
        }
        
        return section
    }
    
    private func createAdvancedSection(frame: NSRect) -> NSView {
        let section = NSView(frame: frame)
        section.wantsLayer = true
        section.layer?.backgroundColor = Design.cardBackground.cgColor
        section.layer?.cornerRadius = 12
        
        // Title
        let titleLabel = createLabel(text: "Advanced", size: 13, weight: .semibold, color: Design.shortcutColor)
        titleLabel.frame = NSRect(x: 16, y: frame.height - 28, width: 100, height: 20)
        section.addSubview(titleLabel)
        
        // Horizontal layout for advanced shortcuts
        let shortcuts = [
            ("⌃⌥⌘→", "Next Display"),
            ("⌃⌥⌘←", "Prev Display"),
            ("⌃⌥⇧→", "Larger"),
            ("⌃⌥⇧←", "Smaller"),
            ("⌃⌥⌘Space", "Throw"),
            ("⌘⇧V", "Clipboard")
        ]
        
        let itemWidth: CGFloat = (frame.width - 32) / 3
        var x: CGFloat = 16
        var y: CGFloat = frame.height - 58
        
        for (index, (shortcut, description)) in shortcuts.enumerated() {
            if index == 3 {
                x = 16
                y -= 24
            }
            
            let row = createCompactShortcutRow(shortcut: shortcut, description: description, width: itemWidth - 8)
            row.frame.origin = NSPoint(x: x, y: y)
            section.addSubview(row)
            
            x += itemWidth
        }
        
        return section
    }
    
    private func createShortcutRow(shortcut: String, description: String, width: CGFloat) -> NSView {
        let row = NSView(frame: NSRect(x: 0, y: 0, width: width, height: 24))
        
        // Shortcut badge
        let shortcutLabel = createLabel(text: shortcut, size: 12, weight: .medium, color: Design.titleColor)
        shortcutLabel.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)
        shortcutLabel.frame = NSRect(x: 0, y: 2, width: 60, height: 20)
        
        // Background for shortcut
        let badgeView = NSView(frame: NSRect(x: 0, y: 0, width: 60, height: 24))
        badgeView.wantsLayer = true
        badgeView.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.1).cgColor
        badgeView.layer?.cornerRadius = 6
        row.addSubview(badgeView)
        row.addSubview(shortcutLabel)
        
        // Description
        let descLabel = createLabel(text: description, size: 13, weight: .regular, color: Design.labelColor)
        descLabel.frame = NSRect(x: 70, y: 2, width: width - 70, height: 20)
        row.addSubview(descLabel)
        
        return row
    }
    
    private func createCompactShortcutRow(shortcut: String, description: String, width: CGFloat) -> NSView {
        let row = NSView(frame: NSRect(x: 0, y: 0, width: width, height: 20))
        
        // Shortcut
        let shortcutLabel = createLabel(text: shortcut, size: 10, weight: .medium, color: Design.titleColor)
        shortcutLabel.font = NSFont.monospacedSystemFont(ofSize: 10, weight: .medium)
        shortcutLabel.frame = NSRect(x: 0, y: 0, width: 65, height: 20)
        
        // Badge background
        let badgeView = NSView(frame: NSRect(x: 0, y: 0, width: 65, height: 20))
        badgeView.wantsLayer = true
        badgeView.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.1).cgColor
        badgeView.layer?.cornerRadius = 4
        row.addSubview(badgeView)
        row.addSubview(shortcutLabel)
        
        // Description
        let descLabel = createLabel(text: description, size: 11, weight: .regular, color: Design.subtitleColor)
        descLabel.frame = NSRect(x: 70, y: 0, width: width - 70, height: 20)
        row.addSubview(descLabel)
        
        return row
    }
    
    private func createLabel(text: String, size: CGFloat, weight: NSFont.Weight, color: NSColor) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: size, weight: weight)
        label.textColor = color
        label.backgroundColor = .clear
        label.isBezeled = false
        label.isEditable = false
        return label
    }
    
    // MARK: - Public API
    
    /// Toggle cheat sheet visibility
    func toggle() {
        if isShowing {
            hide()
        } else {
            show()
        }
    }
    
    /// Show the cheat sheet
    func show() {
        guard !isShowing else { return }
        isShowing = true
        
        // Center on screen
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.frame
        let x = screenFrame.midX - Design.windowWidth / 2
        let y = screenFrame.midY - Design.windowHeight / 2
        setFrameOrigin(NSPoint(x: x, y: y))
        
        // Animate in
        contentView?.layer?.transform = CATransform3DMakeScale(0.9, 0.9, 1)
        alphaValue = 0
        
        orderFront(nil)
        makeKey()
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Design.animationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            context.allowsImplicitAnimation = true
            
            self.alphaValue = 1
            self.contentView?.layer?.transform = CATransform3DIdentity
        }
    }
    
    /// Hide the cheat sheet
    func hide() {
        guard isShowing else { return }
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = Design.animationDuration * 0.8
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            context.allowsImplicitAnimation = true
            
            self.alphaValue = 0
            self.contentView?.layer?.transform = CATransform3DMakeScale(0.95, 0.95, 1)
        }, completionHandler: {
            self.orderOut(nil)
            self.isShowing = false
        })
    }
    
    // MARK: - Key Handling
    
    override func keyDown(with event: NSEvent) {
        // Close on any key press (including Escape)
        hide()
    }
    
    override func mouseDown(with event: NSEvent) {
        // Close on click outside content
        hide()
    }
    
    override var canBecomeKey: Bool { true }
}
