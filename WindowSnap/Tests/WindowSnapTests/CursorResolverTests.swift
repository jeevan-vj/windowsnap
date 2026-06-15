import Foundation
@testable import WindowSnap
import XCTest

final class CursorResolverTests: XCTestCase {
    func testNoCursorTokenReturnsOriginalTextAndNilCount() {
        let result = CursorResolver.resolve("hello world")
        XCTAssertEqual(result.text, "hello world")
        XCTAssertNil(result.leftArrowCount)
    }

    func testCursorAtEndReturnsZeroLeftArrows() {
        let result = CursorResolver.resolve("hello{cursor}")
        XCTAssertEqual(result.text, "hello")
        XCTAssertEqual(result.leftArrowCount, 0)
    }

    func testCursorInMiddleCountsCharactersAfterToken() {
        let result = CursorResolver.resolve("a{cursor}bc")
        XCTAssertEqual(result.text, "abc")
        XCTAssertEqual(result.leftArrowCount, 2)
    }

    func testMultipleCursorTokensOnlyFirstHonoredRestStripped() {
        let result = CursorResolver.resolve("a{cursor}b{cursor}c")
        XCTAssertEqual(result.text, "abc")
        XCTAssertEqual(result.leftArrowCount, 2)
    }

    func testEmojiAfterCursorCountedAsSingleCharacter() {
        let result = CursorResolver.resolve("{cursor}🎉ab")
        XCTAssertEqual(result.text, "🎉ab")
        XCTAssertEqual(result.leftArrowCount, 3)
    }
}
