import Foundation
@testable import WindowSnap
import XCTest

final class CompletionSlotTests: XCTestCase {
    func testTakeReturnsCompletionAndClearsSlot() {
        var calls: [[String: String]?] = []
        var slot: (([String: String]?) -> Void)? = { calls.append($0) }

        let first = CompletionSlot.take(&slot)
        XCTAssertNil(slot)
        first?(["Name": "Ada"])

        let second = CompletionSlot.take(&slot)
        second?(nil)

        XCTAssertNil(second)
        XCTAssertEqual(calls.count, 1)
        XCTAssertEqual(calls.first, ["Name": "Ada"])
    }

    func testWindowCloseAfterInsertDoesNotCancel() {
        var results: [[String: String]?] = []
        var completion: (([String: String]?) -> Void)? = { results.append($0) }

        let insert = CompletionSlot.take(&completion)
        insert?(["Topic": "Review"])

        let close = CompletionSlot.take(&completion)
        close?(nil)

        XCTAssertEqual(results, [["Topic": "Review"]])
    }
}
