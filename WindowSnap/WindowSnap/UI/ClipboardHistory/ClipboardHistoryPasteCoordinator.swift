import AppKit
import Foundation

enum ClipboardHistoryPasteCoordinator {
    static func copyAndPaste(
        item: ClipboardHistoryItem,
        previousApp: NSRunningApplication?
    ) {
        ClipboardManager.shared.copyToClipboard(item)

        let pasteboard = NSPasteboard.general
        let initialChangeCount = pasteboard.changeCount
        var attempts = 0
        let maxAttempts = 3

        func verifyAndPaste() {
            attempts += 1
            if pasteboard.changeCount != initialChangeCount {
                performPasteSequence(previousApp: previousApp)
            } else if attempts < maxAttempts {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { verifyAndPaste() }
            } else {
                performPasteSequence(previousApp: previousApp)
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { verifyAndPaste() }
    }

    private static func performPasteSequence(previousApp: NSRunningApplication?) {
        if let app = previousApp {
            app.activate(options: .activateIgnoringOtherApps)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { simulatePaste() }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { simulatePaste() }
        }
    }

    static func simulatePaste() {
        let source = CGEventSource(stateID: .hidSystemState)
        if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) {
            keyDown.flags = .maskCommand
            keyDown.post(tap: .cghidEventTap)
        }
        if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false) {
            keyUp.flags = .maskCommand
            keyUp.post(tap: .cghidEventTap)
        }
    }
}
