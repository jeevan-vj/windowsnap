import Foundation
import AppKit

@available(macOS 12.3, *)
class RegionShareController: NSObject {
    
    static let shared = RegionShareController()
    
    private var selectionWindows: [RegionSelectionOverlayWindow] = []
    private var didHandleSelection = false
    private var mirrorWindow: RegionMirrorWindow?
    
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
        if let existingMirror = mirrorWindow, existingMirror.isVisible {
            bringMirrorWindowToFront()
            return
        }
        
        mirrorWindow = nil
        
        if let existingRegion = RegionShareManager.shared.currentRegion {
            if RegionShareManager.shared.isDisplayValid(existingRegion.displayID) {
                startMirrorWithRegion(existingRegion)
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
        // Keep existing mirror window alive during reselection to avoid close/recreate races.
        // #region agent log
        RegionShareDebugLog.write(hypothesis: "S", message: "selectNewRegion preserve mirror", data: [
            "runId": "post-fix-v8",
            "hasMirror": mirrorWindow != nil,
            "mirrorVisible": mirrorWindow?.isVisible ?? false
        ], sync: true)
        // #endregion
        mirrorWindow?.stopCapture()
        mirrorWindow?.orderOut(nil)
        RegionShareManager.shared.clearRegion()
        startRegionSelection()
    }
    
    func closeMirrorWindow() {
        // #region agent log
        RegionShareDebugLog.write(hypothesis: "Q", message: "closeMirrorWindow called", data: [
            "runId": "post-fix-v6",
            "hasMirror": mirrorWindow != nil,
            "mirrorVisible": mirrorWindow?.isVisible ?? false
        ], sync: true)
        // #endregion
        mirrorWindow?.close()
        mirrorWindow = nil
    }
    
    private func closeSelectionOverlay() {
        // #region agent log
        RegionShareDebugLog.write(hypothesis: "F,G", message: "closeSelectionOverlay begin", data: [
            "runId": "post-fix",
            "windowCount": selectionWindows.count,
            "appWindowCount": NSApp.windows.count
        ], sync: true)
        // #endregion
        for window in selectionWindows {
            window.close()
        }
        selectionWindows.removeAll()
        // #region agent log
        RegionShareDebugLog.write(hypothesis: "F,G", message: "closeSelectionOverlay end", data: [
            "runId": "post-fix",
            "appWindowCount": NSApp.windows.count
        ], sync: true)
        // #endregion
    }
    
    private func showSelectionOverlay() {
        if !selectionWindows.isEmpty {
            closeSelectionOverlay()
        }
        didHandleSelection = false
        
        let displays = RegionShareManager.shared.getAllDisplays()
        
        // #region agent log
        RegionShareDebugLog.write(hypothesis: "A,B", message: "showSelectionOverlay creating overlays", data: {
            var d: [String: Any] = [:]
            d["runId"] = "post-fix"
            d["mainDisplayID"] = CGMainDisplayID()
            d["overlayCount"] = displays.count
            d["displays"] = displays.map { id in
                ["id": id, "bounds": NSStringFromRect(CGDisplayBounds(id))] as [String: Any]
            }
            return d
        }())
        // #endregion
        
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
    
    private func startMirrorWithRegion(_ region: ShareRegion) {
        if ScreenRecordingPermissions.hasPermissions() {
            createAndShowMirrorWindow(for: region)
        } else {
            ScreenRecordingPermissions.checkPermissionsWithAlert { [weak self] hasPermission in
                if hasPermission {
                    self?.createAndShowMirrorWindow(for: region)
                } else {
                    print("⚠️ Screen recording permission not granted - user needs to enable in System Settings and restart")
                    RegionShareManager.shared.setState(.idle)
                }
            }
        }
    }
    
    private func createAndShowMirrorWindow(for region: ShareRegion) {
        if let existingMirror = mirrorWindow {
            // #region agent log
            RegionShareDebugLog.write(hypothesis: "S", message: "reuse existing mirror window", data: [
                "runId": "post-fix-v8",
                "wasVisible": existingMirror.isVisible
            ], sync: true)
            // #endregion
            existingMirror.updateRegion(region)
            existingMirror.makeKeyAndOrderFront(nil)
            existingMirror.startCapture()
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        // #region agent log
        RegionShareDebugLog.write(hypothesis: "I", message: "createMirror: init start", data: ["runId": "post-fix"], sync: true)
        // #endregion
        let window = RegionMirrorWindow(region: region)
        // #region agent log
        RegionShareDebugLog.write(hypothesis: "I", message: "createMirror: init done", data: ["runId": "post-fix"], sync: true)
        // #endregion
        window.makeKeyAndOrderFront(nil)
        // #region agent log
        RegionShareDebugLog.write(hypothesis: "I", message: "createMirror: ordered front", data: ["runId": "post-fix"], sync: true)
        // #endregion
        window.startCapture()
        // #region agent log
        RegionShareDebugLog.write(hypothesis: "I", message: "createMirror: startCapture returned", data: ["runId": "post-fix"], sync: true)
        // #endregion
        
        mirrorWindow = window
        
        NSApp.activate(ignoringOtherApps: true)
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

@available(macOS 12.3, *)
extension RegionShareController: RegionSelectionDelegate {
    func regionSelectionDidComplete(displayID: CGDirectDisplayID, rect: CGRect) {
        guard !didHandleSelection else { return }
        didHandleSelection = true
        closeSelectionOverlay()
        
        // #region agent log
        RegionShareDebugLog.write(hypothesis: "I,J,K", message: "didComplete entry", data: [
            "runId": "post-fix", "displayID": displayID, "rect": NSStringFromRect(rect)
        ], sync: true)
        // #endregion
        
        guard let displayBounds = RegionShareManager.shared.getDisplayBounds(for: displayID) else {
            print("❌ Could not get display bounds for selection")
            RegionShareManager.shared.setState(.idle)
            return
        }
        
        let boundedRect = rect.intersection(displayBounds)
        guard boundedRect.width >= 50 && boundedRect.height >= 50 else {
            // #region agent log
            RegionShareDebugLog.write(hypothesis: "L", message: "controller boundedRect too small", data: [
                "runId": "post-fix-v3",
                "rect": NSStringFromRect(rect),
                "displayBounds": NSStringFromRect(displayBounds),
                "boundedRect": NSStringFromRect(boundedRect)
            ], sync: true)
            // #endregion
            RegionShareManager.shared.setState(.idle)
            return
        }
        
        let normalizedRect = ShareRegion.normalizedRect(from: boundedRect, in: displayBounds)
        let region = ShareRegion(displayID: displayID, normalizedRect: normalizedRect)
        
        RegionShareManager.shared.setRegion(region)
        
        // #region agent log
        RegionShareDebugLog.write(hypothesis: "I,J,K", message: "didComplete before mirror", data: [
            "runId": "post-fix", "normalizedRect": NSStringFromRect(normalizedRect),
            "displayBounds": NSStringFromRect(displayBounds),
            "boundedRect": NSStringFromRect(boundedRect)
        ], sync: true)
        // #endregion
        
        createAndShowMirrorWindow(for: region)
        
        // #region agent log
        RegionShareDebugLog.write(hypothesis: "I,J,K", message: "didComplete after mirror", data: [
            "runId": "post-fix"
        ], sync: true)
        // #endregion
    }
    
    func regionSelectionDidCancel() {
        // #region agent log
        RegionShareDebugLog.write(hypothesis: "F,G", message: "regionSelectionDidCancel", data: [
            "runId": "post-fix",
            "alreadyHandled": didHandleSelection
        ], sync: true)
        // #endregion
        guard !didHandleSelection else { return }
        didHandleSelection = true
        closeSelectionOverlay()
        RegionShareManager.shared.setState(.idle)
        print("🚫 Region selection cancelled")
    }
}
