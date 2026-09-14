import CVirtualDisplay
import CoreGraphics
import Foundation

/// Isolated wrapper around the private `CGVirtualDisplay` SPI.
final class VirtualDisplayAdapter: VirtualDisplayCreating {
    static let displayName = "WindowSnap Display"
    static let vendorID: UInt32 = 0x5753
    static let productID: UInt32 = 0x5653
    static let serialNumber: UInt32 = 0x0001

    private let queue = DispatchQueue(label: "com.windowsnap.virtual-display")
    private var display: CGVirtualDisplay?

    var isAvailable: Bool {
        NSClassFromString("CGVirtualDisplay") != nil
            && NSClassFromString("CGVirtualDisplayDescriptor") != nil
            && NSClassFromString("CGVirtualDisplaySettings") != nil
            && NSClassFromString("CGVirtualDisplayMode") != nil
    }

    var isConnected: Bool { display != nil }

    var displayID: CGDirectDisplayID? {
        guard let display else { return nil }
        let identifier = display.displayID
        return identifier == 0 ? nil : identifier
    }

    func connect(presets: [VirtualDisplayPreset]) throws -> CGDirectDisplayID {
        guard isAvailable else { throw VirtualDisplayError.unavailable }
        guard display == nil else { throw VirtualDisplayError.alreadyConnected }

        let descriptor = CGVirtualDisplayDescriptor()
        descriptor.setDispatchQueue(queue)
        descriptor.name = Self.displayName
        let maxSize = VirtualDisplayPreset.maximumPixelSize(in: presets)
        descriptor.maxPixelsWide = UInt32(maxSize.width)
        descriptor.maxPixelsHigh = UInt32(maxSize.height)
        descriptor.sizeInMillimeters = CGSize(width: 1600, height: 1000)
        descriptor.productID = Self.productID
        descriptor.vendorID = Self.vendorID
        descriptor.serialNum = Self.serialNumber

        let created = CGVirtualDisplay(descriptor: descriptor)
        let settings = CGVirtualDisplaySettings()
        settings.hiDPI = 1
        settings.modes = presets.map { preset in
            CGVirtualDisplayMode(
                width: preset.width,
                height: preset.height,
                refreshRate: preset.refreshRate
            )
        }

        guard created.apply(settings) else {
            throw VirtualDisplayError.applySettingsFailed
        }

        let identifier = created.displayID
        guard identifier != 0 else {
            throw VirtualDisplayError.creationFailed
        }

        display = created
        return identifier
    }

    func disconnect() {
        display = nil
    }
}
