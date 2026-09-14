import CoreGraphics
import Foundation

/// Geometry helpers for the virtual-screen preview and cursor teleport.
enum VirtualDisplayGeometry {
    /// Returns whether a global AppKit point lies inside the virtual screen frame.
    static func containsCursor(_ point: CGPoint, in screenFrame: CGRect) -> Bool {
        screenFrame.contains(point)
    }

    /// Maps a click in the preview (AppKit, bottom-left) to `CGDisplayMoveCursorToPoint` local coordinates (top-left).
    static func displayPoint(
        fromPreviewLocation location: CGPoint,
        previewBounds: CGRect,
        displaySize: CGSize
    ) -> CGPoint {
        guard previewBounds.width > 0, previewBounds.height > 0 else { return .zero }
        let normalizedX = location.x / previewBounds.width
        let normalizedY = (previewBounds.height - location.y) / previewBounds.height
        return CGPoint(
            x: normalizedX * displaySize.width,
            y: normalizedY * displaySize.height
        )
    }

    /// Picks the first host screen frame that is not the virtual display.
    static func hostScreenFrame(from screens: [CGRect], excluding excluded: CGRect) -> CGRect? {
        screens.first { !$0.equalTo(excluded) } ?? screens.first
    }
}
