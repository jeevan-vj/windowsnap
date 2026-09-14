import CoreGraphics
import Foundation

/// Advertised resolution for a WindowSnap virtual screen.
struct VirtualDisplayPreset: Equatable, Hashable {
    let name: String
    let width: UInt
    let height: UInt
    let refreshRate: Double

    static let all: [VirtualDisplayPreset] = [
        VirtualDisplayPreset(name: "1280×800", width: 1280, height: 800, refreshRate: 60),
        VirtualDisplayPreset(name: "1080p", width: 1920, height: 1080, refreshRate: 60),
        VirtualDisplayPreset(name: "1920×1200", width: 1920, height: 1200, refreshRate: 60),
        VirtualDisplayPreset(name: "1440p", width: 2560, height: 1440, refreshRate: 60),
        VirtualDisplayPreset(name: "2560×1600", width: 2560, height: 1600, refreshRate: 60),
        VirtualDisplayPreset(name: "Ultrawide", width: 3440, height: 1440, refreshRate: 60),
        VirtualDisplayPreset(name: "4K", width: 3840, height: 2160, refreshRate: 60),
        VirtualDisplayPreset(name: "Super Ultrawide", width: 5120, height: 1440, refreshRate: 60)
    ]

    /// Pixel cap advertised to `CGVirtualDisplayDescriptor`. Must cover every preset.
    static let maximumPixelSize = CGSize(width: 5120, height: 2160)

    static func maximumPixelSize(in presets: [VirtualDisplayPreset]) -> CGSize {
        let width = presets.map(\.width).max() ?? UInt(maximumPixelSize.width)
        let height = presets.map(\.height).max() ?? UInt(maximumPixelSize.height)
        return CGSize(
            width: max(CGFloat(width), maximumPixelSize.width),
            height: max(CGFloat(height), maximumPixelSize.height)
        )
    }
}
