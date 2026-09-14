import AppKit
@testable import WindowSnap
import XCTest

final class FillInFormControllerTests: XCTestCase {
    func testInsertFiresValuesOnceAndCloseDoesNotCancel() {
        let parsed = SnippetParser.parse("Hi {field:Name:Ada}")
        var results: [[String: String]?] = []
        let controller = FillInFormController(parsed: parsed) { results.append($0) }

        controller.insertTapped()
        controller.close()

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first, ["Name": "Ada"])
    }

    func testCancelFiresNilOnce() {
        let parsed = SnippetParser.parse("Hi {field:Name}")
        var results: [[String: String]?] = []
        let controller = FillInFormController(parsed: parsed) { results.append($0) }

        controller.cancelTapped()

        XCTAssertEqual(results.count, 1)
        XCTAssertNil(results[0])
    }
}
