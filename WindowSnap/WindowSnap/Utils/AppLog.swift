import Foundation
import os

enum AppLog {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.windowsnap"

    static let textExpansion = Logger(subsystem: subsystem, category: "TextExpansion")
    static let permissions = Logger(subsystem: subsystem, category: "Permissions")
}
