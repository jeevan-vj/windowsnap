import Foundation
import AppKit

/// Represents the saved position and state of a specific window
struct WindowLayout: Codable, Equatable {
    let windowTitle: String
    let frame: CGRect
    let screenIndex: Int
    let isMinimized: Bool
    let isMaximized: Bool
    
    init(windowTitle: String, frame: CGRect, screenIndex: Int, isMinimized: Bool = false, isMaximized: Bool = false) {
        self.windowTitle = windowTitle
        self.frame = frame
        self.screenIndex = screenIndex
        self.isMinimized = isMinimized
        self.isMaximized = isMaximized
    }
    
    /// Get display description for UI
    var displayDescription: String {
        return "\(windowTitle) - Manual Position"
    }
}

/// Represents the layout configuration for a specific application
struct AppLayout: Codable, Equatable {
    let bundleIdentifier: String
    let applicationName: String
    let windowLayouts: [WindowLayout]
    let isRunning: Bool
    
    init(bundleIdentifier: String, applicationName: String, windowLayouts: [WindowLayout], isRunning: Bool = true) {
        self.bundleIdentifier = bundleIdentifier
        self.applicationName = applicationName
        self.windowLayouts = windowLayouts
        self.isRunning = isRunning
    }
    
    /// Get display name for UI
    var displayName: String {
        return "\(applicationName) (\(windowLayouts.count) windows)"
    }
}

/// Represents a saved workspace arrangement with all app positions
struct WorkspaceArrangement: Codable, Identifiable, Equatable {
    let id: UUID
    let name: String
    let appLayouts: [AppLayout]
    let createdDate: Date
    let lastUsed: Date?
    let shortcut: String?
    let description: String
    
    init(name: String, appLayouts: [AppLayout], shortcut: String? = nil) {
        self.id = UUID()
        self.name = name
        self.appLayouts = appLayouts
        self.createdDate = Date()
        self.lastUsed = nil
        self.shortcut = shortcut
        self.description = "\(appLayouts.count) apps"
    }
    
    /// Create a new workspace with updated properties
    private init(id: UUID, name: String, appLayouts: [AppLayout], 
                 createdDate: Date, lastUsed: Date?, shortcut: String?, description: String) {
        self.id = id
        self.name = name
        self.appLayouts = appLayouts
        self.createdDate = createdDate
        self.lastUsed = lastUsed
        self.shortcut = shortcut
        self.description = description
    }
    
    /// Update last used timestamp
    mutating func markAsUsed() {
        self = WorkspaceArrangement(
            id: self.id,
            name: self.name,
            appLayouts: self.appLayouts,
            createdDate: self.createdDate,
            lastUsed: Date(),
            shortcut: self.shortcut,
            description: self.description
        )
    }
    
    /// Get display description for UI
    var displayDescription: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return "\(appLayouts.count) apps, created \(formatter.string(from: createdDate))"
    }
    
    /// Check if this arrangement has a valid shortcut
    var hasShortcut: Bool {
        return shortcut?.isEmpty == false
    }
    
    /// Get all unique app bundle identifiers in this workspace
    var appBundleIdentifiers: [String] {
        return Array(Set(appLayouts.map { $0.bundleIdentifier }))
    }
}

/// Manages workspace arrangements - saving and restoring entire desktop layouts
class WorkspaceManager {
    static let shared = WorkspaceManager()
    
    private let userDefaults = UserDefaults.standard
    private let storageKey = "WindowSnap_WorkspaceArrangements"
    private var arrangements: [WorkspaceArrangement] = []
    
    private init() {
        loadArrangements()
    }
    
    // MARK: - Storage Operations
    
    /// Load workspace arrangements from UserDefaults
    private func loadArrangements() {
        guard let data = userDefaults.data(forKey: storageKey) else {
            arrangements = []
            return
        }
        
        do {
            arrangements = try JSONDecoder().decode([WorkspaceArrangement].self, from: data)
            print("📁 Loaded \(arrangements.count) workspace arrangements")
        } catch {
            print("❌ Failed to load workspace arrangements: \(error)")
            arrangements = []
        }
    }
    
    /// Save workspace arrangements to UserDefaults
    private func saveArrangements() {
        do {
            let data = try JSONEncoder().encode(arrangements)
            userDefaults.set(data, forKey: storageKey)
            print("💾 Saved \(arrangements.count) workspace arrangements")
        } catch {
            print("❌ Failed to save workspace arrangements: \(error)")
        }
    }
    
    // MARK: - Workspace Capture
    
    /// Capture the current workspace state
    func captureCurrentWorkspace(name: String, shortcut: String? = nil) -> WorkspaceArrangement? {
        print("📸 Capturing current workspace: '\(name)'")
        
        guard let windowManager = getCurrentWindowManager() else {
            print("❌ WindowManager not available")
            return nil
        }
        
        let allWindows = windowManager.getAllWindows()
        var appLayouts: [String: AppLayout] = [:]
        
        // Group windows by application
        for window in allWindows {
            let bundleId = getBundleIdentifier(for: window) ?? "unknown.\(window.applicationName)"
            
            // Determine screen index
            let screenIndex = getScreenIndex(for: window)
            
            // Create window layout
            let windowLayout = WindowLayout(
                windowTitle: window.windowTitle,
                frame: window.frame,
                screenIndex: screenIndex
            )
            
            // Add to app layout
            if let existingLayout = appLayouts[bundleId] {
                var updatedWindowLayouts = existingLayout.windowLayouts
                updatedWindowLayouts.append(windowLayout)
                appLayouts[bundleId] = AppLayout(
                    bundleIdentifier: bundleId,
                    applicationName: existingLayout.applicationName,
                    windowLayouts: updatedWindowLayouts,
                    isRunning: true
                )
            } else {
                appLayouts[bundleId] = AppLayout(
                    bundleIdentifier: bundleId,
                    applicationName: window.applicationName,
                    windowLayouts: [windowLayout],
                    isRunning: true
                )
            }
        }
        
        let appLayoutsArray = Array(appLayouts.values)
        
        guard !appLayoutsArray.isEmpty else {
            print("❌ No windows found to capture")
            return nil
        }
        
        let arrangement = WorkspaceArrangement(
            name: name,
            appLayouts: appLayoutsArray,
            shortcut: shortcut
        )
        
        addArrangement(arrangement)
        
        print("✅ Captured workspace with \(appLayoutsArray.count) apps and \(allWindows.count) windows")
        return arrangement
    }
    
    // MARK: - Workspace Restoration
    
    /// Restore a workspace arrangement
    func restoreWorkspace(_ arrangement: WorkspaceArrangement) {
        print("🎯 Restoring workspace: '\(arrangement.name)'")
        
        // Save state for undo (if WindowActionHistory is available)
        saveWorkspaceStateForUndo(action: "Restore: \(arrangement.name)")
        
        var restoredWindows = 0
        var launchedApps = 0
        
        for appLayout in arrangement.appLayouts {
            // Check if app is running
            let runningApp = getRunningApp(bundleIdentifier: appLayout.bundleIdentifier)
            
            if runningApp == nil {
                // Try to launch the app
                if launchApp(bundleIdentifier: appLayout.bundleIdentifier) {
                    launchedApps += 1
                    
                    // Wait a bit for the app to launch
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        _ = self.restoreAppWindows(appLayout)
                    }
                } else {
                    print("⚠️ Could not launch app: \(appLayout.applicationName)")
                }
            } else {
                // App is running, restore windows immediately
                restoredWindows += restoreAppWindows(appLayout)
            }
        }
        
        print("✅ Workspace restoration initiated:")
        print("   - Restored \(restoredWindows) windows")
        print("   - Launched \(launchedApps) apps")
        
        // Mark as used
        if var updatedArrangement = getArrangement(id: arrangement.id) {
            updatedArrangement.markAsUsed()
            updateArrangement(updatedArrangement)
        }
    }
    
    /// Restore windows for a specific app
    private func restoreAppWindows(_ appLayout: AppLayout) -> Int {
        guard let windowManager = getCurrentWindowManager() else {
            print("❌ WindowManager not available")
            return 0
        }
        
        let currentWindows = windowManager.getAllWindows()
        let appWindows = currentWindows.filter { $0.applicationName == appLayout.applicationName }
        
        var restoredCount = 0
        
        // Match saved window layouts with current windows (best effort)
        for (index, windowLayout) in appLayout.windowLayouts.enumerated() {
            guard index < appWindows.count else {
                print("⚠️ Not enough windows for \(appLayout.applicationName)")
                break
            }
            
            let currentWindow = appWindows[index]
            
            // Get target screen
            guard let targetScreen = getScreen(at: windowLayout.screenIndex) else {
                print("⚠️ Screen \(windowLayout.screenIndex) not available")
                continue
            }
            
            // Calculate target frame for current screen setup
            let targetFrame = adjustFrameForCurrentScreen(windowLayout.frame, targetScreen: targetScreen)
            
            // Restore window position
            windowManager.moveAndResizeWindow(currentWindow, to: targetFrame)
            restoredCount += 1
            
            print("   ✅ Restored: \(currentWindow.windowTitle) to screen \(windowLayout.screenIndex)")
        }
        
        return restoredCount
    }
    
    // MARK: - Arrangement Management
    
    /// Add a new workspace arrangement
    func addArrangement(_ arrangement: WorkspaceArrangement) {
        // Check for duplicate names
        if arrangements.contains(where: { $0.name == arrangement.name }) {
            print("⚠️ Workspace arrangement with name '\(arrangement.name)' already exists")
            return
        }
        
        // Check for duplicate shortcuts
        if let shortcut = arrangement.shortcut,
           arrangements.contains(where: { $0.shortcut == shortcut }) {
            print("⚠️ Workspace arrangement with shortcut '\(shortcut)' already exists")
            return
        }
        
        arrangements.append(arrangement)
        saveArrangements()
        
        print("✅ Added workspace arrangement: '\(arrangement.name)'")
        
        // Register shortcut if provided
        if arrangement.hasShortcut {
            registerShortcut(for: arrangement)
        }
    }
    
    /// Remove a workspace arrangement
    func removeArrangement(id: UUID) {
        guard let index = arrangements.firstIndex(where: { $0.id == id }) else {
            print("❌ Workspace arrangement with ID \(id) not found")
            return
        }
        
        let arrangement = arrangements[index]
        
        // Unregister shortcut if it exists
        if let shortcut = arrangement.shortcut {
            unregisterShortcut(shortcut)
        }
        
        arrangements.remove(at: index)
        saveArrangements()
        
        print("🗑️ Removed workspace arrangement: '\(arrangement.name)'")
    }
    
    /// Update an existing workspace arrangement
    func updateArrangement(_ updatedArrangement: WorkspaceArrangement) {
        guard let index = arrangements.firstIndex(where: { $0.id == updatedArrangement.id }) else {
            print("❌ Workspace arrangement with ID \(updatedArrangement.id) not found")
            return
        }
        
        let oldArrangement = arrangements[index]
        
        // Unregister old shortcut
        if let oldShortcut = oldArrangement.shortcut {
            unregisterShortcut(oldShortcut)
        }
        
        arrangements[index] = updatedArrangement
        saveArrangements()
        
        // Register new shortcut
        if updatedArrangement.hasShortcut {
            registerShortcut(for: updatedArrangement)
        }
        
        print("📝 Updated workspace arrangement: '\(updatedArrangement.name)'")
    }
    
    /// Get all workspace arrangements
    func getAllArrangements() -> [WorkspaceArrangement] {
        return arrangements.sorted { $0.createdDate < $1.createdDate }
    }
    
    /// Get a workspace arrangement by ID
    func getArrangement(id: UUID) -> WorkspaceArrangement? {
        return arrangements.first { $0.id == id }
    }
    
    /// Execute a workspace arrangement
    func executeArrangement(_ arrangement: WorkspaceArrangement) {
        restoreWorkspace(arrangement)
    }
    
    // MARK: - Utility Methods
    
    /// Get current WindowManager instance safely
    private func getCurrentWindowManager() -> WindowManager? {
        // Use reflection to check if WindowManager is available
        let className = NSClassFromString("WindowSnap.WindowManager") ?? NSClassFromString("WindowManager")
        if className != nil {
            // If available, use WindowManager.shared
            return WindowManager.shared
        }
        return nil
    }
    
    /// Get the bundle identifier for a window
    private func getBundleIdentifier(for window: WindowInfo) -> String? {
        let runningApps = NSWorkspace.shared.runningApplications
        return runningApps.first { $0.processIdentifier == window.processID }?.bundleIdentifier
    }
    
    /// Get the screen index for a window
    private func getScreenIndex(for window: WindowInfo) -> Int {
        let windowCenter = CGPoint(x: window.frame.midX, y: window.frame.midY)
        
        for (index, screen) in NSScreen.screens.enumerated() {
            if screen.frame.contains(windowCenter) {
                return index
            }
        }
        
        return 0 // Default to main screen
    }
    
    /// Get a running app by bundle identifier
    private func getRunningApp(bundleIdentifier: String) -> NSRunningApplication? {
        return NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == bundleIdentifier }
    }
    
    /// Launch an app by bundle identifier
    private func launchApp(bundleIdentifier: String) -> Bool {
        do {
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
                print("❌ Could not find app with bundle identifier: \(bundleIdentifier)")
                return false
            }
            try NSWorkspace.shared.launchApplication(at: url, options: [], configuration: [:])
            print("🚀 Launched app: \(bundleIdentifier)")
            return true
        } catch {
            print("❌ Failed to launch app \(bundleIdentifier): \(error)")
            return false
        }
    }
    
    /// Get screen at specific index
    private func getScreen(at index: Int) -> NSScreen? {
        guard index >= 0 && index < NSScreen.screens.count else {
            return NSScreen.main
        }
        return NSScreen.screens[index]
    }
    
    /// Adjust frame for current screen configuration
    private func adjustFrameForCurrentScreen(_ frame: CGRect, targetScreen: NSScreen) -> CGRect {
        let screenFrame = targetScreen.visibleFrame
        
        // If the frame is larger than the screen, scale it down proportionally
        var adjustedFrame = frame
        
        if frame.width > screenFrame.width {
            let scale = screenFrame.width / frame.width
            adjustedFrame.size.width = screenFrame.width
            adjustedFrame.size.height *= scale
        }
        
        if adjustedFrame.height > screenFrame.height {
            let scale = screenFrame.height / adjustedFrame.height
            adjustedFrame.size.height = screenFrame.height
            adjustedFrame.size.width *= scale
        }
        
        // Ensure the frame is within screen bounds
        if adjustedFrame.minX < screenFrame.minX {
            adjustedFrame.origin.x = screenFrame.minX
        }
        if adjustedFrame.minY < screenFrame.minY {
            adjustedFrame.origin.y = screenFrame.minY
        }
        if adjustedFrame.maxX > screenFrame.maxX {
            adjustedFrame.origin.x = screenFrame.maxX - adjustedFrame.width
        }
        if adjustedFrame.maxY > screenFrame.maxY {
            adjustedFrame.origin.y = screenFrame.maxY - adjustedFrame.height
        }
        
        return adjustedFrame
    }
    
    /// Save workspace state for undo (if available)
    private func saveWorkspaceStateForUndo(action: String) {
        // Check if WindowActionHistory is available
        let className = NSClassFromString("WindowSnap.WindowActionHistory") ?? NSClassFromString("WindowActionHistory")
        if className != nil {
            // If available, save state
            guard let windowManager = getCurrentWindowManager() else { return }
            let allWindows = windowManager.getAllWindows()
            let representativeWindows = Array(allWindows.prefix(5))
            
            for window in representativeWindows {
                WindowActionHistory.shared.saveState(before: action, window: window)
            }
            print("💾 Saved workspace state before: \(action)")
        }
    }
    
    // MARK: - Shortcut Management
    
    /// Register a global shortcut for a workspace arrangement
    private func registerShortcut(for arrangement: WorkspaceArrangement) {
        guard let shortcut = arrangement.shortcut else { return }
        
        // TODO: Integrate with ShortcutManager
        // This will be implemented when we integrate with the main app
        print("🔗 Would register shortcut '\(shortcut)' for workspace '\(arrangement.name)'")
    }
    
    /// Unregister a global shortcut
    private func unregisterShortcut(_ shortcut: String) {
        // TODO: Integrate with ShortcutManager
        print("🔗 Would unregister shortcut '\(shortcut)'")
    }
}
