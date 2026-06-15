import Foundation
@testable import WindowSnap
import XCTest

final class ClipboardHistoryFilterModelTests: XCTestCase {
    private func makeItem(
        content: String,
        type: ClipboardItemType = .text,
        isPinned: Bool = false,
        timestamp: Date = Date()
    ) -> ClipboardHistoryItem {
        ClipboardHistoryItem(
            id: UUID(),
            content: content,
            type: type,
            timestamp: timestamp,
            preview: ClipboardHistoryItem.makePreview(from: content, type: type),
            isPinned: isPinned
        )
    }

    func testFilterBySearchTextMatchesPreviewAndContent() {
        let history = [
            makeItem(content: "hello world"),
            makeItem(content: "other value"),
        ]

        let filtered = ClipboardHistoryFilterModel.filter(
            history: history,
            searchText: "hello",
            activeTypeFilters: []
        )

        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.content, "hello world")
    }

    func testFilterByTypeChip() {
        let history = [
            makeItem(content: "https://example.com", type: .url),
            makeItem(content: "plain text", type: .text),
        ]

        let filtered = ClipboardHistoryFilterModel.filter(
            history: history,
            searchText: "",
            activeTypeFilters: [.url]
        )

        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.type, .url)
    }

    func testFilterCombinesSearchAndTypeFilters() {
        let history = [
            makeItem(content: "https://example.com", type: .url),
            makeItem(content: "https://other.com", type: .url),
            makeItem(content: "example text", type: .text),
        ]

        let filtered = ClipboardHistoryFilterModel.filter(
            history: history,
            searchText: "example",
            activeTypeFilters: [.url]
        )

        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.content, "https://example.com")
    }

    func testBuildDisplayItemsCreatesPinnedAndRecentSections() {
        let older = Date(timeIntervalSinceNow: -3600)
        let newer = Date()
        let history = [
            makeItem(content: "pinned", isPinned: true, timestamp: newer),
            makeItem(content: "recent", isPinned: false, timestamp: newer),
            makeItem(content: "older recent", isPinned: false, timestamp: older),
        ]

        let filtered = ClipboardHistoryFilterModel.filter(
            history: history,
            searchText: "",
            activeTypeFilters: []
        )
        let displayItems = ClipboardHistoryFilterModel.buildDisplayItems(from: filtered)

        XCTAssertEqual(displayItems.count, 5)
        if case .header(let pinnedTitle) = displayItems[0] {
            XCTAssertEqual(pinnedTitle, "Pinned")
        } else {
            XCTFail("Expected pinned header")
        }
        if case .header(let recentTitle) = displayItems[2] {
            XCTAssertEqual(recentTitle, "Recent")
        } else {
            XCTFail("Expected recent header")
        }
    }

    func testNextSelectableRowSkipsHeaders() {
        let displayItems: [ClipboardHistorySectionItem] = [
            .header("Pinned"),
            .item(makeItem(content: "one", isPinned: true)),
            .header("Recent"),
            .item(makeItem(content: "two")),
        ]

        XCTAssertEqual(
            ClipboardHistoryFilterModel.nextSelectableRow(after: 0, direction: 1, in: displayItems),
            1
        )
        XCTAssertEqual(
            ClipboardHistoryFilterModel.nextSelectableRow(after: 1, direction: 1, in: displayItems),
            3
        )
        XCTAssertEqual(
            ClipboardHistoryFilterModel.nextSelectableRow(after: 3, direction: -1, in: displayItems),
            1
        )
    }

    func testFirstSelectableRowSkipsHeader() {
        let displayItems: [ClipboardHistorySectionItem] = [
            .header("Recent"),
            .item(makeItem(content: "one")),
        ]

        XCTAssertEqual(ClipboardHistoryFilterModel.firstSelectableRow(in: displayItems), 1)
    }

    func testItemCountLabelWhenNotFiltering() {
        let label = ClipboardHistoryFilterModel.itemCountLabel(
            filteredCount: 3,
            totalCount: 10,
            isSearching: false,
            activeFilterNames: []
        )
        XCTAssertEqual(label, "10 items")
    }

    func testItemCountLabelWhenFiltering() {
        let label = ClipboardHistoryFilterModel.itemCountLabel(
            filteredCount: 2,
            totalCount: 10,
            isSearching: true,
            activeFilterNames: ["Text", "URL"]
        )
        XCTAssertEqual(label, "2 of 10 \u{2022} Text, URL")
    }

    func testSortPinnedFirstOrdersByTimestampWithinGroups() {
        let older = Date(timeIntervalSinceNow: -7200)
        let newer = Date()
        let items = [
            makeItem(content: "old unpinned", isPinned: false, timestamp: older),
            makeItem(content: "new pinned", isPinned: true, timestamp: newer),
            makeItem(content: "old pinned", isPinned: true, timestamp: older),
        ]

        let sorted = ClipboardHistoryFilterModel.sortPinnedFirst(items)
        XCTAssertEqual(sorted.map(\.content), ["new pinned", "old pinned", "old unpinned"])
    }
}
