import AppKit
import Foundation

/// Beautiful modern About window for WindowSnap
class AboutWindow: NSWindow {
    
    // MARK: - Design Constants
    private struct Design {
        static let windowWidth: CGFloat = 380
        static let windowHeight: CGFloat = 420
        static let cornerRadius: CGFloat = 20
        static let iconSize: CGFloat = 100
        
        // Colors
        static let accentPrimary = NSColor(red: 0.388, green: 0.404, blue: 0.945, alpha: 1.0)
        static let accentSecondary = NSColor(red: 0.545, green: 0.361, blue: 0.965, alpha: 1.0)
    }
    
    // MARK: - Singleton
    static let shared = AboutWindow()
    
    // MARK: - Initialization
    private init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: Design.windowWidth, height: Design.windowHeight),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        setupWindow()
        setupUI()
    }
    
    private func setupWindow() {
        title = ""
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        backgroundColor = .windowBackgroundColor
        isReleasedWhenClosed = false
        center()
    }
    
    private func setupUI() {
        guard let contentView = contentView else { return }
        
        // Visual effect background
        let visualEffect = NSVisualEffectView(frame: contentView.bounds)
        visualEffect.material = .windowBackground
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.autoresizingMask = [.width, .height]
        contentView.addSubview(visualEffect)
        
        // Icon container with gradient ring
        let iconContainer = createIconContainer()
        iconContainer.frame = NSRect(
            x: (Design.windowWidth - Design.iconSize - 20) / 2,
            y: Design.windowHeight - Design.iconSize - 60,
            width: Design.iconSize + 20,
            height: Design.iconSize + 20
        )
        contentView.addSubview(iconContainer)
        
        // App name
        let appNameLabel = NSTextField(labelWithString: "WindowSnap")
        appNameLabel.font = NSFont.systemFont(ofSize: 26, weight: .bold)
        appNameLabel.textColor = .labelColor
        appNameLabel.alignment = .center
        appNameLabel.frame = NSRect(x: 0, y: Design.windowHeight - 200, width: Design.windowWidth, height: 32)
        contentView.addSubview(appNameLabel)
        
        // Version
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        let versionLabel = NSTextField(labelWithString: "Version \(version) (\(build))")
        versionLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        versionLabel.textColor = .secondaryLabelColor
        versionLabel.alignment = .center
        versionLabel.frame = NSRect(x: 0, y: Design.windowHeight - 228, width: Design.windowWidth, height: 20)
        contentView.addSubview(versionLabel)
        
        // Tagline
        let taglineLabel = NSTextField(labelWithString: "A native window management app\nfor macOS power users")
        taglineLabel.font = NSFont.systemFont(ofSize: 13, weight: .regular)
        taglineLabel.textColor = .secondaryLabelColor
        taglineLabel.alignment = .center
        taglineLabel.maximumNumberOfLines = 2
        taglineLabel.frame = NSRect(x: 20, y: Design.windowHeight - 280, width: Design.windowWidth - 40, height: 40)
        contentView.addSubview(taglineLabel)
        
        // Divider
        let divider = NSBox()
        divider.boxType = .separator
        divider.frame = NSRect(x: 40, y: Design.windowHeight - 300, width: Design.windowWidth - 80, height: 1)
        contentView.addSubview(divider)
        
        // Feature badges
        let features = createFeatureBadges()
        features.frame = NSRect(x: 30, y: Design.windowHeight - 360, width: Design.windowWidth - 60, height: 50)
        contentView.addSubview(features)
        
        // Copyright
        let copyrightLabel = NSTextField(labelWithString: "© 2025 WindowSnap. All rights reserved.")
        copyrightLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        copyrightLabel.textColor = .tertiaryLabelColor
        copyrightLabel.alignment = .center
        copyrightLabel.frame = NSRect(x: 0, y: 50, width: Design.windowWidth, height: 16)
        contentView.addSubview(copyrightLabel)
        
        // Made with love
        let madeWithLabel = NSTextField(labelWithString: "Made with ❤️ using Swift and AppKit")
        madeWithLabel.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        madeWithLabel.textColor = .tertiaryLabelColor
        madeWithLabel.alignment = .center
        madeWithLabel.frame = NSRect(x: 0, y: 30, width: Design.windowWidth, height: 16)
        contentView.addSubview(madeWithLabel)
    }
    
    private func createIconContainer() -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: Design.iconSize + 20, height: Design.iconSize + 20))
        container.wantsLayer = true
        
        // Gradient ring
        let ringLayer = CAGradientLayer()
        ringLayer.colors = [Design.accentPrimary.cgColor, Design.accentSecondary.cgColor]
        ringLayer.startPoint = CGPoint(x: 0, y: 0.5)
        ringLayer.endPoint = CGPoint(x: 1, y: 0.5)
        ringLayer.frame = container.bounds
        ringLayer.cornerRadius = (Design.iconSize + 20) / 2
        
        // Create ring mask
        let ringMask = CAShapeLayer()
        let outerPath = CGPath(ellipseIn: container.bounds, transform: nil)
        let innerRect = container.bounds.insetBy(dx: 4, dy: 4)
        let innerPath = CGPath(ellipseIn: innerRect, transform: nil)
        
        let combinedPath = CGMutablePath()
        combinedPath.addPath(outerPath)
        combinedPath.addPath(innerPath)
        ringMask.path = combinedPath
        ringMask.fillRule = .evenOdd
        ringLayer.mask = ringMask
        
        container.layer?.addSublayer(ringLayer)
        
        // App icon
        let iconView = NSImageView(frame: NSRect(x: 10, y: 10, width: Design.iconSize, height: Design.iconSize))
        iconView.image = NSApp.applicationIconImage
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.wantsLayer = true
        iconView.layer?.cornerRadius = Design.iconSize / 2
        iconView.layer?.masksToBounds = true
        
        // Shadow for icon
        iconView.layer?.shadowColor = NSColor.black.cgColor
        iconView.layer?.shadowOpacity = 0.2
        iconView.layer?.shadowOffset = CGSize(width: 0, height: -2)
        iconView.layer?.shadowRadius = 8
        
        container.addSubview(iconView)
        
        return container
    }
    
    private func createFeatureBadges() -> NSView {
        let container = NSView()
        
        let features = [
            ("keyboard", "Shortcuts"),
            ("rectangle.3.group", "Layouts"),
            ("display.2", "Multi-Monitor"),
            ("doc.on.clipboard", "Clipboard")
        ]
        
        let badgeWidth: CGFloat = 70
        let spacing: CGFloat = 10
        let totalWidth = CGFloat(features.count) * badgeWidth + CGFloat(features.count - 1) * spacing
        var x = (Design.windowWidth - 60 - totalWidth) / 2
        
        for (icon, label) in features {
            let badge = createBadge(icon: icon, label: label)
            badge.frame.origin = NSPoint(x: x, y: 0)
            container.addSubview(badge)
            x += badgeWidth + spacing
        }
        
        return container
    }
    
    private func createBadge(icon: String, label: String) -> NSView {
        let badge = NSView(frame: NSRect(x: 0, y: 0, width: 70, height: 50))
        badge.wantsLayer = true
        badge.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        badge.layer?.cornerRadius = 10
        
        // Icon
        let iconView = NSImageView(frame: NSRect(x: 25, y: 22, width: 20, height: 20))
        if let image = NSImage(systemSymbolName: icon, accessibilityDescription: label) {
            iconView.image = image
            iconView.contentTintColor = Design.accentPrimary
        }
        badge.addSubview(iconView)
        
        // Label
        let labelView = NSTextField(labelWithString: label)
        labelView.font = NSFont.systemFont(ofSize: 9, weight: .medium)
        labelView.textColor = .secondaryLabelColor
        labelView.alignment = .center
        labelView.frame = NSRect(x: 0, y: 4, width: 70, height: 14)
        badge.addSubview(labelView)
        
        return badge
    }
    
    // MARK: - Public API
    
    func show() {
        center()
        makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
