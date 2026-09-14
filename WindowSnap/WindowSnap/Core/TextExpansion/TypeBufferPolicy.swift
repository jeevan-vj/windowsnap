import Carbon
import CoreGraphics
import Foundation

/// Rules for when the text-expander type buffer should ignore or discard input.
enum TypeBufferPolicy {
    static func shouldIgnoreSecureInput(_ isSecureEventInputEnabled: Bool) -> Bool {
        isSecureEventInputEnabled
    }

    static func shouldClear(forEventType type: CGEventType) -> Bool {
        type == .leftMouseDown
    }

    static func shouldClear(forKeyCode keyCode: Int64) -> Bool {
        switch keyCode {
        case Int64(kVK_LeftArrow),
             Int64(kVK_RightArrow),
             Int64(kVK_UpArrow),
             Int64(kVK_DownArrow),
             Int64(kVK_Home),
             Int64(kVK_End),
             Int64(kVK_PageUp),
             Int64(kVK_PageDown),
             Int64(kVK_ForwardDelete),
             Int64(kVK_Escape),
             Int64(kVK_Return),
             Int64(kVK_ANSI_KeypadEnter):
            return true
        default:
            return false
        }
    }
}
