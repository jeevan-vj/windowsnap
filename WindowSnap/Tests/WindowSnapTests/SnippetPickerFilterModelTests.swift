import Foundation
@testable import WindowSnap
import XCTest

final class SnippetPickerFilterModelTests: XCTestCase {
    private func makeSnippet(
        trigger: String,
        replacement: String,
        groupName: String? = nil,
        isEnabled: Bool = true
    ) -> TextExpansionSnippet {
        TextExpansionSnippet(
            trigger: trigger,
            replacement: replacement,
            isEnabled: isEnabled,
            groupName: groupName
        )
    }

    func testFilterBySearchTextMatchesTriggerAndReplacement() {
        let snippets = [
            makeSnippet(trigger: ":email", replacement: "test@example.com"),
            makeSnippet(trigger: ":phone", replacement: "+1 555"),
        ]

        let filtered = SnippetPickerFilterModel.filter(
            snippets: snippets,
            searchText: "email",
            activeGroup: nil
        )

        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.trigger, ":email")
    }

    func testFilterByGroup() {
        let snippets = [
            makeSnippet(trigger: ":a", replacement: "A", groupName: "Work"),
            makeSnippet(trigger: ":b", replacement: "B", groupName: "Personal"),
        ]

        let filtered = SnippetPickerFilterModel.filter(
            snippets: snippets,
            searchText: "",
            activeGroup: "Work"
        )

        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.groupName, "Work")
    }

    func testBuildDisplayItemsCreatesGroupHeaders() {
        let snippets = [
            makeSnippet(trigger: ":a", replacement: "A", groupName: "Work"),
            makeSnippet(trigger: ":b", replacement: "B", groupName: "Personal"),
        ]

        let filtered = SnippetPickerFilterModel.filter(
            snippets: snippets,
            searchText: "",
            activeGroup: nil
        )
        let displayItems = SnippetPickerFilterModel.buildDisplayItems(from: filtered)

        XCTAssertEqual(displayItems.count, 4)
        if case .header(let title) = displayItems[0] {
            XCTAssertEqual(title, "Personal")
        } else {
            XCTFail("Expected header")
        }
    }

    func testNextSelectableRowSkipsHeaders() {
        let displayItems: [SnippetPickerSectionItem] = [
            .header("Work"),
            .item(makeSnippet(trigger: ":a", replacement: "A")),
            .header("Personal"),
            .item(makeSnippet(trigger: ":b", replacement: "B")),
        ]

        XCTAssertEqual(
            SnippetPickerFilterModel.nextSelectableRow(after: 0, direction: 1, in: displayItems),
            1
        )
        XCTAssertEqual(
            SnippetPickerFilterModel.nextSelectableRow(after: 1, direction: 1, in: displayItems),
            3
        )
    }

    func testFirstSelectableRowSkipsHeader() {
        let displayItems: [SnippetPickerSectionItem] = [
            .header("Work"),
            .item(makeSnippet(trigger: ":a", replacement: "A")),
        ]

        XCTAssertEqual(SnippetPickerFilterModel.firstSelectableRow(in: displayItems), 1)
    }
}
