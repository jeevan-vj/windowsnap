import Foundation
import AppKit

/// Represents a rule for automatically positioning windows of a specific application
struct AppPositioningRule: Codable, Identifiable, Equatable {
    let id: UUID
    let appName: String
    let bundleIdentifier: String
    let positionType: PositionType
    let targetScreenIndex: Int
    let windowFilter: WindowFilter
    let isEnabled: Bool
    let createdDate: Date
    let lastUsed: Date?

    enum PositionType: Codable, Equatable {
        case gridPosition(GridPosition)
        case customPosition(UUID) // Reference to a saved CustomPosition
        case maximize
        case center

        var displayName: String {
            switch self {
            case .gridPosition(let pos):
                return pos.displayName
            case .customPosition:
                return "Custom Position"
            case .maximize:
                return "Maximize"
            case .center:
                return "Center"
            }
        }
    }

    enum WindowFilter: Codable, Equatable {
        case firstWindowOnly
        case allWindows
        case windowWithTitle(String)

        var displayName: String {
            switch self {
            case .firstWindowOnly:
                return "First Window Only"
            case .allWindows:
                return "All Windows"
            case .windowWithTitle(let title):
                return "Window: \(title)"
            }
        }
    }

    init(appName: String,
         bundleIdentifier: String,
         positionType: PositionType,
         targetScreenIndex: Int = 0,
         windowFilter: WindowFilter = .firstWindowOnly,
         isEnabled: Bool = true) {
        self.id = UUID()
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.positionType = positionType
        self.targetScreenIndex = targetScreenIndex
        self.windowFilter = windowFilter
        self.isEnabled = isEnabled
        self.createdDate = Date()
        self.lastUsed = nil
    }

    /// Create a new rule with updated properties (for updates)
    private init(id: UUID,
                 appName: String,
                 bundleIdentifier: String,
                 positionType: PositionType,
                 targetScreenIndex: Int,
                 windowFilter: WindowFilter,
                 isEnabled: Bool,
                 createdDate: Date,
                 lastUsed: Date?) {
        self.id = id
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.positionType = positionType
        self.targetScreenIndex = targetScreenIndex
        self.windowFilter = windowFilter
        self.isEnabled = isEnabled
        self.createdDate = createdDate
        self.lastUsed = lastUsed
    }

    /// Update last used timestamp
    mutating func markAsUsed() {
        self = AppPositioningRule(
            id: self.id,
            appName: self.appName,
            bundleIdentifier: self.bundleIdentifier,
            positionType: self.positionType,
            targetScreenIndex: self.targetScreenIndex,
            windowFilter: self.windowFilter,
            isEnabled: self.isEnabled,
            createdDate: self.createdDate,
            lastUsed: Date()
        )
    }

    /// Create a disabled copy of this rule
    func disabled() -> AppPositioningRule {
        return AppPositioningRule(
            id: self.id,
            appName: self.appName,
            bundleIdentifier: self.bundleIdentifier,
            positionType: self.positionType,
            targetScreenIndex: self.targetScreenIndex,
            windowFilter: self.windowFilter,
            isEnabled: false,
            createdDate: self.createdDate,
            lastUsed: self.lastUsed
        )
    }

    /// Create an enabled copy of this rule
    func enabled() -> AppPositioningRule {
        return AppPositioningRule(
            id: self.id,
            appName: self.appName,
            bundleIdentifier: self.bundleIdentifier,
            positionType: self.positionType,
            targetScreenIndex: self.targetScreenIndex,
            windowFilter: self.windowFilter,
            isEnabled: true,
            createdDate: self.createdDate,
            lastUsed: self.lastUsed
        )
    }

    /// Get display description for UI
    var displayDescription: String {
        let screen = targetScreenIndex == 0 ? "Main Screen" : "Screen \(targetScreenIndex + 1)"
        let status = isEnabled ? "✓" : "✗"
        return "\(status) \(appName) → \(positionType.displayName) on \(screen)"
    }

    /// Get target screen
    func getTargetScreen() -> NSScreen? {
        let screens = NSScreen.screens
        guard targetScreenIndex >= 0 && targetScreenIndex < screens.count else {
            return NSScreen.main
        }
        return screens[targetScreenIndex]
    }

    /// Check if this rule should apply to the given window
    func shouldApply(to window: WindowInfo, isFirstWindow: Bool) -> Bool {
        guard isEnabled else { return false }

        switch windowFilter {
        case .firstWindowOnly:
            return isFirstWindow
        case .allWindows:
            return true
        case .windowWithTitle(let title):
            return window.windowTitle.contains(title)
        }
    }
}

// MARK: - Quick Rule Creation Helpers

extension AppPositioningRule {
    /// Create a rule from a running application
    static func fromRunningApp(_ app: NSRunningApplication,
                              position: PositionType,
                              screenIndex: Int = 0,
                              windowFilter: WindowFilter = .firstWindowOnly) -> AppPositioningRule? {
        guard let bundleId = app.bundleIdentifier,
              let appName = app.localizedName else {
            return nil
        }

        return AppPositioningRule(
            appName: appName,
            bundleIdentifier: bundleId,
            positionType: position,
            targetScreenIndex: screenIndex,
            windowFilter: windowFilter
        )
    }

    /// Create a rule from the current focused window
    static func fromCurrentWindow(position: PositionType,
                                 screenIndex: Int = 0,
                                 windowFilter: WindowFilter = .firstWindowOnly) -> AppPositioningRule? {
        guard let focusedWindow = WindowManager.shared.getFocusedWindow() else {
            return nil
        }

        // Get the bundle identifier for the focused window
        let runningApps = NSWorkspace.shared.runningApplications
        guard let app = runningApps.first(where: { $0.processIdentifier == focusedWindow.processID }),
              let bundleId = app.bundleIdentifier else {
            return nil
        }

        return AppPositioningRule(
            appName: focusedWindow.applicationName,
            bundleIdentifier: bundleId,
            positionType: position,
            targetScreenIndex: screenIndex,
            windowFilter: windowFilter
        )
    }
}

// MARK: - Common App Presets

extension AppPositioningRule {
    /// Get preset rules for common productivity setups
    static var commonPresets: [AppPositioningRule] {
        return [
            // Development setup
            AppPositioningRule(
                appName: "Terminal",
                bundleIdentifier: "com.apple.Terminal",
                positionType: .gridPosition(.bottomHalf),
                windowFilter: .allWindows
            ),
            AppPositioningRule(
                appName: "iTerm",
                bundleIdentifier: "com.googlecode.iterm2",
                positionType: .gridPosition(.bottomHalf),
                windowFilter: .allWindows
            ),
            AppPositioningRule(
                appName: "Visual Studio Code",
                bundleIdentifier: "com.microsoft.VSCode",
                positionType: .gridPosition(.leftTwoThirds),
                windowFilter: .allWindows
            ),
            AppPositioningRule(
                appName: "Xcode",
                bundleIdentifier: "com.apple.dt.Xcode",
                positionType: .maximize,
                windowFilter: .allWindows
            ),

            // Browsers
            AppPositioningRule(
                appName: "Safari",
                bundleIdentifier: "com.apple.Safari",
                positionType: .maximize,
                windowFilter: .firstWindowOnly
            ),
            AppPositioningRule(
                appName: "Google Chrome",
                bundleIdentifier: "com.google.Chrome",
                positionType: .maximize,
                windowFilter: .firstWindowOnly
            ),

            // Communication
            AppPositioningRule(
                appName: "Slack",
                bundleIdentifier: "com.tinyspeck.slackmacgap",
                positionType: .gridPosition(.rightThird),
                windowFilter: .allWindows
            ),
            AppPositioningRule(
                appName: "Mail",
                bundleIdentifier: "com.apple.mail",
                positionType: .gridPosition(.leftHalf),
                windowFilter: .allWindows
            ),

            // Music & Media
            AppPositioningRule(
                appName: "Music",
                bundleIdentifier: "com.apple.Music",
                positionType: .gridPosition(.topRight),
                windowFilter: .allWindows
            ),
            AppPositioningRule(
                appName: "Spotify",
                bundleIdentifier: "com.spotify.client",
                positionType: .gridPosition(.topRight),
                windowFilter: .allWindows
            )
        ]
    }
}
