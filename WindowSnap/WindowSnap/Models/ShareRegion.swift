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
        return CGRect(
            x: (absoluteRect.origin.x - displayBounds.origin.x) / displayBounds.width,
            y: (absoluteRect.origin.y - displayBounds.origin.y) / displayBounds.height,
            width: absoluteRect.width / displayBounds.width,
            height: absoluteRect.height / displayBounds.height
        )
    }
    
    func withUpdatedMirrorFrame(_ frame: CGRect) -> ShareRegion {
        var copy = self
        copy.lastMirrorWindowFrame = frame
        return copy
    }
}
