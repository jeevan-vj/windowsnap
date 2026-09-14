import Carbon
import CoreGraphics
@testable import WindowSnap
import XCTest

final class TypeBufferPolicyTests: XCTestCase {
    func testSecureInputIsIgnored() {
        XCTAssertTrue(TypeBufferPolicy.shouldIgnoreSecureInput(true))
        XCTAssertFalse(TypeBufferPolicy.shouldIgnoreSecureInput(false))
    }

    func testMouseDownClearsBuffer() {
        XCTAssertTrue(TypeBufferPolicy.shouldClear(forEventType: .leftMouseDown))
        XCTAssertFalse(TypeBufferPolicy.shouldClear(forEventType: .keyDown))
    }

    func testNavigationKeysClearBuffer() {
        XCTAssertTrue(TypeBufferPolicy.shouldClear(forKeyCode: Int64(kVK_LeftArrow)))
        XCTAssertTrue(TypeBufferPolicy.shouldClear(forKeyCode: Int64(kVK_RightArrow)))
        XCTAssertTrue(TypeBufferPolicy.shouldClear(forKeyCode: Int64(kVK_UpArrow)))
        XCTAssertTrue(TypeBufferPolicy.shouldClear(forKeyCode: Int64(kVK_DownArrow)))
        XCTAssertTrue(TypeBufferPolicy.shouldClear(forKeyCode: Int64(kVK_Home)))
        XCTAssertTrue(TypeBufferPolicy.shouldClear(forKeyCode: Int64(kVK_End)))
        XCTAssertTrue(TypeBufferPolicy.shouldClear(forKeyCode: Int64(kVK_PageUp)))
        XCTAssertTrue(TypeBufferPolicy.shouldClear(forKeyCode: Int64(kVK_PageDown)))
        XCTAssertTrue(TypeBufferPolicy.shouldClear(forKeyCode: Int64(kVK_ForwardDelete)))
        XCTAssertTrue(TypeBufferPolicy.shouldClear(forKeyCode: Int64(kVK_Escape)))
        XCTAssertTrue(TypeBufferPolicy.shouldClear(forKeyCode: Int64(kVK_Return)))
    }

    func testTypingKeysDoNotClearBuffer() {
        XCTAssertFalse(TypeBufferPolicy.shouldClear(forKeyCode: Int64(kVK_ANSI_A)))
        XCTAssertFalse(TypeBufferPolicy.shouldClear(forKeyCode: Int64(kVK_Tab)))
        XCTAssertFalse(TypeBufferPolicy.shouldClear(forKeyCode: Int64(kVK_Delete)))
    }
}
