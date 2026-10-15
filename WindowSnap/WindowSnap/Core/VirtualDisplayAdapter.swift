#if !APP_STORE
import CVirtualDisplay
#endif
import CoreGraphics
import Foundation

/// Isolated wrapper around the private `CGVirtualDisplay` SPI.
final class VirtualDisplayAdapter: VirtualDisplayCreating {
    static let displayName = "WindowSnap Display"
    static let vendorID: UInt32 = 0x5753
    static let productID: UInt32 = 0x5653
    static let serialNumber: UInt32 = 0x0001

    #if !APP_STORE
    private let queue = DispatchQueue(label: "com.windowsnap.virtual-display")
    private var display: CGVirtualDisplay?
    #endif

    var isAvailable: Bool {
        #if APP_STORE
        false
        #else
        NSClassFromString("CGVirtualDisplay") != nil
            && NSClassFromString("CGVirtualDisplayDescriptor") != nil
            && NSClassFromString("CGVirtualDisplaySettings") != nil
            && NSClassFromString("CGVirtualDisplayMode") != nil
        #endif
    }

    var isConnected: Bool {
        #if APP_STORE
        false
        #else
        display != nil
        #endif
    }

    var displayID: CGDirectDisplayID? {
        #if APP_STORE
        nil
        #else
        guard let display else { return nil }
        let identifier = display.displayID
        return identifier == 0 ? nil : identifier
        #endif
    }

    func connect(presets: [VirtualDisplayPreset]) throws -> CGDirectDisplayID {
        #if APP_STORE
        throw VirtualDisplayError.unavailable
        #else
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
        #endif
    }

    func disconnect() {
        #if !APP_STORE
        display = nil
        #endif
    }
}
