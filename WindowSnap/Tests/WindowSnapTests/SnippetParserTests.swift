import Foundation
@testable import WindowSnap
import XCTest

final class SnippetParserTests: XCTestCase {
    func testPlainTextProducesSingleLiteralSegment() {
        let parsed = SnippetParser.parse("hello world")
        XCTAssertEqual(parsed.segments, [.literal("hello world")])
        XCTAssertTrue(parsed.fields.isEmpty)
    }

    func testSingleFieldToken() {
        let parsed = SnippetParser.parse("Hello {field:Name}")
        XCTAssertEqual(parsed.fields.count, 1)
        XCTAssertEqual(parsed.fields.first?.name, "Name")
        XCTAssertEqual(parsed.fields.first?.kind, .singleLine)
    }

    func testFieldWithDefaultValue() {
        let parsed = SnippetParser.parse("{field:Name:World}")
        XCTAssertEqual(parsed.fields.first?.defaultValue, "World")
    }

    func testPopupFieldParsesOptions() {
        let parsed = SnippetParser.parse("{popup:Day:Mon|Tue|Wed}")
        XCTAssertEqual(parsed.fields.first?.name, "Day")
        if case .popup(let options) = parsed.fields.first?.kind {
            XCTAssertEqual(options, ["Mon", "Tue", "Wed"])
        } else {
            XCTFail("Expected popup field")
        }
    }

    func testDuplicateFieldNameAppearsOnceInFieldsTwiceInSegments() {
        let parsed = SnippetParser.parse("{field:Name} and {field:Name}")
        XCTAssertEqual(parsed.fields.count, 1)
        XCTAssertEqual(parsed.segments.filter {
            if case .field = $0 { return true }
            return false
        }.count, 2)
    }

    func testMalformedFieldTokenTreatedAsLiteral() {
        let parsed = SnippetParser.parse("{field:}")
        XCTAssertEqual(parsed.segments, [.literal("{field:}")])
        XCTAssertTrue(parsed.fields.isEmpty)
    }
}

final class SnippetRendererTests: XCTestCase {
    func testRenderSubstitutesProvidedValues() {
        let parsed = SnippetParser.parse("Hello {field:Name}")
        let rendered = SnippetRenderer.render(parsed, values: ["Name": "Ada"])
        XCTAssertEqual(rendered, "Hello Ada")
    }

    func testRenderFallsBackToDefaultWhenValueMissing() {
        let parsed = SnippetParser.parse("{field:Name:World}")
        let rendered = SnippetRenderer.render(parsed, values: [:])
        XCTAssertEqual(rendered, "World")
    }

    func testRenderUsesSameValueForDuplicateFields() {
        let parsed = SnippetParser.parse("{field:Name} {field:Name}")
        let rendered = SnippetRenderer.render(parsed, values: ["Name": "Ada"])
        XCTAssertEqual(rendered, "Ada Ada")
    }
}

final class SnippetExpansionPipelineTests: XCTestCase {
    private let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)

    func testPipelineAppliesRenderMacrosAndCursor() {
        let template = "Hi {field:Name}, today is {date} {cursor}!"
        let result = SnippetExpansionPipeline.expand(
            template,
            values: ["Name": "Ada"],
            now: fixedDate,
            clipboard: nil,
            uuid: { "test-uuid" }
        )

        let expectedDate = DateFormatter.localizedString(from: fixedDate, dateStyle: .medium, timeStyle: .none)
        XCTAssertEqual(result.text, "Hi Ada, today is \(expectedDate) !")
        XCTAssertEqual(result.leftArrowCount, 1)
    }
}
