import Foundation
@testable import WindowSnap
import XCTest

final class UsageStatsTests: XCTestCase {
    func testRecordingIncrementsExpansionCount() {
        let stats = UsageStats().recording(trigger: ":ty", replacement: "Thank you")
        XCTAssertEqual(stats.expansionCount, 1)
    }

    func testRecordingAddsCharacterSavings() {
        let stats = UsageStats().recording(trigger: ":ty", replacement: "Thank you")
        XCTAssertEqual(stats.charactersSaved, 6)
    }

    func testRecordingNeverSubtractsWhenReplacementShorterThanTrigger() {
        let stats = UsageStats().recording(trigger: "longtrigger", replacement: "x")
        XCTAssertEqual(stats.charactersSaved, 0)
    }

    func testTimeSavedEstimateFormatsMinutes() {
        let stats = UsageStats(expansionCount: 10, charactersSaved: 1200)
        XCTAssertEqual(stats.timeSavedEstimate(wpm: 40), "6 minutes saved")
    }

    func testTimeSavedEstimateZeroWhenNoSavings() {
        let stats = UsageStats()
        XCTAssertEqual(stats.timeSavedEstimate(), "0 minutes saved")
    }
}
