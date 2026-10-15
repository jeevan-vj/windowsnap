import Foundation
import AppKit

/// Represents the saved position and state of a specific window
struct WindowLayout: Codable, Equatable {
    let windowTitle: String
    /// Version 2 stores this frame normalized to the display's visible frame.
    let frame: CGRect
    let screenIndex: Int
    let displayUUID: String?
    let displayID: UInt32?
    let isMinimized: Bool
    let isMaximized: Bool
    
    init(
        windowTitle: String,
        frame: CGRect,
        screenIndex: Int,
        displayUUID: String? = nil,
        displayID: UInt32? = nil,
        isMinimized: Bool = false,
        isMaximized: Bool = false
    ) {
        self.windowTitle = windowTitle
        self.frame = frame
        self.screenIndex = screenIndex
        self.displayUUID = displayUUID
        self.displayID = displayID
        self.isMinimized = isMinimized
        self.isMaximized = isMaximized
    }

    private enum CodingKeys: String, CodingKey {
        case windowTitle, frame, screenIndex, displayUUID, displayID, screenID
        case isMinimized, isMaximized
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        windowTitle = try container.decode(String.self, forKey: .windowTitle)
        frame = try container.decode(CGRect.self, forKey: .frame)
        screenIndex = try container.decodeIfPresent(Int.self, forKey: .screenIndex) ?? 0
        displayUUID = try container.decodeIfPresent(String.self, forKey: .displayUUID)
        displayID = try container.decodeIfPresent(UInt32.self, forKey: .displayID)
            ?? container.decodeIfPresent(UInt32.self, forKey: .screenID)
        isMinimized = try container.decodeIfPresent(Bool.self, forKey: .isMinimized) ?? false
        isMaximized = try container.decodeIfPresent(Bool.self, forKey: .isMaximized) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(windowTitle, forKey: .windowTitle)
        try container.encode(frame, forKey: .frame)
        try container.encode(screenIndex, forKey: .screenIndex)
        try container.encodeIfPresent(displayUUID, forKey: .displayUUID)
        try container.encodeIfPresent(displayID, forKey: .displayID)
        try container.encode(isMinimized, forKey: .isMinimized)
        try container.encode(isMaximized, forKey: .isMaximized)
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
    static let currentFormatVersion = 2

    let id: UUID
    let name: String
    let appLayouts: [AppLayout]
    let createdDate: Date
    let lastUsed: Date?
    let shortcut: String?
    let description: String
    let formatVersion: Int
    
    init(name: String, appLayouts: [AppLayout], shortcut: String? = nil) {
        self.id = UUID()
        self.name = name
        self.appLayouts = appLayouts
        self.createdDate = Date()
        self.lastUsed = nil
        self.shortcut = shortcut
        self.description = "\(appLayouts.count) apps"
        self.formatVersion = Self.currentFormatVersion
    }
    
    /// Create a new workspace with updated properties
    private init(id: UUID, name: String, appLayouts: [AppLayout], 
                 createdDate: Date, lastUsed: Date?, shortcut: String?, description: String,
                 formatVersion: Int = Self.currentFormatVersion) {
        self.id = id
        self.name = name
        self.appLayouts = appLayouts
        self.createdDate = createdDate
        self.lastUsed = lastUsed
        self.shortcut = shortcut
        self.description = description
        self.formatVersion = formatVersion
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
            description: self.description,
            formatVersion: self.formatVersion
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

    func updatingMetadata(name: String, shortcut: String?) -> WorkspaceArrangement {
        WorkspaceArrangement(
            id: id,
            name: name,
            appLayouts: appLayouts,
            createdDate: createdDate,
            lastUsed: lastUsed,
            shortcut: shortcut,
            description: description,
            formatVersion: formatVersion
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, appLayouts, createdDate, lastUsed, shortcut, description, formatVersion
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        appLayouts = try container.decode([AppLayout].self, forKey: .appLayouts)
        createdDate = try container.decode(Date.self, forKey: .createdDate)
        lastUsed = try container.decodeIfPresent(Date.self, forKey: .lastUsed)
        shortcut = try container.decodeIfPresent(String.self, forKey: .shortcut)
        description = try container.decodeIfPresent(String.self, forKey: .description)
            ?? "\(appLayouts.count) apps"
        formatVersion = try container.decodeIfPresent(Int.self, forKey: .formatVersion) ?? 1
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(appLayouts, forKey: .appLayouts)
        try container.encode(createdDate, forKey: .createdDate)
        try container.encodeIfPresent(lastUsed, forKey: .lastUsed)
        try container.encodeIfPresent(shortcut, forKey: .shortcut)
        try container.encode(description, forKey: .description)
        try container.encode(formatVersion, forKey: .formatVersion)
    }

    func migrated(to screens: [WorkspaceScreenGeometry]) -> WorkspaceArrangement {
        guard formatVersion < Self.currentFormatVersion else { return self }
        let migratedApps = appLayouts.map { app in
            let windows = app.windowLayouts.map { window -> WindowLayout in
                guard let migrated = WorkspaceCoordinateMath.migrateLegacyFrame(
                    window.frame,
                    displayUUID: window.displayUUID,
                    legacyDisplayID: window.displayID,
                    legacyIndex: window.screenIndex,
                    screens: screens
                ) else { return window }
                return WindowLayout(
                    windowTitle: window.windowTitle,
                    frame: migrated.frame,
                    screenIndex: migrated.screen.index,
                    displayUUID: migrated.screen.displayUUID,
                    displayID: migrated.screen.displayID,
                    isMinimized: window.isMinimized,
                    isMaximized: window.isMaximized
                )
            }
            return AppLayout(
                bundleIdentifier: app.bundleIdentifier,
                applicationName: app.applicationName,
                windowLayouts: windows,
                isRunning: app.isRunning
            )
        }
        return WorkspaceArrangement(
            id: id,
            name: name,
            appLayouts: migratedApps,
            createdDate: createdDate,
            lastUsed: lastUsed,
            shortcut: shortcut,
            description: description
        )
    }
    
    /// Get all unique app bundle identifiers in this workspace
    var appBundleIdentifiers: [String] {
        return Array(Set(appLayouts.map { $0.bundleIdentifier }))
    }
}

/// Manages workspace arrangements - saving and restoring entire desktop layouts
class WorkspaceManager {
    static let shared = WorkspaceManager()
    
    private let userDefaults: UserDefaults
    private let storageKey = "WindowSnap_WorkspaceArrangements"
    private var arrangements: [WorkspaceArrangement] = []
    private weak var shortcutManager: ShortcutManager?
    private var inactiveShortcutIDs: Set<UUID> = []
    
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
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
            let decoded = try JSONDecoder().decode([WorkspaceArrangement].self, from: data)
            let needsMigration = decoded.contains { $0.formatVersion < WorkspaceArrangement.currentFormatVersion }
            arrangements = decoded.map { $0.migrated(to: currentScreenGeometries()) }
            if needsMigration {
                _ = saveArrangements()
                print("📐 Migrated legacy workspace coordinates to format \(WorkspaceArrangement.currentFormatVersion)")
            }
            print("📁 Loaded \(arrangements.count) workspace arrangements")
        } catch {
            print("❌ Failed to load workspace arrangements: \(error)")
            arrangements = []
        }
    }
    
    /// Save workspace arrangements to UserDefaults
    @discardableResult
    private func saveArrangements() -> Bool {
        do {
            let data = try JSONEncoder().encode(arrangements)
            userDefaults.set(data, forKey: storageKey)
            print("💾 Saved \(arrangements.count) workspace arrangements")
            return true
        } catch {
            print("❌ Failed to save workspace arrangements: \(error)")
            return false
        }
    }

    func configure(shortcutManager: ShortcutManager) {
        self.shortcutManager = shortcutManager
        inactiveShortcutIDs.removeAll()
        for arrangement in arrangements where arrangement.hasShortcut {
            if registerShortcut(for: arrangement) == .registered { continue }
            inactiveShortcutIDs.insert(arrangement.id)
        }
    }

    func isShortcutActive(for arrangement: WorkspaceArrangement) -> Bool {
        !arrangement.hasShortcut || !inactiveShortcutIDs.contains(arrangement.id)
    }
    
    // MARK: - Workspace Capture
    
    /// Capture the current workspace state
    func captureCurrentWorkspace(name: String, shortcut: String? = nil) -> WorkspaceArrangement? {
        switch captureCurrentWorkspaceResult(name: name, shortcut: shortcut) {
        case .success(let arrangement): return arrangement
        case .failure: return nil
        }
    }

    func captureCurrentWorkspaceResult(
        name: String,
        shortcut: String? = nil
    ) -> Result<WorkspaceArrangement, ManagedConfigurationError> {
        print("📸 Capturing current workspace: '\(name)'")

        guard let windowManager = getCurrentWindowManager() else {
            print("❌ WindowManager not available")
            return .failure(.nothingToCapture)
        }

        return captureCurrentWorkspaceResult(
            name: name,
            shortcut: shortcut,
            allWindows: windowManager.getAllWindows()
        )
    }

    func captureCurrentWorkspaceResult(
        name: String,
        shortcut: String? = nil,
        completion: @escaping (Result<WorkspaceArrangement, ManagedConfigurationError>) -> Void
    ) {
        print("📸 Capturing current workspace: '\(name)'")
        WindowManager.shared.getAllWindowsAsync { [weak self] windows in
            guard let self else {
                completion(.failure(.persistenceFailed))
                return
            }
            completion(self.captureCurrentWorkspaceResult(name: name, shortcut: shortcut, allWindows: windows))
        }
    }

    private func captureCurrentWorkspaceResult(
        name: String,
        shortcut: String?,
        allWindows: [WindowInfo]
    ) -> Result<WorkspaceArrangement, ManagedConfigurationError> {
        let windowManager = WindowManager.shared
        var appLayouts: [String: AppLayout] = [:]
        
        // Group windows by application
        for window in allWindows {
            let bundleId = getBundleIdentifier(for: window) ?? "unknown.\(window.applicationName)"
            guard let screen = windowManager.screenContainingAXRect(window.frame),
                  let screenIndex = NSScreen.screens.firstIndex(of: screen) else {
                print("⚠️ Skipping window with no matching display: \(window.windowTitle)")
                continue
            }
            let appKitFrame = windowManager.appKitFrame(fromAX: window.frame)
            let windowLayout = WindowLayout(
                windowTitle: window.windowTitle,
                frame: WorkspaceCoordinateMath.normalizedFrame(appKitFrame, in: screen.visibleFrame),
                screenIndex: screenIndex,
                displayUUID: screen.displayUUID,
                displayID: screen.displayID
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
            return .failure(.nothingToCapture)
        }
        
        let arrangement = WorkspaceArrangement(
            name: name,
            appLayouts: appLayoutsArray,
            shortcut: shortcut
        )
        
        switch addArrangement(arrangement) {
        case .success:
            break
        case .failure(let error):
            return .failure(error)
        }
        
        print("✅ Captured workspace with \(appLayoutsArray.count) apps and \(allWindows.count) windows")
        return .success(arrangement)
    }
    
    // MARK: - Workspace Restoration
    
    /// Restore a workspace arrangement
    func restoreWorkspace(_ arrangement: WorkspaceArrangement) {
        print("🎯 Restoring workspace: '\(arrangement.name)'")
        WindowManager.shared.getAllWindowsAsync { [weak self] currentWindows in
            self?.restoreWorkspace(arrangement, using: currentWindows)
        }
    }

    private func restoreWorkspace(_ arrangement: WorkspaceArrangement, using currentWindows: [WindowInfo]) {
        saveWorkspaceStateForUndo(action: "Restore: \(arrangement.name)", windows: currentWindows)

        var restoredWindows = 0
        var skippedWindows = 0
        var launchedApps = 0

        for appLayout in arrangement.appLayouts {
            if getRunningApp(bundleIdentifier: appLayout.bundleIdentifier) == nil {
                if launchApp(bundleIdentifier: appLayout.bundleIdentifier) {
                    launchedApps += 1
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                        WindowManager.shared.getAllWindowsAsync { launchedWindows in
                            guard let self else { return }
                            let result = self.restoreAppWindows(appLayout, currentWindows: launchedWindows)
                            self.logRestoreResult(result, appName: appLayout.applicationName)
                        }
                    }
                } else {
                    skippedWindows += appLayout.windowLayouts.count
                    print("⚠️ Could not launch app: \(appLayout.applicationName)")
                }
                continue
            }

            let result = restoreAppWindows(appLayout, currentWindows: currentWindows)
            restoredWindows += result.restored
            skippedWindows += result.skipped
        }

        print("✅ Workspace restoration initiated:")
        print("   - Restored \(restoredWindows) windows")
        print("   - Skipped \(skippedWindows) unavailable/off-Space windows")
        print("   - Launched \(launchedApps) apps")

        if var updatedArrangement = getArrangement(id: arrangement.id) {
            updatedArrangement.markAsUsed()
            updateArrangement(updatedArrangement)
        }
    }

    /// Restore windows for a specific app
    private func restoreAppWindows(
        _ appLayout: AppLayout,
        currentWindows: [WindowInfo]
    ) -> (restored: Int, skipped: Int) {
        guard let windowManager = getCurrentWindowManager() else {
            print("❌ WindowManager not available")
            return (0, appLayout.windowLayouts.count)
        }

        var available = currentWindows.filter {
            $0.applicationName == appLayout.applicationName && $0.isOnScreen && !$0.isMinimized
        }

        var restoredCount = 0
        var skippedCount = 0

        for windowLayout in appLayout.windowLayouts {
            guard let currentWindow = Self.takeMatchingWindow(
                title: windowLayout.windowTitle,
                from: &available
            ), currentWindow.axElement != nil,
               windowManager.currentAXFrame(of: currentWindow) != nil else {
                skippedCount += 1
                print("⚠️ Skipped unavailable/off-Space window: \(appLayout.applicationName) '\(windowLayout.windowTitle)'")
                continue
            }

            let targetScreen = getScreen(for: windowLayout)
            let targetFrame = WorkspaceCoordinateMath.denormalizedFrame(
                windowLayout.frame,
                in: targetScreen.visibleFrame
            )
            if windowManager.moveAndResizeWindow(currentWindow, to: targetFrame) {
                restoredCount += 1
            } else {
                skippedCount += 1
                print("⚠️ Skipped AX-rejected window: \(appLayout.applicationName) '\(windowLayout.windowTitle)'")
            }

            print("   ✅ Restored: \(currentWindow.windowTitle) to \(targetScreen.localizedName)")
        }

        return (restoredCount, skippedCount)
    }

    private func logRestoreResult(_ result: (restored: Int, skipped: Int), appName: String) {
        print("↪️ Delayed restore for \(appName): \(result.restored) restored, \(result.skipped) skipped")
    }

    /// Picks the window that should receive a saved layout.
    /// Named titles must match exactly; untitled layouts take the next leftover window.
    static func takeMatchingWindow(title: String, from available: inout [WindowInfo]) -> WindowInfo? {
        if !title.isEmpty {
            guard let index = available.firstIndex(where: { $0.windowTitle == title }) else {
                return nil
            }
            return available.remove(at: index)
        }
        guard !available.isEmpty else { return nil }
        return available.removeFirst()
    }
    
    // MARK: - Arrangement Management
    
    /// Add a new workspace arrangement
    @discardableResult
    func addArrangement(_ arrangement: WorkspaceArrangement) -> Result<Void, ManagedConfigurationError> {
        // Check for duplicate names
        if arrangements.contains(where: { $0.name == arrangement.name }) {
            print("⚠️ Workspace arrangement with name '\(arrangement.name)' already exists")
            return .failure(.duplicateName)
        }
        
        // Check for duplicate shortcuts
        if let shortcut = arrangement.shortcut,
           arrangements.contains(where: { $0.shortcut == shortcut }) {
            print("⚠️ Workspace arrangement with shortcut '\(shortcut)' already exists")
            return .failure(.duplicateShortcut)
        }

        if let shortcut = arrangement.shortcut {
            guard shortcutManager?.isValidShortcutSyntax(shortcut) == true else {
                return .failure(.invalidShortcut)
            }
            let registration = registerShortcut(for: arrangement)
            guard registration == .registered else {
                return .failure(.shortcutUnavailable(registration.failureMessage ?? "That shortcut is unavailable."))
            }
        }
        
        arrangements.append(arrangement)
        guard saveArrangements() else {
            arrangements.removeAll { $0.id == arrangement.id }
            if let shortcut = arrangement.shortcut { unregisterShortcut(shortcut) }
            return .failure(.persistenceFailed)
        }
        
        print("✅ Added workspace arrangement: '\(arrangement.name)'")
        
        // Register shortcut if provided
        inactiveShortcutIDs.remove(arrangement.id)
        return .success(())
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
    @discardableResult
    func updateArrangement(_ updatedArrangement: WorkspaceArrangement) -> Result<Void, ManagedConfigurationError> {
        guard let index = arrangements.firstIndex(where: { $0.id == updatedArrangement.id }) else {
            print("❌ Workspace arrangement with ID \(updatedArrangement.id) not found")
            return .failure(.persistenceFailed)
        }
        
        let oldArrangement = arrangements[index]
        
        if arrangements.contains(where: { $0.id != updatedArrangement.id && $0.name == updatedArrangement.name }) {
            return .failure(.duplicateName)
        }
        if let shortcut = updatedArrangement.shortcut,
           arrangements.contains(where: { $0.id != updatedArrangement.id && $0.shortcut == shortcut }) {
            return .failure(.duplicateShortcut)
        }

        let shortcutChanged = oldArrangement.shortcut != updatedArrangement.shortcut
        if shortcutChanged {
            if let newShortcut = updatedArrangement.shortcut,
               shortcutManager?.isValidShortcutSyntax(newShortcut) != true {
                return .failure(.invalidShortcut)
            }
            if let oldShortcut = oldArrangement.shortcut { unregisterShortcut(oldShortcut) }
            if updatedArrangement.hasShortcut {
                let registration = registerShortcut(for: updatedArrangement)
                guard registration == .registered else {
                    _ = registerShortcut(for: oldArrangement)
                    return .failure(.shortcutUnavailable(registration.failureMessage ?? "That shortcut is unavailable."))
                }
            }
        }

        arrangements[index] = updatedArrangement
        guard saveArrangements() else {
            arrangements[index] = oldArrangement
            if shortcutChanged {
                if let newShortcut = updatedArrangement.shortcut { unregisterShortcut(newShortcut) }
                _ = registerShortcut(for: oldArrangement)
            }
            return .failure(.persistenceFailed)
        }

        inactiveShortcutIDs.remove(updatedArrangement.id)
        
        print("📝 Updated workspace arrangement: '\(updatedArrangement.name)'")
        return .success(())
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
        let className: AnyClass? = NSClassFromString("WindowSnap.WindowManager") ?? NSClassFromString("WindowManager")
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
    
    /// Get a running app by bundle identifier
    private func getRunningApp(bundleIdentifier: String) -> NSRunningApplication? {
        return NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == bundleIdentifier }
    }
    
    /// Launch an app by bundle identifier
    private func launchApp(bundleIdentifier: String) -> Bool {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else {
            print("❌ Could not find app with bundle identifier: \(bundleIdentifier)")
            return false
        }
        NSWorkspace.shared.openApplication(at: url, configuration: .init()) { _, error in
            if let error {
                print("❌ Failed to launch app \(bundleIdentifier): \(error)")
            } else {
                print("🚀 Launched app: \(bundleIdentifier)")
            }
        }
        return true
    }
    
    private func currentScreenGeometries() -> [WorkspaceScreenGeometry] {
        NSScreen.screens.enumerated().map { index, screen in
            WorkspaceScreenGeometry(
                displayUUID: screen.displayUUID,
                displayID: screen.displayID,
                index: index,
                visibleFrame: screen.visibleFrame
            )
        }
    }

    /// UUID is stable across display ordering; legacy ID/index are compatibility fallbacks.
    private func getScreen(for layout: WindowLayout) -> NSScreen {
        let screens = NSScreen.screens
        if let uuid = layout.displayUUID,
           let screen = screens.first(where: { $0.displayUUID == uuid }) {
            return screen
        }
        if let displayID = layout.displayID,
           let screen = screens.first(where: { $0.displayID == displayID }) {
            return screen
        }
        if screens.indices.contains(layout.screenIndex) {
            return screens[layout.screenIndex]
        }
        return NSScreen.main ?? screens[0]
    }
    
    /// Save workspace state for undo (if available)
    private func saveWorkspaceStateForUndo(action: String, windows: [WindowInfo]) {
        // Check if WindowActionHistory is available
        let className: AnyClass? = NSClassFromString("WindowSnap.WindowActionHistory") ?? NSClassFromString("WindowActionHistory")
        if className != nil {
            // If available, save state
            let representativeWindows = Array(windows.prefix(5))
            
            for window in representativeWindows {
                WindowActionHistory.shared.saveState(before: action, window: window)
            }
            print("💾 Saved workspace state before: \(action)")
        }
    }
    
    // MARK: - Shortcut Management
    
    /// Register a global shortcut for a workspace arrangement
    private func registerShortcut(for arrangement: WorkspaceArrangement) -> ShortcutRegistrationResult {
        guard let shortcut = arrangement.shortcut else { return .registered }
        guard let shortcutManager else { return .systemRejected(-1) }
        return shortcutManager.registerGlobalShortcutDetailed(shortcut) { [weak self] in
            guard let current = self?.getArrangement(id: arrangement.id) else { return }
            self?.executeArrangement(current)
        }
    }
    
    /// Unregister a global shortcut
    private func unregisterShortcut(_ shortcut: String) {
        shortcutManager?.unregisterShortcut(shortcut)
    }
}
