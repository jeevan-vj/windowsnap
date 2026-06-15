import Foundation
@testable import WindowSnap
import XCTest

final class MacroProcessorTests: XCTestCase {
    private let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)

    func testLegacyDateToken() {
        let result = MacroProcessor.expand("{date}", now: fixedDate, clipboard: nil)
        let expected = DateFormatter.localizedString(from: fixedDate, dateStyle: .medium, timeStyle: .none)
        XCTAssertEqual(result, expected)
    }

    func testLegacyTimeToken() {
        let result = MacroProcessor.expand("{time}", now: fixedDate, clipboard: nil)
        let expected = DateFormatter.localizedString(from: fixedDate, dateStyle: .none, timeStyle: .short)
        XCTAssertEqual(result, expected)
    }

    func testLegacyIsoDateToken() {
        let result = MacroProcessor.expand("{isodate}", now: fixedDate, clipboard: nil)
        XCTAssertEqual(result, ISO8601DateFormatter().string(from: fixedDate))
    }

    func testDateOffsetByDays() {
        let result = MacroProcessor.expand("{date:+3d}", now: fixedDate, clipboard: nil)
        let expectedDate = Calendar.current.date(byAdding: .day, value: 3, to: fixedDate)!
        let expected = DateFormatter.localizedString(from: expectedDate, dateStyle: .medium, timeStyle: .none)
        XCTAssertEqual(result, expected)
    }

    func testDateOffsetByWeeks() {
        let result = MacroProcessor.expand("{date:-2w}", now: fixedDate, clipboard: nil)
        let expectedDate = Calendar.current.date(byAdding: .weekOfYear, value: -2, to: fixedDate)!
        let expected = DateFormatter.localizedString(from: expectedDate, dateStyle: .medium, timeStyle: .none)
        XCTAssertEqual(result, expected)
    }

    func testCustomDateFormat() {
        let result = MacroProcessor.expand("{date:yyyy-MM-dd}", now: fixedDate, clipboard: nil)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        XCTAssertEqual(result, formatter.string(from: fixedDate))
    }

    func testCombinedOffsetAndFormat() {
        let result = MacroProcessor.expand("{date:+1d:yyyy-MM-dd}", now: fixedDate, clipboard: nil)
        let expectedDate = Calendar.current.date(byAdding: .day, value: 1, to: fixedDate)!
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        XCTAssertEqual(result, formatter.string(from: expectedDate))
    }

    func testClipboardTokenUsesProvidedValue() {
        let result = MacroProcessor.expand("clip:{clipboard}", now: fixedDate, clipboard: "hello")
        XCTAssertEqual(result, "clip:hello")
    }

    func testClipboardTokenEmptyWhenNil() {
        let result = MacroProcessor.expand("{clipboard}", now: fixedDate, clipboard: nil)
        XCTAssertEqual(result, "")
    }

    func testUuidTokenUsesInjectedGenerator() {
        let result = MacroProcessor.expand("{uuid}", now: fixedDate, clipboard: nil, uuid: { "test-uuid" })
        XCTAssertEqual(result, "test-uuid")
    }

    func testUnknownTokenLeftVerbatim() {
        let result = MacroProcessor.expand("{unknown}", now: fixedDate, clipboard: nil)
        XCTAssertEqual(result, "{unknown}")
    }
}
