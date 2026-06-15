import Foundation
@testable import WindowSnap
import XCTest

final class TextExpanderManagerTests: XCTestCase {
    private var defaultsSuiteName: String!
    private var userDefaults: UserDefaults!
    private var manager: TextExpanderManager!

    override func setUp() {
        super.setUp()
        defaultsSuiteName = "TextExpanderManagerTests.\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: defaultsSuiteName)!
        userDefaults.removePersistentDomain(forName: defaultsSuiteName)
        userDefaults.set(true, forKey: "WindowSnap_TextExpanderHasPopulatedDefaults")
        manager = TextExpanderManager(userDefaults: userDefaults)
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: defaultsSuiteName)
        manager = nil
        userDefaults = nil
        defaultsSuiteName = nil
        super.tearDown()
    }

    func testFindMatchingSnippetPrefersLongestTrigger() {
        XCTAssertTrue(manager.addSnippet(TextExpansionSnippet(trigger: ":ty", replacement: "Thank you")))
        XCTAssertTrue(manager.addSnippet(TextExpansionSnippet(trigger: ":tyvm", replacement: "Thank you very much")))

        let match = manager.findMatchingSnippet(for: ":tyvm")
        XCTAssertEqual(match?.trigger, ":tyvm")
    }

    func testFindMatchingSnippetRespectsWordBoundary() {
        manager.updateSettings(TextExpanderSettings(isEnabled: true, caseSensitive: true, requireWordBoundary: true))
        XCTAssertTrue(manager.addSnippet(TextExpansionSnippet(trigger: ":ty", replacement: "Thank you")))

        XCTAssertNil(manager.findMatchingSnippet(for: "party"))
        XCTAssertNotNil(manager.findMatchingSnippet(for: "say :ty"))
    }

    func testFindMatchingSnippetIsCaseInsensitiveWhenConfigured() {
        manager.updateSettings(TextExpanderSettings(isEnabled: true, caseSensitive: false, requireWordBoundary: false))
        XCTAssertTrue(manager.addSnippet(TextExpansionSnippet(trigger: ":TY", replacement: "Thank you")))

        XCTAssertNotNil(manager.findMatchingSnippet(for: ":ty"))
    }

    func testImportSkipsInvalidAndDuplicateSnippets() throws {
        let snippets = [
            TextExpansionSnippet(trigger: "x", replacement: "invalid trigger"),
            TextExpansionSnippet(trigger: ":valid", replacement: "ok"),
            TextExpansionSnippet(trigger: ":valid", replacement: "duplicate in import"),
            TextExpansionSnippet(trigger: ":empty", replacement: ""),
        ]
        let data = try JSONEncoder().encode(snippets)

        let addedCount = manager.importSnippets(from: data, merge: true)
        XCTAssertEqual(addedCount, 1)
        XCTAssertEqual(manager.getAllSnippets().map(\.trigger), [":valid"])
    }

    func testImportReplaceModeDedupesTriggers() throws {
        let snippets = [
            TextExpansionSnippet(trigger: ":a", replacement: "first"),
            TextExpansionSnippet(trigger: ":a", replacement: "second"),
            TextExpansionSnippet(trigger: ":b", replacement: "ok"),
        ]
        let data = try JSONEncoder().encode(snippets)

        let addedCount = manager.importSnippets(from: data, merge: false)
        XCTAssertEqual(addedCount, 2)
        XCTAssertEqual(Set(manager.getAllSnippets().map(\.trigger)), Set([":a", ":b"]))
    }

    func testMatchingCacheInvalidatesAfterSnippetMutation() {
        XCTAssertTrue(manager.addSnippet(TextExpansionSnippet(trigger: ":one", replacement: "one")))
        XCTAssertNotNil(manager.findMatchingSnippet(for: ":one"))

        XCTAssertTrue(manager.addSnippet(TextExpansionSnippet(trigger: ":two", replacement: "two")))
        XCTAssertNotNil(manager.findMatchingSnippet(for: ":two"))
    }
}
