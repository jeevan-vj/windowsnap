import Foundation
@testable import WindowSnap
import XCTest

final class ClipboardManagerSortingTests: XCTestCase {
    private func makeItem(
        content: String,
        isPinned: Bool,
        timestamp: Date
    ) -> ClipboardHistoryItem {
        ClipboardHistoryItem(
            id: UUID(),
            content: content,
            type: .text,
            timestamp: timestamp,
            preview: content,
            isPinned: isPinned
        )
    }

    func testSortHistoryPinnedBeforeUnpinned() {
        let older = Date(timeIntervalSinceNow: -3600)
        let newer = Date()
        let items = [
            makeItem(content: "recent unpinned", isPinned: false, timestamp: newer),
            makeItem(content: "recent pinned", isPinned: true, timestamp: newer),
            makeItem(content: "old pinned", isPinned: true, timestamp: older),
        ]

        let sorted = ClipboardManager.sortHistory(items)
        XCTAssertEqual(sorted.map(\.content), ["recent pinned", "old pinned", "recent unpinned"])
    }
}
