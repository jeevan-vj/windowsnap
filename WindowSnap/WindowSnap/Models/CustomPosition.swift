import Foundation
import AppKit

/// Represents a user-defined custom window position
struct CustomPosition: Codable, Identifiable, Equatable {
    let id: UUID
    let name: String
    let widthPercent: Double    // 0.0 - 1.0 (percentage of screen width)
    let heightPercent: Double   // 0.0 - 1.0 (percentage of screen height)
    let xPercent: Double        // 0.0 - 1.0 (percentage from left edge)
    let yPercent: Double        // 0.0 - 1.0 (percentage from bottom edge)
    let shortcut: String?       // Optional keyboard shortcut
    let createdDate: Date
    let lastUsed: Date?
    
    init(name: String, 
         widthPercent: Double, 
         heightPercent: Double, 
         xPercent: Double, 
         yPercent: Double, 
         shortcut: String? = nil) {
        self.id = UUID()
        self.name = name
        self.widthPercent = max(0.0, min(1.0, widthPercent))
        self.heightPercent = max(0.0, min(1.0, heightPercent))
        self.xPercent = max(0.0, min(1.0, xPercent))
        self.yPercent = max(0.0, min(1.0, yPercent))
        self.shortcut = shortcut
        self.createdDate = Date()
        self.lastUsed = nil
    }
    
    /// Create custom position from current window frame and screen
    init?(name: String, from window: WindowInfo, on screen: NSScreen, shortcut: String? = nil) {
        let screenFrame = screen.visibleFrame
        let windowFrame = window.frame
        
        // Validate that window is within screen bounds
        guard screenFrame.contains(windowFrame) else {
            return nil
        }
        
        self.id = UUID()
        self.name = name
        self.widthPercent = windowFrame.width / screenFrame.width
        self.heightPercent = windowFrame.height / screenFrame.height
        self.xPercent = (windowFrame.minX - screenFrame.minX) / screenFrame.width
        self.yPercent = (windowFrame.minY - screenFrame.minY) / screenFrame.height
        self.shortcut = shortcut
        self.createdDate = Date()
        self.lastUsed = nil
    }
    
    /// Calculate the actual frame for this custom position on the given screen
    func calculateFrame(for screen: NSScreen) -> CGRect {
        let screenFrame = screen.visibleFrame
        
        let width = screenFrame.width * widthPercent
        let height = screenFrame.height * heightPercent
        let x = screenFrame.minX + (screenFrame.width * xPercent)
        let y = screenFrame.minY + (screenFrame.height * yPercent)
        
        return CGRect(x: x, y: y, width: width, height: height)
    }
    
    /// Update last used timestamp
    mutating func markAsUsed() {
        self = CustomPosition(
            id: self.id,
            name: self.name,
            widthPercent: self.widthPercent,
            heightPercent: self.heightPercent,
            xPercent: self.xPercent,
            yPercent: self.yPercent,
            shortcut: self.shortcut,
            createdDate: self.createdDate,
            lastUsed: Date()
        )
    }
    
    /// Create a new custom position with updated properties
    private init(id: UUID, name: String, widthPercent: Double, heightPercent: Double, 
                xPercent: Double, yPercent: Double, shortcut: String?, 
                createdDate: Date, lastUsed: Date?) {
        self.id = id
        self.name = name
        self.widthPercent = widthPercent
        self.heightPercent = heightPercent
        self.xPercent = xPercent
        self.yPercent = yPercent
        self.shortcut = shortcut
        self.createdDate = createdDate
        self.lastUsed = lastUsed
    }
    
    /// Get display description for UI
    var displayDescription: String {
        let widthPct = Int(widthPercent * 100)
        let heightPct = Int(heightPercent * 100)
        let xPct = Int(xPercent * 100)
        let yPct = Int(yPercent * 100)
        
        return "\(widthPct)%×\(heightPct)% at (\(xPct)%, \(yPct)%)"
    }
    
    /// Check if this position has a valid shortcut
    var hasShortcut: Bool {
        return shortcut?.isEmpty == false
    }
}

/// Manages storage and operations for custom window positions
class CustomPositionManager {
    static let shared = CustomPositionManager()
    
    private let userDefaults = UserDefaults.standard
    private let storageKey = "WindowSnap_CustomPositions"
    private var positions: [CustomPosition] = []
    
    private init() {
        loadPositions()
    }
    
    // MARK: - Storage Operations
    
    /// Load custom positions from UserDefaults
    private func loadPositions() {
        guard let data = userDefaults.data(forKey: storageKey) else {
            positions = []
            return
        }
        
        do {
            positions = try JSONDecoder().decode([CustomPosition].self, from: data)
            print("📁 Loaded \(positions.count) custom positions")
        } catch {
            print("❌ Failed to load custom positions: \(error)")
            positions = []
        }
    }
    
    /// Save custom positions to UserDefaults
    private func savePositions() {
        do {
            let data = try JSONEncoder().encode(positions)
            userDefaults.set(data, forKey: storageKey)
            print("💾 Saved \(positions.count) custom positions")
        } catch {
            print("❌ Failed to save custom positions: \(error)")
        }
    }
    
    // MARK: - Position Management
    
    /// Add a new custom position
    func addPosition(_ position: CustomPosition) {
        // Check for duplicate names
        if positions.contains(where: { $0.name == position.name }) {
            print("⚠️ Custom position with name '\(position.name)' already exists")
            return
        }
        
        // Check for duplicate shortcuts
        if let shortcut = position.shortcut,
           positions.contains(where: { $0.shortcut == shortcut }) {
            print("⚠️ Custom position with shortcut '\(shortcut)' already exists")
            return
        }
        
        positions.append(position)
        savePositions()
        
        print("✅ Added custom position: '\(position.name)' (\(position.displayDescription))")
        
        // Register shortcut if provided
        if let shortcut = position.shortcut {
            registerShortcut(for: position)
        }
    }
    
    /// Remove a custom position by ID
    func removePosition(id: UUID) {
        guard let index = positions.firstIndex(where: { $0.id == id }) else {
            print("❌ Custom position with ID \(id) not found")
            return
        }
        
        let position = positions[index]
        
        // Unregister shortcut if it exists
        if let shortcut = position.shortcut {
            unregisterShortcut(shortcut)
        }
        
        positions.remove(at: index)
        savePositions()
        
        print("🗑️ Removed custom position: '\(position.name)'")
    }
    
    /// Update an existing custom position
    func updatePosition(_ updatedPosition: CustomPosition) {
        guard let index = positions.firstIndex(where: { $0.id == updatedPosition.id }) else {
            print("❌ Custom position with ID \(updatedPosition.id) not found")
            return
        }
        
        let oldPosition = positions[index]
        
        // Unregister old shortcut
        if let oldShortcut = oldPosition.shortcut {
            unregisterShortcut(oldShortcut)
        }
        
        positions[index] = updatedPosition
        savePositions()
        
        // Register new shortcut
        if let newShortcut = updatedPosition.shortcut {
            registerShortcut(for: updatedPosition)
        }
        
        print("📝 Updated custom position: '\(updatedPosition.name)'")
    }
    
    /// Get all custom positions
    func getAllPositions() -> [CustomPosition] {
        return positions.sorted { $0.createdDate < $1.createdDate }
    }
    
    /// Get a custom position by ID
    func getPosition(id: UUID) -> CustomPosition? {
        return positions.first { $0.id == id }
    }
    
    /// Get positions that have shortcuts assigned
    func getPositionsWithShortcuts() -> [CustomPosition] {
        return positions.filter { $0.hasShortcut }
    }
    
    // MARK: - Position Execution
    
    /// Execute a custom position on the focused window
    func executePosition(_ position: CustomPosition) {
        guard let focusedWindow = WindowManager.shared.getFocusedWindow() else {
            print("❌ No focused window for custom position execution")
            return
        }
        
        executePosition(position, on: focusedWindow)
    }
    
    /// Execute a custom position on a specific window
    func executePosition(_ position: CustomPosition, on window: WindowInfo) {
        // Find the screen containing the window
        guard let screen = getScreenContainingWindow(window) else {
            print("❌ Could not determine screen for window")
            return
        }
        
        // Calculate the target frame
        let targetFrame = position.calculateFrame(for: screen)
        
        print("🎯 Executing custom position '\(position.name)' on window '\(window.windowTitle)'")
        print("   Target frame: \(targetFrame)")
        
        // Save state for undo
        WindowActionHistory.shared.saveState(before: "Custom: \(position.name)", window: window)
        
        // Execute the window positioning
        WindowManager.shared.moveAndResizeWindow(window, to: targetFrame)
        
        // Mark position as used
        if var updatedPosition = getPosition(id: position.id) {
            updatedPosition.markAsUsed()
            updatePosition(updatedPosition)
        }
    }
    
    // MARK: - Shortcut Management
    
    /// Register a global shortcut for a custom position
    private func registerShortcut(for position: CustomPosition) {
        guard let shortcut = position.shortcut else { return }
        
        // TODO: Integrate with ShortcutManager
        // This will be implemented when we integrate with the main app
        print("🔗 Would register shortcut '\(shortcut)' for position '\(position.name)'")
    }
    
    /// Unregister a global shortcut
    private func unregisterShortcut(_ shortcut: String) {
        // TODO: Integrate with ShortcutManager
        print("🔗 Would unregister shortcut '\(shortcut)'")
    }
    
    // MARK: - Utility Methods
    
    /// Get the screen containing the given window
    private func getScreenContainingWindow(_ window: WindowInfo) -> NSScreen? {
        let windowCenter = CGPoint(
            x: window.frame.midX,
            y: window.frame.midY
        )
        
        for screen in NSScreen.screens {
            if screen.frame.contains(windowCenter) {
                return screen
            }
        }
        
        return NSScreen.main
    }
    
    /// Create a custom position from the current focused window
    func createFromCurrentWindow(name: String, shortcut: String? = nil) -> CustomPosition? {
        guard let focusedWindow = WindowManager.shared.getFocusedWindow(),
              let screen = getScreenContainingWindow(focusedWindow) else {
            print("❌ No focused window or screen for custom position creation")
            return nil
        }
        
        guard let position = CustomPosition(name: name, from: focusedWindow, on: screen, shortcut: shortcut) else {
            print("❌ Failed to create custom position from current window")
            return nil
        }
        
        addPosition(position)
        return position
    }
    
    /// Validate a shortcut string
    func isValidShortcut(_ shortcut: String) -> Bool {
        // Basic validation - check for common modifier patterns
        let modifiers = ["cmd", "ctrl", "option", "shift"]
        let parts = shortcut.lowercased().split(separator: "+")
        
        return parts.count >= 2 && parts.dropLast().allSatisfy { modifiers.contains(String($0)) }
    }
}
