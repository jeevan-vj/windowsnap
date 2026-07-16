import AppKit
import Foundation

class RegionMirrorWindow: NSWindow {
    
    private var captureEngine: RegionCaptureEngine?
    private var imageView: NSImageView?
    private var region: ShareRegion
    private var isCapturing = false
    private var isStartingCapture = false
    private var isStopping = false
    private var captureGeneration = 0
    private var stopRequestGeneration = 0
    private var didLogFirstFrame = false
    private var hasLoggedFirstFrame = false
    
    private func engineToken(_ engine: RegionCaptureEngine?) -> String {
        guard let engine else { return "nil" }
        return String(ObjectIdentifier(engine).hashValue)
    }
    
    private func isCurrentEngine(_ engine: RegionCaptureEngine) -> Bool {
        captureEngine === engine
    }
    
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
        guard !isCapturing && !isStartingCapture else {
            // #region agent log
            RegionShareDebugLog.write(hypothesis: "H6", message: "mirror startCapture blocked by guard", data: [
                "runId": "run2",
                "engine": engineToken(captureEngine),
                "isCapturing": isCapturing,
                "isStartingCapture": isStartingCapture,
                "isStopping": isStopping
            ], sync: true)
            // #endregion
            return
        }
        
        guard let displayBounds = RegionShareManager.shared.getDisplayBounds(for: region.displayID) else {
            print("❌ Could not get display bounds")
            RegionShareManager.shared.setState(.idle)
            return
        }
        
        isStartingCapture = true
        isStopping = false
        didLogFirstFrame = false
        hasLoggedFirstFrame = false
        captureGeneration += 1
        let generation = captureGeneration
        let previousEngine = captureEngine
        let absoluteRect = region.absoluteRect(for: displayBounds)
        let newEngine = RegionCaptureEngine(
            displayID: region.displayID,
            cropRect: absoluteRect,
            frameRate: 30
        )
        captureEngine = newEngine
        newEngine.delegate = self
        // #region agent log
        RegionShareDebugLog.write(hypothesis: "H1,H2", message: "mirror startCapture transition", data: [
            "runId": "run1",
            "generation": generation,
            "previousEngine": engineToken(previousEngine),
            "newEngine": engineToken(newEngine),
            "isCapturing": isCapturing,
            "isStartingCapture": isStartingCapture,
            "isStopping": isStopping
        ], sync: true)
        // #endregion
        
        // #region agent log
        RegionShareDebugLog.write(hypothesis: "M,N,O", message: "mirror startCapture begin", data: [
            "runId": "post-fix-v10",
            "displayID": region.displayID,
            "absoluteRect": NSStringFromRect(absoluteRect),
            "isStopping": isStopping,
            "engine": engineToken(newEngine)
        ], sync: true)
        // #endregion
        
        Task { [weak self] in
            guard let self = self else { return }
            
            do {
                try await newEngine.startCapture()
                
                await MainActor.run {
                    if self.isStopping {
                        Task {
                            await newEngine.stopCapture()
                            if self.captureEngine === newEngine {
                                self.captureEngine = nil
                            }
                        }
                    } else {
                        self.isCapturing = true
                        RegionShareManager.shared.setState(.streaming)
                        // #region agent log
                        RegionShareDebugLog.write(hypothesis: "H2", message: "mirror startCapture success state", data: [
                            "runId": "run1",
                            "generation": generation,
                            "engine": self.engineToken(newEngine),
                            "isCurrentEngine": self.isCurrentEngine(newEngine)
                        ], sync: true)
                        // #endregion
                        // #region agent log
                        RegionShareDebugLog.write(hypothesis: "M,N,O", message: "mirror capture streaming", data: [
                            "runId": "post-fix-v4",
                            "displayID": self.region.displayID
                        ], sync: true)
                        // #endregion
                    }
                    self.isStartingCapture = false
                    self.isStopping = false
                }
            } catch {
                await MainActor.run {
                    self.isStartingCapture = false
                    if self.captureEngine === newEngine {
                        self.captureEngine = nil
                    }
                    self.isStopping = false
                    RegionShareManager.shared.setState(.idle)
                    print("❌ Failed to start capture: \(error)")
                    // #region agent log
                    RegionShareDebugLog.write(hypothesis: "M,N,O", message: "mirror startCapture catch", data: [
                        "runId": "post-fix-v4",
                        "error": String(describing: error)
                    ], sync: true)
                    // #endregion
                    self.showCaptureError(error)
                }
            }
        }
    }
    
    func stopCapture() {
        stopRequestGeneration += 1
        let stopRequestID = stopRequestGeneration
        // #region agent log
        RegionShareDebugLog.write(hypothesis: "H2,H3", message: "mirror stopCapture invoked", data: [
            "runId": "run1",
            "engine": engineToken(captureEngine),
            "isCapturing": isCapturing,
            "isStartingCapture": isStartingCapture,
            "isStopping": isStopping,
            "stopRequestID": stopRequestID
        ], sync: true)
        // #endregion
        if isStopping {
            // #region agent log
            RegionShareDebugLog.write(hypothesis: "H6", message: "mirror stopCapture re-entrant", data: [
                "runId": "run2",
                "engine": engineToken(captureEngine),
                "stopRequestID": stopRequestID
            ], sync: true)
            // #endregion
        }
        isStopping = true
        
        guard isCapturing || isStartingCapture else {
            captureEngine = nil
            isStopping = false
            RegionShareManager.shared.setState(.idle)
            return
        }
        
        if isStartingCapture {
            // #region agent log
            RegionShareDebugLog.write(hypothesis: "H2", message: "mirror stopCapture deferred while starting", data: [
                "runId": "run1",
                "engine": engineToken(captureEngine),
                "stopRequestID": stopRequestID
            ], sync: true)
            // #endregion
            return
        }
        
        captureEngine?.delegate = nil
        let engineAtStop = captureEngine
        // #region agent log
        RegionShareDebugLog.write(hypothesis: "U", message: "mirror stopCapture start", data: [
            "runId": "post-fix-v10",
            "engine": engineToken(engineAtStop)
        ], sync: true)
        // #endregion
        
        Task { [weak self] in
            guard let self = self else { return }
            await engineAtStop?.stopCapture()
            
            await MainActor.run {
                if self.captureEngine === engineAtStop {
                    self.captureEngine = nil
                }
                self.isCapturing = false
                self.isStopping = false
                RegionShareManager.shared.setState(.idle)
                // #region agent log
                RegionShareDebugLog.write(hypothesis: "U", message: "mirror stopCapture complete", data: [
                    "runId": "post-fix-v10",
                    "stoppedEngine": self.engineToken(engineAtStop),
                    "currentEngine": self.engineToken(self.captureEngine),
                    "stopRequestID": stopRequestID
                ], sync: true)
                // #endregion
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
    
    deinit {
        // #region agent log
        RegionShareDebugLog.write(hypothesis: "H7", message: "mirror deinit", data: [
            "runId": "run2",
            "engine": engineToken(captureEngine),
            "isCapturing": isCapturing,
            "isStartingCapture": isStartingCapture,
            "isStopping": isStopping
        ], sync: true)
        // #endregion
    }
    
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

extension RegionMirrorWindow: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        // #region agent log
        RegionShareDebugLog.write(hypothesis: "P", message: "mirror windowWillClose", data: [
            "runId": "post-fix-v5",
            "isCapturing": isCapturing,
            "isStartingCapture": isStartingCapture
        ], sync: true)
        // #endregion
        captureEngine?.delegate = nil
        stopCapture()
        
        // #region agent log
        RegionShareDebugLog.write(hypothesis: "P", message: "mirror windowWillClose post-stop", data: [
            "runId": "post-fix-v6",
            "isCapturing": isCapturing,
            "isStartingCapture": isStartingCapture
        ], sync: true)
        // #endregion
        
        RegionShareManager.shared.updateMirrorWindowFrame(frame)
    }
    
    func windowDidResize(_ notification: Notification) {
        RegionShareManager.shared.updateMirrorWindowFrame(frame)
    }
    
    func windowDidMove(_ notification: Notification) {
        RegionShareManager.shared.updateMirrorWindowFrame(frame)
    }
}

extension RegionMirrorWindow: RegionCaptureDelegate {
    func captureEngine(_ engine: RegionCaptureEngine, didOutputFrame image: CGImage) {
        let staleEngine = !isCurrentEngine(engine)
        if staleEngine {
            // #region agent log
            RegionShareDebugLog.write(hypothesis: "H1", message: "stale didOutputFrame callback", data: [
                "runId": "run1",
                "callbackEngine": engineToken(engine),
                "currentEngine": engineToken(captureEngine),
                "isStopping": isStopping
            ], sync: true)
            // #endregion
        }
        guard !isStopping, isVisible, contentView != nil, imageView != nil else { return }
        // #region agent log
        if !hasLoggedFirstFrame {
            hasLoggedFirstFrame = true
            didLogFirstFrame = true
            RegionShareDebugLog.write(hypothesis: "M,N", message: "mirror first frame received", data: [
                "runId": "post-fix-v4",
                "imageW": image.width,
                "imageH": image.height
            ], sync: true)
        }
        // #endregion
        removePlaceholder()
        
        let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        imageView?.image = nsImage
        // #region agent log
        if didLogFirstFrame {
            RegionShareDebugLog.write(hypothesis: "M,N", message: "mirror first frame rendered", data: [
                "runId": "post-fix-v5"
            ], sync: true)
            didLogFirstFrame = false
        }
        // #endregion
    }
    
    func captureEngine(_ engine: RegionCaptureEngine, didFailWithError error: Error) {
        let staleEngine = !isCurrentEngine(engine)
        if staleEngine {
            // #region agent log
            RegionShareDebugLog.write(hypothesis: "H1,H4", message: "stale didFail callback", data: [
                "runId": "run1",
                "callbackEngine": engineToken(engine),
                "currentEngine": engineToken(captureEngine),
                "error": String(describing: error)
            ], sync: true)
            // #endregion
        }
        if isStopping || !isVisible {
            // #region agent log
            RegionShareDebugLog.write(hypothesis: "T", message: "mirror ignore fail while stopping/hidden", data: [
                "runId": "post-fix-v9",
                "isStopping": isStopping,
                "isVisible": isVisible,
                "error": String(describing: error)
            ], sync: true)
            // #endregion
            return
        }
        isCapturing = false
        isStartingCapture = false
        RegionShareManager.shared.setState(.idle)
        // #region agent log
        RegionShareDebugLog.write(hypothesis: "O", message: "mirror didFailWithError", data: [
            "runId": "post-fix-v4",
            "error": String(describing: error)
        ], sync: true)
        // #endregion
        showCaptureError(error)
    }
}

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
