import Foundation
@testable import WindowSnap
import XCTest

final class ClipboardHistoryItemTests: XCTestCase {
    func testTextPreviewTruncatesAt100Characters() {
        let longText = String(repeating: "a", count: 120)
        let preview = ClipboardHistoryItem.makePreview(from: longText, type: .text)
        XCTAssertTrue(preview.hasSuffix("..."))
        XCTAssertEqual(preview.count, 103)
    }

    func testTextPreviewNormalizesWhitespace() {
        let preview = ClipboardHistoryItem.makePreview(from: "line one\nline two", type: .text)
        XCTAssertEqual(preview, "line one line two")
    }

    func testURLPreviewReturnsFullContent() {
        let url = "https://example.com/path"
        let preview = ClipboardHistoryItem.makePreview(from: url, type: .url)
        XCTAssertEqual(preview, url)
    }

    func testRichTextPreviewStripsMarkup() {
        let preview = ClipboardHistoryItem.makePreview(from: "<b>Hello</b> world", type: .richText)
        XCTAssertEqual(preview, "Hello world")
    }

    func testImagePreviewPlaceholder() {
        let preview = ClipboardHistoryItem.makePreview(from: "base64data", type: .image)
        XCTAssertEqual(preview, "[Image]")
    }

    func testFilePreviewUsesLastPathComponent() {
        let preview = ClipboardHistoryItem.makePreview(
            from: "file:///Users/test/Documents/report.pdf",
            type: .file
        )
        XCTAssertEqual(preview, "[File: report.pdf]")
    }

    func testInitSetsPreviewFromContent() {
        let item = ClipboardHistoryItem(content: "short text", type: .text)
        XCTAssertEqual(item.preview, "short text")
        XCTAssertFalse(item.isPinned)
    }
}
