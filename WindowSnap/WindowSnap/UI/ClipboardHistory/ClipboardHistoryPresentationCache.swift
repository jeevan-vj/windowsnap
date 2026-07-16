import Foundation

/// Owns all clipboard payload arrays cached by the history window and purges
/// them synchronously when Clear All is broadcast.
final class ClipboardHistoryPresentationCache {
    var history: [ClipboardHistoryItem] = []
    var filteredHistory: [ClipboardHistoryItem] = []
    var displayItems: [ClipboardHistorySectionItem] = []
    var selectedIndex = 0
    var lastHistoryCount = 0
    var onPurge: (() -> Void)?

    private let notificationCenter: NotificationCenter
    private var clearToken: NSObjectProtocol?

    init(notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter
        clearToken = notificationCenter.addObserver(
            forName: .clipboardHistoryDidClear,
            object: nil,
            queue: nil
        ) { [weak self] _ in
            self?.purge()
        }
    }

    deinit {
        if let clearToken { notificationCenter.removeObserver(clearToken) }
    }

    private func purge() {
        history.removeAll(keepingCapacity: false)
        filteredHistory.removeAll(keepingCapacity: false)
        displayItems.removeAll(keepingCapacity: false)
        selectedIndex = 0
        lastHistoryCount = 0
        onPurge?()
    }
}
