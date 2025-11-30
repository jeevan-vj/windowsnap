import AppKit
import Foundation

/// Visual preview overlay showing where a window will snap
/// Provides immediate visual feedback during window positioning
class SnapPreviewOverlay: NSWindow {
    
    // MARK: - Design Constants
    private struct Design {
        static let cornerRadius: CGFloat = 12
        static let borderWidth: CGFloat = 3
        static let animationDurationIn: TimeInterval = 0.15
        static let animationDurationOut: TimeInterval = 0.1
        static let holdDuration: TimeInterval = 0.15
        
        // Colors - Accent gradient
        static let fillColor = NSColor(red: 0.388, green: 0.404, blue: 0.945, alpha: 0.15)
        static let borderColor = NSColor(red: 0.388, green: 0.404, blue: 0.945, alpha: 0.6)
        static let glowColor = NSColor(red: 0.388, green: 0.404, blue: 0.945, alpha: 0.3)
    }
    
    // MARK: - Singleton
    static let shared = SnapPreviewOverlay()
    
    // MARK: - UI Elements
    private var previewView: SnapPreviewView!
    
    // MARK: - State
    private var isShowing = false
    private var dismissWorkItem: DispatchWorkItem?
    
    // MARK: - Initialization
    private init() {
        super.init(
            contentRect: NSRect.zero,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        setupWindow()
        setupPreviewView()
    }
    
    private func setupWindow() {
        level = .floating
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        isReleasedWhenClosed = false
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
    }
    
    private func setupPreviewView() {
        previewView = SnapPreviewView()
        contentView = previewView
    }
    
    // MARK: - Public API
    
    /// Show preview for a grid position on a specific screen
    func show(for position: GridPosition, on screen: NSScreen) {
        // Cancel any pending dismiss
        dismissWorkItem?.cancel()
        
        // Calculate target frame
        guard let targetFrame = calculateTargetFrame(for: position, on: screen) else {
            return
        }
        
        // Set window frame
        setFrame(targetFrame, display: true)
        previewView.frame = NSRect(origin: .zero, size: targetFrame.size)
        
        // Show with animation
        if !isShowing {
            animateIn()
        }
        
        // Schedule hide
        let workItem = DispatchWorkItem { [weak self] in
            self?.animateOut()
        }
        dismissWorkItem = workItem
        
        let totalDuration = Design.animationDurationIn + Design.holdDuration
        DispatchQueue.main.asyncAfter(deadline: .now() + totalDuration, execute: workItem)
    }
    
    /// Show preview at a specific frame
    func show(at frame: CGRect) {
        dismissWorkItem?.cancel()
        
        setFrame(frame, display: true)
        previewView.frame = NSRect(origin: .zero, size: frame.size)
        
        if !isShowing {
            animateIn()
        }
        
        let workItem = DispatchWorkItem { [weak self] in
            self?.animateOut()
        }
        dismissWorkItem = workItem
        
        let totalDuration = Design.animationDurationIn + Design.holdDuration
        DispatchQueue.main.asyncAfter(deadline: .now() + totalDuration, execute: workItem)
    }
    
    /// Hide preview immediately
    func hide() {
        dismissWorkItem?.cancel()
        animateOut()
    }
    
    // MARK: - Private Methods
    
    private func calculateTargetFrame(for position: GridPosition, on screen: NSScreen) -> CGRect? {
        let visibleFrame = screen.visibleFrame
        
        // Convert to AX coordinates for consistency
        let mainScreenHeight = NSScreen.screens[0].frame.height
        let axY = mainScreenHeight - visibleFrame.maxY
        let axFrame = CGRect(x: visibleFrame.origin.x, y: axY, width: visibleFrame.width, height: visibleFrame.height)
        
        let targetFrame: CGRect
        
        switch position {
        case .leftHalf:
            targetFrame = CGRect(x: axFrame.minX, y: axFrame.minY,
                                width: axFrame.width / 2, height: axFrame.height)
        case .rightHalf:
            targetFrame = CGRect(x: axFrame.minX + axFrame.width / 2, y: axFrame.minY,
                                width: axFrame.width / 2, height: axFrame.height)
        case .topHalf:
            targetFrame = CGRect(x: axFrame.minX, y: axFrame.minY,
                                width: axFrame.width, height: axFrame.height / 2)
        case .bottomHalf:
            targetFrame = CGRect(x: axFrame.minX, y: axFrame.minY + axFrame.height / 2,
                                width: axFrame.width, height: axFrame.height / 2)
        case .topLeft:
            targetFrame = CGRect(x: axFrame.minX, y: axFrame.minY,
                                width: axFrame.width / 2, height: axFrame.height / 2)
        case .topRight:
            targetFrame = CGRect(x: axFrame.minX + axFrame.width / 2, y: axFrame.minY,
                                width: axFrame.width / 2, height: axFrame.height / 2)
        case .bottomLeft:
            targetFrame = CGRect(x: axFrame.minX, y: axFrame.minY + axFrame.height / 2,
                                width: axFrame.width / 2, height: axFrame.height / 2)
        case .bottomRight:
            targetFrame = CGRect(x: axFrame.minX + axFrame.width / 2, y: axFrame.minY + axFrame.height / 2,
                                width: axFrame.width / 2, height: axFrame.height / 2)
        case .leftThird:
            targetFrame = CGRect(x: axFrame.minX, y: axFrame.minY,
                                width: axFrame.width / 3, height: axFrame.height)
        case .centerThird:
            targetFrame = CGRect(x: axFrame.minX + axFrame.width / 3, y: axFrame.minY,
                                width: axFrame.width / 3, height: axFrame.height)
        case .rightThird:
            targetFrame = CGRect(x: axFrame.minX + axFrame.width * 2 / 3, y: axFrame.minY,
                                width: axFrame.width / 3, height: axFrame.height)
        case .leftTwoThirds:
            targetFrame = CGRect(x: axFrame.minX, y: axFrame.minY,
                                width: axFrame.width * 2 / 3, height: axFrame.height)
        case .rightTwoThirds:
            targetFrame = CGRect(x: axFrame.minX + axFrame.width / 3, y: axFrame.minY,
                                width: axFrame.width * 2 / 3, height: axFrame.height)
        case .maximize:
            targetFrame = axFrame
        case .center:
            let width = min(800, axFrame.width * 0.8)
            let height = min(600, axFrame.height * 0.8)
            targetFrame = CGRect(
                x: axFrame.midX - width / 2,
                y: axFrame.midY - height / 2,
                width: width,
                height: height
            )
        }
        
        // Convert back to NSWindow coordinates
        let nsY = mainScreenHeight - targetFrame.maxY
        return CGRect(x: targetFrame.origin.x, y: nsY, width: targetFrame.width, height: targetFrame.height)
    }
    
    private func animateIn() {
        isShowing = true
        
        // Start with scale and opacity
        previewView.layer?.opacity = 0
        previewView.layer?.transform = CATransform3DMakeScale(0.95, 0.95, 1)
        
        orderFront(nil)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Design.animationDurationIn
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            context.allowsImplicitAnimation = true
            
            self.previewView.layer?.opacity = 1
            self.previewView.layer?.transform = CATransform3DIdentity
        }
    }
    
    private func animateOut() {
        guard isShowing else { return }
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = Design.animationDurationOut
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            context.allowsImplicitAnimation = true
            
            self.previewView.layer?.opacity = 0
            self.previewView.layer?.transform = CATransform3DMakeScale(0.98, 0.98, 1)
        }, completionHandler: {
            self.orderOut(nil)
            self.isShowing = false
        })
    }
}

// MARK: - Preview View

private class SnapPreviewView: NSView {
    
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
        
        // Fill color with gradient
        let fillColor = NSColor(red: 0.388, green: 0.404, blue: 0.945, alpha: 0.15)
        layer?.backgroundColor = fillColor.cgColor
        
        // Border
        layer?.borderWidth = 3
        layer?.borderColor = NSColor(red: 0.388, green: 0.404, blue: 0.945, alpha: 0.6).cgColor
        
        // Corner radius
        layer?.cornerRadius = 12
        
        // Glow effect
        layer?.shadowColor = NSColor(red: 0.388, green: 0.404, blue: 0.945, alpha: 1.0).cgColor
        layer?.shadowOpacity = 0.4
        layer?.shadowOffset = .zero
        layer?.shadowRadius = 20
    }
    
    override func layout() {
        super.layout()
        
        // Update shadow path for performance
        layer?.shadowPath = CGPath(roundedRect: bounds, cornerWidth: 12, cornerHeight: 12, transform: nil)
    }
}
