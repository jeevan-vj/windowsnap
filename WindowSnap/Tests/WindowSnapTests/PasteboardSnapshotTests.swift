import AppKit
@testable import WindowSnap
import XCTest

final class PasteboardSnapshotTests: XCTestCase {
    private var pasteboard: NSPasteboard!

    override func setUp() {
        super.setUp()
        pasteboard = NSPasteboard.withUniqueName()
    }

    override func tearDown() {
        pasteboard.clearContents()
        pasteboard = nil
        super.tearDown()
    }

    func testRoundTripPreservesSeparateItems() {
        let first = NSPasteboardItem()
        first.setString("one", forType: .string)
        let second = NSPasteboardItem()
        second.setString("two", forType: .string)
        pasteboard.clearContents()
        XCTAssertTrue(pasteboard.writeObjects([first, second]))

        let snapshot = PasteboardSnapshot.capture(pasteboard)
        XCTAssertEqual(snapshot.items.count, 2)

        pasteboard.clearContents()
        pasteboard.setString("expansion", forType: .string)
        let changeCount = pasteboard.changeCount

        XCTAssertTrue(snapshot.restore(to: pasteboard, ifChangeCountIs: changeCount))
        XCTAssertEqual(pasteboard.pasteboardItems?.count, 2)
        XCTAssertEqual(pasteboard.pasteboardItems?.first?.string(forType: .string), "one")
        XCTAssertEqual(pasteboard.pasteboardItems?.last?.string(forType: .string), "two")
    }

    func testRestoreSkipsWhenChangeCountDiffers() {
        pasteboard.clearContents()
        pasteboard.setString("original", forType: .string)
        let snapshot = PasteboardSnapshot.capture(pasteboard)

        pasteboard.clearContents()
        pasteboard.setString("user copy", forType: .string)

        XCTAssertFalse(snapshot.restore(to: pasteboard, ifChangeCountIs: pasteboard.changeCount - 1))
        XCTAssertEqual(pasteboard.string(forType: .string), "user copy")
    }
}
