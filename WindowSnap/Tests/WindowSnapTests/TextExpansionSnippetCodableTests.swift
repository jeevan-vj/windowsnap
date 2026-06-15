import Foundation
@testable import WindowSnap
import XCTest

final class TextExpansionSnippetCodableTests: XCTestCase {
    func testDecodesLegacyJSONWithoutNewFields() throws {
        let legacySnippet = TextExpansionSnippet(trigger: ":email", replacement: "test@example.com")
        let encoder = JSONEncoder()
        var legacyObject = try JSONSerialization.jsonObject(with: encoder.encode([legacySnippet])) as? [[String: Any]]
        legacyObject?[0].removeValue(forKey: "groupName")
        legacyObject?[0].removeValue(forKey: "contentType")
        legacyObject?[0].removeValue(forKey: "richData")
        let legacyData = try JSONSerialization.data(withJSONObject: legacyObject as Any)

        let snippets = try JSONDecoder().decode([TextExpansionSnippet].self, from: legacyData)

        XCTAssertEqual(snippets.count, 1)
        XCTAssertNil(snippets[0].groupName)
        XCTAssertEqual(snippets[0].contentType, .plainText)
        XCTAssertNil(snippets[0].richData)
    }

    func testRoundTripPreservesGroupAndRichData() throws {
        let snippet = TextExpansionSnippet(
            trigger: ":sig",
            replacement: "Signature",
            groupName: "Work",
            contentType: .richText,
            richData: Data("rtf".utf8)
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = try encoder.encode([snippet])
        let decoded = try decoder.decode([TextExpansionSnippet].self, from: data)

        XCTAssertEqual(decoded.first?.groupName, "Work")
        XCTAssertEqual(decoded.first?.contentType, .richText)
        XCTAssertEqual(decoded.first?.richData, Data("rtf".utf8))
    }
}

final class SnippetPasteboardWriterTests: XCTestCase {
    func testPlainTextWritesStringType() {
        let snippet = TextExpansionSnippet(trigger: ":a", replacement: "hello")
        let items = SnippetPasteboardWriter.writeItems(for: snippet)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].typeIdentifier, "public.utf8-plain-text")
        XCTAssertEqual(String(data: items[0].data, encoding: .utf8), "hello")
    }

    func testRichTextWritesRTFType() {
        let data = Data("{\\rtf1}".utf8)
        let snippet = TextExpansionSnippet(
            trigger: ":sig",
            replacement: "Signature",
            contentType: .richText,
            richData: data
        )
        let items = SnippetPasteboardWriter.writeItems(for: snippet)
        XCTAssertEqual(items.first?.typeIdentifier, "public.rtf")
        XCTAssertEqual(items.first?.data, data)
    }

    func testImageWritesPNGAndTIFFTypes() {
        let data = Data([0x89, 0x50, 0x4E, 0x47])
        let snippet = TextExpansionSnippet(
            trigger: ":img",
            replacement: "image",
            contentType: .image,
            richData: data
        )
        let items = SnippetPasteboardWriter.writeItems(for: snippet)
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items.map(\.typeIdentifier).sorted(), ["public.png", "public.tiff"].sorted())
    }
}
