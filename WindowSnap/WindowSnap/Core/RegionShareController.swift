import Foundation
import AppKit

@available(macOS 12.3, *)
class RegionShareController: NSObject {
    
    static let shared = RegionShareController()
    
    private var selectionWindow: RegionSelectionOverlayWindow?
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
        closeMirrorWindow()
        RegionShareManager.shared.clearRegion()
        startRegionSelection()
    }
    
    func closeMirrorWindow() {
        mirrorWindow?.stopCapture()
        mirrorWindow?.close()
        mirrorWindow = nil
    }
    
    private func closeSelectionOverlay() {
        selectionWindow?.close()
        selectionWindow = nil
    }
    
    private func showSelectionOverlay() {
        if selectionWindow != nil {
            closeSelectionOverlay()
        }
        
        let displayID = RegionShareManager.shared.getActiveDisplayID()
        
        RegionShareManager.shared.setState(.selecting)
        
        let overlay = RegionSelectionOverlayWindow(displayID: displayID)
        overlay.selectionDelegate = self
        overlay.makeKeyAndOrderFront(nil)
        
        selectionWindow = overlay
        
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
        let window = RegionMirrorWindow(region: region)
        window.makeKeyAndOrderFront(nil)
        window.startCapture()
        
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
        selectionWindow?.close()
        selectionWindow = nil
        
        guard let displayBounds = RegionShareManager.shared.getDisplayBounds(for: displayID) else {
            print("❌ Could not get display bounds for selection")
            RegionShareManager.shared.setState(.idle)
            return
        }
        
        let normalizedRect = ShareRegion.normalizedRect(from: rect, in: displayBounds)
        let region = ShareRegion(displayID: displayID, normalizedRect: normalizedRect)
        
        RegionShareManager.shared.setRegion(region)
        
        createAndShowMirrorWindow(for: region)
    }
    
    func regionSelectionDidCancel() {
        selectionWindow?.close()
        selectionWindow = nil
        RegionShareManager.shared.setState(.idle)
        print("🚫 Region selection cancelled")
    }
}
