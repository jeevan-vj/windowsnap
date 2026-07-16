import Foundation
@testable import WindowSnap
import XCTest

final class ClipboardHistoryPresentationCacheTests: XCTestCase {
    func testClearNotificationPurgesAllCachedHistoryArraysImmediately() {
        let center = NotificationCenter()
        let item = ClipboardHistoryItem(content: "sensitive cached value", type: .text)
        let cache = ClipboardHistoryPresentationCache(notificationCenter: center)
        cache.history = [item]
        cache.filteredHistory = [item]
        cache.displayItems = [.item(item)]
        cache.selectedIndex = 2
        cache.lastHistoryCount = 1

        center.post(name: .clipboardHistoryDidClear, object: nil)

        XCTAssertTrue(cache.history.isEmpty)
        XCTAssertTrue(cache.filteredHistory.isEmpty)
        XCTAssertTrue(cache.displayItems.isEmpty)
        XCTAssertEqual(cache.selectedIndex, 0)
        XCTAssertEqual(cache.lastHistoryCount, 0)
    }

    func testClearNotificationInvokesWindowRefreshCallbackAfterPurge() {
        let center = NotificationCenter()
        let cache = ClipboardHistoryPresentationCache(notificationCenter: center)
        cache.history = [ClipboardHistoryItem(content: "cached", type: .text)]
        var callbackSawEmptyState = false
        cache.onPurge = { callbackSawEmptyState = cache.history.isEmpty }

        center.post(name: .clipboardHistoryDidClear, object: nil)

        XCTAssertTrue(callbackSawEmptyState)
    }
}
