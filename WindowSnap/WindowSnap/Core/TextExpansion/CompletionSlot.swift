import Foundation

/// Takes a stored completion, clears the slot, and returns it so the caller
/// can invoke it after side effects such as closing a window.
enum CompletionSlot {
    static func take<Value>(_ slot: inout ((Value) -> Void)?) -> ((Value) -> Void)? {
        let completion = slot
        slot = nil
        return completion
    }
}
