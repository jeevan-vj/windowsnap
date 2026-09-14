import AppKit
import Foundation

final class RegionMirrorWindow: NSWindow {

    private var captureEngine: RegionCaptureEngine?
    private var imageView: NSImageView?
    private var region: ShareRegion
    private var presentationMode: RegionSharePresentationMode
    private var isCapturing = false
    private var isStartingCapture = false
    private var isStopping = false
    private var wantsCapture = false
    private var captureGeneration = 0

    private let minWindowSize = CGSize(width: 320, height: 180)
    private let defaultWindowSize = CGSize(width: 960, height: 540)

    init(region: ShareRegion, presentationMode: RegionSharePresentationMode = .floatingMirror) {
        self.region = region
        self.presentationMode = presentationMode

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
        applyPresentationMode()
        minSize = minWindowSize
        isReleasedWhenClosed = false

        if region.lastMirrorWindowFrame == nil {
            center()
        }

        delegate = self

        setupToolbar()
    }

    private func applyPresentationMode() {
        title = presentationMode.windowTitle

        switch presentationMode {
        case .floatingMirror:
            level = .normal
            collectionBehavior = [.fullScreenAuxiliary]
        case .virtualDisplayWindow:
            level = .normal
            collectionBehavior = [.fullScreenAuxiliary, .managed]
        }

        updateContentAspectRatio()
    }

    private func updateContentAspectRatio() {
        guard let displayBounds = RegionShareManager.shared.getDisplayBounds(for: region.displayID) else {
            return
        }
        let absoluteRect = region.absoluteRect(for: displayBounds)
        guard absoluteRect.width > 0, absoluteRect.height > 0 else { return }
        contentAspectRatio = NSSize(width: absoluteRect.width, height: absoluteRect.height)
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
        guard let displayBounds = RegionShareManager.shared.getDisplayBounds(for: region.displayID) else {
            print("❌ Could not get display bounds")
            RegionShareManager.shared.setState(.idle)
            return
        }

        wantsCapture = true
        captureGeneration += 1
        let generation = captureGeneration
        isStartingCapture = true
        isStopping = false

        let previousEngine = captureEngine
        previousEngine?.delegate = nil
        previousEngine?.requestStop()

        let absoluteRect = region.absoluteRect(for: displayBounds)
        let newEngine = RegionCaptureEngine(
            displayID: region.displayID,
            cropRect: absoluteRect,
            frameRate: 30
        )
        captureEngine = newEngine
        newEngine.delegate = self

        Task { [weak self] in
            await previousEngine?.stopCapture()
            guard let self else {
                await newEngine.stopCapture()
                return
            }

            do {
                try await newEngine.startCapture()
                await MainActor.run {
                    guard self.captureGeneration == generation, self.wantsCapture else {
                        Task { await newEngine.stopCapture() }
                        return
                    }
                    self.isCapturing = true
                    self.isStartingCapture = false
                    RegionShareManager.shared.setState(.streaming)
                }
            } catch {
                await MainActor.run {
                    self.isStartingCapture = false
                    if self.captureEngine === newEngine {
                        self.captureEngine = nil
                    }
                    guard self.captureGeneration == generation else { return }
                    RegionShareManager.shared.setState(.idle)
                    print("❌ Failed to start capture: \(error)")
                    self.showCaptureError(error)
                }
            }
        }
    }

    func stopCapture() {
        wantsCapture = false
        captureGeneration += 1
        let generation = captureGeneration
        isStopping = true

        captureEngine?.delegate = nil
        captureEngine?.requestStop()
        let engineAtStop = captureEngine

        guard isCapturing || isStartingCapture else {
            captureEngine = nil
            isStopping = false
            RegionShareManager.shared.setState(.idle)
            return
        }

        Task { [weak self] in
            await engineAtStop?.stopCapture()
            await MainActor.run {
                guard let self, self.captureGeneration == generation else { return }
                if self.captureEngine === engineAtStop {
                    self.captureEngine = nil
                }
                self.isCapturing = false
                self.isStartingCapture = false
                self.isStopping = false
                if !self.wantsCapture {
                    RegionShareManager.shared.setState(.idle)
                }
            }
        }
    }

    func updateRegion(_ newRegion: ShareRegion) {
        self.region = newRegion
        updateContentAspectRatio()

        guard let displayBounds = RegionShareManager.shared.getDisplayBounds(for: region.displayID) else {
            return
        }

        let absoluteRect = region.absoluteRect(for: displayBounds)
        captureEngine?.updateCropRect(absoluteRect)
    }

    func updatePresentationMode(_ mode: RegionSharePresentationMode) {
        presentationMode = mode
        applyPresentationMode()
    }

    private func showCaptureError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Capture Failed"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.beginSheetModal(for: self)
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

extension RegionMirrorWindow: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        captureEngine?.delegate = nil
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

extension RegionMirrorWindow: RegionCaptureDelegate {
    func captureEngine(_ engine: RegionCaptureEngine, didOutputFrame image: CGImage) {
        guard engine === captureEngine, !isStopping, isVisible, imageView != nil else { return }
        removePlaceholder()

        let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        imageView?.image = nsImage
    }

    func captureEngine(_ engine: RegionCaptureEngine, didFailWithError error: Error) {
        guard engine === captureEngine else { return }
        if isStopping || !isVisible { return }
        isCapturing = false
        isStartingCapture = false
        RegionShareManager.shared.setState(.idle)
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

    func toolbar(
        _ toolbar: NSToolbar,
        itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
        willBeInsertedIntoToolbar flag: Bool
    ) -> NSToolbarItem? {
        if itemIdentifier == Self.selectNewRegionItemID {
            let item = NSToolbarItem(itemIdentifier: itemIdentifier)
            item.label = "New Region"
            item.paletteLabel = "Select New Region"
            item.toolTip = "Select a new screen region to share"
            item.image = NSImage(
                systemSymbolName: "rectangle.dashed.badge.record",
                accessibilityDescription: "Select New Region"
            )
            item.target = self
            item.action = #selector(selectNewRegionClicked)
            return item
        }
        return nil
    }
}
