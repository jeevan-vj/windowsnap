import CoreGraphics
import Foundation

/// Creates and releases a single OS-level virtual display.
protocol VirtualDisplayCreating: AnyObject {
    var isAvailable: Bool { get }
    var isConnected: Bool { get }
    var displayID: CGDirectDisplayID? { get }
    func connect(presets: [VirtualDisplayPreset]) throws -> CGDirectDisplayID
    func disconnect()
}
