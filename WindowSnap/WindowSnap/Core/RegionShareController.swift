import Foundation
import AppKit

final class RegionShareController: NSObject {

    static let shared = RegionShareController()

    private var selectionWindows: [RegionSelectionOverlayWindow] = []
    private var didHandleSelection = false
    private var mirrorWindow: RegionMirrorWindow?
    private var virtualCameraCaptureEngine: RegionCaptureEngine?
    private var wantsVirtualCameraCapture = false
    private var virtualCameraGeneration = 0
    private var pendingPresentationMode: RegionSharePresentationMode = .floatingMirror
    private var regionBeforeReselection: ShareRegion?
    private var isReselecting = false
    private var shouldRestoreMirrorOnCancel = false

    private override init() {
        super.init()
        setupNotifications()
    }

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(mirrorWindowDidClose(_:)),
            name: NSWindow.willCloseNotification,
            object: nil
        )
    }

    @objc private func mirrorWindowDidClose(_ notification: Notification) {
        guard let window = notification.object as? RegionMirrorWindow,
              window === mirrorWindow else { return }
        mirrorWindow = nil
    }

    func showRegionShare() {
        showRegionShare(mode: .floatingMirror)
    }

    func showVirtualDisplayShare() {
        showRegionShare(mode: .virtualDisplayWindow)
    }

    func enableVirtualCameraShare() {
        wantsVirtualCameraCapture = true
        RegionFrameHub.shared.prepare()
        VirtualCameraExtensionManager.shared.activate()

        if let existingRegion = RegionShareManager.shared.currentRegion,
           RegionShareManager.shared.isDisplayValid(existingRegion.displayID) {
            startVirtualCameraCapture(for: existingRegion)
        } else {
            RegionShareManager.shared.clearRegion()
            pendingPresentationMode = .virtualDisplayWindow
            startRegionSelection()
        }
    }

    func stopVirtualCameraShare() {
        wantsVirtualCameraCapture = false
        stopVirtualCameraCapture()
    }

    private func showRegionShare(mode: RegionSharePresentationMode) {
        pendingPresentationMode = mode
        if let existingMirror = mirrorWindow {
            existingMirror.updatePresentationMode(mode)
            if existingMirror.isVisible {
                bringMirrorWindowToFront()
                return
            }
        }

        if let existingRegion = RegionShareManager.shared.currentRegion {
            if RegionShareManager.shared.isDisplayValid(existingRegion.displayID) {
                startMirrorWithRegion(existingRegion, mode: mode)
            } else {
                print("⚠️ Saved region's display is no longer available, clearing and starting new selection")
                RegionShareManager.shared.clearRegion()
                startRegionSelection()
            }
        } else {
            startRegionSelection()
        }
    }

    func startRegionSelection() {
        if ScreenRecordingPermissions.hasPermissions() {
            showSelectionOverlay()
        } else {
            ScreenRecordingPermissions.checkPermissionsWithAlert { [weak self] hasPermission in
                if hasPermission {
                    self?.showSelectionOverlay()
                } else {
                    print("⚠️ Screen recording permission not granted - user needs to enable in System Settings and restart")
                    RegionShareManager.shared.setState(.idle)
                }
            }
        }
    }

    func selectNewRegion() {
        regionBeforeReselection = RegionShareManager.shared.currentRegion
        isReselecting = true
        shouldRestoreMirrorOnCancel = mirrorWindow != nil
        mirrorWindow?.stopCapture()
        mirrorWindow?.orderOut(nil)
        stopVirtualCameraCapture()
        startRegionSelection()
    }

    func closeMirrorWindow() {
        mirrorWindow?.close()
        mirrorWindow = nil
    }

    private func closeSelectionOverlay() {
        for window in selectionWindows {
            window.close()
        }
        selectionWindows.removeAll()
    }

    private func showSelectionOverlay() {
        if !selectionWindows.isEmpty {
            closeSelectionOverlay()
        }
        didHandleSelection = false

        let displays = RegionShareManager.shared.getAllDisplays()
        RegionShareManager.shared.setState(.selecting)

        for displayID in displays {
            let overlay = RegionSelectionOverlayWindow(displayID: displayID)
            overlay.selectionDelegate = self
            overlay.orderFront(nil)
            selectionWindows.append(overlay)
        }

        // Make the overlay on the display under the cursor key so it receives ESC/focus.
        let keyDisplay = RegionShareManager.shared.getDisplayUnderCursor() ?? CGMainDisplayID()
        if let keyOverlay = selectionWindows.first(where: { $0.displayID == keyDisplay }) ?? selectionWindows.first {
            keyOverlay.makeKeyAndOrderFront(nil)
        }

        NSApp.activate(ignoringOtherApps: true)
    }

    private func startMirrorWithRegion(_ region: ShareRegion, mode: RegionSharePresentationMode) {
        if ScreenRecordingPermissions.hasPermissions() {
            createAndShowMirrorWindow(for: region, mode: mode)
        } else {
            ScreenRecordingPermissions.checkPermissionsWithAlert { [weak self] hasPermission in
                if hasPermission {
                    self?.createAndShowMirrorWindow(for: region, mode: mode)
                } else {
                    print("⚠️ Screen recording permission not granted - user needs to enable in System Settings and restart")
                    RegionShareManager.shared.setState(.idle)
                }
            }
        }
    }

    private func createAndShowMirrorWindow(for region: ShareRegion, mode: RegionSharePresentationMode) {
        if let existingMirror = mirrorWindow {
            existingMirror.updatePresentationMode(mode)
            existingMirror.updateRegion(region)
            existingMirror.makeKeyAndOrderFront(nil)
            existingMirror.startCapture()
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let window = RegionMirrorWindow(region: region, presentationMode: mode)
        window.makeKeyAndOrderFront(nil)
        window.startCapture()
        mirrorWindow = window
        NSApp.activate(ignoringOtherApps: true)
    }

    private func startVirtualCameraCapture(for region: ShareRegion) {
        guard wantsVirtualCameraCapture else { return }

        guard let displayBounds = RegionShareManager.shared.getDisplayBounds(for: region.displayID) else {
            RegionShareManager.shared.clearRegion()
            RegionFrameHub.shared.markInactive()
            return
        }

        if !ScreenRecordingPermissions.hasPermissions() {
            ScreenRecordingPermissions.checkPermissionsWithAlert { [weak self] hasPermission in
                if hasPermission {
                    self?.startVirtualCameraCapture(for: region)
                } else {
                    RegionFrameHub.shared.markInactive()
                    RegionShareManager.shared.setState(.idle)
                }
            }
            return
        }

        virtualCameraGeneration += 1
        let generation = virtualCameraGeneration
        let absoluteRect = region.absoluteRect(for: displayBounds)
        let oldEngine = virtualCameraCaptureEngine
        oldEngine?.requestStop()

        let engine = RegionCaptureEngine(displayID: region.displayID, cropRect: absoluteRect, frameRate: 30)
        engine.frameSink = RegionFrameHub.shared
        virtualCameraCaptureEngine = engine

        Task { [weak self] in
            guard let controller = self else { return }
            await oldEngine?.stopCapture()

            do {
                try await engine.startCapture()
                await MainActor.run {
                    guard controller.virtualCameraGeneration == generation,
                          controller.wantsVirtualCameraCapture,
                          controller.virtualCameraCaptureEngine === engine else {
                        Task { await engine.stopCapture() }
                        return
                    }
                    RegionShareManager.shared.setState(.streaming)
                }
            } catch {
                await MainActor.run {
                    if controller.virtualCameraCaptureEngine === engine {
                        controller.virtualCameraCaptureEngine = nil
                    }
                    guard controller.virtualCameraGeneration == generation else { return }
                    RegionFrameHub.shared.markInactive()
                    RegionShareManager.shared.setState(.idle)
                    print("❌ Failed to start virtual camera capture: \(error)")
                }
            }
        }
    }

    private func stopVirtualCameraCapture() {
        virtualCameraGeneration += 1
        guard let engine = virtualCameraCaptureEngine else {
            RegionFrameHub.shared.markInactive()
            return
        }

        engine.requestStop()
        virtualCameraCaptureEngine = nil
        Task {
            await engine.stopCapture()
            RegionFrameHub.shared.markInactive()
        }
    }

    func recoverVirtualCameraAfterWake() {
        guard wantsVirtualCameraCapture,
              let region = RegionShareManager.shared.currentRegion else { return }

        if RegionShareManager.shared.isDisplayValid(region.displayID) {
            startVirtualCameraCapture(for: region)
        } else {
            RegionShareManager.shared.clearRegion()
            stopVirtualCameraShare()
        }
    }

    private func bringMirrorWindowToFront() {
        mirrorWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func registerShortcut(with shortcutManager: ShortcutManager) {
        let success = shortcutManager.registerGlobalShortcut("ctrl+cmd+r") { [weak self] in
            self?.showRegionShare()
        }

        if success {
            print("🎯 Region Share shortcut registered: ⌃⌘R")
        } else {
            print("❌ Failed to register Region Share shortcut")
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

extension RegionShareController: RegionSelectionDelegate {
    func regionSelectionDidComplete(displayID: CGDirectDisplayID, rect: CGRect) {
        guard !didHandleSelection else { return }
        didHandleSelection = true
        closeSelectionOverlay()

        guard let displayBounds = RegionShareManager.shared.getDisplayBounds(for: displayID) else {
            print("❌ Could not get display bounds for selection")
            abortSelectionWithoutNewRegion()
            return
        }

        let boundedRect = rect.intersection(displayBounds)
        guard boundedRect.width >= 50 && boundedRect.height >= 50 else {
            abortSelectionWithoutNewRegion()
            return
        }

        let normalizedRect = ShareRegion.normalizedRect(from: boundedRect, in: displayBounds)
        let region = ShareRegion(displayID: displayID, normalizedRect: normalizedRect)

        isReselecting = false
        regionBeforeReselection = nil
        shouldRestoreMirrorOnCancel = false
        RegionShareManager.shared.setRegion(region)
        createAndShowMirrorWindow(for: region, mode: pendingPresentationMode)
        if wantsVirtualCameraCapture {
            startVirtualCameraCapture(for: region)
        }
    }

    func regionSelectionDidCancel() {
        guard !didHandleSelection else { return }
        didHandleSelection = true
        closeSelectionOverlay()
        abortSelectionWithoutNewRegion()
        print("🚫 Region selection cancelled")
    }

    private func abortSelectionWithoutNewRegion() {
        if isReselecting, let previous = regionBeforeReselection {
            RegionShareManager.shared.setRegion(previous)
            if shouldRestoreMirrorOnCancel {
                createAndShowMirrorWindow(for: previous, mode: pendingPresentationMode)
            }
            if wantsVirtualCameraCapture {
                startVirtualCameraCapture(for: previous)
            }
            RegionShareManager.shared.setState(wantsVirtualCameraCapture ? .streaming : .idle)
        } else {
            RegionShareManager.shared.setState(.idle)
        }

        isReselecting = false
        regionBeforeReselection = nil
        shouldRestoreMirrorOnCancel = false
    }
}
