import AppKit
import Foundation

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

class RegionSelectionOverlayWindow: NSWindow {
    
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
        
        // #region agent log
        RegionShareDebugLog.write(hypothesis: "E", message: "overlay init frames", data: [
            "displayID": displayID,
            "runId": "post-fix",
            "cgDisplayBounds": NSStringFromRect(self.displayBounds),
            "matchedScreen": screen != nil,
            "screenFrame": screen.map { NSStringFromRect($0.frame) } ?? "nil",
            "windowFrame": NSStringFromRect(windowFrame)
        ])
        // #endregion
        
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
            if event.keyCode == 53 { // Escape key
                self?.handleCancel()
                return nil
            }
            return event
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
        
        // #region agent log
        RegionShareDebugLog.write(hypothesis: "L", message: "overlay selection clamp", data: [
            "runId": "post-fix-v3",
            "rawRect": NSStringFromRect(rect),
            "viewBounds": NSStringFromRect(viewBounds),
            "clampedRect": NSStringFromRect(clampedRect)
        ], sync: true)
        // #endregion
        
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
        // #region agent log
        RegionShareDebugLog.write(hypothesis: "F,G", message: "overlay handleCancel", data: [
            "displayID": displayID,
            "runId": "post-fix",
            "alreadyNotified": didNotifyDelegate
        ], sync: true)
        // #endregion
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
        // NSView uses bottom-left origin within the overlay window. CGDisplayBounds uses
        // bottom-left global display coordinates. Map the selection's distance-from-bottom
        // proportionally into CG display space (NSScreen.frame and CGDisplayBounds can differ in Y).
        let normalizedFromBottom = viewRect.origin.y / screenFrame.height
        return CGRect(
            x: displayBounds.origin.x + viewRect.origin.x,
            y: displayBounds.origin.y + normalizedFromBottom * displayBounds.height,
            width: viewRect.width,
            height: viewRect.height
        )
    }
    
    override func close() {
        // #region agent log
        RegionShareDebugLog.write(hypothesis: "R", message: "overlay close begin", data: [
            "runId": "post-fix-v7",
            "displayID": displayID,
            "hasContentView": contentView != nil
        ], sync: true)
        // #endregion
        removeKeyMonitor()
        selectionView?.onSelectionComplete = nil
        selectionView?.onSelectionCancel = nil
        super.close()
        // #region agent log
        RegionShareDebugLog.write(hypothesis: "R", message: "overlay close end", data: [
            "runId": "post-fix-v7",
            "displayID": displayID
        ], sync: true)
        // #endregion
    }
    
    deinit {
        removeKeyMonitor()
    }
    
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

class RegionSelectionView: NSView {
    
    var onSelectionComplete: ((CGRect) -> Void)?
    var onSelectionCancel: (() -> Void)?
    
    private var selectionStart: CGPoint?
    private var selectionRect: CGRect = .zero
    private var isDragging = false
    
    private let overlayColor = NSColor.black.withAlphaComponent(0.4)
    private let selectionBorderColor = NSColor.systemBlue
    private let selectionFillColor = NSColor.systemBlue.withAlphaComponent(0.15)
    private let guideColor = NSColor.white.withAlphaComponent(0.3)
    
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
        
        if isDragging && selectionRect.width > 0 && selectionRect.height > 0 {
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
        
        NSColor.white.setFill()
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
            .foregroundColor: NSColor.white,
            .backgroundColor: NSColor.black.withAlphaComponent(0.7)
        ]
        
        let textSize = dimensionText.size(withAttributes: attributes)
        let textRect = CGRect(
            x: selectionRect.midX - textSize.width / 2 - 6,
            y: selectionRect.maxY + 8,
            width: textSize.width + 12,
            height: textSize.height + 4
        )
        
        NSColor.black.withAlphaComponent(0.7).setFill()
        NSBezierPath(roundedRect: textRect, xRadius: 4, yRadius: 4).fill()
        
        dimensionText.draw(
            at: CGPoint(x: textRect.origin.x + 6, y: textRect.origin.y + 2),
            withAttributes: attributes
        )
    }
    
    private func drawInstructions() {
        let instructions = "Drag to select a region to share\nPress ESC to cancel"
        
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 24, weight: .medium),
            .foregroundColor: NSColor.white,
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
        needsDisplay = true
    }
    
    override func mouseUp(with event: NSEvent) {
        guard isDragging else { return }
        
        isDragging = false
        
        if selectionRect.width >= 50 && selectionRect.height >= 50 {
            onSelectionComplete?(selectionRect)
        } else {
            selectionRect = .zero
            needsDisplay = true
        }
        
        selectionStart = nil
    }
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            onSelectionCancel?()
        } else {
            super.keyDown(with: event)
        }
    }
    
    override var acceptsFirstResponder: Bool { true }
}
