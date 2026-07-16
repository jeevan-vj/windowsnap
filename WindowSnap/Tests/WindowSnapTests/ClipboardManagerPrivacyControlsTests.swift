import Foundation
@testable import WindowSnap
import XCTest

final class ClipboardManagerPrivacyControlsTests: XCTestCase {
    private var temporaryDirectory: URL!
    private var userDefaults: UserDefaults!
    private var suiteName: String!

    override func setUpWithError() throws {
        try super.setUpWithError()
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ClipboardManagerPrivacyControlsTests-\(UUID().uuidString)")
        suiteName = "ClipboardManagerPrivacyControlsTests.\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDownWithError() throws {
        userDefaults.removePersistentDomain(forName: suiteName)
        try? FileManager.default.removeItem(at: temporaryDirectory)
        try super.tearDownWithError()
    }

    func testPauseAndResumePersistMonitoringChoice() {
        let manager = makeManager()

        manager.pauseMonitoring()
        XCTAssertTrue(manager.isMonitoringPaused)

        manager.resumeMonitoring()
        XCTAssertFalse(manager.isMonitoringPaused)
        manager.stopMonitoring()
    }

    func testClearAllRemovesMemoryAndPersistentHistory() throws {
        let store = makeStore()
        try store.save([makeItem(content: "remove-me")])
        let manager = ClipboardManager(store: store, userDefaults: userDefaults)
        XCTAssertEqual(manager.getHistory().count, 1)

        manager.clearHistory()

        XCTAssertEqual(manager.getHistory().count, 0)
        XCTAssertEqual(store.load().count, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.historyURL.path))
    }

    private func makeManager() -> ClipboardManager {
        ClipboardManager(store: makeStore(), userDefaults: userDefaults)
    }

    private func makeStore() -> ClipboardHistoryStore {
        ClipboardHistoryStore(
            applicationSupportDirectory: temporaryDirectory,
            userDefaults: userDefaults
        )
    }

    private func makeItem(content: String) -> ClipboardHistoryItem {
        ClipboardHistoryItem(
            id: UUID(),
            content: content,
            type: .text,
            timestamp: Date(),
            preview: content,
            isPinned: false
        )
    }
}
