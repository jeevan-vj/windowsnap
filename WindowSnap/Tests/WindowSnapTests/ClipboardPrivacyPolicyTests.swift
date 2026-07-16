import AppKit
import Foundation
@testable import WindowSnap
import XCTest

final class ClipboardPrivacyPolicyTests: XCTestCase {
    func testRetentionOptionsIncludeSessionOneSevenAndThirtyDays() {
        XCTAssertEqual(
            Set(ClipboardHistoryRetention.allCases),
            Set([.sessionOnly, .oneDay, .sevenDays, .thirtyDays])
        )
    }

    func testRetentionDeletesExpiredUnpinnedItemsButKeepsPinnedItems() {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let recent = makeItem(content: "recent", timestamp: now.addingTimeInterval(-3600), isPinned: false)
        let expired = makeItem(content: "expired", timestamp: now.addingTimeInterval(-8 * 86_400), isPinned: false)
        let pinned = makeItem(content: "pinned", timestamp: now.addingTimeInterval(-60 * 86_400), isPinned: true)

        let retained = ClipboardHistoryPrivacyPolicy.retainedItems(
            [recent, expired, pinned],
            retention: .sevenDays,
            now: now
        )

        XCTAssertEqual(Set(retained.map(\.content)), Set(["recent", "pinned"]))
    }

    func testSessionOnlyKeepsCurrentSessionItemsInMemory() {
        let items = [makeItem(content: "current", timestamp: .distantPast, isPinned: false)]
        XCTAssertEqual(
            ClipboardHistoryPrivacyPolicy.retainedItems(items, retention: .sessionOnly, now: Date()).count,
            1
        )
        XCTAssertFalse(ClipboardHistoryRetention.sessionOnly.persistsToDisk)
    }

    func testTransientAndConcealedPasteboardsAreNeverCaptured() {
        XCTAssertFalse(ClipboardHistoryPrivacyPolicy.shouldCapture(types: [
            NSPasteboard.PasteboardType("org.nspasteboard.TransientType"),
            .string,
        ]))
        XCTAssertFalse(ClipboardHistoryPrivacyPolicy.shouldCapture(types: [
            NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"),
            .string,
        ]))
        XCTAssertTrue(ClipboardHistoryPrivacyPolicy.shouldCapture(types: [.string]))
    }

    func testSensitiveFilteringIsAlwaysEnabledWithoutPreference() {
        XCTAssertTrue(ClipboardHistoryPrivacyPolicy.containsSensitiveData("password=correct-horse-battery"))
        XCTAssertTrue(ClipboardHistoryPrivacyPolicy.containsSensitiveData("ghp_abcdefghijklmnopqrstuvwxyz0123456789"))
        XCTAssertFalse(ClipboardHistoryPrivacyPolicy.containsSensitiveData("ordinary clipboard text"))
    }

    func testLogSummaryNeverContainsClipboardContentOrPreview() {
        let secret = "https://private.example/secret-token"
        let item = makeItem(content: secret, timestamp: Date(), isPinned: false)

        let summary = ClipboardLogMetadata.summary(for: item)

        XCTAssertFalse(summary.contains(secret))
        XCTAssertFalse(summary.contains(item.preview))
        XCTAssertTrue(summary.contains("URL") || summary.contains("Text"))
    }

    private func makeItem(content: String, timestamp: Date, isPinned: Bool) -> ClipboardHistoryItem {
        ClipboardHistoryItem(
            id: UUID(),
            content: content,
            type: content.hasPrefix("http") ? .url : .text,
            timestamp: timestamp,
            preview: content,
            isPinned: isPinned
        )
    }
}
