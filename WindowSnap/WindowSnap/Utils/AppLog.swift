import Foundation
import os

enum AppLog {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.windowsnap"

    static let app = Logger(subsystem: subsystem, category: "Application")
    static let accessibility = Logger(subsystem: subsystem, category: "Accessibility")
    static let shortcuts = Logger(subsystem: subsystem, category: "Shortcuts")
    static let windowManagement = Logger(subsystem: subsystem, category: "WindowManagement")
    static let workspace = Logger(subsystem: subsystem, category: "Workspace")
    static let regionShare = Logger(subsystem: subsystem, category: "RegionShare")
    static let updates = Logger(subsystem: subsystem, category: "Updates")
    static let textExpansion = Logger(subsystem: subsystem, category: "TextExpansion")
    static let permissions = Logger(subsystem: subsystem, category: "Permissions")
    static let virtualDisplay = Logger(subsystem: subsystem, category: "VirtualDisplay")
}
