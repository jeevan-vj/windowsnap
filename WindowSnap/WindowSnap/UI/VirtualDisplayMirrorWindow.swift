import AppKit
import CoreGraphics
import Foundation

/// Live preview of the OS-level virtual screen for window sharing and cursor teleport.
final class VirtualDisplayMirrorWindow: NSWindow {
    static let previewTitle = "WindowSnap Display"

    private let imageView = NSImageView()
    private var placeholderLabel: NSTextField?
    private var cursorTimer: Timer?
    private var isWindowHighlighted = false
    private var displayID: CGDirectDisplayID
    private var displayBounds: CGRect

    var onClosed: (() -> Void)?

    init(displayID: CGDirectDisplayID, displayBounds: CGRect) {
        self.displayID = displayID
        self.displayBounds = displayBounds
        let initialSize = Self.defaultSize(for: displayBounds)
        super.init(
            contentRect: CGRect(origin: .zero, size: initialSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        setupWindow()
        setupContent()
        pinToRealScreen(excluding: displayID)
        startCursorMonitoring()
    }

    private func setupWindow() {
        title = Self.previewTitle
        level = .normal
        collectionBehavior = [.fullScreenAuxiliary, .managed]
        isReleasedWhenClosed = false
        minSize = NSSize(width: 320, height: 180)
        delegate = self
        updateContentAspectRatio()
    }

    private func setupContent() {
        let preview = VirtualDisplayPreviewView(frame: .zero)
        preview.wantsLayer = true
        preview.layer?.backgroundColor = NSColor.black.cgColor
        preview.onClick = { [weak self] location in
            self?.teleportCursor(fromPreviewLocation: location)
        }

        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.translatesAutoresizingMaskIntoConstraints = false
        preview.addSubview(imageView)

        let label = NSTextField(labelWithString: "Connecting virtual screen…")
        label.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        label.textColor = .secondaryLabelColor
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        preview.addSubview(label)
        placeholderLabel = label

        contentView = preview
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: preview.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: preview.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: preview.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: preview.bottomAnchor),
            label.centerXAnchor.constraint(equalTo: preview.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: preview.centerYAnchor)
        ])
    }

    func updateDisplay(displayID: CGDirectDisplayID, bounds: CGRect) {
        self.displayID = displayID
        self.displayBounds = bounds
        updateContentAspectRatio()
        pinToRealScreen(excluding: displayID)
    }

    func showPlaceholder(_ text: String) {
        placeholderLabel?.stringValue = text
        placeholderLabel?.isHidden = false
    }

    func applyFrame(_ image: CGImage) {
        placeholderLabel?.isHidden = true
        imageView.image = NSImage(
            cgImage: image,
            size: NSSize(width: image.width, height: image.height)
        )
    }

    func pinToRealScreen(excluding excludedDisplayID: CGDirectDisplayID) {
        guard let host = NSScreen.screens.first(where: { $0.displayID != excludedDisplayID })
            ?? NSScreen.screens.first else { return }
        if screen?.displayID == excludedDisplayID || screen == nil {
            var nextFrame = frame
            nextFrame.origin.x = host.visibleFrame.midX - nextFrame.width / 2
            nextFrame.origin.y = host.visibleFrame.midY - nextFrame.height / 2
            setFrame(nextFrame, display: false)
        }
    }

    private func updateContentAspectRatio() {
        guard displayBounds.width > 0, displayBounds.height > 0 else { return }
        contentAspectRatio = NSSize(width: displayBounds.width, height: displayBounds.height)
    }

    private func startCursorMonitoring() {
        cursorTimer?.invalidate()
        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.updateCursorHighlight()
        }
        RunLoop.main.add(timer, forMode: .common)
        cursorTimer = timer
    }

    private func updateCursorHighlight() {
        let matchingScreen = NSScreen.screens.first { $0.displayID == displayID }
        let isInside = matchingScreen.map {
            VirtualDisplayGeometry.containsCursor(NSEvent.mouseLocation, in: $0.frame)
        } ?? false

        guard isInside != isWindowHighlighted else { return }
        isWindowHighlighted = isInside
        backgroundColor = isInside
            ? NSColor.controlAccentColor
            : NSColor.windowBackgroundColor
        if isInside {
            orderFrontRegardless()
        }
    }

    private func teleportCursor(fromPreviewLocation location: CGPoint) {
        guard let contentView else { return }
        let point = VirtualDisplayGeometry.displayPoint(
            fromPreviewLocation: location,
            previewBounds: contentView.bounds,
            displaySize: displayBounds.size
        )
        CGDisplayMoveCursorToPoint(displayID, point)
    }

    private static func defaultSize(for bounds: CGRect) -> NSSize {
        let width: CGFloat = 960
        guard bounds.width > 0, bounds.height > 0 else {
            return NSSize(width: width, height: 540)
        }
        return NSSize(width: width, height: width * (bounds.height / bounds.width))
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

extension VirtualDisplayMirrorWindow: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        cursorTimer?.invalidate()
        cursorTimer = nil
        onClosed?()
    }

    func windowDidMove(_ notification: Notification) {
        pinToRealScreen(excluding: displayID)
    }
}

extension VirtualDisplayMirrorWindow: RegionCaptureDelegate {
    func captureEngine(_ engine: RegionCaptureEngine, didOutputFrame image: CGImage) {
        guard isVisible else { return }
        applyFrame(image)
    }

    func captureEngine(_ engine: RegionCaptureEngine, didFailWithError error: Error) {
        showPlaceholder(error.localizedDescription)
    }
}

private final class VirtualDisplayPreviewView: NSView {
    var onClick: ((CGPoint) -> Void)?

    override func mouseDown(with event: NSEvent) {
        onClick?(convert(event.locationInWindow, from: nil))
    }
}
