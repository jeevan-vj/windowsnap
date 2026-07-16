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

    func testDefaultRetentionDoesNotDropOldLegacyEntriesBeforeExplicitChoice() throws {
        let oldItem = ClipboardHistoryItem(
            id: UUID(),
            content: "old-but-not-consented",
            type: .text,
            timestamp: Date(timeIntervalSinceNow: -90 * 86_400),
            preview: "old-but-not-consented",
            isPinned: false
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        userDefaults.set(
            try encoder.encode([oldItem]),
            forKey: ClipboardHistoryStore.legacyDefaultsKey
        )

        let firstLaunch = makeManager()
        XCTAssertEqual(firstLaunch.getHistory().map(\.content), ["old-but-not-consented"])

        let secondLaunch = makeManager()
        XCTAssertEqual(secondLaunch.getHistory().map(\.content), ["old-but-not-consented"])
        XCTAssertTrue(userDefaults.bool(forKey: ClipboardManager.migratedHistoryProtectionDefaultsKey))

        secondLaunch.retention = .sevenDays
        XCTAssertTrue(secondLaunch.getHistory().isEmpty)
        XCTAssertFalse(userDefaults.bool(forKey: ClipboardManager.migratedHistoryProtectionDefaultsKey))
        XCTAssertTrue(userDefaults.bool(forKey: ClipboardManager.explicitRetentionChoiceDefaultsKey))
    }

    func testPauseStateChangeNotifiesAllUIObservers() {
        let manager = makeManager()
        var preferencesStates: [Bool] = []
        var menuStates: [Bool] = []
        let preferencesObserver = ClipboardPauseStateObserver { preferencesStates.append($0) }
        let menuObserver = ClipboardPauseStateObserver { menuStates.append($0) }

        manager.pauseMonitoring()
        manager.resumeMonitoring()
        manager.stopMonitoring()

        XCTAssertEqual(preferencesStates, [true, false])
        XCTAssertEqual(menuStates, [true, false])
        withExtendedLifetime([preferencesObserver, menuObserver]) {}
    }

    func testManagerClearEventPurgesPresentationCacheSynchronously() throws {
        let center = NotificationCenter()
        let store = makeStore()
        try store.save([makeItem(content: "cached-sensitive-value")])
        let manager = ClipboardManager(
            store: store,
            userDefaults: userDefaults,
            notificationCenter: center
        )
        let cache = ClipboardHistoryPresentationCache(notificationCenter: center)
        cache.history = manager.getHistory()
        cache.filteredHistory = cache.history
        cache.displayItems = cache.history.map(ClipboardHistorySectionItem.item)

        manager.clearHistory()

        XCTAssertTrue(cache.history.isEmpty)
        XCTAssertTrue(cache.filteredHistory.isEmpty)
        XCTAssertTrue(cache.displayItems.isEmpty)
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
