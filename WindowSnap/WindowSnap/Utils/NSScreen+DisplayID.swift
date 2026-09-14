import AppKit
import CoreGraphics

extension NSScreen {
    /// Quartz display identifier for this screen, if AppKit exposes one.
    var displayID: CGDirectDisplayID? {
        guard let number = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return nil
        }
        return number.uint32Value
    }
}
