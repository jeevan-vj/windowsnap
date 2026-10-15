import Foundation
import AppKit

enum RegionShareState {
    case idle
    case selecting
    case streaming
}

class RegionShareManager {
    static let shared = RegionShareManager()
    
    private let userDefaults = UserDefaults.standard
    private let storageKey = "WindowSnap_RegionShareSingleRegion"
    
    private(set) var currentRegion: ShareRegion?
    private(set) var state: RegionShareState = .idle
    
    var onStateChanged: ((RegionShareState) -> Void)?
    var onRegionChanged: ((ShareRegion?) -> Void)?
    
    private init() {
        loadRegion()
        validateRegionDisplay()
    }
    
    private func loadRegion() {
        guard let data = userDefaults.data(forKey: storageKey) else {
            currentRegion = nil
            return
        }
        
        do {
            currentRegion = try JSONDecoder().decode(ShareRegion.self, from: data)
            AppLog.regionShare.info("Loaded saved region for display \(self.currentRegion?.displayID ?? 0)")
        } catch {
            AppLog.regionShare.error("Failed to load region: \(error.localizedDescription, privacy: .public)")
            currentRegion = nil
        }
    }
    
    private func validateRegionDisplay() {
        guard let region = currentRegion else { return }
        
        let activeDisplays = getAllDisplays()
        if !activeDisplays.contains(region.displayID) {
            AppLog.regionShare.notice("Saved region display \(region.displayID) is unavailable; clearing region")
            clearRegion()
        }
    }
    
    func isDisplayValid(_ displayID: CGDirectDisplayID) -> Bool {
        return getAllDisplays().contains(displayID)
    }
    
    private func saveRegion() {
        guard let region = currentRegion else {
            userDefaults.removeObject(forKey: storageKey)
            return
        }
        
        do {
            let data = try JSONEncoder().encode(region)
            userDefaults.set(data, forKey: storageKey)
            AppLog.regionShare.info("Saved region for display \(region.displayID)")
        } catch {
            AppLog.regionShare.error("Failed to save region: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    func setRegion(_ region: ShareRegion) {
        currentRegion = region
        saveRegion()
        onRegionChanged?(region)
        AppLog.regionShare.info("Region set: \(String(describing: region.normalizedRect), privacy: .public)")
    }
    
    func clearRegion() {
        currentRegion = nil
        saveRegion()
        onRegionChanged?(nil)
        AppLog.regionShare.info("Region cleared")
    }
    
    func updateMirrorWindowFrame(_ frame: CGRect) {
        guard let region = currentRegion else { return }
        currentRegion = region.withUpdatedMirrorFrame(frame)
        saveRegion()
    }
    
    func setState(_ newState: RegionShareState) {
        state = newState
        onStateChanged?(newState)
        AppLog.regionShare.debug("State changed: \(String(describing: newState), privacy: .public)")
    }
    
    func getDisplayBounds(for displayID: CGDirectDisplayID) -> CGRect? {
        let displayBounds = CGDisplayBounds(displayID)
        guard displayBounds.width > 0 && displayBounds.height > 0 else {
            return nil
        }
        return displayBounds
    }
    
    func getActiveDisplayID() -> CGDirectDisplayID {
        if let region = currentRegion, isDisplayValid(region.displayID) {
            return region.displayID
        }
        return CGMainDisplayID()
    }
    
    func getAllDisplays() -> [CGDirectDisplayID] {
        var displayCount: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &displayCount)
        
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
        CGGetActiveDisplayList(displayCount, &displays, &displayCount)
        
        return displays
    }
    
    func getDisplayForPoint(_ point: CGPoint) -> CGDirectDisplayID? {
        for displayID in getAllDisplays() {
            let bounds = CGDisplayBounds(displayID)
            if bounds.contains(point) {
                return displayID
            }
        }
        return nil
    }
    
    /// Resolves the display currently under the mouse cursor. Uses NSScreen so the
    /// AppKit (bottom-left origin) mouse location is matched correctly.
    func getDisplayUnderCursor() -> CGDirectDisplayID? {
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main,
              let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }
        return number.uint32Value
    }
}
