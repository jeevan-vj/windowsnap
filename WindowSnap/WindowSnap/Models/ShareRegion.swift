import Foundation
import CoreGraphics

struct ShareRegion: Codable, Equatable {
    let id: UUID
    let displayID: CGDirectDisplayID
    var normalizedRect: CGRect
    var lastMirrorWindowFrame: CGRect?
    let createdDate: Date
    
    init(displayID: CGDirectDisplayID, normalizedRect: CGRect) {
        self.id = UUID()
        self.displayID = displayID
        self.normalizedRect = normalizedRect
        self.lastMirrorWindowFrame = nil
        self.createdDate = Date()
    }
    
    func absoluteRect(for displayBounds: CGRect) -> CGRect {
        return CGRect(
            x: displayBounds.origin.x + normalizedRect.origin.x * displayBounds.width,
            y: displayBounds.origin.y + normalizedRect.origin.y * displayBounds.height,
            width: normalizedRect.width * displayBounds.width,
            height: normalizedRect.height * displayBounds.height
        )
    }
    
    static func normalizedRect(from absoluteRect: CGRect, in displayBounds: CGRect) -> CGRect {
        guard displayBounds.width > 0, displayBounds.height > 0 else { return .zero }
        return CGRect(
            x: (absoluteRect.origin.x - displayBounds.origin.x) / displayBounds.width,
            y: (absoluteRect.origin.y - displayBounds.origin.y) / displayBounds.height,
            width: absoluteRect.width / displayBounds.width,
            height: absoluteRect.height / displayBounds.height
        )
    }

    /// Maps an overlay-view rect (AppKit, bottom-left, overlay points) into
    /// `CGDisplayBounds` space, scaling both axes when the two frames differ.
    static func captureRect(
        fromViewRect viewRect: CGRect,
        overlayFrame: CGRect,
        displayBounds: CGRect
    ) -> CGRect {
        guard overlayFrame.width > 0, overlayFrame.height > 0 else { return .zero }
        let scaleX = displayBounds.width / overlayFrame.width
        let scaleY = displayBounds.height / overlayFrame.height
        return CGRect(
            x: displayBounds.origin.x + viewRect.origin.x * scaleX,
            y: displayBounds.origin.y + viewRect.origin.y * scaleY,
            width: viewRect.width * scaleX,
            height: viewRect.height * scaleY
        )
    }
    
    func withUpdatedMirrorFrame(_ frame: CGRect) -> ShareRegion {
        var copy = self
        copy.lastMirrorWindowFrame = frame
        return copy
    }
}
