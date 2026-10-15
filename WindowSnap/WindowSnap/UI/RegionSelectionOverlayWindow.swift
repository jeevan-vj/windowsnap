import AppKit
import Foundation

@MainActor
protocol RegionSelectionDelegate: AnyObject {
    func regionSelectionDidComplete(displayID: CGDirectDisplayID, rect: CGRect)
    func regionSelectionDidCancel()
}

private func screenMatchesDisplay(_ screen: NSScreen, _ displayID: CGDirectDisplayID) -> Bool {
    guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
        return false
    }
    return number.uint32Value == displayID
}

@MainActor
final class RegionSelectionOverlayWindow: NSWindow {
    
    weak var selectionDelegate: RegionSelectionDelegate?
    
    private var selectionView: RegionSelectionView?
    let displayID: CGDirectDisplayID
    private let displayBounds: CGRect
    private let screenFrame: CGRect
    private var keyMonitor: Any?
    private var didNotifyDelegate = false
    
    init(displayID: CGDirectDisplayID) {
        self.displayID = displayID
        self.displayBounds = CGDisplayBounds(displayID)
        
        // CGDisplayBounds is in CoreGraphics global coords (top-left origin). NSWindow frames
        // use AppKit global coords (bottom-left origin). Use the matching NSScreen.frame so the
        // overlay is positioned correctly on external displays.
        let screen = NSScreen.screens.first { screenMatchesDisplay($0, displayID) }
        let windowFrame = screen?.frame ?? RegionSelectionOverlayWindow.appKitFrame(from: CGDisplayBounds(displayID))
        self.screenFrame = windowFrame
        
        super.init(
            contentRect: windowFrame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        setupWindow(frame: windowFrame)
        setupSelectionView()
        setupKeyHandling()
    }
    
    private static func appKitFrame(from cgBounds: CGRect) -> CGRect {
        // Fallback: convert CG (top-left) global rect to AppKit (bottom-left) global rect
        // using the total desktop height spanning all screens.
        let maxY = NSScreen.screens.map { $0.frame.maxY }.max() ?? cgBounds.height
        return CGRect(
            x: cgBounds.origin.x,
            y: maxY - cgBounds.origin.y - cgBounds.height,
            width: cgBounds.width,
            height: cgBounds.height
        )
    }
    
    private func setupWindow(frame: CGRect) {
        level = .screenSaver
        backgroundColor = NSColor.clear
        isOpaque = false
        hasShadow = false
        ignoresMouseEvents = false
        animationBehavior = .none
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        // Swift owns this window via RegionShareController.selectionWindows.
        // The AppKit default (true) extra-releases on close() and crashes on the
        // next NSApplication autorelease-pool drain.
        isReleasedWhenClosed = false
        
        setFrame(frame, display: true)
    }
    
    private func setupSelectionView() {
        let view = RegionSelectionView(frame: contentRect(forFrameRect: frame))
        view.onSelectionComplete = { [weak self] rect in
            self?.handleSelectionComplete(rect)
        }
        view.onSelectionCancel = { [weak self] in
            self?.handleCancel()
        }
        
        contentView = view
        selectionView = view
    }
    
    private func setupKeyHandling() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            switch event.keyCode {
            case 53: // Escape
                self.handleCancel()
                return nil
            case 36, 76: // Return and keypad Enter
                guard self.isKeyWindow else { return event }
                self.selectionView?.confirmSelection()
                return nil
            case 123, 124, 125, 126: // Arrow keys
                guard self.isKeyWindow else { return event }
                self.selectionView?.handleArrowKey(event)
                return nil
            default:
                return event
            }
        }
    }
    
    private func removeKeyMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }
    
    private func handleSelectionComplete(_ rect: CGRect) {
        let viewBounds = selectionView?.bounds ?? CGRect(origin: .zero, size: frame.size)
        let clampedRect = rect.intersection(viewBounds)
        
        guard clampedRect.width >= 50 && clampedRect.height >= 50 else {
            print("⚠️ Selection too small, minimum 50x50")
            return
        }
        
        guard !didNotifyDelegate else { return }
        didNotifyDelegate = true
        
        let absoluteRect = convertToScreenCoordinates(clampedRect)
        let delegate = selectionDelegate
        let display = displayID
        
        removeKeyMonitor()
        orderOut(nil)
        
        DispatchQueue.main.async {
            delegate?.regionSelectionDidComplete(displayID: display, rect: absoluteRect)
        }
    }
    
    private func handleCancel() {
        guard !didNotifyDelegate else { return }
        didNotifyDelegate = true
        
        let delegate = selectionDelegate
        
        removeKeyMonitor()
        orderOut(nil)
        
        DispatchQueue.main.async {
            delegate?.regionSelectionDidCancel()
        }
    }
    
    private func convertToScreenCoordinates(_ viewRect: CGRect) -> CGRect {
        ShareRegion.captureRect(
            fromViewRect: viewRect,
            overlayFrame: screenFrame,
            displayBounds: displayBounds
        )
    }
    
    override func close() {
        removeKeyMonitor()
        selectionView?.onSelectionComplete = nil
        selectionView?.onSelectionCancel = nil
        super.close()
    }
    
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class RegionSelectionView: NSView {
    
    var onSelectionComplete: ((CGRect) -> Void)?
    var onSelectionCancel: (() -> Void)?
    
    private var selectionStart: CGPoint?
    private var selectionRect: CGRect = .zero
    private var isDragging = false
    
    private let overlayColor = NSColor.underPageBackgroundColor.withAlphaComponent(0.72)
    private let selectionBorderColor = NSColor.controlAccentColor
    private let selectionFillColor = NSColor.controlAccentColor.withAlphaComponent(0.18)
    private let guideColor = NSColor.separatorColor.withAlphaComponent(0.8)
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        wantsLayer = true
        layer?.backgroundColor = overlayColor.cgColor
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel("Screen region selection")
        setAccessibilityHelp("Drag to select. Return confirms, Escape cancels, arrow keys move, and Option plus arrow keys resize.")
        setAccessibilityCustomActions([
            NSAccessibilityCustomAction(name: "Confirm selection") { [weak self] in
                self?.confirmSelection() ?? false
            },
            NSAccessibilityCustomAction(name: "Cancel selection") { [weak self] in
                guard let self else { return false }
                self.onSelectionCancel?()
                return true
            }
        ])
        
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.activeAlways, .mouseMoved, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        overlayColor.setFill()
        bounds.fill()
        
        if selectionRect.width > 0 && selectionRect.height > 0 {
            drawSelection()
            drawGuides()
            drawDimensions()
        } else {
            drawInstructions()
        }
    }
    
    private func drawSelection() {
        NSGraphicsContext.current?.cgContext.clear(selectionRect)
        
        selectionFillColor.setFill()
        selectionRect.fill()
        
        selectionBorderColor.setStroke()
        let path = NSBezierPath(rect: selectionRect)
        path.lineWidth = 2.0
        path.stroke()
        
        let handleSize: CGFloat = 8
        let handles = [
            CGPoint(x: selectionRect.minX, y: selectionRect.minY),
            CGPoint(x: selectionRect.maxX, y: selectionRect.minY),
            CGPoint(x: selectionRect.minX, y: selectionRect.maxY),
            CGPoint(x: selectionRect.maxX, y: selectionRect.maxY),
            CGPoint(x: selectionRect.midX, y: selectionRect.minY),
            CGPoint(x: selectionRect.midX, y: selectionRect.maxY),
            CGPoint(x: selectionRect.minX, y: selectionRect.midY),
            CGPoint(x: selectionRect.maxX, y: selectionRect.midY)
        ]
        
        NSColor.controlBackgroundColor.setFill()
        selectionBorderColor.setStroke()
        
        for handle in handles {
            let handleRect = CGRect(
                x: handle.x - handleSize / 2,
                y: handle.y - handleSize / 2,
                width: handleSize,
                height: handleSize
            )
            let handlePath = NSBezierPath(ovalIn: handleRect)
            handlePath.fill()
            handlePath.lineWidth = 1.5
            handlePath.stroke()
        }
    }
    
    private func drawGuides() {
        guideColor.setStroke()
        
        let dashPattern: [CGFloat] = [4, 4]
        
        let verticalPath = NSBezierPath()
        verticalPath.move(to: CGPoint(x: selectionRect.midX, y: 0))
        verticalPath.line(to: CGPoint(x: selectionRect.midX, y: bounds.height))
        verticalPath.setLineDash(dashPattern, count: 2, phase: 0)
        verticalPath.lineWidth = 1.0
        verticalPath.stroke()
        
        let horizontalPath = NSBezierPath()
        horizontalPath.move(to: CGPoint(x: 0, y: selectionRect.midY))
        horizontalPath.line(to: CGPoint(x: bounds.width, y: selectionRect.midY))
        horizontalPath.setLineDash(dashPattern, count: 2, phase: 0)
        horizontalPath.lineWidth = 1.0
        horizontalPath.stroke()
    }
    
    private func drawDimensions() {
        let width = Int(selectionRect.width)
        let height = Int(selectionRect.height)
        let dimensionText = "\(width) × \(height)"
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .medium),
            .foregroundColor: NSColor.labelColor
        ]
        
        let textSize = dimensionText.size(withAttributes: attributes)
        let labelWidth = textSize.width + 12
        let labelHeight = textSize.height + 4
        let proposedY = selectionRect.maxY + 8
        let textRect = CGRect(
            x: min(max(bounds.minX + 4, selectionRect.midX - labelWidth / 2), bounds.maxX - labelWidth - 4),
            y: proposedY + labelHeight <= bounds.maxY ? proposedY : max(bounds.minY + 4, selectionRect.minY - labelHeight - 8),
            width: labelWidth,
            height: labelHeight
        )
        
        NSColor.windowBackgroundColor.withAlphaComponent(0.92).setFill()
        NSBezierPath(roundedRect: textRect, xRadius: 4, yRadius: 4).fill()
        
        dimensionText.draw(
            at: CGPoint(x: textRect.origin.x + 6, y: textRect.origin.y + 2),
            withAttributes: attributes
        )
    }
    
    private func drawInstructions() {
        let instructions = "Drag to select a region to share\nReturn confirms • Esc cancels"
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 24, weight: .medium),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraphStyle
        ]
        
        let textSize = instructions.size(withAttributes: attributes)
        let textRect = CGRect(
            x: (bounds.width - textSize.width) / 2,
            y: (bounds.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        
        instructions.draw(in: textRect, withAttributes: attributes)
    }
    
    override func mouseDown(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)
        selectionStart = location
        selectionRect = CGRect(origin: location, size: .zero)
        isDragging = true
        needsDisplay = true
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard let start = selectionStart else { return }
        
        let current = convert(event.locationInWindow, from: nil)
        
        let minX = min(start.x, current.x)
        let minY = min(start.y, current.y)
        let maxX = max(start.x, current.x)
        let maxY = max(start.y, current.y)
        
        selectionRect = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        updateAccessibilityValue()
        needsDisplay = true
    }
    
    override func mouseUp(with event: NSEvent) {
        guard isDragging else { return }
        
        isDragging = false

        if selectionRect.width < 50 || selectionRect.height < 50 {
            selectionRect = .zero
            updateAccessibilityValue()
            needsDisplay = true
        }
        
        selectionStart = nil
    }
    
    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 53:
            onSelectionCancel?()
        case 36, 76:
            _ = confirmSelection()
        case 123, 124, 125, 126:
            handleArrowKey(event)
        default:
            super.keyDown(with: event)
        }
    }

    @discardableResult
    func confirmSelection() -> Bool {
        guard selectionRect.width >= 50, selectionRect.height >= 50 else {
            NSSound.beep()
            return false
        }
        onSelectionComplete?(selectionRect)
        return true
    }

    func handleArrowKey(_ event: NSEvent) {
        guard [123, 124, 125, 126].contains(event.keyCode) else { return }
        if selectionRect.isEmpty {
            let size = CGSize(width: min(320, bounds.width), height: min(180, bounds.height))
            selectionRect = CGRect(
                x: bounds.midX - size.width / 2,
                y: bounds.midY - size.height / 2,
                width: size.width,
                height: size.height
            )
        }

        let amount: CGFloat = event.modifierFlags.contains(.shift) ? 10 : 1
        let delta: CGPoint
        switch event.keyCode {
        case 123: delta = CGPoint(x: -amount, y: 0)
        case 124: delta = CGPoint(x: amount, y: 0)
        case 125: delta = CGPoint(x: 0, y: -amount)
        default: delta = CGPoint(x: 0, y: amount)
        }

        if event.modifierFlags.contains(.option) {
            let width = max(50, min(bounds.maxX - selectionRect.minX, selectionRect.width + delta.x))
            let height = max(50, min(bounds.maxY - selectionRect.minY, selectionRect.height + delta.y))
            selectionRect.size = CGSize(width: width, height: height)
        } else {
            selectionRect.origin.x = min(max(bounds.minX, selectionRect.origin.x + delta.x), bounds.maxX - selectionRect.width)
            selectionRect.origin.y = min(max(bounds.minY, selectionRect.origin.y + delta.y), bounds.maxY - selectionRect.height)
        }
        updateAccessibilityValue()
        needsDisplay = true
    }

    private func updateAccessibilityValue() {
        if selectionRect.isEmpty {
            setAccessibilityValue("No region selected")
        } else {
            setAccessibilityValue("\(Int(selectionRect.width)) by \(Int(selectionRect.height)) points")
        }
        NSAccessibility.post(element: self, notification: .valueChanged)
    }
    
    override var acceptsFirstResponder: Bool { true }
}
