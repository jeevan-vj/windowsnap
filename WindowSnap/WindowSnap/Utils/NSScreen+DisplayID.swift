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

    /// Stable hardware UUID used to reconnect workspace layouts after display reordering.
    var displayUUID: String? {
        guard let displayID,
              let uuid = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue() else {
            return nil
        }
        return CFUUIDCreateString(nil, uuid) as String
    }
}
