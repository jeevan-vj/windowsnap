import AppKit
import Foundation

extension Notification.Name {
    static let toggleClipboardHistory = Notification.Name("toggleClipboardHistory")
}

/// Owns the single clipboard-history window used by the menu and the global shortcut.
final class ClipboardHistoryPresenter {
    static let shared = ClipboardHistoryPresenter()

    private var window: ClipboardHistoryWindow?

    private init() {}

    func toggle() {
        if window == nil {
            window = ClipboardHistoryWindow()
        }

        if window?.isVisible == true {
            window?.requestClose()
        } else {
            window?.showWindow()
        }
    }
}
