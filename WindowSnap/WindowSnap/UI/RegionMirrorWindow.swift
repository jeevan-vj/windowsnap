import AppKit
import Foundation

@available(macOS 12.3, *)
class RegionMirrorWindow: NSWindow {
    
    private var captureEngine: RegionCaptureEngine?
    private var imageView: NSImageView?
    private var region: ShareRegion
    private var isCapturing = false
    private var isStartingCapture = false
    private var isStopping = false
    
    private let minWindowSize = CGSize(width: 320, height: 180)
    private let defaultWindowSize = CGSize(width: 960, height: 540)
    
    init(region: ShareRegion) {
        self.region = region
        
        let initialFrame: CGRect
        if let savedFrame = region.lastMirrorWindowFrame {
            initialFrame = savedFrame
        } else {
            initialFrame = CGRect(origin: .zero, size: defaultWindowSize)
        }
        
        super.init(
            contentRect: initialFrame,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        setupWindow()
        setupImageView()
    }
    
    private func setupWindow() {
        title = "Region Share"
        minSize = minWindowSize
        isReleasedWhenClosed = false
        
        if region.lastMirrorWindowFrame == nil {
            center()
        }
        
        delegate = self
        
        setupToolbar()
    }
    
    private func setupToolbar() {
        let toolbar = NSToolbar(identifier: "RegionMirrorToolbar")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        self.toolbar = toolbar
    }
    
    @objc private func selectNewRegionClicked() {
        RegionShareController.shared.selectNewRegion()
    }
    
    private func setupImageView() {
        let view = NSImageView(frame: contentRect(forFrameRect: frame))
        view.imageScaling = .scaleProportionallyUpOrDown
        view.autoresizingMask = [.width, .height]
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.black.cgColor
        
        contentView = view
        imageView = view
        
        addPlaceholderContent()
    }
    
    private func addPlaceholderContent() {
        guard let contentView = contentView else { return }
        
        let label = NSTextField(labelWithString: "Starting capture...")
        label.font = NSFont.systemFont(ofSize: 16, weight: .medium)
        label.textColor = .secondaryLabelColor
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        label.tag = 999
        
        contentView.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }
    
    private func removePlaceholder() {
        contentView?.subviews.first(where: { $0.tag == 999 })?.removeFromSuperview()
    }
    
    func startCapture() {
        guard !isCapturing && !isStartingCapture else { return }
        
        guard let displayBounds = RegionShareManager.shared.getDisplayBounds(for: region.displayID) else {
            print("❌ Could not get display bounds")
            RegionShareManager.shared.setState(.idle)
            return
        }
        
        isStartingCapture = true
        let absoluteRect = region.absoluteRect(for: displayBounds)
        
        captureEngine = RegionCaptureEngine(
            displayID: region.displayID,
            cropRect: absoluteRect,
            frameRate: 30
        )
        captureEngine?.delegate = self
        
        Task { [weak self] in
            guard let self = self else { return }
            
            do {
                try await self.captureEngine?.startCapture()
                
                await MainActor.run {
                    if self.isStopping {
                        Task {
                            await self.captureEngine?.stopCapture()
                            self.captureEngine = nil
                        }
                    } else {
                        self.isCapturing = true
                        RegionShareManager.shared.setState(.streaming)
                    }
                    self.isStartingCapture = false
                }
            } catch {
                await MainActor.run {
                    self.isStartingCapture = false
                    self.captureEngine = nil
                    RegionShareManager.shared.setState(.idle)
                    print("❌ Failed to start capture: \(error)")
                    self.showCaptureError(error)
                }
            }
        }
    }
    
    func stopCapture() {
        isStopping = true
        
        guard isCapturing || isStartingCapture else {
            captureEngine = nil
            RegionShareManager.shared.setState(.idle)
            return
        }
        
        if isStartingCapture {
            return
        }
        
        Task { [weak self] in
            guard let self = self else { return }
            await self.captureEngine?.stopCapture()
            
            await MainActor.run {
                self.captureEngine = nil
                self.isCapturing = false
                RegionShareManager.shared.setState(.idle)
            }
        }
    }
    
    func updateRegion(_ newRegion: ShareRegion) {
        self.region = newRegion
        
        guard let displayBounds = RegionShareManager.shared.getDisplayBounds(for: region.displayID) else {
            return
        }
        
        let absoluteRect = region.absoluteRect(for: displayBounds)
        captureEngine?.updateCropRect(absoluteRect)
    }
    
    private func showCaptureError(_ error: Error) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let alert = NSAlert()
            alert.messageText = "Capture Failed"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.beginSheetModal(for: self)
        }
    }
    
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@available(macOS 12.3, *)
extension RegionMirrorWindow: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        stopCapture()
        
        RegionShareManager.shared.updateMirrorWindowFrame(frame)
    }
    
    func windowDidResize(_ notification: Notification) {
        RegionShareManager.shared.updateMirrorWindowFrame(frame)
    }
    
    func windowDidMove(_ notification: Notification) {
        RegionShareManager.shared.updateMirrorWindowFrame(frame)
    }
}

@available(macOS 12.3, *)
extension RegionMirrorWindow: RegionCaptureDelegate {
    func captureEngine(_ engine: RegionCaptureEngine, didOutputFrame image: CGImage) {
        removePlaceholder()
        
        let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        imageView?.image = nsImage
    }
    
    func captureEngine(_ engine: RegionCaptureEngine, didFailWithError error: Error) {
        isCapturing = false
        isStartingCapture = false
        RegionShareManager.shared.setState(.idle)
        showCaptureError(error)
    }
}

@available(macOS 12.3, *)
extension RegionMirrorWindow: NSToolbarDelegate {
    private static let selectNewRegionItemID = NSToolbarItem.Identifier("SelectNewRegion")
    
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [.flexibleSpace, Self.selectNewRegionItemID]
    }
    
    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        return [Self.selectNewRegionItemID, .flexibleSpace]
    }
    
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        if itemIdentifier == Self.selectNewRegionItemID {
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "New Region"
            item.paletteLabel = "Select New Region"
            item.toolTip = "Select a new screen region to share"
            item.image = NSImage(systemSymbolName: "rectangle.dashed.badge.record", accessibilityDescription: "Select New Region")
            item.target = self
            item.action = #selector(selectNewRegionClicked)
            return item
        }
        return nil
    }
}
