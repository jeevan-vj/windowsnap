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
            print("📁 Loaded saved share region for display \(currentRegion?.displayID ?? 0)")
        } catch {
            print("❌ Failed to load share region: \(error)")
            currentRegion = nil
        }
    }
    
    private func validateRegionDisplay() {
        guard let region = currentRegion else { return }
        
        let activeDisplays = getAllDisplays()
        if !activeDisplays.contains(region.displayID) {
            print("⚠️ Saved region display \(region.displayID) no longer available, clearing region")
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
            print("💾 Saved share region for display \(region.displayID)")
        } catch {
            print("❌ Failed to save share region: \(error)")
        }
    }
    
    func setRegion(_ region: ShareRegion) {
        currentRegion = region
        saveRegion()
        onRegionChanged?(region)
        print("✅ Region set: normalized \(region.normalizedRect)")
    }
    
    func clearRegion() {
        currentRegion = nil
        saveRegion()
        onRegionChanged?(nil)
        print("🗑️ Region cleared")
    }
    
    func updateMirrorWindowFrame(_ frame: CGRect) {
        guard let region = currentRegion else { return }
        currentRegion = region.withUpdatedMirrorFrame(frame)
        saveRegion()
    }
    
    func setState(_ newState: RegionShareState) {
        state = newState
        onStateChanged?(newState)
        print("🔄 Region share state: \(newState)")
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
